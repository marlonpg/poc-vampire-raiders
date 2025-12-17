extends Node

@export var extraction_unlock_time: float = 60.0

var game_time: float = 0.0
var extractions_unlocked: bool = false

signal extractions_available

func _process(delta: float) -> void:
	game_time += delta
	
	if not extractions_unlocked and game_time >= extraction_unlock_time:
		_unlock_extractions()

func _unlock_extractions() -> void:
	extractions_unlocked = true
	extractions_available.emit()
	print("Extraction points now available!")
	
	var extraction_points = get_tree().get_nodes_in_group("extraction_points")
	for point in extraction_points:
		if point.has_method("activate"):
			point.activate()

func get_time_until_extraction() -> float:
	return max(0, extraction_unlock_time - game_time)
