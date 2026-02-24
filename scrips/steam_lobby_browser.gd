extends Control

@onready var refresh_button : Button = $Panel/VBoxContainer/HBoxContainer/RefreshButton
@onready var back_button : Button = $Panel/VBoxContainer/HBoxContainer/BackButton
@onready var lobby_list : VBoxContainer = $Panel/VBoxContainer/ScrollContainer/LobbyList

var found_lobbies : Array = []

func _ready() -> void:
	refresh_button.pressed.connect(_on_refresh_pressed)
	#back_button.pressed.connect(_on_back_pressed)
	
	# Connect to SteamManager lobby list signal
	SteamManager.connect("lobby_match_list", Callable(self, "_on_lobby_match_list"))
	
	_request_lobbies()

# ----------------------------------------------------
# REQUEST LOBBIES
# ----------------------------------------------------

func _request_lobbies() -> void:
	_clear_lobby_list()
	
	# Clear previous filters first (important when refreshing)
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	
	# Filter by game tag
	Steam.addRequestLobbyListStringFilter("game", "WEEPGame", Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()
	

func _on_refresh_pressed() -> void:
	_request_lobbies()

# ----------------------------------------------------
# RECEIVE LOBBY LIST
# ----------------------------------------------------

func _on_lobby_match_list(lobby_ids: Array) -> void:
	found_lobbies = lobby_ids
	_populate_lobby_list()

func _populate_lobby_list() -> void:
	for lobby_id in found_lobbies:
		var lobby_name = Steam.getLobbyData(lobby_id, "name")
		if lobby_name == "":
			lobby_name = "Unnamed Lobby"
			
		var members = Steam.getNumLobbyMembers(lobby_id)
		var max_members = Steam.getLobbyMemberLimit(lobby_id)
		
		var button = Button.new()
		button.text = "%s (%d/%d)" % [lobby_name, members, max_members]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		button.pressed.connect(func():
			_join_lobby(lobby_id)
		)
		
		lobby_list.add_child(button)

func _clear_lobby_list() -> void:
	for child in lobby_list.get_children():
		child.queue_free()

# ----------------------------------------------------
# JOIN LOBBY
# ----------------------------------------------------

func _join_lobby(lobby_id: int) -> void:
	Lobby.join_steam_lobby(lobby_id)

# ----------------------------------------------------
# BACK BUTTON
# ----------------------------------------------------

func _on_back_pressed() -> void:
	hide()
