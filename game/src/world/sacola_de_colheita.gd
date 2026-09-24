## A sacola de colheita de Jota e Helmer: saco de rafia que enche, pesa e balanca.
##
## O que ela tem de contar sem texto nenhum
## ----------------------------------------
## Quanto ja foi colhido. Vazia, e um saco dobrado pendurado no ombro, do tamanho
## de uma mochila de escola. A cada planta que entra ela INCHA de uma vez — um
## "boing" de mola, com passagem do tamanho velho para o novo — e as colas da
## variedade aparecem saindo pela boca. Com cinco plantas ja nao cabe no ombro:
## vai para as costas, segura pelo gargalo por cima do ombro, como saco de Papai
## Noel. Cheia, com dez, e maior que quem carrega, arrasta no chao atras dele, e
## o fazendeiro anda inclinado para a frente e devagar. A piada e o tamanho; o
## que faz a piada funcionar e o saco se comportar como um objeto pesado.
##
## A fisica
## --------
## Um ponto de massa (o centro do saco) preso por uma corda a uma ancora no
## ombro esquerdo, que sai do osso a cada quadro. Passo por posicao (PBD):
##
##   mola     puxa o saco para o lugar de repouso do jeito de carregar (do lado,
##            no quadril; ou nas costas). Mais mole quanto mais cheio: o saco
##            pesado atrasa na curva e demora a parar de balancar
##   corda    o saco nunca se afasta do ombro mais que o comprimento dela
##   corpo    nao entra no tronco de quem carrega (cilindro em volta do eixo)
##   mundo    uma esfera na fisica do Godot: vaso, parede, guarda-corpo, piso e o
##            JOGADOR empurram o saco. E o que faz ele arrastar no chao quando
##            cresce, bater no vaso quando o fazendeiro vira no corredor e
##            balancar quando o jogador esbarra
##   atrito   encostado no chao, o saco escorrega com atrito: e o arrasto
##
## Nenhum RigidBody: o saco nao empurra ninguem (um corpo rigido de trinta quilos
## pendurado num CharacterBody faria o fazendeiro ser arrastado pelo proprio
## saco), e dois sacos a sessenta passos por segundo custam duas consultas de
## forma cada.
##
## Onde mora a carga
## -----------------
## Em `Plantio`, por fazendeiro (`sacolas`), e nao aqui: o no morre quando o
## jogador sai da estufa, e a erva no saco tem de estar la na volta. Este no so
## desenha e simula; `Convidado` diz o que entrou e o que saiu.
class_name SacolaDeColheita
extends Node3D

## Plantas colhidas ate o saco estar cheio.
const CAPACIDADE := 10
## Peso: o saco em si e cada unidade de erva (Variedades.rende). Quilo de
## desenho animado — a erva e leve; o saco cheio de dez plantas pesa como uma
## pessoa pequena, que e o que o corpo dele tem de mostrar.
const KG_VAZIA := 0.4
const KG_POR_UNIDADE := 0.9

const MAT_SACO: StringName = &"estufa_sacola"
const GRAVIDADE := 3.2
## De que tamanho ele vai para as costas.
const RAIO_COSTAS := Vector2(0.27, 0.37)

var dono: Node3D
var corpo: Corpo
## O que esta dentro (StringName da variedade -> unidades) e quantas plantas.
var carga: Dictionary = {}
var plantas: int = 0

var _malha: MeshInstance3D
var _alca: MeshInstance3D
var _imediata: ImmediateMesh
var _raio := 0.0
var _mola := 1.0
var _mola_v := 0.0
var _p := Vector3.ZERO
var _v := Vector3.ZERO
var _pronta := false
var _eixo := Vector3.UP
var _frente := Vector3.BACK
var _pousada := false
var _pouso := Vector3.ZERO
var _no_chao := false
var _achata := 0.0
var _achata_v := 0.0
var _segura := 0.0
var _ancora := Vector3.ZERO
var _boca := Vector3.ZERO
var _consulta := PhysicsShapeQueryParameters3D.new()
var _esfera := SphereShape3D.new()
var _excluir: Array[RID] = []
var _t_arrasto := 0.0
## O arremesso na pilha (`arremessar`): tempo de voo, de onde e para onde.
var _voo := -1.0
var _voo_de := Transform3D()
var _voo_para := Transform3D()
var _voo_bateu := false
var _ao_pousar := Callable()
## Quanto dura o arco, e quanto o saco fica achatado na pilha antes de a pilha
## o assumir (a malha dela sai da thread nesse meio tempo).
const VOO := 0.95
const VOO_ASSENTA := 0.45


