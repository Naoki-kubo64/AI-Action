extends Node

signal response_received(response_text: String)
signal error_occured(error_msg: String)

var chat_history: Array = []
const MAX_HISTORY: int = 20 # 10 turns (User + Model pairs)

func request_action(profile: AICharacterProfile, is_pro_mode: bool, user_input: String) -> void:
	var api_key = GameManager.api_key
	if api_key == "":
		print("[LLMService] No API Key. Using Mock.")
		_mock_request(profile, is_pro_mode, user_input)
		return
		
	if profile.provider_id == "google":
		_call_gemini_api(api_key, profile, is_pro_mode, user_input)
	else:
		print("[LLMService] Provider not implemented yet: ", profile.provider_id)
		_mock_request(profile, is_pro_mode, user_input)

func _call_gemini_api(api_key: String, profile: AICharacterProfile, is_pro: bool, input: String):
	print("[LLMService] Calling Gemini API...")
	
	# Create HTTP Request node dynamically
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_gemini_request_completed.bind(http_request))

	# 1. Initialize History if empty (add System Prompt)
	if chat_history.is_empty():
		var system_prompt = profile.get_combined_system_prompt(is_pro)
		
		# INJECT MEMORY
		var memory_json = MemoryManager.get_memory_string()
		system_prompt += "\n\n[LONG-TERM MEMORY DATA]:\n" + memory_json + "\n"
		system_prompt += "Act based on this past memory. If 'relationship_level' is high, be more friendly. If 'learned_skills' has entries, try to use them.\n"
		
		var prompt_instruction = "IMPORTANT: You are controlling a game character. \n"
		prompt_instruction += "Output a JSON Array of action objects. \n"
		prompt_instruction += "Format: [{\"action\": \"COMMAND\", \"duration\": 0.5, \"strength\": 1.0}]\n"
		prompt_instruction += "- action: The command string (e.g. WALK_RIGHT)\n"
		prompt_instruction += "- duration: Time in seconds (optional, override default)\n"
		prompt_instruction += "- strength: 0.0 to 1.0 (or higher). Multiplier for speed/jump force.\n"
		prompt_instruction += "COMMAND LIST:\n"
		prompt_instruction += "- Move: CREEP_RIGHT/LEFT, STEP_RIGHT/LEFT, WALK_RIGHT/LEFT, RUN_RIGHT/LEFT, SPRINT_RIGHT/LEFT, BACK_STEP\n"
		prompt_instruction += "- Jump (Vertical Only): HOP, JUMP, HIGH_JUMP, SUPER_JUMP. (WARNING: These stop horizontal movement!)\n"
		prompt_instruction += "- Directional Jump: HOP_RIGHT/LEFT, JUMP_RIGHT/LEFT, LONG_JUMP_RIGHT/LEFT, DASH_JUMP_RIGHT/LEFT, SUPER_JUMP_RIGHT/LEFT\n"
		prompt_instruction += "- Technical: SLIDE_RIGHT/LEFT, WALL_KICK_RIGHT/LEFT, AIR_BRAKE\n"
		prompt_instruction += "- Timing: WAIT_SHORT, WAIT_LONG, LOOK_AROUND\n"
		prompt_instruction += "- Failures: STUMBLE, OVERSHOOT_RIGHT/LEFT\n"
		prompt_instruction += "- Interact: INTERACT, PUSH\n"
		prompt_instruction += "- Emote: DANCE, PANIC\n"
		prompt_instruction += "Example Response: [{\"action\": \"RUN_RIGHT\", \"duration\": 1.0, \"strength\": 0.8}, {\"action\": \"SUPER_JUMP_RIGHT\", \"strength\": 1.0}]\n"
		prompt_instruction += "Do NOT output markdown code blocks. Output raw JSON only."
		
		chat_history.append({
			"role": "user",
			"parts": [{"text": system_prompt + "\n\n" + prompt_instruction}]
		})
		# Fake model ack to start conversation properly? No, Gemini handles system context in first user msg usually fine.
	
	# 2. Append User Input
	chat_history.append({
		"role": "user",
		"parts": [{"text": input}]
	})
	
	# 3. Prune History if too long (Keep index 0 as System Prompt)
	while chat_history.size() > MAX_HISTORY + 1:
		# Remove oldest AFTER system prompt (Index 1)
		chat_history.remove_at(1)
	
	# 4. Prepare Request
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + api_key
	print("[LLMService] Request URL: ", url.replace(api_key, "HIDDEN_KEY"))
	var headers = ["Content-Type: application/json"]
	
	var body = JSON.stringify({
		"contents": chat_history
	})
	
	print("[LLMService] Sending Request. History Size: ", chat_history.size())
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("[LLMService] HTTP Request Error: ", error)
		response_received.emit("[]")
		http_request.queue_free()

