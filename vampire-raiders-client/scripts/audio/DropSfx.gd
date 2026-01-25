extends Node

# Centralized drop SFX helper so UI + world code share the same mapping + player.

static var _player: AudioStreamPlayer = null

static var _drop_sfx_by_type := {
	"weapon": preload("res://sounds/weapon.mp3"),
	"loot": preload("res://sounds/gold.mp3"),
	"jewel": preload("res://sounds/jewel.mp3"),
	"armor": preload("res://sounds/armor.mp3"),
}

static func _ensure_player(context: Node) -> void:
	if _player != null:
		return
	if context == null:
		return
	var tree := context.get_tree()
	if tree == null:
		return
	_player = AudioStreamPlayer.new()
	# Put it under the scene tree root so it survives scene changes.
	tree.root.add_child(_player)

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
	_ensure_player(context)
	if _player == null:
		return
	var stream: AudioStream = _drop_sfx_by_type.get(item_type, null)
	if stream == null:
		return
	if max_distance != INF and listener_pos != Vector2.INF and pos != Vector2.INF:
		if listener_pos.distance_to(pos) > max_distance:
			return
	_player.stream = stream
	_player.stop()
	_player.play()
