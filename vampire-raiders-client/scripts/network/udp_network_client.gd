extends Node
## TCP-based network client for Java server communication
## Uses raw TCP sockets to send/receive JSON directly

const PORT := 7777
const BUFFER_SIZE := 4096

var socket: StreamPeerTCP
var server_ip: String = ""
var peer_id: int = -1
var connected: bool = false
var connection_time: float = 0.0
var last_status_printed: int = -1

signal connected_to_server
signal server_message(data: Dictionary)
signal disconnected_from_server

func _ready():
	socket = StreamPeerTCP.new()
	print("[TCP_CLIENT] Ready")

func connect_to_server(ip: String) -> bool:
	server_ip = ip
	print("[TCP_CLIENT] Attempting to connect to ", ip, ":", PORT)
	var err = socket.connect_to_host(ip, PORT)
	
	if err != OK:
		push_error("[TCP_CLIENT] Failed to connect: ", err)
		return false
	
	connection_time = 0.0
	print("[TCP_CLIENT] Connecting to ", ip, ":", PORT)
	return true

func send_json(data: Dictionary) -> bool:
	if not socket or socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	
	var json_str = JSON.stringify(data)
	var err = socket.put_data((json_str + "\n").to_utf8_buffer())
	
	if err != OK:
		push_error("[TCP_CLIENT] Failed to send packet: ", err)
		return false
	
	return true

func send_player_join(username: String, x: float, y: float) -> bool:
	var msg = {
		"type": "player_join",
		"username": username,
		"x": x,
		"y": y
	}
	return send_json(msg)

func send_player_input(dir_x: float, dir_y: float) -> bool:
	var msg = {
		"type": "player_input",
		"dir_x": dir_x,
		"dir_y": dir_y
	}
	return send_json(msg)

func send_player_action(action: String) -> bool:
	var msg = {
		"type": "player_action",
		"action": action
	}
	return send_json(msg)

func send_heartbeat() -> bool:
	var msg = {
		"type": "heartbeat"
	}
	return send_json(msg)

func _process(delta):
	if not socket:
		return
	
	connection_time += delta
	
	# Check connection status
	var status = socket.get_status()
	
	# Print status only when it changes
	if status != last_status_printed:
		print("[TCP_CLIENT] Status changed to: ", status, " (time: %.2f)" % connection_time)
		last_status_printed = status
	
	if status == StreamPeerTCP.STATUS_NONE:
		return
	elif status == StreamPeerTCP.STATUS_CONNECTING:
		if connection_time > 10.0:
			print("[TCP_CLIENT] Connection timeout after 10 seconds")
			disconnect_from_server()
		return
	elif status == StreamPeerTCP.STATUS_CONNECTED:
		if not connected:
			connected = true
			print("[TCP_CLIENT] TCP Socket connected!")
		
		# Read incoming messages
		while socket.get_available_bytes() > 0:
			var line = socket.get_utf8_line()
			if line.is_empty():
				continue
			
			print("[TCP_CLIENT] Received: ", line.length(), " bytes")
			
			var json = JSON.new()
			var err = json.parse(line)
			
			if err != OK:
				push_error("[TCP_CLIENT] Failed to parse JSON: ", line)
				continue
			
			var data = json.data as Dictionary
			_on_server_message(data)
	else:
		# Disconnected or error
		print("[TCP_CLIENT] Socket status error: ", status)
		if connected:
			disconnect_from_server()

func _on_server_message(data: Dictionary):
	print("[TCP_CLIENT] Received: ", data.get("type", "unknown"))
	
	match data.get("type"):
		"player_joined":
			peer_id = data.get("peer_id", -1)
			connected_to_server.emit()
			print("[TCP_CLIENT] Player joined with peer ID: ", peer_id)
		_:
			server_message.emit(data)

func disconnect_from_server():
	if socket:
		socket.disconnect_from_host()
	connected = false
	disconnected_from_server.emit()
	print("[TCP_CLIENT] Disconnected")

func is_connected_to_server() -> bool:
	return connected and socket and socket.get_status() == StreamPeerTCP.STATUS_CONNECTED
