extends Control

var grid_index: int = -1
var item_name: String = "Item"
var parent_grid = null
var is_dragging = false

func _ready():
	custom_minimum_size = Vector2(60, 60)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Create background
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.25, 1)
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)
	
	# Create label
	var label = Label.new()
	label.text = item_name
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0
	label.anchor_top = 0
	label.anchor_right = 1
	label.anchor_bottom = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func set_item(index: int, name: String, grid_ref):
	grid_index = index
	item_name = name
	parent_grid = grid_ref
	
	# Update label if it exists
	if get_child_count() > 1:
		var label = get_child(1) as Label
		if label:
			label.text = item_name if item_name else ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			print("[GRIDITEM] Drag started from index %d" % grid_index)
		else:
			# Mouse released - check if we're over another item
			if is_dragging:
				var mouse_pos = get_global_mouse_position()
				_check_drop_at_position(mouse_pos)
			is_dragging = false

func _check_drop_at_position(mouse_pos: Vector2):
	if not parent_grid:
		return
	
	# Find which item is under the mouse
	var container = parent_grid.grid_container
	for i in range(container.get_child_count()):
		var child = container.get_child(i)
		if child and child.get_global_rect().has_point(mouse_pos):
			if i != grid_index:
				print("[GRIDITEM] Drop detected: from index %d to index %d" % [grid_index, i])
				parent_grid.swap_items(grid_index, i)
			return
	
	print("[GRIDITEM] Drop outside grid")
