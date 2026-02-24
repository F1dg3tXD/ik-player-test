extends Node2D

@onready var main: VBoxContainer = $main/Menu/Main
@onready var multiplayer_menu: Control = $main/Menu/MultiPlayerMenuHead
@onready var options_menu: Control = $main/Menu/OptionsMenuHead

# Main Menu Buttons
@onready var btn_single_player: Button = $main/Menu/Main/SinglePlayer
@onready var btn_multi_player: Button = $main/Menu/Main/MultiPlayer
@onready var btn_options: Button = $main/Menu/Main/Options
@onready var btn_exit: Button = $main/Menu/Main/Exit

# Multiplayer Menu Stuff
#ENet
@onready var btn_e_net_host: Button = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/BTN_ENet_Host
@onready var btn_e_net_join: Button = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/BTN_ENet_Join
@onready var e_net_id_prompt: LineEdit = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/ENet_id_prompt

# Steam
@onready var btn_steam_host: Button = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/Steam/BTN_Steam_Host
@onready var btn_steam_lobby_browser: Button = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/Steam/BTN_Steam_LobbyBrowser
@onready var steam_browser: Control = $main/Menu/SteamLobbyBrowser
@onready var host_steam_lobby: Control = $main/Menu/HostSteamLobby

# Graphics
@onready var graphics: VBoxContainer = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics
@onready var resolutions: OptionButton = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/Resolution/Resolutions
@onready var window_mode: OptionButton = $"main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/Window Mode/WindowMode"
@onready var aa_options: OptionButton = $"main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/AA/AA Options"
@onready var v_sync_toggle: CheckButton = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/VSync/VSyncToggle
@onready var apply: Button = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/Apply

# Audio
@onready var audio: VBoxContainer = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio
@onready var master_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Master/MasterSlider
@onready var sfx_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/SFX/SfxSlider
@onready var music_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Music/MusicSlider
@onready var scares_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Scares/ScaresSlider
@onready var voices_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Voices/VoicesSlider

# Internal storage
var available_resolutions : Array = []
var pending_resolution : Vector2i
var pending_window_mode : int
var pending_vsync : bool

func _ready() -> void:
	# Disable single player for now
	btn_single_player.disabled = true
	
	_connect_main_buttons()
	_connect_audio_sliders()
	_connect_buttons()
	_populate_resolution_dropdown()
	_populate_window_mode_dropdown()
	_populate_aa_dropdown()
	_load_current_settings()
	
	# Default state
	_show_main()

# ----------------------------------------------------
# MAIN MENU BUTTON CONNECTIONS
# ----------------------------------------------------

func _connect_main_buttons() -> void:
	pass
	#apply.pressed.connect(_on_apply_pressed)
	#btn_options.pressed.connect(_on_options_pressed)
	#btn_multi_player.pressed.connect(_on_multiplayer_pressed)
	#btn_exit.pressed.connect(_on_exit_pressed)

# ----------------------------------------------------
# MENU STATE MANAGEMENT
# ----------------------------------------------------

func _show_main() -> void:
	main.show()
	multiplayer_menu.hide()
	options_menu.hide()
	steam_browser.hide()

func _show_options() -> void:
	#main.hide()
	multiplayer_menu.hide()
	options_menu.show()

func _show_multiplayer() -> void:
	#main.hide()
	options_menu.hide()
	multiplayer_menu.show()


func _on_options_pressed() -> void:
	_show_options()

func _on_multiplayer_pressed() -> void:
	_show_multiplayer()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_back_pressed() -> void:
	_show_main()

func _on_steam_browser_pressed() -> void:
	steam_browser.show()
	host_steam_lobby.hide()

func _on_btn_steam_host_pressed() -> void:
	host_steam_lobby.show()
	steam_browser.hide()

# ----------------------------------------------------
# BUTTON CONNECTIONS
# ----------------------------------------------------

func _connect_buttons() -> void:
	resolutions.item_selected.connect(_on_resolution_selected)
	window_mode.item_selected.connect(_on_window_mode_selected)
	aa_options.item_selected.connect(_on_aa_selected)
	v_sync_toggle.toggled.connect(_on_vsync_toggled)

# ----------------------------------------------------
# RESOLUTION SETUP (Godot 4.6 Correct Version)
# ----------------------------------------------------

func _populate_resolution_dropdown() -> void:
	resolutions.clear()
	available_resolutions.clear()

	var screen = DisplayServer.window_get_current_screen()
	var screen_size = DisplayServer.screen_get_size(screen)

	# Common 16:9 resolutions
	var common_resolutions = [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160)
	]

	for res in common_resolutions:
		# Only add resolutions that fit the monitor
		if res.x <= screen_size.x and res.y <= screen_size.y:
			available_resolutions.append(res)
			resolutions.add_item(str(res.x) + " x " + str(res.y))

