extends Node2D
class_name DamageNumber

var damage: int = 0
var lifetime: float = 1.5
var elapsed: float = 0.0
var fade_start: float = 1.0

@onready var label: Label = Label.new()

func _ready():
    print("[SHOW DMG] _ready IT")
	label.text = str(damage)
	label.add_theme_font_size_override("font_sizes/font_size", 32)
	label.add_theme_color_override("font_color", Color.RED)
	add_child(label)
	label.offset = Vector2(-20, -20)

func _process(delta):
    print("[SHOW DMG] _process IT")
	elapsed += delta
	position.y -= 50 * delta  # Float upward
	
	# Fade out in the last 0.5 seconds
	if elapsed > fade_start:
		var alpha = 1.0 - ((elapsed - fade_start) / (lifetime - fade_start))
		label.modulate.a = alpha
	
	if elapsed >= lifetime:
		queue_free()

func set_damage(value: int, is_player_damage: bool = false):
    print("[SHOW DMG] SETTING IT")
	damage = value
	if is_player_damage:
		label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		label.add_theme_color_override("font_color", Color.RED)
