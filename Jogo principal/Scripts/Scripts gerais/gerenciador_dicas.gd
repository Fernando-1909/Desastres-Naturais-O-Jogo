extends Node
class_name GerenciadorDicas

enum CategoriaDica { ALERTA, CONSELHO }

signal nova_dica_disponivel(id_dica: String)
signal lista_dicas_atualizada

# Armazena todas as dicas cadastradas/desbloqueadas
# Chave: id_dica (String) | Valor: Dictionary
var dicas_disponiveis: Dictionary = {}

func _ready() -> void:
	pass

## Avalia a situação do mapa, missões e recursos para liberar dicas com lógica sequencial correta
func avaliar_condicoes_cidade(main_game: Node2D) -> void:
	if main_game == null:
		return

	# 1. Alerta Crítico: Falta de Prefeitura (Turno 1 a 8)
	# Se chegar no turno 9 sem prefeitura, é derrota direta no desastre.
	if Global.turno >= 1 and Global.turno < 9:
		var tem_prefeitura = main_game._tem_prefeitura_construida() if main_game.has_method("_tem_prefeitura_construida") else false
		if not tem_prefeitura:
			adicionar_dica(
				"dica_prefeitura_1",
				"Construção da Prefeitura",
				"dica_prefeitura_1",
				CategoriaDica.ALERTA,
				"SECRETARIA"
			)

	# 2. Falta de Corpo de Bombeiros (Disponível a partir do Turno 2 com a Missão 1)
	if Global.turno >= 2:
		var qtd_bombeiros = main_game.contar_estacoes_bombeiro_construidas() if main_game.has_method("contar_estacoes_bombeiro_construidas") else 0
		if qtd_bombeiros <= 0:
			adicionar_dica(
				"dica_bombeiros_1",
				"Tempo de Resposta dos Bombeiros",
				"dica_bombeiros_1",
				CategoriaDica.CONSELHO,
				"SECRETARIA"
			)

	# 3. Falta de Abrigo de Emergência (Disponível a partir do Turno 6 com a Missão 2)
	if Global.turno >= 6:
		var qtd_abrigos = main_game.contar_abrigos_construidos() if main_game.has_method("contar_abrigos_construidos") else 0
		if qtd_abrigos <= 0:
			adicionar_dica(
				"dica_abrigos_1",
				"Abrigos de Emergência",
				"dica_abrigos_1",
				CategoriaDica.ALERTA,
				"SECRETARIA"
			)

	# 4. Alerta Preventivo da 1ª Enchente (Turnos 7 a 9 - Iminência do Desastre)
	if Global.turno >= 7 and Global.turno <= 9:
		adicionar_dica(
			"dica_desastre_1",
			"Prevenção de Enchentes",
			"dica_desastre_1",
			CategoriaDica.ALERTA,
			"SECRETARIA"
		)

	# 5. Alerta para a 2ª Enchente e Obrigatoriedade das Bombas de Drenagem (Turnos 15 a 19)
	# No turno 20, a falta de bombas causa derrota direta por 'mortebomba'.
	if Global.turno >= 15 and Global.turno <= 19:
		var tem_bomba = false
		if main_game.has_method("contar_construcoes_por_categoria"):
			tem_bomba = main_game.contar_construcoes_por_categoria("bomba") > 0
		if not tem_bomba:
			adicionar_dica(
				"dica_desastre_2",
				"Infraestrutura de Drenagem",
				"dica_desastre_2",
				CategoriaDica.ALERTA,
				"SECRETARIA"
			)

	# 6. Bomba instalada sem Estação de Tratamento (Pós-construção ou a partir do Turno 16)
	var tem_bomba_mapa = false
	var tem_tratamento_mapa = false
	if "construcoes_no_mapa" in main_game:
		for pos in main_game.construcoes_no_mapa.keys():
			var predio = main_game.construcoes_no_mapa[pos]
			if predio and predio.data and predio.durabilidade_atual > 0:
				var id_p = str(predio.data.id).to_lower().strip_edges()
				if "bomba" in id_p:
					tem_bomba_mapa = true
				if "tratamento" in id_p or id_p == "estacao_drenagem":
					tem_tratamento_mapa = true

	if (tem_bomba_mapa or Global.turno >= 16) and not tem_tratamento_mapa:
		adicionar_dica(
			"dica_sem_tratamento_1",
			"Tratamento de Água",
			"dica_sem_tratamento_1",
			CategoriaDica.ALERTA,
			"SECRETARIA"
		)

	# 7. Reconstrução e Resgate Pós-Enchente (Ativado se houver danos ou desabrigados)
	var desabrigados = Global.pessoas_desabrigadas if "pessoas_desabrigadas" in Global else 0
	var casas_destruidas = Global.casas_destruidas if "casas_destruidas" in Global else 0
	if desabrigados > 0 or casas_destruidas > 0:
		adicionar_dica(
			"dica_reconstrucao_1",
			"Resgate e Reconstrução",
			"dica_reconstrucao_1",
			CategoriaDica.ALERTA,
			"SECRETARIA"
		)

	# 8. Déficit Orçamentário / Pouco Caixa
	var receita = main_game.calcular_renda_com_multiplicadores_de_zona() if main_game.has_method("calcular_renda_com_multiplicadores_de_zona") else 0
	var despesa = main_game.calcular_custo_manutencao_construcoes() if main_game.has_method("calcular_custo_manutencao_construcoes") else 0
	if Global.dinheiro < 100 or (receita - despesa) < 0:
		adicionar_dica(
			"dica_deficit_1",
			"Déficit Orçamentário",
			"dica_deficit_1",
			CategoriaDica.ALERTA,
			"TESOUREIRO"
		)

	# 9. Conselho Geral do Tesoureiro (Apenas a partir do Turno 3)
	if Global.turno >= 3:
		adicionar_dica(
			"dica_expansao_1",
			"Gestão e Arrecadação",
			"dica_expansao_1",
			CategoriaDica.CONSELHO,
			"TESOUREIRO"
		)


