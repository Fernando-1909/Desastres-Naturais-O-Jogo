extends Node2D

# CÂMERA E HUD
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud
@onready var menu_pausa: MenuPausa = $MenuPausa

# REFERÊNCIA À TELA DE COMPRAS E AO TILEMAP
@onready var tela_compras: TelaCompras = $TelaCompras
# ⚠️ Ajuste o caminho abaixo caso o nó do seu TileMap tenha outro nome na árvore!
@onready var tilemap_constructions: TileMapLayer = $TileMapConstructions 

# REFERÊNCIA AOS BOTÕES DE TESTE (Podem ser mantidos ou removidos futuramente)
@onready var button_teste_compra: Button = $ButtonTesteCompra
@onready var button_teste_upgrade: Button = $ButtonTesteUpgrade
@onready var button_teste_pausa: Button = $ButtonTestePausa


# Imagem temporária para teste (ícone padrão da Godot)
var icone_temp = preload("res://icon.svg")

var freecam_enabled = false

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
	if tilemap_constructions:
		tilemap_constructions.tile_clicado.connect(_on_tile_clicado)
	
	# Conecta os sinais que a janela envia quando o jogador clica para comprar/aprimorar
	if tela_compras:
		tela_compras.compra_confirmada.connect(_on_compra_confirmada)
		tela_compras.aprimoramento_confirmado.connect(_on_aprimoramento_confirmado)
	
	freecam_camera.enabled = true


func _process(_delta: float) -> void:
	# O _process agora fica livre de checagens visuais contínuas de telas
	pass


# ==============================================================================
# 🏙️ GERENCIADOR DE CLIQUE NOS TILES (Novo Passo 2)
# ==============================================================================
func _on_tile_clicado(tipo: String) -> void:
	match tipo:
		"prefeitura":
			# UPGRADE: Exemplo para o prédio da Prefeitura
			tela_compras.abrir_modo_upgrade(
				"Prefeitura",                                                       # Nome
				1,                                                                  # Nível Atual
				1500.0,                                                             # Ganhos por turno
				100.0,                                                              # Porcentagem Infra
				500000.0,                                                           # Custo do Upgrade
				icone_temp                                                          # Imagem
			)
			
		"casa1":
			# COMPRA: Exemplo para o terreno/área de construção
			tela_compras.abrir_modo_compra(
				"Casa Residencial",                                                 # Nome
				"Residencial",                                                      # Categoria
				"Aumenta a capacidade de moradores e a receita de impostos da cidade.", # Descrição
				10,                                                                 # Bônus População
				5,                                                                  # Bônus Infraestrutura
				150000.0,                                                           # Preço de Compra
				icone_temp                                                          # Imagem
			)


# ==============================================================================
# 🧪 TESTES MANUAIS VIA BOTÃO (Seus testes antigos)
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
	_resetar_estado_construcoes()

func _resetar_estado_construcoes() -> void:
	for chave in Global.construcoes:
		Global.construcoes[chave] = false


# ==============================================================================
# 🗺️ MAPA E OUTROS EVENTOS
# ==============================================================================
func _on_button_mapa_pressed() -> void:
	$CanvasLayer/MapOverlay.visible = true

func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()
	print("praia foi liberada!")

@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")

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
