extends Node2D


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

func _on_popup_teste_pressed() -> void:
	print("popup apertado")
	#print(pop_up_scene)
	$CanvasLayer/BuildingHUD.visible = true
	
	#var new_pop_up = pop_up_scene.instantiate()
	#add_child(new_pop_up)


func _on_button_close_menu_pressed() -> void:
	$CanvasLayer/BuildingHUD.visible = false
