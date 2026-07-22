extends Node2D

# CÂMERA
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud
# Referência para a cena da tela de compras instanciada no mapa
@onready var tela_compras: TelaCompras = $TelaCompras
# Referência aos botões de teste
@onready var button_teste_compra: Button = $ButtonTesteCompra
@onready var button_teste_upgrade: Button = $ButtonTesteUpgrade

# Imagem temporária para teste (ícone padrão da Godot)
var icone_temp = preload("res://icon.svg")

var freecam_enabled = false

func _ready() -> void:
	# Conecta os botões de teste para abrir a janela
	button_teste_compra.pressed.connect(_on_testar_escola_pressed)
	button_teste_upgrade.pressed.connect(_on_testar_hospital_pressed)
	
	# Conecta os sinais que a janela envia quando o jogador clica para comprar
	tela_compras.compra_confirmada.connect(_on_compra_confirmada)
	tela_compras.aprimoramento_confirmado.connect(_on_aprimoramento_confirmado)
	
	
	freecam_camera.enabled = true
	

var tempo_ultimo_print: float = 0.0
var intervalo_print: float = 4.0


# ==============================================================================
# 🧪 TESTE 1: MODO COMPRA (Layout de 2 Colunas)
# ==============================================================================
func _on_testar_escola_pressed() -> void:
	tela_compras.abrir_modo_compra(
		"Escola",                                                           # Nome
		"Construção",                                                       # Categoria
		"A construção essencial para o desenvolvimento humano de uma cidade.", # Descrição
		15,                                                                 # Bônus Pop
		15,                                                                 # Bônus Infra
		290000.0,                                                           # Preço
		icone_temp                                                          # Imagem
	)


# ==============================================================================
# 🧪 TESTE 2: MODO UPGRADE (Layout de 3 Colunas)
# ==============================================================================
func _on_testar_hospital_pressed() -> void:
	tela_compras.abrir_modo_upgrade(
		"Hospital",                                                         # Nome
		1,                                                                  # Nível Atual
		1906135023.0,                                                       # Ganhos
		100.0,                                                              # Porcentagem Infra
		290000.0,                                                           # Preço Upgrade
		icone_temp                                                          # Imagem
	)


# ==============================================================================
# 📢 RESPOSTAS AOS SINAIS DA JANELA (Veja no painel Output/Saída da Godot)
# ==============================================================================
func _on_compra_confirmada(nome: String) -> void:
	print("🟢 SINAL RECEBIDO: O jogador comprou o prédio -> ", nome)

func _on_aprimoramento_confirmado(nome: String) -> void:
	print("🔵 SINAL RECEBIDO: O jogador aprimorou o prédio -> ", nome)


func _process(delta: float) -> void:
	tempo_ultimo_print += delta
	
	if Global.construcoes["prefeitura"] == true:
		if tempo_ultimo_print >= intervalo_print:
			print("prefeitura clicada")
			tempo_ultimo_print = 0.0
		$CanvasLayer/BuildingHUD.visible = true
		
	elif Global.construcoes["casa1"] == true:
		if tempo_ultimo_print >= intervalo_print:
			print("casa1 clicado")
			tempo_ultimo_print = 0.0
		$CanvasLayer/BuildingHUD.visible = true


# MAPA
func _on_button_mapa_pressed() -> void:
	$CanvasLayer/MapOverlay.visible = true

# TESTES
func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()
	print("praia foi liberada!")

func _on_button_dinheiro_plus_pressed() -> void:
	Global.dinheiro += 100
	Global.popularidade += 50

func _on_button_dinheiro_minus_pressed() -> void:
	Global.dinheiro -= 100
	Global.popularidade -= 25


#⁠abrir pop-up de melhorias
@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")


func _on_button_close_menu_pressed() -> void:
	$CanvasLayer/BuildingHUD.visible = false
	for construcao in Global.construcoes:
		Global.construcoes[construcao] = false

