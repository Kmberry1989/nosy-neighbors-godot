class_name SSSAvatar
extends Node3D
## Selfie Social Society avatar: a flat coin-disc head floating over a
## flat-bottomed body, spherical hands with thumbs, and wedge feet.
##
## The head bob / foot plop / squash animations are built at runtime into an
## AnimationLibrary named "male_animation_lib" so the existing Netfox
## RewindableStateMachine states (idle / walk / jump) keep working unchanged.
## Animation track paths resolve against the AnimationPlayer's root_node,
## which defaults to its parent (this avatar root).

const LIB_NAME := &"male_animation_lib"

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_build_animation_library()


func _build_animation_library() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _make_idle())
	lib.add_animation(&"walk", _make_walk())
	lib.add_animation(&"jump", _make_jump())
	_anim.add_animation_library(LIB_NAME, lib)


func _track(anim: Animation, path: String) -> int:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, path)
	return t


func _make_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	# Hover bob on the coin head.
	var bob := _track(a, "HeadPivot:position:y")
	a.track_insert_key(bob, 0.0, 1.5)
	a.track_insert_key(bob, 1.0, 1.58)
	a.track_insert_key(bob, 2.0, 1.5)
	# Gentle body sway.
	var sway := _track(a, "Body:rotation:z")
	a.track_insert_key(sway, 0.0, 0.0)
	a.track_insert_key(sway, 1.0, 0.03)
	a.track_insert_key(sway, 2.0, 0.0)
	return a


func _make_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	# Feet plop, alternating.
	var fl := _track(a, "FootL:position:y")
	a.track_insert_key(fl, 0.0, 0.11)
	a.track_insert_key(fl, 0.15, 0.30)
	a.track_insert_key(fl, 0.30, 0.11)
	a.track_insert_key(fl, 0.45, 0.30)
	a.track_insert_key(fl, 0.60, 0.11)
	var fr := _track(a, "FootR:position:y")
	a.track_insert_key(fr, 0.0, 0.11)
	a.track_insert_key(fr, 0.15, 0.11)
	a.track_insert_key(fr, 0.30, 0.30)
	a.track_insert_key(fr, 0.45, 0.11)
	a.track_insert_key(fr, 0.60, 0.11)
	# Body rock.
	var rock := _track(a, "Body:rotation:z")
	a.track_insert_key(rock, 0.0, 0.05)
	a.track_insert_key(rock, 0.3, -0.05)
	a.track_insert_key(rock, 0.6, 0.05)
	# Head counter-bob.
	var bob := _track(a, "HeadPivot:position:y")
	a.track_insert_key(bob, 0.0, 1.50)
	a.track_insert_key(bob, 0.3, 1.56)
	a.track_insert_key(bob, 0.6, 1.50)
	return a


func _make_jump() -> Animation:
	var a := Animation.new()
	a.length = 0.5
	# Squash and stretch on the body.
	var stretch := _track(a, "Body:scale:y")
	a.track_insert_key(stretch, 0.0, 1.0)
	a.track_insert_key(stretch, 0.2, 1.15)
	a.track_insert_key(stretch, 0.5, 1.0)
	# Head lifts with the jump.
	var lift := _track(a, "HeadPivot:position:y")
	a.track_insert_key(lift, 0.0, 1.50)
	a.track_insert_key(lift, 0.2, 1.68)
	a.track_insert_key(lift, 0.5, 1.50)
	return a
