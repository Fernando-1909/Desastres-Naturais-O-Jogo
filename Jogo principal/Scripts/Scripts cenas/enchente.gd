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

## Tamanho de cada tile em pixels
@export var tile_size: Vector2 = Vector2(16, 16)

## Tamanho (X = largura, Y = altura) da faixa de dano em cada nível.
## A área continua aumentando conforme o nível da enchente.
@export var tamanhos_por_nivel: Array[Vector2] = [
	Vector2(169.0, 146.0),  # Nível 1
	Vector2(271.0, 222.0),  # Nível 2
	Vector2(420.0, 291.0),  # Nível 3
	Vector2(679.0, 398.0),  # Nível 4
	Vector2(886.0, 497.0),  # Nível 5
]

## Dano fixo de infraestrutura da enchente.
## O dano NÃO aumenta conforme o nível.
@export var dano_infraestrutura: float = 25.0

## Quanto tempo (segundos) a faixa de dano fica visível depois de cada atualização de turno
@export var duracao_visivel_segundos: float = 5.0


# Progresso da enchente ao longo dos turnos
var turnos_passados: int = 0
var nivel_atual: int = 1

# Posição-base (borda inferior) da faixa de dano, sorteada uma única vez
# quando a enchente começa — a partir daí ela não se move mais, só cresce.
var _pos_fixa: Vector2 = Vector2.ZERO

# Retângulo de tiles afetado no turno atual
var area_tiles: Rect2i

# Mitigação atual (0.0 a 1.0), vinda de construções como a Bomba de Drenagem.
# Reduz o TAMANHO e o DANO da enchente.
var mitigacao_atual: float = 0.0


## Emitido toda vez que a área de dano é (re)calculada.
signal enchente_iniciada(area_pixels: Rect2, dano: float)

## Emitido quando a enchente sobe de nível
signal enchente_subiu_nivel(nivel: int)

## Emitido quando a enchente termina
signal enchente_terminada


@onready var area_visual: ColorRect = get_node_or_null("AreaVisual")
@onready var area_dano: ColorRect = get_node_or_null("AreaDano")
@onready var timer_visibilidade: Timer = get_node_or_null("TimerDuracao")


func _ready() -> void:
	# Checagem de segurança
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
	
	# AreaVisual é apenas o limite da área.
	area_visual.visible = false
	
	timer_visibilidade.wait_time = duracao_visivel_segundos
	timer_visibilidade.one_shot = true
	timer_visibilidade.timeout.connect(_on_timer_visibilidade_terminado)
	
	_definir_area_fixa()
	
	Global.nivel_enchente = nivel_atual
	_aplicar_turno_atual()


## Define o quanto a enchente está sendo mitigada.
func definir_mitigacao(valor: float) -> void:
	mitigacao_atual = clamp(valor, 0.0, 1.0)


## Chamado pelo main_game a cada turno.
func turno_passou() -> void:
	turnos_passados += 1
	
	if turnos_passados >= duracao_turnos:
		_encerrar_enchente()
		return
	
	# A cada 'turnos_por_nivel' turnos completados, sobe 1 nível.
	var novo_nivel = 1 + int(turnos_passados / turnos_por_nivel)
	
	if novo_nivel != nivel_atual:
		nivel_atual = novo_nivel
		Global.nivel_enchente = nivel_atual
		
		print("[ENCHENTE] Subiu para o nível ", nivel_atual)
		enchente_subiu_nivel.emit(nivel_atual)
	
	_aplicar_turno_atual()


