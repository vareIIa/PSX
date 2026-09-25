## A lida de Jota e Helmer com a sacola de colheita, no tempo: o que o corpo
## faz, onde as maos vao e em que instante o saco muda de mao.
##
## As lidas
## --------
##   COLHER     pousa o saco do lado (se ja atrapalha), segura o galho com a
##              esquerda e arranca tres punhados com a direita, cada puxao
##              levando o tronco junto; vira, leva o punhado por cima ate a boca
##              do saco, solta (o saco incha) e soca duas vezes
##   POUSAR     so o braco: quem vai regar ou plantar desce o saco ao chao pelo
##              gargalo, por cima da pose de trabalho
##   PEGAR      agacha, agarra o gargalo com as duas maos, forca (o saco pesado
##              treme o corpo) e joga por cima do ombro esquerdo — o saco cai
##              nas costas com o baque dele
##   ARREMESSO  tira o saco das costas pela esquerda, pousa na frente, embala
##              duas vezes para o lado direito ("um, dois"), agacha e explode:
##              pernas, tronco e bracos para cima, e solta no alto. Acompanha o
##              voo com os olhos, e se o saco era pesado leva a mao a lombar
##   DESPEJAR   so erva comum, na bancada dos potes: levanta o saco pelo fundo,
##              de boca para baixo, e sacode ate murchar; as colas caem no tampo
##   AJEITAR    andando com o saco cheio nas costas, de tempo em tempo: afunda,
##              da o tranco e o saco pula no ombro
##
## Como
## ---
## Cada lida escreve um `GestoDeCarga` a cada quadro: poses-chave do corpo
## (quadril, tronco, pes) interpoladas com passagem suave, e as maos por IK em
## pontos do MUNDO lidos na hora — a boca do saco que balanca, a copa da planta,
## o ombro. E por ler na hora que a mao nao perde o gargalo quando o saco
## balanca. Os marcos (`_marcos`) sao os instantes em que algo muda de dono: o
## saco vai ao chao, a planta sai do vaso, o saco sai da mao. O de "colhe" e da
## `Convidado`, que e quem fala com a Plantacao; os outros sao daqui.
class_name LidaDaSacola
extends RefCounted

enum Tipo { COLHER, POUSAR, PEGAR, ARREMESSO, DESPEJAR, AJEITAR }

## Com quantas plantas o saco ja atrapalha as maos: vai ao chao para trabalhar.
const GRANDE := 3
## Daqui para cima o saco e pesado: pegar do chao tem um tempo de forca, e quem
## arremessa leva a mao a lombar depois.
const PESADO := 0.6
## Os canais do corpo numa pose-chave (ver `GestoDeCarga`).
const CANAIS: Array[String] = ["dobra", "desce", "torcao", "tomba", "recua", "abre", "avanca"]
const NEUTRA := {"abre": 0.05}
## Os tres puxoes da colheita: comeco de cada um e quanto dura.
const PUXOES: Array[float] = [0.95, 1.53, 2.11]
const PUXAO := 0.58

var tipo: Tipo
var t := 0.0
var duracao := 1.0
var gesto := GestoDeCarga.new()
var dono: Node3D
var corpo: Corpo
var saco: SacolaDeColheita
## COLHER: a copa (mundo) e a variedade. DESPEJAR: o tampo da bancada.
var alvo := Vector3.ZERO
var variedade: StringName = &"comum"
## ARREMESSO: a vaga na pilha (mundo, ja sentada), o raio do saco la e quem
## avisar quando ele pousar.
var para := Transform3D()
var raio_final := 0.3
var ao_pousar := Callable()
## O que a Plantacao devolveu no marco "colhe": 0, a planta ja nao estava la.
var colheu := -1

var _marcos: Dictionary = {}
var _grande := false
var _pesado := false
var _esforco := 0.0
var _solto := false
var _pega := Vector3.ZERO
var _punhado: MeshInstance3D
var _colas := 0
## Onde o saco vai ao chao (mundo) e de que lado de quem trabalha (-1 esquerda,
## 1 direita), lido uma vez, no primeiro quadro.
var _lugar := Vector3.INF
var _lado := -1.0


