class_name BuildingInstance
extends RefCounted

var data: BuildingData         # Referência ao molde (Resource)
var posicao_tile: Vector2i     # Coordenada no TileMap (ex: Vector2i(10, 5))
var nivel_atual: int = 1       # Nível atual desta instância
var durabilidade_atual: float  # Vida atual desta construção específica
var moradores_desabrigados: bool = false  # true depois que os moradores desta casa já foram contados como desabrigados

# Controle do estado de obra por turnos
var em_construcao: bool = false
var turnos_restantes: int = 0

# Construtor da instância
func _init(p_data: BuildingData, p_posicao: Vector2i) -> void:
	data = p_data
	posicao_tile = p_posicao
	nivel_atual = 1
	durabilidade_atual = p_data.durabilidade_maxima
	em_construcao = false
	turnos_restantes = 0

# Calcula porcentagem de durabilidade (0.0 a 100.0)
func get_durabilidade_pct() -> float:
	if data.durabilidade_maxima <= 0: return 100.0
	return (durabilidade_atual / data.durabilidade_maxima) * 100.0

# Calcula o custo do próximo upgrade (dinheiro)
func get_custo_upgrade() -> float:
	return data.custo_base * (data.multiplicador_custo_upgrade ** nivel_atual)

# Calcula os ganhos atuais baseados no nível e tipo de construção
func get_ganhos_atuais() -> float:
	if not data:
		return 0.0

	# 1. Se o prédio tem ganhos diretos definidos no .tres (ex: comércios/indústrias)
	if data.ganhos_base > 0.0:
		return data.ganhos_base * float(nivel_atual)

	# 2. Se for residencial/gerar população, calcula a arrecadação base de tributos
	var cat_lower = str(data.categoria).to_lower().strip_edges() if "categoria" in data and data.categoria != null else ""
	var id_lower = str(data.id).to_lower().strip_edges() if "id" in data and data.id != null else ""

	if cat_lower == "residencial" or "casa" in id_lower or "residenc" in id_lower or data.bonus_populacao > 0:
		var moradores_totais = float(data.bonus_populacao) * float(nivel_atual)
		return moradores_totais / 10.0

	return 0.0
