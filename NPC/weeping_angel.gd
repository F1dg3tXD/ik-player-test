extends CharacterBody3D

@export var MOVE_SPEED := 3.0
@export var PLAYER_PATH : NodePath
@export var VIEW_THRESHOLD := 0.7
@export var VISIBILITY_RADIUS := 1.0
@export var TELEPORT_DISTANCE := 25.0
@export var TELEPORT_MIN_DISTANCE := 10.0
@export var MOVE_DELAY := 0.3
@export var MAX_TELEPORT_SLOPE_DOT := 0.7
@export var SEPARATION_RADIUS := 2.0
@export var SEPARATION_STRENGTH := 3.0
@export var TARGET_RING_RADIUS := 2.5
@export var ATTACK_RANGE := 3.2
@export var OCCLUSION_MASK := 1 << 2
@export var POSE_SWITCH_DELAY := 0.2

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

@onready var angel_attack: MeshInstance3D = $weepingAngelMdl/weepingAngel/Skeleton3D/AngelAttack
@onready var angel_idle: MeshInstance3D = $weepingAngelMdl/weepingAngel/Skeleton3D/Angelidle
@onready var angel_point: MeshInstance3D = $weepingAngelMdl/weepingAngel/Skeleton3D/AngelPoint
@onready var kill_trigger: Area3D = $KillTrigger

var player : CharacterBody3D
var player_camera : Camera3D
var unseen_timer := 0.0
var unseen_pose_timer := 0.0

var nav_map : RID
var nav_ready := false
var nav_iteration_id := 0

var current_state : AngelState = AngelState.IDLE
var current_role : AngelRole = AngelRole.PRESSURE

enum AngelState {IDLE, STALK, ATTACK}
enum AngelRole {PRESSURE, FLANK, AMBUSH}

func _ready():
	self.set_multiplayer_authority(1)
	player = get_tree().get_first_node_in_group("Player")
	player_camera = player.get_node("%Camera3D")
	nav_agent.avoidance_enabled = true
	nav_map = nav_agent.get_navigation_map()
	nav_iteration_id = NavigationServer3D.map_get_iteration_id(nav_map)
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)
	POSE_SWITCH_DELAY += randf_range(-0.05, 0.05)
	current_role = randi() % 3
	kill_trigger.body_entered.connect(_on_kill_trigger_entered)
	
func update_visual_state():
	angel_idle.visible = false
	angel_point.visible = false
	angel_attack.visible = false
	match current_state:
		AngelState.IDLE:
			angel_idle.visible = true
		AngelState.STALK:
			angel_point.visible = true
		AngelState.ATTACK:
			angel_attack.visible = true

func set_state(new_state: AngelState):
	if current_state == new_state:
		return
	current_state = new_state
	update_visual_state()
	
func update_state_logic(can_move: bool, delta: float):
	if player == null:
		return
	var dist = global_position.distance_to(player.global_position)
	var player_can_see_me = is_visible_to_player()
	if player_can_see_me:
		unseen_pose_timer = 0.0
		return
	unseen_pose_timer += delta
	if unseen_pose_timer < POSE_SWITCH_DELAY:
		return
	var attackers := 0
	for angel in get_tree().get_nodes_in_group("WeepingAngel"):
		if angel != self and angel.current_state == AngelState.ATTACK:
			attackers += 1
	var max_attackers := 1
	var desired_state : AngelState = current_state
	# --- Maintain attack (hysteresis) ---
	if current_state == AngelState.ATTACK:
		if dist <= ATTACK_RANGE + 0.3:
			desired_state = AngelState.ATTACK
		else:
			desired_state = AngelState.STALK
	# --- Try to enter attack ---
	elif dist <= ATTACK_RANGE:
		if attackers < max_attackers:
			desired_state = AngelState.ATTACK
		else:
			desired_state = AngelState.STALK
	# --- Normal behavior ---
	elif can_move:
		desired_state = AngelState.STALK
	else:
		desired_state = AngelState.IDLE
	set_state(desired_state)
	
func _on_kill_trigger_entered(body):
	if body.is_in_group("Player") and current_state == AngelState.ATTACK:
		trigger_jumpscare(body)
		
func trigger_jumpscare(player):
	set_physics_process(false)
	player.set_physics_process(false)
	set_state(AngelState.ATTACK)
	
	# Snap to face player
	look_at(player.global_position, Vector3.UP)
	
	# Play animation here


func is_visible_to_player() -> bool:
	if player_camera == null:
		return false
	var space_state = get_world_3d().direct_space_state
	var cam_pos = player_camera.global_transform.origin
	var offsets = [
		Vector3(0, VISIBILITY_RADIUS, 0),
		Vector3(0, -VISIBILITY_RADIUS, 0),
		Vector3(VISIBILITY_RADIUS, 0, 0),
		Vector3(-VISIBILITY_RADIUS, 0, 0),
		Vector3(0, 0, VISIBILITY_RADIUS),
		Vector3(0, 0, -VISIBILITY_RADIUS)
	]
	for offset in offsets:
		var sample_point = global_transform.origin + offset
		# Skip if outside frustum
		if not player_camera.is_position_in_frustum(sample_point):
			continue
		var query = PhysicsRayQueryParameters3D.create(cam_pos, sample_point)
		query.collision_mask = OCCLUSION_MASK
		query.exclude = [self, player]
		var result = space_state.intersect_ray(query)
		# If nothing blocks this sample → visible
		if result.is_empty():
			return true
	return false

