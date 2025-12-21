extends Area2D

@export var item_name: String = "Blood Vial"
@export var item_value: int = 10
@export var slots_required: int = 1
@export var item_color: Color = Color.GOLD

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Visual.color = item_color

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Only allow pickup by local player
		if not body.is_local_player:
			print("[LootItem] Ignoring pickup by remote player")
			return
		
		var inventory = body.get_node_or_null("Inventory")
		if inventory:
			var item_data = {
				"name": item_name,
				"value": item_value,
				"slots": slots_required
			}
			print("[LootItem] Attempting to add %s to inventory" % item_name)
			if inventory.add_item(item_data):
				print("[LootItem] Item added successfully, removing loot")
				# Notify all clients to remove this loot
				rpc("_remove_loot")
			else:
				print("[LootItem] Failed to add item (inventory full?)")
		else:
			print("[LootItem] No inventory found on player")

@rpc("any_peer", "call_remote", "reliable")
func _remove_loot() -> void:
	queue_free()
