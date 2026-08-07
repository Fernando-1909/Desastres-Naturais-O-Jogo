extends CanvasLayer
class_name TelaCompras

signal compra_confirmada(id_edificio: String, variacao_index: int)
signal aprimoramento_confirmado(id_edificio: String)

@export_group("Cenas e Preloads")
@export var item_construcao_scene: PackedScene = preload("res://Jogo principal/UI/item_construcao.tscn")

@export_group("Painéis Principais")
@onready var overlay_fundo: Control = $OverlayFundo
@onready var painel_selecao: Control = $PainelSelecao
@onready var painel_central: Control = $PainelCentral
@onready var painel_detalhes: Control = $PainelDetalhes

@export_group("Nós de Seleção (Catálogo)")
@onready var container_categorias: VBoxContainer = $PainelSelecao/MargemSelecao/VBoxSelecao/ScrollContainer/ContainerCategorias
@onready var button_fechar_selecao: Button = $PainelSelecao/ButtonFecharSelecao

@export_group("Nós do Painel Central - Coluna Stats")
@onready var coluna_stats: Control = $PainelCentral/MargemInterna/ColunasGrid/ColunaStats
@onready var label_ganhos: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaStats/LabelGanhos
@onready var barra_infra: ProgressBar = $PainelCentral/MargemInterna/ColunasGrid/ColunaStats/BarraInfra

@export_group("Nós do Painel Central - Coluna Esquerda")
@onready var label_nome: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaEsquerda/LabelNome
@onready var icone: TextureRect = $PainelCentral/MargemInterna/ColunasGrid/ColunaEsquerda/Icone
@onready var label_categoria: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaEsquerda/LabelCategoria
@onready var label_nivel: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaEsquerda/LabelNivel

@export_group("Nós do Painel Central - Coluna Direita (Compra)")
@onready var container_compra: Control = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerCompra
@onready var label_descricao: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerCompra/LabelDescricao
@onready var label_bonus_pop: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerCompra/LabelBonusPop
@onready var label_bonus_infra: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerCompra/LabelBonusInfra
@onready var button_comprar: Button = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerCompra/ButtonComprar

@export_group("Nós do Painel Central - Coluna Direita (Upgrade)")
@onready var container_upgrade: Control = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerUpgrade
@onready var label_disc: RichTextLabel = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerUpgrade/LabelDisc
@onready var button_aprimorar: Button = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerUpgrade/ButtonAprimorar
@onready var button_detalhes: Button = $PainelCentral/MargemInterna/ColunasGrid/ColunaDireita/ContainerUpgrade/ButtonDetalhes

@export_group("Nós do Painel Central - Geral")
@onready var button_fechar_central: Button = $PainelCentral/ButtonFechar

@export_group("Nós do Painel Detalhes")
@onready var label_titulo_detalhes: RichTextLabel = $PainelDetalhes/MargemDetalhes/VBoxDetalhes/LabelTituloDetalhes
@onready var label_texto_detalhes: RichTextLabel = $PainelDetalhes/MargemDetalhes/VBoxDetalhes/LabelTextoDetalhes
@onready var button_fechar_detalhes: Button = $PainelDetalhes/MargemDetalhes/VBoxDetalhes/ButtonFecharDetalhes

# Controle interno de navegação
var _edificio_atual_id: String = ""
var _variacao_atual_index: int = 0
var _veio_da_selecao: bool = false
var _texto_detalhes_atual: String = ""


func _ready() -> void:
	fechar_tudo()

	if button_fechar_selecao:
		button_fechar_selecao.pressed.connect(fechar_tudo)
	if button_fechar_central:
		button_fechar_central.pressed.connect(_on_fechar_central_pressed)
	if button_fechar_detalhes:
		button_fechar_detalhes.pressed.connect(_on_fechar_detalhes_pressed)
	if button_comprar:
		button_comprar.pressed.connect(_on_comprar_pressed)
	if button_aprimorar:
		button_aprimorar.pressed.connect(_on_aprimorar_pressed)
	if button_detalhes:
		button_detalhes.pressed.connect(_on_detalhes_pressed)


