extends Node2D

# ==============================================================================
# CÂMERA, HUD E NÓS DA INTERFACE
# ==============================================================================
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud
@onready var menu_pausa: MenuPausa = $MenuPausa

# REFERÊNCIA À TELA DE COMPRAS E AO TILEMAP
@onready var tela_compras: TelaCompras = $TelaCompras
@onready var tilemap_constructions: TileMapLayer = $TileMapConstructions

# REFERÊNCIA AOS BOTÕES DE TESTE
@onready var button_teste_compra: Button = $ButtonTesteCompra
@onready var button_teste_upgrade: Button = $ButtonTesteUpgrade
@onready var button_teste_pausa: Button = $ButtonTestePausa

# ==============================================================================
# BANCO DE DADOS E INSTÂNCIAS DE EDIFÍCIOS
# ==============================================================================
@export_group("Banco de Edifícios")
## Pasta onde ficam armazenados todos os seus arquivos .tres de construções
@export var pasta_edificios: String = "res://recursos/predios/"
## Fallback manual: se preferir arrastar arquivos .tres pelo Inspector
@export var banco_edificios_manual: Array[BuildingData] = []
@export var tile_map: TileMap

# Dicionário dinâmico carregado automaticamente
# Chave = String ("casa_simples", "prefeitura") | Valor = BuildingData
var banco_edificios: Dictionary = {}

# Guarda todas as construções vivas no mapa!
# Chave = Vector2i(x, y) | Valor = objeto BuildingInstance
var construcoes_no_mapa: Dictionary = {}

# Controle do lote/tile atualmente selecionado pelo clique do jogador
var _celula_selecionada: Vector2i = Vector2i(-1, -1)
var _building_data_selecionado: BuildingData = null

# Variáveis auxiliares
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
	
	# Conecta o clique do botão diretamente à função toggle_pause
	if button_teste_pausa and menu_pausa:
		button_teste_pausa.pressed.connect(menu_pausa.toggle_pause)
	
	# Conecta os botões de teste para abrir a janela (Opção manual)
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

	# Escaneia o mapa para registrar prédios que já vieram desenhados no editor
	_escanear_mapa_inicial()


# ==============================================================================
# CARREGADOR AUTOMÁTICO DE RECURSOS (.TRES)
# ==============================================================================
func _carregar_todos_os_edificios() -> void:
	banco_edificios.clear()
	
	# 1. Carrega arquivos passados manualmente no Inspector (se houver)
	for b_data in banco_edificios_manual:
		if b_data and b_data.id != "":
			banco_edificios[b_data.id.to_lower()] = b_data
			print("🏢 Edifício (manual) registrado: ", b_data.id)

	# 2. Escaneia a pasta no projeto em busca de arquivos .tres
	if DirAccess.dir_exists_absolute(pasta_edificios):
		var dir = DirAccess.open(pasta_edificios)
		if dir:
			dir.list_dir_begin()
			var nome_arquivo = dir.get_next()
			
			while nome_arquivo != "":
				if not dir.current_is_dir():
					# Trata extensão no editor e em jogos exportados (.remap)
					var nome_limpo = nome_arquivo.replace(".remap", "")
					if nome_limpo.ends_with(".tres"):
						var caminho_completo = pasta_edificios.path_join(nome_limpo)
						var recurso = load(caminho_completo) as BuildingData
						if recurso and recurso.id != "":
							banco_edificios[recurso.id.to_lower()] = recurso
							print("🏢 Edifício (automático) carregado: ", recurso.id)
				nome_arquivo = dir.get_next()
			dir.list_dir_end()
	else:
		print("⚠️ Pasta de edifícios '", pasta_edificios, "' não encontrada no projeto! Crie a pasta ou configure no Inspetor.")


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
				print("💥 Dano aplicado na casa ", _celula_selecionada, "! Nova vida: ", predio.durabilidade_atual, "/", predio.data.durabilidade_maxima)
				
				# Se a janela de detalhes estiver aberta no momento, atualiza a barra imediatamente
				if tela_compras and tela_compras.visible:
					_abrir_modo_upgrade_instancia(predio)
			return

	# --- CLIQUE DO MOUSE NA GRADE DO MAPA ---
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_tree().paused:
			var target_map = tilemap_constructions if tilemap_constructions else tile_map
			if target_map:
				var pos_local = target_map.get_local_mouse_position()
				var pos_tile: Vector2i = target_map.local_to_map(pos_local)
				_processar_clique_no_tile(pos_tile)


