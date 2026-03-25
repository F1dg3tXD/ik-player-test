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
const TUBE_CLIENT_SCRIPT_PATH := "res://addons/tube/tube_client.gd"
const TUBE_CONTEXT_PATHS := [
	"res://globals/TubeContext.tres",
	"res://tube_context.tres",
	"res://addons/tube/tube_context.tres"
]
const SESSION_SETUP_TIMEOUT_SEC := 15.0

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
	if _tube_client and is_instance_valid(_tube_client):
		_tube_client.queue_free()
	_tube_client = null
	_tube_connected = false
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

	if not _is_webrtc_supported():
		return ERR_UNAVAILABLE
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
	_local_peer_id = _resolve_local_peer_id()
	peer = _resolve_active_peer()
	peer_mode = PeerMode.WEBRTC
	return OK

func start_webrtc_client(room_code: String, _signaling_url: String = DEFAULT_SIGNALING_URL) -> Error:
	close_connection()
	_is_host = false
	_room_code = _resolve_room_code(room_code, false)
	if _room_code == DEFAULT_ROOM_CODE:
		push_error("A valid Tube session ID is required to join.")
		return ERR_INVALID_PARAMETER

	if not _is_webrtc_supported():
		return ERR_UNAVAILABLE
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
	_local_peer_id = _resolve_local_peer_id()
	peer = _resolve_active_peer()
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
	var start_time_msec := Time.get_ticks_msec()
	while not _pending_tube_action.is_empty():
		if not _pending_result_error.is_empty():
			push_error(_pending_result_error)
			return FAILED
		if not _pending_result_room_code.is_empty():
			return OK
		var elapsed_sec := float(Time.get_ticks_msec() - start_time_msec) / 1000.0
		if elapsed_sec >= SESSION_SETUP_TIMEOUT_SEC:
			_pending_result_error = "Timed out while waiting for Tube to %s a session." % _pending_tube_action
			push_error(_pending_result_error)
			return ERR_TIMEOUT
		await get_tree().process_frame
	return FAILED

func get_local_peer_id() -> int:
	if _local_peer_id > 0:
		return _local_peer_id
	return multiplayer.get_unique_id()

func _ensure_tube_client() -> bool:
	if _tube_client and is_instance_valid(_tube_client):
		return true

	_tube_client = _instantiate_tube_client()
	if _tube_client == null:
		push_error("Failed to instantiate TubeClient.")
		return false

	_tube_client.name = "TubeClient"
	add_child(_tube_client)
	_connect_tube_signals()
	_load_default_tube_context()
	return true

func _instantiate_tube_client() -> Node:
	if ClassDB.class_exists("TubeClient"):
		return ClassDB.instantiate("TubeClient")
	if not ResourceLoader.exists(TUBE_CLIENT_SCRIPT_PATH):
		push_error("Tube addon not found at %s. Install/enable addons/tube." % TUBE_CLIENT_SCRIPT_PATH)
		return null
	var tube_script := load(TUBE_CLIENT_SCRIPT_PATH) as Script
	if tube_script == null:
		push_error("Unable to load TubeClient script at %s." % TUBE_CLIENT_SCRIPT_PATH)
		return null
	var client: Node = tube_script.new()
	if client == null:
		push_error("Unable to instantiate TubeClient from %s." % TUBE_CLIENT_SCRIPT_PATH)
		return null
	return client

func _is_webrtc_supported() -> bool:
	if ClassDB.class_exists("WebRTCPeerConnection"):
		return true
	push_error("WebRTC support is missing. Install/enable webrtc-native for non-HTML5 exports.")
	return false

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
	for context_path in TUBE_CONTEXT_PATHS:
		if ResourceLoader.exists(context_path):
			var context_resource := load(context_path)
			if context_resource != null:
				_tube_client.set("context", context_resource)
				_tube_client.set("multiplayer_root_node", get_tree().root)
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
	_local_peer_id = _resolve_local_peer_id()

func _on_peer_connected(_id: int) -> void:
	_local_peer_id = _resolve_local_peer_id()

func _resolve_local_peer_id() -> int:
	if _tube_client and is_instance_valid(_tube_client):
		var tube_peer_id := int(_tube_client.get("peer_id"))
		if tube_peer_id > 0:
			return tube_peer_id
	return multiplayer.get_unique_id()

func _resolve_active_peer() -> MultiplayerPeer:
	if _tube_client and is_instance_valid(_tube_client):
		var tube_peer: MultiplayerPeer = _tube_client.get("multiplayer_peer")
		if tube_peer is MultiplayerPeer:
			return tube_peer
	return multiplayer.multiplayer_peer
