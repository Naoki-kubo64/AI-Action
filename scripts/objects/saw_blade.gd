extends Area2D

@export var rotation_speed: float = 360.0 # Degrees per second

func _ready():
	add_to_group("hazard")

func _process(delta):
	rotation_degrees += rotation_speed * delta
