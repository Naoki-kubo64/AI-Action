extends Node

var current_world: int = 1
var current_stage: int = 1
const MAX_STAGES_PER_WORLD = 4 # Example, user said 1-4 is enemies, maybe 1-7 limit?
# User said "1-4 enemies", "1-7 last". Let's assume 7.
const FINAL_STAGE = 7

func get_current_level_path() -> String:
	return "res://scenes/levels/Level_%d-%d.tscn" % [current_world, current_stage]

func next_level():
	current_stage += 1
	if current_stage > FINAL_STAGE:
		current_stage = 1
		current_world += 1
	
	load_current_level()

func load_level(world: int, stage: int):
	current_world = world
	current_stage = stage
	load_current_level()

func load_current_level():
	# In our new architecture, we want to mimic the "Start Game" flow exactly.
	# Direct calls to _reset_game() might leave physics state dirty.
	# So we force a Scene Reload if we are already in-game.
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.name == "GameScene":
		# Reload to ensure fresh _ready() and physics state
		get_tree().reload_current_scene()
	else:
		# We are in menu, go to game
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func reload_current_level():
	load_current_level()
