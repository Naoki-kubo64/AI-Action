extends Node

@export var level_length: int = 50
@export var grid_size: int = 64

var safe_zone_start: int = 5
var safe_zone_end: int = 5

func generate_level(root_node: Node2D) -> Vector2:
	# Clear existing (Just in case, though Controller handles it for resets)
	for child in root_node.get_children():
		child.queue_free()
		
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Create Layers
	var vis_layer = Node2D.new()
	vis_layer.name = "Visuals"
	root_node.add_child(vis_layer)
	
	var phys_layer = Node2D.new()
	phys_layer.name = "Physics"
	root_node.add_child(phys_layer)
	
	var current_x = 0
	var current_y = 5 # Start mid-height (Grid Y)
	
	# Start Platform
	_create_platform(vis_layer, phys_layer, current_x, current_y, safe_zone_start)
	current_x += safe_zone_start
	
	# Generate Segments
	var segments_to_gen = level_length - safe_zone_start - safe_zone_end
	
	while segments_to_gen > 0:
		var segment_type = rng.randi_range(0, 3) # 0: Flat, 1: Gap, 2: Step Up, 3: Step Down
		var length = rng.randi_range(2, 5)
		if length > segments_to_gen: length = segments_to_gen
		
		match segment_type:
			0: # Flat
				_create_platform(vis_layer, phys_layer, current_x, current_y, length)
				# 20% Chance for Obstacle
				if length > 3 and rng.randf() < 0.2:
					_create_obstacle(vis_layer, phys_layer, current_x + 2, current_y - 1)
				current_x += length
			1: # Gap
				current_x += length # Just advance X without floor
			2: # Step Up
				current_y -= 1
				if current_y < 2: current_y = 2
				_create_platform(vis_layer, phys_layer, current_x, current_y, length)
				current_x += length
			3: # Step Down
				current_y += 1
				if current_y > 8: current_y = 8
				_create_platform(vis_layer, phys_layer, current_x, current_y, length)
				current_x += length
				
		segments_to_gen -= length
	
	# End Platform
	_create_platform(vis_layer, phys_layer, current_x, current_y, safe_zone_end)
	
	# Goal
	var goal_x = (current_x + safe_zone_end - 2) * grid_size
	var goal_y = (current_y - 1) * grid_size
	_create_goal(vis_layer, phys_layer, goal_x, goal_y)

	return Vector2(100, (5 * grid_size) - 64) # Player Start Pos

func _create_platform(vis_layer, phys_layer, start_x, y, length):
	# Create visual blocks
	for k in range(length):
		var x = start_x + k
		var block_pos = Vector2(x * grid_size, y * grid_size)
		
		# Visual Block (Mario Style)
		var visual_rect = ColorRect.new()
		visual_rect.size = Vector2(grid_size - 1, grid_size - 1) # 1px Gap
		visual_rect.position = block_pos
		visual_rect.color = Color("#8B4513") # Brick Brown
		
		# Inner bevel for 3D look
		var inner = ColorRect.new()
		inner.size = Vector2(grid_size - 8, grid_size - 8)
		inner.position = Vector2(4, 4)
		inner.color = Color("#A0522D") # Lighter Brown
		visual_rect.add_child(inner)
		
		# Studs (Block pattern)
		for stud_i in range(2):
			for stud_j in range(2):
				var stud = ColorRect.new()
				stud.size = Vector2(4, 4)
				stud.color = Color.BLACK
				stud.position = Vector2(16 + stud_i * 32, 16 + stud_j * 32)
				inner.add_child(stud)
				
		vis_layer.add_child(visual_rect)
	
	# Physical Body (One collider for smoothness)
	var static_body = StaticBody2D.new()
	static_body.position = Vector2(start_x * grid_size + (length * grid_size) / 2.0, y * grid_size + grid_size / 2.0)
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length * grid_size, grid_size)
	
	var col = CollisionShape2D.new()
	col.shape = shape
	static_body.add_child(col)
	phys_layer.add_child(static_body)

func _create_obstacle(vis_layer, phys_layer, x, y):
	var pos = Vector2(x * grid_size, y * grid_size)
	
	var visual = ColorRect.new()
	visual.size = Vector2(grid_size, grid_size)
	visual.position = pos
	visual.color = Color.RED
	vis_layer.add_child(visual)
	
	# Hazard Area
	var area = Area2D.new()
	area.position = pos + Vector2(grid_size/2.0, grid_size/2.0)
	area.add_to_group("hazard")
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(grid_size - 10, grid_size - 10) # Slightly smaller hitbox
	
	var col = CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	phys_layer.add_child(area)

func _create_goal(vis_layer, phys_layer, x, y):
	var visual = ColorRect.new()
	visual.size = Vector2(grid_size, grid_size * 2)
	visual.position = Vector2(x, y - grid_size)
	visual.color = Color.GOLD
	vis_layer.add_child(visual)
	
	# Goal Area
	var area = Area2D.new()
	area.position = Vector2(x + grid_size/2.0, y)
	area.add_to_group("goal")
	
	var shape = RectangleShape2D.new()
	shape.size = Vector2(grid_size, grid_size * 2)
	
	var col = CollisionShape2D.new()
	col.shape = shape
	area.add_child(col)
	phys_layer.add_child(area)
