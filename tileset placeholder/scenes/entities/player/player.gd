extends CharacterBody2D

var speed: int = 400
var move_direction: Vector2 = Vector2(0,0)

func _physics_process(_delta: float) -> void:
	movement_loop()
	
func movement_loop() -> void:
	var keyboard_direction := Vector2(
		int(Input.is_action_pressed("Right")) - int(Input.is_action_pressed("Left")),
		int(Input.is_action_pressed("Down")) - int(Input.is_action_pressed("Up"))
	)
	if joystick:
		move_direction = keyboard_direction + joystick.output
	else:
		move_direction = keyboard_direction
	var motion = move_direction.normalized() * speed
	set_velocity(motion)
	move_and_slide()

func mostrar_posicao() -> void:
	print("X: %d | Y: %d" % [global_position.x, global_position.y])

@onready var camera = $Camera2D
@onready var joystick = get_node("/root/MainGame/CanvasLayer/Hud/VirtualJoystick")
