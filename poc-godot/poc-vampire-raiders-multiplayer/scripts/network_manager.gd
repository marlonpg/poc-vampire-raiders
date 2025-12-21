extends Node

const PORT := 7777

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	print("[NETWORK] Ready")

# =========================
# SERVER
# =========================
func start_server():
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)

	if err != OK:
		push_error("[NETWORK] Failed to start server: " + str(err))
		return

	multiplayer.multiplayer_peer = peer

	print("[NETWORK] SERVER started on port", PORT)
	print("[NETWORK] Server peer ID:", multiplayer.get_unique_id())

# =========================
# CLIENT
# =========================
func start_client(ip: String):
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)

	if err != OK:
		push_error("[NETWORK] Failed to connect to server: " + str(err))
		return

	multiplayer.multiplayer_peer = peer
	print("[NETWORK] Connecting to", ip, ":", PORT)

# =========================
# SIGNALS
# =========================
func _on_connected_to_server():
	print("[NETWORK] Connected to server")
	print("[NETWORK] Client peer ID:", multiplayer.get_unique_id())

func _on_connection_failed():
	push_error("[NETWORK] Connection failed")

func _on_peer_connected(id: int):
	print("[NETWORK] Peer connected:", id)

func _on_peer_disconnected(id: int):
	print("[NETWORK] Peer disconnected:", id)
