# player.gd
extends CharacterBody3D

#class_name Player

@export var SPEED := 5.0
@export var ACCEL := 10.0
@export var DECEL := 12.0
@export var JUMP_VELOCITY := 4.5

var roll_angle: float = 0.0
@export var ROLL_RADIUS := 0.4
@export var ROLL_DAMP := 2.0
@export var STRAFE_YAW_ANGLE := deg_to_rad(90.0)

@onready var walker: Marker3D = $player_mdl/roller/walker
@onready var player_mdl: Node3D = $player_mdl
@onready var beta_joints: MeshInstance3D = $player_mdl/Armature/Skeleton3D/Beta_Joints
@onready var beta_surface: MeshInstance3D = $player_mdl/Armature/Skeleton3D/Beta_Surface

var horizontal_vel := Vector3.ZERO
var _profile_loaded_attempted := false

@export var MOUSE_SENS := 0.002
@export var TURN_SPEED := 8.0
@export var PITCH_LIMIT := 80.0

var is_flying: bool = false
@export var FLY_SPEED := 8.0

var cam_yaw: float = 0.0
var cam_pitch: float = -15.0

# Thirdperson camera will be reused for spectator camera

# Main FPS Camera Stuff
@onready var camera_3d: Camera3D = %Camera3D
@onready var neck: Node3D = $neck
@onready var head: Node3D = $neck/head

@export var stick_sensitivity := 2.5
@export var stick_deadzone := 0.15

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export var tilt_limit = deg_to_rad(75)

# Player profile UI
@onready var display_name: Label = $SteamName/displayName
@onready var avatar_sprite: Sprite2D = $SteamIcon/avatarSprite
@onready var name_plate: Sprite3D = $namePlate

# Transform replication
@export var remote_position_lerp_speed := 18.0
@export var remote_rotation_lerp_speed := 14.0
@export var state_broadcast_interval := 0.05
var _state_broadcast_timer := 0.0
var _remote_position_target := Vector3.ZERO
var _remote_body_yaw_target := 0.0
var _remote_head_pitch_target := 0.0
var _remote_roll_angle := 0.0
var _remote_walker_rot_x := 0.0
var _remote_walker_scale := Vector3.ONE
var _remote_head_target_pos := Vector3.ZERO
var _remote_spine_target_pos := Vector3.ZERO

# Player colors 
const JOINTS_MATERIAL := preload("res://materials/player_joints.tres")
const SURFACE_MATERIAL := preload("res://materials/player_mesh.tres")

var beta_joints_mat: StandardMaterial3D
var beta_surface_mat: StandardMaterial3D
var _joints_color: Color = Color(0.612501, 0.38787553, 0.35089412)
var _surface_color: Color = Color(0.9246135, 0.58587474, 0.55036527)

# UI elements
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var joints_color_picker: ColorPickerButton = $PauseMenu/PausePanel/VBoxContainer/ColorRow/JointsColorPicker
@onready var surface_color_picker: ColorPickerButton = $PauseMenu/PausePanel/VBoxContainer/ColorRow/SurfaceColorPicker
@onready var room_code_value: LineEdit = $PauseMenu/PausePanel/VBoxContainer/RoomCodeRow/RoomCodeValue
@onready var copy_room_code_button: Button = $PauseMenu/PausePanel/VBoxContainer/CopyRoomCodeButton
@onready var status_label: Label = $PauseMenu/PausePanel/VBoxContainer/StatusLabel
@onready var disconnect_button: Button = $PauseMenu/PausePanel/VBoxContainer/OptionsRow/DisconnectButton
@onready var quit_game_button: Button = $PauseMenu/PausePanel/VBoxContainer/OptionsRow/QuitGameButton

var is_paused: bool = false

@onready var lobby_node: Node = null

# Interaction Ray
@onready var head_target: Marker3D = $neck/head/LookTarget/HeadTarget
@onready var spine_target: Marker3D = $neck/head/LookTarget/SpineTarget
@onready var head_look: Node3D = $player_mdl/Armature/Skeleton3D/HeadLook
@onready var chest_look: Node3D = $player_mdl/Armature/Skeleton3D/ChestLook

func _enter_tree() -> void:
	var peer_id := str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
		
# Render Meshes
@onready var beta_joints_render: MeshInstance3D = $player_mdl/Armature/Skeleton3D/Beta_JointsRender
@onready var beta_surface_render: MeshInstance3D = $player_mdl/Armature/Skeleton3D/Beta_SurfaceRender

