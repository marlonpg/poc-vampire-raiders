extends Node

const PORT = 7777
const MAX_PLAYERS = 4

var peer = ENetMultiplayerPeer.new()
var players = {}
var player_scene = preload("res://scenes/player/Player.tscn")

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal players_ready

func create_server() -> void:
	peer.create_server(PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	print("Server started on port %d" % PORT)

func create_client(address: String) -> void:
	peer.create_client(address, PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	print("Connecting to %s:%d" % [address, PORT])

func _on_player_connected(id: int) -> void:
	print("Player connected: %d" % id)
	players[id] = null
	player_connected.emit(id)

func _on_player_disconnected(id: int) -> void:
	print("Player disconnected: %d" % id)
	if players.has(id):
		players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("Connected to server!")

func _on_connection_failed() -> void:
	print("Connection failed!")

func is_server() -> bool:
	return multiplayer.is_server()

func spawn_player(peer_id: int, spawn_pos: Vector2 = Vector2.ZERO) -> void:
	if not is_server():
		return
	
	var player = player_scene.instantiate()
	player.name = "Player_%d" % peer_id
	player.global_position = spawn_pos
	player.set_multiplayer_authority(peer_id)
	
	var game_world = get_tree().root.get_node_or_null("GameWorld")
	if game_world:
		game_world.add_child(player, true)
		players[peer_id] = player
		print("Spawned player for peer %d" % peer_id)
	else:
		print("ERROR: GameWorld not found!")

func spawn_all_players() -> void:
	if not is_server():
		return
	
	var spawn_positions = [
		Vector2(0, 0),
		Vector2(100, 0),
		Vector2(-100, 0),
		Vector2(0, 100)
	]
	
	var idx = 0
	for peer_id in multiplayer.get_peers():
		spawn_player(peer_id, spawn_positions[idx])
		idx += 1
	
	spawn_player(1, spawn_positions[idx])
	players_ready.emit()