static func raio_de(n: int) -> float:
	return 0.13 + 0.62 * pow(clampf(float(n) / float(CAPACIDADE), 0.0, 1.2), 0.75)


func _ready() -> void:
	top_level = true
	_malha = MeshInstance3D.new()
	_malha.name = "Saco"
	_malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_malha)
	_imediata = ImmediateMesh.new()
	_alca = MeshInstance3D.new()
	_alca.name = "Alca"
	_alca.mesh = _imediata
	_alca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A alca e desenhada em coordenada de mundo: o no dela nao pode herdar a
	# transformada do saco.
	_alca.top_level = true
	add_child(_alca)
	_consulta.shape = _esfera
	_consulta.collision_mask = 1
	_refazer(false)


# --- a carga ----------------------------------------------------------------

## O que o `Plantio` guardou para este fazendeiro (a volta a estufa).
func restaurar(nova_carga: Dictionary, n: int) -> void:
	carga = nova_carga.duplicate()
	plantas = n
	_refazer(false)


## Entrou uma planta: `quanto` unidades da variedade `v`.
func guardar(v: StringName, quanto: int) -> void:
	carga[v] = int(carga.get(v, 0)) + quanto
	plantas += 1
	_refazer(true)
	if _pronta:
		AudioDirector.tocar(&"pegar", _p, -8.0, 0.85)


## Saiu tudo (o caixote). O saco murcha de volta a dobrado, tambem com mola.
func esvaziar() -> void:
	carga = {}
	plantas = 0
	_refazer(true)


func cheia() -> bool:
	return plantas >= CAPACIDADE


func unidades() -> int:
	var n := 0
	for v: StringName in carga:
		n += int(carga[v])
	return n


func peso() -> float:
	return KG_VAZIA + float(unidades()) * KG_POR_UNIDADE


## 0 vazia, 1 cheia.
func fracao() -> float:
	return clampf(float(plantas) / float(CAPACIDADE), 0.0, 1.0)


## Quanto o passo de quem carrega encolhe. Cheia, anda a 62%.
func fator_de_passo() -> float:
	return 1.0 - 0.38 * fracao()


## A inclinacao do corpo (Corpo.inclinacao): do lado, a pessoa pende para o
## lado de LA do saco; nas costas, dobra para a frente para nao cair para tras.
func inclinacao() -> Vector2:
	if _pousada or _voo >= 0.0:
		return Vector2.ZERO
	var f := fracao()
	var lado := 0.07 * f * (1.0 - _segura) + 0.03 * (1.0 - _segura) * signf(f)
	var frente := 0.17 * f * _segura
	return Vector2(lado, frente)


## Onde a mao esquerda segura: a alca na frente do peito, ou o gargalo por cima
## do ombro. INF: mao livre (o saco esta no chao).
func pegada() -> Vector3:
	if _pousada or not _pronta or _voo >= 0.0:
		return Vector3.INF
	var b := _base_do_corpo()
	if _segura > 0.5:
		# O punho na frente do ombro, na altura da clavicula, puxando o gargalo por
		# cima dele: o cotovelo desce para a frente. Com a mao EM CIMA do ombro o
		# braco abria de lado, em asa.
		return _ancora - b.z * 0.13 + b.x * 0.06 - b.y * 0.03
	return _ancora - b.y * 0.26 - b.z * 0.14 + b.x * 0.04


## Pousa o saco no chao, em `onde` (mundo, no piso), para trabalhar com as duas
## maos. `levantar` pega de volta.
func pousar(onde: Vector3) -> void:
	_pousada = true
	_pouso = onde


func levantar() -> void:
	_pousada = false


func esta_pousada() -> bool:
	return _pousada


func voando() -> bool:
	return _voo >= 0.0


