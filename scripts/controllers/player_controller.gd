extends CharacterBody2D
class_name PlayerController

@export var move_speed: float = 300.0
@export var jump_force: float = -600.0
@export var gravity: float = 1200.0

# AI Commands
var current_command: String = ""

func _ready():
	_setup_visuals()

func _physics_process(delta):
	# Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle AI Commands
	_process_command()
	
	move_and_slide()
	
	# Simple visual rotation
	if velocity.x != 0:
		$Visuals.scale.x = sign(velocity.x)

func set_command(cmd: String):
	current_command = cmd

func _process_command():
	# Reset horizontal velocity (AI controls it step by step, or continuous)
	# For this prototype: executed command persists for the frame or until changed
	
	# Default friction
	velocity.x = move_toward(velocity.x, 0, move_speed)
	
	if current_command == "RIGHT":
		velocity.x = move_speed
	elif current_command == "LEFT":
		velocity.x = -move_speed
	elif current_command == "JUMP":
		if is_on_floor():
			velocity.y = jump_force
		# After jump, keep moving forward if needed, or just jump vertical
		# Ideally AI says "JUMP_RIGHT"
		
	elif current_command == "JUMP_RIGHT":
		if is_on_floor():
			velocity.y = jump_force
		velocity.x = move_speed
		
	elif current_command == "STOP":
		velocity.x = 0

func _setup_visuals():
	if has_node("Visuals"): return
	
	var visuals = Node2D.new()
	visuals.name = "Visuals"
	add_child(visuals)
	
	# Body (Robot style)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-16, -24), Vector2(16, -24),
		Vector2(20, 16), Vector2(-20, 16)
	])
	body.color = Color.WHITE
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
