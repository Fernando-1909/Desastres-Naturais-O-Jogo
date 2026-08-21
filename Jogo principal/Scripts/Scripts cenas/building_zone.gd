@tool
extends Area2D
class_name BuildingZone

@export_group("Visualização no Editor")
## Cor de preenchimento e borda para identificar a zona no editor
@export var cor_da_zona: Color = Color(0.2, 0.6, 1.0, 0.35):
	set(val):
		cor_da_zona = val
		queue_redraw()

## Exibe a área colorida dentro do Editor do Godot
@export var mostrar_no_editor: bool = true:
	set(val):
		mostrar_no_editor = val
		queue_redraw()

## Exibe a área colorida durante a execução do jogo (útil para testes)
@export var mostrar_no_jogo: bool = false:
	set(val):
		mostrar_no_jogo = val
		queue_redraw()

@export_group("Identificação da Zona")
@export var nome_zona: String = "Zona Residencial"
@export var tipo_zona: String = "Baixada"

@export_group("Estado e Economia")
## Se falso, o jogador precisará comprar a zona antes de construir nela
@export var desbloqueada_por_padrao: bool = true
## Custo para desbloquear esta zona durante a partida
@export var custo_desbloqueio: int = 1000
## Multiplicador de renda/impostos dos prédios construídos aqui (ex: 1.2 = +20%)
@export var multiplicador_receita: float = 1.0

@export_group("Regras de Construção")
## Categorias permitidas (ex: "Residencial", "Comercial"). Deixe vazio para todas.
@export var categorias_permitidas: Array[String] = []
## Lista específica de BuildingData liberados nesta zona
@export var edificios_permitidos: Array[BuildingData] = []
## Limite de prédios nesta zona (0 = sem limite)
@export var limite_maximo_edificios: int = 5

@export_group("Impacto Ambiental e Desastres")
## Multiplicador de dano de enchente (ex: 2.0 = dobro de dano, 0.0 = imune)
@export var multiplicador_dano_enchente: float = 1.0


func _ready() -> void:
	add_to_group("zonas_construcao")
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint() and not mostrar_no_editor:
		return
	if not Engine.is_editor_hint() and not mostrar_no_jogo:
		return

	var collision_node = _obter_collision_child()
	if collision_node and collision_node.shape:
		if collision_node.shape is RectangleShape2D:
			var rect_shape = collision_node.shape as RectangleShape2D
			var rect = Rect2(-rect_shape.size / 2.0, rect_shape.size)
			# Desenha o preenchimento translúcido
			draw_rect(rect, cor_da_zona, true)
			# Desenha a borda sólida
			draw_rect(rect, Color(cor_da_zona.r, cor_da_zona.g, cor_da_zona.b, 1.0), false, 2.0)


func _obter_collision_child() -> CollisionShape2D:
	for child in get_children():
		if child is CollisionShape2D:
			return child
	return null


## Verifica se uma posição global está dentro dos limites desta zona
func contem_posicao_global(pos_global: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos_global
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var resultados = space_state.intersect_point(query)
	for res in resultados:
		if res.collider == self:
			return true
	return false


## Valida se o prédio atende às regras da zona
func pode_construir(b_data: BuildingData) -> bool:
	if b_data == null:
		return false

	if edificios_permitidos.size() > 0:
		return edificios_permitidos.has(b_data)

	if categorias_permitidas.size() > 0:
		var cat_bdata = ""
		if "categoria" in b_data and b_data.categoria != null:
			cat_bdata = str(b_data.categoria).strip_edges().to_lower()
		
		for cat in categorias_permitidas:
			if cat.strip_edges().to_lower() == cat_bdata:
				return true
		return false

	return true


func tem_vaga_disponivel(total_construcoes_atuais: int) -> bool:
	if limite_maximo_edificios <= 0:
		return true
	return total_construcoes_atuais < limite_maximo_edificios


## Retorna o multiplicador de dano aplicado por desastres nesta zona
func obter_multiplicador_dano() -> float:
	return multiplicador_dano_enchente
