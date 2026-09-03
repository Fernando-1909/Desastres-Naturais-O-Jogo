class_name MissionData
extends Resource

@export_group("Identificação")
@export var id: String = ""                          # ex: "missao1", "missao2"
@export var nome: String = ""                         # ex: "Corpo de Bombeiros"

@export_group("Descrição")
## Texto mostrado ao jogador — escrito como uma pequena discussão entre dois
## conselheiros (um a favor de construir, outro a favor de economizar).
## Use BBCode (ex: [b]Nome:[/b] fala) — o label que exibe isso é um
## RichTextLabel, então confirme que "BBCode Enabled" está marcado nele.
@export_multiline var info: String = ""

@export_group("Custo para Concluir (se aceitar)")
@export var custo: float = 0.0                        # Custo em dinheiro, pago ao concluir

@export_group("Recompensa (se aceitar e concluir)")
@export var popularidade: int = 0                     # Popularidade ganha ao concluir
