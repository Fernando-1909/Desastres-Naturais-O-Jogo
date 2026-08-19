extends CanvasLayer
class_name TelaCompras

signal compra_confirmada(id_edificio: String, variacao_index: int)
signal aprimoramento_confirmado(id_edificio: String)

## Lista oficial de categorias aceitas no jogo
const CATEGORIAS_ACEITAS: Array[String] = [
	"Residencial",
	"Comercial",
	"Industrial",
	"Serviços",
	"Infraestrutura",
	"Lazer",
	"Decoração",
	"Especial"
]

@export_group("Configurações do TileSet")
## Opcional: Arraste seu TileSet aqui se preferir, senão o script busca sozinho na cena.
@export var tile_set_override: TileSet

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
@onready var button_fechar_detalhes: Button = $PainelDetalhes/ButtonFecharDetalhes


# Controle interno de navegação
var _edificio_atual_id: String = ""
var _variacao_atual_index: int = 0
var _veio_da_selecao: bool = false
var _texto_detalhes_atual: String = ""


func _ready() -> void:
	fechar_tudo()

	if button_fechar_selecao and not button_fechar_selecao.pressed.is_connected(fechar_tudo):
		button_fechar_selecao.pressed.connect(fechar_tudo)
	if button_fechar_central and not button_fechar_central.pressed.is_connected(_on_fechar_central_pressed):
		button_fechar_central.pressed.connect(_on_fechar_central_pressed)
	if button_fechar_detalhes and not button_fechar_detalhes.pressed.is_connected(_on_fechar_detalhes_pressed):
		button_fechar_detalhes.pressed.connect(_on_fechar_detalhes_pressed)
	if button_comprar and not button_comprar.pressed.is_connected(_on_comprar_pressed):
		button_comprar.pressed.connect(_on_comprar_pressed)
	if button_aprimorar and not button_aprimorar.pressed.is_connected(_on_aprimorar_pressed):
		button_aprimorar.pressed.connect(_on_aprimorar_pressed)
	if button_detalhes and not button_detalhes.pressed.is_connected(_on_detalhes_pressed):
		button_detalhes.pressed.connect(_on_detalhes_pressed)


# ==============================================================================
# MODO 1: CATÁLOGO DE SELEÇÃO DE EDIFÍCIOS (AGRUPADO POR CATEGORIAS DA WHITELIST)
# ==============================================================================
func abrir_modo_selecao(lista_edificios: Array) -> void:
	get_tree().paused = true
	_veio_da_selecao = false
	
	visible = true
	if overlay_fundo: overlay_fundo.visible = true
	if painel_selecao: painel_selecao.visible = true
	if painel_central: painel_central.visible = false
	if painel_detalhes: painel_detalhes.visible = false

	if container_categorias:
		for child in container_categorias.get_children():
			child.queue_free()

		var categorias_map: Dictionary = {}

		for item in lista_edificios:
			var b_data = item as BuildingData
			if b_data == null: continue

			var cat_nome = _obter_categoria_edificio(b_data)

			if not categorias_map.has(cat_nome):
				categorias_map[cat_nome] = []
			
			categorias_map[cat_nome].append(b_data)

		# Ordena as categorias na tela
		var chaves_ordenadas: Array = []
		for cat in CATEGORIAS_ACEITAS:
			if categorias_map.has(cat):
				chaves_ordenadas.append(cat)

		for cat_chave in categorias_map.keys():
			if not chaves_ordenadas.has(cat_chave) and cat_chave != "" and cat_chave != "Geral":
				chaves_ordenadas.append(cat_chave)

		# Itens sem categoria válida entram no final
		if categorias_map.has(""):
			chaves_ordenadas.append("")
		if categorias_map.has("Geral") and not chaves_ordenadas.has("Geral"):
			chaves_ordenadas.append("Geral")

		# Instancia os grupos e os cards
		for cat_chave in chaves_ordenadas:
			var lista_cat: Array = categorias_map[cat_chave]
			if lista_cat.size() == 0: continue

			# Só cria o banner se a categoria for válida e não for vazia/Geral
			if cat_chave != "" and cat_chave != "Geral":
				var banner_categoria = _criar_divisor_categoria(cat_chave)
				container_categorias.add_child(banner_categoria)

			var grid = GridContainer.new()
			grid.columns = 3
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_theme_constant_override("h_separation", 12)
			grid.add_theme_constant_override("v_separation", 12)
			container_categorias.add_child(grid)

			for b_data in lista_cat:
				var qtd_variacoes = 1
				if b_data.has_method("get_quantidade_variacoes"):
					qtd_variacoes = b_data.get_quantidade_variacoes()

				for v_idx in range(qtd_variacoes):
					var card_instance = item_construcao_scene.instantiate()
					grid.add_child(card_instance)
					
					if card_instance.has_method("configurar_card"):
						card_instance.configurar_card(b_data, v_idx)
					
					if card_instance.has_signal("card_selecionado"):
						if not card_instance.card_selecionado.is_connected(_on_card_construcao_selecionado):
							card_instance.card_selecionado.connect(_on_card_construcao_selecionado)


