extends Node2D
class_name Enemy

var template_id: int = 0
var template_name: String = "Unknown"
var health := 50
var max_health := 50
var level := 1

# Telegraph attack visualization
var telegraph_rect: ColorRect = null
var attack_state: String = "IDLE"  # IDLE, TELEGRAPHING, ATTACKING
var telegraph_target_x: float = 0
var telegraph_target_y: float = 0
var telegraph_start_time: int = 0
var telegraph_duration_ms: int = 1000
var telegraph_size: int = 60  # Size of the warning square

# Enemy type colors
const ENEMY_COLORS = {
	"Spider": Color(0.8, 0.5, 0.5, 1.0),      # Light red
	"Worm": Color(1.0, 0.6, 0.2, 1.0),        # Orange
	"Wild Dog": Color(0.2, 0.6, 1.0, 1.0),    # Blue
	"Goblin": Color(0.4, 1.0, 0.4, 1.0),      # Green
}

const TELEGRAPH_COLOR = Color(1.0, 0.2, 0.2, 0.6)  # Red semi-transparent

func _ready():
	print("[ENEMY] Enemy spawned: ", name, " (", template_name, ")")
	_create_telegraph_visual()

func _create_telegraph_visual() -> void:
	if telegraph_rect == null:
		telegraph_rect = ColorRect.new()
		telegraph_rect.color = TELEGRAPH_COLOR
		telegraph_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		telegraph_rect.z_index = 10  # In front of enemy
		add_child(telegraph_rect)
		telegraph_rect.hide()

func _process(_delta):
	# Update telegraph position and visibility
	if telegraph_rect != null:
		if health > 0 and attack_state == "TELEGRAPHING":
			# Convert world coordinates to local coordinates (relative to enemy position)
			var local_x = telegraph_target_x - position.x
			var local_y = telegraph_target_y - position.y
			telegraph_rect.position = Vector2(local_x - telegraph_size / 2, local_y - telegraph_size / 2)
			telegraph_rect.size = Vector2(telegraph_size, telegraph_size)
			telegraph_rect.show()
		else:
			telegraph_rect.hide()
	
	queue_redraw()

func update_from_server(enemy_data: Dictionary) -> void:
	"""Update enemy state from server"""
	health = enemy_data.get("health", health)
	attack_state = enemy_data.get("attack_state", "IDLE")
	telegraph_target_x = enemy_data.get("telegraph_target_x", 0)
	telegraph_target_y = enemy_data.get("telegraph_target_y", 0)
	telegraph_start_time = enemy_data.get("telegraph_start_time", 0)

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
