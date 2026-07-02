extends Label

var textoPadrao = "Dinheiro: "

@warning_ignore("unused_parameter")
func _process(delta):
	var text = str(textoPadrao, str(Global.dinheiro))
	self.text = (text)
