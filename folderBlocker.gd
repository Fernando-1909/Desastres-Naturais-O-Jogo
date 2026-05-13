extends Node

var pasta_lvl2_ativa = false

const PASTA_LVL2 = "res://Jogo principal/Map_City/Lvl2/"


func carregar_recurso(caminho):

	# Verifica se o arquivo está dentro da pasta bloqueada
	if caminho.begins_with(PASTA_LVL2):

		if !pasta_lvl2_ativa:
			print("Essa pasta está bloqueada!")
			return null

	# Se estiver liberada, carrega normalmente
	return load(caminho)


func ativar_pasta_lvl2():
	pasta_lvl2_ativa = true
	print("Pasta Lvl2 ativada!")


func desativar_pasta_lvl2():
	pasta_lvl2_ativa = false
	print("Pasta Lvl2 desativada!")
