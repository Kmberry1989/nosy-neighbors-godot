class_name NosyNeighbors
extends Node
## Live game-show manager for "Nosy Neighbors!" — the Family Feud-style
## one-on-one. The room host is the MC and the authority; two contestants
## (humans, plus "Nosy Bot" when only one human shows up) face off.
##
## The buzzer is the whole reason this lives in the Godot client: every
## contestant's buzz press is a rollback-synced input stamped with the shared
## tick clock, so the host rewinds time and crowns the true first presser.
## Late-arriving inputs still carry their true tick, and a short grace window
## after the first observed buzz lets stragglers land before the call.

const BOT_ID := 0
const BOT_NAME := "Nosy Bot"
const FACEOFF_GRACE_TICKS := 45   # 0.75 s for late inputs to land
const FACEOFF_TIMEOUT_TICKS := 900  # 15 s with no buzz -> re-prompt
const ANSWER_TICKS := 720         # 12 s per answer
const INTRO_TICKS := 180          # 3 s round intro
const RESULT_TICKS := 90          # 1.5 s "X buzzed first!" beat
const PAUSE_TICKS := 240          # 4 s between rounds
const ROUNDS_PER_SHOW := 3
const FM_QUESTIONS := 5
const FM_TIME_P1_TICKS := 1200  # 20 s for the leader
const FM_TIME_P2_TICKS := 1500  # 25 s for the trailer
const PODIUM_A := Vector3(-9.5, 0.0, 9.0)
const PODIUM_B := Vector3(-6.5, 0.0, 9.0)
const BOT_WRONG_ANSWERS := ["uhhh", "my neighbor's cat", "taxes", "the moon",
		"spaghetti", "idk", "a lamp", "the HOA"]

enum Phase { IDLE, ROUND_INTRO, FACEOFF, FACEOFF_RESULT, FACEOFF_ANSWER,
		FACEOFF_ANSWER2, CONTROL, STEAL, ROUND_END, SHOW_END,
		FAST_MONEY_INTRO, FAST_MONEY_TURN, FAST_MONEY_RESULTS }

var phase: int = Phase.IDLE
var buzz_window_open := false
var faceoff_start_tick := 0

var _contestants: Array = []
var _names := {}
var _scores := {}
var _questions: Array = []
var _q_index := 0
var _answers: Array = []
var _revealed: Array = []
var _bank := 0
var _strikes := 0
var _controller := 0
var _faceoff_winner := 0
var _faceoff_loser := 0
var _winner_points := 0
var _buzzes := {}
var _grace_until := 0
var _deadline_tick := 0
var _awaiting_answer_from := 0
var _bot_buzz_tick := -1
var _bot_answer_tick := -1
# Fast Money state
var _fm_questions: Array = []
var _fm_order: Array = []
var _fm_turn := 0
var _fm_q := 0
var _fm_deadline := 0
var _fm_scores := {}
var _fm_p1_answers: Array = []
var _fm_revealed: Array = []

@onready var _ui: CanvasLayer = $NosyNeighborsUI


func _ready() -> void:
	_ui.answer_submitted.connect(_on_local_answer_submitted)
	_ui.host_start_requested.connect(host_start_show)
	_ui.set_host_controls(is_multiplayer_authority())
	_ui.hide_ui()


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	_check_contestants_present()
	match phase:
		Phase.ROUND_INTRO:
			if NetworkTime.tick >= _deadline_tick:
				_begin_faceoff()
		Phase.FACEOFF:
			_update_faceoff()
		Phase.FACEOFF_RESULT:
			if NetworkTime.tick >= _deadline_tick:
				_begin_faceoff_answer()
		Phase.FACEOFF_ANSWER, Phase.FACEOFF_ANSWER2, Phase.CONTROL, Phase.STEAL:
			_update_bot_answer()
			if _awaiting_answer_from != 0 and NetworkTime.tick >= _deadline_tick:
				_on_answer(_awaiting_answer_from, "")
		Phase.ROUND_END:
			if NetworkTime.tick >= _deadline_tick:
				_advance_round()
		Phase.FAST_MONEY_INTRO:
			if NetworkTime.tick >= _deadline_tick:
				_begin_fm_turn()
		Phase.FAST_MONEY_TURN:
			_update_bot_answer()
			if _awaiting_answer_from != 0 and NetworkTime.tick >= _fm_deadline:
				_end_fm_turn()
		Phase.FAST_MONEY_RESULTS:
			if NetworkTime.tick >= _deadline_tick:
				if _fm_turn == 0:
					_fm_turn = 1
					_begin_fm_turn()
				else:
					_finish_fast_money()


