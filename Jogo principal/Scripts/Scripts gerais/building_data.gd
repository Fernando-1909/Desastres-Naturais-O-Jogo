class_name BuildingData
extends Resource

@export_group("Identificação Base")
@export var id: String = ""                           # ex: "casa_simples", "prefeitura"
@export var nome: String = ""                         # ex: "Casa Simples", "Prefeitura"
@export var categoria: String = "Residencial"         # ex: "Residencial", "Governamental"
@export var icone: Texture2D                          # Ícone único (fallback)
## Coloque aqui a lista de PNGs que correspondem às variações deste prédio
@export var icones: Array[Texture2D] = []             

@export_group("Regras de Construção")
@export var eh_unica: bool = false                    # Se true, só permite 1 no mapa
@export var pode_aprimorar: bool = true               # Se false, desativa botão de upgrade
@export var nivel_maximo: int = 1                     # Nível máximo
@export var custo_base: float = 100.0                 # Preço de compra (dinheiro)
@export var custo_pedra: float = 0.0                  # Preço de compra (pedra)
@export var custo_madeira: float = 0.0                # Preço de compra (madeira)

@export_group("Descrições")
@export_multiline var descricao_curta: String = ""    
@export_multiline var texto_detalhes: String = ""    

@export_group("Atributos Base")
@export var durabilidade_maxima: float = 100.0        
@export var ganhos_base: float = 0.0                  
@export var bonus_populacao: int = 0
@export var multiplicador_custo_upgrade: float = 1.5

@export_group("Tiles no TileSet")
## Coloque aqui TODAS as coordenadas atlas que representam este prédio JÁ CONSTRUÍDO (variações)
@export var tiles_atlas_coords: Array[Vector2i] = [] 
@export var source_id: int = 4                       # ID da fonte no TileSet
@export var tile_vazio_atlas_coords: Vector2i = Vector2i(-1, -1)


## Retorna true se o .tres tem pelo menos 1 imagem válida associada
func tem_icones_validos() -> bool:
	if icones.size() > 0:
		for tex in icones:
			if tex != null:
				return true
	return icone != null


## Retorna a quantidade de variações registradas no array icones (ou 1 se usar 'icone')
func get_quantidade_variacoes() -> int:
	var contagem_validos = 0
	if icones.size() > 0:
		for tex in icones:
			if tex != null:
				contagem_validos += 1
		return contagem_validos
	elif icone != null:
		return 1
	return 0


## Retorna a textura de um índice específico de variação
func get_icone_variacao(indice: int = 0) -> Texture2D:
	if icones.size() > 0 and indice >= 0 and indice < icones.size():
		if icones[indice] != null:
			return icones[indice]
	return icone


func tem_tile_vazio() -> bool:
	return tile_vazio_atlas_coords != Vector2i(-1, -1)


func get_atlas_coord_para_construir(indice: int = -1) -> Vector2i:
	if tiles_atlas_coords.is_empty():
		return Vector2i.ZERO
	
	if indice >= 0 and indice < tiles_atlas_coords.size():
		return tiles_atlas_coords[indice]
		
	return tiles_atlas_coords.pick_random()
