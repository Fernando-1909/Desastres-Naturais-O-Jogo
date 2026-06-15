extends Control

signal toggle_freecam  # ← adiciona essa linha

var freecam: Camera2D
var scene_camera: Camera2D
var freecam_active := false

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_setup()

func _setup() -> void:
	scene_camera = get_tree().get_first_node_in_group("scene_camera")

func _on_button_freecam_pressed() -> void:
	emit_signal("toggle_freecam")

func _on_button_mapa_pressed() -> void:
	$MapOverlay.visible = !$MapOverlay.visible


func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()


func _on_button_dinheiro_plus_pressed() -> void:
	Global.dinheiro += 100
	Global.popularidade += 50


func _on_button_dinheiro_minus_pressed() -> void:
	Global.dinheiro -= 100
	Global.popularidade -= 25
