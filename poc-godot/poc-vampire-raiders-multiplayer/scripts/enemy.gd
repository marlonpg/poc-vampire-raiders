extends Node2D
class_name Enemy

const SPEED := 100
const DAMAGE := 10

var health := 50

func _ready():
	print("[ENEMY]", _role(),
		"node:", name,
		"authority:", get_multiplayer_authority())

func _physics_process(delta):
	if not multiplayer.is_server():
		return

	var player := find_nearest_player()
	if player == null:
		return

	var dir := (player.position - position).normalized()
	position += dir * SPEED * delta

	if position.distance_to(player.position) < 20:
		player.take_damage(DAMAGE)
		queue_free()
		return

	rpc("sync_position", position)

func find_nearest_player() -> Player:
	var closest: Player = null
	var min_dist := INF

	for node in get_parent().get_children():
		if node is Player:
			var d := position.distance_to(node.position)
			if d < min_dist:
				min_dist = d
				closest = node

	return closest

func take_damage(amount):
	if not multiplayer.is_server():
		return

	health -= amount
	if health <= 0:
		queue_free()

@rpc("authority")
func sync_position(pos):
	position = pos

func _draw():
	draw_circle(Vector2.ZERO, 10, Color.RED)

func _role() -> String:
	return "SERVER" if multiplayer.is_server() else "CLIENT"
