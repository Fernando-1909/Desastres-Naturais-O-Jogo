extends CanvasLayer

# --- MAPEAMENTO DE AUTORES E PORTRAITS ---
const PORTRAIT_MAP: Dictionary = {
	"SISTEMA": "res://Jogo principal/UI/Assets/Portraits/rean_portrait.jpeg",
	#"DEFESA_CIVIL": "res://assets/portraits/defesa_civil.png",
	#"ENGENHEIRO_VIRTUAL": "res://assets/portraits/engenheiro.png"
}

var loaded_portraits: Dictionary = {}

# --- REFERÊNCIAS AOS NÓS (Usando Nomes Únicos %) ---
@onready var dialogue_box: PanelContainer = %DialogueBox
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var portrait: TextureRect = %Portrait
@onready var author_label: RichTextLabel = %NameLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var timer: Timer = %Timer

# --- VARIÁVEIS DE CONTROLE ---
var dialogue_data: Dictionary = {}        
var current_node_id: String = ""        
var is_dialogue_active: bool = false    
var last_advance_frame: int = -1        

func _ready() -> void:
	# Garante que o sistema de diálogo continue recebendo inputs mesmo com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	dialogue_box.visible = false
	choices_container.visible = false
	dialogue_text.text = ""
	
	timer.one_shot = false
	timer.wait_time = 0.03 
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	
	if not dialogue_box.gui_input.is_connected(_on_dialogue_box_gui_input):
		dialogue_box.gui_input.connect(_on_dialogue_box_gui_input)
	
	carregar_e_iniciar_dialogo("res://Jogo principal/Scripts/dialogues.json", "escolha_inicio")


func _input(event: InputEvent) -> void:
	if not is_dialogue_active:
		return
		
	if event.is_action_pressed("ui_accept") and not choices_container.visible:
		advance_dialogue()


# --- DETECÇÃO DE CLIQUE NA CAIXA ---

func _on_dialogue_box_gui_input(event: InputEvent) -> void:
	if not is_dialogue_active or choices_container.visible:
		return
		
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		advance_dialogue()


# --- FUNÇÕES DE NAVEGAÇÃO E CARREGAMENTO ---

func carregar_e_iniciar_dialogo(caminho_arquivo: String, no_inicial: String) -> void:
	if not FileAccess.file_exists(caminho_arquivo):
		printerr("Erro: Arquivo não encontrado: ", caminho_arquivo)
		return
		
	var arquivo = FileAccess.open(caminho_arquivo, FileAccess.READ)
	var conteudo = arquivo.get_as_text()
	arquivo.close()
	
	var dados = JSON.parse_string(conteudo)
	if dados == null:
		printerr("Erro ao ler JSON.")
		return
		
	dialogue_data = dados
	current_node_id = no_inicial
	is_dialogue_active = true
	dialogue_box.visible = true
	choices_container.hide()
	
	get_tree().paused = true
	show_current_line()


func show_current_line() -> void:
	var blocos = dialogue_data.get("dialogos", {})
	if not blocos.has(current_node_id):
		end_dialogue()
		return
		
	var dados_fala = blocos[current_node_id]
	var autor_id = dados_fala.get("autor", "")
	
	atualizar_autor_e_portrait(autor_id)
	
	var texto_chave = dados_fala.get("texto_chave", "")
	dialogue_text.text = tr(texto_chave)
	dialogue_text.visible_characters = 0
	timer.start()


func atualizar_autor_e_portrait(autor_id: String) -> void:
	if author_label:
		author_label.text = tr(autor_id)
	
	if autor_id == "" or not PORTRAIT_MAP.has(autor_id):
		portrait.hide()
		return
		
	var caminho_imagem = PORTRAIT_MAP[autor_id]
	
	if not loaded_portraits.has(caminho_imagem):
		if ResourceLoader.exists(caminho_imagem):
			loaded_portraits[caminho_imagem] = load(caminho_imagem)
		else:
			loaded_portraits[caminho_imagem] = null
	
	var textura = loaded_portraits[caminho_imagem]
	if textura != null:
		portrait.texture = textura
		portrait.show()
	else:
		portrait.hide()


func advance_dialogue() -> void:
	var current_frame = Engine.get_process_frames()
	if current_frame == last_advance_frame:
		return
	last_advance_frame = current_frame

	if not timer.is_stopped():
		timer.stop()                            
		dialogue_text.visible_characters = -1   
		return
	
	var blocos = dialogue_data.get("dialogos", {})
	var dados_fala = blocos[current_node_id]
	
	if dados_fala.has("escolhas") and not dados_fala["escolhas"].is_empty():
		mostrar_menu_escolhas(dados_fala["escolhas"])
		return

	var proximo_id = dados_fala.get("proximo", "fim")
	if proximo_id == "fim" or proximo_id == "":
		end_dialogue()
	else:
		current_node_id = proximo_id
		show_current_line()


func mostrar_menu_escolhas(opcoes: Array) -> void:
	for child in choices_container.get_children():
		child.queue_free()
		
	choices_container.show()
	
	for opcao in opcoes:
		var btn = Button.new()
		# Define a largura (ex: 360px) e altura (ex: 48px) do botão
		btn.custom_minimum_size = Vector2(360, 48)
		# Impede que o botão estique em 100% da tela, mantendo-o centralizado
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		
		var rtl = RichTextLabel.new()
		rtl.bbcode_enabled = true
		# Centralização nativa (evita erros com tags [center])
		rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rtl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rtl.text = tr(opcao.get("texto_chave", ""))
		rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		btn.add_child(rtl)
		
		var proximo_alvo = opcao.get("proximo", "fim")
		btn.pressed.connect(_on_opcao_selecionada.bind(proximo_alvo))
		
		choices_container.add_child(btn)


func _on_opcao_selecionada(proximo_id: String) -> void:
	choices_container.hide()
	
	if proximo_id == "resposta_pt":
		Global.alterar_idioma("pt")
	elif proximo_id == "resposta_en":
		Global.alterar_idioma("en")
		
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
