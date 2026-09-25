## O corpo dele acordando e levantando na Praca da Matriz: as poses, o olho
## (a camera presa ao osso da cabeca), as maos de primeira pessoa e a camera
## que acompanha o levantar.
##
## Por que o corpo nao gira mais como uma prancha
## ----------------------------------------------
## A versao anterior deitava o no inteiro do `Corpo` com uma base de noventa
## graus e, para levantar, girava o no de volta enquanto `Corpo.levantar`
## dobrava as pernas por dentro. Na tela era um boneco duro tombando para cima
## sobre os pes, com os joelhos dobrando no ar e as maos juntas na frente do
## peito — e, deitado, boiando acima do calcamento. Aqui o no fica de pe e
## parado, como o `BonecoDePano` faz, e quem deita e levanta e o QUADRIL, por
## chaves com alvo de mao e pe (`LevantarDoChao`): a mao planta no chao e fica
## plantada, o pe planta e fica plantado, e o tronco pousa no piso pela pele.
##
## Referencial
## -----------
## O do Corpo de pe no fim: frente em -Z. Ele esta caido DE COSTAS com a cabeca
## para a frente (-Z) e os pes para tras (+Z) — de pe, no fim, olha para onde a
## cabeca estava, que e a igreja. Deitado assim, o olho que desce pelo proprio
## corpo ve a praca do lado de la dos pes, e a igreja fica guardada atras da
## cabeca ate a revelacao.
##
## O levantar e o de quem nao consegue: rola para o lado, poe as maos no chao a
## frente, empurra, escorrega, empurra de novo, fica de quatro, poe um pe, apoia
## a mao no joelho e sobe. As quatro ultimas chaves sao as do `LevantarDoChao`
## de bruços, que a regua (`tests/medir_levantar.gd`) ja aprovou.
class_name AcordarNaPraca
extends Node

const O := Corpo.Osso
const C := preload("res://src/render/chaves_do_acordar.gd")

## O olho, no referencial do osso da cabeca (para 1,72 m): no meio da cara, na
## linha dos olhos, rente a frente da caixa.
const OLHO := Vector3(0.0, 0.155, -0.095)
const FOV_OLHO := 74.0
## Respiracao do tronco deitado: amplitude (rad) e ciclos por segundo. Quem
## acabou de acordar de um tranco respira curto e rapido.
const FOLEGO := Vector2(0.035, 0.42)
## Tremor da camera presa ao olho (rad): o pescoco de quem esta tonto.
const TREMOR_OLHO := 0.006

var _cena: Node3D
var _jogador: Player
var _corpo: Corpo
var _sk: Skeleton3D
var _cam: Camera3D
var _palpebra: PalpebraDaLente
var _bracos: Array[BracoVivo] = []

## A sequencia em curso e o relogio dela.
var _ch: Array = []
var _t: float = 0.0
var _parado: bool = true

## Olho: a camera presa na cabeca, as maos de primeira pessoa e a cabeca e os
## bracos do corpo recolhidos (senao a caixa da cabeca tapa a lente e o braco de
## caixas aparece dentro do braco vivo).
var _pov: bool = false
var olho_giro := Vector2.ZERO
var folego: float = 1.0
var tremor: float = 1.0
var _t_ruido: float = 0.0

## As maos de primeira pessoa, por lado (0 esquerda, 1 direita).
## Palma virada para o olho (0 a 1), e o quanto ela gira para mostrar o dorso.
var palma_no_olho: float = 0.0
var vira_mao: float = 0.0
## Mao espalmada no chao, dorso para cima (0 a 1).
var espalma: float = 0.0
var _dedos_de: Array[Dictionary] = [{}, {}]
var _dedos_para: Array[Dictionary] = [{}, {}]
var _dedos_k: Array[float] = [1.0, 1.0]
var _dedos_dur: Array[float] = [1.0, 1.0]

## Camera de trilho para os planos de fora: pontos, duracao, osso mirado.
var _trilho: Array[Vector3] = []
var _trilho_dur: float = 1.0
var _trilho_t: float = 0.0
var _trilho_mira := Vector3.INF
var _trilho_osso: int = O.TORSO
var _trilho_desvio := Vector3.ZERO
var _trilho_fov := Vector2(50.0, 50.0)
var _trilho_tremor: float = 0.0
var _trilho_cima := Vector3.UP

