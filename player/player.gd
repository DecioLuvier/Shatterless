extends CharacterBody3D
## Minimal networked cylinder: WASD move, mouse look, space jump. No weapon,
## no HUD — reduced scope for netfox sync verification (see TDD determinism
## rules). Movement runs on the rollback tick only.

const SPEED := 6.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENS := 0.0025
const PITCH_LIMIT := deg_to_rad(85.0)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _prev_jump_held := false

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _input: PlayerInput = $Input

## Whether this avatar is the one running on THIS machine (camera, mouse
## capture). Set by the spawner for remote avatars; defaults to true so the
## scene still works standalone (no spawner, single static instance).
var _is_local_view := true


func set_local_view(is_local: bool) -> void:
	_is_local_view = is_local
	_camera.current = is_local
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	add_to_group("player")
	_camera.current = _is_local_view
	if _is_local_view:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_view:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_head.rotate_x(-event.relative.y * MOUSE_SENS)
		_head.rotation.x = clampf(_head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


## Networked simulation: movement only. Runs on every rollback tick, on every
## peer, from the recorded/replayed input in `_input` — never from `Input`
## directly.
func _rollback_tick(delta: float, _tick: int, _is_fresh: bool) -> void:
	var jump_edge := _input.jump_pressed and not _prev_jump_held
	_prev_jump_held = _input.jump_pressed

	if not is_on_floor():
		velocity.y -= _gravity * delta
	if jump_edge and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var dir := (transform.basis * Vector3(_input.movement.x, 0.0, _input.movement.y)).normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED

	# move_and_slide() assumes a physics-process delta; NetworkTime's tick
	# delta differs, so scale velocity by physics_factor around the call.
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
