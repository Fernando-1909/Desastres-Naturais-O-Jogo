extends CanvasLayer

# --- REFERÊNCIAS AOS NÓS (Sua cena precisa ter esses caminhos exatos!) ---
@onready var dialogue_box: Control = $DialogueBox
@onready var dialogue_text: RichTextLabel = $DialogueBox/DialogueText
@onready var timer: Timer = $DialogueBox/Timer
@onready var button: Button = $DialogueBox/Button
@onready var choices_container: VBoxContainer = $DialogueBox/ChoicesContainer


# --- VARIÁVEIS DE CONTROLE ---
var dialogue_data: Dictionary = {}      
var current_node_id: String = ""        
var is_dialogue_active: bool = false    
var last_advance_frame: int = -1        

func _ready() -> void:
	dialogue_box.visible = false
	choices_container.visible = false
	dialogue_text.text = ""
	
	timer.one_shot = false
	timer.wait_time = 0.03 
	timer.timeout.connect(_on_timer_timeout)
	
	button.focus_mode = Control.FOCUS_NONE
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)
	
	# ==========================================
	# 🧪 NOVO FLUXO DE TESTE
	# ==========================================
	
	# Agora o jogo começa direto na tela de escolha de idioma!
	carregar_e_iniciar_dialogo("res://Jogo principal/Scripts/dialogues.json", "escolha_inicio")


func _input(event: InputEvent) -> void:
	if not is_dialogue_active:
		return
		
	# Só avança com o "Espaço" se não houver escolhas ativas na tela
	if event.is_action_pressed("ui_accept") and not choices_container.visible:
		advance_dialogue()


# --- FUNÇÕES DE NAVEGAÇÃO E CARREGAMENTO ---

## Abre o JSON, lê o conteúdo e inicia a conversa no nó indicado
func carregar_e_iniciar_dialogo(caminho_arquivo: String, no_inicial: String) -> void:
	if not FileAccess.file_exists(caminho_arquivo):
		printerr("Erro: Arquivo não encontrado: ", caminho_arquivo)
		return
		
	var arquivo = FileAccess.open(caminho_arquivo, FileAccess.READ)
	var conteudo = arquivo.get_as_text()
	arquivo.close()
	
	var dados = JSON.parse_string(conteudo)
	if dados == null:
		printerr("Erro ao ler JSON. Verifique a sintaxe (chaves, vírgulas).")
		return
		
	dialogue_data = dados
	current_node_id = no_inicial
	is_dialogue_active = true
	dialogue_box.visible = true
	choices_container.hide()
	
	get_tree().paused = true
	show_current_line()


## Busca o texto correspondente no JSON e aplica a tradução
func show_current_line() -> void:
	var blocos = dialogue_data.get("dialogos", {})
	if not blocos.has(current_node_id):
		end_dialogue()
		return
		
	var dados_fala = blocos[current_node_id]
	var texto_chave = dados_fala.get("texto_chave", "")
	
	# tr() traduz automaticamente baseado no idioma ativo do jogo!
	dialogue_text.text = tr(texto_chave)
	dialogue_text.visible_characters = 0
	timer.start()


## Avança o texto ou abre o menu de escolhas
func advance_dialogue() -> void:
	var current_frame = Engine.get_process_frames()
	if current_frame == last_advance_frame:
		return
	last_advance_frame = current_frame

	# Se o texto ainda está sendo digitado, pula para o final da frase
	if not timer.is_stopped():
		timer.stop()                            
		dialogue_text.visible_characters = -1   
		return
	
	var blocos = dialogue_data.get("dialogos", {})
	var dados_fala = blocos[current_node_id]
	
	# Se a fala atual tiver escolhas, gera o menu de opções
	if dados_fala.has("escolhas") and not dados_fala["escolhas"].is_empty():
		mostrar_menu_escolhas(dados_fala["escolhas"])
		return

	# Se for um diálogo linear comum, avança para o próximo ID
	var proximo_id = dados_fala.get("proximo", "fim")
	if proximo_id == "fim" or proximo_id == "":
		end_dialogue()
	else:
		current_node_id = proximo_id
		show_current_line()


## Limpa e cria os botões de escolha dinamicamente na tela
func mostrar_menu_escolhas(opcoes: Array) -> void:
	# Limpa botões criados em escolhas anteriores
	for child in choices_container.get_children():
		child.queue_free()
		
	button.hide() # Esconde o botão geral de avançar provisoriamente
	choices_container.show()
	
	# Cria um botão físico na Godot para cada opção do JSON
	for opcao in opcoes:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 45) # Dá uma altura boa para o texto caber confortavelmente
		btn.focus_mode = Control.FOCUS_NONE
		
		# --- SOLUÇÃO DO BBCODE NOS BOTÕES ---
		# Criamos um RichTextLabel dinâmico para renderizar os efeitos das escolhas
		var rtl = RichTextLabel.new()
		rtl.bbcode_enabled = true
		
		# Usamos a tag [center] para garantir que o texto fique centralizado no botão
		rtl.text = "[center]" + tr(opcao.get("texto_chave", "")) + "[/center]"
		
		# Faz o RichTextLabel esticar e ocupar o tamanho inteiro do botão
		rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# MÁGICA: Ignora o mouse no texto. O clique "atravessa" o texto e aciona o botão!
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Ajuste fino: empurra o texto um pouquinho para baixo para centralizar verticalmente
		rtl.offset_top = 8 
		
		# Adiciona o texto como filho do botão
		btn.add_child(rtl)
		# -------------------------------------
		
		# Conecta o clique desse botão para nos levar ao próximo ID do JSON
		var proximo_alvo = opcao.get("proximo", "fim")
		btn.pressed.connect(_on_opcao_selecionada.bind(proximo_alvo))
		
		choices_container.add_child(btn)


## Executado quando o jogador clica em um dos botões de escolha
func _on_opcao_selecionada(proximo_id: String) -> void:
	choices_container.hide()
	button.show() # Devolve o botão de avançar padrão
	
	# MÁGICA: Se a escolha foi um idioma, altera a localização global do jogo!
	if proximo_id == "resposta_pt":
		TranslationServer.set_locale("pt")
	elif proximo_id == "resposta_en":
		TranslationServer.set_locale("en")
		
	if proximo_id == "fim" or proximo_id == "":
		end_dialogue()
	else:
		current_node_id = proximo_id
		show_current_line()


func end_dialogue() -> void:
	is_dialogue_active = false
	dialogue_box.visible = false
	choices_container.hide()
	dialogue_text.text = ""
	get_tree().paused = false


# --- SINAIS ---

func _on_timer_timeout() -> void:
	dialogue_text.visible_characters += 1
	if dialogue_text.visible_ratio >= 1.0:
		timer.stop()


func _on_button_pressed() -> void:
	if not choices_container.visible:
		advance_dialogue()
