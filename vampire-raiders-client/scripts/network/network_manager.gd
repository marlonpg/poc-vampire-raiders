extends Node

const PORT := 7777

signal game_state_received(data: Dictionary)
signal inventory_received(data: Dictionary)
signal item_picked_up(world_item_id: int)
signal damage_event_received(target_id: int, target_type: String, damage: int, position: Vector2, map_id: String)
signal latency_updated(rtt_ms: float)

var socket: StreamPeerTCP
var server_ip: String = ""
var is_server: bool = false
var peer_id: int = -1
var udp_token: String = ""
var connected: bool = false
var connection_time: float = 0.0
var last_status: int = -1
var heartbeat_timer: float = 0.0
var heartbeat_interval: float = 5.0

# RTT (ping) tracking
var last_rtt_ms: float = -1.0
var ping_timer: float = 0.0
var ping_interval: float = 1.0
var pending_ping_client_ms: int = -1

func _ready():
	print("[NETWORK] Ready (TCP)")

# =========================
# SERVER
# =========================
func start_server():
	print("[NETWORK] SERVER mode not supported in TCP client")
	print("[NETWORK] Run Java server: ./start.bat")

# =========================
# CLIENT
# =========================
func start_client(ip: String):
	server_ip = ip
	socket = StreamPeerTCP.new()
	print("[NETWORK] Connecting to ", ip, ":", PORT)
	var err = socket.connect_to_host(ip, PORT)
	
	if err != OK:
		push_error("[NETWORK] Failed to connect: ", err)
		return
	
	connection_time = 0.0
	heartbeat_timer = 0.0
	print("[NETWORK] TCP connection initiated")

func _process(delta):
	if not socket:
		return
	
	connection_time += delta
	var status = socket.get_status()
	
	if status != last_status:
		print("[NETWORK] Status changed: ", last_status, " -> ", status, " (", connection_time, "s)")
		last_status = status
	
	# Workaround: Godot 4's StreamPeerTCP doesn't properly transition to STATUS_CONNECTED
	# If we've been CONNECTING for more than 0.1s and can send data, treat it as connected
	if not connected and status == StreamPeerTCP.STATUS_CONNECTING and connection_time > 0.1:
		connected = true
		print("[NETWORK] Connected!")
		heartbeat_timer = 0.0
		_on_connected_to_server()
	
	if status == StreamPeerTCP.STATUS_CONNECTED or (connected and status == StreamPeerTCP.STATUS_CONNECTING):
		# Send ping periodically to estimate RTT (ms)
		ping_timer += delta
		if ping_timer >= ping_interval:
			ping_timer = 0.0
			var now_ms := Time.get_ticks_msec()
			# Avoid stacking multiple pings; if one is stuck, allow a new one after 5s
			if pending_ping_client_ms == -1 or (now_ms - pending_ping_client_ms) > 5000:
				pending_ping_client_ms = now_ms
				send_json({"type": "ping", "client_time_ms": now_ms})

		# Send heartbeat periodically
		heartbeat_timer += delta
		if heartbeat_timer >= heartbeat_interval:
			heartbeat_timer = 0.0
			send_json({"type": "heartbeat"})
		
		# Read messages
		var available_bytes = socket.get_available_bytes()
		if available_bytes > 0:
			var bytes = socket.get_data(available_bytes)
			if bytes[0] != OK:
				# Read error, skip this frame
				return
			
			var data = bytes[1].get_string_from_utf8()
			if data == "":
				return
				
			for line in data.split("\n"):
				if line.is_empty():
					continue
				
				var json = JSON.new()
				if json.parse(line) == OK:
					_handle_server_message(json.data)
	elif status == StreamPeerTCP.STATUS_NONE and connected:
		connected = false
		print("[NETWORK] Disconnected!")
		_on_connection_failed()

func _handle_server_message(data: Dictionary):
	match data.get("type"):
		"player_joined":
			peer_id = data.get("peer_id", -1)
			udp_token = data.get("udp_token", "")
			print("[NETWORK] Got peer ID: ", peer_id)
		"game_state":
			game_state_received.emit(data)
		"inventory":
			inventory_received.emit(data)
		"damage_event":
			var target_id = data.get("target_id", -1)
			var target_type = data.get("target_type", "")
			var damage = data.get("damage", 0)
			var x = data.get("x", 0.0)
			var y = data.get("y", 0.0)
			var map_id = data.get("map_id", "main")
			damage_event_received.emit(target_id, target_type, damage, Vector2(x, y), map_id)
		"pong":
			var echoed_ms = int(data.get("client_time_ms", -1))
			if echoed_ms != -1:
				var now_ms := Time.get_ticks_msec()
				last_rtt_ms = float(now_ms - echoed_ms)
				latency_updated.emit(last_rtt_ms)
				# Clear pending ping if this matches the latest
				if pending_ping_client_ms == echoed_ms:
					pending_ping_client_ms = -1
		_:
			pass

func send_json(data: Dictionary) -> bool:
	if not socket:
		print("[NETWORK] send_json: socket is null")
		return false
	
	socket.poll()  # Poll socket to update status
	var status = socket.get_status()
	if status != StreamPeerTCP.STATUS_CONNECTED and status != StreamPeerTCP.STATUS_CONNECTING:
		print("[NETWORK] send_json: bad status=", status)
		return false
	
	var json_str = JSON.stringify(data)
	var result = socket.put_data((json_str + "\n").to_utf8_buffer()) == OK
	return result

# Preferred input sender: UDP-first with TCP fallback
func send_player_input(dir_x: float, dir_y: float) -> bool:
	# Look for UDP helper under Bootstrap
	var udp_client: Node = get_node_or_null("/root/Bootstrap/UDPNetworkClient")
	if udp_client and udp_client.has_method("send_player_input"):
		var ok = udp_client.send_player_input(dir_x, dir_y)
		if ok:
			return true
	# Fallback to TCP JSON
	return send_json({
		"type": "player_input",
		"dir_x": dir_x,
		"dir_y": dir_y
	})

func is_tcp_connected() -> bool:
	if not socket:
		return false
	var status = socket.get_status()
	# Accept either CONNECTED or CONNECTING (with workaround flag)
	return connected and (status == StreamPeerTCP.STATUS_CONNECTED or status == StreamPeerTCP.STATUS_CONNECTING)

func is_client_mode() -> bool:
	return socket != null

func request_inventory():
	send_json({"type": "get_inventory"})

# =========================
# SIGNALS
# =========================
func _on_connected_to_server():
	print("[NETWORK] Connected!")

func _on_connection_failed():
	push_error("[NETWORK] Connection failed")

func _on_peer_connected(id: int):
	print("[NETWORK] Peer connected:", id)

func _on_peer_disconnected(id: int):
	print("[NETWORK] Peer disconnected:", id)
