extends Node2D

# ==============================================================================
# 📌 CÂMERA, HUD E NÓS DA INTERFACE
# ==============================================================================
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud
@onready var menu_pausa: MenuPausa = $MenuPausa

# REFERÊNCIA À TELA DE COMPRAS E AO TILEMAP
@onready var tela_compras: TelaCompras = $TelaCompras
# ⚠️ Ajuste o caminho abaixo caso o nó do seu TileMap tenha outro nome na árvore!
@onready var tilemap_constructions: TileMapLayer = $TileMapConstructions 

# REFERÊNCIA AOS BOTÕES DE TESTE
@onready var button_teste_compra: Button = $ButtonTesteCompra
@onready var button_teste_upgrade: Button = $ButtonTesteUpgrade
@onready var button_teste_pausa: Button = $ButtonTestePausa

# ==============================================================================
# 🏢 BANCO DE DADOS E INSTÂNCIAS DE EDIFÍCIOS
# ==============================================================================
## Arraste seus arquivos .tres aqui pelo Inspector (ex: casa_simples.tres, prefeitura.tres)
@export var banco_edificios: Array[BuildingData] = [] 
@export var tile_map: TileMap

# Guarda todas as construções vivas no mapa!
# Chave = Vector2i(x, y) ou String ID | Valor = objeto BuildingInstance
var construcoes_no_mapa: Dictionary = {}

# Imagem temporária para teste (ícone padrão da Godot)
var icone_temp = preload("res://icon.svg")
var freecam_enabled = false
@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")


# ==============================================================================
# 🎬 CICLO DE VIDA (READY & INPUT)
# ==============================================================================
func _ready() -> void:
	
	# TESTANDO SISTEMA DE RECURSOS!!!
	Global.pedra = 150
	Global.madeira = 200
	
	# Conecta o clique do botão diretamente à função toggle_pause da janela
	if button_teste_pausa and menu_pausa:
		button_teste_pausa.pressed.connect(menu_pausa.toggle_pause)
	
	# Conecta os botões de teste para abrir a janela (Opção manual)
	if button_teste_compra:
		button_teste_compra.pressed.connect(_on_testar_escola_pressed)
	if button_teste_upgrade:
		button_teste_upgrade.pressed.connect(_on_testar_hospital_pressed)
	
	# 📡 CONEXÃO DO SINAL DO TILEMAP (Abre as telas pelo clique no mapa)
	if tilemap_constructions and tilemap_constructions.has_signal("tile_clicado"):
		tilemap_constructions.tile_clicado.connect(_on_tile_clicado)
	
	# Conecta os sinais que a janela envia quando o jogador clica para comprar/aprimorar
	if tela_compras:
		tela_compras.compra_confirmada.connect(_on_compra_confirmada)
		tela_compras.aprimoramento_confirmado.connect(_on_aprimoramento_confirmado)
	
	if freecam_camera:
		freecam_camera.enabled = true




# ==============================================================================
# 🗺️ MAPA E OUTROS EVENTOS
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
# 📜 SISTEMA DE MISSÕES
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
			print("Turno 2: Missão obrigatória - ", Global.missao_escolhida["nome"])
			
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
	

func _unhandled_input(event: InputEvent) -> void:
	# Permite clicar nos tiles do mapa com o botão esquerdo
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not get_tree().paused:
			var target_map = tilemap_constructions if tilemap_constructions else tile_map
			if target_map:
				var pos_global = target_map.get_global_mouse_position()
				var pos_tile: Vector2i = target_map.local_to_map(pos_global)
				_on_tile_clicado(pos_tile)



