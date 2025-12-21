extends Node

func _ready():
	var args := OS.get_cmdline_args()

	if "--server" in args:
		print("[BOOT] Starting as SERVER")
		NetworkManager.start_server()
	else:
		print("[BOOT] Starting as CLIENT")
		NetworkManager.start_client("127.0.0.1")
