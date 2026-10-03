## O dente que sai no terceiro golpe e fica pendurado por um fio de gengiva,
## balancando na frente do labio de baixo, como o olho no nervo.
##
## Por que existe
## --------------
## Pedido do usuario (26/09/2026, no pop-up da boca): "dente pendurado pela
## gengiva". O olho pendurado ja provou que gore que fica no corpo dele, fisico,
## le melhor que peca voando para um alvo (`olho-pendurado-fica`).
##
## Como funciona
## -------------
## Em espaco de mundo (o no e `top_level`):
##   - o fio e uma corrente de Verlet presa no alveolo (que anda com a cabeca) e
##     no colo do dente; ele cede sob tensao ate `FIO_MAX`, como tecido;
##   - o dente e a peca inteira do glb (`Lasca_<id>_inteiro`, o mesmo material dos
##     dentes, sem pipeline novo), pendurado pelo colo: a coroa acerta, amortecida,
##     para a direcao do fio;
##   - a frente da cara (`OlhoSolto._frente_em`) segura o dente na frente do
##     labio, e nao dentro dele;
##   - o fio e um cabo desenhado de novo a cada quadro (`ImmediateMesh`), com o
##     mesmo material do nervo do olho (ja aquecido na cena).
class_name DentePendurado
extends Node3D

const PONTOS := 7
## O fio: o que ja sai, o maximo que ele estica e quanto cede por segundo sob
## tensao; os raios no alveolo e no dente (m, em escala de gente).
const FIO_INICIO := 0.004
const FIO_MAX := 0.011
const FIO_CEDE := 0.06
const FIO_RAIO := Vector2(0.0019, 0.0009)
const CABO_ANEIS := 16
const CABO_LADOS := 8
const PASSO := 1.0 / 240.0
const ITERACOES := 8
const GRAVIDADE := Vector3(0.0, -9.8, 0.0)
const ARRASTO_DENTE := 5.0
const ARRASTO_FIO := 10.0
## O dente molhado gruda na pele: quanto da velocidade de lado perde encostado.
const GRUDA := 0.3
## O raio do dente para a colisao com a frente da cara (m).
const RAIO_DENTE := 0.0035

var _cab: CabecaDoPadre
var _dente: MeshInstance3D
var _ancora := Vector3.ZERO
var _colo := Vector3.ZERO
var _coroa := Vector3.DOWN
var _escala := 1.0
var _fio := PackedVector3Array()
var _antes := PackedVector3Array()
var _comprimento := FIO_INICIO
var _giro := Vector3.ZERO
var _malha: ImmediateMesh
var _mat: StandardMaterial3D
var _t := 0.0


## Prende o dente `dente` (a peca solta, ja posta no lugar dele) na cabeca `cab`.
## `ancora` e o alveolo e `colo_local` o colo no espaco da peca, `coroa_local` a
## direcao do colo para a ponta no espaco da peca; `impulso` o tranco (m/s).
func soltar(cab: CabecaDoPadre, dente: MeshInstance3D, ancora: Vector3, colo_local: Vector3,
		coroa_local: Vector3, impulso: Vector3) -> void:
	name = "DentePendurado"
	top_level = true
	_cab = cab
	_dente = dente
	_ancora = ancora
	_colo = colo_local
	_coroa = coroa_local.normalized()
	_escala = cab.global_basis.get_scale().x
	OlhoSolto._montar_frente()
	_malha = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Fio"
	mi.mesh = _malha
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	add_child(mi)
	# O mesmo material do nervo do olho (`OlhoSolto.preparar`): o mesmo shader,
	# ja compilado quando o olho aquece.
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 0.42
	_mat.metallic_specular = 0.35
	var a := cab.global_transform * ancora
	var c := dente.global_transform * colo_local
	_fio.resize(PONTOS)
	_antes.resize(PONTOS)
	for i in PONTOS:
		var f := float(i) / float(PONTOS - 1)
		_fio[i] = a.lerp(c, f)
		_antes[i] = _fio[i] - impulso * f * (1.0 / 60.0)
	_comprimento = maxf(FIO_INICIO * _escala, a.distance_to(c))
	_giro = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * 8.0


