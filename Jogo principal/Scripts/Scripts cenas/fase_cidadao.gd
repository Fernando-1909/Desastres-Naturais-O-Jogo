extends Node2D
class_name FaseCidadao

signal fase_concluida(sucesso: bool)

# Referências dos nós da interface
@onready var margem_principal: MarginContainer = $CanvasUI/ControlUI/MargemPrincipal if has_node("CanvasUI/ControlUI/MargemPrincipal") else null
@onready var texto_situacao: RichTextLabel = $CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/PainelNarrativa/MargemTexto/TextoSituacao if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/PainelNarrativa/MargemTexto/TextoSituacao") else null
@onready var container_opcoes: VBoxContainer = $CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes if has_node("CanvasUI/ControlUI/MargemPrincipal/ColunaConteudo/ColunaOpcoes") else null

@onready var painel_feedback: PanelContainer = $CanvasUI/ControlUI/PainelFeedback if has_node("CanvasUI/ControlUI/PainelFeedback") else null
@onready var titulo_feedback: RichTextLabel = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TituloFeedback if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TituloFeedback") else null
@onready var texto_feedback: RichTextLabel = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TextoFeedback if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/TextoFeedback") else null
@onready var botao_continuar: Button = $CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/BotaoContinuar if has_node("CanvasUI/ControlUI/PainelFeedback/MargemFeedback/ColunaFeedback/BotaoContinuar") else null

# Referências do cenário 2D
@onready var agua_enchente: ColorRect = $Cenario2D/AguaEnchente if has_node("Cenario2D/AguaEnchente") else null
@onready var personagem: Node2D = $PersonagemCidadao if has_node("PersonagemCidadao") else null

# Waypoints
@onready var marker_casa: Marker2D = $PontosCaminho/MarkerCasa if has_node("PontosCaminho/MarkerCasa") else null
@onready var marker_casa_erro: Marker2D = $PontosCaminho/MarkerCasaErro if has_node("PontosCaminho/MarkerCasaErro") else null
@onready var marker_rua: Marker2D = $PontosCaminho/MarkerRua if has_node("PontosCaminho/MarkerRua") else null
@onready var marker_rua_erro: Marker2D = $PontosCaminho/MarkerRuaErro if has_node("PontosCaminho/MarkerRuaErro") else null
@onready var marker_escola: Marker2D = $PontosCaminho/MarkerEscola if has_node("PontosCaminho/MarkerEscola") else null
@onready var marker_escola_erro: Marker2D = $PontosCaminho/MarkerEscolaErro if has_node("PontosCaminho/MarkerEscolaErro") else null
@onready var marker_poste: Marker2D = $PontosCaminho/MarkerPoste if has_node("PontosCaminho/MarkerPoste") else null
@onready var marker_poste_erro: Marker2D = $PontosCaminho/MarkerPosteErro if has_node("PontosCaminho/MarkerPosteErro") else null
@onready var marker_morro: Marker2D = $PontosCaminho/MarkerMorro if has_node("PontosCaminho/MarkerMorro") else null
@onready var marker_abrigo: Marker2D = $PontosCaminho/MarkerAbrigo if has_node("PontosCaminho/MarkerAbrigo") else null

