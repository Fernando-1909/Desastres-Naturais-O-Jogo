class_name BuildingData
extends Resource

@export_group("Identificação Base")
@export var id: String = ""                           # ex: "casa_simples", "prefeitura"
@export var nome: String = ""                         # ex: "Casa Simples", "Prefeitura"
@export var icone: Texture2D                          # Ícone único (fallback)
## Coloque aqui a lista de PNGs que correspondem às variações deste prédio
@export var icones: Array[Texture2D] = []             

@export_group("Regras de Construção")
@export var eh_unica: bool = false                    # Se true, só permite 1 no mapa
@export var pode_aprimorar: bool = true               # Se false, desativa botão de upgrade
@export var nivel_maximo: int = 1                     # Nível máximo
@export var custo_base: float = 100.0                 # Preço de compra (dinheiro)

@export_group("Tempo de Construção e Emergência")
## Quantidade de turnos necessária para finalizar a obra (0 = instantâneo)
@export var tempo_construcao_turnos: int = 1          
## Multiplicador de custo quando comprado em modo de emergência (ex: bomba no desastre)
@export var multiplicador_custo_emergencia: float = 1.5 

@export_group("Descrições")
@export_multiline var descricao_curta: String = ""    
@export_multiline var texto_detalhes: String = ""    

@export_group("Atributos Base")
@export var durabilidade_maxima: float = 100.0        
@export var ganhos_base: float = 0.0                  
@export var bonus_populacao: int = 0
@export var multiplicador_custo_upgrade: float = 1.5
@export var bonus_ganho_geral_pct: float = 0.0 # Ex: 0.10 para 10%

@export_group("Serviços e Socorro")
## Quantidade de pessoas desabrigadas que esta construção pode acolher durante/após desastres
@export var capacidade_abrigo: int = 0
## Quantidade de equipes de bombeiros/resgate que esta construção disponibiliza no mapa
@export var equipes_resgate: int = 0
## Quantidade máxima de bombas de drenagem disponibilizadas por esta construção
@export var capacidade_bombas: int = 0

@export_group("Tiles no TileSet")
## Coloque aqui TODAS as coordenadas atlas que representam este prédio JÁ CONSTRUÍDO (variações)
@export var tiles_atlas_coords: Array[Vector2i] = [] 
@export var source_id: int = 4                       # ID da fonte no TileSet
@export var tile_vazio_atlas_coords: Vector2i = Vector2i(-1, -1)

@export_subgroup("Tile em Construção / Obra")
## ID da fonte no TileSet para a versão em obra (se -1, reutiliza o source_id padrão)
@export var under_construction_source_id: int = -1    
## Coordenada atlas (x, y) do sprite de estrutura em construção
@export var under_construction_tile_atlas_coords: Vector2i = Vector2i(-1, -1) 

@export_subgroup("Tile Destruído")
## Configurações para a versão destruída da construção
@export var destroyed_source_id: int = -1            # Se -1, reutiliza o source_id padrão
@export var destroyed_tile_atlas_coords: Vector2i = Vector2i(-1, -1) # Posição (x, y) do tile destruído

@export_subgroup("Tile Alagado")
## Configurações para a versão alagada da construção
@export var flooded_source_id: int = -1              # Se -1, reutiliza o source_id padrão
@export var flooded_tile_atlas_coords: Vector2i = Vector2i(-1, -1) # Posição (x, y) do tile alagado


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


func tem_tile_em_construcao() -> bool:
	return under_construction_tile_atlas_coords != Vector2i(-1, -1)


func tem_tile_destruido() -> bool:
	return destroyed_tile_atlas_coords != Vector2i(-1, -1)


func tem_tile_alagado() -> bool:
	return flooded_tile_atlas_coords != Vector2i(-1, -1)


func get_under_construction_source_id() -> int:
	return under_construction_source_id if under_construction_source_id >= 0 else source_id


func get_atlas_coord_por_nivel(nivel: int) -> Vector2i:
	var indice: int = nivel - 1
	return get_atlas_coord_para_construir(indice)

func get_destroyed_source_id() -> int:
	return destroyed_source_id if destroyed_source_id >= 0 else source_id


func get_flooded_source_id() -> int:
	return flooded_source_id if flooded_source_id >= 0 else source_id


func get_atlas_coord_para_construir(indice: int = -1) -> Vector2i:
	if tiles_atlas_coords.is_empty():
		return Vector2i.ZERO
	
	if indice >= 0 and indice < tiles_atlas_coords.size():
		return tiles_atlas_coords[indice]
		
	return tiles_atlas_coords.pick_random()
