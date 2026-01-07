extends Node2D
class_name Player

const SPEED := 200
const ATTACK_RADIUS := 60
const ATTACK_DAMAGE := 25
const ATTACK_COOLDOWN := 1.0

var velocity := Vector2.ZERO
var health := 100
var xp := 0
var attack_range := 200.0  # Received from server, default 200
var is_local_player := false  # Set by world script to identify local player

# Weapon handling
const DEFAULT_WEAPON := "Steel Sword"
var _weapon_instance: Node2D = null
var _weapon_scenes := {
	"Iron Dagger": preload("res://scenes/weapons/IronDagger.tscn"),
	"Steel Sword": preload("res://scenes/weapons/SteelSword.tscn"),
}

var _attack_timer := 0.0

func _ready():
	print("[PLAYER]", _role(), "node:", name, "authority:", get_multiplayer_authority())
	# Camera activation is handled centrally in World._on_spawner_spawned to ensure correct timing on clients

	# Equip default weapon locally and on server
	equip_weapon(DEFAULT_WEAPON)

func _process(delta):
	if health <= 0:
		return
	if can_send_input():
		send_input()

func _physics_process(delta):
	if health <= 0:
		return
	if multiplayer.is_server():
		position += velocity * delta
		handle_auto_attack(delta)
		# Broadcast authoritative state to connected peers (avoids analyzer rpc_unreliable issue)
		var peers := get_tree().get_multiplayer().get_peers()
		for pid in peers:
			get_tree().get_multiplayer().rpc(pid, self, "sync_state", [position, health, xp])

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
@rpc("authority")
func sync_state(pos, h, x):
	position = pos
	health = h
	xp = x

# Update attack range from server state
func update_attack_range(range: float):
	attack_range = range
	queue_redraw()  # Trigger redraw when range changes

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
# WEAPON EQUIP
# =========================
func equip_weapon(name: String):
	var socket := $WeaponSocket if has_node("WeaponSocket") else null
	if socket == null:
		return

	# Remove previous weapon
	if _weapon_instance and is_instance_valid(_weapon_instance):
		_weapon_instance.queue_free()
		_weapon_instance = null

	# Instance new weapon
	if _weapon_scenes.has(name):
		var scene: PackedScene = _weapon_scenes[name]
		_weapon_instance = scene.instantiate()
		socket.add_child(_weapon_instance)
		_weapon_instance.position = Vector2.ZERO
	else:
		print("[WEAPON] Unknown weapon", name)

# =========================
# DEBUG
# =========================
func _draw():
	draw_rect(Rect2(Vector2(-10, -10), Vector2(20, 20)), Color.BLUE)
	# Only draw attack range circle for local player
	if is_local_player:
		draw_circle(Vector2.ZERO, attack_range, Color(0.5, 0.5, 0.5, 0.15))

func _role() -> String:
	return "SERVER" if multiplayer.is_server() else "CLIENT"
