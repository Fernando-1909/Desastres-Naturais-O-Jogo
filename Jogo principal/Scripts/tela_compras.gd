extends CanvasLayer
class_name TelaCompras

enum Modo { COMPRA, UPGRADE }

# ==============================================================================
# 📌 REFERÊNCIAS DE CONTAINERS E ESTRUTURA
# ==============================================================================
@export_group("Layout & Containers")
@export var painel_central: PanelContainer
@export var overlay_fundo: ColorRect
@export var colunas_grid: HBoxContainer

@export var coluna_stats: VBoxContainer      # Coluna de Ganhos/Infra (Esquerda no Upgrade)
@export var coluna_card: VBoxContainer       # Coluna Central do Prédio (ColunaEsquerda no seu Inspector)
@export var coluna_direita: VBoxContainer    # Coluna Direita (Ações/Infos)

@export var container_compra: VBoxContainer  # Bloco da Compra (Descrição + Bônus + Botão Comprar)
@export var container_upgrade: VBoxContainer # Bloco do Upgrade (Botões Aprimorar e Detalhes)

# ==============================================================================
# 📌 REFERÊNCIAS DOS ELEMENTOS INDIVIDUAIS
# ==============================================================================
@export_group("Elementos do Card")
@export var label_nome: RichTextLabel
@export var icone: TextureRect
@export var label_categoria: RichTextLabel   # "CONSTRUÇÃO"
@export var label_nivel: RichTextLabel       # "NÍVEL: X"

@export_group("Elementos de Dados")
@export var label_descricao: RichTextLabel
@export var label_bonus_pop: RichTextLabel
@export var label_bonus_infra: RichTextLabel
@export var label_ganhos: RichTextLabel
@export var barra_infra: ProgressBar
@export var button_comprar: Button
@export var button_aprimorar: Button
@export var button_detalhes: Button
@export var button_fechar: Button            # ❌ Botão "X" para fechar a tela

# ==============================================================================
# 📌 SINAIS
# ==============================================================================
signal compra_confirmada(nome_edificio: String)
signal aprimoramento_confirmado(nome_edificio: String)
signal detalhes_solicitados(nome_edificio: String)


func _ready() -> void:
	# Garante que este nó continue funcionando com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resetar_tudo()
	hide()
	_conectar_botoes()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		fechar_janela()


# ==============================================================================
# 🧹 RESET TOTAL (Garante que nada do modo anterior fique visível)
# ==============================================================================
func _resetar_tudo() -> void:
	if coluna_stats: coluna_stats.visible = false
	if container_compra: container_compra.visible = false
	if container_upgrade: container_upgrade.visible = false
	
	if label_categoria: label_categoria.visible = false
	if label_nivel: label_nivel.visible = false
	
	if label_descricao: label_descricao.visible = false
	if label_bonus_pop: label_bonus_pop.visible = false
	if label_bonus_infra: label_bonus_infra.visible = false
	if label_ganhos: label_ganhos.visible = false
	if barra_infra: barra_infra.visible = false
	if button_comprar: button_comprar.visible = false
	if button_aprimorar: button_aprimorar.visible = false
	if button_detalhes: button_detalhes.visible = false


# ==============================================================================
# 🛒 MODO COMPRA (2 Colunas)
# ==============================================================================
func abrir_modo_compra(
	nome: String, 
	categoria: String, 
	descricao: String, 
	bonus_pop: int, 
	bonus_infra: int, 
	preco: float, 
	textura_predio: Texture2D
) -> void:
	
	_resetar_tudo()
	_verificar_referencias_nulas()
	
	if container_compra: container_compra.visible = true
	if label_categoria: label_categoria.visible = true
	if label_descricao: label_descricao.visible = true
	if label_bonus_pop: label_bonus_pop.visible = true
	if label_bonus_infra: label_bonus_infra.visible = true
	if button_comprar: button_comprar.visible = true
	
	if label_nome: label_nome.text = "[center][b][color=purple]" + nome.to_upper() + "[/color][/b][/center]"
	if label_categoria: label_categoria.text = "[center][b][color=lightblue]" + categoria.to_upper() + "[/color][/b][/center]"
	if label_descricao: label_descricao.text = "[center]" + descricao + "[/center]"
	if label_bonus_pop: label_bonus_pop.text = "[center][b][color=green]+ " + str(bonus_pop) + " Popularidade[/color][/b][/center]"
	if label_bonus_infra: label_bonus_infra.text = "[center][b][color=orange]+ " + str(bonus_infra) + " Infraestrutura[/color][/b][/center]"
	if button_comprar: button_comprar.text = "COMPRAR\nR$ " + _formatar_numero(preco)
	if icone and textura_predio: icone.texture = textura_predio
	
	if colunas_grid and coluna_card and coluna_direita:
		colunas_grid.move_child(coluna_card, 0)
		colunas_grid.move_child(coluna_direita, 1)
	
	_animar_popin()


