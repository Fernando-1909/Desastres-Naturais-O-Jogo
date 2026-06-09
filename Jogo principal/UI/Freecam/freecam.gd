extends Camera2D

var dragging := false
var last_drag_pos := Vector2.ZERO
var zoom_min = 0.5
var zoom_max = 3.0
var zoom_speed = 0.1

func _input(event):
	if not enabled:
		return
	
	if event is InputEventScreenDrag:
		position -= event.relative
		
	if event is InputEventScreenTouch:
		if event.pressed:
			dragging = true
			last_drag_pos = event.position
		else:
			dragging = false
			
	if event is InputEventMagnifyGesture:
		var new_zoom = zoom * event.factor
		new_zoom = clamp(new_zoom, Vector2(zoom_min, zoom_min), Vector2(zoom_max, zoom_max))
		zoom = new_zoom