func _ready() -> void:
	beta_joints_mat = JOINTS_MATERIAL.duplicate()
	beta_surface_mat = SURFACE_MATERIAL.duplicate()
	beta_joints_mat.albedo_color = _joints_color
	beta_surface_mat.albedo_color = _surface_color
	beta_joints.set_surface_override_material(0, beta_joints_mat)
	beta_surface.set_surface_override_material(0, beta_surface_mat)
	beta_joints_render.set_surface_override_material(0, beta_joints_mat)
	beta_surface_render.set_surface_override_material(0, beta_surface_mat)

	if is_multiplayer_authority():
		print("Local player ready -> enabling camera")
		await get_tree().process_frame
		await get_tree().process_frame
		camera_3d.current = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player_mdl.visible = true
		name_plate.visible = false
		beta_joints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		beta_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		if head_look and "enabled" in head_look:
			head_look.set("enabled", true)
		if chest_look and "enabled" in chest_look:
			chest_look.set("enabled", true)
	else:
		camera_3d.current = false
		_remote_position_target = global_position
		_remote_body_yaw_target = rotation.y
		_remote_head_pitch_target = head.rotation.x

	_try_sync_profile()

	lobby_node = get_tree().root.get_node_or_null("Lobby")

	if is_multiplayer_authority() and joints_color_picker and surface_color_picker:
		joints_color_picker.color = _joints_color
		surface_color_picker.color = _surface_color
	
	if is_multiplayer_authority():
		if pause_menu:
			pause_menu.visible = false
		if copy_room_code_button:
			copy_room_code_button.pressed.connect(_on_copy_room_code_button_pressed)
			_update_pause_menu_for_role()
		if disconnect_button:
			disconnect_button.pressed.connect(_on_disconnect_pressed)
		if quit_game_button:
			quit_game_button.pressed.connect(_on_quit_game_pressed)
		if lobby_node:
			lobby_node.lobby_created.connect(_on_lobby_state_updated)
			lobby_node.lobby_joined.connect(_on_lobby_state_updated)
		NetworkManager.session_ended.connect(_on_session_ended)

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		return
	global_position = global_position.lerp(_remote_position_target, clamp(delta * remote_position_lerp_speed, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _remote_body_yaw_target, clamp(delta * remote_rotation_lerp_speed, 0.0, 1.0))
	head.rotation.x = lerp_angle(head.rotation.x, _remote_head_pitch_target, clamp(delta * remote_rotation_lerp_speed, 0.0, 1.0))
	roll_angle = lerp_angle(roll_angle, _remote_roll_angle, clamp(delta * remote_rotation_lerp_speed, 0.0, 1.0))
	walker.rotation.x = lerp_angle(walker.rotation.x, _remote_walker_rot_x, clamp(delta * remote_rotation_lerp_speed, 0.0, 1.0))
	walker.scale = walker.scale.lerp(_remote_walker_scale, clamp(delta * remote_position_lerp_speed, 0.0, 1.0))
	if head_target and is_instance_valid(head_target):
		head_target.global_position = head_target.global_position.lerp(_remote_head_target_pos, clamp(delta * remote_position_lerp_speed, 0.0, 1.0))
	if spine_target and is_instance_valid(spine_target):
		spine_target.global_position = spine_target.global_position.lerp(_remote_spine_target_pos, clamp(delta * remote_position_lerp_speed, 0.0, 1.0))

func _on_multiplayer_authority_changed() -> void:
	_try_sync_profile()

func _try_sync_profile() -> void:
	if not is_multiplayer_authority():
		return
	
	ProfileManager.load_profile()
	_sync_profile.rpc(ProfileManager.username, ProfileManager.get_icon_png_buffer())

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if event.is_action_pressed("pause"):
		_toggle_pause_menu()
		return
	
	if is_paused:
		return
		
	if event is InputEventMouseMotion:
		# Yaw rotates the body
		rotation.y -= event.relative.x * mouse_sensitivity
		# Pitch rotates the head
		head.rotation.x += event.relative.y * mouse_sensitivity
		head.rotation.x = clamp(head.rotation.x, -tilt_limit, tilt_limit)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	# -------------------------------------------------
	# INPUT
	# -------------------------------------------------

	var input: Vector2 = Input.get_vector("move_right", "move_left", "move_up", "move_down")

	var look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down", stick_deadzone)

	if look != Vector2.ZERO and is_multiplayer_authority():
		rotation.y -= look.x * stick_sensitivity * delta
		head.rotation.x += look.y * stick_sensitivity * delta
		head.rotation.x = clamp(head.rotation.x, -tilt_limit, tilt_limit)

	# -------------------------------------------------
	# CAMERA RELATIVE MOVEMENT
	# -------------------------------------------------

	var forward = -transform.basis.z
	var right = transform.basis.x

	if not is_flying:
		forward.y = 0
		right.y = 0

	forward = forward.normalized()
	right = right.normalized()

	var move_dir = right * input.x + forward * input.y

	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	# Horizontal accel
	if move_dir != Vector3.ZERO:
		horizontal_vel = horizontal_vel.move_toward(move_dir * SPEED, ACCEL * delta)
	else:
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, DECEL * delta)

	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z

	# -------------------------------------------------
	# VERTICAL LOGIC (Clean Separation)
	# -------------------------------------------------

	if is_flying:
		var vertical_input := 0.0

		if Input.is_action_pressed("jump"):
			vertical_input += 1.0
		if Input.is_action_pressed("crouch"):
			vertical_input -= 1.0

		velocity.y = move_toward(
			velocity.y,
			vertical_input * FLY_SPEED,
			ACCEL * delta
		)

	else:
		# Ground gravity
		if not is_on_floor():
			velocity.y += get_gravity().y * delta
		else:
			if velocity.y < 0:
				velocity.y = 0

		# Jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	move_and_slide()
	update_walker(delta)
	_broadcast_state(delta)

