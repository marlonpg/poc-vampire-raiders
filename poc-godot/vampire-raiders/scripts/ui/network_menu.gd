extends Control

@onready var host_button = $Panel/VBoxContainer/HostButton
@onready var join_button = $Panel/VBoxContainer/JoinButton
@onready var ip_input = $Panel/VBoxContainer/IPInput
@onready var status_label = $Panel/VBoxContainer/StatusLabel

var network_manager: Node

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

func _on_host_pressed() -> void:
	if not network_manager:
		network_manager = preload("res://scripts/managers/network_manager.gd").new()
		add_child(network_manager)
		network_manager.player_connected.connect(_on_player_connected)
	network_manager.create_server()
	status_label.text = "Status: Hosting..."
	_start_game()

func _on_join_pressed() -> void:
	if not network_manager:
		network_manager = preload("res://scripts/managers/network_manager.gd").new()
		add_child(network_manager)
		network_manager.player_connected.connect(_on_player_connected)
	var address = ip_input.text if ip_input.text != "" else "localhost"
	network_manager.create_client(address)
	status_label.text = "Status: Connecting..."

func _on_player_connected(_id: int) -> void:
	_start_game()

func _start_game() -> void:
	var tree = get_tree()
	tree.change_scene_to_file("res://scenes/world/GameWorld.tscn")
	tree.node_added.connect(_on_scene_loaded, CONNECT_ONE_SHOT)

func _on_scene_loaded(node: Node) -> void:
	if node.name == "GameWorld":
		await get_tree().process_frame
		if network_manager and network_manager.is_server():
			network_manager.spawn_all_players()