# ==============================================================================
# ⬆️ MODO UPGRADE (3 Colunas)
# ==============================================================================
func abrir_modo_upgrade(
	nome: String, 
	nivel: int, 
	ganhos: float, 
	pct_infra: float, 
	preco_upgrade: float, 
	textura_predio: Texture2D
) -> void:
	
	_resetar_tudo()
	_verificar_referencias_nulas()
	
	if coluna_stats: coluna_stats.visible = true
	if container_upgrade: container_upgrade.visible = true
	if label_nivel: label_nivel.visible = true
	if label_ganhos: label_ganhos.visible = true
	if barra_infra: barra_infra.visible = true
	if button_aprimorar: button_aprimorar.visible = true
	if button_detalhes: button_detalhes.visible = true
	
	if label_nome: label_nome.text = "[center][b][color=red]" + nome.to_upper() + "[/color][/b][/center]"
	if label_nivel: label_nivel.text = "[center][b][color=lightblue]NÍVEL: " + str(nivel) + "[/color][/b][/center]"
	if label_ganhos: label_ganhos.text = "[center]GANHOS\n[color=green]R$ " + _formatar_numero(ganhos) + "[/color][/center]"
	if barra_infra: barra_infra.value = pct_infra
	if button_aprimorar: button_aprimorar.text = "APRIMORAR\nR$ " + _formatar_numero(preco_upgrade)
	if button_detalhes: button_detalhes.text = "DETALHES"
	if icone and textura_predio: icone.texture = textura_predio
	
	if colunas_grid and coluna_stats and coluna_card and coluna_direita:
		colunas_grid.move_child(coluna_stats, 0)
		colunas_grid.move_child(coluna_card, 1)
		colunas_grid.move_child(coluna_direita, 2)
	
	_animar_popin()


# ==============================================================================
# 🎬 ANIMAÇÕES, PAUSA E FECHAMENTO
# ==============================================================================
func _animar_popin() -> void:
	# ⏸️ Pausa o jogo (mundo/câmera congelam)
	get_tree().paused = true
	show()
	
	if painel_central:
		painel_central.pivot_offset = painel_central.size / 2.0
		painel_central.scale = Vector2.ZERO
		
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(painel_central, "scale", Vector2.ONE, 0.25)


func fechar_janela() -> void:
	_resetar_global_construcoes()
	
	if painel_central:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(painel_central, "scale", Vector2.ZERO, 0.15)
		tween.tween_callback(func():
			hide()
			_resetar_tudo()
			# ▶️ Despausa o jogo ao terminar a animação
			get_tree().paused = false
		)
	else:
		hide()
		_resetar_tudo()
		get_tree().paused = false


func _resetar_global_construcoes() -> void:
	if typeof(Global) != TYPE_NIL and "construcoes" in Global:
		for chave in Global.construcoes:
			Global.construcoes[chave] = false


# ==============================================================================
# 🛠️ AUXILIARES
# ==============================================================================
func _verificar_referencias_nulas() -> void:
	if not coluna_stats: push_warning("⚠️ TelaCompras: Variable 'coluna_stats' is null in Inspector!")
	if not container_compra: push_warning("⚠️ TelaCompras: Variable 'container_compra' is null in Inspector!")
	if not container_upgrade: push_warning("⚠️ TelaCompras: Variable 'container_upgrade' is null in Inspector!")


func _conectar_botoes() -> void:
	if button_comprar and not button_comprar.pressed.is_connected(_on_comprar_pressed):
		button_comprar.pressed.connect(_on_comprar_pressed)
		
	if button_aprimorar and not button_aprimorar.pressed.is_connected(_on_aprimorar_pressed):
		button_aprimorar.pressed.connect(_on_aprimorar_pressed)
		
	if button_detalhes and not button_detalhes.pressed.is_connected(_on_detalhes_pressed):
		button_detalhes.pressed.connect(_on_detalhes_pressed)
		
	if button_fechar and not button_fechar.pressed.is_connected(fechar_janela):
		button_fechar.pressed.connect(fechar_janela)


func _on_comprar_pressed() -> void:
	compra_confirmada.emit(label_nome.get_parsed_text())
	fechar_janela()


func _on_aprimorar_pressed() -> void:
	aprimoramento_confirmado.emit(label_nome.get_parsed_text())
	fechar_janela()


func _on_detalhes_pressed() -> void:
	detalhes_solicitados.emit(label_nome.get_parsed_text())


func _formatar_numero(valor: float) -> String:
	var texto = str(int(valor))
	var resultado = ""
	var contador = 0
	for i in range(texto.length() - 1, -1, -1):
		if contador > 0 and contador % 3 == 0:
			resultado = "." + resultado
		resultado = texto[i] + resultado
		contador += 1
	return resultado
