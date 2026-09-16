extends CanvasLayer

const DEFAULT_PORT := 8910

@onready var _address_input: LineEdit = %AddressInput
@onready var _port_input: LineEdit = %PortInput
@onready var _status_label: Label = %StatusLabel
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton


func _ready() -> void:
	_port_input.text = str(DEFAULT_PORT)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	NetworkBootstrap.connect_failed.connect(_on_connect_failed)
	NetworkEvents.on_server_start.connect(func(): visible = false)
	NetworkEvents.on_client_start.connect(func(_id): visible = false)
	NetworkEvents.on_server_stop.connect(func(): visible = true)
	NetworkEvents.on_client_stop.connect(func(): visible = true)


func _on_host_pressed() -> void:
	var port := _parse_port()
	if port == -1:
		return
	_set_status("Hosting on port %d..." % port)
	_set_buttons_enabled(false)
	var err := await NetworkBootstrap.host(port)
	_set_buttons_enabled(true)
	if err == OK:
		_set_status("")


func _on_join_pressed() -> void:
	var address := _address_input.text.strip_edges()
	if address.is_empty():
		_set_status("Enter host address")
		return
	var port := _parse_port()
	if port == -1:
		return
	_set_status("Connecting to %s:%d..." % [address, port])
	_set_buttons_enabled(false)
	var err := await NetworkBootstrap.join(address, port)
	_set_buttons_enabled(true)
	if err == OK:
		_set_status("")


func _parse_port() -> int:
	var text := _port_input.text.strip_edges()
	if not text.is_valid_int():
		_set_status("Invalid port")
		return -1
	return text.to_int()


func _on_connect_failed(reason: String) -> void:
	_set_status(reason)


func _set_status(text: String) -> void:
	_status_label.text = text


func _set_buttons_enabled(enabled: bool) -> void:
	_host_button.disabled = not enabled
	_join_button.disabled = not enabled