## Recalcula a área de dano e aplica o dano.
##
## IMPORTANTE:
## O dano é FIXO e não aumenta com o nível da enchente.
func _aplicar_turno_atual() -> void:
	_atualizar_tamanho_area_dano()
	_converter_area_dano_para_tiles()
	
	# O dano da enchente é fixo.
	# O nível NÃO aumenta mais o dano.
	var dano_atual = dano_infraestrutura * (1.0 - mitigacao_atual)
	
	# Reinicia a visibilidade temporária da faixa de dano
	timer_visibilidade.stop()
	timer_visibilidade.start()
	
	print(
		"[ENCHENTE] Nível ",
		nivel_atual,
		" (turno ",
		turnos_passados,
		"/",
		duracao_turnos,
		") | Mitigação: ",
		int(mitigacao_atual * 100),
		"% | Área: ",
		area_dano.position,
		" tamanho: ",
		area_dano.size,
		" | Dano: ",
		dano_atual
	)
	
	# Emite o retângulo em pixels globais.
	var area_pixels := Rect2(
		area_dano.global_position,
		area_dano.size
	)
	
	enchente_iniciada.emit(area_pixels, dano_atual)


## Sorteia posição/tamanho do AreaVisual em tiles.
func _gerar_area_grande_aleatoria() -> void:
	var largura = randi_range(largura_min_tiles, largura_max_tiles)
	var altura = randi_range(altura_min_tiles, altura_max_tiles)
	
	var pos_x = randi_range(
		mapa_min_tile.x,
		max(mapa_min_tile.x, mapa_max_tile.x - largura)
	)
	
	var pos_y = randi_range(
		mapa_min_tile.y,
		max(mapa_min_tile.y, mapa_max_tile.y - altura)
	)
	
	area_visual.position = Vector2(pos_x, pos_y) * tile_size
	area_visual.size = Vector2(largura, altura) * tile_size


## Sorteia uma única vez a posição-base da faixa de dano.
func _definir_area_fixa() -> void:
	# Nível máximo que essa enchente consegue alcançar.
	var nivel_maximo = 1 + int(
		max(duracao_turnos - 1, 0) / float(turnos_por_nivel)
	)
	
	var altura_maxima_possivel = _obter_tamanho_por_nivel(nivel_maximo).y
	
	# Guarda a borda inferior fixa.
	var y_bottom_min = area_visual.position.y + altura_maxima_possivel
	var y_bottom_max = area_visual.position.y + area_visual.size.y
	
	if y_bottom_min > y_bottom_max:
		y_bottom_min = y_bottom_max
	
	_pos_fixa = Vector2(
		area_visual.position.x,
		randf_range(y_bottom_min, y_bottom_max)
	)


## Atualiza o tamanho da área conforme o nível.
##
## A área cresce conforme o nível, mas o dano permanece fixo.
func _atualizar_tamanho_area_dano() -> void:
	var tamanho_base = _obter_tamanho_por_nivel(nivel_atual)
	
	var largura = tamanho_base.x
	var altura = tamanho_base.y * (1.0 - mitigacao_atual)
	
	area_dano.position = Vector2(
		_pos_fixa.x,
		_pos_fixa.y - altura
	)
	
	area_dano.size = Vector2(
		largura,
		altura
	)
	
	area_dano.visible = true


## Retorna o tamanho configurado para o nível atual.
func _obter_tamanho_por_nivel(nivel: int) -> Vector2:
	if tamanhos_por_nivel.is_empty():
		return area_visual.size
	
	var indice = clamp(
		nivel - 1,
		0,
		tamanhos_por_nivel.size() - 1
	)
	
	return tamanhos_por_nivel[indice]


## Converte a área de dano para coordenadas de tile.
func _converter_area_dano_para_tiles() -> void:
	var tile_inicio := Vector2i(
		floori(area_dano.position.x / tile_size.x),
		floori(area_dano.position.y / tile_size.y)
	)
	
	var tile_fim := Vector2i(
		ceili((area_dano.position.x + area_dano.size.x) / tile_size.x),
		ceili((area_dano.position.y + area_dano.size.y) / tile_size.y)
	)
	
	area_tiles = Rect2i(
		tile_inicio,
		tile_fim - tile_inicio
	)


## Retorna todas as coordenadas de tile afetadas.
func get_tiles_afetados() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	
	for x in range(
		area_tiles.position.x,
		area_tiles.position.x + area_tiles.size.x
	):
		for y in range(
			area_tiles.position.y,
			area_tiles.position.y + area_tiles.size.y
		):
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
