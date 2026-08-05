extends CanvasLayer
class_name TelaCompras

enum Modo { COMPRA, UPGRADE }

# ==============================================================================
# REFERÊNCIAS DE CONTAINERS E ESTRUTURA DO LAYOUT
# ==============================================================================
@export_group("Layout & Containers")
@export var painel_central: PanelContainer
@export var overlay_fundo: ColorRect
@export var colunas_grid: HBoxContainer

@export var coluna_stats: VBoxContainer
@export var coluna_esquerda: VBoxContainer
@export var coluna_direita: VBoxContainer

@export var container_compra: VBoxContainer
@export var container_upgrade: VBoxContainer

@export_group("Painel Pop-in de Detalhes")
@export var painel_detalhes: PanelContainer
@export var label_titulo_detalhes: RichTextLabel
@export var label_texto_detalhes: RichTextLabel
@export var button_fechar_detalhes: Button

# ==============================================================================
# REFERÊNCIAS DOS ELEMENTOS INDIVIDUAIS DE INTERFACE
# ==============================================================================
@export_group("Elementos do Card (ColunaEsquerda)")
@export var label_nome: RichTextLabel
@export var icone: TextureRect
@export var label_categoria: RichTextLabel
@export var label_nivel: RichTextLabel

@export_group("Elementos do Modo Compra (ContainerCompra)")
@export var label_descricao: RichTextLabel
@export var label_bonus_pop: RichTextLabel
@export var label_bonus_infra: RichTextLabel
@export var button_comprar: Button

@export_group("Elementos do Modo Upgrade (ContainerUpgrade)")
@export var label_disc: RichTextLabel
@export var button_aprimorar: Button
@export var button_detalhes: Button

@export_group("Elementos de Stats e Gerais")
@export var label_ganhos: RichTextLabel
@export var barra_infra: ProgressBar
@export var button_fechar: Button

# ==============================================================================
# SINAIS E VARIÁVEIS INTERNAS
# ==============================================================================
signal compra_confirmada(nome_edificio: String)
signal aprimoramento_confirmado(nome_edificio: String)
signal detalhes_solicitados(nome_edificio: String)

# Estado atual para permitir atualização dinâmica ao trocar o idioma
var _modo_atual: int = -1 # -1: Fechado, 0: COMPRA, 1: UPGRADE
var _dados_compra: Dictionary = {}
var _dados_upgrade: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_configurar_propriedades_texto()
	_resetar_tudo()
	hide()
	_conectar_botoes()
	_conectar_sinal_idioma()


func _conectar_sinal_idioma() -> void:
	# Conecta ao sinal global de alteração de idioma
	if typeof(Global) != TYPE_NIL and Global.has_signal("idioma_alterado"):
		if not Global.idioma_alterado.is_connected(_on_idioma_alterado):
			Global.idioma_alterado.connect(_on_idioma_alterado)


func _on_idioma_alterado(_novo_codigo: String) -> void:
	# Recarrega a interface com o novo idioma se ela estiver visível
	if visible:
		if _modo_atual == Modo.COMPRA:
			_atualizar_interface_compra()
		elif _modo_atual == Modo.UPGRADE:
			_atualizar_interface_upgrade()
			if painel_detalhes and painel_detalhes.visible:
				_atualizar_conteudo_detalhes()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if painel_detalhes and painel_detalhes.visible:
			fechar_detalhes()
		else:
			fechar_janela()


func _configurar_propriedades_texto() -> void:
	var labels = [
		label_nome, label_categoria, label_nivel, label_descricao, 
		label_disc, label_ganhos, label_titulo_detalhes, label_texto_detalhes
	]
	for l in labels:
		if l:
			l.fit_content = true
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if painel_detalhes and painel_detalhes.custom_minimum_size == Vector2.ZERO:
		painel_detalhes.custom_minimum_size = Vector2(380, 200)


