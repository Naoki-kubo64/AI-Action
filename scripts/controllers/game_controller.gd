extends Node
class_name GameController

@onready var player: PlayerController = $Player
@onready var retry_dialog = $CanvasLayer/RetryDialog
@onready var prompt_ui = $CanvasLayer/PromptInputUI
@onready var camera = $Player/Camera2D

enum State {PREVIEW, INPUT, ACTION, GAMEOVER}
var current_state = State.PREVIEW

var turn_count: int = 0
var max_turns: int = 30
var user_prompt: String = ""
var start_pos: Vector2 = Vector2.ZERO

# --- COMMAND DICTIONARY ---
# Defines properties for every possible AI command
var command_db = {
	# Ground Movement
	"STOP": {"speed": 0.0, "jump": 0.0, "duration": 0.5},
	"WAIT": {"speed": 0.0, "jump": 0.0, "duration": 1.0},
	"SHORT_WAIT": {"speed": 0.0, "jump": 0.0, "duration": 0.5},
	
	"CREEP_RIGHT": {"speed": 0.3, "jump": 0.0, "duration": 0.4},
	"STEP_RIGHT": {"speed": 0.5, "jump": 0.0, "duration": 0.5},
	"WALK_RIGHT": {"speed": 1.0, "jump": 0.0, "duration": 0.8},
	"RUN_RIGHT": {"speed": 1.5, "jump": 0.0, "duration": 1.2},
	"SPRINT_RIGHT": {"speed": 2.0, "jump": 0.0, "duration": 1.5},
	"BACK_STEP": {"speed": - 0.5, "jump": 0.0, "duration": 0.3}, # Usually moves left if facing right, simplifies to negative speed
	
	"CREEP_LEFT": {"speed": - 0.3, "jump": 0.0, "duration": 0.4},
	"STEP_LEFT": {"speed": - 0.5, "jump": 0.0, "duration": 0.5},
	"WALK_LEFT": {"speed": - 1.0, "jump": 0.0, "duration": 0.8},
	"RUN_LEFT": {"speed": - 1.5, "jump": 0.0, "duration": 1.2},
	"SPRINT_LEFT": {"speed": - 2.0, "jump": 0.0, "duration": 1.5},
	
	# Vertical Jumps
	"HOP": {"speed": 0.0, "jump": 0.5, "duration": 0.6},
	"JUMP": {"speed": 0.0, "jump": 1.0, "duration": 0.8},
	"HIGH_JUMP": {"speed": 0.0, "jump": 1.3, "duration": 1.0},
	"SUPER_JUMP": {"speed": 0.0, "jump": 1.6, "duration": 1.2},
	
	# Directional Jumps (Right)
	"HOP_RIGHT": {"speed": 0.5, "jump": 0.5, "duration": 0.5},
	"JUMP_RIGHT": {"speed": 1.0, "jump": 1.0, "duration": 1.0},
	"LONG_JUMP_RIGHT": {"speed": 1.5, "jump": 1.0, "duration": 1.2},
	"HIGH_JUMP_RIGHT": {"speed": 0.5, "jump": 1.4, "duration": 1.2},
	"DASH_JUMP_RIGHT": {"speed": 2.0, "jump": 1.2, "duration": 1.5},
	
	# Directional Jumps (Left)
	"HOP_LEFT": {"speed": - 0.5, "jump": 0.5, "duration": 0.5},
	"JUMP_LEFT": {"speed": - 1.0, "jump": 1.0, "duration": 1.0},
	"LONG_JUMP_LEFT": {"speed": - 1.5, "jump": 1.0, "duration": 1.2},
	"HIGH_JUMP_LEFT": {"speed": - 0.5, "jump": 1.4, "duration": 1.2},
	"DASH_JUMP_LEFT": {"speed": - 2.0, "jump": 1.2, "duration": 1.5},
	"SUPER_JUMP_LEFT": {"speed": - 1.5, "jump": 1.6, "duration": 1.5},
	
	"SUPER_JUMP_RIGHT": {"speed": 1.5, "jump": 1.6, "duration": 1.5},
	
	# Timing / Idle
	"WAIT_SHORT": {"speed": 0.0, "jump": 0.0, "duration": 0.5},
	"WAIT_LONG": {"speed": 0.0, "jump": 0.0, "duration": 2.0},
	"LOOK_AROUND": {"speed": 0.0, "jump": 0.0, "duration": 1.5, "special": "LOOK_AROUND"},
	
	# Technical (Physics)
	"SLIDE_RIGHT": {"speed": 1.8, "jump": 0.0, "duration": 0.8, "special": "SLIDE"},
	"SLIDE_LEFT": {"speed": - 1.8, "jump": 0.0, "duration": 0.8, "special": "SLIDE"},
	"WALL_KICK_RIGHT": {"speed": 1.2, "jump": 1.2, "duration": 0.6, "special": "WALL_KICK"},
	"WALL_KICK_LEFT": {"speed": - 1.2, "jump": 1.2, "duration": 0.6, "special": "WALL_KICK"},
	"AIR_BRAKE": {"speed": 0.0, "jump": 0.0, "duration": 0.5, "special": "AIR_BRAKE"},
	
	# Failure / Noise
	"STUMBLE": {"speed": 0.2, "jump": 0.0, "duration": 1.5, "special": "STUMBLE"},
	"OVERSHOOT_RIGHT": {"speed": 1.5, "jump": 0.0, "duration": 2.5}, # Runs too long
	"OVERSHOOT_LEFT": {"speed": - 1.5, "jump": 0.0, "duration": 2.5},
	
	# Interaction (Mock)
	"INTERACT": {"speed": 0.0, "jump": 0.0, "duration": 1.0, "special": "INTERACT"},
	"PUSH": {"speed": 0.2, "jump": 0.0, "duration": 2.0, "special": "PUSH"},
	
	# Special Emotes
	"DANCE": {"speed": 0.0, "jump": 0.0, "duration": 1.5, "special": "DANCE"},
	"PANIC": {"speed": 0.0, "jump": 0.0, "duration": 1.5, "special": "PANIC"},
}

