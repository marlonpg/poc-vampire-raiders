extends Node

# Centralized enemy SFX helper so all enemy audio is managed in one place.
# Each sound creates its own AudioStreamPlayer to allow concurrent sounds.

static var _scene_root: Node = null
static var _current_walk_player: AudioStreamPlayer = null

# Enemy audio mappings by enemy name
static var _enemy_walk_sfx := {
	"Spider": preload("res://sounds/enemy/spider-walk.mp3")
	#"Worm": preload("res://sounds/enemy/worm-walk.mp3"),
	#"Wild Dog": preload("res://sounds/enemy/wild-dog-walk.mp3"),
	#"Hound": preload("res://sounds/enemy/hound-walk.mp3"),
	#"Elite Wild Dog": preload("res://sounds/enemy/elite-wild-dog-walk.mp3"),
	#"Lich": preload("res://sounds/enemy/lich-walk.mp3"),
	#"Giant": preload("res://sounds/enemy/giant-walk.mp3"),
	#"Skeleton": preload("res://sounds/enemy/skeleton-walk.mp3"),
}

static var _enemy_attack_sfx := {
	"Spider": preload("res://sounds/enemy/spider-attacking.mp3")
	#"Worm": preload("res://sounds/enemy/worm-attacking.mp3"),
	#"Wild Dog": preload("res://sounds/enemy/wild-dog-attacking.mp3"),
	#"Hound": preload("res://sounds/enemy/hound-attacking.mp3"),
	#"Elite Wild Dog": preload("res://sounds/enemy/elite-wild-dog-attacking.mp3"),
	#"Lich": preload("res://sounds/enemy/lich-attacking.mp3"),
	#"Giant": preload("res://sounds/enemy/giant-attacking.mp3"),
	#"Skeleton": preload("res://sounds/enemy/skeleton-attacking.mp3"),
}

static func _get_scene_root(context: Node) -> Node:
	if _scene_root != null:
		return _scene_root
	if context == null:
		return null
	var tree := context.get_tree()
	if tree == null:
		return null
	_scene_root = tree.root
	return _scene_root

static func play_walk_sound(enemy_name: String, context: Node) -> void:
	"""Play walking sound for the given enemy type - waits for previous sound to finish before playing again"""
	if enemy_name == null or enemy_name == "":
		return
	# If a walk sound is already playing, don't spawn a new one
	if _current_walk_player != null and is_instance_valid(_current_walk_player) and _current_walk_player.playing:
		return
	var root := _get_scene_root(context)
	if root == null:
		return
	var stream: AudioStream = _enemy_walk_sfx.get(enemy_name, null)
	if stream == null:
		return
	# Create a new player for this sound
	var player := AudioStreamPlayer.new()
	player.stream = stream
	root.add_child(player)
	player.play()
	_current_walk_player = player
	# Auto-cleanup after sound finishes
	player.finished.connect(func(): player.queue_free())

static func play_attack_sound(enemy_name: String, context: Node) -> void:
	"""Play attack sound for the given enemy type"""
	if enemy_name == null or enemy_name == "":
		return
	var root := _get_scene_root(context)
	if root == null:
		return
	var stream: AudioStream = _enemy_attack_sfx.get(enemy_name, null)
	if stream == null:
		return
	# Create a new player for this sound so multiple sounds can play concurrently
	var player := AudioStreamPlayer.new()
	player.stream = stream
	root.add_child(player)
	player.play()
	# Auto-cleanup after sound finishes (connect signal instead of await to avoid blocking)
	player.finished.connect(func(): player.queue_free())
