extends Control

@export var tempo_na_tela: float = 6.5

@onready var defeat_message: RichTextLabel = get_node_or_null("DefeatMessage")
@onready var timer_retorno: Timer = get_node_or_null("TimerRetorno")


func _ready() -> void:
	_preencher_mensagem()
	_iniciar_retorno_automatico()


func _preencher_mensagem() -> void:
	if not defeat_message:
		push_warning("Derrota: node 'DefeatMessage' (RichTextLabel) não encontrado — crie um pra mostrar a mensagem na tela.")
		return
	
	defeat_message.text = "[b]Sua gestão chegou ao fim[/b]\n\nA popularidade da cidade caiu abaixo de zero: a população perdeu a confiança e começou a deixar o município.\n\n[b]Lembre-se:[/b] moradores insatisfeitos se mudam. Mantenha a popularidade em dia — cada decisão pesa na hora de manter as pessoas por aqui.\n\nNão desista. Toda gestão começa de novo com o que foi aprendido."


func _iniciar_retorno_automatico() -> void:
	if timer_retorno:
		timer_retorno.wait_time = tempo_na_tela
		timer_retorno.one_shot = true
		timer_retorno.timeout.connect(_voltar_ao_menu)
		timer_retorno.start()
	else:
		await get_tree().create_timer(tempo_na_tela).timeout
		_voltar_ao_menu()


func _voltar_ao_menu() -> void:
	get_tree().change_scene_to_file("res://Menu Principal/main_menu.tscn")
