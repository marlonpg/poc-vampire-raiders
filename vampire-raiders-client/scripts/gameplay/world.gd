extends Node2D
class_name World

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var bullet_scene: PackedScene = preload("res://scenes/gameplay/Bullet.tscn")
@onready var damage_number_scene: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

var spawner: MultiplayerSpawner
var is_server_mode: bool = false
var player_instance: Node2D = null
var net_manager: Node = null
var enemies: Dictionary = {}  # ID -> enemy node
var bullets: Dictionary = {}  # ID -> bullet node
var other_players: Dictionary = {}  # peer_id -> player node (excluding local)
var world_items: Dictionary = {}  # id -> world item node
var last_input_dir: Vector2 = Vector2.ZERO
var input_send_timer: float = 0.0
var input_send_interval: float = 0.1  # Send input every 0.1 seconds
var local_player_alive: bool = true
var death_handled: bool = false
var local_max_health: int = 100
var local_level: int = 1
var local_xp: int = 0
var damage_container: Node2D = null

# Damage number tracking
var enemy_last_health: Dictionary = {}  # Track previous health per enemy ID
var player_last_health: int = 100  # Track previous player health

@onready var world_item_scene: PackedScene = preload("res://scenes/gameplay/WorldItem.tscn")

const HEALTH_BAR_WIDTH := 220.0
const XP_BAR_WIDTH := 1280.0

# Enemy sprite mapping by template name
var enemy_sprites = {
	"Spider": "res://assets/enemies/spider.png"
}

@onready var health_fill: ColorRect = $HUD/MarginRoot/VBoxContainer/BarBG/HealthFill
@onready var health_label: Label = $HUD/MarginRoot/VBoxContainer/HealthLabel
@onready var xp_fill: ColorRect = $XPBarHUD/BottomMargin/BarBG/XPFill
@onready var xp_label: Label = $XPBarHUD/BottomMargin/LevelLabel

func _ready():
	await get_tree().process_frame
	
	# Get the network manager first
	net_manager = get_node("/root/NetworkManager")

	# Create a dedicated container for floating damage numbers (keeps them above world)
	damage_container = Node2D.new()
	damage_container.name = "DamageContainer"
	damage_container.z_index = 1000
	add_child(damage_container)
	
	# Determine if we're server or client based on whether network_manager started as client
	is_server_mode = not net_manager.is_client_mode() if net_manager else false
	print("[WORLD] Server:", is_server_mode)

	_log_role("World _ready()")

	_setup_spawner()

	if is_server_mode:
		_log_server("Setting up server-only logic")
		spawn_enemy_loop()
	else:
		_log_client("Client ready, waiting to join server")
		if net_manager:
			# Listen for game state updates
			# Connect to network signals
			net_manager.game_state_received.connect(_on_game_state_received)
			net_manager.damage_event_received.connect(_on_damage_event_received)
			
			# Wait for connection to be established (status = 2 = STATUS_CONNECTED)
			var wait_time = 0.0
			while wait_time < 10.0 and not net_manager.is_tcp_connected():
				await get_tree().create_timer(0.1).timeout
				wait_time += 0.1
			
			if net_manager.is_tcp_connected():
				_join_as_player()
			else:
				_log_client("Failed to connect to server after 10 seconds")

	_log_role("World ready complete")
	_update_health_ui(local_max_health, local_max_health)
	_update_xp_ui(local_xp, local_level)

func _join_as_player():
	"""Send player join message to Java server"""
	_log_client("_join_as_player() called, net_manager=" + str(net_manager))
	if not net_manager:
		_log_client("No net_manager!")
		return
	
	_log_client("Checking if TCP connected: " + str(net_manager.is_tcp_connected()))
	if not net_manager.is_tcp_connected():
		_log_client("Not connected to server yet")
		return
	
	_log_client("Sending player join message")
	var username = GlobalAuth.logged_in_username if GlobalAuth.is_logged_in() else "Player_%d" % net_manager.peer_id
	var password = GlobalAuth.logged_in_password if GlobalAuth.is_logged_in() else "pass"
	var join_msg = {
		"type": "player_join",
		"username": username,
		"password": password,
		"x": 640.0,
		"y": 360.0
	}
	var sent = net_manager.send_json(join_msg)
	_log_client("Send result: " + str(sent))
	_log_client("Send result: " + str(sent))
	_log_client("Send result: " + str(sent))
	
	# Spawn player locally
	if player_scene:
		player_instance = player_scene.instantiate()
		player_instance.name = str(net_manager.peer_id)
		player_instance.position = Vector2(640, 360)
		player_instance.is_local_player = true  # Mark as local player
		add_child(player_instance)
		_log_client("Local player spawned")

