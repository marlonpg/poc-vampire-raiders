extends Node2D

const GRID_SIZE = 64
const LINE_COLOR = Color(0.3, 0.3, 0.4, 1)

func _draw() -> void:
	var screen_size = get_viewport_rect().size
	var camera = get_viewport().get_camera_2d()
	
	if not camera:
		return
	
	var cam_pos = camera.global_position
	var zoom = camera.zoom.x
	
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
