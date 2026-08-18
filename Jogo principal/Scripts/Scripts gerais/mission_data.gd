class_name MissionData
extends Resource

@export_group("Identificação")
@export var id: String = ""                          # ex: "missao1", "missao2"
@export var nome: String = ""                         # ex: "Construir hospital"

@export_group("Descrição")
@export_multiline var info: String = ""               # Texto narrativo mostrado ao jogador

@export_group("Custo para Concluir")
@export var custo: float = 0.0                        # Custo em dinheiro

@export_group("Recompensa")
@export var popularidade: int = 0                     # Popularidade ganha ao concluir
