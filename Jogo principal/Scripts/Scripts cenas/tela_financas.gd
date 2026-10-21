extends Control

# Configurações editáveis diretamente no Inspetor para o Designer
@export_group("Cores de Indicadores")
@export var cor_lucro: Color = Color(0.2, 0.8, 0.2, 1.0)
@export var cor_prejuizo: Color = Color(0.9, 0.2, 0.2, 1.0)
@export var cor_neutra: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("Banco de Dicas Educativas")
@export_multiline var lista_dicas: Array[String] = [
	"Construir bombas de drenagem sem uma Estação de Tratamento ativa não reduz o dano total das enchentes.",
	"Mantenha serviços públicos e infraestrutura bem distribuídos para garantir a popularidade do prefeito.",
	"Reconstruir casas após uma enchente só é possível após concluir o resgate dos moradores desabrigados.",
	"Zonas residenciais aprimoradas geram maior arrecadação de tributos por turno para os cofres públicos."
]

# Referências de Nós com Unique Names
@onready var saldo_valor: Node = %SaldoValor if has_node("%SaldoValor") else null
@onready var receita_valor: Node = %ReceitaValor if has_node("%ReceitaValor") else null
@onready var despesa_valor: Node = %DespesaValor if has_node("%DespesaValor") else null
@onready var balanco_valor: Node = %BalancoValor if has_node("%BalancoValor") else null
@onready var gasto_obras_valor: Node = %GastoObrasValor if has_node("%GastoObrasValor") else null
@onready var danos_valor: Node = %DanosValor if has_node("%DanosValor") else null

# Indicadores de Desempenho
@onready var status_desempenho_valor: Node = %StatusDesempenhoValor if has_node("%StatusDesempenhoValor") else null
@onready var resumo_desempenho_label: Node = %ResumoDesempenhoLabel if has_node("%ResumoDesempenhoLabel") else null

# Painel e Histórico de Dicas
@onready var painel_dica: PanelContainer = %PainelDica if has_node("%PainelDica") else null
@onready var scroll_dicas: ScrollContainer = %ScrollDicas if has_node("%ScrollDicas") else null
@onready var coluna_dicas_v_box: VBoxContainer = %ColunaDicasVBox if has_node("%ColunaDicasVBox") else null
@onready var texto_dica_label: Node = %TextoDicaLabel if has_node("%TextoDicaLabel") else null
@onready var check_box_dicas: CheckBox = %CheckBoxDicas if has_node("%CheckBoxDicas") else null

@onready var botao_fechar: Button = $PainelCentral/ContainerMargem/ConteudoVBox/CabecalhoHBox/BotaoFechar if has_node("PainelCentral/ContainerMargem/ConteudoVBox/CabecalhoHBox/BotaoFechar") else null
@onready var botao_ok: Button = %BotaoOk if has_node("%BotaoOk") else null

var _historico_dicas: Array[String] = []
var _dicas_habilitadas: bool = true
var _dica_nova_recebida: bool = false
var _tween_brilho_dica: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_resolver_falhas_de_nos()

	# Remove programmaticamente o CheckBox antigo da tela de finanças
	if check_box_dicas:
		check_box_dicas.visible = false
		check_box_dicas.queue_free()

	if botao_fechar and not botao_fechar.pressed.is_connected(fechar_tela):
		botao_fechar.pressed.connect(fechar_tela)
	if botao_ok and not botao_ok.pressed.is_connected(fechar_tela):
		botao_ok.pressed.connect(fechar_tela)

	_conectar_eventos_mouse_dicas()
	_atualizar_visibilidade_dicas()


## Chamado por main_game.gd para abrir e atualizar os dados da tela
func abrir_tela(main_game: Node2D) -> void:
	if main_game == null:
		return
		
	_atualizar_visibilidade_dicas()
	_atualizar_valores_financeiros(main_game)
	_atualizar_historico_dicas(main_game)
	
	if _dica_nova_recebida:
		_iniciar_efeito_brilho_dica()
		
	get_tree().paused = true
	visible = true


