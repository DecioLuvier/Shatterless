extends Node3D

const SPEED := 45.0
const DAMAGE := 1
const LIFETIME_TICKS := 90

var direction := Vector3.FORWARD

var _ticks_alive := 0
var _dead := false


func launch(dir: Vector3) -> void:
	direction = dir.normalized()


func _rollback_tick(delta: float, _tick: int, _is_fresh: bool) -> void:
	if _dead:
		return

	var from := global_position
	var to := from + direction * SPEED * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := space.intersect_ray(query)

	global_position = to
	_ticks_alive += 1

	if not result.is_empty():
		var body: Object = result.collider
		if not (body is Node and (body as Node).is_in_group("player")):
			if body.has_method("take_damage"):
				body.take_damage(DAMAGE)
			_die()
			return

	if _ticks_alive >= LIFETIME_TICKS:
		_die()


func _die() -> void:
	_dead = true
	queue_free()
