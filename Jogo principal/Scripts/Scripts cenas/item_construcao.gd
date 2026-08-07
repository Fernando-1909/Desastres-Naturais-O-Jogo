extends Button
class_name ItemConstrucao

signal card_selecionado(building_data: BuildingData, variacao_index: int)

var data: BuildingData
var variacao_index: int = 0

func _ready() -> void:
	pressed.connect(_on_pressed)
	_atualizar_ui()

func configurar_card(p_data: BuildingData, p_variacao_index: int = 0) -> void:
	data = p_data
	variacao_index = p_variacao_index
	_atualizar_ui()

func _atualizar_ui() -> void:
	if not data:
		return

	# 1. Busca o nó da imagem dinamicamente na cena do card
	var node_icone: TextureRect = find_child("Icone", true, false) as TextureRect
	
	# Fallback: Se não achar um nó chamado "Icone", pega o primeiro TextureRect no card
	if node_icone == null:
		var rects = find_children("", "TextureRect", true, false)
		if rects.size() > 0:
			node_icone = rects[0] as TextureRect

	# 2. Obtém a textura da variação ou ícone padrão
	var tex: Texture2D = null
	if data.has_method("get_icone_variacao"):
		tex = data.get_icone_variacao(variacao_index)
	elif "icone" in data:
		tex = data.icone

	# 3. Aplica a textura no botão/ícone
	if node_icone and tex:
		node_icone.texture = tex

func _on_pressed() -> void:
	if data:
		card_selecionado.emit(data, variacao_index)