func _init(tipo_: Tipo, dono_: Node3D, corpo_: Corpo, saco_: SacolaDeColheita) -> void:
	tipo = tipo_
	dono = dono_
	corpo = corpo_
	saco = saco_
	_grande = saco.plantas >= GRANDE
	_pesado = saco.fracao() >= PESADO
	match tipo:
		Tipo.COLHER:
			duracao = 3.9
			_marcos = {&"puxa": PUXOES[0] + PUXAO * 0.5, &"puxa2": PUXOES[1] + PUXAO * 0.5,
				&"puxa3": PUXOES[2] + PUXAO * 0.5, &"colhe": 2.5, &"guarda": 3.12,
				&"soca": 3.3, &"soca2": 3.51}
			if _grande:
				_marcos[&"pousa"] = 0.08
		Tipo.POUSAR:
			duracao = 0.8
			gesto.aditivo = true
			_marcos = {&"pousa": 0.05}
		Tipo.PEGAR:
			_esforco = 0.4 if _pesado else 0.0
			duracao = 1.35 + _esforco
			_marcos = {&"agarra": 0.42, &"ombro": 0.9 + _esforco}
		Tipo.ARREMESSO:
			duracao = 3.7
			_marcos = {&"segura": 0.32, &"solta": 1.7}
		Tipo.DESPEJAR:
			duracao = 3.3
			_marcos = {&"segura": 0.32, &"vira": 0.75, &"esvazia": 1.45, &"desvira": 2.2,
				&"larga": 2.5}
		Tipo.AJEITAR:
			duracao = 0.75
			gesto.aditivo = true
			_marcos = {&"tranco": 0.3}


## A lida manda no corpo inteiro (a postura de baixo e a de parado), ou so
## soma por cima do que ele ja faz.
func domina() -> bool:
	return tipo != Tipo.POUSAR and tipo != Tipo.AJEITAR


func acabou() -> bool:
	return t >= duracao


## Um quadro, ANTES de o corpo posar. Devolve os marcos que passaram agora.
func passo(delta: float) -> Array[StringName]:
	if not _lugar.is_finite() and (tipo == Tipo.POUSAR or (tipo == Tipo.COLHER and _grande)):
		var b0 := dono.global_basis.orthonormalized()
		_lugar = saco.lugar_para_pousar(dono.global_position, b0)
		_lado = signf((b0.inverse() * (_lugar - dono.global_position)).x)
		if _lado == 0.0:
			_lado = -1.0
	var antes := t
	t += delta
	gesto.relogio = t
	var saiu: Array[StringName] = []
	for m: StringName in _marcos:
		var tm: float = _marcos[m]
		if antes < tm and t >= tm:
			saiu.append(m)
			_no_marco(m)
	var pe := dono.global_position
	var b := dono.global_basis.orthonormalized()
	match tipo:
		Tipo.COLHER:
			_colher(pe, b)
		Tipo.POUSAR:
			_pousar()
		Tipo.PEGAR:
			_pegar(pe, b)
		Tipo.ARREMESSO:
			_arremesso(pe, b)
		Tipo.DESPEJAR:
			_despejar(pe, b)
		Tipo.AJEITAR:
			_ajeitar()
	return saiu


## Depois de o corpo posar: o punhado vai na mao deste quadro, e nao na do outro.
func depois_de_posar() -> void:
	if _punhado != null and _punhado.visible:
		_punhado.global_transform = corpo.pega_no_mundo()


## Interrompida (tombo, saiu andando): o que ja mudou de dono tem de chegar.
## O saco que ia voar voa; o que ia murchar murcha; a planta arrancada entra.
func cancelar() -> void:
	match tipo:
		Tipo.ARREMESSO:
			if not _solto:
				_soltar_na_pilha()
		Tipo.DESPEJAR:
			if t < float(_marcos[&"esvazia"]):
				saco.esvaziar()
		Tipo.COLHER:
			if colheu > 0 and t < float(_marcos[&"guarda"]):
				saco.guardar(variedade, colheu)
	encerrar()


func encerrar() -> void:
	if saco.nas_maos():
		saco.soltar()
	saco.virar(false)
	if _punhado != null:
		_punhado.queue_free()
		_punhado = null
	gesto.peso = 0.0
	corpo.olhar_lateral(0.0)


# --- os marcos --------------------------------------------------------------

