extends Control

const GRID_COLS = 4
const GRID_ROWS = 3
const GridItem = preload("res://scripts/GridItem.gd")

var grid_items = {}  # {index: item_data}
var grid_container = null

func _ready():
	# Create GridContainer
	grid_container = GridContainer.new()
	grid_container.columns = GRID_COLS
	grid_container.add_theme_constant_override("h_separation", 5)
	grid_container.add_theme_constant_override("v_separation", 5)
	grid_container.anchor_left = 0.1
	grid_container.anchor_top = 0.1
	grid_container.anchor_right = 0.9
	grid_container.anchor_bottom = 0.9
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow drops on grid
	add_child(grid_container)
	
	# Initialize grid with sample items
	_initialize_grid()

func _initialize_grid():
	var items = [
		"Sword", "Shield", "Helmet", "Armor",
		"Boots", "Ring", "Potion", "Key",
		"Scroll", "Map", "Coin", null
	]
	
	for i in range(GRID_ROWS * GRID_COLS):
		# Create Control node (not Panel)
		var item = Control.new()
		item.set_script(GridItem)
		
		if items[i]:
			grid_items[i] = items[i]
		
		# Set properties BEFORE adding to tree so _ready() is called with proper data
		item.grid_index = i
		item.item_name = items[i] if items[i] else ""
		item.parent_grid = self
		
		grid_container.add_child(item)

func swap_items(from_index: int, to_index: int):
	print("[DRAGDROPGRID] Swapping items: index %d <-> index %d" % [from_index, to_index])
	
	# Get the items
	var from_item = grid_items.get(from_index)
	var to_item = grid_items.get(to_index)
	
	# Swap in dictionary
	if from_item:
		grid_items[to_index] = from_item
	else:
		grid_items.erase(to_index)
	
	if to_item:
		grid_items[from_index] = to_item
	else:
		grid_items.erase(from_index)
	
	# Update UI
	var from_panel = grid_container.get_child(from_index) as Control
	var to_panel = grid_container.get_child(to_index) as Control
	
	if from_panel and from_panel.has_method("set_item"):
		from_panel.set_item(from_index, to_item if to_item else "", self)
	
	if to_panel and to_panel.has_method("set_item"):
		to_panel.set_item(to_index, from_item if from_item else "", self)
	
	print("[DRAGDROPGRID] Swap complete. Grid state: %s" % grid_items)