# ==============================================================================
# MODO 1: CATÁLOGO DE SELEÇÃO DE EDIFÍCIOS (COM CABEÇALHO E FILTRO DE PNG)
# ==============================================================================
func abrir_modo_selecao(lista_edificios: Array[BuildingData]) -> void:
	get_tree().paused = true
	_veio_da_selecao = false
	
	visible = true
	if overlay_fundo: overlay_fundo.visible = true
	if painel_selecao: painel_selecao.visible = true
	if painel_central: painel_central.visible = false
	if painel_detalhes: painel_detalhes.visible = false

	# Limpa conteúdos anteriores
	if container_categorias:
		for child in container_categorias.get_children():
			child.queue_free()

		# 1. Agrupa os edifícios por categoria
		var categorias_map: Dictionary = {}

		for b_data in lista_edificios:
			if b_data == null: continue
			
			# FILTRO: Se não tiver nenhum PNG associado no .tres, descarta!
			if not b_data.tem_icones_validos():
				continue

			var cat_nome = b_data.categoria if b_data.categoria != "" else "Geral"
			if not categorias_map.has(cat_nome):
				categorias_map[cat_nome] = []
			
			categorias_map[cat_nome].append(b_data)

		# 2. Cria as seções visuais para cada categoria
		for cat_chave in categorias_map.keys():
			var lista_cat: Array = categorias_map[cat_chave]
			if lista_cat.size() == 0: continue

			# Título / Divisor da Categoria
			var banner_categoria = _criar_divisor_categoria(cat_chave)
			container_categorias.add_child(banner_categoria)

			# Grid container para os cards desta categoria
			var grid = GridContainer.new()
			grid.columns = 3 # Número de colunas de cards por linha
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 12)
			container_categorias.add_child(grid)

			# Instancia cards para cada variação de cada prédio da categoria
			for b_data in lista_cat:
				var qtd_variacoes = b_data.get_quantidade_variacoes()
				
				for v_idx in range(qtd_variacoes):
					var card_instance = item_construcao_scene.instantiate()
					grid.add_child(card_instance)
					
					if card_instance.has_method("configurar_card"):
						card_instance.configurar_card(b_data, v_idx)
					
					if card_instance.has_signal("card_selecionado"):
						card_instance.card_selecionado.connect(_on_card_construcao_selecionado)


func _criar_divisor_categoria(nome_categoria: String) -> Control:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	
	var texto_cat = tr(nome_categoria).to_upper()
	label.text = "[center][b]=== " + texto_cat + " ===[/b][/center]"
	return label


func _on_card_construcao_selecionado(b_data: BuildingData, variacao_index: int) -> void:
	_veio_da_selecao = true
	_variacao_atual_index = variacao_index
	abrir_modo_compra_por_dados(b_data, variacao_index)


# ==============================================================================
# MODO 2: JANELA DE CONFIRMAÇÃO DE COMPRA
# ==============================================================================
func abrir_modo_compra_por_dados(b_data: BuildingData, variacao_index: int = 0) -> void:
	_variacao_atual_index = variacao_index
	var tex = b_data.get_icone_variacao(variacao_index)
	var id_ou_nome = b_data.id if b_data.id != "" else b_data.nome
	
	abrir_modo_compra(
		id_ou_nome,
		b_data.categoria,
		b_data.descricao_curta,
		b_data.bonus_populacao,
		b_data.custo_base,
		tex,
		b_data.texto_detalhes
	)


func abrir_modo_compra(id_or_nome: String, categoria: String, descricao: String, bonus_pop: int, custo: int, tex: Texture2D, texto_detalhes: String = "") -> void:
	get_tree().paused = true
	_edificio_atual_id = id_or_nome
	_texto_detalhes_atual = texto_detalhes
	
	visible = true
	if overlay_fundo: overlay_fundo.visible = true
	if painel_selecao: painel_selecao.visible = false
	if painel_central: painel_central.visible = true
	if painel_detalhes: painel_detalhes.visible = false

	if container_compra: container_compra.visible = true
	if container_upgrade: container_upgrade.visible = false
	if coluna_stats: coluna_stats.visible = false

	if label_nome: label_nome.text = "[center]" + tr(id_or_nome) + "[/center]"
	if label_categoria: label_categoria.text = tr(categoria)
	if label_nivel: label_nivel.text = ""
	if icone and tex: icone.texture = tex

	if label_descricao: label_descricao.text = tr(descricao)
	if label_bonus_pop: label_bonus_pop.text = tr("HUD_POPULARIDADE") + ": +" + str(bonus_pop)
	if label_bonus_infra: label_bonus_infra.text = ""

	_definir_texto_botao(button_comprar, tr("UI_COMPRAR") + " ($" + str(custo) + ")")


