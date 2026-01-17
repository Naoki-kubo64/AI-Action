extends Control

signal retry_requested(use_pro_mode: bool)

func show_fail_dialog(title: String = "MISSION FAILED"):
	visible = true
	$Panel/VBoxContainer/Label.text = title

func _on_retry_standard_pressed():
	retry_requested.emit(false)
	visible = false

func _on_retry_pro_pressed():
	# 課金処理呼び出し
	print("Processing Payment for Pro Retry...")
	retry_requested.emit(true)
	visible = false

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
