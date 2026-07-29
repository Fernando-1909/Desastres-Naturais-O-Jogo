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

@export var coluna_stats: VBoxContainer      # ColunaStats
@export var coluna_esquerda: VBoxContainer   # ColunaEsquerda
@export var coluna_direita: VBoxContainer    # ColunaDireita

@export var container_compra: VBoxContainer  # ContainerCompra
@export var container_upgrade: VBoxContainer # ContainerUpgrade

@export_group("Painel Pop-in de Detalhes")
@export var painel_detalhes: PanelContainer
@export var label_titulo_detalhes: RichTextLabel # LabelTituloDetalhes
@export var label_texto_detalhes: RichTextLabel  # LabelTextoDetalhes
@export var button_fechar_detalhes: Button       # ButtonFecharDetalhes

# ==============================================================================
# 📌 REFERÊNCIAS DOS ELEMENTOS INDIVIDUAIS
# ==============================================================================
@export_group("Elementos do Card (ColunaEsquerda)")
@export var label_nome: RichTextLabel        # LabelNome
@export var icone: TextureRect               # Icone
@export var label_categoria: RichTextLabel   # LabelCategoria
@export var label_nivel: RichTextLabel       # LabelNivel

@export_group("Elementos do Modo Compra (ContainerCompra)")
@export var label_descricao: RichTextLabel   # LabelDescricao
@export var label_bonus_pop: RichTextLabel   # LabelBonusPop
@export var label_bonus_infra: RichTextLabel # LabelBonusInfra
@export var button_comprar: Button           # ButtonComprar

@export_group("Elementos do Modo Upgrade (ContainerUpgrade)")
@export var label_disc: RichTextLabel        # LabelDisc (Descrição Curta Upgrade)
@export var button_aprimorar: Button         # ButtonAprimorar
@export var button_detalhes: Button          # ButtonDetalhes

@export_group("Elementos de Stats e Gerais")
@export var label_ganhos: RichTextLabel      # LabelGanhos
@export var barra_infra: ProgressBar         # BarraInfra
@export var button_fechar: Button            # ButtonFechar

# ==============================================================================
# 📌 SINAIS E VARIÁVEIS INTERNAS
# ==============================================================================
signal compra_confirmada(nome_edificio: String)
signal aprimoramento_confirmado(nome_edificio: String)
signal detalhes_solicitados(nome_edificio: String)

var _texto_detalhes_atual: String = ""
var _nome_predio_atual: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configurar_propriedades_texto()
	_resetar_tudo()
	hide()
	_conectar_botoes()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if painel_detalhes and painel_detalhes.visible:
			fechar_detalhes()
		else:
			fechar_janela()


# Garante que os RichTextLabels quebrem linha e expandam a altura do container
func _configurar_propriedades_texto() -> void:
	var labels = [label_nome, label_categoria, label_nivel, label_descricao, label_disc, label_ganhos, label_titulo_detalhes, label_texto_detalhes]
	for l in labels:
		if l:
			l.fit_content = true
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if painel_detalhes and painel_detalhes.custom_minimum_size == Vector2.ZERO:
		painel_detalhes.custom_minimum_size = Vector2(380, 200)


# ==============================================================================
# 🧹 RESET TOTAL
# ==============================================================================
func _resetar_tudo() -> void:
	if coluna_stats: coluna_stats.visible = false
	if container_compra: container_compra.visible = false
	if container_upgrade: container_upgrade.visible = false
	if painel_detalhes: painel_detalhes.visible = false
	
	if label_categoria: label_categoria.visible = false
	if label_nivel: label_nivel.visible = false
	
	if label_descricao: label_descricao.visible = false
	if label_disc: label_disc.visible = false
	if label_bonus_pop: label_bonus_pop.visible = false
	if label_bonus_infra: label_bonus_infra.visible = false
	if label_ganhos: label_ganhos.visible = false
	if barra_infra: barra_infra.visible = false
	if button_comprar: button_comprar.visible = false
	
	if button_aprimorar: 
		button_aprimorar.visible = false
		button_aprimorar.disabled = false
		
	if button_detalhes: button_detalhes.visible = false


# ==============================================================================
# 🛒 MODO COMPRA
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
	
	if container_compra: container_compra.visible = true
	if label_categoria: label_categoria.visible = true
	if label_bonus_pop: label_bonus_pop.visible = true
	if label_bonus_infra: label_bonus_infra.visible = true
	if button_comprar: button_comprar.visible = true
	
	if label_descricao:
		var tem_desc = descricao.strip_edges() != ""
		label_descricao.visible = tem_desc
		if tem_desc:
			label_descricao.text = "[center]" + descricao + "[/center]"

	if label_nome: label_nome.text = "[center][b][color=purple]" + nome.to_upper() + "[/color][/b][/center]"
	if label_categoria: label_categoria.text = "[center][b][color=lightblue]" + categoria.to_upper() + "[/color][/b][/center]"
	if label_bonus_pop: label_bonus_pop.text = "[center][b][color=green]+ " + str(bonus_pop) + " Popularidade[/color][/b][/center]"
	if label_bonus_infra: label_bonus_infra.text = "[center][b][color=orange]+ " + str(bonus_infra) + " Infraestrutura[/color][/b][/center]"
	if button_comprar: button_comprar.text = "COMPRAR\nR$ " + _formatar_numero(preco)
	if icone and textura_predio: icone.texture = textura_predio
	
	if colunas_grid and coluna_esquerda and coluna_direita:
		colunas_grid.move_child(coluna_esquerda, 0)
		colunas_grid.move_child(coluna_direita, 1)
	
	_animar_popin()


