extends TileMapLayer

# 1. Criamos um sinal personalizado que avisa a cena principal sobre o clique
signal tile_clicado(tipo_construcao: String)


func _ready() -> void:
	pass


func _input(event: InputEvent) -> void:
	# Detecta o clique com o botão esquerdo do mouse
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		
		# Converte a posição do mouse para as coordenadas da grade (grid) do TileMap
		var grid_pos = local_to_map(to_local(mouse_pos))
		
		# Pega os dados do tile clicado nessa posição da grade
		var tile_data: TileData = get_cell_tile_data(grid_pos)
		
		# Se não clicou em nada ou se o tile não tem "clicavel" = true, ignora
		if tile_data == null or not tile_data.get_custom_data("clicavel"):
			return
		
		# Pega o texto da propriedade customizada "tipo" do Tile (ex: "prefeitura", "casa1", etc.)
		var tipo: String = tile_data.get_custom_data("tipo")
		
		# Limpa qualquer outra construção que estivesse true antes no dicionário
		_resetar_dicionario_construcoes()
		
		# Se essa construção existir no dicionário do Global, marca ela como true
		if Global.construcoes.has(tipo):
			Global.construcoes[tipo] = true
		
		# 2. Emite o sinal avisando qual tipo de tile foi clicado
		tile_clicado.emit(tipo)


# Função auxiliar para garantir que só 1 construção fique true por vez
func _resetar_dicionario_construcoes() -> void:
	for chave in Global.construcoes:
		Global.construcoes[chave] = false


# Função original do seu amigo para teste de troca de tiles
func _on_teste_troca_pressed() -> void:
	var cells = get_used_cells()
	
	for cell in cells:
		var tile_data = get_cell_tile_data(cell)
		
		if tile_data == null:
			continue
		
		var tipo = tile_data.get_custom_data("tipo")
		if tipo == "casa1":
			var source_id = get_cell_source_id(cell)
			var coord_agua = Vector2i(0, 0) # Ajuste a coordenada do atlas aqui se necessário
			
			set_cell(cell, source_id, coord_agua)
