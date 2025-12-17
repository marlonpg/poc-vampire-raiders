extends CanvasLayer

@onready var level_label = $LevelLabel
@onready var xp_bar = $XPBar
@onready var health_bar = $HealthBar
@onready var level_up_menu = $LevelUpMenu

var player: CharacterBody2D

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.level_up.connect(_on_player_level_up)
		player.health_changed.connect(_on_player_health_changed)
	
	if level_up_menu:
		level_up_menu.upgrade_selected.connect(_on_upgrade_selected)

func _process(_delta: float) -> void:
	if player:
		level_label.text = "Level: %d" % player.level
		xp_bar.value = float(player.xp) / float(player.xp_to_next_level) * 100.0
		health_bar.value = float(player.health) / float(player.max_health) * 100.0

func _on_player_level_up(new_level: int) -> void:
	if level_up_menu:
		level_up_menu.show_upgrades()

func _on_upgrade_selected(upgrade_type: String) -> void:
	if player:
		player.apply_upgrade(upgrade_type)

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_bar.value = float(current_health) / float(max_health) * 100.0
