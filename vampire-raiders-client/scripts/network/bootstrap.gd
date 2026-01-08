extends Node

func _ready():
	var args := OS.get_cmdline_args()
	var tcp_only := "--tcp-only" in args or "--net=tcp" in args

	if "--server" in args:
		print("[BOOT] Starting as SERVER")
		NetworkManager.start_server()
		return

	# Default: start TCP client and attach UDP input client unless disabled
	print("[BOOT] Starting client; UDP input is default (use --tcp-only to disable)")
	NetworkManager.start_client("127.0.0.1")

	if not tcp_only:
		var existing := get_node_or_null("UDPNetworkClient")
		if existing == null:
			var udp_client := preload("res://scripts/network/udp_network_client.gd").new()
			udp_client.name = "UDPNetworkClient"
			add_child(udp_client)
			udp_client.connect_to_server("127.0.0.1")
