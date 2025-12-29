extends Node2D
class_name Enemy

var health := 50
var max_health := 50

func _ready():
	print("[ENEMY] Enemy spawned: ", name)

func _process(_delta):
	queue_redraw()

func take_damage(amount: int) -> void:
	"""Called when enemy takes damage"""
	health -= amount
	print("[ENEMY] %s took %d damage (health: %d)" % [name, amount, health])

func _draw():
	# Draw a red circle for the enemy
	draw_circle(Vector2.ZERO, 15, Color.RED)