# ==============================================================================
# GERENCIADOR DE CLIQUE NOS TILES (COMPRA VS UPGRADE/DETALHES)
# ==============================================================================
func _processar_clique_no_tile(pos_tile: Vector2i) -> void:
	if not tela_compras: return
	_celula_selecionada = pos_tile

	# 1. Se já existe uma construção salva na memória -> Modo Upgrade / Detalhes
	if construcoes_no_mapa.has(pos_tile) and construcoes_no_mapa[pos_tile] != null:
		var predio_existente: BuildingInstance = construcoes_no_mapa[pos_tile]
		_abrir_modo_upgrade_instancia(predio_existente)
		return

	# 2. Busca o TileData do mapa na coordenada clicada
	var tile_data: TileData = null
	var atlas_coords_atuais: Vector2i = Vector2i(-1, -1)
	
	if tilemap_constructions:
		tile_data = tilemap_constructions.get_cell_tile_data(pos_tile)
		if tile_data:
			atlas_coords_atuais = tilemap_constructions.get_cell_atlas_coords(pos_tile)
	elif tile_map:
		tile_data = tile_map.get_cell_tile_data(0, pos_tile)
		if tile_data:
			atlas_coords_atuais = tile_map.get_cell_atlas_coords(0, pos_tile)

	# Se não há nenhum tile desenhado no local, ignora
	if tile_data == null:
		return

	# 3. BUSCA INTELIGENTE:
	var b_data: BuildingData = null

	# PRIORIDADE 1: Lê o Custom Data "building_id" configurado no TileSet
	var building_id_custom = tile_data.get_custom_data("building_id")
	if building_id_custom and str(building_id_custom).strip_edges() != "":
		b_data = _buscar_data_por_id(str(building_id_custom))

	# PRIORIDADE 2: Se não houver Custom Data no tile, busca pelas coordenadas configuradas no .tres
	if b_data == null:
		b_data = _buscar_data_por_atlas_coords(atlas_coords_atuais)
	
	# PRIORIDADE 3: Fallback de segurança
	if b_data == null:
		b_data = _buscar_data_por_id("casa_simples")
		if not b_data:
			return
	
	_building_data_selecionado = b_data

	# 4. DECISÃO: O tile clicado é um prédio pronto ou um terreno/água de compra?
	if b_data.tiles_atlas_coords.has(atlas_coords_atuais):
		var nova_instancia = BuildingInstance.new(b_data, pos_tile)
		construcoes_no_mapa[pos_tile] = nova_instancia
		_abrir_modo_upgrade_instancia(nova_instancia)
	else:
		_abrir_modo_compra_para_dados(b_data)


# Suporte legado/manual para recebimento por String se necessário
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
# ESCANEAR PRÉDIOS COLOCADOS NO EDITOR DE CENAS
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
	
	var b_data = _buscar_data_por_atlas_coords(atlas_coords)
	if b_data and b_data.tiles_atlas_coords.has(atlas_coords):
		# Registra na memória a casa que já veio desenhada no mapa
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
		print("praia foi liberada!")

func _on_button_close_menu_pressed() -> void:
	if $CanvasLayer.has_node("BuildingHUD"):
		$CanvasLayer/BuildingHUD.visible = false
	_resetar_estado_construcoes()


