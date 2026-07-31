extends CanvasLayer
class_name TelaCompras

# Enumeração que define os modos operacionais da interface
enum Modo { COMPRA, UPGRADE }

# ==============================================================================
# REFERÊNCIAS DE CONTAINERS E ESTRUTURA DO LAYOUT
# ==============================================================================
@export_group("Layout & Containers")
# O painel central que contém toda a janela do menu
@export var painel_central: PanelContainer
# Fundo escuro semi-transparente que cobre o jogo durante a navegação
@export var overlay_fundo: ColorRect
# Container horizontal que organiza as colunas da interface lado a lado
@export var colunas_grid: HBoxContainer

# Colunas individuais para distribuição dinâmica dos dados
@export var coluna_stats: VBoxContainer      # Exibe dados de ganhos e integridade no modo Upgrade
@export var coluna_esquerda: VBoxContainer   # Exibe nome, ícone, categoria e nível do edifício
@export var coluna_direita: VBoxContainer    # Exibe descrições e botões de ação (Comprar/Aprimorar)

# Containers dinâmicos acionados dependendo do modo aberto
@export var container_compra: VBoxContainer  # Conteúdo exclusivo para compra de novos lotes
@export var container_upgrade: VBoxContainer # Conteúdo exclusivo para edifícios já construídos

@export_group("Painel Pop-in de Detalhes")
# Sub-janela pop-up para leitura do texto completo de detalhes/lore do edifício
@export var painel_detalhes: PanelContainer
@export var label_titulo_detalhes: RichTextLabel
@export var label_texto_detalhes: RichTextLabel
@export var button_fechar_detalhes: Button

# ==============================================================================
# REFERÊNCIAS DOS ELEMENTOS INDIVIDUAIS DE INTERFACE
# ==============================================================================
@export_group("Elementos do Card (ColunaEsquerda)")
@export var label_nome: RichTextLabel
@export var icone: TextureRect
@export var label_categoria: RichTextLabel
@export var label_nivel: RichTextLabel

@export_group("Elementos do Modo Compra (ContainerCompra)")
@export var label_descricao: RichTextLabel
@export var label_bonus_pop: RichTextLabel
@export var label_bonus_infra: RichTextLabel
@export var button_comprar: Button

@export_group("Elementos do Modo Upgrade (ContainerUpgrade)")
@export var label_disc: RichTextLabel        # Descrição curta no modo de aprimoramento
@export var button_aprimorar: Button
@export var button_detalhes: Button

@export_group("Elementos de Stats e Gerais")
@export var label_ganhos: RichTextLabel
@export var barra_infra: ProgressBar         # Barra de progresso visual da integridade/durabilidade
@export var button_fechar: Button

# ==============================================================================
# SINAIS E VARIÁVEIS INTERNAS
# ==============================================================================
# Sinais emitidos para delegar as ações de jogo para o script gerenciador (main_game.gd)
# Isso mantêm a interface desvinculada (decoupled) da lógica de regras de negócio
signal compra_confirmada(nome_edificio: String)
signal aprimoramento_confirmado(nome_edificio: String)
signal detalhes_solicitados(nome_edificio: String)

# Cache local de textos para alimentar o painel secundário de detalhes
var _texto_detalhes_atual: String = ""
var _nome_predio_atual: String = ""


func _ready() -> void:
	# REGRA CRUCIAL: Define que este nó continuará processando mesmo quando a árvore
	# do jogo estiver pausada (get_tree().paused = true). Sem isso, as animações e
	# cliques de botão da interface congelariam junto com o jogo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_configurar_propriedades_texto()
	_resetar_tudo()
	hide()
	_conectar_botoes()


func _input(event: InputEvent) -> void:
	# Trata o atalho de cancelamento (tecla ESC ou botão Voltar no controle/mobile)
	if visible and event.is_action_pressed("ui_cancel"):
		# Se a sub-janela de detalhes estiver aberta, fecha apenas ela primeiro
		if painel_detalhes and painel_detalhes.visible:
			fechar_detalhes()
		else:
			# Caso contrário, fecha a janela principal de compras
			fechar_janela()


