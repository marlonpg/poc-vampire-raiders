extends Node2D

var multiplayer_manager: Node
var spawned_players: Dictionary = {}  # player_id -> player_node

func _ready() -> void:
	multiplayer_manager = get_tree().root.get_node("MultiplayerManager")
	
	print("[GameWorld] Local player ID: ", multiplayer_manager.local_player_id)
	print("[GameWorld] Is host: ", multiplayer_manager.is_host)
	
	# Spawn all connected players
	_spawn_all_players()
	
	# Listen for new players (if anyone joins during game)
	multiplayer_manager.player_connected.connect(_on_player_connected)
	multiplayer_manager.player_disconnected.connect(_on_player_disconnected)

func _process(_delta: float) -> void:
	# Update remote player positions from network state
	var players_info = multiplayer_manager.get_players_info()
	for player_id in players_info.keys():
		# Skip host player (no visual representation)
		if players_info[player_id].get("is_host", false):
			continue
		
		if player_id in spawned_players:
			var player_node = spawned_players[player_id]
			var player_data = players_info[player_id]
			# Update position if it's different (for remote players)
			if not player_node.is_local_player and player_node.position != player_data["position"]:
				player_node.position = player_data["position"]

func _spawn_all_players() -> void:
	var players_info = multiplayer_manager.get_players_info()
	print("[GameWorld] Spawning %d players" % players_info.size())
	
	for player_id in players_info.keys():
		var player_data = players_info[player_id]
		# Skip spawning the host player (server only handles validation, doesn't play)
		if player_data.get("is_host", false):
			print("[GameWorld] Skipping host player spawn: %d - %s" % [player_id, player_data.get("name", "Unknown")])
			continue
		print("[GameWorld] Found player: %d - %s" % [player_id, player_data.get("name", "Unknown")])
		_spawn_player(player_id, player_data)

func _spawn_player(player_id: int, player_data: Dictionary) -> void:
	var player_scene = preload("res://scenes/player/Player.tscn")
	var player = player_scene.instantiate()
	
	# Set position from player data
	player.position = player_data["position"]
	player.player_id = player_id
	player.is_local_player = (player_id == multiplayer_manager.local_player_id)
	
	# Set multiplayer authority
	player.set_multiplayer_authority(player_id)
	
	add_child(player)
	spawned_players[player_id] = player
	
	var local_indicator = "LOCAL" if player.is_local_player else "REMOTE"
	print("[GameWorld] Spawned %s player %d (%s) at %s" % [local_indicator, player_id, player_data.get("name", "Unknown"), player.position])
	
	# Ensure only local player's camera is active
	if not player.is_local_player:
		# Disable any cameras on remote players
		for cam in player.find_children("*", "Camera2D"):
			cam.enabled = false

func _on_player_connected(player_id: int) -> void:
	# If a new player joins during the game
	var player_data = multiplayer_manager.players_info.get(player_id)
	if player_data:
		_spawn_player(player_id, player_data)

func _on_player_disconnected(player_id: int) -> void:
	# Clean up disconnected player
	if player_id in spawned_players:
		spawned_players[player_id].queue_free()
		spawned_players.erase(player_id)
		print("Player disconnected: ", player_id)

func get_all_players() -> Array:
	return spawned_players.values()
