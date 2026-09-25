## Um encapuzado subindo no carro: o corpo inteiro posto a cada quadro a partir
## de onde as maos, os joelhos e os pes estao apoiados na lataria.
##
## Por que existe
## --------------
## O `Corpo` sabe andar, parar, sentar, agachar. Nao sabe agarrar a borda de um
## capo, puxar o peso, subir o joelho e rastejar em cima de uma chapa inclinada:
## nenhuma pose dele tem as maos presas num lugar do MUNDO enquanto o tronco se
## mexe. E e isso que separa escalar de deslizar — a mao que chegou na chapa nao
## sai dali ate a proxima pegada, e o corpo e que vai ate ela.
##
## Como funciona
## -------------
## Duas pistas, as duas no espaco do CARRO (o corpo e filho dele, e balanca
## junto quando a suspensao afunda):
##
## - o corpo: chaves de tempo com o quadril (onde esta e para onde a pelve
##   aponta), o tronco dobrado sobre ela, a cabeca olhando um ponto, e o piso do
##   pano (a altura em que a batina deita). Entre duas chaves, uma curva de tempo
##   escolhida por chave: o puxao pesado, o estalo que passa do ponto e volta, o
##   bote que acelera ate bater.
## - os membros: cada mao e cada perna tem os seus apoios. Um apoio e um ponto da
##   lataria e um tempo de ida; entre dois apoios o membro levanta em arco e cai
##   no seguinte, e enquanto nao ha passo novo ele FICA onde apoiou. O IK de dois
##   ossos do levantar (`LevantarDoChao._ik`) poe braco e perna ate la; a perna
##   que apoia no piso usa a versao que nao enterra joelho nem bico
##   (`_ik_no_chao`), com o piso do pano no y zero do esqueleto.
##
## O joelho no capo e o apoio que manda no quadril: quem esta de joelhos nao
## escolhe a altura do quadril, ela e a coxa em cima do joelho. Com os joelhos
## apoiados, a altura pedida pela pista e corrigida para a coxa caber.
##
## Por cima, o que faz ele nao ser gente: o tremor fino que nunca para, a
## cabeca que estala para uma pose e fica, e as pausas no meio do movimento
## (que moram na propria pista).
##
## O `Corpo` fica `dominado`: a pose de sempre nao e escrita, so esta. A mao do
## `Corpo` e rigida no antebraco, entao o apoio da mao e pela PONTA dos dedos
## (o antebraco apontando para a chapa, a mao em garra), e nao pela palma.
class_name EscaladorDoCarro
extends RefCounted

enum { MAO_E, MAO_D, PE_E, PE_D }
## Tipo de apoio de um membro.
enum Apoio {
	## Solto: o braco pendurado (ou a perna reta), sem alvo.
	SOLTO,
	## A ponta dos dedos no ponto (a mao em garra na chapa ou no vidro).
	PONTA,
	## O punho no ponto (mao fechada, murro, antebraco na borda).
	PUNHO,
	## O joelho no ponto, a canela deitada para tras na chapa.
	JOELHO,
	## A sola no ponto (agachado na ponta do pe).
	PE,
}

const OSSO_DO_MEMBRO := [Corpo.Osso.BRACO_E, Corpo.Osso.BRACO_D, Corpo.Osso.COXA_E,
	Corpo.Osso.COXA_D]
## Da junta ao que encosta, no corpo de 1,72 m: a ponta dos dedos esta 14 cm
## alem do punho (`LevantarDoChao._pontas`), o raio do joelho com a calca e
## 6,5 cm, a sola 7 cm abaixo do tornozelo.
const MAO_ATE_A_PONTA := 0.14
const RAIO_JOELHO := 0.065
const TORNOZELO := 0.07
## O tremor fino (rad) da cabeca e do tronco, e a respiracao (rad, Hz).
const TREMOR_CABECA := 0.022
const TREMOR_TRONCO := 0.006
const RESPIRA := Vector2(0.035, 0.34)

