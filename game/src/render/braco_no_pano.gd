## O pano da batina AAA (`PanoGPU`: capuz, murca e batina) contra o braco vivo
## (`BracoVivo`/`BracoDoPadre`) que aparece no lugar do braco do `Corpo`.
##
## Por que existe
## --------------
## Quem troca o braco do `Corpo` pelo braco vivo (o cerco no capo, a janela do
## carona) apaga o braco do corpo pelo no `BracoPodreE`/`D` (ver `CorpoAAA`), e a
## manga da batina some com ele. Mas o pano continuava batendo no braco
## escondido: os colisores do braco no `PanoGPU` sao presos nos ossos do
## `Corpo`, que o IK de quem anima poe em outro lugar, com outro comprimento. A
## murca deitava em cima de um braco que nao se ve, e o que se ve passava pelo
## meio dela. E com o braco erguido (o do capo deitado, as maos no vidro por
## cima da cabeca) o pano perto do ombro estava preso no tronco: a borda da
## cava da batina e a murca, com 1 a 4 cm de folga, eram cortadas pelo umero.
##
## Como funciona
## -------------
## Um no por `Corpo` (`ligar`), rodando depois de quem anima o corpo e o braco
## vivo e antes do `PanoGPU` (`process_priority` 99; ou `aplicar()` na mao, com
## `automatico` falso, para quem anima o braco depois disso). Por lado, com o
## braco vivo a vista:
## - os ossos do braco do `Corpo` (que nao aparece) giram para a reta do braco
##   vivo: do ombro para o cotovelo dele e dali para o punho. O que esta preso
##   neles (o pano que `soltar_capa` liga ao umero) vai junto;
## - os colisores do braco no pano (umero, antebraco e mao: os do `CorpoAAA`)
##   vao para os ossos do braco vivo, com o raio da malha dele.
## Sem o braco vivo, os colisores voltam aos do `Corpo`.
##
## `soltar_capa` (so para quem ergue o braco por cima da cabeca, o do capo):
## a murca, a borda da cava da batina e a barra do capuz passam a subir com o
## umero (o segundo osso das particulas, `PanoGPU.ligar_ao_osso`), a batina ve o
## umero (ela passava entre ele e o tronco) e a capa fica mais solta.
##
## Uso
## ---
##     var bp := BracoNoPano.ligar(corpo, capuz.pano)
##     bp.por_braco(true, braco_direito)   # e/ou o esquerdo
##     bp.soltar_capa()                    # opcional: braco erguido
## Custo: nenhum colisor novo (os tres de cada braco sao os do `CorpoAAA`); na
## CPU, dois giros de osso e tres `mover_colisor` por braco por quadro.
class_name BracoNoPano
extends Node

## O raio do braco para o pano: umero, antebraco e mao (m no modelo do
## `BracoDoPadre`, o percentil 90 da pele em volta do eixo medido na malha;
## vezes a `escala` do braco). O de tubos (`--braco-antigo`), em metros.
const RAIO_MODELO := Vector3(0.057, 0.036, 0.05)
const RAIO_TUBOS := Vector3(0.042, 0.032, 0.04)
## A mais no raio: o pano desenhado e a superficie das particulas MAIS o desvio
## de cada vertice (`BatinaAAA`), e a particula para no raio mais a espessura.
const MARGEM := 0.012
## `soltar_capa`: a folga (m) e de que linha da grade em diante, e a da barra de
## cima (que era presa no tronco; 0 continua presa). A murca tinha 1 a 4 cm nos
## ombros: o braco erguido nao a levantava, a furava.
const MURCA_FOLGA := Vector3(0.16, 3, 0.04)
const BATINA_FOLGA := Vector3(0.06, 1, 0.04)
const CAPUZ_FOLGA := Vector3(0.0, 0, 0.03)
## A folga (m) do pano que anda com o umero (peso > 0,3 em `LIGA`).
const FOLGA_NO_BRACO := 0.03
## `soltar_capa`: de que lado do braco cada peca fica quando ele a alcanca
## (`PanoGPU.colisor_de_um_lado`: 0 pelo lado mais perto, +1 por fora, -1 por
## dentro, +2 pelas costas) e o raio a mais (m, na pessoa de 1,72 m). Com o
## colisor de um lado, as arestas do pano tambem batem no braco. Medido no capo:
## o lado forcado abria dobra no ombro (o pano de cima do ombro e o do lado do
## braco, empurrados para lados opostos); pelo mais perto, com raio a mais (a
## grade da murca tem uma particula a cada 5 cm; a borda da batina na cava e
## desenhada ate 7 cm fora da grade), e o que menos fura.
const LADO := {"Murca": Vector2(0.0, 0.04), "Capuz": Vector2(0.0, 0.02),
	"Batina": Vector2(0.0, 0.06)}
## `soltar_capa`: quanto de cada peca sobe com o umero. [peso maximo, alcance
## (m do eixo do umero no repouso: peso inteiro ate x, nenhum depois de y),
## linhas (a partir de x ganha peso, inteiro em y)]. Vazio no capo: preso no
## umero, o pano dava a volta no braco com celulas de mais de 150 graus, e a
## superficie entre as particulas cortava o braco (medido: 20-30 mm).
const LIGA := {}