func _on_nav_map_changed(changed_map):
	if changed_map == nav_map:
		var new_id = NavigationServer3D.map_get_iteration_id(nav_map)
		if new_id != nav_iteration_id:
			nav_iteration_id = new_id
			nav_ready = true

func is_fully_outside_view() -> bool:
	var center = global_transform.origin
	# Check multiple sample points
	var offsets = [
		Vector3(0, VISIBILITY_RADIUS, 0),
		Vector3(0, -VISIBILITY_RADIUS, 0),
		Vector3(VISIBILITY_RADIUS, 0, 0),
		Vector3(-VISIBILITY_RADIUS, 0, 0),
		Vector3(0, 0, VISIBILITY_RADIUS),
		Vector3(0, 0, -VISIBILITY_RADIUS)
	]
	for offset in offsets:
		if player_camera.is_position_in_frustum(center + offset):
			return false
	return true
	
func teleport_closer():
	if not nav_ready:
		return
	# Reject if player not on navmesh.
	var player_nav_point = NavigationServer3D.map_get_closest_point(nav_map, player.global_position)
	if player.global_position.distance_to(player_nav_point) > 1.5:
		return  # Screw you, now I don't wanna do it.
	var dir = (global_position - player.global_position).normalized()
	var raw_target = player.global_position + dir * TELEPORT_MIN_DISTANCE
	var safe_target = NavigationServer3D.map_get_closest_point(nav_map, raw_target)
	# Ensure teleport target is actually on navmesh
	if raw_target.distance_to(safe_target) > 1.0:
		return
	# Ensure reachable
	nav_agent.target_position = safe_target
	if not nav_agent.is_target_reachable():
		return
	global_position.x = safe_target.x
	global_position.z = safe_target.z

func any_angel_visible() -> bool:
	for angel in get_tree().get_nodes_in_group("WeepingAngel"):
		if angel.is_visible_to_player():
			return true
	return false

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		if velocity.y < 0:
			velocity.y = 0

func handle_teleport():
	var dist = global_position.distance_to(player.global_position)
	if not nav_ready:
		return
	if dist > TELEPORT_DISTANCE and is_fully_outside_view():
		teleport_closer()

func clamp_to_navmesh():
	if not nav_ready:
		return
	var closest = NavigationServer3D.map_get_closest_point(nav_map, global_position)
	# Only correct horizontal position
	global_position.x = closest.x
	global_position.z = closest.z

func compute_separation() -> Vector3:
	var push = Vector3.ZERO
	for angel in get_tree().get_nodes_in_group("WeepingAngel"):
		if angel == self:
			continue
		var diff = global_position - angel.global_position
		diff.y = 0
		var dist = diff.length()
		if dist < SEPARATION_RADIUS and dist > 0.01:
			push += diff.normalized() * (SEPARATION_RADIUS - dist)
	return push * SEPARATION_STRENGTH

func _physics_process(delta):
	if player == null:
		return
	apply_gravity(delta)
	handle_teleport()
	var can_move = should_move(delta)
	if can_move:
		move_toward_player(delta)
	else:
		stop_horizontal()
	# Update visual state AFTER movement decision
	update_state_logic(can_move, delta)
	move_and_slide()
	clamp_to_navmesh()

func should_move(delta) -> bool:
	if is_visible_to_player():
		unseen_timer = 0.0
		return false
	unseen_timer += delta
	return unseen_timer > MOVE_DELAY

func stop_horizontal():
	velocity.x = 0
	velocity.z = 0

func move_toward_player(delta):
	var to_player = (global_position - player.global_position).normalized()
	var offset_target : Vector3
	match current_role:
		AngelRole.PRESSURE:
			offset_target = player.global_position + to_player * TARGET_RING_RADIUS
		AngelRole.FLANK:
			var side = to_player.cross(Vector3.UP).normalized()
			offset_target = player.global_position + (to_player * TARGET_RING_RADIUS) + side * 2.0
		AngelRole.AMBUSH:
			offset_target = player.global_position - to_player * (TARGET_RING_RADIUS + 2.0)
	nav_agent.target_position = offset_target
	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position)
	direction.y = 0
	if direction.length() > 0.1:
		direction = direction.normalized()
		var sep = compute_separation()
		var final_dir = (direction + sep).normalized()
		velocity.x = final_dir.x * MOVE_SPEED
		velocity.z = final_dir.z * MOVE_SPEED
		var target_rot = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, delta * 5.0)
