extends Area2D

var id: int
var shooter_id: int
var vx: float = 0.0
var vy: float = 0.0
var speed: float = 400.0

func _ready():
	pass

func _process(delta):
	# Velocity from server already includes speed, just apply directly
	position.x += vx * delta
	position.y += vy * delta

func setup(bullet_id: int, shooter_id_param: int, start_pos: Vector2, vel_x: float, vel_y: float):
	id = bullet_id
	shooter_id = shooter_id_param
	position = start_pos
	vx = vel_x
	vy = vel_y
