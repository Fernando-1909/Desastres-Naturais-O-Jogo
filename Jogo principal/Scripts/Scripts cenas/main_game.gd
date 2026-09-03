extends Node2D

# ==============================================================================
# CAMERA, HUD E NÓS DA INTERFACE
# ==============================================================================
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud
@onready var menu_pausa: MenuPausa = $MenuPausa

# REFERENCIA A TELA DE COMPRAS E AO TILEMAP (Suporta TileMapLayer e TileMap)
@onready var tela_compras: TelaCompras = $TelaCompras
@onready var tilemap_constructions: TileMapLayer = $TileMapConstructions

# REFERENCIA AOS BOTOES DE TESTE
@onready var button_teste_compra: Button = $ButtonTesteCompra
@onready var button_teste_upgrade: Button = $ButtonTesteUpgrade
@onready var button_teste_pausa: Button = $ButtonTestePausa

# ==============================================================================
# BANCO DE DADOS E INSTANCIAS DE EDIFICIOS
# ==============================================================================
@export_group("Banco de Edificios")
## Pasta onde ficam armazenados todos os seus arquivos .tres de construcoes
@export var pasta_edificios: String = "res://recursos/predios/"
## Fallback manual: se preferir arrastar arquivos .tres pelo Inspector
@export var banco_edificios_manual: Array[BuildingData] = []
@export var tile_map: TileMap

@export_group("Desastres")
## Arraste aqui o .tscn da cena de Enchente que criamos
@export var cena_enchente: PackedScene = preload("res://Jogo principal/Desastres/enchente.tscn")

@export_group("População / NPCs")
## Arraste aqui o .tscn do NPC (npc.gd)
@export var cena_npc: PackedScene = preload("res://Jogo principal/npc.tscn")
## Node onde os NPCs devem ser instanciados. IMPORTANTE: precisa ter um
## "NavigationRegion2D" como filho, porque o npc.gd usa
## get_parent().get_node("NavigationRegion2D") pra sortear destino.
@export var npc_container: Node
## Quantos pontos de população equivalem a 1 NPC visível andando pelo mapa
@export var populacao_por_npc: int = 30
## Quantas pessoas desabrigadas equivalem a 1 NPC visível andando pelo mapa
@export var desabrigados_por_npc: int = 10

# NPCs atualmente instanciados no mapa (housed + desabrigados, controlados juntos)
var _npcs_ativos: Array[Node] = []

@export_group("Banco de Missões")
## Pasta onde ficam armazenados todos os seus arquivos .tres de missões
@export var pasta_missoes: String = "res://Jogo principal/Scripts/Scripts missoes/"
## Fallback manual: se preferir arrastar arquivos .tres pelo Inspector
@export var banco_missoes_manual: Array[MissionData] = []

# Dicionario dinamico carregado automaticamente
# Chave = String (id da missao, ex: "missao1") | Valor = MissionData
var banco_missoes: Dictionary = {}

# Dicionario dinamico carregado automaticamente
# Chave = String ("casa_simples", "cons_lazer", etc) | Valor = BuildingData
var banco_edificios: Dictionary = {}

# Guarda todas as construcoes vivas no mapa
# Chave = Vector2i(x, y) | Valor = objeto BuildingInstance
var construcoes_no_mapa: Dictionary = {}

# Controle de Zonas por Tile
# Chave = Vector2i(pos_tile) | Valor = BuildingZone
var zona_por_tile: Dictionary = {}
# Chave = BuildingZone | Valor = Array[Vector2i]
var construcoes_por_zona: Dictionary = {}

# Controle do lote/tile atualmente selecionado pelo clique do jogador
var _celula_selecionada: Vector2i = Vector2i(-1, -1)
var _building_data_selecionado: BuildingData = null

# Variaveis auxiliares
var icone_temp = preload("res://icon.svg")
var freecam_enabled = false
@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")

# Controle interno de resgate
var equipes_bombeiro_ocupadas: int = 0


# ==============================================================================
# CICLO DE VIDA (READY & INPUT)
# ==============================================================================
func _ready() -> void:
	# 1. Carrega todos os .tres automaticamente da pasta e/ou array manual
	_carregar_todos_os_edificios()
	_carregar_todas_as_missoes()
	# variaveis de teste para testar no inicio
	Global.dinheiro = 1000
	Global.populacao = 10
	
	# Conecta o clique do botao diretamente a funcao toggle_pause
	if button_teste_pausa and menu_pausa:
		button_teste_pausa.pressed.connect(menu_pausa.toggle_pause)
	
	# Conecta os botoes de teste para abrir a janela (Opcao manual)
	if button_teste_compra:
		button_teste_compra.pressed.connect(_on_testar_escola_pressed)
	if button_teste_upgrade:
		button_teste_upgrade.pressed.connect(_on_testar_hospital_pressed)
	
	# Conecta os sinais enviados pela TelaCompras
	if tela_compras:
		tela_compras.compra_confirmada.connect(_on_compra_confirmada)
		tela_compras.aprimoramento_confirmado.connect(_on_aprimoramento_confirmado)
	
	if freecam_camera:
		freecam_camera.enabled = true

	# Escaneia o mapa para registrar predios que ja vieram desenhados no editor
	_escanear_mapa_inicial()
	
	print("[DEBUG-NPC] _ready: cena_npc=", cena_npc, " | npc_container=", npc_container, " | populacao_inicial=", Global.populacao)
	
	# Sorteia os NPCs iniciais de acordo com a população inicial
	_atualizar_npcs_por_populacao()


