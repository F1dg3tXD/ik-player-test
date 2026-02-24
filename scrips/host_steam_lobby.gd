extends Control
#$Panel/VBoxContainer/LobbyNameRow/LobbyName
@onready var lobby_name: LineEdit = $Panel/VBoxContainer/LobbyNameRow/LobbyName
@onready var max_players: SpinBox = $Panel/VBoxContainer/MaxPlayersRow/MaxPlayers
@onready var friends_only: CheckBox = $Panel/VBoxContainer/FriendsOnly
@onready var enable_password: CheckBox = $Panel/VBoxContainer/EnablePassword
@onready var password_field: LineEdit = $Panel/VBoxContainer/PasswordField

@onready var create_button: Button = $Panel/VBoxContainer/ButtonsRow/CreateButton
@onready var back_button: Button = $Panel/VBoxContainer/ButtonsRow/BackButton

func _ready() -> void:
	enable_password.toggled.connect(_on_password_toggle)
	create_button.pressed.connect(_on_create_pressed)
	back_button.pressed.connect(_on_back_pressed)

# ----------------------------------------------------
# PASSWORD TOGGLE
# ----------------------------------------------------

func _on_password_toggle(enabled: bool) -> void:
	password_field.editable = enabled
	if not enabled:
		password_field.text = ""

# ----------------------------------------------------
# CREATE LOBBY
# ----------------------------------------------------

func _on_create_pressed() -> void:

	if lobby_name.text.strip_edges() == "":
		lobby_name.text = "WEEP Lobby"

	Lobby.host_steam_lobby(
		max_players.value,
		friends_only.button_pressed,
		enable_password.button_pressed,
		password_field.text
	)
	hide()

# ----------------------------------------------------
# BACK
# ----------------------------------------------------

func _on_back_pressed() -> void:
	hide()
