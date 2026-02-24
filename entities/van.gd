extends Node3D

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var player_trigger: Area3D = $PlayerTrigger

var is_open: bool = false
var players_inside: int = 0

func _ready() -> void:
	# Ensure signals are connected (in case not connected in editor)
	player_trigger.body_entered.connect(_on_player_trigger_body_entered)
	player_trigger.body_exited.connect(_on_player_trigger_body_exited)
	
	# Server controls initial state
	if multiplayer.is_server():
		set_door_state(false)

func _on_player_trigger_body_entered(body: Node) -> void:
	if !multiplayer.is_server():
		return
	
	if body.is_in_group("Player"):
		players_inside += 1
		print("Player entered Van trigger:", body.name)
		_update_door_state()

func _on_player_trigger_body_exited(body: Node) -> void:
	if !multiplayer.is_server():
		return
	
	if body.is_in_group("Player"):
		players_inside = max(players_inside - 1, 0)
		print("Player exited Van trigger:", body.name)
		_update_door_state()

func _update_door_state() -> void:
	var should_open := players_inside > 0
	
	if should_open != is_open:
		set_door_state(should_open)

func set_door_state(open: bool) -> void:
	is_open = open
	
	# Server updates itself immediately
	_apply_door_animation(is_open)
	
	# Then sync to all clients
	rpc("sync_door_state", is_open)

@rpc("authority", "call_local")
func sync_door_state(open: bool) -> void:
	is_open = open
	_apply_door_animation(is_open)

func _apply_door_animation(open: bool) -> void:
	var state_machine = animation_tree.get("parameters/playback")
	
	if open:
		state_machine.travel("van_doors_open")
	else:
		state_machine.travel("van_doors_close")