func _no_marco(m: StringName) -> void:
	var pe := dono.global_position
	var b := dono.global_basis.orthonormalized()
	match m:
		&"pousa":
			# De preferencia do lado esquerdo, um pouco atras (fora do caminho
			# das maos e do vaso): o primeiro lugar livre (`lugar_para_pousar`).
			saco.pousar(_lugar if _lugar.is_finite() else pe - b.x * 0.7)
		&"puxa", &"puxa2", &"puxa3":
			_colas += 1
			_mostrar_punhado()
			AudioDirector.tocar(&"pegar", alvo, -17.0, 1.35)
		&"guarda":
			if _punhado != null:
				_punhado.visible = false
			if colheu > 0:
				saco.guardar(variedade, colheu)
		&"soca", &"soca2":
			saco.amassar(2.4)
			saco.empurrar(Vector3.DOWN * 0.5)
		&"agarra":
			_pega = saco.boca()
			saco.levantar()
			saco.segurar(_pega)
		&"ombro":
			saco.soltar()
			# O embalo que o joga por cima do ombro, para as costas.
			saco.empurrar(Vector3.UP * 0.45 + b.z * 0.7)
			AudioDirector.tocar(&"baque_corpo_%d" % (1 + saco.plantas % 3), saco.global_position,
				-15.0, 1.25)
		&"segura":
			_pega = saco.boca()
			saco.segurar(_pega)
		&"solta":
			_soltar_na_pilha()
		&"vira":
			saco.virar(true)
		&"esvazia":
			_chuva_de_colas()
			saco.esvaziar()
		&"desvira":
			saco.virar(false)
		&"larga":
			saco.soltar()
		&"tranco":
			saco.empurrar(Vector3.UP * 2.2 + b.z * 0.5)
			AudioDirector.tocar(&"arrasto_corpo", saco.global_position, -17.0, 1.4)


func _soltar_na_pilha() -> void:
	if _solto:
		return
	_solto = true
	saco.soltar()
	saco.arremessar(para, raio_final, ao_pousar)


# --- as lidas ---------------------------------------------------------------

func _colher(pe: Vector3, b: Basis) -> void:
	var dir := b.x
	# Da copa para quem colhe, no chao: e para onde o puxao traz a mao.
	var ate := pe - alvo
	ate.y = 0.0
	ate = ate.normalized() if ate.length() > 0.01 else b.z
	# Quanto dobrar e descer para as maos chegarem a copa, pela altura dela: a
	# Morcega pende do teto (olha para cima), o bonsai esta na mesa, a lavoura
	# na altura do quadril.
	var h := alvo.y - pe.y
	var colhe := {"dobra": remap(clampf(h, 0.55, 1.6), 0.55, 1.6, 0.8, -0.12),
		"desce": remap(clampf(h, 0.35, 0.95), 0.35, 0.95, 0.3, 0.04),
		"abre": 0.1, "avanca": 0.14}
	colhe["recua"] = maxf(0.0, float(colhe["dobra"])) * 0.06
	var boca := saco.boca()
	var guarda := _virar_para(pe, b, boca)
	var chaves: Array = [[0.0, NEUTRA]]
	if _grande:
		var pousa := {"dobra": 0.5, "desce": 0.18, "torcao": -0.45 * _lado, "tomba": 0.06 * _lado,
			"recua": 0.03, "abre": 0.12}
		chaves.append_array([[0.35, pousa], [0.55, pousa]])
	chaves.append_array([[0.85, colhe], [2.5, colhe], [2.95, guarda], [3.55, guarda],
		[3.9, NEUTRA]])
	var p := _pose(t, chaves)
	# Cada cola que sai puxa o tronco um tico para tras.
	var tranco := _tranco_do_puxao()
	p["dobra"] = float(p["dobra"]) - 0.09 * tranco
	p["desce"] = float(p["desce"]) - 0.015 * tranco
	_por(p)

	# A direita: chega, entra na copa, agarra, puxa — tres vezes — e leva o
	# punhado por cima ate a boca do saco, solta e soca.
	var fim := PUXOES[2] + PUXAO
	var d: Vector3
	if t < PUXOES[0]:
		d = _fora(0, ate, dir)
	elif t < fim:
		var i := clampi(int((t - PUXOES[0]) / PUXAO), 0, 2)
		var u := (t - PUXOES[i]) / PUXAO
		var de := _fora(maxi(i - 1, 0), ate, dir)
		var dentro := _dentro(i, ate, dir)
		if u < 0.35:
			d = de.lerp(dentro, smoothstep(0.0, 0.35, u))
		elif u < 0.5:
			d = dentro
		else:
			d = dentro.lerp(_fora(i, ate, dir), smoothstep(0.5, 0.8, u))
	else:
		var acima := boca + Vector3.UP * 0.16
		var funda := boca + Vector3.DOWN * 0.05
		if t < 2.98:
			var u := smoothstep(fim, 2.98, t)
			d = _fora(2, ate, dir).lerp(acima, u) + Vector3.UP * 0.18 * sin(PI * u)
		elif t < 3.12:
			d = acima.lerp(funda, smoothstep(2.98, 3.12, t))
		else:
			# Socando: duas descidas curtas dentro da boca.
			var soca := absf(sin(PI * clampf((t - 3.2) / 0.21, 0.0, 2.0)))
			d = funda + Vector3.UP * (0.04 - 0.09 * soca * (1.0 - smoothstep(3.6, 3.7, t)))
	gesto.mao_d = d
	gesto.peso_d = smoothstep(0.45, 0.85, t) * (1.0 - smoothstep(3.6, 3.88, t))
	if _grande and _lado > 0.0 and t < 0.85:
		# Saco a direita: e a direita que o desce pelo gargalo.
		gesto.mao_d = boca.lerp(d, smoothstep(0.55, 0.85, t))
		gesto.peso_d = smoothstep(0.0, 0.18, t)

	# A esquerda: desce o saco pelo gargalo, segura o galho enquanto a direita
	# arranca, e segura a borda da boca aberta para o punhado entrar.
	var caule := alvo + ate * 0.1 - dir * 0.1 + Vector3.UP * 0.16 + ate * 0.035 * tranco
	var perto := pe - boca
	perto.y = 0.0
	var borda := boca + perto.normalized() * saco.raio() * 0.35 + Vector3.UP * 0.03
	var e_chaves: Array = []
	var esquerda := _grande and _lado < 0.0
	if esquerda:
		e_chaves = [[0.0, boca], [0.55, boca]]
	# Com o saco a direita, a esquerda nao atravessa o corpo para a borda: larga
	# o galho quando a planta sai.
	var na_borda := _lado < 0.0 or not _grande
	var fim_e := borda if na_borda else caule
	e_chaves.append_array([[0.85, caule], [2.5, caule], [2.9, fim_e], [3.6, fim_e]])
	gesto.mao_e = _ponto(t, e_chaves)
	var solta_e := (1.0 - smoothstep(3.55, 3.85, t)) if na_borda else (1.0 - smoothstep(2.55, 2.95, t))
	gesto.peso_e = (smoothstep(0.0, 0.18, t) if esquerda else smoothstep(0.5, 0.85, t)) * solta_e
	gesto.cotovelo_d = Vector3(0.55, -0.75, 0.35)
	gesto.peso = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(3.6, 3.9, t))
	if _grande and t < 0.55:
		_olhar(boca)
	elif t < 2.62 or t > 3.62:
		_olhar(alvo)
	else:
		_olhar(boca)


