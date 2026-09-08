extends Node

# Variáveis gerais
var dinheiro: int
var popularidade: int
var populacao: int
var pessoas_desabrigadas: int = 0   # NPCs que perderam a casa em um desastre (infraestrutura chegou a 0)
var turno: int
var renda: int             # Quantidade de "unidades" de renda geradas por turno (baseado na população)
var idioma_atual: String = "pt"

#Variáveis Resgate
var pessoas_abrigadas: int = 0
var capacidade_total_abrigo: int = 0
var total_equipes_resgate: int = 0

# Sinal emitido sempre que o idioma do jogo e alterado
signal idioma_alterado(novo_idioma: String)

# Variáveis de desastre
var aquecimento: int
var enchente: int
var nivel_enchente: int = 0   # Nível atual da enchente ativa (0 = nenhuma enchente ativa)

# Variáveis de missões
var missao_escolhida: MissionData = null
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

# As missões agora são carregadas como .tres (MissionData) pelo main_game.gd,
# no dicionário 'banco_missoes' — veja mission_data.gd

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
