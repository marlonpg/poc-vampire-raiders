extends Node

# Centralized drop SFX helper so UI + world code share the same mapping.
# Each drop creates its own AudioStreamPlayer to allow concurrent sounds.

static var _scene_root: Node = null

static var _drop_sfx_by_type := {
	"weapon": preload("res://sounds/weapon.mp3"),
	"loot": preload("res://sounds/gold.mp3"),
	"jewel": preload("res://sounds/jewel.mp3"),
	"armor": preload("res://sounds/armor.mp3"),
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

static func play_drop_for_item(item: Dictionary, context: Node, listener_pos: Vector2 = Vector2.INF, max_distance: float = INF) -> void:
	if item == null:
		return
	var item_type := str(item.get("type", ""))
	var pos := Vector2.INF
	if item.has("x") and item.has("y"):
		pos = Vector2(float(item.get("x", 0)), float(item.get("y", 0)))
	play_drop_for_type(item_type, context, pos, listener_pos, max_distance)

static func play_drop_for_type(item_type: String, context: Node, pos: Vector2 = Vector2.INF, listener_pos: Vector2 = Vector2.INF, max_distance: float = INF) -> void:
	if item_type == null or item_type == "":
		return
	var root := _get_scene_root(context)
	if root == null:
		return
	var stream: AudioStream = _drop_sfx_by_type.get(item_type, null)
	if stream == null:
		return
	if max_distance != INF and listener_pos != Vector2.INF and pos != Vector2.INF:
		if listener_pos.distance_to(pos) > max_distance:
			return
	# Create a new player for this drop so multiple sounds can play concurrently
	var player := AudioStreamPlayer.new()
	player.stream = stream
	root.add_child(player)
	player.play()
	# Auto-cleanup after sound finishes (connect signal instead of await to avoid blocking)
	player.finished.connect(func(): player.queue_free())
