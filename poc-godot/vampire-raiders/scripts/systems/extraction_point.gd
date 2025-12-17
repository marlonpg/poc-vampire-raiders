extends Area2D

@export var extraction_time: float = 5.0
@export var active: bool = false

var extracting: bool = false
var extraction_timer: float = 0.0
var player_in_zone: Node2D = null

signal extraction_started
signal extraction_complete
signal extraction_cancelled

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if not active:
		modulate = Color(0.5, 0.5, 0.5, 0.5)

func _process(delta: float) -> void:
	if not active:
		return
	
	if extracting and player_in_zone:
		extraction_timer += delta
		if extraction_timer >= extraction_time:
			_complete_extraction()
	
	if player_in_zone and Input.is_action_just_pressed("ui_accept"):
		if not extracting:
			_start_extraction()

func activate() -> void:
	active = true
	modulate = Color(1, 1, 1, 1)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and active:
		player_in_zone = body
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("set_extraction_point"):
			hud.set_extraction_point(self)

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_zone:
		if extracting:
			_cancel_extraction()
		player_in_zone = null

func _start_extraction() -> void:
	extracting = true
	extraction_timer = 0.0
	extraction_started.emit()
	print("Extraction started! Stay in zone for %d seconds" % extraction_time)

func _cancel_extraction() -> void:
	extracting = false
	extraction_timer = 0.0
	extraction_cancelled.emit()
	print("Extraction cancelled!")

func _complete_extraction() -> void:
	extracting = false
	extraction_complete.emit()
	
	var player = get_tree().get_first_node_in_group("player")
	var win_screen = get_tree().get_first_node_in_group("win_screen")
	
	if player and win_screen:
		var inventory = player.get_node_or_null("Inventory")
		var loot_value = inventory.get_total_value() if inventory else 0
		win_screen.show_win(loot_value)
