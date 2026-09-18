extends Control

@onready var return_menu: Button = $PanelContainer/MarginContainer/VBoxContainer/ReturnMenu
@onready var defeat_message: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/DefeatMessage



func _ready() -> void:
	_preencher_mensagem()

func _preencher_mensagem() -> void:
	if not defeat_message:
		push_warning("Game Over: node 'DefeatMessage' (RichTextLabel) não encontrado.")
		return

	# Cada motivo possui um texto temporário diferente.
	# Você pode substituir "morte1", "morte2" etc. pelo conteúdo final.
	if Global.muitascasas:
		defeat_message.text = "morte1"

	elif Global.semfuncoes:
		defeat_message.text = "morte2"

	elif Global.sembombeiros:
		defeat_message.text = "morte3"

	elif Global.sembomba:
		defeat_message.text = "morte4"

	elif Global.semtratamento:
		defeat_message.text = "morte5"

	elif Global.semabrigo:
		defeat_message.text = "morte6"

	# Motivos antigos de derrota continuam funcionando como fallback.
	elif Global.enchentederrota:
		defeat_message.text = "[center]Sua gestão chegou ao fim[/center]\n\nAs enchentes destruíram casas demais enquanto a popularidade da cidade estava em 0. A população perdeu a confiança na gestão e o município não conseguiu se recuperar.\n\nLembre-se: durante uma enchente, proteja as áreas residenciais e mantenha a cidade preparada para reduzir as perdas."

	elif Global.missaoderrota:
		defeat_message.text = "[center]Sua gestão chegou ao fim[/center]\n\nUma missão não foi concluída a tempo e a popularidade da cidade chegou a 0. A população perdeu a confiança na gestão e começou a deixar o município.\n\nLembre-se: fique atento às missões e tome decisões que mantenham a confiança da população."

	else:
		defeat_message.text = "morte7"


func _on_return_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu Principal/main_menu.tscn")
