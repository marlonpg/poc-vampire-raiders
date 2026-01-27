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
	var mods = item_data.get("mods", [])
	if typeof(mods) == TYPE_ARRAY and mods.size() > 0:
		for m in mods:
			if typeof(m) == TYPE_DICTIONARY:
				parts.append("Mod: %s" % m.get("mod_name", ""))
	return "\n".join(parts)

func _make_custom_tooltip(_for_text):
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	panel.add_child(vb)

	var title := Label.new()
	title.text = "%s (%s)" % [item_data.get("name", "Item"), item_data.get("rarity", "common")]
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)

	if item_data.has("type"):
		var type_lbl := Label.new()
		type_lbl.text = "Type: %s" % item_data.get("type")
		vb.add_child(type_lbl)

	if item_data.has("damage") and int(item_data.get("damage", 0)) > 0:
		var dmg_lbl := Label.new()
		dmg_lbl.text = "Damage: %d" % int(item_data.get("damage", 0))
		vb.add_child(dmg_lbl)

	if item_data.has("defense") and int(item_data.get("defense", 0)) > 0:
		var def_lbl := Label.new()
		def_lbl.text = "Defense: %d" % int(item_data.get("defense", 0))
		vb.add_child(def_lbl)

	var mods = item_data.get("mods", [])
	if typeof(mods) == TYPE_ARRAY and mods.size() > 0:
		for m in mods:
			if typeof(m) != TYPE_DICTIONARY:
				continue
			var mod_lbl := Label.new()
			mod_lbl.text = "Mod: %s" % m.get("mod_name", "")
			mod_lbl.add_theme_color_override("font_color", Color(0.40, 0.70, 1.00, 1))
			vb.add_child(mod_lbl)

	return panel

func gui_input(event: InputEvent) -> void:
	# Handle mouse button clicks
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		var mouse_in_rect = get_global_rect().has_point(mbe.position)
		
		# Only handle if click is actually on this item
		if not mouse_in_rect:
			return
		
		# Handle double-click to unequip
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.double_click:
			if parent_inventory_ui and parent_inventory_ui.has_method("_unequip_item_to_inventory"):
				parent_inventory_ui._unequip_item_to_inventory(slot_type)
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
							if cell and is_instance_valid(cell) and cell.get_global_rect().has_point(mouse_pos):
								inventory_cell_index = i
								break
						
						print("[EQUIPPED_DRAG] Released at cell index: ", inventory_cell_index, " mouse: ", mouse_pos)
						
						if inventory_cell_index >= 0:
							# Released over inventory - move item back to inventory
							parent_inventory_ui._unequip_item_to_inventory_at_index(drag_slot, inventory_cell_index)
						else:
							# Released somewhere else - just unequip to first available slot
							parent_inventory_ui._unequip_item_to_inventory(drag_slot)
					
					parent_inventory_ui._set_dragging_equipped("")
			return
