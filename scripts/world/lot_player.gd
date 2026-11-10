class_name LotPlayer
extends CharacterBody3D
## Standalone local player for the sidewalk-chats prototype scene.
##
## Plain WASD + mouse look + jump. Deliberately NOT the networked player:
## this scene runs offline with no rollback, no spawner, no lobby.
## Mouse only for now — touch look is a later step if the prototype goes
## to a phone. Click to capture the mouse, Esc to release it.

const SPEED := 5.0
const JUMP_VELOCITY := 4.5
const MOUSE_SPEED := 0.0022
const PITCH_MIN := deg_to_rad(-60.0)
const PITCH_MAX := deg_to_rad(50.0)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _camera_mount: Node3D = $CameraMount
@onready var _camera_rot: Node3D = $CameraMount/CameraRot
@onready var _camera: Camera3D = $CameraMount/CameraRot/Camera3D
@onready var _avatar: Node3D = $SSSAvatar
@onready var _anim: AnimationPlayer = $SSSAvatar/AnimationPlayer


func _ready() -> void:
	_camera.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_play_anim(&"male_animation_lib/idle")


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_camera_mount.rotate_y(-event.relative.x * MOUSE_SPEED)
		_camera_mount.orthonormalize()
		_camera_rot.rotation.x = clampf(_camera_rot.rotation.x - event.relative.y * MOUSE_SPEED, PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("in-game-menu"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var basis_yaw: Basis = _camera_mount.global_transform.basis
	var direction: Vector3 = (basis_yaw * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	direction.y = 0.0
	if direction.length() > 0.01:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		_avatar.rotation.y = lerp_angle(_avatar.rotation.y, atan2(direction.x, direction.z), clampf(12.0 * delta, 0.0, 1.0))
		_play_anim(&"male_animation_lib/walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_anim(&"male_animation_lib/idle")
	move_and_slide()


func _play_anim(anim_name: StringName) -> void:
	if _anim != null and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name)
