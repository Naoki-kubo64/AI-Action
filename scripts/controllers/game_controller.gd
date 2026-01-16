extends Node
class_name GameController

@onready var player: PlayerController = $Player
@onready var retry_dialog = $CanvasLayer/RetryDialog

var turn_count: int = 0
var max_turns: int = 10
var game_active: bool = true

func _ready():
	# GameManagerから初期設定読み込み
	if GameManager.current_character == null:
		print("[GameController] No character selected, using fallback.")
		# フォールバック処理 (テスト用)
	else:
		var profile = GameManager.current_character
		print("[GameController] Initialized with ", profile.character_name)
		# プレイヤーの色変更など
		player.modulate = profile.base_color
	
	LLMService.response_received.connect(_on_llm_response)
	start_turn()

func start_turn():
	if not game_active: return
	turn_count += 1
	if turn_count > max_turns:
		game_over("Turn Limit Reached")
		return

	print("--- Turn ", turn_count, " ---")
	request_ai_action()

func request_ai_action():
	if GameManager.current_character == null: return
	
	# 現在の状況をテキスト化 (簡易)
	var context_text = "Turn: " + str(turn_count) + ". You are at " + str(player.position)
	LLMService.request_action(
		GameManager.current_character, 
		GameManager.is_pro_mode, 
		context_text
	)

func _on_llm_response(response: String):
	print("[GameController] AI decided: ", response)
	
	# 本来はレスポンスを解析して行動決定するが、プロトタイプではランダムまたは固定移動
	# モッドレスポンス文字列に "Right" などが含まれているかを判定するロジックを想定
	
	# デモ用に右または下に移動させる
	var move_dir = Vector2.RIGHT
	if "Creative" in response: # Type G uses creative path (Down)
		move_dir = Vector2.DOWN
	elif "Safety" in response: # Type C moves carefully (Right)
		move_dir = Vector2.RIGHT
	else:
		move_dir = Vector2.RIGHT
		
	player.move_relative(move_dir)
	
	# 次のターンへ
	await get_tree().create_timer(1.5).timeout
	start_turn()

func game_over(reason: String):
	game_active = false
	print("Game Over: ", reason)
	retry_dialog.show_fail_dialog()

func _on_retry_requested(use_pro: bool):
	print("Retrying... ProMode: ", use_pro)
	GameManager.is_pro_mode = use_pro
	get_tree().reload_current_scene()
