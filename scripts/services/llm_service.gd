extends Node

signal response_received(response_text: String)
signal error_occured(error_msg: String)

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
	
	var model = "gemini-2.0-flash"
	var url = "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + api_key
	
	print("[LLMService] Request URL: ", url.replace(api_key, "HIDDEN_KEY"))
	var headers = ["Content-Type: application/json"]
	
	var full_prompt = system_prompt + "\n\n" + input + "\n\nIMPORTANT: Output a list of commands separated by commas. Use nuances based on user intent.\n"
	full_prompt += "COMMAND LIST:\n"
	full_prompt += "- Move: CREEP_RIGHT/LEFT, STEP_RIGHT/LEFT, WALK_RIGHT/LEFT, RUN_RIGHT/LEFT, SPRINT_RIGHT/LEFT, BACK_STEP\n"
	full_prompt += "- Jump: HOP, JUMP, HIGH_JUMP, SUPER_JUMP\n"
	full_prompt += "- Directional Jump: HOP_RIGHT/LEFT, JUMP_RIGHT/LEFT, LONG_JUMP_RIGHT/LEFT, DASH_JUMP_RIGHT/LEFT\n"
	full_prompt += "- Technical: SLIDE_RIGHT/LEFT (Low), WALL_KICK_RIGHT/LEFT, AIR_BRAKE (Stop mid-air)\n"
	full_prompt += "- Timing: WAIT_SHORT (0.5s), WAIT_LONG (2s), LOOK_AROUND\n"
	full_prompt += "- Failures (Use for low level): STUMBLE, OVERSHOOT_RIGHT/LEFT\n"
	full_prompt += "- Interact: INTERACT, PUSH\n"
	full_prompt += "- Emote: DANCE, PANIC\n"
	full_prompt += "Example: 'RUN_RIGHT, LONG_JUMP_RIGHT, WALK_RIGHT'\n"
	full_prompt += "Output ONLY the command list."
	
	print("[LLMService] Sending Prompt:\n", full_prompt)
	
	var body = JSON.stringify({
		"contents": [{
			"parts": [{"text": full_prompt}]
		}]
	})
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("[LLMService] HTTP Request Error: ", error)
		response_received.emit("STOP")
		http_request.queue_free()

func _on_gemini_request_completed(result, response_code, headers, body, http_request):
	var response_text = "STOP"
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.has("candidates") and json["candidates"].size() > 0:
			var content = json["candidates"][0]["content"]["parts"][0]["text"]
			response_text = content.strip_edges()
			print("[LLMService] API Response: ", response_text)
		else:
			print("[LLMService] Invalid JSON response: ", body.get_string_from_utf8())
	else:
		print("[LLMService] Server Error: ", response_code)
		# Print body for debugging 404s or 400s
		print("[LLMService] Error Body: ", body.get_string_from_utf8())
	
	response_received.emit(response_text)
	http_request.queue_free()

func _mock_request(profile, is_pro, input):
	print("[LLMService] Mocking response...")
	await get_tree().create_timer(0.5).timeout
	response_received.emit("RIGHT")

func _get_model_name(provider: String, is_pro: bool) -> String:
	return "gemini-2.0-flash"
