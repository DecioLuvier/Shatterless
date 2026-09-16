extends Node
class_name PlayerInput

const MOUSE_SENS := 0.0025
const PITCH_LIMIT := deg_to_rad(85.0)

var movement := Vector2.ZERO
var jump_pressed := false
var fire_pressed := false
var reload_pressed := false

var yaw := 0.0
var pitch := 0.0


func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -PITCH_LIMIT, PITCH_LIMIT)


func _gather() -> void:
	if not is_multiplayer_authority():
		return
	movement = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	jump_pressed = Input.is_action_pressed("jump")
	fire_pressed = Input.is_action_pressed("fire")
	reload_pressed = Input.is_action_pressed("reload")