# ==============================================================================
# 🏙️ GERENCIADOR DE CLIQUE NOS TILES (INTEGRADO AO BUILDINGDATA)
# ==============================================================================
func _on_tile_clicado(argument) -> void:
	if not tela_compras: return

	# --------------------------------------------------------------------------
	# CASO A: O argumento é um NOME / ID (String), ex: "prefeitura", "casa1"
	# --------------------------------------------------------------------------
	if typeof(argument) == TYPE_STRING:
		var id_string: String = argument
		
		# Trata o alias "casa1" para buscar "casa_simples" se necessário
		if id_string == "casa1":
			id_string = "casa_simples"
			
		var b_data: BuildingData = _buscar_data_por_id(id_string)
		
		if b_data:
			_abrir_tela_por_building_data(b_data)
		else:
			# Fallback para caso o arquivo .tres ainda não esteja configurado no Inspector
			_executar_fallback_por_string(argument)

	# --------------------------------------------------------------------------
	# CASO B: O argumento é uma COORDENADA (Vector2i) do TileMap
	# --------------------------------------------------------------------------
	elif typeof(argument) == TYPE_VECTOR2I:
		var pos_tile: Vector2i = argument
		
		# 1. Se já existe um prédio construído/instanciado nesta coordenada
		if construcoes_no_mapa.has(pos_tile):
			var predio_existente: BuildingInstance = construcoes_no_mapa[pos_tile]
			_abrir_modo_upgrade_instancia(predio_existente)
			return
			
		# 2. Busca os dados do tile dependendo do tipo do mapa (TileMapLayer ou TileMap)
		var tile_data: TileData = null
		if tilemap_constructions:
			tile_data = tilemap_constructions.get_cell_tile_data(pos_tile)
		elif tile_map:
			tile_data = tile_map.get_cell_tile_data(0, pos_tile)
			
		if tile_data:
			var building_id: String = tile_data.get_custom_data("building_id")
			if building_id != "":
				var b_data = _buscar_data_por_id(building_id)
				if b_data:
					var nova_instancia = BuildingInstance.new(b_data, pos_tile)
					construcoes_no_mapa[pos_tile] = nova_instancia
					_abrir_modo_upgrade_instancia(nova_instancia)
					return


# ==============================================================================
# 🛠️ HELPER FUNCTIONS (ABERTURA DE TELAS E BUSCA)
# ==============================================================================
func _abrir_tela_por_building_data(b_data: BuildingData) -> void:
	# Se o prédio é único (ex: Prefeitura) ou pode evoluir
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
		# Modo Compra (Para novas construções como Casas)
		var tex = b_data.icone if b_data.icone else icone_temp
		tela_compras.abrir_modo_compra(
			b_data.nome,
			b_data.categoria,
			b_data.descricao_curta,
			b_data.bonus_populacao,
			b_data.bonus_infraestrutura,
			b_data.custo_base,
			tex
		)


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


func _buscar_data_por_id(p_id: String) -> BuildingData:
	for b_data in banco_edificios:
		if b_data and b_data.id.to_lower() == p_id.to_lower():
			return b_data
	return null


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
				"Melhorar a prefeitura libera novas áreas de expansão no mapa."
			)
		"casa1", "casa_simples":
			tela_compras.abrir_modo_compra(
				"Casa Residencial",
				"Residencial",
				"Aumenta a capacidade de moradores e a receita de impostos da cidade.",
				10,
				5,
				150000.0,
				icone_temp
			)


# ==============================================================================
# 🧪 TESTES MANUAIS VIA BOTÃO
# ==============================================================================
func _on_testar_escola_pressed() -> void:
	tela_compras.abrir_modo_compra(
		"Escola",
		"Construção",
		"A construção essencial para o desenvolvimento humano de uma cidade.",
		15,
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
# 📢 RESPOSTAS AOS SINAIS DA JANELA
# ==============================================================================
func _on_compra_confirmada(nome: String) -> void:
	print("🟢 SINAL RECEBIDO: O jogador comprou o prédio -> ", nome)
	_resetar_estado_construcoes()

func _on_aprimoramento_confirmado(nome: String) -> void:
	print("🔵 SINAL RECEBIDO: O jogador aprimorou o prédio -> ", nome)
	
	# Procura a instância correspondente e incrementa o nível
	for pos in construcoes_no_mapa:
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio.data and predio.data.nome.to_upper() == nome.to_upper():
			predio.nivel_atual += 1
			print("⬆️ Nível atualizado para: ", predio.nivel_atual)
			break
			
	_resetar_estado_construcoes()

func _resetar_estado_construcoes() -> void:
	if typeof(Global) != TYPE_NIL and "construcoes" in Global:
		for chave in Global.construcoes:
			Global.construcoes[chave] = false
