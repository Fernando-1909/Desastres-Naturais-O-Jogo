extends TextureProgressBar

@onready var percent_label: RichTextLabel = $PorcentagemBarra

func _ready() -> void:
	# Garante que o label não bloqueie cliques/inputs que a barra deva receber
	percent_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	value_changed.connect(_atualizar_texto_percentual)
	_atualizar_texto_percentual(value)

func _atualizar_texto_percentual(novo_valor: float) -> void:
	var percentual := (novo_valor / max_value) * 100.0
	percent_label.text = "%d%%" % int(percentual)
