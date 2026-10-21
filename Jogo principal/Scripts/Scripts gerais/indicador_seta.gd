class_name IndicadorSeta
extends Node2D

## Cor de preenchimento da seta (Amarelo)
@export var cor_preenchimento: Color = Color(1.0, 0.85, 0.0, 1.0)
## Cor do contorno da seta (Preto)
@export var cor_contorno: Color = Color(0.0, 0.0, 0.0, 1.0)
## Espessura da linha do contorno
@export var largura_contorno: float = 2.0
## Distância em pixels da borda da tela quando o alvo estiver fora da câmera
@export var margem_borda: float = 40.0

var pos_tile: Vector2i = Vector2i(-1, -1)
var zona_ref: Node = null

var _tempo: float = 0.0
var _pos_base_global: Vector2 = Vector2.ZERO
var _sendo_removido: bool = false

# Polígono da seta apontando para BAIXO por padrão (Ponta da seta na origem Vector2(0,0))
var pontos_seta: PackedVector2Array = PackedVector2Array([
	Vector2(-5, -30),   # Canto superior esquerdo da haste
	Vector2(5, -30),    # Canto superior direito da haste
	Vector2(5, -14),    # Junção direita haste/cabeça
	Vector2(13, -14),   # Ponta extrema direita da cabeça
	Vector2(0, 0),      # Ponta da seta (ponto de ancoragem)
	Vector2(-13, -14),  # Ponta extrema esquerda da cabeça
	Vector2(-5, -14)    # Junção esquerda haste/cabeça
])

func _ready() -> void:
	# Garantimos um z_index alto para que o indicador de borda fique visível sobre tudo
	z_index = 100
	queue_redraw()

func inicializar(p_pos_tile: Vector2i, p_pos_global: Vector2, p_zona: Node = null) -> void:
	pos_tile = p_pos_tile
	_pos_base_global = p_pos_global
	_pos_base_global.y -= 10.0
	global_position = _pos_base_global
	zona_ref = p_zona

func _process(delta: float) -> void:
	if _sendo_removido:
		return
	
	_tempo += delta * 3.5
	_atualizar_posicao_e_rotacao()

## Calcula a posição da seta no mapa ou prende na borda da tela caso esteja fora da câmera
func _atualizar_posicao_e_rotacao() -> void:
	var canvas_transform = get_canvas_transform()
	var viewport_rect = get_viewport_rect()
	
	# Posição exata do alvo convertida para coordenadas de tela (pixels do monitor)
	var pos_alvo_tela = canvas_transform * _pos_base_global
	
	# Limites da área visível da tela respeitando a margem configurada
	var min_x = viewport_rect.position.x + margem_borda
	var max_x = viewport_rect.size.x - margem_borda
	var min_y = viewport_rect.position.y + margem_borda
	var max_y = viewport_rect.size.y - margem_borda
	
	# Checa se a zona está dentro do campo de visão da câmera
	var esta_na_tela = (
		pos_alvo_tela.x >= min_x and pos_alvo_tela.x <= max_x and
		pos_alvo_tela.y >= min_y and pos_alvo_tela.y <= max_y
	)
	
	if esta_na_tela:
		# MODO 1: Dentro da Tela -> Flutua suavemente sobre o tile apontando para baixo
		global_position = _pos_base_global + Vector2(0.0, sin(_tempo) * 5.0)
		rotation = 0.0
	else:
		# MODO 2: Fora da Tela -> Trava na borda e rotaciona apontando para o alvo
		var pos_borda_tela = Vector2(
			clamp(pos_alvo_tela.x, min_x, max_x),
			clamp(pos_alvo_tela.y, min_y, max_y)
		)
		
		# Converte a posição da borda da tela de volta para coordenadas do mundo
		global_position = canvas_transform.affine_inverse() * pos_borda_tela
		
		# Rotaciona a seta na direção exata do alvo fora da tela
		var vetor_direcao = pos_alvo_tela - pos_borda_tela
		if vetor_direcao.length_squared() > 0.0:
			# Subtrai 90° (PI/2) porque o desenho original do polígono aponta para baixo
			rotation = vetor_direcao.angle() - (PI / 2.0)

func _draw() -> void:
	draw_colored_polygon(pontos_seta, cor_preenchimento)
	
	var pontos_fechados = pontos_seta.duplicate()
	pontos_fechados.append(pontos_seta[0])
	draw_polyline(pontos_fechados, cor_contorno, largura_contorno, true)

func desaparecer() -> void:
	if _sendo_removido:
		return
	_sendo_removido = true
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
