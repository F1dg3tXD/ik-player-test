extends CharacterBody3D

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

#Steam Stuff
@onready var display_name: Label = $SteamName/displayName
@onready var avatar_sprite: Sprite2D = $SteamIcon/avatarSprite

var personaName := Steam.getPersonaName()

# For later multiplayer
#Steam.getPlayerAvatar(remote_steam_id, Steam.AVATAR_MEDIUM)

func _ready() -> void:
	if is_multiplayer_authority():
		await get_tree().process_frame
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Steam.getPlayerAvatar(Steam.AVATAR_LARGE)
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	display_name.text = personaName
	
	if is_multiplayer_authority():
		player_mdl.visible = true
		beta_joints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		beta_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		camera_3d.current = true
	else:
		camera_3d.current = false
	
func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	print("Avatar for user: %s" % user_id)
	print("Size: %s" % avatar_size)
	# Check if user exists
	if user_id != Steam.getSteamID():
		return
	# Create the image and texture for loading
	var avatar_image: Image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	# Optionally resize the image if it is too large
	avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	# Apply the image to a texture
	var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	# Set the texture to a Sprite, TextureRect, etc.
	avatar_sprite.set_texture(avatar_texture)

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

func set_fly_mode(enabled: bool) -> void:
	is_flying = enabled
	
	if is_flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
	velocity = Vector3.ZERO
	
@rpc("authority", "call_local")
func apply_color(color: Color):
	$MeshInstance3D.material_override.albedo_color = color
