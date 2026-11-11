extends Node2D
class_name FaseCidadao

signal fase_concluida(sucesso: bool)

# Referência do DialogueManager instanciado na cena
@onready var dialogue_manager: CanvasLayer = $DialogueManager if has_node("DialogueManager") else null

# Referências dos nós da interface de escolhas e feedback
@onready var margem_principal: MarginContainer = $CanvasUI/ControlUI/MargemPrincipal if has_node("CanvasUI/ControlUI/MargemPrincipal") else null
@onready var botoes_opcoes: Array[Button] = [
	$CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao1 if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao1") else null,
	$CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao2 if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao2") else null,
	$CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao3 if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao3") else null
]

@onready var painel_feedback: PanelContainer = $CanvasUI/ControlUI/PainelFeedback if has_node("CanvasUI/ControlUI/PainelFeedback") else null
@onready var titulo_feedback: RichTextLabel = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TituloFeedback if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TituloFeedback") else null
@onready var texto_feedback: RichTextLabel = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TextoFeedback if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TextoFeedback") else null
@onready var botao_continuar: Button = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/BotaoContinuar if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/BotaoContinuar") else null

# Nós da introdução e efeitos visuais
@onready var painel_intro_contexto: ColorRect = $CanvasUI/ControlUI/PainelIntroContexto if has_node("CanvasUI/ControlUI/PainelIntroContexto") else null
@onready var botao_iniciar_intro: Button = $CanvasUI/ControlUI/PainelIntroContexto/MargemIntro/ColunaIntro/BotaoIniciarIntro if has_node("CanvasUI/ControlUI/PainelIntroContexto/MargemIntro/ColunaIntro/BotaoIniciarIntro") else null
@onready var alerta_vermelho: ColorRect = $CanvasUI/ControlUI/AlertaVermelho if has_node("CanvasUI/ControlUI/AlertaVermelho") else null
@onready var efeito_chuva: CPUParticles2D = $Cenario2D/EfeitoChuva if has_node("Cenario2D/EfeitoChuva") else null

# Referências do cenário 2D
@onready var agua_enchente: ColorRect = $Cenario2D/AguaEnchente if has_node("Cenario2D/AguaEnchente") else null
@onready var personagem: Node2D = $PersonagemCidadao if has_node("PersonagemCidadao") else null

# Waypoints do percurso
@onready var marker_casa: Marker2D = $PontosCaminho/MarkerCasa if has_node("PontosCaminho/MarkerCasa") else null
@onready var marker_casa_moveis: Marker2D = $PontosCaminho/MarkerCasaMoveis if has_node("PontosCaminho/MarkerCasaMoveis") else null
@onready var marker_rua: Marker2D = $PontosCaminho/MarkerRua if has_node("PontosCaminho/MarkerRua") else null
@onready var marker_carro: Marker2D = $PontosCaminho/MarkerCarro if has_node("PontosCaminho/MarkerCarro") else null
@onready var marker_passarela: Marker2D = $PontosCaminho/MarkerPassarela if has_node("PontosCaminho/MarkerPassarela") else null
@onready var marker_bueiro_buraco: Marker2D = $PontosCaminho/MarkerBueiroBuraco if has_node("PontosCaminho/MarkerBueiroBuraco") else null
@onready var marker_desvio_bueiro: Marker2D = $PontosCaminho/MarkerDesvioBueiro if has_node("PontosCaminho/MarkerDesvioBueiro") else null
@onready var marker_poste_inicio: Marker2D = $PontosCaminho/MarkerPosteInicio if has_node("PontosCaminho/MarkerPosteInicio") else null
@onready var marker_poca_poste: Marker2D = $PontosCaminho/MarkerPocaPoste if has_node("PontosCaminho/MarkerPocaPoste") else null
@onready var marker_desvio_poste: Marker2D = $PontosCaminho/MarkerDesvioPoste if has_node("PontosCaminho/MarkerDesvioPoste") else null
@onready var marker_morro: Marker2D = $PontosCaminho/MarkerMorro if has_node("PontosCaminho/MarkerMorro") else null
@onready var marker_retorno_casa: Marker2D = $PontosCaminho/MarkerRetornoCasa if has_node("PontosCaminho/MarkerRetornoCasa") else null
@onready var marker_abrigo: Marker2D = $PontosCaminho/MarkerAbrigo if has_node("PontosCaminho/MarkerAbrigo") else null

