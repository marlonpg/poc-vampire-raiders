extends Node2D
class_name DamageNumber

var damage: int = 0
var lifetime: float = 1.5
var elapsed: float = 0.0
var fade_start: float = 1.0

var label: Label = Label.new()

func _ensure_label():
	if label == null:
		label = Label.new()
	if label.get_parent() == null:
		add_child(label)

func _ready():
	_ensure_label()
	label.text = str(damage)
	label.add_theme_font_size_override("font_sizes/font_size", 48)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	await get_tree().process_frame
	var sz = label.get_rect().size
	label.position = -sz / 2

func _process(delta):
	elapsed += delta
	position.y -= 50 * delta
	if elapsed > fade_start:
		var alpha = 1.0 - ((elapsed - fade_start) / (lifetime - fade_start))
		label.modulate.a = alpha
	if elapsed >= lifetime:
		queue_free()

func set_damage(value: int, is_player_damage: bool = false):
	_ensure_label()
	damage = value
	label.text = str(damage)
	if is_player_damage:
		label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		label.add_theme_color_override("font_color", Color.RED)