var corpo: Corpo
var nome: String = ""
var ativo: bool = false
## Congelado: nada anda, nem o tremor. E o quadro em que o celular morre.
var parado: bool = false
var t: float = 0.0
## Multiplica o relogio da pista. >1 corre para caber antes da deixa.
var ritmo: float = 1.0
## 0 a 1: o quanto o tique e o tremor valem agora.
var tique: float = 1.0
## O ultimo estado resolvido, no espaco do carro (para quem mede e mira).
var ultimo: Dictionary = {}

var _esq: Skeleton3D
var _s: float = 1.0
var _chaves: Array = []
var _passos: Array = [[], [], [], []]
## Onde cada membro esta apoiado agora (espaco do carro) e como.
var _apoio_pos: Array = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]
var _apoio_tipo: Array = [Apoio.SOLTO, Apoio.SOLTO, Apoio.SOLTO, Apoio.SOLTO]
var _apoio_polo: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
## O IK de cada membro (0 FK solto, 1 no alvo), para entrar e sair sem salto.
var _peso_ik: Array = [0.0, 0.0, 0.0, 0.0]
var _eventos: Array = []
var _i_evento: int = 0
var _rng := RandomNumberGenerator.new()
var _t_vivo: float = 0.0
## O tique da cabeca: de onde saiu, para onde vai, o tempo do estalo e a espera.
var _tq_de := Vector3.ZERO
var _tq_para := Vector3.ZERO
var _tq_k: float = 1.0
var _tq_dur: float = 0.05
var _tq_espera: float = 0.6
var _tq_lento: bool = false
## Quem ouve o estalo do pescoco (forca de 0 a 1). Opcional.
var ao_estalar: Callable
## Quem ouve um apoio chegando: (membro, ponto no espaco do carro, apoio, forca).
var ao_apoiar: Callable
## A altura do chao debaixo de um ponto (espaco do carro): e o piso do pano. O
## pano deita num plano so, na altura do esqueleto; em cima do carro ele e a
## chapa debaixo do quadril, fora dele o chao. Muda devagar, para o pano nao
## pular.
var piso_de: Callable
var _piso: float = NAN
var _dt: float = 1.0 / 60.0


func _init(c: Corpo, semente: int, nome_: String = "") -> void:
	corpo = c
	nome = nome_
	_esq = c.esqueleto()
	_s = c.altura() / Corpo.ALTURA_REF
	_rng.seed = 7_331 + semente * 104_729
	_t_vivo = _rng.randf() * 10.0
	_tq_espera = _rng.randf_range(0.3, 0.9)


# --- a pista ----------------------------------------------------------------

## Uma chave do corpo em `em` segundos. `k` pode ter:
##   quadril  Vector3  o quadril (a junta), no espaco do carro
##   frente   float    para onde o corpo olha (rad em volta de +Y; 0 e -Z do carro)
##   tronco   Vector3  a espinha inteira sobre a frente (x negativo debruca, z
##                     deita de lado, y torce)
##   pelve_segue float quanto da espinha a pelve leva (0 a 1; o resto dobra na
##                     cintura). A batina de pano e presa na pelve: pelve
##                     deitada deita a batina para tras.
##   pelve    Vector3  giro a mais so da pelve
##   cabeca   Vector3  giro a mais da cabeca, por cima do olhar
##   olha     Vector3  ponto (espaco do carro) que a cabeca olha; INF = sem alvo
##   olha_peso float   quanto a cabeca vai ao ponto (0 a 1)
##   piso     float    a altura do piso do pano (espaco do carro); NAN (o
##                     padrao) = o que esta debaixo do quadril (`piso_de`)
## O que faltar repete a chave anterior. `curva` e a forma do tempo ate ela
## (ver `curva`).
func chave(em: float, k: Dictionary, curva_: StringName = &"suave") -> void:
	var cheia := {}
	if not _chaves.is_empty():
		cheia = (_chaves[_chaves.size() - 1][1] as Dictionary).duplicate()
	else:
		cheia = {"quadril": Vector3(0.0, 0.9 * _s, 0.0), "frente": 0.0, "pelve": Vector3.ZERO,
			"tronco": Vector3.ZERO, "pelve_segue": 0.3, "cabeca": Vector3.ZERO,
			"olha": Vector3.INF, "olha_peso": 0.0, "piso": NAN}
	for nome_k: String in k:
		cheia[nome_k] = k[nome_k]
	_chaves.append([em, cheia, curva_])