## Camera de orbita (o olhar em volta): chaves (tempo, valor) de angulo,
## raio, altura e fov, em volta de `_orbita_base` (o corpo parado).
var _orbita: Dictionary = {}
var _orbita_t: float = 0.0
var _orbita_base := Transform3D.IDENTITY

var _tocadores: Array[AudioStreamPlayer] = []


# =============================================================================
# Montagem
# =============================================================================

## Toma o corpo do jogador e deita ele na primeira chave. O no do Corpo volta a
## base de pe (sem giro nenhum): quem deita e o quadril.
func montar(cena: Node3D, jogador: Player) -> void:
	_cena = cena
	_jogador = jogador
	_corpo = jogador.figura()
	if _corpo == null:
		return
	_sk = _corpo.esqueleto()
	process_priority = 100
	_corpo.basis = Basis()
	_corpo.position = Vector3.ZERO
	_corpo.postura(Corpo.Postura.LIVRE)
	_corpo.dominado = true
	_montar_bracos()
	tocar(C.chaves_deitado(_corpo))
	_aplicar(0.0)


func _montar_bracos() -> void:
	var cores := MotoristaCena._cores_do_jogador()
	var pele: Color = cores["pele"]
	var longa: bool = cores["longa"]
	var manga: Color = cores["manga"] if longa else pele
	for i in 2:
		var b := BracoVivo.criar("BracoDoOlho%d" % i, i == 1, pele, manga, longa)
		_cena.add_child(b)
		_bracos.append(b)
		_dedos_de[i] = MaoPosada.pose(&"relaxada")
		_dedos_para[i] = _dedos_de[i]


## O material dos bracos compila ~106 pipelines no primeiro quadro em que eles
## entram numa camera que os desenha (a do jogador nao ve a camada deles): 140 ms
## parado. Entrar no olho com a tela ainda branca e chapada, e esperar, faz esse
## quadro cair onde nao ha nada para ver.
func entrar_no_olho_aquecido() -> void:
	entrar_no_olho()
	for i in 5:
		await get_tree().process_frame


## Devolve o corpo ao jogo: de pe, na postura livre, com cabeca e bracos no
## tamanho de sempre.
func soltar() -> void:
	_pov = false
	_trilho.clear()
	_orbita.clear()
	_restaurar_ossos()
	for b: BracoVivo in _bracos:
		if is_instance_valid(b):
			b.queue_free()
	_bracos.clear()
	if _corpo != null and is_instance_valid(_corpo):
		_corpo.dominado = false
		_corpo.postura(Corpo.Postura.LIVRE)
	if _palpebra != null and is_instance_valid(_palpebra):
		_palpebra.queue_free()
		_palpebra = null
	Cinema.sem_profundidade()
	_parado = true


# =============================================================================
# Sequencias
# =============================================================================

## Toca uma sequencia de chaves do comeco.
func tocar(ch: Array) -> void:
	_ch = ch
	_t = 0.0
	_parado = false


## Espera o relogio da sequencia chegar em `t` segundos.
func ate(t: float) -> void:
	while _t < t and not _parado:
		await get_tree().process_frame


func tempo() -> float:
	return _t


## A camera passa a ser o olho dele.
func entrar_no_olho() -> void:
	_cam = Cinema.assumir()
	_cam.fov = FOV_OLHO
	_pov = true
	Lente.recomecar()
	for b: BracoVivo in _bracos:
		b.visible = true
	if _palpebra == null:
		_palpebra = PalpebraDaLente.new()
		_cena.add_child(_palpebra)


func sair_do_olho() -> void:
	_pov = false
	_restaurar_ossos()
	for b: BracoVivo in _bracos:
		b.visible = false


func palpebra() -> PalpebraDaLente:
	return _palpebra