func _on_game_state_received(data: Dictionary):
	"""Handle game state updates from server"""
	var players = data.get("players", [])
	var enemies_data = data.get("enemies", [])
	var bullets_data = data.get("bullets", [])
	var world_items_data = data.get("world_items", [])
	
	#print("[GAME_STATE] Received: %d players, %d enemies, %d bullets, %d items" % [players.size(), enemies_data.size(), bullets_data.size(), world_items_data.size()])
	
	# Update players (local + others)
	_update_players(players)
	
	# Update enemies
	_update_enemies(enemies_data)
	
	# Update bullets
	_update_bullets(bullets_data)

	# Update world items (drops)
	_update_world_items(world_items_data)

func _update_players(players_data: Array) -> void:
	"""Spawn/update/remove player sprites for all peers."""
	var server_ids := {}
	for p in players_data:
		var pid = p.get("peer_id")
		server_ids[pid] = true

		# Local player: keep existing instance but update position/health
		if net_manager and pid == net_manager.peer_id:
			var previous_alive = local_player_alive
			local_player_alive = p.get("alive", true)
			local_max_health = p.get("max_health", local_max_health)
			local_level = p.get("level", local_level)
			local_xp = p.get("xp", local_xp)
			#_log_client("Local player data: Level=%d, XP=%d, HP=%d/%d" % [local_level, local_xp, p.get("health", 100), local_max_health])
			if player_instance:
				#_log_client("Updating local player at (%.0f, %.0f)" % [p.get("x", 0), p.get("y", 0)])
				player_instance.position = Vector2(p.get("x", 0), p.get("y", 0))
				player_instance.health = p.get("health", 100)
				# Update attack range from server
				if player_instance.has_method("update_attack_range"):
					player_instance.update_attack_range(p.get("attack_range", 200.0))
			elif player_scene:
				#_log_client("ERROR: Local player not spawned yet, creating late instance")
				player_instance = player_scene.instantiate()
				player_instance.name = str(pid)
				player_instance.position = Vector2(p.get("x", 0), p.get("y", 0))
				add_child(player_instance)
			if player_instance:
				_update_health_ui(player_instance.health, local_max_health)
				_update_xp_ui(local_xp, local_level)
			if previous_alive and not local_player_alive:
				_on_local_player_died()
			
			player_last_health = p.get("health", 100)
		else:
			# Remote players
			if not other_players.has(pid) and player_scene:
				_log_client("Spawning remote player %d" % pid)
				var remote = player_scene.instantiate()
				remote.name = "Player_%d" % pid
				remote.modulate = Color(0.6, 0.8, 1.0)  # light tint to distinguish
				add_child(remote)
				other_players[pid] = remote
			if other_players.has(pid) and is_instance_valid(other_players[pid]):
				other_players[pid].position = Vector2(p.get("x", 0), p.get("y", 0))
				other_players[pid].visible = p.get("alive", true)

	# Remove players that disappeared
	var to_remove := []
	for pid in other_players.keys():
		if not server_ids.has(pid):
			if is_instance_valid(other_players[pid]):
				other_players[pid].queue_free()
			to_remove.append(pid)

	for pid in to_remove:
		other_players.erase(pid)

func _update_world_items(items_data: Array):
	"""Spawn/update/remove world item drops sent by server"""
	var server_ids := {}
	for item_data in items_data:
		var item_id = item_data.get("id")
		server_ids[item_id] = true
		if not world_items.has(item_id):
			if world_item_scene:
				var node = world_item_scene.instantiate()
				node.item_id = item_id
				node.item_name = item_data.get("name", "Item")
				node.position = Vector2(item_data.get("x", 0), item_data.get("y", 0))
				node.connect("input_event", Callable(self, "_on_world_item_input").bind(item_id))
				add_child(node)
				world_items[item_id] = node
		else:
			var node = world_items[item_id]
			if is_instance_valid(node):
				node.position = Vector2(item_data.get("x", 0), item_data.get("y", 0))
				node.set_name_and_color(item_data.get("name", "Item"))

	# Remove items that disappeared server-side (picked up)
	var to_remove := []
	for existing_id in world_items.keys():
		if not server_ids.has(existing_id):
			if is_instance_valid(world_items[existing_id]):
				world_items[existing_id].queue_free()
			to_remove.append(existing_id)

	for existing_id in to_remove:
		world_items.erase(existing_id)

