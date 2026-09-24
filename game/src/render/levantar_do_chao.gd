## Levantar do chao depois de um tombo: de costas ou de bruços.
##
## E a parte que o Euphoria nao faz — no GTA IV o levantar e animacao gravada,
## e o ragdoll so entrega a pose de partida. Aqui tambem: poses-chave escritas a
## mao, com a pose em que a fisica deixou o corpo misturada na primeira delas
## (ver `BonecoDePano.MISTURA`).
##
## Maos e pes vao por ALVO, e nao por angulo
## -----------------------------------------
## A primeira versao era so angulo, e a regua (`tests/medir_levantar.gd`)
## reprovou: a mao que apoia no corpo de 1,72 m fica dez centimetros no ar no
## de 1,90 e entra no chao no de 1,58; e entre duas chaves o pe plantado
## escorrega e atravessa o piso, porque o angulo interpola e o quadril tambem,
## cada um para um lado. Com alvo, o pe plantado numa chave continua no MESMO
## ponto do chao ate a chave em que ele sai, qualquer que seja o corpo: o angulo
## de quadril e de joelho sai de um IK de dois ossos a cada quadro (`_ik`).
##
## Referencial: o do Corpo em pe no fim, frente em -Z, x para a direita. De
## costas, os pes apontam para a frente (ele senta e levanta na direcao dos pes);
## de bruços, a cabeca aponta para a frente. O no do Corpo nao anda: quem anda e
## o quadril, de onde estava deitado ate em cima dos pes.
class_name LevantarDoChao
extends RefCounted

const O := Corpo.Osso
const MEIO_PI := PI * 0.5

## Membros por alvo. O alvo e o PUNHO (mao) ou o TORNOZELO (pe), no corpo de
## 1,72 m; o x e somado ao x de repouso do membro (meio ombro, meio quadril),
## com o sinal do lado. O polo e para onde o cotovelo ou o joelho aponta.
const MAO_E := &"mao_e"
const MAO_D := &"mao_d"
const PE_E := &"pe_e"
const PE_D := &"pe_d"
const MEMBROS := {
	MAO_E: [O.BRACO_E, O.ANTEBRACO_E, -1.0, 1.0],
	MAO_D: [O.BRACO_D, O.ANTEBRACO_D, 1.0, 1.0],
	PE_E: [O.COXA_E, O.CANELA_E, -1.0, -1.0],
	PE_D: [O.COXA_D, O.CANELA_D, 1.0, -1.0],
}

const FRENTE := Vector3(0.0, 0.0, -1.0)
const TRAS := Vector3(0.0, 0.0, 1.0)
const CIMA := Vector3(0.0, 1.0, 0.0)
const BAIXO := Vector3(0.0, -1.0, 0.0)