## Adiciona ou ativa uma dica no banco de dados do jogador
func adicionar_dica(id: String, titulo_chave: String, no_dialogo: String, categoria: CategoriaDica, autor: String) -> void:
	if not dicas_disponiveis.has(id):
		dicas_disponiveis[id] = {
			"id": id,
			"titulo_chave": titulo_chave,
			"no_dialogo": no_dialogo,
			"categoria": categoria,
			"autor": autor,
			"nao_lida": true
		}
		nova_dica_disponivel.emit(id)
		lista_dicas_atualizada.emit()


## Retorna as dicas ordenadas: NÃO LIDAS no topo, seguidas por ALERTAS e depois CONSELHOS
func obter_dicas_filtradas() -> Array:
	var lista: Array = []
	for key in dicas_disponiveis.keys():
		lista.append(dicas_disponiveis[key])

	lista.sort_custom(func(a, b):
		# 1º Critério: Não lidas vêm antes de lidas
		if a["nao_lida"] != b["nao_lida"]:
			return a["nao_lida"] # true vem antes de false
		# 2º Critério: ALERTAS (0) vêm antes de CONSELHOS (1)
		if a["categoria"] != b["categoria"]:
			return a["categoria"] < b["categoria"]
		# 3º Critério: Ordem alfabética pelo ID
		return a["id"] < b["id"]
	)
	return lista


func marcar_como_lida(id_dica: String) -> void:
	if dicas_disponiveis.has(id_dica):
		dicas_disponiveis[id_dica]["nao_lida"] = false
		lista_dicas_atualizada.emit()


func tem_dica_nao_lida() -> bool:
	for key in dicas_disponiveis.keys():
		if dicas_disponiveis[key]["nao_lida"]:
			return true
	return false
