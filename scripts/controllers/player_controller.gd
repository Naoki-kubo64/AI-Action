extends CharacterBody2D
class_name PlayerController

@export var move_speed: float = 200.0
@export var jump_force: float = -600.0
@export var gravity: float = 1200.0

# Actions parameters
var target_velocity_x: float = 0.0
var current_jump_force_mod: float = 1.0
var is_dancing: bool = false

func _ready():
	_setup_visuals()

func _physics_process(delta):
	# Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Movement Logic
	if is_dancing:
		velocity.x = move_toward(velocity.x, 0, move_speed) # Stop while dancing
		_process_dance(delta)
	else:
		velocity.x = move_toward(velocity.x, target_velocity_x, move_speed * 5 * delta)
	
	move_and_slide()
	
	# Visuals
	if velocity.x != 0:
		$Visuals.scale.x = sign(velocity.x)

func execute_action(action_data: Dictionary):
	# Reset states
	is_dancing = false
	$Visuals.rotation = 0
	target_velocity_x = 0.0
	
	var cmd = action_data.get("cmd", "STOP")
	var speed_mod = action_data.get("speed", 0.0)
	var jump_mod = action_data.get("jump", 0.0)
	var special = action_data.get("special", "")
	
	# horizontal
	target_velocity_x = move_speed * speed_mod
	
	# vertical
	if jump_mod > 0.0 and is_on_floor():
		velocity.y = jump_force * jump_mod
	
	# Special
	if special == "DANCE":
		is_dancing = true
	elif special == "PANIC":
		# Handle panic in process or just erratic movement
		_start_panic()

func _process_dance(delta):
	$Visuals.rotation += 10.0 * delta

func _start_panic():
	var tween = create_tween()
	for i in range(5):
		tween.tween_property($Visuals, "position:x", 5, 0.05)
		tween.tween_property($Visuals, "position:x", -5, 0.05)
	tween.tween_property($Visuals, "position:x", 0, 0.05)


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
