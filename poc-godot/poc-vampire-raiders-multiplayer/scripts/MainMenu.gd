extends Control

func _on_enter_dungeon_pressed():
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_inventory_pressed():
	print("Inventory selected")

func _on_character_pressed():
	print("Character selected")
