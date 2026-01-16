extends CharacterBody2D
class_name PlayerController

@export var move_speed: float = 200.0
var target_position: Vector2

func _ready():
	target_position = position

func _physics_process(delta):
	if position.distance_to(target_position) > 5.0:
		velocity = position.direction_to(target_position) * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func move_relative(direction: Vector2):
	# 格子状移動を想定 (例: 1マス=64px)
	target_position += direction * 64.0
