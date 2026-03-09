extends Node

enum PeerMode { NONE, ENET, STEAM }

var peer_mode : PeerMode = PeerMode.NONE
var peer : MultiplayerPeer

func start_steam_host():
	peer_mode = PeerMode.STEAM
	var steam_peer := SteamMultiplayerPeer.new()
	var result = steam_peer.create_host(0)
	if result != OK:
		push_error("Failed to host: %s" % result)
		return
	multiplayer.multiplayer_peer = steam_peer
	peer = steam_peer
	print("Steam host started")

func start_steam_client(host_steam_id:int):
	peer_mode = PeerMode.STEAM
	var steam_peer := SteamMultiplayerPeer.new()
	var result = steam_peer.create_client(host_steam_id,0)
	if result != OK:
		push_error("Failed to connect")
		return
	multiplayer.multiplayer_peer = steam_peer
	peer = steam_peer
	print("Steam client started")
