extends Node

# Controle de acesso à praia
var nivelPraia: bool = false


# Libera a praia
func liberarPraia():
	nivelPraia = true
	print("Praia liberada")


# Bloqueia a praia
func bloquearPraia():
	nivelPraia = false
	print("Praia bloqueada")