func fechar_tela() -> void:
	_remover_status_nova_dica()
	get_tree().paused = false
	visible = false


func definir_modo_pesquisa_dicas(ativado: bool) -> void:
	if typeof(Global) != TYPE_NIL:
		Global.dicas_habilitadas = ativado
	_atualizar_visibilidade_dicas()


## Calcula a pontuação de desempenho do jogador no turno atual (0 a 100)
func _calcular_desempenho_turno(main_game: Node2D) -> Dictionary:
	var pontuacao: int = 0
	var problemas: Array[String] = []

	var saldo: int = Global.dinheiro if "dinheiro" in Global else 0
	var popularidade: int = Global.popularidade if "popularidade" in Global else 40
	var desabrigados: int = Global.pessoas_desabrigadas if "pessoas_desabrigadas" in Global else 0
	
	var receita: int = main_game.calcular_renda_com_multiplicadores_de_zona() if main_game.has_method("calcular_renda_com_multiplicadores_de_zona") else 0
	var despesa: int = main_game.calcular_custo_manutencao_construcoes() if main_game.has_method("calcular_custo_manutencao_construcoes") else 0
	var balanco: int = receita - despesa

	# 1. Avaliação do Balanço Líquido (Até 25 pontos)
	if balanco > 0:
		pontuacao += 25
	elif balanco == 0:
		pontuacao += 15
	else:
		pontuacao += 0
		problemas.append("déficit orçamentário por turno")

	# 2. Reserva Financeira em Caixa (Até 25 pontos)
	if saldo >= 300:
		pontuacao += 25
	elif saldo >= 100:
		pontuacao += 15
	else:
		pontuacao += 5
		problemas.append("caixa muito baixo")

	# 3. Nível de Popularidade (Até 30 pontos)
	if popularidade >= 60:
		pontuacao += 30
	elif popularidade >= 35:
		pontuacao += 20
	elif popularidade >= 20:
		pontuacao += 10
		problemas.append("popularidade baixa")
	else:
		pontuacao += 0
		problemas.append("popularidade em nível crítico")

	# 4. Gestão de Crise e População (Até 20 pontos)
	if desabrigados == 0:
		pontuacao += 20
	else:
		pontuacao += 0
		problemas.append("moradores desabrigados aguardando resgate/abrigo")

	# Classificação final do desempenho
	var nivel_str: String = ""
	var cor_hex: String = ""
	var resumo_str: String = ""

	if pontuacao >= 85:
		nivel_str = "EXCELENTE 🟢"
		cor_hex = "#4CAF50"
		resumo_str = "Sua gestão está impecável! Cofres saudáveis, alta aprovação popular e cidade segura."
	elif pontuacao >= 65:
		nivel_str = "BOM 🔵"
		cor_hex = "#2196F3"
		resumo_str = "Sua administração está estável. Fique atento às despesas com novas obras."
	elif pontuacao >= 45:
		nivel_str = "REGULAR 🟡"
		cor_hex = "#FFEB3B"
		resumo_str = "Desempenho mediano."
		if not problemas.is_empty():
			resumo_str += " Atenção para: " + ", ".join(problemas) + "."
	elif pontuacao >= 25:
		nivel_str = "PREOCUPANTE 🟠"
		cor_hex = "#FF9800"
		resumo_str = "Alerta de gestão! Problemas identificados: " + ", ".join(problemas) + "."
	else:
		nivel_str = "CRÍTICO 🔴"
		cor_hex = "#F44336"
		resumo_str = "Situação crítica! " + ", ".join(problemas) + ". Ação imediata é necessária!"

	return {
		"pontuacao": pontuacao,
		"nivel": nivel_str,
		"cor": cor_hex,
		"resumo": resumo_str
	}