## Camera de trilho: passa pelos `pontos` (Catmull-Rom) em `duracao`, mirando o
## osso `osso` (+ `desvio`) com atraso, como um operador que acompanha.
##
## `cima` e o alto do quadro: para camera olhando para baixo (o zenital), e para
## onde a cabeca dele fica na tela.
func trilho(pontos: Array[Vector3], duracao: float, osso: int, desvio: Vector3,
		fov_de: float, fov_ate: float, tremor_mao: float = 1.0,
		cima: Vector3 = Vector3.UP, continuar: bool = false) -> void:
	_cam = Cinema.assumir()
	_trilho_cima = cima.normalized()
	# Continuando o plano (sem corte), a mira segue de onde estava em vez de
	# pular para o osso novo.
	var mira := _trilho_mira
	if continuar and not pontos.is_empty():
		pontos.insert(0, _cam.global_position)
	_trilho = pontos
	_trilho_dur = maxf(duracao, 0.01)
	_trilho_t = 0.0
	_trilho_osso = osso
	_trilho_desvio = desvio
	_trilho_fov = Vector2(fov_de, fov_ate)
	_trilho_tremor = tremor_mao
	_trilho_mira = mira if continuar and mira != Vector3.INF else ponto(osso) + desvio
	# Corte: a lente nao pode ler o pulo da camera como movimento. Sem isto o
	# primeiro quadro do plano novo saia inteiro borrado pelo desfoque de
	# movimento (dois metros e meio num quadro de 4K sao ~80 m/s).
	if not continuar:
		Lente.recomecar()


func parar_trilho() -> void:
	_trilho.clear()


## Camera que da a volta nele, na altura do rosto.
##
## `chaves` tem quatro listas de (tempo, valor): "angulo" em volta dele (0 atras,
## PI/2 a direita dele, PI na frente do rosto), "raio", "altura" (do chao, em
## metros de 1,72) e "fov". A mira persegue o osso com atraso, como o operador
## do trilho. A base e a do corpo agora: ele pode girar o quadril dentro da
## orbita sem arrastar a camera junto.
##
## A volta passa rente a poste, banco e gente da plateia. Antes de comecar, cada
## ponto da volta tem a linha da cabeca ate a lente testada; onde bate, o raio
## daquele trecho encolhe ate caber (nunca abaixo de 0,7 m).
func orbitar(chaves: Dictionary, osso: int, desvio: Vector3) -> void:
	_cam = Cinema.assumir()
	_pov = false
	_trilho.clear()
	_orbita = chaves.duplicate(true)
	_orbita_t = 0.0
	_orbita_base = Transform3D(_corpo.global_basis.orthonormalized(), _corpo.global_position)
	_trilho_osso = osso
	_trilho_desvio = desvio
	_encolher_orbita()
	_trilho_mira = ponto(osso) + desvio
	_quadro_da_orbita(0.0)
	Lente.recomecar()


func parar_orbita() -> void:
	_orbita.clear()


func _quadro_da_orbita(delta: float) -> void:
	_orbita_t += delta
	var t := _orbita_t
	var a := curva_em(_orbita["angulo"], t)
	var r := curva_em(_orbita["raio"], t)
	var h := curva_em(_orbita["altura"], t) * C._s(_corpo)
	var onde := _orbita_base * (Vector3(sin(a) * r, h, cos(a) * r))
	var alvo := ponto(_trilho_osso) + _trilho_desvio
	var k := 1.0 - exp(-delta * 7.0)
	_trilho_mira = _trilho_mira.lerp(alvo, k) if delta > 0.0 else alvo
	var rr := _t_ruido
	var mao := Vector3(sin(rr * 1.3) + 0.5 * sin(rr * 3.1 + 1.0),
		sin(rr * 0.9 + 2.0) + 0.5 * sin(rr * 2.6), 0.0) * 0.008
	_cam.fov = curva_em(_orbita["fov"], t)
	_cam.global_position = onde + mao
	if (_trilho_mira - _cam.global_position).length() > 0.01:
		_cam.look_at(_trilho_mira, Vector3.UP)


