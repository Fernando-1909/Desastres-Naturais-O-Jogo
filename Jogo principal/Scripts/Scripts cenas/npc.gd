extends CharacterBody2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var speed: float = 80.0
var min_wait_time: float = 1.0
var max_wait_time: float = 3.0
var is_waiting: bool = false

# Fica invisível e parado enquanto a enchente estiver ativa.
var escondido_enchente: bool = false


func _ready() -> void:
	add_to_group("npcs")

	# Configurar o agente de navegação
	navigation_agent.path_desired_distance = 4.0
	navigation_agent.target_desired_distance = 4.0
	
	# Desligado de propósito: assim os NPCs não ficam se desviando uns dos
	# outros (podem se atravessar livremente).
	navigation_agent.avoidance_enabled = false
	
	# Colisão física: colide com construções, mas NÃO com outros NPCs.
	# Camada 2 = "sou um NPC" | Máscara 1 = "só colido com a camada 1"
	collision_layer = 2
	collision_mask = 1
	
	# Começa parado.
	animated_sprite.play("default")
	
	# Nasce dentro da zona de navegação.
	_posicionar_dentro_da_zona()
	
	# Conectar aos eventos da enchente.
	_conectar_a_enchente()

	# Começar movimento
	if not escondido_enchente:
		escolher_novo_destino()


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
	
	# Se estiver se movimentando, toca "walk".
	# Caso contrário, toca "default".
	if velocity.length() > 0.1:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("default")


func _conectar_a_enchente() -> void:
	var enchente = get_tree().get_first_node_in_group("enchente")
	
	if enchente == null:
		enchente = get_tree().current_scene.find_child("Enchente", true, false)

	if enchente == null:
		return

	# Conecta ao início da enchente.
	if enchente.has_signal("enchente_iniciada"):
		if not enchente.enchente_iniciada.is_connected(_on_enchente_iniciada):
			enchente.enchente_iniciada.connect(_on_enchente_iniciada)

	# Conecta ao fim da enchente.
	if enchente.has_signal("enchente_terminada"):
		if not enchente.enchente_terminada.is_connected(_on_enchente_terminada):
			enchente.enchente_terminada.connect(_on_enchente_terminada)

	# Caso o NPC seja criado depois que a enchente já começou,
	# verifica o estado atual diretamente.
	if enchente.get("enchente_ativa") == true:
		_esconder_durante_enchente()


func _on_enchente_iniciada(_area: Rect2, _dano: float) -> void:
	_esconder_durante_enchente()


func _esconder_durante_enchente() -> void:
	escondido_enchente = true
	is_waiting = false
	velocity = Vector2.ZERO
	
	# Torna o NPC invisível.
	visible = false
	
	# Desativa colisões enquanto estiver escondido.
	collision_layer = 0
	collision_mask = 0


func _on_enchente_terminada() -> void:
	# Somente um NPC coordena o reaparecimento gradual,
	# evitando que todos iniciem a mesma rotina ao mesmo tempo.
	var npcs = get_tree().get_nodes_in_group("npcs")
	
	if npcs.is_empty():
		return
	
	if npcs[0] != self:
		return
	
	_reaparecer_npcs_aos_poucos(npcs)


func _reaparecer_npcs_aos_poucos(npcs: Array) -> void:
	var metade: int = ceili(npcs.size() / 2.0)

	# Primeiro aparece metade dos NPCs.
	for i in range(metade):
		if is_instance_valid(npcs[i]):
			if npcs[i].has_method("mostrar_depois_da_enchente"):
				npcs[i].mostrar_depois_da_enchente()

	# Espera 2 segundos antes de mostrar o restante.
	await get_tree().create_timer(2.0).timeout

	# Depois aparece a outra metade.
	for i in range(metade, npcs.size()):
		if is_instance_valid(npcs[i]):
			if npcs[i].has_method("mostrar_depois_da_enchente"):
				npcs[i].mostrar_depois_da_enchente()


func mostrar_depois_da_enchente() -> void:
	escondido_enchente = false
	
	# Torna o NPC visível novamente.
	visible = true
	
	# Restaura as colisões originais.
	collision_layer = 2
	collision_mask = 1
	
	# Escolhe um novo destino para voltar a andar.
	escolher_novo_destino()


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
			# O ponto sorteado está em espaço LOCAL do NavigationRegion2D.
			# Precisa converter para GLOBAL antes de usar como destino.
			var random_point_local = ponto_aleatorio_no_poligono(vertices)
			navigation_agent.target_position = navigation_region.to_global(random_point_local)


func ponto_aleatorio_no_poligono(vertices: PackedVector2Array) -> Vector2:
	# Método simples: escolhe um triângulo aleatório do polígono.
	
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
	
	return vertices[i] \
		+ r1 * (vertices[j] - vertices[i]) \
		+ r2 * (vertices[k] - vertices[i])


func comecar_espera() -> void:
	is_waiting = true
	
	var wait_time = randf_range(min_wait_time, max_wait_time)
	
	await get_tree().create_timer(wait_time).timeout
	
	# Se a enchente começou enquanto o NPC estava esperando,
	# não volta a andar.
	if escondido_enchente:
		return

	is_waiting = false
	escolher_novo_destino()
