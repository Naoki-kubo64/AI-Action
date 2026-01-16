extends Control

signal game_start_requested(prompt: String, api_key: String)

@onready var prompt_edit = $Panel/VBoxContainer/PromptEdit
@onready var api_key_edit = $Panel/VBoxContainer/ApiKeyEdit

func _on_start_button_pressed():
	var prompt = prompt_edit.text
	var api_key = api_key_edit.text
	
	if prompt.strip_edges() == "":
		prompt = "Move carefully and reach the goal." # Default
	
	visible = false
	game_start_requested.emit(prompt, api_key)
