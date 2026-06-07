extends Node2D

@onready var freecam: Camera2D = $FreeCamera2D
@onready var scene_camera: Camera2D = $Player/Camera2D
@onready var hud = $CanvasLayer/Hud

var freecam_active := false

func _ready():
	hud.toggle_freecam.connect(_on_toggle_freecam)
	freecam.enabled = false

func _on_toggle_freecam():
	freecam_active = !freecam_active
	freecam.enabled = freecam_active
	scene_camera.enabled = !freecam_active
	if freecam_active:
		freecam.position = scene_camera.global_position