# ---------------------------------------------------------------- host API

func host_start_show() -> void:
	if not is_multiplayer_authority():
		return
	if phase != Phase.IDLE and phase != Phase.SHOW_END:
		return
	if not _gather_contestants():
		_ui.set_status("Need at least one contestant to start the show!")
		return
	_questions = SurveyData.load_questions()
	_questions.shuffle()
	if _questions.is_empty():
		_ui.set_status("No survey questions found!")
		return
	_q_index = 0
	_scores.clear()
	for pid in _contestants:
		_scores[pid] = 0
		_names[pid] = _name_of(pid)
	var spawn := get_node("../World/PlayerSpawnPoint")
	for i in _contestants.size():
		var pid: int = _contestants[i]
		if pid == BOT_ID:
			continue
		var p = spawn.get_node_or_null(str(pid))
		if p:
			p.position = PODIUM_A if i == 0 else PODIUM_B
			p.set_movement_locked(true)
	var ids: Array = []
	var nms: Array = []
	for pid in _contestants:
		ids.append(pid)
		nms.append(_names[pid])
	rpc_lock_movement.rpc(true)
	rpc_show_start.rpc(ids, nms)
	_begin_round()


func is_faceoff_open() -> bool:
	return buzz_window_open and phase == Phase.FACEOFF


func record_buzz(pid: int, tick: int) -> void:
	if phase != Phase.FACEOFF:
		return
	if tick < faceoff_start_tick:
		return
	if not _contestants.has(pid):
		return
	if _buzzes.has(pid):
		_buzzes[pid] = mini(_buzzes[pid], tick)
	else:
		_buzzes[pid] = tick


# ------------------------------------------------------------- host phases

func _gather_contestants() -> bool:
	_contestants.clear()
	var spawn := get_node("../World/PlayerSpawnPoint")
	var ids: Array = []
	for child in spawn.get_children():
		var pid := str(child.name).to_int()
		if pid == 1 or pid <= 0:
			continue  # host is the MC, never a contestant
		ids.append(pid)
	ids.sort()
	_contestants = ids.slice(0, 2)
	while _contestants.size() < 2:
		_contestants.append(BOT_ID)
	# At least one human, otherwise it's just a bot talking to itself.
	for pid in _contestants:
		if pid != BOT_ID:
			return true
	return false


func _begin_round() -> void:
	var q: Dictionary = _questions[_q_index]
	_answers = q["answers"]
	_revealed = []
	for _a in _answers:
		_revealed.append(false)
	_bank = 0
	_strikes = 0
	_controller = 0
	phase = Phase.ROUND_INTRO
	_deadline_tick = NetworkTime.tick + INTRO_TICKS
	rpc_round_intro.rpc(_q_index + 1, ROUNDS_PER_SHOW, q["category"])


func _begin_faceoff() -> void:
	var q: Dictionary = _questions[_q_index]
	phase = Phase.FACEOFF
	_buzzes.clear()
	_grace_until = 0
	_bot_buzz_tick = -1
	faceoff_start_tick = NetworkTime.tick
	buzz_window_open = true
	_deadline_tick = NetworkTime.tick + FACEOFF_TIMEOUT_TICKS
	rpc_faceoff.rpc(q["question"], _answers.size())


func _update_faceoff() -> void:
	var now := NetworkTime.tick
	if _contestants.has(BOT_ID) and _bot_buzz_tick == -1:
		_bot_buzz_tick = faceoff_start_tick + randi_range(15, 90)
	if _bot_buzz_tick > 0 and now >= _bot_buzz_tick:
		record_buzz(BOT_ID, _bot_buzz_tick)
		_bot_buzz_tick = -2
	if not _buzzes.is_empty():
		if _grace_until == 0:
			_grace_until = _buzzes.values().min() + FACEOFF_GRACE_TICKS
		if now >= _grace_until:
			_resolve_faceoff()
	elif now >= _deadline_tick:
		_begin_faceoff()
		rpc_status.rpc("Nobody buzzed — one more time! BUZZ IN!")


