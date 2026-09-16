extends Control
@onready var game_over: Control = $"."
@onready var informações: RichTextLabel = $Informações
@onready var info_desabrigados: RichTextLabel = $InfoDesabrigados
@onready var info_casas_destruidas: RichTextLabel = $InfoCasasDestruidas
@onready var info_dano: RichTextLabel = $InfoDano
@onready var info_parabens: RichTextLabel = $InfoParabens
@onready var info_civis: RichTextLabel = $InfoCivis


func _ready() -> void:
	_montar_resumo()


func _montar_resumo() -> void:
	# --- Avaliação geral, com base na popularidade final ---

	# --- Pessoas desabrigadas ---
	if info_desabrigados:
		info_desabrigados.text = "[b]Pessoas desabrigadas:[/b] %s" % str(Global.pessoas_desabrigadas)

	# --- Casas destruídas ---
	if info_casas_destruidas:
		info_casas_destruidas.text = "[b]Construções destruídas:[/b] %s" % str(Global.casas_destruidas)

	# --- Dano total sofrido ---
	if info_dano:
		info_dano.text = "[b]Dano total sofrido:[/b] %s" % str(int(Global.dano_total))

	# --- Civis resgatados ---
	if info_civis:
		info_civis.text = "[b]Civis resgatados:[/b] %s" % str(Global.total_civis_resgatados)



## Retorna um texto curto avaliando a gestão do jogador, com base na
## popularidade final. Ajuste as faixas/textos como preferir.
func _avaliar_gestao() -> String:
	var p = Global.popularidade
	if p >= 100:
		return "[center][b]Gestão Exemplar![/b]\nA cidade prosperou sob sua liderança.[/center]"
	elif p >= 50:
		return "[center][b]Boa Gestão[/b]\nA cidade seguiu em frente, apesar dos desafios.[/center]"
	elif p >= 0:
		return "[center][b]Gestão Instável[/b]\nA cidade sobreviveu, mas por pouco.[/center]"
	else:
		return "[center][b]Gestão em Crise[/b]\nA população perdeu a confiança na administração.[/center]"
