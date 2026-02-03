extends Node2D
class_name Player

const SPEED := 200
const ATTACK_RADIUS := 60
const ATTACK_DAMAGE := 25
const ATTACK_COOLDOWN := 1.0

const _DIRECTION_TEXTURES := {
	"up": preload("res://assets/player/default/up.png"),
	"down": preload("res://assets/player/default/down.png"),
	"left": preload("res://assets/player/default/left.png"),
	"right": preload("res://assets/player/default/right.png"),
	"right-up": preload("res://assets/player/default/right-up.png"),
	"right-down": preload("res://assets/player/default/right-down.png"),
	"idle": preload("res://assets/player/default/idle.png"),
	"left-up": preload("res://assets/player/default/left-up.png"),
	"left-down": preload("res://assets/player/default/left-down.png"),
}
var _idle_texture: Texture2D = null

const _IDLE_TEXTURE := preload("res://assets/player/default/idle.png")

var velocity := Vector2.ZERO
var health := 100
var xp := 0
var attack_range := 200.0  # Received from server, default 200
var is_local_player := false  # Set by world script to identify local player
var _last_position := Vector2.ZERO
var _current_direction := "down"

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")

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
	var sprite_nodes: Array = []
	for child in get_children():
		if child is Sprite2D:
			sprite_nodes.append(child)
	if _sprite == null and sprite_nodes.size() == 0:
		if is_local_player:
			push_warning("[PLAYER] Sprite2D node not found on Player scene. Creating one.")
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		_sprite.centered = true
		add_child(_sprite)
		sprite_nodes.append(_sprite)
	elif _sprite == null and sprite_nodes.size() > 0:
		_sprite = sprite_nodes[0]
	# If multiple Sprite2D nodes exist, keep the selected one and remove the rest
	for node in sprite_nodes:
		if node != _sprite:
			node.queue_free()
	if _sprite != null:
		_sprite.visible = true
		_sprite.z_index = 1
		_sprite.z_as_relative = true
	_last_position = position
	_update_sprite_direction(_current_direction)

	# Equip default weapon locally and on server
	equip_weapon(DEFAULT_WEAPON)

func _process(delta):
	if health <= 0:
		return
	if can_send_input():
		send_input()
	_update_sprite_from_motion()

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
	_update_sprite_from_motion()

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
	_update_sprite_from_vector(input)

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
	_update_sprite_from_vector(input)

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
	_update_sprite_from_motion()

# Update attack range from server state
func update_attack_range(range: float):
	attack_range = range
	queue_redraw()  # Trigger redraw when range changes

func set_position_from_server(new_pos: Vector2) -> void:
	var motion := new_pos - position
	position = new_pos
	_update_sprite_from_vector(motion)
	_last_position = new_pos

func set_direction_from_server(dir_x: float, dir_y: float) -> void:
	_update_sprite_from_vector(Vector2(dir_x, dir_y))

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
	if _sprite == null or _sprite.texture == null:
		draw_rect(Rect2(Vector2(-10, -10), Vector2(20, 20)), Color.BLUE)
	# Only draw attack range circle for local player
	if is_local_player:
		draw_circle(Vector2.ZERO, attack_range, Color(0.5, 0.5, 0.5, 0.15))

func _update_sprite_from_motion() -> void:
	if _sprite == null:
		return
	var motion := position - _last_position
	if motion.length() > 0.001:
		_update_sprite_from_vector(motion)
	elif velocity.length() > 0.001:
		_update_sprite_from_vector(velocity)
	_last_position = position

func _update_sprite_from_vector(v: Vector2) -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D")
		if _sprite == null:
			return
	if v.length() <= 0.001:
		if _current_direction != "idle":
			_current_direction = "idle"
			_update_sprite_direction(_current_direction)
			print("[PLAYER] setting to idle")
		return
	var direction := _direction_from_vector(v)
	print("[PLAYER] computed direction:", direction, " from", v)
	if direction != "" and direction != _current_direction:
		_current_direction = direction
		_update_sprite_direction(_current_direction)

func _direction_from_vector(v: Vector2) -> String:
	if v.length() <= 0.1:
		return "idle"
	var angle := rad_to_deg(atan2(v.y, v.x))
	print("[PLAYER] angle from vector:", angle)
	if angle >= -22.5 and angle < 22.5:
		return "right"
	if angle >= 22.5 and angle < 67.5:
		return "right-down"
	if angle >= 67.5 and angle < 112.5:
		return "down"
	if angle >= 112.5 and angle < 157.5:
		return "left-down"
	if angle >= 157.5 or angle < -157.5:
		return "left"
	if angle >= -157.5 and angle < -112.5:
		return "left-up"
	if angle >= -112.5 and angle < -67.5:
		return "up"
	if angle >= -67.5 and angle < -22.5:
		return "right-up"
	return ""

func _update_sprite_direction(direction: String) -> void:
	print("[PLAYER] updating sprite direction to:", direction)
	if _sprite == null:
		return
	var texture: Texture2D = _DIRECTION_TEXTURES.get(direction, null)
	if texture != null:
		_sprite.texture = texture

func _role() -> String:
	return "SERVER" if multiplayer.is_server() else "CLIENT"
