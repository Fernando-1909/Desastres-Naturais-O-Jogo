extends Node

# Variáveis gerais
var dinheiro: int
var popularidade: int
var turno: int
var renda: int             # Quantidade de construções que geram renda (dinheiro) por turno
var renda_pedra: int       # Quantidade de construções que geram pedra por turno (esboço, sem uso ainda)
var renda_madeira: int     # Quantidade de construções que geram madeira por turno (esboço, sem uso ainda)
var madeira: int
var pedra: int
var idioma_atual: String = "pt"

# Sinal emitido sempre que o idioma do jogo e alterado
signal idioma_alterado(novo_idioma: String)

# Variáveis de desastre
var aquecimento: int
var enchente: int

# Variáveis de missões
var missao_escolhida = null
var missao_aceita := false  # true = missão aceita, aguardando conclusão (botão de concluir)
var missoes_concluidas = []
var chance_missao = 30
var turnos_sem_missao = {}  # Dicionário para contar turnos sem cada missão
var missao_atual_turnos = 0


var jogo_pausado = false

#Dicionario para identificar qual construção foi clicada:
var construcoes := {
	"prefeitura": false,
	"bombeiros": false,
	"estacao_de_tratamento": false,
	"secretaria": false,
	"hospital": false,
	"casa1": false,
	"escola1": false,
	"igreja": false,
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
		"custo": 100,
		"pedra": 50,
		"madeira": 70,
		"popularidade": 10
	},
	"missao2": {
		"nome": "Construir praça",
		"info": "A cidade está sem áreas de lazer e os moradores reclamam da falta de um espaço para descanso e convivência.",
		"custo": 200,
		"pedra": 80,
		"madeira": 60,
		"popularidade": 15
	},
	"missao3": {
		"nome": "Expandir cidade",
		"info": "Com o aumento da população, precisamos expandir os limites da cidade para acomodar novos moradores.",
		"custo": 300,
		"pedra": 120,
		"madeira": 100,
		"popularidade": 20
	}
}

func _ready() -> void:
	# Detecta o idioma do sistema operacional ou carrega o padrao
	var idioma_sistema = TranslationServer.get_locale().left(2)
	if idioma_sistema in ["pt", "en"]:
		alterar_idioma(idioma_sistema)
	else:
		alterar_idioma("pt")

## Função global para alterar o idioma em tempo de execução
func alterar_idioma(codigo_lang: String) -> void:
	idioma_atual = codigo_lang
	TranslationServer.set_locale(codigo_lang)
	idioma_alterado.emit(codigo_lang)
	print("Idioma do jogo alterado para: ", codigo_lang)
