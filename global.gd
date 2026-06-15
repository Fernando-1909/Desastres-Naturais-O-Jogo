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
