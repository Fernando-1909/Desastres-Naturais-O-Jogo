extends CanvasLayer
class_name MenuPausa

# ==============================================================================
# 📌 CONFIGURAÇÕES E REFERÊNCIAS
# ==============================================================================
## Selecione o arquivo .tscn da tela do Menu Principal no Inspector
@export_file("*.tscn") var cena_menu_principal: String = ""

@export_group("Referências dos Botões")
@export var button_continuar: Button
@export var button_opcoes: Button
@export var button_menu: Button


func _ready() -> void:
	# ⚠️ FORÇA O PROCESSO EM PAUSE: Garante que a interface responda aos cliques
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Garante que o jogo inicie sem estar pausado
	hide()
	get_tree().paused = false
	
	_buscar_e_conectar_botoes()


func _unhandled_input(event: InputEvent) -> void:
	# Ativa/Desativa o pause com ESC ou tecla P
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P):
		toggle_pause()


# ==============================================================================
# ⏸️ CONTROLE DE PAUSE
# ==============================================================================
func toggle_pause() -> void:
	var estado_atual = get_tree().paused
	var novo_estado = not estado_atual
	
	get_tree().paused = novo_estado
	visible = novo_estado


# ==============================================================================
# 🔘 AÇÕES DOS BOTÕES
# ==============================================================================
func _on_continuar_pressed() -> void:
	# Despausa o jogo e oculta a tela
	get_tree().paused = false
	hide()


func _on_opcoes_pressed() -> void:
	print("⚙️ Botão Opções clicado (Aguardando tela de opções).")


func _on_menu_pressed() -> void:
	# 🔴 CRÍTICO: Despausa antes de mudar de cena para a próxima não carregar congelada
	get_tree().paused = false
	
	if cena_menu_principal != "" and ResourceLoader.exists(cena_menu_principal):
		get_tree().change_scene_to_file(cena_menu_principal)
	else:
		push_error("⚠️ MenuPausa: Selecione o arquivo '.tscn' do Menu Principal no Inspector do nó MenuPausa!")


# ==============================================================================
# 🛠️ FALLBACK AUTOMÁTICO DE CONEXÃO DE BOTÕES
# ==============================================================================
func _buscar_e_conectar_botoes() -> void:
	# Tenta encontrar os botões automaticamente se não tiverem sido arrastados no Inspector
	if not button_continuar: button_continuar = find_child("ButtonContinuar", true, false) as Button
	if not button_opcoes:    button_opcoes = find_child("ButtonOpcoes", true, false) as Button
	if not button_menu:      button_menu = find_child("ButtonMenu", true, false) as Button

	# Conecta os sinais de clique de forma segura
	if button_continuar and not button_continuar.pressed.is_connected(_on_continuar_pressed):
		button_continuar.pressed.connect(_on_continuar_pressed)
		
	if button_opcoes and not button_opcoes.pressed.is_connected(_on_opcoes_pressed):
		button_opcoes.pressed.connect(_on_opcoes_pressed)
		
	if button_menu and not button_menu.pressed.is_connected(_on_menu_pressed):
		button_menu.pressed.connect(_on_menu_pressed)
