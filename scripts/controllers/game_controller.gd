extends Node
class_name GameController

@onready var player: PlayerController = $Player
@onready var retry_dialog = $CanvasLayer/RetryDialog
@onready var prompt_ui = $CanvasLayer/PromptInputUI

var turn_count: int = 0
var max_turns: int = 30 # Increased for platformer
var game_active: bool = false
var user_prompt: String = ""

func _ready():
	# Initial setup
	if GameManager.current_character:
		print("[GameController] Initialized with ", GameManager.current_character.character_name)
		player.modulate = GameManager.current_character.base_color
	
	# Wait for Prompt UI
	prompt_ui.visible = true
	prompt_ui.game_start_requested.connect(_on_game_start_requested)
	LLMService.response_received.connect(_on_llm_response)

func _on_game_start_requested(prompt: String, api_key: String):
	user_prompt = prompt
	# Set API Key if provided (mock for now, or actual service update)
	print("Game Starting with Prompt: ", prompt)
	
	# Generate Level
	var level_gen = $LevelGenerator
	var start_pos = level_gen.generate_level($LevelRoot)
	player.position = start_pos
	
	game_active = true
	start_turn()

func start_turn():
	if not game_active: return
	turn_count += 1
	if turn_count > max_turns:
		game_over("Turn Limit Reached")
		return

	print("--- Turn ", turn_count, " ---")
	request_ai_action()

func request_ai_action():
	if GameManager.current_character == null: return
	
	# Platformer Context
	# Raycast or logic to detect surroundings
	var context = _get_platformer_context()
	var full_input = "User Instruction: " + user_prompt + "\nContext: " + context
	
	LLMService.request_action(
		GameManager.current_character, 
		GameManager.is_pro_mode, 
		full_input
	)

func _get_platformer_context() -> String:
	# Simple mock context generator
	# In real game, use RayCast2D to detect walls/gaps properly
	var pos_x = int(player.position.x / 64)
	return "Player at X=" + str(pos_x) + ". Ground: " + str(player.is_on_floor())

func _on_llm_response(response: String):
	print("[GameController] AI Raw Response: ", response)
	
	# Parse response (Simple keyword matching for prototype)
	# Expected: [JUMP], [RIGHT], [STOP]
	var cmd = "STOP"
	if "JUMP" in response or "jump" in response.to_lower():
		if "RIGHT" in response or "forward" in response.to_lower():
			cmd = "JUMP_RIGHT"
		else:
			cmd = "JUMP"
	elif "RIGHT" in response or "forward" in response.to_lower():
		cmd = "RIGHT"
	elif "LEFT" in response:
		cmd = "LEFT"
		
	print("[GameController] Executing: ", cmd)
	player.set_command(cmd)
	
	# Platformer is real-time, but here we update AI decision periodically
	await get_tree().create_timer(1.0).timeout
	start_turn()

func game_over(reason: String):
	game_active = false
	player.set_command("STOP")
	print("Game Over: ", reason)
	retry_dialog.show_fail_dialog()
