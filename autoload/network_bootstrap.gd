extends Node

signal connect_failed(reason: String)

const CONNECT_TIMEOUT := 10.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--net-host="):
			var port := arg.substr("--net-host=".length()).to_int()
			call_deferred("host", port)
		elif arg.begins_with("--net-join="):
			var value := arg.substr("--net-join=".length())
			var parts := value.split(":")
			if parts.size() == 2:
				call_deferred("join", parts[0], parts[1].to_int())


func host(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		connect_failed.emit("Failed to listen on port %d: %s" % [port, error_string(err)])
		return err

	get_tree().get_multiplayer().multiplayer_peer = peer
	await _wait_until_connected(peer)

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		connect_failed.emit("Failed to start server on port %d" % port)
		return FAILED

	get_tree().get_multiplayer().server_relay = true
	return OK


func join(address: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		connect_failed.emit("Failed to create client: %s" % error_string(err))
		return err

	get_tree().get_multiplayer().multiplayer_peer = peer
	await _wait_until_connected(peer)

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		get_tree().get_multiplayer().multiplayer_peer = null
		connect_failed.emit("Failed to connect to %s:%d" % [address, port])
		return FAILED

	return OK


func disconnect_network() -> void:
	var mp := get_tree().get_multiplayer()
	if mp.multiplayer_peer != null and not (mp.multiplayer_peer is OfflineMultiplayerPeer):
		mp.multiplayer_peer.close()
		mp.multiplayer_peer = null


func _wait_until_connected(peer: ENetMultiplayerPeer) -> void:
	var deadline := Time.get_ticks_msec() + CONNECT_TIMEOUT * 1000.0
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		await get_tree().process_frame
		if Time.get_ticks_msec() > deadline:
			break
