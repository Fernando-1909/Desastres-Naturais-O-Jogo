extends Camera2D

var dragging: bool = false
var last_drag_pos: Vector2 = Vector2.ZERO

var zoom_min: float = 2.5
var zoom_max: float = 5.0
var zoom_speed: float = 0.1

# ==========================================
# LIMITES DO MAPA
# ==========================================

var limite_esquerda: float = 174.0
var limite_direita: float = 1121.0
var limite_cima: float = 79.0
var limite_baixo: float = 609.0

# Margem permitida quando estiver em zoom out
var margem_zoom_out: float = 150.0


func _ready() -> void:
	# Começa sempre no zoom mínimo
	zoom = Vector2(zoom_min, zoom_min)

	# Ajusta a posição de acordo com os limites
	limitar_camera()


func _input(event: InputEvent) -> void:

	if not enabled:
		return


	# ==========================================
	# MOUSE
	# ==========================================

	if event is InputEventMouseButton:

		# ------------------------------------------
		# BOTÃO ESQUERDO
		# ------------------------------------------

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:
				dragging = true
				last_drag_pos = event.position
			else:
				dragging = false


		# ------------------------------------------
		# ZOOM IN
		# ------------------------------------------

		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:

			var novo_zoom: Vector2 = zoom * (1.0 + zoom_speed)

			zoom = novo_zoom.clamp(
				Vector2(zoom_min, zoom_min),
				Vector2(zoom_max, zoom_max)
			)

			limitar_camera()


		# ------------------------------------------
		# ZOOM OUT
		# ------------------------------------------

		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:

			var novo_zoom: Vector2 = zoom * (1.0 - zoom_speed)

			zoom = novo_zoom.clamp(
				Vector2(zoom_min, zoom_min),
				Vector2(zoom_max, zoom_max)
			)

			limitar_camera()


	# ==========================================
	# ARRASTAR COM MOUSE
	# ==========================================

	if event is InputEventMouseMotion:

		if dragging:

			# Explicitamente Vector2
			var movimento: Vector2 = event.position - last_drag_pos

			# Move a câmera na direção contrária ao mouse
			position -= movimento / zoom

			last_drag_pos = event.position

			limitar_camera()


	# ==========================================
	# TOUCH
	# ==========================================

	if event is InputEventScreenTouch:

		if event.pressed:
			dragging = true
			last_drag_pos = event.position
		else:
			dragging = false


	# ==========================================
	# ARRASTAR COM TOUCH
	# ==========================================

	if event is InputEventScreenDrag:

		if dragging:

			var movimento_touch: Vector2 = event.relative

			position -= movimento_touch / zoom

			limitar_camera()


	# ==========================================
	# ZOOM POR GESTO
	# ==========================================

	if event is InputEventMagnifyGesture:

		var novo_zoom_gesto: Vector2 = zoom * event.factor

		zoom = novo_zoom_gesto.clamp(
			Vector2(zoom_min, zoom_min),
			Vector2(zoom_max, zoom_max)
		)

		limitar_camera()


# ==========================================
# LIMITAR CÂMERA
# ==========================================

func limitar_camera() -> void:

	var viewport_size: Vector2 = get_viewport_rect().size


	# ==========================================
	# TAMANHO VISÍVEL NO MUNDO
	# ==========================================

	var metade_largura: float = viewport_size.x / (2.0 * zoom.x)
	var metade_altura: float = viewport_size.y / (2.0 * zoom.y)


	# ==========================================
	# TAMANHO DO MAPA
	# ==========================================

	var largura_mapa: float = limite_direita - limite_esquerda
	var altura_mapa: float = limite_baixo - limite_cima


	# ==========================================
	# LIMITES HORIZONTAIS
	# ==========================================

	var limite_x_min: float
	var limite_x_max: float

	if largura_mapa >= metade_largura * 2.0:

		# O mapa é maior que a tela.
		# A câmera pode se mover normalmente
		# entre as bordas.

		limite_x_min = limite_esquerda + metade_largura
		limite_x_max = limite_direita - metade_largura

	else:

		# A câmera é maior que o mapa.
		#
		# Em vez de simplesmente travar no centro,
		# permitimos que o jogador arraste a câmera.

		var centro_x: float = (limite_esquerda + limite_direita) / 2.0

		var excesso_x: float = metade_largura - (largura_mapa / 2.0)

		limite_x_min = centro_x - excesso_x
		limite_x_max = centro_x + excesso_x


	# ==========================================
	# LIMITES VERTICAIS
	# ==========================================

	var limite_y_min: float
	var limite_y_max: float

	if altura_mapa >= metade_altura * 2.0:

		# O mapa é maior que a tela.

		limite_y_min = limite_cima + metade_altura
		limite_y_max = limite_baixo - metade_altura

	else:

		# A câmera é maior que o mapa.

		var centro_y: float = (limite_cima + limite_baixo) / 2.0

		var excesso_y: float = metade_altura - (altura_mapa / 2.0)

		limite_y_min = centro_y - excesso_y
		limite_y_max = centro_y + excesso_y


	# ==========================================
	# MARGEM DE ZOOM OUT
	# ==========================================

	# A margem só é aplicada quando zoom < 1.
	# Nunca fica negativa.

	var margem_x: float = 0.0
	var margem_y: float = 0.0

	if zoom.x < 1.0:
		margem_x = margem_zoom_out * (1.0 - zoom.x)

	if zoom.y < 1.0:
		margem_y = margem_zoom_out * (1.0 - zoom.y)


	# Aplica margem
	limite_x_min -= margem_x
	limite_x_max += margem_x

	limite_y_min -= margem_y
	limite_y_max += margem_y


	# ==========================================
	# APLICA OS LIMITES
	# ==========================================

	position.x = clamp(
		position.x,
		limite_x_min,
		limite_x_max
	)

	position.y = clamp(
		position.y,
		limite_y_min,
		limite_y_max
	)
