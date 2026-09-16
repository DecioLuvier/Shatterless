extends Node
class_name PlayerSpawner

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
		NetworkTime.start()
		_spawn(1)


func _handle_connected(_id: int) -> void:
	_spawn(multiplayer.get_unique_id())
	for id in multiplayer.get_peers():
		_spawn(id)
	if multiplayer.get_unique_id() != 1:
		_spawn(1)


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
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer) \
			and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var avatar := player_scene.instantiate()
	_avatars[id] = avatar
	avatar.name += " #%d" % id

	avatar.set_multiplayer_authority(1)
	var input := avatar.find_child("Input")
	if input != null:
		input.set_multiplayer_authority(id)

	spawn_root.add_child.call_deferred(avatar)
	await avatar.ready

	var slot := _avatars.keys().find(id)
	avatar.global_position = spawn_point + Vector3(slot * 3.0, 0.0, 0.0)

	avatar.set_local_view(id == multiplayer.get_unique_id())
