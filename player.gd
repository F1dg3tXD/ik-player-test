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

var horizontal_vel := Vector3.ZERO

@export var MOUSE_SENS := 0.002
@export var TURN_SPEED := 8.0
@export var PITCH_LIMIT := 80.0

var is_flying: bool = false
@export var FLY_SPEED := 8.0

var cam_yaw: float = 0.0
var cam_pitch: float = -15.0

#@onready var _camera := %Camera3D as Camera3D
@onready var _camera_pivot := %CameraPivot as Node3D

@export var stick_sensitivity := 2.5
@export var stick_deadzone := 0.15

@export_range(0.0, 1.0) var mouse_sensitivity = 0.01
@export var tilt_limit = deg_to_rad(75)

# Stuff that didn't work
#var dir_axis = walker.rotation.x // map to movement speed, +x rotation is forward
#var feet_dist = walker.scale.x // smooth range from 1 to 4 for side step
#var stride = walker.scale.z // smooth range from 1 to 7 based on movement speed
#var strafe_dir = walker.rotation.y // rotate y between 0 and -90 if strafing, where -x rotation is left and +x rotation is right. 

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	# Mouselook implemented using `screen_relative` for resolution-independent sensitivity.
	if event is InputEventMouseMotion:
		_camera_pivot.rotation.x -= event.screen_relative.y * mouse_sensitivity
		# Prevent the camera from rotating too far up or down.
		_camera_pivot.rotation.x = clampf(_camera_pivot.rotation.x, -tilt_limit, tilt_limit)
		_camera_pivot.rotation.y += -event.screen_relative.x * mouse_sensitivity

func _physics_process(delta: float) -> void:

	# -------------------------------------------------
	# INPUT
	# -------------------------------------------------

	var input: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_down",
		"move_up"
	)

	var look: Vector2 = Input.get_vector(
		"look_left",
		"look_right",
		"look_up",
		"look_down",
		stick_deadzone
	)

	if look != Vector2.ZERO:
		_camera_pivot.rotation.x -= look.y * stick_sensitivity * delta
		_camera_pivot.rotation.x = clampf(
			_camera_pivot.rotation.x,
			-tilt_limit,
			tilt_limit
		)
		_camera_pivot.rotation.y -= look.x * stick_sensitivity * delta


	# -------------------------------------------------
	# CAMERA RELATIVE MOVEMENT
	# -------------------------------------------------

	var pivot_basis: Basis = _camera_pivot.global_transform.basis
	var cam_forward: Vector3 = -pivot_basis.z
	var cam_right: Vector3 = pivot_basis.x

	if not is_flying:
		cam_forward.y = 0.0
		cam_right.y = 0.0

	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	var move_dir: Vector3 = cam_right * input.x + cam_forward * input.y
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

# --- VISUAL ROTATION (MODEL ONLY) ---
	if move_dir != Vector3.ZERO:
		var target_rot: float = atan2(move_dir.x, move_dir.z)

		# Forward input biases turning (prevents forced rotation while strafing)
		var face_strength: float = abs(input.y)

		player_mdl.rotation.y = lerp_angle(
			player_mdl.rotation.y,
			target_rot,
			delta * TURN_SPEED * face_strength
		)
	
	# -------------------------------------------------
	# MOVE
	# -------------------------------------------------

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