# ==============================================================================
# LIMPEZA E RESET DE ESTADO
# ==============================================================================
func _resetar_tudo() -> void:
	_modo_atual = -1
	
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
# MODO COMPRA
# ==============================================================================
func abrir_modo_compra(
	nome: String, 
	categoria: String, 
	descricao: String, 
	bonus_pop: int, 
	preco: float, 
	textura_predio: Texture2D
) -> void:
	
	_resetar_tudo()
	_modo_atual = Modo.COMPRA
	
	# Armazena os dados para o caso de o idioma mudar
	_dados_compra = {
		"nome": nome,
		"categoria": categoria,
		"descricao": descricao,
		"bonus_pop": bonus_pop,
		"preco": preco,
		"textura": textura_predio
	}
	
	_atualizar_interface_compra()
	
	if colunas_grid and coluna_esquerda and coluna_direita:
		colunas_grid.move_child(coluna_esquerda, 0)
		colunas_grid.move_child(coluna_direita, 1)
	
	_animar_popin()


func _atualizar_interface_compra() -> void:
	if container_compra: container_compra.visible = true
	if label_categoria: label_categoria.visible = true
	if label_bonus_pop: label_bonus_pop.visible = true
	if button_comprar: button_comprar.visible = true
	
	var desc_traduzida = tr(_dados_compra["descricao"])
	if label_descricao:
		var tem_desc = desc_traduzida.strip_edges() != ""
		label_descricao.visible = tem_desc
		if tem_desc:
			label_descricao.text = "[center]" + desc_traduzida + "[/center]"

	# A função tr() busca a chave no CSV. Se não encontrar, exibe o próprio texto.
	var nome_traduzido = tr(_dados_compra["nome"]).to_upper()
	var cat_traduzida = tr(_dados_compra["categoria"]).to_upper()
	var texto_pop_traduzido = tr("HUD_POPULARIDADE")
	var texto_comprar_traduzido = tr("UI_COMPRAR")
	
	if label_nome: label_nome.text = "[center][b][color=purple]" + nome_traduzido + "[/color][/b][/center]"
	if label_categoria: label_categoria.text = "[center][b][color=lightblue]" + cat_traduzida + "[/color][/b][/center]"
	if label_bonus_pop: label_bonus_pop.text = "[center][b][color=green]+ " + str(_dados_compra["bonus_pop"]) + " " + texto_pop_traduzido + "[/color][/b][/center]"
	
	_definir_texto_botao(button_comprar, texto_comprar_traduzido + "\nR$ " + _formatar_numero(_dados_compra["preco"]))
	
	if icone and _dados_compra["textura"]: 
		icone.texture = _dados_compra["textura"]


# ==============================================================================
# MODO UPGRADE
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
	_modo_atual = Modo.UPGRADE
	
	# Armazena os dados para o caso de o idioma mudar
	_dados_upgrade = {
		"nome": nome,
		"nivel": nivel,
		"ganhos": ganhos,
		"durabilidade_pct": durabilidade_pct,
		"preco_upgrade": preco_upgrade,
		"textura": textura_predio,
		"descricao": descricao,
		"texto_detalhes": texto_detalhes,
		"pode_aprimorar": pode_aprimorar
	}
	
	_atualizar_interface_upgrade()
	
	if colunas_grid and coluna_stats and coluna_esquerda and coluna_direita:
		colunas_grid.move_child(coluna_stats, 0)
		colunas_grid.move_child(coluna_esquerda, 1)
		colunas_grid.move_child(coluna_direita, 2)
	
	_animar_popin()


