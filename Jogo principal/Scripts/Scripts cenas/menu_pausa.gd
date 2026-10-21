extends CanvasLayer
class_name MenuPausa

# ==============================================================================
# CONFIGURAÇÕES E REFERÊNCIAS
# ==============================================================================
## Selecione o arquivo .tscn do Menu Principal no Inspector
@export_file("*.tscn") var cena_menu_principal: String = ""

# Referências diretas aos botões da pausa
@onready var button_continuar: Button = $CenterContainer/PainelCentral/MargemExterna/ColunaPrincipal/CaixaBotoes/MargemInterna/ColunaBotoes/ButtonContinuar
@onready var button_opcoes: Button = $CenterContainer/PainelCentral/MargemExterna/ColunaPrincipal/CaixaBotoes/MargemInterna/ColunaBotoes/ButtonOpcoes
@onready var button_menu: Button = $CenterContainer/PainelCentral/MargemExterna/ColunaPrincipal/CaixaBotoes/MargemInterna/ColunaBotoes/ButtonMenu
@onready var button_dicas: Button = $CenterContainer/PainelCentral/MargemExterna/ColunaPrincipal/CaixaBotoes/MargemInterna/ColunaBotoes/ButtonDicas

# Instância da cena de opções reutilizável
@onready var menu_opcoes: MenuOpcoes = $MenuOpcoes

var _chaves_traducao: Dictionary = {}


func _ready() -> void:
	# Garante que a interface responda aos cliques mesmo com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	hide()
	get_tree().paused = false
	
	_configurar_chaves_traducao()
	_conectar_sinais()
	
	# Escuta mudanças de idioma globais
	if typeof(Global) != TYPE_NIL and Global.has_signal("idioma_alterado"):
		Global.idioma_alterado.connect(func(_lang): _atualizar_textos_botoes())
		
	_atualizar_textos_botoes()


func _unhandled_input(event: InputEvent) -> void:
	# Ativa/Desativa o pause com ESC ou tecla P
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P):
		toggle_pause()


# ==============================================================================
# CONTROLE DE PAUSE E TELAS
# ==============================================================================
func toggle_pause() -> void:
	var estado_atual = get_tree().paused
	var novo_estado = not estado_atual
	
	get_tree().paused = novo_estado
	visible = novo_estado

	# Se fechou o pause, fecha as opções também caso estivessem abertas
	if not novo_estado and menu_opcoes:
		menu_opcoes.fechar()


func _conectar_sinais() -> void:
	if button_continuar: button_continuar.pressed.connect(_on_continuar_pressed)
	if button_dicas: button_dicas.pressed.connect(_on_dicas_pressed)
	if button_opcoes: button_opcoes.pressed.connect(_on_opcoes_pressed)
	if button_menu: button_menu.pressed.connect(_on_menu_pressed)


# ==============================================================================
# AÇÕES DOS BOTÕES
# ==============================================================================
func _on_continuar_pressed() -> void:
	toggle_pause()


func _on_opcoes_pressed() -> void:
	if menu_opcoes:
		menu_opcoes.abrir()

## Alterna o estado global das dicas entre ativado e desativado
func _on_dicas_pressed() -> void:
	var estado_atual: bool = Global.get("dicas_habilitadas") if Global.get("dicas_habilitadas") != null else true
	Global.set("dicas_habilitadas", not estado_atual)
	_atualizar_texto_dicas()

## Atualiza o RichTextLabel do botão de dicas com o status atual
func _atualizar_texto_dicas() -> void:
	if button_dicas == null:
		return
	var rtl = button_dicas.get_node_or_null("RichTextLabel") as RichTextLabel
	var ativado: bool = Global.get("dicas_habilitadas") if Global.get("dicas_habilitadas") != null else true
	var texto = "DICAS: ATIVADAS" if ativado else "DICAS: DESATIVADAS"
	if rtl:
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.text = "[center]" + tr(texto) + "[/center]"
	else:
		button_dicas.text = tr(texto)

func _on_menu_pressed() -> void:
	get_tree().paused = false
	
	if cena_menu_principal != "" and ResourceLoader.exists(cena_menu_principal):
		get_tree().change_scene_to_file(cena_menu_principal)
	else:
		push_error("MenuPausa: Selecione o arquivo '.tscn' do Menu Principal no Inspector!")


# ==============================================================================
# GERENCIAMENTO DE TRADUÇÃO
# ==============================================================================
func _configurar_chaves_traducao() -> void:
	_chaves_traducao = {
		button_continuar: "MENU_CONTINUAR",
		button_opcoes: "MENU_OPCOES",
		button_menu: "MENU_SAIR"
	}


func _atualizar_textos_botoes() -> void:
	for btn in _chaves_traducao.keys():
		if btn == null:
			continue
			
		var chave = _chaves_traducao[btn]
		var rtl = btn.get_node_or_null("RichTextLabel") as RichTextLabel
		
		if rtl:
			rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rtl.text = "[center]" + tr(chave) + "[/center]"
			
	_atualizar_texto_dicas()
