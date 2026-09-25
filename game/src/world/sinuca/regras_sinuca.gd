## Regras da bola 8 de bar: lisas contra listradas, quem mata a 8 depois do
## proprio grupo ganha.
##
## Dados puros. Recebe o que a tacada fez (os eventos da FisicaSinuca) e devolve
## o que acontece agora: falta, de quem e a vez, se a branca vai na mao, se o
## jogo acabou. O jogo (JogoSinuca) so executa.
##
## As regras sao as de mesa de bar, sem cantar cacapa:
## - quebra com a branca atras da linha de cabeceira; a 8 caida na quebra volta
##   para a marca do pe;
## - mesa aberta ate a primeira bola encacapada sem falta depois da quebra: o
##   grupo dela e de quem encacapou;
## - falta: a branca nao toca em bola, toca primeiro na bola errada, nenhuma bola
##   vai a tabela nem cai depois do toque, ou a branca cai. Falta da bola na mao
##   (em qualquer lugar) para o outro;
## - a 8 caida antes de limpar o grupo, ou com falta, perde o jogo.
class_name RegrasSinuca
extends RefCounted

const LISAS := 0
const LISTRADAS := 1
const ABERTA := -1

## 0 e o jogador, 1 o adversario.
var vez := 0
var grupo: Array[int] = [ABERTA, ABERTA]
var quebra := true
var bola_na_mao := true
## Bola na mao so atras da linha de cabeceira (a da quebra).
var so_cabeceira := true
var fim := false
var vencedor := -1


static func grupo_da_bola(n: int) -> int:
	if n >= 1 and n <= 7:
		return LISAS
	if n >= 9 and n <= 15:
		return LISTRADAS
	return -2


static func nome_do_grupo(g: int) -> String:
	match g:
		LISAS:
			return "LISAS"
		LISTRADAS:
			return "LISTRADAS"
	return "MESA ABERTA"


func restantes(f: FisicaSinuca, g: int) -> int:
	var n := 0
	for i in range(1, 16):
		if grupo_da_bola(i) == g and f.na_mesa(i):
			n += 1
	return n


## As bolas que quem esta na vez pode tocar primeiro.
func alvos(f: FisicaSinuca) -> Array[int]:
	var g := grupo[vez]
	var lista: Array[int] = []
	if g == ABERTA:
		for i in range(1, 16):
			if i != 8 and f.na_mesa(i):
				lista.append(i)
		return lista
	if restantes(f, g) == 0:
		lista.append(8)
		return lista
	for i in range(1, 16):
		if grupo_da_bola(i) == g and f.na_mesa(i):
			lista.append(i)
	return lista


## Julga a tacada que acabou. Devolve o que o jogo precisa mostrar e fazer.
func avaliar(f: FisicaSinuca) -> Dictionary:
	var caidas: Array[int] = []
	var primeira := -1
	var tabela_depois := false
	var tocou := false
	for e: Dictionary in f.eventos:
		match StringName(e["tipo"]):
			&"bola":
				var a := int(e["a"])
				var b := int(e["b"])
				if not tocou and (a == 0 or b == 0):
					primeira = b if a == 0 else a
					tocou = true
			&"tabela":
				if tocou:
					tabela_depois = true
			&"cacapa":
				caidas.append(int(e["a"]))

	var g := grupo[vez]
	# Quantas do grupo havia ANTES desta tacada: as que ficaram mais as que caram.
	var do_grupo_caidas := 0
	for n in caidas:
		if g != ABERTA and grupo_da_bola(n) == g:
			do_grupo_caidas += 1
	var limpo_antes := g != ABERTA and restantes(f, g) + do_grupo_caidas == 0

	var falta := false
	var motivo := ""
	if primeira == -1:
		falta = true
		motivo = "a branca não tocou em nenhuma bola"
	elif g == ABERTA:
		if primeira == 8 and not quebra:
			falta = true
			motivo = "tocou primeiro na 8"
	elif limpo_antes:
		if primeira != 8:
			falta = true
			motivo = "tinha de tocar primeiro na 8"
	elif grupo_da_bola(primeira) != g:
		falta = true
		motivo = "tocou primeiro na %s" % ("8" if primeira == 8 else "bola do adversário")
	if not falta and not tabela_depois and caidas.is_empty():
		falta = true
		motivo = "nenhuma bola foi à tabela"
	var riscou := caidas.has(0)
	if riscou:
		falta = true
		motivo = "a branca caiu"

	var recolocar_8 := false
	if caidas.has(8):
		if quebra:
			recolocar_8 = true
		else:
			fim = true
			vencedor = vez if (limpo_antes and not falta) else 1 - vez

	# Mesa aberta: a primeira bola de grupo que caiu sem falta define os grupos.
	if not fim and g == ABERTA and not quebra and not falta:
		for n in caidas:
			var gn := grupo_da_bola(n)
			if gn >= 0:
				grupo[vez] = gn
				grupo[1 - vez] = 1 - gn
				break

	var g_agora := grupo[vez]
	var matou_a_sua := false
	for n in caidas:
		var gn := grupo_da_bola(n)
		if gn >= 0 and (g_agora == ABERTA or gn == g_agora):
			matou_a_sua = true
	var continua := not falta and matou_a_sua and not fim
	var quem_tacou := vez
	var era_quebra := quebra
	quebra = false
	so_cabeceira = false
	if fim:
		bola_na_mao = false
	elif falta:
		vez = 1 - vez
		bola_na_mao = true
	else:
		bola_na_mao = false
		if not continua:
			vez = 1 - vez

	return {
		"falta": falta, "motivo": motivo, "continua": continua, "caidas": caidas,
		"fim": fim, "vencedor": vencedor, "recolocar_8": recolocar_8,
		"riscou": riscou, "primeira": primeira, "tacou": quem_tacou,
		"quebra": era_quebra, "grupo_definido": g == ABERTA and grupo[quem_tacou] != ABERTA,
	}
