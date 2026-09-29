extends CanvasLayer
## On-screen HUD for the Nosy Neighbors live game show: question board,
## scores, status line, buzzer button, answer entry, and host controls.
## Driven entirely by the NosyNeighbors manager via RPCs.

signal answer_submitted(text: String)
signal host_start_requested()


func _ready() -> void:
	$BuzzButton.button_down.connect(_on_buzz_down)
	$BuzzButton.button_up.connect(_on_buzz_up)
	$AnswerBox/SubmitButton.pressed.connect(_on_submit_pressed)
	$AnswerBox/AnswerEdit.text_submitted.connect(_on_edit_submitted)
	$HostPanel/VBox/HostStartButton.pressed.connect(_on_host_start_pressed)


func hide_ui() -> void:
	visible = false


func show_ui() -> void:
	visible = true
	$WinnerLabel.visible = false
	prompt_buzz(false)
	prompt_answer(false)
	set_strikes(0)


func round_intro(round_no: int, total: int, category: String) -> void:
	$BoardPanel/VBox/QuestionLabel.text = "ROUND %d of %d\n%s" % [round_no, total, category]
	set_status("Get ready…")


func show_faceoff(question: String, answer_count: int) -> void:
	$BoardPanel/VBox/QuestionLabel.text = question
	for i in 5:
		var lbl: Label = $BoardPanel/VBox.get_node("Answer%d" % i)
		lbl.text = "%d. ···" % (i + 1) if i < answer_count else ""
	set_strikes(0)


func reveal_answer(slot: int, text: String, points: int) -> void:
	var lbl: Label = $BoardPanel/VBox.get_node("Answer%d" % slot)
	lbl.text = "%d. %s — %d" % [slot + 1, text, points]


func set_scores(names: Array, scores: Array) -> void:
	var lines: Array = []
	for i in mini(names.size(), scores.size()):
		lines.append("%s: %d" % [names[i], scores[i]])
	$ScorePanel/VBox/ScoreLabel.text = "\n".join(lines)


func set_status(text: String) -> void:
	$StatusLabel.text = text


func set_strikes(n: int) -> void:
	$BoardPanel/VBox/StrikesLabel.text = "Strikes: " + ("X ".repeat(n).strip_edges() if n > 0 else "–")


func prompt_buzz(show: bool) -> void:
	$BuzzButton.visible = show


func prompt_answer(show: bool) -> void:
	$AnswerBox.visible = show
	if show:
		$AnswerBox/AnswerEdit.text = ""
		$AnswerBox/AnswerEdit.grab_focus()


func show_winner(winner_name: String) -> void:
	fm_hide()
	$WinnerLabel.text = "%s WINS THE SHOW!" % winner_name
	$WinnerLabel.visible = true


func set_host_controls(shown: bool) -> void:
	$HostPanel.visible = shown


# ------------------------------------------------------------ Fast Money UI

var _fm_time_left := 0.0
var _fm_active := false


func _process(delta: float) -> void:
	if _fm_active and _fm_time_left > 0.0:
		_fm_time_left = maxf(0.0, _fm_time_left - delta)
		$FMPanel/VBox/FMTimerLabel.text = "⏱ %d" % int(ceil(_fm_time_left))


func fm_intro() -> void:
	$BoardPanel.visible = false
	$WinnerLabel.visible = false
	$FMPanel.visible = true
	$FMPanel/VBox/FMTitle.text = "FAST MONEY"
	$FMPanel/VBox/FMTimerLabel.text = ""
	for i in 5:
		$FMPanel/VBox.get_node("FMRow%d" % i).text = "%d. ···" % (i + 1)


func fm_turn(player_name: String, seconds: int) -> void:
	$FMPanel/VBox/FMTitle.text = "FAST MONEY — %s" % player_name
	_fm_time_left = float(seconds)
	_fm_active = true
	for i in 5:
		$FMPanel/VBox.get_node("FMRow%d" % i).text = "%d. ···" % (i + 1)


func fm_question(q_idx: int, question: String) -> void:
	$FMPanel/VBox.get_node("FMRow%d" % q_idx).text = "%d. %s…" % [q_idx + 1, question]


func fm_result(q_idx: int, text: String, points: int, is_dup: bool) -> void:
	var lbl: Label = $FMPanel/VBox.get_node("FMRow%d" % q_idx)
	if is_dup:
		lbl.text = "%d. Already said — try again! (0)" % (q_idx + 1)
	elif points > 0:
		lbl.text = "%d. %s — %d pts" % [q_idx + 1, text, points]
	else:
		lbl.text = "%d. %s — 0" % [q_idx + 1, text]


func fm_hide() -> void:
	_fm_active = false
	$FMPanel.visible = false
	$BoardPanel.visible = true


func _on_buzz_down() -> void:
	Input.action_press("buzz")


func _on_buzz_up() -> void:
	Input.action_release("buzz")


func _on_submit_pressed() -> void:
	_submit_edit()


func _on_edit_submitted(_text: String) -> void:
	_submit_edit()


func _submit_edit() -> void:
	var edit: LineEdit = $AnswerBox/AnswerEdit
	var text := edit.text.strip_edges()
	if text.is_empty():
		return
	edit.text = ""
	answer_submitted.emit(text)


func _on_host_start_pressed() -> void:
	host_start_requested.emit()
