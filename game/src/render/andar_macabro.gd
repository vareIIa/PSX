## O andar dos encapuzados de fundo: pesado, arrastando uma perna, curvado, a
## cabeca tombada e os olhos na lente, os bracos pendurados como peso morto.
##
## Por que existe
## --------------
## Os de fundo deslizavam: o no ia para a frente (`global_position +=`) com o
## ciclo do `Corpo` escondido debaixo da batina, um em cada tres piscava e
## voltava mais perto, e o `TiqueMacabro` estalava cabeca e braco de todos o
## tempo todo. Na tela era ruido e pisca, e nao medo. O medo aqui vem do corpo
## que anda ERRADO, do olhar que nao sai da lente, e de uma coisa rara de cada
## vez, que a lente consegue ler.
##
## Como funciona
## -------------
## Uma camada por cima da pose, como o tique: quem usa chama `Corpo.animar` (com
## `dominado = false`) e depois `passo`, que escreve os onze ossos inteiros por
## cima, sem somar no que o corpo escreveu. O ciclo e proprio e continuo: o do
## `Corpo` e travado em quinze poses por ciclo, e devagar assim cada pose ficava
## meio segundo parada e o quadril pulava.
##
## - O passo: a perna ruim passa menos, quase nao dobra o joelho e abre em arco.
##   O tempo em cima dela encurta (`TORTO`), o quadril afunda nela e o tronco
##   pende para ela. A rapidez pulsa com o passo: arranca na perna boa e quase
##   para no arrasto da ruim.
## - O tronco curvado para a frente, torcendo e rolando os ombros a cada passo.
## - A cabeca mira a lente. A conta sai da junta do pescoco de verdade, e nao dos
##   1,58 m fixos de `Corpo.olhar_para` (curvado, aquela conta olha o chao). Ela
##   fica tombada de lado e um pouco caida, olhando por baixo do capuz.
## - Os bracos sao dois pendulos por lado (braco e antebraco), empurrados pela
##   aceleracao do ombro de verdade. Ficam a prumo, chegam atrasados ao passo, e
##   cada um tem a sua frequencia: nunca batem juntos.
##
## Quem move o no e o chamador. Daqui sai quanto mover (`ritmo`): quase nada com
## o corpo no quadro da lente ou do retrovisor (`olhado`), depressa fora dele. A
## cada corte a lente volta e eles estao mais perto, e ninguem os viu chegar.
##
## Os eventos: um por vez no grupo inteiro, e so em quem a lente ve de perto.
## - Ele para de repente e ergue a cabeca para a lente.
## - Ele entorta o pescoco devagar, quase ate deitar a cabeca, e fica assim.
## - A mao abre e fecha os dedos. So acontece se o corpo tiver o meta `dedos`,
##   que vem da veste dos bracos: um Callable(lado, abre).
## O estalo de osso (o que `passo` devolve) e so deles.
##
## Angulos em radianos na convencao do `Corpo`: x positivo leva tronco e cabeca
## para tras e o braco pendurado para a frente; z positivo leva o que pende para
## +X (a direita dele).
class_name AndarMacabro
extends RefCounted

