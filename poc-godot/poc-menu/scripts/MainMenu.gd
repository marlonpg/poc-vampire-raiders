extends Control

func _on_enter_dungeon_pressed():
	print("Enter Dungeon selected")
	# get_tree().change_scene_to_file("res://scenes/dungeon.tscn")

func _on_inventory_pressed():
	print("Inventory selected")
	# get_tree().change_scene_to_file("res://scenes/inventory.tscn")

func _on_character_pressed():
	print("Character selected")
	# get_tree().change_scene_to_file("res://scenes/character.tscn")