## Pousa o membro direto num apoio, sem ida (o comeco da pista).
func pousar(membro: int, onde: Vector3, apoio: int, polo: Vector3 = Vector3.ZERO) -> void:
	_passos[membro].append({"t0": -1.0, "t1": -1.0, "para": onde, "apoio": apoio,
		"polo": polo, "arco": Vector3.ZERO, "forca": 0.0, "avisou": true})


## Um passo do membro: sai de onde esta em `t0`, chega em `para` em `t1`,
## fazendo arco (`arco`, no espaco do carro, no meio do caminho). `forca` (0 a 1)
## e a pancada da chegada — quem ouve o apoio (`ao_apoiar`) toca o som e sacode
## o carro com ela.
func passo(membro: int, t0: float, t1: float, para: Vector3, apoio: int,
		arco := Vector3(0.0, 0.08, 0.0), polo := Vector3.ZERO, forca: float = 0.4) -> void:
	_passos[membro].append({"t0": t0, "t1": t1, "para": para, "apoio": apoio,
		"polo": polo, "arco": arco, "forca": forca, "avisou": false})


## Algo que acontece em `em` segundos da pista (um som, uma pancada no carro).
func evento(em: float, f: Callable) -> void:
	_eventos.append([em, f])
	_eventos.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


## Troca a ultima chave (a pose do contato, ajustada depois de medida).
func trocar_ultima_chave(k: Dictionary) -> void:
	if _chaves.is_empty():
		return
	var cheia: Dictionary = (_chaves[_chaves.size() - 1][1] as Dictionary).duplicate()
	for nome_k: String in k:
		cheia[nome_k] = k[nome_k]
	_chaves[_chaves.size() - 1][1] = cheia


## Quando a pista termina (a ultima chave ou o ultimo passo).
func fim() -> float:
	var f := 0.0
	if not _chaves.is_empty():
		f = float(_chaves[_chaves.size() - 1][0])
	for lista: Array in _passos:
		for p: Dictionary in lista:
			f = maxf(f, float(p["t1"]))
	return f


## Recomeca do zero, sem pista.
func limpar() -> void:
	_chaves.clear()
	_passos = [[], [], [], []]
	_eventos.clear()
	_i_evento = 0
	t = 0.0
	ritmo = 1.0
	_peso_ik = [0.0, 0.0, 0.0, 0.0]
	_apoio_pos = [Vector3.INF, Vector3.INF, Vector3.INF, Vector3.INF]
	_apoio_tipo = [Apoio.SOLTO, Apoio.SOLTO, Apoio.SOLTO, Apoio.SOLTO]


## Acrescenta a pista de agora em diante: as chaves e passos novos contam de
## `t` (o relogio atual), e o que estava depois de `t` sai.
func continuar_de_agora() -> float:
	var agora := t
	var ficam: Array = []
	for c: Array in _chaves:
		if float(c[0]) <= agora:
			ficam.append(c)
	# A chave de agora, amostrada: a proxima parte daqui, e nao de onde a
	# pista antiga ia.
	var atual := _corpo_em(agora)
	ficam.append([agora, atual, &"linear"])
	_chaves = ficam
	for m in 4:
		var lista: Array = []
		for p: Dictionary in _passos[m]:
			if float(p["t1"]) <= agora:
				lista.append(p)
		# Onde o membro esta, como apoio fixo: o passo que estava no meio para ali.
		if _apoio_pos[m] != Vector3.INF:
			lista.append({"t0": -1.0, "t1": agora, "para": _apoio_pos[m],
				"apoio": _apoio_tipo[m], "polo": _apoio_polo[m], "arco": Vector3.ZERO,
				"forca": 0.0, "avisou": true})
		_passos[m] = lista
	var eventos: Array = []
	for e: Array in _eventos:
		if float(e[0]) <= agora:
			eventos.append(e)
	_eventos = eventos
	_i_evento = eventos.size()
	return agora


# --- o quadro ---------------------------------------------------------------