func _on_gemini_request_completed(result, response_code, headers, body, http_request):
	var response_string = body.get_string_from_utf8()
	var json = JSON.parse_string(response_string)
	
	if json and json.has("candidates") and json["candidates"].size() > 0:
		var content = json["candidates"][0]["content"]
		var text = content["parts"][0]["text"]
		print("[LLMService] Response: ", text)
		
		# Append Model Response to History
		chat_history.append({
			"role": "model",
			"parts": [{"text": text}]
		})
		
		response_received.emit(text)
	else:
		print("[LLMService] Error Parsing Response: ", response_string)
		response_received.emit("[]")
		# The original code had a duplicate print here, removing it.
		# print("[LLMService] Invalid JSON response: ", body.get_string_from_utf8())
	
	if response_code != 200: # This check was outside the else block in the original, keeping it separate.
		print("[LLMService] Server Error: ", response_code)
		# Print body for debugging 404s or 400s
		print("[LLMService] Error Body: ", body.get_string_from_utf8())
	
	
	http_request.queue_free()

func request_summarization():
	print("[LLMService] Requesting Session Summary...")
	
	# Create a new, separate HTTP request to avoid conflict with game loop
	var summarization_request = HTTPRequest.new()
	add_child(summarization_request)
	summarization_request.request_completed.connect(_on_summary_completed.bind(summarization_request))
	
	var api_key = GameManager.api_key
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" + api_key
	
	# Construct Summary Prompt
	var current_memory = MemoryManager.get_memory_string()
	var session_log = JSON.stringify(chat_history)
	var prompt = "Here is the current Long-Term Memory: " + current_memory + "\n"
	prompt += "Here is the Session Chat Log: " + session_log + "\n"
	prompt += "TASK: Analyze the session. Update the memory JSON based on the user's feedback, new skills learned, and relationship changes.\n"
	prompt += "Output ONLY the updated JSON object. Keep the same structure: {player_personality, learned_skills, relationship_level, last_feedback}."
	
	var body = JSON.stringify({
		"contents": [{
			"parts": [{"text": prompt}]
		}]
	})
	
	summarization_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)

func _on_summary_completed(result, response_code, headers, body, request_node):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("candidates"):
			var content = json["candidates"][0]["content"]["parts"][0]["text"]
			# Clean markdown
			content = content.replace("```json", "").replace("```", "").strip_edges()
			var new_memory = JSON.parse_string(content)
			if new_memory:
				MemoryManager.save_memory(new_memory)
				print("[LLMService] Memory Updated: ", new_memory)
			else:
				print("[LLMService] Failed to parse summary JSON: ", content)
	else:
		print("[LLMService] Summary Request Failed: ", response_code)
	
	request_node.queue_free()

func _mock_request(profile, is_pro, input):
	print("[LLMService] Mocking response...")
	await get_tree().create_timer(0.5).timeout
	response_received.emit("RIGHT")

func _get_model_name(provider: String, is_pro: bool) -> String:
	return "gemini-2.0-flash"