func _criar_divisor_categoria(nome_categoria: String) -> Control:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 30)
	
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
	if b_data == null:
		push_error("TelaCompras: b_data é NULO ao tentar abrir modo de compra!")
		return

	_variacao_atual_index = variacao_index
	var tex: Texture2D = null
	if b_data.has_method("get_icone_variacao"):
		tex = b_data.get_icone_variacao(variacao_index)
	elif "icone" in b_data:
		tex = b_data.icone

	# ID interno para lógica/sinais
	var id_edificio = b_data.id if ("id" in b_data and b_data.id != "") else ""
	
	# Nome visual priorizado para exibição na UI
	var nome_exibicao = b_data.nome if ("nome" in b_data and b_data.nome != "") else id_edificio

	var cat = _obter_categoria_edificio(b_data)
	var desc = b_data.descricao_curta if "descricao_curta" in b_data else ""
	var pop = b_data.bonus_populacao if "bonus_populacao" in b_data else 0
	var custo = b_data.custo_base if "custo_base" in b_data else 0
	var det = b_data.texto_detalhes if "texto_detalhes" in b_data else ""

	abrir_modo_compra(
		id_edificio,
		cat,
		desc,
		pop,
		custo,
		tex,
		det,
		nome_exibicao
	)


func abrir_modo_compra(id_or_nome: String, categoria: String, descricao: String, bonus_pop: int, custo: int, tex: Texture2D, texto_detalhes: String = "", nome_exibicao: String = "") -> void:
	get_tree().paused = true
	_edificio_atual_id = id_or_nome
	_texto_detalhes_atual = texto_detalhes
	
	# Se um nome de exibição foi informado, usa ele no título; senão usa o ID como fallback
	var titulo_final = nome_exibicao if nome_exibicao != "" else id_or_nome
	
	visible = true
	if overlay_fundo: overlay_fundo.visible = true
	if painel_selecao: painel_selecao.visible = false
	if painel_central: painel_central.visible = true
	if painel_detalhes: painel_detalhes.visible = false

	if container_compra: container_compra.visible = true
	if container_upgrade: container_upgrade.visible = false
	if coluna_stats: coluna_stats.visible = false

	if label_nome: label_nome.text = "[center]" + tr(titulo_final) + "[/center]"
	
	# Esconde/Limpa categoria se for vazia ou Geral
	if label_categoria:
		if categoria != "" and categoria != "Geral":
			label_categoria.text = tr(categoria)
		else:
			label_categoria.text = ""

	if label_nivel: label_nivel.text = ""
	if icone: icone.texture = tex

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
	if icone: icone.texture = tex

	if label_disc: label_disc.text = tr(descricao)

	if button_aprimorar:
		button_aprimorar.disabled = not pode_aprimorar
		if pode_aprimorar:
			_definir_texto_botao(button_aprimorar, tr("UI_APRIMORAR") + " ($" + str(custo_upgrade) + ")")
		else:
			_definir_texto_botao(button_aprimorar, tr("UI_NIVEL_MAXIMO"))

	_definir_texto_botao(button_detalhes, tr("UI_DETALHES"))


