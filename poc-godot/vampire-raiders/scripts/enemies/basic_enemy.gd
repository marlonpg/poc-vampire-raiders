extends CharacterBody2D

@export var speed: float = 150.0
@export var health: int = 10
@export var aggro_range: float = 512.0
@export var damage: int = 10
@export var xp_gem_scene: PackedScene
@export var loot_scene: PackedScene
@export var loot_drop_chance: float = 0.1

var player: CharacterBody2D
var damage_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if damage_cooldown > 0:
		damage_cooldown -= delta
	
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= aggro_range:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
			
			if get_slide_collision_count() > 0:
				for i in get_slide_collision_count():
					var collision = get_slide_collision(i)
					if collision.get_collider() == player and damage_cooldown <= 0:
						if player.has_method("take_damage"):
							player.take_damage(damage)
							damage_cooldown = 1.0
		else:
			velocity = Vector2.ZERO

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		drop_xp()
		queue_free()

func drop_xp() -> void:
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate()
		gem.global_position = global_position
		get_tree().root.call_deferred("add_child", gem)
	
	if loot_scene and randf() < loot_drop_chance:
		var loot = loot_scene.instantiate()
		loot.global_position = global_position
		get_tree().root.call_deferred("add_child", loot)
