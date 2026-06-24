extends Node2D

# CÂMERA
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud

var freecam_enabled = false

func _ready() -> void:
	freecam_camera.enabled = true


# MAPA
func _on_button_mapa_pressed() -> void:
	$CanvasLayer/MapOverlay.visible = true

# TESTES
func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()
	print("praia foi liberada!")

func _on_button_dinheiro_plus_pressed() -> void:
	Global.dinheiro += 100
	Global.popularidade += 50

func _on_button_dinheiro_minus_pressed() -> void:
	Global.dinheiro -= 100
	Global.popularidade -= 25


#⁠abrir pop-up de melhorias
@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")


func _on_button_close_menu_pressed() -> void:
	$CanvasLayer/BuildingHUD.visible = false
	for construcao in Global.construcoes:
		Global.construcoes[construcao] = false

func _on_prefeitura_button_pressed() -> void:
	print("prefeitura clicada")
	Global.construcoes["prefeitura"] = true
	$CanvasLayer/BuildingHUD.visible = true


func _on_bombeiros_button_pressed() -> void:
	print("bombeiros clicado")
	Global.construcoes["bombeiros"] = true
	$CanvasLayer/BuildingHUD.visible = true

func escolher_missao_aleatoria():
	# Verifica se o turno é par e diferente de 0
	if Global.turno > 0 and Global.turno % 2 == 0:
		# Filtra apenas missões NÃO concluídas
		var missoes_disponiveis = {}
		for chave in Global.missoes.keys():
			if chave not in Global.missoes_concluidas:
				missoes_disponiveis[chave] = Global.missoes[chave]
		
		# Verifica se ainda há missões disponíveis
		if missoes_disponiveis.is_empty():
			print("Todas as missões foram concluídas!")
			Global.missao_escolhida = null
			return null
		
		# Obtém as chaves das missões disponíveis
		var chaves_missoes = missoes_disponiveis.keys()
		
		# Escolhe um índice aleatório
		var indice_aleatorio = randi() % chaves_missoes.size()
		
		# Obtém a chave aleatória
		var chave_escolhida = chaves_missoes[indice_aleatorio]
		
		# Armazena a missão escolhida
		Global.missao_escolhida = Global.missoes[chave_escolhida]
		Global.missao_escolhida["chave"] = chave_escolhida
		
		print("Turno: ", Global.turno)
		print("Missão escolhida: ", Global.missao_escolhida["nome"])
		print("Recompensa: ", Global.missao_escolhida["recompensa"], " dinheiro")
		print("Popularidade: +", Global.missao_escolhida["popularidade"])
		
		return Global.missao_escolhida
	else:
		print("Turno ", Global.turno, " é ímpar ou zero - não é possível escolher missão")
		return null
