extends Node2D

@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.5
@export var max_range: float = 448.0

var fire_timer: float = 0.0

func _process(delta: float) -> void:
	fire_timer += delta
	
	if fire_timer >= fire_rate:
		fire()
		fire_timer = 0.0

func fire() -> void:
	if not projectile_scene:
		return
	
	var closest_enemy = get_closest_enemy()
	if not closest_enemy:
		return
	
	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position
	
	var direction = (closest_enemy.global_position - global_position).normalized()
	projectile.direction = direction
	
	get_tree().root.add_child(projectile)

func get_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	
	var closest: Node2D = null
	var closest_distance: float = INF
	
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance and distance <= max_range:
			closest_distance = distance
			closest = enemy
	
	return closest
