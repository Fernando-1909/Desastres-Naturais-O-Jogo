extends Control

@onready var global = get_node("/root/Global")
@onready var main_game = get_tree().current_scene 

signal toggle_freecam  # ← adiciona essa linha

var freecam: Camera2D
var scene_camera: Camera2D
var freecam_active := false
var botoes_bloqueaveis = []

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_setup()
	
	Global.renda = 1 #valor temporario pra debug
	
	# Guarda referência dos botões que devem ser bloqueados
	botoes_bloqueaveis = [
		$ButtonTurno,
		$ButtonMapa,
		$BotaoTeste,
		$ButtonPausa
	]

func atualizar_botoes():
	var desabilitar = Global.jogo_pausado
	for botao in botoes_bloqueaveis:
		if botao:
			botao.disabled = desabilitar

func _setup() -> void:
	scene_camera = get_tree().get_first_node_in_group("scene_camera")

func _on_button_freecam_pressed() -> void:
	emit_signal("toggle_freecam")

func _on_button_mapa_pressed() -> void:
	$MapOverlay.visible = !$MapOverlay.visible


func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()


func _on_button_turno_pressed() -> void:
	# Verifica se o jogo está pausado
	if Global.jogo_pausado:
		print("Jogo pausado! Não é possível avançar o turno.")
		return
	
	Global.turno += 1
	print("Turno: ", Global.turno)
	
	# Sistema de renda
	if Global.renda > 0:
		var range_min = 0
		var range_max = 0
		
		# Define o range baseado na popularidade
		if Global.popularidade < 0:
			range_min = 80
			range_max = 99
		elif Global.popularidade >= 0 and Global.popularidade <= 24:
			range_min = 100
			range_max = 120
		elif Global.popularidade >= 25 and Global.popularidade <= 49:
			range_min = 121
			range_max = 140
		elif Global.popularidade >= 50 and Global.popularidade <= 74:
			range_min = 141
			range_max = 160
		elif Global.popularidade >= 75 and Global.popularidade <= 99:
			range_min = 161
			range_max = 180
		elif Global.popularidade >= 100:
			range_min = 181
			range_max = 200
		
		# Calcula a renda total
		var renda_total = 0
		for i in range(Global.renda):
			var valor_aleatorio = randi() % (range_max - range_min + 1) + range_min
			renda_total += valor_aleatorio
		
		Global.dinheiro += renda_total
		print("Renda coletada: ", renda_total, " dinheiro (", Global.renda, " construções de renda)")
		print("Range usado: ", range_min, "-", range_max, " (Popularidade: ", Global.popularidade, ")")
	
	# SESSÃO DE MISSÕES
	# Se tem missão ativa, conta os turnos
	if Global.missao_escolhida != null:
		Global.missao_atual_turnos += 1
		
		# Se passou 2 turnos sem completar, volta para lista
		if Global.missao_atual_turnos >= 2:
			var chave = Global.missao_escolhida["chave"]
			print("Missão '", Global.missao_escolhida["nome"], "' não foi completada em 2 turnos. Voltando para lista...")
			Global.missao_escolhida = null
			Global.missao_atual_turnos = 0
	
	main_game.escolher_missao_aleatoria()


func _on_aceitar_missao_pressed() -> void:
	if Global.missao_escolhida == null:
		print("Nenhuma missão ativa!")
		return
	
	var missao = Global.missao_escolhida
	
	# TODO: Consumir recursos necessários para completar a missão
	
	# Adiciona a chave da missão à lista de concluídas
	Global.missoes_concluidas.append(missao["chave"])
	
	# Adiciona as recompensas
	Global.dinheiro += missao["recompensa"]
	Global.popularidade += missao["popularidade"]
	
	# Remove do contador de turnos sem missão
	if missao["chave"] in Global.turnos_sem_missao:
		Global.turnos_sem_missao.erase(missao["chave"])
	
	print("Missão aceita e concluída: ", missao["nome"])
	print("Recompensa: ", missao["recompensa"], " dinheiro")
	print("Popularidade: +", missao["popularidade"])
	
	# Esconde o container de missão
	$MissaoContainer.visible = false
	
	# Despausa o jogo
	Global.jogo_pausado = false
	
	# Limpa a missão atual e reseta contadores
	Global.missao_escolhida = null
	Global.missao_atual_turnos = 0
	Global.chance_missao = 30


func _on_recusar_missao_pressed() -> void:
	if Global.missao_escolhida == null:
		print("Nenhuma missão ativa!")
		return
	
	var missao = Global.missao_escolhida
	
	# Perde a popularidade que ganharia
	Global.popularidade -= missao["popularidade"]
	
	print("Missão recusada: ", missao["nome"])
	print("Popularidade perdida: -", missao["popularidade"])
	print("Popularidade atual: ", Global.popularidade)
	
	# Esconde o container de missão
	$MissaoContainer.visible = false
	
	# Despausa o jogo
	Global.jogo_pausado = false
	
	# Limpa a missão atual
	Global.missao_escolhida = null
	Global.missao_atual_turnos = 0
