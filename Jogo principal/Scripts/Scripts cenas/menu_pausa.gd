extends CanvasLayer
class_name MenuPausa

# ==============================================================================
# CONFIGURAÇÕES E REFERÊNCIAS
# ==============================================================================
## Selecione o arquivo .tscn da tela do Menu Principal no Inspector
@export_file("*.tscn") var cena_menu_principal: String = ""

@export_group("Referências dos Painéis")
@export var painel_principal: Control
@export var painel_opcoes: Control
@export var label_titulo: Label

@export_group("Referências dos Botões")
@export var button_continuar: Button
@export var button_opcoes: Button
@export var button_menu: Button
@export var button_idioma_pt: Button
@export var button_idioma_en: Button
@export var button_voltar: Button

# Dicionario interno para mapear cada botao a sua respectiva chave no CSV
var _chaves_traducao: Dictionary = {}


func _ready() -> void:
	# Garante que a interface responda aos cliques mesmo com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Garante que o jogo inicie sem estar pausado
	hide()
	get_tree().paused = false
	
	_buscar_e_conectar_componentes()
	_configurar_chaves_traducao()
	
	# Conecta ao sinal do autoload Global caso exista
	if Global and Global.has_signal("idioma_alterado"):
		Global.idioma_alterado.connect(_atualizar_textos_botoes)
		
	_atualizar_textos_botoes()


func _unhandled_input(event: InputEvent) -> void:
	# Ativa/Desativa o pause com ESC ou tecla P
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P):
		toggle_pause()


func _notification(what: int) -> void:
	# Notificacao nativa do Godot acionada ao mudar o idioma do sistema/jogo
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_atualizar_textos_botoes()


# ==============================================================================
# CONTROLE DE PAUSE E TELAS
# ==============================================================================
func toggle_pause() -> void:
	var estado_atual = get_tree().paused
	var novo_estado = not estado_atual
	
	get_tree().paused = novo_estado
	visible = novo_estado

	# Sempre que abrir a pausa, garante que comece no painel principal
	if novo_estado:
		_exibir_painel_principal()


func _exibir_painel_principal() -> void:
	if painel_principal: painel_principal.show()
	if painel_opcoes: painel_opcoes.hide()
	if label_titulo: label_titulo.text = tr("MENU_PAUSA")


func _exibir_painel_opcoes() -> void:
	if painel_principal: painel_principal.hide()
	if painel_opcoes: painel_opcoes.show()
	if label_titulo: label_titulo.text = tr("MENU_OPCOES")


# ==============================================================================
# AÇÕES DOS BOTÕES
# ==============================================================================
func _on_continuar_pressed() -> void:
	get_tree().paused = false
	hide()


func _on_opcoes_pressed() -> void:
	_exibir_painel_opcoes()


func _on_voltar_pressed() -> void:
	_exibir_painel_principal()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	
	if cena_menu_principal != "" and ResourceLoader.exists(cena_menu_principal):
		get_tree().change_scene_to_file(cena_menu_principal)
	else:
		push_error("MenuPausa: Selecione o arquivo '.tscn' do Menu Principal no Inspector!")


func _on_idioma_pt_pressed() -> void:
	if Global:
		Global.alterar_idioma("pt")


func _on_idioma_en_pressed() -> void:
	if Global:
		Global.alterar_idioma("en")


# ==============================================================================
# GERENCIAMENTO DE TRADUÇÃO E RICHTEXTLABEL
# ==============================================================================
func _configurar_chaves_traducao() -> void:
	_chaves_traducao = {
		button_continuar: "MENU_CONTINUAR",
		button_opcoes: "MENU_OPCOES",
		button_idioma_pt: "BTN_PT",
		button_idioma_en: "BTN_EN",
		button_voltar: "MENU_VOLTAR",
		button_menu: "MENU_SAIR"
	}


func _atualizar_textos_botoes(_novo_idioma: String = "") -> void:
	if label_titulo:
		if painel_opcoes and painel_opcoes.visible:
			label_titulo.text = tr("MENU_OPCOES")
		else:
			label_titulo.text = tr("MENU_PAUSA")

	for btn in _chaves_traducao.keys():
		if btn == null:
			continue
			
		var chave = _chaves_traducao[btn]
		var rtl = btn.get_node_or_null("RichTextLabel") as RichTextLabel
		
		if rtl:
			rtl.text = "[center]" + tr(chave) + "[/center]"


# ==============================================================================
# FALLBACK AUTOMÁTICO DE CONEXÃO DE COMPONENTES
# ==============================================================================
func _buscar_e_conectar_componentes() -> void:
	# Busca dos paineis
	if not painel_principal: painel_principal = find_child("ColunaBotoes", true, false) as Control
	if not painel_opcoes:    painel_opcoes = find_child("PainelOpcoes", true, false) as Control
	if not label_titulo:     label_titulo = find_child("LabelTitulo", true, false) as Label

	# Busca dos botoes
	if not button_continuar: button_continuar = find_child("ButtonContinuar", true, false) as Button
	if not button_opcoes:    button_opcoes = find_child("ButtonOpcoes", true, false) as Button
	if not button_menu:      button_menu = find_child("ButtonMenu", true, false) as Button
	if not button_idioma_pt: button_idioma_pt = find_child("ButtonIdiomaPT", true, false) as Button
	if not button_idioma_en: button_idioma_en = find_child("ButtonIdiomaEN", true, false) as Button
	if not button_voltar:    button_voltar = find_child("ButtonVoltar", true, false) as Button

	# Conexao dos sinais
	if button_continuar and not button_continuar.pressed.is_connected(_on_continuar_pressed):
		button_continuar.pressed.connect(_on_continuar_pressed)
		
	if button_opcoes and not button_opcoes.pressed.is_connected(_on_opcoes_pressed):
		button_opcoes.pressed.connect(_on_opcoes_pressed)
		
	if button_menu and not button_menu.pressed.is_connected(_on_menu_pressed):
		button_menu.pressed.connect(_on_menu_pressed)

	if button_idioma_pt and not button_idioma_pt.pressed.is_connected(_on_idioma_pt_pressed):
		button_idioma_pt.pressed.connect(_on_idioma_pt_pressed)

	if button_idioma_en and not button_idioma_en.pressed.is_connected(_on_idioma_en_pressed):
		button_idioma_en.pressed.connect(_on_idioma_en_pressed)

	if button_voltar and not button_voltar.pressed.is_connected(_on_voltar_pressed):
		button_voltar.pressed.connect(_on_voltar_pressed)