func _atualizar_valores_financeiros(main_game: Node2D) -> void:
	# 1. Saldo Atual
	var saldo: int = Global.dinheiro if "dinheiro" in Global else 0
	_definir_texto_no(saldo_valor, "$ " + str(saldo))
	
	# 2. Receita estimada por turno (Tributos)
	var receita: int = 0
	if main_game.has_method("calcular_renda_com_multiplicadores_de_zona"):
		receita = main_game.calcular_renda_com_multiplicadores_de_zona()
	_definir_texto_no(receita_valor, "+$ " + str(receita))
	if receita_valor and receita_valor.has_method("add_theme_color_override"):
		receita_valor.add_theme_color_override("font_color", cor_lucro)

	# 3. Custos de Manutenção por turno
	var despesa: int = 0
	if main_game.has_method("calcular_custo_manutencao_construcoes"):
		despesa = main_game.calcular_custo_manutencao_construcoes()
	_definir_texto_no(despesa_valor, "-$ " + str(despesa))
	if despesa_valor and despesa_valor.has_method("add_theme_color_override"):
		despesa_valor.add_theme_color_override("font_color", cor_prejuizo)

	# 4. Balanço Líquido por turno
	var balanco: int = receita - despesa
	if balanco > 0:
		_definir_texto_no(balanco_valor, "+$ " + str(balanco))
		if balanco_valor and balanco_valor.has_method("add_theme_color_override"):
			balanco_valor.add_theme_color_override("font_color", cor_lucro)
	elif balanco < 0:
		_definir_texto_no(balanco_valor, "-$ " + str(abs(balanco)))
		if balanco_valor and balanco_valor.has_method("add_theme_color_override"):
			balanco_valor.add_theme_color_override("font_color", cor_prejuizo)
	else:
		_definir_texto_no(balanco_valor, "$ 0")
		if balanco_valor and balanco_valor.has_method("add_theme_color_override"):
			balanco_valor.add_theme_color_override("font_color", cor_neutra)

	# 5. Gastos Totais em Obras Acumulados
	var gastos_obras: int = Global.gastos_totais_obras if "gastos_totais_obras" in Global else 0
	_definir_texto_no(gasto_obras_valor, "$ " + str(gastos_obras))

	# 6. Danos Acumulados por Enchentes
	var danos: float = Global.dano_total if "dano_total" in Global else 0.0
	_definir_texto_no(danos_valor, "$ " + str(int(danos)))
	if danos_valor and danos > 0 and danos_valor.has_method("add_theme_color_override"):
		danos_valor.add_theme_color_override("font_color", cor_prejuizo)

	# 7. Avaliação do Desempenho do Turno
	var info_desempenho = _calcular_desempenho_turno(main_game)
	if status_desempenho_valor:
		_definir_texto_no(status_desempenho_valor, "[b][color=%s]%s (%d/100)[/color][/b]" % [info_desempenho["cor"], info_desempenho["nivel"], info_desempenho["pontuacao"]])
	if resumo_desempenho_label:
		_definir_texto_no(resumo_desempenho_label, "[font_size=13][color=#dddddd]%s[/color][/font_size]" % info_desempenho["resumo"])