## O passo: metros por ciclo (dois passos) devagar e depressa, e a rapidez em
## que a passada chega no maximo.
const PASSADA := Vector2(0.55, 1.2)
const PASSADA_ATE := 1.1
## Quanto a coxa boa balanca na passada maior.
const PERNA := 0.46
## Sorteio do quanto ele manca (0 a 1).
const MANCA := Vector2(0.7, 1.0)
## O tempo em cima da perna ruim encurta: a fase corre como f + TORTO * sen f.
const TORTO := 0.5
## A rapidez pulsa no passo: arranca na perna boa, arrasta na ruim.
const PULSO := 0.65
## O quadril: o quique do passo, quanto afunda na perna ruim e quanto ele anda
## mais baixo, de joelho mole (m, corpo de 1,72 m).
const QUIQUE := 0.016
const AFUNDA := 0.05
const JOELHO_MOLE := 0.015
## O tronco: curvado (sorteio; x negativo e para a frente), quanto arranca para a
## frente no passo bom, quanto pende para a perna ruim e quanto torce.
const CURVADO := Vector2(-0.36, -0.52)
const ARRANCO := 0.08
const PENDE := 0.13
const TORCE := 0.12
## A cabeca: o tombo de lado (sorteio), o quanto ela cai para a frente sem sair
## da lente, e o limite do pescoco em relacao ao tronco (giro, pitch).
const TOMBO := Vector2(0.26, 0.5)
const CAIDA := 0.2
const PESCOCO := Vector2(1.25, 0.85)
## O tronco gira junto para a lente: esta fracao do giro, ate o limite (rad), e
## em quanto tempo (s). Com o pescoco sozinho girando muito, o pano do capuz (que
## abaixo do pescoco vai com o tronco) esticava por cima da cara.
const TRONCO_OLHA := 0.45
const TRONCO_OLHA_ATE := 0.5
const TRONCO_OLHA_TEMPO := 0.45
## Os olhos em relacao a junta do pescoco (m, corpo de 1,72 m): quem mira a lente
## e o olho, e nao a nuca.
const OLHOS := Vector3(0.0, 0.10, -0.07)
## Os bracos: frequencia do pendulo (Hz) do braco e do antebraco, o
## amortecimento, o comprimento que a forca do ombro ve (m), a abertura para
## fora do corpo e a dobra de repouso do cotovelo.
## O braco da veste (`BracosPodres`) e comprido: a ponta dos dedos fica a dois
## dedos do joelho, e a manga em sino vai dura com o antebraco. Pendulo longo e
## lento, e pouca amplitude (`BALANCO`): com mais, a mao varria o joelho. O
## antebraco nunca passa de `DOBRA_MAX` do braco, bem abaixo da horizontal.
const BRACO_HZ := Vector2(0.5, 0.62)
const ANTEBRACO_HZ := Vector2(0.8, 1.0)
const AMORTECE := Vector2(0.1, 0.17)
const BRACO_M := 0.62
const ABRE := 0.07
const COTOVELO := 0.1
const BALANCO := Vector2(-0.28, 0.32)
const DOBRA_MAX := 0.6
## O olhar da lente: rapidez maxima dentro do quadro (m/s), quanto fora dele
## multiplica e o teto, o tempo para frear quando a lente chega e para soltar
## quando ela sai, e a folga (m) do corpo na borda do quadro.
const VISTO_ATE := 0.2
const FORA := 2.4
const FORA_ATE := 1.15
const FREIA := 0.3
const SOLTA := 0.8
const MARGEM := 0.4
## Abaixo disto (m/s) ele esta parado.
const PARADO := 0.08
## Os eventos: o intervalo entre um e outro no grupo (s), o alcance da lente (m)
## e a chance por segundo de um candidato pegar a vez.
const EVENTO_INTERVALO := Vector2(2.2, 4.6)
const EVENTO_PERTO := 12.0
const EVENTO_CHANCE := 1.2
## O pescoco que entorta: ate onde (rad; o tique antigo ia a 1,30) e em quanto
## tempo, em tres puxoes.
const ENTORTA_ATE := 1.35
const ENTORTA_TEMPO := 3.2
## O erguer: o instante parado antes de a cabeca subir, o estalo da subida,
## quanto ele fica encarando (s), e a forca do estalo.
const ERGUE_SOBE := 0.16
const ERGUE_ESTALA := 0.14
const ERGUE_FICA := 2.4
const ERGUE_ESTALO := 0.75
## Os dedos, em (tempo, abertura): de onde a mao esta a aberta, a garra, e de
## novo. O repouso da mao e da veste; aqui so o gesto.
const DEDOS := [[0.0, 0.35], [0.7, 1.0], [1.05, 0.0], [1.6, 0.9], [2.0, 0.08], [2.7, 0.35]]

