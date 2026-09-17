extends Control

@onready var return_menu: Button = $PanelContainer/MarginContainer/VBoxContainer/ReturnMenu
@onready var defeat_message: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/DefeatMessage



func _ready() -> void:
	_preencher_mensagem()

func _preencher_mensagem() -> void:
	if not defeat_message:
		push_warning("Game Over: node 'DefeatMessage' (RichTextLabel) não encontrado.")
		return

	# Derrota causada pelas enchentes
	if Global.enchentederrota:
		defeat_message.text = "[center]Sua gestão chegou ao fim[/center]\n\nAs enchentes destruíram casas demais enquanto a popularidade da cidade estava em 0. A população perdeu a confiança na gestão e o município não conseguiu se recuperar.\n\nLembre-se: durante uma enchente, proteja as áreas residenciais e mantenha a cidade preparada para reduzir as perdas."

	# Derrota causada por uma missão
	elif Global.missaoderrota:
		defeat_message.text = "[center]Sua gestão chegou ao fim[/center]\n\nUma missão não foi concluída a tempo e a popularidade da cidade chegou a 0. A população perdeu a confiança na gestão e começou a deixar o município.\n\nLembre-se: fique atento às missões e tome decisões que mantenham a confiança da população."


func _on_return_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu Principal/main_menu.tscn")
