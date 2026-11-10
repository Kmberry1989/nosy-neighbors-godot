class_name SidewalkChats
extends Node3D
## Director for the sidewalk-chats prototype.
##
## Loop: the two neighbors stroll in from opposite ends of the sidewalk,
## meet, trade the lines of one conversation from data/sidewalk_chats.json,
## then stroll back to their ends and the next conversation starts.
## Argument conversations use red bubbles and both neighbors wave their arms.
## Walk up mid-conversation and both neighbors stop, turn to face you, and
## hold until you back off (no spoken line yet — that line is still a pick).

const LINE_TIME := 3.4
const GAP_TIME := 0.5
const PAUSE_TIME := 1.6
const INTERRUPT_DIST := 2.4
const LEAVE_DIST := 3.2
const RESUME_DELAY := 1.0
const MEET_GAP := 1.1

enum State { MEET, CHAT_LINE, CHAT_GAP, PART, PAUSE, INTERRUPTED }

@onready var _neighbor_a: SidewalkNeighbor = $NeighborA
@onready var _neighbor_b: SidewalkNeighbor = $NeighborB
@onready var _player: CharacterBody3D = $LotPlayer

var _state: int = State.MEET
var _state_time := 0.0
var _cast_by_id := {}
var _conversations: Array = []
var _order: Array = []
var _conv_index := 0
var _conv: Dictionary = {}
var _line_index := 0
var _interrupted_line := 0
var _resume_timer := 0.0
var _end_a := Vector3.ZERO
var _end_b := Vector3.ZERO
var _meet_a := Vector3.ZERO
var _meet_b := Vector3.ZERO


func _ready() -> void:
	if not _load_data():
		return
	_end_a = _neighbor_a.global_position
	_end_b = _neighbor_b.global_position
	var mid: Vector3 = (_end_a + _end_b) * 0.5
	_meet_a = Vector3(mid.x - MEET_GAP, mid.y, mid.z)
	_meet_b = Vector3(mid.x + MEET_GAP, mid.y, mid.z)
	_order = []
	for i in _conversations.size():
		_order.append(i)
	_order.shuffle()
	_conv_index = 0
	_start_conversation()
	_walk_to_meet()


func _process(delta: float) -> void:
	_state_time += delta
	match _state:
		State.MEET:
			if _arrived(_neighbor_a, _meet_a) and _arrived(_neighbor_b, _meet_b):
				_start_chat()
		State.CHAT_LINE:
			if _player_close():
				_interrupt()
			elif _state_time >= LINE_TIME:
				_end_line()
		State.CHAT_GAP:
			if _player_close():
				_interrupt()
			elif _state_time >= GAP_TIME:
				_show_line(_line_index + 1)
		State.PART:
			if _arrived(_neighbor_a, _end_a) and _arrived(_neighbor_b, _end_b):
				_state = State.PAUSE
				_state_time = 0.0
		State.PAUSE:
			if _state_time >= PAUSE_TIME:
				_next_conversation()
		State.INTERRUPTED:
			_neighbor_a.face_toward(_player.global_position)
			_neighbor_b.face_toward(_player.global_position)
			if _player_far():
				_resume_timer += delta
				if _resume_timer >= RESUME_DELAY:
					_show_line(_interrupted_line)
			else:
				_resume_timer = 0.0


func _load_data() -> bool:
	var file := FileAccess.open("res://data/sidewalk_chats.json", FileAccess.READ)
	if file == null:
		push_error("SidewalkChats: could not open data/sidewalk_chats.json")
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("SidewalkChats: bad JSON in data/sidewalk_chats.json")
		return false
	var data: Dictionary = json.data
	for person in data.get("cast", []):
		_cast_by_id[str(person.get("id", ""))] = person
	_conversations = data.get("conversations", [])
	if _conversations.is_empty():
		push_error("SidewalkChats: no conversations in data/sidewalk_chats.json")
		return false
	return true


func _start_conversation() -> void:
	_conv = _conversations[_order[_conv_index]]
	_neighbor_a.setup(_cast_by_id.get(str(_conv.get("a", "")), {}))
	_neighbor_b.setup(_cast_by_id.get(str(_conv.get("b", "")), {}))


func _next_conversation() -> void:
	_conv_index = (_conv_index + 1) % _order.size()
	_start_conversation()
	_walk_to_meet()


func _walk_to_meet() -> void:
	_neighbor_a.clear_face_target()
	_neighbor_b.clear_face_target()
	_neighbor_a.walk_to(_meet_a)
	_neighbor_b.walk_to(_meet_b)
	_state = State.MEET
	_state_time = 0.0


func _start_chat() -> void:
	_line_index = 0
	_show_line(0)


func _show_line(index: int) -> void:
	_line_index = index
	var lines: Array = _conv.get("lines", [])
	var line: Dictionary = lines[index]
	var speaker: SidewalkNeighbor = _neighbor_a if str(line.get("speaker", "a")) == "a" else _neighbor_b
	var other: SidewalkNeighbor = _neighbor_b if speaker == _neighbor_a else _neighbor_a
	var argument: bool = bool(_conv.get("argument", false))
	_neighbor_a.face_toward(_neighbor_b.global_position)
	_neighbor_b.face_toward(_neighbor_a.global_position)
	other.stop_speaking()
	speaker.speak(str(line.get("text", "")), argument)
	_neighbor_a.set_waving(argument)
	_neighbor_b.set_waving(argument)
	_state = State.CHAT_LINE
	_state_time = 0.0


func _end_line() -> void:
	_neighbor_a.stop_speaking()
	_neighbor_b.stop_speaking()
	var lines: Array = _conv.get("lines", [])
	if _line_index >= lines.size() - 1:
		_start_part()
	else:
		_state = State.CHAT_GAP
		_state_time = 0.0


func _start_part() -> void:
	_neighbor_a.clear_face_target()
	_neighbor_b.clear_face_target()
	_neighbor_a.walk_to(_end_a)
	_neighbor_b.walk_to(_end_b)
	_state = State.PART
	_state_time = 0.0


func _interrupt() -> void:
	_interrupted_line = _line_index
	_neighbor_a.stop_speaking()
	_neighbor_b.stop_speaking()
	_neighbor_a.face_toward(_player.global_position)
	_neighbor_b.face_toward(_player.global_position)
	_resume_timer = 0.0
	_state = State.INTERRUPTED
	_state_time = 0.0


func _player_close() -> bool:
	return _player.global_position.distance_to(_neighbor_a.global_position) < INTERRUPT_DIST or _player.global_position.distance_to(_neighbor_b.global_position) < INTERRUPT_DIST


func _player_far() -> bool:
	return _player.global_position.distance_to(_neighbor_a.global_position) > LEAVE_DIST and _player.global_position.distance_to(_neighbor_b.global_position) > LEAVE_DIST


func _arrived(neighbor: SidewalkNeighbor, target: Vector3) -> bool:
	return neighbor.global_position.distance_to(target) < 0.3