# ==============================================================================
# GERENCIAMENTO DE ZONAS DE CONSTRUÇÃO
# ==============================================================================
func _obter_zona_no_tile(pos_tile: Vector2i) -> BuildingZone:
	var pos_global = Vector2.ZERO
	if tilemap_constructions:
		pos_global = tilemap_constructions.to_global(tilemap_constructions.map_to_local(pos_tile))
	elif tile_map:
		pos_global = tile_map.to_global(tile_map.map_to_local(pos_tile))

	var zonas = get_tree().get_nodes_in_group("zonas_construcao")
	for no in zonas:
		if no is BuildingZone and no.contem_posicao_global(pos_global):
			return no
	return null


func _contar_construcoes_na_zona(zona: BuildingZone) -> int:
	if zona == null or not construcoes_por_zona.has(zona):
		return 0
	return (construcoes_por_zona[zona] as Array).size()


# ==============================================================================
# FUNCOES DE CONTAGEM SOLICITADAS PELO GERENCIADOR DE TURNOS / HUD
# ==============================================================================
func contar_casas_ativas() -> int:
	var total: int = 0
	for pos in construcoes_no_mapa.keys():
		var predio = construcoes_no_mapa[pos]
		if predio != null:
			if "durabilidade_atual" in predio:
				if predio.durabilidade_atual > 0:
					total += 1
			else:
				total += 1
	return total


func contar_construcoes_por_categoria(categoria: String = "") -> int:
	var total: int = 0
	var cat_alvo = categoria.to_lower().strip_edges()

	for pos in construcoes_no_mapa.keys():
		var predio = construcoes_no_mapa[pos]
		if predio != null and predio.data != null:
			if cat_alvo == "":
				total += 1
			else:
				var cat_predio = ""
				if "categoria" in predio.data and predio.data.categoria != null:
					cat_predio = str(predio.data.categoria).to_lower().strip_edges()

				var id_predio = ""
				if "id" in predio.data and predio.data.id != null:
					id_predio = str(predio.data.id).to_lower().strip_edges()

				if cat_predio == cat_alvo or id_predio == cat_alvo:
					total += 1

	return total


func contar_construcoes(categoria: String = "") -> int:
	return contar_construcoes_por_categoria(categoria)


# ==============================================================================
# SISTEMA DE ABRIGOS E BOMBEIROS (RESGATE)
# ==============================================================================
func obter_capacidade_total_abrigos() -> int:
	var total: int = 0
	for pos in construcoes_no_mapa.keys():
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio != null and predio.data != null and predio.durabilidade_atual > 0:
			if "capacidade_abrigo" in predio.data:
				total += predio.data.capacidade_abrigo
	return total


func obter_vagas_abrigos_disponiveis() -> int:
	var pessoas_abrigadas = 0
	if typeof(Global) != TYPE_NIL and "pessoas_abrigadas" in Global:
		pessoas_abrigadas = Global.pessoas_abrigadas
	return max(0, obter_capacidade_total_abrigos() - pessoas_abrigadas)


func obter_equipes_bombeiro_totais() -> int:
	var total: int = 0
	for pos in construcoes_no_mapa.keys():
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio != null and predio.data != null and predio.durabilidade_atual > 0:
			if "equipes_resgate" in predio.data:
				total += predio.data.equipes_resgate
	return total


func obter_equipes_bombeiro_disponiveis() -> int:
	return max(0, obter_equipes_bombeiro_totais() - equipes_bombeiro_ocupadas)


func alocar_equipe_bombeiro() -> bool:
	if obter_equipes_bombeiro_disponiveis() > 0:
		equipes_bombeiro_ocupadas += 1
		return true
	return false


func liberar_equipe_bombeiro() -> void:
	equipes_bombeiro_ocupadas = max(0, equipes_bombeiro_ocupadas - 1)


func abrigar_pessoas(quantidade: int) -> int:
	var vagas = obter_vagas_abrigos_disponiveis()
	var abrigadas = min(vagas, quantidade)
	if typeof(Global) != TYPE_NIL:
		if "pessoas_abrigadas" in Global:
			Global.pessoas_abrigadas += abrigadas
		if "pessoas_desabrigadas" in Global:
			Global.pessoas_desabrigadas = max(0, Global.pessoas_desabrigadas - abrigadas)
	return abrigadas


# ==============================================================================
# SISTEMA DE POPULAÇÃO E NPCS
# ==============================================================================
func _atualizar_npcs_por_populacao() -> void:
	print("[DEBUG-NPC] _atualizar_npcs_por_populacao chamada. cena_npc=", cena_npc, " | npc_container=", npc_container)
	
	if not cena_npc or not npc_container:
		print("[DEBUG-NPC] Abortou: cena_npc ou npc_container não estão configurados no Inspector!")
		return
	
	var desabrigadas = Global.pessoas_desabrigadas if "pessoas_desabrigadas" in Global else 0
	var quantidade_alvo = int(Global.populacao / populacao_por_npc) + int(desabrigadas / desabrigados_por_npc)
	quantidade_alvo = max(quantidade_alvo, 0)
	
	print("[DEBUG-NPC] populacao=", Global.populacao, " (/", populacao_por_npc, ") | desabrigadas=", desabrigadas, " (/", desabrigados_por_npc, ") | alvo=", quantidade_alvo, " | ativos_atualmente=", _npcs_ativos.size())
	
	while _npcs_ativos.size() < quantidade_alvo:
		var novo_npc = cena_npc.instantiate()
		npc_container.add_child(novo_npc)
		_npcs_ativos.append(novo_npc)
		print("[DEBUG-NPC] NPC instanciado! Total agora: ", _npcs_ativos.size())
	
	while _npcs_ativos.size() > quantidade_alvo:
		var npc_removido = _npcs_ativos.pop_back()
		if is_instance_valid(npc_removido):
			npc_removido.queue_free()
		print("[DEBUG-NPC] NPC removido! Total agora: ", _npcs_ativos.size())


