# player.gd
extends CharacterBody3D

class_name Player

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
var _profile_synced := false

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

# Player color 
var beta_joints_mat := StandardMaterial3D.new()
var beta_surface_mat := StandardMaterial3D.new()
var _player_color: Color = Color(0.612501, 0.38787553, 0.35089412)

func _enter_tree() -> void:
	var peer_id := str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)

func _ready() -> void:
	beta_joints_mat.albedo_color = _player_color
	beta_surface_mat.albedo_color = _player_color
	beta_joints.set_surface_override_material(0, beta_joints_mat)
	beta_surface.set_surface_override_material(0, beta_surface_mat)
	_apply_player_color(_player_color)

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
	else:
		camera_3d.current = false
		_remote_position_target = global_position
		_remote_body_yaw_target = rotation.y
		_remote_head_pitch_target = head.rotation.x

	_try_sync_profile()

func _process(delta: float) -> void:
	if is_multiplayer_authority():
		return
	global_position = global_position.lerp(_remote_position_target, clamp(delta * remote_position_lerp_speed, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _remote_body_yaw_target, clamp(delta * remote_rotation_lerp_speed, 0.0, 1.0))
	head.rotation.x = lerp_angle(head.rotation.x, _remote_head_pitch_target, clamp(delta * remote_rotation_lerp_speed, 0.0, 1.0))

func _on_multiplayer_authority_changed() -> void:
	_try_sync_profile()

func _try_sync_profile() -> void:
	if _profile_synced or not is_multiplayer_authority():
		return
	_profile_synced = true
	_sync_profile.rpc(ProfileManager.username, ProfileManager.get_icon_png_buffer())

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
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
	_receive_state.rpc(global_position, rotation.y, head.rotation.x)

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

@rpc("authority", "call_local", "reliable")
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

@rpc("authority", "call_local", "unreliable_ordered")
func _receive_state(world_pos: Vector3, body_yaw: float, head_pitch: float) -> void:
	if is_multiplayer_authority():
		return
	_remote_position_target = world_pos
	_remote_body_yaw_target = body_yaw
	_remote_head_pitch_target = head_pitch

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

func _on_color_changed(new_color: Color) -> void:
	_player_color = new_color
	_apply_player_color(new_color)
	replicate_color.rpc(new_color)

@rpc("authority", "call_local")
func replicate_color(color: Color) -> void:
	_player_color = color
	_apply_player_color(color)

func _apply_player_color(color: Color) -> void:
	beta_joints_mat.albedo_color = color
	beta_surface_mat.albedo_color = color
