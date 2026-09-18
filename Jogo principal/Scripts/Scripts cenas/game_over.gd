extends Control
@onready var game_over: Control = $"."
@onready var informações: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer2/VBoxContainer/Informações
@onready var info_desabrigados: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer2/HBoxContainer/InfoDesabrigados
@onready var info_casas_destruidas: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer2/HBoxContainer/InfoCasasDestruidas
@onready var info_dano: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer2/HBoxContainer/InfoDano
@onready var info_parabens: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer2/InfoParabens
@onready var info_civis: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer2/HBoxContainer/InfoCivis


func _ready() -> void:
	_montar_resumo()


func _montar_resumo() -> void:
	# --- Avaliação geral, com base na popularidade final ---

	# --- Pessoas desabrigadas ---
	if info_desabrigados:
		info_desabrigados.text = "%s" % str(Global.pessoas_desabrigadas)

	# --- Casas destruídas ---
	if info_casas_destruidas:
		info_casas_destruidas.text = "%s" % str(Global.casas_destruidas)

	# --- Dano total sofrido ---
	if info_dano:
		info_dano.text = "%s" % str(int(Global.dano_total))

	# --- Civis resgatados ---
	if info_civis:
		info_civis.text = "%s" % str(Global.total_civis_resgatados)



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


func _on_return_menu_pressed() -> void:
		get_tree().change_scene_to_file("res://Menu Principal/main_menu.tscn")
