extends Node
class_name GameController

@onready var player: PlayerController = $Player
@onready var retry_dialog = $CanvasLayer/RetryDialog
@onready var prompt_ui = $CanvasLayer/PromptInputUI
@onready var camera = $Player/Camera2D

enum State { PREVIEW, INPUT, ACTION }
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
	"STEP_RIGHT":  {"speed": 0.5, "jump": 0.0, "duration": 0.5},
	"WALK_RIGHT":  {"speed": 1.0, "jump": 0.0, "duration": 0.8},
	"RUN_RIGHT":   {"speed": 1.5, "jump": 0.0, "duration": 1.2},
	"SPRINT_RIGHT":{"speed": 2.0, "jump": 0.0, "duration": 1.5},
	"BACK_STEP":   {"speed": -0.5, "jump": 0.0, "duration": 0.3}, # Usually moves left if facing right, simplifies to negative speed
	
	"CREEP_LEFT":  {"speed": -0.3, "jump": 0.0, "duration": 0.4},
	"STEP_LEFT":   {"speed": -0.5, "jump": 0.0, "duration": 0.5},
	"WALK_LEFT":   {"speed": -1.0, "jump": 0.0, "duration": 0.8},
	"RUN_LEFT":    {"speed": -1.5, "jump": 0.0, "duration": 1.2},
	"SPRINT_LEFT": {"speed": -2.0, "jump": 0.0, "duration": 1.5},
	
	# Vertical Jumps
	"HOP":         {"speed": 0.0, "jump": 0.5, "duration": 0.6},
	"JUMP":        {"speed": 0.0, "jump": 1.0, "duration": 0.8},
	"HIGH_JUMP":   {"speed": 0.0, "jump": 1.3, "duration": 1.0},
	"SUPER_JUMP":  {"speed": 0.0, "jump": 1.6, "duration": 1.2},
	
	# Directional Jumps (Right)
	"HOP_RIGHT":        {"speed": 0.5, "jump": 0.5, "duration": 0.5},
	"JUMP_RIGHT":       {"speed": 1.0, "jump": 1.0, "duration": 1.0},
	"LONG_JUMP_RIGHT":  {"speed": 1.5, "jump": 1.0, "duration": 1.2},
	"HIGH_JUMP_RIGHT":  {"speed": 0.5, "jump": 1.4, "duration": 1.2},
	"DASH_JUMP_RIGHT":  {"speed": 2.0, "jump": 1.2, "duration": 1.5},
	
	# Directional Jumps (Left)
	"HOP_LEFT":        {"speed": -0.5, "jump": 0.5, "duration": 0.5},
	"JUMP_LEFT":       {"speed": -1.0, "jump": 1.0, "duration": 1.0},
	"LONG_JUMP_LEFT":  {"speed": -1.5, "jump": 1.0, "duration": 1.2},
	"HIGH_JUMP_LEFT":  {"speed": -0.5, "jump": 1.4, "duration": 1.2},
	"DASH_JUMP_LEFT":  {"speed": -2.0, "jump": 1.2, "duration": 1.5},
	
	# Timing / Idle
	"WAIT_SHORT":  {"speed": 0.0, "jump": 0.0, "duration": 0.5},
	"WAIT_LONG":   {"speed": 0.0, "jump": 0.0, "duration": 2.0},
	"LOOK_AROUND": {"speed": 0.0, "jump": 0.0, "duration": 1.5, "special": "LOOK_AROUND"},
	
	# Technical (Physics)
	"SLIDE_RIGHT":      {"speed": 1.8, "jump": 0.0, "duration": 0.8, "special": "SLIDE"},
	"SLIDE_LEFT":       {"speed": -1.8, "jump": 0.0, "duration": 0.8, "special": "SLIDE"},
	"WALL_KICK_RIGHT":  {"speed": 1.2, "jump": 1.2, "duration": 0.6, "special": "WALL_KICK"},
	"WALL_KICK_LEFT":   {"speed": -1.2, "jump": 1.2, "duration": 0.6, "special": "WALL_KICK"},
	"AIR_BRAKE":        {"speed": 0.0, "jump": 0.0, "duration": 0.5, "special": "AIR_BRAKE"},
	
	# Failure / Noise
	"STUMBLE":          {"speed": 0.2, "jump": 0.0, "duration": 1.5, "special": "STUMBLE"},
	"OVERSHOOT_RIGHT":  {"speed": 1.5, "jump": 0.0, "duration": 2.5}, # Runs too long
	"OVERSHOOT_LEFT":   {"speed": -1.5, "jump": 0.0, "duration": 2.5},
	
	# Interaction (Mock)
	"INTERACT":         {"speed": 0.0, "jump": 0.0, "duration": 1.0, "special": "INTERACT"},
	"PUSH":             {"speed": 0.2, "jump": 0.0, "duration": 2.0, "special": "PUSH"},
	
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
	
	_enter_preview_mode()
	_setup_minimap()

