extends CharacterBody2D

@export var speed: float = 300.0
@export var max_health: int = 100
@export var invincibility_time: float = 0.5
@export var position_sync_interval: float = 0.1  # Sync position every 0.1 seconds

var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 5
var health: int = 100
var invincible: bool = false

# Multiplayer
var player_id: int = -1
var is_local_player: bool = false
var last_synced_position: Vector2 = Vector2.ZERO
var position_sync_timer: float = 0.0

signal level_up(new_level: int)
signal health_changed(current_health: int, max_health: int)
signal player_died

@onready var inventory = $Inventory

func _ready() -> void:
	add_to_group("player")
	health = max_health
	
	# Multiplayer setup
	if multiplayer:
		player_id = get_multiplayer_authority()
		is_local_player = is_multiplayer_authority()
	
	# Setup camera for local player
	if is_local_player:
		var camera = Camera2D.new()
		camera.enabled = true
		add_child(camera)
		# make_current() must be called after camera is in the tree
		camera.make_current()
		print("[Player %d] Camera added for LOCAL player" % player_id)
	else:
		print("[Player %d] REMOTE player (no camera)" % player_id)

func _physics_process(delta: float) -> void:
	# Only local player handles input
	if not is_local_player:
		return
	
	var input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * speed
	move_and_slide()
	
	# Sync position to network at interval
	position_sync_timer += delta
	if position_sync_timer >= position_sync_interval:
		position_sync_timer = 0.0
		if position != last_synced_position:
			last_synced_position = position
			_sync_position_to_network()

func add_xp(amount: int) -> void:
	if not is_local_player:
		return
	
	xp += amount
	_check_level_up()
	_sync_stats_to_network()

func _check_level_up() -> void:
	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level += 1
		xp_to_next_level = int(5 * pow(1.2, level - 1))
		level_up.emit(level)

func apply_upgrade(upgrade_type: String) -> void:
	if not is_local_player:
		return
	
	rpc("_apply_upgrade_sync", upgrade_type)

@rpc("any_peer", "call_remote", "reliable")
func _apply_upgrade_sync(upgrade_type: String) -> void:
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
	# Only local player can take damage, sync via RPC
	if not is_local_player:
		return
	
	rpc("_apply_damage", amount)

@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(amount: int) -> void:
	if invincible:
		return
	
	health -= amount
	health_changed.emit(health, max_health)
	_sync_stats_to_network()
	
	if health <= 0:
		rpc("_on_player_died")
	else:
		invincible = true
		await get_tree().create_timer(invincibility_time).timeout
		invincible = false

@rpc("any_peer", "call_remote", "reliable")
func _on_player_died() -> void:
	die()

func die() -> void:
	if not is_local_player:
		return
	
	player_died.emit()
	print("Player died!")
	
	# Notify network
	var multiplayer_manager = get_tree().root.get_node("MultiplayerManager")
	if multiplayer_manager:
		multiplayer_manager.on_player_died(player_id)
	
	# Drop all inventory items (TODO: implement loot drops)
	# get_tree().reload_current_scene()

# ============================================================================
# NETWORK SYNCHRONIZATION
# ============================================================================

func _sync_position_to_network() -> void:
	var multiplayer_manager = get_tree().root.get_node_or_null("MultiplayerManager")
	if multiplayer_manager:
		multiplayer_manager.update_player_position(position)

func _sync_stats_to_network() -> void:
	var multiplayer_manager = get_tree().root.get_node_or_null("MultiplayerManager")
	if multiplayer_manager:
		multiplayer_manager.update_player_stats(health, level, xp)
