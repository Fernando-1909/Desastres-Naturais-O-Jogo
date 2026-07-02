extends Label

var texto_padrao = ""

@warning_ignore("unused_parameter")
func _process(_delta):
	if Global.missao_escolhida != null:
		var texto = str(Global.missao_escolhida["info"])
		self.text = texto
	else:
		self.text = texto_padrao
