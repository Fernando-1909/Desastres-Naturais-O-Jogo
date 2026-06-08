extends Label


var texto = "texto"

@warning_ignore("unused_parameter")
func _process(delta):
	var text = str(texto)
	if Global.construcoes["prefeitura"] == true:
		self.text = "aqui é a prefeitura!"
	elif Global.construcoes["bombeiros"] == true:
		self.text = "aqui é os bombeiros!"
