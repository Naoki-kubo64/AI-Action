extends Node
class_name LevelGenerator

@export var level_width: int = 10
@export var level_height: int = 10
@export var cell_size: int = 64

# Simple level data: 0 = Floor, 1 = Wall, 2 = Goal, 3 = Start
var grid_data: Array = []

func _ready():
	pass

func generate_level(root_node: Node2D) -> Vector2:
	# Clear previous level
	for child in root_node.get_children():
		child.queue_free()
	
	grid_data.clear()
	var start_pos = Vector2.ZERO
	
	for y in range(level_height):
		var row = []
		for x in range(level_width):
			# Simple logic: Border is wall, random obstacles inside
			if x == 0 or x == level_width - 1 or y == 0 or y == level_height - 1:
				row.append(1) # Wall
			elif (x == 1 and y == 1):
				row.append(3) # Start
				start_pos = Vector2(x, y) * cell_size + Vector2(cell_size/2, cell_size/2)
			elif x == level_width - 2 and y == level_height - 2:
				row.append(2) # Goal
			else:
				if randf() < 0.2:
					row.append(1) # Wall
				else:
					row.append(0) # Floor
		grid_data.append(row)
	
	_instantiate_visuals(root_node)
	return start_pos

func _instantiate_visuals(root_node: Node2D):
	for y in range(level_height):
		for x in range(level_width):
			var type = grid_data[y][x]
			var pos = Vector2(x, y) * cell_size
			
			var rect = ColorRect.new()
			rect.position = pos
			rect.size = Vector2(cell_size, cell_size)
			
			if type == 1: # Wall
				rect.color = Color(0.2, 0.2, 0.3)
				# Add collision if needed (skipping for visual prototype simplicity, assuming logic handles movement restriction or we add StaticBody)
			elif type == 2: # Goal
				rect.color = Color(1.0, 0.8, 0.0, 0.5)
			else: # Floor
				rect.color = Color(0.1, 0.1, 0.15)
				# Checker pattern
				if (x + y) % 2 == 0:
					rect.color = Color(0.12, 0.12, 0.18)
			
			root_node.add_child(rect)
			
			# Add Wall outline or simple detail
			if type == 1:
				var border = ReferenceRect.new()
				border.editor_only = false
				border.border_color = Color(0.3, 0.3, 0.4)
				border.border_width = 2.0
				border.size = rect.size
				rect.add_child(border)