# ==============================================================================
# LEITURA E VALIDAÇÃO DE CATEGORIA (CUSTOM DATA TILESET -> WHITELIST)
# ==============================================================================
func _obter_categoria_edificio(b_data: BuildingData) -> String:
	if b_data == null:
		return ""

	var cat_encontrada: String = ""

	# 1. Tenta pegar a categoria informada no próprio Resource .tres (se a variável ainda existir)
	if "categoria" in b_data and b_data.categoria != null and str(b_data.categoria).strip_edges() != "":
		cat_encontrada = str(b_data.categoria).strip_edges()

	# 2. Se não houver no Resource, busca no Custom Data Layer do TileSet (usando a coordenada principal)
	if cat_encontrada == "":
		var tile_set_ref: TileSet = _obter_tileset_referencia()
		if tile_set_ref != null:
			var coords: Vector2i = Vector2i(-1, -1)
			if "tiles_atlas_coords" in b_data and b_data.tiles_atlas_coords is Array and b_data.tiles_atlas_coords.size() > 0:
				coords = b_data.tiles_atlas_coords[0]
			elif "atlas_coords" in b_data:
				coords = b_data.atlas_coords

			if coords != Vector2i(-1, -1):
				var source_id: int = 0
				if "source_id" in b_data and b_data.source_id >= 0:
					source_id = b_data.source_id

				if tile_set_ref.has_source(source_id):
					var source = tile_set_ref.get_source(source_id) as TileSetAtlasSource
					if source and source.has_tile(coords):
						var tile_data: TileData = source.get_tile_data(coords, 0)
						if tile_data != null:
							cat_encontrada = _obter_custom_data_seguro(tile_set_ref, tile_data, "categoria")
							if cat_encontrada == "":
								cat_encontrada = _obter_custom_data_seguro(tile_set_ref, tile_data, "Categoria")

	cat_encontrada = cat_encontrada.strip_edges()

	# 3. Valida se a categoria pertence à Whitelist
	if cat_encontrada != "":
		for cat_aceita in CATEGORIAS_ACEITAS:
			if cat_encontrada.to_lower() == cat_aceita.to_lower():
				return cat_aceita

	return ""


func _obter_tileset_referencia() -> TileSet:
	if tile_set_override != null:
		return tile_set_override

	var main = get_parent()
	if main:
		if "tilemap_constructions" in main and main.tilemap_constructions and main.tilemap_constructions.tile_set:
			return main.tilemap_constructions.tile_set
		elif "tile_map" in main and main.tile_map and main.tile_map.tile_set:
			return main.tile_map.tile_set
	return null


func _obter_custom_data_seguro(ts: TileSet, td: TileData, nome_camada: String) -> String:
	if ts == null or td == null:
		return ""
	if ts.has_custom_data_layer_by_name(nome_camada):
		var val = td.get_custom_data(nome_camada)
		if val != null:
			return str(val).strip_edges()
	return ""


# ==============================================================================
# AÇÕES E NAVEGAÇÃO
# ==============================================================================
func _on_comprar_pressed() -> void:
	var id_emitir = _edificio_atual_id
	var var_emitir = _variacao_atual_index
	fechar_tudo()
	compra_confirmada.emit(id_emitir, var_emitir)

func _on_aprimorar_pressed() -> void:
	var id_emitir = _edificio_atual_id
	fechar_tudo()
	aprimoramento_confirmado.emit(id_emitir)

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
		_veio_da_selecao = false
		if painel_central: painel_central.visible = false
		if painel_selecao: painel_selecao.visible = true
	else:
		fechar_tudo()

func fechar_tudo() -> void:
	_veio_da_selecao = false
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
