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
var drag_from_index: int = -1  # Track which item is being dragged

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
		var cell_script = load("res://scripts/GridCell.gd")
		if cell_script:
			cell.set_script(cell_script)
			cell.grid_index = i
			cell.parent_inventory_ui = self
		
		grid_container.add_child(cell)
	
	# Enable drop on grid container
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS

func _setup_equipment_slots():
	"""Setup equipment slot drag-and-drop"""
	for slot in [weapon_slot, helmet_slot, armor_slot, boots_slot]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2, 1)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.6, 0.5, 0.3, 1)
		slot.add_theme_stylebox_override("panel", style)

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
	print("[INVENTORY] Received inventory update with %d items" % items.size())
	_clear_grid()
	for item_data in items:
		var slot_x = item_data.get("slot_x", 0)
		var slot_y = item_data.get("slot_y", 0)
		var index = slot_y * GRID_COLS + slot_x
		_place_item_at(item_data, index)
	print("[INVENTORY] Inventory display updated with %d items" % inventory_items.size())

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
	var icon_script = load("res://scripts/ItemIcon.gd")
	print("[INVENTORY] Loading ItemIcon script: %s" % icon_script)
	if icon_script:
		print("[INVENTORY] Script loaded, attaching to ColorRect at index %d" % grid_index)
		item_icon.set_script(icon_script)
		print("[INVENTORY] set_script called on ColorRect")
		
		# Set properties BEFORE adding to tree
		item_icon.inventory_index = grid_index
		item_icon.item_data = item_data
		item_icon.parent_inventory_ui = self
		print("[INVENTORY] Properties set on ColorRect")
	else:
		print("[INVENTORY] ERROR: Failed to load ItemIcon script")
	
	# NOW add to tree - this will trigger _ready() on the script
	cell.add_child(item_icon)
	print("[INVENTORY] Placed item %s at index %d" % [item_data.get("name", "?"), grid_index])

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
	if valid:
		print("[INVENTORY] Can drop at position: %s" % at_position)
	return valid

func _drop_data(at_position: Vector2, data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("from_index"):
		print("[INVENTORY] Invalid drop data")
		return
	var from_index: int = data["from_index"]
	print("[INVENTORY] Drop detected from index %d at position %s" % [from_index, at_position])
	var to_index: int = _cell_index_at(at_position)
	print("[INVENTORY] Target cell index: %d" % to_index)
	if to_index < 0:
		print("[INVENTORY] Drop target not found")
		return
	_move_item(from_index, to_index)

func _cell_index_at(local_pos: Vector2) -> int:
	# Determine which cell was dropped on by iterating children
	var global_mouse_pos = get_global_mouse_position()
	print("[INVENTORY] Looking for cell at global pos: %s" % global_mouse_pos)
	
	for i in range(grid_container.get_child_count()):
		var cell := grid_container.get_child(i) as Control
		if not cell:
			continue
		var cell_rect := Rect2(cell.global_position, cell.size)
		if cell_rect.has_point(global_mouse_pos):
			print("[INVENTORY] Found cell %d at position %s" % [i, cell.global_position])
			return i
	
	print("[INVENTORY] No cell found at position")
	return -1

func _move_item(from_index: int, to_index: int):
	print("[INVENTORY] Moving item from index %d to %d" % [from_index, to_index])
	
	if not inventory_items.has(from_index):
		print("[INVENTORY] Source index has no item")
		return
	
	# Prevent moving to same slot
	if from_index == to_index:
		print("[INVENTORY] Source and target are the same")
		return
	
	var from_item = inventory_items[from_index]
	var to_item = inventory_items.get(to_index)
	
	print("[INVENTORY] Item to move: %s (inventory_id=%s)" % [from_item.get("name", "?"), from_item.get("inventory_id", "?")])
	if to_item:
		print("[INVENTORY] Target has item: %s (inventory_id=%s)" % [to_item.get("name", "?"), to_item.get("inventory_id", "?")])
	
	# Send move request to server first
	if net_manager and from_item.has("inventory_id"):
		var slot_x = to_index % GRID_COLS
		var slot_y = int(to_index / GRID_COLS)
		print("[INVENTORY] Sending move_inventory_item: from_index=%d, to_index=%d, slot_x=%d, slot_y=%d" % [from_index, to_index, slot_x, slot_y])
		
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
			print("[INVENTORY] Sending swap: moving target item to source position")
			
			net_manager.send_json({
				"type": "move_inventory_item",
				"inventory_id": to_item["inventory_id"],
				"slot_x": from_slot_x,
				"slot_y": from_slot_y
			})
		
		# Auto-refresh inventory from server after a small delay to sync with server state
		await get_tree().create_timer(0.1).timeout
		if net_manager:
			print("[INVENTORY] Auto-requesting inventory refresh after move")
			net_manager.request_inventory()
	else:
		print("[INVENTORY] Cannot move: net_manager=%s, has_inventory_id=%s" % [net_manager != null, from_item.has("inventory_id")])

func _request_drop_from_inventory(index: int):
	print("[INVENTORY] Drop request for item at index %d" % index)
	print("[INVENTORY] Current inventory size: %d items" % inventory_items.size())
	
	if not inventory_items.has(index):
		print("[INVENTORY] No item at index %d" % index)
		return
	
	var item = inventory_items[index]
	print("[INVENTORY] Dropping item: %s (inventory_id=%s)" % [item.get("name", "?"), item.get("inventory_id", "?")])
	
	if net_manager and item.has("inventory_id"):
		print("[INVENTORY] Sending drop_inventory_item to server")
		net_manager.send_json({
			"type": "drop_inventory_item",
			"inventory_id": item["inventory_id"]
		})
		
		# Clear from UI immediately
		var cell = grid_container.get_child(index)
		if is_instance_valid(cell):
			print("[INVENTORY] Clearing cell %d" % index)
			for c in cell.get_children():
				c.queue_free()
		
		inventory_items.erase(index)
		print("[INVENTORY] Item dropped successfully, inventory now has %d items" % inventory_items.size())
		
		# Auto-refresh inventory from server after a small delay
		await get_tree().create_timer(0.1).timeout
		if net_manager:
			print("[INVENTORY] Auto-requesting inventory refresh after drop")
			net_manager.request_inventory()
	else:
		print("[INVENTORY] Cannot drop: net_manager=%s, has_inventory_id=%s" % [net_manager != null, item.has("inventory_id")])

func equip_item(item_data: Dictionary, slot_name: String):
	"""Equip an item to a slot"""
	equipped_items[slot_name] = item_data
	# TODO: Send to backend

func unequip_item(slot_name: String):
	"""Unequip an item from a slot"""
	var item = equipped_items[slot_name]
	equipped_items[slot_name] = null

func is_inventory_full() -> bool:
	"""Check if inventory has reached max capacity"""
	return inventory_items.size() >= (GRID_ROWS * GRID_COLS)

func _set_dragging(index: int):
	"""Set the item being dragged"""
	drag_from_index = index
	print("[INVENTORY] Drag from index set to: %d" % index)

func _get_dragging() -> int:
	"""Get the item being dragged"""
	return drag_from_index

func _on_close_button_pressed():
	visible = false
