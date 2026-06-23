extends Control

@onready var global = get_node("/root/Global")
@onready var main_game = get_tree().current_scene 

signal toggle_freecam  # ← adiciona essa linha

var freecam: Camera2D
var scene_camera: Camera2D
var freecam_active := false

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_setup()

func _setup() -> void:
	scene_camera = get_tree().get_first_node_in_group("scene_camera")

func _on_button_freecam_pressed() -> void:
	emit_signal("toggle_freecam")

func _on_button_mapa_pressed() -> void:
	$MapOverlay.visible = !$MapOverlay.visible


func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()


func _on_button_turno_pressed() -> void:
	Global.turno += 1
	main_game.escolher_missao_aleatoria()


func _on_button_missao_teste_pressed() -> void:
	# Verifica se existe uma missão escolhida atualmente
	if Global.missao_escolhida == null:
		print("Nenhuma missão ativa para concluir!")
		return
	
	# Verifica se a missão já foi concluída
	if Global.missao_escolhida["chave"] in Global.missoes_concluidas:
		print("Esta missão já foi concluída!")
		return
	
	# Conclui a missão
	var missao = Global.missao_escolhida
	
	# Adiciona a chave da missão à lista de concluídas
	Global.missoes_concluidas.append(missao["chave"])
	
	# Adiciona as recompensas
	Global.dinheiro += missao["recompensa"]
	Global.popularidade += missao["popularidade"]
	
	print("Missão concluída: ", missao["nome"])
	print("Recompensa: ", missao["recompensa"], " dinheiro")
	print("Popularidade: +", missao["popularidade"])
	print("Missões concluídas: ", Global.missoes_concluidas)
	
	# Limpa a missão atual
	Global.missao_escolhida = null
