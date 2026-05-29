extends Label

var textoPadrao = "Popularidade: "

@warning_ignore("unused_parameter")
func _process(delta):
	var text = str(textoPadrao, str(Global.popularidade))
	self.text = (text) + "%"
