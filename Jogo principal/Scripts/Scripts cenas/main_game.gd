extends Node2D

# ==============================================================================
# CAMERA, HUD E NOS DA INTERFACE
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

# Dicionario dinamico carregado automaticamente
# Chave = String ("casa_simples", "prefeitura") | Valor = BuildingData
var banco_edificios: Dictionary = {}

# Guarda todas as construcoes vivas no mapa
# Chave = Vector2i(x, y) | Valor = objeto BuildingInstance
var construcoes_no_mapa: Dictionary = {}

# Controle do lote/tile atualmente selecionado pelo clique do jogador
var _celula_selecionada: Vector2i = Vector2i(-1, -1)
var _building_data_selecionado: BuildingData = null

# Variaveis auxiliares
var icone_temp = preload("res://icon.svg")
var freecam_enabled = false
@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")


# ==============================================================================
# CICLO DE VIDA (READY & INPUT)
# ==============================================================================
func _ready() -> void:
	# 1. Carrega todos os .tres automaticamente da pasta e/ou array manual
	_carregar_todos_os_edificios()
	Global.dinheiro = 1000
	
	# Sistema de recursos inicial
	Global.pedra = 150
	Global.madeira = 200
	
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
# CARREGADOR AUTOMATICO DE RECURSOS (.TRES)
# ==============================================================================
func _carregar_todos_os_edificios() -> void:
	banco_edificios.clear()
	
	# 1. Carrega arquivos passados manualmente no Inspector (se houver)
	for b_data in banco_edificios_manual:
		if b_data and b_data.id != "":
			banco_edificios[b_data.id.to_lower()] = b_data
			print("[INFO] Edificio (manual) registrado: ", b_data.id)

	# 2. Escaneia a pasta no projeto em busca de arquivos .tres
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
						if recurso and recurso.id != "":
							banco_edificios[recurso.id.to_lower()] = recurso
							print("[INFO] Edificio (automatico) carregado: ", recurso.id)
				nome_arquivo = dir.get_next()
			dir.list_dir_end()
	else:
		print("[AVISO] Pasta de edificios '", pasta_edificios, "' nao encontrada no projeto!")


# ==============================================================================
# LEITURA DE CLIQUES NO MAPA
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	# --- TECLA DEBUG: Aperte 'D' no teclado para causar 25 de dano na casa selecionada ---
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D and _celula_selecionada in construcoes_no_mapa:
			var predio: BuildingInstance = construcoes_no_mapa[_celula_selecionada]
			if predio:
				predio.durabilidade_atual = max(0.0, predio.durabilidade_atual - 25.0)
				print("[DEBUG] Dano aplicado na casa ", _celula_selecionada, "! Nova vida: ", predio.durabilidade_atual, "/", predio.data.durabilidade_maxima)
				
				if tela_compras and tela_compras.visible:
					_abrir_modo_upgrade_instancia(predio)
			return

	# --- CLIQUE DO MOUSE NA GRADE DO MAPA ---
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

	# 3. Lê a propriedade Custom Data 'building_id' se existir
	var building_id_custom = ""
	var raw_custom = tile_data.get_custom_data("building_id")
	if raw_custom != null:
		building_id_custom = str(raw_custom).strip_edges().to_lower()

	# --------------------------------------------------------------------------
	# CASO TERRENO VAZIO -> ABRE O CATÁLOGO DE SELEÇÃO DE EDIFÍCIOS
	# --------------------------------------------------------------------------
	if building_id_custom == "terreno_vazio" or building_id_custom == "":
		var lista_opcoes = _obter_edificios_genericos()
		if lista_opcoes.size() > 0:
			tela_compras.abrir_modo_selecao(lista_opcoes)
		else:
			print("[AVISO] Nenhuma construção disponível encontrada no banco de dados!")
		return

	# --------------------------------------------------------------------------
	# CASO OUTRO PRÉDIO PRÉ-DEFINIDO (Ex: Prefeitura)
	# --------------------------------------------------------------------------
	var b_data: BuildingData = _buscar_data_por_id(building_id_custom)
	if b_data != null:
		_building_data_selecionado = b_data
		_abrir_modo_compra_para_dados(b_data)
	else:
		# Fallback: se for desconhecido, abre o catálogo
		var lista_opcoes = _obter_edificios_genericos()
		if lista_opcoes.size() > 0:
			tela_compras.abrir_modo_selecao(lista_opcoes)


