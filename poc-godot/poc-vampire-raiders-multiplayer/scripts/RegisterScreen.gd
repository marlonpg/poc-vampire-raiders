extends Control

@onready var username_input = $VBoxContainer/UsernameInput
@onready var password_input = $VBoxContainer/PasswordInput
@onready var confirm_password_input = $VBoxContainer/ConfirmPasswordInput
@onready var error_label = $VBoxContainer/ErrorLabel
@onready var register_button = $VBoxContainer/RegisterButton
@onready var back_button = $VBoxContainer/BackButton

func _ready():
	error_label.text = ""

func _on_register_button_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text
	var confirm_password = confirm_password_input.text
	
	if username.is_empty() or password.is_empty():
		show_error("Username and password are required")
		return
	
	if username.length() < 3:
		show_error("Username must be at least 3 characters")
		return
	
	if password.length() < 4:
		show_error("Password must be at least 4 characters")
		return
	
	if password != confirm_password:
		show_error("Passwords do not match")
		return
	
	error_label.text = "Creating account..."
	register_button.disabled = true
	back_button.disabled = true
	
	# Store credentials for later use
	GlobalAuth.pending_registration_username = username
	GlobalAuth.pending_registration_password = password
	
	print("[AUTH] Account created: ", username)
	show_success("Account created! Redirecting to login...")
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")

func show_error(message: String):
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color.RED)
	register_button.disabled = false
	back_button.disabled = false

func show_success(message: String):
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color.GREEN)