func _ready():
	if GameManager.current_character:
		print("[GameController] Initialized with ", GameManager.current_character.character_name)
		player.modulate = GameManager.current_character.base_color
	
	prompt_ui.game_start_requested.connect(_on_prompt_submitted)
	LLMService.response_received.connect(_on_llm_response)
	retry_dialog.retry_requested.connect(_on_retry_requested)
	
	# Connect Player Signals FIRST before reset_game
	if not player.hit_hazard.is_connected(_on_player_hit_hazard):
		player.hit_hazard.connect(_on_player_hit_hazard)
	if not player.hit_goal.is_connected(_on_player_hit_goal):
		player.hit_goal.connect(_on_player_hit_goal)
	if not player.debug_message.is_connected(_log):
		player.debug_message.connect(_log)
	
	_setup_minimap()
	
	# Call _reset_game to properly load level (including fixed levels)
	_reset_game()

func _on_player_hit_hazard():
	if current_state != State.PREVIEW and current_state != State.INPUT:
	trigger_shake(20.0) # Shake screen
		game_over("Hit Hazard")

var is_level_clearing: bool = false

func _on_player_hit_goal():
	if is_level_clearing: return
	is_level_clearing = true
	
	# Victory
	print("Level Cleared!")
	current_state = State.PREVIEW # Stop inputs
	player.execute_action(command_db["STOP"])
	
	# Show message (reuse RetryDialog for now or add a HUD message)
	if has_node("CanvasLayer/LevelHUD"):
		$CanvasLayer/LevelHUD.text = "STAGE CLEAR!"
		$CanvasLayer/LevelHUD.modulate = Color.GREEN
	
	# Wait and Advance
	await get_tree().create_timer(3.0).timeout
	
	# next_level() calls load_current_level() which calls _reset_game() internally
	LevelManager.next_level()
	is_level_clearing = false


