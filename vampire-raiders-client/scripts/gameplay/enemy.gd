extends Node2D
class_name Enemy

var template_id: int = 0
var template_name: String = "Unknown"
var health := 50
var max_health := 50
var level := 1

# Enemy type colors
const ENEMY_COLORS = {
	"Spider": Color(0.8, 0.5, 0.5, 1.0),      # Light red
	"Worm": Color(1.0, 0.6, 0.2, 1.0),        # Orange
	"Wild Dog": Color(0.2, 0.6, 1.0, 1.0),    # Blue
	"Goblin": Color(0.4, 1.0, 0.4, 1.0),      # Green
}

func _ready():
	print("[ENEMY] Enemy spawned: ", name, " (", template_name, ")")

func _process(_delta):
	queue_redraw()

func take_damage(amount: int) -> void:
	"""Called when enemy takes damage"""
	health -= amount
	print("[ENEMY] %s took %d damage (health: %d)" % [name, amount, health])

func _draw():
	# Get color based on template name
	var color = ENEMY_COLORS.get(template_name, Color.RED)
	
	# Draw colored circle for the enemy
	draw_circle(Vector2.ZERO, 20, color)
	
	# Draw health bar above enemy
	var health_ratio = float(health) / float(max_health)
	var bar_width = 30
	var bar_height = 4
	var bar_color = Color.RED.lerp(Color.GREEN, health_ratio)
	
	# Background bar (dark)
	draw_rect(Rect2(-bar_width / 2, -35, bar_width, bar_height), Color.BLACK)
	# Health bar
	draw_rect(Rect2(-bar_width / 2, -35, bar_width * health_ratio, bar_height), bar_color)
