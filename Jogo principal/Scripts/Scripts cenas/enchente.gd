extends Node2D
class_name Enchente

## Quantos turnos a enchente dura no total, a partir do turno em que começou
@export var duracao_turnos: int = 7
## A cada quantos turnos o nível da enchente sobe 1
@export var turnos_por_nivel: int = 1

## Se true, sorteia posição/tamanho do AreaVisual (em tiles) na largada.
## Deixe false enquanto estiver testando o AreaVisual manualmente no editor.
@export var randomizar_area_grande: bool = false

## Usado só se randomizar_area_grande = true
@export var largura_min_tiles: int = 3
@export var largura_max_tiles: int = 6
@export var altura_min_tiles: int = 3
@export var altura_max_tiles: int = 6
@export var mapa_min_tile: Vector2i = Vector2i.ZERO
@export var mapa_max_tile: Vector2i = Vector2i(50, 50)

## Tamanho de cada tile em pixels (pra converter a área de dano em coordenadas de tile).
## Ajuste pro tile_size real do seu TileMap/TileSet.
@export var tile_size: Vector2 = Vector2(16, 16)

## Tamanho (X = largura, Y = altura, em pixels) da faixa de dano em cada nível.
## Índice 0 = nível 1, índice 1 = nível 2, etc. Níveis além do array usam o
## último valor da lista. A borda esquerda e a borda inferior ficam fixas —
## a faixa só cresce pra DIREITA (X) e pra CIMA (Y diminuindo), nunca muda de posição.
@export var tamanhos_por_nivel: Array[Vector2] = [
	Vector2(169.0, 146.0),  # Nível 1
	Vector2(271.0, 222.0),  # Nível 2
	Vector2(420.0, 291.0),  # Nível 3
	Vector2(679.0, 398.0),  # Nível 4
	Vector2(886.0, 497.0),  # Nível 5
]

## Dano de infraestrutura no nível 1
@export var dano_infraestrutura: float = 25.0
## Quanto o dano aumenta a cada nível acima do 1
@export var aumento_dano_por_nivel: float = 0.0

## Quanto tempo (segundos) a faixa de dano fica visível depois de cada atualização de turno
@export var duracao_visivel_segundos: float = 5.0

# Progresso da enchente ao longo dos turnos
var turnos_passados: int = 0
var nivel_atual: int = 1

# Posição-base (borda inferior) da faixa de dano, sorteada uma única vez
# quando a enchente começa — a partir daí ela não se move mais, só cresce.
var _pos_fixa: Vector2 = Vector2.ZERO

# Retângulo de tiles afetado no turno atual (calculado a cada atualização, com base no AreaDano)
var area_tiles: Rect2i

# Mitigação atual (0.0 a 1.0), vinda de construções como a Bomba de Drenagem.
# Reduz tanto o TAMANHO quanto o DANO da enchente. O main_game atualiza isso
# a cada turno, então bombas construídas DURANTE a enchente já fazem efeito
# a partir do próximo turno.
var mitigacao_atual: float = 0.0

## Emitido toda vez que a área de dano é (re)calculada — no início e a cada turno
## que passa enquanto a enchente segue ativa — com o retângulo de dano em
## coordenadas de PIXEL GLOBAIS (não em tiles) e o dano a aplicar. Emitir em
## pixels evita qualquer divergência entre o "tile_size" configurado aqui e o
## tamanho real das células do TileMap — quem escuta (main_game.gd) converte
## a posição de cada construção pro mundo (do mesmo jeito que já faz pra
## posicioná-la) e testa se ela cai dentro desse retângulo, garantindo que
## TODAS as construções na área tomem dano, sem exceção.
signal enchente_iniciada(area_pixels: Rect2, dano: float)
## Emitido quando a enchente sobe de nível
signal enchente_subiu_nivel(nivel: int)
## Emitido quando a enchente termina (acabou a duração em turnos)
signal enchente_terminada

@onready var area_visual: ColorRect = get_node_or_null("AreaVisual")
@onready var area_dano: ColorRect = get_node_or_null("AreaDano")
@onready var timer_visibilidade: Timer = get_node_or_null("TimerDuracao")