func _verificar_casa_destruida(predio: BuildingInstance) -> void:
	print("[DEBUG-DESTRUIDA] Chamada! durabilidade=", predio.durabilidade_atual if predio else "predio nulo", " | ja_processado=", predio.moradores_desabrigados if predio else "-")
	
	if predio == null or predio.data == null:
		print("[DEBUG-DESTRUIDA] Abortou: predio ou predio.data é null.")
		return
	if predio.durabilidade_atual > 0:
		print("[DEBUG-DESTRUIDA] Abortou: durabilidade ainda > 0 (", predio.durabilidade_atual, ").")
		return
	if predio.moradores_desabrigados:
		print("[DEBUG-DESTRUIDA] Abortou: essa casa já tinha sido processada antes.")
		return
	
	predio.moradores_desabrigados = true
	
	var moradores = predio.data.bonus_populacao
	print("[DEBUG-DESTRUIDA] bonus_populacao dessa casa (", predio.data.id, ") = ", moradores)
	
	if moradores > 0:
		Global.populacao = max(0, Global.populacao - moradores)
		if "pessoas_desabrigadas" in Global:
			Global.pessoas_desabrigadas += moradores
		print("[DESASTRE] '", predio.data.nome, "' foi destruída! ", moradores, " pessoas ficaram desabrigadas. Total desabrigadas agora: ", Global.pessoas_desabrigadas)
		_atualizar_npcs_por_populacao()
	else:
		print("[DEBUG-DESTRUIDA] moradores = 0 — essa casa não tem bonus_populacao configurado no .tres, então ninguém fica desabrigado e o NPC não é atualizado!")


# ==============================================================================
# CARREGADOR AUTOMATICO DE RECURSOS (.TRES) DA PASTA INTEIRA
# ==============================================================================
func _carregar_todos_os_edificios() -> void:
	banco_edificios.clear()
	
	for b_data in banco_edificios_manual:
		if b_data and "id" in b_data and b_data.id != "":
			banco_edificios[b_data.id.to_lower()] = b_data
			print("[INFO] Edificio (manual) registrado: ", b_data.id)

	if DirAccess.dir_exists_absolute(pasta_edificios):
		var dir = DirAccess.open(pasta_edificios)
		if dir:
			dir.list_dir_begin()
			var nome_arquivo = dir.get_next()
			
			while nome_arquivo != "":
				if not dir.current_is_dir():
					var nome_limpo = nome_arquivo.replace(".remap", "")
					if nome_limpo.ends_with(".tres"):
						var caminho_completo = pasta_edificios.path_join(nome_limpo)
						var recurso = load(caminho_completo) as BuildingData
						if recurso and "id" in recurso and recurso.id != "":
							banco_edificios[recurso.id.to_lower()] = recurso
							print("[INFO] Edificio (automatico) carregado: ", recurso.id)
				nome_arquivo = dir.get_next()
			dir.list_dir_end()
	else:
		print("[AVISO] Pasta de edificios '", pasta_edificios, "' nao encontrada no projeto!")


# ==============================================================================
# CARREGADOR AUTOMATICO DE MISSOES (.TRES) DA PASTA INTEIRA
# ==============================================================================
func _carregar_todas_as_missoes() -> void:
	banco_missoes.clear()
	
	for m_data in banco_missoes_manual:
		if m_data and m_data.id != "":
			banco_missoes[m_data.id.to_lower()] = m_data
			print("[INFO] Missao (manual) registrada: ", m_data.id)
	
	if DirAccess.dir_exists_absolute(pasta_missoes):
		var dir = DirAccess.open(pasta_missoes)
		if dir:
			dir.list_dir_begin()
			var nome_arquivo = dir.get_next()
			
			while nome_arquivo != "":
				if not dir.current_is_dir():
					var nome_limpo = nome_arquivo.replace(".remap", "")
					if nome_limpo.ends_with(".tres"):
						var caminho_completo = pasta_missoes.path_join(nome_limpo)
						var recurso = load(caminho_completo) as MissionData
						if recurso and recurso.id != "":
							banco_missoes[recurso.id.to_lower()] = recurso
							print("[INFO] Missao (automatica) carregada: ", recurso.id)
				nome_arquivo = dir.get_next()
			dir.list_dir_end()
	else:
		print("[AVISO] Pasta de missoes '", pasta_missoes, "' nao encontrada no projeto!")


