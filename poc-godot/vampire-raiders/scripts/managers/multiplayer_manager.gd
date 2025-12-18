extends Node

# Network configuration
const PORT = 7777
const DEFAULT_IP = "127.0.0.1"
const MAX_PLAYERS = 4

# State
var players_info: Dictionary = {}  # player_id -> {name, position, health, level, xp}
var is_host: bool = false
var local_player_id: int = -1

# Signals
signal player_connected(player_id: int, player_data: Dictionary)
signal player_disconnected(player_id: int)
signal lobby_updated
signal game_started
signal game_state_requested(player_id: int)

func _ready() -> void:
	print("[MultiplayerManager] Initialized as autoload")
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# ============================================================================
# HOST FUNCTIONS
# ============================================================================

func start_host(player_name: String) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PLAYERS)
	
	if error != OK:
		print("Failed to start server: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	# Host always gets peer_id = 1 in Godot's networking
	local_player_id = multiplayer.get_unique_id()
	
	# Register host player
	players_info[local_player_id] = {
		"id": local_player_id,
		"name": player_name,
		"is_host": true,
		"position": Vector2.ZERO,
		"health": 100,
		"max_health": 100,
		"level": 1,
		"xp": 0,
		"ready": false
	}
	
	print("Server started on port ", PORT, " with player_id: ", local_player_id)
	lobby_updated.emit()
	return true

# ============================================================================
# CLIENT FUNCTIONS
# ============================================================================

func join_game(ip: String, player_name: String) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	
	if error != OK:
		print("Failed to create client: ", error)
		return false
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	
	print("Attempting to join server at ", ip, ":", PORT)
	return true

# ============================================================================
# NETWORK CALLBACKS
# ============================================================================

func _on_connected_to_server() -> void:
	print("Successfully connected to server")
	# Request to be added to the game
	var player_data = {
		"id": multiplayer.get_unique_id(),
		"name": "Player " + str(multiplayer.get_unique_id()),
		"position": Vector2.ZERO,
		"health": 100,
		"max_health": 100,
		"level": 1,
		"xp": 0
	}
	local_player_id = multiplayer.get_unique_id()
	rpc("request_player_registration", player_data)

func _on_server_disconnected() -> void:
	print("Disconnected from server")
	is_host = false
	players_info.clear()

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)
	
	if is_host:
		# Host will handle registration
		pass
	
	lobby_updated.emit()

func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
	players_info.erase(peer_id)
	player_disconnected.emit(peer_id)
	lobby_updated.emit()

# ============================================================================
# PLAYER REGISTRATION (RPC - Server Authority)
# ============================================================================

@rpc("any_peer", "call_remote", "reliable")
func request_player_registration(player_data: Dictionary) -> void:
	if not is_host:
		return
	
	var peer_id = multiplayer.get_remote_sender_id()
	
	# Validate player count
	if players_info.size() >= MAX_PLAYERS:
		reject_player.rpc_id(peer_id, "Server is full")
		return
	
	# Register player
	player_data["id"] = peer_id
	player_data["is_host"] = false
	player_data["position"] = _get_spawn_position(players_info.size())
	player_data["ready"] = false
	
	players_info[peer_id] = player_data
	
	print("Player registered: ", peer_id, " - ", player_data["name"])
	
	# Notify all clients of new player
	rpc("notify_player_joined", player_data)
	
	# Send full player list to newly connected player
	rpc_id(peer_id, "send_full_game_state", players_info)

@rpc("authority", "call_remote", "reliable")
func reject_player(reason: String) -> void:
	print("Player rejected: ", reason)
	get_tree().quit()

@rpc("authority", "call_remote", "reliable")
func notify_player_joined(player_data: Dictionary) -> void:
	if player_data["id"] != local_player_id:
		players_info[player_data["id"]] = player_data
	lobby_updated.emit()

@rpc("authority", "call_remote", "reliable")
func send_full_game_state(game_players_info: Dictionary) -> void:
	players_info = game_players_info
	lobby_updated.emit()

# ============================================================================
# PLAYER READY / START GAME
# ============================================================================

func set_player_ready(ready: bool) -> void:
	if local_player_id in players_info:
		players_info[local_player_id]["ready"] = ready
		rpc("notify_ready_status", local_player_id, ready)

@rpc("any_peer", "call_remote", "reliable")
func notify_ready_status(player_id: int, is_ready: bool) -> void:
	if player_id in players_info:
		players_info[player_id]["ready"] = is_ready
		lobby_updated.emit()

func can_start_game() -> bool:
	if not is_host:
		return false
	
	if players_info.size() < 1:
		return false
	
	# At least host must be ready
	if not players_info[local_player_id]["ready"]:
		return false
	
	return true

func start_game() -> void:
	if not is_host or not can_start_game():
		return
	
	print("Host starting game...")
	rpc("begin_game")

@rpc("authority", "call_remote", "reliable")
func begin_game() -> void:
	print("Game started!")
	game_started.emit()

# ============================================================================
# PLAYER STATE SYNCHRONIZATION
# ============================================================================

