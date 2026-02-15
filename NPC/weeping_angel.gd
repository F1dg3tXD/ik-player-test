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

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var player : CharacterBody3D
var player_camera : Camera3D
var unseen_timer := 0.0

var nav_map : RID
var nav_ready := false
var nav_iteration_id := 0

func _ready():
	player = get_tree().get_first_node_in_group("Player")
	player_camera = player.get_node("%Camera3D")
	nav_agent.avoidance_enabled = true
	nav_map = nav_agent.get_navigation_map()
	nav_iteration_id = NavigationServer3D.map_get_iteration_id(nav_map)
	NavigationServer3D.map_changed.connect(_on_nav_map_changed)

func is_visible_to_player() -> bool:
	if player_camera == null:
		return false
	# 1. Completely outside frustum?
	if not player_camera.is_position_in_frustum(global_transform.origin):
		return false
	# 2. Raycast visibility check
	var space_state = get_world_3d().direct_space_state
	var cam_pos = player_camera.global_transform.origin
	var target_pos = global_transform.origin
	var query = PhysicsRayQueryParameters3D.create(cam_pos, target_pos)
	# Ignore self AND player because the HL2 source code taught me well.
	query.exclude = [self, player]
	var result = space_state.intersect_ray(query)
	# If something blocks it, it's hidden
	if result:
		return false
	return true

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
		pass
	apply_gravity(delta)
	handle_teleport()
	var can_move = should_move(delta)
	if can_move:
		move_toward_player(delta)
	else:
		stop_horizontal()
	move_and_slide()
	clamp_to_navmesh()

func should_move(delta) -> bool:
	# Freeze if ANY angel visible
	if any_angel_visible():
		unseen_timer = 0.0
		return false
	# Freeze if this angel visible
	if is_visible_to_player():
		unseen_timer = 0.0
		return false
	# Only move if fully outside view
	if is_fully_outside_view():
		unseen_timer += delta
	else:
		unseen_timer = 0.0
	return unseen_timer > MOVE_DELAY
	
func stop_horizontal():
	velocity.x = 0
	velocity.z = 0

func move_toward_player(delta):
	var to_player = (global_position - player.global_position).normalized()
	var offset_target = player.global_position + to_player * TARGET_RING_RADIUS
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
