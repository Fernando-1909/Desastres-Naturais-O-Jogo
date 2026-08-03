class_name BuildingData
extends Resource

@export_group("Identificação Base")
@export var id: String = ""                           # ex: "casa_simples", "prefeitura"
@export var nome: String = ""                         # ex: "Casa Simples", "Prefeitura"
@export var categoria: String = "Residencial"         # ex: "Residencial", "Governamental"
@export var icone: Texture2D                          # Ícone exibido na loja/menu

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
@export var source_id: int = 4                       # I D da fonte no TileSet
## Coordenada atlas do "lote vazio" que representa este prédio ANTES de ser construído
## (substitui o Custom Data "building_id" do TileSet — deixe (-1,-1) se este prédio
## não tiver um lote vazio próprio no mapa).
@export var tile_vazio_atlas_coords: Vector2i = Vector2i(-1, -1)

## Retorna true se este prédio tem um tile de "lote vazio" configurado
func tem_tile_vazio() -> bool:
	return tile_vazio_atlas_coords != Vector2i(-1, -1)

## Retorna uma coordenada específica pelo índice, ou sorteia se o índice for -1
func get_atlas_coord_para_construir(indice: int = -1) -> Vector2i:
	if tiles_atlas_coords.is_empty():
		return Vector2i.ZERO
	
	# Se um índice válido for passado (ex: 0, 1 ou 2), usa o sprite exato
	if indice >= 0 and indice < tiles_atlas_coords.size():
		return tiles_atlas_coords[indice]
		
	# Caso contrário (-1), mantém o comportamento aleatório
	return tiles_atlas_coords.pick_random()
