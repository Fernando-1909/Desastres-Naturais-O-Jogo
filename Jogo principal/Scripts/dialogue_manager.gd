extends CanvasLayer

# --- REFERÊNCIAS AOS NÓS (NODES) ---
@onready var dialogue_box: Control = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/DialogueText
@onready var timer: Timer = $DialogueBox/Timer
@onready var button: Button = $DialogueBox/Button

# --- VARIÁVEIS DE CONTROLE ---
var dialogue_lines: Array[String] = []  
var current_line_index: int = 0         
var is_dialogue_active: bool = false    
var last_advance_frame: int = -1        # Guarda o frame para evitar clique duplo fantasma

func _ready() -> void:
	dialogue_box.visible = false
	dialogue_text.text = ""
	
	# Garante via código que o Timer vai rodar em loop até o fim da frase
	timer.one_shot = false
	timer.wait_time = 0.03 # Velocidade da escrita (sinta-se livre para mudar)
	
	timer.timeout.connect(_on_timer_timeout)
	
	# Desativa o foco do botão para o "Espaço" não ativar o botão e o _input juntos
	button.focus_mode = Control.FOCUS_NONE
	
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)
	
	# TESTE:
	start_dialogue(["Arroz, feijão e rebeca.",
	"É RECEBA POHA!!", 
	"É nadaaa... O jogo despausou!"])


func _input(event: InputEvent) -> void:
	if not is_dialogue_active:
		return
		
	if event.is_action_pressed("ui_accept"):
		advance_dialogue()


# --- FUNÇÕES PRINCIPAIS DO FLUXO ---

func start_dialogue(lines: Array[String]) -> void:
	if lines.is_empty():
		return
		
	dialogue_lines = lines
	current_line_index = 0
	is_dialogue_active = true
	dialogue_box.visible = true
	
	get_tree().paused = true
	show_current_line()


func show_current_line() -> void:
	dialogue_text.text = dialogue_lines[current_line_index]
	dialogue_text.visible_characters = 0
	timer.start()


func advance_dialogue() -> void:
	# Se a função for chamada duas vezes no mesmo frame, ignora a segunda
	var current_frame = Engine.get_process_frames()
	if current_frame == last_advance_frame:
		return
	last_advance_frame = current_frame

	# SE O TIMER ESTIVER RODANDO: Mostra o texto completo instantaneamente
	if not timer.is_stopped():
		timer.stop()                            
		dialogue_text.visible_characters = -1   
	
	# SE O TEXTO JÁ ESTIVER COMPLETO: Avança para a próxima frase
	else:
		current_line_index += 1
		
		if current_line_index < dialogue_lines.size():
			show_current_line()
		else:
			end_dialogue()


func end_dialogue() -> void:
	is_dialogue_active = false
	dialogue_box.visible = false
	dialogue_text.text = ""
	get_tree().paused = false


# --- SINAIS ---

func _on_timer_timeout() -> void:
	dialogue_text.visible_characters += 1
	
	if dialogue_text.visible_ratio >= 1.0:
		timer.stop()


func _on_button_pressed() -> void:
	advance_dialogue()
