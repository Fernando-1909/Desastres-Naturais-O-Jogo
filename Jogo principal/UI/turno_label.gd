extends Label

var textoPadrao = "Turno: "

@warning_ignore("unused_parameter")
func _process(delta):
	var text = str(textoPadrao, str(Global.turno))
	self.text = (text)
