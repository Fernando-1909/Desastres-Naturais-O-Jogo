extends Node2D

# ==============================================================================
# CAMERA, HUD E NÓS DA INTERFACE
# ==============================================================================
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Ui
@onready var menu_pausa: MenuPausa = $MenuPausa
@onready var sistema_drenagem: SistemaDrenagem = $SistemaDrenagem

# Referência à cena de diálogos, já instanciada na árvore. Em vez de um
# caminho fixo (que pode não bater com a posição real dela na sua cena),
# procuramos automaticamente por qualquer node que tenha o método
# iniciar_dialogo_da_missao (ver _encontrar_dialogue_manager, chamado no _ready).
var dialogue_manager: Node = null

# REFERENCIA A TELA DE COMPRAS E AO TILEMAP (Suporta TileMapLayer e TileMap)
@onready var tela_compras: TelaCompras = $TelaCompras
@onready var tilemap_constructions: TileMapLayer = $TileMapConstructions
@onready var tilemap_base: TileMapLayer = $TileMapBase

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
## Quanto CADA Bomba de Drenagem construída reduz o tamanho/dano da enchente
## ativa (0.12 = 12% por bomba). O id do prédio precisa ser "bomba_drenagem".
@export var mitigacao_por_bomba: float = 0.12
## Redução máxima possível somando todas as bombas — a enchente nunca é
## totalmente anulada, sempre sobra pelo menos essa fração do efeito original.
@export var mitigacao_maxima_enchente: float = 0.75

@export_group("Progressão do Jogo")
## Turno em que a enchente começa automaticamente (sem precisar do botão de teste)
@export var turno_inicio_enchente: int = 9
## Quantos turnos a enchente automática dura (turno_inicio_enchente até
## turno_inicio_enchente + duracao_enchente_turnos - 1)
@export var duracao_enchente_turnos: int = 5
## Último turno jogável. Ao entrar no turno seguinte (turno_final + 1), o jogo acaba.
@export var turno_final: int = 15
## IDs de edifícios que começam bloqueados e só aparecem ao surgir a missão correspondente
@export var edificios_bloqueados_inicialmente: Array[String] = ["abrigo","bombeiros", "estacao_tratamento", "estacao_drenagem"]

# Guarda os IDs dos edifícios que foram liberados durante a partida
var edificios_desbloqueados: Array[String] = []

var _tiles_ocultos_zona_funcoes: Array[Dictionary] = []

@export_group("Resgate")
@export var cena_ponto_resgate: PackedScene = preload("res://Jogo principal/UI/ponto_resgate.tscn")

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

var _tiles_ocultos_zona_rio: Array[Dictionary] = []

# Controle do lote/tile atualmente selecionado pelo clique do jogador
var _celula_selecionada: Vector2i = Vector2i(-1, -1)
var _building_data_selecionado: BuildingData = null

# Variaveis auxiliares
var icone_temp = preload("res://icon.svg")
var freecam_enabled = false
@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")

# Controle interno de resgate e emergências
var equipes_bombeiro_ocupadas: int = 0
var total_capacidade_abrigo: int = 0
var total_equipes_resgate: int = 0
var abrigo_ocupado: int = 0


# ==============================================================================
# CICLO DE VIDA (READY & INPUT)
# ==============================================================================
func _ready() -> void:
	
	await get_tree().process_frame # Aguarda o carregamento dos nós
	var zonas = get_tree().get_nodes_in_group("zonas_construcao")
	print("--- TESTE DE CONFIGURAÇÃO DE ZONAS ---")
	print("Quantidade de zonas encontradas no grupo: ", zonas.size())
	for z in zonas:
		var tipo = z.tipo_zona if "tipo_zona" in z else "SEM VARIAVEL TIPO_ZONA"
		print("Nó: ", z.name, " | Posição Global: ", z.global_position, " | Tipo: ", tipo)
	
	# Executa a ocultação após todos os nós e zonas estarem totalmente carregados.
	# A Zona de Funções começa fechada e só é liberada junto da primeira
	# missão, que aparece obrigatoriamente no turno 2.
	_bloquear_zona_funcoes_ate_turno_2()
	call_deferred("_ocultar_terrenos_zona_bloqueada")
	
	# 1. Carrega todos os .tres automaticamente da pasta e/ou array manual
	_carregar_todos_os_edificios()
	_carregar_todas_as_missoes()
	Global.turno = 0
	Global.popularidade = 40
	Global.dinheiro = 1000
	Global.populacao = 10
	# Reseta os motivos de derrota ao iniciar uma nova partida.
	Global.missaoderrota = false
	Global.enchentederrota = false
	
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
	
	if tela_compras and not tela_compras.reconstrucao_confirmada.is_connected(_on_reconstrucao_confirmada):
		tela_compras.reconstrucao_confirmada.connect(_on_reconstrucao_confirmada)
	
	if freecam_camera:
		freecam_camera.enabled = true

	# Escaneia o mapa para registrar predios que ja vieram desenhados no editor
	_escanear_mapa_inicial()
	
	_atualizar_sistema_drenagem()
	
	# Mapeia a capacidade de abrigo e equipes de bombeiros existentes no inicio
	_recalcular_recursos_resgate()
	
	print("[DEBUG-NPC] _ready: cena_npc=", cena_npc, " | npc_container=", npc_container, " | populacao_inicial=", Global.populacao)
	
	# Sorteia os NPCs iniciais de acordo com a população inicial
	_atualizar_npcs_por_populacao()

	# Encontra o DialogueManager em qualquer lugar da cena (não depende de caminho fixo)
	dialogue_manager = _encontrar_dialogue_manager()
	if dialogue_manager:
		print("[DEBUG-DIALOGO] DialogueManager encontrado em: ", dialogue_manager.get_path())
	else:
		print("[AVISO] DialogueManager não encontrado na cena! Diálogos de missão não vão tocar.")



## Procura, em toda a árvore da cena, por um node que tenha o método
## iniciar_dialogo_da_missao (assinatura do dialogue_manager.gd). Assim não
## precisamos acertar o caminho exato de onde o DialogueManager foi colocado.
func _encontrar_dialogue_manager() -> Node:
	return _buscar_no_com_metodo(self, "iniciar_dialogo_da_missao")


func _buscar_no_com_metodo(no: Node, metodo: String) -> Node:
	if no.has_method(metodo):
		return no
	for filho in no.get_children():
		var encontrado = _buscar_no_com_metodo(filho, metodo)
		if encontrado:
			return encontrado
	return null


# ==============================================================================
# GERENCIAMENTO DE ZONAS DE CONSTRUÇÃO
# ==============================================================================
func _obter_zona_no_tile(pos_tile: Vector2i) -> Node:
	var pos_global = Vector2.ZERO
	if tilemap_constructions:
		pos_global = tilemap_constructions.to_global(tilemap_constructions.map_to_local(pos_tile))
	elif tile_map:
		pos_global = tile_map.to_global(tile_map.map_to_local(pos_tile))

	var zonas = get_tree().get_nodes_in_group("zonas_construcao")
	for no in zonas:
		if no.has_method("contem_posicao_global") and no.contem_posicao_global(pos_global):
			return no
	return null


func _contar_construcoes_na_zona(zona: BuildingZone) -> int:
	if zona == null:
		return 0
		
	var total = 0
	for pos_tile in construcoes_no_mapa.keys():
		var predio = construcoes_no_mapa[pos_tile]
		if predio != null:
			var pos_global = Vector2.ZERO
			if tilemap_constructions:
				pos_global = tilemap_constructions.to_global(tilemap_constructions.map_to_local(pos_tile))
			elif tile_map:
				pos_global = tile_map.to_global(tile_map.map_to_local(pos_tile))
				
			# Verifica se o prédio está em QUALQUER área pertencente ao mesmo grupo
			if zona.contem_posicao_global_no_grupo(pos_global):
				total += 1
				
	return total


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
func contar_abrigos_construidos() -> int:
	var total_abrigos: int = 0
	for pos in construcoes_no_mapa.keys():
		var instancia: BuildingInstance = construcoes_no_mapa[pos]
		if instancia and instancia.data and instancia.durabilidade_atual > 0:
			var cat = str(instancia.data.categoria).to_lower().strip_edges() if "categoria" in instancia.data and instancia.data.categoria != null else ""
			var id_predio = str(instancia.data.id).to_lower().strip_edges() if "id" in instancia.data and instancia.data.id != null else ""
			
			# Ignora explicitamente a prefeitura
			if id_predio == "prefeitura" or "prefeitura" in cat:
				continue

			if cat == "abrigo" or "abrigo" in id_predio:
				total_abrigos += 1
	return total_abrigos


func contar_estacoes_bombeiro_construidas() -> int:
	var total_bombeiros: int = 0
	for pos in construcoes_no_mapa.keys():
		var instancia: BuildingInstance = construcoes_no_mapa[pos]
		if instancia and instancia.data and instancia.durabilidade_atual > 0:
			var cat = str(instancia.data.categoria).to_lower().strip_edges() if "categoria" in instancia.data and instancia.data.categoria != null else ""
			var id_predio = str(instancia.data.id).to_lower().strip_edges() if "id" in instancia.data and instancia.data.id != null else ""
			
			if cat == "bombeiros" or "bombeiro" in id_predio:
				total_bombeiros += 1
	return total_bombeiros


func _recalcular_recursos_resgate() -> void:
	total_capacidade_abrigo = 0
	total_equipes_resgate = 0

	var qtd_abrigos = contar_abrigos_construidos()
	var qtd_bombeiros = contar_estacoes_bombeiro_construidas()

	# 1. Recalcula a capacidade apenas se houver abrigos construídos
	if qtd_abrigos > 0:
		for pos in construcoes_no_mapa.keys():
			var instancia: BuildingInstance = construcoes_no_mapa[pos]
			if instancia and instancia.data and instancia.durabilidade_atual > 0:
				var data = instancia.data
				var nivel = instancia.nivel_atual if "nivel_atual" in instancia else 1
				var cat = str(data.categoria).to_lower().strip_edges() if "categoria" in data and data.categoria != null else ""
				var id_predio = str(data.id).to_lower().strip_edges() if "id" in data and data.id != null else ""

				if cat == "abrigo" or "abrigo" in id_predio:
					if "capacidade_abrigo" in data and data.capacidade_abrigo != null:
						total_capacidade_abrigo += int(data.capacidade_abrigo) * nivel

	# 2. Recalcula as equipes de bombeiro apenas se houver estações construídas
	if qtd_bombeiros > 0:
		for pos in construcoes_no_mapa.keys():
			var instancia: BuildingInstance = construcoes_no_mapa[pos]
			if instancia and instancia.data and instancia.durabilidade_atual > 0:
				var data = instancia.data
				var nivel = instancia.nivel_atual if "nivel_atual" in instancia else 1
				var cat = str(data.categoria).to_lower().strip_edges() if "categoria" in data and data.categoria != null else ""
				var id_predio = str(data.id).to_lower().strip_edges() if "id" in data and data.id != null else ""

				if cat == "bombeiros" or "bombeiro" in id_predio:
					if "equipes_resgate" in data and data.equipes_resgate != null:
						total_equipes_resgate += int(data.equipes_resgate) * nivel

	# 3. Sincroniza com a classe Global
	if typeof(Global) != TYPE_NIL:
		if "capacidade_total_abrigo" in Global:
			Global.capacidade_total_abrigo = total_capacidade_abrigo
		
		if "pessoas_abrigadas" in Global:
			Global.pessoas_abrigadas = clamp(Global.pessoas_abrigadas, 0, total_capacidade_abrigo)
			abrigo_ocupado = Global.pessoas_abrigadas

	# Feedback do sistema no console
	print("[SISTEMA RESGATE] Abrigos construídos: ", qtd_abrigos, 
		  " | Capacidade Total: ", total_capacidade_abrigo, 
		  " | Ocupação: ", abrigo_ocupado, "/", total_capacidade_abrigo, 
		  " | Vagas Livres: ", obter_vagas_abrigos_disponiveis())