func _dentro(i: int, ate: Vector3, dir: Vector3) -> Vector3:
	var f := float(i)
	return alvo + ate * 0.06 + dir * (0.07 * sin(f * 2.3 + 0.4)) \
		+ Vector3.UP * (0.09 * cos(f * 1.9))


func _fora(i: int, ate: Vector3, dir: Vector3) -> Vector3:
	return _dentro(i, ate, dir) + ate * 0.17 + Vector3.DOWN * 0.03


## 0 a 1 no meio de cada puxao (o tranco para tras), 0 fora.
func _tranco_do_puxao() -> float:
	for t0: float in PUXOES:
		var u := (t - t0) / PUXAO
		if u >= 0.5 and u < 0.8:
			return sin(PI * (u - 0.5) / 0.3)
	return 0.0


## A pose de quem se vira para `ponto` e se abaixa ate ele: o quanto torce pelo
## angulo, e o quanto dobra e desce pela altura.
func _virar_para(pe: Vector3, b: Basis, ponto: Vector3) -> Dictionary:
	var rel := b.inverse() * (ponto - pe)
	var giro := clampf(atan2(-rel.x, -rel.z), -1.2, 1.2)
	var hb := ponto.y - pe.y
	return {"dobra": remap(clampf(hb, 0.35, 1.5), 0.35, 1.5, 0.75, 0.0),
		"desce": remap(clampf(hb, 0.3, 0.95), 0.3, 0.95, 0.28, 0.02),
		"torcao": giro * 0.7, "tomba": 0.04 * signf(giro), "recua": 0.03, "abre": 0.14}


func _pousar() -> void:
	gesto.mao_e = saco.boca()
	gesto.peso_e = 1.0
	gesto.torcao = 0.22 * sin(PI * clampf(t / duracao, 0.0, 1.0))
	gesto.peso = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.55, 0.8, t))
	_olhar(saco.boca())


