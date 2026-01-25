extends Control

const GRID_COLS = 6
const GRID_ROWS = 12
const CELL_SIZE = 50

@onready var grid_container = $Panel/MarginContainer/VBoxContainer/InventoryPanel/GridWrapper/GridContainer
@onready var weapon_slot = $Panel/MarginContainer/VBoxContainer/EquipmentPanel/WeaponSlot
@onready var helmet_slot = $Panel/MarginContainer/VBoxContainer/EquipmentPanel/HelmetSlot
@onready var armor_slot = $Panel/MarginContainer/VBoxContainer/EquipmentPanel/ArmorSlot
@onready var boots_slot = $Panel/MarginContainer/VBoxContainer/EquipmentPanel/BootsSlot
@onready var net_manager: Node = get_node_or_null("/root/NetworkManager")

var inventory_items = {} # {slot_index: item_data}
var equipped_items = {
	"weapon": null,
	"helmet": null,
	"armor": null,
	"boots": null
}
var drag_from_index: int = -1  # Track which item is being dragged from inventory
var drag_from_equipped: String = ""  # Track which equipped item is being dragged

func _ready():
	if grid_container == null:
		return
	_initialize_grid()
	_setup_equipment_slots()
	# Enable drag-and-drop on this control
	mouse_filter = Control.MOUSE_FILTER_PASS
	if net_manager:
		net_manager.inventory_received.connect(_on_inventory_received)

func _initialize_grid():
	"""Create inventory grid cells"""
	for i in range(GRID_ROWS * GRID_COLS):
		var cell = Panel.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.name = "Cell_%d" % i
		cell.mouse_filter = Control.MOUSE_FILTER_STOP  # Detect mouse events on empty cells
		
		# Add visual feedback
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.25, 1)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.4, 0.4, 0.45, 1)
		cell.add_theme_stylebox_override("panel", style)
		
		# Attach a script to handle mouse releases on empty slots
		var cell_script = load("res://scripts/ui/GridCell.gd")
		if cell_script:
			cell.set_script(cell_script)
			cell.grid_index = i
			cell.parent_inventory_ui = self
		
		grid_container.add_child(cell)
	
	# Enable drop on grid container
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS

func _setup_equipment_slots():
	"""Setup equipment slot drag-and-drop"""
	var slot_types = {"weapon": weapon_slot, "helmet": helmet_slot, "armor": armor_slot, "boots": boots_slot}
	
	for slot_type in slot_types:
		var slot = slot_types[slot_type]
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2, 1)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.6, 0.5, 0.3, 1)
		slot.add_theme_stylebox_override("panel", style)
		
		# Attach equipment slot script
		var slot_script = load("res://scripts/ui/EquipmentSlot.gd")
		if slot_script:
			slot.set_script(slot_script)
			slot.slot_type = slot_type
			slot.parent_inventory_ui = self
		
		# Enable mouse input on slot
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

func _input(event):
	"""Toggle inventory with 'I' key"""
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_I and event.pressed):
		toggle_inventory()

func toggle_inventory():
	visible = !visible
	if visible:
		load_inventory()

func load_inventory():
	"""Request inventory from backend"""
	if net_manager:
		net_manager.request_inventory()

func _on_inventory_received(data: Dictionary):
	"""Populate grid with items from server"""
	var items: Array = data.get("items", [])
	var equipped: Dictionary = data.get("equipped", {})
	
	_clear_grid()
	
	# Build a set of equipped inventory IDs to skip them in the grid
	var equipped_inv_ids = {}
	for slot_type in equipped:
		var item = equipped[slot_type]
		if item and item.has("inventory_id"):
			equipped_inv_ids[item.get("inventory_id")] = true
	
	# Load inventory items (but skip equipped ones)
	for item_data in items:
		var inv_id = item_data.get("inventory_id")
		# Skip this item if it's equipped
		if equipped_inv_ids.has(inv_id):
			continue
		
		var slot_x = item_data.get("slot_x", 0)
		var slot_y = item_data.get("slot_y", 0)
		var index = slot_y * GRID_COLS + slot_x
		_place_item_at(item_data, index)
	
	# Load equipped items
	for slot_type in equipped:
		equipped_items[slot_type] = equipped[slot_type]
		_update_equipment_slot_display(slot_type)
	
	# Clear any equipped slots that are NOT in the new equipped data
	for slot_type in equipped_items:
		if not equipped.has(slot_type) or equipped[slot_type] == null:
			equipped_items[slot_type] = null
			_update_equipment_slot_display(slot_type)

