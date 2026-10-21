extends Control

@onready var global = get_node("/root/Global")
@onready var main_game = get_tree().current_scene
@onready var avisos: RichTextLabel = $Avisos
@onready var botao_turno: TextureButton = $PainelTurnos/Turnos/PularTurno
@onready var menufinancas = $TelaFinancas
@export var tempo_ocioso: float = 15.0


# Referências ao Sistema do Gabinete de Dicas
@onready var botao_gabinete: TextureButton = get_node_or_null("BotaoGabinete")
@onready var badge_novidade: ColorRect = get_node_or_null("BotaoGabinete/BadgeNovidade")
@onready var painel_aba_dicas: PanelContainer = get_node_or_null("PainelAbaDicas")
@onready var lista_topicos_vbox: VBoxContainer = get_node_or_null("PainelAbaDicas/MargemAba/VBoxDicas/ScrollAba/ListaTopicosVBox")

var gerenciador_dicas: GerenciadorDicas = null

signal toggle_freecam

var _tween_atencao_gabinete: Tween
var _tween_aba_dicas: Tween
var freecam: Camera2D
var scene_camera: Camera2D
var freecam_active := false
var botoes_bloqueaveis = []
var turno_idle_timer: Timer
var _tween_atencao: Tween

# Quantas pessoas de população equivalem a 1 "unidade" de renda por turno.
const POPULACAO_POR_UNIDADE_RENDA := 10


func _ready() -> void:
	
	#Botao Animado
	turno_idle_timer = Timer.new()
	turno_idle_timer.name = "TurnoIdleTimer"
	turno_idle_timer.one_shot = true
	turno_idle_timer.wait_time = tempo_ocioso
	turno_idle_timer.timeout.connect(_chamar_atencao_turno)
	add_child(turno_idle_timer)
	turno_idle_timer.start()
	botao_turno.resized.connect(_atualizar_pivot)
	_atualizar_pivot()
	
	# Instancia e conecta o gerenciador de dicas
	gerenciador_dicas = GerenciadorDicas.new()
	add_child(gerenciador_dicas)
	gerenciador_dicas.lista_dicas_atualizada.connect(_atualizar_interface_dicas)
	gerenciador_dicas.nova_dica_disponivel.connect(_on_nova_dica_recebida)

	await get_tree().create_timer(0.5).timeout
	_setup()

	# Guarda referência dos botões que devem ser bloqueados
	botoes_bloqueaveis = [
		$ButtonTurno,
		$ButtonMapa,
		$BotaoTeste,
		$ButtonPausa
	]


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		_parar_atencao_turno()
		turno_idle_timer.start()

#Botao Animado
func _atualizar_pivot() -> void:
	botao_turno.pivot_offset = botao_turno.size / 2

#Botao Animado
func _chamar_atencao_turno() -> void:
	_parar_atencao_turno()
	_tween_atencao = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_tween_atencao.tween_property(botao_turno, "modulate", Color(1.4, 1.4, 1.4), 0.6)
	_tween_atencao.parallel().tween_property(botao_turno, "scale", Vector2(1.06, 1.06), 0.6)
	_tween_atencao.tween_property(botao_turno, "modulate", Color.WHITE, 0.6)
	_tween_atencao.parallel().tween_property(botao_turno, "scale", Vector2.ONE, 0.6)