func _on_retry_requested(use_pro: bool):
	GameManager.is_pro_mode = use_pro
	_reset_game()

func _reset_game():
	print("[GameController] Resetting Game...")
	turn_count = 0
	
	# Update HUD
	if has_node("CanvasLayer/LevelHUD"):
		$CanvasLayer/LevelHUD.text = "LEVEL %d-%d" % [LevelManager.current_world, LevelManager.current_stage]
	
	# Clear old level
	for child in $LevelRoot.get_children():
		child.queue_free()
	
	await get_tree().physics_frame
	
	# Load Level from Manager
	var level_path = LevelManager.get_current_level_path()
	_log("[Game] Loading Level: " + level_path)
	
	# FORCE MANUAL CONSTRUCTION for World 1 levels
	if "Level_1-" in level_path:
		var constructed = _construct_world_1_level(level_path, $LevelRoot)
		if constructed:
			start_pos = Vector2(96, 400)
			player.position = start_pos
			player.velocity = Vector2.ZERO
			player.execute_action(command_db["STOP"])
			
			camera.position_smoothing_enabled = false
			camera.align()
			await get_tree().process_frame
			camera.position_smoothing_enabled = true
			_enter_preview_mode()
			return

	# Fallback: Random Generator for other worlds
	_log("[Game] Using Random Generator for non-World-1 level.")
	var level_gen = $LevelGenerator
	start_pos = level_gen.generate_level($LevelRoot)
	
	player.position = start_pos
	player.velocity = Vector2.ZERO
	player.execute_action(command_db["STOP"])
	
	camera.position_smoothing_enabled = false
	camera.align()
	await get_tree().process_frame
	camera.position_smoothing_enabled = true
	
	_enter_preview_mode()

func _setup_minimap():
	var minimap_viewport = $CanvasLayer/MinimapContainer/SubViewportContainer/SubViewport
	if minimap_viewport:
		minimap_viewport.world_2d = get_viewport().world_2d
		var mini_cam = minimap_viewport.get_node("Camera2D")
		if mini_cam:
			var remote = RemoteTransform2D.new()
			remote.remote_path = mini_cam.get_path()
			player.add_child(remote )

func _enter_preview_mode():
	current_state = State.PREVIEW
	prompt_ui.visible = false
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(0.5, 0.5), 1.0)
	await get_tree().create_timer(2.0).timeout
	_enter_input_mode()

func _enter_input_mode():
	if current_state == State.GAMEOVER: return
	
	current_state = State.INPUT
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow tween during pause
	tween.tween_property(camera, "zoom", Vector2(1.5, 1.5), 0.5)
	prompt_ui.visible = true
	get_tree().paused = true # PAUSE GAME

func _on_prompt_submitted(prompt: String, key: String):
	if current_state != State.INPUT: return
	user_prompt = prompt
	GameManager.api_key = key
	_enter_action_mode()

func _enter_action_mode():
	get_tree().paused = false # RESUME GAME
	current_state = State.ACTION
	prompt_ui.visible = false
	
	turn_count += 1
	if turn_count > max_turns:
		game_over("Max Turns Reached")
		return

	_request_ai_action()

func _process(delta):
	# Fall Check
	if current_state != State.PREVIEW and player.position.y > 1500:
		# Player fell off
		if current_state != State.PREVIEW: # Avoid loop
			game_over("Fell off world")
	
	# Camera Shake
	if shake_strength > 0:
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		var offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		camera.offset = offset
	else:
		camera.offset = Vector2.ZERO

var shake_strength: float = 0.0
var shake_decay: float = 5.0

func trigger_shake(amount: float):
	shake_strength = amount

func _request_ai_action():
	if GameManager.current_character == null:
		_finish_action()
		return
	
	var context = _get_platformer_context()
	var full_input = "User Instruction: " + user_prompt + "\nContext: " + context
	
	print("[GameController] Requesting AI Action... Prompt: ", user_prompt)
	LLMService.request_action(
		GameManager.current_character,
		GameManager.is_pro_mode,
		full_input
	)

