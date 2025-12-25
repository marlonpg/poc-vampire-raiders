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

func _ready():
	if grid_container == null:
		return
	_initialize_grid()
	_setup_equipment_slots()
	if net_manager:
		net_manager.inventory_received.connect(_on_inventory_received)

func _initialize_grid():
	"""Create inventory grid cells"""
	for i in range(GRID_ROWS * GRID_COLS):
		var cell = Panel.new()
		cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
		cell.name = "Cell_%d" % i
		
		# Add visual feedback
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.25, 1)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.4, 0.4, 0.45, 1)
		cell.add_theme_stylebox_override("panel", style)
		
		grid_container.add_child(cell)

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
	_clear_grid()
	var items: Array = data.get("items", [])
	for item_data in items:
		var slot_x = item_data.get("slot_x", 0)
		var slot_y = item_data.get("slot_y", 0)
		var index = slot_y * GRID_COLS + slot_x
		_place_item_at(item_data, index)

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
	
	# Add label
	var label = Label.new()
	label.text = item_data.get("name", "Item")
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(0, CELL_SIZE / 2 - 10)
	label.size = Vector2(CELL_SIZE, 20)
	item_icon.add_child(label)
	
	# Attach drag source script AFTER adding to scene
	var icon_script = load("res://scripts/ItemIcon.gd")
	if icon_script:
		item_icon.set_script(icon_script)
		item_icon.inventory_index = grid_index
		item_icon.item_data = item_data
		item_icon.parent_inventory_ui = self
	
	cell.add_child(item_icon)

func _clear_grid():
	inventory_items.clear()
	# Directly remove all children instead of queue_free to avoid doubling
	for cell in grid_container.get_children():
		cell.free()
	_initialize_grid()

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
	return typeof(data) == TYPE_DICTIONARY and data.has("from_index")

func _drop_data(at_position: Vector2, data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("from_index"):
		return
	var from_index: int = data["from_index"]
	var to_index: int = _cell_index_at(at_position)
	if to_index < 0:
		return
	_move_item(from_index, to_index)

func _cell_index_at(local_pos: Vector2) -> int:
	# Determine which cell was dropped on by iterating children
	for i in range(grid_container.get_child_count()):
		var cell := grid_container.get_child(i) as Control
		if not cell:
			continue
		var rect := Rect2(cell.global_position, cell.size)
		if rect.has_point(get_global_mouse_position()):
			return i
	return -1

func _move_item(from_index: int, to_index: int):
	if not inventory_items.has(from_index):
		return
	var item = inventory_items[from_index]
	inventory_items.erase(from_index)
	inventory_items[to_index] = item
	# Re-render affected cells
	var from_cell = grid_container.get_child(from_index)
	var to_cell = grid_container.get_child(to_index)
	if is_instance_valid(from_cell):
		for c in from_cell.get_children():
			c.queue_free()
	if is_instance_valid(to_cell):
		for c in to_cell.get_children():
			c.queue_free()
	_place_item_at(item, to_index)
	# Notify server
	if net_manager and item.has("inventory_id"):
		var slot_x = to_index % GRID_COLS
		var slot_y = int(to_index / GRID_COLS)
		net_manager.send_json({
			"type": "move_inventory_item",
			"inventory_id": item["inventory_id"],
			"slot_x": slot_x,
			"slot_y": slot_y
		})

func _request_drop_from_inventory(index: int):
	if not inventory_items.has(index):
		return
	var item = inventory_items[index]
	if net_manager and item.has("inventory_id"):
		net_manager.send_json({
			"type": "drop_inventory_item",
			"inventory_id": item["inventory_id"]
		})
		# Optimistically clear from UI; server will sync drop
		var cell = grid_container.get_child(index)
		if is_instance_valid(cell):
			for c in cell.get_children():
				c.queue_free()
		inventory_items.erase(index)

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

func _on_close_button_pressed():
	visible = false
