extends Control
class_name MenuOpcoes

signal fechado

@onready var label_titulo: RichTextLabel = $CenterContainer/PainelCentral/MarginContainer/VBoxContainer/LabelTitulo
@onready var button_pt: Button = $CenterContainer/PainelCentral/MarginContainer/VBoxContainer/ContainerIdiomas/ButtonPT
@onready var button_en: Button = $CenterContainer/PainelCentral/MarginContainer/VBoxContainer/ContainerIdiomas/ButtonEN
@onready var button_voltar: Button = $CenterContainer/PainelCentral/MarginContainer/VBoxContainer/ButtonVoltar

var _mapeamento_tr: Dictionary = {}


func _ready() -> void:
	_mapeamento_tr = {
		button_pt: "BTN_PT",
		button_en: "BTN_EN",
		button_voltar: "MENU_VOLTAR"
	}
	
	_conectar_sinais()
	_atualizar_textos()
	hide() # Começa escondido


func _conectar_sinais() -> void:
	if button_pt: button_pt.pressed.connect(func(): Global.alterar_idioma("pt"))
	if button_en: button_en.pressed.connect(func(): Global.alterar_idioma("en"))
	if button_voltar: button_voltar.pressed.connect(fechar)
	
	if typeof(Global) != TYPE_NIL and Global.has_signal("idioma_alterado"):
		if not Global.idioma_alterado.is_connected(_on_idioma_alterado):
			Global.idioma_alterado.connect(_on_idioma_alterado)


func _on_idioma_alterado(_novo_codigo: String) -> void:
	_atualizar_textos()


func _atualizar_textos() -> void:
	for btn in _mapeamento_tr.keys():
		if btn == null: continue
		var rtl = btn.get_node_or_null("RichTextLabel") as RichTextLabel
		if rtl:
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rtl.text = "[center]" + tr(_mapeamento_tr[btn]) + "[/center]"
			
	if label_titulo:
		label_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label_titulo.text = "[center][b]" + tr("MENU_OPCOES").to_upper() + "[/b][/center]"


func abrir() -> void:
	show()


func fechar() -> void:
	hide()
	fechado.emit()