func _ready() -> void:
	# Checagem de segurança: avisa exatamente o que falta na cena, em vez de travar
	if not area_visual or not area_dano or not timer_visibilidade:
		if not area_visual:
			push_warning("Enchente: node 'AreaVisual' (ColorRect) não encontrado na cena!")
		if not area_dano:
			push_warning("Enchente: node 'AreaDano' (ColorRect) não encontrado na cena!")
		if not timer_visibilidade:
			push_warning("Enchente: node 'TimerDuracao' (Timer) não encontrado na cena!")
		return
	
	if randomizar_area_grande:
		_gerar_area_grande_aleatoria()
	
	# AreaVisual é só o limite onde a faixa de dano pode aparecer — não é visível pro jogador
	area_visual.visible = false
	
	timer_visibilidade.wait_time = duracao_visivel_segundos
	timer_visibilidade.one_shot = true
	timer_visibilidade.timeout.connect(_on_timer_visibilidade_terminado)
	
	_definir_area_fixa()
	
	Global.nivel_enchente = nivel_atual
	_aplicar_turno_atual()


## Chamado pelo main_game (ex: em _iniciar_enchente e a cada turno) pra
## atualizar o quanto essa enchente está sendo mitigada por construções como
## a Bomba de Drenagem. 0.0 = nenhuma mitigação | 1.0 = anularia por completo
## (o main_game já limita isso a um teto antes de chamar, pra enchente nunca
## sumir de vez só com bombas).
func definir_mitigacao(valor: float) -> void:
	mitigacao_atual = clamp(valor, 0.0, 1.0)


## Chamado pelo main_game a cada turno que passa, enquanto esta enchente estiver ativa.
func turno_passou() -> void:
	turnos_passados += 1
	
	if turnos_passados >= duracao_turnos:
		_encerrar_enchente()
		return
	
	# A cada 'turnos_por_nivel' turnos completados, sobe 1 nível
	var novo_nivel = 1 + int(turnos_passados / turnos_por_nivel)
	if novo_nivel != nivel_atual:
		nivel_atual = novo_nivel
		Global.nivel_enchente = nivel_atual
		print("[ENCHENTE] Subiu para o nível ", nivel_atual)
		enchente_subiu_nivel.emit(nivel_atual)
	
	_aplicar_turno_atual()


## Recalcula a área de dano (tamanho já refletindo o nível atual) e reaplica o dano
func _aplicar_turno_atual() -> void:
	_atualizar_tamanho_area_dano()
	_converter_area_dano_para_tiles()
	
	var dano_sem_mitigacao = dano_infraestrutura + (nivel_atual - 1) * aumento_dano_por_nivel
	var dano_atual = dano_sem_mitigacao * (1.0 - mitigacao_atual)
	
	# Reinicia a visibilidade temporária da faixa de dano
	timer_visibilidade.stop()
	timer_visibilidade.start()
	
	print("[ENCHENTE] Nível ", nivel_atual, " (turno ", turnos_passados, "/", duracao_turnos, ") | Mitigação: ", int(mitigacao_atual * 100), "% | Área: ", area_dano.position, " tamanho: ", area_dano.size, " | Dano: ", dano_atual)
	
	# Emite o retângulo em PIXELS GLOBAIS (não em tiles) — ver comentário no
	# signal acima sobre por que isso evita construções "escapando" do dano.
	var area_pixels := Rect2(area_dano.global_position, area_dano.size)
	enchente_iniciada.emit(area_pixels, dano_atual)


## (Opcional) Sorteia posição/tamanho do AreaVisual em tiles, só usado se
## randomizar_area_grande = true. Enquanto estiver testando manualmente
## pelo editor, deixe essa flag desligada.
func _gerar_area_grande_aleatoria() -> void:
	var largura = randi_range(largura_min_tiles, largura_max_tiles)
	var altura = randi_range(altura_min_tiles, altura_max_tiles)
	
	var pos_x = randi_range(mapa_min_tile.x, max(mapa_min_tile.x, mapa_max_tile.x - largura))
	var pos_y = randi_range(mapa_min_tile.y, max(mapa_min_tile.y, mapa_max_tile.y - altura))
	
	area_visual.position = Vector2(pos_x, pos_y) * tile_size
	area_visual.size = Vector2(largura, altura) * tile_size