enum Evento { NENHUM, ERGUE, ENTORTA, DEDOS }

var _c: Corpo
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _fase: float = 0.0
var _fase_ar: float = 0.0
var _manca: float = 0.85
## Qual perna arrasta: -1 a esquerda, 1 a direita.
var _ruim: float = 1.0
var _curvado: float = -0.44
## O tombo da cabeca, com o lado no sinal.
var _tombo: float = 0.35
## A rapidez media suavizada, a com o evento, e a do quadro (com o pulso).
var _v: float = 0.0
var _v_passo: float = 0.0
var _anda: float = 0.0
var _giro_tronco: float = 0.0
var _visto: bool = false
## Por lado (-1, 1): o estado dos dois pendulos e o que o ombro fez.
var _bracos: Dictionary = {}

var _ev: int = Evento.NENHUM
var _ev_t: float = 0.0
var _ev_lado: float = 1.0
var _ev_passo: int = -1
## O que os eventos fazem no corpo: parar (0 a 1), erguer (0 curvado e caido, 1
## reto encarando) e entortar (0 a 1; o que entortou fica).
var _para: float = 0.0
var _ergue: float = 0.0
var _entorta: float = 0.0
var _entortado: bool = false
var _estalo: float = 0.0
## O ultimo quadro em que `passo` rodou: quem saiu de cena no meio de um evento
## (escondido, levado para outro papel) nao segura a vez do grupo.
var _quadro_passo: int = -1

## A vez do grupo: quem esta no evento, quando o proximo pode comecar, e o
## relogio que anda uma vez por quadro, por mais corpos que chamem.
static var _dono: WeakRef = null
static var _livre_em: float = 0.0
static var _relogio: float = 0.0
static var _quadro: int = -1
## O retrovisor, se houver: o que ele mostra tambem esta sendo olhado.
static var _espelho: WeakRef = null
static var _espelho_vp: WeakRef = null
## Os planos do quadro de cada camera, por quadro (`olhado`).
static var _planos: Dictionary = {}
## `--andar-log`: cada evento que comeca sai no log.
static var _log: bool = OS.get_cmdline_user_args().has("--andar-log")


func _init(corpo: Corpo, semente: int) -> void:
	_c = corpo
	_rng.seed = 50_021 + semente * 6007
	_fase = _rng.randf() * TAU
	_fase_ar = _rng.randf() * TAU
	_manca = _rng.randf_range(MANCA.x, MANCA.y)
	_ruim = -1.0 if _rng.randf() < 0.5 else 1.0
	_curvado = _rng.randf_range(CURVADO.x, CURVADO.y)
	_tombo = _rng.randf_range(TOMBO.x, TOMBO.y) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	for lado: float in [-1.0, 1.0]:
		_bracos[lado] = {
			"hz": _rng.randf_range(BRACO_HZ.x, BRACO_HZ.y),
			"hz2": _rng.randf_range(ANTEBRACO_HZ.x, ANTEBRACO_HZ.y),
			"amortece": _rng.randf_range(AMORTECE.x, AMORTECE.y),
			"ruido_w": _rng.randf_range(0.7, 1.6), "ruido_f": _rng.randf() * TAU,
			"a": 0.04, "da": 0.0, "b": lado * ABRE, "db": 0.0, "g": 0.04 + COTOVELO, "dg": 0.0,
			"p": Vector3.INF, "vel": Vector3.ZERO, "acc": Vector3.ZERO,
		}


## O retrovisor da cena (a camera do reflexo e o SubViewport dela). O que ele
## mostra conta como olhado enquanto ele estiver desenhando.
static func usar_espelho(cam: Camera3D, vp: SubViewport) -> void:
	_espelho = weakref(cam) if cam != null else null
	_espelho_vp = weakref(vp) if vp != null else null


