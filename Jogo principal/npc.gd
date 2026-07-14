extends CharacterBody2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

var speed: float = 80.0
var min_wait_time: float = 1.0
var max_wait_time: float = 3.0
var is_waiting: bool = false

func _ready() -> void:
	# Configurar o agente de navegação
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	navigation_agent.avoidance_enabled = true
	
	# Começar movimento
	escolher_novo_destino()

func _physics_process(delta: float) -> void:
	if is_waiting:
		velocity = Vector2.ZERO
		return
	
	if navigation_agent.is_navigation_finished():
		comecar_espera()
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	velocity = direction * speed
	move_and_slide()

func escolher_novo_destino() -> void:
	# Pega o polígono do NavigationRegion2D pai
	var navigation_region = get_parent().get_node("NavigationRegion2D")
	
	if navigation_region and navigation_region.navigation_polygon:
		var polygon = navigation_region.navigation_polygon
		var vertices = polygon.vertices
		
		if vertices.size() > 0:
			# Gerar um ponto aleatório dentro do polígono
			var random_point = ponto_aleatorio_no_poligono(vertices)
			navigation_agent.target_position = random_point

func ponto_aleatorio_no_poligono(vertices: PackedVector2Array) -> Vector2:
	# Método simples: escolhe um triângulo aleatório do polígono
	# Para polígonos mais complexos, use triangulação
	
	if vertices.size() < 3:
		return Vector2.ZERO
	
	# Escolhe três vértices aleatórios para formar um triângulo
	var i = randi() % (vertices.size() - 2)
	var j = i + 1 + randi() % (vertices.size() - i - 2)
	var k = j + 1 + randi() % (vertices.size() - j - 1)
	
	# Ponto aleatório dentro do triângulo
	var r1 = randf()
	var r2 = randf()
	
	if r1 + r2 > 1:
		r1 = 1 - r1
		r2 = 1 - r2
	
	return vertices[i] + r1 * (vertices[j] - vertices[i]) + r2 * (vertices[k] - vertices[i])

func comecar_espera() -> void:
	is_waiting = true
	var wait_time = randf_range(min_wait_time, max_wait_time)
	await get_tree().create_timer(wait_time).timeout
	is_waiting = false
	escolher_novo_destino()
