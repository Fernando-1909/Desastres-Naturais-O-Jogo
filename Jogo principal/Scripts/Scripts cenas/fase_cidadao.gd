extends Node2D
class_name FaseCidadao

signal fase_concluida(sucesso: bool)

# Referências dos nós da interface
@onready var margem_principal: MarginContainer = $CanvasUI/ControlUI/MargemPrincipal if has_node("CanvasUI/ControlUI/MargemPrincipal") else null
@onready var texto_situacao: RichTextLabel = $CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/PainelNarrativa/MargemTexto/TextoSituacao if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/PainelNarrativa/MargemTexto/TextoSituacao") else null

# Botões estáticos compactos da UI
@onready var botoes_opcoes: Array[Button] = [
	$CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao1 if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao1") else null,
	$CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao2 if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao2") else null,
	$CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao3 if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes/BotaoOpcao3") else null
]

@onready var painel_feedback: PanelContainer = $CanvasUI/ControlUI/PainelFeedback if has_node("CanvasUI/ControlUI/PainelFeedback") else null
@onready var titulo_feedback: RichTextLabel = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TituloFeedback if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TituloFeedback") else null
@onready var texto_feedback: RichTextLabel = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TextoFeedback if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TextoFeedback") else null
@onready var botao_continuar: Button = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/BotaoContinuar if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/BotaoContinuar") else null

# Referências do cenário 2D
@onready var agua_enchente: ColorRect = $Cenario2D/AguaEnchente if has_node("Cenario2D/AguaEnchente") else null
@onready var personagem: Node2D = $PersonagemCidadao if has_node("PersonagemCidadao") else null

# Waypoints do percurso alinhados com a narrativa
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

# Estrutura Narrativa Sequencial em 5 Atos com tom de PENSAMENTO DO PERSONAGEM
var _etapas: Array[Dictionary] = [
	{
		"id": 0,
		"marcador_inicial": "marker_casa",
		"marcador_sucesso": "marker_rua",
		"marcador_erro": "marker_casa_moveis",
		"nivel_agua_inicial": 0.0,
		"nivel_agua_sucesso": 350.0,
		"nivel_agua_erro": 550.0,
		"texto": "[b]Ato I - O Começo da Inundação[/b]\nA água começou a subir rápido no portão da minha casa. Sinto a urgência aumentando. O que devo fazer primeiro?",
		"opcoes": [
			{
				"texto": "\"Preciso correndo subir os móveis e salvar as fotos da família antes que a água estrague tudo!\"",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nPerder minutos preciosos salvando bens materiais durante uma inundação rápida pode deixar você ilhado dentro de casa. Sua vida é a prioridade!"
			},
			{
				"texto": "\"Vou desligar a chave geral de luz, fechar o registro de gás e sair imediatamente com o kit de emergência!\"",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nDesligar energia e gás evita curtos-circuitos, choques elétricos e explosões quando a água atinge tomadas e tubulações."
			}
		]
	},
	{
		"id": 1,
		"marcador_inicial": "marker_rua",
		"marcador_sucesso": "marker_passarela",
		"marcador_erro": "marker_carro",
		"nivel_agua_inicial": 350.0,
		"nivel_agua_sucesso": 800.0,
		"nivel_agua_erro": 950.0,
		"texto": "[b]Ato II - A Enxurrada na Avenida[/b]\nConsegui sair de casa, mas a rua virou um rio de água marrom. Um vizinho passou devagar de carro e acenou me chamando.",
		"opcoes": [
			{
				"texto": "\"O carro dele é pesado. Se eu entrar no banco do passageiro, a gente atravessa a enxurrada bem mais rápido!\"",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nApenas 30 cm de água em movimento conseguem fazer um carro flutuar e ser arrastado. Entrar em veículos alagados é uma das principais causas de afogamento."
			},
			{
				"texto": "\"Entrar em carro na enxurrada é arriscado. É melhor eu subir as escadas da passarela e cruzar por cima!\"",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nCaminhar por estruturas e passarelas elevadas, longe do leito de enxurradas e de veículos imersos, é a rota mais protegida."
			}
		]
	},
	{
		"id": 2,
		"marcador_inicial": "marker_passarela",
		"marcador_sucesso": "marker_desvio_bueiro",
		"marcador_erro": "marker_bueiro_buraco",
		"nivel_agua_inicial": 800.0,
		"nivel_agua_sucesso": 1250.0,
		"nivel_agua_erro": 1400.0,
		"texto": "[b]Ato III - A Armadilha Oculta na Água[/b]\nDesci da passarela, mas a rua à frente virou uma lâmina de água escura com redemoinhos. Não consigo enxergar o chão abaixo da água.",
		"opcoes": [
			{
				"texto": "\"A água parece rasa, abaixo do joelho. Vou atravessar direto andando rápido pela água barrenta para ganhar tempo!\"",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nEm enchentes, a força da enxurrada costuma arrancar tampas de bueiros e esconder buracos profundos. Pisar em água turva sem enxergar o chão pode causar quedas fatais em galerias de esgoto ou afogamento!"
			},
			{
				"texto": "\"Água barrenta pode esconder bueiros abertos e buracos. Vou caminhar com cuidado pela mureta elevada e testar o solo antes de pisar!\"",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nA Defesa Civil orienta jamais caminhar em áreas alagadas sem visibilidade do piso. Prefira sempre passeios elevados ou use apoio para testar a profundidade antes de avançar."
			}
		]
	},
	{
		"id": 3,
		"marcador_inicial": "marker_desvio_bueiro",
		"marcador_sucesso": "marker_desvio_poste",
		"marcador_erro": "marker_poca_poste",
		"nivel_agua_inicial": 1250.0,
		"nivel_agua_sucesso": 1700.0,
		"nivel_agua_erro": 1850.0,
		"texto": "[b]Ato IV - A Fiação Elétrica Caída[/b]\nRetomei a subida em direção ao morro, mas um poste caiu e o cabo elétrico está faiscando numa poça perto do caminho principal.",
		"opcoes": [
			{
				"texto": "\"Estou de galocha alta de borracha. Se eu passar dando passos rápidos perto do poste, a borracha me isola!\"",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nCalçados comuns de borracha não isolam alta tensão. A água conduz eletricidade a metros de distância e o choque em meio aquoso é fatal."
			},
			{
				"texto": "\"Não dá pra confiar em calçado na água energizada. Vou recuar e dar a volta pelo caminho seco de cima!\"",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Segura![/b][/color]\nMantenha distância mínima de 15 metros de fiação caída. A água ao redor cria uma zona invisível de eletrificação."
			}
		]
	},
	{
		"id": 4,
		"marcador_inicial": "marker_desvio_poste",
		"marcador_sucesso": "marker_abrigo",
		"marcador_erro": "marker_retorno_casa",
		"nivel_agua_inicial": 1700.0,
		"nivel_agua_sucesso": 2200.0,
		"nivel_agua_erro": 2200.0,
		"texto": "[b]Ato V - Chegada ao Abrigo Seguro[/b]\nCheguei ao Abrigo Municipal no topo do morro. Lá embaixo, a enxurrada continua forte e o nível da água não para de subir. Alguns moradores assustados cogitam descer para tentar resgatar pertences.",
		"opcoes": [
			{
				"texto": "\"Minha casa ficou lá embaixo. Vou descer correndo agora antes que a água suba mais para tentar resgatar o resto das minhas coisas!\"",
				"correta": false,
				"feedback": "[color=#F44336][b]Decisão Perigosa![/b][/color]\nEnquanto a tempestade continua e o nível da água se eleva, retornar a áreas alagadas traz risco mortal de afogamento. Pertences materiais podem ser repostos, a vida não!"
			},
			{
				"texto": "\"A enxurrada continua subindo e o risco é alto. Vou me manter em local elevado no abrigo, me registrar com a Defesa Civil e aguardar orientações!\"",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Parabéns! Jornada Concluída com Segurança![/b][/color]\nRegistrar-se nos abrigos e aguardar em ponto elevado até a avaliação técnica das autoridades garante a proteção de todos e facilita o trabalho das equipes de resgate."
			}
		]
	}
]

