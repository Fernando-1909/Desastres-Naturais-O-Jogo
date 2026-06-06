extends Node2D

#CÂMERA
@onready var player_camera = $Player/Camera2D
@onready var freecam_camera = $FreeCam/Camera2D
@onready var freecam = $FreeCam

var freecam_enabled = false

func _on_free_cam_button_pressed():
	freecam_enabled = !freecam_enabled
	
	if freecam_enabled:
		freecam.global_position = $Player.global_position
		player_camera.enabled = false
		freecam_camera.enabled = true
		freecam.active = true
		$CanvasLayer/Hud/VirtualJoystick.visible = false
		$CanvasLayer/Hud/VirtualJoystick.enabled = false
	else:
		freecam_camera.enabled = false
		player_camera.enabled = true
		freecam.active = false
		$CanvasLayer/Hud/VirtualJoystick.output = Vector2.ZERO
		$CanvasLayer/Hud/VirtualJoystick.visible = true
		$CanvasLayer/Hud/VirtualJoystick.enabled = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.

#func _process(delta: float) -> void:
#	pass

#abrir pop-up do mapa
func _on_button_mapa_pressed() -> void:
	$CanvasLayer/MapOverlay.visible = true

# Liberar a praia para o jogador
func _on_botao_teste_pressed() -> void:
	FolderBlocker.liberarPraia()
	print("praia foi liberada!")


func _on_button_dinheiro_plus_pressed() -> void:
	Global.dinheiro += 100
	Global.popularidade += 50


func _on_button_dinheiro_minus_pressed() -> void:
	Global.dinheiro -= 100
	Global.popularidade -= 25

#abrir pop-up de melhorias
@onready var pop_up_scene = load("res://Jogo principal/building_hud.tscn")


func _on_button_close_menu_pressed() -> void:
	$CanvasLayer/BuildingHUD.visible = false
	for construcao in Global.construcoes:
		Global.construcoes[construcao] = false

func _on_prefeitura_button_pressed() -> void:
	print("prefeitura clicada")
	Global.construcoes["prefeitura"] = true
	$CanvasLayer/BuildingHUD.visible = true


func _on_bombeiros_button_pressed() -> void:
	print("bombeiros clicado")
	Global.construcoes["bombeiros"] = true
	$CanvasLayer/BuildingHUD.visible = true