func tem_abrigo_construido() -> bool:
	return contar_abrigos_construidos() > 0


func tem_estacao_bombeiros() -> bool:
	return contar_estacoes_bombeiro_construidas() > 0


# ==============================================================================
# SISTEMA DE TEMPO DE RESGATE POR DISTÂNCIA DE ZONAS
# ==============================================================================
func atualizar_tempo_resgate_das_zonas() -> void:
	var zonas = get_tree().get_nodes_in_group("zonas_construcao")
	var posicoes_origem: Array[Vector2] = []
	var tm = tilemap_constructions if tilemap_constructions else tile_map

	# 1. Pega a posição global de cada Estação de Bombeiros ativa no mapa
	for pos in construcoes_no_mapa.keys():
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio and predio.durabilidade_atual > 0 and predio.data:
			var id_p = str(predio.data.id).to_lower().strip_edges()
			var cat = str(predio.data.categoria).to_lower().strip_edges() if "categoria" in predio.data and predio.data.categoria != null else ""
			if "bombeiro" in id_p or "bombeiro" in cat:
				if tm:
					posicoes_origem.append(tm.to_global(tm.map_to_local(pos)))

	# 2. Fallback: Se ainda não houver bombeiros construídos, usa a posição das Zonas de Funções
	if posicoes_origem.is_empty():
		for zona in zonas:
			if zona is BuildingZone:
				var tipo = str(zona.tipo_zona).to_lower().strip_edges()
				if "func" in tipo or "serv" in tipo or "bombeiro" in tipo or "abrigo" in tipo:
					posicoes_origem.append(zona.global_position)

	# 3. Define o limite de distância em pixels (Ex: 400.0px). Altere este valor para ajustar a tolerância.
	var DISTANCIA_LIMITE_pixels: float = 400.0

	# 4. Avalia CADA zona residencial individualmente
	for z_res in zonas:
		if z_res is BuildingZone:
			var tipo = str(z_res.tipo_zona).to_lower().strip_edges()
			if "residenc" in tipo or "casa" in tipo:
				if posicoes_origem.is_empty():
					z_res.tempo_resgate = 1
					continue

				var menor_distancia: float = INF
				for pos_origem in posicoes_origem:
					var dist = z_res.global_position.distance_to(pos_origem)
					if dist < menor_distancia:
						menor_distancia = dist

				# Qualquer zona residencial além do limite de distância leva 2 turnos
				if menor_distancia > DISTANCIA_LIMITE_pixels:
					z_res.tempo_resgate = 2
				else:
					z_res.tempo_resgate = 1


func obter_tempo_resgate_para_tile(pos_tile: Vector2i) -> int:
	var tm = tilemap_constructions if tilemap_constructions else tile_map
	
	# Calcula a distância diretamente a partir da Posição Global do Tile no mapa
	if tm:
		var pos_global_tile = tm.to_global(tm.map_to_local(pos_tile))
		var menor_distancia: float = INF

		# Procura a estação de bombeiros mais próxima da casa atingida
		for pos_p in construcoes_no_mapa.keys():
			var predio: BuildingInstance = construcoes_no_mapa[pos_p]
			if predio and predio.durabilidade_atual > 0 and predio.data:
				var id_p = str(predio.data.id).to_lower().strip_edges()
				var cat = str(predio.data.categoria).to_lower().strip_edges() if "categoria" in predio.data and predio.data.categoria != null else ""
				if "bombeiro" in id_p or "bombeiro" in cat:
					var pos_bombeiro = tm.to_global(tm.map_to_local(pos_p))
					var dist = pos_global_tile.distance_to(pos_bombeiro)
					if dist < menor_distancia:
						menor_distancia = dist

		# Raio de tolerância (em pixels) para o resgate de 1 turno
		var RAIO_RESGATE_RAPIDO: float = 400.0

		if menor_distancia != INF:
			return 2 if menor_distancia > RAIO_RESGATE_RAPIDO else 1

	# Fallback para o tempo registrado na zona
	atualizar_tempo_resgate_das_zonas()
	var zona = _obter_zona_no_tile(pos_tile)
	if zona and "tempo_resgate" in zona:
		return zona.tempo_resgate

	return 1

func pode_realizar_resgate() -> bool:
	var abrigos_qtd = contar_abrigos_construidos()
	var bombeiros_qtd = contar_estacoes_bombeiro_construidas()

	if bombeiros_qtd <= 0:
		print("[RESGATE BLOQUEADO] Nenhuma Estação de Bombeiros construída no mapa.")
		return false

	if abrigos_qtd <= 0:
		print("[RESGATE BLOQUEADO] Nenhum Abrigo construído no mapa (0 abrigos / 0 vagas).")
		return false

	if obter_equipes_bombeiro_disponiveis() <= 0:
		print("[RESGATE BLOQUEADO] Todas as equipes de bombeiros estão ocupadas.")
		return false

	if obter_vagas_abrigos_disponiveis() <= 0:
		print("[RESGATE BLOQUEADO] Todos os abrigos estão lotados (", abrigo_ocupado, "/", total_capacidade_abrigo, " vagas).")
		return false

	return true


func _simular_emergencia(qtd_vitimas: int) -> void:
	print("\n--- [ALERTA] Emergência Ocorreu! Vítimas a resgatar: ", qtd_vitimas, " ---")
	print("[STATUS MAPA] Abrigos construídos: ", contar_abrigos_construidos(), 
		  " | Vagas Totais: ", total_capacidade_abrigo, 
		  " | Estações Bombeiro: ", contar_estacoes_bombeiro_construidas())

	if not pode_realizar_resgate():
		print("[RESGATE CANCELADO] O resgate não pôde ser iniciado por falta de pré-requisitos.")
		return

	if alocar_equipe_bombeiro():
		var resgatados = abrigar_pessoas(qtd_vitimas)
		print("[RESGATE SUCESSO] ", resgatados, " vítimas foram resgatadas e levadas ao abrigo.")
		liberar_equipe_bombeiro()
	else:
		print("[RESGATE FALHOU] Não foi possível alocar uma equipe de bombeiros!")


func processar_resgate_ponto(qtd_vitimas: int) -> bool:
	if not pode_realizar_resgate():
		return false

	if alocar_equipe_bombeiro():
		var resgatados = abrigar_pessoas(qtd_vitimas)
		liberar_equipe_bombeiro()
		return resgatados > 0

	return false


func processar_construcoes_no_turno() -> void:
	for pos in construcoes_no_mapa.keys():
		var instancia: BuildingInstance = construcoes_no_mapa[pos]
		if instancia and "em_construcao" in instancia and instancia.em_construcao:
			instancia.turnos_restantes -= 1
			
			if instancia.turnos_restantes <= 0:
				instancia.em_construcao = false
				
				# Restaura visualmente no TileMap para o sprite final
				_restaurar_tile_grafico(pos, instancia)
				
				# Adiciona o bônus de população somente após a conclusão da obra
				if instancia.data and "bonus_populacao" in instancia.data and instancia.data.bonus_populacao > 0:
					Global.populacao += instancia.data.bonus_populacao
					_atualizar_npcs_por_populacao()
					if _enchente_ativa == null and Global.pessoas_abrigadas > 0:
						_processar_retorno_abrigo_para_casas()
				
				# Recalcula sistemas e valida missões após a conclusão
				_recalcular_recursos_resgate()
				_atualizar_sistema_drenagem()

				if instancia.data:
					var id_limpo = str(instancia.data.id).to_lower().strip_edges() if "id" in instancia.data and instancia.data.id != null else ""
					if id_limpo == "estacao_tratamento" or id_limpo == "estacao_drenagem":
						_ativar_terrenos_zona_rio()
					elif id_limpo == "bombeiros" or id_limpo == "bombeiro":
						_ativar_terrenos_zona_funcoes()

					_verificar_conclusao_construcao(instancia.data)
					
				print("[SISTEMA] Obra concluída no tile: ", pos)


func obter_capacidade_total_abrigos() -> int:
	return total_capacidade_abrigo


func obter_vagas_abrigos_disponiveis() -> int:
	var pessoas_abrigadas = abrigo_ocupado
	if typeof(Global) != TYPE_NIL and "pessoas_abrigadas" in Global:
		pessoas_abrigadas = Global.pessoas_abrigadas
	return max(0, total_capacidade_abrigo - pessoas_abrigadas)


func obter_equipes_bombeiro_totais() -> int:
	return total_equipes_resgate


func obter_equipes_bombeiro_disponiveis() -> int:
	return max(0, total_equipes_resgate - equipes_bombeiro_ocupadas)


func alocar_equipe_bombeiro() -> bool:
	if obter_equipes_bombeiro_disponiveis() > 0:
		equipes_bombeiro_ocupadas += 1
		print("[BOMBEIROS] Equipe alocada. Ocupadas: ", equipes_bombeiro_ocupadas, "/", total_equipes_resgate)
		return true
	print("[BOMBEIROS] Falha ao alocar equipe: Nenhuma equipe disponível!")
	return false


func liberar_equipe_bombeiro() -> void:
	equipes_bombeiro_ocupadas = max(0, equipes_bombeiro_ocupadas - 1)
	print("[BOMBEIROS] Equipe liberada. Ocupadas: ", equipes_bombeiro_ocupadas, "/", total_equipes_resgate)


func abrigar_pessoas(quantidade: int) -> int:
	if not tem_abrigo_construido():
		print("[ABRIGO FALHOU] Impossível abrigar: Nenhum abrigo foi construído na cidade.")
		return 0

	var vagas = obter_vagas_abrigos_disponiveis()
	if vagas <= 0:
		print("[ABRIGO FALHOU] Impossível abrigar: Capacidade máxima atingida (", abrigo_ocupado, "/", total_capacidade_abrigo, ").")
		return 0

	var abrigadas = min(vagas, quantidade)
	abrigo_ocupado += abrigadas
	
	if typeof(Global) != TYPE_NIL:
		if "pessoas_abrigadas" in Global:
			Global.pessoas_abrigadas = abrigo_ocupado
		if "pessoas_desabrigadas" in Global:
			Global.pessoas_desabrigadas = max(0, Global.pessoas_desabrigadas - abrigadas)
		if "total_civis_resgatados" in Global:
			Global.total_civis_resgatados += abrigadas
			
	_recalcular_recursos_resgate()
	print("[ABRIGO] ", abrigadas, " pessoas abrigadas. Ocupação total: ", abrigo_ocupado, "/", total_capacidade_abrigo)
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


