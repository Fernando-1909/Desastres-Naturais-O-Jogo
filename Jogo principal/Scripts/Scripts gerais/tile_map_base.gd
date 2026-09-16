extends TileMapLayer

## Source_id e atlas coords do tile usado pra representar a água da enchente.
## Ajuste esses valores pro tile de água correto no seu TileSet (Inspector).
@export var enchente_source_id: int = 0
@export var enchente_atlas_coords: Vector2i = Vector2i(2, 1)
@export var enchente_alternative_tile: int = 0

# Guarda o estado original de cada célula usada do mapa (posição, source_id,
# atlas_coords e alternative_tile) — salvo assim que o jogo começa, pra dar
# pra restaurar depois que a enchente acabar.
var _mapa_original: Array[Dictionary] = []
var _mapa_salvo := false


func _ready() -> void:
	# Salva o mapa como ele está assim que o jogo começa, antes de qualquer
	# enchente poder mexer nele.
	_salvar_mapa_original()


## Salva o estado atual de todas as células usadas do TileMapBase, pra
## conseguir restaurar exatamente esse estado depois.
func _salvar_mapa_original() -> void:
	_mapa_original.clear()
	for cell in get_used_cells():
		_mapa_original.append({
			"pos": cell,
			"source_id": get_cell_source_id(cell),
			"atlas_coords": get_cell_atlas_coords(cell),
			"alternative_tile": get_cell_alternative_tile(cell),
		})
	_mapa_salvo = true
	print("[TileMapBase] Mapa original salvo (", _mapa_original.size(), " células).")


## Chamado quando a enchente começa: troca TODAS as células que existiam no
## mapa original pelo tile de água configurado acima. Enquanto a enchente
## durar, o mapa inteiro fica com esse tile.
func alagar_mapa() -> void:
	if not _mapa_salvo:
		_salvar_mapa_original()
	for dado in _mapa_original:
		set_cell(dado["pos"], enchente_source_id, enchente_atlas_coords, enchente_alternative_tile)
	print("[TileMapBase] Mapa alagado (", _mapa_original.size(), " células trocadas pro tile de enchente).")


## Chamado quando a enchente termina: restaura cada célula pro que ela era
## antes da enchente começar.
func restaurar_mapa() -> void:
	if not _mapa_salvo:
		return
	for dado in _mapa_original:
		set_cell(dado["pos"], dado["source_id"], dado["atlas_coords"], dado["alternative_tile"])
	print("[TileMapBase] Mapa restaurado ao estado original.")
