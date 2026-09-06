class_name MissionData
extends Resource

@export_group("Identificação")
@export var id: String = ""                          # ex: "missao1", "missao2"
@export var nome: String = ""                         # ex: "Corpo de Bombeiros"

@export_group("Descrição")
## Texto mostrado ao jogador — escrito como uma pequena discussão entre a
## Secretária (a favor de construir) e o Tesoureiro (a favor de economizar).
## Use BBCode (ex: [b]Nome:[/b] fala) — o label que exibe isso é um
## RichTextLabel, então confirme que "BBCode Enabled" está marcado nele.
@export_multiline var info: String = ""

@export_group("Conclusão")
## Custo em dinheiro, cobrado ao concluir pelo botão de concluir manual.
## Se "Edificio Id Alvo" (abaixo) estiver preenchido, esse custo é ignorado
## quando a missão é concluída automaticamente ao construir o prédio (porque
## o custo do prédio em si já foi pago na hora da compra).
@export var custo: float = 0.0
## Se preenchido (ex: "bombeiros"), a missão é concluída automaticamente
## assim que o jogador construir esse prédio (comparado com BuildingData.id),
## sem precisar apertar o botão de concluir manual. Deixe em branco pra
## missões que não têm um prédio específico associado.
@export var edificio_id_alvo: String = ""

@export_group("Recompensa (se aceitar e concluir)")
@export var popularidade: int = 0                     # Popularidade ganha ao concluir
@export var bonus_populacao: int = 0                  # População extra ganha ao concluir
