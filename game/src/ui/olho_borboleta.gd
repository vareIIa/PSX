## Autoload. O olho PSX que aparece quando uma escolha vai pesar no futuro.
##
## So a borda do olho, translucida, no meio-alto da tela. Ele abre, olha para um
## lado, olha para o outro e fecha. E a unica interface do jogo que nao finge ser
## papel, de proposito: ela nao pertence ao mundo, pertence ao destino.
##
## STUB da branch missao1/base. A tarefa A (cinema e escolhas) desenha o olho.
## O contrato abaixo nao muda: `mostrar` toca a animacao inteira e emite
## `terminou` no fim; chamar de novo durante a animacao reinicia.
extends CanvasLayer

signal terminou()


func _ready() -> void:
	# Acima do pos-processamento (150) nao: o olho recebe o mesmo grao e dither
	# do resto. Abaixo da Cinematica (145) tambem nao, porque aparece por cima
	# das tarjas.
	layer = 146
	Borboleta.marcou.connect(_ao_marcar)


func _ao_marcar(_chave: StringName, _valor: Variant, olho: bool) -> void:
	if olho:
		mostrar()


## Toca o olho: abre, olha esquerda, olha direita, fecha.
func mostrar() -> void:
	terminou.emit.call_deferred()