func _resolve_faceoff() -> void:
	var winner := _earliest_buzzer()
	_faceoff_winner = winner
	_faceoff_loser = _other_contestant(winner)
	_winner_points = 0
	buzz_window_open = false
	rpc_buzz_window.rpc(false)
	phase = Phase.FACEOFF_RESULT
	_deadline_tick = NetworkTime.tick + RESULT_TICKS
	rpc_faceoff_result.rpc(_names[winner])


func _begin_faceoff_answer() -> void:
	phase = Phase.FACEOFF_ANSWER
	_prompt(_faceoff_winner)


func _prompt(pid: int) -> void:
	_awaiting_answer_from = pid
	_deadline_tick = NetworkTime.tick + ANSWER_TICKS
	rpc_prompt_answer.rpc(pid, _names[pid])
	if pid == BOT_ID:
		_bot_answer_tick = NetworkTime.tick + randi_range(60, 150)


func _on_answer(pid: int, text: String) -> void:
	if pid != _awaiting_answer_from:
		return
	if phase == Phase.FAST_MONEY_TURN:
		_on_fm_answer(pid, text)
		return
	_awaiting_answer_from = 0
	_bot_answer_tick = -1
	var idx := SurveyData.match_answer(text, _answers, _revealed)
	match phase:
		Phase.FACEOFF_ANSWER:
			if idx >= 0:
				_reveal(idx)
				_winner_points = _answers[idx]["points"]
				if idx == 0:
					_set_controller(_faceoff_winner)
				else:
					phase = Phase.FACEOFF_ANSWER2
					_prompt(_faceoff_loser)
			else:
				rpc_status.rpc("%s missed!" % _names[pid])
				phase = Phase.FACEOFF_ANSWER2
				_prompt(_faceoff_loser)
		Phase.FACEOFF_ANSWER2:
			if idx >= 0:
				_reveal(idx)
				if _answers[idx]["points"] > _winner_points:
					_set_controller(_faceoff_loser)
				else:
					_set_controller(_faceoff_winner)
			else:
				rpc_status.rpc("%s missed!" % _names[pid])
				_set_controller(_faceoff_winner)
		Phase.CONTROL:
			if idx >= 0:
				_reveal(idx)
				_bank += _answers[idx]["points"]
				rpc_bank.rpc(_bank, _names[_controller])
				if _all_revealed():
					_award_bank(_controller)
					_end_round()
				else:
					_prompt(_controller)
			else:
				_strikes += 1
				rpc_strike.rpc(_strikes)
				if _strikes >= 3:
					phase = Phase.STEAL
					rpc_status.rpc("Three strikes! %s can steal the bank!" % _names[_other_contestant(_controller)])
					_prompt(_other_contestant(_controller))
				else:
					_prompt(_controller)
		Phase.STEAL:
			var stealer := pid
			if idx >= 0:
				_reveal(idx)
				_award_bank(stealer)
				rpc_status.rpc("%s steals the bank!" % _names[stealer])
			else:
				_award_bank(_controller)
				rpc_status.rpc("%s couldn't steal it." % _names[stealer])
			_end_round()


func _set_controller(pid: int) -> void:
	_controller = pid
	_strikes = 0
	phase = Phase.CONTROL
	rpc_control.rpc(_names[pid])
	_prompt(pid)


func _end_round() -> void:
	phase = Phase.ROUND_END
	_deadline_tick = NetworkTime.tick + PAUSE_TICKS
	var ids: Array = []
	var nms: Array = []
	var scs: Array = []
	for pid in _contestants:
		ids.append(pid)
		nms.append(_names[pid])
		scs.append(_scores[pid])
	rpc_round_end.rpc(ids, nms, scs)


func _advance_round() -> void:
	_q_index += 1
	if _q_index < ROUNDS_PER_SHOW and _q_index < _questions.size():
		_begin_round()
	else:
		_begin_fast_money()


# ------------------------------------------------------- Fast Money endgame

