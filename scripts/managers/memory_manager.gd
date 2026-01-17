extends Node

var memory_data: Dictionary = {
	"player_personality": "",
	"learned_skills": [],
	"relationship_level": 0,
	"last_feedback": ""
}

const MEMORY_FILE = "user://ai_memory.json"

func _ready():
	load_memory()

func load_memory():
	if FileAccess.file_exists(MEMORY_FILE):
		var file = FileAccess.open(MEMORY_FILE, FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json:
			memory_data = json
			print("[MemoryManager] Loaded: ", memory_data)
		else:
			print("[MemoryManager] Failed to parse memory file.")
	else:
		print("[MemoryManager] No memory file found. Starting fresh.")

func save_memory(new_data: Dictionary = {}):
	if not new_data.is_empty():
		memory_data = new_data
	
	var file = FileAccess.open(MEMORY_FILE, FileAccess.WRITE)
	var json_string = JSON.stringify(memory_data, "\t")
	file.store_string(json_string)
	print("[MemoryManager] Saved: ", json_string)

func reset_memory():
	memory_data = {
		"player_personality": "",
		"learned_skills": [],
		"relationship_level": 0,
		"last_feedback": ""
	}
	
	if FileAccess.file_exists(MEMORY_FILE):
		DirAccess.remove_absolute(MEMORY_FILE)
	
	print("[MemoryManager] Memory Wiped.")

func get_memory_string() -> String:
	return JSON.stringify(memory_data)