func avancar(delta: float) -> void:
	if not ativo or corpo == null or _esq == null:
		return
	_dt = delta
	if not parado:
		t += delta * ritmo
		_t_vivo += delta
		_tique_passo(delta)
		while _i_evento < _eventos.size() and float(_eventos[_i_evento][0]) <= t:
			var f: Callable = _eventos[_i_evento][1]
			_i_evento += 1
			if f.is_valid():
				f.call()
	resolver()


## Escreve a pose de agora no esqueleto. `seco`: so para medir (a testa no
## contato), sem avisar apoio nem mexer no piso do pano.
func resolver(seco: bool = false) -> void:
	var k := _corpo_em(t)
	var alvos: Array = []
	for m in 4:
		alvos.append(_membro_em(m, t, seco))
	var frente: float = k["frente"]
	var giro := Basis(Vector3.UP, frente)
	# A espinha inteira (a pelve leva uma parte, o tronco o resto): o que a
	# pista escreve e para onde o tronco aponta, e nao dois angulos soltos.
	var respira := sin(_t_vivo * TAU * RESPIRA.y) * RESPIRA.x * (0.0 if parado else 1.0)
	var espinha := Basis.from_euler((k["tronco"] as Vector3) + Vector3(respira * 0.4, 0.0, 0.0)
		+ _tremor(TREMOR_TRONCO) * tique)
	var pelve := Basis(Quaternion.IDENTITY.slerp(espinha.get_rotation_quaternion(),
		clampf(float(k["pelve_segue"]), 0.0, 1.0)))
	pelve = pelve * Basis.from_euler(k["pelve"])
	var tronco := (pelve.inverse() * espinha).orthonormalized()
	var quadril: Vector3 = k["quadril"]

	# De joelhos, o quadril senta na coxa: a junta da coxa fica a um
	# comprimento de coxa do joelho apoiado, e a altura sai dai.
	var coxa := (Corpo.Y_QUADRIL - Corpo.Y_JOELHO) * _s
	var soma := 0.0
	var pesos := 0.0
	for m: int in [PE_E, PE_D]:
		var a: Dictionary = alvos[m]
		if int(a["apoio"]) != Apoio.JOELHO or float(a["peso"]) <= 0.0:
			continue
		var kj: Vector3 = (a["pos"] as Vector3) + Vector3.UP * RAIO_JOELHO
		var da_coxa := giro * (pelve * _esq.get_bone_rest(OSSO_DO_MEMBRO[m]).origin)
		var h := quadril + da_coxa
		var dxz := Vector2(h.x - kj.x, h.z - kj.z).length()
		var sobe := sqrt(maxf(coxa * coxa - dxz * dxz, 0.0))
		var w := float(a["peso"]) * float(a["chegou"])
		soma += (kj.y + sobe - da_coxa.y) * w
		pesos += w
	if pesos > 0.0:
		quadril.y = lerpf(quadril.y, soma / pesos, clampf(pesos, 0.0, 1.0))

	var piso: float = k["piso"]
	if is_nan(piso):
		var alvo_piso: float = piso_de.call(quadril) if piso_de.is_valid() else 0.0
		if is_nan(_piso) or seco:
			piso = alvo_piso if is_nan(_piso) else _piso
		else:
			piso = move_toward(_piso, alvo_piso, 1.6 * _dt)
		if not seco:
			_piso = piso
	elif not seco:
		_piso = piso
	var no := Transform3D(giro, Vector3(quadril.x, piso, quadril.z))
	corpo.transform = no
	var inv := no.affine_inverse()
	var q_S := inv * quadril
	_esq.set_bone_pose_position(Corpo.Osso.QUADRIL, q_S)
	_esq.set_bone_pose_rotation(Corpo.Osso.QUADRIL, pelve.get_rotation_quaternion())
	_esq.set_bone_pose_rotation(Corpo.Osso.TORSO, tronco.get_rotation_quaternion())
	var quadril_T := Transform3D(pelve, q_S)
	var tronco_T := quadril_T * Transform3D(tronco, _esq.get_bone_rest(Corpo.Osso.TORSO).origin)

	# A cabeca: olha o ponto (se ha), e por cima o giro da pista, o tique e o
	# tremor.
	var extra: Vector3 = (k["cabeca"] as Vector3) + _tique_agora() * tique \
		+ _tremor(TREMOR_CABECA) * tique
	var olha: Vector3 = k["olha"]
	var cab_local := Basis.from_euler(extra)
	if olha.is_finite() and float(k["olha_peso"]) > 0.001:
		var pescoco := tronco_T * _esq.get_bone_rest(Corpo.Osso.CABECA).origin
		var olho := pescoco + tronco_T.basis * Vector3(0.0, 0.15 * _s, -0.07)
		var para := (inv * olha) - olho
		if para.length_squared() > 1e-4:
			var cima := (tronco_T.basis.y + Vector3.UP).normalized()
			var global_ := Basis.looking_at(para.normalized(), cima)
			var local := (tronco_T.basis.inverse() * global_).orthonormalized()
			var q_olhar := Quaternion.IDENTITY.slerp(local.get_rotation_quaternion(),
				clampf(float(k["olha_peso"]), 0.0, 1.0))
			cab_local = Basis(q_olhar) * cab_local
	_esq.set_bone_pose_rotation(Corpo.Osso.CABECA, cab_local.get_rotation_quaternion())

	# Os bracos, do tronco ate a mao apoiada (ou pendurados).
	for m: int in [MAO_E, MAO_D]:
		var a: Dictionary = alvos[m]
		var osso: int = OSSO_DO_MEMBRO[m]
		var lado := -1.0 if m == MAO_E else 1.0
		var fk_b := Basis.from_euler(Vector3(0.12, 0.0, lado * -0.06)).get_rotation_quaternion()
		var fk_a := Basis.from_euler(Vector3(0.35, 0.0, 0.0)).get_rotation_quaternion()
		var w: float = a["peso"]
		if w > 0.001:
			var alvo_S := inv * (a["pos"] as Vector3)
			var polo_S := inv.basis * (a["polo"] as Vector3)
			if polo_S.length_squared() < 1e-4:
				polo_S = tronco_T.basis * Vector3(lado * 0.8, -0.3, 0.4)
			var extra_m := 0.0
			match int(a["apoio"]):
				Apoio.PONTA:
					extra_m = MAO_ATE_A_PONTA * _s
				Apoio.PUNHO:
					# A mao do `Corpo` e rigida: o punho fechado e quase a mao inteira.
					extra_m = MAO_ATE_A_PONTA * _s * 0.8
			var r := LevantarDoChao._ik(corpo, tronco_T, osso, alvo_S, polo_S, 1.0, extra_m)
			fk_b = fk_b.slerp(r[0] as Quaternion, w)
			fk_a = fk_a.slerp(r[1] as Quaternion, w)
		_esq.set_bone_pose_rotation(osso, fk_b)
		_esq.set_bone_pose_rotation(osso + 1, fk_a)

	# As pernas, do quadril ate o joelho ou a sola.
	var canela := (Corpo.Y_JOELHO - Corpo.Y_TORNOZELO) * _s
	for m: int in [PE_E, PE_D]:
		var a: Dictionary = alvos[m]
		var osso: int = OSSO_DO_MEMBRO[m]
		var lado := -1.0 if m == PE_E else 1.0
		var fk_c := Quaternion.IDENTITY
		var fk_k := Basis.from_euler(Vector3(-0.05, 0.0, 0.0)).get_rotation_quaternion()
		var w: float = a["peso"]
		if w > 0.001:
			var apoio := int(a["apoio"])
			var p: Vector3 = a["pos"]
			var polo: Vector3 = a["polo"]
			var alvo_car := p
			var h_car := no * (quadril_T * _esq.get_bone_rest(osso).origin)
			if apoio == Apoio.JOELHO:
				# O joelho a um comprimento de coxa da junta, o mais perto do ponto
				# que a coxa deixa; a canela deitada para tras (para o lado do
				# quadril), e o polo EXATO: a direcao do joelho fora da linha do
				# quadril ao tornozelo. Sem isso o IK escolhia o outro lado.
				var kj := p + Vector3.UP * RAIO_JOELHO
				kj = h_car + (kj - h_car).normalized() * coxa
				var tras := h_car - kj
				tras.y = 0.0
				tras = tras.normalized() if tras.length_squared() > 1e-5 \
					else (giro * Vector3(0.0, 0.0, 1.0))
				alvo_car = kj + tras * canela * 0.93 + Vector3.UP * 0.05
				var eixo := (alvo_car - h_car)
				var proj := h_car + eixo * clampf((kj - h_car).dot(eixo)
					/ maxf(eixo.length_squared(), 1e-6), 0.0, 1.0)
				polo = kj - proj
				if polo.length_squared() < 1e-6:
					polo = giro * Vector3(0.0, -0.2, -1.0)
			elif apoio == Apoio.PE:
				alvo_car = p + Vector3.UP * (TORNOZELO * _s)
			var alvo_S := inv * alvo_car
			var polo_S := inv.basis * polo
			if polo_S.length_squared() < 1e-4:
				polo_S = Vector3(lado * 0.25, 0.0, -1.0)
			var r: Array
			if alvo_S.y > -0.05:
				r = LevantarDoChao._ik_no_chao(corpo, quadril_T, osso, alvo_S, polo_S, -1.0)
			else:
				r = LevantarDoChao._ik(corpo, quadril_T, osso, alvo_S, polo_S, -1.0)
			fk_c = fk_c.slerp(r[0] as Quaternion, w)
			fk_k = fk_k.slerp(r[1] as Quaternion, w)
		_esq.set_bone_pose_rotation(osso, fk_c)
		_esq.set_bone_pose_rotation(osso + 1, fk_k)

	if not seco:
		ultimo = {"quadril": quadril, "frente": frente, "piso": piso,
			"cabeca": corpo.transform * (tronco_T * Transform3D(cab_local,
				_esq.get_bone_rest(Corpo.Osso.CABECA).origin)).origin}