# Configuração responsiva de texto: ajusta a quebra automática de linha e expansão vertical
func _configurar_propriedades_texto() -> void:
	var labels = [
		label_nome, label_categoria, label_nivel, label_descricao, 
		label_disc, label_ganhos, label_titulo_detalhes, label_texto_detalhes
	]
	for l in labels:
		if l:
			# Garante que a altura do nó do texto se adapte dinamicamente à quantidade de caracteres
			l.fit_content = true
			# Habilita quebra de linha inteligente por palavras completas
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Garante uma dimensão mínima para o painel de detalhes não colapsar em 0px
	if painel_detalhes and painel_detalhes.custom_minimum_size == Vector2.ZERO:
		painel_detalhes.custom_minimum_size = Vector2(380, 200)


# ==============================================================================
# LIMPEZA E RESET DE ESTADO
# ==============================================================================
# Oculta todos os componentes condicionais antes de repopular a janela.
# Isso evita vazamento de dados visuais (UI Bleeding) entre seleções de prédios diferentes.
func _resetar_tudo() -> void:
	if coluna_stats: coluna_stats.visible = false
	if container_compra: container_compra.visible = false
	if container_upgrade: container_upgrade.visible = false
	if painel_detalhes: painel_detalhes.visible = false
	
	if label_categoria: label_categoria.visible = false
	if label_nivel: label_nivel.visible = false
	
	if label_descricao: label_descricao.visible = false
	if label_disc: label_disc.visible = false
	if label_bonus_pop: label_bonus_pop.visible = false
	if label_bonus_infra: label_bonus_infra.visible = false
	if label_ganhos: label_ganhos.visible = false
	if barra_infra: barra_infra.visible = false
	if button_comprar: button_comprar.visible = false
	
	if button_aprimorar: 
		button_aprimorar.visible = false
		button_aprimorar.disabled = false
		
	if button_detalhes: button_detalhes.visible = false


# ==============================================================================
# CONFIGURAÇÃO: MODO COMPRA
# ==============================================================================
# Prepara e exibe a interface formatada para a aquisição de um novo edifício em lote vago
func abrir_modo_compra(
	nome: String, 
	categoria: String, 
	descricao: String, 
	bonus_pop: int, 
	bonus_infra: int, 
	preco: float, 
	textura_predio: Texture2D
) -> void:
	
	_resetar_tudo()
	
	# Habilita apenas os containers pertencentes ao fluxo de compra
	if container_compra: container_compra.visible = true
	if label_categoria: label_categoria.visible = true
	if label_bonus_pop: label_bonus_pop.visible = true
	if label_bonus_infra: label_bonus_infra.visible = true
	if button_comprar: button_comprar.visible = true
	
	# Exibe a descrição apenas se houver texto configurado
	if label_descricao:
		var tem_desc = descricao.strip_edges() != ""
		label_descricao.visible = tem_desc
		if tem_desc:
			label_descricao.text = "[center]" + descricao + "[/center]"

	# Aplicação de BBCode para formatação de cores e estilo no texto
	if label_nome: label_nome.text = "[center][b][color=purple]" + nome.to_upper() + "[/color][/b][/center]"
	if label_categoria: label_categoria.text = "[center][b][color=lightblue]" + categoria.to_upper() + "[/color][/b][/center]"
	if label_bonus_pop: label_bonus_pop.text = "[center][b][color=green]+ " + str(bonus_pop) + " Popularidade[/color][/b][/center]"
	if label_bonus_infra: label_bonus_infra.text = "[center][b][color=orange]+ " + str(bonus_infra) + " Infraestrutura[/color][/b][/center]"
	if button_comprar: button_comprar.text = "COMPRAR\nR$ " + _formatar_numero(preco)
	if icone and textura_predio: icone.texture = textura_predio
	
	# REORGANIZAÇÃO DE COLUNAS:
	# Alinha o layout para 2 colunas no modo compra: [Esquerda (Card) | Direita (Ações)]
	if colunas_grid and coluna_esquerda and coluna_direita:
		colunas_grid.move_child(coluna_esquerda, 0)
		colunas_grid.move_child(coluna_direita, 1)
	
	_animar_popin()


