extends Node
class_name PlayerInput
## Input property node for the player's RollbackSynchronizer. Gathered once
## per network tick on the owning peer only; read back inside
## Player._rollback_tick on every peer (fresh or replayed).

var movement := Vector2.ZERO
var jump_pressed := false


func _ready() -> void:
	NetworkTime.before_tick_loop.connect(_gather)


func _gather() -> void:
	if not is_multiplayer_authority():
		return
	# Gathered once per network tick (30/s) but real input events land on
	# render frames (commonly 60+/s), so `is_action_just_pressed` here would
	# silently miss presses that don't happen to land on a tick-sampling
	# frame. Sample the held state instead (netfox's own recommended
	# pattern) and let the simulation side edge-detect deterministically
	# from recorded/replayed ticks.
	movement = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	jump_pressed = Input.is_action_pressed("jump")
