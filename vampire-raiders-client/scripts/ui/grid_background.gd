extends Node2D

const GRID_SIZE = 64
const LINE_COLOR = Color(0.3, 0.3, 0.4, 1)
const MAP_GRIDS = 250

# Tile type constants (must match Java Tilemap)
const TILE_SAFE_ZONE = 1
const TILE_MOAT = 2
const TILE_BRIDGE = 3
const TILE_HUNTING = 4

# Colors for each tile type
const TILE_COLORS = {
	TILE_SAFE_ZONE: Color(0.6, 0.9, 0.3, 0.3),  # Green
	TILE_MOAT: Color(0.1, 0.4, 0.7, 0.4),       # Blue
	TILE_BRIDGE: Color(0.6, 0.9, 0.3, 0.4),     # Green
	TILE_HUNTING: Color(0.5, 0.1, 0.1, 0.2)     # Red
}

# Tilemap will be populated when connection is ready
var tilemap: Array = []
var tilemap_loaded: bool = false

func _ready() -> void:
	# Generate tilemap matching server logic
	for x in range(MAP_GRIDS):
		var column = []
		for y in range(MAP_GRIDS):
			column.append(TILE_HUNTING)
		tilemap.append(column)
	
	# Generate zones
	var center_x = MAP_GRIDS / 2
	var center_y = MAP_GRIDS / 2
	
	# Safe zone: 25x25 grids at center
	var safe_zone_size = 25
	var safe_half = safe_zone_size / 2
	for x in range(center_x - safe_half, center_x + safe_half + 1):
		for y in range(center_y - safe_half, center_y + safe_half + 1):
			if x >= 0 and x < MAP_GRIDS and y >= 0 and y < MAP_GRIDS:
				tilemap[x][y] = TILE_SAFE_ZONE
	
	# Moat: 10 grids wide ring
	var moat_width = 10
	var moat_inner = safe_half
	var moat_outer = safe_half + moat_width
	
	for x in range(MAP_GRIDS):
		for y in range(MAP_GRIDS):
			if tilemap[x][y] == TILE_HUNTING:
				var dx = abs(x - center_x)
				var dy = abs(y - center_y)
				var in_moat = (dx > moat_inner or dy > moat_inner) and (dx < moat_outer and dy < moat_outer)
				if in_moat:
					tilemap[x][y] = TILE_MOAT
	
	# Bridges: 6 tiles wide
	var bridge_width = 6
	var bridge_half = bridge_width / 2
	
	# North bridge
	for x in range(center_x - bridge_half, center_x + bridge_half):
		for y in range(center_y - moat_outer, center_y - moat_inner):
			if x >= 0 and x < MAP_GRIDS and y >= 0 and y < MAP_GRIDS:
				tilemap[x][y] = TILE_BRIDGE
	
	# South bridge
	for x in range(center_x - bridge_half, center_x + bridge_half):
		for y in range(center_y + moat_inner, center_y + moat_outer):
			if x >= 0 and x < MAP_GRIDS and y >= 0 and y < MAP_GRIDS:
				tilemap[x][y] = TILE_BRIDGE
	
	# West bridge
	for x in range(center_x - moat_outer, center_x - moat_inner):
		for y in range(center_y - bridge_half, center_y + bridge_half):
			if x >= 0 and x < MAP_GRIDS and y >= 0 and y < MAP_GRIDS:
				tilemap[x][y] = TILE_BRIDGE
	
	# East bridge
	for x in range(center_x + moat_inner, center_x + moat_outer):
		for y in range(center_y - bridge_half, center_y + bridge_half):
			if x >= 0 and x < MAP_GRIDS and y >= 0 and y < MAP_GRIDS:
				tilemap[x][y] = TILE_BRIDGE
	
	tilemap_loaded = true

func _draw() -> void:
	var screen_size = get_viewport_rect().size
	var camera = get_viewport().get_camera_2d()
	
	if not camera:
		return
	
	var cam_pos = camera.global_position
	var zoom = camera.zoom.x
	
	# Calculate visible tile range
	var start_tile_x = max(0, int((cam_pos.x - screen_size.x / zoom) / GRID_SIZE))
	var start_tile_y = max(0, int((cam_pos.y - screen_size.y / zoom) / GRID_SIZE))
	var end_tile_x = min(MAP_GRIDS - 1, int((cam_pos.x + screen_size.x / zoom) / GRID_SIZE))
	var end_tile_y = min(MAP_GRIDS - 1, int((cam_pos.y + screen_size.y / zoom) / GRID_SIZE))
	
	# Draw only visible tiles
	for x in range(start_tile_x, end_tile_x + 1):
		for y in range(start_tile_y, end_tile_y + 1):
			var tile_type = tilemap[x][y] if x < tilemap.size() and y < tilemap[x].size() else TILE_HUNTING
			var color = TILE_COLORS.get(tile_type, Color.WHITE)
			var tile_pos = Vector2(x * GRID_SIZE, y * GRID_SIZE)
			var tile_rect = Rect2(tile_pos, Vector2(GRID_SIZE, GRID_SIZE))
			draw_rect(tile_rect, color, true)
	
	# Draw grid lines
	var start_x = int((cam_pos.x - screen_size.x / zoom) / GRID_SIZE) * GRID_SIZE
	var start_y = int((cam_pos.y - screen_size.y / zoom) / GRID_SIZE) * GRID_SIZE
	var end_x = int((cam_pos.x + screen_size.x / zoom) / GRID_SIZE) * GRID_SIZE
	var end_y = int((cam_pos.y + screen_size.y / zoom) / GRID_SIZE) * GRID_SIZE
	
	for x in range(start_x, end_x + GRID_SIZE, GRID_SIZE):
		draw_line(Vector2(x, start_y), Vector2(x, end_y), LINE_COLOR, 1.0)
	
	for y in range(start_y, end_y + GRID_SIZE, GRID_SIZE):
		draw_line(Vector2(start_x, y), Vector2(end_x, y), LINE_COLOR, 1.0)

func _process(_delta: float) -> void:
	queue_redraw()

# Called from game state sync to update tilemap from server
func set_tilemap_data(data: Array) -> void:
	tilemap = data
	tilemap_loaded = true
	queue_redraw()