# ==============================================================================
# SISTEMA DE MISSÕES
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
			print("Turno 2: Missao obrigatoria - ", Global.missao_escolhida["nome"])
			
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
# FUNÇÕES AUXILIARES DE ABERTURA E BUSCA
# ==============================================================================
func _abrir_modo_compra_para_dados(b_data: BuildingData) -> void:
	var tex = b_data.icone if b_data.icone else icone_temp
	tela_compras.abrir_modo_compra(
		b_data.nome,
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
	var tex = b_data.icone if b_data.icone else icone_temp
	
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

# Busca O(1) diretamente no Dicionário
func _buscar_data_por_id(p_id: String) -> BuildingData:
	var chave = p_id.to_lower()
	if banco_edificios.has(chave):
		return banco_edificios[chave]
	return null

# Substitui o antigo Custom Data "building_id": descobre a qual BuildingData
# uma coordenada do atlas pertence, seja ela um prédio já construído
# (tiles_atlas_coords) ou o lote vazio dele (tile_vazio_atlas_coords).
func _buscar_data_por_atlas_coords(coords: Vector2i) -> BuildingData:
	for b_data in banco_edificios.values():
		if not b_data:
			continue
		if b_data.tiles_atlas_coords.has(coords):
			return b_data
		if b_data.tem_tile_vazio() and b_data.tile_vazio_atlas_coords == coords:
			return b_data
	return null

# ==============================================================================
# CONTAGEM DE CONSTRUÇÕES ATIVAS (usado pelo sistema de renda/recursos por turno)
# ==============================================================================
## Conta quantas construções ativas no mapa têm um id que começa com "prefixo_id"
## (ex: "casa" conta "casa_simples" e "casa_grande")
func contar_construcoes_por_categoria(prefixo_id: String) -> int:
	var total := 0
	for predio in construcoes_no_mapa.values():
		if predio and predio.data and predio.data.id.to_lower().begins_with(prefixo_id.to_lower()):
			total += 1
	return total

## Quantidade de casas ativas no mapa agora (usado pra Global.renda)
func contar_casas_ativas() -> int:
	return contar_construcoes_por_categoria("casa")

func _executar_fallback_por_string(tipo: String) -> void:
	match tipo:
		"prefeitura":
			tela_compras.abrir_modo_upgrade(
				"Prefeitura",
				1,
				1500.0,
				100.0,
				500000.0,
				icone_temp,
				"Sede administrativa da cidade.",
				"Melhorar a prefeitura libera novas areas de expansao no mapa."
			)
		"casa1", "casa_simples":
			tela_compras.abrir_modo_compra(
				"Casa Residencial",
				"Residencial",
				"Aumenta a capacidade de moradores e a receita de impostos da cidade.",
				10,
				150000.0,
				icone_temp
			)


# ==============================================================================
# TESTES MANUAIS VIA BOTÃO
# ==============================================================================
func _on_testar_escola_pressed() -> void:
	tela_compras.abrir_modo_compra(
		"Escola",
		"Construcao",
		"A construcao essencial para o desenvolvimento humano de uma cidade.",
		15,
		290000.0,
		icone_temp
	)

func _on_testar_hospital_pressed() -> void:
	tela_compras.abrir_modo_upgrade(
		"Hospital",
		1,
		1906135023.0,
		100.0,
		290000.0,
		icone_temp
	)


# ==============================================================================
# RESPOSTAS AOS SINAIS DA JANELA (COMPRA E UPGRADE)
# ==============================================================================
func _on_compra_confirmada(nome: String) -> void:
	print("SINAL RECEBIDO: O jogador comprou o predio -> ", nome)
	
	var b_data = _building_data_selecionado
	if not b_data:
		b_data = _buscar_data_por_id("casa_simples")
		
	if b_data and _celula_selecionada != Vector2i(-1, -1):
		# Só efetua a compra se houver dinheiro suficiente
		if Global.dinheiro < b_data.custo_base:
			print("Dinheiro insuficiente para comprar '", b_data.nome, "'! Necessário: ", b_data.custo_base, " | Você tem: ", Global.dinheiro)
			_resetar_estado_construcoes()
			return
		
		# Consome o dinheiro
		Global.dinheiro -= b_data.custo_base
		print("Dinheiro gasto: ", b_data.custo_base, " | Restante: ", Global.dinheiro)
		
		# 1. Cria a instancia na memoria e salva na coordenada do dicionario
		var nova_instancia = BuildingInstance.new(b_data, _celula_selecionada)
		construcoes_no_mapa[_celula_selecionada] = nova_instancia
		
		# 2. Pega a coordenada atlas configurada no .tres (suporta variações)
		var atlas_coords = b_data.get_atlas_coord_para_construir()
		
		# 3. Troca o tile visualmente respeitando o tipo exato do nó
		if tilemap_constructions:
			tilemap_constructions.set_cell(_celula_selecionada, b_data.source_id, atlas_coords)
		elif tile_map:
			tile_map.set_cell(0, _celula_selecionada, b_data.source_id, atlas_coords)
				
		print("Construcao efetuada no tile: ", _celula_selecionada)
		
	_resetar_estado_construcoes()

func _on_aprimoramento_confirmado(nome: String) -> void:
	print("SINAL RECEBIDO: O jogador aprimorou o predio -> ", nome)
	
	# Incrementa o nivel do predio na posicao selecionada
	if _celula_selecionada in construcoes_no_mapa and construcoes_no_mapa[_celula_selecionada] != null:
		var predio: BuildingInstance = construcoes_no_mapa[_celula_selecionada]
		var custo_upgrade = predio.get_custo_upgrade()
		
		if Global.dinheiro < custo_upgrade:
			print("Dinheiro insuficiente para aprimorar '", nome, "'! Necessário: ", custo_upgrade, " | Você tem: ", Global.dinheiro)
		else:
			Global.dinheiro -= custo_upgrade
			predio.nivel_atual += 1
			print("Dinheiro gasto no upgrade: ", custo_upgrade, " | Restante: ", Global.dinheiro)
			print("Nivel atualizado para: ", predio.nivel_atual)
	else:
		# Fallback: Procura por correspondencia de nome
		for pos in construcoes_no_mapa:
			var predio: BuildingInstance = construcoes_no_mapa[pos]
			if predio and predio.data and predio.data.nome.to_upper() == nome.to_upper():
				var custo_upgrade = predio.get_custo_upgrade()
				
				if Global.dinheiro < custo_upgrade:
					print("Dinheiro insuficiente para aprimorar '", nome, "'! Necessário: ", custo_upgrade, " | Você tem: ", Global.dinheiro)
				else:
					Global.dinheiro -= custo_upgrade
					predio.nivel_atual += 1
					print("Dinheiro gasto no upgrade: ", custo_upgrade, " | Restante: ", Global.dinheiro)
					print("Nivel atualizado para: ", predio.nivel_atual)
				break
			
	_resetar_estado_construcoes()

func _resetar_estado_construcoes() -> void:
	if typeof(Global) != TYPE_NIL and "construcoes" in Global:
		for chave in Global.construcoes:
			Global.construcoes[chave] = false
