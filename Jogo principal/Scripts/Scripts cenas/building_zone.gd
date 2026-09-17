@tool
extends Area2D
class_name BuildingZone

@export_group("Visualização no Editor")
## Cor de preenchimento e borda para identificar a zona no editor
@export var cor_da_zona: Color = Color(0.2, 0.6, 1.0, 0.35):
	set(val):
		cor_da_zona = val
		queue_redraw()

@export var tempo_resgate: int = 1

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
## Identificador para agrupar áreas duplicadas (ex: "rio", "residencial"). Se deixado em branco, o 'nome_zona' será usado.
@export var id_grupo: String = ""

@export_group("Estado e Economia")
## Se falso, o jogador precisará comprar/liberar a zona antes de construir nela
@export var desbloqueada_por_padrao: bool = true
## ID do edifício necessário para liberar esta zona (ex: "estacao_tratamento", "bombeiros")
@export var edificio_requisito_id: String = ""
## Mantido para compatibilidade prévia
@export var precisa_estacao_tratamento: bool = false
## Nó pai que agrupa os sprites de terreno vazio desta zona
@export var container_terrenos_vazios: Node2D
## Custo para desbloquear esta zona durante a partida
@export var custo_desbloqueio: int = 1000
## Multiplicador de renda/impostos dos prédios construídos aqui
@export var multiplicador_receita: float = 1.0

@export_group("Regras de Construção")
## Categorias permitidas (ex: "Residencial", "Comercial"). Deixe vazio para todas.
@export var categorias_permitidas: Array[String] = []
## Lista específica de BuildingData liberados nesta zona
@export var edificios_permitidos: Array[BuildingData] = []
## Limite de prédios nesta zona (0 = sem limite)
@export var limite_maximo_edificios: int = 5

@export_group("Impacto Ambiental e Desastres")
## Multiplicador de dano de enchente
@export var multiplicador_dano_enchente: float = 1.0

var desbloqueada: bool = true


func _ready() -> void:
	add_to_group("zonas_construcao")
	
	if not Engine.is_editor_hint():
		# Se tiver qualquer requisito cadastrado ou for marcada para iniciar bloqueada
		var tem_requisito = precisa_estacao_tratamento or edificio_requisito_id.strip_edges() != "" or not desbloqueada_por_padrao
		if tem_requisito:
			desbloqueada = false
			definir_visibilidade_terrenos(false)
		else:
			desbloqueada = true
			definir_visibilidade_terrenos(true)

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
			draw_rect(rect, cor_da_zona, true)
			draw_rect(rect, Color(cor_da_zona.r, cor_da_zona.g, cor_da_zona.b, 1.0), false, 2.0)


func _obter_collision_child() -> CollisionShape2D:
	for child in get_children():
		if child is CollisionShape2D:
			return child
	return null


func definir_visibilidade_terrenos(visivel: bool) -> void:
	if container_terrenos_vazios:
		container_terrenos_vazios.visible = visivel


## Desbloqueia esta zona e todas as zonas pertencentes ao mesmo grupo
func desbloquear_zona() -> void:
	for zona in obter_todas_zonas_do_grupo():
		zona.desbloqueada = true
		zona.definir_visibilidade_terrenos(true)
	print("[ZONA] Grupo de zonas '", obter_id_grupo(), "' foi liberado para construção!")


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


func pode_construir(b_data: BuildingData) -> bool:
	if not desbloqueada:
		return false
	if b_data == null:
		return false
	
	var id_p = str(b_data.id).to_lower().strip_edges() if "id" in b_data and b_data.id != null else ""
	var cat_p = str(b_data.categoria).to_lower().strip_edges() if "categoria" in b_data and b_data.categoria != null else ""
	
	if edificios_permitidos.size() > 0:
		for ed in edificios_permitidos:
			if ed and ed.id.to_lower().strip_edges() == id_p:
				return true
		return false
	
	if categorias_permitidas.size() > 0:
		var permitida = false
		for cat in categorias_permitidas:
			if cat.to_lower().strip_edges() == cat_p:
				permitida = true
				break
		if not permitida:
			return false
	
	return true


func obter_id_grupo() -> String:
	if id_grupo.strip_edges() != "":
		return id_grupo.strip_edges().to_lower()
	return nome_zona.strip_edges().to_lower()


func pertence_ao_mesmo_grupo(outra_zona: BuildingZone) -> bool:
	if outra_zona == null:
		return false
	return self.obter_id_grupo() == outra_zona.obter_id_grupo()


func obter_todas_zonas_do_grupo() -> Array[BuildingZone]:
	var resultado: Array[BuildingZone] = []
	var todas_zonas = get_tree().get_nodes_in_group("zonas_construcao")
	var meu_id = obter_id_grupo()
	
	for z in todas_zonas:
		if z is BuildingZone and z.obter_id_grupo() == meu_id:
			resultado.append(z)
			
	return resultado


func contem_posicao_global_no_grupo(pos_global: Vector2) -> bool:
	var grupo = obter_id_grupo()
	var zonas = get_tree().get_nodes_in_group("zonas_construcao")
	for z in zonas:
		if z is BuildingZone and z.obter_id_grupo() == grupo and z.contem_posicao_global(pos_global):
			return true
	return false


func tem_vaga_disponivel(total_construcoes_atuais: int) -> bool:
	if limite_maximo_edificios <= 0:
		return true
	return total_construcoes_atuais < limite_maximo_edificios


func obter_multiplicador_dano() -> float:
	return multiplicador_dano_enchente


## Verifica se uma determinada palavra-chave/ID está entre os edifícios ou categorias permitidas da zona
func edificios_permitidos_contem(termo: String) -> bool:
	var termo_limpo = termo.to_lower().strip_edges()
	
	if "edificios_permitidos" in self and edificios_permitidos is Array:
		for item in edificios_permitidos:
			if termo_limpo in str(item).to_lower():
				return true
				
	if "categorias_permitidas" in self and categorias_permitidas is Array:
		for item in categorias_permitidas:
			if termo_limpo in str(item).to_lower():
				return true
				
	return false