var _etapa_atual_index: int = 0
var _escolha_correta_feita: bool = false
var _executando_acao: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if painel_feedback:
		painel_feedback.visible = false

	if botao_continuar and not botao_continuar.pressed.is_connected(_on_botao_continuar_pressed):
		botao_continuar.pressed.connect(_on_botao_continuar_pressed)

	if get_tree().current_scene == self:
		iniciar_fase()


## Inicia a fase interativa do cidadão
func iniciar_fase() -> void:
	_etapa_atual_index = 0
	_executando_acao = false
	visible = true
	get_tree().paused = true

	if marker_casa and personagem:
		personagem.position = marker_casa.position

	_definir_posicao_agua_direta(0.0)
	_carregar_etapa(_etapa_atual_index)


func _carregar_etapa(index: int) -> void:
	if index >= _etapas.size():
		_concluir_fase(true)
		return

	_executando_acao = false
	if painel_feedback:
		painel_feedback.visible = false

	var dados_etapa = _etapas[index]

	# Movimentação fluida de transição entre atos no mapa 2D
	var start_marker: Marker2D = get(dados_etapa["marcador_inicial"])
	if start_marker and personagem:
		if personagem.position.distance_to(start_marker.position) > 10.0:
			var tw_trans = _animar_personagem(start_marker.position, 1.2)
			await tw_trans.finished

	if margem_principal:
		margem_principal.visible = true

	if texto_situacao:
		texto_situacao.text = dados_etapa["texto"]

	# Configura os botões estáticos com os pensamentos do personagem
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

	# Esconde a interface para o jogador acompanhar a ação no mapa
	if margem_principal:
		margem_principal.visible = false

	# Executa a ação visual no cenário 2D
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

	# Exibe o container de feedback educativo
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

		# Rewind suave para o início da etapa atual
		var start_marker: Marker2D = get(dados_etapa["marcador_inicial"])
		if start_marker and personagem:
			var t_rewind = _animar_personagem(start_marker.position, 1.2)
			_animar_agua(dados_etapa["nivel_agua_inicial"], 1.2)
			await t_rewind.finished

		_carregar_etapa(_etapa_atual_index)


func _animar_personagem(destino: Vector2, duracao: float) -> Tween:
	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(personagem, "position", destino, duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


func _animar_agua(pos_x_direita: float, duracao: float) -> Tween:
	var x_inicio = -600.0
	var largura_calculada = pos_x_direita - x_inicio
	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if agua_enchente:
		tw.tween_property(agua_enchente, "size:x", largura_calculada, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw


func _definir_posicao_agua_direta(pos_x_direita: float) -> void:
	if agua_enchente:
		var x_inicio = -600.0
		agua_enchente.size.x = pos_x_direita - x_inicio


func _concluir_fase(sucesso: bool) -> void:
	get_tree().paused = false
	visible = false
	fase_concluida.emit(sucesso)