## A lente (ou o retrovisor) tem `c` no quadro, com uma folga na borda: o corpo
## inteiro numa esfera, contra os planos do quadro de cada camera.
static func olhado(c: Corpo) -> bool:
	if c == null or not c.is_inside_tree():
		return false
	var h := c.altura()
	var centro := c.global_position + Vector3.UP * h * 0.55
	var raio := h * 0.5 + MARGEM
	var cam := c.get_viewport().get_camera_3d()
	if cam != null and _no_quadro(cam, centro, raio):
		return true
	var e := _espelho_ativo()
	return e != null and _no_quadro(e, centro, raio)


static func _espelho_ativo() -> Camera3D:
	if _espelho == null or _espelho_vp == null:
		return null
	var cam := _espelho.get_ref() as Camera3D
	var vp := _espelho_vp.get_ref() as SubViewport
	if cam == null or vp == null or not cam.is_inside_tree() \
			or vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return null
	return cam


static func _no_quadro(cam: Camera3D, centro: Vector3, raio: float) -> bool:
	var id := cam.get_instance_id()
	var q := Engine.get_process_frames()
	var cache: Array = _planos.get(id, [])
	if cache.is_empty() or int(cache[0]) != q:
		cache = [q, cam.get_frustum()]
		_planos[id] = cache
	# As normais dos planos do quadro apontam para fora.
	for p: Plane in cache[1]:
		if p.distance_to(centro) > raio:
			return false
	return true


## Quanto mover o no neste quadro (m/s), para quem quer andar a `rapidez`:
## com `visto` (ver `olhado`) ele quase para, fora do quadro ele vai depressa. O
## evento para, e o passo pulsa. `livre` falso: a rapidez e de outro (a meia-lua
## da janela tem a coreografia dela) e o olhar nao mexe nela.
func ritmo(delta: float, rapidez: float, visto: bool, livre: bool = true) -> float:
	_visto = visto
	var alvo := maxf(rapidez, 0.0)
	if livre and alvo > 0.0:
		alvo = minf(alvo, VISTO_ATE) if visto else minf(alvo * FORA, FORA_ATE)
	var tau := FREIA if alvo < _v else SOLTA
	_v = lerpf(_v, alvo, 1.0 - exp(-maxf(delta, 0.0) / tau))
	_v_passo = _v * (1.0 - _para)
	if _v_passo < PARADO:
		return 0.0
	var f := _f()
	var media := 1.0 + PULSO * _manca * TORTO * _manca * 0.5
	return _v_passo * (1.0 - PULSO * _manca * cos(f)) / media


