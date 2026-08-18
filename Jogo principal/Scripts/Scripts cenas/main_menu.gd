extends Control

@onready var button_iniciar: Button = $MenuPrincipal/ButtonIniciar
@onready var button_opcoes: Button = $MenuPrincipal/ButtonOpcoes
@onready var button_creditos: Button = $MenuPrincipal/ButtonCreditos
@onready var button_sair: Button = $MenuPrincipal/ButtonSair

# Referência para a nova cena instanciada de opções
@onready var menu_opcoes: MenuOpcoes = $MenuOpcoes 

var _mapeamento_tr: Dictionary = {}


func _ready() -> void:
	_mapeamento_tr = {
		button_iniciar: "MENU_JOGAR",
		button_opcoes: "MENU_OPCOES",
		button_creditos: "MENU_CREDITOS",
		button_sair: "MENU_SAIR"
	}
	
	_conectar_sinais()
	_atualizar_textos()


func _conectar_sinais() -> void:
	button_iniciar.pressed.connect(_on_iniciar_pressed)
	button_opcoes.pressed.connect(_on_opcoes_pressed)
	button_creditos.pressed.connect(_on_creditos_pressed)
	button_sair.pressed.connect(_on_sair_pressed)
	
	if typeof(Global) != TYPE_NIL and Global.has_signal("idioma_alterado"):
		Global.idioma_alterado.connect(func(_lang): _atualizar_textos())


func _atualizar_textos() -> void:
	for btn in _mapeamento_tr.keys():
		if btn == null: continue
		var rtl = btn.get_node_or_null("RichTextLabel") as RichTextLabel
		if rtl:
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rtl.text = "[center]" + tr(_mapeamento_tr[btn]) + "[/center]"


func _on_iniciar_pressed() -> void:
	get_tree().change_scene_to_file("res://Jogo principal/Main_game.tscn")


func _on_opcoes_pressed() -> void:
	if menu_opcoes:
		menu_opcoes.abrir()


func _on_creditos_pressed() -> void:
	print("Créditos pressionado")


func _on_sair_pressed() -> void:
	get_tree().quit()