## Chave: [duracao ate chegar nela, quadril (posicao), quadril (euler), {osso:
## euler, membro: [alvo, polo]}]. A primeira tem duracao zero: e o corpo deitado
## de onde a mistura parte.
static func _costas() -> Array:
	# Tornozelo em pe: x de repouso, 7 cm do chao, z zero. Os pes que plantam
	# plantam AQUI, para o ficar de pe nao arrastar o pe.
	var pe_e := [Vector3(0.0, 0.07, 0.0), FRENTE]
	var pe_d := [Vector3(0.0, 0.07, 0.0), FRENTE]
	return [
		[0.0, Vector3(0.0, 0.115, 0.62), Vector3(MEIO_PI, 0.0, 0.0), {
			O.TORSO: Vector3.ZERO, O.CABECA: Vector3(-0.2, 0.0, 0.0),
			PE_E: [Vector3(-0.03, 0.08, -0.24), CIMA], PE_D: [Vector3(0.03, 0.08, -0.25), CIMA],
			O.BRACO_E: Vector3(0.05, 0.0, -0.2), O.BRACO_D: Vector3(0.05, 0.0, 0.2),
			O.ANTEBRACO_E: Vector3(0.2, 0.0, 0.0), O.ANTEBRACO_D: Vector3(0.2, 0.0, 0.0),
		}, true],
		# Apoia nos cotovelos: o tronco sobe, a cabeca olha os pes.
		[0.45, Vector3(0.0, 0.115, 0.62), Vector3(1.05, 0.0, 0.0), {
			O.TORSO: Vector3.ZERO, O.CABECA: Vector3(-0.5, 0.0, 0.0),
			PE_E: [Vector3(-0.03, 0.08, -0.24), CIMA], PE_D: [Vector3(0.03, 0.08, -0.25), CIMA],
			MAO_E: [Vector3(0.02, 0.06, 0.84), TRAS], MAO_D: [Vector3(0.02, 0.06, 0.84), TRAS],
		}, true],
		# Sentado, maos atras no chao, o pe direito ja plantado onde vai ficar.
		[0.5, Vector3(0.0, 0.125, 0.58), Vector3(0.3, 0.0, 0.0), {
			O.TORSO: Vector3(-0.12, 0.0, 0.0), O.CABECA: Vector3(-0.1, 0.0, 0.0),
			PE_E: [Vector3(-0.04, 0.08, -0.18), FRENTE + CIMA], PE_D: pe_d,
			MAO_E: [Vector3(0.06, 0.06, 0.86), TRAS], MAO_D: [Vector3(0.06, 0.06, 0.86), TRAS],
		}],
		# O peso vai para os pes: agachado, bracos a frente de contrapeso.
		[0.5, Vector3(0.0, 0.5, 0.3), Vector3(-0.6, 0.0, 0.0), {
			O.TORSO: Vector3(-0.2, 0.0, 0.0), O.CABECA: Vector3(0.45, 0.0, 0.0),
			PE_E: pe_e, PE_D: pe_d,
			MAO_E: [Vector3(0.0, 0.55, -0.32), TRAS + BAIXO],
			MAO_D: [Vector3(0.0, 0.55, -0.32), TRAS + BAIXO],
		}],
		[0.55, Vector3(0.0, 0.9, 0.0), Vector3.ZERO, {PE_E: pe_e, PE_D: pe_d}],
	]


static func _brucos() -> Array:
	var pe_d := [Vector3(0.0, 0.07, 0.0), FRENTE]
	return [
		[0.0, Vector3(0.0, 0.12, 0.32), Vector3(-MEIO_PI, 0.0, 0.0), {
			O.TORSO: Vector3.ZERO, O.CABECA: Vector3(0.3, 0.45, 0.0),
			PE_E: [Vector3(-0.02, 0.17, 1.02), BAIXO], PE_D: [Vector3(0.02, 0.17, 1.02), BAIXO],
			MAO_E: [Vector3(-0.1, 0.09, -0.02), TRAS + CIMA * 0.5],
			MAO_D: [Vector3(0.1, 0.09, -0.02), TRAS + CIMA * 0.5],
		}, true],
		# Flexao: as maos embaixo dos ombros empurram, o peito sai do chao.
		[0.45, Vector3(0.0, 0.12, 0.32), Vector3(-1.15, 0.0, 0.0), {
			O.TORSO: Vector3.ZERO, O.CABECA: Vector3(0.35, 0.0, 0.0),
			PE_E: [Vector3(-0.02, 0.17, 1.02), BAIXO], PE_D: [Vector3(0.02, 0.17, 1.02), BAIXO],
			MAO_E: [Vector3(0.0, 0.09, -0.15), TRAS + CIMA],
			MAO_D: [Vector3(0.0, 0.09, -0.15), TRAS + CIMA],
		}, true],
		# De quatro: joelhos embaixo do quadril, bracos quase retos.
		[0.5, Vector3(0.0, 0.47, 0.3), Vector3(-1.35, 0.0, 0.0), {
			O.TORSO: Vector3.ZERO, O.CABECA: Vector3(0.35, 0.0, 0.0),
			PE_E: [Vector3(0.0, 0.16, 0.69), BAIXO + FRENTE * 0.3],
			PE_D: [Vector3(0.0, 0.16, 0.69), BAIXO + FRENTE * 0.3],
			MAO_E: [Vector3(0.0, 0.06, -0.15), TRAS],
			MAO_D: [Vector3(0.0, 0.06, -0.15), TRAS],
		}],
		# Um joelho so: o pe direito vai a frente e planta onde vai ficar.
		[0.5, Vector3(0.0, 0.5, 0.25), Vector3(-0.2, 0.0, 0.0), {
			O.TORSO: Vector3(-0.1, 0.0, 0.0), O.CABECA: Vector3(0.1, 0.0, 0.0),
			PE_E: [Vector3(0.0, 0.15, 0.72), BAIXO + FRENTE * 0.3], PE_D: pe_d,
			MAO_E: [Vector3(0.05, 0.62, 0.05), TRAS], MAO_D: [Vector3(-0.05, 0.62, -0.18), TRAS],
		}],
		[0.6, Vector3(0.0, 0.9, 0.0), Vector3.ZERO, {
			PE_E: [Vector3(0.0, 0.07, 0.0), FRENTE], PE_D: pe_d}],
	]