func _obter_edificios_genericos() -> Array[BuildingData]:
	var lista: Array[BuildingData] = []
	for b_data in banco_edificios.values():
		if b_data and not b_data.eh_unica:
			lista.append(b_data)
	return lista


# ==============================================================================
# CONFIRMACAO DE ACOES DA TELA DE COMPRAS
# ==============================================================================
func _on_compra_confirmada(nome_ou_id_edificio: String, variacao_index: int = 0) -> void:
	if _celula_selecionada == Vector2i(-1, -1):
		print("[ERRO] Nenhuma celula selecionada para compra.")
		return

	# Busca de forma flexivel por ID ou por Nome
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

	# 3. Registra a nova instancia na memoria do mapa
	var nova_instancia = BuildingInstance.new(b_data, _celula_selecionada)
	if "variacao_index" in nova_instancia:
		nova_instancia.variacao_index = variacao_index
	construcoes_no_mapa[_celula_selecionada] = nova_instancia

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


# Suporte legado/manual para recebimento por String se necessario
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
			Global.missao_escolhida = Global.missoes["missao1"]
			Global.missao_escolhida["chave"] = "missao1"
			Global.missao_atual_turnos = 0
			Global.missao_aceita = false
			print("[INFO] Turno 2: Missao obrigatoria - ", Global.missao_escolhida["nome"])
			
			if hud and hud.has_node("MissaoContainer"):
				var missao_container = hud.get_node("MissaoContainer")
				var vbox = missao_container.get_node("VBoxContainer")
				
				if vbox.has_node("missao_info"):
					vbox.get_node("missao_info").text = Global.missao_escolhida["info"]
				
				if vbox.has_node("missao_recompensa"):
					vbox.get_node("missao_recompensa").text = "Custo: " + str(Global.missao_escolhida["custo"]) + " dinheiro" + \
						"\nPedra: " + str(Global.missao_escolhida["pedra"]) + \
						"\nMadeira: " + str(Global.missao_escolhida["madeira"]) + \
						"\nPopularidade: +" + str(Global.missao_escolhida["popularidade"])
				
				missao_container.visible = true
				Global.jogo_pausado = true
			return Global.missao_escolhida
	
	if Global.turno >= 4:
		var missoes_disponiveis = {}
		for chave in Global.missoes.keys():
			if chave not in Global.missoes_concluidas:
				missoes_disponiveis[chave] = Global.missoes[chave]
		
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
			
			Global.missao_escolhida = Global.missoes[chave_escolhida]
			Global.missao_escolhida["chave"] = chave_escolhida
			Global.missao_atual_turnos = 0
			Global.missao_aceita = false
			
			Global.chance_missao = 30
			Global.turnos_sem_missao[chave_escolhida] = 0
			
			for chave in missoes_disponiveis.keys():
				if chave != chave_escolhida:
					Global.turnos_sem_missao[chave] += 1
			
			if hud and hud.has_node("MissaoContainer"):
				var missao_container = hud.get_node("MissaoContainer")
				var vbox = missao_container.get_node("VBoxContainer")
				
				if vbox.has_node("missao_info"):
					vbox.get_node("missao_info").text = Global.missao_escolhida["info"]
				
				if vbox.has_node("missao_recompensa"):
					vbox.get_node("missao_recompensa").text = "Custo: " + str(Global.missao_escolhida["custo"]) + " dinheiro" + \
						"\nPedra: " + str(Global.missao_escolhida["pedra"]) + \
						"\nMadeira: " + str(Global.missao_escolhida["madeira"]) + \
						"\nPopularidade: +" + str(Global.missao_escolhida["popularidade"])
				
				missao_container.visible = true
				Global.jogo_pausado = true
			
			return Global.missao_escolhida
		else:
			Global.chance_missao = min(Global.chance_missao + 15, 100)
			for chave in missoes_disponiveis.keys():
				Global.turnos_sem_missao[chave] += 1
			Global.missao_escolhida = null
			return null
	
	return null


# ==============================================================================
# FUNCOES AUXILIARES DE ABERTURA E BUSCA
# ==============================================================================
func _abrir_modo_compra_para_dados(b_data: BuildingData, variacao_index: int = 0) -> void:
	var tex = b_data.get_icone_variacao(variacao_index) if b_data.has_method("get_icone_variacao") else (b_data.icone if b_data.icone else icone_temp)
	tela_compras.abrir_modo_compra(
		b_data.id if b_data.id != "" else b_data.nome,
		b_data.categoria,
		b_data.descricao_curta,
		b_data.bonus_populacao,
		b_data.custo_base,
		tex
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
