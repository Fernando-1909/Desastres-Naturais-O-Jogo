extends Node2D
class_name SistemaDrenagem

signal bombas_atualizadas(qtd_atual: int, max_qtd: int)
signal status_estacao_alterado(esta_ativa: bool)

@export_group("Configurações de Drenagem")
@export var max_bombas: int = 3
@export var reducao_dano_por_bomba: float = 0.15
@export var dano_minimo_residual: float = 0.10

@export_group("Visual das Bombas")
## Imagem/Sprite da bomba de drenagem
@export var texture_bomba: Texture2D
## Ajuste fino de posição do sprite sobre o tile (caso a imagem não esteja centralizada)
@export var offset_sprite: Vector2 = Vector2(0, -8)

@export_group("Sons e Nós")
@onready var som_bomba: AudioStreamPlayer2D = $SomBomba if has_node("SomBomba") else null
@onready var container_bombas: Node2D = $ContainerBombas if has_node("ContainerBombas") else self

var estacao_construida: bool = false
var bombas_alocadas: int = 0
# Mapeia cada posição de tile ocupada para o seu respectivo Sprite2D no mapa
var _sprites_bombas: Dictionary = {} # Vector2i (tile_pos) -> Sprite2D


func _ready() -> void:
	_limpar_sprites()
	bombas_atualizadas.emit(bombas_alocadas, max_bombas)


func definir_estacao_construida(status: bool) -> void:
	estacao_construida = status
	status_estacao_alterado.emit(estacao_construida)
	
	# Se a estação for destruída, remove todas as bombas e seus sprites
	if not estacao_construida:
		bombas_alocadas = 0
		_limpar_sprites()
		bombas_atualizadas.emit(bombas_alocadas, max_bombas)


## Adiciona uma bomba no tile especificado e desenha seu sprite
func adicionar_bomba_no_tile(pos_tile: Vector2i, pos_global: Vector2) -> bool:
	if not estacao_construida:
		print("Drenagem: Requer uma Estação de Tratamento de Água construída!")
		return false
		
	if _sprites_bombas.has(pos_tile):
		print("Drenagem: Já existe uma bomba neste tile!")
		return false

	if bombas_alocadas < max_bombas:
		bombas_alocadas += 1
		_criar_sprite_bomba(pos_tile, pos_global)
		_tocar_som_bomba()
		bombas_atualizadas.emit(bombas_alocadas, max_bombas)
		return true
		
	print("Drenagem: Limite máximo de bombas atingido (%d/%d)" % [bombas_alocadas, max_bombas])
	return false


## Remove uma bomba de um tile específico
func remover_bomba_do_tile(pos_tile: Vector2i) -> bool:
	if _sprites_bombas.has(pos_tile):
		var sprite = _sprites_bombas[pos_tile] as Sprite2D
		if is_instance_valid(sprite):
			sprite.queue_free()
		_sprites_bombas.erase(pos_tile)
		
		bombas_alocadas = max(0, bombas_alocadas - 1)
		bombas_atualizadas.emit(bombas_alocadas, max_bombas)
		return true
	return false


func _criar_sprite_bomba(pos_tile: Vector2i, pos_global: Vector2) -> void:
	var sprite = Sprite2D.new()
	sprite.texture = texture_bomba
	sprite.global_position = pos_global + offset_sprite
	# Define a ordem de renderização para ficar sobre o chão
	sprite.z_index = 1
	
	if container_bombas:
		container_bombas.add_child(sprite)
		
	_sprites_bombas[pos_tile] = sprite


func _limpar_sprites() -> void:
	for pos_tile in _sprites_bombas.keys():
		var sprite = _sprites_bombas[pos_tile]
		if is_instance_valid(sprite):
			sprite.queue_free()
	_sprites_bombas.clear()


func obter_multiplicador_dano() -> float:
	if not estacao_construida or bombas_alocadas == 0:
		return 1.0
	var reducao_total = bombas_alocadas * reducao_dano_por_bomba
	return max(dano_minimo_residual, 1.0 - reducao_total)


func obter_porcentagem_mitigacao() -> int:
	if not estacao_construida:
		return 0
	return int((1.0 - obter_multiplicador_dano()) * 100)


func _tocar_som_bomba() -> void:
	if som_bomba and som_bomba.stream:
		som_bomba.play()
		