static func _cru(de_brucos: bool) -> Array:
	return _brucos() if de_brucos else _costas()


## As chaves, prontas para `pose_em`. A ultima leva a pose parada do proprio
## Corpo nos ossos que ela nao define, para a volta ao controle normal nao dar
## pulo.
static func chaves(de_brucos: bool, corpo: Corpo) -> Array:
	var cru := _cru(de_brucos)
	var s := corpo.altura() / Corpo.ALTURA_REF
	var saida: Array = []
	for i in cru.size():
		var c: Array = cru[i]
		var ossos: Dictionary = (c[3] as Dictionary).duplicate()
		if i == cru.size() - 1:
			var parado := de_pe(corpo)
			for osso: int in parado:
				if not ossos.has(osso):
					ossos[osso] = parado[osso]
		var k := {
			"dur": float(c[0]),
			"pos": (c[1] as Vector3) * s,
			"rot": Basis.from_euler(c[2]).get_rotation_quaternion(),
			"ossos": {},
			"membros": {},
			"assenta": c.size() > 4 and bool(c[4]),
		}
		for chave: Variant in ossos:
			if chave is StringName:
				var alvo: Array = ossos[chave]
				k["membros"][chave] = [_alvo_do_membro(corpo, chave, alvo[0], s),
					(alvo[1] as Vector3).normalized()]
			else:
				k["ossos"][chave] = Basis.from_euler(ossos[chave]).get_rotation_quaternion()
		saida.append(k)
	return saida


## x relativo ao repouso do membro, com o sinal do lado; y e z escalados.
static func _alvo_do_membro(corpo: Corpo, membro: StringName, alvo: Vector3, s: float) -> Vector3:
	var dados: Array = MEMBROS[membro]
	var lado := float(dados[2])
	var rest_x := absf(corpo.esqueleto().get_bone_global_rest(int(dados[0])).origin.x)
	return Vector3(lado * (rest_x + alvo.x), alvo.y * s, alvo.z * s)


## A pose parada de `Corpo._pose_parado` no instante zero da respiracao.
static func de_pe(corpo: Corpo) -> Dictionary:
	var ab := corpo.abducao()
	return {
		O.TORSO: Vector3(-0.01, 0.0, 0.0), O.CABECA: Vector3.ZERO,
		O.COXA_E: Vector3.ZERO, O.COXA_D: Vector3.ZERO,
		O.CANELA_E: Vector3(-0.04, 0.0, 0.0), O.CANELA_D: Vector3(-0.02, 0.0, 0.0),
		O.BRACO_E: Vector3(0.03, 0.0, 0.07 - ab), O.BRACO_D: Vector3(0.03, 0.0, -0.07 + ab),
		O.ANTEBRACO_E: Vector3(0.16, 0.0, 0.0), O.ANTEBRACO_D: Vector3(0.16, 0.0, 0.0),
	}


## Onde o quadril esta deitado na primeira chave, no referencial do corpo. E
## por aqui que o no do Corpo e posto no chao: o quadril da fisica tem de cair
## em cima do quadril da primeira chave.
static func quadril_deitado(de_brucos: bool, corpo: Corpo) -> Vector3:
	return ((_cru(de_brucos)[0] as Array)[1] as Vector3) * (corpo.altura() / Corpo.ALTURA_REF)


