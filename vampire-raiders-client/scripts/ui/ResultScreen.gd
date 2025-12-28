extends Control

func _ready():
	var button = $CenterContainer/Panel/VBoxContainer/BackToMenuButton
	if button:
		button.grab_focus()

func _on_back_to_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
