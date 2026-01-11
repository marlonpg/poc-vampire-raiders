extends Area2D

@export var item_id: int
@export var item_name: String = "Item"

@onready var label: Label = $Label
@onready var color_rect: ColorRect = $ColorRect

var sprite_rect: TextureRect = null
var quantity: int = 1

func _ready():
	label.text = item_name
	color_rect.color = Color(0.8, 0.6, 0.2, 0.9)
	_load_sprite_if_available()

func _load_sprite_if_available() -> void:
	# Try to load sprite based on item name (convert to snake_case)
	var item_name_snake = item_name.to_lower().replace(" ", "-")
	var sprite_path = "res://assets/items/%s.png" % item_name_snake
	
	# Check if the sprite exists
	if ResourceLoader.exists(sprite_path):
		print("[WorldItem] Loading sprite for %s from %s" % [item_name, sprite_path])
		
		# Create a TextureRect to display the sprite
		sprite_rect = TextureRect.new()
		sprite_rect.texture = load(sprite_path)
		sprite_rect.anchor_left = 0.5
		sprite_rect.anchor_top = 0.5
		sprite_rect.anchor_right = 0.5
		sprite_rect.anchor_bottom = 0.5
		sprite_rect.offset_left = -16
		sprite_rect.offset_top = -16
		sprite_rect.offset_right = 16
		sprite_rect.offset_bottom = 16
		sprite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Add sprite as child (will appear on top of color rect)
		add_child(sprite_rect)
		sprite_rect.z_index = 1
		
		# Hide the color rect since we have a sprite
		color_rect.hide()
	else:
		print("[WorldItem] Sprite not found for %s at %s, using color background" % [item_name, sprite_path])

func set_name_and_color(name: String):
	item_name = name
	label.text = name
	_load_sprite_if_available()

func set_highlight(active: bool):
	color_rect.modulate = active if Color(1, 1, 1, 1) else Color(1, 1, 1, 0.8)

func set_quantity(qty: int) -> void:
	quantity = qty
	# Update label to show quantity if more than 1
	if quantity > 1:
		label.text = "%s (x%d)" % [item_name, quantity]
	else:
		label.text = item_name
