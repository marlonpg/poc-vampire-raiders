extends Node2D

const GRID_SIZE = 64
const LINE_COLOR = Color(0.3, 0.3, 0.4, 1)
const MAP_GRIDS = 100  # Changed to match main-map.txt 100x100 grid

# Tile type codes (must match Java TileType codes)
const TILE_BLK = "BLK"
const TILE_SAF = "SAF"
const TILE_PVE = "PVE"
const TILE_EL1 = "EL1"
const TILE_EL2 = "EL2"
const TILE_EL3 = "EL3"
const TILE_EL4 = "EL4"
const TILE_PV1 = "PV1"  # Spider
const TILE_PV2 = "PV2"  # Worm
const TILE_PV3 = "PV3"  # Wild Dog
const TILE_PV4 = "PV4"  # Goblin

# Colors for each tile type
const TILE_COLORS = {
	TILE_BLK: Color(0.2, 0.2, 0.2, 0.8),      # Gray
	TILE_SAF: Color(0.0, 0.8, 0.0, 0.3),      # Green
	TILE_PVE: Color(0.8, 0.1, 0.1, 0.3),      # Red
	TILE_EL1: Color(0.8, 0.1, 0.1, 0.3),      # Red (elite)
	TILE_EL2: Color(0.8, 0.1, 0.1, 0.3),      # Red (elite)
	TILE_EL3: Color(0.8, 0.1, 0.1, 0.3),      # Red (elite)
	TILE_EL4: Color(0.8, 0.1, 0.1, 0.3),      # Red (elite)
	TILE_PV1: Color(0.8, 0.1, 0.1, 0.3),      # Red (spider spawn)
	TILE_PV2: Color(0.8, 0.1, 0.1, 0.3),      # Red (worm spawn)
	TILE_PV3: Color(0.8, 0.1, 0.1, 0.3),      # Red (wild dog spawn)
	TILE_PV4: Color(0.8, 0.1, 0.1, 0.3),      # Red (goblin spawn)
}

# Tilemap will be populated when connection is ready
var tilemap: Array = []
var map_width: int = MAP_GRIDS
var map_height: int = MAP_GRIDS
var tilemap_loaded: bool = false

func _ready() -> void:
	# Load map from file (same map as server uses)
	var map_data = MapLoader.load_map("main-map.txt")
	if map_data.is_empty():
		push_error("Failed to load map file")
		return
	
	# Convert tiles array to the format we need
	var tiles_list = map_data["tiles"]
	map_width = map_data["width"]
	map_height = map_data["height"]
	
	# Store tiles as 2D array for access
	tilemap = tiles_list
	tilemap_loaded = true

func _draw() -> void:
	var screen_size = get_viewport_rect().size
	var camera = get_viewport().get_camera_2d()
	
	if not camera:
		return
	
	# Draw black background for entire viewport
	draw_rect(Rect2(camera.global_position - screen_size / (2 * camera.zoom), screen_size / camera.zoom), Color.BLACK, true)
	
	var cam_pos = camera.global_position
	var zoom = camera.zoom.x
	
	# Calculate map world bounds
	var map_world_width = map_width * GRID_SIZE
	var map_world_height = map_height * GRID_SIZE
	
	# Calculate visible tile range
	var start_tile_x = max(0, int((cam_pos.x - screen_size.x / zoom) / GRID_SIZE))
	var start_tile_y = max(0, int((cam_pos.y - screen_size.y / zoom) / GRID_SIZE))
	var end_tile_x = min(map_width - 1, int((cam_pos.x + screen_size.x / zoom) / GRID_SIZE))
	var end_tile_y = min(map_height - 1, int((cam_pos.y + screen_size.y / zoom) / GRID_SIZE))
	
	# Draw only visible tiles
	for y in range(start_tile_y, end_tile_y + 1):
		for x in range(start_tile_x, end_tile_x + 1):
			if y < tilemap.size() and x < tilemap[y].size():
				var tile_code = tilemap[y][x]
				var color = TILE_COLORS.get(tile_code, Color(0.5, 0.5, 0.5, 0.3))
				var tile_pos = Vector2(x * GRID_SIZE, y * GRID_SIZE)
				var tile_rect = Rect2(tile_pos, Vector2(GRID_SIZE, GRID_SIZE))
				draw_rect(tile_rect, color, true)
	
	# Draw grid lines (only on map area)
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
func set_tilemap_data(data: Array, width: int, height: int) -> void:
	tilemap = data
	map_width = width
	map_height = height
	tilemap_loaded = true
	queue_redraw()
