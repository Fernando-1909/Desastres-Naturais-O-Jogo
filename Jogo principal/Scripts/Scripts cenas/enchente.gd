extends Node2D
class_name Enchente

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

## Altura (em pixels) da faixa de dano, sorteada dentro dessa faixa.
## A largura da faixa é sempre igual à largura do AreaVisual.
@export var altura_dano_min: float = 100.0
@export var altura_dano_max: float = 150.0

## Quanto tempo (segundos) a faixa de dano fica visível antes de sumir
@export var duracao_segundos: float = 5.0

## Dano de infraestrutura aplicado às construções atingidas
@export var dano_infraestrutura: float = 25.0

# Retângulo de tiles afetado nesta ocorrência (calculado em _ready, com base no AreaDano)
var area_tiles: Rect2i

## Emitido assim que a faixa de dano é gerada, com o retângulo (em tiles) e o dano a aplicar.
## Quem escuta esse sinal (ex: main_game.gd) decide como aplicar o dano nas construções.
signal enchente_iniciada(area: Rect2i, dano: float)
## Emitido quando a enchente termina (acabou o tempo)
signal enchente_terminada

@onready var area_visual: ColorRect = $AreaVisual
@onready var area_dano: ColorRect = $AreaDano
@onready var timer_duracao: Timer = $TimerDuracao


func _ready() -> void:
	if randomizar_area_grande:
		_gerar_area_grande_aleatoria()
	
	# AreaVisual é só o limite onde a faixa de dano pode aparecer — não é visível pro jogador
	area_visual.visible = false
	
	_gerar_area_dano()
	_converter_area_dano_para_tiles()
	
	timer_duracao.wait_time = duracao_segundos
	timer_duracao.one_shot = true
	timer_duracao.timeout.connect(_on_duracao_terminada)
	timer_duracao.start()
	
	print("Área de dano gerada em: ", area_dano.position, " tamanho: ", area_dano.size, " | Dano: ", dano_infraestrutura)
	enchente_iniciada.emit(area_tiles, dano_infraestrutura)


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


## Gera a faixa de dano (AreaDano): largura igual ao AreaVisual, altura
## aleatória entre altura_dano_min/max, numa posição vertical aleatória
## dentro dos limites do AreaVisual.
func _gerar_area_dano() -> void:
	var altura = randf_range(altura_dano_min, altura_dano_max)
	var largura = area_visual.size.x
	
	var y_min = area_visual.position.y
	var y_max = area_visual.position.y + area_visual.size.y - altura
	if y_max < y_min:
		y_max = y_min  # segurança, caso o AreaVisual seja menor que a altura de dano
	
	var pos_y = randf_range(y_min, y_max)
	var pos_x = area_visual.position.x
	
	area_dano.position = Vector2(pos_x, pos_y)
	area_dano.size = Vector2(largura, altura)
	area_dano.visible = true


## Converte a área de dano (em pixels) pra coordenadas de tile, guardando
## em area_tiles — é isso que deve ser comparado com as chaves de
## construcoes_no_mapa (no main_game.gd) pra saber quais construções foram atingidas.
func _converter_area_dano_para_tiles() -> void:
	var tile_inicio := Vector2i(floori(area_dano.position.x / tile_size.x), floori(area_dano.position.y / tile_size.y))
	var tile_fim := Vector2i(ceili((area_dano.position.x + area_dano.size.x) / tile_size.x), ceili((area_dano.position.y + area_dano.size.y) / tile_size.y))
	
	area_tiles = Rect2i(tile_inicio, tile_fim - tile_inicio)


## Retorna a lista de todas as coordenadas de tile cobertas pela faixa de dano.
func get_tiles_afetados() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(area_tiles.position.x, area_tiles.position.x + area_tiles.size.x):
		for y in range(area_tiles.position.y, area_tiles.position.y + area_tiles.size.y):
			tiles.append(Vector2i(x, y))
	return tiles


func _on_duracao_terminada() -> void:
	print("Enchente terminou.")
	enchente_terminada.emit()
	queue_free()
