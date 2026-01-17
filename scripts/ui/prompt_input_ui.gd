extends Control

signal game_start_requested(prompt: String, api_key: String)

@onready var prompt_edit = $Panel/VBoxContainer/PromptEdit
@onready var api_key_edit = $Panel/VBoxContainer/ApiKeyEdit

func _ready():
	_load_api_key()

func _load_api_key():
	if FileAccess.file_exists("res://secret_api_key.txt"):
		var file = FileAccess.open("res://secret_api_key.txt", FileAccess.READ)
		var key = file.get_as_text().strip_edges()
		api_key_edit.text = key
		print("Loaded API Key from file.")

func _on_start_button_pressed():
	var prompt = prompt_edit.text
	var api_key = api_key_edit.text
	
	if prompt.strip_edges() == "":
		prompt = "Move carefully and reach the goal." # Default
	
	# visible = false # Controlled by GameController
	game_start_requested.emit(prompt, api_key)
