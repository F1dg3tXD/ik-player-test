extends Node

signal remote_profile_received(peer_id: int, player_name: String, icon_png_base64: String)
signal session_created(room_code: String)
signal session_joined(room_code: String)
signal session_ended()
signal error_raised(message: String)

const PLAYER = preload("res://player.tscn")
const TUBE_CONTEXT = preload("res://globals/TubeContext.tres")

var tube_client: Node = null
var tube_enabled := true

var PORT := 9999
var IP_ADDRESS := '127.0.0.1'

var active_room_code := ""
var _local_peer_id := 1
var _is_host := false

var _pending_profile_sync: Dictionary = {}
var _signals_connected := false

func _ready() -> void:
	if tube_enabled:
		_create_tube_client()

func _exit_tree() -> void:
	_cleanup_tube_client()

func _cleanup_tube_client() -> void:
	if tube_client and is_instance_valid(tube_client):
		if tube_client.has_method("leave_session"):
			tube_client.call("leave_session")
		if tube_client.has_method("destroy"):
			tube_client.call("destroy")
		tube_client.queue_free()
	tube_client = null

func _create_tube_client() -> void:
	if tube_client and is_instance_valid(tube_client):
		return
	
	var TubeClientScript = load("res://addons/tube/tube_client.gd")
	if TubeClientScript:
		tube_client = TubeClientScript.new()
	else:
		push_error("TubeClient script not found")
		return
	
	tube_client.context = TUBE_CONTEXT
	tube_client.set("multiplayer_root_node", get_tree().root)
	get_tree().root.add_child.call_deferred(tube_client)
	
	if tube_client.has_signal("session_created"):
		tube_client.connect("session_created", Callable(self, "_on_session_created"))
	if tube_client.has_signal("session_joined"):
		tube_client.connect("session_joined", Callable(self, "_on_session_joined"))
	if tube_client.has_signal("error_raised"):
		tube_client.connect("error_raised", Callable(self, "_on_tube_error"))

func _ensure_multiplayer_signals() -> void:
	if _signals_connected:
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	_signals_connected = true

func create_session(as_host: bool = true) -> Error:
	_is_host = as_host
	_ensure_multiplayer_signals()
	
	_create_tube_client()
	if tube_client.has_method("create_session"):
		tube_client.call("create_session")
	else:
		push_error("TubeClient missing create_session()")
		return ERR_UNAVAILABLE
	
	return OK

func join_session(session_id: String) -> Error:
	_is_host = false
	active_room_code = session_id
	_ensure_multiplayer_signals()
	
	_create_tube_client()
	if tube_client.has_method("join_session"):
		tube_client.call("join_session", session_id)
	else:
		push_error("TubeClient missing join_session()")
		return ERR_UNAVAILABLE
	
	return OK

func start_server() -> void:
	var enet_peer := ENetMultiplayerPeer.new()
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	_ensure_multiplayer_signals()
	_is_host = true

func join_server() -> void:
	var enet_peer := ENetMultiplayerPeer.new()
	enet_peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = enet_peer
	_ensure_multiplayer_signals()
	_is_host = false

func _on_session_created() -> void:
	active_room_code = str(tube_client.get("session_id"))
	_local_peer_id = 1
	_is_host = true
	print("Session created: ", active_room_code)
	emit_signal("session_created", active_room_code)
	add_local_player()

func _on_session_joined() -> void:
	active_room_code = str(tube_client.get("session_id"))
	print("Session joined: ", active_room_code)
	emit_signal("session_joined", active_room_code)

func _on_tube_error(code: int, message: String) -> void:
	push_error("Tube error ", code, ": ", message)
	emit_signal("error_raised", message)

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	_spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	_despawn_player(id)

func _on_connected_to_server() -> void:
	_local_peer_id = multiplayer.get_unique_id()
	print("Connected to server as peer: ", _local_peer_id)
	_spawn_player(_local_peer_id)
	send_local_profile.rpc(ProfileManager.username)

func add_local_player() -> void:
	_local_peer_id = 1
	_spawn_player(_local_peer_id)
	send_local_profile.rpc(ProfileManager.username)

func _spawn_player(peer_id: int) -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main == null:
		push_error("Main node not found")
		return
	
	var players_parent = main.get_node_or_null("World/Players")
	if players_parent == null:
		push_error("World/Players not found in scene")
		return
	
	if players_parent.has_node(str(peer_id)):
		return
	
	var spawn_points = main.get_node_or_null("World/LobbyMap/spawnPoints")
	var spawn_pos := Vector3(0, 1, 0)
	
	if spawn_points and spawn_points.is_inside_tree():
		var spawn_markers = []
		for child in spawn_points.get_children():
			if child.is_in_group("PlayerSpawn"):
				spawn_markers.append(child)
		if not spawn_markers.is_empty():
			var idx = players_parent.get_child_count() % spawn_markers.size()
			spawn_pos = spawn_markers[idx].global_position
	
	var new_player = PLAYER.instantiate()
	new_player.name = str(peer_id)
	new_player.position = spawn_pos
	players_parent.add_child(new_player, true)
	new_player.set_multiplayer_authority(peer_id)
	print("Spawned player: ", peer_id, " at ", spawn_pos)

func _despawn_player(peer_id: int) -> void:
	var main = get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	
	var players_parent = main.get_node_or_null("World/Players")
	if players_parent == null:
		return
	
	var player_node = players_parent.get_node_or_null(str(peer_id))
	if player_node:
		player_node.queue_free()

@rpc("any_peer", "call_remote")
func send_local_profile(player_name: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	var path = "Main/World/Players/" + str(sender_id)
	var player_node = get_tree().root.get_node_or_null(path)
	if player_node and player_node.has_method("apply_remote_profile"):
		player_node.apply_remote_profile(player_name, "")
	_apply_remote_profile_for_pending(sender_id)

@rpc("authority", "call_local")
func broadcast_profile(player_name: String) -> void:
	send_local_profile.rpc(player_name)

func _apply_remote_profile_for_pending(peer_id: int) -> void:
	if not _pending_profile_sync.has(peer_id):
		return
	
	var main = get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	
	var players_parent = main.get_node_or_null("World/Players")
	if players_parent == null:
		return
	
	var player_node = players_parent.get_node_or_null(str(peer_id))
	if player_node == null:
		return
	
	if not player_node.has_method("apply_remote_profile"):
		return
	
	var profile = _pending_profile_sync[peer_id]
	player_node.apply_remote_profile(
		str(profile.get("player_name", "Player")),
		str(profile.get("icon_png_base64", ""))
	)
	_pending_profile_sync.erase(peer_id)

@rpc("any_peer", "call_local")
func receive_player_profile(peer_id: int, player_name: String, icon_png_base64: String) -> void:
	emit_signal("remote_profile_received", peer_id, player_name, icon_png_base64)
	
	if get_tree().current_scene == null:
		_pending_profile_sync[peer_id] = {
			"player_name": player_name,
			"icon_png_base64": icon_png_base64
		}
		_apply_remote_profile_for_pending(peer_id)
		return
	
	_apply_remote_profile_for_pending(peer_id)

func leave_session() -> void:
	if tube_enabled and tube_client and tube_client.has_method("leave_session"):
		tube_client.call("leave_session")
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	multiplayer.peer_connected.disconnect(_on_peer_connected)
	multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	
	active_room_code = ""
	_local_peer_id = 0
	
	emit_signal("session_ended")

func is_host() -> bool:
	return _is_host

func get_local_peer_id() -> int:
	return _local_peer_id if _local_peer_id > 0 else multiplayer.get_unique_id()