var corpo: Corpo
var pano: PanoGPU
## Falso: quem anima o braco chama `aplicar()` depois de mexer nele.
var automatico: bool = true
var margem: float = MARGEM
## Por lado (true = direito): o braco vivo.
var _bracos: Dictionary = {}
## Por lado: [[indice, osso, a, b, raio] do umero, antebraco e mao, originais].
var _cols: Dictionary = {}
var _no_vivo: Dictionary = {}


## O no do `Corpo` `c` com o pano `p` (cria na primeira vez; fica no meta
## `braco_no_pano`). Null sem pano ou sem os colisores do braco.
static func ligar(c: Corpo, p: PanoGPU) -> BracoNoPano:
	if c == null or p == null:
		return null
	if c.has_meta(&"braco_no_pano"):
		var ja := c.get_meta(&"braco_no_pano") as BracoNoPano
		if ja != null and is_instance_valid(ja):
			return ja
	var n := BracoNoPano.new()
	n.name = "BracoNoPano"
	n.corpo = c
	n.pano = p
	n.process_priority = 99
	n._achar_colisores()
	c.add_child(n)
	c.set_meta(&"braco_no_pano", n)
	return n


## O braco vivo do lado `direita` (null solta o lado).
func por_braco(direita: bool, b: BracoVivo) -> void:
	if b == null:
		_bracos.erase(direita)
	else:
		_bracos[direita] = b


## Os colisores do braco do lado `direita` no pano: [[indice, osso, a, b, raio]]
## (umero, antebraco, mao), ou vazio.
func colisores(direita: bool) -> Array:
	return _cols.get(direita, [])


func _achar_colisores() -> void:
	_cols.clear()
	var cols := pano.colisores()
	for direita: bool in [false, true]:
		var ob := Corpo.Osso.BRACO_D if direita else Corpo.Osso.BRACO_E
		var oa := Corpo.Osso.ANTEBRACO_D if direita else Corpo.Osso.ANTEBRACO_E
		var achados: Array = []
		for i in cols.size():
			var col: Array = cols[i]
			if int(col[0]) == ob and achados.is_empty():
				achados.append([i, ob, col[1], col[2], col[3]])
			elif int(col[0]) == oa and achados.size() in [1, 2]:
				achados.append([i, oa, col[1], col[2], col[3]])
		if achados.size() >= 2:
			_cols[direita] = achados


func _process(_delta: float) -> void:
	if automatico:
		aplicar()


## O quadro de agora: o braco do `Corpo` e os colisores no braco vivo (ou de
## volta aos do `Corpo`).
func aplicar() -> void:
	if corpo == null or pano == null or not is_instance_valid(pano):
		return
	var esq := corpo.esqueleto()
	if esq == null:
		return
	for direita: bool in _cols:
		var b := _bracos.get(direita, null) as BracoVivo
		var vivo := b != null and is_instance_valid(b) and b.is_visible_in_tree() \
			and not b.pegada.is_empty()
		if not vivo:
			if _no_vivo.get(direita, false):
				for c: Array in _cols[direita]:
					pano.mover_colisor(int(c[0]), c[2], c[3], float(c[4]))
				_no_vivo[direita] = false
			continue
		_no_vivo[direita] = true
		var bx := b.global_transform
		var ombro := bx * b.ombro
		var cot := bx * b.cotovelo_montado
		var pun := bx * b.punho_montado
		var palma := bx * (b.pegada["o"] as Vector3)
		_corpo_no_braco(esq, direita, ombro, cot, pun)
		var r := RAIO_TUBOS
		if b is BracoDoPadre:
			r = RAIO_MODELO * float(b.get(&"escala"))
		var pontos := [[ombro, cot, r.x], [cot, pun, r.y], [pun, palma, r.z]]
		var achados: Array = _cols[direita]
		for k in mini(achados.size(), 3):
			var c: Array = achados[k]
			var t := esq.global_transform * esq.get_bone_global_pose(int(c[1]))
			var inv := Transform3D(t.basis.orthonormalized(), t.origin).affine_inverse()
			pano.mover_colisor(int(c[0]), inv * (pontos[k][0] as Vector3),
				inv * (pontos[k][1] as Vector3), float(pontos[k][2]) + margem)


