extends Node2D
class_name Player

const SPEED := 200
const ATTACK_RADIUS := 60
const ATTACK_DAMAGE := 25
const ATTACK_COOLDOWN := 1.0

var velocity := Vector2.ZERO
var health := 100
var xp := 0

var _attack_timer := 0.0

func _ready():
	print("[PLAYER]", _role(), "node:", name, "authority:", get_multiplayer_authority())

func _process(delta):
	if can_send_input():
		send_input()

func _physics_process(delta):
	if multiplayer.is_server():
		position += velocity * delta
		handle_auto_attack(delta)
		rpc("sync_state", position, health, xp)

# =========================
# INPUT (CLIENT → SERVER)
# =========================
func can_send_input() -> bool:
	if multiplayer.is_server():
		return false
	if multiplayer.multiplayer_peer == null:
		return false
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false
	if multiplayer.get_unique_id() != name.to_int():
		return false
	return true

func send_input():
	var input = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input.length() > 1:
		input = input.normalized()

	rpc_id(1, "receive_input", input)

@rpc("any_peer")
func receive_input(input: Vector2):
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != name.to_int():
		print("[SECURITY] Input rejected from peer", sender, "for player", name)
		return

	velocity = input * SPEED

# =========================
# COMBAT (SERVER ONLY)
# =========================
func handle_auto_attack(delta):
	_attack_timer -= delta
	if _attack_timer > 0:
		return

	_attack_timer = ATTACK_COOLDOWN

	for node in get_parent().get_children():
		if node is Enemy:
			if position.distance_to(node.position) <= ATTACK_RADIUS:
				node.take_damage(ATTACK_DAMAGE)

# =========================
# STATE SYNC (SERVER → CLIENT)
# =========================
@rpc("authority", "unreliable")
func sync_state(pos, h, x):
	position = pos
	health = h
	xp = x

# =========================
# DAMAGE
# =========================
func take_damage(amount):
	if not multiplayer.is_server():
		return

	health -= amount
	if health <= 0:
		queue_free()

# =========================
# DEBUG
# =========================
func _draw():
	draw_rect(Rect2(Vector2(-10, -10), Vector2(20, 20)), Color.BLUE)
	draw_circle(Vector2.ZERO, ATTACK_RADIUS, Color(0, 0, 1, 0.15))

func _role() -> String:
	return "SERVER" if multiplayer.is_server() else "CLIENT"
