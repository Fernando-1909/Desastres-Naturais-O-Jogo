extends TileMapLayer

func _ready() -> void:
	pass
	
func _unhandled_input(event: InputEvent) -> void:
	# Verifica se é clique esquerdo do mouse
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		#print("Clique detectado")  # Debug: ver se o clique está sendo registrado
		
		# Converte posição do mouse
		var mouse_pos_local = to_local(event.global_position)
		var grid_pos = local_to_map(mouse_pos_local)
		
		#print("Posição do grid: ", grid_pos)  # Debug: mostra coordenadas
		
		# Verifica se existe tile na posição DEBUG
		# var source_id = get_cell_source_id(grid_pos)
		# print("Source ID: ", source_id)  # Mostra o ID da fonte
		# print("Atlas coords: ", get_cell_atlas_coords(grid_pos)) 
		
		# Tenta pegar os dados customizados
		var tile_data: TileData = get_cell_tile_data(grid_pos)
		
		if tile_data == null:
			print("✗ tile_data é null")
			return
		
		# Verifica a propriedade customizada
		var is_clicavel = tile_data.get_custom_data("clicavel")
		print("Valor de 'clicavel': ", is_clicavel)  # Debug: mostra o valor
		
		if is_clicavel == true:
			print("Tile clicado") 
		else:
			print("✗ Tile não é clicável")