## Escreve o andar por cima do que `Corpo.animar` escreveu, com os olhos em
## `olho` (mundo). Devolve a forca do estalo de osso que comecou neste quadro
## (0 se nenhum), para quem chama tocar.
func passo(delta: float, olho: Vector3) -> float:
	var esq := _c.esqueleto()
	if esq == null or delta <= 0.0:
		return 0.0
	_t += delta
	_estalo = 0.0
	_quadro_passo = Engine.get_process_frames()
	_agenda(delta, olho)
	_eventos(delta)
	var s := _c.altura() / Corpo.ALTURA_REF
	var v := _v_passo
	_anda = move_toward(_anda, smoothstep(PARADO, PARADO + 0.12, v), delta * 4.0)
	var anda := _anda
	var passada := lerpf(PASSADA.x, PASSADA.y, clampf(v / PASSADA_ATE, 0.0, 1.0)) * s
	if v > PARADO:
		_fase = fmod(_fase + TAU * v / passada * delta, TAU)
	var f := _f()
	var apoio_ruim := maxf(0.0, cos(f))
	var apoio_bom := maxf(0.0, -cos(f))
	var amp := PERNA * lerpf(0.6, 1.0, clampf(v / PASSADA_ATE, 0.0, 1.0)) * anda
	var ar := sin(_t * 1.25 + _fase_ar)

	# O quadril: quica no passo bom e afunda na perna ruim.
	var rest_q := esq.get_bone_rest(Corpo.Osso.QUADRIL).origin
	var y := (absf(sin(f)) * QUIQUE - apoio_ruim * AFUNDA * _manca) * anda - JOELHO_MOLE + ar * 0.003
	var pos_q := rest_q + Vector3(0.0, y * s, 0.0)
	var rot_q := Basis.from_euler(Vector3(0.0, sin(f) * 0.06 * anda, cos(f) * 0.035 * anda))
	esq.set_bone_pose_position(Corpo.Osso.QUADRIL, pos_q)
	esq.set_bone_pose_rotation(Corpo.Osso.QUADRIL, rot_q.get_rotation_quaternion())

	# As pernas. A boa (sen f) leva o passo; a ruim (sen f + pi) passa menos, fica
	# para tras, nao dobra o joelho e abre em arco enquanto a boa apoia.
	var coxa_boa := Corpo.Osso.COXA_E if _ruim > 0.0 else Corpo.Osso.COXA_D
	var coxa_ruim := Corpo.Osso.COXA_D if _ruim > 0.0 else Corpo.Osso.COXA_E
	_girar(esq, coxa_boa, amp * sin(f), 0.0, 0.0)
	_girar(esq, coxa_boa + 1, -(0.10 + 0.55 * maxf(0.0, -sin(f + 0.55))) * lerpf(0.4, 1.0, anda))
	var arco := maxf(0.0, -cos(f))
	_girar(esq, coxa_ruim, amp * 0.42 * sin(f + PI) - 0.09 * _manca * anda + 0.07 * (1.0 - anda),
		0.0, _ruim * (0.13 * _manca * arco * anda + 0.05 * (1.0 - anda)))
	_girar(esq, coxa_ruim + 1, -(0.05 + 0.1 * maxf(0.0, -sin(f + PI + 0.55))) * anda
		- 0.07 * (1.0 - anda))

	# O tronco: curvado, arrancando para a frente no passo bom, pendendo e
	# rolando os ombros para a perna ruim quando ela aguenta o peso. Parado, o
	# peso vai todo para a perna boa.
	var tx := _curvado * lerpf(1.0, 0.3, _ergue) - ARRANCO * _manca * apoio_bom * anda \
		+ 0.03 * apoio_ruim * anda + ar * 0.015
	var alvo := esq.global_transform.affine_inverse() * olho
	var giro := clampf(atan2(-alvo.x, -alvo.z) * TRONCO_OLHA, -TRONCO_OLHA_ATE, TRONCO_OLHA_ATE)
	_giro_tronco = lerpf(_giro_tronco, giro, 1.0 - exp(-delta / TRONCO_OLHA_TEMPO))
	var ty := -sin(f + 0.35) * TORCE * anda + _giro_tronco
	var tz := (-_ruim * PENDE * _manca * apoio_ruim + 0.04 * sin(f)) * anda \
		+ _ruim * 0.05 * (1.0 - anda) * (1.0 - _ergue)
	var rot_t := Basis.from_euler(Vector3(tx, ty, tz))
	esq.set_bone_pose_rotation(Corpo.Osso.TORSO, rot_t.get_rotation_quaternion())
	var t_tronco := Transform3D(rot_q, pos_q) \
		* Transform3D(rot_t, esq.get_bone_rest(Corpo.Osso.TORSO).origin)

	_bracos_mortos(esq, delta, t_tronco, tx, tz, s)
	_cabeca(esq, t_tronco, olho, f, anda, s)
	return _estalo


## A fase de agora, com o tempo curto em cima da perna ruim.
func _f() -> float:
	return _fase + TORTO * _manca * sin(_fase)


func _girar(esq: Skeleton3D, osso: int, x: float, y: float = 0.0, z: float = 0.0) -> void:
	esq.set_bone_pose_rotation(osso, Basis.from_euler(Vector3(x, y, z)).get_rotation_quaternion())


