extends Node2D
class_name World

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene
@export var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

var spawner: MultiplayerSpawner
var is_server_mode: bool = false
var player_instance: Node2D = null
var net_manager: Node = null
var enemies: Dictionary = {}  # ID -> enemy node
var bullets: Dictionary = {}  # ID -> bullet node
var other_players: Dictionary = {}  # peer_id -> player node (excluding local)
var last_input_dir: Vector2 = Vector2.ZERO
var input_send_timer: float = 0.0
var input_send_interval: float = 0.1  # Send input every 0.1 seconds
var local_player_alive: bool = true
var death_handled: bool = false
var local_max_health: int = 100

const HEALTH_BAR_WIDTH := 220.0

@onready var health_fill: ColorRect = $HUD/MarginRoot/VBoxContainer/BarBG/HealthFill
@onready var health_label: Label = $HUD/MarginRoot/VBoxContainer/HealthLabel

func _ready():
	await get_tree().process_frame
	
	# Get the network manager first
	net_manager = get_node("/root/NetworkManager")
	
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
			net_manager.game_state_received.connect(_on_game_state_received)
			
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
	var join_msg = {
		"type": "player_join",
		"username": "Player_%d" % randi_range(1000, 9999),
		"x": 640.0,
		"y": 360.0
	}
	var sent = net_manager.send_json(join_msg)
	_log_client("Send result: " + str(sent))
	
	# Spawn player locally
	if player_scene:
		player_instance = player_scene.instantiate()
		player_instance.name = str(net_manager.peer_id)
		player_instance.position = Vector2(640, 360)
		add_child(player_instance)
		_log_client("Local player spawned")

func _on_game_state_received(data: Dictionary):
	"""Handle game state updates from server"""
	var players = data.get("players", [])
	var enemies_data = data.get("enemies", [])
	var bullets_data = data.get("bullets", [])
	
	# Update players (local + others)
	_update_players(players)
	
	# Update enemies
	_update_enemies(enemies_data)
	
	# Update bullets
	_update_bullets(bullets_data)

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
			if player_instance:
				player_instance.position = Vector2(p.get("x", 0), p.get("y", 0))
				player_instance.health = p.get("health", 100)
			elif player_scene:
				player_instance = player_scene.instantiate()
				player_instance.name = str(pid)
				player_instance.position = Vector2(p.get("x", 0), p.get("y", 0))
				add_child(player_instance)
			if player_instance:
				_update_health_ui(player_instance.health, local_max_health)
			if previous_alive and not local_player_alive:
				_on_local_player_died()
		else:
			# Remote players
			if not other_players.has(pid) and player_scene:
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

func _update_enemies(enemies_data: Array):
	"""Update enemy positions and states from server"""
	var server_ids = {}
	
	for enemy_data in enemies_data:
		var enemy_id = enemy_data.get("id")
		server_ids[enemy_id] = true
		
		if not enemy_id in enemies:
			# Spawn new enemy
			if enemy_scene:
				var enemy = enemy_scene.instantiate()
				enemy.name = "Enemy_%d" % enemy_id
				add_child(enemy)
				enemies[enemy_id] = enemy
		
		# Update enemy position (check if node is still valid)
		if enemy_id in enemies and is_instance_valid(enemies[enemy_id]):
			var enemy = enemies[enemy_id]
			enemy.position = Vector2(enemy_data.get("x", 0), enemy_data.get("y", 0))
	
	# Remove enemies that no longer exist on server
	var to_remove = []
	for enemy_id in enemies.keys():
		if not enemy_id in server_ids:
			if is_instance_valid(enemies[enemy_id]):
				enemies[enemy_id].queue_free()
				# print("[ENEMIES] Removed enemy %d from client" % enemy_id)
			to_remove.append(enemy_id)
	
	for enemy_id in to_remove:
		enemies.erase(enemy_id)

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
	get_tree().change_scene_to_file("res://scenes/ResultScreen.tscn")

# ------------------------------------------------------------------
# Logging helpers
# ------------------------------------------------------------------

func _log_role(message: String):
	print("[WORLD] ", message)

func _log_server(message: String):
	print("[SERVER] ", message)

func _log_client(message: String):
	print("[CLIENT] ", message)