static func duracao(ch: Array) -> float:
	var t := 0.0
	for c: Dictionary in ch:
		t += float(c["dur"])
	return t


## A pose em `t` segundos: {-1: posicao do quadril, osso: Quaternion}. Cada
## trecho acelera e freia (smoothstep) — peso de gente mudando de apoio, e nao
## robo em velocidade fixa.
static func pose_em(ch: Array, t: float, corpo: Corpo) -> Dictionary:
	var acumulado := 0.0
	for i in range(1, ch.size()):
		var dur := float((ch[i] as Dictionary)["dur"])
		if t <= acumulado + dur:
			var k := smoothstep(0.0, 1.0, (t - acumulado) / maxf(dur, 0.001))
			return _entre(ch[i - 1], ch[i], k, corpo)
		acumulado += dur
	return _entre(ch[ch.size() - 1], ch[ch.size() - 1], 1.0, corpo)


static func _entre(a: Dictionary, b: Dictionary, k: float, corpo: Corpo) -> Dictionary:
	var sk := corpo.esqueleto()
	var pose := {}
	pose[-1] = (a["pos"] as Vector3).lerp(b["pos"], k)
	pose[O.QUADRIL] = (a["rot"] as Quaternion).slerp(b["rot"], k)
	var oa: Dictionary = a["ossos"]
	var ob: Dictionary = b["ossos"]
	for osso: int in [O.TORSO, O.CABECA]:
		pose[osso] = (oa.get(osso, Quaternion.IDENTITY) as Quaternion).slerp(
			ob.get(osso, Quaternion.IDENTITY), k)
	# O tronco pousa no chao: sobe sempre que a pele dele entraria no piso, e
	# desce ate encostar nas chaves marcadas como deitadas. E o que deixa a
	# barriga do gordo em cima do asfalto sem uma tabela por corpo.
	var folga := _folga_do_tronco(corpo, pose)
	var assenta := lerpf(1.0 if a.get("assenta", false) else 0.0,
		1.0 if b.get("assenta", false) else 0.0, k)
	if folga < 0.0:
		pose[-1] = (pose[-1] as Vector3) + Vector3(0.0, -folga, 0.0)
	else:
		pose[-1] = (pose[-1] as Vector3) - Vector3(0.0, folga * assenta, 0.0)
	# Pais dos membros, ja na pose interpolada.
	var quadril := Transform3D(Basis(pose[O.QUADRIL] as Quaternion), pose[-1])
	var tronco := quadril * Transform3D(Basis(pose[O.TORSO] as Quaternion),
		sk.get_bone_rest(O.TORSO).origin)
	var ma: Dictionary = a["membros"]
	var mb: Dictionary = b["membros"]
	for membro: StringName in MEMBROS:
		var d: Array = MEMBROS[membro]
		var cima := int(d[0])
		var baixo := int(d[1])
		var pai := tronco if cima == O.BRACO_E or cima == O.BRACO_D else quadril
		if ma.has(membro) and mb.has(membro):
			# Alvo contra alvo: interpola o PONTO, e o pe plantado fica plantado.
			var pa: Array = ma[membro]
			var pb: Array = mb[membro]
			var polo := (pa[1] as Vector3).lerp(pb[1], k)
			var r := _ik_no_chao(corpo, pai, cima, (pa[0] as Vector3).lerp(pb[0], k), polo,
				float(d[3]))
			pose[cima] = r[0]
			pose[baixo] = r[1]
		else:
			var qa := _membro_em(corpo, a, membro, _pai_da_chave(corpo, a, cima))
			var qb := _membro_em(corpo, b, membro, _pai_da_chave(corpo, b, cima))
			pose[cima] = (qa[0] as Quaternion).slerp(qb[0], k)
			pose[baixo] = (qa[1] as Quaternion).slerp(qb[1], k)
	return pose