# Mapeamento dos 5 Atos com marcadores, níveis de água e textos resumidos nas escolhas
var _etapas: Array[Dictionary] = [
	{
		"id": 0,
		"chave_dialogo": "cidadao_etapa1_inicio",
		"marcador_inicial": "marker_casa",
		"marcador_sucesso": "marker_rua",
		"marcador_erro": "marker_casa_moveis",
		"nivel_agua_inicial": 0.0,
		"nivel_agua_sucesso": 350.0,
		"nivel_agua_erro": 550.0,
		"opcoes": [
			{
				"texto": "Salvar bens materiais e móveis primeiro",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nPerder minutos preciosos salvando bens materiais durante uma inundação rápida pode deixar você ilhado dentro de casa. Sua vida é a prioridade!"
			},
			{
				"texto": "Desligar luz/gás e evacuar com kit de emergência",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nDesligar energia e gás evita curtos-circuitos, choques elétricos e explosões quando a água atinge tomadas e tubulações."
			}
		]
	},
	{
		"id": 1,
		"chave_dialogo": "cidadao_etapa2_rua",
		"marcador_inicial": "marker_rua",
		"marcador_sucesso": "marker_passarela",
		"marcador_erro": "marker_carro",
		"nivel_agua_inicial": 350.0,
		"nivel_agua_sucesso": 800.0,
		"nivel_agua_erro": 950.0,
		"opcoes": [
			{
				"texto": "Atravessar a enxurrada de carona no carro",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nApenas 30 cm de água em movimento conseguem fazer um carro flutuar e ser arrastado. Entrar em veículos alagados é uma das principais causas de afogamento."
			},
			{
				"texto": "Subir as escadas da passarela para cruzar por cima",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nCaminhar por estruturas e passarelas elevadas, longe do leito de enxurradas e de veículos imersos, é a rota mais protegida."
			}
		]
	},
	{
		"id": 2,
		"chave_dialogo": "cidadao_etapa3_escola",
		"marcador_inicial": "marker_passarela",
		"marcador_sucesso": "marker_desvio_bueiro",
		"marcador_erro": "marker_bueiro_buraco",
		"nivel_agua_inicial": 800.0,
		"nivel_agua_sucesso": 1250.0,
		"nivel_agua_erro": 1400.0,
		"opcoes": [
			{
				"texto": "Atravessar direto andando rápido pela água barrenta",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nEm enchentes, a força da enxurrada costuma arrancar tampas de bueiros e esconder buracos profundos. Pisar em água turva sem enxergar o chão pode causar quedas fatais em galerias de esgoto ou afogamento!"
			},
			{
				"texto": "Caminhar pela mureta elevada e testar o solo antes",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nA Defesa Civil orienta jamais caminhar em áreas alagadas sem visibilidade do piso. Prefira sempre passeios elevados ou use apoio para testar a profundidade antes de avançar."
			}
		]
	},
	{
		"id": 3,
		"chave_dialogo": "cidadao_etapa4_poste",
		"marcador_inicial": "marker_desvio_bueiro",
		"marcador_sucesso": "marker_desvio_poste",
		"marcador_erro": "marker_poca_poste",
		"nivel_agua_inicial": 1250.0,
		"nivel_agua_sucesso": 1700.0,
		"nivel_agua_erro": 1850.0,
		"opcoes": [
			{
				"texto": "Passar perto do poste contando com a galocha",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nCalçados comuns de borracha não isolam alta tensão. A água conduz eletricidade a metros de distância e o choque em meio aquoso é fatal."
			},
			{
				"texto": "Recuar e dar a volta pelo caminho seco de cima",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nMantenha distância mínima de 15 metros de fiação caída. A água ao redor cria uma zona invisível de eletrificação."
			}
		]
	},
	{
		"id": 4,
		"chave_dialogo": "cidadao_etapa5_abrigo",
		"marcador_inicial": "marker_desvio_poste",
		"marcador_sucesso": "marker_abrigo",
		"marcador_erro": "marker_retorno_casa",
		"nivel_agua_inicial": 1700.0,
		"nivel_agua_sucesso": 2200.0,
		"nivel_agua_erro": 2200.0,
		"opcoes": [
			{
				"texto": "Voltar para casa tentando resgatar pertences",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nEnquanto a tempestade continua e o nível da água se eleva, retornar a áreas alagadas traz risco mortal de afogamento. Pertences materiais podem ser repostos, a vida não!"
			},
			{
				"texto": "Permanecer no abrigo elevado e aguardar orientações",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Parabéns! Jornada Concluída com Segurança![/b][/color]\nRegistrar-se nos abrigos e aguardar em ponto elevado até a avaliação técnica das autoridades garante a proteção de todos e facilita o trabalho das equipes de resgate."
			}
		]
	}
]

