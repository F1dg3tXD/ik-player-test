extends Node2D

# Server/Host List Stuff
@onready var server_list_v_box_container: VBoxContainer = $Control/Menu/ServerListVBoxContainer
@onready var server_button_instance: Button = $Control/Menu/ServerListVBoxContainer/ServerButtonInstance

# Player List stuff (per server/host)
@onready var player_list_v_box_container: VBoxContainer = %PlayerListVBoxContainer
@onready var player_info_h_box_container: HBoxContainer = %PlayerInfoHBoxContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
