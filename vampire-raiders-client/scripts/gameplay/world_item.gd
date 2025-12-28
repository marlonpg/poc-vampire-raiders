extends Area2D

@export var item_id: int
@export var item_name: String = "Item"

@onready var label: Label = $Label
@onready var color_rect: ColorRect = $ColorRect

func _ready():
	label.text = item_name
	color_rect.color = Color(0.8, 0.6, 0.2, 0.9)

func set_name_and_color(name: String):
	item_name = name
	label.text = name

func set_highlight(active: bool):
	color_rect.modulate = active if Color(1, 1, 1, 1) else Color(1, 1, 1, 0.8)
