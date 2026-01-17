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

func _ready():
	# Initial setup
	if GameManager.current_character:
		print("[GameController] Initialized with ", GameManager.current_character.character_name)
		player.modulate = GameManager.current_character.base_color
	
	# Connect signals
	prompt_ui.game_start_requested.connect(_on_prompt_submitted)
	LLMService.response_received.connect(_on_llm_response)
	
	# Generate Level
	var level_gen = $LevelGenerator
	var start_pos = level_gen.generate_level($LevelRoot)
	player.position = start_pos
	
	# Start Sequence
	_enter_preview_mode()
	
	# Setup Minimap
	_setup_minimap()

func _setup_minimap():
	var minimap_viewport = $CanvasLayer/MinimapContainer/SubViewportContainer/SubViewport
	if minimap_viewport:
		minimap_viewport.world_2d = get_viewport().world_2d
		# Find Minimap Camera
		var mini_cam = minimap_viewport.get_node("Camera2D")
		if mini_cam:
			# Sync position logic could be added in _process
			var remote = RemoteTransform2D.new()
			remote.remote_path = mini_cam.get_path()
			player.add_child(remote)

func _enter_preview_mode():
	current_state = State.PREVIEW
	print("[GameController] State: PREVIEW")
	prompt_ui.visible = false
	
	# Zoom out to show level
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(0.5, 0.5), 1.0)
	
	# Wait for 2 seconds then go to input
	await get_tree().create_timer(2.0).timeout
	_enter_input_mode()

func _enter_input_mode():
	current_state = State.INPUT
	print("[GameController] State: INPUT")
	
	# Zoom in to player
	var tween = create_tween()
	tween.tween_property(camera, "zoom", Vector2(1.5, 1.5), 0.5)
	
	prompt_ui.visible = true
	# Optional: prompt_ui.grab_focus() if implemented

func _on_prompt_submitted(prompt: String, key: String):
	if current_state != State.INPUT: return
	
	user_prompt = prompt
	GameManager.api_key = key
	
	_enter_action_mode()

func _enter_action_mode():
	current_state = State.ACTION
	print("[GameController] State: ACTION")
	prompt_ui.visible = false
	
	# Request AI Action ONE TIME
	_request_ai_action()

func _request_ai_action():
	if GameManager.current_character == null: 
		print("[GameController] No character, skipping.")
		_finish_action()
		return
	
	# Platformer Context
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
	return "Player at X-Grid=" + str(pos_x) + ". Is On Floor: " + str(player.is_on_floor())

func _on_llm_response(response: String):
	if current_state != State.ACTION: return
	
	print("[GameController] AI Raw Response: ", response)
	
	# Clean response
	response = response.replace("\n", "").replace(".", "").strip_edges()
	
	# Split by commas for sequence
	var commands = response.split(",")
	
	for raw_cmd in commands:
		var cmd = _parse_command(raw_cmd)
		print("[GameController] Executing Step: ", cmd)
		
		# Reset jump trigger for new command step
		player.set_command(cmd)
		player.jump_triggered = false 
		
		# Duration per step: 0.5s (Matches 128px/s * 0.5s = 64px = 1 block)
		# If user said "Walk, Jump", we walk for 0.5s, then jump.
		await get_tree().create_timer(0.5).timeout
	
	_finish_action()

func _parse_command(raw_cmd: String) -> String:
	var lower_res = raw_cmd.to_lower()
	var cmd = "STOP"
	if "jump_right" in lower_res or ("jump" in lower_res and "right" in lower_res):
		cmd = "JUMP_RIGHT"
	elif "jump_left" in lower_res:
		cmd = "JUMP_LEFT"
	elif "jump" in lower_res:
		cmd = "JUMP"
	elif "left" in lower_res:
		cmd = "LEFT"
	elif "right" in lower_res:
		cmd = "RIGHT"
	return cmd

func _finish_action():
	print("[GameController] Action Finished. Stopping.")
	player.set_command("STOP")
	
	# Check Win/Loss conditions here if needed
	
	# Return to Input
	_enter_input_mode()

func game_over(reason: String):
	player.set_command("STOP")
	print("Game Over: ", reason)
	retry_dialog.show_fail_dialog()
