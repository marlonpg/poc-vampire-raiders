extends ColorRect

@export var inventory_index: int = -1
@export var item_data: Dictionary = {}
var parent_inventory_ui: Node = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = _build_tooltip()

func _build_tooltip() -> String:
	var parts: Array[String] = []
	parts.append("%s (%s)" % [item_data.get("name", "Item"), item_data.get("rarity", "common")])
	if item_data.has("type"):
		parts.append("Type: %s" % item_data.get("type"))
	if item_data.has("damage") and int(item_data.get("damage", 0)) > 0:
		parts.append("Damage: %d" % int(item_data.get("damage", 0)))
	if item_data.has("defense") and int(item_data.get("defense", 0)) > 0:
		parts.append("Defense: %d" % int(item_data.get("defense", 0)))
	return "\n".join(parts)

func get_drag_data(at_position: Vector2):
	var data := {
		"from_index": inventory_index,
		"item": item_data
	}
	var preview := Label.new()
	preview.text = item_data.get("name", "Item")
	preview.add_theme_font_size_override("font_size", 12)
	preview.modulate = Color(1,1,1,0.9)
	preview.size = Vector2(80, 24)
	preview.add_theme_color_override("font_color", Color(1,1,0))
	set_drag_preview(preview)
	return data

func gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.double_click and mbe.button_index == MOUSE_BUTTON_LEFT:
			if parent_inventory_ui and parent_inventory_ui.has_method("_request_drop_from_inventory"):
				parent_inventory_ui._request_drop_from_inventory(inventory_index)
