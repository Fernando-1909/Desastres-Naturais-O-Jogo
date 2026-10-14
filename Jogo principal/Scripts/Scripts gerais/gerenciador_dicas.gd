extends Node
class_name GerenciadorDicas

signal nova_dica_disponivel(id_dica: String)
signal lista_dicas_atualizada

enum CategoriaDica {
	ALERTA,     # 🟡 Alertas Urgentes
	PRATICA,    # 🟢 Dicas Práticas de Gestão
	HISTORICO   # 📜 Diálogos já visualizados
}

# Estrutura das dicas cadastradas no sistema
var banco_dicas: Dictionary = {
	"dica_deficit": {
		"id": "dica_deficit",
		"titulo_chave": "TXT_TITULO_DEFICIT",
		"no_dialogo": "dica_deficit_1",
		"categoria": CategoriaDica.ALERTA,
		"desbloqueada": false,
		"lida": false
	},
	"dica_sem_tratamento": {
		"id": "dica_sem_tratamento",
		"titulo_chave": "TXT_TITULO_SEM_TRATAMENTO",
		"no_dialogo": "dica_sem_tratamento_1",
		"categoria": CategoriaDica.ALERTA,
		"desbloqueada": false,
		"lida": false
	},
	"dica_bombeiros": {
		"id": "dica_bombeiros",
		"titulo_chave": "TXT_TITULO_BOMBEIROS",
		"no_dialogo": "dica_bombeiros_1",
		"categoria": CategoriaDica.ALERTA,
		"desbloqueada": false,
		"lida": false
	},
	"dica_abrigos": {
		"id": "dica_abrigos",
		"titulo_chave": "TXT_TITULO_ABRIGOS",
		"no_dialogo": "dica_abrigos_1",
		"categoria": CategoriaDica.ALERTA,
		"desbloqueada": false,
		"lida": false
	},
	"dica_expansao": {
		"id": "dica_expansao",
		"titulo_chave": "TXT_TITULO_EXPANSAO",
		"no_dialogo": "dica_expansao_1",
		"categoria": CategoriaDica.PRATICA,
		"desbloqueada": false,
		"lida": false
	}
}

var dicas_desbloqueadas: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Avalia os dados do main_game a cada turno ou ação relevante
func avaliar_condicoes_cidade(main_game: Node2D) -> void:
	if main_game == null:
		return

	var turno: int = Global.turno if "turno" in Global else 0
	var receita: int = main_game.calcular_renda_com_multiplicadores_de_zona() if main_game.has_method("calcular_renda_com_multiplicadores_de_zona") else 0
	var despesa: int = main_game.calcular_custo_manutencao_construcoes() if main_game.has_method("calcular_custo_manutencao_construcoes") else 0

	# 1. Checagem de Déficit Orçamentário
	if (receita - despesa) < 0:
		_desbloquear_dica("dica_deficit")

	# 2. Bombas de drenagem sem Estação de Tratamento
	var tem_bomba: bool = main_game.contar_construcoes_por_categoria("bomba") > 0 if main_game.has_method("contar_construcoes_por_categoria") else false
	var tem_tratamento: bool = main_game.contar_construcoes_por_categoria("estacao_tratamento") > 0 if main_game.has_method("contar_construcoes_por_categoria") else false
	if tem_bomba and not tem_tratamento:
		_desbloquear_dica("dica_sem_tratamento")

	# 3. Sem Bombeiros a partir do Turno 2
	if turno >= 2:
		if main_game.has_method("contar_estacoes_bombeiro_construidas") and main_game.contar_estacoes_bombeiro_construidas() == 0:
			_desbloquear_dica("dica_bombeiros")

	# 4. Sem Abrigos a partir do Turno 6
	if turno >= 6:
		if main_game.has_method("contar_abrigos_construidos") and main_game.contar_abrigos_construidos() == 0:
			_desbloquear_dica("dica_abrigos")

	# 5. Dica de Expansão Residencial Padrão
	if turno >= 1:
		_desbloquear_dica("dica_expansao")


func _desbloquear_dica(id_dica: String) -> void:
	if not banco_dicas.has(id_dica):
		return

	var dica = banco_dicas[id_dica]
	if not dica["desbloqueada"]:
		dica["desbloqueada"] = true
		dicas_desbloqueadas.append(id_dica)
		nova_dica_disponivel.emit(id_dica)
		lista_dicas_atualizada.emit()


func marcar_como_lida(id_dica: String) -> void:
	if banco_dicas.has(id_dica):
		banco_dicas[id_dica]["lida"] = true
		lista_dicas_atualizada.emit()


func tem_dica_nao_lida() -> bool:
	for id in dicas_desbloqueadas:
		if banco_dicas.has(id) and not banco_dicas[id]["lida"]:
			return true
	return false


func obter_dicas_filtradas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for id in dicas_desbloqueadas:
		if banco_dicas.has(id):
			lista.append(banco_dicas[id])
	return lista
