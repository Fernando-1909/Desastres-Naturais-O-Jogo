class_name PontoResgate
extends Area2D

enum Estado { AGUARDANDO, EM_ANDAMENTO, CONCLUIDO }

var estado_atual: Estado = Estado.AGUARDANDO
var turnos_restantes: int = 2
var vitimas_para_resgatar: int = 0
var pos_tile: Vector2i = Vector2i.ZERO
var main_game_ref: Node = null

@onready var label_status: RichTextLabel = $LabelStatus
@onready var painel_aviso: Control = $CanvasLayer/PainelAviso
@onready var label_aviso_texto: RichTextLabel = $CanvasLayer/PainelAviso/MarginContainer/VBoxContainer/LabelMensagem
@onready var btn_fechar_aviso: Button = $CanvasLayer/PainelAviso/ButtonFechar


func _ready() -> void:
	input_pickable = true
	add_to_group("pontos_resgate")
	
	if painel_aviso:
		painel_aviso.visible = false
		
	if btn_fechar_aviso and not btn_fechar_aviso.pressed.is_connected(_ocultar_aviso):
		btn_fechar_aviso.pressed.connect(_ocultar_aviso)


func inicializar(p_pos_tile: Vector2i, pos_global: Vector2, p_vitimas: int, main_ref: Node) -> void:
	pos_tile = p_pos_tile
	global_position = pos_global
	vitimas_para_resgatar = p_vitimas
	main_game_ref = main_ref
	_atualizar_interface()


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_ao_clicar_no_ponto()


func _ao_clicar_no_ponto() -> void:
	if estado_atual == Estado.EM_ANDAMENTO:
		_mostrar_aviso("Resgate em andamento!\n\nUma equipe está no local. Restam " + str(turnos_restantes) + " turno(s) para finalizar.")
		return
		
	if estado_atual == Estado.AGUARDANDO:
		_tentar_iniciar_resgate()


func _tentar_iniciar_resgate() -> void:
	if not main_game_ref:
		_mostrar_aviso("Erro de referência no jogo principal!")
		return

	# Recalcula dinamicamente os recursos das construções antes da checagem
	if main_game_ref.has_method("_recalcular_recursos_resgate"):
		main_game_ref._recalcular_recursos_resgate()

	# 1. Checa Corpo de Bombeiros / Equipes de Resgate
	var equipes_totais: int = 0
	if main_game_ref.has_method("obter_equipes_bombeiro_totais"):
		equipes_totais = main_game_ref.obter_equipes_bombeiro_totais()
	elif main_game_ref.has_method("tem_estacao_bombeiros"):
		equipes_totais = 1 if main_game_ref.tem_estacao_bombeiros() else 0

	if equipes_totais <= 0:
		_mostrar_aviso("Sem Equipes de Resgate!\n\nConstrua um Corpo de Bombeiros para realizar operações de resgate.")
		return

	# 2. Checa se existe Abrigo construído no mapa
	var possui_abrigo: bool = false
	if main_game_ref.has_method("tem_abrigo_construido"):
		possui_abrigo = main_game_ref.tem_abrigo_construido()

	if not possui_abrigo:
		_mostrar_aviso("Nenhum abrigo disponível!\n\nConstrua um Abrigo para onde levar as vítimas antes de iniciar a operação.")
		return

	# 3. Checa Vagas disponíveis no abrigo
	var vagas_livres: int = 0
	if main_game_ref.has_method("obter_vagas_abrigos_disponiveis"):
		vagas_livres = main_game_ref.obter_vagas_abrigos_disponiveis()

	if vagas_livres < vitimas_para_resgatar:
		_mostrar_aviso("Vagas insuficientes nos abrigos!\n\nVagas livres: " + str(vagas_livres) + "\nNecessárias: " + str(vitimas_para_resgatar) + ".\n\nConstrua mais abrigos ou aprimore os existentes.")
		return

	# 4. Tenta alocar uma equipe de bombeiros disponível
	if main_game_ref.has_method("alocar_equipe_bombeiro"):
		if main_game_ref.alocar_equipe_bombeiro():
			estado_atual = Estado.EM_ANDAMENTO
			turnos_restantes = 2
			_atualizar_interface()
			_mostrar_aviso("Operação Iniciada!\n\nEquipe de bombeiros enviada. O resgate levará " + str(turnos_restantes) + " turnos.")
		else:
			_mostrar_aviso("Todas as equipes de bombeiros estão ocupadas!\n\nAguarde até que finalizem outros resgates.")


func _mostrar_aviso(mensagem: String) -> void:
	if painel_aviso and label_aviso_texto:
		label_aviso_texto.text = mensagem
		painel_aviso.visible = true


func _ocultar_aviso() -> void:
	if painel_aviso:
		painel_aviso.visible = false


func avancar_turno() -> void:
	if estado_atual == Estado.EM_ANDAMENTO:
		turnos_restantes -= 1
		_atualizar_interface()
		if turnos_restantes <= 0:
			_finalizar_resgate()


func _finalizar_resgate() -> void:
	estado_atual = Estado.CONCLUIDO
	if main_game_ref:
		if main_game_ref.has_method("liberar_equipe_bombeiro"):
			main_game_ref.liberar_equipe_bombeiro()
			
		if main_game_ref.has_method("abrigar_pessoas"):
			main_game_ref.abrigar_pessoas(vitimas_para_resgatar)
			
	queue_free()


func _atualizar_interface() -> void:
	if label_status:
		match estado_atual:
			Estado.AGUARDANDO:
				label_status.text = "[center]SOS (" + str(vitimas_para_resgatar) + ")[/center]"
			Estado.EM_ANDAMENTO:
				label_status.text = "[center]Resgatando...\n" + str(turnos_restantes) + "t[/center]"
