extends Node

# Global authentication state
var logged_in_username: String = ""
var logged_in_password: String = ""

# For registration flow
var pending_registration_username: String = ""
var pending_registration_password: String = ""

func is_logged_in() -> bool:
	return not logged_in_username.is_empty()

func clear_auth():
	logged_in_username = ""
	logged_in_password = ""
	pending_registration_username = ""
	pending_registration_password = ""
