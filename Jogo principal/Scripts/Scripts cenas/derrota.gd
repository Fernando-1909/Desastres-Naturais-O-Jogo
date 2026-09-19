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
		defeat_message.text = "[center]Sua gestão chegou ao fim[center]\n\nConstruir muitas casas perto de rios pode ser perigoso, seria melhor deixar elas mais afastadas para não correr o risco de perder elas para enchente!\n\nLembre-se: balancear o posicionamento das casas é importante!"

	elif Global.semfuncoes:
		defeat_message.text = "[center]Sua gestão chegou ao fim[center]\n\nVocê não construiu nenhuma construção de funções para ajudar a população! É importante toda cidade ter as construções para poder atender as necessidades dos cidadãos, as cidades não vivem apenas de casas!\n\n"

	elif Global.sembombeiros:
		defeat_message.text = "[center]Sua gestão chegou ao fim[center]\n\nSem bombeiros, os cidadãos não puderam ser resgatados da enchente, e a população ficou furiosa com você.\n\nLembre-se: é importante em situações de crise tentar salvar os cidadãos desabrigados."

	elif Global.mortebomba:
		defeat_message.text = "mortebomba"

	elif Global.sembomba:
		defeat_message.text = "[center]Sua gestão chegou ao fim[center]\n\nSem bombas para mitigar o dano das casas, elas foram inundadas muito mais rapidamente, tente construir uma na próxima!"

	elif Global.semtratamento:
		defeat_message.text = "[center]Sua gestão chegou ao fim[center]\n\nEstações de tratamento são muito importantes em cidades perto de rios, elas ajudam demais a população a se preparar para possiveis desastres como enchentes. Se lembre, cada construção pode ter sua funcionalidade!"

	elif Global.semabrigo:
		defeat_message.text = "[center]Sua gestão chegou ao fim[center]\n\nAbrigos, são essenciais para qualquer cidade, eles servem para abrigar a população de desastres, são essenciais para proteger a população e garantir a segurança de todos!"

	# Motivos antigos de derrota continuam funcionando como fallback.
	elif Global.enchentederrota:
		defeat_message.text = "[center]Sua gestão chegou ao fim[/center]\n\nAs enchentes destruíram casas demais enquanto a popularidade da cidade estava em 0. A população perdeu a confiança na gestão e o município não conseguiu se recuperar.\n\nLembre-se: durante uma enchente, proteja as áreas residenciais e mantenha a cidade preparada para reduzir as perdas."

	elif Global.missaoderrota:
		defeat_message.text = "[center]Sua gestão chegou ao fim[/center]\n\nUma missão não foi concluída a tempo e a popularidade da cidade chegou a 0. A população perdeu a confiança na gestão e começou a deixar o município.\n\nLembre-se: fique atento às missões e tome decisões que mantenham a confiança da população."



func _on_return_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Menu Principal/main_menu.tscn")
