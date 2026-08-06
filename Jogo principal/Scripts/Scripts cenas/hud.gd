extends Control

@onready var global = get_node("/root/Global")
@onready var main_game = get_tree().current_scene 


signal toggle_freecam  # ← adiciona essa linha

var freecam: Camera2D
var scene_camera: Camera2D
var freecam_active := false
var botoes_bloqueaveis = []
var missao_check_aberta := false  # true quando a tela de missão está aberta só pra consulta (via ButtonMissaoCheck)

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
	
	# Sistema de renda (dinheiro) — baseado na quantidade de casas ativas no mapa
	Global.renda = main_game.contar_casas_ativas()
	if Global.renda > 0:
		var faixa := _obter_range_por_popularidade()
		
		# Calcula a renda total
		var renda_total = 0
		for i in range(Global.renda):
			var valor_aleatorio = randi() % (faixa.y - faixa.x + 1) + faixa.x
			renda_total += valor_aleatorio
		
		Global.dinheiro += renda_total
		print("Renda coletada: ", renda_total, " dinheiro (", Global.renda, " casas ativas)")
		print("Range usado: ", faixa.x, "-", faixa.y, " (Popularidade: ", Global.popularidade, ")")
	
	# --- ESBOÇO: renda de pedra e madeira por turno ---
	# Mesma lógica do dinheiro, mas ainda não gera nada porque nenhuma
	# construção do tipo produtor existe no jogo (contagem = 0 por enquanto).
	_gerar_renda_pedra_e_madeira()
	
	# SESSÃO DE MISSÕES
	# Se a missão foi ACEITA mas não foi concluída antes de passar o turno,
	# ela falha imediatamente e o jogador perde 50% a mais de popularidade
	# (a "promessa falsa" custa mais caro do que simplesmente recusar).
	if Global.missao_escolhida != null and Global.missao_aceita:
		var popularidade_perdida = Global.missao_escolhida["popularidade"] * 1.5
		Global.popularidade -= popularidade_perdida
		print("Missão '", Global.missao_escolhida["nome"], "' falhou por não ter sido concluída a tempo! Popularidade perdida: -", popularidade_perdida)
		
		Global.missao_escolhida = null
		Global.missao_aceita = false
		Global.missao_atual_turnos = 0
	
	main_game.escolher_missao_aleatoria()


# Faixa (min, max) de renda por unidade, de acordo com a popularidade atual.
# Usada tanto pelo dinheiro quanto pelo esboço de pedra/madeira.
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


# ESBOÇO — sistema de renda de pedra e madeira por turno.
# Mesma lógica do dinheiro (faixa por popularidade x quantidade de construções
# produtoras), mas por enquanto sempre gera 0, pois ainda não existem prédios
# do tipo "pedreira"/"serraria" no banco de edifícios.
#
# Pra ativar no futuro: crie os .tres dos prédios produtores com id começando
# em "pedreira"/"serraria" (ou troque os prefixos abaixo pelos que você usar).
func _gerar_renda_pedra_e_madeira() -> void:
	Global.renda_pedra = main_game.contar_construcoes_por_categoria("pedreira")
	Global.renda_madeira = main_game.contar_construcoes_por_categoria("serraria")
	
	if Global.renda_pedra > 0:
		var faixa_pedra := _obter_range_por_popularidade()
		var pedra_total = 0
		for i in range(Global.renda_pedra):
			pedra_total += randi() % (faixa_pedra.y - faixa_pedra.x + 1) + faixa_pedra.x
		Global.pedra += pedra_total
		print("Pedra coletada: ", pedra_total, " (", Global.renda_pedra, " pedreiras)")
	
	if Global.renda_madeira > 0:
		var faixa_madeira := _obter_range_por_popularidade()
		var madeira_total = 0
		for i in range(Global.renda_madeira):
			madeira_total += randi() % (faixa_madeira.y - faixa_madeira.x + 1) + faixa_madeira.x
		Global.madeira += madeira_total
		print("Madeira coletada: ", madeira_total, " (", Global.renda_madeira, " serrarias)")


func _on_aceitar_missao_pressed() -> void:
	if Global.missao_escolhida == null:
		print("Nenhuma missão ativa!")
		return
	
	# Apenas ACEITA a missão — ela só é concluída de fato ao apertar o botão
	# de concluir (_on_button_missao_concluir_pressed), e só se houver dinheiro.
	Global.missao_aceita = true
	
	print("Missão aceita: ", Global.missao_escolhida["nome"], " — conclua antes de passar o turno, ou ela falhará!")
	
	# Esconde o container de missão
	$MissaoContainer.visible = false
	
	# Despausa o jogo
	Global.jogo_pausado = false


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


# Labels
@onready var dinheiro_label: RichTextLabel = $DinheiroContainer/HBoxContainer/DinheiroLabel
@onready var madeira_label: RichTextLabel = $MadeiraContainer/HBoxContainer/MadeiraLabel
@onready var pedra_label: RichTextLabel = $PedraContainer/HBoxContainer/PedraLabel
@onready var turno_label: RichTextLabel = $TurnoContainer/HBoxContainer/TurnoLabel
@onready var popularidade_label: RichTextLabel = $PopularidadeContainer/HBoxContainer/PopularidadeLabel
@onready var missao_info_label: RichTextLabel = $MissaoContainer/VBoxContainer/MissaoInfo
@onready var missao_recompensa_label: RichTextLabel = $MissaoContainer/VBoxContainer/MissaoRecompensa