func _pegar(pe: Vector3, b: Basis) -> void:
	var e := _esforco
	var boca := _pega if saco.nas_maos() or t >= 0.42 else saco.boca()
	var abaixa := _virar_para(pe, b, boca)
	abaixa["torcao"] = float(abaixa["torcao"]) * 0.85
	abaixa["abre"] = 0.16
	var chaves: Array = [[0.0, NEUTRA], [0.38, abaixa], [0.5, abaixa]]
	if e > 0.0:
		# A forca: as pernas empurram, o tronco sobe um pouco e o saco nao.
		var forca := abaixa.duplicate()
		forca["dobra"] = float(forca["dobra"]) - 0.2
		forca["desce"] = float(forca["desce"]) + 0.04
		chaves.append([0.5 + e, forca])
	chaves.append_array([
		[0.88 + e, {"dobra": -0.16, "desce": 0.0, "torcao": -0.3, "tomba": 0.07, "abre": 0.1}],
		[1.02 + e, {"dobra": 0.22, "desce": 0.08, "torcao": -0.05, "abre": 0.1}],
		[duracao, NEUTRA]])
	var p := _pose(t, chaves)
	if e > 0.0 and t > 0.5 and t < 0.5 + e:
		# O saco pesado treme o corpo inteiro.
		p["tomba"] = float(p["tomba"]) + sin(t * 55.0) * 0.025
		p["desce"] = float(p["desce"]) + sin(t * 41.0) * 0.006
	_por(p)

	var ombro := _osso(Corpo.Osso.BRACO_E)
	var alto := ombro + Vector3.UP * 0.1 - b.x * 0.02 + b.z * 0.04
	var sobe := 0.05 if e > 0.0 else 0.0
	var h: Vector3
	if t < 0.42:
		h = boca
	elif t < 0.5 + e:
		h = _pega + Vector3.UP * sobe * smoothstep(0.5, 0.5 + e, t)
	else:
		# Por fora, pela esquerda: o saco vem num arco e passa por cima do ombro.
		var u := smoothstep(0.5 + e, 0.88 + e, t)
		var lado := signf((b.inverse() * (_pega - pe)).x)
		h = (_pega + Vector3.UP * sobe).lerp(alto, u) + b.x * 0.3 * lado * sin(PI * u)
	if saco.nas_maos():
		saco.segurar(h)
	gesto.mao_e = h - b.x * 0.03
	var pg := saco.pegada()
	if pg.is_finite():
		# Ja nas costas: a esquerda fica no gargalo, onde a pose de carregar a quer.
		gesto.mao_e = gesto.mao_e.lerp(pg, smoothstep(0.9 + e, 1.15 + e, t))
	gesto.mao_d = h + b.x * 0.03 + Vector3.UP * 0.06
	gesto.peso_e = 1.0
	gesto.peso_d = 1.0 - smoothstep(0.92 + e, 1.15 + e, t)
	gesto.peso = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(duracao - 0.3, duracao, t))
	if t < 0.88 + e:
		_olhar(boca)
	else:
		_olhar(pe - b.z * 3.0 + Vector3.UP * 1.4)


