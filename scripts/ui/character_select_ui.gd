extends Control

# UI要素への参照 (実際のシーンに合わせてパスは調整が必要ですが、ここでは想定で書きます)
# @onready var name_label = $InfoPanel/NameLabel
# @onready var description_label = $InfoPanel/DescriptionLabel
# @onready var start_std_btn = $ActionPanel/StartStandardButton
# @onready var start_pro_btn = $ActionPanel/StartProButton

# エディタで割り当てる配列
@export var characters: Array[AICharacterProfile]

var selected_index: int = 0

func _ready():
	_update_ui()

# ボタンから呼ばれる想定
func _on_char_button_pressed(index: int):
	selected_index = index
	_update_ui()

func _update_ui():
	if characters.is_empty():
		return
	var char_data = characters[selected_index]
	
	print("Selected: ", char_data.character_name)
	# name_label.text = char_data.character_name
	# description_label.text = char_data.description
	
	# 色を変えるなどの演出
	# $CharacterImage.modulate = char_data.base_color

func _on_start_standard_pressed():
	if characters.is_empty(): return
	GameManager.start_game(characters[selected_index], false)

func _on_start_pro_pressed():
	if characters.is_empty(): return
	# ここで課金処理を入れる想定
	print("Processing Payment for Pro Mode...")
	GameManager.start_game(characters[selected_index], true)
