extends CanvasLayer
class_name TelaCompras

enum Modo { COMPRA, UPGRADE }

# ==============================================================================
# 📌 REFERÊNCIAS DO CARD CENTRAL (Sempre Visíveis)
# ==============================================================================
@export_group("Geral & Animação")
@export var painel_central: PanelContainer
@export var overlay_fundo: ColorRect
@export var label_nome: RichTextLabel
@export var icone: TextureRect

# ==============================================================================
# 📌 REFERÊNCIAS DO MODO COMPRA 
# ==============================================================================
@export_group("Modo Compra")
@export var container_compra: VBoxContainer
@export var label_categoria: RichTextLabel
@export var label_descricao: RichTextLabel
@export var label_bonus_pop: RichTextLabel
@export var label_bonus_infra: RichTextLabel
@export var button_comprar: Button

# ==============================================================================
# 📌 REFERÊNCIAS DO MODO UPGRADE
# ==============================================================================
@export_group("Modo Upgrade")
@export var coluna_stats: VBoxContainer
@export var container_upgrade: VBoxContainer
@export var label_nivel: RichTextLabel
@export var label_ganhos: RichTextLabel
@export var barra_infra: ProgressBar
@export var button_aprimorar: Button
@export var button_detalhes: Button

# ==============================================================================
# 📌 SINAIS DE EVENTO
# ==============================================================================
signal compra_confirmada(nome_edificio: String)
signal aprimoramento_confirmado(nome_edificio: String)
signal detalhes_solicitados(nome_edificio: String)


func _ready() -> void:
	hide()
	_conectar_botoes()


func _input(event: InputEvent) -> void:
	# Fecha a janela se o jogador pressionar ESC
	if visible and event.is_action_pressed("ui_cancel"):
		fechar_janela()


# ==============================================================================
# 🛠️ ABRIR NO MODO COMPRA (Ex: Escola)
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
	
	_alternar_modo(Modo.COMPRA)
	
	if label_nome: label_nome.text = "[center][b][color=purple]" + nome.to_upper() + "[/color][/b][/center]"
	if label_categoria: label_categoria.text = "[center][b][color=gray]" + categoria.to_upper() + "[/color][/b][/center]"
	if label_descricao: label_descricao.text = descricao
	if label_bonus_pop: label_bonus_pop.text = "[b][color=green]+ " + str(bonus_pop) + " Popularidade[/color][/b]"
	if label_bonus_infra: label_bonus_infra.text = "[b][color=orange]+ " + str(bonus_infra) + " Infraestrutura[/color][/b]"
	if button_comprar: button_comprar.text = "COMPRAR\nR$ " + _formatar_numero(preco)
	if icone and textura_predio: icone.texture = textura_predio
	
	_animar_popin()


# ==============================================================================
# 🛠️ ABRIR NO MODO UPGRADE (Ex: Hospital)
# ==============================================================================
func abrir_modo_upgrade(
	nome: String, 
	nivel: int, 
	ganhos: float, 
	pct_infra: float, 
	preco_upgrade: float, 
	textura_predio: Texture2D
) -> void:
	
	_alternar_modo(Modo.UPGRADE)
	
	if label_nome: label_nome.text = "[center][b][color=red]" + nome.to_upper() + "[/color][/b][/center]"
	if label_nivel: label_nivel.text = "[center][b][color=gray]NÍVEL: " + str(nivel) + "[/color][/b][/center]"
	if label_ganhos: label_ganhos.text = "GANHOS\n[color=green]R$ " + _formatar_numero(ganhos) + "[/color]"
	if barra_infra: barra_infra.value = pct_infra
	if button_aprimorar: button_aprimorar.text = "APRIMORAR\nR$ " + _formatar_numero(preco_upgrade)
	if icone and textura_predio: icone.texture = textura_predio
	
	_animar_popin()


# ==============================================================================
# 🎬 LÓGICA DE EXIBIÇÃO E ANIMAÇÃO
# ==============================================================================

func _alternar_modo(modo: Modo) -> void:
	if modo == Modo.COMPRA:
		if coluna_stats: coluna_stats.hide()
		if label_nivel: label_nivel.hide()
		if label_categoria: label_categoria.show()
		if container_compra: container_compra.show()
		if container_upgrade: container_upgrade.hide()
	else:
		if coluna_stats: coluna_stats.show()
		if label_nivel: label_nivel.show()
		if label_categoria: label_categoria.hide()
		if container_compra: container_compra.hide()
		if container_upgrade: container_upgrade.show()


func _animar_popin() -> void:
	show()
	if painel_central:
		painel_central.pivot_offset = painel_central.size / 2.0
		painel_central.scale = Vector2.ZERO
		
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(painel_central, "scale", Vector2.ONE, 0.25)


func fechar_janela() -> void:
	if painel_central:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(painel_central, "scale", Vector2.ZERO, 0.15)
		tween.tween_callback(hide)
	else:
		hide()


func _conectar_botoes() -> void:
	if button_comprar and not button_comprar.pressed.is_connected(_on_comprar_pressed):
		button_comprar.pressed.connect(_on_comprar_pressed)
		
	if button_aprimorar and not button_aprimorar.pressed.is_connected(_on_aprimorar_pressed):
		button_aprimorar.pressed.connect(_on_aprimorar_pressed)
		
	if button_detalhes and not button_detalhes.pressed.is_connected(_on_detalhes_pressed):
		button_detalhes.pressed.connect(_on_detalhes_pressed)


func _on_comprar_pressed() -> void:
	compra_confirmada.emit(label_nome.get_parsed_text())
	fechar_janela()


func _on_aprimorar_pressed() -> void:
	aprimoramento_confirmado.emit(label_nome.get_parsed_text())
	fechar_janela()


func _on_detalhes_pressed() -> void:
	detalhes_solicitados.emit(label_nome.get_parsed_text())


## Função utilitária para formatar números em estilo moeda (ex: 290000 -> "290.000")
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
