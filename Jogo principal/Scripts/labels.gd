extends Node

# Referências para os labels (serão preenchidas quando o script for chamado)
var building_info: Label
var building_name: Label
var dinheiro_label: Label

# Função para configurar as referências dos labels
func setup_labels(info: Label, name: Label, dinheiro: Label):
	building_info = info
	building_name = name
	dinheiro_label = dinheiro

# Função para atualizar todos os labels
func atualizar_todos():
	if building_info:
		if Global.construcoes.get("prefeitura", false) == true:
			building_info.text = "aqui é a prefeitura!"
		elif Global.construcoes.get("casa1", false) == true:
			building_info.text = "aqui é uma casa!"
		else:
			building_info.text = ""
	
	if building_name:
		if Global.construcoes.get("prefeitura", false) == true:
			building_name.text = "prefeitura"
		elif Global.construcoes.get("bombeiros", false) == true:
			building_name.text = "bombeiros"
		else:
			building_name.text = ""
	
	if dinheiro_label:
		dinheiro_label.text = "Dinheiro: " + str(Global.dinheiro)