## Sorteia, uma ÚNICA vez (quando a enchente começa), a posição-base — agora a
## borda INFERIOR, já que a faixa passou a crescer pra CIMA — da faixa de dano.
## A posição não muda mais depois disso — só o tamanho, à medida que o nível
## sobe (ver tamanhos_por_nivel). O cálculo já reserva espaço suficiente pra
## faixa crescer até o nível máximo sem estourar os limites do AreaVisual.
func _definir_area_fixa() -> void:
	# Nível máximo que essa enchente consegue alcançar, dado duracao_turnos/turnos_por_nivel
	var nivel_maximo = 1 + int(max(duracao_turnos - 1, 0) / float(turnos_por_nivel))
	var altura_maxima_possivel = _obter_tamanho_por_nivel(nivel_maximo).y
	
	# _pos_fixa.y guarda a borda INFERIOR fixa (a faixa cresce pra cima a
	# partir dela, não mais pra baixo a partir do topo)
	var y_bottom_min = area_visual.position.y + altura_maxima_possivel
	var y_bottom_max = area_visual.position.y + area_visual.size.y
	if y_bottom_min > y_bottom_max:
		y_bottom_min = y_bottom_max  # segurança, caso a altura máxima já não caiba no AreaVisual
	
	_pos_fixa = Vector2(area_visual.position.x, randf_range(y_bottom_min, y_bottom_max))


## Atualiza o TAMANHO (largura e altura) da faixa de dano, de acordo com o
## nível atual e a mitigação atual (ex: Bombas de Drenagem reduzem a altura).
## A borda inferior (_pos_fixa.y) fica fixa — a faixa cresce pra CIMA (Y
## diminuindo) conforme a altura aumenta, em vez de pra baixo.
func _atualizar_tamanho_area_dano() -> void:
	var tamanho_base = _obter_tamanho_por_nivel(nivel_atual)
	var largura = tamanho_base.x
	var altura = tamanho_base.y * (1.0 - mitigacao_atual)
	
	area_dano.position = Vector2(_pos_fixa.x, _pos_fixa.y - altura)
	area_dano.size = Vector2(largura, altura)
	area_dano.visible = true


## Retorna o tamanho (largura, altura) configurado pra esse nível em
## "tamanhos_por_nivel". Níveis acima do tamanho da lista repetem o último valor cadastrado.
func _obter_tamanho_por_nivel(nivel: int) -> Vector2:
	if tamanhos_por_nivel.is_empty():
		return area_visual.size
	var indice = clamp(nivel - 1, 0, tamanhos_por_nivel.size() - 1)
	return tamanhos_por_nivel[indice]


## Converte a área de dano (em pixels) pra coordenadas de tile, guardando
## em area_tiles — é isso que deve ser comparado com as chaves de
## construcoes_no_mapa (no main_game.gd) pra saber quais construções foram atingidas.
func _converter_area_dano_para_tiles() -> void:
	var tile_inicio := Vector2i(floori(area_dano.position.x / tile_size.x), floori(area_dano.position.y / tile_size.y))
	var tile_fim := Vector2i(ceili((area_dano.position.x + area_dano.size.x) / tile_size.x), ceili((area_dano.position.y + area_dano.size.y) / tile_size.y))
	
	area_tiles = Rect2i(tile_inicio, tile_fim - tile_inicio)


## Retorna a lista de todas as coordenadas de tile cobertas pela faixa de dano atual.
func get_tiles_afetados() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(area_tiles.position.x, area_tiles.position.x + area_tiles.size.x):
		for y in range(area_tiles.position.y, area_tiles.position.y + area_tiles.size.y):
			tiles.append(Vector2i(x, y))
	return tiles


func _on_timer_visibilidade_terminado() -> void:
	if area_dano:
		area_dano.visible = false


func _encerrar_enchente() -> void:
	print("Enchente terminou.")
	if area_dano:
		area_dano.visible = false
	Global.nivel_enchente = 0
	enchente_terminada.emit()
	queue_free()