func _get_platformer_context() -> String:
	var pos_x = int(player.position.x / 64)
	return "Player Grid X: " + str(pos_x) + ". Is On Floor: " + str(player.is_on_floor())

func _on_llm_response(response: String):
	if current_state != State.ACTION: return
	print("[GameController] AI Raw Response: ", response)
	
	# Clean text if it contains markdown code blocks
	response = response.replace("```json", "").replace("```", "").strip_edges()
	
	var actions = JSON.parse_string(response)
	
	if actions == null or not (actions is Array):
		print("[GameController] Failed to parse JSON actions. Fallback to parsing basic list.")
		# Fallback handling might be needed if AI fails to follow JSON instructions, 
		# but for now lets rely on the prompt instructions.
		_finish_action()
		return
	
	for action_item in actions:
		var cmd_str = action_item.get("action", "STOP").to_upper()
		var override_duration = action_item.get("duration")
		var strength_mod = action_item.get("strength", 1.0)
		
		# Look up base stats
		var action_data = command_db.get("STOP").duplicate() # Secure default
		if command_db.has(cmd_str):
			action_data = command_db[cmd_str].duplicate()
		elif "RIGHT" in cmd_str: action_data = command_db["WALK_RIGHT"].duplicate()
		elif "LEFT" in cmd_str: action_data = command_db["WALK_LEFT"].duplicate()
		
		# Apply Overrides
		action_data["cmd"] = cmd_str
		if override_duration != null:
			action_data["duration"] = float(override_duration)
		
		# Merge Strength into Speed/Jump
		# If strength is 0.5, speed becomes half of BASE speed of that command
		action_data["speed"] = action_data.get("speed", 0.0) * float(strength_mod)
		action_data["jump"] = action_data.get("jump", 0.0) * float(strength_mod)
		action_data["strength"] = strength_mod
		
		print("[GameController] Executing: ", cmd_str, " | Strength: ", strength_mod, " | Dur: ", action_data["duration"])
		
		player.execute_action(action_data)
		
		await get_tree().create_timer(action_data["duration"]).timeout
	
	_finish_action()

func _finish_action():
	if current_state == State.GAMEOVER: return
	
	print("[GameController] Action Finished. Waiting for stop...")
	player.execute_action(command_db["STOP"])
	
	# Wait for player to stabilize
	# We wait until on floor AND velocity is low
	var wait_time = 0.0
	while wait_time < 3.0: # Max wait 3s to prevent softlock
		if current_state == State.GAMEOVER: return
		
		if player.is_on_floor() and player.velocity.length() < 10.0:
			break
		await get_tree().physics_frame
		wait_time += get_physics_process_delta_time()
		
		# Allow early exit if player falls off map (game over handles it)
		if player.position.y > 1500:
			# Redundant check but safe
			break
	
	if current_state == State.GAMEOVER: return
	_enter_input_mode()

func game_over(reason: String):
	if current_state == State.GAMEOVER: return # Prevent double trigger
	current_state = State.GAMEOVER
	
	player.execute_action(command_db["STOP"])
	retry_dialog.show_fail_dialog(reason)
	# Trigger Memory Update
	LLMService.request_summarization()

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		$CanvasLayer/DebugLog.visible = not $CanvasLayer/DebugLog.visible

func _log(msg: String):
	print(msg)
	if has_node("CanvasLayer/DebugLog"):
		var log_node = $CanvasLayer/DebugLog
		log_node.text += msg + "\n"
		log_node.scroll_vertical = INF

