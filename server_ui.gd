extends Node2D

@onready var server_list_v_box_container: VBoxContainer = $Control/Menu/ServerListVBoxContainer
@onready var server_button_instance: Button = $Control/Menu/ServerListVBoxContainer/ServerButtonInstance
@onready var player_list_v_box_container: VBoxContainer = %PlayerListVBoxContainer
@onready var player_info_h_box_container: HBoxContainer = %PlayerInfoHBoxContainer

var _refresh_interval_sec := 1.0
var _refresh_accumulator := 0.0

func _ready() -> void:
	server_button_instance.visible = false
	player_info_h_box_container.visible = false

	if Lobby != null:
		Lobby.lobby_created.connect(_on_lobby_changed)
		Lobby.lobby_joined.connect(_on_lobby_changed)

	multiplayer.peer_connected.connect(_on_peer_changed)
	multiplayer.peer_disconnected.connect(_on_peer_changed)

	_refresh_all()

func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < _refresh_interval_sec:
		return
	_refresh_accumulator = 0.0
	_refresh_all()

func _on_lobby_changed(_room_code: String) -> void:
	_refresh_all()

func _on_peer_changed(_peer_id: int) -> void:
	_refresh_all()

func _refresh_all() -> void:
	_refresh_server_list()
	_refresh_player_list()

func _refresh_server_list() -> void:
	_clear_dynamic_children(server_list_v_box_container, server_button_instance)

	var room_code := Lobby.active_room_code if Lobby != null else ""
	if room_code.is_empty():
		room_code = "(starting...)"

	var connected_peers := multiplayer.get_peers()
	var player_count := connected_peers.size() + (1 if multiplayer.is_server() else 0)

	var row := server_button_instance.duplicate() as Button
	row.visible = true
	row.disabled = true
	row.text = "Room: %s | Players: %s" % [room_code, player_count]
	row.tooltip_text = "Dedicated server room status"
	server_list_v_box_container.add_child(row)

func _refresh_player_list() -> void:
	_clear_dynamic_children(player_list_v_box_container, player_info_h_box_container)

	if multiplayer.is_server():
		_add_player_row(1, true)

	for peer_id in multiplayer.get_peers():
		_add_player_row(peer_id, false)

func _add_player_row(peer_id: int, is_host: bool) -> void:
	var row := player_info_h_box_container.duplicate() as HBoxContainer
	row.visible = true

	var player_name := row.get_node_or_null("player_name") as Label
	if player_name:
		player_name.text = "Peer %s%s" % [peer_id, " (Host)" if is_host else ""]

	var player_ping := row.get_node_or_null("player_ping") as Label
	if player_ping:
		player_ping.text = "Ping: n/a"

	player_list_v_box_container.add_child(row)

func _clear_dynamic_children(container: Node, template_node: Node) -> void:
	for child in container.get_children():
		if child == template_node:
			continue
		child.queue_free()