# ==============================================================================
# DESTRUIÇÃO E RESGATE
# ==============================================================================
func _verificar_casa_destruida(predio: BuildingInstance) -> void:
	if predio == null or predio.data == null:
		return
	if predio.durabilidade_atual > 0:
		return
	if "moradores_desabrigados" in predio and predio.moradores_desabrigados:
		return

	if "moradores_desabrigados" in predio:
		predio.moradores_desabrigados = true
	if "resgate_pendente" in predio:
		predio.resgate_pendente = true

	Global.casas_destruidas += 1

	# Cada construção destruída reduz 15 pontos de popularidade.
	# O valor nunca fica abaixo de 0.
	Global.popularidade = max(0, Global.popularidade - 15)

	# Se esta destruição fez a popularidade chegar a 0 durante uma enchente,
	# registra que a derrota veio da enchente.
	if _enchente_ativa != null and Global.popularidade <= 0:
		Global.enchentederrota = true

	_recalcular_recursos_resgate()

	_aplicar_tile_destruido(predio)

	var moradores = predio.data.bonus_populacao if "bonus_populacao" in predio.data else 0
	if moradores > 0:
		Global.populacao = max(0, Global.populacao - moradores)
		if "pessoas_desabrigadas" in Global:
			Global.pessoas_desabrigadas += moradores
		
		_atualizar_npcs_por_populacao()
		_instanciar_ponto_resgate(predio.posicao_tile, moradores)

	# Atualiza o sistema de drenagem para qualquer estrutura destruída
	_atualizar_sistema_drenagem()


func _aplicar_tile_alagado(predio: BuildingInstance) -> void:
	if not predio or not predio.data:
		return
	
	if predio.durabilidade_atual <= 0:
		return

	var b_data = predio.data
	if b_data.has_method("tem_tile_alagado") and b_data.tem_tile_alagado():
		var src_id = b_data.get_flooded_source_id() if b_data.has_method("get_flooded_source_id") else 0
		var coords = b_data.flooded_tile_atlas_coords if "flooded_tile_atlas_coords" in b_data else Vector2i(-1, -1)
		var pos_tile = predio.posicao_tile
		
		if coords != Vector2i(-1, -1):
			if tilemap_constructions:
				tilemap_constructions.set_cell(pos_tile, src_id, coords)
			elif tile_map:
				tile_map.set_cell(0, pos_tile, src_id, coords)
				
			print("[SISTEMA] Construção em ", pos_tile, " foi alterada para o sprite alagado (Source: ", src_id, ", Coords: ", coords, ")")


func _aplicar_tile_destruido(predio: BuildingInstance) -> void:
	if not predio or not predio.data:
		return
	
	var b_data = predio.data
	if b_data.has_method("tem_tile_destruido") and b_data.tem_tile_destruido():
		var src_id = b_data.get_destroyed_source_id() if b_data.has_method("get_destroyed_source_id") else 0
		var coords = b_data.destroyed_tile_atlas_coords if "destroyed_tile_atlas_coords" in b_data else Vector2i(-1, -1)
		var pos_tile = predio.posicao_tile
		
		if coords != Vector2i(-1, -1):
			if tilemap_constructions:
				
				tilemap_constructions.set_cell(pos_tile, src_id, coords)
			elif tile_map:
				tile_map.set_cell(0, pos_tile, src_id, coords)
				
			print("[SISTEMA] Construção em ", pos_tile, " foi alterada para o sprite destruído (Source: ", src_id, ", Coords: ", coords, ")")


func _instanciar_ponto_resgate(pos_tile: Vector2i, vitimas: int) -> void:
	if not cena_ponto_resgate:
		return

	var pos_global = Vector2.ZERO
	if tilemap_constructions:
		pos_global = tilemap_constructions.to_global(tilemap_constructions.map_to_local(pos_tile))
	elif tile_map:
		pos_global = tile_map.to_global(tile_map.map_to_local(pos_tile))

	# Deslocamento Y para o ícone aparecer acima da casa
	pos_global.y -= 25.0

	var turnos = obter_tempo_resgate_para_tile(pos_tile)

	var ponto = cena_ponto_resgate.instantiate()
	add_child(ponto)
	ponto.inicializar(pos_tile, pos_global, vitimas, self)
	
	if "turnos_restantes" in ponto:
		ponto.turnos_restantes = turnos
		
	print("[RESGATE] Pop-in de emergência criado no tile: ", pos_tile, " | Tempo de resgate: ", turnos, " turno(s)")


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
# LEITURA DE CLIQUES NO MAPA E TECLAS DE ATALHO
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	
	# Pressione a tecla 'T' para spawnar uma bomba no local do mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		_spawnar_bomba_teste()
		
		
	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla E para testar uma emergência no sistema de resgate
		if event.keycode == KEY_E:
			_simular_emergencia(3)
			return

		# Tecla D para aplicar dano na construção selecionada
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

	# 1. Se já existe uma construção salva na memória -> Verifica estado e durabilidade
	if construcoes_no_mapa.has(pos_tile) and construcoes_no_mapa[pos_tile] != null:
		var predio_existente: BuildingInstance = construcoes_no_mapa[pos_tile]
		
		# BLOQUEIO: Se a estrutura estiver em obra, exibe o aviso do sistema de resgate
		if "em_construcao" in predio_existente and predio_existente.em_construcao:
			if cena_ponto_resgate:
				var aviso_temp = cena_ponto_resgate.instantiate()
				add_child(aviso_temp)
				var restam = predio_existente.turnos_restantes if "turnos_restantes" in predio_existente else 1
				aviso_temp._mostrar_aviso("Esta estrutura está em construção! Restam " + str(restam) + " turno(s).")
				if "btn_fechar_aviso" in aviso_temp and aviso_temp.btn_fechar_aviso:
					aviso_temp.btn_fechar_aviso.pressed.connect(aviso_temp.queue_free)
			return

		if predio_existente.durabilidade_atual <= 0:
			if _enchente_ativa != null:
				if cena_ponto_resgate:
					var aviso_temp = cena_ponto_resgate.instantiate()
					add_child(aviso_temp)
					aviso_temp._mostrar_aviso("Não é possível reconstruir estruturas enquanto um desastre estiver ocorrendo!")
					if "btn_fechar_aviso" in aviso_temp and aviso_temp.btn_fechar_aviso:
						aviso_temp.btn_fechar_aviso.pressed.connect(aviso_temp.queue_free)
				return

			if _tem_resgate_pendente(pos_tile, predio_existente):
				if cena_ponto_resgate:
					var aviso_temp = cena_ponto_resgate.instantiate()
					add_child(aviso_temp)
					aviso_temp._mostrar_aviso("Não é possível reconstruir a casa antes de concluir o resgate dos moradores!")
					if "btn_fechar_aviso" in aviso_temp and aviso_temp.btn_fechar_aviso:
						aviso_temp.btn_fechar_aviso.pressed.connect(aviso_temp.queue_free)
				return

			tela_compras.abrir_modo_reconstrucao(predio_existente, pos_tile)
		else:
			_abrir_modo_upgrade_instancia(predio_existente)
		return

	# 2. Busca o TileData e as coordenadas do atlas no TileMap
	var tile_data: TileData = null
	var atlas_coords: Vector2i = Vector2i(-1, -1)
	if tilemap_constructions:
		tile_data = tilemap_constructions.get_cell_tile_data(pos_tile)
		atlas_coords = tilemap_constructions.get_cell_atlas_coords(pos_tile)
	elif tile_map:
		tile_data = tile_map.get_cell_tile_data(0, pos_tile)
		atlas_coords = tile_map.get_cell_atlas_coords(0, pos_tile)

	if tile_data == null: return

	# 3. Lê Custom Data Layer 'building_id'
	var building_id_custom = ""
	if tile_data.has_custom_data("building_id"):
		var raw_custom_id = tile_data.get_custom_data("building_id")
		if raw_custom_id != null:
			building_id_custom = str(raw_custom_id).strip_edges().to_lower()

	# 4. Tenta identificar o prédio pelo ID customizado ou pelas coordenadas no Atlas
	var b_data: BuildingData = null
	if building_id_custom == "terreno_vazio":
		b_data = null
	elif building_id_custom != "":
		b_data = _buscar_data_por_id(building_id_custom)
	elif atlas_coords != Vector2i(-1, -1):
		b_data = _buscar_data_por_atlas_coords(atlas_coords)

	# 5. Se o sprite pertence a um prédio válido no banco de dados, registra e abre upgrade
	if b_data != null:
		var nova_instancia = BuildingInstance.new(b_data, pos_tile)
		construcoes_no_mapa[pos_tile] = nova_instancia
		_building_data_selecionado = b_data
		_abrir_modo_upgrade_instancia(nova_instancia)
		return

	# 6. Caso contrário, verifica a zona e abre a loja para construir
	var zona_atual = _obter_zona_no_tile(pos_tile)
	var lista_opcoes = _obter_edificios_para_zona(zona_atual)
	var total_na_zona = _contar_construcoes_na_zona(zona_atual)

	if zona_atual != null:
		# BLOQUEIO DE ZONA CHEIA: Impede a abertura da loja e exibe o popup de aviso
		if not zona_atual.tem_vaga_disponivel(total_na_zona):
			if cena_ponto_resgate:
				var aviso_temp = cena_ponto_resgate.instantiate()
				add_child(aviso_temp)
				aviso_temp._mostrar_aviso("Limite máximo de edifícios nesta zona atingido!")
				if "btn_fechar_aviso" in aviso_temp and aviso_temp.btn_fechar_aviso:
					aviso_temp.btn_fechar_aviso.pressed.connect(aviso_temp.queue_free)
			return

		tela_compras.abrir_loja_com_zona(zona_atual, lista_opcoes, total_na_zona)
	else:
		tela_compras.abrir_modo_selecao(lista_opcoes)