func _place_item_at(item_data: Dictionary, grid_index: int):
	"""Place an item in the grid"""
	if grid_index >= grid_container.get_child_count():
		return
	
	var cell = grid_container.get_child(grid_index)
	if not is_instance_valid(cell):
		return
	
	inventory_items[grid_index] = item_data
	
	# Create item icon
	var item_icon = ColorRect.new()
	item_icon.custom_minimum_size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
	item_icon.size = Vector2(CELL_SIZE - 4, CELL_SIZE - 4)
	item_icon.position = Vector2(2, 2)
	item_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	item_icon.tooltip_text = _build_tooltip(item_data)
	item_icon.visible = true
	item_icon.modulate = Color.WHITE
	
	# Color based on item type
	match item_data.get("type", ""):
		"weapon":
			item_icon.color = Color(0.8, 0.3, 0.3, 1)
		"armor":
			item_icon.color = Color(0.3, 0.5, 0.8, 1)
		"consumable":
			item_icon.color = Color(0.3, 0.8, 0.3, 1)
		_:
			item_icon.color = Color(0.6, 0.6, 0.6, 1)
	
	# Add label - set mouse_filter to IGNORE so it doesn't block input
	var label = Label.new()
	label.text = item_data.get("name", "Item")
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, CELL_SIZE / 2 - 10)
	label.size = Vector2(CELL_SIZE, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input!
	item_icon.add_child(label)
	
	# Attach drag source script BEFORE adding to tree so _ready() is called
	var icon_script = load("res://scripts/ui/ItemIcon.gd")
	if icon_script:
		item_icon.set_script(icon_script)
		
		# Set properties BEFORE adding to tree
		item_icon.inventory_index = grid_index
		item_icon.item_data = item_data
		item_icon.parent_inventory_ui = self
	else:
		return
	
	# NOW add to tree - this will trigger _ready() on the script
	cell.add_child(item_icon)

func _clear_grid():
	inventory_items.clear()
	# Remove only the item icons (ColorRects), keep the grid cells (Panels) intact
	for cell in grid_container.get_children():
		for child in cell.get_children():
			child.free()  # Use free() instead of queue_free() to remove immediately

func _build_tooltip(item: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("%s (%s)" % [item.get("name", "Item"), item.get("rarity", "common")])
	if item.has("type"):
		parts.append("Type: %s" % item.get("type"))
	if item.has("damage") and int(item.get("damage", 0)) > 0:
		parts.append("Damage: %d" % int(item.get("damage", 0)))
	if item.has("defense") and int(item.get("defense", 0)) > 0:
		parts.append("Defense: %d" % int(item.get("defense", 0)))
	return "\n".join(parts)

func _can_drop_data(at_position: Vector2, data) -> bool:
	var valid = typeof(data) == TYPE_DICTIONARY and data.has("from_index")
	return valid

func _drop_data(at_position: Vector2, data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("from_index"):
		return
	var from_index: int = data["from_index"]
	var to_index: int = _cell_index_at(at_position)
	_move_item(from_index, to_index)

func _cell_index_at(local_pos: Vector2) -> int:
	# Determine which cell was dropped on by iterating children
	var global_mouse_pos = get_global_mouse_position()
	
	for i in range(grid_container.get_child_count()):
		var cell := grid_container.get_child(i) as Control
		if not cell:
			continue
		var cell_rect := Rect2(cell.global_position, cell.size)
		if cell_rect.has_point(global_mouse_pos):
			return i
	
	return -1

func _move_item(from_index: int, to_index: int):
	if not inventory_items.has(from_index):
		return
	
	# Prevent moving to same slot
	if from_index == to_index:
		return
	
	var from_item = inventory_items[from_index]
	var to_item = inventory_items.get(to_index)
	
	# Jewel application: dropping a jewel on a weapon/armor applies it instead of swapping slots.
	if from_item.get("type") == "jewel" and to_item != null:
		var target_type := str(to_item.get("type", ""))
		if target_type == "weapon" or target_type == "armor":
			if net_manager and from_item.has("inventory_id") and to_item.has("inventory_id"):
				net_manager.send_json({
					"type": "apply_jewel",
					"jewel_inventory_id": from_item["inventory_id"],
					"target_inventory_id": to_item["inventory_id"],
				})
				# Auto-refresh inventory to reflect consumption + mod changes
				await get_tree().create_timer(0.1).timeout
				if net_manager:
					net_manager.request_inventory()
			return
		# Jewel dropped on a non-weapon/armor item: ignore (no swap)
		return
	
	# Send move request to server first
	if net_manager and from_item.has("inventory_id"):
		var slot_x = to_index % GRID_COLS
		var slot_y = int(to_index / GRID_COLS)
		
		net_manager.send_json({
			"type": "move_inventory_item",
			"inventory_id": from_item["inventory_id"],
			"slot_x": slot_x,
			"slot_y": slot_y
		})
		
		# If there's an item at the target, also move it to the source position
		if to_item and to_item.has("inventory_id"):
			var from_slot_x = from_index % GRID_COLS
			var from_slot_y = int(from_index / GRID_COLS)
			
			net_manager.send_json({
				"type": "move_inventory_item",
				"inventory_id": to_item["inventory_id"],
				"slot_x": from_slot_x,
				"slot_y": from_slot_y
			})
		
		# Auto-refresh inventory from server after a small delay to sync with server state
		await get_tree().create_timer(0.1).timeout
		if net_manager:
			net_manager.request_inventory()
	else:
		return

func _request_drop_from_inventory(index: int):
	if not inventory_items.has(index):
		return
	
	var item = inventory_items[index]
	
	if net_manager and item.has("inventory_id"):
		net_manager.send_json({
			"type": "drop_inventory_item",
			"inventory_id": item["inventory_id"]
		})
		
		# Clear from UI immediately
		var cell = grid_container.get_child(index)
		if is_instance_valid(cell):
			for c in cell.get_children():
				c.queue_free()
		
		inventory_items.erase(index)
		
		# Auto-refresh inventory from server after a small delay
		await get_tree().create_timer(0.1).timeout
		if net_manager:
			net_manager.request_inventory()

func equip_item(item_data: Dictionary, slot_name: String):
	"""Equip an item to a slot"""
	equipped_items[slot_name] = item_data
	# TODO: Send to backend

func unequip_item(slot_name: String):
	"""Unequip an item from a slot"""
	var item = equipped_items[slot_name]
	equipped_items[slot_name] = null

func _equip_item_from_inventory(inventory_index: int, slot_type: String):
	"""Equip an item from inventory to an equipment slot"""
	if not inventory_items.has(inventory_index):
		return
	
	var item = inventory_items[inventory_index]
	
	# Check if item type matches slot type
	if item.get("type") != slot_type:
		return
	
	# Get the cell and clear all its children immediately with free()
	var cell = grid_container.get_child(inventory_index)
	if is_instance_valid(cell):
		for c in cell.get_children():
			c.free()

	# If there's already an item in the slot, swap them
	if equipped_items[slot_type] != null:
		var old_item = equipped_items[slot_type]
		# Put the old item in the inventory slot where the new item came from
		inventory_items[inventory_index] = old_item
		# Re-render the inventory cell with the old item
		_place_item_at(old_item, inventory_index)
	# Note: We don't erase the item from inventory_items because it's still in the database
	# It just won't be rendered since it's in the equipped_inv_ids filter

	# Equip new item
	equipped_items[slot_type] = item

	# Update equipment slot display
	_update_equipment_slot_display(slot_type)
	
	# Send equip message to server
	if net_manager and item.has("inventory_id"):
		var swap_item_id = null
		if equipped_items[slot_type] != null and equipped_items[slot_type] != item:
			swap_item_id = equipped_items[slot_type].get("inventory_id")
		
		net_manager.send_json({
			"type": "equip_item",
			"inventory_id": item["inventory_id"],
			"slot_type": slot_type,
			"swap_inventory_id": swap_item_id
		})
	
	# Refresh inventory display
	await get_tree().create_timer(0.1).timeout
	if net_manager:
		net_manager.request_inventory()

func is_inventory_full() -> bool:
	"""Check if inventory has reached max capacity"""
	return inventory_items.size() >= (GRID_ROWS * GRID_COLS)

func _set_dragging(index: int):
	"""Set the item being dragged"""
	drag_from_index = index

func _get_dragging() -> int:
	"""Get the item being dragged"""
	return drag_from_index

func _update_equipment_slot_display(slot_type: String):
	"""Update the visual display of an equipment slot"""
	var slot_panel = null
	
	match slot_type:
		"weapon":
			slot_panel = weapon_slot
		"helmet":
			slot_panel = helmet_slot
		"armor":
			slot_panel = armor_slot
		"boots":
			slot_panel = boots_slot
	
	if not slot_panel:
		return
	
	# Clear existing item display safely
	var children_to_remove = []
	for child in slot_panel.get_children():
		children_to_remove.append(child)
	for child in children_to_remove:
		slot_panel.remove_child(child)
		child.queue_free()
	
	# If slot is empty, just show empty slot
	if equipped_items[slot_type] == null:
		return
	
	# Create visual representation of equipped item
	var item = equipped_items[slot_type]
	var item_icon = ColorRect.new()
	item_icon.custom_minimum_size = Vector2(48, 48)
	item_icon.size = Vector2(48, 48)
	item_icon.position = Vector2(1, 1)
	item_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	item_icon.tooltip_text = _build_tooltip(item)
	item_icon.visible = true
	
	# Color based on item type
	match item.get("type", ""):
		"weapon":
			item_icon.color = Color(0.8, 0.3, 0.3, 1)
		"armor":
			item_icon.color = Color(0.3, 0.5, 0.8, 1)
		"consumable":
			item_icon.color = Color(0.3, 0.8, 0.3, 1)
		_:
			item_icon.color = Color(0.6, 0.6, 0.6, 1)
	
	# Add label
	var label = Label.new()
	label.text = item.get("name", "Item")
	label.add_theme_font_size_override("font_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, 20)
	label.size = Vector2(50, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.add_child(label)
	
	# Attach EquippedItemIcon script to make it draggable
	var equipped_script = load("res://scripts/ui/EquippedItemIcon.gd")
	if equipped_script:
		item_icon.set_script(equipped_script)
		item_icon.slot_type = slot_type
		item_icon.item_data = item
		item_icon.parent_inventory_ui = self
	
	slot_panel.add_child(item_icon)

func _set_dragging_equipped(slot_type: String):
	"""Set the equipped item being dragged"""
	drag_from_equipped = slot_type

func _get_dragging_equipped() -> String:
	"""Get the equipped item being dragged"""
	return drag_from_equipped

func _unequip_item_to_inventory(slot_type: String):
	"""Unequip an item and return it to inventory at first available slot"""
	if equipped_items[slot_type] == null:
		return
	
	var item = equipped_items[slot_type]
	
	# Find an empty slot in inventory
	var empty_index = -1
	for i in range(GRID_ROWS * GRID_COLS):
		if not inventory_items.has(i):
			empty_index = i
			break
	
	if empty_index < 0:
		return  # Inventory is full
	
	_unequip_item_to_inventory_at_index(slot_type, empty_index)

func _unequip_item_to_inventory_at_index(slot_type: String, inventory_index: int):
	"""Unequip an item and place it at a specific inventory index"""
	if equipped_items[slot_type] == null:
		return
	
	var item = equipped_items[slot_type]
	var existing_item = inventory_items.get(inventory_index)
	
	# If there's already an item at target, swap them
	if existing_item != null:
		equipped_items[slot_type] = existing_item
		inventory_items[inventory_index] = item
		_update_equipment_slot_display(slot_type)
	else:
		# Move equipped item to inventory
		inventory_items[inventory_index] = item
		equipped_items[slot_type] = null
		_update_equipment_slot_display(slot_type)
	
	# Send unequip message to server
	if net_manager and item.has("inventory_id"):
		var slot_x = inventory_index % GRID_COLS
		var slot_y = int(inventory_index / GRID_COLS)
		var swap_item_id = existing_item.get("inventory_id") if existing_item else null
		
		# First unequip the item
		net_manager.send_json({
			"type": "unequip_item",
			"inventory_id": item["inventory_id"],
			"slot_type": slot_type
		})
		
		# Then update its inventory position
		net_manager.send_json({
			"type": "move_inventory_item",
			"inventory_id": item["inventory_id"],
			"slot_x": slot_x,
			"slot_y": slot_y
		})
	
	# Refresh inventory display
	await get_tree().create_timer(0.1).timeout
	if net_manager:
		net_manager.request_inventory()
