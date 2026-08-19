class_name BuildingInstance
extends RefCounted

var data: BuildingData         # Referência ao molde (Resource)
var posicao_tile: Vector2i     # Coordenada no TileMap (ex: Vector2i(10, 5))
var nivel_atual: int = 1       # Nível atual desta instância
var durabilidade_atual: float  # Vida atual desta construção específica

# Construtor da instância
func _init(p_data: BuildingData, p_posicao: Vector2i) -> void:
	data = p_data
	posicao_tile = p_posicao
	nivel_atual = 1
	durabilidade_atual = p_data.durabilidade_maxima

# Calcula porcentagem de durabilidade (0.0 a 100.0)
func get_durabilidade_pct() -> float:
	if data.durabilidade_maxima <= 0: return 100.0
	return (durabilidade_atual / data.durabilidade_maxima) * 100.0

# Calcula o custo do próximo upgrade (dinheiro)
func get_custo_upgrade() -> float:
	return data.custo_base * (data.multiplicador_custo_upgrade ** nivel_atual)

# Calcula o custo do próximo upgrade (pedra)
func get_custo_upgrade_pedra() -> float:
	return data.custo_pedra * (data.multiplicador_custo_upgrade ** nivel_atual)

# Calcula o custo do próximo upgrade (madeira)
func get_custo_upgrade_madeira() -> float:
	return data.custo_madeira * (data.multiplicador_custo_upgrade ** nivel_atual)

# Calcula os ganhos atuais baseados no nível
func get_ganhos_atuais() -> float:
	return data.ganhos_base * nivel_atual
