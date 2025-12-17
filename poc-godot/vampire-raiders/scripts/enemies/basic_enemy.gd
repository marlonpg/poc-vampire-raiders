extends CharacterBody2D

@export var speed: float = 150.0
@export var health: int = 10
@export var aggro_range: float = 512.0

var player: CharacterBody2D

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= aggro_range:
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()