func _construct_manual_level_1_1(parent: Node2D):
	_log("[Game] Constructing Level 1-1 programmatically...")
	
	var floor_node = Node2D.new()
	floor_node.name = "Floor"
	parent.add_child(floor_node)
	
	# Helper to create a single block (StaticBody2D + CollisionShape2D + ColorRect)
	var create_block = func(x_idx: int, y_idx: int) -> StaticBody2D:
		var block = StaticBody2D.new()
		block.position = Vector2(x_idx * 64, y_idx * 64)
		
		# Collision
		var col = CollisionShape2D.new()
		col.position = Vector2(32, 32)
		var shape = RectangleShape2D.new()
		shape.size = Vector2(64, 64)
		col.shape = shape
		block.add_child(col)
		
		# Visual (Brown brick)
		var rect = ColorRect.new()
		rect.size = Vector2(64, 64)
		rect.color = Color(0.55, 0.27, 0.07) # Brown
		block.add_child(rect)
		
		# Inner bevel
		var inner = ColorRect.new()
		inner.size = Vector2(56, 56)
		inner.position = Vector2(4, 4)
		inner.color = Color(0.65, 0.35, 0.15) # Lighter brown
		rect.add_child(inner)
		
		return block
	
	# Flat Area (0 to 5)
	for i in range(6):
		floor_node.add_child(create_block.call(i, 8))
	
	# Stairs 1 (i=6)
	floor_node.add_child(create_block.call(6, 8))
	
	# Stairs 2 (i=7)
	floor_node.add_child(create_block.call(7, 8))
	floor_node.add_child(create_block.call(7, 7))
	
	# Stairs 3 (i=8)
	floor_node.add_child(create_block.call(8, 8))
	floor_node.add_child(create_block.call(8, 7))
	floor_node.add_child(create_block.call(8, 6))
	
	# Stairs 4 (i=9) - Top
	floor_node.add_child(create_block.call(9, 8))
	floor_node.add_child(create_block.call(9, 7))
	floor_node.add_child(create_block.call(9, 6))
	floor_node.add_child(create_block.call(9, 5))
	
	# Goal Area (on top of stack 4)
	var goal = Area2D.new()
	goal.name = "GoalArea"
	goal.add_to_group("goal")
	goal.position = Vector2(9 * 64 + 32, 4 * 64 + 32) # Centered
	
	var goal_col = CollisionShape2D.new()
	var goal_shape = RectangleShape2D.new()
	goal_shape.size = Vector2(64, 64)
	goal_col.shape = goal_shape
	goal.add_child(goal_col)
	
	var goal_viz = ColorRect.new()
	goal_viz.size = Vector2(64, 64)
	goal_viz.position = Vector2(-32, -32)
	goal_viz.color = Color(1, 0.84, 0, 0.7) # Gold
	goal.add_child(goal_viz)
	
	parent.add_child(goal)
	_log("[Game] Manual Level 1-1 Constructed Successfully!")

# World 1 Level Dispatcher
func _construct_world_1_level(level_path: String, parent: Node2D) -> bool:
	if "1-1" in level_path:
		_log("[Game] Constructing Level 1-1 (Tutorial: Stairs)")
		_construct_manual_level_1_1(parent)
		return true
	elif "1-2" in level_path:
		_log("[Game] Constructing Level 1-2 (Gaps)")
		_construct_manual_level_1_2(parent)
		return true
	elif "1-3" in level_path:
		_log("[Game] Constructing Level 1-3 (Walls)")
		_construct_manual_level_1_3(parent)
		return true
	elif "1-4" in level_path:
		_log("[Game] Constructing Level 1-4 (Enemies)")
		_construct_manual_level_1_4(parent)
		return true
	else:
		_log("[Game] Unknown World 1 level: " + level_path)
		return false

# --- SHARED HELPER ---
func _create_block(x_idx: int, y_idx: int) -> StaticBody2D:
	var block = StaticBody2D.new()
	block.position = Vector2(x_idx * 64, y_idx * 64)
	
	var col = CollisionShape2D.new()
	col.position = Vector2(32, 32)
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	col.shape = shape
	block.add_child(col)
	
	var rect = ColorRect.new()
	rect.size = Vector2(64, 64)
	rect.color = Color(0.55, 0.27, 0.07)
	block.add_child(rect)
	
	var inner = ColorRect.new()
	inner.size = Vector2(56, 56)
	inner.position = Vector2(4, 4)
	inner.color = Color(0.65, 0.35, 0.15)
	rect.add_child(inner)
	
	return block

