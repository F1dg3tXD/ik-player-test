extends Node2D

@onready var main: VBoxContainer = $main/Menu/Main
@onready var multiplayer_menu: Control = $main/Menu/MultiPlayerMenuHead
@onready var options_menu: Control = $main/Menu/OptionsMenuHead

# Main Menu Buttons
@onready var btn_single_player: Button = $main/Menu/Main/SinglePlayer

# Multiplayer UI
@onready var btn_webrtc_host: Button = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/BTN_ENet_Host
@onready var btn_webrtc_join: Button = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/BTN_ENet_Join
@onready var room_code_prompt: LineEdit = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/ENet_id_prompt
@onready var signaling_prompt: LineEdit = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/SignalURLPrompt
@onready var status_label: Label = $main/Menu/MultiPlayerMenuHead/VBoxContainer/MultiplayerMenu/ENet/StatusLabel

# Profile UI
@onready var username_prompt: LineEdit = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Profile/UsernameRow/UsernamePrompt
@onready var icon_path_prompt: LineEdit = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Profile/IconRow/IconPathPrompt

# Graphics
@onready var resolutions: OptionButton = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/Resolution/Resolutions
@onready var window_mode: OptionButton = $"main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/Window Mode/WindowMode"
@onready var aa_options: OptionButton = $"main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/AA/AA Options"
@onready var v_sync_toggle: CheckButton = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Graphics/VSync/VSyncToggle

# Audio
@onready var master_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Master/MasterSlider
@onready var sfx_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/SFX/SfxSlider
@onready var music_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Music/MusicSlider
@onready var scares_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Scares/ScaresSlider
@onready var voices_slider: HSlider = $main/Menu/OptionsMenuHead/VBoxContainer/OptionsMenu/Audio/VBoxContainer/Voices/VoicesSlider

var available_resolutions: Array = []
var pending_resolution: Vector2i
var pending_window_mode: int
var pending_vsync: bool

func _ready() -> void:
	btn_single_player.disabled = true
	_connect_audio_sliders()
	_connect_buttons()
	_populate_resolution_dropdown()
	_populate_window_mode_dropdown()
	_populate_aa_dropdown()
	_load_current_settings()
	_load_profile_ui()
	_show_main()

func _show_main() -> void:
	main.show()
	multiplayer_menu.hide()
	options_menu.hide()

func _show_options() -> void:
	multiplayer_menu.hide()
	options_menu.show()

func _show_multiplayer() -> void:
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

func _on_btn_host_pressed() -> void:
	ProfileManager.save_profile(username_prompt.text, icon_path_prompt.text)
	var room := room_code_prompt.text.strip_edges()
	var signaling_url := signaling_prompt.text.strip_edges()
	var result := await Lobby.host_webrtc_lobby(room, signaling_url)
	if result == OK:
		room_code_prompt.text = Lobby.active_room_code
		status_label.text = "Host started. Room: %s" % Lobby.active_room_code
	else:
		status_label.text = "Host failed: %s" % result

func _on_btn_join_pressed() -> void:
	ProfileManager.save_profile(username_prompt.text, icon_path_prompt.text)
	var room := room_code_prompt.text.strip_edges()
	var signaling_url := signaling_prompt.text.strip_edges()
	var result := Lobby.join_webrtc_lobby(room, signaling_url)
	if result == OK:
		room_code_prompt.text = Lobby.active_room_code
		status_label.text = "Joining room %s..." % Lobby.active_room_code
	else:
		status_label.text = "Join failed: %s" % result

func _on_id_prompt_text_changed(_new_text: String) -> void:
	pass

func _connect_buttons() -> void:
	resolutions.item_selected.connect(_on_resolution_selected)
	window_mode.item_selected.connect(_on_window_mode_selected)
	aa_options.item_selected.connect(_on_aa_selected)
	v_sync_toggle.toggled.connect(_on_vsync_toggled)

func _populate_resolution_dropdown() -> void:
	resolutions.clear()
	available_resolutions.clear()
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var common_resolutions := [
		Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)
	]
	for res in common_resolutions:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			available_resolutions.append(res)
			resolutions.add_item("%s x %s" % [res.x, res.y])

func _on_resolution_selected(index: int) -> void:
	pending_resolution = available_resolutions[index]

func _populate_window_mode_dropdown() -> void:
	window_mode.clear()
	window_mode.add_item("Windowed")
	window_mode.add_item("Fullscreen")
	window_mode.add_item("Borderless")

func _on_window_mode_selected(index: int) -> void:
	match index:
		0: pending_window_mode = DisplayServer.WINDOW_MODE_WINDOWED
		1: pending_window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		2: pending_window_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _populate_aa_dropdown() -> void:
	aa_options.clear()
	aa_options.add_item("Disabled")
	aa_options.add_item("2x MSAA")
	aa_options.add_item("4x MSAA")
	aa_options.add_item("8x MSAA")

func _on_aa_selected(index: int) -> void:
	match index:
		0: get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		1: get_viewport().msaa_3d = Viewport.MSAA_2X
		2: get_viewport().msaa_3d = Viewport.MSAA_4X
		3: get_viewport().msaa_3d = Viewport.MSAA_8X

func _on_vsync_toggled(enabled: bool) -> void:
	pending_vsync = enabled

func _on_apply_pressed() -> void:
	if pending_window_mode != null:
		DisplayServer.window_set_mode(pending_window_mode)
	if pending_resolution != null:
		DisplayServer.window_set_size(pending_resolution)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if pending_vsync else DisplayServer.VSYNC_DISABLED)
	ProfileManager.save_profile(username_prompt.text, icon_path_prompt.text)

func _connect_audio_sliders() -> void:
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	scares_slider.value_changed.connect(_on_scares_changed)
	voices_slider.value_changed.connect(_on_voices_changed)
	_load_audio_values()

func _on_master_changed(value: float) -> void: _set_bus_volume("Master", value)
func _on_sfx_changed(value: float) -> void: _set_bus_volume("SFX", value)
func _on_music_changed(value: float) -> void: _set_bus_volume("Music", value)
func _on_scares_changed(value: float) -> void: _set_bus_volume("Scares", value)
func _on_voices_changed(value: float) -> void: _set_bus_volume("Voices", value)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))

func _load_audio_values() -> void:
	_set_slider_from_bus(master_slider, "Master")
	_set_slider_from_bus(sfx_slider, "SFX")
	_set_slider_from_bus(music_slider, "Music")
	_set_slider_from_bus(scares_slider, "Scares")
	_set_slider_from_bus(voices_slider, "Voices")

func _set_slider_from_bus(slider: HSlider, bus_name: String) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus == -1:
		return
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus)) * 100.0

func _load_current_settings() -> void:
	var current_size := DisplayServer.window_get_size()
	for i in available_resolutions.size():
		if available_resolutions[i] == current_size:
			resolutions.select(i)
			break
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_WINDOWED: window_mode.select(0)
		DisplayServer.WINDOW_MODE_FULLSCREEN: window_mode.select(1)
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN: window_mode.select(2)
	v_sync_toggle.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	match get_viewport().msaa_3d:
		Viewport.MSAA_DISABLED: aa_options.select(0)
		Viewport.MSAA_2X: aa_options.select(1)
		Viewport.MSAA_4X: aa_options.select(2)
		Viewport.MSAA_8X: aa_options.select(3)
	pending_resolution = DisplayServer.window_get_size()
	pending_window_mode = DisplayServer.window_get_mode()
	pending_vsync = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED

func _load_profile_ui() -> void:
	username_prompt.text = ProfileManager.username
	icon_path_prompt.text = ProfileManager.icon_path
