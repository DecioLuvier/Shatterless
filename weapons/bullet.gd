extends Area3D
## Projectile fired by the player's gun. Travels forward, damages anything
## with take_damage(), and frees itself on any impact or after a timeout.

const SPEED := 45.0
const DAMAGE := 1
const LIFETIME := 3.0

var _direction := Vector3.FORWARD


func _ready() -> void:
	body_entered.connect(_on_hit)
	get_tree().create_timer(LIFETIME).timeout.connect(_safe_free)


func launch(dir: Vector3) -> void:
	_direction = dir.normalized()


func _physics_process(delta: float) -> void:
	global_position += _direction * SPEED * delta


func _on_hit(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	_safe_free()


func _safe_free() -> void:
	if is_instance_valid(self):
		queue_free()