#Botao Animado
func _parar_atencao_turno() -> void:
	if _tween_atencao:
		_tween_atencao.kill()
	botao_turno.modulate = Color.WHITE
	botao_turno.scale = Vector2.ONE

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

	# ========================================================
	# CHECAGEM DE TURNO OCIOSO
	# ========================================================
	if main_game and main_game.has_method("pode_passar_turno"):
		if not main_game.pode_passar_turno():
			_mostrar_aviso_turno_ocioso()
			return

	Global.turno += 1
	print("Turno: ", Global.turno)
	
	# Se o jogador passou do último turno jogável, vai direto para Game Over.
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
	# SISTEMA DE RENDA E MANUTENÇÃO (GANHOS - CUSTOS)
	# ========================================================
	
	if main_game and main_game.has_method("calcular_renda_com_multiplicadores_de_zona"):
		Global.renda = main_game.calcular_renda_com_multiplicadores_de_zona()
	else:
		Global.renda = int(Global.populacao / POPULACAO_POR_UNIDADE_RENDA)
	
	var renda_total = 0
	
	if Global.renda > 0:
		var faixa := _obter_range_por_popularidade()
		
		for i in range(Global.renda):
			var valor_aleatorio = (
				randi() % (faixa.y - faixa.x + 1)
				+ faixa.x
			)
			
			renda_total += valor_aleatorio

	# Durante uma enchente, a renda das construções é reduzida em 90%.
	# Fora de um desastre ativo, a renda permanece exatamente como antes.
	if main_game and "_enchente_ativa" in main_game and main_game._enchente_ativa != null:
		renda_total = int(round(renda_total * 0.10))

	# 1. Calcula o custo total das construções ativas puxando do .tres no main_game
	var custo_total = 0
	if main_game and main_game.has_method("calcular_custo_manutencao_construcoes"):
		custo_total = main_game.calcular_custo_manutencao_construcoes()

	# 2. Calcula o saldo líquido (Ganhos - Custos) e atribui ao saldo Global
	var saldo_turno = renda_total - custo_total
	Global.dinheiro += saldo_turno

	# 3. Confirmação no Output
	print("--- BALANÇO FINANCEIRO DO TURNO ---")
	print("Ganhos (Renda): ", renda_total)
	print("Custos das Construções (.tres): ", custo_total)
	print("Cálculo: Ganhos (", renda_total, ") - Custo (", custo_total, ") = ", saldo_turno)
	print("Dinheiro Total Atual: ", Global.dinheiro)
	print("-----------------------------------")
	
	# Processa o progresso de construções em andamento
	if main_game and main_game.has_method("processar_construcoes_no_turno"):
		main_game.processar_construcoes_no_turno()

	# Avança qualquer desastre em curso
	main_game.avancar_turno_desastres()
	
	# Processa o sistema de missões
	main_game.processar_missao_no_turno()

	# Reavalia as condições da cidade no gerenciador de dicas
	if gerenciador_dicas:
		gerenciador_dicas.avaliar_condicoes_cidade(main_game)

	# Atualiza o estado do turno ocioso
	if main_game and main_game.has_method("finalizar_checada_turno_ocioso"):
		main_game.finalizar_checada_turno_ocioso()


# ============================================================
# AVISO DE TURNO OCIOSO
# ============================================================

func _mostrar_aviso_turno_ocioso() -> void:
	# Feedback visual sutil quando o jogador tenta passar o turno
	# sem ter progredido a cidade.
	if avisos == null:
		return

	var tween := create_tween()

	avisos.bbcode_enabled = true
	avisos.text = "[center][font_size=27][color=#FFD54F]Você deve progredir a cidade antes de passar o turno.[/color][/font_size][/center]"
	avisos.visible = true
	avisos.modulate.a = 0.0

	tween.tween_property(avisos, "modulate:a", 1.0, 0.35)
	tween.tween_interval(1.2)
	tween.tween_property(avisos, "modulate:a", 0.0, 0.45)
	tween.tween_callback(func():
		avisos.visible = false
	)


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
	_update_visibilidade_dicas()


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


## Atualiza a visibilidade do botão e aba lateral do Gabinete com base na configuração global
func _update_visibilidade_dicas() -> void:
	var ativado = Global.dicas_habilitadas if ("dicas_habilitadas" in Global and Global.dicas_habilitadas != null) else true
	if botao_gabinete:
		botao_gabinete.visible = ativado
	if not ativado and painel_aba_dicas and painel_aba_dicas.visible:
		painel_aba_dicas.visible = false

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


func _on_button_financas_pressed() -> void:
	menufinancas.visible = !menufinancas.visible



# ============================================================
# EVENTOS DO SISTEMA DE DICAS DO GABINETE
# ============================================================

## Quando uma nova dica é liberada, ativa a badge e faz o botão do Gabinete piscar
func _on_nova_dica_recebida(_id_dica: String) -> void:
	var ativado = Global.dicas_habilitadas if ("dicas_habilitadas" in Global and Global.dicas_habilitadas != null) else true
	if not ativado:
		return
	if badge_novidade:
		badge_novidade.visible = true
	_chamar_atencao_gabinete()


