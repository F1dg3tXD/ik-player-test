extends Node

enum PeerMode { NONE, WEBRTC }
signal remote_profile_received(peer_id: int, player_name: String, icon_png_base64: String)
signal tube_session_created(room_code: String)
signal tube_session_joined(room_code: String)
signal tube_error(message: String)

const DEFAULT_SIGNALING_URL := "ws://127.0.0.1:9080"
const DEFAULT_ROOM_CODE := "DEFAULT"
const ROOM_CODE_LENGTH := 6
const HOST_PEER_ID := 1

var peer_mode: PeerMode = PeerMode.NONE
var peer: MultiplayerPeer

var _is_host := false
var _room_code := ""
var _local_peer_id := 0
var _tube_client: Node = null
var _tube_connected := false
var _pending_tube_action := ""

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)

func close_connection() -> void:
	if _tube_client and _tube_client.has_method("leave_session"):
		_tube_client.call("leave_session")
	multiplayer.multiplayer_peer = null
	peer = null
	peer_mode = PeerMode.NONE
	_room_code = ""
	_local_peer_id = 0
	_tube_connected = false

func start_webrtc_host(room_code: String, _signaling_url: String = DEFAULT_SIGNALING_URL) -> Error:
	close_connection()
	_is_host = true
	_room_code = _resolve_room_code(room_code, true)

	if not _ensure_tube_client():
		return ERR_UNAVAILABLE
	if not _tube_client.has_method("create_session"):
		push_error("TubeClient is missing create_session().")
		return ERR_UNAVAILABLE

	_pending_tube_action = "create"
	_tube_client.call("create_session")
	var created_payload: Array = await tube_session_created
	_pending_tube_action = ""
	if created_payload.is_empty():
		return FAILED

	_room_code = str(created_payload[0])
	_local_peer_id = multiplayer.get_unique_id()
	peer = multiplayer.multiplayer_peer
	peer_mode = PeerMode.WEBRTC
	return OK

func start_webrtc_client(room_code: String, _signaling_url: String = DEFAULT_SIGNALING_URL) -> Error:
	close_connection()
	_is_host = false
	_room_code = _resolve_room_code(room_code, false)
	if _room_code == DEFAULT_ROOM_CODE:
		push_error("A valid Tube session ID is required to join.")
		return ERR_INVALID_PARAMETER

	if not _ensure_tube_client():
		return ERR_UNAVAILABLE
	if not _tube_client.has_method("join_session"):
		push_error("TubeClient is missing join_session().")
		return ERR_UNAVAILABLE

	_pending_tube_action = "join"
	_tube_client.call("join_session", _room_code)
	var joined_payload: Array = await tube_session_joined
	_pending_tube_action = ""
	if joined_payload.is_empty():
		return FAILED

	_room_code = str(joined_payload[0])
	_local_peer_id = multiplayer.get_unique_id()
	peer = multiplayer.multiplayer_peer
	peer_mode = PeerMode.WEBRTC
	return OK

func generate_room_code() -> String:
	# Tube generates session IDs internally when hosting.
	return ""

func get_active_room_code() -> String:
	return _room_code

func _normalize_room_code(room_code: String) -> String:
	return room_code.strip_edges()

func _resolve_room_code(input_room_code: String, is_host: bool) -> String:
	var normalized := _normalize_room_code(input_room_code)
	if not normalized.is_empty():
		return normalized
	if is_host:
		return ""
	return DEFAULT_ROOM_CODE


func get_local_peer_id() -> int:
	if _local_peer_id > 0:
		return _local_peer_id
	return multiplayer.get_unique_id()

func _ensure_tube_client() -> bool:
	if _tube_client and is_instance_valid(_tube_client):
		return true

	var scene_client := _find_existing_tube_client()
	if scene_client != null:
		_tube_client = scene_client
		_connect_tube_signals()
		_load_default_tube_context()
		return true

	if not ClassDB.class_exists("TubeClient"):
		push_error("TubeClient node not found in scene tree and Tube class is unavailable. Ensure the Tube plugin is enabled and a TubeClient node exists in the active scene.")
		return false

	_tube_client = ClassDB.instantiate("TubeClient")
	if _tube_client == null:
		push_error("Failed to instantiate TubeClient.")
		return false

	_tube_client.name = "TubeClient"
	add_child(_tube_client)
	_connect_tube_signals()
	_load_default_tube_context()
	return true

func _find_existing_tube_client() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var root := tree.root
	if root == null:
		return null

	var named_client := root.find_child("TubeClient", true, false)
	if _is_tube_client_node(named_client):
		return named_client

	return _find_tube_client_recursive(root)

func _find_tube_client_recursive(node: Node) -> Node:
	for child in node.get_children():
		if not (child is Node):
			continue
		var child_node := child as Node
		if _is_tube_client_node(child_node):
			return child_node
		var nested := _find_tube_client_recursive(child_node)
		if nested != null:
			return nested
	return null

func _is_tube_client_node(node: Node) -> bool:
	if node == null:
		return false
	if not node.has_method("create_session"):
		return false
	if not node.has_method("join_session"):
		return false
	if not node.has_method("leave_session"):
		return false
	return node.has_signal("session_created") and node.has_signal("session_joined")

func _connect_tube_signals() -> void:
	if _tube_connected or _tube_client == null:
		return
	if _tube_client.has_signal("session_created"):
		_tube_client.connect("session_created", Callable(self, "_on_tube_session_created"))
	if _tube_client.has_signal("session_joined"):
		_tube_client.connect("session_joined", Callable(self, "_on_tube_session_joined"))
	if _tube_client.has_signal("error_raised"):
		_tube_client.connect("error_raised", Callable(self, "_on_tube_error_raised"))
	_tube_connected = true

func _load_default_tube_context() -> void:
	if _tube_client == null:
		return
	if _tube_client.get("context") != null:
		return
	var context_paths := [
		"res://globals/TubeContext.tres",
		"res://tube_context.tres",
		"res://addons/tube/tube_context.tres"
	]
	for context_path in context_paths:
		if ResourceLoader.exists(context_path):
			var context_resource := load(context_path)
			if context_resource != null:
				_tube_client.set("context", context_resource)
				return
	push_warning("Tube context resource not found. Create a TubeContext resource and assign it to NetworkManager's TubeClient.")

func _on_tube_session_created() -> void:
	_room_code = str(_tube_client.get("session_id"))
	emit_signal("tube_session_created", _room_code)

func _on_tube_session_joined() -> void:
	var joined_id := str(_tube_client.get("session_id"))
	if not joined_id.is_empty():
		_room_code = joined_id
	emit_signal("tube_session_joined", _room_code)

func _on_tube_error_raised(code: int, message: String) -> void:
	push_error("Tube error %s: %s" % [code, message])
	emit_signal("tube_error", "%s: %s" % [code, message])
	if _pending_tube_action == "create":
		emit_signal("tube_session_created", "")
	elif _pending_tube_action == "join":
		emit_signal("tube_session_joined", "")

func _on_connected_to_server() -> void:
	_local_peer_id = multiplayer.get_unique_id()

func _on_peer_connected(_id: int) -> void:
	_local_peer_id = multiplayer.get_unique_id()
