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
		var inventory = body.get_node_or_null("Inventory")
		if inventory:
			var item_data = {
				"name": item_name,
				"value": item_value,
				"slots": slots_required
			}
			if inventory.add_item(item_data):
				queue_free()
