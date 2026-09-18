extends CharacterBody2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var speed: float = 80.0
var min_wait_time: float = 1.0
var max_wait_time: float = 3.0
var is_waiting: bool = false

# ============================================================
# ENCHENTE - HARD CODED
# ============================================================

# NPCs somem no turno 8, um turno antes da enchente (turno 9).
const TURNO_SUMIR_NPCS: int = 9

# A enchente dura 7 turnos a partir do turno 9.
# Portanto termina no turno 16.
const TURNO_VOLTA_NPCS: int = 14

var escondido_enchente: bool = false
var npcs_ja_voltaram: bool = false


func _ready() -> void:
	add_to_group("npcs")

	# Configurar o agente de navegação
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	
	# Desligado de propósito: assim os NPCs não ficam se desviando uns dos
	# outros (podem se atravessar livremente).
	navigation_agent.avoidance_enabled = false
	
	# Colisão física: colide com construções, mas NÃO com outros NPCs.
	collision_layer = 2
	collision_mask = 1
	
	# Começa parado.
	animated_sprite.play("default")
	
	# Nasce dentro da zona de navegação.
	_posicionar_dentro_da_zona()
	
	# Verifica imediatamente o turno atual.
	_verificar_turno_hardcoded()
	
	# Começar movimento somente se estiver visível.
	if not escondido_enchente:
		escolher_novo_destino()


func _process(_delta: float) -> void:
	# Controle HARD CODED pelo número do turno.
	_verificar_turno_hardcoded()


func _verificar_turno_hardcoded() -> void:
	var turno_atual: int = Global.turno
	
	# ========================================================
	# TURNO 8 -> NPCS SOMEM
	# ========================================================
	if turno_atual >= TURNO_SUMIR_NPCS and turno_atual < TURNO_VOLTA_NPCS:
		if not escondido_enchente:
			_esconder_durante_enchente()
	
	# ========================================================
	# TURNO 16 -> NPCS VOLTAM
	# ========================================================
	elif turno_atual >= TURNO_VOLTA_NPCS:
		if escondido_enchente and not npcs_ja_voltaram:
			npcs_ja_voltaram = true
			mostrar_depois_da_enchente()


func _physics_process(_delta: float) -> void:
	# Durante a enchente, o NPC fica completamente parado e invisível.
	if escondido_enchente:
		velocity = Vector2.ZERO
		return

	if is_waiting:
		velocity = Vector2.ZERO
		animated_sprite.play("default")
		return
	
	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		animated_sprite.play("default")
		comecar_espera()
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var direction = global_position.direction_to(next_position)
	
	velocity = direction * speed
	move_and_slide()
	
	if velocity.length() > 0.1:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("default")


func _esconder_durante_enchente() -> void:
	escondido_enchente = true
	is_waiting = false
	velocity = Vector2.ZERO
	
	# Invisível
	visible = false
	
	# Sem colisão
	collision_layer = 0
	collision_mask = 0


func mostrar_depois_da_enchente() -> void:
	escondido_enchente = false
	
	# Visível novamente
	visible = true
	
	# Restaura colisões
	collision_layer = 2
	collision_mask = 1
	
	# Escolhe novo destino
	escolher_novo_destino()


## Sorteia um ponto dentro do polígono da NavigationRegion2D.
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
	var navigation_region = get_parent().get_node_or_null("NavigationRegion2D")
	
	if navigation_region and navigation_region.navigation_polygon:
		var polygon = navigation_region.navigation_polygon
		var vertices = polygon.vertices
		
		if vertices.size() > 0:
			var random_point_local = ponto_aleatorio_no_poligono(vertices)
			navigation_agent.target_position = navigation_region.to_global(random_point_local)


func ponto_aleatorio_no_poligono(vertices: PackedVector2Array) -> Vector2:
	if vertices.size() < 3:
		return Vector2.ZERO
	
	var i = randi() % (vertices.size() - 2)
	var j = i + 1 + randi() % (vertices.size() - i - 2)
	var k = j + 1 + randi() % (vertices.size() - j - 1)
	
	var r1 = randf()
	var r2 = randf()
	
	if r1 + r2 > 1:
		r1 = 1 - r1
		r2 = 1 - r2
	
	return vertices[i] \
		+ r1 * (vertices[j] - vertices[i]) \
		+ r2 * (vertices[k] - vertices[i])


func comecar_espera() -> void:
	is_waiting = true
	
	var wait_time = randf_range(min_wait_time, max_wait_time)
	
	await get_tree().create_timer(wait_time).timeout
	
	# Se estiver escondido, não volta a andar.
	if escondido_enchente:
		return

	is_waiting = false
	escolher_novo_destino()
