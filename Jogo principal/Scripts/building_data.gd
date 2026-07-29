class_name BuildingData
extends Resource

@export_group("Identificação Base")
@export var id: String = ""                           # ex: "casa_simples", "casa_grande", "prefeitura"
@export var nome: String = ""                         # ex: "Casa Simples", "Mansão", "Prefeitura"
@export var categoria: String = "Residencial"         # ex: "Residencial", "Governamental"
@export var icone: Texture2D                     # Ícone exibido na loja/menu de compras

@export_group("Regras de Construção")
@export var eh_unica: bool = false                    # Se true, só permite 1 no mapa (ex: Prefeitura)
@export var pode_aprimorar: bool = true               # Se false, desativa botão de upgrade
@export var nivel_maximo: int = 1                     # Nível máximo
@export var custo_base: float = 100.0                 # Preço de compra

@export_group("Descrições")
@export_multiline var descricao_curta: String = ""    # Descrição do card
@export_multiline var texto_detalhes: String = ""    # Texto para tela de detalhes (se houver)

@export_group("Atributos Base")
@export var durabilidade_maxima: float = 100.0        # Vida do prédio
@export var ganhos_base: float = 0.0                  # Rendimento de dinheiro
@export var bonus_populacao: int = 0
@export var bonus_infraestrutura: int = 0
@export var multiplicador_custo_upgrade: float = 1.5

@export_group("Tiles no TileSet")
# Guarda as posições x,y do TileSet para as variações deste prédio
@export var tiles_atlas_coords: Array[Vector2i] = [] 
@export var source_id: int = 0 # ID da fonte do TileSet (geralmente 0)
