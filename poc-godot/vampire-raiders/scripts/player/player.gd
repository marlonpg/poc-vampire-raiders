extends CharacterBody2D

@export var speed: float = 300.0
@export var max_health: int = 100
@export var invincibility_time: float = 0.5

var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 5
var health: int = 100
var invincible: bool = false

signal level_up(new_level: int)
signal health_changed(current_health: int, max_health: int)
signal player_died

@onready var inventory = $Inventory

func _ready() -> void:
	add_to_group("player")
	health = max_health

func _physics_process(_delta: float) -> void:
	# Single player or multiplayer authority
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = input_direction * speed
		move_and_slide()
		
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			rpc("sync_position", global_position, velocity)

@rpc("unreliable")
func sync_position(pos: Vector2, vel: Vector2) -> void:
	if not is_multiplayer_authority():
		global_position = pos
		velocity = vel

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(5 * pow(1.2, level - 1))
		level_up.emit(level)

func apply_upgrade(upgrade_type: String) -> void:
	match upgrade_type:
		"fire_rate":
			var weapon = get_node_or_null("WeaponController")
			if weapon:
				weapon.fire_rate *= 0.8
		"damage":
			var weapon = get_node_or_null("WeaponController")
			if weapon and weapon.projectile_scene:
				pass
		"speed":
			speed += 50
		"max_health":
			max_health += 20
			health += 20
			health_changed.emit(health, max_health)
		"weapon_range":
			var weapon = get_node_or_null("WeaponController")
			if weapon:
				weapon.max_range += 128

func take_damage(amount: int) -> void:
	if invincible:
		return
	
	health -= amount
	health_changed.emit(health, max_health)
	
	if health <= 0:
		die()
	else:
		invincible = true
		await get_tree().create_timer(invincibility_time).timeout
		invincible = false

func die() -> void:
	player_died.emit()
	
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_drop_all_loot()
	
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		print("You died!")
		await get_tree().create_timer(3.0).timeout
		get_tree().reload_current_scene()

func _drop_all_loot() -> void:
	if not inventory:
		return
	
	for i in range(inventory.items.size() - 1, -1, -1):
		inventory.drop_item(i)
		await get_tree().create_timer(0.1).timeout
