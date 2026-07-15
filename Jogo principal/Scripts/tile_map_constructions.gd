extends TileMapLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		
		# Converte para coordenadas locais considerando a posicao do node
		var grid_pos = local_to_map(to_local(mouse_pos))
		
		var tile_data: TileData = get_cell_tile_data(grid_pos)
		
		if tile_data == null or not tile_data.get_custom_data("clicavel"):
			return
		
		var tipo: String = tile_data.get_custom_data("tipo")
		
		if tipo == "prefeitura":
			print("prefeitura clicada")
			Global.construcoes["prefeitura"] = true
			
		elif tipo == "casa1":
			print("casa1 clicada")
			Global.construcoes["casa1"] = true
