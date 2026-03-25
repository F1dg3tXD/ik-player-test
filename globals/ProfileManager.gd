extends Node

const PROFILE_PATH := "user://player_profile.json"
const ICON_COPY_PATH := "user://profile_icon.png"

var username: String = "Player"
var icon_path: String = ""

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		return
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	username = str(data.get("username", username)).strip_edges()
	if username.is_empty():
		username = "Player"
	icon_path = str(data.get("icon_path", "")).strip_edges()
	if icon_path.is_empty() or not FileAccess.file_exists(icon_path):
		icon_path = ""

func save_profile(new_username: String, source_icon_path: String) -> void:
	username = new_username.strip_edges()
	if username.is_empty():
		username = "Player"

	if not source_icon_path.is_empty():
		var image := Image.new()
		if image.load(source_icon_path) == OK:
			image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			image.save_png(ICON_COPY_PATH)
			icon_path = ICON_COPY_PATH
	else:
		icon_path = ""

	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"username": username,
			"icon_path": icon_path
		}, "\t"))

func _create_fallback_icon() -> Image:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.1, 0.1, 1.0))
	return image

func get_icon_image() -> Image:
	if icon_path.is_empty():
		return _create_fallback_icon()

	var image := Image.new()
	if image.load(icon_path) != OK:
		return _create_fallback_icon()

	image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	return image

func get_icon_png_buffer() -> PackedByteArray:
	return get_icon_image().save_png_to_buffer()