## Gera uma dica dinâmica/contextual baseada nas variáveis e no turno atual do jogo
func _gerar_dica_contextual(main_game: Node2D) -> String:
	var turno_atual: int = Global.turno if "turno" in Global else 0

	# 1. Sem Prefeitura no início (Turno 1 a 8)
	var tem_prefeitura = main_game._tem_prefeitura_construida() if main_game.has_method("_tem_prefeitura_construida") else true
	if turno_atual >= 1 and turno_atual < 9 and not tem_prefeitura:
		return "Construa a Prefeitura o quanto antes! Sem ela, nossa gestão não terá legitimidade para enfrentar a primeira enchente do turno 9."

	# 2. Déficit Financeiro (Manutenção maior que receita)
	var receita: int = main_game.calcular_renda_com_multiplicadores_de_zona() if main_game.has_method("calcular_renda_com_multiplicadores_de_zona") else 0
	var despesa: int = main_game.calcular_custo_manutencao_construcoes() if main_game.has_method("calcular_custo_manutencao_construcoes") else 0
	if (receita - despesa) < 0 or Global.dinheiro < 100:
		return tr("DICA_DEFICIT")

	# 3. Reconstrução Pós-Enchente (Apenas se houver desabrigados ou casas destruídas)
	var desabrigados: int = Global.pessoas_desabrigadas if "pessoas_desabrigadas" in Global else 0
	var casas_destruidas: int = Global.casas_destruidas if "casas_destruidas" in Global else 0
	if desabrigados > 0 or casas_destruidas > 0:
		return tr("DICA_RECONSTRUCAO")

	# 4. Sem Bombeiros (SÓ SUGERE SE TURNO >= 2, com a Missão 1)
	if turno_atual >= 2:
		if main_game.has_method("contar_estacoes_bombeiro_construidas") and main_game.contar_estacoes_bombeiro_construidas() == 0:
			return tr("DICA_SEM_BOMBEIROS")

	# 5. Sem Abrigos (SÓ SUGERE SE TURNO >= 6, com a Missão 2 e aproximação da enchente)
	if turno_atual >= 6:
		if main_game.has_method("contar_abrigos_construidos") and main_game.contar_abrigos_construidos() == 0:
			return tr("DICA_SEM_ABRIGOS")

	# 6. Alerta para Segunda Enchente / Bombas no Rio (Turno 15 a 20)
	if turno_atual >= 15 and turno_atual <= 20:
		var tem_bomba: bool = main_game.contar_construcoes_por_categoria("bomba") > 0 if main_game.has_method("contar_construcoes_por_categoria") else false
		if not tem_bomba:
			return "Instale Bombas de Drenagem na Zona do Rio até o turno 20 para defender a cidade da segunda enchente!"

	# 7. Bombas sem Estação de Tratamento (SÓ SUGERE SE TURNO >= 16 ou se já houver bombas no mapa)
	var tem_bomba: bool = main_game.contar_construcoes_por_categoria("bomba") > 0 if main_game.has_method("contar_construcoes_por_categoria") else false
	var tem_tratamento: bool = main_game.contar_construcoes_por_categoria("estacao_tratamento") > 0 if main_game.has_method("contar_construcoes_por_categoria") else false
	if (tem_bomba or turno_atual >= 16) and not tem_tratamento:
		return tr("DICA_SEM_TRATAMENTO")

	# 8. Dicas Gerais Educativas (Fallback)
	var lista_chaves_dicas: Array[String] = ["DICA_GERAL_1", "DICA_GERAL_2", "DICA_GERAL_3", "DICA_GERAL_4"]
	var idx = randi() % lista_chaves_dicas.size()
	return tr(lista_chaves_dicas[idx])


## Atualiza o registro de histórico de dicas com o turno atual
func _atualizar_historico_dicas(main_game: Node2D) -> void:
	var nova_dica = _gerar_dica_contextual(main_game)
	var turno_atual: int = Global.turno if "turno" in Global else 0
	
	var prefixo_turno = tr("DICA_TURNO_PREFIXO")
	if "%d" in prefixo_turno:
		prefixo_turno = prefixo_turno % turno_atual
	else:
		prefixo_turno = "• Turno %d:" % turno_atual

	var entrada_formatada = "[b][color=#80d0ff]%s[/color][/b] %s" % [prefixo_turno, nova_dica]

	if _historico_dicas.is_empty() or not _historico_dicas[0].contains(nova_dica):
		_historico_dicas.push_front(entrada_formatada)
		_dica_nova_recebida = true

	_exibir_historico_dicas()


