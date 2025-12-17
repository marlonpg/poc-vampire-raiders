extends CanvasLayer

@onready var loot_label = $Panel/VBoxContainer/LootLabel
@onready var restart_button = $Panel/VBoxContainer/RestartButton

func _ready() -> void:
	hide()
	restart_button.pressed.connect(_on_restart_pressed)

func show_win(loot_value: int) -> void:
	get_tree().paused = true
	loot_label.text = "Loot Value: $%d" % loot_value
	show()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
