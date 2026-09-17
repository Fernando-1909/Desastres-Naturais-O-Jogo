extends Control

@onready var global = get_node("/root/Global")
@onready var main_game = get_tree().current_scene


signal toggle_freecam  # ← adiciona essa linha

var freecam: Camera2D
var scene_camera: Camera2D
var freecam_active := false
var botoes_bloqueaveis = []

# Quantas pessoas de população equivalem a 1 "unidade" de renda por turno.
# Ajuste esse número pra calibrar o quanto a população influencia o dinheiro ganho.
const POPULACAO_POR_UNIDADE_RENDA := 10

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_setup()
	
	
	# Global.renda agora é calculado dinamicamente a cada turno, com base
	# na quantidade de casas ativas no mapa (ver _on_button_turno_pressed)
	#Global.popularidade = 0 # Altere aqui para testar os ranges
	
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


func _on_button_turno_pressed() -> void:
	# Verifica se o jogo está pausado
	if Global.jogo_pausado:
		print("Jogo pausado! Não é possível avançar o turno.")
		return
	
	Global.turno += 1
	print("Turno: ", Global.turno)
	
	# Se o jogador passou do último turno jogável, o jogo acaba aqui: vai
	# direto pra tela de Game Over e nem processa renda/desastres/missões.
	if main_game and "turno_final" in main_game and Global.turno > main_game.turno_final:
		print("[FIM DE JOGO] Turno ", Global.turno, " > turno final (", main_game.turno_final, "). Indo para Game Over.")
		get_tree().change_scene_to_file("res://Jogo principal/game_over.tscn")
		return
	
	# Sistema de renda (dinheiro) — baseado na população da cidade.
	# Cada POPULACAO_POR_UNIDADE_RENDA pessoas contam como 1 unidade de renda,
	# e cada unidade sorteia um valor dentro da faixa definida pela popularidade.
	Global.renda = int(Global.populacao / POPULACAO_POR_UNIDADE_RENDA)
	if Global.renda > 0:
		var faixa := _obter_range_por_popularidade()
		
		# Calcula a renda total
		var renda_total = 0
		for i in range(Global.renda):
			var valor_aleatorio = randi() % (faixa.y - faixa.x + 1) + faixa.x
			renda_total += valor_aleatorio
		
		Global.dinheiro += renda_total
		print("Renda coletada: ", renda_total, " dinheiro (população: ", Global.populacao, " | ", Global.renda, " unidades de renda)")
		print("Range usado: ", faixa.x, "-", faixa.y, " (Popularidade: ", Global.popularidade, ")")
	
	
	# Avança qualquer desastre em curso (ex: enchente sobe de nível, reaplica dano)
	main_game.avancar_turno_desastres()
	
	# Processa o sistema de missões (falha por turno + sorteio da próxima),
	# tudo centralizado no main_game agora.
	main_game.processar_missao_no_turno()


# Faixa (min, max) de renda por unidade, de acordo com a popularidade atual.
# Usada para dinheiro
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



func _on_aceitar_missao_pressed() -> void:
	main_game.aceitar_missao()


func _on_recusar_missao_pressed() -> void:
	main_game.recusar_missao()


# Labels
@onready var dinheiro_label: RichTextLabel = $DinheiroContainer/HBoxContainer/DinheiroLabel
@onready var turno_label: RichTextLabel = $TurnoContainer/HBoxContainer/TurnoLabel
@onready var popularidade_label: RichTextLabel = $PopularidadeContainer/HBoxContainer/PopularidadeLabel
@onready var missao_titulo_label: RichTextLabel = $MissaoContainer/VBoxContainer/Missaolabel
@onready var missao_info_label: RichTextLabel = $MissaoContainer/VBoxContainer/MissaoInfo
@onready var missao_recompensa_label: RichTextLabel = $MissaoContainer/VBoxContainer/MissaoRecompensa
@onready var populacao_label: RichTextLabel = $PopulacaoContainer/HBoxContainer/PopulacaoLabel
@onready var desabrigados_label: RichTextLabel = $DesabrigadosContainer/HBoxContainer/DesabrigadosLabel

# ButtonMissaoCheck pode estar aninhado em algum container — busca em
# qualquer profundidade da árvore, em vez de exigir que seja filho direto.
@onready var button_missao_check: Button = find_child("ButtonMissaoCheck", true, false)

# Os dois grupos de botões da caixa de missão (decisão vs. fechar).
@onready var missao_hbox_decisao: HBoxContainer = $MissaoContainer/VBoxContainer/HBoxContainer
@onready var missao_hbox_fechar: HBoxContainer = $MissaoContainer/VBoxContainer/HBoxContainer2


