## Levantar do chao, medido pela pele: o que encosta e o que entra no chao.
##
##     godot --headless --path game --script res://tests/medir_levantar.gd
##
## Para cada chave de `LevantarDoChao` (de costas e de bruços) e para instantes
## no meio delas, aplica a pose num Corpo de verdade e deforma a malha como a
## placa de video deforma (peso por osso, pose global vezes repouso inverso).
## Da pele sai, por osso, o ponto mais baixo. Dois criterios:
##
## - nada entra no chao mais que ENTRA (a pose que atravessa o piso some meia
##   perna dentro do asfalto e ninguem ve a perna, ve o toco);
## - cada chave tem os apoios que diz ter (maos no chao na flexao, joelho no
##   chao ajoelhado, pes no chao agachado): um apoio que nao toca e gente
##   levitando de quatro.
##
## Tres corpos: o de referencia, o alto e magro, o baixo e gordo. A pose e
## escalada pela altura; a gordura muda onde a pele esta.
extends SceneTree

const ENTRA := 0.035
const TOCA := 0.06
const O := Corpo.Osso

## Apoios por chave (indice), costas e bruços. So as chaves; os meios so
## contam para "nao entra".
const APOIOS_COSTAS := {
	0: [O.TORSO, O.CABECA, O.CANELA_E, O.CANELA_D],
	1: [O.QUADRIL, O.ANTEBRACO_E, O.ANTEBRACO_D, O.CANELA_E, O.CANELA_D],
	2: [O.QUADRIL, O.ANTEBRACO_E, O.ANTEBRACO_D, O.CANELA_D],
	3: [O.CANELA_E, O.CANELA_D],
	4: [O.CANELA_E, O.CANELA_D],
}
const APOIOS_BRUCOS := {
	0: [O.TORSO, O.CANELA_E, O.CANELA_D],
	1: [O.ANTEBRACO_E, O.ANTEBRACO_D, O.CANELA_E, O.CANELA_D],
	2: [O.ANTEBRACO_E, O.ANTEBRACO_D, O.CANELA_E, O.CANELA_D],
	3: [O.CANELA_E, O.CANELA_D],
	4: [O.CANELA_E, O.CANELA_D],
}

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
		for de_brucos in [false, true]:
			var nome := "%s alt %.2f gord %.1f" % ["brucos" if de_brucos else "costas",
				f["altura"], f["gordura"]]
			_sequencia(corpo, de_brucos, nome, detalhe)
		corpo.queue_free()
	print("[levantar] %d/%d" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _sequencia(corpo: Corpo, de_brucos: bool, nome: String, detalhe: bool) -> void:
	corpo.dominado = true
	var ch := LevantarDoChao.chaves(de_brucos, corpo)
	var apoios: Dictionary = APOIOS_BRUCOS if de_brucos else APOIOS_COSTAS
	var pior := INF
	var onde_pior := ""
	var t := 0.0
	for i in ch.size():
		t += float((ch[i] as Dictionary)["dur"])
		# A chave e tres pontos do trecho que chega nela: so o meio deixa um
		# quarto ruim passar.
		var instantes := [t]
		if i > 0:
			var dur := float((ch[i] as Dictionary)["dur"])
			instantes = [t - dur * 0.75, t - dur * 0.5, t - dur * 0.25, t]
		for ti: float in instantes:
			LevantarDoChao.aplicar(corpo, LevantarDoChao.pose_em(ch, ti, corpo))
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
			if detalhe:
				var linha := "  %s t=%.2f%s:" % [nome, ti, " *" if e_chave else ""]
				for osso: int in baixo:
					linha += " %s %.2f" % [corpo.esqueleto().get_bone_name(osso), baixo[osso]]
				print(linha)
			if e_chave and apoios.has(i):
				for osso: int in apoios[i]:
					_conta("%s chave %d apoia %s" % [nome, i, corpo.esqueleto().get_bone_name(osso)],
						float(baixo.get(osso, INF)) < TOCA,
						"%.3f m" % float(baixo.get(osso, INF)))
	_conta("%s nada entra no chao" % nome, pior > -ENTRA, "%.3f m em %s" % [pior, onde_pior])


## Pele deformada, ponto mais baixo por osso dominante do vertice.
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
			# Saia e barriga contam como o osso a que estao presos.
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
