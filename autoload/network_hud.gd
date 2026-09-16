extends Control

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.position = Vector2(8, 8)
	add_child(_label)

	set_process(true)


func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	var ping_text := "--"

	var peer := get_tree().get_multiplayer().multiplayer_peer
	var connected := peer != null and not (peer is OfflineMultiplayerPeer) \
			and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	if connected and not multiplayer.is_server():
		ping_text = "%d ms" % roundi(NetworkTimeSynchronizer.rtt * 1000.0)

	_label.text = "FPS: %d\nPing: %s" % [fps, ping_text]
