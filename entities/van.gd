extends Node3D

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var player_trigger: Area3D = $PlayerTrigger

var is_open: bool = false
var players_inside: int = 0

func _ready() -> void:
	if multiplayer.is_server():
		set_door_state(false)

func _on_player_trigger_body_entered(body: Node3D) -> void:
	if !multiplayer.is_server():
		return
	
	if body.is_in_group("Player"):
		players_inside += 1
		update_door_state()

func _on_player_trigger_body_exited(body: Node3D) -> void:
	if !multiplayer.is_server():
		return
	
	if body.is_in_group("Player"):
		players_inside -= 1
		update_door_state()

func update_door_state():
	var should_open = players_inside > 0
	
	if should_open != is_open:
		set_door_state(should_open)

func set_door_state(open: bool):
	is_open = open
	
	# Server tells everyone to update animation
	rpc("sync_door_state", is_open)

@rpc("authority", "call_local")
func sync_door_state(open: bool):
	is_open = open
	animation_tree.set("parameters/conditions/is_open", is_open)
