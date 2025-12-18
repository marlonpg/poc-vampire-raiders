extends Node2D

@export var enemy_scene: PackedScene
@export var initial_enemy_count: int = 400
@export var map_size: int = 100

const GRID_SIZE = 64

func _ready() -> void:
	spawn_initial_enemies()

func spawn_initial_enemies() -> void:
	if not enemy_scene:
		return
	
	var map_pixel_size = map_size * GRID_SIZE
	var half_size = map_pixel_size / 2
	
	for i in initial_enemy_count:
		var enemy = enemy_scene.instantiate()
		var random_x = randf_range(-half_size, half_size)
		var random_y = randf_range(-half_size, half_size)
		enemy.global_position = Vector2(random_x, random_y)
		add_child(enemy)
		
		# Spread spawning over frames to avoid freezing
		if i % 10 == 0:
			await get_tree().process_frame