## Onde a volta bate em alguma coisa, o raio daquele trecho encolhe.
func _encolher_orbita() -> void:
	var espaco := _corpo.get_world_3d().direct_space_state
	var cabeca := ponto(O.CABECA)
	var angulos: Array = _orbita["angulo"]
	var fim := float((angulos[angulos.size() - 1] as Vector2).x)
	var raios: Array = []
	var t := 0.0
	var encolheu := 0
	while t <= fim + 0.001:
		var a := curva_em(angulos, t)
		var r := curva_em(_orbita["raio"], t)
		var h := curva_em(_orbita["altura"], t) * C._s(_corpo)
		var lente := _orbita_base * Vector3(sin(a) * (r + 0.25), h, cos(a) * (r + 0.25))
		var q := PhysicsRayQueryParameters3D.create(cabeca, lente, 1)
		var hit := espaco.intersect_ray(q)
		if not hit.is_empty():
			var livre := cabeca.distance_to(hit["position"] as Vector3) - 0.3
			r = maxf(0.7, minf(r, livre))
			encolheu += 1
		raios.append(Vector2(t, r))
		t += 0.25
	if encolheu > 0:
		print("[orbita] %d de %d pontos da volta encolhidos" % [encolheu, raios.size()])
		_orbita["raio"] = raios


## Valor numa lista de chaves (tempo, valor) em `t`: cubica monotona
## (Fritsch-Carlson), para a volta acelerar e frear sem passar do ponto nem
## voltar para tras entre duas chaves.
static func curva_em(chaves: Array, t: float) -> float:
	var n := chaves.size()
	if n == 0:
		return 0.0
	var p0 := chaves[0] as Vector2
	if n == 1 or t <= p0.x:
		return p0.y
	var ult := chaves[n - 1] as Vector2
	if t >= ult.x:
		# Depois da ultima chave, segue na ultima inclinacao: a camera nao para
		# de estalo se o plano durar um pouco mais que a volta.
		var pen := chaves[n - 2] as Vector2
		return ult.y + (ult.y - pen.y) / maxf(ult.x - pen.x, 0.001) * (t - ult.x) * 0.5
	var i := 0
	while i < n - 2 and t > (chaves[i + 1] as Vector2).x:
		i += 1
	var a := chaves[i] as Vector2
	var b := chaves[i + 1] as Vector2
	var hab := maxf(b.x - a.x, 0.0001)
	var m_a := _inclinacao(chaves, i)
	var m_b := _inclinacao(chaves, i + 1)
	var u := (t - a.x) / hab
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * a.y + (u3 - 2.0 * u2 + u) * hab * m_a 		+ (-2.0 * u3 + 3.0 * u2) * b.y + (u3 - u2) * hab * m_b


static func _inclinacao(chaves: Array, i: int) -> float:
	var n := chaves.size()
	var p := chaves[i] as Vector2
	if i == 0:
		var q := chaves[1] as Vector2
		return (q.y - p.y) / maxf(q.x - p.x, 0.0001)
	if i == n - 1:
		var o := chaves[n - 2] as Vector2
		return (p.y - o.y) / maxf(p.x - o.x, 0.0001)
	var ant := chaves[i - 1] as Vector2
	var prox := chaves[i + 1] as Vector2
	var d0 := (p.y - ant.y) / maxf(p.x - ant.x, 0.0001)
	var d1 := (prox.y - p.y) / maxf(prox.x - p.x, 0.0001)
	if d0 * d1 <= 0.0:
		return 0.0
	# Media harmonica ponderada: monotona e sem ultrapassar.
	var w0 := 2.0 * (prox.x - p.x) + (p.x - ant.x)
	var w1 := (prox.x - p.x) + 2.0 * (p.x - ant.x)
	return (w0 + w1) / (w0 / d0 + w1 / d1)


## Posicao de um osso no mundo.
func ponto(osso: int) -> Vector3:
	return _mundo(osso).origin


# =============================================================================
# Maos de primeira pessoa
# =============================================================================

## Leva os dedos de um lado (0 esquerda, 1 direita) a uma pose de `MaoPosada`.
func dedos(lado: int, nome: StringName, dur: float) -> void:
	_dedos_de[lado] = _dedos_agora(lado)
	_dedos_para[lado] = MaoPosada.pose(nome)
	_dedos_k[lado] = 0.0
	_dedos_dur[lado] = maxf(dur, 0.01)


