extends AnimatableBody2D

@export var move_offset: Vector2 = Vector2(200, 0)
@export var duration: float = 3.0
@export var wait_time: float = 1.0

@onready var visual = $ColorRect

func _ready():
	_start_tween()

func _start_tween():
	var tween = create_tween().set_loops()
	
	# Move To
	tween.tween_property(self, "position", position + move_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)
	
	# Move Back
	tween.tween_property(self, "position", position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)
