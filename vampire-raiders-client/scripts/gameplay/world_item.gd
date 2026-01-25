extends Area2D

@export var item_id: int
@export var item_name: String = "Item"

@onready var label: Label = $Label
@onready var color_rect: ColorRect = $ColorRect

var sprite_rect: TextureRect = null
var quantity: int = 1

var has_mods: bool = false

# Background behind the item name text (always black)
var name_bg: ColorRect = null

# Map item names to text colors; default is white if not found
var name_color_map := {
	"Gold Coin": Color(1, 1, 0, 1)  # yellow
}

const TILE_HALF := 16
const LABEL_SPACING := 2

func _ready():
	label.text = item_name
	color_rect.color = Color(0.8, 0.6, 0.2, 0.9)

	# Ensure name label has a black background and mapped text color
	_create_name_background()
	_apply_name_style()
	_update_name_bg()
	# Keep background in sync with label size changes
	if not label.resized.is_connected(_update_name_bg):
		label.resized.connect(_update_name_bg)
	_load_sprite_if_available()
	_position_name_above_item()

func _get_label() -> Label:
	# `set_has_mods` (and other setters) can be called immediately after instancing,
	# before this node is inside the scene tree, so @onready vars may still be null.
	if label != null:
		return label
	label = get_node_or_null("Label")
	return label

func _load_sprite_if_available() -> void:
	# Avoid reloading if we already have the sprite
	if sprite_rect != null:
		return
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

	# Reposition the label/background after loading (or failing to load) the sprite
	_position_name_above_item()

func _create_name_background() -> void:
	var lbl := _get_label()
	if lbl == null:
		return
	if name_bg == null:
		name_bg = ColorRect.new()
		name_bg.color = Color(0, 0, 0, 0.50)  # black, slightly transparent
		name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Place behind label
		name_bg.z_index = 2
		add_child(name_bg)
		# Ensure label renders above background
		lbl.z_index = 3

func _apply_name_style() -> void:
	var lbl := _get_label()
	if lbl == null:
		return
	# If item has mods, its name should be blue (unless an explicit mapping exists)
	if has_mods and not name_color_map.has(item_name):
		lbl.add_theme_color_override("font_color", Color(0.40, 0.70, 1.00, 1))
		return
	# Set text color based on the item name mapping; default to white
	var col: Color = name_color_map.get(item_name, Color(1, 1, 1, 1))
	lbl.add_theme_color_override("font_color", col)

func _update_name_bg() -> void:
	var lbl := _get_label()
	if name_bg == null or lbl == null:
		return
	# Size background to content siaze (no padding)
	var content = lbl.get_minimum_size()
	if content == Vector2.ZERO:
		content = lbl.size
	name_bg.size = content
	# Position background exactly under the label
	name_bg.position = lbl.position

func _position_name_above_item() -> void:
	var lbl := _get_label()
	if lbl == null:
		return
	# Center the label horizontally and place it above the item sprite
	var content = lbl.get_minimum_size()
	if content == Vector2.ZERO:
		content = lbl.size
	var y_base := -TILE_HALF if sprite_rect != null else 0
	lbl.position = Vector2(-content.x / 2.0, y_base - content.y - LABEL_SPACING)
	_update_name_bg()

func set_name_and_color(name: String):
	if item_name == name:
		# Name unchanged; skip re-applying styles and sprite load
		return
	item_name = name
	var lbl := _get_label()
	if lbl != null:
		lbl.text = name
	_apply_name_style()
	_update_name_bg()
	_position_name_above_item()
	_load_sprite_if_available()

func set_highlight(active: bool):
	color_rect.modulate = active if Color(1, 1, 1, 1) else Color(1, 1, 1, 0.8)

func set_quantity(qty: int) -> void:
	quantity = qty
	var lbl := _get_label()
	if lbl == null:
		return
	# Update label to show quantity if more than 1
	if quantity > 1:
		lbl.text = "%s (x%d)" % [item_name, quantity]
	else:
		lbl.text = item_name
	_apply_name_style()
	_update_name_bg()
	_position_name_above_item()

func set_has_mods(value: bool) -> void:
	if has_mods == value:
		return
	has_mods = value
	_apply_name_style()
	_update_name_bg()
