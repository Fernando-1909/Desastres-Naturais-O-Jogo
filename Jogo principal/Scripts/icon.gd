extends Sprite2D

func _physics_process(delta: float) -> void:
	print(position)
	if Input.is_action_pressed("ui_right"):
		position.x += 10
	if Input.is_action_pressed("ui_left"):
		position.x -= 10
