extends CharacterBody2D

var speed: int = 400
var move_direction: Vector2 = Vector2(0,0)
var joystick = null
var camera: Camera2D

func _ready() -> void:
	camera = $Camera2D
	call_deferred("_find_nodes")

func _find_nodes() -> void:
	joystick = get_tree().get_first_node_in_group("virtual_joystick")
	print("joystick: ", joystick)  # confirma que achou

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