func _arremesso(pe: Vector3, b: Basis) -> void:
	var F := para.origin - pe
	F.y = 0.0
	F = F.normalized() if F.length() > 0.01 else -b.z
	var dir := F.cross(Vector3.UP)
	var R := saco.raio()
	# As maos altas o bastante para o saco apoiar no chao na frente, e nao mais.
	var baixo := clampf(R * 2.0 + 0.12, 0.6, 1.45)
	var Hf := pe + F * 0.5 + Vector3.UP * baixo
	var Hb := pe + dir * 0.42 - F * 0.3 + Vector3.UP * (baixo + 0.1)
	var Hm := pe + F * 0.15 + dir * 0.12 + Vector3.UP * (baixo * 0.7 + 0.2)
	var Ha := pe + F * 0.5 + Vector3.UP * 2.05
	var h: Vector3
	if t < 0.32:
		h = saco.boca()
	elif t < 0.7:
		var u := smoothstep(0.32, 0.7, t)
		h = _pega.lerp(Hf, u) - dir * 0.3 * sin(PI * u)
	elif t < 1.45:
		h = _ponto(t, [[0.7, Hf], [0.93, Hf.lerp(Hb, 0.6)], [1.13, Hf], [1.45, Hb]])
	elif t < 1.85:
		# A explosao: de tras e de baixo, pelo meio, para o alto e a frente — uma
		# curva, e nao uma reta, e mais rapida no meio, onde o saco sai.
		var u := smoothstep(1.45, 1.85, t)
		h = Hb * (1.0 - u) * (1.0 - u) + Hm * 2.0 * u * (1.0 - u) + Ha * u * u
	else:
		h = Ha.lerp(pe + F * 0.45 + Vector3.UP * 1.3, smoothstep(1.85, 2.45, t))
	if saco.nas_maos():
		saco.segurar(h)
	gesto.mao_e = h - dir * 0.05
	gesto.mao_d = h + dir * 0.05 + Vector3.UP * 0.05
	gesto.peso_e = 1.0
	gesto.peso_d = 1.0
	gesto.cotovelo_e = Vector3(-0.7, -0.6, 0.2)
	gesto.cotovelo_d = Vector3(0.7, -0.6, 0.2)

	var frente := {"dobra": 0.4, "desce": 0.18, "abre": 0.18, "avanca": 0.22, "recua": 0.04}
	var chaves: Array = [[0.0, NEUTRA], [0.32, {"dobra": 0.1, "torcao": 0.15, "abre": 0.1}],
		[0.7, frente],
		[0.93, {"dobra": 0.36, "desce": 0.22, "torcao": -0.35, "tomba": 0.04, "abre": 0.18,
			"avanca": 0.22, "recua": 0.04}],
		[1.13, frente],
		[1.45, {"dobra": 0.5, "desce": 0.3, "torcao": -0.7, "tomba": 0.08, "abre": 0.2,
			"avanca": 0.24, "recua": 0.06}],
		[1.72, {"dobra": -0.22, "desce": -0.01, "torcao": 0.3, "tomba": -0.05, "abre": 0.18,
			"avanca": 0.3}],
		[2.1, {"dobra": 0.22, "desce": 0.06, "torcao": 0.08, "abre": 0.18, "avanca": 0.32}],
		[2.5, {"dobra": 0.12, "desce": 0.03, "abre": 0.14, "avanca": 0.2}]]
	if _pesado:
		# "Ai, as costas": as duas maos na lombar e o corpo arqueado para tras.
		chaves.append_array([[2.9, {"dobra": -0.3, "desce": 0.02, "abre": 0.12}],
			[3.3, {"dobra": -0.24, "tomba": 0.06, "abre": 0.12}], [3.7, NEUTRA]])
		var lombar := pe + Vector3.UP * 1.0 * corpo.altura() / Corpo.ALTURA_REF + b.z * 0.17
		var k := smoothstep(2.45, 2.85, t)
		gesto.mao_e = gesto.mao_e.lerp(lombar - b.x * 0.11, k)
		gesto.mao_d = gesto.mao_d.lerp(lombar + b.x * 0.11, k)
		gesto.cotovelo_e = gesto.cotovelo_e.lerp(Vector3(-0.9, -0.1, 0.6), k)
		gesto.cotovelo_d = gesto.cotovelo_d.lerp(Vector3(0.9, -0.1, 0.6), k)
	else:
		chaves.append_array([[2.9, {"dobra": 0.06, "abre": 0.1}], [3.7, NEUTRA]])
		_bater_as_maos(pe, F, dir, 2.45, h)
	_por(_pose(t, chaves))
	gesto.peso = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(3.4, 3.7, t))
	if t < 0.7:
		_olhar(saco.boca())
	elif t < 1.7 or t > 2.7:
		_olhar(para.origin if not _pesado or t < 2.7 else pe + F * 2.0 + Vector3.UP * 3.2)
	else:
		_olhar(saco.global_position)


func _despejar(pe: Vector3, b: Basis) -> void:
	var F := alvo - pe
	F.y = 0.0
	F = F.normalized() if F.length() > 0.01 else -b.z
	var dir := F.cross(Vector3.UP)
	var peito := pe + F * 0.45 + Vector3.UP * 1.25
	var alto := pe + F * 0.5 + Vector3.UP * 1.62
	var h: Vector3
	if t < 0.32:
		h = saco.boca()
	elif t < 0.75:
		var u := smoothstep(0.32, 0.75, t)
		h = _pega.lerp(peito, u) - dir * 0.25 * sin(PI * u)
	elif t < 1.0:
		h = peito.lerp(alto, smoothstep(0.75, 1.0, t))
	elif t < 2.2:
		# Sacudindo: curto e rapido, como quem esvazia saco de verdade.
		var k := smoothstep(1.0, 1.15, t) * (1.0 - smoothstep(2.05, 2.2, t))
		h = alto + Vector3.UP * 0.07 * sin((t - 1.0) * 19.0) * k
	else:
		h = alto.lerp(_osso(Corpo.Osso.BRACO_E) + Vector3.UP * 0.1, smoothstep(2.2, 2.5, t))
	if saco.nas_maos():
		saco.segurar(h)
	gesto.mao_e = h - dir * 0.06
	gesto.mao_d = h + dir * 0.06
	gesto.peso_e = 1.0
	gesto.peso_d = 1.0
	_bater_as_maos(pe, F, dir, 2.5, h)
	var chaves: Array = [[0.0, NEUTRA], [0.32, {"dobra": 0.1, "torcao": 0.15, "abre": 0.1}],
		[0.75, {"dobra": 0.1, "desce": 0.04, "abre": 0.12}],
		[1.0, {"dobra": -0.12, "abre": 0.14}], [2.2, {"dobra": -0.12, "abre": 0.14}],
		[2.5, {"dobra": 0.05, "abre": 0.1}], [3.3, NEUTRA]]
	var p := _pose(t, chaves)
	if t > 1.0 and t < 2.2:
		p["desce"] = float(p["desce"]) + 0.02 * sin((t - 1.0) * 19.0 + 0.8)
	_por(p)
	gesto.peso = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(3.0, 3.3, t))
	_olhar(saco.boca() if t < 0.75 else alvo)