## Gira o braco do `Corpo` (escondido) para a reta do braco vivo: o umero do
## ombro dele para `cot`, o antebraco para `pun` (mundo).
func _corpo_no_braco(esq: Skeleton3D, direita: bool, _ombro: Vector3, cot: Vector3,
		pun: Vector3) -> void:
	var ob := Corpo.Osso.BRACO_D if direita else Corpo.Osso.BRACO_E
	var oa := Corpo.Osso.ANTEBRACO_D if direita else Corpo.Osso.ANTEBRACO_E
	var inv := esq.global_transform.affine_inverse()
	var pai := esq.get_bone_global_pose(esq.get_bone_parent(ob))
	var gb := esq.get_bone_global_pose(ob)
	var para_c := inv * cot
	var dir_u := (para_c - gb.origin).normalized()
	var agora_u := (gb.basis * Vector3.DOWN).normalized()
	if dir_u.length_squared() > 0.5 and agora_u.dot(dir_u) < 0.99999:
		var nb := Basis(Quaternion(agora_u, dir_u)) * gb.basis
		esq.set_bone_pose_rotation(ob, (pai.basis.inverse() * nb).orthonormalized().get_rotation_quaternion())
	var gb2 := esq.get_bone_global_pose(ob)
	var ga := gb2 * Transform3D(Basis(esq.get_bone_pose_rotation(oa)), esq.get_bone_pose_position(oa))
	var dir_a := (inv * pun - ga.origin).normalized()
	var agora_a := (ga.basis * Vector3.DOWN).normalized()
	if dir_a.length_squared() > 0.5 and agora_a.dot(dir_a) < 0.99999:
		var na := Basis(Quaternion(agora_a, dir_a)) * ga.basis
		esq.set_bone_pose_rotation(oa, (gb2.basis.inverse() * na).orthonormalized().get_rotation_quaternion())


## A capa de quem ergue o braco por cima da cabeca: o pano perto do ombro sobe
## com o umero (`LIGA`), a batina ve o umero, cada peca fica do lado dela do
## braco (`LADO`), e murca, batina e a barra do capuz ficam mais soltas
## (`MURCA_FOLGA`, `BATINA_FOLGA`, `CAPUZ_FOLGA`). Chame uma vez, antes de ele
## aparecer.
func soltar_capa(murca := MURCA_FOLGA, batina := BATINA_FOLGA, liga := LIGA,
		capuz := CAPUZ_FOLGA, lados := LADO) -> void:
	var esq := corpo.esqueleto()
	if esq == null:
		return
	var s := corpo.altura() / Corpo.ALTURA_REF
	for pc: PanoGPU.PecaDePano in pano.pecas:
		var folga := Vector3.ZERO
		match pc.nome:
			"Murca":
				folga = murca
			"Batina":
				folga = batina
				for direita: bool in _cols:
					pano.ver_colisor(pc, int((_cols[direita] as Array)[0][0]), true)
			"Capuz":
				folga = capuz
		if folga.x > 0.0 or folga.z > 0.0:
			pano.soltar(pc, folga.x * s, int(folga.y), folga.z * s)
		if lados.has(pc.nome):
			for direita: bool in _cols:
				for c: Array in _cols[direita]:
					var ld: Vector2 = lados[pc.nome]
					pano.colisor_de_um_lado(pc, int(c[0]), ld.x, ld.y * s)
		if not liga.has(pc.nome):
			continue
		var cfg: Array = liga[pc.nome]
		for direita: bool in [false, true]:
			var ob := Corpo.Osso.BRACO_D if direita else Corpo.Osso.BRACO_E
			var oa := Corpo.Osso.ANTEBRACO_D if direita else Corpo.Osso.ANTEBRACO_E
			var a := esq.get_bone_global_rest(ob).origin
			var b := esq.get_bone_global_rest(oa).origin
			var lado := 1.0 if a.x > 0.0 else -1.0
			var alcance: Vector2 = cfg[1] * s
			var linhas: Vector2 = cfg[2]
			var pesos := PackedFloat32Array()
			pesos.resize(pc.n)
			for i in pc.n:
				var p := pano.repouso_de(pc, i)
				var ab := b - a
				var t0 := (p - a).dot(ab) / ab.length_squared()
				var t := clampf(t0, 0.0, 1.0)
				var d := p.distance_to(a + ab * t)
				# So o pano em volta do umero, abaixo do ombro: o de cima do ombro,
				# girando com o braco erguido, dava a volta na junta e ia parar
				# debaixo do braco (a gola da murca no caminho do umero).
				var w := float(cfg[0]) * (1.0 - smoothstep(alcance.x, alcance.y, d)) \
					* smoothstep(0.03 * s, 0.10 * s, lado * p.x) * smoothstep(0.0, 0.25, t0)
				if linhas.y > linhas.x:
					w *= smoothstep(linhas.x, linhas.y, float(i / pc.w))
				else:
					w *= 1.0 if i / pc.w == 0 else 0.0
				pesos[i] = w
			# O pano que anda com o braco nao se afasta do lugar dele mais que
			# `FOLGA_NO_BRACO`: no tranco da cabecada ele ficava para tras, e o
			# braco passava entre duas particulas.
			for i in pc.n:
				if pesos[i] > 0.3:
					var o := i * PanoGPU.FIXO_FLOATS + 9
					pc.fixo[o] = minf(pc.fixo[o], FOLGA_NO_BRACO * s)
			# A batina tem o quadril no segundo osso (a barra de cima so 10%): troca.
			pano.ligar_ao_osso(pc, ob, pesos, pc.nome == "Batina")