# ==============================================================================
# LEITURA DE CLIQUES NO MAPA
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D and _celula_selecionada in construcoes_no_mapa:
			var predio: BuildingInstance = construcoes_no_mapa[_celula_selecionada]
			if predio:
				predio.durabilidade_atual = max(0.0, predio.durabilidade_atual - 25.0)
				print("[DEBUG] Dano aplicado na casa ", _celula_selecionada, "! Nova vida: ", predio.durabilidade_atual, "/", predio.data.durabilidade_maxima)
				_verificar_casa_destruida(predio)
				
				if tela_compras and tela_compras.visible:
					_abrir_modo_upgrade_instancia(predio)
			return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_tree().paused:
			if tilemap_constructions:
				var pos_local = tilemap_constructions.get_local_mouse_position()
				var pos_tile: Vector2i = tilemap_constructions.local_to_map(pos_local)
				_processar_clique_no_tile(pos_tile)
			elif tile_map:
				var pos_local = tile_map.get_local_mouse_position()
				var pos_tile: Vector2i = tile_map.local_to_map(pos_local)
				_processar_clique_no_tile(pos_tile)


# ==============================================================================
# GERENCIADOR DE CLIQUE NOS TILES (COMPRA VS UPGRADE/DETALHES)
# ==============================================================================
func _processar_clique_no_tile(pos_tile: Vector2i) -> void:
	if not tela_compras: return
	_celula_selecionada = pos_tile

	# 1. Se já existe uma construção viva salva na memória -> Modo Upgrade / Detalhes
	if construcoes_no_mapa.has(pos_tile) and construcoes_no_mapa[pos_tile] != null:
		var predio_existente: BuildingInstance = construcoes_no_mapa[pos_tile]
		_abrir_modo_upgrade_instancia(predio_existente)
		return

	# 2. Busca o TileData
	var tile_data: TileData = null
	if tilemap_constructions:
		tile_data = tilemap_constructions.get_cell_tile_data(pos_tile)
	elif tile_map:
		tile_data = tile_map.get_cell_tile_data(0, pos_tile)

	if tile_data == null: return

	# 3. Lê as Custom Data Layers 'building_id'
	var building_id_custom = ""
	var raw_custom_id = tile_data.get_custom_data("building_id")
	if raw_custom_id != null:
		building_id_custom = str(raw_custom_id).strip_edges().to_lower()

	# --------------------------------------------------------------------------
	# CASO TERRENO VAZIO -> ABRE O CATÁLOGO FILTRADO POR ZONA
	# --------------------------------------------------------------------------
	if building_id_custom == "terreno_vazio" or building_id_custom == "":
		var zona_atual = _obter_zona_no_tile(pos_tile)
		var lista_opcoes = _obter_todos_edificios_disponiveis()
		var total_na_zona = _contar_construcoes_na_zona(zona_atual)

		if zona_atual != null:
			tela_compras.abrir_loja_com_zona(zona_atual, lista_opcoes, total_na_zona)
		else:
			tela_compras.abrir_modo_selecao(lista_opcoes)
		return

	# --------------------------------------------------------------------------
	# CASO OUTRO PRÉDIO PRÉ-DEFINIDO (Ex: Prefeitura colocada previamente)
	# --------------------------------------------------------------------------
	var b_data: BuildingData = _buscar_data_por_id(building_id_custom)
	if b_data != null:
		_building_data_selecionado = b_data
		_abrir_modo_compra_para_dados(b_data, 0)
	else:
		var zona_atual = _obter_zona_no_tile(pos_tile)
		var lista_opcoes = _obter_todos_edificios_disponiveis()
		var total_na_zona = _contar_construcoes_na_zona(zona_atual)

		if zona_atual != null:
			tela_compras.abrir_loja_com_zona(zona_atual, lista_opcoes, total_na_zona)
		else:
			tela_compras.abrir_modo_selecao(lista_opcoes)


# ==============================================================================
# CARREGAMENTO DINÂMICO DE EDIFÍCIOS PARA A LOJA
# ==============================================================================
func _eh_edificio_permitido_na_loja(b_data: BuildingData) -> bool:
	if b_data == null:
		return false
	
	var id_limpo = str(b_data.id).to_lower().strip_edges() if "id" in b_data and b_data.id != null else ""
	var nome_arquivo = b_data.resource_path.get_file().to_lower().strip_edges()
	
	if id_limpo == "prefeitura" or nome_arquivo == "prefeitura.tres":
		return false
		
	return true


func _obter_todos_edificios_disponiveis() -> Array[BuildingData]:
	var lista: Array[BuildingData] = []
	for b_data in banco_edificios.values():
		if _eh_edificio_permitido_na_loja(b_data):
			lista.append(b_data)
	return lista


func _obter_edificios_por_categoria(categoria_alvo: String = "") -> Array[BuildingData]:
	var lista: Array[BuildingData] = []
	var cat_limpa = categoria_alvo.to_lower().strip_edges()

	for b_data in banco_edificios.values():
		if not _eh_edificio_permitido_na_loja(b_data):
			continue

		var cat_bdata = ""
		if "categoria" in b_data and b_data.categoria != null:
			cat_bdata = str(b_data.categoria).to_lower().strip_edges()

		if cat_limpa != "" and cat_limpa != "terreno_vazio":
			if cat_bdata == cat_limpa:
				lista.append(b_data)
		else:
			lista.append(b_data)

	if lista.size() == 0:
		return _obter_todos_edificios_disponiveis()

	return lista


