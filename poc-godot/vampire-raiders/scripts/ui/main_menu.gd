extends Control

@onready var single_player_button = $Panel/VBoxContainer/SinglePlayerButton
@onready var multiplayer_button = $Panel/VBoxContainer/MultiplayerButton

func _ready() -> void:
	single_player_button.pressed.connect(_on_single_player_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_pressed)

func _on_single_player_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/GameWorld.tscn")

func _on_multiplayer_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/NetworkMenu.tscn")
