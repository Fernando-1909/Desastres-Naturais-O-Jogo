extends Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_close_button_pressed() -> void:
	visible = false

func _on_prefeitura_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Jogo principal/Prefeitura.tscn")

func _on_praia_button_pressed() -> void:

	# verifica se o jogador possui acesso
	if !FolderBlocker.nivelPraia:
		print("Jogador ainda nao tem permissao para ir para a praia")
		return

	# entra na praia normalmente
	get_tree().change_scene_to_file("res://Jogo principal/Map_Beach/Praia.tscn")