# ==============================================================================
# CONFIRMACAO DE ACOES DA TELA DE COMPRAS
# ==============================================================================
func _on_compra_confirmada(nome_ou_id_edificio: String, variacao_index: int = 0) -> void:
	if _celula_selecionada == Vector2i(-1, -1):
		print("[ERRO] Nenhuma celula selecionada para compra.")
		return

	var b_data = _buscar_data_por_id(nome_ou_id_edificio)
	if not b_data:
		print("[ERRO] Edificio nao encontrado no banco de dados para: ", nome_ou_id_edificio)
		return

	# 1. Validacao de Recursos
	if Global.dinheiro < b_data.custo_base:
		print("[ERRO] Dinheiro insuficiente para comprar ", b_data.nome)
		return

	# 2. Transacao
	Global.dinheiro -= b_data.custo_base
	
	if b_data.bonus_populacao > 0:
		Global.populacao += b_data.bonus_populacao
		_atualizar_npcs_por_populacao()

	# 3. Registra a nova instancia na memoria do mapa
	var nova_instancia = BuildingInstance.new(b_data, _celula_selecionada)
	if "variacao_index" in nova_instancia:
		nova_instancia.variacao_index = variacao_index
	construcoes_no_mapa[_celula_selecionada] = nova_instancia

	# --- REGISTRO NA ZONA ---
	var zona_atual = _obter_zona_no_tile(_celula_selecionada)
	if zona_atual:
		zona_por_tile[_celula_selecionada] = zona_atual
		if not construcoes_por_zona.has(zona_atual):
			construcoes_por_zona[zona_atual] = []
		if not (construcoes_por_zona[zona_atual] as Array).has(_celula_selecionada):
			(construcoes_por_zona[zona_atual] as Array).append(_celula_selecionada)

	# 4. Obtem a coordenada atlas exata da variação escolhida
	var novas_coords_atlas: Vector2i = Vector2i(-1, -1)
	if b_data.has_method("get_atlas_coord_para_construir"):
		novas_coords_atlas = b_data.get_atlas_coord_para_construir(variacao_index)
	elif "tiles_atlas_coords" in b_data and b_data.tiles_atlas_coords is Array and b_data.tiles_atlas_coords.size() > 0:
		var idx = min(variacao_index, b_data.tiles_atlas_coords.size() - 1)
		novas_coords_atlas = b_data.tiles_atlas_coords[idx]

	# 5. Descobre o source_id de forma segura
	var source_id: int = -1
	if "source_id" in b_data and b_data.source_id >= 0:
		source_id = b_data.source_id
	else:
		if tilemap_constructions:
			source_id = tilemap_constructions.get_cell_source_id(_celula_selecionada)
		elif tile_map:
			source_id = tile_map.get_cell_source_id(0, _celula_selecionada)

		if source_id == -1:
			var ts: TileSet = null
			if tilemap_constructions and tilemap_constructions.tile_set:
				ts = tilemap_constructions.tile_set
			elif tile_map and tile_map.tile_set:
				ts = tile_map.tile_set

			if ts and ts.get_source_count() > 0:
				source_id = ts.get_source_id(0)
			else:
				source_id = 0

	# 6. Troca o tile no mapa
	if novas_coords_atlas != Vector2i(-1, -1):
		if tilemap_constructions:
			tilemap_constructions.set_cell(_celula_selecionada, source_id, novas_coords_atlas)
		elif tile_map:
			tile_map.set_cell(0, _celula_selecionada, source_id, novas_coords_atlas)
		print("[INFO] ", b_data.nome, " (Variação ", variacao_index, ") construido com sucesso em ", _celula_selecionada)
	else:
		print("[AVISO] Nenhuma coordenada de atlas encontrada no recurso para ", b_data.nome)


func _on_aprimoramento_confirmado(nome_ou_id_edificio: String) -> void:
	if _celula_selecionada == Vector2i(-1, -1): return
	if not construcoes_no_mapa.has(_celula_selecionada): return
	
	var predio: BuildingInstance = construcoes_no_mapa[_celula_selecionada]
	var custo = predio.get_custo_upgrade()
	
	if Global.dinheiro >= custo:
		Global.dinheiro -= custo
		predio.nivel_atual += 1
		print("[INFO] ", predio.data.nome, " aprimorado para o nivel ", predio.nivel_atual)
	else:
		print("[ERRO] Dinheiro insuficiente para upgrade!")


func _on_tile_clicado(argument) -> void:
	if typeof(argument) == TYPE_STRING:
		var id_string: String = argument
		if id_string == "casa1": id_string = "casa_simples"
		var b_data = _buscar_data_por_id(id_string)
		if b_data:
			_building_data_selecionado = b_data
			_abrir_tela_por_building_data(b_data)
		else:
			_executar_fallback_por_string(argument)
	elif typeof(argument) == TYPE_VECTOR2I:
		_processar_clique_no_tile(argument)


# ==============================================================================
# ESCANEAR PREDIOS COLOCADOS NO EDITOR DE CENAS
# ==============================================================================
func _escanear_mapa_inicial() -> void:
	if tilemap_constructions:
		for pos in tilemap_constructions.get_used_cells():
			var tile_data = tilemap_constructions.get_cell_tile_data(pos)
			var atlas_coords = tilemap_constructions.get_cell_atlas_coords(pos)
			_registrar_predio_se_existir(pos, tile_data, atlas_coords)
			
	elif tile_map:
		for pos in tile_map.get_used_cells(0):
			var tile_data = tile_map.get_cell_tile_data(0, pos)
			var atlas_coords = tile_map.get_cell_atlas_coords(0, pos)
			_registrar_predio_se_existir(pos, tile_data, atlas_coords)