func _obter_edificios_para_zona(zona: BuildingZone) -> Array[BuildingData]:
	var lista: Array[BuildingData] = []
	for b_data in banco_edificios.values():
		if not _eh_edificio_permitido_na_loja(b_data):
			continue
		
		if zona != null:
			if zona.pode_construir(b_data):
				lista.append(b_data)
		else:
			lista.append(b_data)
			
	return lista


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

	# Se o prédio está na lista de bloqueio inicial e ainda não foi liberado por uma missão, oculta da loja
	if edificios_bloqueados_inicialmente.has(id_limpo) and not edificios_desbloqueados.has(id_limpo):
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

	# 1. Validacao de Regras da Zona
	var id_limpo = str(b_data.id).to_lower().strip_edges() if "id" in b_data and b_data.id != null else ""
	var zona_atual = _obter_zona_no_tile(_celula_selecionada)
	
	if zona_atual:
		if "desbloqueada" in zona_atual and not zona_atual.desbloqueada:
			print("[ERRO] Esta zona precisa de um edifício requisito construído para ser utilizada!")
			return

		if not zona_atual.pode_construir(b_data):
			print("[ERRO] O edifício '", b_data.nome, "' não é permitido nesta zona!")
			return
		
		var total_na_zona = _contar_construcoes_na_zona(zona_atual)
		if not zona_atual.tem_vaga_disponivel(total_na_zona):
			print("[ERRO] Limite máximo de edifícios nesta zona atingido!")
			if cena_ponto_resgate:
				var aviso_temp = cena_ponto_resgate.instantiate()
				add_child(aviso_temp)
				aviso_temp._mostrar_aviso("Limite máximo de edifícios nesta zona atingido!")
				if "btn_fechar_aviso" in aviso_temp and aviso_temp.btn_fechar_aviso:
					aviso_temp.btn_fechar_aviso.pressed.connect(aviso_temp.queue_free)
			return
	else:
		if id_limpo == "bomba_drenagem" or "bomba" in id_limpo:
			print("[ERRO] A bomba de drenagem só pode ser construída dentro da Zona do Rio!")
			return

	# 2. Validacao e Calculo Dinamico de Custo e Tempo de Construcao
	var custo_final: int = b_data.custo_base if "custo_base" in b_data else 0
	var tempo_construcao: int = b_data.tempo_construcao_turnos if "tempo_construcao_turnos" in b_data else 0

	# Regra especial: Bomba de drenagem durante a enchente ativa
	if (id_limpo == "bomba_drenagem" or "bomba" in id_limpo) and _enchente_ativa != null:
		custo_final *= 2
		tempo_construcao = 0

	if Global.dinheiro < custo_final:
		print("[ERRO] Dinheiro insuficiente para comprar ", b_data.nome, " (Custo: ", custo_final, ")")
		_mostrar_aviso_texto("Você não possui dinheiro o suficiente!")
		return

	# 3. Transacao
	Global.dinheiro -= custo_final
	
	var precisa_construir = tempo_construcao > 0

	# A população só aumenta imediatamente se a construção for instantânea (tempo = 0)
	if not precisa_construir and b_data.bonus_populacao > 0:
		Global.populacao += b_data.bonus_populacao
		_atualizar_npcs_por_populacao()
		
		if _enchente_ativa == null and Global.pessoas_abrigadas > 0:
			_processar_retorno_abrigo_para_casas()

	# 4. Registra a nova instancia na memoria do mapa com controle de obras
	var nova_instancia = BuildingInstance.new(b_data, _celula_selecionada)
	if "variacao_index" in nova_instancia:
		nova_instancia.variacao_index = variacao_index

	if "em_construcao" in nova_instancia:
		nova_instancia.em_construcao = precisa_construir
	if "turnos_restantes" in nova_instancia:
		nova_instancia.turnos_restantes = tempo_construcao if precisa_construir else 0

	construcoes_no_mapa[_celula_selecionada] = nova_instancia

	# Registro na Zona
	if zona_atual:
		zona_por_tile[_celula_selecionada] = zona_atual
		if not construcoes_por_zona.has(zona_atual):
			construcoes_por_zona[zona_atual] = []
		if not (construcoes_por_zona[zona_atual] as Array).has(_celula_selecionada):
			(construcoes_por_zona[zona_atual] as Array).append(_celula_selecionada)

	# 5. Determina Sprite e Source ID (Modo Obra vs Modo Final)
	var novas_coords_atlas: Vector2i = Vector2i(-1, -1)
	var source_id: int = -1

	if precisa_construir:
		if b_data.has_method("get_under_construction_source_id"):
			source_id = b_data.get_under_construction_source_id()
		elif "source_id" in b_data:
			source_id = b_data.source_id

		if "under_construction_tile_atlas_coords" in b_data:
			novas_coords_atlas = b_data.under_construction_tile_atlas_coords
	else:
		if b_data.has_method("get_atlas_coord_para_construir"):
			novas_coords_atlas = b_data.get_atlas_coord_para_construir(variacao_index)
		elif "tiles_atlas_coords" in b_data and b_data.tiles_atlas_coords is Array and b_data.tiles_atlas_coords.size() > 0:
			var idx = min(variacao_index, b_data.tiles_atlas_coords.size() - 1)
			novas_coords_atlas = b_data.tiles_atlas_coords[idx]

	# 6. Fallback seguro para o source_id caso não tenha sido preenchido
	if source_id == -1:
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

	# 7. Troca o tile no TileMap
	if novas_coords_atlas != Vector2i(-1, -1):
		if tilemap_constructions:
			tilemap_constructions.set_cell(_celula_selecionada, source_id, novas_coords_atlas)
		elif tile_map:
			tile_map.set_cell(0, _celula_selecionada, source_id, novas_coords_atlas)
		
		if precisa_construir:
			print("[INFO] Obra de ", b_data.nome, " iniciada em ", _celula_selecionada, ". Conclusão em ", tempo_construcao, " turno(s).")
		else:
			print("[INFO] ", b_data.nome, " (Variação ", variacao_index, ") construído com sucesso em ", _celula_selecionada)
		
		_recalcular_recursos_resgate()
		
		if not precisa_construir:
			_verificar_conclusao_construcao(b_data)
	else:
		print("[AVISO] Nenhuma coordenada de atlas encontrada no recurso para ", b_data.nome)
	
	if not precisa_construir:
		if id_limpo == "estacao_tratamento" or id_limpo == "estacao_drenagem":
			_ativar_terrenos_zona_rio()
		elif id_limpo == "bombeiros" or id_limpo == "bombeiro":
			_ativar_terrenos_zona_funcoes()

	_atualizar_sistema_drenagem()


func _verificar_conclusao_construcao(b_data: BuildingData) -> void:
	print("[DEBUG-MISSAO] _verificar_conclusao_construcao chamada com prédio id='", b_data.id, "' | missao_escolhida=", (Global.missao_escolhida.id if Global.missao_escolhida else "null"), " | missao_aceita=", Global.missao_aceita)
	
	if Global.missao_escolhida == null or not Global.missao_aceita:
		return
	
	if not ("edificio_id_alvo" in Global.missao_escolhida):
		return
	
	var alvo = str(Global.missao_escolhida.edificio_id_alvo).strip_edges().to_lower()
	var predio_construido = str(b_data.id).strip_edges().to_lower()
	print("[DEBUG-MISSAO] edificio_id_alvo='", alvo, "' | prédio construído='", predio_construido, "'")
	
	if alvo == "" or alvo != predio_construido:
		print("[DEBUG-MISSAO] Não bateu — missão não concluída por essa construção.")
		return
	
	var missao = Global.missao_escolhida
	
	# Aplica as recompensas da missão
	Global.popularidade += missao.popularidade
	if "bonus_populacao" in missao and missao.bonus_populacao > 0:
		Global.populacao += missao.bonus_populacao
		_atualizar_npcs_por_populacao()
	
	# Registra a conclusão
	Global.missoes_concluidas.append(missao.id)
	
	print("[MISSÃO SUCESSO] '", missao.nome, "' concluída ao construir '", b_data.nome, "'!")
	
	# Guarda a missão concluída pra tela de confirmação (ver hud.gd)
	ultima_missao_concluida = missao
	
	# Reseta os estados de missão
	Global.missao_escolhida = null
	Global.missao_aceita = false
	Global.missao_atual_turnos = 0
	
	# Atualiza a interface
	_fechar_container_missao()
	_missao_check_aberta = true
	print("[DEBUG-MISSAO] _missao_check_aberta setado para true | ultima_missao_concluida='", ultima_missao_concluida.id, "'")
	if hud and hud.has_node("MissaoContainer"):
		var missao_container = hud.get_node("MissaoContainer")
		if missao_container.has_node("VBoxContainer/HBoxContainer"):
			missao_container.get_node("VBoxContainer/HBoxContainer").visible = false
		if missao_container.has_node("VBoxContainer/HBoxContainer2"):
			missao_container.get_node("VBoxContainer/HBoxContainer2").visible = true
		missao_container.visible = true
	else:
		print("[DEBUG-MISSAO] hud ou 'MissaoContainer' não encontrado — container não pôde ser reaberto!")


func _on_aprimoramento_confirmado(nome_ou_id_edificio: String) -> void:
	if _celula_selecionada == Vector2i(-1, -1): return
	if not construcoes_no_mapa.has(_celula_selecionada): return
	
	var predio: BuildingInstance = construcoes_no_mapa[_celula_selecionada]
	var custo = predio.get_custo_upgrade()
	
	if Global.dinheiro >= custo:
		Global.dinheiro -= custo
		predio.nivel_atual += 1
		
		# Atualiza os sistemas dinâmicos afetados por nível
		_recalcular_recursos_resgate()
		_atualizar_sistema_drenagem()
		_atualizar_npcs_por_populacao()
		
		print("[INFO] ", predio.data.nome, " aprimorado para o nivel ", predio.nivel_atual)
	else:
		print("[ERRO] Dinheiro insuficiente para upgrade!")


func _ativar_terrenos_zona_funcoes() -> void:
	# 1. Altera o estado do nó BuildingZone
	for zona in get_tree().get_nodes_in_group("zonas_construcao"):
		if zona is BuildingZone:
			var tipo = str(zona.tipo_zona).to_lower()
			if "func" in tipo or "serv" in tipo:
				zona.desbloquear_zona()

	# 2. Restaura as células no TileMap
	var tm = tilemap_constructions if tilemap_constructions else tile_map
	if tm:
		for item in _tiles_ocultos_zona_funcoes:
			if tm is TileMapLayer:
				tm.set_cell(item["pos"], item["source_id"], item["atlas_coords"])
			elif tm is TileMap:
				tm.set_cell(0, item["pos"], item["source_id"], item["atlas_coords"])
		_tiles_ocultos_zona_funcoes.clear()