## Bate uma mao na outra, duas vezes, na frente do peito: tirar o po da rafia.
## Comeca em `t0`, saindo de onde as maos estavam (`de`).
func _bater_as_maos(pe: Vector3, F: Vector3, dir: Vector3, t0: float, de: Vector3) -> void:
	if t < t0:
		return
	var c := pe + F * 0.3 + Vector3.UP * 1.12 * corpo.altura() / Corpo.ALTURA_REF
	var k := smoothstep(t0, t0 + 0.3, t)
	var bate := absf(sin(PI * clampf((t - t0 - 0.3) / 0.22, 0.0, 2.0)))
	var vao := 0.035 + 0.07 * bate
	gesto.mao_e = (de - dir * 0.05).lerp(c - dir * vao, k)
	gesto.mao_d = (de + dir * 0.05).lerp(c + dir * vao + Vector3.UP * 0.035 * bate, k)
	gesto.cotovelo_e = Vector3(-0.7, -0.8, 0.1)
	gesto.cotovelo_d = Vector3(0.7, -0.8, 0.1)


func _ajeitar() -> void:
	_por(_pose(t, [[0.0, {}], [0.22, {"dobra": 0.14, "desce": 0.05}],
		[0.36, {"dobra": -0.07, "desce": -0.015}], [0.75, {}]]))
	var pg := saco.pegada()
	if pg.is_finite():
		gesto.mao_e = pg + Vector3.UP * _curva(t, [[0.0, 0.0], [0.22, -0.06], [0.36, 0.07],
			[0.75, 0.0]])
		gesto.peso_e = 1.0
	gesto.peso = smoothstep(0.0, 0.1, t) * (1.0 - smoothstep(0.55, 0.75, t))


# --- o punhado e a chuva de colas -------------------------------------------

func _mostrar_punhado() -> void:
	if _punhado == null:
		_punhado = MeshInstance3D.new()
		_punhado.name = "Punhado"
		_punhado.top_level = true
		_punhado.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dono.add_child(_punhado)
	_punhado.mesh = malha_de_colas(variedade, _colas, hash(dono.get_instance_id()) + 31)
	_punhado.visible = true
	depois_de_posar()


## As colas que caem da boca do saco virado, no tampo da bancada.
func _chuva_de_colas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(dono.get_instance_id()) ^ saco.plantas
	var boca := saco.boca()
	var chao := alvo.y - 0.04
	for k in 3:
		var malha := malha_de_colas(&"comum", 1, rng.randi())
		for j in 3:
			var m := MeshInstance3D.new()
			m.mesh = malha
			m.top_level = true
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dono.add_child(m)
			var p0 := boca + Vector3(rng.randf_range(-0.1, 0.1), 0.0, rng.randf_range(-0.1, 0.1))
			var v := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.2),
				rng.randf_range(-0.5, 0.5))
			var giro := Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0),
				rng.randf_range(-8.0, 8.0))
			m.global_position = p0
			m.visible = false
			var cair := func(x: float) -> void:
				var p := p0 + v * x + Vector3.DOWN * 4.9 * x * x
				p.y = maxf(p.y, chao)
				m.global_transform = Transform3D(Basis.from_euler(giro * minf(x, 0.5)), p)
			var tw := m.create_tween()
			tw.tween_interval(float(k * 3 + j) * 0.05)
			tw.tween_callback(m.show)
			tw.tween_method(cair, 0.0, 0.9, 0.9)
			tw.tween_callback(m.queue_free)