## O pai do membro (tronco ou quadril) na pose da propria chave, com o tronco
## ja pousado no chao como `_entre` pousa.
static func _pai_da_chave(corpo: Corpo, c: Dictionary, osso: int) -> Transform3D:
	var pose := {-1: c["pos"], O.QUADRIL: c["rot"],
		O.TORSO: (c["ossos"] as Dictionary).get(O.TORSO, Quaternion.IDENTITY),
		O.CABECA: (c["ossos"] as Dictionary).get(O.CABECA, Quaternion.IDENTITY)}
	var folga := _folga_do_tronco(corpo, pose)
	var pos: Vector3 = c["pos"]
	if folga < 0.0 or c.get("assenta", false):
		pos.y -= folga
	var quadril := Transform3D(Basis(c["rot"] as Quaternion), pos)
	if osso == O.BRACO_E or osso == O.BRACO_D:
		var t: Quaternion = (c["ossos"] as Dictionary).get(O.TORSO, Quaternion.IDENTITY)
		return quadril * Transform3D(Basis(t), corpo.esqueleto().get_bone_rest(O.TORSO).origin)
	return quadril


static func _membro_em(corpo: Corpo, c: Dictionary, membro: StringName, pai: Transform3D) -> Array:
	var d: Array = MEMBROS[membro]
	var m: Dictionary = c["membros"]
	if m.has(membro):
		var alvo: Array = m[membro]
		return _ik_no_chao(corpo, pai, int(d[0]), alvo[0], alvo[1], float(d[3]))
	var o: Dictionary = c["ossos"]
	return [o.get(int(d[0]), Quaternion.IDENTITY), o.get(int(d[1]), Quaternion.IDENTITY)]


## Raio da junta do meio (joelho com a calca, cotovelo com a manga): o quanto
## ela fica acima do chao quando encosta nele.
const RAIO_JOELHO := 0.065
const RAIO_COTOVELO := 0.05


## IK que respeita o chao, em duas protecoes:
##
## - a junta do meio nao entra no piso. Se o joelho (ou o cotovelo) do IK cai
##   abaixo do raio dele, a perna gira em volta do eixo quadril-tornozelo ate
##   ele sair: o menor giro que resolve. E o joelho que, entre "de bruços" e
##   "de quatro", arrastava meia coxa por baixo do asfalto.
## - a ponta rigida nao entra no piso. Sem osso de tornozelo, o sapato e parte
##   da canela: canela inclinada para a frente enterra o bico, para tras
##   enterra o calcanhar. O alvo sobe o que falta e o IK roda de novo; agachado,
##   a pessoa fica na ponta do pe, que e o que gente faz.
static func _ik_no_chao(corpo: Corpo, pai: Transform3D, cima: int, alvo: Vector3,
		polo: Vector3, dobra: float) -> Array:
	var sk := corpo.esqueleto()
	var baixo := cima + 1
	# Perna de gordo e mais grossa no joelho: o raio cresce com a gordura.
	var g := Anatomia.gordura(corpo.aparencia())
	var raio := (RAIO_COTOVELO + 0.02 * g) if dobra > 0.0 else (RAIO_JOELHO + 0.04 * g)
	var r: Array = []
	var destino := alvo
	for tentativa in 3:
		r = _ik(corpo, pai, cima, destino, polo, dobra)
		var ombro := pai * sk.get_bone_rest(cima).origin
		var g_cima := pai * Transform3D(Basis(r[0] as Quaternion), sk.get_bone_rest(cima).origin)
		var junta := g_cima * sk.get_bone_rest(baixo).origin
		if junta.y < raio:
			var giro := _giro_para_cima(ombro, destino, junta, raio)
			if giro != 0.0:
				var eixo := (destino - ombro).normalized()
				var nova := Basis(eixo, giro) * g_cima.basis
				r[0] = (pai.basis.inverse() * nova).orthonormalized().get_rotation_quaternion()
				g_cima = pai * Transform3D(Basis(r[0] as Quaternion), sk.get_bone_rest(cima).origin)
		var g_baixo := g_cima * Transform3D(Basis(r[1] as Quaternion), sk.get_bone_rest(baixo).origin)
		var menor := INF
		for ponta: Vector3 in _pontas(corpo, baixo):
			menor = minf(menor, (g_baixo * ponta).y)
		if menor >= -0.004:
			break
		destino.y += -menor
	return r


