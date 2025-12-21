extends CharacterBody2D

@export var speed: float = 150.0
@export var health: int = 10
@export var aggro_range: float = 512.0
@export var damage: int = 10
@export var xp_gem_scene: PackedScene
@export var loot_scene: PackedScene
@export var loot_drop_chance: float = 0.1

var nearest_player: CharacterBody2D = null
var damage_cooldown: float = 0.0
var frame_count: int = 0
var is_dead: bool = false  # Prevent multiple death triggers

# Reference to the MultiplayerManager autoload (may be null in some contexts)
@onready var multiplayer_manager = get_node_or_null("/root/multiplayer_manager")

func _ready() -> void:
	add_to_group("enemies")
	# Register with server if manager is available
	if multiplayer_manager:
		if multiplayer_manager.is_host:
			multiplayer_manager.register_enemy(name, health)
		else:
			# Request the host to register this enemy (server authoritative)
			rpc_id(1, "register_enemy", name, health)
	else:
		print("[BasicEnemy] WARNING: multiplayer_manager not found; skipping server registration")

func _physics_process(delta: float) -> void:
	if damage_cooldown > 0:
		damage_cooldown -= delta
	
	# Find nearest player (refresh every few frames to catch newly spawned players)
	frame_count += 1
	if frame_count % 10 == 0:  # Check every 10 frames
		_update_nearest_player()
	
	if nearest_player and is_instance_valid(nearest_player):
		var distance = global_position.distance_to(nearest_player.global_position)
		if distance <= aggro_range:
			var direction = (nearest_player.global_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
			
			if get_slide_collision_count() > 0:
				for i in get_slide_collision_count():
					var collision = get_slide_collision(i)
					if collision.get_collider() == nearest_player and damage_cooldown <= 0:
						if nearest_player.has_method("take_damage"):
							nearest_player.take_damage(damage)
							damage_cooldown = 1.0
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

func _update_nearest_player() -> void:
	nearest_player = null
	var min_distance = INF
	
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist < min_distance:
				min_distance = dist
				nearest_player = player
				#print("[BasicEnemy] Found player at distance: %.1f" % dist)

func take_damage(amount: int) -> void:
	# Send damage to server, server will handle death and sync to all clients
	if multiplayer_manager:
		# If running on host, apply directly to server-side manager
		if multiplayer_manager.is_host:
			multiplayer_manager.apply_enemy_damage(name, amount)
		else:
			# Send request to host (peer id 1)
			rpc_id(1, "apply_enemy_damage", name, amount)
	else:
		# Single-player or missing manager: apply locally
		health -= amount
		if health <= 0:
			# Local fallback death handling
			drop_xp(randf() < loot_drop_chance)
			queue_free()

@rpc("any_peer", "call_remote", "reliable")
func _apply_damage(amount: int) -> void:
	# Deprecated - damage now goes through multiplayer_manager
	pass

@rpc("any_peer", "call_remote", "reliable")
func _sync_health(new_health: int) -> void:
	# Deprecated - health now tracked on server
	pass

@rpc("any_peer", "call_remote", "reliable")
func _on_enemy_died() -> void:
	# Deprecated - death now handled by server's despawn_enemy
	pass

func drop_xp(should_drop_loot: bool = true) -> void:
	if xp_gem_scene:
		var gem = xp_gem_scene.instantiate()
		gem.global_position = global_position
		get_tree().root.add_child(gem)
	
	if loot_scene and should_drop_loot:
		var loot = loot_scene.instantiate()
		loot.global_position = global_position
		get_tree().root.add_child(loot)