## Joga o saco na pilha do deposito: sai de onde esta num arco ate `para` (a
## vaga, em mundo, ja sentada), virando e encolhendo para o tamanho do saco
## amarrado (`raio_final`). Bate, achata, assenta — e so entao `ao_pousar` (a
## pilha passa a desenha-lo) e a sacola volta ao ombro, vazia e dobrada.
func arremessar(para: Transform3D, raio_final: float, ao_pousar: Callable) -> void:
	_voo = 0.0
	_voo_bateu = false
	_voo_de = global_transform
	var k := raio_final / maxf(_raio, 0.01)
	_voo_para = Transform3D(para.basis * Basis.from_scale(Vector3.ONE * k), para.origin)
	_ao_pousar = ao_pousar
	_imediata.clear_surfaces()
	AudioDirector.tocar(&"bracada", _p, -10.0, 0.8)


func _voar(delta: float) -> void:
	_voo += delta
	var t := clampf(_voo / VOO, 0.0, 1.0)
	# Sai rapido da mao e chega devagar no alto do arco: facil de ler como jogado.
	var s := 1.0 - pow(1.0 - t, 1.6)
	var a := _voo_de.origin
	var b := _voo_para.origin
	var altura := 0.7 + 0.35 * a.distance_to(b)
	var pos := a.lerp(b, s) + Vector3.UP * altura * 4.0 * s * (1.0 - s)
	var qa := _voo_de.basis.get_rotation_quaternion()
	var qb := _voo_para.basis.get_rotation_quaternion()
	var ea := _voo_de.basis.get_scale()
	var eb := _voo_para.basis.get_scale()
	var escala := ea.lerp(eb, s)
	if _voo > VOO:
		if not _voo_bateu:
			_voo_bateu = true
			AudioDirector.tocar(&"baque_corpo_%d" % (1 + plantas % 3), b, -9.0, 1.1)
		# Assentando: achata e volta, duas vezes, cada vez menos.
		var tl := _voo - VOO
		var am := 0.16 * exp(-tl * 8.0) * cos(tl * 28.0)
		escala = Vector3(escala.x * (1.0 + am * 0.6), escala.y * (1.0 - am), escala.z * (1.0 + am * 0.6))
	global_transform = Transform3D(Basis(qa.slerp(qb, s)).scaled_local(escala), pos)
	if _voo >= VOO + VOO_ASSENTA:
		_voo = -1.0
		if _ao_pousar.is_valid():
			_ao_pousar.call()
		_ao_pousar = Callable()
		# A sacola nova: dobrada, e desdobra com a mola ao voltar ao ombro.
		restaurar({}, 0)
		_mola = 0.35
		_mola_v = 0.0
		_pronta = false


# --- a fisica ---------------------------------------------------------------

func _base_do_corpo() -> Basis:
	return dono.global_transform.basis.orthonormalized()


