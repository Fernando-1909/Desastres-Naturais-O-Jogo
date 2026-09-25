extends Node2D


@onready var dialogue_manager = $DialogueManager
@onready var tutorial_tile: TextureRect = $TutorialUI/TutorialTile


const TILES := {
	"prefeitura": "res://Jogo principal/tilesheets/Prefeituras.png",
	"casa": "res://Jogo principal/tilesheets/casa_level_1.png",
	"terreno_construcao": "res://Jogo principal/tilesheets/Terreno_construcao.png",

	# Imagem de alerta de desastre (arquivo próprio, não é spritesheet)
	"alerta": "res://Jogo principal/UI/Assets/alerta.png",

	# ---------------------------------------------------------------
	# ATENÇÃO: allmenusprites.png é um SPRITESHEET (várias imagens numa
	# imagem só). As coordenadas abaixo (Rect2(x, y, largura, altura)) são
	# PLACEHOLDER — preciso que você me diga o retângulo real de cada ícone
	# dentro do arquivo (ou me mande o .png que eu descubro certinho).
	# Até ajustar, essas 5 entradas vão mostrar o pedaço ERRADO da imagem.
	# ---------------------------------------------------------------
	"icone_populacao": {"path": "res://Jogo principal/UI/Assets/allmenusprites.png", "region": Rect2(0, 0, 32, 32)},
	"icone_desabrigados": {"path": "res://Jogo principal/UI/Assets/allmenusprites.png", "region": Rect2(32, 0, 32, 32)},
	"icone_dinheiro": {"path": "res://Jogo principal/UI/Assets/allmenusprites.png", "region": Rect2(64, 0, 32, 32)},
	"icone_popularidade": {"path": "res://Jogo principal/UI/Assets/allmenusprites.png", "region": Rect2(96, 0, 32, 32)},
	"icone_pular_turno": {"path": "res://Jogo principal/UI/Assets/allmenusprites.png", "region": Rect2(128, 0, 32, 32)},
}


# Define qual imagem deve aparecer em cada momento do tutorial.
# "" significa que nenhuma imagem deve aparecer.
const TUTORIAL_IMAGES := {
	"tutorial_1": "",
	"tutorial_2": "",
	"tutorial_3": "",
	"tutorial_4": "",

	"tutorial_5": "terreno_construcao",
	"tutorial_6": "terreno_construcao",

	"tutorial_7": "casa",
	"tutorial_8": "casa",

	"tutorial_9": "terreno_construcao",
	"tutorial_10": "terreno_construcao",

	"tutorial_11": "",
	"tutorial_12": "",

	"tutorial_13": "prefeitura",
	"tutorial_14": "prefeitura",

	"tutorial_15": "alerta",
	"tutorial_16": "alerta",

	"tutorial_17": "icone_populacao",
	"tutorial_18": "icone_desabrigados",
	"tutorial_19": "icone_dinheiro",
	"tutorial_20": "icone_popularidade",
	"tutorial_21": "icone_pular_turno",

	"tutorial_22": "",
	"tutorial_23": ""
}


var ultimo_dialogo: String = ""


func _ready() -> void:
	# O diálogo pode pausar a árvore do jogo.
	# O tutorial precisa continuar funcionando para acompanhar
	# a troca das falas.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Começa sem nenhuma imagem.
	tutorial_tile.hide()
	tutorial_tile.texture = null

	# Quando o diálogo terminar, recebemos o ID do último diálogo.
	if not dialogue_manager.dialogo_finalizado.is_connected(_on_dialogo_finalizado):
		dialogue_manager.dialogo_finalizado.connect(_on_dialogo_finalizado)

	# Inicia o tutorial.
	dialogue_manager.carregar_e_iniciar_dialogo(
		"res://Jogo principal/Scripts/dialogues.json",
		"tutorial_1"
	)


func _process(_delta: float) -> void:
	# Verifica se existe um diálogo sendo exibido.
	if not dialogue_manager.is_dialogue_active:
		return

	# Pega o ID da fala atualmente exibida.
	var dialogo_atual: String = dialogue_manager.current_node_id

	# Só troca a imagem quando a fala realmente mudou.
	if dialogo_atual == ultimo_dialogo:
		return

	ultimo_dialogo = dialogo_atual

	atualizar_imagem(dialogo_atual)


func atualizar_imagem(dialogo_id: String) -> void:
	# Se o diálogo não tiver uma imagem associada,
	# esconde a imagem.
	if not TUTORIAL_IMAGES.has(dialogo_id):
		tutorial_tile.hide()
		tutorial_tile.texture = null
		return

	var tile_id: String = TUTORIAL_IMAGES[dialogo_id]

	if tile_id == "":
		tutorial_tile.hide()
		tutorial_tile.texture = null
		return

	# Verifica se o nome da imagem existe na lista de tiles.
	if not TILES.has(tile_id):
		push_warning("Imagem do tutorial não encontrada: " + tile_id)
		tutorial_tile.hide()
		tutorial_tile.texture = null
		return

	var entrada = TILES[tile_id]
	var textura: Texture2D = null

	if entrada is String:
		# Imagem inteira (arquivo próprio)
		textura = load(entrada)
	elif entrada is Dictionary:
		# Recorte de um spritesheet (AtlasTexture)
		var base: Texture2D = load(entrada["path"])
		if base:
			var atlas := AtlasTexture.new()
			atlas.atlas = base
			atlas.region = entrada["region"]
			textura = atlas

	if textura:
		tutorial_tile.texture = textura
		tutorial_tile.show()
	else:
		push_warning("Não foi possível carregar a imagem: " + tile_id)
		tutorial_tile.hide()
		tutorial_tile.texture = null


func _on_dialogo_finalizado(_ultimo_no_id: String) -> void:
	# Remove a imagem antes de sair do tutorial.
	tutorial_tile.hide()
	tutorial_tile.texture = null

	# Vai para o jogo principal.
	get_tree().change_scene_to_file(
		"res://Jogo principal/Main_game.tscn"
	)
