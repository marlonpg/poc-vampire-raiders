extends CanvasLayer

@onready var level_label = $LevelLabel
@onready var xp_bar = $XPBar
@onready var health_bar = $HealthBar
@onready var level_up_menu = $LevelUpMenu
@onready var timer_label = $TimerLabel
@onready var extraction_bar = $ExtractionBar

var player: CharacterBody2D
var game_manager: Node
var extraction_point: Area2D

func _ready() -> void:
	add_to_group("hud")
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.level_up.connect(_on_player_level_up)
		player.health_changed.connect(_on_player_health_changed)
	
	if level_up_menu:
		level_up_menu.upgrade_selected.connect(_on_upgrade_selected)
	
	game_manager = get_tree().get_first_node_in_group("game_manager")
	extraction_bar.visible = false

func _process(_delta: float) -> void:
	if player:
		level_label.text = "Level: %d" % player.level
		xp_bar.value = float(player.xp) / float(player.xp_to_next_level) * 100.0
		health_bar.value = float(player.health) / float(player.max_health) * 100.0
	
	if game_manager:
		var time_left = game_manager.get_time_until_extraction()
		if time_left > 0:
			timer_label.text = "Extraction in: %d s" % int(time_left)
		else:
			timer_label.text = "Extraction Available!"
	
	if extraction_point and extraction_point.extracting:
		extraction_bar.visible = true
		extraction_bar.value = (extraction_point.extraction_timer / extraction_point.extraction_time) * 100.0
	else:
		extraction_bar.visible = false

func _on_player_level_up(new_level: int) -> void:
	if level_up_menu:
		level_up_menu.show_upgrades()

func _on_upgrade_selected(upgrade_type: String) -> void:
	if player:
		player.apply_upgrade(upgrade_type)

func set_extraction_point(point: Area2D) -> void:
	extraction_point = point

func _on_player_health_changed(current_health: int, max_health: int) -> void:
	health_bar.value = float(current_health) / float(max_health) * 100.0
