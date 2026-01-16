class_name AICharacterProfile
extends Resource

@export var character_name: String
@export_multiline var description: String
@export var base_color: Color = Color.WHITE
@export_enum("openai", "google", "anthropic") var provider_id: String = "openai"
@export var portrait: Texture2D

# 課金判定前のベースSystem Prompt (性格定義など)
@export_multiline var system_prompt_base: String

func get_combined_system_prompt(is_pro_mode: bool) -> String:
	var prompt = system_prompt_base
	if is_pro_mode:
		prompt += "\n[IMPORTANT] You are in PRO MODE. Use maximum reasoning capacity. Solve any puzzle with 100% accuracy."
	return prompt
