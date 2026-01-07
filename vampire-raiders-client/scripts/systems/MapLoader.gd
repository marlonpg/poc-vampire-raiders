extends Node

# This mirrors the Java MapLoader to load map files on the client side
# Map files use [TAG] format where each cell contains a 3-character tile type

class_name MapLoader

const TILE_SIZE = 64

static func load_map(filename: String) -> Dictionary:
	"""
	Load a map from a text file in res://maps/ directory.
	Returns a dictionary with:
	- tiles: Array[Array] of tile type strings
	- width: int
	- height: int
	"""
	var path = "res://maps/" + filename
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file == null:
		push_error("Could not load map file: " + path)
		return {}
	
	var tiles: Array[Array] = []
	var width = 0
	var height = 0
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		
		if line.is_empty():
			continue
		
		# Parse line with [TAG] format
		var row: Array = []
		var start = 0
		
		while true:
			var open_bracket = line.find("[", start)
			if open_bracket == -1:
				break
			
			var close_bracket = line.find("]", open_bracket)
			if close_bracket == -1:
				break
			
			var tile_type = line.substr(open_bracket + 1, close_bracket - open_bracket - 1)
			row.append(tile_type)
			
			start = close_bracket + 1
		
		if row.size() > 0:
			if width == 0:
				width = row.size()
			height += 1
			tiles.append(row)
	
	return {
		"tiles": tiles,
		"width": width,
		"height": height
	}

static func get_safe_zone_center(map_data: Dictionary) -> Vector2:
	"""
	Calculate the center of the safe zone from SAF tiles.
	Returns world coordinates (not grid coordinates).
	"""
	var tiles = map_data["tiles"]
	var safe_tiles = []
	
	for y in range(tiles.size()):
		for x in range(tiles[y].size()):
			if tiles[y][x] == "SAF":
				safe_tiles.append(Vector2(x, y))
	
	if safe_tiles.is_empty():
		push_error("No safe zone (SAF) tiles found in map!")
		return Vector2(0, 0)
	
	# Calculate average position of all SAF tiles
	var sum = Vector2.ZERO
	for pos in safe_tiles:
		sum += pos
	
	var center_grid = sum / safe_tiles.size()
	# Convert grid coordinates to world coordinates
	return center_grid * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