## Animação que faz o botão do Gabinete piscar suavemente para chamar atenção
func _chamar_atencao_gabinete() -> void:
	_parar_atencao_gabinete()
	if botao_gabinete == null:
		return

	_tween_atencao_gabinete = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_tween_atencao_gabinete.tween_property(botao_gabinete, "modulate", Color(1.3, 1.3, 0.8), 0.5)
	_tween_atencao_gabinete.parallel().tween_property(botao_gabinete, "scale", Vector2(1.08, 1.08), 0.5)
	_tween_atencao_gabinete.tween_property(botao_gabinete, "modulate", Color.WHITE, 0.5)
	_tween_atencao_gabinete.parallel().tween_property(botao_gabinete, "scale", Vector2.ONE, 0.5)


func _parar_atencao_gabinete() -> void:
	if _tween_atencao_gabinete:
		_tween_atencao_gabinete.kill()
	if botao_gabinete:
		botao_gabinete.modulate = Color.WHITE
		botao_gabinete.scale = Vector2.ONE


## Abre e fecha a aba lateral de conselhos deslizando de/para a borda esquerda (efeito gaveta)
func _on_botao_gabinete_pressed() -> void:
	var ativado = Global.dicas_habilitadas if ("dicas_habilitadas" in Global and Global.dicas_habilitadas != null) else true
	if not ativado or painel_aba_dicas == null:
		return

	if _tween_aba_dicas and _tween_aba_dicas.is_running():
		_tween_aba_dicas.kill()

	_tween_aba_dicas = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)

	if painel_aba_dicas.visible and painel_aba_dicas.modulate.a > 0.1:
		_tween_aba_dicas.set_ease(Tween.EASE_IN)
		_tween_aba_dicas.tween_property(painel_aba_dicas, "position:x", -260.0, 0.25)
		_tween_aba_dicas.tween_property(painel_aba_dicas, "modulate:a", 0.0, 0.2)
		_tween_aba_dicas.chain().tween_callback(func():
			painel_aba_dicas.visible = false
		)
	else:
		_atualizar_interface_dicas()
		painel_aba_dicas.visible = true
		painel_aba_dicas.position.x = -260.0
		painel_aba_dicas.modulate.a = 0.0

		_tween_aba_dicas.set_ease(Tween.EASE_OUT)
		_tween_aba_dicas.tween_property(painel_aba_dicas, "position:x", 0.0, 0.3)
		_tween_aba_dicas.tween_property(painel_aba_dicas, "modulate:a", 1.0, 0.25)


## Gera a lista de botões com as dicas novas NO TOPO, indicativo visual e nome do autor
func _atualizar_interface_dicas() -> void:
	var tem_nao_lida = gerenciador_dicas and gerenciador_dicas.tem_dica_nao_lida()
	
	if badge_novidade:
		badge_novidade.visible = tem_nao_lida
		
	if not tem_nao_lida:
		_parar_atencao_gabinete()

	if lista_topicos_vbox == null or gerenciador_dicas == null:
		return

	for child in lista_topicos_vbox.get_children():
		child.queue_free()

	# Dicas vêm ordenadas com as NÃO LIDAS no topo
	var lista = gerenciador_dicas.obter_dicas_filtradas()
	for dica in lista:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 38)
		btn.focus_mode = Control.FOCUS_NONE

		# Formatação do Autor
		var autor_nome = "Secretária" if dica.get("autor", "") == "SECRETARIA" else "Tesoureiro"
		
		# Indicativo de dica nova vs dica antiga/lida
		var prefixo = "🔴 [NOVA] " if dica["nao_lida"] else "✓ "
		var titulo = tr(dica["titulo_chave"])

		btn.text = prefixo + autor_nome + ": " + titulo
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var no_dialogo = dica["no_dialogo"]
		var id_dica = dica["id"]
		btn.pressed.connect(_on_topico_dica_clicado.bind(id_dica, no_dialogo))

		lista_topicos_vbox.add_child(btn)


## Marca a dica como lida e dispara o diálogo na tela com a Secretária ou Tesoureiro
func _on_topico_dica_clicado(id_dica: String, no_dialogo: String) -> void:
	if gerenciador_dicas:
		gerenciador_dicas.marcar_como_lida(id_dica)

	_atualizar_interface_dicas()

	if main_game and "dialogue_manager" in main_game and main_game.dialogue_manager:
		if main_game.dialogue_manager.has_method("iniciar_dialogo_dica"):
			main_game.dialogue_manager.iniciar_dialogo_dica(no_dialogo)
		elif main_game.dialogue_manager.has_method("iniciar_dialogo_da_missao"):
			main_game.dialogue_manager.iniciar_dialogo_da_missao(no_dialogo)