func braco(lado: int) -> BracoVivo:
	return _bracos[lado] if lado < _bracos.size() else null


func _dedos_agora(lado: int) -> Dictionary:
	var k := _dedos_k[lado]
	if k >= 1.0:
		return _dedos_para[lado]
	return MaoPosada.misturar(_dedos_de[lado], _dedos_para[lado], k * k * (3.0 - 2.0 * k))


# =============================================================================
# Quadro
# =============================================================================

func _process(delta: float) -> void:
	if _corpo == null or not is_instance_valid(_corpo) or _sk == null:
		return
	if not _parado and not _ch.is_empty():
		_t += delta
		_aplicar(delta)
	_t_ruido += delta
	for i in 2:
		if _dedos_k[i] < 1.0:
			_dedos_k[i] = minf(1.0, _dedos_k[i] + delta / _dedos_dur[i])
	if _pov:
		_quadro_do_olho(delta)
	elif not _orbita.is_empty():
		_quadro_da_orbita(delta)
	elif not _trilho.is_empty():
		_quadro_do_trilho(delta)


func _aplicar(_delta: float) -> void:
	var t := _t
	# PS1 STYLE: a pose anda em degraus, como o resto do elenco.
	if not Corpo._luz_por_pixel():
		t = floorf(t * Corpo.POSES_POR_CICLO) / Corpo.POSES_POR_CICLO
	var pose := C.pose_em(_ch, t, _corpo)
	LevantarDoChao.aplicar(_corpo, pose)
	# O folego: o peito sobe e desce por cima da pose.
	if folego > 0.0:
		var f := sin(_t_ruido * TAU * FOLEGO.y) * FOLEGO.x * folego
		var q := _sk.get_bone_pose_rotation(O.TORSO)
		_sk.set_bone_pose_rotation(O.TORSO, q * Quaternion(Vector3.RIGHT, f))


## O olho: bracos vivos no lugar dos de caixa, cabeca recolhida, camera no osso.
func _quadro_do_olho(delta: float) -> void:
	_restaurar_ossos()
	var cabeca := _mundo(O.CABECA)
	var s := C._s(_corpo)
	var base := cabeca.basis.orthonormalized()
	var olho := cabeca.origin + base * (OLHO * s)
	for i in 2:
		_montar_braco_vivo(i, olho, base, delta)
	# Recolhe o que a lente nao pode ver por dentro: a caixa da cabeca e os
	# bracos de caixa (os vivos estao no lugar deles).
	for osso: int in [O.CABECA, O.BRACO_E, O.BRACO_D]:
		_sk.set_bone_pose_scale(osso, Vector3.ONE * 0.001)
	var r := _t_ruido
	var ruido := Vector3(
		sin(r * 1.7) * 0.6 + sin(r * 4.3 + 1.1) * 0.4,
		sin(r * 1.3 + 2.0) * 0.6 + sin(r * 3.7) * 0.4,
		sin(r * 0.9 + 0.5)) * TREMOR_OLHO * tremor
	base = base * Basis.from_euler(Vector3(olho_giro.x + ruido.x, olho_giro.y + ruido.y, ruido.z))
	_cam.global_transform = Transform3D(base, olho)


