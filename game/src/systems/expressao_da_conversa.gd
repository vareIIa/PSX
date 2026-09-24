## A cara de cada temperamento, e como ela reage ao que o jogador pergunta.
##
## A base e o rosto em repouso durante a conversa inteira: o desconfiado ja
## chega de sobrancelha torta, o melancolico triste, o assustado de olho
## arregalado. A reacao e o que a pergunta provoca, por um instante, antes de a
## pessoa responder — e o que faz a opcao escolhida PESAR na cara de quem
## escuta, em vez de a resposta cair num rosto que nao ouviu nada.
##
## Indices de `Personalidade.LISTA`: DESCONFIADO 0, TAGARELA 1, APRESSADO 2,
## MELANCOLICO 3, GENTIL 4, BEBADO 5, DEVOTO 6, CINICO 7, ASSUSTADO 8,
## MANDAO 9, SONHADOR 10, VIGARISTA 11.
class_name ExpressaoDaConversa
extends RefCounted

const E := Rosto.Expressao

const BASE: Array[int] = [
	E.DESCONFIANCA, E.SIMPATIA, E.NEUTRA, E.TRISTEZA, E.SIMPATIA, E.BEBADO,
	E.NEUTRA, E.DESCONFIANCA, E.MEDO, E.RAIVA, E.CHAPADO, E.SIMPATIA,
]

## Reacao por assunto: [expressao, segundos]. `null` num temperamento usa a
## linha padrao; a tabela por temperamento vem primeiro.
const REACAO := {
	&"nevoa": [E.MEDO, 1.6],
	&"bairro": [E.NEUTRA, 0.0],
	&"voce": [E.SURPRESA, 0.9],
	&"documento": [E.DESCONFIANCA, 1.4],
	&"trabalho": [E.SIMPATIA, 1.2],
	&"role": [E.RISO, 1.2],
	&"plantio": [E.SIMPATIA, 1.0],
	&"super": [E.SURPRESA, 1.2],
	&"entregar": [E.SIMPATIA, 1.2],
	&"sair": [E.NEUTRA, 0.0],
	&"descer": [E.RAIVA, 1.6],
	&"blitz_colaborar": [E.DESCONFIANCA, 1.5],
	&"blitz_cafe": [E.DESCONFIANCA, 1.0],
	&"blitz_correr": [E.RAIVA, 2.0],
}

## Quem reage diferente do padrao: {temperamento: {assunto: [expressao, s]}}.
const POR_TEMPERAMENTO := {
	0: {&"voce": [E.DESCONFIANCA, 1.4], &"nevoa": [E.DESCONFIANCA, 1.4]},
	1: {&"nevoa": [E.SURPRESA, 1.2], &"bairro": [E.SIMPATIA, 1.2]},
	3: {&"bairro": [E.TRISTEZA, 1.6], &"voce": [E.TRISTEZA, 1.2]},
	5: {&"nevoa": [E.RISO, 1.2], &"documento": [E.BEBADO, 1.0]},
	7: {&"voce": [E.NOJO, 1.0], &"trabalho": [E.NOJO, 1.2]},
	8: {&"nevoa": [E.MEDO, 2.4], &"voce": [E.MEDO, 1.4], &"documento": [E.MEDO, 1.6]},
	9: {&"documento": [E.RAIVA, 1.4], &"voce": [E.RAIVA, 1.0]},
	11: {&"documento": [E.SIMPATIA, 1.2], &"trabalho": [E.RISO, 1.2]},
}


static func base(personalidade: int) -> int:
	return BASE[clampi(personalidade, 0, BASE.size() - 1)]


## [expressao, segundos] da reacao a `chave`, ou [] se nao ha reacao.
static func reacao(chave: StringName, personalidade: int) -> Array:
	var proprio: Dictionary = POR_TEMPERAMENTO.get(personalidade, {})
	if proprio.has(chave):
		return proprio[chave]
	var texto := String(chave)
	if texto.begins_with("contratar_"):
		return [E.SIMPATIA, 1.4]
	if texto.begins_with("demitir_"):
		return [E.TRISTEZA, 1.6]
	var r: Array = REACAO.get(chave, [])
	if r.is_empty() or float(r[1]) <= 0.0:
		return []
	return r