# ==============================================================================
# CONFIGURAÇÃO: MODO UPGRADE E DETALHES
# ==============================================================================
# Prepara a interface para exibir métricas de um prédio já existente e gerenciar aprimoramentos
func abrir_modo_upgrade(
	nome: String, 
	nivel: int, 
	ganhos: float, 
	durabilidade_pct: float, 
	preco_upgrade: float, 
	textura_predio: Texture2D,
	descricao: String = "",
	texto_detalhes: String = "",
	pode_aprimorar: bool = true
) -> void:
	
	_resetar_tudo()
	
	# Armazena os textos do edifício atual para consumo no painel de detalhes
	_nome_predio_atual = nome
	_texto_detalhes_atual = texto_detalhes
	
	# Habilita os containers pertinentes ao modo upgrade/estatísticas
	if coluna_stats: coluna_stats.visible = true
	if container_upgrade: container_upgrade.visible = true
	if label_nivel: label_nivel.visible = true
	if label_ganhos: label_ganhos.visible = true
	if barra_infra: barra_infra.visible = true
	
	# Exibe Descrição Curta
	if label_disc:
		var tem_desc = descricao.strip_edges() != ""
		label_disc.visible = tem_desc
		if tem_desc:
			label_disc.text = "[center]" + descricao + "[/center]"

	# Exibe o Botão de Detalhes caso exista texto de lore/informação estendida
	if button_detalhes:
		var tem_detalhes = texto_detalhes.strip_edges() != ""
		button_detalhes.visible = tem_detalhes
		if tem_detalhes:
			button_detalhes.text = "DETALHES"

	# Gerencia os estados do botão de aprimorar (Bloqueado se atingir o Nível Máximo)
	if button_aprimorar: 
		button_aprimorar.visible = true
		if pode_aprimorar:
			button_aprimorar.disabled = false
			button_aprimorar.text = "APRIMORAR\nR$ " + _formatar_numero(preco_upgrade)
		else:
			button_aprimorar.disabled = true
			button_aprimorar.text = "NÍVEL MÁXIMO"
	
	if label_nome: label_nome.text = "[center][b][color=red]" + nome.to_upper() + "[/color][/b][/center]"
	if label_nivel: label_nivel.text = "[center][b][color=lightblue]NÍVEL: " + str(nivel) + "[/color][/b][/center]"
	if label_ganhos: label_ganhos.text = "[center]GANHOS\n[color=green]R$ " + _formatar_numero(ganhos) + "[/color][/center]"
	
	# Atualiza o valor e o Tooltip explicativo da barra de durabilidade
	if barra_infra: 
		barra_infra.value = durabilidade_pct
		barra_infra.tooltip_text = "Integridade do Prédio: " + str(int(durabilidade_pct)) + "%"
		
	if icone and textura_predio: icone.texture = textura_predio
	
	# REORGANIZAÇÃO DE COLUNAS:
	# Reordena para 3 colunas lado a lado: [Stats/Barra | Card do Prédio | Botões/Descrições]
	if colunas_grid and coluna_stats and coluna_esquerda and coluna_direita:
		colunas_grid.move_child(coluna_stats, 0)
		colunas_grid.move_child(coluna_esquerda, 1)
		colunas_grid.move_child(coluna_direita, 2)
	
	_animar_popin()


# ==============================================================================
# PAINEL SECUNDÁRIO (POP-IN DE DETALHES)
# ==============================================================================
# Exibe a caixa de diálogo secundária com animação de escala independente
func _abrir_detalhes() -> void:
	if not painel_detalhes: return
	
	if label_titulo_detalhes:
		label_titulo_detalhes.text = "[center][b][color=gold]" + _nome_predio_atual.to_upper() + " - DETALHES[/color][/b][/center]"
		
	if label_texto_detalhes:
		label_texto_detalhes.text = "[center][color=#ffffff]" + _texto_detalhes_atual + "[/color][/center]"
		
	painel_detalhes.show()
	# Define o ponto de pivô no centro exato da janela para garantir escala simétrica
	painel_detalhes.pivot_offset = painel_detalhes.size / 2.0
	painel_detalhes.scale = Vector2.ZERO
	
	# Animação suave de entrada usando curva elástica (TRANS_BACK)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(painel_detalhes, "scale", Vector2.ONE, 0.2)