func _on_resolution_selected(index: int) -> void:
	pending_resolution = available_resolutions[index]

# ----------------------------------------------------
# WINDOW MODE SETUP
# ----------------------------------------------------

func _populate_window_mode_dropdown() -> void:
	window_mode.clear()

	window_mode.add_item("Windowed")
	window_mode.add_item("Fullscreen")
	window_mode.add_item("Borderless")

func _on_window_mode_selected(index: int) -> void:
	match index:
		0:
			pending_window_mode = DisplayServer.WINDOW_MODE_WINDOWED
		1:
			pending_window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		2:
			pending_window_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

# ----------------------------------------------------
# ANTI-ALIASING SETUP
# ----------------------------------------------------

func _populate_aa_dropdown() -> void:
	aa_options.clear()

	aa_options.add_item("Disabled")
	aa_options.add_item("2x MSAA")
	aa_options.add_item("4x MSAA")
	aa_options.add_item("8x MSAA")

func _on_aa_selected(index: int) -> void:
	match index:
		0:
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1:
			get_viewport().msaa_3d = Viewport.MSAA_2X
		2:
			get_viewport().msaa_3d = Viewport.MSAA_4X
		3:
			get_viewport().msaa_3d = Viewport.MSAA_8X

# ----------------------------------------------------
# VSYNC
# ----------------------------------------------------

func _on_vsync_toggled(enabled: bool) -> void:
	pending_vsync = enabled
	
# ----------------------------------------------------
# APPLY SETTINGS
# ----------------------------------------------------

func _on_apply_pressed() -> void:
	# Apply window mode first (important for fullscreen behavior)
	if pending_window_mode != null:
		DisplayServer.window_set_mode(pending_window_mode)

	# Apply resolution
	if pending_resolution != null:
		DisplayServer.window_set_size(pending_resolution)

	# Apply VSync
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if pending_vsync else DisplayServer.VSYNC_DISABLED
	)
# ----------------------------------------------------
# AUDIO SETTINGS
# ----------------------------------------------------

func _connect_audio_sliders() -> void:
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	scares_slider.value_changed.connect(_on_scares_changed)
	voices_slider.value_changed.connect(_on_voices_changed)

	_load_audio_values()


func _on_master_changed(value: float) -> void:
	_set_bus_volume("Master", value)

func _on_sfx_changed(value: float) -> void:
	_set_bus_volume("SFX", value)

func _on_music_changed(value: float) -> void:
	_set_bus_volume("Music", value)

func _on_scares_changed(value: float) -> void:
	_set_bus_volume("Scares", value)

func _on_voices_changed(value: float) -> void:
	_set_bus_volume("Voices", value)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus = AudioServer.get_bus_index(bus_name)
	if bus == -1:
		push_warning("Bus not found: " + bus_name)
		return
	
	# Sliders usually 0–100. Convert to decibels.
	var db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(bus, db)

# ----------------------------------------------------
# LOAD CURRENT SETTINGS INTO UI
# ----------------------------------------------------

func _load_audio_values() -> void:
	_set_slider_from_bus(master_slider, "Master")
	_set_slider_from_bus(sfx_slider, "SFX")
	_set_slider_from_bus(music_slider, "Music")
	_set_slider_from_bus(scares_slider, "Scares")
	_set_slider_from_bus(voices_slider, "Voices")


func _set_slider_from_bus(slider: HSlider, bus_name: String) -> void:
	var bus = AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	
	var db = AudioServer.get_bus_volume_db(bus)
	var linear = db_to_linear(db)
	slider.value = linear * 100.0

func _load_current_settings() -> void:
	# Set current resolution selection
	var current_size = DisplayServer.window_get_size()
	for i in available_resolutions.size():
		if available_resolutions[i] == current_size:
			resolutions.select(i)
			break
	
	# Set window mode selection
	var mode = DisplayServer.window_get_mode()
	match mode:
		DisplayServer.WINDOW_MODE_WINDOWED:
			window_mode.select(0)
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode.select(1)
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			window_mode.select(2)
	
	# Set VSync
	v_sync_toggle.button_pressed = (
		DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	)
	
	# Set AA
	match get_viewport().msaa_3d:
		Viewport.MSAA_DISABLED:
			aa_options.select(0)
		Viewport.MSAA_2X:
			aa_options.select(1)
		Viewport.MSAA_4X:
			aa_options.select(2)
		Viewport.MSAA_8X:
			aa_options.select(3)
	
	# Apply Settings
	pending_resolution = DisplayServer.window_get_size()
	pending_window_mode = DisplayServer.window_get_mode()
	pending_vsync = (
		DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	)
