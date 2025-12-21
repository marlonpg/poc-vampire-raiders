extends Node2D

@export var enemy_scene: PackedScene
@export var initial_enemy_count: int = 400
@export var map_size: int = 100

const GRID_SIZE = 64

func _ready() -> void:
	print("[EnemySpawner] Starting enemy spawn")
	spawn_initial_enemies()

func spawn_initial_enemies() -> void:
	if not enemy_scene:
		print("[EnemySpawner] ERROR: No enemy scene configured")
		return
	
	# Use a fixed seed so all instances spawn enemies at the same positions
	seed(12345)
	
	var map_pixel_size = map_size * GRID_SIZE
	var half_size = map_pixel_size / 2
	
	print("[EnemySpawner] Spawning %d enemies in map area" % initial_enemy_count)
	for i in initial_enemy_count:
		var enemy = enemy_scene.instantiate()
		var random_x = randf_range(-half_size, half_size)
		var random_y = randf_range(-half_size, half_size)
		enemy.global_position = Vector2(random_x, random_y)
		# Give enemies deterministic names so RPC can find them across instances
		enemy.name = "Enemy_%d" % i
		add_child(enemy)
