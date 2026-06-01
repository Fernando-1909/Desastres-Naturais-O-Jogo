extends Node2D

var active = false
var dragging = false

func _unhandled_input(event):
	if !active:
		return

	# Android
	if event is InputEventScreenTouch:
		dragging = event.pressed

	elif event is InputEventScreenDrag and dragging:
		global_position -= event.relative

	# PC
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		global_position -= event.relative
