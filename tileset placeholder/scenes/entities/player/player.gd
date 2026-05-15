extends CharacterBody2D

var speed: int = 400
var move_direction: Vector2 = Vector2(0,0)

func _physics_process(_delta: float) -> void:
	movement_loop()
	
func movement_loop() -> void:
	move_direction.x = int(Input.is_action_pressed("Right")) - int(Input.is_action_pressed("Left"))
	move_direction.y = (int(Input.is_action_pressed("Down")) - int(Input.is_action_pressed("Up"))) / float(2)
	var motion: Vector2 = move_direction.normalized() * speed
	set_velocity(motion)
	move_and_slide()
