extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	print("Iniciar jogo apertado")
	get_tree().change_scene_to_file("res://Jogo principal/Main_game.tscn")


func _on_creditos_pressed() -> void:
	print("Creditos apertado")


func _on_exit_pressed() -> void:
	print("Sair apertado")
	get_tree().quit()
