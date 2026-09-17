extends Node2D


@onready var dialogue_manager = $DialogueManager
@onready var tutorial_tile: TextureRect = $TutorialUI/TutorialTile


const TILES := {
	"prefeitura": "res://Jogo principal/tilesheets/Prefeitura.png",
	"abrigo": "res://Jogo principal/tilesheets/Abrigo.png",
	"bombeiros": "res://Jogo principal/tilesheets/Estacao_de_bombeiros_level_1.png"
}


func _ready() -> void:
	# Garante que o tile comece escondido.
	#tutorial_tile.hide()
	tutorial_tile.texture = load(TILES["abrigo"])
	tutorial_tile.show()

	# Quando o diálogo terminar, recebemos o ID do último diálogo.
	if not dialogue_manager.dialogo_finalizado.is_connected(_on_dialogo_finalizado):
		dialogue_manager.dialogo_finalizado.connect(_on_dialogo_finalizado)

	# Inicia o tutorial.
	dialogue_manager.carregar_e_iniciar_dialogo(
		"res://Jogo principal/Scripts/dialogues.json",
		"tutorial_1"
	)


func _on_dialogo_finalizado(_ultimo_no_id: String) -> void:
	# Por enquanto não fazemos nada quando o tutorial terminar.
	get_tree().change_scene_to_file("res://Jogo principal/Main_game.tscn")
