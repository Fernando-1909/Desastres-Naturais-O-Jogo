extends Camera2D

var dragging := false
var last_drag_pos := Vector2.ZERO

var zoom_min = 0.9
var zoom_max = 3.0
var zoom_speed = 0.1

# Limites do mapa
var limite_esquerda := 174.0
var limite_direita := 1121.0
var limite_cima := 79.0
var limite_baixo := 609.0

# Quanto pode ultrapassar os limites durante o zoom out
var margem_zoom_out := 150.0


func _ready() -> void:
	limitar_camera()


func _input(event):
	if not enabled:
		return
	
	# ==========================================
	# ARRASTAR COM MOUSE
	# ==========================================
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				last_drag_pos = event.position
			else:
				dragging = false
		
		# Zoom com roda do mouse
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				var new_zoom = zoom * (1.0 + zoom_speed)
				
				zoom = clamp(
					new_zoom,
					Vector2(zoom_min, zoom_min),
					Vector2(zoom_max, zoom_max)
				)
				
				limitar_camera()
			
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var new_zoom = zoom * (1.0 - zoom_speed)
				
				zoom = clamp(
					new_zoom,
					Vector2(zoom_min, zoom_min),
					Vector2(zoom_max, zoom_max)
				)
				
				limitar_camera()
	
	
	# ==========================================
	# MOVIMENTO COM MOUSE ARRASTANDO
	# ==========================================
	if event is InputEventMouseMotion:
		if dragging:
			var movimento = event.position - last_drag_pos
			
			# Move a câmera na direção contrária ao mouse,
			# criando o efeito de "arrastar o mapa".
			position -= movimento / zoom
			
			last_drag_pos = event.position
			
			limitar_camera()
	
	
	# ==========================================
	# TOUCH / CELULAR
	# ==========================================
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			last_drag_pos = event.position
		else:
			dragging = false
	
	
	if event is InputEventScreenDrag:
		if dragging:
			position -= event.relative / zoom
			limitar_camera()
	
	
	# ==========================================
	# ZOOM POR GESTO
	# ==========================================
	if event is InputEventMagnifyGesture:
		var new_zoom = zoom * event.factor
		
		zoom = clamp(
			new_zoom,
			Vector2(zoom_min, zoom_min),
			Vector2(zoom_max, zoom_max)
		)
		
		limitar_camera()


func _process(_delta: float) -> void:
	if enabled:
		limitar_camera()


func limitar_camera() -> void:
	var viewport_size = get_viewport_rect().size
	
	# Área do mundo que a câmera consegue enxergar.
	var metade_largura = viewport_size.x / (2.0 * zoom.x)
	var metade_altura = viewport_size.y / (2.0 * zoom.y)
	
	# Limites considerando o tamanho da área visível.
	var esquerda = limite_esquerda + metade_largura
	var direita = limite_direita - metade_largura
	
	var cima = limite_cima + metade_altura
	var baixo = limite_baixo - metade_altura
	
	
	# ==========================================
	# LIMITE HORIZONTAL
	# ==========================================
	if esquerda > direita:
		# A tela é maior que o mapa.
		# Mantém a câmera centralizada.
		position.x = (limite_esquerda + limite_direita) / 2.0
	else:
		# Pequena margem adicional no zoom out.
		var margem_x = margem_zoom_out * (1.0 - zoom.x)
		
		var limite_x_min = esquerda - margem_x
		var limite_x_max = direita + margem_x
		
		position.x = clamp(
			position.x,
			limite_x_min,
			limite_x_max
		)
	
	
	# ==========================================
	# LIMITE VERTICAL
	# ==========================================
	if cima > baixo:
		# A tela é maior que o mapa.
		# Mantém a câmera centralizada.
		position.y = (limite_cima + limite_baixo) / 2.0
	else:
		# Pequena margem adicional no zoom out.
		var margem_y = margem_zoom_out * (1.0 - zoom.y)
		
		var limite_y_min = cima - margem_y
		var limite_y_max = baixo + margem_y
		
		position.y = clamp(
			position.y,
			limite_y_min,
			limite_y_max
		)
