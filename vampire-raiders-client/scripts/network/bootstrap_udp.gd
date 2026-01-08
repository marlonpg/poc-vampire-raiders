extends Node
## Dev-only helper: manual UDP bootstrap (not used in default startup)

@export var server_ip: String = "127.0.0.1"
@export var player_username: String = "TestPlayer"

var udp_client: Node
var player_scene = preload("res://scenes/gameplay/Player.tscn")
var player_instance: Node2D

func _ready():
	# Load the UDP network client
	udp_client = get_node_or_null("UDPNetworkClient")
	if not udp_client:
		udp_client = preload("res://scripts/network/udp_network_client.gd").new()
		add_child(udp_client)
	
	# Connect signals
	udp_client.connected_to_server.connect(_on_connected_to_server)
	udp_client.server_message.connect(_on_server_message)
	udp_client.disconnected_from_server.connect(_on_disconnected_from_server)
	
	# Connect to server
	if not udp_client.connect_to_server(server_ip):
		push_error("[BOOTSTRAP] Failed to initiate connection")
		return
	
	print("[BOOTSTRAP] Connection initiated to ", server_ip)

func _on_connected_to_server():
	print("[BOOTSTRAP] Connected to server!")
	
	# Send player join message
	var start_x = 640.0
	var start_y = 360.0
	
	if not udp_client.send_player_join(player_username, start_x, start_y):
		push_error("[BOOTSTRAP] Failed to send player join")
		return
	
	# Spawn local player
	player_instance = player_scene.instantiate()
	player_instance.position = Vector2(start_x, start_y)
	player_instance.name = str(udp_client.peer_id)
	add_child(player_instance)
	
	print("[BOOTSTRAP] Player spawned with peer ID: ", udp_client.peer_id)

func _on_server_message(data: Dictionary):
	print("[BOOTSTRAP] Server message: ", data.get("type"))
	
	match data.get("type"):
		"game_state":
			_handle_game_state(data)
		"player_damage":
			_handle_player_damage(data)
		"enemy_spawn":
			_handle_enemy_spawn(data)
		_:
			print("[BOOTSTRAP] Unknown message type: ", data.get("type"))

func _handle_game_state(data: Dictionary):
	# Update game state from server
	if player_instance:
		var players = data.get("players", [])
		for player_data in players:
			if player_data.get("peer_id") == udp_client.peer_id:
				player_instance.position = Vector2(player_data.get("x"), player_data.get("y"))
				player_instance.health = player_data.get("health")
				player_instance.xp = player_data.get("xp")

func _handle_player_damage(data: Dictionary):
	var victim_id = data.get("victim_id")
	var damage = data.get("damage")
	print("[BOOTSTRAP] Player ", victim_id, " took ", damage, " damage")

func _handle_enemy_spawn(data: Dictionary):
	print("[BOOTSTRAP] Enemy spawned: ", data.get("id"))

func _on_disconnected_from_server():
	print("[BOOTSTRAP] Disconnected from server")

func _process(_delta):
	if udp_client and udp_client.is_connected_to_server():
		# Send player input
		var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input.length_squared() > 0:
			udp_client.send_player_input(input.x, input.y)
		
		# Update player position (local prediction)
		if player_instance:
			var velocity = input.normalized() * 200
			player_instance.position += velocity * _delta

func _exit_tree():
	if udp_client:
		udp_client.disconnect_from_server()