func _registrar_predio_se_existir(pos: Vector2i, tile_data: TileData, atlas_coords: Vector2i) -> void:
	if not tile_data:
		return
	
	var building_id_custom = str(tile_data.get_custom_data("building_id")).strip_edges().to_lower()
	
	if building_id_custom == "terreno_vazio" or building_id_custom == "":
		return

	var b_data = _buscar_data_por_atlas_coords(atlas_coords)
	if b_data:
		if b_data.has_method("tem_tile_vazio") and b_data.tem_tile_vazio() and b_data.tile_vazio_atlas_coords == atlas_coords:
			return

		var eh_tile_construido = false
		if "tiles_atlas_coords" in b_data and b_data.tiles_atlas_coords is Array and b_data.tiles_atlas_coords.has(atlas_coords):
			eh_tile_construido = true
		elif "atlas_coords" in b_data and b_data.atlas_coords == atlas_coords:
			eh_tile_construido = true
		elif "tile_atlas_coords" in b_data and b_data.tile_atlas_coords == atlas_coords:
			eh_tile_construido = true

		if eh_tile_construido:
			construcoes_no_mapa[pos] = BuildingInstance.new(b_data, pos)
			var zona = _obter_zona_no_tile(pos)
			if zona:
				zona_por_tile[pos] = zona
				if not construcoes_por_zona.has(zona):
					construcoes_por_zona[zona] = []
				(construcoes_por_zona[zona] as Array).append(pos)


# ==============================================================================
# MAPA E OUTROS EVENTOS
# ==============================================================================
func _on_button_mapa_pressed() -> void:
	if has_node("CanvasLayer/MapOverlay"):
		$CanvasLayer/MapOverlay.visible = true

func _on_botao_teste_pressed() -> void:
	if typeof(FolderBlocker) != TYPE_NIL:
		FolderBlocker.liberarPraia()
		print("[INFO] Praia foi liberada!")

func _on_button_close_menu_pressed() -> void:
	if $CanvasLayer.has_node("BuildingHUD"):
		$CanvasLayer/BuildingHUD.visible = false
	_resetar_estado_construcoes()


func _on_testar_escola_pressed() -> void:
	var b_data = _buscar_data_por_id("escola")
	if b_data: _abrir_modo_compra_para_dados(b_data)

func _on_testar_hospital_pressed() -> void:
	var b_data = _buscar_data_por_id("hospital")
	if b_data: _abrir_modo_compra_para_dados(b_data)

func _resetar_estado_construcoes() -> void:
	if typeof(Global) != TYPE_NIL and "construcoes" in Global:
		for chave in Global.construcoes:
			Global.construcoes[chave] = false


# ==============================================================================
# SISTEMA DE MISSOES
# ==============================================================================
func escolher_missao_aleatoria():
	if Global.turno <= 0:
		return null
	
	if Global.turno == 2:
		if "missao1" not in Global.missoes_concluidas:
			var m_data: MissionData = banco_missoes.get("missao1")
			if m_data == null:
				print("[AVISO] Missao 'missao1' nao encontrada no banco_missoes!")
				return null
			
			Global.missao_escolhida = m_data
			Global.missao_atual_turnos = 0
			Global.missao_aceita = false
			print("[INFO] Turno 2: Missao obrigatoria - ", m_data.nome)
			
			_abrir_container_missao()
			return Global.missao_escolhida
	
	if Global.turno >= 4:
		var missoes_disponiveis: Dictionary = {}
		for chave in banco_missoes.keys():
			if chave not in Global.missoes_concluidas:
				missoes_disponiveis[chave] = banco_missoes[chave]
		
		if missoes_disponiveis.is_empty():
			Global.missao_escolhida = null
			return null
		
		for chave in missoes_disponiveis.keys():
			if chave not in Global.turnos_sem_missao:
				Global.turnos_sem_missao[chave] = 0
		
		var chance_atual = Global.chance_missao
		var sorteio_aparecer = randi() % 100
		
		if sorteio_aparecer < chance_atual:
			var chances = {}
			for chave in missoes_disponiveis.keys():
				var chance_individual = 30 + (Global.turnos_sem_missao[chave] * 15)
				chances[chave] = min(chance_individual, 100)
			
			var total_chance = 0
			for chance in chances.values():
				total_chance += chance
			
			var sorteio_missao = randi() % total_chance
			var acumulado = 0
			var chave_escolhida = ""
			
			for chave in chances.keys():
				acumulado += chances[chave]
				if sorteio_missao < acumulado:
					chave_escolhida = chave
					break
			
			if chave_escolhida == "":
				chave_escolhida = missoes_disponiveis.keys()[0]
			
			var m_data: MissionData = missoes_disponiveis[chave_escolhida]
			Global.missao_escolhida = m_data
			Global.missao_atual_turnos = 0
			Global.missao_aceita = false
			
			Global.chance_missao = 30
			Global.turnos_sem_missao[chave_escolhida] = 0
			
			for chave in missoes_disponiveis.keys():
				if chave != chave_escolhida:
					Global.turnos_sem_missao[chave] += 1
			
			_abrir_container_missao()
			
			return Global.missao_escolhida
		else:
			Global.chance_missao = min(Global.chance_missao + 15, 100)
			for chave in missoes_disponiveis.keys():
				Global.turnos_sem_missao[chave] += 1
			Global.missao_escolhida = null
			return null
	
	return null


