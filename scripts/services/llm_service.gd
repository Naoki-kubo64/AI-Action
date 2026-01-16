extends Node

# 将来的にはHTTPRequestノードなどを使って非同期通信する
# 今回はモックとしてprint出力とシグナル発火を行う

signal response_received(response_text: String)
signal error_occured(error_msg: String)

func request_action(profile: AICharacterProfile, is_pro_mode: bool, user_input: String) -> void:
	print("[LLMService] Requesting action for: ", profile.character_name, " | ProMode: ", is_pro_mode)
	
	var model_name = _get_model_name(profile.provider_id, is_pro_mode)
	print("[LLMService] Using Model: ", model_name)
	
	var system_prompt = profile.get_combined_system_prompt(is_pro_mode)
	print("[LLMService] System Prompt: \n", system_prompt)
	print("[LLMService] User Input: ", user_input)
	
	# 非同期通信のシミュレーション
	await get_tree().create_timer(1.0).timeout
	
	var mock_response = _generate_mock_response(profile, is_pro_mode, user_input)
	response_received.emit(mock_response)

func _get_model_name(provider: String, is_pro: bool) -> String:
	match provider:
		"openai":
			return "gpt-4" if is_pro else "gpt-3.5-turbo"
		"google":
			return "gemini-ultra" if is_pro else "gemini-flash"
		"anthropic":
			return "claude-3-opus" if is_pro else "claude-3-haiku"
		_:
			return "unknown-model"

func _generate_mock_response(profile: AICharacterProfile, is_pro: bool, input: String) -> String:
	var prefix = ""
	match profile.provider_id:
		"openai": prefix = "[Logic/O]"
		"google": prefix = "[Creative/G]"
		"anthropic": prefix = "[Safety/C]"
	
	var mode_str = " (Pro Thinking...)" if is_pro else " (Quick Answer)"
	return prefix + mode_str + " solution for: " + input
