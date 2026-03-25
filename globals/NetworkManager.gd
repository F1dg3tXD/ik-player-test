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
var _pending_result_room_code := ""
var _pending_result_error := ""

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
	_pending_tube_action = ""
	_pending_result_room_code = ""
	_pending_result_error = ""

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
	_pending_result_room_code = ""
	_pending_result_error = ""
	_tube_client.call("create_session")
	var wait_error := await _wait_for_pending_tube_action()
	_pending_tube_action = ""
	if wait_error != OK:
		return wait_error

	_room_code = _pending_result_room_code
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
	_pending_result_room_code = ""
	_pending_result_error = ""
	_tube_client.call("join_session", _room_code)
	var wait_error := await _wait_for_pending_tube_action()
	_pending_tube_action = ""
	if wait_error != OK:
		return wait_error

	_room_code = _pending_result_room_code
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

func _wait_for_pending_tube_action() -> Error:
	while not _pending_tube_action.is_empty():
		if not _pending_result_error.is_empty():
			push_error(_pending_result_error)
			return FAILED
		if not _pending_result_room_code.is_empty():
			return OK
		await get_tree().process_frame
	return FAILED

func get_local_peer_id() -> int:
	if _local_peer_id > 0:
		return _local_peer_id
	return multiplayer.get_unique_id()

func _ensure_tube_client() -> bool:
	if _tube_client and is_instance_valid(_tube_client):
		return true

	if not ClassDB.class_exists("TubeClient"):
		push_error("Tube plugin is not available. Install/enable addons/tube and restart Godot.")
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
	_pending_result_room_code = _room_code
	emit_signal("tube_session_created", _room_code)

func _on_tube_session_joined() -> void:
	var joined_id := str(_tube_client.get("session_id"))
	if not joined_id.is_empty():
		_room_code = joined_id
	_pending_result_room_code = _room_code
	emit_signal("tube_session_joined", _room_code)

func _on_tube_error_raised(code: int, message: String) -> void:
	push_error("Tube error %s: %s" % [code, message])
	_pending_result_error = "Tube error %s: %s" % [code, message]
	emit_signal("tube_error", _pending_result_error)
	if _pending_tube_action == "create":
		_pending_tube_action = ""
		emit_signal("tube_session_created", "")
	elif _pending_tube_action == "join":
		_pending_tube_action = ""
		emit_signal("tube_session_joined", "")

func _on_connected_to_server() -> void:
	_local_peer_id = multiplayer.get_unique_id()

func _on_peer_connected(_id: int) -> void:
	_local_peer_id = multiplayer.get_unique_id()