func _on_world_item_input(viewport, event, shape_idx, item_id):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if net_manager:
			# Get inventory UI and check if full
			var inventory_ui = get_node_or_null("/root/CanvasLayer/InventoryUI")
			if inventory_ui and inventory_ui.is_inventory_full():
				print("Cannot pickup: inventory is full!")
				return
			
			var payload = {
				"type": "pickup_item",
				"world_item_id": item_id
			}
			net_manager.send_json(payload)
			# Auto-request inventory refresh after pickup
			await get_tree().create_timer(0.1).timeout
			net_manager.request_inventory()

func _update_enemies(enemies_data: Array):
	"""Update enemy positions and states from server"""
	#print("[ENEMIES] _update_enemies called with %d enemies" % enemies_data.size())
	var server_ids = {}
	
	for enemy_data in enemies_data:
		var enemy_id = enemy_data.get("id")
		var template_name = enemy_data.get("type", "Unknown")
		
		# Create enemy if it doesn't exist yet (for late joiners)
		if not enemy_id in enemies:
			if enemy_scene:
				var enemy = enemy_scene.instantiate()
				enemy.name = "Enemy_%d" % enemy_id
				enemy.position = Vector2(enemy_data.get("x", 0), enemy_data.get("y", 0))
				# Set enemy template info
				enemy.template_id = enemy_data.get("template_id", 0)
				enemy.template_name = template_name
				enemy.level = enemy_data.get("level", 1)
				enemy.max_health = enemy_data.get("max_health", 30)
				enemy.health = enemy_data.get("health", 30)
				add_child(enemy)
				enemies[enemy_id] = enemy
				
				_load_enemy_sprite(enemy, template_name)
		
		server_ids[enemy_id] = true
		
		# Update enemy position and health (check if node is still valid)
		if enemy_id in enemies and is_instance_valid(enemies[enemy_id]):
			var enemy = enemies[enemy_id]
			enemy.position = Vector2(enemy_data.get("x", 0), enemy_data.get("y", 0))
			enemy.health = enemy_data.get("health", enemy.max_health)
			enemy.max_health = enemy_data.get("max_health", 30)
	
	# Remove enemies that no longer exist on server
	var to_remove = []
	for enemy_id in enemies.keys():
		if not enemy_id in server_ids:
			if is_instance_valid(enemies[enemy_id]):
				enemies[enemy_id].queue_free()
			to_remove.append(enemy_id)
		enemy_last_health.erase(enemy_id)
	
	for enemy_id in to_remove:
		enemies.erase(enemy_id)

func _load_enemy_sprite(enemy: Node2D, template_name: String):
	"""Load sprite for enemy based on template name"""
	if template_name in enemy_sprites:
		var sprite_path = enemy_sprites[template_name]
		var sprite = enemy.get_node_or_null("Sprite2D")
		if sprite:
			var texture = load(sprite_path)
			if texture:
				sprite.texture = texture
				print("[ENEMY] Loaded sprite for %s: %s" % [template_name, sprite_path])
			else:
				print("[ENEMY] Failed to load texture: %s" % sprite_path)
		else:
			print("[ENEMY] No Sprite2D node in Enemy scene")
	else:
		print("[ENEMY] No sprite mapping for template: %s" % template_name)

func _update_bullets(bullets_data: Array):
	"""Update bullet positions from server"""

	var server_ids = {}
	
	for bullet_data in bullets_data:
		var bullet_id = bullet_data.get("id")
		server_ids[bullet_id] = true
		
		if not bullet_id in bullets:
			# Spawn new bullet
			if bullet_scene:
				var bullet = bullet_scene.instantiate()
				bullet.name = "Bullet_%d" % bullet_id
				add_child(bullet)
				# Initialize bullet with velocity from server
				var vx = bullet_data.get("vx", 0.0)
				var vy = bullet_data.get("vy", 0.0)
				var x = bullet_data.get("x", 0.0)
				var y = bullet_data.get("y", 0.0)
				bullet.setup(bullet_id, bullet_data.get("shooter_id", 0), Vector2(x, y), vx, vy)
				# print("[BULLETS] Spawned bullet %d at (%.1f, %.1f) with velocity (%.1f, %.1f)" % [bullet_id, x, y, vx, vy])
				bullets[bullet_id] = bullet
			else:
				print("[BULLETS] ERROR: bullet_scene not assigned!")
		
		# Update bullet position
		if bullet_id in bullets and is_instance_valid(bullets[bullet_id]):
			var bullet = bullets[bullet_id]
			bullet.position = Vector2(bullet_data.get("x", 0), bullet_data.get("y", 0))
	
	# Remove bullets that no longer exist on server
	var to_remove = []
	for bullet_id in bullets.keys():
		if not bullet_id in server_ids:
			if is_instance_valid(bullets[bullet_id]):
				bullets[bullet_id].queue_free()
			to_remove.append(bullet_id)
	
	for bullet_id in to_remove:
		bullets.erase(bullet_id)