func _exibir_historico_dicas() -> void:
	if not texto_dica_label:
		return

	if _historico_dicas.is_empty():
		_definir_texto_no(texto_dica_label, tr("DICA_HISTORICO_VAZIO"))
		return

	var texto_completo = ""
	for i in range(_historico_dicas.size()):
		texto_completo += _historico_dicas[i]

		if i < _historico_dicas.size() - 1:
			texto_completo += "\n\n[color=#3d3d3d]──────────────────────────────────────────────────────────[/color]\n\n"

	_definir_texto_no(texto_dica_label, texto_completo)


func _iniciar_efeito_brilho_dica() -> void:
	if not painel_dica:
		return
		
	if _tween_brilho_dica and _tween_brilho_dica.is_valid():
		_tween_brilho_dica.kill()
		
	painel_dica.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	_tween_brilho_dica = create_tween().set_loops()
	_tween_brilho_dica.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween_brilho_dica.tween_property(painel_dica, "self_modulate", Color(1.18, 1.18, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	_tween_brilho_dica.tween_property(painel_dica, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

func _remover_status_nova_dica() -> void:
	if _dica_nova_recebida:
		_dica_nova_recebida = false
		if _tween_brilho_dica and _tween_brilho_dica.is_valid():
			_tween_brilho_dica.kill()
			_tween_brilho_dica = null
		if painel_dica:
			painel_dica.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		_exibir_historico_dicas()


func _on_painel_dica_mouse_entered() -> void:
	_remover_status_nova_dica()


func _conectar_eventos_mouse_dicas() -> void:
	if painel_dica and not painel_dica.mouse_entered.is_connected(_on_painel_dica_mouse_entered):
		painel_dica.mouse_entered.connect(_on_painel_dica_mouse_entered)
	if scroll_dicas and not scroll_dicas.mouse_entered.is_connected(_on_painel_dica_mouse_entered):
		scroll_dicas.mouse_entered.connect(_on_painel_dica_mouse_entered)


func _resolver_falhas_de_nos() -> void:
	if not saldo_valor: saldo_valor = find_child("*Saldo*", true, false)
	if not receita_valor: receita_valor = find_child("*Receita*", true, false)
	if not despesa_valor: despesa_valor = find_child("*Despesa*", true, false)
	if not balanco_valor: balanco_valor = find_child("*Balanco*", true, false)
	if not gasto_obras_valor: gasto_obras_valor = find_child("*Obras*", true, false)
	if not danos_valor: danos_valor = find_child("*Dano*", true, false)
	if not status_desempenho_valor: status_desempenho_valor = find_child("*StatusDesempenho*", true, false)
	if not resumo_desempenho_label: resumo_desempenho_label = find_child("*ResumoDesempenho*", true, false)
	if not texto_dica_label: texto_dica_label = find_child("*Dica*", true, false)
	if not coluna_dicas_v_box: coluna_dicas_v_box = find_child("*ColunaDicas*", true, false) as VBoxContainer
	if not painel_dica: painel_dica = find_child("*PainelDica*", true, false) as PanelContainer
	if not scroll_dicas: scroll_dicas = find_child("*ScrollDicas*", true, false) as ScrollContainer
	if not botao_fechar: botao_fechar = find_child("*Fechar*", true, false) as Button
	if not botao_ok: botao_ok = find_child("*Ok*", true, false) as Button


func _on_check_box_dicas_toggled(toggled_on: bool) -> void:
	_dicas_habilitadas = toggled_on
	_atualizar_visibilidade_dicas()


func _atualizar_visibilidade_dicas() -> void:
	var ativado = Global.dicas_habilitadas if ("dicas_habilitadas" in Global and Global.dicas_habilitadas != null) else true
	if coluna_dicas_v_box:
		coluna_dicas_v_box.visible = ativado


## Define texto com segurança tanto para Label quanto para RichTextLabel
func _definir_texto_no(no: Node, texto: String) -> void:
	if no == null:
		return
	if no is Label or no is RichTextLabel or "text" in no:
		no.text = texto