## Um passo. Quem chama e o Convidado, no fim do quadro de fisica dele, depois
## que o corpo posou: a ancora sai do osso DESTE quadro.
func passo(delta: float) -> void:
	if dono == null or corpo == null or delta <= 0.0:
		return
	if _voo >= 0.0:
		_voar(delta)
		return
	var esq := corpo.esqueleto()
	if esq == null:
		return
	var b := _base_do_corpo()
	var direita := b.x
	var tras := b.z
	var ombro := esq.global_transform * esq.get_bone_global_pose(Corpo.Osso.BRACO_E).origin
	var alvo_segura := clampf((_raio - RAIO_COSTAS.x) / (RAIO_COSTAS.y - RAIO_COSTAS.x), 0.0, 1.0)
	_segura = move_toward(_segura, alvo_segura, delta * 1.5)
	_ancora = ombro + Vector3.UP * 0.04 + tras * 0.05 * _segura
	var pe := dono.global_position

	# O lugar de repouso de cada jeito de carregar.
	var lado := pe - direita * (0.27 + _raio * 0.78) + Vector3.UP * (0.93 - _raio * 0.2) \
		+ tras * 0.03
	var costas := ombro + tras * (0.16 + _raio * 0.92) - direita * 0.04 \
		+ Vector3.DOWN * (0.22 + _raio * 1.02)
	var alvo := lado.lerp(costas, _segura)
	var corda := lerpf(_ancora.distance_to(lado), _ancora.distance_to(costas), _segura) + 0.05
	if _pousada:
		alvo = _pouso + Vector3.UP * _raio * 0.92
		corda = INF

	if not _pronta or _p.distance_to(_ancora) > 3.5 or not _p.is_finite():
		_p = alvo
		_v = Vector3.ZERO
		_eixo = Vector3.UP
		_pronta = true

	var f := fracao()
	var k := lerpf(60.0, 20.0, f) if not _pousada else 45.0
	var amortece := lerpf(6.5, 4.0, f)
	var inicio := _p
	var acel := (alvo - _p) * k - _v * amortece + Vector3.DOWN * GRAVIDADE
	_v += acel * delta
	_p += _v * delta

	# Restricoes, duas voltas.
	var contato_chao := false
	for volta in 2:
		var d := _p - _ancora
		if d.length() > corda:
			_p = _ancora + d.normalized() * corda
		_p = _fora_do_corpo(_p, pe)
		var empurrao := _fora_do_mundo(_p)
		_p += empurrao
		if empurrao.length() > 0.0005 and empurrao.normalized().y > 0.55:
			contato_chao = true
	var vy_antes := _v.y
	_v = (_p - inicio) / delta
	if contato_chao:
		# Arrasto: o saco no chao escorrega com atrito.
		var at := exp(-6.0 * delta)
		_v.x *= at
		_v.z *= at
		if not _no_chao and vy_antes < -0.4:
			# Bateu no chao: achata e volta, com o baque de um saco de erva — mais
			# grave quanto mais cheio.
			_achata_v += -vy_antes * 0.9
			if vy_antes < -0.8:
				AudioDirector.tocar(&"baque_corpo_%d" % (1 + plantas % 3), _p,
					-18.0 + 8.0 * f, 1.35 - 0.35 * f)
		# Arrastando: o raspar da rafia no epoxi, no ritmo do passo.
		_t_arrasto -= delta
		var rapidez := Vector2(_v.x, _v.z).length()
		if not _pousada and rapidez > 0.2 and _t_arrasto <= 0.0:
			_t_arrasto = 0.85
			AudioDirector.tocar(&"arrasto_corpo", _p, -20.0 + 7.0 * f, 1.15)
	_no_chao = contato_chao

	# O eixo do saco aponta para a ancora (o gargalo vai para onde esta preso);
	# no chao, fica de pe.
	var eixo_alvo := Vector3.UP
	if not _pousada:
		eixo_alvo = (_ancora - _p).normalized().lerp(Vector3.UP, 0.35).normalized()
	_eixo = _eixo.slerp(eixo_alvo, minf(1.0, 7.0 * delta)).normalized()
	# A impressao olha para longe do corpo: para o lado de fora, ou para tras.
	var fora := (-direita).lerp(tras, _segura).normalized()
	_frente = _frente.slerp(fora, minf(1.0, 5.0 * delta)).normalized()

	# As duas molas do desenho: o inchar (boing) e o achatar no chao.
	_mola_v += (-(_mola - 1.0) * 170.0 - _mola_v * 11.0) * delta
	_mola += _mola_v * delta
	var achata_alvo := 0.1 if _no_chao else 0.0
	_achata_v += (-(_achata - achata_alvo) * 140.0 - _achata_v * 10.0) * delta
	_achata = clampf(_achata + _achata_v * delta, -0.2, 0.3)

	_posar()
	_desenhar_alca()


## Empurra `p` para fora do tronco de quem carrega.
func _fora_do_corpo(p: Vector3, pe: Vector3) -> Vector3:
	var alto := p.y - pe.y
	if alto < -0.2 or alto > 1.75:
		return p
	var raio := 0.17 + _raio * 0.82
	var h := Vector2(p.x - pe.x, p.z - pe.z)
	if h.length() >= raio:
		return p
	if h.length() < 0.001:
		h = Vector2(_frente.x, _frente.z)
	h = h.normalized() * raio
	return Vector3(pe.x + h.x, p.y, pe.z + h.y)


