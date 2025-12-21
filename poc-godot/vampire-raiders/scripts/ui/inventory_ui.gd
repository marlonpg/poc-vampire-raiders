extends Control

@onready var grid = $Panel/GridContainer
@onready var value_label = $Panel/ValueLabel

var inventory: Node
var slot_buttons: Array = []

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		inventory = player.get_node_or_null("Inventory")
		if inventory:
			inventory.inventory_changed.connect(_update_display)
			inventory.inventory_full.connect(_on_inventory_full)
			_create_slots()
	_update_display()

func _create_slots() -> void:
	if not inventory:
		return
	
	for i in range(inventory.max_slots):
		var button = Button.new()
		button.custom_minimum_size = Vector2(60, 60)
		button.text = ""
		var slot_index = i
		button.pressed.connect(func(): _on_slot_clicked(slot_index))
		grid.add_child(button)
		slot_buttons.append(button)

func _update_display() -> void:
	if not inventory:
		return
	
	value_label.text = "Value: %d" % inventory.get_total_value()
	
	for i in slot_buttons.size():
		if i < inventory.items.size():
			var item = inventory.items[i]
			slot_buttons[i].text = "%s\n$%d" % [item.name, item.value]
		else:
			slot_buttons[i].text = ""

func _on_slot_clicked(index: int) -> void:
	if inventory and index < inventory.items.size():
		inventory.drop_item(index)

func _on_inventory_full() -> void:
	print("Inventory full!")