# ==============================================================================
# SISTEMA DE MISSOES — AÇÕES DO JOGADOR
# ==============================================================================
var _missao_check_aberta := false


func aceitar_missao() -> void:
	if Global.missao_escolhida == null:
		print("Nenhuma missão ativa!")
		return
	
	Global.missao_aceita = true
	print("Missão aceita: ", Global.missao_escolhida.nome, " — conclua antes de passar o turno, ou ela falhará!")
	
	_fechar_container_missao()
	Global.jogo_pausado = false


func recusar_missao() -> void:
	if Global.missao_escolhida == null:
		print("Nenhuma missão ativa!")
		return
	
	var missao = Global.missao_escolhida
	
	# Recusar é uma escolha neutra: mantém os recursos, mas abre mão do
	# benefício. Sem penalidade — a decisão certa depende da prioridade
	# do jogador no momento, não existe resposta "correta".
	print("Missão recusada: ", missao.nome, " — recursos mantidos, oportunidade perdida.")
	
	# Essa missão já foi decidida (recusada) e não deve mais reaparecer
	Global.missoes_concluidas.append(missao.id)
	if missao.id in Global.turnos_sem_missao:
		Global.turnos_sem_missao.erase(missao.id)
	
	_fechar_container_missao()
	Global.jogo_pausado = false
	
	Global.missao_escolhida = null
	Global.missao_atual_turnos = 0


func concluir_missao() -> void:
	if Global.missao_escolhida == null or not Global.missao_aceita:
		print("Nenhuma missão aceita para concluir no momento!")
		return
	
	var missao = Global.missao_escolhida
	
	if Global.dinheiro < missao.custo:
		print("Recursos insuficientes para concluir a missão!")
		print("Necessário -> Dinheiro: ", missao.custo)
		print("Você tem -> Dinheiro: ", Global.dinheiro)
		return
	
	Global.dinheiro -= missao.custo
	Global.popularidade += missao.popularidade
	
	Global.missoes_concluidas.append(missao.id)
	if missao.id in Global.turnos_sem_missao:
		Global.turnos_sem_missao.erase(missao.id)
	
	print("Missão concluída: ", missao.nome)
	print("Gasto -> Dinheiro: ", missao.custo)
	print("Popularidade: +", missao.popularidade)
	print("Restante -> Dinheiro: ", Global.dinheiro)
	
	Global.missao_escolhida = null
	Global.missao_aceita = false
	Global.missao_atual_turnos = 0
	Global.chance_missao = 30


func abrir_checagem_missao() -> void:
	if Global.missao_escolhida == null or not Global.missao_aceita:
		return
	if not hud or not hud.has_node("MissaoContainer"):
		return
	
	_missao_check_aberta = true
	
	var missao_container = hud.get_node("MissaoContainer")
	missao_container.get_node("VBoxContainer/HBoxContainer").visible = false
	missao_container.get_node("VBoxContainer/HBoxContainer2").visible = true
	missao_container.visible = true


func fechar_checagem_missao() -> void:
	_missao_check_aberta = false
	_fechar_container_missao()


func _fechar_container_missao() -> void:
	if not hud or not hud.has_node("MissaoContainer"):
		return
	var missao_container = hud.get_node("MissaoContainer")
	missao_container.visible = false
	missao_container.get_node("VBoxContainer/HBoxContainer").visible = true
	missao_container.get_node("VBoxContainer/HBoxContainer2").visible = false


func _abrir_container_missao() -> void:
	if hud and hud.has_node("MissaoContainer"):
		hud.get_node("MissaoContainer").visible = true
		Global.jogo_pausado = true


func processar_missao_no_turno() -> void:
	if Global.missao_escolhida != null and Global.missao_aceita:
		var popularidade_perdida = Global.missao_escolhida.popularidade * 1.5
		Global.popularidade -= popularidade_perdida
		print("Missão '", Global.missao_escolhida.nome, "' falhou por não ter sido concluída a tempo! Popularidade perdida: -", popularidade_perdida)
		
		Global.missao_escolhida = null
		Global.missao_aceita = false
		Global.missao_atual_turnos = 0
	
	escolher_missao_aleatoria()


# ==============================================================================
# FUNCOES AUXILIARES DE ABERTURA E BUSCA
# ==============================================================================
func _abrir_modo_compra_para_dados(b_data: BuildingData, variacao_index: int = 0, cat_override: String = "") -> void:
	var tex = b_data.get_icone_variacao(variacao_index) if b_data.has_method("get_icone_variacao") else (b_data.icone if b_data.icone else icone_temp)
	
	var cat_nome = ""
	if cat_override != "" and cat_override != "terreno_vazio":
		cat_nome = cat_override
	elif "categoria" in b_data and b_data.categoria != null and str(b_data.categoria).strip_edges() != "":
		cat_nome = str(b_data.categoria).strip_edges()

	var nome_exibicao = b_data.nome if ("nome" in b_data and b_data.nome != "") else b_data.id

	tela_compras.abrir_modo_compra(
		nome_exibicao,
		cat_nome,
		b_data.descricao_curta,
		b_data.bonus_populacao,
		b_data.custo_base,
		tex,
		b_data.texto_detalhes,
		nome_exibicao,
		b_data.capacidade_abrigo,
		b_data.equipes_resgate
	)

