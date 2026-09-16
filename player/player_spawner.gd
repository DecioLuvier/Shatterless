extends Node
class_name PlayerSpawner
## Spawns one Player avatar per connected peer. Falls back to a single local
## avatar when no network session is running, so the arena still works
## standalone (F5 in the editor, no host/join).

@export var player_scene: PackedScene
@export var spawn_root: Node
@export var spawn_point := Vector3(0.0, 1.1, 6.0)

var _avatars: Dictionary = {}


func _ready() -> void:
	NetworkEvents.on_client_start.connect(_handle_connected)
	NetworkEvents.on_server_start.connect(_handle_host)
	NetworkEvents.on_peer_join.connect(_handle_new_peer)
	NetworkEvents.on_peer_leave.connect(_handle_leave)
	NetworkEvents.on_client_stop.connect(_handle_stop)
	NetworkEvents.on_server_stop.connect(_handle_stop)

	var peer := get_tree().get_multiplayer().multiplayer_peer
	var has_menu := get_tree().get_root().find_child("NetworkMenu", true, false) != null
	if (peer == null or peer is OfflineMultiplayerPeer) and not has_menu:
		# No real multiplayer session and no menu waiting to host/join: start
		# the simulation clock ourselves so the arena still ticks standalone
		# (F5 in the editor, no host/join). When a NetworkMenu is present,
		# let it drive the session; NetworkEvents starts NetworkTime once
		# on_server_start/on_client_start fires, avoiding a double start.
		NetworkTime.start()
		_spawn(1)


func _handle_connected(_id: int) -> void:
	_spawn(multiplayer.get_unique_id())


func _handle_host() -> void:
	_spawn(1)


func _handle_new_peer(id: int) -> void:
	_spawn(id)


func _handle_leave(id: int) -> void:
	if not _avatars.has(id):
		return
	(_avatars[id] as Node).queue_free()
	_avatars.erase(id)


func _handle_stop() -> void:
	for avatar in _avatars.values():
		(avatar as Node).queue_free()
	_avatars.clear()
	_spawn(1)


func _spawn(id: int) -> void:
	if _avatars.has(id):
		return
	var avatar := player_scene.instantiate()
	_avatars[id] = avatar
	avatar.name += " #%d" % id
	spawn_root.add_child.call_deferred(avatar)
	await avatar.ready
	# Offset each peer's spawn so avatars don't stack on the same point —
	# lets both cylinders be seen apart on screen/in screenshots.
	var slot := _avatars.keys().find(id)
	avatar.global_position = spawn_point + Vector3(slot * 3.0, 0.0, 0.0)

	# State is server-authoritative; input belongs to the owning peer.
	avatar.set_multiplayer_authority(1)
	var input := avatar.find_child("Input")
	if input != null:
		input.set_multiplayer_authority(id)

	avatar.set_local_view(id == multiplayer.get_unique_id())