var _etapa_atual_index: int = 0
var _escolha_correta_feita: bool = false
var _executando_acao: bool = false
var _tween_alerta: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if painel_feedback:
		painel_feedback.visible = false
	if margem_principal:
		margem_principal.visible = false
	if alerta_vermelho:
		alerta_vermelho.visible = false

	if botao_continuar and not botao_continuar.pressed.is_connected(_on_botao_continuar_pressed):
		botao_continuar.pressed.connect(_on_botao_continuar_pressed)

	if botao_iniciar_intro and not botao_iniciar_intro.pressed.is_connected(_on_botao_iniciar_intro_pressed):
		botao_iniciar_intro.pressed.connect(_on_botao_iniciar_intro_pressed)

	if get_tree().current_scene == self:
		iniciar_fase()


func iniciar_fase() -> void:
	_etapa_atual_index = 0
	_executando_acao = false
	visible = true
	get_tree().paused = true

	if marker_casa and personagem:
		personagem.position = marker_casa.position

	_definir_posicao_agua_direta(0.0)

	if efeito_chuva:
		efeito_chuva.emitting = true
		efeito_chuva.amount = 60

	if painel_intro_contexto:
		painel_intro_contexto.visible = true
		painel_intro_contexto.modulate.a = 1.0


func _on_botao_iniciar_intro_pressed() -> void:
	if painel_intro_contexto:
		var tw_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_fade.tween_property(painel_intro_contexto, "modulate:a", 0.0, 0.8)
		await tw_fade.finished
		painel_intro_contexto.visible = false

	_executar_sequencia_alerta_intro()


func _executar_sequencia_alerta_intro() -> void:
	_iniciar_efeito_alerta_piscando()
	await _exibir_dialogo_sistema("cidadao_intro_alerta")

	if efeito_chuva:
		var tw_chuva = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_chuva.tween_property(efeito_chuva, "amount", 350, 2.5)

	_animar_agua(350.0, 2.5)
	await get_tree().create_timer(2.5).timeout

	_parar_efeito_alerta()
	_carregar_etapa(0)


func _exibir_dialogo_sistema(chave_dialogo: String) -> void:
	if not dialogue_manager:
		await get_tree().create_timer(0.5).timeout
		return

	dialogue_manager.layer = 20

	if margem_principal:
		margem_principal.visible = false

	if dialogue_manager.has_method("iniciar_dialogo_dica"):
		dialogue_manager.iniciar_dialogo_dica(chave_dialogo)
		await dialogue_manager.dialogo_finalizado
	else:
		await get_tree().create_timer(0.5).timeout


func _carregar_etapa(index: int) -> void:
	if index >= _etapas.size():
		_concluir_fase(true)
		return

	_executando_acao = false
	if painel_feedback:
		painel_feedback.visible = false
	if margem_principal:
		margem_principal.visible = false

	var dados_etapa = _etapas[index]

	# Movimentação do personagem até o ponto inicial da etapa
	var start_marker: Marker2D = get(dados_etapa["marcador_inicial"])
	if start_marker and personagem:
		if personagem.position.distance_to(start_marker.position) > 10.0:
			var tw_trans = _animar_personagem(start_marker.position, 1.2)
			await tw_trans.finished

	# Exibe o diálogo da fala inicial via DialogueManager
	if dados_etapa.has("chave_dialogo") and not dados_etapa["chave_dialogo"].is_empty():
		await _exibir_dialogo_sistema(dados_etapa["chave_dialogo"])

	# Exibe as escolhas no HUD
	if margem_principal:
		margem_principal.visible = true

	var opcoes: Array = dados_etapa["opcoes"]
	for i in range(botoes_opcoes.size()):
		var btn = botoes_opcoes[i]
		if not btn:
			continue

		if i < opcoes.size():
			var opcao = opcoes[i]
			btn.text = "%d. %s" % [i + 1, opcao["texto"]]
			btn.visible = true

			for conn in btn.pressed.get_connections():
				btn.pressed.disconnect(conn.callable)

			btn.pressed.connect(_on_opcao_selecionada.bind(opcao))
		else:
			btn.visible = false


