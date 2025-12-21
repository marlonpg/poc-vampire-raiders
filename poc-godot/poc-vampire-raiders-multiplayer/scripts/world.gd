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

	# On clients, activate Camera2D for the local player's spawned instance.
	if not multiplayer.is_server():
		# Ensure the spawn is fully in the tree and settled
		await get_tree().process_frame
		await get_tree().process_frame
		# If this spawned node is the local player, enable its camera
		if node is Player:
			var my_id := multiplayer.get_unique_id()
			# Node name holds the peer id (server sets player.name = str(peer_id))
			var name_str := str(node.name)
			var nid := name_str.to_int()
			# Peer IDs are positive integers (server=1), so check > 0 to validate
			if nid > 0 and my_id == nid:
				# Local player spawn detected; ensure we have a camera and make it current
				_log_client("Local player spawn detected for id=%d" % nid)
				# Disable any other Camera2D instances first to avoid a remote camera being active
				var root := get_tree().get_root()
				var cams := root.find_children("", "Camera2D", true, true)
				for c in cams:
					if c.is_inside_tree():
						var c_path: String = str(c.get_path())
						var c_parent_name: String = (str(c.get_parent().name) if c.get_parent() != null else "nil")
						_log_client("Disabling camera id=%d path=%s parent=%s" % [c.get_instance_id(), c_path, c_parent_name])
					# Defer deactivation to avoid touching viewport/camera state during instantiation
					call_deferred("_deactivate_camera", c)
				# Activate local player's camera deferred to ensure it becomes current reliably
				var cam = node.get_node_or_null("Camera2D")
				if cam != null:
					cam.call_deferred("make_current")
					call_deferred("_report_camera_activation", cam, node.name)
					_log_client("Activated camera for local player %s" % node.name)
				else:
					# No Camera2D present on the spawned Player — create a client-only camera
					_log_client("No Camera2D found on local player %s; creating one now" % node.name)
					var new_cam: Camera2D = Camera2D.new()
					new_cam.name = "Camera2D_local"
					# NOTE: Some engine versions may not expose smoothing via script; avoid setting it to prevent errors
					node.add_child(new_cam)
					# Activate and report using deferred calls
					new_cam.call_deferred("make_current")
					call_deferred("_report_camera_activation", new_cam, node.name)
					_log_client("Created and activated Camera2D id=%d for player %s" % [new_cam.get_instance_id(), node.name])

func _on_spawner_despawned(node: Node):
	if node.is_inside_tree():
		_log_role("Spawner despawned -> %s (path=%s)" % [node.name, node.get_path()])
	else:
		_log_role("Spawner despawned -> %s (not in tree)" % node.name)

# Camera debug reports (client-side helpers)
func _report_camera_activation(cam: Camera2D, player_name: String):
	if cam == null:
		_log_client("Camera activation report: camera is null for player %s" % player_name)
		return
	var path: String = (str(cam.get_path()) if cam.is_inside_tree() else "not in tree")
	var parent_name: String = (str(cam.get_parent().name) if cam.get_parent() != null else "nil")
	_log_client("Camera activation report: id=%d path=%s parent=%s current=%s for player=%s" % [cam.get_instance_id(), path, parent_name, str(cam.is_current()), player_name])

func _report_camera_disabled(cam: Camera2D):
	if cam == null:
		return
	var path: String = (str(cam.get_path()) if cam.is_inside_tree() else "not in tree")
	var parent_name: String = (str(cam.get_parent().name) if cam.get_parent() != null else "nil")
	_log_client("Camera disabled report: id=%d path=%s parent=%s current=%s" % [cam.get_instance_id(), path, parent_name, str(cam.is_current())])
# Safely deactivate a Camera2D by clearing it from the viewport if it's the active camera
func _deactivate_camera(cam: Camera2D):
	if cam == null:
		return
	if not cam.is_inside_tree():
		# Nothing to do
		return
	var vp := cam.get_viewport()
	if vp != null:
		var active := vp.get_camera_2d()
		if active == cam:
			vp.set_camera_2d(null)
	# Report final state
	_report_camera_disabled(cam)
func _log_server(message: String):
	if multiplayer.is_server():
		print("[SERVER] ", message, " | Peer ID:", multiplayer.get_unique_id())

func _log_client(message: String):
	if not multiplayer.is_server():
		print("[CLIENT] ", message, " | Peer ID:", multiplayer.get_unique_id())

func _role() -> String:
	return "SERVER" if multiplayer.is_server() else "CLIENT"
