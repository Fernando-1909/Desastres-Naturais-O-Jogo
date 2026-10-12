class_name IndicadorSeta
extends Node2D

## Cor de preenchimento da seta (Amarelo)
@export var cor_preenchimento: Color = Color(1.0, 0.85, 0.0, 1.0)
## Cor do contorno da seta (Preto)
@export var cor_contorno: Color = Color(0.0, 0.0, 0.0, 1.0)
## Espessura da linha do contorno (Reduzida para um visual mais fino)
@export var largura_contorno: float = 2.0

var pos_tile: Vector2i = Vector2i(-1, -1)
var zona_ref: Node = null

var _tempo: float = 0.0
var _pos_base_y: float = 0.0
var _sendo_removido: bool = false

# Polígono da seta reduzido e mais estreito
var pontos_seta: PackedVector2Array = PackedVector2Array([
	Vector2(-5, -30),   # Canto superior esquerdo da haste
	Vector2(5, -30),    # Canto superior direito da haste
	Vector2(5, -14),    # Junção direita haste/cabeça
	Vector2(13, -14),   # Ponta extrema direita da cabeça
	Vector2(0, 0),      # Ponta da seta
	Vector2(-13, -14),  # Ponta extrema esquerda da cabeça
	Vector2(-5, -14)    # Junção esquerda haste/cabeça
])

func _ready() -> void:
	z_index = 15
	_pos_base_y = position.y
	queue_redraw()

func inicializar(p_pos_tile: Vector2i, p_pos_global: Vector2, p_zona: Node = null) -> void:
	pos_tile = p_pos_tile
	global_position = p_pos_global
	global_position.y -= 10.0
	_pos_base_y = global_position.y
	zona_ref = p_zona

func _process(delta: float) -> void:
	if _sendo_removido:
		return
	
	# Flutuação mais suave ajustada ao novo tamanho
	_tempo += delta * 3.5
	global_position.y = _pos_base_y + sin(_tempo) * 5.0

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