func _on_opcao_selecionada(opcao: Dictionary) -> void:
	if _executando_acao:
		return

	_executando_acao = true
	_escolha_correta_feita = opcao["correta"]
	var dados_etapa = _etapas[_etapa_atual_index]

	if margem_principal:
		margem_principal.visible = false

	# Executa a movimentação do personagem e a elevação da água
	if _escolha_correta_feita:
		var target_marker: Marker2D = get(dados_etapa["marcador_sucesso"])
		if target_marker and personagem:
			var t1 = _animar_personagem(target_marker.position, 2.0)
			_animar_agua(dados_etapa["nivel_agua_sucesso"], 2.0)
			await t1.finished
	else:
		var err_marker: Marker2D = get(dados_etapa["marcador_erro"])
		if err_marker and personagem:
			var t1 = _animar_personagem(err_marker.position, 1.5)
			_animar_agua(dados_etapa["nivel_agua_erro"], 1.5)
			await t1.finished

	await get_tree().create_timer(0.4).timeout

	# Apresenta o painel de feedback
	if titulo_feedback:
		titulo_feedback.text = "[center]" + ("[color=#4CAF50]DECISÃO SEGURA[/color]" if _escolha_correta_feita else "[color=#F44336]DECISÃO INCORRETA[/color]") + "[/center]"

	if texto_feedback:
		texto_feedback.text = opcao["feedback"]

	if botao_continuar:
		botao_continuar.text = "Avançar" if _escolha_correta_feita else "Tentar Novamente"

	if painel_feedback:
		painel_feedback.visible = true


func _on_botao_continuar_pressed() -> void:
	var dados_etapa = _etapas[_etapa_atual_index]

	if _escolha_correta_feita:
		if painel_feedback:
			painel_feedback.visible = false
		_etapa_atual_index += 1
		_carregar_etapa(_etapa_atual_index)
	else:
		if painel_feedback:
			painel_feedback.visible = false

		var start_marker: Marker2D = get(dados_etapa["marcador_inicial"])
		if start_marker and personagem:
			var t_rewind = _animar_personagem(start_marker.position, 1.2)
			_animar_agua(dados_etapa["nivel_agua_inicial"], 1.2)
			await t_rewind.finished

		_carregar_etapa(_etapa_atual_index)


func _iniciar_efeito_alerta_piscando() -> void:
	if not alerta_vermelho:
		return
	alerta_vermelho.visible = true
	alerta_vermelho.color.a = 0.0

	if _tween_alerta and _tween_alerta.is_valid():
		_tween_alerta.kill()

	_tween_alerta = create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_alerta.tween_property(alerta_vermelho, "color:a", 0.22, 0.75).set_trans(Tween.TRANS_SINE)
	_tween_alerta.tween_property(alerta_vermelho, "color:a", 0.04, 0.75).set_trans(Tween.TRANS_SINE)


func _parar_efeito_alerta() -> void:
	if _tween_alerta and _tween_alerta.is_valid():
		_tween_alerta.kill()

	if alerta_vermelho:
		var tw_stop = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_stop.tween_property(alerta_vermelho, "color:a", 0.0, 1.0)
		await tw_stop.finished
		alerta_vermelho.visible = false


func _animar_personagem(destino: Vector2, duracao: float) -> Tween:
	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(personagem, "position", destino, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


func _animar_agua(pos_x_direita: float, duracao: float) -> Tween:
	var x_inicio = -600.0
	var largura_calculada = pos_x_direita - x_inicio
	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if agua_enchente:
		var novo_tamanho = Vector2(largura_calculada, agua_enchente.size.y)
		tw.tween_property(agua_enchente, "size", novo_tamanho, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw


func _definir_posicao_agua_direta(pos_x_direita: float) -> void:
	if agua_enchente:
		var x_inicio = -600.0
		agua_enchente.size.x = pos_x_direita - x_inicio


func _concluir_fase(sucesso: bool) -> void:
	get_tree().paused = false
	visible = false
	fase_concluida.emit(sucesso)
