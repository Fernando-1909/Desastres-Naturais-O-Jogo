extends Node2D

@onready var pathFollow = $Path2D/PathFollow2D

func _process(delta: float) -> void:
	print(pathFollow.progress_ratio)
	
func _input(event):
	if event.is_action_pressed("mouse_wheel_up"):
		pathFollow.progress_ratio -= 0.05
	if event.is_action_pressed("mouse_wheel_down"):
		pathFollow.progress_ratio += 0.05
