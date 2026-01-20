extends Node2D
class_name Enemy

var template_id: int = 0
var template_name: String = "Unknown"
var health := 50
var max_health := 50
var level := 1

# Telegraph attack visualization
var telegraph_circle: Node2D = null
var attack_state: String = "IDLE"  # IDLE, TELEGRAPHING, ATTACKING
var telegraph_target_x: float = 0
var telegraph_target_y: float = 0
var telegraph_start_time: int = 0
var telegraph_duration_ms: int = 1000  # Will be updated from server based on attack_rate
# Telegraph rectangle dimensions (must match backend CombatSystem.java)
var telegraph_width: float = 48.0  # Width side-to-side (48 pixels on each side)
var telegraph_depth: float = 96.0  # Depth forward from enemy
var show_telegraph: bool = false
var telegraph_progress: float = 0.0  # Animation progress 0.0 to 1.0
var client_telegraph_start: int = 0  # Client-side timestamp when telegraph started

# Enemy type colors
const ENEMY_COLORS = {
	"Spider": Color(0.8, 0.5, 0.5, 1.0),      # Light red
	"Worm": Color(1.0, 0.6, 0.2, 1.0),        # Orange
	"Wild Dog": Color(0.2, 0.6, 1.0, 1.0),    # Blue
	"Goblin": Color(0.4, 1.0, 0.4, 1.0),      # Green
}

func _ready():
	print("[ENEMY] Enemy spawned: ", name, " (", template_name, ")")
	_create_telegraph_visual()

func _create_telegraph_visual() -> void:
	if telegraph_circle == null:
		telegraph_circle = Node2D.new()
		telegraph_circle.z_index = 10  # In front of enemy
		add_child(telegraph_circle)

func _process(_delta):
	# Update telegraph visibility flag and animate growth
	if health > 0 and attack_state == "TELEGRAPHING":
		show_telegraph = true
		
		# Calculate progress (0.0 to 1.0) based on time elapsed since client saw telegraph start
		var current_time = Time.get_ticks_msec()
		var elapsed = current_time - client_telegraph_start
		telegraph_progress = clamp(float(elapsed) / float(telegraph_duration_ms), 0.0, 1.0)
	else:
		show_telegraph = false
		telegraph_progress = 0.0
	
	queue_redraw()

func update_from_server(enemy_data: Dictionary) -> void:
	"""Update enemy state from server"""
	health = enemy_data.get("health", health)
	var new_attack_state = enemy_data.get("attack_state", "IDLE")
	if new_attack_state != attack_state:
		print("[ENEMY] %s attack state changed: %s -> %s" % [name, attack_state, new_attack_state])
		# Track when we first see TELEGRAPHING state on client
		if new_attack_state == "TELEGRAPHING":
			client_telegraph_start = Time.get_ticks_msec()
			print("[ENEMY] %s telegraph started at client time: %d" % [name, client_telegraph_start])
	attack_state = new_attack_state
	telegraph_target_x = enemy_data.get("telegraph_target_x", 0)
	telegraph_target_y = enemy_data.get("telegraph_target_y", 0)
	telegraph_start_time = enemy_data.get("telegraph_start_time", 0)
	telegraph_duration_ms = enemy_data.get("telegraph_duration_ms", 1000)  # Update from server

func take_damage(amount: int) -> void:
	"""Called when enemy takes damage"""
	health -= amount
	print("[ENEMY] %s took %d damage (health: %d)" % [name, amount, health])

func _draw():
	# Draw telegraph rectangle when active (oriented box in attack direction)
	if show_telegraph:
		# Get direction from enemy to telegraph target
		var target_pos = Vector2(telegraph_target_x, telegraph_target_y)
		var enemy_pos = global_position
		var direction = (target_pos - enemy_pos).normalized()
		
		# Perpendicular vector (90 degrees rotated)
		var perpendicular = Vector2(-direction.y, direction.x)
		
		# Calculate rectangle corners (growing with progress)
		var current_depth = telegraph_depth * telegraph_progress
		var half_width = telegraph_width / 2.0
		
		# Four corners of the rectangle
		var corner1 = direction * current_depth - perpendicular * half_width
		var corner2 = direction * current_depth + perpendicular * half_width
		var corner3 = -perpendicular * half_width
		var corner4 = perpendicular * half_width
		
		# Draw the telegraph rectangle
		var telegraph_color = Color(1.0, 0.2, 0.2, 0.5)  # Red semi-transparent
		draw_colored_polygon([corner3, corner1, corner2, corner4], telegraph_color)
	
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