func update_player_position(position: Vector2) -> void:
	if local_player_id in players_info:
		players_info[local_player_id]["position"] = position
		rpc("sync_player_position", local_player_id, position)

@rpc("any_peer", "call_remote", "unreliable")
func sync_player_position(player_id: int, position: Vector2) -> void:
	if is_host:
		# Server validates position (anti-cheat)
		if _validate_movement(player_id, position):
			if player_id in players_info:
				players_info[player_id]["position"] = position
				# Broadcast corrected position to all
				rpc("broadcast_player_position", player_id, position)
		else:
			print("Position hack detected from player: ", player_id)
	else:
		# Client receives corrected position
		if player_id in players_info:
			players_info[player_id]["position"] = position

@rpc("authority", "call_remote", "unreliable")
func broadcast_player_position(player_id: int, position: Vector2) -> void:
	if player_id in players_info:
		players_info[player_id]["position"] = position

# ============================================================================
# PLAYER STATS SYNCHRONIZATION
# ============================================================================

func update_player_stats(health: int, level: int, xp: int) -> void:
	if local_player_id in players_info:
		players_info[local_player_id]["health"] = health
		players_info[local_player_id]["level"] = level
		players_info[local_player_id]["xp"] = xp
		rpc("sync_player_stats", local_player_id, health, level, xp)

@rpc("any_peer", "call_remote", "unreliable")
func sync_player_stats(player_id: int, health: int, level: int, xp: int) -> void:
	if is_host:
		# Server validates stats (anti-cheat)
		if _validate_stats(player_id, health, level, xp):
			if player_id in players_info:
				players_info[player_id]["health"] = health
				players_info[player_id]["level"] = level
				players_info[player_id]["xp"] = xp
				# Broadcast to all
				rpc("broadcast_player_stats", player_id, health, level, xp)
		else:
			print("Stats hack detected from player: ", player_id)
	else:
		# Client receives stats
		if player_id in players_info:
			players_info[player_id]["health"] = health
			players_info[player_id]["level"] = level
			players_info[player_id]["xp"] = xp

@rpc("authority", "call_remote", "unreliable")
func broadcast_player_stats(player_id: int, health: int, level: int, xp: int) -> void:
	if player_id in players_info:
		players_info[player_id]["health"] = health
		players_info[player_id]["level"] = level
		players_info[player_id]["xp"] = xp

# ============================================================================
# ANTI-CHEAT VALIDATION
# ============================================================================

var last_position: Dictionary = {}  # player_id -> Vector2
var last_position_time: Dictionary = {}  # player_id -> float

func _validate_movement(player_id: int, new_position: Vector2) -> bool:
	if not player_id in last_position:
		last_position[player_id] = new_position
		last_position_time[player_id] = Time.get_ticks_msec() / 1000.0
		return true
	
	var old_position = last_position[player_id]
	var old_time = last_position_time[player_id]
	var current_time = Time.get_ticks_msec() / 1000.0
	var delta_time = current_time - old_time
	
	if delta_time <= 0:
		return false
	
	var distance = old_position.distance_to(new_position)
	var player_data = players_info[player_id]
	var max_speed = 300.0  # Should match player.gd
	var max_allowed_distance = max_speed * delta_time * 1.1  # Allow 10% tolerance for latency
	
	last_position[player_id] = new_position
	last_position_time[player_id] = current_time
	
	return distance <= max_allowed_distance

func _validate_stats(player_id: int, health: int, level: int, xp: int) -> bool:
	if player_id not in players_info:
		return false
	
	var player_data = players_info[player_id]
	
	# Health can't exceed max_health
	if health > player_data["max_health"]:
		return false
	
	# Health can't go below 0 (handled by death system)
	if health < 0:
		return false
	
	# XP can't decrease (only increases)
	if xp < player_data["xp"]:
		return false
	
	# Level can't skip (only increases by 1)
	if level > player_data["level"] + 1:
		return false
	
	return true

# ============================================================================
# DEATH HANDLING
# ============================================================================

func on_player_died(player_id: int) -> void:
	if is_host:
		rpc("handle_player_death", player_id)

@rpc("authority", "call_remote", "reliable")
func handle_player_death(player_id: int) -> void:
	if player_id in players_info:
		print("Player died: ", player_id)
		# TODO: Drop all inventory items
		# This will be handled by the Inventory system

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func get_players_info() -> Dictionary:
	return players_info

func get_player_count() -> int:
	return players_info.size()

func is_player_host(player_id: int) -> bool:
	if player_id in players_info:
		return players_info[player_id].get("is_host", false)
	return false

func _get_spawn_position(player_index: int) -> Vector2:
	var spawn_positions = [
		Vector2(0, 0),           # Host/Player 1
		Vector2(200, 0),         # Player 2
		Vector2(0, 200),         # Player 3
		Vector2(200, 200)        # Player 4
	]
	
	if player_index < spawn_positions.size():
		return spawn_positions[player_index]
	
	return Vector2.ZERO

func disconnect_from_server() -> void:
	multiplayer.multiplayer_peer = null
	is_host = false
	players_info.clear()
	local_player_id = -1