# Estrutura de decisões pedagógicas com 5 etapas
var _etapas: Array[Dictionary] = [
	{
		"id": 0,
		"marcador_inicial": "marker_casa",
		"marcador_sucesso": "marker_rua",
		"marcador_erro": "marker_casa_erro",
		"nivel_agua_inicial": 0.0,
		"nivel_agua_sucesso": 350.0,
		"nivel_agua_erro": 550.0,
		"texto": "[b]Etapa 1: A enchente começou na sua rua![/b]\nA água do rio está subindo rapidamente em direção à sua casa. O que fazer antes de evacuar?",
		"opcoes": [
			{
				"texto": "Desligar a chave geral de energia elétrica e fechar o registro de gás.",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Excelente escolha![/b][/color]\nDesligar a energia e o gás previne curtos-circuitos, incêndios e choques elétricos graves quando a água atinge as instalações."
			},
			{
				"texto": "Tentar juntar móveis pesados e aparelhos eletrônicos antes de sair.",
				"correta": false,
				"feedback": "[color=#F44336][b]Escolha Perigosa![/b][/color]\nPerder tempo salvando bens materiais em uma inundação rápida coloca sua vida em risco iminente. A evacuação imediata é prioridade!"
			}
		]
	},
	{
		"id": 1,
		"marcador_inicial": "marker_rua",
		"marcador_sucesso": "marker_escola",
		"marcador_erro": "marker_rua_erro",
		"nivel_agua_inicial": 350.0,
		"nivel_agua_sucesso": 800.0,
		"nivel_agua_erro": 950.0,
		"texto": "[b]Etapa 2: Trajetória pela rua alagada.[/b]\nHá uma correnteza cruzando a pista e bueiros abertos invisíveis sob a água. Como avançar de forma segura?",
		"opcoes": [
			{
				"texto": "Atravessar correndo pelo meio da enxurrada para economizar tempo.",
				"correta": false,
				"feedback": "[color=#F44336][b]Risco Crítico![/b][/color]\nApenas 15 cm de água em movimento podem derrubar um adulto, e bueiros destampados submersos podem arrastar uma pessoa."
			},
			{
				"texto": "Utilizar a passarela elevada do prédio comercial e caminhar pelas calçadas altas.",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Decisão Correta![/b][/color]\nBuscar pontos elevados e rotas protegidas evita o contato direto com enxurradas perigosas e contaminações."
			}
		]
	},
	{
		"id": 2,
		"marcador_inicial": "marker_escola",
		"marcador_sucesso": "marker_poste",
		"marcador_erro": "marker_escola_erro",
		"nivel_agua_inicial": 800.0,
		"nivel_agua_sucesso": 1250.0,
		"nivel_agua_erro": 1400.0,
		"texto": "[b]Etapa 3: Ponto de apoio na Escola Municipal.[/b]\nVocê tem a oportunidade de montar um kit básico de emergência antes de prosseguir. O que levar?",
		"opcoes": [
			{
				"texto": "Documentos pessoais, medicamentos de uso contínuo, garrafa de água e lanterna.",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Kit Perfeito![/b][/color]\nDocumentos, remédios e água limpa são essenciais nos abrigos temporários e aceleram seu atendimento."
			},
			{
				"texto": "Bolsas pesadas com roupas extras, aparelhos de videogame e objetos de valor.",
				"correta": false,
				"feedback": "[color=#F44336][b]Carga Excessiva![/b][/color]\nCarregar excesso de peso dificulta sua locomoção em terrenos alagados e causa esgotamento físico rápido."
			}
		]
	},
	{
		"id": 3,
		"marcador_inicial": "marker_poste",
		"marcador_sucesso": "marker_morro",
		"marcador_erro": "marker_poste_erro",
		"nivel_agua_inicial": 1250.0,
		"nivel_agua_sucesso": 1700.0,
		"nivel_agua_erro": 1850.0,
		"texto": "[b]Etapa 4: Perigo na fiação elétrica caída.[/b]\nUm poste foi danificado e há fiação solta faíscando próxima a uma grande poça d'água no caminho.",
		"opcoes": [
			{
				"texto": "Tentar saltar por cima dos cabos para não perder o ritmo da subida.",
				"correta": false,
				"feedback": "[color=#F44336][b]Risco Mortal de Choque![/b][/color]\nA água conduz eletricidade a metros de distância do cabo fallen. O solo energizado pode ser fatal!"
			},
			{
				"texto": "Manter distância mínima de 10 metros, dar a volta por local seco e alertar outros moradores.",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Atitude Exemplar![/b][/color]\nAfastar-se de rede elétrica danificada e alertar terceiros evita tragédias graves durante tempestades."
			}
		]
	},
	{
		"id": 4,
		"marcador_inicial": "marker_morro",
		"marcador_sucesso": "marker_abrigo",
		"marcador_erro": "marker_morro",
		"nivel_agua_inicial": 1700.0,
		"nivel_agua_sucesso": 2200.0,
		"nivel_agua_erro": 2200.0,
		"texto": "[b]Etapa 5: Chegada ao Abrigo Municipal.[/b]\nVocê chegou ao terreno seguro no topo do morro! Qual a primeira atitude ao entrar no abrigo?",
		"opcoes": [
			{
				"texto": "Registrar-se com as equipes da Defesa Civil / Bombeiros e seguir as orientações de higiene e alojamento.",
				"correta": true,
				"feedback": "[color=#4CAF50][b]Parabéns, Você Conseguiu![/b][/color]\nO cadastro correto ajuda a localizar pessoas desaparecidas e organiza a distribuição de mantimentos e remédios."
			},
			{
				"texto": "Sair correndo sem avisar ninguém para tentar voltar à zona de perigo e buscar pertences.",
				"correta": false,
				"feedback": "[color=#F44336][b]Retorno Proibido![/b][/color]\nNunca retorne a áreas alagadas antes da liberação oficial da Defesa Civil. As águas podem subir ainda mais sem aviso."
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


## Inicia a minicena do cidadão
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

	if margem_principal:
		margem_principal.visible = true

	var dados_etapa = _etapas[index]

	if texto_situacao:
		texto_situacao.text = dados_etapa["texto"]

	if container_opcoes:
		for child in container_opcoes.get_children():
			child.queue_free()

		var opcoes: Array = dados_etapa["opcoes"]
		for i in range(opcoes.size()):
			var opcao = opcoes[i]
			var btn = Button.new()
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text = "%d. %s" % [i + 1, opcao["texto"]]
			btn.pressed.connect(_on_opcao_selecionada.bind(opcao))
			container_opcoes.add_child(btn)


func _on_opcao_selecionada(opcao: Dictionary) -> void:
	if _executando_acao:
		return

	_executando_acao = true
	_escolha_correta_feita = opcao["correta"]
	var dados_etapa = _etapas[_etapa_atual_index]

	# Esconde a caixa de texto e botões imediatamente
	if margem_principal:
		margem_principal.visible = false

	# Executa a animação no mapa 2D em tempo real
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

	# Pausa para o jogador visualizar o resultado no mapa antes da janela de feedback
	await get_tree().create_timer(0.4).timeout

	# Exibe o feedback
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

		# Animação de Rewind (Rebobinar): Volta o personagem e a água suavemente
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
