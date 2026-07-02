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
	"casa1": false
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
		"info": "Os cidadãos estão se machucando bastante ultimamente, e alguns até ficando doentes, precisamos de uma forma para tratá-los!",
		"recompensa": 100,
		"popularidade": 10
	},
	"missao2": {
		"nome": "Construir praça",
		"info": "A cidade está sem áreas de lazer e os moradores reclamam da falta de um espaço para descanso e convivência.",
		"recompensa": 200,
		"popularidade": 15
	},
	"missao3": {
		"nome": "Expandir cidade",
		"info": "Com o aumento da população, precisamos expandir os limites da cidade para acomodar novos moradores.",
		"recompensa": 300,
		"popularidade": 20
	}
}

var missao_escolhida = null
var missoes_concluidas = []
var chance_missao = 30
var turnos_sem_missao = {}  # Dicionário para contar turnos sem cada missão
var missao_atual_turnos = 0
var jogo_pausado = false
