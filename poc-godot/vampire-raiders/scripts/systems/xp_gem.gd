extends Area2D

@export var xp_value: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Only local player can pick up
		if not body.is_local_player:
			return
		
		if body.has_method("add_xp"):
			body.add_xp(xp_value)
		
		# Notify all clients to remove this gem
		rpc("_remove_gem")

@rpc("any_peer", "call_remote", "reliable")
func _remove_gem() -> void:
	queue_free()
