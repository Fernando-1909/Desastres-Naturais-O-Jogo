extends Node2D
class_name Enchente

## Quantos turnos a enchente dura no total, a partir do turno em que começou
@export var duracao_turnos: int = 7
## A cada quantos turnos o nível da enchente sobe 1
@export var turnos_por_nivel: int = 2

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

## Altura (em pixels) da faixa de dano no nível 1, sorteada dentro dessa faixa.
## A largura da faixa é sempre igual à largura do AreaVisual.
@export var altura_dano_min: float = 100.0
@export var altura_dano_max: float = 150.0
## Quanto a altura da faixa aumenta a cada nível acima do 1 (nível 2: +200, nível 3: +400...)
@export var aumento_altura_por_nivel: float = 200.0

## Dano de infraestrutura no nível 1
@export var dano_infraestrutura: float = 25.0
## Quanto o dano aumenta a cada nível acima do 1
@export var aumento_dano_por_nivel: float = 30.0

## Quanto tempo (segundos) a faixa de dano fica visível depois de cada atualização de turno
@export var duracao_visivel_segundos: float = 5.0

# Progresso da enchente ao longo dos turnos
var turnos_passados: int = 0
var nivel_atual: int = 1

# Retângulo de tiles afetado no turno atual (calculado a cada atualização, com base no AreaDano)
var area_tiles: Rect2i

## Emitido toda vez que a área de dano é (re)calculada — no início e a cada turno
## que passa enquanto a enchente segue ativa — com o retângulo (em tiles) e o dano a aplicar.
## Quem escuta esse sinal (ex: main_game.gd) decide como aplicar o dano nas construções.
signal enchente_iniciada(area: Rect2i, dano: float)
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
	
	Global.nivel_enchente = nivel_atual
	_aplicar_turno_atual()


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
	_gerar_area_dano()
	_converter_area_dano_para_tiles()
	
	var dano_atual = dano_infraestrutura + (nivel_atual - 1) * aumento_dano_por_nivel
	
	# Reinicia a visibilidade temporária da faixa de dano
	timer_visibilidade.stop()
	timer_visibilidade.start()
	
	print("[ENCHENTE] Nível ", nivel_atual, " (turno ", turnos_passados, "/", duracao_turnos, ") | Área: ", area_dano.position, " tamanho: ", area_dano.size, " | Dano: ", dano_atual)
	enchente_iniciada.emit(area_tiles, dano_atual)


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
## aleatória entre altura_dano_min/max SOMADA ao aumento do nível atual,
## numa posição vertical aleatória dentro dos limites do AreaVisual.
func _gerar_area_dano() -> void:
	var altura_base = randf_range(altura_dano_min, altura_dano_max)
	var altura = altura_base + (nivel_atual - 1) * aumento_altura_por_nivel
	var largura = area_visual.size.x
	
	var y_min = area_visual.position.y
	var y_max = area_visual.position.y + area_visual.size.y - altura
	if y_max < y_min:
		y_max = y_min  # segurança, caso a faixa já seja maior que o AreaVisual
	
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
