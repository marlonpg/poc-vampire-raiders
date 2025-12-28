extends ColorRect

@export var slot_type: String = ""
@export var item_data: Dictionary = {}
var parent_inventory_ui: Node = null

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tooltip = _build_tooltip()
	tooltip_text = tooltip
	focus_mode = Control.FOCUS_ALL

func _input(event: InputEvent) -> void:
	# Only process if event is a mouse button or touch event
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		# Check if this event is within this item's bounds
		var pos = event.position if "position" in event else Vector2.ZERO
		if get_global_rect().has_point(pos):
			gui_input(event)

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

func gui_input(event: InputEvent) -> void:
	# Handle mouse button clicks
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		var mouse_in_rect = get_global_rect().has_point(mbe.position)
		
		# Only handle if click is actually on this item
		if not mouse_in_rect:
			return
		
		# Handle drag for single clicks
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				# Start drag - store a marker for equipped item drag
				if parent_inventory_ui and parent_inventory_ui.has_method("_set_dragging_equipped"):
					parent_inventory_ui._set_dragging_equipped(slot_type)
			else:
				# Mouse released - check where we released
				if parent_inventory_ui and parent_inventory_ui.has_method("_get_dragging_equipped"):
					var drag_slot = parent_inventory_ui._get_dragging_equipped()
					if drag_slot != "":
						# Check if mouse is over an inventory cell
						var inventory_grid = parent_inventory_ui.grid_container
						var mouse_pos = get_global_mouse_position()
						var inventory_cell_index = -1
						
						for i in range(inventory_grid.get_child_count()):
							var cell = inventory_grid.get_child(i)
							if cell and cell.get_global_rect().has_point(mouse_pos):
								inventory_cell_index = i
								break
						
						if inventory_cell_index >= 0:
							# Released over inventory - move item back to inventory
							parent_inventory_ui._unequip_item_to_inventory_at_index(drag_slot, inventory_cell_index)
						else:
							# Released somewhere else - just unequip to first available slot
							parent_inventory_ui._unequip_item_to_inventory(drag_slot)
					
					parent_inventory_ui._set_dragging_equipped("")
			return