func _broadcast_state(delta: float) -> void:
	_state_broadcast_timer += delta
	if _state_broadcast_timer < state_broadcast_interval:
		return
	_state_broadcast_timer = 0.0
	
	if not multiplayer.has_multiplayer_peer() or multiplayer.get_multiplayer_peer().get_connection_status() != multiplayer.get_multiplayer_peer().CONNECTION_CONNECTED:
		return
	
	_receive_state.rpc(
		global_position, 
		rotation.y, 
		head.rotation.x, 
		roll_angle, 
		walker.rotation.x, 
		walker.scale,
		head_target.global_position,
		spine_target.global_position
	)

func update_walker(delta: float) -> void:
	var local_vel: Vector3 = player_mdl.global_transform.basis.inverse() * horizontal_vel

	var forward_speed: float = local_vel.z
	var strafe_speed: float = local_vel.x

	var forward_norm: float = clamp(abs(forward_speed) / SPEED, 0.0, 1.0)
	var strafe_norm: float = clamp(abs(strafe_speed) / SPEED, 0.0, 1.0)

	var _moving: float = abs(forward_speed) > 0.01 or abs(strafe_speed) > 0.01

	# --- CONTINUOUS ROLL (FORWARD ONLY) ---
	if abs(forward_speed) > 0.01:
		roll_angle += (forward_speed / ROLL_RADIUS) * delta
	else:
		# Snap to nearest 180° when stopping forward motion
		var snap := PI
		var target: float = round(roll_angle / snap) * snap
		roll_angle = lerp_angle(roll_angle, target, delta * ROLL_DAMP)

	walker.rotation.x = roll_angle

	# --- STRIDE LENGTH (FORWARD/BACK ONLY) ---
	var target_stride: float = lerp(1.0, 7.0, forward_norm)
	walker.scale.z = lerp(walker.scale.z, target_stride, delta * 6.0)

	# --- FEET DISTANCE (STRAFE ONLY) ---
	var target_feet: float = lerp(1.0, 4.0, strafe_norm)
	walker.scale.x = lerp(walker.scale.x, target_feet, delta * 6.0)

	# --- STRAFE DIRECTION (LEAN / Y ROTATION) ---
	var strafe_dir: float = clamp(strafe_speed / SPEED, -1.0, 1.0)
	var target_yaw: float = deg_to_rad(0.0) * strafe_dir
	walker.rotation.y = lerp(walker.rotation.y, target_yaw, delta * 8.0)