func _process(delta: float) -> void:
	if _cab == null or not is_instance_valid(_cab) or _dente == null or delta <= 0.0:
		return
	_t += delta
	var tempo := minf(delta, 1.0 / 15.0)
	var passos := clampi(ceili(tempo / PASSO), 1, 16)
	var dt := tempo / float(passos)
	var solta_dente := exp(-ARRASTO_DENTE * dt)
	var solta_fio := exp(-ARRASTO_FIO * dt)
	var a := _cab.global_transform * _ancora
	var da_cabeca := _cab.global_transform.affine_inverse()
	for _s in passos:
		for i in range(1, PONTOS):
			var p := _fio[i]
			var v := (p - _antes[i]) * (solta_dente if i == PONTOS - 1 else solta_fio)
			_antes[i] = p
			_fio[i] = p + v + GRAVIDADE * dt * dt
		_fio[0] = a
		_antes[0] = a
		if a.distance_to(_fio[PONTOS - 1]) > _comprimento * 0.97:
			_comprimento = minf(_comprimento + FIO_CEDE * _escala * dt, FIO_MAX * _escala)
		var seg := _comprimento / float(PONTOS - 1)
		for _it in ITERACOES:
			for i in range(PONTOS - 1):
				var d := _fio[i + 1] - _fio[i]
				var l := d.length()
				if l < 1e-7:
					continue
				var corr := d * ((l - seg) / l)
				var wa := 0.0 if i == 0 else 0.5
				var wb := 0.3 if i + 1 == PONTOS - 1 else 0.5
				_fio[i] += corr * (wa / (wa + wb))
				_fio[i + 1] -= corr * (wb / (wa + wb))
			if _t > 0.04:
				_na_frente_da_cara(da_cabeca)
	# O dente: pendurado pelo colo no fim do fio, a coroa virando para longe dele.
	var fim := _fio[PONTOS - 1]
	var para_fora := (fim - _fio[PONTOS - 2]).normalized()
	_giro *= exp(-delta * 3.0)
	var b := _dente.global_basis
	var escala := b.get_scale()
	var q := b.orthonormalized().get_rotation_quaternion()
	if _giro.length() > 0.001:
		q = Quaternion(_giro.normalized(), _giro.length() * delta) * q
	var coroa := (q * _coroa).normalized()
	if coroa.dot(para_fora) < 0.9999 and para_fora.length() > 0.5:
		q = Quaternion.IDENTITY.slerp(Quaternion(coroa, para_fora), clampf(delta * 5.0, 0.0, 1.0)) * q
	var base := Basis(q.normalized()).scaled(escala)
	_dente.global_transform = Transform3D(base, fim - base * _colo)
	_desenhar()


## O fim do fio (o dente) fica na frente da cara, e nao dentro do labio.
func _na_frente_da_cara(da_cabeca: Transform3D) -> void:
	var i := PONTOS - 1
	var q := da_cabeca * _fio[i]
	var z := OlhoSolto._frente_em(q.x, q.y)
	if z == INF:
		return
	z -= RAIO_DENTE
	if q.z <= z or q.z > z + 0.03:
		return
	var fora := _cab.global_transform * Vector3(q.x, q.y, z)
	var nrm := (fora - _fio[i]).normalized()
	var v := _fio[i] - _antes[i]
	v -= nrm * minf(v.dot(nrm), 0.0)
	v *= 1.0 - GRUDA
	_fio[i] = fora
	_antes[i] = fora - v


## O fio de gengiva: rosa-arroxeado rasgado, sangue nas pontas, afinando do
## alveolo para o dente.
func _desenhar() -> void:
	_malha.clear_surfaces()
	var n := CABO_ANEIS
	var liso := PackedVector3Array()
	for i in n:
		var f := float(i) / float(n - 1) * float(PONTOS - 1)
		var k := mini(floori(f), PONTOS - 2)
		liso.append(_fio[k].lerp(_fio[k + 1], f - float(k)))
	var gengiva := Color(0.84, 0.52, 0.52)
	var escura := Color(0.42, 0.08, 0.10)
	var sangue := Color(0.36, 0.02, 0.02)
	_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	var ref := Vector3.UP
	var aneis: Array = []
	for i in n:
		var t := (liso[mini(i + 1, n - 1)] - liso[maxi(i - 1, 0)]).normalized()
		if absf(t.dot(ref)) > 0.95:
			ref = Vector3.RIGHT
		var u := t.cross(ref).normalized()
		var w := t.cross(u).normalized()
		var f := float(i) / float(n - 1)
		var r := lerpf(FIO_RAIO.x, FIO_RAIO.y, f) * _escala * (1.0 + 0.2 * sin(f * 19.0 + 0.7))
		var anel: Array = []
		for k in CABO_LADOS:
			var ang := TAU * float(k) / float(CABO_LADOS)
			var dir := u * cos(ang) + w * sin(ang) * 0.6
			var c := gengiva.lerp(escura, 0.5 + 0.5 * sin(f * 11.0 + float(k) * 1.3))
			c = c.lerp(sangue, clampf(1.0 - f * 3.0, 0.0, 1.0) * 0.8 + clampf((f - 0.8) * 5.0, 0.0, 1.0) * 0.6)
			anel.append([liso[i] + dir * r, dir.normalized(), c])
		aneis.append(anel)
	for i in range(1, n):
		for k in CABO_LADOS:
			var k2 := (k + 1) % CABO_LADOS
			for p: Array in [aneis[i - 1][k], aneis[i][k], aneis[i][k2],
					aneis[i - 1][k], aneis[i][k2], aneis[i - 1][k2]]:
				_malha.surface_set_color(p[2])
				_malha.surface_set_normal(p[1])
				_malha.surface_add_vertex(p[0])
	_malha.surface_end()