func _begin_fast_money() -> void:
	var pool := SurveyData.load_fast_money()
	pool.shuffle()
	_fm_questions = pool.slice(0, FM_QUESTIONS)
	if _fm_questions.size() < FM_QUESTIONS:
		_end_show()
		return
	# Leader plays first (ties go to the first contestant).
	var leader: int = _contestants[0]
	for pid in _contestants:
		if _scores[pid] > _scores[leader]:
			leader = pid
	_fm_order = [leader, _other_contestant(leader)]
	_fm_turn = 0
	_fm_scores.clear()
	for pid in _contestants:
		_fm_scores[pid] = 0
	_fm_p1_answers.clear()
	phase = Phase.FAST_MONEY_INTRO
	_deadline_tick = NetworkTime.tick + INTRO_TICKS
	rpc_fm_intro.rpc()


func _begin_fm_turn() -> void:
	var pid: int = _fm_order[_fm_turn]
	_fm_q = 0
	var total_ticks := FM_TIME_P1_TICKS if _fm_turn == 0 else FM_TIME_P2_TICKS
	_fm_deadline = NetworkTime.tick + total_ticks
	phase = Phase.FAST_MONEY_TURN
	rpc_fm_turn.rpc(pid, _names[pid], total_ticks / 60)
	_ask_fm_question()


func _ask_fm_question() -> void:
	var pid: int = _fm_order[_fm_turn]
	var q: Dictionary = _fm_questions[_fm_q]
	_answers = q["answers"]
	_fm_revealed = []
	for i in _answers.size():
		_fm_revealed.append(false)
	_revealed = _fm_revealed
	_awaiting_answer_from = pid
	rpc_fm_question.rpc(pid, _names[pid], _fm_q, q["question"])
	if pid == BOT_ID:
		_bot_answer_tick = NetworkTime.tick + randi_range(60, 150)


func _on_fm_answer(pid: int, text: String) -> void:
	_awaiting_answer_from = 0
	_bot_answer_tick = -1
	var norm := SurveyData.normalize(text)
	# Second player can't repeat the first player's answers.
	if _fm_turn == 1 and norm != "" and norm in _fm_p1_answers:
		rpc_fm_result.rpc(_fm_q, text, 0, true)
		_ask_fm_question()
		return
	var idx := SurveyData.match_answer(text, _answers, _revealed)
	var points := 0
	if idx >= 0:
		points = _answers[idx]["points"]
		_revealed[idx] = true
	if _fm_turn == 0 and norm != "":
		_fm_p1_answers.append(norm)
	_fm_scores[pid] = _fm_scores[pid] + points
	rpc_fm_result.rpc(_fm_q, text, points, false)
	_fm_q += 1
	if _fm_q >= FM_QUESTIONS:
		_end_fm_turn()
	else:
		_ask_fm_question()


func _end_fm_turn() -> void:
	_awaiting_answer_from = 0
	_bot_answer_tick = -1
	var pid: int = _fm_order[_fm_turn]
	phase = Phase.FAST_MONEY_RESULTS
	_deadline_tick = NetworkTime.tick + PAUSE_TICKS
	rpc_fm_turn_end.rpc(_names[pid], _fm_scores[pid])


func _finish_fast_money() -> void:
	for pid in _contestants:
		_scores[pid] = _scores[pid] + _fm_scores[pid]
	var ids: Array = []
	var nms: Array = []
	var scs: Array = []
	for pid in _contestants:
		ids.append(pid)
		nms.append(_names[pid])
		scs.append(_scores[pid])
	rpc_scores.rpc(ids, nms, scs)
	_end_show()


func _end_show() -> void:
	phase = Phase.SHOW_END
	var winner: int = _contestants[0]
	for pid in _contestants:
		if _scores[pid] > _scores[winner]:
			winner = pid
	var spawn := get_node("../World/PlayerSpawnPoint")
	for pid in _contestants:
		if pid == BOT_ID:
			continue
		var p = spawn.get_node_or_null(str(pid))
		if p:
			p.set_movement_locked(false)
	var ids: Array = []
	var nms: Array = []
	var scs: Array = []
	for pid in _contestants:
		ids.append(pid)
		nms.append(_names[pid])
		scs.append(_scores[pid])
	rpc_lock_movement.rpc(false)
	rpc_show_end.rpc(_names[winner], ids, nms, scs)


