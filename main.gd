extends Node2D

@onready var id_prompt: LineEdit = $main/VBoxContainer/id_prompt

func _on_btn_host_pressed() -> void:
	NetworkManager.host_game()

func _on_btn_join_pressed() -> void:
	NetworkManager.join_game(id_prompt.text.strip_edges())
