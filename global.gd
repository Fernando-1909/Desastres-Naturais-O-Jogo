extends Node


var dinheiro: int
var popularidade: int
var turno: int
var aquecimento: int


#Dicionario para identificar qual construção foi clicada:
var construcoes := {
	"prefeitura": false,
	"bombeiros": false,
	"estacao_de_tratamento": false,
	"secretaria": false,
	"vizinhanca": false, #area residencial
}

#vao ser 4 areas residenciais no inicio
var desastres := {
	"enchente": 0,
	"incendio": 0,
	"desabamento": 0
}

# Dicionário com as missões disponíveis
var missoes = {
	"missao1": {
		"nome": "Construir hospital",
		"recompensa": 100,
		"popularidade": 10
	},
	"missao2": {
		"nome": "Construir praça",
		"recompensa": 200,
		"popularidade": 15
	},
	"missao3": {
		"nome": "Expandir cidade",
		"recompensa": 300,
		"popularidade": 20
	}
}

var missao_escolhida = null
var missoes_concluidas = []