## Os bracos como peso morto: o angulo de cada um no mundo (a prumo e zero) e
## um pendulo, e o que o move e o ombro acelerando no espaco do corpo (o passo,
## o arranco, a torcao, o tranco de parar). O antebraco e outro pendulo pendurado
## no cotovelo, que so dobra para a frente.
func _bracos_mortos(esq: Skeleton3D, delta: float, t_tronco: Transform3D, tx: float,
		tz: float, s: float) -> void:
	var mundo := esq.global_transform
	var corpo_inv := _c.global_basis.inverse()
	var dt := minf(delta, 0.1)
	var n := maxi(1, ceili(dt * 120.0))
	var h := dt / float(n)
	var abre_barriga := maxf(0.0, _c.abducao() - 0.06)
	for lado: float in [-1.0, 1.0]:
		var osso := Corpo.Osso.BRACO_E if lado < 0.0 else Corpo.Osso.BRACO_D
		var b: Dictionary = _bracos[lado]
		var ombro := mundo * (t_tronco * esq.get_bone_rest(osso).origin)
		var p0: Vector3 = b["p"]
		if p0.is_finite() and ombro.distance_to(p0) < 0.5:
			var vel := (ombro - p0) / dt
			var acc := ((vel - (b["vel"] as Vector3)) / dt).limit_length(14.0)
			b["acc"] = (b["acc"] as Vector3).lerp(acc, 0.5)
			b["vel"] = vel
		else:
			# Primeiro quadro, ou teleporte: sem tranco.
			b["vel"] = Vector3.ZERO
			b["acc"] = Vector3.ZERO
		b["p"] = ombro
		# No espaco do corpo: -Z e a frente, +X a direita.
		var a := corpo_inv * (b["acc"] as Vector3)
		var w := TAU * float(b["hz"])
		var w2 := TAU * float(b["hz2"])
		var z := float(b["amortece"])
		var alvo_a := 0.04
		var alvo_b := lado * (ABRE + abre_barriga)
		# O ombro vai para a frente e a mao fica: o angulo cai. Mais um fio de vida
		# (o ar, o peso trocando) para ele nunca assentar de todo.
		var fa := a.z / (BRACO_M * s) + 0.35 * sin(_t * float(b["ruido_w"]) + float(b["ruido_f"]))
		var fb := -a.x / (BRACO_M * s)
		var ang_a := float(b["a"])
		var vel_a := float(b["da"])
		var ang_b := float(b["b"])
		var vel_b := float(b["db"])
		var ang_g := float(b["g"])
		var vel_g := float(b["dg"])
		for _i in n:
			var aa := -w * w * (ang_a - alvo_a) - 2.0 * z * w * vel_a + fa
			vel_a += aa * h
			ang_a += vel_a * h
			# No fim do balanco o braco bate na perna (ou no pano) e perde o embalo.
			if ang_a < BALANCO.x or ang_a > BALANCO.y:
				ang_a = clampf(ang_a, BALANCO.x, BALANCO.y)
				vel_a *= -0.2
			var ab := -w * w * (ang_b - alvo_b) - 2.0 * z * w * vel_b + fb
			vel_b += ab * h
			ang_b += vel_b * h
			if absf(ang_b - alvo_b) > 0.3:
				ang_b = alvo_b + clampf(ang_b - alvo_b, -0.3, 0.3)
				vel_b *= -0.2
			var ag := -w2 * w2 * (ang_g - ang_a - COTOVELO) - 2.0 * z * w2 * (vel_g - vel_a) + fa * 1.3
			vel_g += ag * h
			ang_g += vel_g * h
			# O cotovelo nao dobra para tras, e nem vai perto da horizontal.
			if ang_g - ang_a < 0.03:
				ang_g = ang_a + 0.03
				vel_g = maxf(vel_g, vel_a)
			elif ang_g - ang_a > DOBRA_MAX:
				ang_g = ang_a + DOBRA_MAX
				vel_g = minf(vel_g, vel_a)
		b["a"] = ang_a
		b["da"] = vel_a
		b["b"] = ang_b
		b["db"] = vel_b
		b["g"] = ang_g
		b["dg"] = vel_g
		# No osso, relativo ao tronco: o que o tronco curvou o braco desfaz, e ele
		# fica a prumo.
		_girar(esq, osso, ang_a - tx, 0.0, ang_b - tz)
		_girar(esq, osso + 1, ang_g - ang_a)


