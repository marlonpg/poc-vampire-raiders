extends Control

var multiplayer_manager: Node
var current_mode: String = ""  # "host", "join", "lobby"
var host_button: Button
var join_button: Button
var start_button: Button
var ready_button: Button
var player_name_input: LineEdit
var ip_input: LineEdit
var join_player_name_input: LineEdit
var error_label: Label
var players_list: VBoxContainer
var mode_container: VBoxContainer
var host_panel: PanelContainer
var join_panel: PanelContainer
var lobby_panel: PanelContainer

func _ready() -> void:
	multiplayer_manager = get_tree().root.get_node_or_null("MultiplayerManager")
	if not multiplayer_manager:
		multiplayer_manager = MultiplayerManager  # Use autoload directly
	
	# Get references to UI elements - use safe access with null checks
	var vbox = $CenterContainer/VBoxContainer
	
	mode_container = vbox.get_node("ModeContainer")
	host_button = vbox.get_node("ModeContainer/HostButton")
	join_button = vbox.get_node("ModeContainer/JoinButton")
	host_panel = vbox.get_node("HostPanel")
	join_panel = vbox.get_node("JoinPanel")
	lobby_panel = vbox.get_node("LobbyPanel")
	players_list = vbox.get_node("LobbyPanel/MarginContainer/VBoxContainer/ScrollContainer/PlayersList")
	start_button = vbox.get_node("LobbyPanel/MarginContainer/VBoxContainer/StartButton")
	ready_button = vbox.get_node("LobbyPanel/MarginContainer/VBoxContainer/ReadyButton")
	player_name_input = vbox.get_node("HostPanel/MarginContainer/VBoxContainer/PlayerNameInput")
	ip_input = vbox.get_node("JoinPanel/MarginContainer/VBoxContainer/IPInput")
	join_player_name_input = vbox.get_node("JoinPanel/MarginContainer/VBoxContainer/PlayerNameInput")
	error_label = vbox.get_node("ErrorLabel")
	
	if not host_button or not join_button:
		print("[Lobby] Error: Could not find mode buttons")
		return
	
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	ready_button.pressed.connect(_on_ready_toggled)
	
	# Connect host panel button
	var host_panel_button = host_panel.get_node("MarginContainer/VBoxContainer/HostButton")
	host_panel_button.pressed.connect(_on_start_host)
	
	# Connect join panel button
	var join_panel_button = join_panel.get_node("MarginContainer/VBoxContainer/JoinButton")
	join_panel_button.pressed.connect(_on_join_game)
	
	multiplayer_manager.lobby_updated.connect(_on_lobby_updated)
	multiplayer_manager.game_started.connect(_on_game_started)
	
	print("[Lobby] UI initialized successfully")
	_show_mode_selection()

func _show_mode_selection() -> void:
	if mode_container:
		mode_container.show()
	if host_panel:
		host_panel.hide()
	if join_panel:
		join_panel.hide()
	if lobby_panel:
		lobby_panel.hide()
	if error_label:
		error_label.text = ""
	print("[Lobby] Mode selection shown")

func _show_host_panel() -> void:
	mode_container.hide()
	host_panel.show()
	join_panel.hide()
	lobby_panel.hide()
	player_name_input.grab_focus()

func _show_join_panel() -> void:
	mode_container.hide()
	host_panel.hide()
	join_panel.show()
	lobby_panel.hide()
	ip_input.grab_focus()

func _show_lobby() -> void:
	mode_container.hide()
	host_panel.hide()
	join_panel.hide()
	lobby_panel.show()
	_refresh_player_list()

func _on_host_pressed() -> void:
	_show_host_panel()

func _on_join_pressed() -> void:
	_show_join_panel()

func _on_start_host() -> void:
	var player_name = player_name_input.text.strip_edges()
	
	if player_name.is_empty():
		player_name = "Host"
	
	if multiplayer_manager.start_host(player_name):
		_show_lobby()
		error_label.text = ""
	else:
		error_label.text = "Failed to start server"

func _on_join_game() -> void:
	var ip = ip_input.text.strip_edges()
	var player_name = join_player_name_input.text.strip_edges()
	
	if ip.is_empty():
		error_label.text = "Please enter server IP"
		return
	
	if player_name.is_empty():
		player_name = "Player"
	
	if multiplayer_manager.join_game(ip, player_name):
		_show_lobby()
		error_label.text = ""
	else:
		error_label.text = "Failed to join server"

func _on_lobby_updated() -> void:
	_refresh_player_list()
	_update_start_button_visibility()

func _update_start_button_visibility() -> void:
	# Only show Start Game button if this player is the host and they're ready
	if multiplayer_manager.is_host:
		var players = multiplayer_manager.get_players_info()
		var local_id = multiplayer_manager.local_player_id
		
		if local_id in players:
			var host_ready = players[local_id].get("ready", false)
			start_button.visible = host_ready
		else:
			start_button.visible = false
	else:
		start_button.visible = false

func _refresh_player_list() -> void:
	# Clear old items
	for child in players_list.get_children():
		child.queue_free()
	
	var players = multiplayer_manager.get_players_info()
	
	for player_id in players.keys():
		var player_data = players[player_id]
		var item = Label.new()
		
		var status = "Ready" if player_data.get("ready", false) else "Not Ready"
		var host_label = " (HOST)" if player_data.get("is_host", false) else ""
		
		item.text = "%s - Lvl %d %s%s" % [
			player_data["name"],
			player_data["level"],
			status,
			host_label
		]
		
		players_list.add_child(item)

func _on_ready_toggled() -> void:
	var players = multiplayer_manager.get_players_info()
	var local_id = multiplayer_manager.local_player_id
	
	if local_id in players:
		var current_status = players[local_id].get("ready", false)
		multiplayer_manager.set_player_ready(not current_status)
		_update_start_button_visibility()

func _on_start_pressed() -> void:
	if multiplayer_manager.is_host:
		multiplayer_manager.start_game()

func _on_game_started() -> void:
	get_tree().change_scene_to_file("res://scenes/world/GameWorld.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if current_mode != "":
				_show_mode_selection()
				current_mode = ""