## O quanto o mundo empurra a esfera do saco para fora de si.
func _fora_do_mundo(p: Vector3) -> Vector3:
	var mundo := get_world_3d()
	if mundo == null:
		return Vector3.ZERO
	if _excluir.is_empty():
		var corpo_fisico := dono as PhysicsBody3D
		if corpo_fisico != null:
			_excluir.append(corpo_fisico.get_rid())
			# O chao da rua passa pela altura da cabeca na estufa, e o dono ja tem
			# excecao com ele (InteriorNoMundo._ao_nascer): o saco tambem.
			for outro: PhysicsBody3D in corpo_fisico.get_collision_exceptions():
				_excluir.append(outro.get_rid())
	_esfera.radius = maxf(0.08, _raio * 0.88)
	_consulta.transform = Transform3D(Basis(), p)
	_consulta.exclude = _excluir
	var pares := mundo.direct_space_state.collide_shape(_consulta, 8)
	var maior := Vector3.ZERO
	for k in range(0, pares.size() - 1, 2):
		var empurra: Vector3 = pares[k + 1] - pares[k]
		if empurra.length() > maior.length():
			maior = empurra
	return maior


func _posar() -> void:
	var y := _eixo
	var z := (_frente - y * _frente.dot(y)).normalized()
	if z.length_squared() < 0.5:
		z = Vector3.BACK
	var x := y.cross(z).normalized()
	var esticada := 1.0 + clampf(_v.length() * 0.03, 0.0, 0.08)
	var s := _mola
	var escala := Vector3(s * (1.0 + _achata * 0.55), s * (1.0 - _achata) * esticada,
		s * (1.0 + _achata * 0.55))
	# Achatado, o centro desce junto, e o fundo continua no chao.
	var centro := _p - Vector3.UP * _raio * _achata * 0.8
	global_transform = Transform3D(Basis(x, y, z).scaled_local(escala), centro)
	_boca = centro + y * _raio * 1.2 * s


# --- a alca -----------------------------------------------------------------

## A fita da alca, em coordenada de mundo, refeita a cada quadro: do gargalo
## por cima do ombro e atravessada no peito ate o quadril direito. Nas costas nao
## ha alca — ha o gargalo torcido ate o punho.
func _desenhar_alca() -> void:
	_imediata.clear_surfaces()
	_alca.global_transform = Transform3D.IDENTITY
	if _pousada:
		return
	var b := _base_do_corpo()
	var pe := dono.global_position
	var mat := _material(MAT_SACO)
	if _segura < 0.5:
		var peito := pe + Vector3.UP * 1.17 - b.z * 0.15
		var quadril := pe + b.x * 0.19 + Vector3.UP * 0.93 - b.z * 0.04
		var pts := PackedVector3Array([_boca, _ancora + Vector3.UP * 0.03, peito, quadril])
		_fita(pts, 0.045, mat, pe)
	else:
		# O gargalo torcido, do saco ate a mao por cima do ombro.
		var mao := pegada()
		var pts := PackedVector3Array([_boca, _boca.lerp(mao, 0.5) + Vector3.UP * 0.02, mao])
		_fita(pts, 0.05 + _raio * 0.05, mat, pe)


func _fita(pts: PackedVector3Array, larg: float, mat: Material, pe: Vector3) -> void:
	# Mais pontos, com a curva de Catmull-Rom: a fita dobra no ombro, nao quebra.
	var cheia := PackedVector3Array()
	for k in pts.size() - 1:
		var p0 := pts[maxi(k - 1, 0)]
		var p1 := pts[k]
		var p2 := pts[k + 1]
		var p3 := pts[mini(k + 2, pts.size() - 1)]
		for j in 5:
			var t := float(j) / 5.0
			cheia.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	cheia.append(pts[pts.size() - 1])
	_imediata.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var comp := 0.0
	for k in cheia.size() - 1:
		var a := cheia[k]
		var c := cheia[k + 1]
		var dir := (c - a).normalized()
		# A fita deita sobre o corpo: a largura corre em volta dele.
		var fora_a := Vector3(a.x - pe.x, 0.0, a.z - pe.z).normalized()
		var fora_c := Vector3(c.x - pe.x, 0.0, c.z - pe.z).normalized()
		var la := dir.cross(fora_a).normalized() * larg * 0.5
		var lc := dir.cross(fora_c).normalized() * larg * 0.5
		var u0 := comp
		comp += a.distance_to(c)
		var u1 := comp
		for q: Array in [[a - la, u0, 0.0, fora_a], [a + la, u0, 1.0, fora_a],
				[c + lc, u1, 1.0, fora_c], [a - la, u0, 0.0, fora_a],
				[c + lc, u1, 1.0, fora_c], [c - lc, u1, 0.0, fora_c]]:
			_imediata.surface_set_normal(q[3])
			_imediata.surface_set_color(Color(0.92, 0.9, 0.84))
			# A fita e rafia sem impressao: a faixa alta da textura, perto da boca.
			_imediata.surface_set_uv(Vector2(float(q[1]) * 0.5, 0.06 + float(q[2]) * 0.03))
			_imediata.surface_add_vertex(q[0])
	_imediata.surface_end()