func _atualizar_interface_upgrade() -> void:
	if coluna_stats: coluna_stats.visible = true
	if container_upgrade: container_upgrade.visible = true
	if label_nivel: label_nivel.visible = true
	if label_ganhos: label_ganhos.visible = true
	if barra_infra: barra_infra.visible = true
	
	var desc_traduzida = tr(_dados_upgrade["descricao"])
	if label_disc:
		var tem_desc = desc_traduzida.strip_edges() != ""
		label_disc.visible = tem_desc
		if tem_desc:
			label_disc.text = "[center]" + desc_traduzida + "[/center]"

	var detalhes_traduzido = tr(_dados_upgrade["texto_detalhes"])
	if button_detalhes:
		var tem_detalhes = detalhes_traduzido.strip_edges() != ""
		button_detalhes.visible = tem_detalhes
		if tem_detalhes:
			_definir_texto_botao(button_detalhes, tr("UI_DETALHES"))

	if button_aprimorar: 
		button_aprimorar.visible = true
		if _dados_upgrade["pode_aprimorar"]:
			button_aprimorar.disabled = false
			_definir_texto_botao(button_aprimorar, tr("UI_APRIMORAR") + "\nR$ " + _formatar_numero(_dados_upgrade["preco_upgrade"]))
		else:
			button_aprimorar.disabled = true
			_definir_texto_botao(button_aprimorar, tr("UI_NIVEL_MAXIMO"))
	
	var nome_traduzido = tr(_dados_upgrade["nome"]).to_upper()
	if label_nome: label_nome.text = "[center][b][color=red]" + nome_traduzido + "[/color][/b][/center]"
	if label_nivel: label_nivel.text = "[center][b][color=lightblue]" + tr("UI_NIVEL") + ": " + str(_dados_upgrade["nivel"]) + "[/color][/b][/center]"
	if label_ganhos: label_ganhos.text = "[center]" + tr("UI_GANHOS") + "\n[color=green]R$ " + _formatar_numero(_dados_upgrade["ganhos"]) + "[/color][/center]"
	
	if barra_infra: 
		barra_infra.value = _dados_upgrade["durabilidade_pct"]
		barra_infra.tooltip_text = "Integridade: " + str(int(_dados_upgrade["durabilidade_pct"])) + "%"
		
	if icone and _dados_upgrade["textura"]: 
		icone.texture = _dados_upgrade["textura"]


# ==============================================================================
# PAINEL SECUNDÁRIO (POP-IN DE DETALHES)
# ==============================================================================
func _abrir_detalhes() -> void:
	if not painel_detalhes: return
	
	_atualizar_conteudo_detalhes()
		
	painel_detalhes.show()
	painel_detalhes.pivot_offset = painel_detalhes.size / 2.0
	painel_detalhes.scale = Vector2.ZERO
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(painel_detalhes, "scale", Vector2.ONE, 0.2)


func _atualizar_conteudo_detalhes() -> void:
	if not _dados_upgrade.has("nome"): return
	
	var nome_traduzido = tr(_dados_upgrade["nome"]).to_upper()
	var texto_detalhes_traduzido = tr(_dados_upgrade["texto_detalhes"])
	var titulo_detalhes_traduzido = tr("UI_DETALHES")
	
	if label_titulo_detalhes:
		label_titulo_detalhes.text = "[center][b][color=gold]" + nome_traduzido + " - " + titulo_detalhes_traduzido + "[/color][/b][/center]"
		
	if label_texto_detalhes:
		label_texto_detalhes.text = "[center][color=#ffffff]" + texto_detalhes_traduzido + "[/color][/center]"


func fechar_detalhes() -> void:
	if not painel_detalhes: return
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(painel_detalhes, "scale", Vector2.ZERO, 0.12)
	tween.tween_callback(func():
		painel_detalhes.hide()
	)


# ==============================================================================
# GERENCIAMENTO DE PAUSA E ANIMAÇÕES
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
# CONEXÃO DE SINAIS E AÇÕES DOS BOTÕES
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
	compra_confirmada.emit(_dados_compra.get("nome", ""))
	fechar_janela()


func _on_aprimoramento_pressed() -> void:
	aprimoramento_confirmado.emit(_dados_upgrade.get("nome", ""))
	fechar_janela()


func _on_detalhes_pressed() -> void:
	detalhes_solicitados.emit(_dados_upgrade.get("nome", ""))
	_abrir_detalhes()


# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================
func _definir_texto_botao(btn: Button, texto_bbcode: String) -> void:
	if not btn: return
	
	var rtl = btn.get_node_or_null("RichTextLabel") as RichTextLabel
	if rtl:
		rtl.text = "[center]" + texto_bbcode + "[/center]"
	else:
		btn.text = texto_bbcode


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