func escolher_missao_aleatoria():
	# Turno 0: não faz nada
	if Global.turno <= 0:
		return null
	
	# Turno 2: obrigatório ser missao1
	if Global.turno == 2:
		if "missao1" not in Global.missoes_concluidas:
			Global.missao_escolhida = Global.missoes["missao1"]
			Global.missao_escolhida["chave"] = "missao1"
			Global.missao_atual_turnos = 0
			print("Turno 2: Missão obrigatória - ", Global.missao_escolhida["nome"])
			
			# Mostrar container
			if hud and hud.has_node("MissaoContainer"):
				var missao_container = hud.get_node("MissaoContainer")
				
				# Atualiza as labels através do VBoxContainer PRIMEIRO
				var vbox = missao_container.get_node("VBoxContainer")
				if vbox.has_node("missao_info"):
					vbox.get_node("missao_info").text = Global.missao_escolhida["info"]
					print("Info atualizada: ", Global.missao_escolhida["info"])
				
				if vbox.has_node("missao_recompensa"):
					vbox.get_node("missao_recompensa").text = "Dinheiro: " + str(Global.missao_escolhida["recompensa"]) + "\nPopularidade: +" + str(Global.missao_escolhida["popularidade"])
					print("Recompensa atualizada")
				
				# Torna visível
				missao_container.visible = true
				
				# Pausa o jogo (bloqueia botões)
				Global.jogo_pausado = true
				print("Jogo pausado - Missão ativa")
			else:
				print("ERRO: MissaoContainer não encontrado!")
			
			return Global.missao_escolhida
	
	# Turno 4+: sistema de chances aleatórias
	if Global.turno >= 4:
		var missoes_disponiveis = {}
		for chave in Global.missoes.keys():
			if chave not in Global.missoes_concluidas:
				missoes_disponiveis[chave] = Global.missoes[chave]
		
		if missoes_disponiveis.is_empty():
			print("Todas as missões foram concluídas!")
			Global.missao_escolhida = null
			return null
		
		for chave in missoes_disponiveis.keys():
			if chave not in Global.turnos_sem_missao:
				Global.turnos_sem_missao[chave] = 0
		
		var chance_atual = Global.chance_missao
		var sorteio_aparecer = randi() % 100
		
		print("Chance de missão neste turno: ", chance_atual, "%")
		print("Sorteio: ", sorteio_aparecer)
		
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
			
			Global.chance_missao = 30
			Global.turnos_sem_missao[chave_escolhida] = 0
			
			for chave in missoes_disponiveis.keys():
				if chave != chave_escolhida:
					Global.turnos_sem_missao[chave] += 1
			
			print("Missão escolhida: ", Global.missao_escolhida["nome"])
			
			# Mostrar container
			if hud and hud.has_node("MissaoContainer"):
				var missao_container = hud.get_node("MissaoContainer")
				
				# Atualiza as labels através do VBoxContainer PRIMEIRO
				var vbox = missao_container.get_node("VBoxContainer")
				if vbox.has_node("missao_info"):
					vbox.get_node("missao_info").text = Global.missao_escolhida["info"]
					print("Info atualizada: ", Global.missao_escolhida["info"])
				
				if vbox.has_node("missao_recompensa"):
					vbox.get_node("missao_recompensa").text = "Dinheiro: " + str(Global.missao_escolhida["recompensa"]) + "\nPopularidade: +" + str(Global.missao_escolhida["popularidade"])
					print("Recompensa atualizada")
				
				# Torna visível
				missao_container.visible = true
				
				# Pausa o jogo (bloqueia botões)
				Global.jogo_pausado = true
				print("Jogo pausado - Missão ativa")
			else:
				print("ERRO: MissaoContainer não encontrado!")
			
			return Global.missao_escolhida
		else:
			Global.chance_missao = min(Global.chance_missao + 15, 100)
			
			for chave in missoes_disponiveis.keys():
				Global.turnos_sem_missao[chave] += 1
			
			print("Nenhuma missão neste turno. Chance para próximo turno: ", Global.chance_missao, "%")
			Global.missao_escolhida = null
			return null
	
	return null