func _abrir_tela_por_building_data(b_data: BuildingData) -> void:
	if b_data.eh_unica or b_data.pode_aprimorar:
		var pos_chave = Vector2i.ZERO
		var instancia: BuildingInstance
		
		if construcoes_no_mapa.has(pos_chave):
			instancia = construcoes_no_mapa[pos_chave]
		else:
			instancia = BuildingInstance.new(b_data, pos_chave)
			construcoes_no_mapa[pos_chave] = instancia
			
		_abrir_modo_upgrade_instancia(instancia)
	else:
		_abrir_modo_compra_para_dados(b_data)

func _abrir_modo_upgrade_instancia(predio: BuildingInstance) -> void:
	var b_data = predio.data
	var idx = predio.variacao_index if "variacao_index" in predio else 0
	var tex = b_data.get_icone_variacao(idx) if b_data.has_method("get_icone_variacao") else (b_data.icone if b_data.icone else icone_temp)
	
	tela_compras.abrir_modo_upgrade(
		b_data.nome,
		predio.nivel_atual,
		predio.get_ganhos_atuais(),
		predio.get_durabilidade_pct(),
		predio.get_custo_upgrade(),
		tex,
		b_data.descricao_curta,
		b_data.texto_detalhes,
		b_data.pode_aprimorar and (predio.nivel_atual < b_data.nivel_maximo)
	)

func _buscar_data_por_id(p_id: String) -> BuildingData:
	if p_id == "":
		return null
	var chave = p_id.to_lower().strip_edges()
	
	if banco_edificios.has(chave):
		return banco_edificios[chave]
		
	for b_data in banco_edificios.values():
		if not b_data:
			continue
		if "id" in b_data and b_data.id != null and str(b_data.id).to_lower().strip_edges() == chave:
			return b_data
		if "nome" in b_data and b_data.nome != null and str(b_data.nome).to_lower().strip_edges() == chave:
			return b_data
			
	return null

func _buscar_data_por_atlas_coords(coords: Vector2i) -> BuildingData:
	for b_data in banco_edificios.values():
		if not b_data:
			continue
		if "tiles_atlas_coords" in b_data and b_data.tiles_atlas_coords is Array and b_data.tiles_atlas_coords.has(coords):
			return b_data
		if "atlas_coords" in b_data and b_data.atlas_coords == coords:
			return b_data
		if "tile_atlas_coords" in b_data and b_data.tile_atlas_coords == coords:
			return b_data
		if b_data.has_method("tem_tile_vazio") and b_data.tem_tile_vazio() and b_data.tile_vazio_atlas_coords == coords:
			return b_data
	return null

func _executar_fallback_por_string(id_str: String) -> void:
	print("[AVISO] Fallback acionado para ID: ", id_str)


func _on_desastre_button_pressed() -> void:
	_iniciar_enchente()


# ==============================================================================
# INTEGRAÇÃO COM A CENA DE DESASTRE: ENCHENTE E ZONAS
# ==============================================================================
var _enchente_ativa: Enchente = null

func _iniciar_enchente() -> void:
	if not cena_enchente:
		print("[AVISO] Nenhuma cena de Enchente configurada em 'cena_enchente' (Inspector do main_game)!")
		return
	
	if _enchente_ativa:
		print("[AVISO] Já existe uma enchente ativa! Aguarde ela terminar antes de iniciar outra.")
		return
	
	var enchente: Enchente = cena_enchente.instantiate()
	add_child(enchente)
	enchente.enchente_iniciada.connect(_on_enchente_iniciada)
	enchente.enchente_terminada.connect(_on_enchente_terminada)
	_enchente_ativa = enchente
	
	Global.enchente += 1
	if "desastres" in Global and Global.desastres.has("enchente"):
		Global.desastres["enchente"] += 1


func _on_enchente_terminada() -> void:
	_enchente_ativa = null


func avancar_turno_desastres() -> void:
	if _enchente_ativa:
		_enchente_ativa.turno_passou()


func _on_enchente_iniciada(area: Rect2i, dano: float) -> void:
	var atingidos := 0
	for x in range(area.position.x, area.position.x + area.size.x):
		for y in range(area.position.y, area.position.y + area.size.y):
			var pos := Vector2i(x, y)
			if construcoes_no_mapa.has(pos) and construcoes_no_mapa[pos] != null:
				var predio: BuildingInstance = construcoes_no_mapa[pos]
				
				var mult_dano: float = 1.0
				if zona_por_tile.has(pos):
					var zona: BuildingZone = zona_por_tile[pos]
					mult_dano = zona.obter_multiplicador_dano()
				else:
					var zona = _obter_zona_no_tile(pos)
					if zona:
						mult_dano = zona.obter_multiplicador_dano()

				var dano_final = dano * mult_dano
				predio.durabilidade_atual = max(0.0, predio.durabilidade_atual - dano_final)
				atingidos += 1
				print("[ENCHENTE] Dano em ", pos, ": ", dano_final, " (Mult. Zona: x", mult_dano, ") | Vida: ", predio.durabilidade_atual)
				_verificar_casa_destruida(predio)
				
				if tela_compras and tela_compras.visible and pos == _celula_selecionada:
					_abrir_modo_upgrade_instancia(predio)
	
	print("[ENCHENTE] Total de construções atingidas: ", atingidos, " / Dano base: ", dano)
