extends Node2D

func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		_spawn_single_player()

func _spawn_single_player() -> void:
	var player_scene = preload("res://scenes/player/Player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player"
	player.global_position = Vector2.ZERO
	add_child(player)
	print("Single player spawned!")
