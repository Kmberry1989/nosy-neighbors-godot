class_name PlayerInput extends Node

var input_dir : Vector2 = Vector2.ZERO
var jump_input := false
var run_input := false
var buzzer_input := false

# When true (game-show mode), movement/jump/run are zeroed but the buzzer
# still works — contestants stay at their podiums.
var movement_locked := false

var _buzz_was_down := false
var _buzz_latched := false

func _ready():
	NetworkTime.before_tick_loop.connect(_gather)

func _gather():
	# In this case, should be client authority
	if is_multiplayer_authority():
		if movement_locked:
			input_dir = Vector2.ZERO
			jump_input = false
			run_input = false
		else:
			input_dir = Input.get_vector("left", "right", "forward", "backward")
			jump_input = Input.is_action_pressed("jump")
			run_input = Input.is_action_pressed("run")
		_gather_buzzer()

func _gather_buzzer():
	var gs := get_tree().get_first_node_in_group("gameshow")
	var buzz_open := false
	if gs != null:
		buzz_open = gs.get("buzz_window_open")
	var buzz_down := Input.is_action_pressed("buzz")
	var fresh := buzz_down and not _buzz_was_down
	_buzz_was_down = buzz_down
	if buzz_open:
		# Latch the press so a quick tap always covers at least one tick,
		# and presses that start before the window opens never count.
		if fresh:
			_buzz_latched = true
		buzzer_input = _buzz_latched
	else:
		_buzz_latched = false
		buzzer_input = false

func _exit_tree():
	NetworkTime.before_tick_loop.disconnect(_gather)