## A cabeca na lente: a direcao sai do olho de verdade (a junta do pescoco depois
## do tronco escrito), tombada de lado e um pouco caida, e presa no que um
## pescoco gira em relacao ao tronco.
func _cabeca(esq: Skeleton3D, t_tronco: Transform3D, olho: Vector3, f: float, anda: float,
		s: float) -> void:
	var pescoco := t_tronco * esq.get_bone_rest(Corpo.Osso.CABECA).origin
	var olhos := pescoco + t_tronco.basis * (OLHOS * s)
	var alvo := esq.global_transform.affine_inverse() * olho
	var dir := alvo - olhos
	var lado := signf(_tombo)
	var tombo := lado * lerpf(absf(_tombo) * (1.0 - _ergue), ENTORTA_ATE, _entorta)
	# O aceno do passo, atrasado: a cabeca pesada chega depois do corpo.
	var caida := CAIDA * (1.0 - _ergue) - 0.06 * _ergue + 0.05 * sin(2.0 * f - 0.9) * anda
	var olhando := Basis.looking_at(dir, Vector3.UP) if dir.length_squared() > 0.0001 \
		else Basis.IDENTITY
	olhando = olhando * Basis.from_euler(Vector3(-caida, 0.0, tombo))
	var e := (t_tronco.basis.inverse() * olhando).get_euler()
	e.x = clampf(e.x, -PESCOCO.y, PESCOCO.y)
	e.y = clampf(e.y, -PESCOCO.x, PESCOCO.x)
	esq.set_bone_pose_rotation(Corpo.Osso.CABECA, Basis.from_euler(e).get_rotation_quaternion())


# --- eventos ----------------------------------------------------------------

## A vez do grupo: sem ninguem no meio de um evento, passado o intervalo, e com
## a lente perto e em cima dele, ele pode pegar a vez.
func _agenda(delta: float, olho: Vector3) -> void:
	var q := Engine.get_process_frames()
	if q != _quadro:
		_quadro = q
		_relogio += _c.get_process_delta_time()
	if _ev != Evento.NENHUM or not _visto or _relogio < _livre_em:
		return
	var dono: AndarMacabro = _dono.get_ref() if _dono != null else null
	if dono != null and dono != self and dono._ev != Evento.NENHUM \
			and q - dono._quadro_passo < 3:
		return
	var longe := (_c.global_position + Vector3.UP * _c.altura() * 0.85).distance_to(olho)
	if longe > EVENTO_PERTO or longe < 1.2:
		return
	if _rng.randf() > delta * EVENTO_CHANCE:
		return
	var opcoes: Array = [[Evento.ERGUE, 0.45]]
	if not _entortado:
		opcoes.append([Evento.ENTORTA, 0.35])
	if _c.has_meta(&"dedos"):
		opcoes.append([Evento.DEDOS, 0.3])
	var total := 0.0
	for o: Array in opcoes:
		total += float(o[1])
	var r := _rng.randf() * total
	var qual: int = Evento.ERGUE
	for o: Array in opcoes:
		r -= float(o[1])
		if r <= 0.0:
			qual = int(o[0])
			break
	comecar(qual)


