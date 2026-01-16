extends Node
class_name LevelGenerator

@export var level_length: int = 50
@export var cell_size: int = 64

# Terrain Types: 0=Air, 1=FloorBlock, 2=Gap, 3=TallBlock, 9=Goal, 8=Enemy
var level_data: Array = []

func generate_level(root_node: Node2D) -> Vector2:
	for child in root_node.get_children():
		child.queue_free()
	
	level_data.clear()
	var start_pos = Vector2(100, 300) # Default start
	
	var current_height = 5 # Cells from bottom
	var floor_y_index = 10 # Bottom of screen approx 
	
	# 0 to level_length
	for x in range(level_length):
		if x < 5: 
			# Start area: Flat
			_create_column(root_node, x, floor_y_index, 0)
			if x == 2: start_pos = Vector2(x * cell_size + 32, (floor_y_index-1) * cell_size)
		elif x == level_length - 5:
			# Goal area
			_create_column(root_node, x, floor_y_index, 9)
		else:
			# Random generation
			var rand = randf()
			if rand < 0.1: # Gap
				# No floor
				pass 
			elif rand < 0.2: # High platform
				_create_column(root_node, x, floor_y_index - 2, 0)
			elif rand < 0.25: # Enemy/Obstacle
				_create_column(root_node, x, floor_y_index, 8)
			else: # Normal floor
				_create_column(root_node, x, floor_y_index, 0)
	
	return start_pos

func _create_column(root: Node2D, x: int, floor_y: int, special_type: int):
	# Create floor block
	if special_type != 9 and special_type != 8:
		# Just physics static body for floor
		var pos = Vector2(x * cell_size, floor_y * cell_size)
		_create_block(root, pos, Color(0.2, 0.8, 0.2), true) # Green floor
	
	if special_type == 8: # Obstacle / Enemy
		var pos = Vector2(x * cell_size, (floor_y - 1) * cell_size)
		_create_block(root, pos, Color(0.8, 0.2, 0.2), true, "Enemy")
		# Also floor below
		var floor_pos = Vector2(x * cell_size, floor_y * cell_size)
		_create_block(root, floor_pos, Color(0.2, 0.8, 0.2), true)

	if special_type == 9: # Goal
		var pos = Vector2(x * cell_size, (floor_y - 1) * cell_size)
		_create_block(root, pos, Color(1.0, 0.8, 0.0), false, "Goal") # No collision rigid, trigger area ideally
		var floor_pos = Vector2(x * cell_size, floor_y * cell_size)
		_create_block(root, floor_pos, Color(0.2, 0.8, 0.2), true)

func _create_block(parent: Node2D, pos: Vector2, color: Color, has_collision: bool, name_tag: String = ""):
	var body
	if has_collision:
		body = StaticBody2D.new()
	else:
		body = Area2D.new() # For triggers
		
	body.position = pos + Vector2(cell_size/2, cell_size/2) # Center
	if name_tag != "": body.name = name_tag
	parent.add_child(body)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	col.shape = shape
	body.add_child(col)
	
	var visual = ColorRect.new()
	visual.position = Vector2(-cell_size/2, -cell_size/2)
	visual.size = Vector2(cell_size, cell_size)
	visual.color = color
	body.add_child(visual)