func _process(_delta: float) -> void:
	_update_dinheiro_label()
	_update_pedra_label()
	_update_madeira_label()
	_update_turno_label()
	_update_popularidade_label()
	_update_missao_info_label()
	_update_missao_recompensa_label()
	_update_button_missao_check()

func _update_dinheiro_label() -> void:
	if dinheiro_label == null:
		return
	dinheiro_label.text = "%s" % str(Global.dinheiro)
	
func _update_pedra_label() -> void:
	if pedra_label == null:
		return
	pedra_label.text = "%s" % str(Global.pedra)
	
func _update_madeira_label() -> void:
	if madeira_label == null:
		return
	madeira_label.text = "%s" % str(Global.madeira)

func _update_turno_label() -> void:
	if turno_label == null:
		return
	turno_label.text = "Turno: %s" % str(Global.turno)

func _update_popularidade_label() -> void:
	if popularidade_label == null:
		return
	popularidade_label.text = str("Popularidade: ", str(Global.popularidade)) + "%"

func _update_missao_info_label() -> void:
	if missao_info_label == null:
		return
	if Global.missao_escolhida != null:
		missao_info_label.text = str(Global.missao_escolhida["info"])
	else:
		missao_info_label.text = ""

func _update_missao_recompensa_label() -> void:
	if missao_recompensa_label == null:
		return
	if Global.missao_escolhida != null:
		missao_recompensa_label.text = "Custo: " + str(Global.missao_escolhida["custo"]) + " dinheiro" + \
			"\nPedra: " + str(Global.missao_escolhida["pedra"]) + \
			"\nMadeira: " + str(Global.missao_escolhida["madeira"]) + \
			"\nPopularidade: +" + str(Global.missao_escolhida["popularidade"])
	else:
		missao_recompensa_label.text = ""

func _update_button_missao_check() -> void:
	if not has_node("ButtonMissaoCheck"):
		return
	# O botão só aparece se existe uma missão ativa E ela já foi aceita
	$ButtonMissaoCheck.visible = (Global.missao_escolhida != null and Global.missao_aceita)


func _on_button_missao_concluir_pressed() -> void:
	if Global.missao_escolhida == null or not Global.missao_aceita:
		print("Nenhuma missão aceita para concluir no momento!")
		return
	
	var missao = Global.missao_escolhida
	
	# Só pode concluir se tiver dinheiro, pedra e madeira suficientes
	if Global.dinheiro < missao["custo"] or Global.pedra < missao["pedra"] or Global.madeira < missao["madeira"]:
		print("Recursos insuficientes para concluir a missão!")
		print("Necessário -> Dinheiro: ", missao["custo"], " | Pedra: ", missao["pedra"], " | Madeira: ", missao["madeira"])
		print("Você tem -> Dinheiro: ", Global.dinheiro, " | Pedra: ", Global.pedra, " | Madeira: ", Global.madeira)
		return
	
	# Paga o custo (dinheiro, pedra e madeira) e recebe a recompensa de popularidade
	Global.dinheiro -= missao["custo"]
	Global.pedra -= missao["pedra"]
	Global.madeira -= missao["madeira"]
	Global.popularidade += missao["popularidade"]
	
	# Adiciona a chave da missão à lista de concluídas
	Global.missoes_concluidas.append(missao["chave"])
	
	# Remove do contador de turnos sem missão
	if missao["chave"] in Global.turnos_sem_missao:
		Global.turnos_sem_missao.erase(missao["chave"])
	
	print("Missão concluída: ", missao["nome"])
	print("Gasto -> Dinheiro: ", missao["custo"], " | Pedra: ", missao["pedra"], " | Madeira: ", missao["madeira"])
	print("Popularidade: +", missao["popularidade"])
	print("Restante -> Dinheiro: ", Global.dinheiro, " | Pedra: ", Global.pedra, " | Madeira: ", Global.madeira)
	
	# Limpa a missão atual e reseta contadores
	Global.missao_escolhida = null
	Global.missao_aceita = false
	Global.missao_atual_turnos = 0
	Global.chance_missao = 30


func _on_button_missao_check_pressed() -> void:
	# Só abre a tela de checagem se existe missão ativa e aceita
	if Global.missao_escolhida == null or not Global.missao_aceita:
		return
	
	missao_check_aberta = true
	
	# Esconde os botões de Aceitar/Recusar (não fazem sentido nesse modo)
	$MissaoContainer/VBoxContainer/HBoxContainer.visible = false
	
	# Mostra o container com o botão de fechar
	$MissaoContainer/VBoxContainer/HBoxContainer2.visible = true
	
	$MissaoContainer.visible = true


func _on_missao_close_pressed() -> void:
	missao_check_aberta = false
	$MissaoContainer.visible = false
	
	# Restaura os botões de Aceitar/Recusar pra próxima vez que uma missão for oferecida
	$MissaoContainer/VBoxContainer/HBoxContainer.visible = true
	
	# Esconde de novo o container do botão de fechar (só aparece durante a checagem)
	$MissaoContainer/VBoxContainer/HBoxContainer2.visible = false