func _on_retry_requested(use_pro: bool):
	GameManager.is_pro_mode = use_pro
	_reset_game()

func _reset_game():
	print("[GameController] Resetting Game...")
	turn_count = 0
	
	# Regenerate Level for fresh experience
	var level_gen = $LevelGenerator
	start_pos = level_gen.generate_level($LevelRoot)
	
	player.position = start_pos
	player.velocity = Vector2.ZERO
	player.execute_action(command_db["STOP"])
	
	# Reset Camera Smoothing immediately to prevent lag
	camera.position_smoothing_enabled = false
	await get_tree().process_frame
	camera.position_smoothing_enabled = true # Re-enable if used, or leave as configured
	camera.align() # Force update
	
	_enter_preview_mode()

func _setup_minimap():
	var minimap_viewport = $CanvasLayer/MinimapContainer/SubViewportContainer/SubViewport
	if minimap_viewport:
		minimap_viewport.world_2d = get_viewport().world_2d
		var mini_cam = minimap_viewport.get_node("Camera2D")
		if mini_cam:
			var remote = RemoteTransform2D.new()
			remote.remote_path = mini_cam.get_path()
			player.add_child(remote)

func _enter_preview_mode():
	current_state = State.PREVIEW
	prompt_ui.visible = false
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(0.5, 0.5), 1.0)
	await get_tree().create_timer(2.0).timeout
	_enter_input_mode()

func _enter_input_mode():
	current_state = State.INPUT
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(1.5, 1.5), 0.5)
	prompt_ui.visible = true

func _on_prompt_submitted(prompt: String, key: String):
	if current_state != State.INPUT: return
	user_prompt = prompt
	GameManager.api_key = key
	_enter_action_mode()

func _enter_action_mode():
	current_state = State.ACTION
	prompt_ui.visible = false
	_request_ai_action()

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
	
	# Parse Sequence
	response = response.replace("\n", "").replace(".", "").strip_edges()
	var commands = response.split(",")
	
	for raw_cmd in commands:
		var cmd_str = raw_cmd.strip_edges().to_upper()
		
		# Allow simple fuzzy matching if needed, but strict is better for now
		# If key not found, try to find substring
		var action_data = command_db.get("STOP") # Default
		
		if command_db.has(cmd_str):
			action_data = command_db[cmd_str]
		else:
			# Fallback: check if includes "RIGHT"
			if "RIGHT" in cmd_str: action_data = command_db["WALK_RIGHT"]
			elif "LEFT" in cmd_str: action_data = command_db["WALK_LEFT"]
			elif "JUMP" in cmd_str: action_data = command_db["JUMP"]
		
		action_data["cmd"] = cmd_str # Pass name for debugging
		print("[GameController] Executing: ", cmd_str)
		
		player.execute_action(action_data)
		
		var duration = action_data.get("duration", 1.0)
		await get_tree().create_timer(duration).timeout
	
	_finish_action()

func _finish_action():
	print("[GameController] Action Finished.")
	player.execute_action(command_db["STOP"])
	_enter_input_mode()

func game_over(reason: String):
	player.execute_action(command_db["STOP"])
	retry_dialog.show_fail_dialog()
