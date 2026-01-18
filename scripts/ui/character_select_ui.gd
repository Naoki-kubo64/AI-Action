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
	if selected_index == -1: return
	GameManager.start_game(characters[selected_index], true)

func _on_reset_memory_pressed():
	$ConfirmationDialog.popup_centered()

func _on_reset_confirmed():
	MemoryManager.reset_memory()

func _on_debug_start_pressed():
	if selected_index == -1: return
	
	var w_spin = $CenterContainer/VBoxContainer/DebugPanel/HBox/WorldSpin
	var s_spin = $CenterContainer/VBoxContainer/DebugPanel/HBox/StageSpin
	
	# Workaround: SpinBox value might not update until enter/focus loss
	# Force validation by releasing focus if active
	if w_spin.get_line_edit().has_focus():
		w_spin.get_line_edit().release_focus()
	if s_spin.get_line_edit().has_focus():
		s_spin.get_line_edit().release_focus()
	
	# Now value should be correct and clamped
	var w_val = int(w_spin.value)
	var s_val = int(s_spin.value)
	
	print("Debug Start: W-", w_val, " S-", s_val)
	
	# Set Level
	LevelManager.current_world = w_val
	LevelManager.current_stage = s_val
	
	# Start
	GameManager.start_game(characters[selected_index], false)