# Esconde o painel secundário com animação inversa antes de desativar o nó
func fechar_detalhes() -> void:
	if not painel_detalhes: return
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(painel_detalhes, "scale", Vector2.ZERO, 0.12)
	# Garante que hide() só é chamado após a animação de encolhimento ser concluída
	tween.tween_callback(func():
		painel_detalhes.hide()
	)


# ==============================================================================
# GERENCIAMENTO DE PAUSA E ANIMAÇÕES PRINCIPAIS
# ==============================================================================
# Abre a janela principal, aplica o congelamento do jogo e dispara a animação Pop-in
func _animar_popin() -> void:
	# Congela a lógica e físicas do jogo ao fundo (Câmeras, NPCs, Timers)
	get_tree().paused = true
	show()
	
	if painel_central:
		# Centraliza o pivô para animação a partir do centro da janela
		painel_central.pivot_offset = painel_central.size / 2.0
		painel_central.scale = Vector2.ZERO
		
		# Animação elástica de abertura
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(painel_central, "scale", Vector2.ONE, 0.25)


# Fecha a janela principal, descongela o jogo e reseta o estado da interface
func fechar_janela() -> void:
	_resetar_global_construcoes()
	
	if painel_central:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(painel_central, "scale", Vector2.ZERO, 0.15)
		tween.tween_callback(func():
			hide()
			_resetar_tudo()
			# Descongela a árvore do jogo de volta ao estado normal
			get_tree().paused = false
		)
	else:
		hide()
		_resetar_tudo()
		get_tree().paused = false


# Reseta flags temporárias de construção no Autoload Global, caso existam
func _resetar_global_construcoes() -> void:
	if typeof(Global) != TYPE_NIL and "construcoes" in Global:
		for chave in Global.construcoes:
			Global.construcoes[chave] = false


# ==============================================================================
# CONEXÃO DE SINAIS E AÇÕES DOS BOTÕES
# ==============================================================================
# Conecta os eventos de clique dos botões nativos às funções do script com proteção contra duplicatas
func _conectar_botoes() -> void:
	if button_comprar and not button_comprar.pressed.is_connected(_on_comprar_pressed):
		button_comprar.pressed.connect(_on_comprar_pressed)
		
	if button_aprimorar and not button_aprimorar.pressed.is_connected(_on_aprimoramento_pressed):
		button_aprimorar.pressed.connect(_on_aprimoramento_pressed)
		
	if button_detalhes and not button_detalhes.pressed.is_connected(_on_detalhes_pressed):
		button_detalhes.pressed.connect(_on_detalhes_pressed)
		
	if button_fechar and not button_fechar.pressed.is_connected(fechar_janela):
		button_fechar.pressed.connect(fechar_janela)
		
	if button_fechar_detalhes and not button_fechar_detalhes.pressed.is_connected(fechar_detalhes):
		button_fechar_detalhes.pressed.connect(fechar_detalhes)


# Dispara o sinal de compra e encerra a janela
func _on_comprar_pressed() -> void:
	compra_confirmada.emit(label_nome.get_parsed_text())
	fechar_janela()


# Dispara o sinal de aprimoramento e encerra a janela
func _on_aprimoramento_pressed() -> void:
	aprimoramento_confirmado.emit(label_nome.get_parsed_text())
	fechar_janela()


# Solicita a abertura do painel interno de detalhes
func _on_detalhes_pressed() -> void:
	detalhes_solicitados.emit(label_nome.get_parsed_text())
	_abrir_detalhes()


# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================
# Algoritmo de formatação numérica de moedas: Insere pontos a cada 3 dígitos (Ex: 150000 -> 150.000)
func _formatar_numero(valor: float) -> String:
	var texto = str(int(valor))
	var resultado = ""
	var contador = 0
	
	# Itera sobre o número de trás para a frente inserindo a pontuação de milhar
	for i in range(texto.length() - 1, -1, -1):
		if contador > 0 and contador % 3 == 0:
			resultado = "." + resultado
		resultado = texto[i] + resultado
		contador += 1
		
	return resultado
