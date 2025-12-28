extends Panel

@export var grid_index: int = -1
var parent_inventory_ui: Node = null

func _gui_input(event: InputEvent) -> void:
	# Handle mouse button releases on empty cells
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		
		# On mouse release, check if a drag is in progress
		if mbe.button_index == MOUSE_BUTTON_LEFT and not mbe.pressed:
			if parent_inventory_ui and parent_inventory_ui.has_method("_get_dragging"):
				var drag_from = parent_inventory_ui._get_dragging()
				if drag_from >= 0:
					parent_inventory_ui._move_item(drag_from, grid_index)
				parent_inventory_ui._set_dragging(-1)
