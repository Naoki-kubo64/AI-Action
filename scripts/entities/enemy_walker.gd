extends CharacterBody2D

@export var move_speed: float = 100.0
@export var gravity: float = 1000.0

var direction: float = -1.0 # Left by default

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Movement
	velocity.x = move_speed * direction
	
	# Move
	move_and_slide()
	
	# Wall/Ledge Check
	if is_on_wall():
		direction *= -1.0
	
	# Ledge check (optional, user didn't explicitly ask but good for walker)
	# For now, just wall bounce is requested: "Reverse on wall/ledge" -> ok, needs raycast for ledge.
	if is_on_floor() and not $LedgeCheck.is_colliding():
		direction *= -1.0
	
	# Visual Facing
	$Visuals.scale.x = -1 if direction > 0 else 1

func _on_stomp_area_entered(area: Area2D):
	# Assuming Player has a "Hitbox" that enters this area from ABOVE
	var parent = area.get_parent()
	if parent is CharacterBody2D and parent.name == "Player":
		# Check alignment roughly? Or just rely on area position (Head)
		# If Player is falling (velocity.y > 0)
		if parent.velocity.y > 0:
			die()
			parent.velocity.y = -400 # Bounce
			print("Enemy Stomped!")


func die():
	queue_free()
