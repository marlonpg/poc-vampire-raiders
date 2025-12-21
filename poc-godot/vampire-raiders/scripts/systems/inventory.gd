extends Node

@export var max_slots: int = 6
@export var loot_item_scene: PackedScene

var items: Array = []
var player_id: int = -1
var is_local_player: bool = false

signal inventory_changed
signal inventory_full
signal item_dropped(index: int)

func _ready() -> void:
	# Get reference to player for multiplayer context
	var player = get_parent()
	if player:
		player_id = player.player_id
		is_local_player = player.is_local_player
		print("[Inventory] Initialized for player %d (local: %s)" % [player_id, is_local_player])

func add_item(item_data: Dictionary) -> bool:
	# Only local player can add items
	if not is_local_player:
		print("[Inventory] Ignoring add_item from non-local player")
		return false
	
	var slots_needed = item_data.get("slots", 1)
	
	if get_used_slots() + slots_needed > max_slots:
		inventory_full.emit()
		return false
	
	items.append(item_data)
	inventory_changed.emit()
	
	# Sync to network
	_sync_inventory_to_network()
	return true

func remove_item(index: int) -> void:
	if index >= 0 and index < items.size():
		items.remove_at(index)
		inventory_changed.emit()

func drop_item(index: int) -> void:
	if index >= 0 and index < items.size():
		var item_data = items[index]
		items.remove_at(index)
		item_dropped.emit(index)
		inventory_changed.emit()
		
		if loot_item_scene:
			var loot = loot_item_scene.instantiate()
			loot.item_name = item_data.name
			loot.item_value = item_data.value
			loot.slots_required = item_data.slots
			
			var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			loot.global_position = get_parent().global_position + offset
			
			get_tree().root.add_child(loot)

func get_used_slots() -> int:
	var used = 0
	for item in items:
		used += item.get("slots", 1)
	return used

func get_available_slots() -> int:
	return max_slots - get_used_slots()

func clear() -> void:
	items.clear()
	inventory_changed.emit()

func get_total_value() -> int:
	var total = 0
	for item in items:
		total += item.get("value", 0)
	return total

# ============================================================================
# NETWORK SYNCHRONIZATION (Anti-Duplication)
# ============================================================================

func _sync_inventory_to_network() -> void:
	# Convert items array to a serializable format for RPC
	var items_data = []
	for item in items:
		items_data.append(item)
	
	var multiplayer_manager = get_tree().root.get_node_or_null("MultiplayerManager")
	if multiplayer_manager:
		multiplayer_manager.update_inventory(player_id, items_data)