func _abort_show(reason: String) -> void:
	phase = Phase.IDLE
	buzz_window_open = false
	var spawn := get_node("../World/PlayerSpawnPoint")
	for pid in _contestants:
		if pid == BOT_ID:
			continue
		var p = spawn.get_node_or_null(str(pid))
		if p:
			p.set_movement_locked(false)
	_contestants.clear()
	rpc_lock_movement.rpc(false)
	rpc_abort.rpc(reason)


func _check_contestants_present() -> void:
	if phase == Phase.IDLE or phase == Phase.SHOW_END:
		return
	var spawn := get_node("../World/PlayerSpawnPoint")
	for pid in _contestants:
		if pid == BOT_ID:
			continue
		if spawn.get_node_or_null(str(pid)) == null:
			_abort_show("A contestant left — show's over!")
			return


# ------------------------------------------------------------------ helpers

func _earliest_buzzer() -> int:
	var best := -1
	var best_tick := 1 << 30
	for pid in _buzzes:
		var t: int = _buzzes[pid]
		if t < best_tick or (t == best_tick and pid < best):
			best = pid
			best_tick = t
	return best


func _other_contestant(pid: int) -> int:
	for c in _contestants:
		if c != pid:
			return c
	return pid


func _reveal(idx: int) -> void:
	_revealed[idx] = true
	rpc_reveal_answer.rpc(idx, _answers[idx]["text"], _answers[idx]["points"])


func _all_revealed() -> bool:
	for r in _revealed:
		if not r:
			return false
	return true


func _award_bank(pid: int) -> void:
	_scores[pid] = _scores[pid] + _bank
	_bank = 0
	var ids: Array = []
	var nms: Array = []
	var scs: Array = []
	for c in _contestants:
		ids.append(c)
		nms.append(_names[c])
		scs.append(_scores[c])
	rpc_scores.rpc(ids, nms, scs)


func _update_bot_answer() -> void:
	if _awaiting_answer_from == BOT_ID and _bot_answer_tick > 0 \
			and NetworkTime.tick >= _bot_answer_tick:
		_bot_answer_tick = -1
		_submit_bot_answer()


func _submit_bot_answer() -> void:
	var unrevealed: Array = []
	for i in _answers.size():
		if not _revealed[i]:
			unrevealed.append(i)
	var text := ""
	if not unrevealed.is_empty() and randf() < 0.65:
		text = _answers[unrevealed[randi_range(0, unrevealed.size() - 1)]]["text"]
	else:
		text = BOT_WRONG_ANSWERS[randi_range(0, BOT_WRONG_ANSWERS.size() - 1)]
	_on_answer(BOT_ID, text)


func _name_of(pid: int) -> String:
	if pid == BOT_ID:
		return BOT_NAME
	var p = get_node_or_null("../World/PlayerSpawnPoint/%d" % pid)
	if p and "display_name" in p:
		return p.display_name
	return "Neighbor %d" % pid


func _is_local_contestant() -> bool:
	return _contestants.has(multiplayer.get_unique_id())


func _on_local_answer_submitted(text: String) -> void:
	_rpc_submit_answer.rpc_id(1, text.strip_edges())


# --------------------------------------------------------------------- RPCs
# Host -> everyone. call_local so the host's own UI updates with one call.

@rpc("authority", "call_local", "reliable")
func rpc_show_start(ids: Array, names: Array) -> void:
	_contestants = ids.duplicate()
	_names.clear()
	for i in ids.size():
		_names[ids[i]] = names[i]
	_ui.show_ui()
	_ui.set_host_controls(false)
	_ui.set_scores(names, [0, 0])


@rpc("authority", "call_local", "reliable")
func rpc_lock_movement(locked: bool) -> void:
	var spawn := get_node("../World/PlayerSpawnPoint")
	for child in spawn.get_children():
		if child.has_method("set_movement_locked"):
			child.set_movement_locked(locked)


@rpc("authority", "call_local", "reliable")
func rpc_round_intro(round_no: int, total: int, category: String) -> void:
	_ui.round_intro(round_no, total, category)


