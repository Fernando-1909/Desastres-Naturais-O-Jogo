extends Node2D

# CÂMERA
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud

var freecam_enabled = false

func _ready() -> void:
	freecam_camera.enabled = false
	hud.toggle_freecam.connect(_on_toggle_freecam)

func _on_toggle_freecam():
	freecam_enabled = !freecam_enabled
	if freecam_enabled:
		freecam_camera.global_position = $Player.global_position
		player_camera.enabled = false
		freecam_camera.enabled = true
	else:
		freecam_camera.enabled = false
		player_camera.enabled = true

# MAPA
func _on_button_mapa_pressed() -> void:
	$CanvasLayer/MapOverlay.visible = true

# TESTES
func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()
	print("praia foi liberada!")

func _on_button_dinheiro_plus_pressed() -> void:
	Global.dinheiro += 100
	Global.popularidade += 50

func _on_button_dinheiro_minus_pressed() -> void:
	Global.dinheiro -= 100
	Global.popularidade -= 25
