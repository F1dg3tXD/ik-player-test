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
func start_steam_host():
	set_peer_mode(PeerMode.STEAM)
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	var result = peer.create_host(0)
	
	if result != OK:
		print("Failed to host:", result)
		return
	
	update_multiplayer_peer()
	print("Steam Host Started")

func start_steam_client(host_steam_id: int):
	set_peer_mode(PeerMode.STEAM)
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	var result = peer.create_client(host_steam_id, 0)
	
	if result != OK:
		print("Failed to connect:", result)
		return
	
	update_multiplayer_peer()
	print("Connected to host")
