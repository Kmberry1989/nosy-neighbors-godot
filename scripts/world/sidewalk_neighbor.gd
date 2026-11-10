class_name SidewalkNeighbor
extends Node3D
## One strolling neighbor for the sidewalk-chats prototype.
##
## Driven by the SidewalkChats director: walk_to() a point, speak() a line,
## face_toward() a point. The coin-head avatar faces +Z (eyes sit at +Z),
## so facing uses rotation.y = atan2(dir.x, dir.z).

const WALK_SPEED := 1.6
const ARRIVE_DIST := 0.12
const TURN_SPEED := 6.0

@onready var _avatar: Node3D = $SSSAvatar
@onready var _anim: AnimationPlayer = $SSSAvatar/AnimationPlayer
@onready var _name_label: Label3D = $NameLabel3D
@onready var _bubble: Label3D = $ChatBubble
@onready var _hand_l: MeshInstance3D = $SSSAvatar/HandL
@onready var _hand_r: MeshInstance3D = $SSSAvatar/HandR

var personality_id := ""
var personality_title := "Neighbor"

var _walking := false
var _walk_target := Vector3.ZERO
var _face_target := Vector3.INF
var _waving := false
var _wave_time := 0.0
var _hand_l_base := Vector3(-0.52, 1.0, 0.0)
var _hand_r_base := Vector3(0.52, 1.0, 0.0)


func _ready() -> void:
	_bubble.visible = false
	_play_anim(&"male_animation_lib/idle")


func _process(delta: float) -> void:
	if _walking:
		var to_target: Vector3 = _walk_target - global_position
		to_target.y = 0.0
		var dist := to_target.length()
		if dist <= ARRIVE_DIST:
			_walking = false
			_play_anim(&"male_animation_lib/idle")
		else:
			var step: Vector3 = to_target.normalized() * WALK_SPEED * delta
			if step.length() > dist:
				step = to_target
			global_position += step
			_face_yaw(atan2(to_target.x, to_target.z), delta)
	if _face_target != Vector3.INF:
		var to_face: Vector3 = _face_target - global_position
		to_face.y = 0.0
		if to_face.length() > 0.05:
			_face_yaw(atan2(to_face.x, to_face.z), delta)
	_update_hands(delta)


func setup(personality: Dictionary) -> void:
	personality_id = str(personality.get("id", ""))
	personality_title = str(personality.get("title", "Neighbor"))
	_name_label.text = personality_title
	var tunic: Array = personality.get("tunic", [0.16, 0.55, 0.6])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(float(tunic[0]), float(tunic[1]), float(tunic[2]), 1.0)
	mat.roughness = 0.85
	var body: MeshInstance3D = $SSSAvatar/Body
	body.set_surface_override_material(0, mat)


func walk_to(target: Vector3) -> void:
	_walk_target = target
	_walking = true
	_play_anim(&"male_animation_lib/walk")


func stop_walking() -> void:
	_walking = false
	_play_anim(&"male_animation_lib/idle")


func face_toward(point: Vector3) -> void:
	_face_target = point


func clear_face_target() -> void:
	_face_target = Vector3.INF


func speak(text: String, argument: bool) -> void:
	_bubble.text = text
	if argument:
		_bubble.modulate = Color(0.95, 0.12, 0.12, 1.0)
		_bubble.outline_modulate = Color(0.45, 0.0, 0.0, 1.0)
		_bubble.outline_size = 18
	else:
		_bubble.modulate = Color(1.0, 0.98, 0.92, 1.0)
		_bubble.outline_modulate = Color(0.1, 0.1, 0.15, 1.0)
		_bubble.outline_size = 12
	_bubble.visible = true


func stop_speaking() -> void:
	_bubble.visible = false
	set_waving(false)


func set_waving(waving: bool) -> void:
	_waving = waving


func _face_yaw(target_yaw: float, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _update_hands(delta: float) -> void:
	var target_l := _hand_l_base
	var target_r := _hand_r_base
	if _waving:
		_wave_time += delta
		var swing := sin(_wave_time * 9.0)
		target_l = Vector3(-0.62 - 0.12 * swing, 1.52 + 0.08 * swing, 0.12)
		target_r = Vector3(0.62 + 0.12 * swing, 1.52 - 0.08 * swing, 0.12)
	else:
		_wave_time = 0.0
	var blend := clampf(10.0 * delta, 0.0, 1.0)
	_hand_l.position = _hand_l.position.lerp(target_l, blend)
	_hand_r.position = _hand_r.position.lerp(target_r, blend)


func _play_anim(anim_name: StringName) -> void:
	if _anim != null and _anim.has_animation(anim_name):
		_anim.play(anim_name)
