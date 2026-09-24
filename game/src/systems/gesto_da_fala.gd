## Que gesto acompanha a fala, e em que letra ele comeca.
##
## A linha nao diz o gesto — e a frase que diz. "Nao" nega com a cabeca, "sim"
## concorda, "voce" aponta ou explica, "eu" e a mao no peito, a pergunta da de
## ombros, a exclamacao abre os bracos. O temperamento escolhe entre as opcoes
## (o mandao aponta, o gentil explica, o desconfiado so mexe a cabeca) e o jeito
## da pessoa diz quanto ela gesticula (`Jeito.gesto`). Um gesto por vez, com
## folga entre eles: gesto em toda palavra le como mimica.
##
## Marca explicita `[gesto:nome]` na linha vale mais que tudo isto (`Fala`).
class_name GestoDaFala
extends RefCounted

## Folga minima entre dois gestos, em letras (~1,5 s a 25 letras por segundo).
const FOLGA := 36

const NOMES := {
	&"explica": ReacaoCorpo.GESTO_EXPLICA, &"abre": ReacaoCorpo.GESTO_ABRE,
	&"ombros": ReacaoCorpo.GESTO_OMBROS, &"peito": ReacaoCorpo.GESTO_PEITO,
	&"aponta": ReacaoCorpo.GESTO_APONTA, &"aceno": ReacaoCorpo.GESTO_ACENO,
	&"nega": ReacaoCorpo.GESTO_NEGA, &"concorda": ReacaoCorpo.GESTO_CONCORDA,
	&"xinga": ReacaoCorpo.REACAO_XINGA, &"protege": ReacaoCorpo.REACAO_PROTEGE,
	&"maos_alto": ReacaoCorpo.REACAO_MAOS_ALTO, &"benze": ReacaoCorpo.OCIO_BENZE,
	&"cruza": ReacaoCorpo.OCIO_CRUZA, &"cintura": ReacaoCorpo.OCIO_CINTURA,
	&"esfrega": ReacaoCorpo.OCIO_ESFREGA, &"nuca": ReacaoCorpo.OCIO_NUCA,
}


## [[posicao na linha limpa, tipo de ReacaoCorpo], ...] para `linha`.
static func escolher(linha: String, personalidade: int, gesto: float = 1.0) -> Array:
	var saida: Array = []
	var baixa := linha.to_lower()
	var so_cabeca := personalidade == 0 or gesto < 0.55  # DESCONFIADO, contido
	var ultimo := -FOLGA

	var inicio := baixa.strip_edges()
	if inicio.begins_with("nao") or inicio.begins_with("não") or inicio.begins_with("nunca"):
		saida.append([0, ReacaoCorpo.GESTO_NEGA])
		ultimo = 0
	elif inicio.begins_with("sim") or inicio.begins_with("claro") or inicio.begins_with("isso") \
			or inicio.begins_with("pode") or inicio.begins_with("ta ") or inicio.begins_with("tá"):
		saida.append([0, ReacaoCorpo.GESTO_CONCORDA])
		ultimo = 0
	if so_cabeca:
		return saida

	# Palavras que apontam para alguem.
	var r := RegEx.create_from_string("\\b(voce|você|vc|eu|me|meu|minha)\\b")
	for m in r.search_all(baixa):
		var pos := m.get_start()
		if pos - ultimo < int(FOLGA / maxf(0.4, gesto)):
			continue
		var palavra := m.get_string(1)
		var tipo := ReacaoCorpo.GESTO_PEITO
		if palavra.begins_with("v"):
			tipo = ReacaoCorpo.GESTO_APONTA if personalidade in [7, 9] else ReacaoCorpo.GESTO_EXPLICA
		saida.append([pos, tipo])
		ultimo = pos

	var fim := linha.strip_edges()
	var perto_do_fim := maxi(0, fim.length() - 12)
	if perto_do_fim - ultimo >= int(FOLGA / maxf(0.4, gesto)):
		if fim.ends_with("?"):
			saida.append([perto_do_fim, ReacaoCorpo.GESTO_OMBROS if personalidade in [1, 4, 10]
				else ReacaoCorpo.GESTO_EXPLICA])
		elif fim.ends_with("!"):
			saida.append([perto_do_fim, ReacaoCorpo.REACAO_XINGA if personalidade == 9
				else ReacaoCorpo.GESTO_ABRE])
		elif gesto > 1.1 and fim.length() > 30:
			# Quem gesticula muito marca a frase comprida mesmo sem pontuacao.
			saida.append([fim.length() / 2, ReacaoCorpo.GESTO_EXPLICA])
	return saida