## O rosto, no espaco do carro: a frente da cabeca, na altura dos olhos.
func rosto() -> Vector3:
	if _esq == null:
		return Vector3.INF
	var cab := _esq.get_bone_global_pose(Corpo.Osso.CABECA)
	return corpo.transform * (cab * Vector3(0.0, 0.155 * _s, -0.105))


## A testa (o ponto que bate), no espaco do carro, e a frente da cabeca.
func testa() -> Transform3D:
	var cab := _esq.get_bone_global_pose(Corpo.Osso.CABECA)
	var xf := corpo.transform * cab
	return Transform3D(xf.basis.orthonormalized(), xf * Vector3(0.0, 0.21 * _s, -0.105))


## Os pontos que tocam (ponta dos dedos, joelho, bico), no espaco do carro,
## por membro: para a sonda que mede se algo entrou na lataria.
func pontas() -> Array:
	var out: Array = []
	for m in 4:
		var osso: int = OSSO_DO_MEMBRO[m] + 1
		var xf := corpo.transform * _esq.get_bone_global_pose(osso)
		if m <= MAO_D:
			out.append([xf * Vector3(0.0, -(Corpo.Y_COTOVELO - 0.71) * _s, 0.0)])
		else:
			var y := -Corpo.Y_JOELHO * _s + 0.004
			out.append([xf.origin, xf * Vector3(0.0, y, -0.175), xf * Vector3(0.0, y, 0.082)])
	return out


