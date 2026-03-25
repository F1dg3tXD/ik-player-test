extends Node

enum PeerMode { NONE, WEBRTC }

const DEFAULT_SIGNALING_URL := "ws://127.0.0.1:9080"
const DEFAULT_STUN := "stun:stun.l.google.com:19302"
const HOST_PEER_ID := 1
const MIN_CLIENT_PEER_ID := 2
const MAX_PEER_ID := 2147483647

var peer_mode: PeerMode = PeerMode.NONE
var peer: MultiplayerPeer

var _webrtc_mesh: WebRTCMultiplayerPeer
var _signaling_socket := WebSocketPeer.new()
var _connections: Dictionary = {}
var _is_host := false
var _room_code := ""
var _local_peer_id := 0

func _process(_delta: float) -> void:
	var socket_state := _signaling_socket.get_ready_state()
	if socket_state == WebSocketPeer.STATE_CLOSED:
		return

	_signaling_socket.poll()

	while _signaling_socket.get_available_packet_count() > 0:
		var raw := _signaling_socket.get_packet().get_string_from_utf8()
		_handle_signaling_message(raw)

func close_connection() -> void:
	multiplayer.multiplayer_peer = null
	peer = null
	peer_mode = PeerMode.NONE
	_connections.clear()
	_local_peer_id = 0
	if _signaling_socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_signaling_socket.close()

func start_webrtc_host(room_code: String, signaling_url: String = DEFAULT_SIGNALING_URL) -> Error:
	close_connection()
	_room_code = room_code.strip_edges()
	if _room_code.is_empty():
		_room_code = "default"

	_is_host = true
	_local_peer_id = HOST_PEER_ID
	_webrtc_mesh = WebRTCMultiplayerPeer.new()

	var mesh_result := _webrtc_mesh.create_server()
	if mesh_result != OK:
		push_error("Failed to create WebRTC server peer: %s" % mesh_result)
		return mesh_result

	multiplayer.multiplayer_peer = _webrtc_mesh
	peer = _webrtc_mesh
	peer_mode = PeerMode.WEBRTC

	var ws_result := _signaling_socket.connect_to_url(signaling_url)
	if ws_result != OK:
		push_error("Failed to connect to signaling server: %s" % ws_result)
		return ws_result
	return OK

func start_webrtc_client(room_code: String, signaling_url: String = DEFAULT_SIGNALING_URL) -> Error:
	close_connection()
	_room_code = room_code.strip_edges()
	if _room_code.is_empty():
		_room_code = "default"

	_is_host = false
	_local_peer_id = _generate_client_peer_id()
	_webrtc_mesh = WebRTCMultiplayerPeer.new()

	var mesh_result := _webrtc_mesh.create_client(_local_peer_id)
	if mesh_result != OK:
		push_error("Failed to create WebRTC client peer: %s" % mesh_result)
		return mesh_result

	multiplayer.multiplayer_peer = _webrtc_mesh
	peer = _webrtc_mesh
	peer_mode = PeerMode.WEBRTC

	var ws_result := _signaling_socket.connect_to_url(signaling_url)
	if ws_result != OK:
		push_error("Failed to connect to signaling server: %s" % ws_result)
		return ws_result
	return OK

func _generate_client_peer_id() -> int:
	var timestamp := Time.get_unix_time_from_system()
	var micros := Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [OS.get_unique_id(), timestamp, micros])
	return rng.randi_range(MIN_CLIENT_PEER_ID, MAX_PEER_ID)


func get_local_peer_id() -> int:
	return _local_peer_id

func _send_signaling(payload: Dictionary) -> void:
	if _signaling_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_signaling_socket.send_text(JSON.stringify(payload))

func _handle_signaling_message(message: String) -> void:
	var data = JSON.parse_string(message)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var action := str(data.get("action", ""))
	match action:
		"hello":
			_send_signaling({
				"action": "join",
				"room": _room_code,
				"host": _is_host,
				"peer_id": _local_peer_id
			})
		"peer_joined":
			var peer_id := int(data.get("peer_id", 0))
			if peer_id > 0 and peer_id != _local_peer_id:
				_create_connection(peer_id, _is_host)
		"offer":
			var from_peer := int(data.get("from", 0))
			var conn = _create_connection(from_peer, false)
			if conn:
				conn.set_remote_description("offer", str(data.get("sdp", "")))
		"answer":
			var answer_from := int(data.get("from", 0))
			if _connections.has(answer_from):
				_connections[answer_from].set_remote_description("answer", str(data.get("sdp", "")))
		"ice":
			var ice_from := int(data.get("from", 0))
			if _connections.has(ice_from):
				_connections[ice_from].add_ice_candidate(
					str(data.get("mid", "0")),
					int(data.get("index", 0)),
					str(data.get("candidate", ""))
				)

func _create_connection(remote_id: int, should_create_offer: bool) -> WebRTCPeerConnection:
	if _connections.has(remote_id):
		return _connections[remote_id]

	var conn := WebRTCPeerConnection.new()
	conn.initialize({"iceServers": [{"urls": [DEFAULT_STUN]}]})
	conn.session_description_created.connect(func(type: String, sdp: String):
		conn.set_local_description(type, sdp)
		_send_signaling({"action": type, "room": _room_code, "from": _local_peer_id, "to": remote_id, "sdp": sdp})
	)
	conn.ice_candidate_created.connect(func(media: String, index: int, candidate_name: String):
		_send_signaling({
			"action": "ice",
			"room": _room_code,
			"from": _local_peer_id,
			"to": remote_id,
			"mid": media,
			"index": index,
			"candidate": candidate_name
		})
	)

	var add_result := _webrtc_mesh.add_peer(conn, remote_id)
	if add_result != OK:
		push_error("Could not add peer %s to mesh" % remote_id)
		return null

	_connections[remote_id] = conn
	if should_create_offer:
		conn.create_offer()
	return conn
