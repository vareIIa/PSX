## Acordar e levantar da praca, medidos pela pele (ver `ChavesDoAcordar`).
##
##     godot --headless --path game --script res://tests/medir_acordar.gd [-- --detalhe]
##
## A mesma regua de `tests/medir_levantar.gd`, nas duas sequencias novas:
##
## - nada entra no chao mais que ENTRA, em quatro instantes de cada trecho;
## - cada chave marcada apoia no chao o que diz apoiar;
## - no acordar, o olho fica acima do chao e a mao que sobe para na frente dele,
##   a um palmo e meio (nem dentro da lente, nem longe demais para ser mao).
##
## Tres corpos: o de referencia, o alto e magro, o baixo e gordo.
extends SceneTree

const ENTRA := 0.035
const TOCA := 0.07
const O := Corpo.Osso
const C := preload("res://src/render/chaves_do_acordar.gd")

## Apoios por chave (indice na sequencia).
const APOIOS_ACORDAR := {
	0: [O.TORSO, O.CABECA, O.CANELA_E, O.CANELA_D],
	8: [O.ANTEBRACO_E, O.ANTEBRACO_D, O.QUADRIL],
	11: [O.TORSO, O.CANELA_E],
}
const APOIOS_LEVANTAR := {
	0: [O.TORSO, O.CABECA],
	3: [O.ANTEBRACO_E],
	5: [O.ANTEBRACO_E, O.ANTEBRACO_D, O.CANELA_E, O.CANELA_D],
	8: [O.ANTEBRACO_E, O.ANTEBRACO_D, O.CANELA_E, O.CANELA_D],
	10: [O.CANELA_E, O.CANELA_D],
	14: [O.CANELA_E, O.CANELA_D],
}
## O olhar em volta: de pe o tempo todo; na chave 8 o pe esquerdo esta no ar.
const APOIOS_OLHAR := {
	0: [O.CANELA_E, O.CANELA_D], 1: [O.CANELA_E, O.CANELA_D], 4: [O.CANELA_E, O.CANELA_D],
	5: [O.CANELA_E, O.CANELA_D], 7: [O.CANELA_E, O.CANELA_D], 8: [O.CANELA_D],
	9: [O.CANELA_E, O.CANELA_D], 11: [O.CANELA_E, O.CANELA_D],
}
## O olho no referencial do osso da cabeca (o mesmo de `AcordarNaPraca.OLHO`).
const OLHO := Vector3(0.0, 0.155, -0.095)

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	var fichas := [
		{"altura": 1.72, "gordura": 0.5, "ombro": 0.42},
		{"altura": 1.9, "gordura": 0.1, "ombro": 0.44},
		{"altura": 1.58, "gordura": 1.0, "ombro": 0.46},
	]
	var detalhe := OS.get_cmdline_user_args().has("--detalhe")
	for f: Dictionary in fichas:
		var a := Aparencia.de_ficha({"id": 11, "sexo": &"M", "idade": 35})
		for k: String in f:
			a[k] = f[k]
		var corpo := Corpo.new()
		root.add_child(corpo)
		corpo.montar(a)
		corpo.dominado = true
		var sufixo := "alt %.2f gord %.1f" % [f["altura"], f["gordura"]]
		_sequencia(corpo, C.chaves_acordar(corpo), APOIOS_ACORDAR, "acordar " + sufixo, detalhe)
		_olho_e_mao(corpo, sufixo)
		_sequencia(corpo, C.chaves_levantar(corpo), APOIOS_LEVANTAR, "levantar " + sufixo, detalhe)
		_sequencia(corpo, C.chaves_olhar(corpo), APOIOS_OLHAR, "olhar " + sufixo, detalhe)
		_conta("olhar %s dura o que a camera espera" % sufixo,
			is_equal_approx(C.duracao(C.chaves_olhar(corpo)), C.OLHAR_FIM),
			"%.2f s" % C.duracao(C.chaves_olhar(corpo)))
		corpo.queue_free()
	print("[acordar] %d/%d" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _sequencia(corpo: Corpo, ch: Array, apoios: Dictionary, nome: String, detalhe: bool) -> void:
	var pior := INF
	var onde_pior := ""
	var t := 0.0
	for i in ch.size():
		var dur := float((ch[i] as Dictionary)["dur"])
		t += dur
		var instantes := [t]
		if i > 0:
			instantes = [t - dur * 0.75, t - dur * 0.5, t - dur * 0.25, t]
		for ti: float in instantes:
			LevantarDoChao.aplicar(corpo, C.pose_em(ch, ti, corpo))
			var baixo := _mais_baixo_por_osso(corpo)
			var menor := INF
			var qual := -1
			for osso: int in baixo:
				if float(baixo[osso]) < menor:
					menor = baixo[osso]
					qual = osso
			if menor < pior:
				pior = menor
				onde_pior = "t=%.2f %s" % [ti, corpo.esqueleto().get_bone_name(qual)]
			var e_chave := is_equal_approx(ti, t)
			if detalhe and e_chave:
				var linha := "  %s chave %d t=%.2f:" % [nome, i, ti]
				for osso: int in baixo:
					linha += " %s %.2f" % [corpo.esqueleto().get_bone_name(osso), baixo[osso]]
				print(linha)
			if e_chave and apoios.has(i):
				for osso: int in apoios[i]:
					_conta("%s chave %d apoia %s" % [nome, i, corpo.esqueleto().get_bone_name(osso)],
						float(baixo.get(osso, INF)) < TOCA,
						"%.3f m" % float(baixo.get(osso, INF)))
	_conta("%s nada entra no chao" % nome, pior > -ENTRA, "%.3f m em %s" % [pior, onde_pior])


## No acordar: olho acima do chao o tempo todo, e a mao na frente dele quando
## sobe (entre 22 e 45 cm, e na frente — nao do lado nem atras).
func _olho_e_mao(corpo: Corpo, sufixo: String) -> void:
	var ch := C.chaves_acordar(corpo)
	var sk := corpo.esqueleto()
	var s := corpo.altura() / Corpo.ALTURA_REF
	var olho_min := INF
	var t := 0.0
	while t <= C.duracao(ch):
		LevantarDoChao.aplicar(corpo, C.pose_em(ch, t, corpo))
		var cab := sk.get_bone_global_pose(O.CABECA)
		var olho := cab.origin + cab.basis.orthonormalized() * (OLHO * s)
		olho_min = minf(olho_min, olho.y)
		t += 0.1
	_conta("acordar %s olho acima do chao" % sufixo, olho_min > 0.08, "%.3f m" % olho_min)
	for quando: float in [C.ACORDAR_MAO_NO_ROSTO, C.ACORDAR_MAO_NO_ROSTO + 1.2]:
		LevantarDoChao.aplicar(corpo, C.pose_em(ch, quando, corpo))
		var cab := sk.get_bone_global_pose(O.CABECA)
		var base := cab.basis.orthonormalized()
		var olho := cab.origin + base * (OLHO * s)
		var ante := sk.get_bone_global_pose(O.ANTEBRACO_D)
		var punho := ante.origin - ante.basis.orthonormalized().y * (Corpo.Y_COTOVELO - Corpo.Y_PUNHO) * s
		var mao := punho + (punho - ante.origin).normalized() * 0.08
		var ate := mao - olho
		var frente := -base.z
		var angulo := rad_to_deg(frente.angle_to(ate))
		print("  acordar %s t=%.1f olho %s mao %s dist %.3f angulo %.1f" % [sufixo, quando,
			olho, mao, ate.length(), angulo])
		_conta("acordar %s t=%.1f mao a um palmo e meio" % [sufixo, quando],
			ate.length() > 0.22 and ate.length() < 0.45, "%.3f m" % ate.length())
		_conta("acordar %s t=%.1f mao na frente do olho" % [sufixo, quando],
			angulo < 28.0, "%.1f graus" % angulo)


## Pele deformada, ponto mais baixo por osso dominante do vertice (a mesma de
## `tests/medir_levantar.gd`).
func _mais_baixo_por_osso(corpo: Corpo) -> Dictionary:
	var sk := corpo.esqueleto()
	var matriz := {}
	for b in sk.get_bone_count():
		matriz[b] = sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse()
	var malha := corpo.get_node("Esqueleto/Pele") as MeshInstance3D
	var saida := {}
	var m := malha.mesh as ArrayMesh
	for sup in m.get_surface_count():
		var arr := m.surface_get_arrays(sup)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var por := bs.size() / maxi(1, vs.size())
		for i in range(0, vs.size(), 2):
			var p := Vector3.ZERO
			var dono := -1
			var maior := -1.0
			for k in por:
				var w := ws[i * por + k]
				if w <= 0.0:
					continue
				var b := bs[i * por + k]
				p += (matriz[b] as Transform3D) * vs[i] * w
				if w > maior:
					maior = w
					dono = b
			if dono < 0:
				continue
			if dono == O.SAIA_F or dono == O.SAIA_T:
				dono = O.QUADRIL
			elif dono == O.BARRIGA:
				dono = O.TORSO
			if p.y < float(saida.get(dono, INF)):
				saida[dono] = p.y
	return saida


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