## Menor giro (em volta do eixo ombro-alvo) que poe `junta` a `raio` do chao.
## Zero quando nao ha giro que resolva: ai fica o melhor que o IK achou.
static func _giro_para_cima(ombro: Vector3, alvo: Vector3, junta: Vector3, raio: float) -> float:
	var eixo := (alvo - ombro)
	if eixo.length() < 0.001:
		return 0.0
	eixo = eixo.normalized()
	var centro := ombro + eixo * (junta - ombro).dot(eixo)
	var u := junta - centro
	if u.length() < 0.001:
		return 0.0
	var v := eixo.cross(u)
	# y(phi) = centro.y + u.y cos(phi) + v.y sin(phi)
	var m := sqrt(u.y * u.y + v.y * v.y)
	if m < 0.0001:
		return 0.0
	var delta := atan2(v.y, u.y)
	var c0 := (raio - centro.y) / m
	if c0 > 1.0:
		return delta
	var largura := acos(clampf(c0, -1.0, 1.0))
	# O intervalo bom e [delta - largura, delta + largura]: a ponta mais perto
	# de zero.
	var d1 := wrapf(delta - largura, -PI, PI)
	var d2 := wrapf(delta + largura, -PI, PI)
	return d1 if absf(d1) < absf(d2) else d2


## Pontas rigidas presas ao osso de baixo, no referencial dele: bico e
## calcanhar do sapato (`Anatomia.sapato`), ponta dos dedos (`Anatomia.mao`).
static func _pontas(corpo: Corpo, baixo: int) -> Array:
	var s := corpo.altura() / Corpo.ALTURA_REF
	if baixo == O.CANELA_E or baixo == O.CANELA_D:
		var y := -Corpo.Y_JOELHO * s + 0.004
		return [Vector3(0.0, y, -0.175), Vector3(0.0, y, 0.082)]
	return [Vector3(0.0, -(Corpo.Y_COTOVELO - 0.71) * s, 0.0)]


## Quanto a pele do tronco (quadril, tronco, cabeca) esta acima do chao no
## ponto mais baixo. Negativo: esta dentro dele.
static func _folga_do_tronco(corpo: Corpo, pose: Dictionary) -> float:
	var sk := corpo.esqueleto()
	var amostras := _amostras_do_tronco(corpo)
	var quadril := Transform3D(Basis(pose[O.QUADRIL] as Quaternion), pose[-1])
	var tronco := quadril * Transform3D(Basis(pose.get(O.TORSO, Quaternion.IDENTITY) as Quaternion),
		sk.get_bone_rest(O.TORSO).origin)
	var cabeca := tronco * Transform3D(Basis(pose.get(O.CABECA, Quaternion.IDENTITY) as Quaternion),
		sk.get_bone_rest(O.CABECA).origin)
	var menor := INF
	for p: Vector3 in amostras[O.QUADRIL]:
		menor = minf(menor, (quadril * p).y)
	for p: Vector3 in amostras[O.TORSO]:
		menor = minf(menor, (tronco * p).y)
	for p: Vector3 in amostras[O.CABECA]:
		menor = minf(menor, (cabeca * p).y)
	return menor


## Pontos da pele do tronco, por osso, no referencial do osso: frente, costas e
## lados em sete alturas (do perfil do proprio corpo), e os cantos da cabeca.
static func _amostras_do_tronco(corpo: Corpo) -> Dictionary:
	if corpo.has_meta(&"_amostras_do_tronco"):
		return corpo.get_meta(&"_amostras_do_tronco")
	var sk := corpo.esqueleto()
	var s := corpo.altura() / Corpo.ALTURA_REF
	var perfil := corpo.perfil()
	var saida := {O.QUADRIL: [], O.TORSO: [], O.CABECA: []}
	var y_torso := sk.get_bone_global_rest(O.TORSO).origin.y
	var y_quadril := sk.get_bone_global_rest(O.QUADRIL).origin.y
	for y_ref: float in [0.82, 0.9, 1.0, 1.1, 1.2, 1.3, 1.38]:
		var m := Anatomia.medida(perfil, y_ref)
		var osso := O.QUADRIL if y_ref < 0.96 else O.TORSO
		var base := y_quadril if osso == O.QUADRIL else y_torso
		var y := y_ref * s - base
		for p: Vector3 in [Vector3(0.0, y, -m.y), Vector3(0.0, y, m.z),
				Vector3(m.x, y, 0.0), Vector3(-m.x, y, 0.0),
				Vector3(m.x * 0.7, y, -m.y * 0.7), Vector3(-m.x * 0.7, y, -m.y * 0.7),
				Vector3(m.x * 0.7, y, m.z * 0.7), Vector3(-m.x * 0.7, y, m.z * 0.7)]:
			(saida[osso] as Array).append(p)
	for x: float in [-0.107, 0.107]:
		for y: float in [0.04 * s, 0.31 * s]:
			for z: float in [-0.12, 0.12]:
				(saida[O.CABECA] as Array).append(Vector3(x, y, z))
	corpo.set_meta(&"_amostras_do_tronco", saida)
	return saida