# --- a malha ----------------------------------------------------------------

func _material(nome: StringName) -> Material:
	var m: Material = Interiores.material(nome)
	return m


## Refaz o saco no tamanho da carga. `mola`: com o boing (o saco passa do tamanho
## velho para o novo balancando), ou direto (restaurado da memoria).
func _refazer(mola: bool) -> void:
	var novo := raio_de(plantas)
	if mola and _raio > 0.0:
		_mola = _raio / novo
		_mola_v = 0.0
	_raio = novo
	if _malha == null:
		return
	var obra := {}
	var semente := hash(dono.get_instance_id()) if dono != null else 7
	malha_do_saco(obra, _raio, fracao(), semente, false)
	malha_do_conteudo(obra, _raio, plantas, carga, semente + plantas * 7919, 9, false)
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
		am.surface_set_material(am.get_surface_count() - 1, _material(nome))
	_malha.mesh = am


## O saco, em coordenada propria (centro da barriga na origem, boca em +Y):
## revolucao com barriga, gargalo franzido, boca virada para fora e as duas
## orelhas do fundo que todo saco cheio tem. A carga empelota a rafia por
## dentro; a boca franze em pregas. `fechado`: amarrado para a pilha — gargalo
## apertado e boca pequena. Estatica e sem no: a pilha do deposito
## (DepositoDaEstufa) monta os mesmos sacos na thread.
static func malha_do_saco(obra: Dictionary, R: float, cheio: float, semente: int,
		fechado: bool, tinta: Color = Color.WHITE) -> void:
	var b := KitEstufa._balde(obra, MAT_SACO)
	var gargalo := (0.055 + 0.17 * R) * (0.45 if fechado else 1.0)
	var aba := 1.12 if fechado else 1.55
	# (raio, altura, V) do fundo a boca e de volta para dentro.
	var perfil: Array[Vector3] = [
		Vector3(0.0, -R * 0.98, 0.0),
		Vector3(R * 0.55, -R * 0.95, 0.03),
		Vector3(R * 0.86, -R * 0.82, 0.08),
		Vector3(R * 1.0, -R * 0.42, 0.2),
		Vector3(R * 1.02, 0.0, 0.36),
		Vector3(R * 0.97, R * 0.4, 0.52),
		Vector3(R * 0.8, R * 0.72, 0.66),
		Vector3(R * 0.52, R * 0.95, 0.78),
		Vector3(gargalo * 1.1, R * 1.08, 0.86),
		Vector3(gargalo, R * 1.13, 0.9),
		Vector3(gargalo * aba, R * 1.22 + 0.02, 0.95),
		Vector3(gargalo * (aba - 0.1), R * 1.25 + 0.03, 0.98),
		Vector3(gargalo * 1.15, R * 1.18 + 0.02, 1.0),
	]
	var lados := 22
	var aneis := perfil.size()
	var pos: Array[Vector3] = []
	for a in aneis:
		var pf: Vector3 = perfil[a]
		var rel := pf.y / maxf(R, 0.01)
		for k in lados + 1:
			var ang := TAU * float(k % lados) / float(lados)
			var r := pf.x
			# Pelotas da carga por dentro: mais cheio, mais pelota.
			var pel := KitEstufa._h(semente, k % lados, a) - 0.5
			r *= 1.0 + (0.05 + 0.08 * cheio) * pel * smoothstep(-1.0, -0.5, rel) \
				* (1.0 - smoothstep(0.8, 1.05, rel))
			# Pregas do franzido, do ombro ate a boca.
			r *= 1.0 + 0.11 * sin(ang * 11.0 + rel * 2.0) * smoothstep(0.62, 1.05, rel)
			# Vazio, o saco e um pano dobrado: amassa em volta toda.
			r *= 1.0 + 0.18 * (1.0 - cheio) * sin(ang * 3.0 + float(a)) \
				* smoothstep(-1.0, 0.8, rel) * (1.0 - smoothstep(0.85, 1.1, rel))
			# As orelhas do fundo, a 0 e a PI.
			var orelha := exp(-pow(minf(absf(ang), absf(ang - PI)) / 0.32, 2.0)) \
				+ exp(-pow(absf(ang - TAU) / 0.32, 2.0))
			r *= 1.0 + 0.22 * orelha * smoothstep(-0.55, -0.95, rel) * (0.4 + 0.6 * cheio)
			pos.append(Vector3(cos(ang) * r, pf.y, sin(ang) * r))
	var inicio := b.v.size()
	for a in aneis:
		for k in lados + 1:
			var i := a * (lados + 1) + k
			var ku := k + 1 if k < lados else 1
			var kd := k - 1 if k > 0 else lados - 1
			var au := mini(a + 1, aneis - 1)
			var ad := maxi(a - 1, 0)
			var tu: Vector3 = pos[a * (lados + 1) + ku] - pos[a * (lados + 1) + kd]
			var tv: Vector3 = pos[au * (lados + 1) + k] - pos[ad * (lados + 1) + k]
			var n := tu.cross(tv).normalized()
			var p: Vector3 = pos[i]
			var radial := Vector3(p.x, 0.0, p.z)
			# A ultima volta e a boca virada: a de dentro olha para o eixo.
			var dentro := a == aneis - 1
			if (n.dot(radial) < 0.0) != dentro and radial.length() > 0.001:
				n = -n
			if n.length_squared() < 0.5:
				n = Vector3.DOWN if a == 0 else Vector3.UP
			var cor := tinta if not dentro else Color(0.45, 0.43, 0.4)
			b.vert(p, n, Vector2(1.0 - float(k) / float(lados), 1.0 - (perfil[a] as Vector3).z), cor)
	for a in aneis - 1:
		for k in lados:
			var i0 := inicio + a * (lados + 1) + k
			var i1 := i0 + lados + 1
			b.quad(i0, i0 + 1, i1 + 1, i1, b.n[i0] + b.n[i0 + 1] + b.n[i1] + b.n[i1 + 1])
	# A corda amarrada no gargalo, com as duas pontas soltas.
	var kb := KitEstufa._balde(obra, KitEstufa.MAT)
	var y := R * 1.12
	var anel := PackedVector3Array()
	var raios := PackedFloat32Array()
	for k in 13:
		var ang := TAU * float(k) / 12.0
		anel.append(Vector3(cos(ang) * gargalo * 1.12, y, sin(ang) * gargalo * 1.12))
		raios.append(0.009 + 0.004 * R)
	var ponta := anel[0]
	for j in 3:
		anel.append(ponta + Vector3(0.03 * float(j + 1), -0.05 * float(j + 1), 0.01 * float(j)))
		raios.append(0.008)
	KitEstufa._tubo(kb, anel, raios, 5, KitEstufa._r(KitEstufa.R_SACO), Color(0.86, 0.72, 0.5))


