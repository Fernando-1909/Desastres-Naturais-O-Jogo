extends Control

@onready var global = get_node("/root/Global")
@onready var main_game = get_tree().current_scene

signal toggle_freecam

var freecam: Camera2D
var scene_camera: Camera2D
var freecam_active := false
var botoes_bloqueaveis = []

# Quantas pessoas de população equivalem a 1 "unidade" de renda por turno.
const POPULACAO_POR_UNIDADE_RENDA := 10


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_setup()

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


# ============================================================
# AVANÇAR TURNO
# ============================================================

func _on_pular_turno_pressed() -> void:
	# Verifica se o jogo está pausado
	if Global.jogo_pausado:
		print("Jogo pausado! Não é possível avançar o turno.")
		return
	
	Global.turno += 1
	print("Turno: ", Global.turno)
	
	# Se o jogador passou do último turno jogável,
	# vai direto para Game Over.
	if main_game and "turno_final" in main_game and Global.turno > main_game.turno_final:
		print(
			"[FIM DE JOGO] Turno ",
			Global.turno,
			" > turno final (",
			main_game.turno_final,
			"). Indo para Game Over."
		)
		
		get_tree().change_scene_to_file(
			"res://Jogo principal/game_over.tscn"
		)
		
		return
	
	# ========================================================
	# SISTEMA DE RENDA
	# ========================================================
	
	Global.renda = int(
		Global.populacao / POPULACAO_POR_UNIDADE_RENDA
	)
	
	if Global.renda > 0:
		var faixa := _obter_range_por_popularidade()
		
		var renda_total = 0
		
		for i in range(Global.renda):
			var valor_aleatorio = (
				randi() % (faixa.y - faixa.x + 1)
				+ faixa.x
			)
			
			renda_total += valor_aleatorio
		
		Global.dinheiro += renda_total
		
		print(
			"Renda coletada: ",
			renda_total,
			" dinheiro (população: ",
			Global.populacao,
			" | ",
			Global.renda,
			" unidades de renda)"
		)
		
		print(
			"Range usado: ",
			faixa.x,
			"-",
			faixa.y,
			" (Popularidade: ",
			Global.popularidade,
			")"
		)
	
	# Avança qualquer desastre em curso
	main_game.avancar_turno_desastres()
	
	# Processa o sistema de missões
	main_game.processar_missao_no_turno()


# ============================================================
# RENDA POR POPULARIDADE
# ============================================================

func _obter_range_por_popularidade() -> Vector2i:
	if Global.popularidade < 0:
		return Vector2i(80, 99)
	elif Global.popularidade <= 24:
		return Vector2i(100, 120)
	elif Global.popularidade <= 49:
		return Vector2i(121, 140)
	elif Global.popularidade <= 74:
		return Vector2i(141, 160)
	elif Global.popularidade <= 99:
		return Vector2i(161, 180)
	else:
		return Vector2i(181, 200)


# ============================================================
# LABELS
# ============================================================

@onready var dinheiro_label: RichTextLabel = \
	$PainelExibição/Exibição/Dinheiro/Numero

@onready var turno_label: RichTextLabel = \
	$PainelTurnos/Turnos/Turno/Numero

@onready var popularidade_label: RichTextLabel = \
	$PainelExibição/Exibição/Popularidade/Numero

@onready var missao_info_label: RichTextLabel = \
	$MissaoContainer/MarginContainer/VBoxContainer/MissaoInfo

@onready var missao_recompensa_label: RichTextLabel = \
	$MissaoContainer/MarginContainer/VBoxContainer/MissaoRecompensa

@onready var populacao_label: RichTextLabel = \
	$PainelExibição/Exibição/População/Numero

@onready var desabrigados_label: RichTextLabel = \
	$PainelExibição/Exibição/Desabrigados/Numero


# Procura o botão em qualquer profundidade da árvore.
@onready var button_missao_check: TextureButton = \
	find_child("ButtonMissaoCheck", true, false)


func _process(_delta: float) -> void:
	_update_dinheiro_label()
	_update_turno_label()
	_update_popularidade_label()
	_update_missao_titulo()
	_update_missao_info_label()
	_update_missao_recompensa_label()
	_update_button_missao_check()
	_update_missao_botoes()
	_update_populacao_label()
	_update_desabrigados_label()


# ============================================================
# LABELS GERAIS
# ============================================================

func _update_dinheiro_label() -> void:
	if dinheiro_label == null:
		return
	
	dinheiro_label.text = "%s" % str(Global.dinheiro)


func _update_desabrigados_label() -> void:
	if desabrigados_label == null:
		return
	
	desabrigados_label.text = "%s" % str(Global.pessoas_desabrigadas)


func _update_populacao_label() -> void:
	if populacao_label == null:
		return
	
	populacao_label.text = "%s" % str(Global.populacao)


func _update_turno_label() -> void:
	if turno_label == null:
		return
	
	turno_label.text = "%s" % str(Global.turno)


func _update_popularidade_label() -> void:
	if popularidade_label == null:
		return
	
	popularidade_label.text = str(Global.popularidade) + "%"


# ============================================================
# TÍTULO DA MISSÃO
# ============================================================

func _update_missao_titulo() -> void:
	var titulo = get_node_or_null(
		"MissaoContainer/MarginContainer/VBoxContainer/HBoxContainer2/Missaolabel"
	)
	
	if titulo == null:
		return
	
	# Missão concluída tem prioridade.
	if _missao_recem_concluida() != null:
		titulo.text = "Missão concluída!"
	
	elif Global.missao_escolhida != null:
		titulo.text = "Missão!"
	
	else:
		titulo.text = ""


