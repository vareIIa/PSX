## Onde ficam os lugares da Missao 1.
##
## A igreja e fixa: a Praca da Matriz e ancorada a mao (`Tracado._ancora`,
## `ParqueBuilder.planta_matriz`, `KitParque.igreja_matriz`), e o jogador
## acorda no pino (270, -40) com a cabeca para ela. A casa da fumaca e sorteio
## do gerador, e a vaga na calcada depende da rua que estiver ali. Tudo e
## estatico e responde sem chunk carregado: o Berg precisa estacionar na igreja
## antes de ela existir na tela.
##
## STUB da branch missao1/base: a igreja sai de constantes aproximadas
## (`cidade.gd` IGREJA_ANCORA / IGREJA_FACHADA_Z) e a vaga e o proprio ponto.
## A tarefa D calcula tudo a partir de `planta_matriz` e confere no jogo.
class_name Lugares
extends RefCounted

const IGREJA_ANCORA := Vector3(270.9, 0.0, -59.1)
const IGREJA_FACHADA_Z := -53.1


## A casa da fumaca mais proxima: {mundo, chunk, semente, nome}.
static func casa_fumaca_mais_perto(de: Vector3) -> Dictionary:
	return Missoes.casa_mais_perto(de)


## A igreja da Praca da Matriz. Chaves:
##   mundo: Vector3       a porta principal, no topo da escadaria
##   frente: Vector3      onde o jogador para, no adro, olhando a porta
##   giro: float          para onde a fachada olha (rad, eixo Y; +Z = sul)
##   vaga: Transform3D    onde o carro do Berg estaciona, duas rodas na calcada
##                        da praca, de frente para a escadaria
##   area: Rect2          retangulo do adro em XZ, onde o Berg vaga
##   nome: String
static func igreja() -> Dictionary:
	var porta := Vector3(IGREJA_ANCORA.x, 0.55, IGREJA_FACHADA_Z)
	return {
		"mundo": porta,
		"frente": porta + Vector3(0.0, -0.55, 6.0),
		"giro": 0.0,
		"vaga": Transform3D(Basis(Vector3.UP, PI * 0.5), porta + Vector3(0.0, -0.55, 22.0)),
		"area": Rect2(IGREJA_ANCORA.x - 14.0, IGREJA_FACHADA_Z, 28.0, 18.0),
		"nome": "IGREJA MATRIZ",
	}


## Vaga paralela ao meio-fio perto de um ponto, com as duas rodas do lado da
## calcada em cima dela (o padrao da viatura da blitz, `Blitz._montar_viatura`
## e `_pegada_livre`). `frente_para` aponta o capo.
static func vaga_na_calcada(perto_de: Vector3, frente_para: Vector3 = Vector3.INF) -> Transform3D:
	var giro := 0.0
	if frente_para != Vector3.INF:
		var d := frente_para - perto_de
		giro = atan2(-d.x, -d.z)
	return Transform3D(Basis(Vector3.UP, giro), perto_de)