## `n` colas da variedade saindo de um ponto (o punho), em leque para -Y — a
## base da mao que segura (`Corpo.pega_no_mundo`): os caules no punho e as
## colas para fora dos dedos.
static func malha_de_colas(v: StringName, n: int, semente: int) -> ArrayMesh:
	var obra := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	for k in n:
		var a := float(k) / maxf(float(n), 1.0) * TAU + rng.randf() * 0.6
		var eixo := (Vector3.DOWN + Vector3(cos(a), 0.0, sin(a)) * 0.45).normalized()
		SacolaDeColheita._cola_da_boca(obra, eixo * 0.02, eixo, rng.randf_range(0.13, 0.19),
			rng.randf_range(0.026, 0.034), rng, v)
	var am := ArrayMesh.new()
	for nome: StringName in obra:
		var bd: KitEstufa.Balde = obra[nome]
		if bd.i.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = bd.v
		arr[Mesh.ARRAY_NORMAL] = bd.n
		arr[Mesh.ARRAY_TEX_UV] = bd.uv
		arr[Mesh.ARRAY_COLOR] = bd.c
		arr[Mesh.ARRAY_INDEX] = bd.i
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, Interiores.material(nome))
	return am


# --- ajudas -----------------------------------------------------------------

## Poses-chave [[tempo, {canal: valor}], ...] com passagem suave (smoothstep)
## de uma para a seguinte. Canal ausente vale 0.
static func _pose(x: float, chaves: Array) -> Dictionary:
	var a: Array = chaves[0]
	if x > float(a[0]):
		for k in range(1, chaves.size()):
			var c: Array = chaves[k]
			if x <= float(c[0]):
				var u := smoothstep(float(a[0]), float(c[0]), x)
				var saida := {}
				for canal: String in CANAIS:
					saida[canal] = lerpf(float((a[1] as Dictionary).get(canal, 0.0)),
						float((c[1] as Dictionary).get(canal, 0.0)), u)
				return saida
			a = c
	var fixa := {}
	for canal: String in CANAIS:
		fixa[canal] = float((a[1] as Dictionary).get(canal, 0.0))
	return fixa


static func _ponto(x: float, chaves: Array) -> Vector3:
	var a: Array = chaves[0]
	if x <= float(a[0]):
		return a[1]
	for k in range(1, chaves.size()):
		var c: Array = chaves[k]
		if x <= float(c[0]):
			return (a[1] as Vector3).lerp(c[1], smoothstep(float(a[0]), float(c[0]), x))
		a = c
	return a[1]


static func _curva(x: float, chaves: Array) -> float:
	var a: Array = chaves[0]
	if x <= float(a[0]):
		return a[1]
	for k in range(1, chaves.size()):
		var c: Array = chaves[k]
		if x <= float(c[0]):
			return lerpf(float(a[1]), float(c[1]), smoothstep(float(a[0]), float(c[0]), x))
		a = c
	return a[1]


func _por(p: Dictionary) -> void:
	gesto.dobra = float(p.get("dobra", 0.0))
	gesto.desce = float(p.get("desce", 0.0))
	gesto.torcao = float(p.get("torcao", 0.0))
	gesto.tomba = float(p.get("tomba", 0.0))
	gesto.recua = float(p.get("recua", 0.0))
	gesto.abre = float(p.get("abre", 0.0))
	gesto.avanca = float(p.get("avanca", 0.0))


## Onde fica a junta de um osso no mundo, com a pose do ultimo quadro.
func _osso(o: int) -> Vector3:
	var sk := corpo.esqueleto()
	return sk.global_transform * sk.get_bone_global_pose(o).origin


## A cabeca olha para `ponto`, descontando o quanto o tronco ja dobrou e girou
## (a cabeca vai com ele): sem isso, quem se dobra para colher olharia os pes.
func _olhar(ponto: Vector3) -> void:
	var k := clampf(gesto.peso, 0.0, 1.0)
	var pe := dono.global_position
	var olhos := pe + Vector3.UP * (corpo.altura_da_boca() - gesto.desce * k)
	var d := dono.global_basis.orthonormalized().inverse() * (ponto - olhos)
	var giro := atan2(-d.x, -d.z)
	var pitch := atan2(-d.y, maxf(Vector2(d.x, d.z).length(), 0.05))
	if not gesto.aditivo:
		giro -= gesto.torcao * k
		pitch -= gesto.dobra * k * 0.85
	corpo.olhar_lateral(giro, pitch)
