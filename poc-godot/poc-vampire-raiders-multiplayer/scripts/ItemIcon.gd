extends ColorRect

@export var inventory_index: int = -1
@export var item_data: Dictionary = {}
var parent_inventory_ui: Node = null
var last_click_time: float = 0.0
var click_count: int = 0
var double_click_timeout: float = 0.3

func _ready():
	print("[ITEMICON] Ready called for index=%d, name=%s" % [inventory_index, item_data.get("name", "?")])
	print("[ITEMICON] Parent inventory UI: %s" % (parent_inventory_ui.name if parent_inventory_ui else "null"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tooltip = _build_tooltip()
	tooltip_text = tooltip
	# Ensure tooltip is visible
	focus_mode = Control.FOCUS_ALL
	print("[ITEMICON] Ready complete: index=%d, tooltip=%s" % [inventory_index, tooltip])

func _input(event: InputEvent) -> void:
	# Only process if event is a mouse button or touch event
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		# Check if this event is within this item's bounds
		var pos = event.position if "position" in event else Vector2.ZERO
		if get_global_rect().has_point(pos):
			gui_input(event)

func _build_tooltip() -> String:
	var parts: Array[String] = []
	parts.append("%s (%s)" % [item_data.get("name", "Item"), item_data.get("rarity", "common")])
	if item_data.has("type"):
		parts.append("Type: %s" % item_data.get("type"))
	if item_data.has("damage") and int(item_data.get("damage", 0)) > 0:
		parts.append("Damage: %d" % int(item_data.get("damage", 0)))
	if item_data.has("defense") and int(item_data.get("defense", 0)) > 0:
		parts.append("Defense: %d" % int(item_data.get("defense", 0)))
	return "\n".join(parts)

func gui_input(event: InputEvent) -> void:
	# Handle mouse button clicks
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		var mouse_in_rect = get_global_rect().has_point(mbe.position)
		
		print("[ITEMICON] Mouse event at index %d: button=%d, pressed=%s, double_click=%s, in_rect=%s" % [inventory_index, mbe.button_index, mbe.pressed, mbe.double_click, mouse_in_rect])
		
		# Only handle if click is actually on this item
		if not mouse_in_rect:
			return
		
		# Check double-click FIRST (before handling press/release for drag)
		if mbe.button_index == MOUSE_BUTTON_LEFT and mbe.double_click:
			print("[ITEMICON] Double-click detected, dropping item at index %d" % inventory_index)
			if parent_inventory_ui and parent_inventory_ui.has_method("_request_drop_from_inventory"):
				parent_inventory_ui._request_drop_from_inventory(inventory_index)
			get_tree().root.set_input_as_handled()
			if parent_inventory_ui and parent_inventory_ui.has_method("_set_dragging"):
				parent_inventory_ui._set_dragging(-1)
			return
		
		# Handle drag for single clicks
		if mbe.button_index == MOUSE_BUTTON_LEFT:
			if mbe.pressed:
				# Start drag
				print("[ITEMICON] Drag started from index %d" % inventory_index)
				if parent_inventory_ui and parent_inventory_ui.has_method("_set_dragging"):
					parent_inventory_ui._set_dragging(inventory_index)
			else:
				# Mouse released - check if we're over another slot
				print("[ITEMICON] Mouse released at index %d" % inventory_index)
				# Check if a drag was in progress
				if parent_inventory_ui and parent_inventory_ui.has_method("_get_dragging"):
					var drag_from = parent_inventory_ui._get_dragging()
					if drag_from >= 0 and drag_from != inventory_index:
						print("[ITEMICON] Drop detected: from index %d to index %d" % [drag_from, inventory_index])
						parent_inventory_ui._move_item(drag_from, inventory_index)
					parent_inventory_ui._set_dragging(-1)
			return
	
	# Handle touch taps for mobile (double-tap to drop)
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		
		if not get_global_rect().has_point(touch.position):
			return
		
		print("[ITEMICON] Touch: pressed=%s, in_rect=true at index %d" % [touch.pressed, inventory_index])
		if touch.pressed:
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_click_time < double_click_timeout:
				click_count += 1
			else:
				click_count = 1
			last_click_time = current_time
			
			print("[ITEMICON] Touch detected: count=%d, index=%d" % [click_count, inventory_index])
			
			# On second tap, trigger drop
			if click_count >= 2:
				print("[ITEMICON] Double-tap detected, dropping item at index %d" % inventory_index)
				if parent_inventory_ui and parent_inventory_ui.has_method("_request_drop_from_inventory"):
					parent_inventory_ui._request_drop_from_inventory(inventory_index)
				click_count = 0
				get_tree().root.set_input_as_handled()
				return
