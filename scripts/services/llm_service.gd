extends Node

signal response_received(response_text: String)
signal error_occured(error_msg: String)

func request_action(profile: AICharacterProfile, is_pro_mode: bool, user_input: String) -> void:
	# API Key check (GameController should pass the API Key, but for now we might need to access it differently or pass it in context)
	# NOTE: For this prototype, we'll assume the API KEY is passed OR we look it up from PromptUI/GameManager storage.
	# But actually, request_action signature in previous step didn't have api_key.
	# We should update GameManager to store api_key and pass it, or update signature.
	# Let's assume GameManager stores the active API KEY.
	
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
	
	var system_prompt = profile.get_combined_system_prompt(is_pro)
	var full_prompt = system_prompt + "\n\n" + input + "\n\nIMPORTANT: Output ONLY a single command from [RIGHT, LEFT, JUMP, JUMP_RIGHT, STOP]. No other text."
	
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
	
	response_received.emit(response_text)
	http_request.queue_free()

func _mock_request(profile, is_pro, input):
	print("[LLMService] Mocking response...")
	await get_tree().create_timer(0.5).timeout
	response_received.emit("RIGHT")

func _get_model_name(provider: String, is_pro: bool) -> String:
	match provider:
		"openai": return "gpt-4" if is_pro else "gpt-3.5-turbo"
		"google": return "gemini-1.5-pro" if is_pro else "gemini-1.5-flash"
		"anthropic": return "claude-3-opus" if is_pro else "claude-3-haiku"
		_: return "unknown"