func _montar_braco_vivo(i: int, olho: Vector3, cabeca: Basis, delta: float) -> void:
	var b := _bracos[i]
	var direita := i == 1
	var braco_osso := O.BRACO_D if direita else O.BRACO_E
	var antebraco_osso := O.ANTEBRACO_D if direita else O.ANTEBRACO_E
	var s := C._s(_corpo)
	var ombro := _mundo(braco_osso).origin
	var ante := _mundo(antebraco_osso)
	var cotovelo := ante.origin
	var eixo := -(ante.basis.orthonormalized().y)
	var punho := cotovelo + eixo * (Corpo.Y_COTOVELO - Corpo.Y_PUNHO) * s
	var d := eixo
	# O dorso: o de fora do braco, pelo osso; virado para longe do olho quando
	# ele olha a palma, e para cima quando a mao espalma no chao.
	var dorso := ante.basis.orthonormalized().x * (1.0 if direita else -1.0)
	if direita and palma_no_olho > 0.0:
		# Quem olha a propria palma deitado dobra o punho para tras: o antebraco
		# sobe na direcao do olhar, e a mao fica atravessada nele, com os dedos
		# para o alto da cabeca. Sem a dobra a palma fica de perfil para a lente
		# e os quatro dedos viram um so.
		var para_olho := (punho - olho).normalized()
		var alto := cabeca.y - para_olho * cabeca.y.dot(para_olho)
		if alto.length() > 0.01:
			d = d.slerp(alto.normalized(), palma_no_olho * 0.8).normalized()
		var palma := para_olho.rotated(d, vira_mao * PI * 0.92)
		dorso = dorso.slerp(palma - d * palma.dot(d), palma_no_olho)
	if espalma > 0.0:
		dorso = dorso.slerp(Vector3.UP, espalma)
	dorso = (dorso - d * dorso.dot(d)).normalized()
	var o := punho - (MaoPosada.punho_de(Vector3.ZERO, d, dorso))
	var pega := BracoVivo.pega(o, d, dorso, _dedos_agora(i))
	b.ombro = ombro
	var meio := (ombro + punho) * 0.5
	var polo := cotovelo - meio
	b.polo = polo.normalized() if polo.length() > 0.001 else Vector3.DOWN
	b.pular(pega)
	b.passo(delta)


func _quadro_do_trilho(delta: float) -> void:
	_trilho_t += delta
	var u := clampf(_trilho_t / _trilho_dur, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	e = lerpf(u, e, 0.75)
	var onde := _catmull(_trilho, e)
	# O operador acompanha o corpo com atraso: a mira persegue o osso.
	var alvo := ponto(_trilho_osso) + _trilho_desvio
	var k := 1.0 - exp(-delta * 5.5)
	_trilho_mira = _trilho_mira.lerp(alvo, k) if _trilho_mira != Vector3.INF else alvo
	var r := _t_ruido
	var mao := Vector3(sin(r * 1.1) + 0.5 * sin(r * 2.9 + 1.0),
		sin(r * 0.8 + 2.0) + 0.5 * sin(r * 2.3), 0.0) * 0.012 * _trilho_tremor
	_cam.fov = lerpf(_trilho_fov.x, _trilho_fov.y, e)
	_cam.global_position = onde + mao
	var dir := _trilho_mira - _cam.global_position
	if dir.length() > 0.001:
		var cima := _trilho_cima
		if absf(dir.normalized().dot(cima)) > 0.99:
			cima = Vector3.BACK
		_cam.look_at(_trilho_mira, cima)


static func _catmull(p: Array[Vector3], u: float) -> Vector3:
	if p.size() == 1:
		return p[0]
	var n := p.size() - 1
	var x := u * float(n)
	var i := clampi(int(floor(x)), 0, n - 1)
	var f := x - float(i)
	var p0 := p[maxi(i - 1, 0)]
	var p1 := p[i]
	var p2 := p[i + 1]
	var p3 := p[mini(i + 2, n)]
	var f2 := f * f
	var f3 := f2 * f
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f3)


func _mundo(osso: int) -> Transform3D:
	return _sk.global_transform * _sk.get_bone_global_pose(osso)


func _restaurar_ossos() -> void:
	if _sk == null or not is_instance_valid(_sk):
		return
	for osso: int in [O.CABECA, O.BRACO_E, O.BRACO_D]:
		_sk.set_bone_pose_scale(osso, Vector3.ONE)


# =============================================================================
# Som
# =============================================================================

## Um som solto num tocador proprio: a piscina de seis vozes da UI descarta em
## silencio, e aqui cada respiracao conta.
func som(nome: StringName, volume_db: float, afinacao: float = 1.0,
		bus: StringName = &"") -> AudioStreamPlayer:
	var s: AudioStream = AudioDirector.stream(nome)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = afinacao
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	if bus != &"":
		p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func _exit_tree() -> void:
	_restaurar_ossos()
	for b: BracoVivo in _bracos:
		if is_instance_valid(b):
			b.queue_free()
	if _palpebra != null and is_instance_valid(_palpebra):
		_palpebra.queue_free()
