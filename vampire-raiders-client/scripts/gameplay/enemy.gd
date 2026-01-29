extends Node2D
class_name Enemy

var EnemySfx = preload("res://scripts/audio/EnemySfx.gd")

var template_id: int = 0
var template_name: String = "Unknown"
var health := 50
var max_health := 50
var level := 1

# Audio tracking
var is_walking: bool = false
var last_position: Vector2 = Vector2.ZERO
var walk_sound_cooldown: float = 0.0

# Telegraph attack visualization
var telegraph_circle: Node2D = null
var attack_state: String = "IDLE"  # IDLE, TELEGRAPHING, ATTACKING
var telegraph_target_x: float = 0
var telegraph_target_y: float = 0
var telegraph_start_time: int = 0
var telegraph_duration_ms: int = 1000  # Will be updated from server based on attack_rate
# Telegraph type and dimensions (loaded from mapping, not from server request)
var telegraph_type: String = "RECTANGLE"  # CIRCLE or RECTANGLE
var telegraph_width: float = 96.0
var telegraph_depth: float = 96.0
var show_telegraph: bool = false
var telegraph_progress: float = 0.0  # Animation progress 0.0 to 1.0
var client_telegraph_start: int = 0  # Client-side timestamp when telegraph started

# Telegraph type mapping by enemy name (matches backend TelegraphType enum)
const TELEGRAPH_TYPES = {
	"Spider": {"type": "CIRCLE", "width": 96.0, "depth": 0.0},
	"Worm": {"type": "RECTANGLE", "width": 36.0, "depth": 48.0},
	"Wild Dog": {"type": "RECTANGLE", "width": 48.0, "depth": 72.0},
	"Hound": {"type": "RECTANGLE", "width": 72.0, "depth": 72.0},
	"Elite Wild Dog": {"type": "RECTANGLE", "width": 48.0, "depth": 96.0},
	"Giant": {"type": "RECTANGLE", "width": 96.0, "depth": 96.0},
	"Skeleton": {"type": "RECTANGLE", "width": 20.0, "depth": 120.0},
}

# Enemy type colors
const ENEMY_COLORS = {
	"Spider": Color(0.8, 0.5, 0.5, 1.0),      # Light red
	"Worm": Color(1.0, 0.6, 0.2, 1.0),        # Orange
	"Wild Dog": Color(0.6, 0.4, 0.2, 1.0),    # Brown
	"Hound": Color(0.2, 0.5, 1.0, 1.0),       # Blue
}

func _ready():
	print("[ENEMY] Enemy spawned: ", name, " (", template_name, ")")
	_create_telegraph_visual()
	last_position = global_position

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
	
	# Handle walking sounds
	_update_walk_sounds(_delta)
	
	queue_redraw()

func _update_walk_sounds(delta: float) -> void:
	"""Update walking sounds based on enemy movement"""
	# Check if enemy is moving (position changed)
	var movement_distance = global_position.distance_to(last_position)
	is_walking = movement_distance > 0.5  # Small threshold to avoid noise
	last_position = global_position
	
	# Play walking sound while moving (with cooldown to avoid overlapping)
	if is_walking and attack_state == "IDLE":
		walk_sound_cooldown -= delta
		if walk_sound_cooldown <= 0.0:
			EnemySfx.play_walk_sound(template_name, self)
			walk_sound_cooldown = 0.5  # 500ms between walk sound loops
	else:
		walk_sound_cooldown = 0.0

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
			# Play attack sound when enemy starts telegraphing
			EnemySfx.play_attack_sound(template_name, self)
	attack_state = new_attack_state
	telegraph_target_x = enemy_data.get("telegraph_target_x", 0)
	telegraph_target_y = enemy_data.get("telegraph_target_y", 0)
	telegraph_start_time = enemy_data.get("telegraph_start_time", 0)
	telegraph_duration_ms = enemy_data.get("telegraph_duration_ms", 1000)  # Update from server
	
	# Load telegraph type from local mapping (no server request needed)
	if TELEGRAPH_TYPES.has(template_name):
		var telegraph_data = TELEGRAPH_TYPES[template_name]
		telegraph_type = telegraph_data["type"]
		telegraph_width = telegraph_data["width"]
		telegraph_depth = telegraph_data["depth"]

func take_damage(amount: int) -> void:
	"""Called when enemy takes damage"""
	health -= amount
	print("[ENEMY] %s took %d damage (health: %d)" % [name, amount, health])

func _draw():
	# Draw telegraph attack zone when active
	if show_telegraph:
		var telegraph_color = Color(1.0, 0.2, 0.2, 0.5)  # Red semi-transparent
		if telegraph_type == "CIRCLE":
			# Draw growing circle
			var radius = (telegraph_width / 2.0) * telegraph_progress
			draw_circle(Vector2.ZERO, radius, telegraph_color)
		else:
			# Draw growing rectangle (oriented box in attack direction)
			var target_pos = Vector2(telegraph_target_x, telegraph_target_y)
			var enemy_pos = global_position
			var direction = (target_pos - enemy_pos).normalized()
			# Perpendicular vector (90 degrees rotated)
			var perpendicular = Vector2(-direction.y, direction.x)
			# Calculate rectangle dimensions (growing with progress)
			var current_depth = telegraph_depth * telegraph_progress
			var half_width = telegraph_width / 2.0
			# Four corners of the rectangle
			var corner1 = direction * current_depth - perpendicular * half_width
			var corner2 = direction * current_depth + perpendicular * half_width
			var corner3 = -perpendicular * half_width
			var corner4 = perpendicular * half_width
			# Draw the telegraph rectangle
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
