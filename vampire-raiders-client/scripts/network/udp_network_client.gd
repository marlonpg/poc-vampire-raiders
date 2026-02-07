extends Node
## Facade over NetworkManager (TCP) providing a UDP-style client API
## Reuses the autoloaded NetworkManager to keep UI/inventory working

const PORT := 7777

var server_ip: String = ""
var peer_id: int = -1
var connected: bool = false
var _connected_emitted: bool = false
var net_manager: Node
var udp: PacketPeerUDP
var udp_ready: bool = false
var udp_registered: bool = false
var udp_seq: int = 1
var udp_disabled: bool = false
var udp_failures: int = 0
const UDP_FAIL_THRESHOLD := 6

signal connected_to_server
signal server_message(data: Dictionary)
signal disconnected_from_server

func _ready():
	net_manager = get_node_or_null("/root/NetworkManager")
	if not net_manager:
		push_error("[UDP_FACADE] NetworkManager autoload not found")
		return

	# Bridge NetworkManager signals into a generic server_message stream
	net_manager.game_state_received.connect(_on_game_state)
	net_manager.inventory_received.connect(_on_inventory)
	net_manager.damage_event_received.connect(_on_damage_event)
	print("[UDP_FACADE] Ready and bound to NetworkManager")
	udp = PacketPeerUDP.new()

func connect_to_server(ip: String) -> bool:
	server_ip = ip
	if not net_manager:
		push_error("[UDP_FACADE] No NetworkManager to connect")
		return false
	print("[UDP_FACADE] Connecting via NetworkManager to ", ip)
	net_manager.start_client(ip)
	# Prepare UDP remote (connectionless)
	var err = udp.connect_to_host(ip, PORT)
	if err == OK:
		udp_disabled = false
		udp_failures = 0
		udp_registered = false
		udp_seq = 1
		udp_ready = true
		print("[UDP_FACADE] UDP ready for host ", ip, ":", PORT)
	else:
		udp_ready = false
		_register_udp_failure("connect_to_host failed: %s" % err)
	return true

func send_json(data: Dictionary) -> bool:
	if not net_manager:
		return false
	return net_manager.send_json(data)

func send_player_join(username: String, x: float, y: float) -> bool:
	var msg = {
		"type": "player_join",
		"username": username,
		"x": x,
		"y": y
	}
	return send_json(msg)

func send_player_input(dir_x: float, dir_y: float) -> bool:
	if _udp_available():
		var dx_i := int(round(dir_x * 10000.0))
		var dy_i := int(round(dir_y * 10000.0))
		var payload := {
			"type": "player_input",
			"peer_id": peer_id,
			"dir_x": dir_x,
			"dir_y": dir_y,
			"dx_i": dx_i,
			"dy_i": dy_i,
			"token": net_manager.udp_token,
			"seq": udp_seq,
			"hmac": _compute_hmac("player_input", peer_id, udp_seq, dx_i, dy_i)
		}
		var ok = _send_udp_json(payload)
		if ok:
			udp_seq += 1
			return true
		# fall through to TCP on UDP failure
	# Fallback to TCP if UDP not ready
	var msg = {"type": "player_input", "dir_x": dir_x, "dir_y": dir_y}
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
	if not net_manager:
		return
	# Detect connected state via NetworkManager peer_id
	if not _connected_emitted and net_manager.peer_id != -1:
		_connected_emitted = true
		connected = true
		peer_id = net_manager.peer_id
		connected_to_server.emit()
		print("[UDP_FACADE] Connected (peer=", peer_id, ")")

	# After peer_id assigned, register UDP endpoint once
	if connected and udp_ready and not udp_registered and peer_id != -1 and not udp_disabled:
		var payload := {
			"type": "register_udp",
			"peer_id": peer_id,
			"token": net_manager.udp_token,
			"seq": udp_seq,
			"hmac": _compute_hmac("register_udp", peer_id, udp_seq)
		}
		var ok = _send_udp_json(payload)
		if ok:
			udp_registered = true
			print("[UDP_FACADE] UDP registered for peer ", peer_id)
			udp_seq += 1
		else:
			_register_udp_failure("register_udp send failed")

func _on_game_state(data: Dictionary):
	# Re-emit as a generic server_message for bootstrap consumers
	var payload := {"type": "game_state"}
	for k in data.keys():
		payload[k] = data[k]
	server_message.emit(payload)

func _on_inventory(data: Dictionary):
	var payload := {"type": "inventory"}
	for k in data.keys():
		payload[k] = data[k]
	server_message.emit(payload)

func _on_damage_event(target_id: int, target_type: String, damage: int, position: Vector2, map_id: String):
	server_message.emit({
		"type": "player_damage",
		"victim_id": target_id,
		"damage": damage,
		"x": position.x,
		"y": position.y,
		"map_id": map_id
	})

func disconnect_from_server():
	if net_manager and net_manager.socket:
		net_manager.socket.disconnect_from_host()
	connected = false
	disconnected_from_server.emit()
	print("[UDP_FACADE] Disconnected")

func is_connected_to_server() -> bool:
	if not net_manager:
		return false
	return net_manager.is_tcp_connected()

# Internal helper to send a UDP JSON packet
func _send_udp_json(data: Dictionary) -> bool:
	if not udp_ready:
		return false
	var json_str = JSON.stringify(data)
	var err = udp.put_packet(json_str.to_utf8_buffer())
	if err != OK:
		_register_udp_failure("send failed: %s" % err)
		return false
	udp_failures = 0
	return true

func _udp_available() -> bool:
	if udp_disabled:
		return false
	return udp_ready and connected and peer_id != -1 and udp_registered

func _register_udp_failure(reason: String):
	udp_failures += 1
	push_error("[UDP_FACADE] UDP error %d/%d: %s" % [udp_failures, UDP_FAIL_THRESHOLD, reason])
	if udp_failures >= UDP_FAIL_THRESHOLD:
		udp_disabled = true
		udp_registered = false
		udp_ready = false
		push_error("[UDP_FACADE] UDP disabled after repeated failures; falling back to TCP-only")

# Compute HMAC-SHA256 as lowercase hex over canonical fields
func _compute_hmac(msg_type: String, pid: int, seq: int, dx_i: int = 0, dy_i: int = 0) -> String:
	var sb := "%s|%d|%d" % [msg_type, pid, seq]
	if msg_type == "player_input":
		sb += "|%d|%d" % [dx_i, dy_i]
	var crypto := Crypto.new()
	var key: PackedByteArray = net_manager.udp_token.to_utf8_buffer()
	var msg := sb.to_utf8_buffer()
	var mac := crypto.hmac_digest(HashingContext.HASH_SHA256, key, msg)
	return mac.hex_encode()