func _update_health_ui(current: int, max_value: int):
	if health_fill == null or health_label == null:
		return
	var max_safe = max(max_value, 1)
	var clamped = clamp(current, 0, max_safe)
	var percent = float(clamped) / float(max_safe)
	health_fill.size.x = max(0.0, (HEALTH_BAR_WIDTH - 4.0) * percent)  # subtract 4 for 2px inset on each side
	health_label.text = "HP %d/%d" % [clamped, max_safe]

func _update_xp_ui(current: int, level: int):
	if xp_fill == null or xp_label == null:
		_log_client("ERROR: XP UI nodes not initialized - xp_fill=%s, xp_label=%s" % [xp_fill, xp_label])
		return
	
	var xp_needed = int(120.0 * pow(level, 1.5))
	var clamped = clamp(current, 0, xp_needed)
	var percent = float(clamped) / float(max(xp_needed, 1))
	xp_fill.size.x = max(0.0, (XP_BAR_WIDTH - 4.0) * percent)
	xp_label.text = "Level %d: %d / %d XP" % [level, clamped, xp_needed]
	#_log_client("XP Update: Level=%d, Current=%d/%d, Percent=%.2f, BarWidth=%.0f" % [level, clamped, xp_needed, percent, xp_fill.size.x])

func _process(delta):
	"""Send player input to server"""
	if not local_player_alive:
		return
	if not is_server_mode and net_manager:
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		input_send_timer += delta
		
		# Send if input changed OR every 0.1 seconds
		var should_send = (input_dir != last_input_dir) or (input_send_timer >= input_send_interval)
		
		if should_send:
			net_manager.send_json({
				"type": "player_input",
				"dir_x": input_dir.x,
				"dir_y": input_dir.y
			})
			last_input_dir = input_dir
			input_send_timer = 0.0


func _setup_spawner():
	# TCP mode doesn't use MultiplayerSpawner - server is authoritative Java backend
	_log_role("Skipping MultiplayerSpawner setup (TCP mode)")

func spawn_enemy_loop():
	_log_server("Starting enemy spawn loop")

	while true:
		await get_tree().create_timer(2.0).timeout
		spawn_enemy()

func spawn_enemy():
	if enemy_scene == null:
		push_error("[SERVER] Enemy scene not assigned")
		return

	_log_server("Spawning Enemy")

	var enemy = enemy_scene.instantiate()
	enemy.set_multiplayer_authority(1)
	# Give a simple unique name before adding so it doesn't have a reserved internal name
	enemy.name = "Enemy_%d" % randi()
	# Add with legible unique names so MultiplayerSpawner can replicate without name collisions
	add_child(enemy, true)
	# Wait a frame so the spawn is replicated to clients before server-side RPCs are sent
	await get_tree().process_frame

	enemy.position = Vector2(
		randf_range(50, 750),
		randf_range(50, 450)
	)

func _on_local_player_died():
	if death_handled:
		return
	death_handled = true
	_log_client("Local player died, showing result screen")
	call_deferred("_show_result_screen")

func _show_result_screen():
	get_tree().change_scene_to_file("res://scenes/ui/ResultScreen.tscn")

func _on_damage_event_received(target_id: int, target_type: String, damage: int, position: Vector2):
	"""Handle damage event from server"""
	print("[DAMAGE_EVENT] %s ID:%d took %d damage at (%.0f, %.0f)" % [target_type, target_id, damage, position.x, position.y])
	_show_damage_number(position, damage, target_type == "player")

# ------------------------------------------------------------------
# Damage Number Display
# ------------------------------------------------------------------

func _show_damage_number(position: Vector2, damage: int, is_player: bool = false):
	"""Display a floating damage number at the given position using DamageNumber scene"""
	if damage_number_scene == null:
		return
	var dn = damage_number_scene.instantiate()
	if dn == null:
		return
	dn.position = position
	if dn.has_method("set_damage"):
		dn.set_damage(damage, is_player)
	if damage_container and is_instance_valid(damage_container):
		damage_container.add_child(dn)
	else:
		add_child(dn)
	print("[DAMAGE_DISPLAY] Showing %d damage at (%.0f, %.0f) for %s" % [damage, position.x, position.y, "PLAYER" if is_player else "ENEMY"])

# ------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------

func _log_role(message: String):
	print("[WORLD] ", message)

func _log_server(message: String):
	print("[SERVER] ", message)

func _log_client(message: String):
	print("[CLIENT] ", message)
