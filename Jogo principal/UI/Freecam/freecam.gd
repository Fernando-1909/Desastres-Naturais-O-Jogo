extends Camera2D

var dragging := false
var last_drag_pos := Vector2.ZERO

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
		zoom *= event.factor
		zoom = zoom.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))