@rpc("authority", "call_remote", "reliable")
func _sync_profile(player_name: String, icon_png: PackedByteArray) -> void:
	var safe_name := player_name.strip_edges()
	if safe_name.is_empty():
		safe_name = "Player"
	display_name.text = safe_name
	var avatar_image := Image.new()
	if icon_png.is_empty() or avatar_image.load_png_from_buffer(icon_png) != OK:
		avatar_image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		avatar_image.fill(Color(0.8, 0.1, 0.1, 1.0))
	else:
		avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	avatar_sprite.texture = ImageTexture.create_from_image(avatar_image)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_state(world_pos: Vector3, body_yaw: float, head_pitch: float, w_roll: float, w_rot_x: float, w_scale: Vector3, head_target_pos: Vector3, spine_target_pos: Vector3) -> void:
	if is_multiplayer_authority():
		return
	_remote_position_target = world_pos
	_remote_body_yaw_target = body_yaw
	_remote_head_pitch_target = head_pitch
	_remote_roll_angle = w_roll
	_remote_walker_rot_x = w_rot_x
	_remote_walker_scale = w_scale
	_remote_head_target_pos = head_target_pos
	_remote_spine_target_pos = spine_target_pos

func apply_remote_profile(player_name: String, icon_png_base64: String) -> void:
	var png_buffer := PackedByteArray()
	if not icon_png_base64.is_empty():
		png_buffer = Marshalls.base64_to_raw(icon_png_base64)
	_sync_profile(player_name, png_buffer)

func set_fly_mode(enabled: bool) -> void:
	is_flying = enabled

	if is_flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	velocity = Vector3.ZERO

func _on_color_changed(joints_color: Color, surface_color: Color) -> void:
	if not is_multiplayer_authority():
		return
	_joints_color = joints_color
	_surface_color = surface_color
	_apply_player_colors()
	replicate_colors.rpc(joints_color, surface_color)

func _on_joints_color_changed(color: Color) -> void:
	if not is_multiplayer_authority():
		return
	_joints_color = color
	_apply_player_colors()
	replicate_colors.rpc(_joints_color, _surface_color)

func _on_surface_color_changed(color: Color) -> void:
	if not is_multiplayer_authority():
		return
	_surface_color = color
	_apply_player_colors()
	replicate_colors.rpc(_joints_color, _surface_color)

@rpc("authority", "call_remote", "reliable")
func replicate_colors(joints_color: Color, surface_color: Color) -> void:
	_joints_color = joints_color
	_surface_color = surface_color
	_apply_player_colors()

func get_joints_color() -> Color:
	return _joints_color

func get_surface_color() -> Color:
	return _surface_color

func _apply_player_colors() -> void:
	beta_joints_mat.albedo_color = _joints_color
	beta_surface_mat.albedo_color = _surface_color

func _toggle_pause_menu() -> void:
	if pause_menu == null:
		return
	is_paused = not is_paused
	pause_menu.visible = is_paused
	if is_paused:
		_update_pause_menu_for_role()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_pause_menu_for_role() -> void:
	if status_label == null:
		return
	
	var room_code_val := ""
	if lobby_node != null:
		var ac = lobby_node.get("active_room_code")
		if ac != null:
			room_code_val = ac
	
	if room_code_val.is_empty():
		room_code_val = "(No lobby room code available)"
	if room_code_value:
		room_code_value.text = room_code_val

	var can_copy: bool = multiplayer.is_server()
	if lobby_node != null and lobby_node.has_method("_is_dedicated_server_mode"):
		var is_dedicated: bool = lobby_node.call("_is_dedicated_server_mode")
		can_copy = can_copy and not is_dedicated
	if copy_room_code_button:
		copy_room_code_button.visible = can_copy
	if room_code_value:
		room_code_value.editable = false

	if can_copy:
		status_label.text = "Host room code available for sharing."
	else:
		status_label.text = "Room code copy is host-only."

func _on_copy_room_code_button_pressed() -> void:
	if lobby_node != null:
		var ac = lobby_node.get("active_room_code")
		if ac != null and ac != "":
			DisplayServer.clipboard_set(ac)
			status_label.text = "Room code copied to clipboard."
			return
	status_label.text = "No room code to copy yet."

func _on_lobby_state_updated(_room_code: String) -> void:
	_update_pause_menu_for_role()

func _on_disconnect_pressed() -> void:
	is_paused = false
	if pause_menu:
		pause_menu.visible = false
		await get_tree().process_frame
		get_tree().root.get_node("Main/Menu").visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().root.get_node("Main/Menu").visible = true
	NetworkManager.leave_session()

func _on_quit_game_pressed() -> void:
	NetworkManager.leave_session()
	get_tree().quit()

func _on_session_ended() -> void:
	is_paused = false
	if pause_menu:
		pause_menu.visible = true
		_update_pause_menu_for_role()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().root.get_node("Main/Menu").visible = true
