# NetworkManager.gd (Autoload)
extends Node

enum PeerMode { NONE, ENET, STEAM }

var peer_mode : PeerMode = PeerMode.NONE
var peer : Object = null

func set_peer_mode(mode: PeerMode) -> void:
	peer_mode = mode
	match mode:
		PeerMode.ENET:
			peer = ENetMultiplayerPeer.new()
		PeerMode.STEAM:
			# SteamMultiplayerPeer class provided by GodotSteam extension / custom build
			peer = SteamMultiplayerPeer.new()
		PeerMode.NONE:
			peer = null

# Safe update function: only assign multiplayer_peer when peer is connected/connecting
func update_multiplayer_peer() -> void:
	# NOTE: `multiplayer` is the SceneTree's MultiplayerAPI instance
	if peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		return

	# If peer has get_connection_status, ensure it's not disconnected
	if peer.has_method("get_connection_status"):
		var status = peer.get_connection_status()
		# Godot C++ constants are available; compare against DISCONNECTED
		if int(status) == MultiplayerPeer.CONNECTION_DISCONNECTED:
			push_warning("Peer is disconnected — not assigning multiplayer_peer yet.")
			return

	# Assign
	multiplayer.multiplayer_peer = peer

# Helper wrappers for ENet
func start_local_server(port: int, max_clients: int = 8) -> Error:
	if peer_mode != PeerMode.ENET:
		set_peer_mode(PeerMode.ENET)
	var err = peer.create_server(port, max_clients)
	if err != OK:
		return err
	update_multiplayer_peer()
	return OK

func start_local_client(addr: String, port: int) -> Error:
	if peer_mode != PeerMode.ENET:
		set_peer_mode(PeerMode.ENET)
	var err = peer.create_client(addr, port)
	if err != OK:
		return err
	update_multiplayer_peer()
	return OK

# Helper wrappers for SteamMultiplayerPeer:
func start_steam_host(relay: bool = true) -> Error:
	if peer_mode != PeerMode.STEAM:
		set_peer_mode(PeerMode.STEAM)
	peer.server_relay = true
	var err = peer.create_host()
	if err != OK:
		return err
	update_multiplayer_peer()
	return OK

func start_steam_client(owner_steamid: int) -> Error:
	if peer_mode != PeerMode.STEAM:
		set_peer_mode(PeerMode.STEAM)
	peer.server_relay = true
	var err = peer.create_client(owner_steamid)
	if err != OK:
		return err
	update_multiplayer_peer()
	return OK