func _create_goal(x_idx: int, y_idx: int) -> Area2D:
	var goal = Area2D.new()
	goal.name = "GoalArea"
	goal.add_to_group("goal")
	goal.position = Vector2(x_idx * 64 + 32, y_idx * 64 + 32)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	col.shape = shape
	goal.add_child(col)
	
	var viz = ColorRect.new()
	viz.size = Vector2(64, 64)
	viz.position = Vector2(-32, -32)
	viz.color = Color(1, 0.84, 0, 0.7)
	goal.add_child(viz)
	
	return goal

# --- LEVEL 1-2: GAPS ---
func _construct_manual_level_1_2(parent: Node2D):
	var floor_node = Node2D.new()
	floor_node.name = "Floor"
	parent.add_child(floor_node)
	
	# Start Platform (0-2)
	for i in range(3):
		floor_node.add_child(_create_block(i, 8))
	
	# Gap (3-4)
	
	# Middle Platform (5-7)
	for i in range(5, 8):
		floor_node.add_child(_create_block(i, 8))
	
	# Bigger Gap (8-10)
	
	# End Platform (11-14)
	for i in range(11, 15):
		floor_node.add_child(_create_block(i, 8))
	
	parent.add_child(_create_goal(14, 7))
	_log("[Game] Level 1-2 Constructed!")

# --- LEVEL 1-3: WALLS ---
func _construct_manual_level_1_3(parent: Node2D):
	var floor_node = Node2D.new()
	floor_node.name = "Floor"
	parent.add_child(floor_node)
	
	# Start (0-1)
	for i in range(2):
		floor_node.add_child(_create_block(i, 8))
	
	# Wall 1 (x=2, height 2)
	floor_node.add_child(_create_block(2, 8))
	floor_node.add_child(_create_block(2, 7))
	
	# Platform (3-4)
	for i in range(3, 5):
		floor_node.add_child(_create_block(i, 8))
	
	# Wall 2 (x=5, height 3)
	floor_node.add_child(_create_block(5, 8))
	floor_node.add_child(_create_block(5, 7))
	floor_node.add_child(_create_block(5, 6))
	
	# End Platform (6-9)
	for i in range(6, 10):
		floor_node.add_child(_create_block(i, 8))
	
	parent.add_child(_create_goal(9, 7))
	_log("[Game] Level 1-3 Constructed!")

# --- LEVEL 1-4: ENEMIES ---
func _construct_manual_level_1_4(parent: Node2D):
	var floor_node = Node2D.new()
	floor_node.name = "Floor"
	parent.add_child(floor_node)
	
	# Full flat floor (0-12)
	for i in range(13):
		floor_node.add_child(_create_block(i, 8))
	
	# Add Enemies (simple red hazard blocks for now)
	var enemy1 = _create_enemy(4, 7)
	var enemy2 = _create_enemy(8, 7)
	floor_node.add_child(enemy1)
	floor_node.add_child(enemy2)
	
	parent.add_child(_create_goal(12, 7))
	_log("[Game] Level 1-4 Constructed!")

func _create_enemy(x_idx: int, y_idx: int) -> Area2D:
	var enemy = Area2D.new()
	enemy.name = "Enemy"
	enemy.add_to_group("hazard")
	enemy.position = Vector2(x_idx * 64 + 32, y_idx * 64 + 32)
	
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(48, 48)
	col.shape = shape
	enemy.add_child(col)
	
	var viz = ColorRect.new()
	viz.size = Vector2(48, 48)
	viz.position = Vector2(-24, -24)
	viz.color = Color(0.8, 0.2, 0.2, 1.0)
	enemy.add_child(viz)
	
	return enemy
