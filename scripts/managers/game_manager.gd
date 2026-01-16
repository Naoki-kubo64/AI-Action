extends Node

var current_character: AICharacterProfile
var is_pro_mode: bool = false

func start_game(character: AICharacterProfile, pro_mode: bool):
	current_character = character
	is_pro_mode = pro_mode
	print("Game Started with ", character.character_name, ". Pro Mode: ", is_pro_mode)
	# 実際のシーン遷移処理
	# get_tree().change_scene_to_file("res://scenes/game.tscn") 
	# (シーンファイルはまだないのでログのみ)