## IK de dois ossos, analitico. `pai` e a transformada (no referencial do
## corpo) do osso-pai do membro; `alvo` e o punho ou o tornozelo; `polo` e para
## onde o cotovelo ou o joelho aponta; `dobra` e o sinal da flexao do osso de
## baixo (+1 antebraco, -1 canela, ver `Corpo._girar`).
##
## A dobra e so em x local, como no esqueleto: o cotovelo e o joelho sao
## dobradicas. No referencial do osso de cima, o punho fica em
## h = (0, -l1, 0) + Rx(dobra * e) (0, -l2, 0); a rotacao do osso de cima e a
## que leva h para a direcao do alvo e poe a junta do meio do lado do polo.
static func _ik(corpo: Corpo, pai: Transform3D, cima: int, alvo: Vector3, polo: Vector3,
		dobra: float) -> Array:
	var sk := corpo.esqueleto()
	# O osso de baixo e o seguinte no enum (braco/antebraco, coxa/canela).
	var baixo := cima + 1
	var l1 := sk.get_bone_rest(baixo).origin.length()
	var s := corpo.altura() / Corpo.ALTURA_REF
	var l2 := (Corpo.Y_COTOVELO - Corpo.Y_PUNHO) * s if dobra > 0.0 \
		else (Corpo.Y_JOELHO - Corpo.Y_TORNOZELO) * s
	var ombro := pai * sk.get_bone_rest(cima).origin
	var inv := pai.basis.inverse()
	var d_vec := inv * (alvo - ombro)
	var p := inv * polo
	var d := clampf(d_vec.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var interno := acos(clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0))
	var e := PI - interno
	var q_baixo := Quaternion(Vector3.RIGHT, dobra * e)
	var h := Vector3(0.0, -l1, 0.0) + Basis(q_baixo) * Vector3(0.0, -l2, 0.0)
	var a1 := h.normalized()
	var junta := Vector3(0.0, -l1, 0.0)
	var b1 := (junta - a1 * junta.dot(a1))
	b1 = b1.normalized() if b1.length() > 0.0001 else Vector3(0.0, 0.0, -dobra)
	var a2 := d_vec.normalized() if d_vec.length() > 0.0001 else a1
	var b2 := p - a2 * p.dot(a2)
	if b2.length() < 0.0001:
		b2 = b1 - a2 * b1.dot(a2)
	b2 = b2.normalized()
	var de := Basis(a1, b1, a1.cross(b1))
	var para := Basis(a2, b2, a2.cross(b2))
	var r := (para * de.inverse()).orthonormalized()
	return [r.get_rotation_quaternion(), q_baixo]


static func misturar(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var saida := {}
	for chave: int in b:
		if chave == -1:
			saida[-1] = (a.get(-1, b[-1]) as Vector3).lerp(b[-1], k)
		else:
			var qa: Quaternion = a.get(chave, b[chave])
			saida[chave] = qa.slerp(b[chave], k)
	return saida


static func aplicar(corpo: Corpo, pose: Dictionary) -> void:
	var sk := corpo.esqueleto()
	for chave: int in pose:
		if chave == -1:
			sk.set_bone_pose_position(O.QUADRIL, pose[-1])
		else:
			sk.set_bone_pose_rotation(chave, pose[chave])
