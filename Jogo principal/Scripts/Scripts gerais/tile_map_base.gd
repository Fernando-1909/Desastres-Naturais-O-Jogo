extends TileMapLayer

## Tile de água usado durante a enchente.
@export var enchente_source_id: int = 5
@export var enchente_atlas_coords: Vector2i = Vector2i(0, 0)
@export var enchente_alternative_tile: int = 0

## Quantos tiles além da hitbox da onda também serão alagados.
@export_range(0, 8, 1) var margem_tiles: int = 2

# Estado original de cada célula usada, preservado durante toda a partida.
var _mapa_original: Dictionary = {}
var _mapa_salvo := false
var _tiles_alagados: Dictionary = {}


func _ready() -> void:
	_salvar_mapa_original()


func _salvar_mapa_original() -> void:
	_mapa_original.clear()
	for cell in get_used_cells():
		_mapa_original[cell] = {
			"source_id": get_cell_source_id(cell),
			"atlas_coords": get_cell_atlas_coords(cell),
			"alternative_tile": get_cell_alternative_tile(cell),
		}
	_mapa_salvo = true
	print("[TileMapBase] Mapa original salvo (", _mapa_original.size(), " células).")


## Atualiza o alagamento conforme a posição/tamanho atual da hitbox da onda.
## Recebe a área em coordenadas globais, como emitida por Enchente.
func atualizar_area_alagada(area_global: Rect2) -> void:
	if not _mapa_salvo:
		_salvar_mapa_original()

	if _mapa_original.is_empty():
		return

	# Converte os cantos globais da hitbox para coordenadas locais do TileMap.
	var canto_a := to_local(area_global.position)
	var canto_b := to_local(area_global.position + area_global.size)
	var tile_a := local_to_map(Vector2(min(canto_a.x, canto_b.x), min(canto_a.y, canto_b.y)))
	var tile_b := local_to_map(Vector2(max(canto_a.x, canto_b.x), max(canto_a.y, canto_b.y)))

	var inicio := Vector2i(
		min(tile_a.x, tile_b.x) - margem_tiles,
		min(tile_a.y, tile_b.y) - margem_tiles
	)
	var fim := Vector2i(
		max(tile_a.x, tile_b.x) + margem_tiles,
		max(tile_a.y, tile_b.y) + margem_tiles
	)

	var novos_tiles_alagados: Dictionary = {}

	for pos in _mapa_original.keys():
		if pos.x < inicio.x or pos.x > fim.x or pos.y < inicio.y or pos.y > fim.y:
			continue

		novos_tiles_alagados[pos] = true
		if not _tiles_alagados.has(pos):
			set_cell(pos, enchente_source_id, enchente_atlas_coords, enchente_alternative_tile)

	# Se a hitbox deixar de cobrir alguma célula, restaura-a imediatamente.
	for pos in _tiles_alagados.keys():
		if novos_tiles_alagados.has(pos):
			continue
		_restaurar_celula(pos)

	_tiles_alagados = novos_tiles_alagados
	print("[TileMapBase] Área atualizada: ", _tiles_alagados.size(), " tiles alagados.")


func _restaurar_celula(pos: Vector2i) -> void:
	if not _mapa_original.has(pos):
		return
	var dado: Dictionary = _mapa_original[pos]
	set_cell(pos, dado["source_id"], dado["atlas_coords"], dado["alternative_tile"])


## Restaura exatamente source, atlas e tile alternativo de todas as células.
func restaurar_mapa() -> void:
	if not _mapa_salvo:
		return
	for pos in _tiles_alagados.keys():
		_restaurar_celula(pos)
	_tiles_alagados.clear()
	print("[TileMapBase] Mapa restaurado ao estado original.\n")