# ==============================================================================
# ⬆️ MODO UPGRADE / INFORMAÇÕES
# ==============================================================================
func abrir_modo_upgrade(
	nome: String, 
	nivel: int, 
	ganhos: float, 
	durabilidade_pct: float, 
	preco_upgrade: float, 
	textura_predio: Texture2D,
	descricao: String = "",
	texto_detalhes: String = "",
	pode_aprimorar: bool = true
) -> void:
	
	_resetar_tudo()
	_nome_predio_atual = nome
	_texto_detalhes_atual = texto_detalhes
	
	if coluna_stats: coluna_stats.visible = true
	if container_upgrade: container_upgrade.visible = true
	if label_nivel: label_nivel.visible = true
	if label_ganhos: label_ganhos.visible = true
	if barra_infra: barra_infra.visible = true
	
	# Exibe Descrição Curta
	if label_disc:
		var tem_desc = descricao.strip_edges() != ""
		label_disc.visible = tem_desc
		if tem_desc:
			label_disc.text = "[center]" + descricao + "[/center]"

	# Exibe Botão de Detalhes
	if button_detalhes:
		var tem_detalhes = texto_detalhes.strip_edges() != ""
		button_detalhes.visible = tem_detalhes
		if tem_detalhes:
			button_detalhes.text = "DETALHES"

	# Exibe Botão de Aprimorar ou Nível Máximo
	if button_aprimorar: 
		button_aprimorar.visible = true
		if pode_aprimorar:
			button_aprimorar.disabled = false
			button_aprimorar.text = "APRIMORAR\nR$ " + _formatar_numero(preco_upgrade)
		else:
			button_aprimorar.disabled = true
			button_aprimorar.text = "NÍVEL MÁXIMO"
	
	if label_nome: label_nome.text = "[center][b][color=red]" + nome.to_upper() + "[/color][/b][/center]"
	if label_nivel: label_nivel.text = "[center][b][color=lightblue]NÍVEL: " + str(nivel) + "[/color][/b][/center]"
	if label_ganhos: label_ganhos.text = "[center]GANHOS\n[color=green]R$ " + _formatar_numero(ganhos) + "[/color][/center]"
	
	if barra_infra: 
		barra_infra.value = durabilidade_pct
		barra_infra.tooltip_text = "Integridade do Prédio: " + str(int(durabilidade_pct)) + "%"
		
	if icone and textura_predio: icone.texture = textura_predio
	
	if colunas_grid and coluna_stats and coluna_esquerda and coluna_direita:
		colunas_grid.move_child(coluna_stats, 0)
		colunas_grid.move_child(coluna_esquerda, 1)
		colunas_grid.move_child(coluna_direita, 2)
	
	_animar_popin()


# ==============================================================================
# 🔍 JANELA POP-IN DE DETALHES
# ==============================================================================
func _abrir_detalhes() -> void:
	if not painel_detalhes: return
	
	# Título estilizado em amarelo/dourado
	if label_titulo_detalhes:
		label_titulo_detalhes.text = "[center][b][color=gold]" + _nome_predio_atual.to_upper() + " - DETALHES[/color][/b][/center]"
		
	# Texto em branco vivo (#ffffff) para alto contraste e fácil leitura
	if label_texto_detalhes:
		label_texto_detalhes.text = "[center][color=#ffffff]" + _texto_detalhes_atual + "[/color][/center]"
		
	painel_detalhes.show()
	painel_detalhes.pivot_offset = painel_detalhes.size / 2.0
	painel_detalhes.scale = Vector2.ZERO
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(painel_detalhes, "scale", Vector2.ONE, 0.2)


func fechar_detalhes() -> void:
	if not painel_detalhes: return
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(painel_detalhes, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(func():
		painel_detalhes.hide()
	)


# ==============================================================================
# 🎬 ANIMAÇÕES E CONTROLE DA JANELA
# ==============================================================================
func _animar_popin() -> void:
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
# 🛠️ CONEXÕES DE BOTÕES E AUXILIARES
# ==============================================================================
func _conectar_botoes() -> void:
	if button_comprar and not button_comprar.pressed.is_connected(_on_comprar_pressed):
		button_comprar.pressed.connect(_on_comprar_pressed)
		
	if button_aprimorar and not button_aprimorar.pressed.is_connected(_on_aprimoramento_pressed):
		button_aprimorar.pressed.connect(_on_aprimoramento_pressed)
		
	if button_detalhes and not button_detalhes.pressed.is_connected(_on_detalhes_pressed):
		button_detalhes.pressed.connect(_on_detalhes_pressed)
		
	if button_fechar and not button_fechar.pressed.is_connected(fechar_janela):
		button_fechar.pressed.connect(fechar_janela)
		
	if button_fechar_detalhes and not button_fechar_detalhes.pressed.is_connected(fechar_detalhes):
		button_fechar_detalhes.pressed.connect(fechar_detalhes)


func _on_comprar_pressed() -> void:
	compra_confirmada.emit(label_nome.get_parsed_text())
	fechar_janela()


func _on_aprimoramento_pressed() -> void:
	aprimoramento_confirmado.emit(label_nome.get_parsed_text())
	fechar_janela()


func _on_detalhes_pressed() -> void:
	detalhes_solicitados.emit(label_nome.get_parsed_text())
	_abrir_detalhes()


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