# ==============================================================================
# MODO 3: UPGRADE
# ==============================================================================
func abrir_modo_upgrade(nome_edificio: String, nivel: int, ganhos: int, durabilidade_pct: float, custo_upgrade: int, tex: Texture2D, descricao: String, texto_detalhes: String, pode_aprimorar: bool) -> void:
	get_tree().paused = true
	_veio_da_selecao = false
	_edificio_atual_id = nome_edificio
	_texto_detalhes_atual = texto_detalhes
	
	visible = true
	if overlay_fundo: overlay_fundo.visible = true
	if painel_selecao: painel_selecao.visible = false
	if painel_central: painel_central.visible = true
	if painel_detalhes: painel_detalhes.visible = false

	if container_compra: container_compra.visible = false
	if container_upgrade: container_upgrade.visible = true
	if coluna_stats: coluna_stats.visible = true

	if label_ganhos: label_ganhos.text = tr("UI_GANHOS") + ": $" + str(ganhos)
	if barra_infra: barra_infra.value = durabilidade_pct

	if label_nome: label_nome.text = "[center]" + tr(nome_edificio) + "[/center]"
	if label_categoria: label_categoria.text = ""
	if label_nivel: label_nivel.text = tr("UI_NIVEL") + ": " + str(nivel)
	if icone and tex: icone.texture = tex

	if label_disc: label_disc.text = tr(descricao)

	if button_aprimorar:
		button_aprimorar.disabled = not pode_aprimorar
		if pode_aprimorar:
			_definir_texto_botao(button_aprimorar, tr("UI_APRIMORAR") + " ($" + str(custo_upgrade) + ")")
		else:
			_definir_texto_botao(button_aprimorar, tr("UI_NIVEL_MAXIMO"))

	_definir_texto_botao(button_detalhes, tr("UI_DETALHES"))


# ==============================================================================
# AÇÕES E NAVEGAÇÃO
# ==============================================================================
func _on_comprar_pressed() -> void:
	compra_confirmada.emit(_edificio_atual_id, _variacao_atual_index)
	fechar_tudo()

func _on_aprimorar_pressed() -> void:
	aprimoramento_confirmado.emit(_edificio_atual_id)
	fechar_tudo()

func _on_detalhes_pressed() -> void:
	if painel_detalhes:
		if label_titulo_detalhes:
			label_titulo_detalhes.text = "[center]" + tr(_edificio_atual_id) + "[/center]"
		if label_texto_detalhes:
			label_texto_detalhes.text = tr(_texto_detalhes_atual)
		painel_detalhes.visible = true

func _on_fechar_detalhes_pressed() -> void:
	if painel_detalhes:
		painel_detalhes.visible = false

func _on_fechar_central_pressed() -> void:
	if _veio_da_selecao:
		if painel_central: painel_central.visible = false
		if painel_selecao: painel_selecao.visible = true
	else:
		fechar_tudo()

func fechar_tudo() -> void:
	get_tree().paused = false
	visible = false
	if overlay_fundo: overlay_fundo.visible = false
	if painel_selecao: painel_selecao.visible = false
	if painel_central: painel_central.visible = false
	if painel_detalhes: painel_detalhes.visible = false


func _definir_texto_botao(botao: Button, texto: String) -> void:
	if botao == null: return
	var rtl = botao.get_node_or_null("RichTextLabel") as RichTextLabel
	if rtl:
		rtl.text = "[center]" + texto + "[/center]"
	else:
		botao.text = texto
