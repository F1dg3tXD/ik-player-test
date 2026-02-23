# SteamManager.gd (Autoload)
extends Node

# Set your test app id (480 for Spacewar while testing)
@export var app_id: int = 480

func _ready() -> void:
	# Make sure Steam overlay & APIs can initialize
	OS.set_environment("SteamAppId", str(app_id))
	Steam.steamInitEx() # prefer steamInitEx to get more info
	# Hook signals we rely on
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.join_requested.connect(_on_join_requested) # friend invite acceptance
	# NOTE: subscribe any additional Steam signals you need (e.g. avatar_loaded)

func _process(_delta: float) -> void:
	# MUST run Steam callbacks each frame
	Steam.run_callbacks()

# --- wrappers & helpers for the app ---
func create_lobby(type: int, max_members: int) -> void:
	Steam.createLobby(type, max_members)

func join_lobby(lobby_id: int) -> void:
	Steam.joinLobby(lobby_id)

# --- Signals forwarded to app ---
func _on_lobby_created(result: int, lobby_id: int) -> void:
	emit_signal("lobby_created", result, lobby_id) # optional re-emit

func _on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int) -> void:
	emit_signal("lobby_joined", lobby_id, permissions, locked, response)

func _on_lobby_match_list(lobby_array: Array) -> void:
	emit_signal("lobby_match_list", lobby_array)

# Called when a Steam invite is accepted (user clicked friend invite)
# GodotSteam delivers the lobby id in the join request signal
func _on_join_requested(lobby_id: int) -> void:
	emit_signal("join_requested", lobby_id)

# expose signals for other script to connect
signal lobby_created(result, lobby_id)
signal lobby_joined(lobby_id, permissions, locked, response)
signal lobby_match_list(lobbies)
signal join_requested(lobby_id)
