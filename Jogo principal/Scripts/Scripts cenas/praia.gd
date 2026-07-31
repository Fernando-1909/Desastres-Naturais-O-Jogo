extends Node2D

@onready var freecam: Camera2D = $FreeCamera2D
@onready var hud = $CanvasLayer/Hud

var freecam_active := true

func _ready():
	freecam.enabled = true