# ============================================================
# INFORMAÇÕES DA MISSÃO
# ============================================================

func _update_missao_info_label() -> void:
	if missao_info_label == null:
		return
	
	var missao_concluida = _missao_recem_concluida()
	
	# Se acabou de concluir uma missão,
	# mostra a missão concluída.
	if missao_concluida != null:
		missao_info_label.text = (
			"Missão concluída: "
			+ str(missao_concluida.nome)
		)
	
	elif Global.missao_escolhida != null:
		missao_info_label.text = str(
			Global.missao_escolhida.info
		)
	
	else:
		missao_info_label.text = ""


# ============================================================
# RECOMPENSA DA MISSÃO
# ============================================================

func _update_missao_recompensa_label() -> void:
	if missao_recompensa_label == null:
		return
	
	var missao_concluida = _missao_recem_concluida()
	
	# ========================================================
	# MISSÃO CONCLUÍDA
	# ========================================================
	
	if missao_concluida != null:
		var m = missao_concluida
		
		var texto = (
			"Popularidade: +"
			+ str(m.popularidade)
		)
		
		if "bonus_populacao" in m and m.bonus_populacao > 0:
			texto += (
				"\nPopulação: +"
				+ str(m.bonus_populacao)
			)
		
		missao_recompensa_label.text = texto
	
	# ========================================================
	# MISSÃO ATIVA
	# ========================================================
	
	elif Global.missao_escolhida != null:
		var m = Global.missao_escolhida
		
		var texto = (
			"Custo: "
			+ str(m.custo)
			+ " dinheiro"
			+ "\nPopularidade: +"
			+ str(m.popularidade)
		)
		
		if "bonus_populacao" in m and m.bonus_populacao > 0:
			texto += (
				"\nPopulação: +"
				+ str(m.bonus_populacao)
			)
		
		missao_recompensa_label.text = texto
	
	else:
		missao_recompensa_label.text = ""


# ============================================================
# VERIFICA SE EXISTE UMA MISSÃO RECÉM-CONCLUÍDA
# ============================================================

func _missao_recem_concluida() -> MissionData:
	if main_game == null:
		return null
	
	# Verifica se o main_game possui a variável.
	if not ("_missao_check_aberta" in main_game):
		return null
	
	# A confirmação precisa estar aberta.
	if not main_game._missao_check_aberta:
		return null
	
	# Verifica se existe uma missão concluída armazenada.
	if not ("ultima_missao_concluida" in main_game):
		return null
	
	if main_game.ultima_missao_concluida == null:
		return null
	
	return main_game.ultima_missao_concluida


# ============================================================
# BOTÃO DE VERIFICAÇÃO
# ============================================================

func _update_button_missao_check() -> void:
	if button_missao_check == null:
		return
	
	# Durante missão concluída, o botão de checagem
	# não deve aparecer.
	if _missao_recem_concluida() != null:
		button_missao_check.visible = false
		return
	
	button_missao_check.visible = (
		Global.missao_escolhida != null
		and Global.missao_aceita
	)


# ============================================================
# BOTÕES ACEITAR / RECUSAR / FECHAR
# ============================================================

func _update_missao_botoes() -> void:
	var check_aberta := false
	
	if main_game != null:
		if "_missao_check_aberta" in main_game:
			check_aberta = main_game._missao_check_aberta
	
	
	# Estrutura REAL da sua UI.tscn:
	#
	# MissaoContainer
	# └── MarginContainer
	#     └── VBoxContainer
	#         ├── HBoxContainer
	#         └── HBoxContainer2
	
	var hbox_decisao = get_node_or_null(
		"MissaoContainer/MarginContainer/VBoxContainer/HBoxContainer"
	)
	
	var hbox_fechar = get_node_or_null(
		"MissaoContainer/MarginContainer/VBoxContainer/HBoxContainer2"
	)
	
	
	# ========================================================
	# ACEITAR / RECUSAR
	# ========================================================
	
	if hbox_decisao:
		# Se a confirmação de conclusão estiver aberta,
		# NUNCA mostra Aceitar/Recusar.
		if check_aberta:
			hbox_decisao.visible = false
		
		else:
			hbox_decisao.visible = (
				Global.missao_escolhida != null
				and not Global.missao_aceita
			)
	
	
	# ========================================================
	# FECHAR
	# ========================================================
	
	if hbox_fechar:
		# Só aparece enquanto a confirmação está aberta.
		hbox_fechar.visible = check_aberta


# ============================================================
# AÇÕES DA MISSÃO
# ============================================================

func _on_button_missao_concluir_pressed() -> void:
	main_game.concluir_missao()


func _on_texture_button_pressed() -> void:
	main_game.abrir_checagem_missao()

func _on_missao_close_pressed() -> void:
	main_game.fechar_checagem_missao()


# ============================================================
# PAUSA
# ============================================================

func _on_pausa_pressed() -> void:
	var evento := InputEventAction.new()
	
	evento.action = "ui_cancel"
	evento.pressed = true
	
	Input.parse_input_event(evento)


# ============================================================
# ACEITAR / RECUSAR
# ============================================================

func _on_aceitar_pressed() -> void:
	main_game.aceitar_missao()


func _on_recusar_pressed() -> void:
	main_game.recusar_missao()
