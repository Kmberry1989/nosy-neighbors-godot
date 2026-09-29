class_name VirtualJoystick
extends Control
## Left-thumb virtual joystick. Drives the "left/right/forward/backward" input
## actions with analog strength so Input.get_vector() just works.

const RADIUS := 80.0
const KNOB_RADIUS := 30.0
const DEADZONE := 0.15

var value := Vector2.ZERO

var _touch_index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_index = event.index
			_update_stick(event.position)
		elif event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_stick(event.position)


func _update_stick(local_pos: Vector2) -> void:
	var d := local_pos - size * 0.5
	if d.length() > RADIUS:
		d = d.normalized() * RADIUS
	value = d / RADIUS
	_apply()
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	value = Vector2.ZERO
	_apply()
	queue_redraw()


func _apply() -> void:
	_set_action(&"left", -value.x)
	_set_action(&"right", value.x)
	_set_action(&"forward", -value.y)
	_set_action(&"backward", value.y)


func _set_action(action: StringName, amount: float) -> void:
	if amount > DEADZONE:
		Input.action_press(action, minf(amount, 1.0))
	else:
		Input.action_release(action)


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.18))
	draw_arc(c, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(c + value * RADIUS, KNOB_RADIUS, Color(1, 1, 1, 0.45))