## Comeca um evento (`Evento`) agora: a bancada pede de fora, a agenda por dentro.
func comecar(qual: int) -> void:
	_ev = qual
	_ev_t = 0.0
	_ev_passo = -1
	_ev_lado = -1.0 if _rng.randf() < 0.5 else 1.0
	_dono = weakref(self)
	if _log:
		print("[andar] evento %s em %s (relogio %.2f)" % [Evento.keys()[qual], _c.name, _relogio])


func evento() -> int:
	return _ev


func _fim_do_evento() -> void:
	_ev = Evento.NENHUM
	_livre_em = _relogio + _rng.randf_range(EVENTO_INTERVALO.x, EVENTO_INTERVALO.y)


func _eventos(delta: float) -> void:
	_ev_t += delta
	match _ev:
		Evento.NENHUM:
			_para = move_toward(_para, 0.0, delta * 1.5)
			_ergue = move_toward(_ergue, 0.0, delta * 0.9)
		Evento.ERGUE:
			# Para seco. Um instante depois a cabeca sobe de uma vez (passa do
			# ponto e volta, como estalo) e o tronco endireita; fica encarando, e
			# so entao relaxa e volta a andar.
			var fica := ERGUE_SOBE + ERGUE_ESTALA + ERGUE_FICA
			_para = 1.0 if _ev_t < fica else maxf(0.0, 1.0 - (_ev_t - fica) / 0.7)
			if _ev_t >= ERGUE_SOBE and _ev_t < fica:
				var u := (_ev_t - ERGUE_SOBE) / ERGUE_ESTALA
				_ergue = 1.0 if u >= 1.0 else clampf(1.0 - exp(-u * 6.0) * cos(u * 7.5), 0.0, 1.25)
				if _ev_passo < 0:
					_ev_passo = 0
					_estalo = ERGUE_ESTALO
			elif _ev_t >= fica:
				_ergue = move_toward(_ergue, 0.0, delta / 1.0)
			if _ev_t > fica + 1.0:
				_fim_do_evento()
		Evento.ENTORTA:
			# Tres puxoes: cada um estala e entra um tanto, e depois cede devagar.
			_para = minf(0.6, _ev_t / 0.4) if _ev_t < ENTORTA_TEMPO \
				else maxf(0.0, 0.6 - (_ev_t - ENTORTA_TEMPO) / 0.8)
			var u := clampf(_ev_t / ENTORTA_TEMPO, 0.0, 1.0) * 3.0
			var i := mini(int(u), 2)
			var dentro := u - float(i)
			if i > _ev_passo:
				_ev_passo = i
				_estalo = 0.35 + 0.1 * float(i)
			_entorta = maxf(_entorta, (float(i) + 0.3 * smoothstep(0.0, 0.1, dentro)
				+ 0.7 * smoothstep(0.1, 1.0, dentro)) / 3.0)
			if _ev_t > ENTORTA_TEMPO + 0.8:
				_entorta = 1.0
				_entortado = true
				_fim_do_evento()
		Evento.DEDOS:
			_para = minf(0.5, _ev_t / 0.3)
			var dedos: Variant = _c.get_meta(&"dedos") if _c.has_meta(&"dedos") else null
			var abre := _dedos_em(_ev_t)
			if dedos is Callable and (dedos as Callable).is_valid():
				(dedos as Callable).call(_ev_lado, abre)
			# O estalo e o da garra fechando.
			if _ev_passo < 0 and _ev_t >= float(DEDOS[2][0]):
				_ev_passo = 0
				_estalo = 0.3
			var fim := float(DEDOS[DEDOS.size() - 1][0])
			if _ev_t > fim:
				_fim_do_evento()


func _dedos_em(t: float) -> float:
	for k in DEDOS.size() - 1:
		var a: Array = DEDOS[k]
		var b: Array = DEDOS[k + 1]
		if t <= float(b[0]):
			var u := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.01), 0.0, 1.0)
			return lerpf(float(a[1]), float(b[1]), smoothstep(0.0, 1.0, u))
	return float(DEDOS[DEDOS.size() - 1][1])
