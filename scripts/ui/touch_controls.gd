extends CanvasLayer
## Mobile touch controls: virtual joystick (left), jump + run (right).
## Hidden automatically on non-touch devices.

@onready var _jump_button: Button = $JumpButton
@onready var _run_button: Button = $RunButton


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	_jump_button.button_down.connect(_on_jump_down)
	_jump_button.button_up.connect(_on_jump_up)
	_run_button.toggled.connect(_on_run_toggled)


func _on_jump_down() -> void:
	Input.action_press(&"jump")


func _on_jump_up() -> void:
	Input.action_release(&"jump")


func _on_run_toggled(on: bool) -> void:
	if on:
		Input.action_press(&"run")
	else:
		Input.action_release(&"run")
