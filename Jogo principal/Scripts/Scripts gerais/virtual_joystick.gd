extends Control

@onready var knob = $Knob

var enabled := true

var radius := 80.0
var output := Vector2.ZERO

var dragging := false
var touch_id := -1

var center := Vector2.ZERO

func _ready():
	center = knob.position

func _gui_input(event):

	if event is InputEventScreenTouch:

		if event.pressed:

			dragging = true
			touch_id = event.index

		elif event.index == touch_id:

			dragging = false
			touch_id = -1

			output = Vector2.ZERO
			knob.position = center

	elif event is InputEventScreenDrag:

		if dragging and event.index == touch_id:

			var offset = event.position - center

			if offset.length() > radius:
				offset = offset.normalized() * radius

			knob.position = center + offset

			output = offset / radius

func _input(event):

	if !enabled:
		return

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			if event.pressed:

				dragging = true

			else:

				dragging = false

				output = Vector2.ZERO
				knob.position = center

	elif event is InputEventMouseMotion and dragging:

		var offset = get_local_mouse_position() - center

		if offset.length() > radius:
			offset = offset.normalized() * radius

		knob.position = center + offset

		output = offset / radius
