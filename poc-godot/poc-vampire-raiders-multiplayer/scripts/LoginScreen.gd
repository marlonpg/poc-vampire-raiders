extends Control

@onready var username_input = $VBoxContainer/UsernameInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var error_label = $VBoxContainer/ErrorLabel
@onready var login_button = $VBoxContainer/LoginButton
@onready var register_button = $VBoxContainer/RegisterButton

func _ready():
	# Set default values
	username_input.text = "admin"
	password_input.text = "pass"
	error_label.text = ""

func _on_login_button_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text
	
	if username.is_empty() or password.is_empty():
		show_error("Username and password are required")
		return
	
	error_label.text = "Logging in..."
	login_button.disabled = true
	register_button.disabled = true
	
	# For now, do direct database validation (later we'll add proper HTTP auth)
	await _validate_credentials(username, password)

func _on_register_button_pressed():
	get_tree().change_scene_to_file("res://scenes/RegisterScreen.tscn")

func _validate_credentials(username: String, password: String):
	# Simple validation - in a real game you'd call a backend API
	# For now, we'll just store the credentials and proceed
	# The backend will validate when the player joins
	
	# Store username for the game session
	GlobalAuth.logged_in_username = username
	GlobalAuth.logged_in_password = password
	
	print("[AUTH] Logged in as: ", username)
	
	# Proceed to main menu
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func show_error(message: String):
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color.RED)
	login_button.disabled = false
	register_button.disabled = false
