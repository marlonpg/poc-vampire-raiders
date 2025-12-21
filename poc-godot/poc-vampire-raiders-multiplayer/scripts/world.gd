extends Node2D
class_name World

@export var player_scene: PackedScene
@export var enemy_scene: PackedScene

var spawner: MultiplayerSpawner

func _ready():
	await get_tree().process_frame
	print("[WORLD] Server:", multiplayer.is_server(), "ID:", multiplayer.get_unique_id())

	_log_role("World _ready()")

	_setup_spawner()

	if multiplayer.is_server():
		_log_server("Setting up server-only logic")
		multiplayer.peer_connected.connect(_on_peer_connected)
		spawn_enemy_loop()
	else:
		_log_client("Client ready, waiting for server spawns")

	_log_role("World ready complete")

func _setup_spawner():
	_log_role("Setting up MultiplayerSpawner")

	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)

	# Spawn nodes under World (spawner is a child of World, so use parent path)
	spawner.spawn_path = NodePath("..")

	# Register scenes for replication
	spawner.add_spawnable_scene("res://scenes/Player.tscn")
	spawner.add_spawnable_scene("res://scenes/Enemy.tscn")

	# Log when remote peers spawn/despawn so we can debug replication
	spawner.spawned.connect(_on_spawner_spawned)
	spawner.despawned.connect(_on_spawner_despawned)

	_log_role("Spawner configured (Player + Enemy registered)")

func _on_peer_connected(peer_id: int):
	_log_server("Peer connected → ID = %d" % peer_id)
	spawn_player(peer_id)

func spawn_player(peer_id: int):
	if player_scene == null:
		push_error("[SERVER] Player scene not assigned")
		return

	_log_server("Spawning Player for peer %d" % peer_id)

	var player = player_scene.instantiate()
	player.name = str(peer_id)
	# Keep authority on the server for security; clients send inputs only
	player.set_multiplayer_authority(1)
	# Add with legible unique names so MultiplayerSpawner can replicate without name collisions
	add_child(player, true)
	# Wait a frame so the spawn is replicated to clients before any RPCs target it
	await get_tree().process_frame

	player.position = Vector2(
		randf_range(100, 500),
		randf_range(100, 500)
	)

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

# ------------------------------------------------------------------
# Logging helpers (clean & consistent)
# ------------------------------------------------------------------

func _log_role(message: String):
	print("[", _role(), "] ", message,
		" | Peer ID:", multiplayer.get_unique_id())

# Spawner signals for debugging replication
func _on_spawner_spawned(node: Node):
	_log_role("Spawner spawned -> %s (path=%s)" % [node.name, node.get_path()])

func _on_spawner_despawned(node: Node):
	_log_role("Spawner despawned -> %s (path=%s)" % [node.name, node.get_path()])

func _log_server(message: String):
	if multiplayer.is_server():
		print("[SERVER] ", message, " | Peer ID:", multiplayer.get_unique_id())

func _log_client(message: String):
	if not multiplayer.is_server():
		print("[CLIENT] ", message, " | Peer ID:", multiplayer.get_unique_id())

func _role() -> String:
	return "SERVER" if multiplayer.is_server() else "CLIENT"