func _ativar_terrenos_zona_rio() -> void:
	# 1. Altera o estado do nó BuildingZone
	for zona in get_tree().get_nodes_in_group("zonas_construcao"):
		if zona is BuildingZone:
			var tipo = str(zona.tipo_zona).to_lower()
			var permite_bomba = false
			
			if zona.has_method("edificios_permitidos_contem"):
				permite_bomba = zona.edificios_permitidos_contem("bomba")
				
			if "rio" in tipo or zona.precisa_estacao_tratamento or permite_bomba:
				zona.desbloquear_zona()
				
	# 2. Restaura as células no TileMap
	var tm = tilemap_constructions if tilemap_constructions else tile_map
	if tm:
		for item in _tiles_ocultos_zona_rio:
			if tm is TileMapLayer:
				tm.set_cell(item["pos"], item["source_id"], item["atlas_coords"])
			elif tm is TileMap:
				tm.set_cell(0, item["pos"], item["source_id"], item["atlas_coords"])
		_tiles_ocultos_zona_rio.clear()
	
	# 3. Avisa o jogador que a Zona do Rio foi liberada (verde suave)
	_mostrar_aviso_texto("Agora você pode construir bombas de água!", Color(0.519, 0.877, 0.572, 1.0))
		
		
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
	
	var building_id_custom = ""
	if tile_data.has_custom_data("building_id"):
		var raw_custom_id = tile_data.get_custom_data("building_id")
		if raw_custom_id != null:
			building_id_custom = str(raw_custom_id).strip_edges().to_lower()
	
	# Ignora apenas se for explicitamente marcado como terreno vazio
	if building_id_custom == "terreno_vazio":
		return

	# 1. Tenta buscar pelo building_id do TileSet
	var b_data: BuildingData = null
	if building_id_custom != "":
		b_data = _buscar_data_por_id(building_id_custom)
	
	# 2. Fallback: se o building_id não existir ou não estiver setado no TileSet, busca pelas coordenadas do Atlas
	if not b_data:
		b_data = _buscar_data_por_atlas_coords(atlas_coords)

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
		elif "flooded_tile_atlas_coords" in b_data and b_data.flooded_tile_atlas_coords == atlas_coords:
			eh_tile_construido = true
		elif building_id_custom != "":
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



func _processar_retorno_abrigo_para_casas() -> void:
	# Só libera se o desastre acabou e se houver pessoas abrigadas
	if _enchente_ativa != null or Global.pessoas_abrigadas <= 0:
		return

	# 1. Calcula a capacidade total de moradias intactas/construídas
	var capacidade_casas_intactas: int = 0
	for pos in construcoes_no_mapa.keys():
		var inst: BuildingInstance = construcoes_no_mapa[pos]
		if inst and inst.durabilidade_atual > 0 and inst.data:
			var cat = str(inst.data.categoria).to_lower().strip_edges() if "categoria" in inst.data and inst.data.categoria != null else ""
			var id_p = str(inst.data.id).to_lower().strip_edges() if "id" in inst.data and inst.data.id != null else ""
			
			if cat != "abrigo" and not "abrigo" in id_p and cat != "bombeiros":
				if "bonus_populacao" in inst.data and inst.data.bonus_populacao > 0:
					capacidade_casas_intactas += inst.data.bonus_populacao * (inst.nivel_atual if "nivel_atual" in inst else 1)

	# 2. Vagas disponíveis = Capacidade total intacta - População alojada
	var vagas_livres = max(0, capacidade_casas_intactas - Global.populacao)

	# 3. Transfere as pessoas do abrigo para as moradias e atualiza o contador histórico
	if vagas_livres > 0:
		var liberados = min(Global.pessoas_abrigadas, vagas_livres)
		Global.pessoas_abrigadas -= liberados
		Global.populacao += liberados
		
		# Registra o histórico total de pessoas resgatadas que retornaram para casa
		Global.total_pessoas_retornadas_casa += liberados
		
		_recalcular_recursos_resgate()
		_atualizar_npcs_por_populacao()
		
		print("[ABRIGO] ", liberados, " pessoas saíram do abrigo! Total acumulado resgatado/retornado: ", Global.total_pessoas_retornadas_casa)

# ==============================================================================
# SISTEMA DE MISSOES
# ==============================================================================

# Cada missão tem sua própria sequência de diálogo em dialogues.json (a
# conversa entre Secretária e Tesoureiro). Aqui mapeamos o id da missão
# para o id do PRIMEIRO nó dessa sequência.
const DIALOGO_INICIAL_POR_MISSAO := {
	"missao1": "missao1_1",
	"missao2": "missao2_1",
	"missao3": "missao3_1",
}

# Turnos fixos das missões. Não existe mais sorteio.
const TURNO_MISSAO := {
	"missao1": 2,
	"missao3": 5,
	"missao2": 7,
}

func processar_missao_programada():
	# As missões agora são escolhidas somente pelos turnos fixos definidos acima.
	if Global.turno <= 0:
		return null

	for id_missao in TURNO_MISSAO.keys():
		if Global.turno != TURNO_MISSAO[id_missao]:
			continue

		if id_missao in Global.missoes_concluidas:
			return null

		var m_data: MissionData = banco_missoes.get(id_missao)
		if m_data == null:
			print("[AVISO] Missao '", id_missao, "' nao encontrada no banco_missoes!")
			return null

		Global.missao_escolhida = m_data
		Global.missao_atual_turnos = 0
		Global.missao_aceita = false

		print("[INFO] Turno ", Global.turno, ": Missao obrigatoria - ", m_data.nome)

		# A primeira missão libera a Zona de Funções e os tiles de construção.
		if id_missao == "missao1":
			_ativar_terrenos_zona_funcoes()

		_iniciar_fluxo_da_missao(m_data)
		return Global.missao_escolhida

	return null


# ==============================================================================
# SISTEMA DE MISSOES — AÇÕES DO JOGADOR
# ==============================================================================
var _missao_check_aberta := false

# Guarda a última missão concluída, pra podermos mostrar "Missão concluída:
# <nome>" na tela de confirmação mesmo depois de Global.missao_escolhida
# já ter sido zerado (ver hud.gd -> _update_missao_info_label / _update_missao_recompensa_label).
var ultima_missao_concluida: MissionData = null


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
	print("Missão recusada: ", missao.nome, " — recursos mantidos, oportunidade perdida.")
	
	Global.missoes_concluidas.append(missao.id)
	
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
	if "bonus_populacao" in missao and missao.bonus_populacao > 0:
		Global.populacao += missao.bonus_populacao
		_atualizar_npcs_por_populacao()
	
	Global.missoes_concluidas.append(missao.id)
	
	print("Missão concluída: ", missao.nome)
	print("Gasto -> Dinheiro: ", missao.custo)
	print("Popularidade: +", missao.popularidade)
	if "bonus_populacao" in missao and missao.bonus_populacao > 0:
		print("População: +", missao.bonus_populacao)
	print("Restante -> Dinheiro: ", Global.dinheiro)
	
	# Guarda a missão concluída pra tela de confirmação (ver hud.gd)
	ultima_missao_concluida = missao
	
	Global.missao_escolhida = null
	Global.missao_aceita = false
	Global.missao_atual_turnos = 0
	
	# Mostra a tela de confirmação com "Missão concluída: <nome>", em vez de
	# simplesmente fechar o container sem feedback nenhum.
	_fechar_container_missao()
	if hud and hud.has_node("MissaoContainer"):
		_missao_check_aberta = true
		var missao_container = hud.get_node("MissaoContainer")
		if missao_container.has_node("VBoxContainer/HBoxContainer"):
			missao_container.get_node("VBoxContainer/HBoxContainer").visible = false
		if missao_container.has_node("VBoxContainer/HBoxContainer2"):
			missao_container.get_node("VBoxContainer/HBoxContainer2").visible = true
		missao_container.visible = true


## NOTA: a checagem de missão concluída por construção mora em
## _verificar_conclusao_construcao(), mais acima no arquivo. Havia uma
## segunda versão duplicada dessa função aqui (nunca era chamada, só gerava
## confusão) — removida.


## Abre a caixa de missão em modo só-consulta: mostra a informação da missão
## aceita, mas esconde os botões de Aceitar/Recusar (HBoxContainer) e mostra
## o botão de fechar (HBoxContainer2) no lugar deles.
func abrir_checagem_missao() -> void:
	if Global.missao_escolhida == null or not Global.missao_aceita:
		return
	if not hud or not hud.has_node("MissaoContainer"):
		return
	
	_missao_check_aberta = true
	
	var missao_container = hud.get_node("MissaoContainer")
	if missao_container.has_node("MarginContainer/VBoxContainer/HBoxContainer"):
		missao_container.get_node("MarginContainer/VBoxContainer/HBoxContainer").visible = false
	if missao_container.has_node("MarginContainer/VBoxContainer/HBoxContainer2"):
		missao_container.get_node("MarginContainer/VBoxContainer/HBoxContainer2").visible = true
	missao_container.visible = true


func fechar_checagem_missao() -> void:
	_missao_check_aberta = false
	_fechar_container_missao()


func desbloquear_edificio(id_edificio: String) -> void:
	var id_limpo = id_edificio.to_lower().strip_edges()
	if id_limpo != "" and not edificios_desbloqueados.has(id_limpo):
		edificios_desbloqueados.append(id_limpo)
		print("[PROGRESSÃO] Edifício liberado para construção: ", id_limpo)



func _fechar_container_missao() -> void:
	if not hud or not hud.has_node("MissaoContainer"):
		return
	var missao_container = hud.get_node("MissaoContainer")
	missao_container.visible = false
	var hbox_decisao = missao_container.get_node_or_null(
		"MarginContainer/VBoxContainer/HBoxContainer"
	)
	var hbox_fechar = missao_container.get_node_or_null(
		"MarginContainer/VBoxContainer/HBoxContainer2"
	)
	if hbox_decisao:
		hbox_decisao.visible = true
	if hbox_fechar:
		hbox_fechar.visible = false

func _abrir_container_missao() -> void:
	if hud and hud.has_node("MissaoContainer"):
		hud.get_node("MissaoContainer").visible = true
		Global.jogo_pausado = true


## Toca primeiro o diálogo da missão (Secretária/Tesoureiro) na cena
## DialogueManager, e SÓ DEPOIS que ele terminar é que a caixa de missão
## (MissaoContainer) aparece. Se não houver DialogueManager configurado ou a
## missão não tiver diálogo mapeado, cai direto na caixa de missão de sempre.
func _iniciar_fluxo_da_missao(missao: MissionData) -> void:
	# Libera o prédio alvo assim que a missão APARECE (sem precisar aceitar)
	if missao:
		if "edificio_id_alvo" in missao and missao.edificio_id_alvo != "":
			desbloquear_edificio(missao.edificio_id_alvo)
		if "edificios_para_desbloquear" in missao:
			for id_predio in missao.edificios_para_desbloquear:
				desbloquear_edificio(id_predio)

	var no_inicial: String = DIALOGO_INICIAL_POR_MISSAO.get(missao.id, "")

	if dialogue_manager and no_inicial != "" and dialogue_manager.has_method("iniciar_dialogo_da_missao"):
		if not dialogue_manager.dialogo_finalizado.is_connected(_on_dialogo_da_missao_finalizado):
			dialogue_manager.dialogo_finalizado.connect(_on_dialogo_da_missao_finalizado, CONNECT_ONE_SHOT)
		dialogue_manager.iniciar_dialogo_da_missao(no_inicial)
	else:
		if not dialogue_manager:
			print("[AVISO] DialogueManager não encontrado na cena — abrindo a missão direto na caixa.")
		_abrir_container_missao()


