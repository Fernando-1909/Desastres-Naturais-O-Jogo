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

@onready var coluna_dicas_v_box: VBoxContainer = %ColunaDicasVBox if has_node("%ColunaDicasVBox") else null
@onready var texto_dica_label: Node = %TextoDicaLabel if has_node("%TextoDicaLabel") else null
@onready var check_box_dicas: CheckBox = %CheckBoxDicas if has_node("%CheckBoxDicas") else null

@onready var botao_fechar: Button = $PainelCentral/ContainerMargem/ConteudoVBox/CabecalhoHBox/BotaoFechar if has_node("PainelCentral/ContainerMargem/ConteudoVBox/CabecalhoHBox/BotaoFechar") else null
@onready var botao_ok: Button = %BotaoOk if has_node("%BotaoOk") else null

var _historico_dicas: Array[String] = []
var _dicas_habilitadas: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_resolver_falhas_de_nos()

	if botao_fechar and not botao_fechar.pressed.is_connected(fechar_tela):
		botao_fechar.pressed.connect(fechar_tela)
	if botao_ok and not botao_ok.pressed.is_connected(fechar_tela):
		botao_ok.pressed.connect(fechar_tela)
	if check_box_dicas and not check_box_dicas.toggled.is_connected(_on_check_box_dicas_toggled):
		check_box_dicas.toggled.connect(_on_check_box_dicas_toggled)

	_atualizar_visibilidade_dicas()


## Chamado por main_game.gd para abrir e atualizar os dados da tela
func abrir_tela(main_game: Node2D) -> void:
	if main_game == null:
		return
		
	_atualizar_valores_financeiros(main_game)
	_atualizar_historico_dicas(main_game)
	
	visible = true


func fechar_tela() -> void:
	visible = false


func definir_modo_pesquisa_dicas(ativado: bool) -> void:
	_dicas_habilitadas = ativado
	if check_box_dicas:
		check_box_dicas.button_pressed = ativado
	_atualizar_visibilidade_dicas()


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


## Gera uma dica dinâmica/contextual baseada nas variáveis atuais do jogo
func _gerar_dica_contextual(main_game: Node2D) -> String:
	# 1. Sem Bombeiros
	if main_game.has_method("contar_estacoes_bombeiro_construidas") and main_game.contar_estacoes_bombeiro_construidas() == 0:
		return "[color=#ff6666]⚠️ Sem Bombeiros:[/color] Construa uma Estação de Bombeiros na zona de serviços para permitir o resgate de pessoas durante enchentes."

	# 2. Sem Abrigos
	if main_game.has_method("contar_abrigos_construidos") and main_game.contar_abrigos_construidos() == 0:
		return "[color=#ffbb33]⚠️ Sem Abrigos:[/color] Construa Abrigos para dar refúgio às pessoas desabrigadas pelas enchentes."

	# 3. Bombas sem Estação de Tratamento
	var tem_bomba: bool = main_game.contar_construcoes_por_categoria("bomba") > 0 if main_game.has_method("contar_construcoes_por_categoria") else false
	var tem_tratamento: bool = main_game.contar_construcoes_por_categoria("estacao_tratamento") > 0 if main_game.has_method("contar_construcoes_por_categoria") else false
	if tem_bomba and not tem_tratamento:
		return "[color=#ffbb33]💡 Drenagem:[/color] Bombas de drenagem só reduzem enchentes se houver uma Estação de Tratamento ativa no mapa."

	# 4. Déficit Financeiro (Manutenção maior que tributos)
	var receita: int = main_game.calcular_renda_com_multiplicadores_de_zona() if main_game.has_method("calcular_renda_com_multiplicadores_de_zona") else 0
	var despesa: int = main_game.calcular_custo_manutencao_construcoes() if main_game.has_method("calcular_custo_manutencao_construcoes") else 0
	if (receita - despesa) < 0:
		return "[color=#ff6666]🔴 Déficit:[/color] A manutenção das suas construções superou a receita. Aprimore zonas residenciais para aumentar arrecadação."

	# 5. Reconstrução Pós-Enchente Padrão
	var danos: float = Global.dano_total if "dano_total" in Global else 0.0
	if danos > 0 and Global.casas_destruidas > 0:
		return "[color=#ffbb33]🌊 Reconstrução:[/color] Reconstrua casas destruídas para recuperar moradores e receita de tributos."

	# 6. Dicas Gerais Educativas (Fallback aleatório)
	if not lista_dicas.is_empty():
		var idx = randi() % lista_dicas.size()
		return "💡 " + lista_dicas[idx]

	return "💡 Mantenha a popularidade e os tributos equilibrados para garantir a expansão sustentável da cidade."


## Atualiza o registro de histórico de dicas com o turno atual
func _atualizar_historico_dicas(main_game: Node2D) -> void:
	var nova_dica = _gerar_dica_contextual(main_game)
	var turno_atual: int = Global.turno if "turno" in Global else 0
	var entrada_formatada = "[b][color=#80d0ff]• Turno %d:[/color][/b] %s" % [turno_atual, nova_dica]

	# Adiciona no topo se o histórico estiver vazio ou se for diferente da última dica gerada
	if _historico_dicas.is_empty() or not _historico_dicas[0].contains(nova_dica):
		_historico_dicas.push_front(entrada_formatada)

	_exibir_historico_dicas()


func _exibir_historico_dicas() -> void:
	if not texto_dica_label:
		return

	if _historico_dicas.is_empty():
		_definir_texto_no(texto_dica_label, "Nenhuma dica registrada ainda.")
		return

	var texto_completo = ""
	for i in range(_historico_dicas.size()):
		texto_completo += _historico_dicas[i]
		if i < _historico_dicas.size() - 1:
			texto_completo += "\n\n[color=#444444]----------------------------------------[/color]\n\n"

	_definir_texto_no(texto_dica_label, texto_completo)


func _on_check_box_dicas_toggled(toggled_on: bool) -> void:
	_dicas_habilitadas = toggled_on
	_atualizar_visibilidade_dicas()


func _atualizar_visibilidade_dicas() -> void:
	if coluna_dicas_v_box:
		coluna_dicas_v_box.visible = _dicas_habilitadas


## Define texto com segurança tanto para Label quanto para RichTextLabel
func _definir_texto_no(no: Node, texto: String) -> void:
	if no == null:
		return
	if no is Label or no is RichTextLabel or "text" in no:
		no.text = texto


## Busca os nós automaticamente por padrão de nome se não foram marcados com Unique Name (%)
func _resolver_falhas_de_nos() -> void:
	if not saldo_valor: saldo_valor = find_child("*Saldo*", true, false)
	if not receita_valor: receita_valor = find_child("*Receita*", true, false)
	if not despesa_valor: despesa_valor = find_child("*Despesa*", true, false)
	if not balanco_valor: balanco_valor = find_child("*Balanco*", true, false)
	if not gasto_obras_valor: gasto_obras_valor = find_child("*Obras*", true, false)
	if not danos_valor: danos_valor = find_child("*Dano*", true, false)
	if not texto_dica_label: texto_dica_label = find_child("*Dica*", true, false)
	if not coluna_dicas_v_box: coluna_dicas_v_box = find_child("*ColunaDicas*", true, false) as VBoxContainer
	if not botao_fechar: botao_fechar = find_child("*Fechar*", true, false) as Button
	if not botao_ok: botao_ok = find_child("*Ok*", true, false) as Button
	if not check_box_dicas: check_box_dicas = find_child("*Check*", true, false) as CheckBox