func _process(_delta: float) -> void:
	_update_dinheiro_label()
	_update_turno_label()
	_update_popularidade_label()
	_update_missao_titulo_label()
	_update_missao_info_label()
	_update_missao_recompensa_label()
	_update_button_missao_check()
	_update_missao_botoes()
	_update_populacao_label()
	_update_desabrigados_label()

func _update_dinheiro_label() -> void:
	if dinheiro_label == null:
		return
	dinheiro_label.text = "%s" % str(Global.dinheiro)
	
func _update_desabrigados_label() -> void:
	if desabrigados_label == null:
		return
	desabrigados_label.text = "Desabrigados: %s" % str(Global.pessoas_desabrigadas)
	
func _update_populacao_label() -> void:
	if populacao_label == null:
		return
	populacao_label.text = "População: %s" % str(Global.populacao)

func _update_turno_label() -> void:
	if turno_label == null:
		return
	turno_label.text = "Turno: %s" % str(Global.turno)

func _update_popularidade_label() -> void:
	if popularidade_label == null:
		return
	popularidade_label.text = str("Popularidade: ", str(Global.popularidade)) + "%"

func _update_missao_titulo_label() -> void:
	if missao_titulo_label == null:
		return
	if _missao_recem_concluida() != null:
		missao_titulo_label.text = "Missão concluída!"
	elif Global.missao_escolhida != null:
		missao_titulo_label.text = "Missão!"
	else:
		missao_titulo_label.text = "Missão!"

func _update_missao_info_label() -> void:
	if missao_info_label == null:
		return
	if Global.missao_escolhida != null:
		missao_info_label.text = str(Global.missao_escolhida.info)
	elif _missao_recem_concluida() != null:
		missao_info_label.text = "Missão concluída: " + str(_missao_recem_concluida().nome)
	else:
		missao_info_label.text = ""

func _update_missao_recompensa_label() -> void:
	if missao_recompensa_label == null:
		return
	if Global.missao_escolhida != null:
		var m = Global.missao_escolhida
		var texto = "Custo: " + str(m.custo) + " dinheiro" + \
			"\nPopularidade: +" + str(m.popularidade)
		if "bonus_populacao" in m and m.bonus_populacao > 0:
			texto += "\nPopulação: +" + str(m.bonus_populacao)
		missao_recompensa_label.text = texto
	elif _missao_recem_concluida() != null:
		var m = _missao_recem_concluida()
		var texto = "Popularidade: +" + str(m.popularidade)
		if "bonus_populacao" in m and m.bonus_populacao > 0:
			texto += "\nPopulação: +" + str(m.bonus_populacao)
		missao_recompensa_label.text = texto
	else:
		missao_recompensa_label.text = ""

# Só considera a missão como "recém-concluída" enquanto a tela de
# confirmação (HBoxContainer2 dentro do MissaoContainer) estiver aberta —
# ou seja, entre a conclusão e o jogador clicar em fechar.
func _missao_recem_concluida() -> MissionData:
	if main_game == null:
		return null
	if not ("_missao_check_aberta" in main_game) or not main_game._missao_check_aberta:
		return null
	if not ("ultima_missao_concluida" in main_game):
		return null
	return main_game.ultima_missao_concluida

func _update_button_missao_check() -> void:
	if button_missao_check == null:
		return
	# O botão só aparece se existe uma missão ativa E ela já foi aceita
	button_missao_check.visible = (Global.missao_escolhida != null and Global.missao_aceita)


# Controla a visibilidade dos botões da caixa de missão TODO FRAME, em vez de
# depender de cada função (aceitar/recusar/concluir/etc.) lembrar de ligar e
# desligar o grupo certo — assim não fica um estado "preso" errado.
func _update_missao_botoes() -> void:
	var check_aberta = main_game != null and "_missao_check_aberta" in main_game and main_game._missao_check_aberta
	
	if missao_hbox_decisao:
		# Aceitar/Recusar só fazem sentido enquanto a missão foi OFERECIDA e
		# ainda não foi aceita (nunca durante checagem/confirmação de conclusão)
		missao_hbox_decisao.visible = Global.missao_escolhida != null and not Global.missao_aceita and not check_aberta
	
	if missao_hbox_fechar:
		# O botão de fechar só aparece durante a checagem/confirmação de conclusão
		missao_hbox_fechar.visible = check_aberta


func _on_button_missao_concluir_pressed() -> void:
	main_game.concluir_missao()


func _on_button_missao_check_pressed() -> void:
	main_game.abrir_checagem_missao()


func _on_missao_close_pressed() -> void:
	main_game.fechar_checagem_missao()