## Chamado quando o DialogueManager termina o diálogo da missão (conectado
## como CONNECT_ONE_SHOT em _iniciar_fluxo_da_missao). A cena do diálogo já
## se desativa sozinha (ver dialogue_manager.gd -> end_dialogue); aqui só
## precisamos mostrar a caixa de missão de sempre.
func _on_dialogo_da_missao_finalizado(_ultimo_no_id: String) -> void:
	_abrir_container_missao()


func processar_missao_no_turno() -> void:
	if Global.missao_escolhida != null and Global.missao_aceita:
		var popularidade_antes: int = Global.popularidade
		var popularidade_perdida = Global.missao_escolhida.popularidade * 1.5
		Global.popularidade -= popularidade_perdida
		print("Missão '", Global.missao_escolhida.nome, "' falhou por não ter sido concluída a tempo! Popularidade perdida: -", popularidade_perdida)

		# A missão só é marcada como causa da derrota se a penalidade dela
		# for o que fez a popularidade chegar a 0 ou menos.
		if popularidade_antes > 0 and Global.popularidade <= 0:
			Global.missaoderrota = true
			print(Global.missaoderrota)
		
		Global.missao_escolhida = null
		Global.missao_aceita = false
		Global.missao_atual_turnos = 0
	
	# Não sorteia uma missão nova enquanto a tela de "Missão concluída!" ainda
	# estiver aberta esperando o jogador fechar — senão ela é substituída na
	# hora pelo popup da PRÓXIMA missão, e "Missão concluída!" nunca aparece.
	if not _missao_check_aberta:
		processar_missao_programada()
	
	_verificar_derrota()


