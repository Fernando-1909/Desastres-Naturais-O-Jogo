extends Label

var texto_padrao = ""

@warning_ignore("unused_parameter")
func _process(_delta):
	if Global.missao_escolhida != null:
		var texto = "Dinheiro: " + str(Global.missao_escolhida["recompensa"]) + "\nPopularidade: +" + str(Global.missao_escolhida["popularidade"])
		self.text = texto
	else:
		self.text = texto_padrao
