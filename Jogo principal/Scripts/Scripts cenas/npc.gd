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
	# Desligado de propósito: assim os NPCs não ficam se desviando uns dos
	# outros (podem se atravessar livremente, como pedido).
	navigation_agent.avoidance_enabled = false
	
	# Colisão física: colide com construções, mas NÃO com outros NPCs.
	# Camada 2 = "sou um NPC" | Máscara 1 = "só colido com a camada 1"
	# (ajuste esses números se o seu projeto usar camadas diferentes pras
	# construções/obstáculos no TileMap).
	collision_layer = 2
	collision_mask = 1
	
	# Nasce dentro da zona de navegação, em vez de na origem do container
	_posicionar_dentro_da_zona()
	
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

## Sorteia um ponto dentro do polígono da NavigationRegion2D (irmã do NPC,
## filha do mesmo container) e usa ele como posição inicial — assim o NPC já
## nasce dentro da zona andável, em vez de nascer na origem do container.
func _posicionar_dentro_da_zona() -> void:
	var navigation_region = get_parent().get_node_or_null("NavigationRegion2D")
	if not navigation_region or not navigation_region.navigation_polygon:
		push_warning("Npc: NavigationRegion2D (ou o polígono dele) não encontrado — não foi possível posicionar dentro da zona.")
		return
	
	var vertices = navigation_region.navigation_polygon.vertices
	if vertices.size() < 3:
		return
	
	var ponto_local = ponto_aleatorio_no_poligono(vertices)
	global_position = navigation_region.to_global(ponto_local)

func escolher_novo_destino() -> void:
	# Pega o polígono do NavigationRegion2D pai
	var navigation_region = get_parent().get_node_or_null("NavigationRegion2D")
	
	if navigation_region and navigation_region.navigation_polygon:
		var polygon = navigation_region.navigation_polygon
		var vertices = polygon.vertices
		
		if vertices.size() > 0:
			# O ponto sorteado está em espaço LOCAL do NavigationRegion2D —
			# precisa converter pra GLOBAL antes de usar como destino, senão
			# o NPC mira num ponto deslocado sempre que a região não estiver
			# exatamente na origem (0,0) do mundo.
			var random_point_local = ponto_aleatorio_no_poligono(vertices)
			navigation_agent.target_position = navigation_region.to_global(random_point_local)

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
