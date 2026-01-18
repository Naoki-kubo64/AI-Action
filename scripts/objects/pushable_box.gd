extends CharacterBody2D

var gravity = 1200.0
var friction = 600.0

func _physics_process(delta):
	# Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Apply Friction
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	move_and_slide()

func push(force_velocity: Vector2):
	velocity.x = force_velocity.x