@rpc("authority", "call_local", "reliable")
func rpc_faceoff(question: String, answer_count: int) -> void:
	buzz_window_open = true
	_ui.show_faceoff(question, answer_count)
	_ui.set_status("BUZZ IN!")
	_ui.prompt_buzz(_is_local_contestant())


@rpc("authority", "call_local", "reliable")
func rpc_buzz_window(open: bool) -> void:
	buzz_window_open = open
	_ui.prompt_buzz(false)


@rpc("authority", "call_local", "reliable")
func rpc_faceoff_result(winner_name: String) -> void:
	_ui.set_status("%s buzzed first!" % winner_name)


@rpc("authority", "call_local", "reliable")
func rpc_prompt_answer(pid: int, pname: String) -> void:
	var mine := pid == multiplayer.get_unique_id()
	_ui.prompt_answer(mine)
	if mine:
		_ui.set_status("Your turn — name something on the board!")
	else:
		_ui.set_status("%s is answering…" % pname)


@rpc("authority", "call_local", "reliable")
func rpc_reveal_answer(slot: int, text: String, points: int) -> void:
	_ui.reveal_answer(slot, text, points)


@rpc("authority", "call_local", "reliable")
func rpc_strike(strikes: int) -> void:
	_ui.set_strikes(strikes)


@rpc("authority", "call_local", "reliable")
func rpc_bank(bank: int, controller_name: String) -> void:
	_ui.set_status("Bank: %d — %s is in control" % [bank, controller_name])


@rpc("authority", "call_local", "reliable")
func rpc_control(controller_name: String) -> void:
	_ui.set_strikes(0)
	_ui.set_status("%s has control of the board!" % controller_name)


@rpc("authority", "call_local", "reliable")
func rpc_scores(ids: Array, names: Array, scores: Array) -> void:
	_ui.set_scores(names, scores)


@rpc("authority", "call_local", "reliable")
func rpc_round_end(ids: Array, names: Array, scores: Array) -> void:
	_ui.set_scores(names, scores)
	_ui.prompt_answer(false)
	_ui.set_status("Round over!")


@rpc("authority", "call_local", "reliable")
func rpc_fm_intro() -> void:
	_ui.fm_intro()


@rpc("authority", "call_local", "reliable")
func rpc_fm_turn(pid: int, pname: String, seconds: int) -> void:
	_ui.fm_turn(pname, seconds)
	_ui.prompt_answer(pid == multiplayer.get_unique_id())
	if pid == multiplayer.get_unique_id():
		_ui.set_status("Fast Money — %d seconds, %d questions. Go!" % [seconds, FM_QUESTIONS])
	else:
		_ui.set_status("%s is playing Fast Money…" % pname)


@rpc("authority", "call_local", "reliable")
func rpc_fm_question(pid: int, _pname: String, q_idx: int, question: String) -> void:
	_ui.fm_question(q_idx, question)
	_ui.prompt_answer(pid == multiplayer.get_unique_id())


@rpc("authority", "call_local", "reliable")
func rpc_fm_result(q_idx: int, text: String, points: int, is_dup: bool) -> void:
	_ui.fm_result(q_idx, text, points, is_dup)


@rpc("authority", "call_local", "reliable")
func rpc_fm_turn_end(pname: String, fm_score: int) -> void:
	_ui.prompt_answer(false)
	_ui.set_status("%s's Fast Money: %d points!" % [pname, fm_score])


@rpc("authority", "call_local", "reliable")
func rpc_show_end(winner_name: String, ids: Array, names: Array, scores: Array) -> void:
	_ui.fm_hide()
	_ui.set_scores(names, scores)
	_ui.prompt_answer(false)
	_ui.prompt_buzz(false)
	_ui.show_winner(winner_name)
	_ui.set_host_controls(is_multiplayer_authority())


@rpc("authority", "call_local", "reliable")
func rpc_abort(reason: String) -> void:
	_ui.hide_ui()
	_ui.set_host_controls(is_multiplayer_authority())
	# Status shows on next show; keep it simple.


@rpc("authority", "call_local", "reliable")
func rpc_status(text: String) -> void:
	_ui.set_status(text)


# Contestant -> host.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_submit_answer(text: String) -> void:
	if not is_multiplayer_authority():
		return
	_on_answer(multiplayer.get_remote_sender_id(), text)
