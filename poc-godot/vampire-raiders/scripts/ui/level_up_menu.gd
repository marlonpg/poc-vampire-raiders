extends CanvasLayer

signal upgrade_selected(upgrade_type: String)

@onready var panel = $Panel
@onready var option1 = $Panel/VBoxContainer/Option1
@onready var option2 = $Panel/VBoxContainer/Option2
@onready var option3 = $Panel/VBoxContainer/Option3

var upgrades = [
	{"id": "fire_rate", "name": "Faster Attacks", "desc": "-20% cooldown"},
	{"id": "damage", "name": "More Damage", "desc": "+2 damage"},
	{"id": "speed", "name": "Move Speed", "desc": "+50 speed"},
	{"id": "max_health", "name": "Max Health", "desc": "+20 max HP"},
	{"id": "weapon_range", "name": "Weapon Range", "desc": "+2 squares range"}
]

func _ready() -> void:
	hide()
	option1.pressed.connect(func(): _on_option_selected(0))
	option2.pressed.connect(func(): _on_option_selected(1))
	option3.pressed.connect(func(): _on_option_selected(2))

func show_upgrades() -> void:
	get_tree().paused = true
	show()
	
	var available = upgrades.duplicate()
	available.shuffle()
	
	option1.text = "%s\n%s" % [available[0].name, available[0].desc]
	option1.set_meta("upgrade", available[0].id)
	
	option2.text = "%s\n%s" % [available[1].name, available[1].desc]
	option2.set_meta("upgrade", available[1].id)
	
	option3.text = "%s\n%s" % [available[2].name, available[2].desc]
	option3.set_meta("upgrade", available[2].id)

func _on_option_selected(index: int) -> void:
	var button = [option1, option2, option3][index]
	var upgrade = button.get_meta("upgrade")
	upgrade_selected.emit(upgrade)
	get_tree().paused = false
	hide()
