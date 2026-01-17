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
	
	var level_gen = $LevelGenerator
	start_pos = level_gen.generate_level($LevelRoot)
	player.position = start_pos
	
	# Connect Player Signals
	if not player.hit_hazard.is_connected(_on_player_hit_hazard):
		player.hit_hazard.connect(_on_player_hit_hazard)
	if not player.hit_goal.is_connected(_on_player_hit_goal):
		player.hit_goal.connect(_on_player_hit_goal)
	
	_enter_preview_mode()
	_setup_minimap()

func _on_player_hit_hazard():
	if current_state != State.PREVIEW and current_state != State.INPUT:
		trigger_shake(20.0) # Shake screen
		game_over("Hit Hazard")

func _on_player_hit_goal():
	# Victory
	print("Level Cleared!")
	current_state = State.PREVIEW # Stop inputs
	player.execute_action(command_db["STOP"])
	
	# Show message (reuse RetryDialog for now or add a HUD message)
	# For simplicity, using a visual feedback via Label or Print
	if has_node("CanvasLayer/LevelHUD"):
		$CanvasLayer/LevelHUD.text = "STAGE CLEAR!"
		$CanvasLayer/LevelHUD.modulate = Color.GREEN
	
	# Play sound? (Todo)
	
	# Wait and Advance
	await get_tree().create_timer(3.0).timeout
	
	LevelManager.next_level()
	_reset_game()


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
	print("[GameController] Attempting to load level: '", level_path, "'")
	
	if not ResourceLoader.exists(level_path):
		print("[GameController] Level file not found: ", level_path, ". Using Generator Fallback.")
		var level_gen = $LevelGenerator
		start_pos = level_gen.generate_level($LevelRoot)
	else:
		print("[GameController] Level found. Instantiating.")
		var level_scene = load(level_path)
		var level_instance = level_scene.instantiate()
		$LevelRoot.add_child(level_instance)
		
		# Find start pos
		var start_node = level_instance.get_node_or_null("PlayerStart")
		if start_node:
			start_pos = start_node.position
		else:
			start_pos = Vector2(100, 100) # Default
	
	player.position = start_pos
	player.velocity = Vector2.ZERO
	player.execute_action(command_db["STOP"])
	
	# Reset Camera Smoothing immediately to prevent lag
	camera.position_smoothing_enabled = false
	camera.align() # Force update
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
	print("[GameController] Action Finished. Waiting for stop...")
	player.execute_action(command_db["STOP"])
	
	# Wait for player to stabilize
	# We wait until on floor AND velocity is low
	var wait_time = 0.0
	while wait_time < 3.0: # Max wait 3s to prevent softlock
		if player.is_on_floor() and player.velocity.length() < 10.0:
			break
		await get_tree().physics_frame
		wait_time += get_physics_process_delta_time()
		
		# Allow early exit if player falls off map (game over handles it)
		if player.position.y > 1500: break
	
	_enter_input_mode()

enum State {PREVIEW, INPUT, ACTION, GAMEOVER}
var current_state = State.PREVIEW

# ... (omitted)

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
