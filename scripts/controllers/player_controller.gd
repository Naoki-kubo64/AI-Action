extends CharacterBody2D
class_name PlayerController

@export var move_speed: float = 128.0
@export var jump_force: float = -600.0
@export var gravity: float = 1200.0

# AI Commands
var current_command: String = ""
var jump_triggered: bool = false # To prevent bunny hopping in one command

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
	if current_command != cmd:
		current_command = cmd
		jump_triggered = false # Reset jump flag on new command logic? 
		# Or should reset only when explicitly setting a new instruction sequence?
		# For this prototype, we assume set_command comes from a queued sequence.

func _process_command():
	# Default friction
	velocity.x = move_toward(velocity.x, 0, move_speed)
	
	# Parse
	var cmd_upper = current_command.to_upper()
	
	if "RIGHT" in cmd_upper:
		velocity.x = move_speed
	elif "LEFT" in cmd_upper:
		velocity.x = -move_speed
	elif "STOP" in cmd_upper:
		velocity.x = 0
		
	if "JUMP" in cmd_upper:
		if is_on_floor() and not jump_triggered:
			velocity.y = jump_force
			jump_triggered = true # Lock jump until reset

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
	
	# Collision Shape
	if not has_node("CollisionShape2D"):
		var col = CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape = RectangleShape2D.new()
		shape.size = Vector2(40, 48) # Match visual size roughly
		col.shape = shape
		add_child(col)
