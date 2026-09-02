extends StaticBody3D
## A destructible objective. Takes hits from bullets and is destroyed
## once its health reaches zero.

@export var max_health := 3

var _health := 0

@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_health = max_health


func take_damage(amount: int) -> void:
	_health -= amount
	_flash()
	if _health <= 0:
		_destroy()


func _flash() -> void:
	if _mesh == null:
		return
	var t := create_tween()
	_mesh.scale = Vector3.ONE * 1.15
	t.tween_property(_mesh, "scale", Vector3.ONE, 0.12)


func _destroy() -> void:
	print("[DestructibleTarget] destroyed: ", name)
	queue_free()