## As colas saindo pela boca, na cor da variedade que esta dentro. O numero
## cresce com a carga, e o tamanho tambem: o saco cheio cospe cola gigante.
## `fechado`: o saco amarrado da pilha, com as colas presas no gargalo.
static func malha_do_conteudo(obra: Dictionary, R: float, plantas: int, carga: Dictionary,
		semente: int, colas_max: int, fechado: bool) -> void:
	if plantas <= 0 or carga.is_empty():
		return
	var gargalo := (0.055 + 0.17 * R) * (0.45 if fechado else 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var variedades: Array = carga.keys()
	var total := 0
	for w: StringName in variedades:
		total += int(carga[w])
	var colas := mini(plantas + 1, colas_max)
	for k in colas:
		# Sorteio pelo peso de cada variedade na carga.
		var sorte := rng.randf() * float(total)
		var v: StringName = variedades[0]
		for w: StringName in variedades:
			sorte -= float(carga[w])
			if sorte <= 0.0:
				v = w
				break
		var ang := rng.randf() * TAU
		var dist := gargalo * rng.randf_range(0.0, 0.75)
		var pe := Vector3(cos(ang) * dist, R * 1.05, sin(ang) * dist)
		var abre := rng.randf_range(0.2, 0.75) * (0.6 if fechado else 1.0)
		var eixo := (Vector3.UP + Vector3(cos(ang), 0.0, sin(ang)) * abre).normalized()
		var comp := (0.09 + 0.2 * R) * rng.randf_range(0.8, 1.15) * (0.75 if fechado else 1.0)
		_cola_da_boca(obra, pe, eixo, comp, 0.024 + 0.05 * R, rng, v)
	# As folhas de leque caidas pela borda.
	var fb := KitEstufa._balde(obra, KitEstufa.MAT_FOLHA)
	var r_fol := KitEstufa._r(KitEstufa.R_FOLIOLO)
	for k in mini(plantas, 4):
		var ang := rng.randf() * TAU
		var fora := Vector3(cos(ang), 0.0, sin(ang))
		var p0 := fora * gargalo * 1.3 + Vector3.UP * R * 1.2
		var d := (fora + Vector3.DOWN * 0.6).normalized()
		var verde := Color(0.36, 0.6, 0.24) * rng.randf_range(0.85, 1.1)
		verde.a = 1.0
		KitEstufa._foliolo(fb, p0, d, fora.cross(Vector3.UP).normalized(), Vector3.UP,
			0.1 + 0.12 * R, 0.03 + 0.03 * R, 0.2, r_fol, verde, verde.darkened(0.2))


## Uma cola saindo da boca: botoes do kit empilhados, grossos embaixo e em
## ponta no alto, com foliolo de acucar. Sem o tufo de pistilo da planta: no
## tamanho do saco cheio, os dois cartoes laranja viravam quadrados de sete
## centimetros e a boca parecia um vaso de flor.
static func _cola_da_boca(obra: Dictionary, pe: Vector3, eixo: Vector3, comp: float,
		grossura: float, rng: RandomNumberGenerator, v: StringName) -> void:
	var brilha := v == &"vagalume"
	var b := KitEstufa._balde(obra, KitEstufa.MAT_BRILHO if brilha else KitEstufa.MAT_FOLHA)
	var verde := KitEstufa._verde_de(v)
	var cor := Color(0.84, 0.97, 0.66) * verde
	cor.a = 1.0
	var r_bud := KitEstufa._r(KitEstufa.R_BUD_BRILHO if brilha else KitEstufa.R_BUD)
	var base := KitEstufa._base_do_eixo(eixo)
	var qtd := 4
	for k in qtd:
		var tt := (float(k) + 0.5) / float(qtd)
		var raio := grossura * (1.0 - 0.5 * tt * tt)
		var fora := (base.x * rng.randf_range(-1.0, 1.0) + base.z * rng.randf_range(-1.0, 1.0)) \
			* raio * 0.22
		KitEstufa._botao(b, pe + eixo * comp * tt + fora, Vector3(raio, raio * 1.3, raio),
			Basis(eixo, rng.randf() * TAU) * base, 6, 3, rng, cor, r_bud)
	var r_acu := KitEstufa._r(KitEstufa.R_ACUCAR)
	var cor_acu := Color(0.95, 1.0, 0.88) * verde
	cor_acu.a = 1.0
	for k in 3:
		var a := rng.randf() * TAU
		var saida := (base.x * cos(a) + base.z * sin(a)).normalized()
		var d := (saida * 0.8 + eixo * 0.6).normalized()
		KitEstufa._foliolo(b, pe + eixo * comp * rng.randf_range(0.2, 0.8) + saida * grossura * 0.4,
			d, eixo.cross(d).normalized(), eixo, grossura * 2.2, grossura * 0.75, 0.15, r_acu,
			cor_acu, cor_acu.darkened(0.15), 0.25)