# --- amostragem -------------------------------------------------------------

func _corpo_em(tt: float) -> Dictionary:
	if _chaves.is_empty():
		return {"quadril": Vector3(0.0, 0.9 * _s, 0.0), "frente": 0.0, "pelve": Vector3.ZERO,
			"tronco": Vector3.ZERO, "pelve_segue": 0.3, "cabeca": Vector3.ZERO,
			"olha": Vector3.INF, "olha_peso": 0.0, "piso": NAN}
	if tt <= float(_chaves[0][0]):
		return (_chaves[0][1] as Dictionary).duplicate()
	for i in range(1, _chaves.size()):
		var t1 := float(_chaves[i][0])
		if tt <= t1:
			var t0 := float(_chaves[i - 1][0])
			var k := clampf((tt - t0) / maxf(t1 - t0, 1e-5), 0.0, 1.0)
			k = curva(_chaves[i][2], k)
			return _misturar(_chaves[i - 1][1], _chaves[i][1], k)
	return (_chaves[_chaves.size() - 1][1] as Dictionary).duplicate()


static func _misturar(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var olha_a: Vector3 = a["olha"]
	var olha_b: Vector3 = b["olha"]
	var olha := olha_b
	if olha_a.is_finite() and olha_b.is_finite():
		olha = olha_a.lerp(olha_b, k)
	elif olha_a.is_finite():
		olha = olha_a
	var qa := Basis.from_euler(a["pelve"]).get_rotation_quaternion()
	var qb := Basis.from_euler(b["pelve"]).get_rotation_quaternion()
	var ta := Basis.from_euler(a["tronco"]).get_rotation_quaternion()
	var tb := Basis.from_euler(b["tronco"]).get_rotation_quaternion()
	return {
		"quadril": (a["quadril"] as Vector3).lerp(b["quadril"], k),
		"frente": lerp_angle(float(a["frente"]), float(b["frente"]), k),
		"pelve": Basis(qa.slerp(qb, k)).get_euler(),
		"tronco": Basis(ta.slerp(tb, k)).get_euler(),
		"cabeca": (a["cabeca"] as Vector3).lerp(b["cabeca"], k),
		"olha": olha,
		"olha_peso": lerpf(float(a["olha_peso"]), float(b["olha_peso"]), k),
		"pelve_segue": lerpf(float(a["pelve_segue"]), float(b["pelve_segue"]), k),
		"piso": NAN if is_nan(float(a["piso"])) or is_nan(float(b["piso"])) \
			else lerpf(float(a["piso"]), float(b["piso"]), k),
	}


## A forma do tempo entre duas chaves.
##   linear   anda igual
##   suave    sai e chega devagar
##   entra    acelera ate o fim (o bote, a queda: bate sem frear)
##   sai      sai de uma vez e freia
##   puxa     o peso: demora a sair do lugar, vai, e assenta passando um nada
##   estalo   chega em poucos quadros, passa do ponto e volta (o tique)
static func curva(nome_c: StringName, k: float) -> float:
	match nome_c:
		&"linear":
			return k
		&"entra":
			return k * k * k
		&"sai":
			return 1.0 - pow(1.0 - k, 3.0)
		&"puxa":
			var s := k * k * (3.0 - 2.0 * k)
			s = pow(s, 1.35)
			# Assenta passando uns 4% e voltando.
			return s + 0.04 * sin(PI * smoothstep(0.55, 1.0, k)) * smoothstep(0.55, 0.8, k)
		&"estalo":
			if k >= 1.0:
				return 1.0
			return 1.0 - exp(-k * 6.0) * cos(k * 7.5)
		_:
			return k * k * (3.0 - 2.0 * k)


## O membro em `tt`: {pos, apoio, polo, peso}.
func _membro_em(m: int, tt: float, seco: bool = false) -> Dictionary:
	var lista: Array = _passos[m]
	var pos := Vector3.INF
	var apoio := Apoio.SOLTO
	var polo := Vector3.ZERO
	var de := Vector3.INF
	var em_ida := false
	var k := 1.0
	var arco := Vector3.ZERO
	for p: Dictionary in lista:
		var t0 := float(p["t0"])
		var t1 := float(p["t1"])
		if t0 < 0.0 and t1 < 0.0:
			pos = p["para"]
			apoio = int(p["apoio"])
			polo = p["polo"]
			continue
		if tt < t0:
			break
		if tt < t1:
			de = pos
			em_ida = true
			k = clampf((tt - t0) / maxf(t1 - t0, 1e-5), 0.0, 1.0)
			arco = p["arco"]
			pos = p["para"]
			apoio = int(p["apoio"])
			polo = p["polo"]
			break
		pos = p["para"]
		apoio = int(p["apoio"])
		polo = p["polo"]
		if not bool(p["avisou"]) and not seco:
			p["avisou"] = true
			if ao_apoiar.is_valid():
				ao_apoiar.call(m, pos, apoio, float(p["forca"]))
	if pos == Vector3.INF:
		_peso_ik[m] = 0.0
		return {"pos": Vector3.ZERO, "apoio": Apoio.SOLTO, "polo": Vector3.ZERO, "peso": 0.0,
			"chegou": 0.0}
	var peso := 1.0
	if em_ida:
		# Sai devagar, vai, e bate: a mao cai na chapa, nao pousa.
		var e := k * k * (3.0 - 2.0 * k)
		e = lerpf(e, k * k, 0.35)
		if de == Vector3.INF:
			# Saindo do solto: o IK entra junto com a ida.
			peso = smoothstep(0.0, 0.45, k)
			de = pos - arco * 2.0
		pos = de.lerp(pos, e) + arco * sin(PI * e)
	if not seco:
		_apoio_pos[m] = pos
		_apoio_tipo[m] = apoio
		_apoio_polo[m] = polo
		_peso_ik[m] = peso
	return {"pos": pos, "apoio": apoio, "polo": polo, "peso": peso,
		"chegou": smoothstep(0.5, 1.0, k) if em_ida else 1.0}


# --- o tique ----------------------------------------------------------------

## As poses que a cabeca estala (x queixo, y giro, z tombo): a orelha no ombro,
## o giro demais, o queixo que cai, e reta.
const TIQUE_POSES := [
	[0.26, 0.06, 0.12, 0.95],
	[0.18, 0.02, 0.9, 0.18],
	[0.14, 0.35, 0.1, 0.25],
	[0.12, -0.25, 0.3, 0.55],
	[0.30, 0.0, 0.0, 0.0],
]


func _tique_passo(delta: float) -> void:
	if _tq_k < 1.0:
		_tq_k = minf(1.0, _tq_k + delta / _tq_dur)
		return
	if _tq_lento:
		return
	_tq_espera -= delta
	if _tq_espera > 0.0:
		return
	var total := 0.0
	for p: Array in TIQUE_POSES:
		total += float(p[0])
	var r := _rng.randf() * total
	var escolha: Array = TIQUE_POSES[TIQUE_POSES.size() - 1]
	for p: Array in TIQUE_POSES:
		r -= float(p[0])
		if r <= 0.0:
			escolha = p
			break
	var lado := 1.0 if _rng.randf() < 0.5 else -1.0
	estalar_cabeca(Vector3(float(escolha[1]), float(escolha[2]) * lado,
		float(escolha[3]) * lado) * _rng.randf_range(0.75, 1.1))
	_tq_espera = lerpf(0.18, 1.3, pow(_rng.randf(), 1.6))


## Estala a cabeca para `pose` agora (poucos quadros, passando do ponto).
func estalar_cabeca(pose: Vector3, dur: float = -1.0) -> void:
	var de := _tique_agora()
	var giro := (de - pose).length()
	_tq_de = de
	_tq_para = pose
	_tq_k = 0.0
	_tq_dur = dur if dur > 0.0 else _rng.randf_range(0.035, 0.07)
	_tq_lento = false
	if giro > 0.45 and ao_estalar.is_valid() and tique > 0.3:
		ao_estalar.call(clampf(giro / 1.6, 0.3, 1.0))


## Leva a cabeca devagar ate `pose` e segura ali, sem estalar (o sorriso do
## padre na janela; aqui, o encarar).
func segurar_cabeca(pose: Vector3, dur: float) -> void:
	_tq_de = _tique_agora()
	_tq_para = pose
	_tq_k = 0.0
	_tq_dur = maxf(dur, 0.01)
	_tq_lento = true


func soltar_cabeca() -> void:
	_tq_lento = false
	_tq_espera = _rng.randf_range(0.1, 0.4)


func _tique_agora() -> Vector3:
	var k := clampf(_tq_k, 0.0, 1.0)
	var e: float
	if _tq_lento:
		e = k * k * (3.0 - 2.0 * k)
	else:
		e = 1.0 if k >= 1.0 else 1.0 - exp(-k * 6.0) * cos(k * 7.5)
	return _tq_de.lerp(_tq_para, e)


func _tremor(amp: float) -> Vector3:
	if parado:
		return Vector3.ZERO
	var tt := _t_vivo
	return Vector3(sin(tt * 41.0) + 0.5 * sin(tt * 19.3 + 1.1),
		sin(tt * 37.0 + 2.0) + 0.5 * sin(tt * 23.7),
		sin(tt * 47.0 + 4.0) + 0.5 * sin(tt * 29.1 + 0.4)) * amp * 0.67
