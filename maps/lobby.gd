extends Node3D

var _players_parent: Node3D

func _ready() -> void:
	_get_players_parent()

	if multiplayer.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _get_players_parent() -> Node3D:
	if _players_parent and is_instance_valid(_players_parent):
		return _players_parent
	var root = get_tree().root
	if root.has_node("World/Players"):
		_players_parent = root.get_node("World/Players")
	return _players_parent

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		var parent := _get_players_parent()
		if parent:
			var player = parent.get_node_or_null(str(id))
			if player:
				player.queue_free()