## Se a popularidade cair abaixo de 0, a população perdeu a confiança na
## gestão e o jogo termina ali — vai direto pra tela de derrota.
func _verificar_derrota() -> void:
	if Global.popularidade <= 0:
		print("[FIM DE JOGO] Popularidade chegou a 0 ou menos (", Global.popularidade, "). Indo para tela de derrota.")
		print("[FIM DE JOGO] missaoderrota=", Global.missaoderrota, " | enchentederrota=", Global.enchentederrota)
		get_tree().change_scene_to_file("res://Jogo principal/derrota.tscn")


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

	var cap_abrigo = b_data.capacidade_abrigo if "capacidade_abrigo" in b_data and b_data.capacidade_abrigo != null else 0
	var eq_resgate = b_data.equipes_resgate if "equipes_resgate" in b_data and b_data.equipes_resgate != null else 0

	# Exibe o custo ajustado na UI caso esteja em situação de desastre
	var custo: int = b_data.custo_base if "custo_base" in b_data else 0
	var id_limpo = str(b_data.id).to_lower().strip_edges() if "id" in b_data and b_data.id != null else ""
	if (id_limpo == "bomba_drenagem" or "bomba" in id_limpo) and _enchente_ativa != null:
		custo *= 2

	tela_compras.abrir_modo_compra(
		nome_exibicao,
		cat_nome,
		b_data.descricao_curta if "descricao_curta" in b_data else "",
		b_data.bonus_populacao if "bonus_populacao" in b_data else 0,
		custo,
		tex,
		b_data.texto_detalhes if "texto_detalhes" in b_data else "",
		nome_exibicao,
		cap_abrigo,
		eq_resgate
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
	if not predio or not predio.data:
		return

	var b_data = predio.data
	var idx = predio.variacao_index if "variacao_index" in predio else 0
	var tex = b_data.get_icone_variacao(idx) if b_data.has_method("get_icone_variacao") else (b_data.icone if "icone" in b_data and b_data.icone else icone_temp)
	
	# Recalcula a capacidade atualizada dos abrigos e equipes
	if has_method("_recalcular_recursos_resgate"):
		_recalcular_recursos_resgate()
	
	var cat = str(b_data.categoria).to_lower().strip_edges() if "categoria" in b_data and b_data.categoria != null else ""
	var id_predio = str(b_data.id).to_lower().strip_edges() if "id" in b_data and b_data.id != null else ""
	
	var texto_stats_custom = ""
	
	# Caso a construção seja um abrigo, exibe a contagem de vagas
	if cat == "abrigo" or "abrigo" in id_predio or ("capacidade_abrigo" in b_data and b_data.capacidade_abrigo > 0):
		var vagas_disponiveis = obter_vagas_abrigos_disponiveis() if has_method("obter_vagas_abrigos_disponiveis") else 0
		var cap_total = total_capacidade_abrigo if "total_capacidade_abrigo" in self else 0
		texto_stats_custom = tr("UI_VAGAS_ABRIGO") + ": " + str(vagas_disponiveis) + " / " + str(cap_total)
	elif cat == "bombeiros" or "bombeiro" in id_predio or ("equipes_resgate" in b_data and b_data.equipes_resgate > 0):
		var equipes_disponiveis = obter_equipes_bombeiro_disponiveis() if has_method("obter_equipes_bombeiro_disponiveis") else 0
		var eq_total = total_equipes_resgate if "total_equipes_resgate" in self else 0
		texto_stats_custom = tr("UI_EQUIPES_RESGATE") + ": " + str(equipes_disponiveis) + " / " + str(eq_total)

	if tela_compras and tela_compras.has_method("abrir_modo_upgrade"):
		var n_atual = predio.nivel_atual if "nivel_atual" in predio else 1
		var n_max = b_data.nivel_maximo if "nivel_maximo" in b_data else 1
		var pode_up = b_data.pode_aprimorar if "pode_aprimorar" in b_data else false
		
		tela_compras.abrir_modo_upgrade(
			b_data.nome if "nome" in b_data else "",
			n_atual,
			predio.get_ganhos_atuais() if predio.has_method("get_ganhos_atuais") else 0,
			predio.get_durabilidade_pct() if predio.has_method("get_durabilidade_pct") else 1.0,
			predio.get_custo_upgrade() if predio.has_method("get_custo_upgrade") else 0,
			tex,
			b_data.descricao_curta if "descricao_curta" in b_data else "",
			b_data.texto_detalhes if "texto_detalhes" in b_data else "",
			pode_up and (n_atual < n_max),
			texto_stats_custom
		)

func _on_reconstrucao_confirmada(pos_tile: Vector2i, custo: int) -> void:
	# 0. Impede a reconstrução se houver desastre ativo
	if _enchente_ativa != null:
		print("[RECONSTRUÇÃO BLOQUEADA] Impossível reconstruir durante um desastre ativo!")
		if cena_ponto_resgate:
			var aviso_temp = cena_ponto_resgate.instantiate()
			add_child(aviso_temp)
			aviso_temp._mostrar_aviso("Não é possível reconstruir estruturas enquanto um desastre estiver ocorrendo!")
			if "btn_fechar_aviso" in aviso_temp and aviso_temp.btn_fechar_aviso:
				aviso_temp.btn_fechar_aviso.pressed.connect(aviso_temp.queue_free)
		return

	if _tem_resgate_pendente(pos_tile):
		print("[RECONSTRUÇÃO BLOQUEADA] O resgate das pessoas desta casa ainda não foi concluído!")
		if cena_ponto_resgate:
			var aviso_temp = cena_ponto_resgate.instantiate()
			add_child(aviso_temp)
			aviso_temp._mostrar_aviso("Não é possível reconstruir a casa antes de concluir o resgate dos moradores!")
			if "btn_fechar_aviso" in aviso_temp and aviso_temp.btn_fechar_aviso:
				aviso_temp.btn_fechar_aviso.pressed.connect(aviso_temp.queue_free)
		return

	if not construcoes_no_mapa.has(pos_tile):
		print("[RECONSTRUÇÃO ERRO] Construção não encontrada na posição: ", pos_tile)
		return

	# Verificação de Saldo
	var dinheiro_atual = Global.dinheiro if typeof(Global) != TYPE_NIL and "dinheiro" in Global else 999999
	if dinheiro_atual < custo:
		print("[RECONSTRUÇÃO BLOQUEADA] Dinheiro insuficiente! Necessário: $", custo)
		return

	# 1. Deduz o Custo
	if typeof(Global) != TYPE_NIL and "dinheiro" in Global:
		Global.dinheiro -= custo

	# 2. Restaura a Durabilidade e o Estado da Estrutura
	var instancia: BuildingInstance = construcoes_no_mapa[pos_tile]
	var durabilidade_max = instancia.durabilidade_maxima if "durabilidade_maxima" in instancia else 100
	instancia.durabilidade_atual = durabilidade_max
	
	if "moradores_desabrigados" in instancia:
		instancia.moradores_desabrigados = false
	if "resgate_pendente" in instancia:
		instancia.resgate_pendente = false

	# 3. Gerencia a População e a Desocupação do Abrigo
	if instancia.data and "bonus_populacao" in instancia.data and instancia.data.bonus_populacao > 0:
		if Global.pessoas_abrigadas > 0:
			# Se houver desabrigados no abrigo, move-os de volta para esta casa restaurada
			_processar_retorno_abrigo_para_casas()
		else:
			# Se o abrigo já estiver vazio, restaura a população original normalmente
			var moradores = instancia.data.bonus_populacao
			Global.populacao += moradores
			_atualizar_npcs_por_populacao()

	# 4. Restaura Visualmente no TileMap
	_restaurar_tile_grafico(pos_tile, instancia)

	# 5. Recalcula Redes de Resgate, Abrigos e Drenagem
	_recalcular_recursos_resgate()
	_atualizar_sistema_drenagem()

	print("[RECONSTRUÇÃO SUCESSO] Estrutura '", instancia.data.nome, "' reconstruída em ", pos_tile)


func _bloquear_zona_funcoes_ate_turno_2() -> void:
	for zona in get_tree().get_nodes_in_group("zonas_construcao"):
		if zona is BuildingZone:
			var tipo_zona := str(zona.tipo_zona).to_lower().strip_edges()
			if (
				tipo_zona == "funcoes"
				or tipo_zona == "funcao"
				or tipo_zona == "servicos"
				or tipo_zona == "servico"
				or "func" in tipo_zona
				or "serv" in tipo_zona
			):
				zona.desbloqueada = false
				zona.definir_visibilidade_terrenos(false)


func _ocultar_terrenos_zona_bloqueada() -> void:
	var tm: Object = tilemap_constructions if tilemap_constructions else tile_map
	if not tm:
		return

	var celulas = tm.get_used_cells() if tm is TileMapLayer else tm.get_used_cells(0)

	for pos in celulas:
		# Nunca esconde o tile de uma construção que já existe no mapa.
		if construcoes_no_mapa.has(pos):
			continue

		var zona = _obter_zona_no_tile(pos)
		if zona == null:
			continue

		var tipo_zona := ""
		if "tipo_zona" in zona and zona.tipo_zona != null:
			tipo_zona = str(zona.tipo_zona).to_lower().strip_edges()

		var eh_zona_funcoes: bool = (
			tipo_zona == "funcoes"
			or tipo_zona == "funcao"
			or tipo_zona == "servicos"
			or tipo_zona == "servico"
			or "func" in tipo_zona
			or "serv" in tipo_zona
		)

		var eh_zona_rio: bool = (
			"rio" in tipo_zona
			or "ribeir" in tipo_zona
			or ("precisa_estacao_tratamento" in zona and zona.precisa_estacao_tratamento)
		)

		# A Zona de Funções tem uma regra especial: os tiles de construção
		# ficam invisíveis desde o começo da partida e só reaparecem quando
		# a primeira missão for criada, no turno 2.
		# Isso é independente de desbloqueada_por_padrao.
		var deve_ocultar: bool = false
		if eh_zona_funcoes:
			deve_ocultar = true
		elif eh_zona_rio:
			var zona_desbloqueada: bool = false
			if "desbloqueada" in zona and zona.desbloqueada != null:
				zona_desbloqueada = bool(zona.desbloqueada)
			deve_ocultar = not zona_desbloqueada

		if not deve_ocultar:
			continue

		var src_id = tm.get_cell_source_id(pos) if tm is TileMapLayer else tm.get_cell_source_id(0, pos)
		if src_id == -1:
			continue

		var atlas_coords = tm.get_cell_atlas_coords(pos) if tm is TileMapLayer else tm.get_cell_atlas_coords(0, pos)

		var dados_tile = {
			"pos": pos,
			"source_id": src_id,
			"atlas_coords": atlas_coords
		}

		if eh_zona_funcoes:
			var ja_salvo_funcoes := false
			for item in _tiles_ocultos_zona_funcoes:
				if item["pos"] == pos:
					ja_salvo_funcoes = true
					break
			if not ja_salvo_funcoes:
				_tiles_ocultos_zona_funcoes.append(dados_tile)
		else:
			var ja_salvo_rio := false
			for item in _tiles_ocultos_zona_rio:
				if item["pos"] == pos:
					ja_salvo_rio = true
					break
			if not ja_salvo_rio:
				_tiles_ocultos_zona_rio.append(dados_tile)

		if tm is TileMapLayer:
			tm.set_cell(pos, -1)
		elif tm is TileMap:
			tm.set_cell(0, pos, -1)

	print("[ZONA FUNÇÕES] Tiles de construção ocultados até a primeira missão (turno 2).")


func _restaurar_tile_grafico(pos_tile: Vector2i, instancia: BuildingInstance) -> void:
	var tm: Object = tilemap_constructions if tilemap_constructions else tile_map
	if not tm or not instancia or not instancia.data: return

	var b_data = instancia.data
	var source_id = b_data.source_id if "source_id" in b_data else 0
	
	# Resgata a variação original que foi construída no local
	var idx = instancia.variacao_index if "variacao_index" in instancia else 0
	var atlas_coords: Vector2i = Vector2i.ZERO
	if b_data.has_method("get_atlas_coord_para_construir"):
		atlas_coords = b_data.get_atlas_coord_para_construir(idx)
	elif "tiles_atlas_coords" in b_data and b_data.tiles_atlas_coords is Array and b_data.tiles_atlas_coords.size() > 0:
		var i = min(idx, b_data.tiles_atlas_coords.size() - 1)
		atlas_coords = b_data.tiles_atlas_coords[i]
	elif "atlas_coords" in b_data:
		atlas_coords = b_data.atlas_coords

	# Identifica o tipo correto do nó para chamar set_cell sem erros de tipo
	if tm is TileMapLayer:
		tm.set_cell(pos_tile, source_id, atlas_coords)
	elif tm is TileMap:
		tm.set_cell(0, pos_tile, source_id, atlas_coords)
	else:
		tm.call("set_cell", pos_tile, source_id, atlas_coords)


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
		
		# Se as coordenadas do tile forem o 'tile_vazio' do recurso, ignora (indica terreno sem construção)
		if b_data.has_method("tem_tile_vazio") and b_data.tem_tile_vazio() and b_data.tile_vazio_atlas_coords == coords:
			continue
			
		if "tiles_atlas_coords" in b_data and b_data.tiles_atlas_coords is Array and b_data.tiles_atlas_coords.has(coords):
			return b_data
		if "atlas_coords" in b_data and b_data.atlas_coords == coords:
			return b_data
		if "tile_atlas_coords" in b_data and b_data.tile_atlas_coords == coords:
			return b_data
		if "flooded_tile_atlas_coords" in b_data and b_data.flooded_tile_atlas_coords == coords:
			return b_data
	return null

func _executar_fallback_por_string(id_str: String) -> void:
	print("[AVISO] Fallback acionado para ID: ", id_str)


func _on_desastre_button_pressed() -> void:
	_iniciar_enchente()


# ==============================================================================
# INTEGRAÇÃO COM A CENA DE DESASTRE: ENCHENTE E ZONAS
# ==============================================================================
var _enchente_ativa: Node = null

# Alerta de enchente (pausa o jogo e pisca "Alerta de enchente" por 5s antes
# da enchente começar de fato). Evita disparar duas vezes no mesmo turno.
var _alerta_enchente_em_andamento := false
# Cache do RichTextLabel de avisos ("Avisos" no UI.tscn), resolvido na
# primeira vez que precisamos dele (ver _obter_richtext_avisos).
var _richtext_avisos: RichTextLabel = null

# Tween ativo de um aviso de texto simples (ex: "dinheiro insuficiente"),
# guardado pra poder cancelar um aviso anterior se outro for disparado antes
# dele terminar (evita ficar empilhando fades).
var _tween_aviso_texto: Tween = null

## duracao_customizada: se > 0, sobrescreve a duração padrão da cena de enchente
## (usado pela enchente automática, que dura duracao_enchente_turnos turnos).
## Deixe -1 (padrão) para usar a duração configurada na própria cena.
func _iniciar_enchente(duracao_customizada: int = -1) -> void:
	if not cena_enchente:
		print("[AVISO] Nenhuma cena de Enchente configurada em 'cena_enchente' (Inspector do main_game)!")
		return
	
	if _enchente_ativa:
		print("[AVISO] Já existe uma enchente ativa! Aguarde ela terminar antes de iniciar outra.")
		return
	
	var enchente = cena_enchente.instantiate()
	if duracao_customizada > 0 and "duracao_turnos" in enchente:
		enchente.duracao_turnos = duracao_customizada
	add_child(enchente)
	if enchente.has_signal("enchente_iniciada"):
		enchente.enchente_iniciada.connect(_on_enchente_iniciada)
	if enchente.has_signal("enchente_terminada"):
		enchente.enchente_terminada.connect(_on_enchente_terminada)
	_enchente_ativa = enchente
	
	# Alaga o TileMapBase inteiro assim que a enchente começa — ele guarda
	# o mapa original sozinho e restaura tudo quando ela terminar.
	if tilemap_base and tilemap_base.has_method("alagar_mapa"):
		tilemap_base.alagar_mapa()
	
	# Se já existem Bombas de Drenagem construídas, a enchente já nasce mitigada
	if enchente.has_method("definir_mitigacao"):
		enchente.definir_mitigacao(_calcular_mitigacao_enchente())
	
	Global.enchente += 1
	if "desastres" in Global and Global.desastres.has("enchente"):
		Global.desastres["enchente"] += 1


# ==============================================================================
# CORREÇÕES DO SISTEMA DE DRENAGEM E MITIGAÇÃO
# ==============================================================================

func _spawnar_bomba_teste() -> void:
	var tm: Object = tilemap_constructions if tilemap_constructions else tile_map
	if not tm:
		print("[ERRO] Nenhum TileMap ou TileMapLayer configurado!")
		return

	# 1. Carrega o recurso da bomba
	var bomba_data = load("res://recursos/construcoes/bomba_drenagem.tres") as BuildingData
	if not bomba_data:
		bomba_data = _buscar_data_por_id("bomba_drenagem")

	if not bomba_data:
		print("[ERRO] Recurso da bomba não encontrado!")
		return

	var pos_mouse = get_global_mouse_position()
	var pos_tile: Vector2i = tm.local_to_map(tm.to_local(pos_mouse))
	var pos_global: Vector2 = tm.to_global(tm.map_to_local(pos_tile))

	# 2. Valida se a posição atual está dentro de uma zona permitida
	var dentro_de_zona_valida: bool = false
	for zona in get_tree().get_nodes_in_group("zonas_construcao"):
		if zona is BuildingZone:
			if zona.contem_posicao_global(pos_global) and zona.pode_construir(bomba_data):
				dentro_de_zona_valida = true
				break

	if not dentro_de_zona_valida:
		print("[BLOQUEADO] A bomba de drenagem só pode ser construída na Zona do Rio!")
		return

	# 3. Instancia a bomba no mapa
	var nova_bomba = BuildingInstance.new(bomba_data, pos_tile)
	if "durabilidade_maxima" in bomba_data:
		nova_bomba.durabilidade_atual = bomba_data.durabilidade_maxima
	else:
		nova_bomba.durabilidade_atual = 100.0

	construcoes_no_mapa[pos_tile] = nova_bomba

	# 4. Renderiza visualmente
	var source_id: int = bomba_data.source_id
	var atlas_coords: Vector2i = bomba_data.get_atlas_coord_para_construir()

	if tm is TileMapLayer:
		tm.set_cell(pos_tile, source_id, atlas_coords)
	elif tm is TileMap:
		tm.set_cell(0, pos_tile, source_id, atlas_coords)

	_atualizar_sistema_drenagem()
	print("Bomba de teste adicionada na Zona do Rio | Tile: ", pos_tile)
	print("Nova mitigação da enchente: ", _calcular_mitigacao_enchente() * 100.0, "%")


func _calcular_mitigacao_enchente() -> float:
	# 1. Checa se existe uma Estação de Tratamento/Drenagem ativa e inteira
	var tem_estacao: bool = false
	var qtd_bombas: int = 0

	for pos in construcoes_no_mapa.keys():
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio and predio.durabilidade_atual > 0 and predio.data:
			var id_predio = str(predio.data.id).to_lower().strip_edges()
			if id_predio == "estacao_tratamento" or id_predio == "estacao_drenagem":
				tem_estacao = true
			elif id_predio == "bomba_drenagem" or "bomba" in id_predio:
				qtd_bombas += 1

	# Se a estação estiver destruída ou ausente, a mitigação zerará
	if not tem_estacao:
		return 0.0

	# 2. Usa o sistema de drenagem como prioridade se disponível
	if sistema_drenagem and sistema_drenagem.has_method("obter_multiplicador_dano"):
		var mult_dano = sistema_drenagem.obter_multiplicador_dano()
		var mitigacao = 1.0 - mult_dano
		return clamp(mitigacao, 0.0, mitigacao_maxima_enchente)

	# 3. Fallback: calcula diretamente com base nas variáveis exportadas
	var mitigacao_total = float(qtd_bombas) * mitigacao_por_bomba
	return clamp(mitigacao_total, 0.0, mitigacao_maxima_enchente)


func _atualizar_sistema_drenagem() -> void:
	if not sistema_drenagem:
		return

	# 1. Verifica se a estação principal está ativa
	var tem_estacao: bool = false
	for pos in construcoes_no_mapa.keys():
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio and predio.durabilidade_atual > 0 and predio.data:
			var id_predio = str(predio.data.id).to_lower().strip_edges()
			if id_predio == "estacao_tratamento" or id_predio == "estacao_drenagem":
				tem_estacao = true
				break

	sistema_drenagem.definir_estacao_construida(tem_estacao)

	# 2. Se não houver estação ativa, desativa o efeito na enchente
	if not tem_estacao:
		if _enchente_ativa and _enchente_ativa.has_method("definir_mitigacao"):
			_enchente_ativa.definir_mitigacao(0.0)
		return

	# 3. Sincroniza bombas ativas no mapa
	if "_sprites_bombas" in sistema_drenagem:
		for pos_tile in sistema_drenagem._sprites_bombas.keys():
			if not construcoes_no_mapa.has(pos_tile) or construcoes_no_mapa[pos_tile].durabilidade_atual <= 0:
				sistema_drenagem.remover_bomba_do_tile(pos_tile)

		for pos_tile in construcoes_no_mapa.keys():
			var predio: BuildingInstance = construcoes_no_mapa[pos_tile]
			if predio and predio.durabilidade_atual > 0 and predio.data:
				var id_predio = str(predio.data.id).to_lower().strip_edges()
				if id_predio == "bomba_drenagem" or "bomba" in id_predio:
					if not sistema_drenagem._sprites_bombas.has(pos_tile):
						var pos_global = Vector2.ZERO
						if tilemap_constructions:
							pos_global = tilemap_constructions.to_global(tilemap_constructions.map_to_local(pos_tile))
						elif tile_map:
							pos_global = tile_map.to_global(tile_map.map_to_local(pos_tile))

						sistema_drenagem.adicionar_bomba_no_tile(pos_tile, pos_global)

	# 4. Atualiza a mitigação na enchente ativa
	if _enchente_ativa and _enchente_ativa.has_method("definir_mitigacao"):
		_enchente_ativa.definir_mitigacao(_calcular_mitigacao_enchente())


func _on_enchente_terminada() -> void:
	_enchente_ativa = null
	
	# A enchente acabou. Os NPCs voltam gradualmente:
	# primeiro metade, depois a outra metade.
	_reaparecer_npcs_aos_poucos()
	print("[DESASTRE] Enchente finalizada. Verificando retorno de desabrigados para casas...")
	
	# Restaura o TileMapBase pro estado de antes da enchente
	if tilemap_base and tilemap_base.has_method("restaurar_mapa"):
		tilemap_base.restaurar_mapa()
	
	# Restaura visualmente todas as construções intactas que não estejam em obra
	for pos in construcoes_no_mapa.keys():
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio and predio.durabilidade_atual > 0:
			if not ("em_construcao" in predio and predio.em_construcao):
				_restaurar_tile_grafico(pos, predio)
	
	_processar_retorno_abrigo_para_casas()


func _reaparecer_npcs_aos_poucos() -> void:
	var npcs := get_tree().get_nodes_in_group("npcs")
	
	if npcs.is_empty():
		return
	
	var metade: int = ceili(npcs.size() / 2.0)
	
	# Primeira metade.
	for i in range(metade):
		if is_instance_valid(npcs[i]) and npcs[i].has_method("mostrar_depois_da_enchente"):
			npcs[i].mostrar_depois_da_enchente()
	
	# Segunda metade após 2 segundos.
	await get_tree().create_timer(2.0).timeout
	
	for i in range(metade, npcs.size()):
		if is_instance_valid(npcs[i]) and npcs[i].has_method("mostrar_depois_da_enchente"):
			npcs[i].mostrar_depois_da_enchente()


## Verifica se é a hora de disparar a enchente automaticamente (turno_inicio_enchente),
## sem depender do botão de teste. Chamada uma vez por turno, antes de tudo o resto.
func _verificar_inicio_automatico_de_enchente() -> void:
	if Global.turno == turno_inicio_enchente and _enchente_ativa == null and not _alerta_enchente_em_andamento:
		_alerta_enchente_em_andamento = true
		_mostrar_alerta_e_iniciar_enchente()


## Pausa o jogo, mostra "Alerta de enchente" piscando lentamente em vermelho
## no RichTextLabel de avisos por 5 segundos e, ao final, despausa e só então
## inicia a enchente de verdade.
func _mostrar_alerta_e_iniciar_enchente() -> void:
	print("[ENCHENTE AUTOMÁTICA] Turno ", Global.turno, " — exibindo alerta antes de iniciar (duração: ", duracao_enchente_turnos, " turnos)")
	
	Global.jogo_pausado = true
	get_tree().paused = true
	
	var aviso: RichTextLabel = _obter_richtext_avisos()
	var tween: Tween = null
	
	if aviso:
		aviso.bbcode_enabled = true
		aviso.text = "[center][color=red]Alerta de enchente!!![/color][/center]"
		aviso.modulate = Color.WHITE
		aviso.visible = true
		
		# Pisca lentamente (fade in/out do alpha). TWEEN_PAUSE_PROCESS faz o
		# tween continuar rodando mesmo com a árvore pausada.
		tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_loops()
		tween.tween_property(aviso, "modulate:a", 0.15, 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(aviso, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	else:
		print("[AVISO] Não encontrei o RichTextLabel de avisos (procurei pela propriedade 'avisos' de ui.gd e pelo nó 'Avisos'). Ajuste em _obter_richtext_avisos().")
	
	# Espera 5 segundos reais, mesmo com o jogo pausado (create_timer com
	# process_always=true, o padrão, continua rodando durante a pausa).
	await get_tree().create_timer(5.0).timeout
	
	if tween and tween.is_valid():
		tween.kill()
	
	if aviso:
		aviso.visible = false
		aviso.modulate = Color.WHITE
	
	Global.jogo_pausado = false
	get_tree().paused = false
	
	_alerta_enchente_em_andamento = false
	_iniciar_enchente(duracao_enchente_turnos)


## Procura o RichTextLabel usado pros avisos em qualquer lugar da árvore do
## HUD, pelo nome "RichTextAvisos". Se o nó tiver outro nome na sua cena,
## troque o nome aqui.
## Procura o RichTextLabel usado pros avisos ("Avisos" no UI.tscn, exposto
## em ui.gd como "avisos"). Tenta primeiro pela propriedade @onready de
## ui.gd; se não achar, cai pro nome do nó direto.
func _obter_richtext_avisos() -> RichTextLabel:
	if _richtext_avisos:
		return _richtext_avisos
	if hud:
		if "avisos" in hud and hud.avisos is RichTextLabel:
			_richtext_avisos = hud.avisos
		else:
			_richtext_avisos = hud.find_child("Avisos", true, false) as RichTextLabel
	return _richtext_avisos


## Mostra uma mensagem curta no RichTextLabel de avisos: aparece com fade in
## suave, fica visível por 'duracao' segundos e some com fade out — sem
## piscar. Usado pra avisos rápidos, tipo "dinheiro insuficiente". Usa fonte
## menor (27) que o padrão do label (38) — só pra esses avisos, nunca pro
## alerta de enchente.
func _mostrar_aviso_texto(texto: String, cor: Color = Color(1.0, 0.287, 0.227, 1.0), duracao: float = 1.5, fade_seg: float = 1.0) -> void:
	var aviso: RichTextLabel = _obter_richtext_avisos()
	if aviso == null:
		print("[AVISO] Não encontrei o RichTextLabel de avisos pra mostrar: ", texto)
		return
	
	if _tween_aviso_texto and _tween_aviso_texto.is_valid():
		_tween_aviso_texto.kill()
	
	aviso.bbcode_enabled = true
	aviso.text = "[center][font_size=27][color=#%s]%s[/color][/font_size][/center]" % [cor.to_html(false), texto]
	aviso.visible = true
	aviso.modulate.a = 0.0
	
	_tween_aviso_texto = create_tween()
	_tween_aviso_texto.tween_property(aviso, "modulate:a", 1.0, fade_seg)
	_tween_aviso_texto.tween_interval(duracao)
	_tween_aviso_texto.tween_property(aviso, "modulate:a", 0.0, fade_seg)


func avancar_turno_desastres() -> void:
	# Processa o progresso de todas as construções em andamento
	processar_construcoes_no_turno()

	_verificar_inicio_automatico_de_enchente()

	if _enchente_ativa:
		if _enchente_ativa.has_method("definir_mitigacao"):
			_enchente_ativa.definir_mitigacao(_calcular_mitigacao_enchente())
		_enchente_ativa.turno_passou()

	# Avança o tempo de todos os pontos de resgate ativos na cena
	get_tree().call_group("pontos_resgate", "avancar_turno")


func _tem_resgate_pendente(pos_tile: Vector2i, predio: BuildingInstance = null) -> bool:
	if predio != null and "resgate_pendente" in predio and predio.resgate_pendente:
		return true

	var pontos = get_tree().get_nodes_in_group("pontos_resgate")
	for ponto in pontos:
		var p_tile = Vector2i(-999, -999)
		if "pos_tile" in ponto:
			p_tile = ponto.pos_tile
		elif "posicao_tile" in ponto:
			p_tile = ponto.posicao_tile
		elif "tile_pos" in ponto:
			p_tile = ponto.tile_pos

		if p_tile == pos_tile:
			return true

	return false


func _on_enchente_iniciada(area_pixels: Rect2, dano: float) -> void:
	# A enchente começou: TODOS os NPCs desaparecem imediatamente.
	# O controle é feito aqui no main_game porque este sinal é garantidamente
	# recebido pelo nó que criou a enchente.
	get_tree().call_group("npcs", "_esconder_durante_enchente")
	
	var atingidos := 0
	
	for pos in construcoes_no_mapa.keys():
		var predio: BuildingInstance = construcoes_no_mapa[pos]
		if predio == null:
			continue
		
		var pos_global: Vector2
		if tilemap_constructions:
			pos_global = tilemap_constructions.to_global(tilemap_constructions.map_to_local(pos))
		elif tile_map:
			pos_global = tile_map.to_global(tile_map.map_to_local(pos))
		else:
			continue
		
		if not area_pixels.has_point(pos_global):
			continue
		
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
		Global.dano_total += dano_final
		atingidos += 1
		print("[ENCHENTE] Dano em ", pos, ": ", dano_final, " (Mult. Zona: x", mult_dano, ") | Vida: ", predio.durabilidade_atual)
		
		if predio.durabilidade_atual <= 0:
			_verificar_casa_destruida(predio)
		else:
			_aplicar_tile_alagado(predio)
		
		if tela_compras and tela_compras.visible and pos == _celula_selecionada:
			_abrir_modo_upgrade_instancia(predio)
	
	print("[ENCHENTE] Total de construções atingidas: ", atingidos, " / Dano base: ", dano)
