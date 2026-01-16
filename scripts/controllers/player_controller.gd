extends CharacterBody2D
class_name PlayerController

@export var move_speed: float = 300.0
var target_position: Vector2

func _ready():
	_setup_visuals()
	target_position = position

func _physics_process(delta):
	if position.distance_to(target_position) > 2.0:
		velocity = position.direction_to(target_position) * move_speed
		move_and_slide()
		# Simple bobbing animation
		$Visuals.position.y = sin(Time.get_ticks_msec() * 0.01) * 5.0
	else:
		velocity = Vector2.ZERO
		position = target_position # Snap to grid
		$Visuals.position.y = lerp($Visuals.position.y, 0.0, delta * 5.0)

func move_relative(direction: Vector2):
	# 格子状移動 64px
	target_position += direction * 64.0
	# Rotate visuals to face direction
	if direction.x != 0:
		$Visuals.scale.x = sign(direction.x)

func _setup_visuals():
	# Create a simple robot character using Polygon2D if not already existing
	if has_node("Visuals"): return
	
	var visuals = Node2D.new()
	visuals.name = "Visuals"
	add_child(visuals)
	
	# Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-16, -24), Vector2(16, -24),
		Vector2(20, 16), Vector2(-20, 16)
	])
	body.color = Color.WHITE # Will be tinted by modulate
	visuals.add_child(body)
	
	# Eyes
	var left_eye = Polygon2D.new()
	left_eye.polygon = PackedVector2Array([
		Vector2(-10, -10), Vector2(-4, -10),
		Vector2(-4, -4), Vector2(-10, -4)
	])
	left_eye.color = Color.BLACK
	visuals.add_child(left_eye)
	
	var right_eye = Polygon2D.new()
	right_eye.polygon = PackedVector2Array([
		Vector2(4, -10), Vector2(10, -10),
		Vector2(10, -4), Vector2(4, -4)
	])
	right_eye.color = Color.BLACK
	visuals.add_child(right_eye)
