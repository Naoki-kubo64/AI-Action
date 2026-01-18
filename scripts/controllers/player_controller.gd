extends CharacterBody2D
class_name PlayerController

@export var move_speed: float = 200.0
@export var jump_force: float = -600.0
@export var gravity: float = 1200.0

# Actions parameters
var target_velocity_x: float = 0.0
var current_jump_force_mod: float = 1.0

# State Flags
var is_dancing: bool = false
var is_stumbling: bool = false
var is_sliding: bool = false
var special_timer: float = 0.0
var active_special: String = ""
var was_on_floor: bool = false
var run_particles: CPUParticles2D
var land_particles: CPUParticles2D

func _ready():
	_setup_visuals()

func _physics_process(delta):
	# Apply Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# DEBUG: Force Label
	if not has_node("DebugLabel"):
		var l = Label.new()
		l.name = "DebugLabel"
		l.position = Vector2(-100, -100)
		l.text = "PLAYER ACTIVE"
		l.modulate = Color.RED
		l.scale = Vector2(2, 2)
		add_child(l)
	$DebugLabel.text = "Pos: " + str(position) + "\nLevel: " + LevelManager.get_current_level_path()
	
	# Landing / Jumping detection for Squash & Stretch
	if is_on_floor() and not was_on_floor:
		_animate_squash(Vector2(1.2, 0.8)) # Land = Squash
		if land_particles: land_particles.restart()
	
	was_on_floor = is_on_floor()
	
	# Particle Logic (Run)
	if run_particles:
		if is_on_floor() and abs(velocity.x) > 50:
			run_particles.emitting = true
			run_particles.direction = Vector2(-sign(velocity.x), -0.5)
		else:
			run_particles.emitting = false

	# Special Logic modifiers
	var speed_multiplier = 1.0
	
	if active_special == "SLIDE":
		# Low friction, maintain velocity
		speed_multiplier = 0.0 # Don't apply motor force, just slide
		velocity.x = move_toward(velocity.x, 0, 50 * delta) # Low friction
	elif active_special == "STUMBLE":
		speed_multiplier = 0.0
		velocity.x = move_toward(velocity.x, 0, 500 * delta)
	elif active_special == "AIR_BRAKE":
		# Rapidly reduce velocity
		velocity.x = move_toward(velocity.x, 0, 2000 * delta)
		velocity.y = move_toward(velocity.y, 0, 1000 * delta)
	else:
		# Normal Movement
		velocity.x = move_toward(velocity.x, target_velocity_x, move_speed * 5 * delta)

	# Apply Special Transforms
	_process_special_visuals(delta)
	
	move_and_slide()
	
	# Interaction with RigidBodies (Pushing)
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			# Apply impulse proportional to move direction or generic push
			# Simple push:
			c.get_collider().apply_central_impulse(-c.get_normal() * 100.0)
	
	# Visuals Facing
	if velocity.x != 0 and active_special != "LOOK_AROUND":
		$Visuals.scale.x = sign(velocity.x)

func execute_action(action_data: Dictionary):
	_reset_special_states()
	
	var cmd = action_data.get("cmd", "STOP")
	var speed_mod = action_data.get("speed", 0.0)
	var jump_mod = action_data.get("jump", 0.0)
	var special = action_data.get("special", "")
	
	active_special = special
	
	# Set Velocity Target
	if special == "SLIDE":
		# Impulse
		velocity.x = move_speed * speed_mod
		target_velocity_x = 0 # Let it slide
		$CollisionShape2D.scale.y = 0.5 # Shrink hitbox
		$Visuals.rotation_degrees = -90 if speed_mod > 0 else 90
		$Visuals.position.y = 10
	elif special == "WALL_KICK":
		if is_on_wall():
			# Wall Kick Logic
			var wall_normal = get_wall_normal()
			velocity.x = wall_normal.x * move_speed * speed_mod
			velocity.y = jump_force * jump_mod
		else:
			# Failed wall kick = small hop
			velocity.y = jump_force * 0.5
	elif special == "STUMBLE":
		velocity.x = move_speed * 0.5 # Initial stumble step
		is_stumbling = true
		$Visuals.rotation_degrees = 45
	elif special == "LOOK_AROUND":
		special_timer = 0.0
	# vertical
	if jump_mod > 0.0 and is_on_floor():
		velocity.y = jump_force * jump_mod
		_animate_squash(Vector2(0.8, 1.2)) # Jump = Stretch
	
	# Special
	if special == "DANCE":
		is_dancing = true
	elif special == "PANIC":
		_start_panic()
	else:
		# Standard Move
		target_velocity_x = move_speed * speed_mod
		if jump_mod > 0.0 and is_on_floor():
			velocity.y = jump_force * jump_mod
			_animate_squash(Vector2(0.8, 1.2)) # Jump = Stretch

func _animate_squash(target_scale: Vector2):
	# Don't squash if special transforms (slide) are active
	if active_special == "SLIDE": return
	if not has_node("Visuals"): return
	
	var tween = create_tween()
	tween.tween_property($Visuals, "scale", target_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property($Visuals, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _reset_special_states():
	is_dancing = false
	is_stumbling = false
	is_sliding = false
	active_special = ""
	
	if has_node("Visuals"):
		$Visuals.rotation = 0
		$Visuals.position = Vector2.ZERO
		$Visuals.scale = Vector2(1, 1)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.scale = Vector2(1, 1)

func _process_special_visuals(delta):
	special_timer += delta
	
	if active_special == "DANCE":
		$Visuals.rotation += 15.0 * delta
	elif active_special == "LOOK_AROUND":
		# Flip left/right every 0.3s
		var phase = int(special_timer / 0.3) % 2
		$Visuals.scale.x = 1 if phase == 0 else -1

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
	
	# Particles Setup
	# 1. Run Dust
	if not has_node("RunParticles"):
		var p = CPUParticles2D.new()
		p.name = "RunParticles"
		p.position = Vector2(0, 24) # Feet
		p.emitting = false
		p.amount = 8
		p.lifetime = 0.4
		p.direction = Vector2(-1, 0)
		p.spread = 20.0
		p.gravity = Vector2(0, -10)
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 60.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 5.0
		p.color = Color(0.9, 0.9, 0.9, 0.5)
		add_child(p)
	
	# 2. Land Dust
	if not has_node("LandParticles"):
		var p = CPUParticles2D.new()
		p.name = "LandParticles"
		p.position = Vector2(0, 24)
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 10
		p.direction = Vector2(0, -1)
		p.spread = 90.0
		p.gravity = Vector2(0, 0)
		p.initial_velocity_min = 20
		p.initial_velocity_max = 50
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.0
		p.color = Color(0.8, 0.8, 0.8, 0.6)
		add_child(p)

	# 3. Reference
	run_particles = get_node_or_null("RunParticles")
	land_particles = get_node_or_null("LandParticles")
	
	# 4. Interaction Hitbox
	if not has_node("Hitbox"):
		var area = Area2D.new()
		area.name = "Hitbox"
		
		var shape = RectangleShape2D.new()
		shape.size = Vector2(40, 48)
		var col = CollisionShape2D.new()
		col.shape = shape
		area.add_child(col)
		
		add_child(area)
		area.area_entered.connect(_on_area_entered)

signal hit_hazard
signal hit_goal
signal debug_message(msg: String)

func _on_area_entered(area: Area2D):
	debug_message.emit("Hit Area: " + area.name + " Groups: " + str(area.get_groups()))
	if area.is_in_group("hazard"):
		hit_hazard.emit()
	elif area.is_in_group("goal"):
		hit_goal.emit()
