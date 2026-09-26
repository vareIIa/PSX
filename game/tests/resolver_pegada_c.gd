extends Node
## O resolvedor das pegadas do chao de `src/celular/pegada_leitura.gd`: a pinca em C
## no aparelho caido e a troca por tras dele ate a leitura. Espaco do aparelho: x
## para a direita da tela, y para cima, z saindo do vidro (m).
##
##     godot --headless --path game res://tests/resolver_pegada_c.tscn -- --pinca
##     godot --headless --path game res://tests/resolver_pegada_c.tscn -- --troca
##
##   --pinca    busca a pinca (54 chutes): polegar no vidro perto da borda direita, os
##              quatro dedos nas costas; nota pelas metas, pela malha dentro do
##              aparelho, pela cabine (carpete e corta-fogo) e pelos dedos sobre a
##              tela. Grava a melhor em `<pasta>/pinca_c.txt`.
##   --troca    da pinca gravada, resolve a chegada e as chaves da troca (quatro
##              passes: metas andando; a palma alisada entre as chaves e os dedos
##              de novo com ela parada; o polegar por poses de passagem rentes ao
##              vidro; os dedos alisados) e grava `<pasta>/troca_c.txt` com
##              `PINCA`, `CHEGA` e `TROCA` prontos para colar.
##   --pasta=<dir>  onde ler e gravar (padrao: user://resolver_pegada_c).
##
## O aparelho no chao (`FONE`) e o ombro (`OMBRO`) sao os do quadro de antes do
## erguer, lidos do `diag_pegar_celular` (`fone.c`, `eixo_y`, `eixo_z`, `ombro`):
## se a queda mudar, eles mudam aqui.

const Pegada := preload("res://src/celular/pegada_leitura.gd")
const Traj := preload("res://src/world/trajeto_do_braco.gd")
var M := Iphone4S.TAMANHO * 0.5
var RC := Iphone4S.RAIO_CANTO
var T := Iphone4S.TELA * 0.5
const INFLA := 0.0008
const PISO := 0.36
const CORTA_FOGO := -0.880
## O aparelho no chao do carona, como a queda o deixa (lido do diag da cena).
var FONE := Transform3D()
const OMBRO := Vector3(-0.0527, 0.8356, 0.0976)
var PASTA := ""
var _cores := {}
var _uvp := Vector2.ZERO


func _ready() -> void:
	var y := Vector3(0.5129, 0.5817, -0.6313).normalized()
	var z := Vector3(-0.3668, 0.8134, 0.4515).normalized()
	FONE = Transform3D(Basis(y.cross(z).normalized(), y, z), Vector3(0.38, 0.4233, -0.84))
	PASTA = OS.get_user_data_dir().path_join("resolver_pegada_c")
	for x: String in OS.get_cmdline_user_args():
		if x.begins_with("--pasta="):
			PASTA = x.trim_prefix("--pasta=")
	DirAccess.make_dir_recursive_absolute(PASTA)
	call_deferred("_rodar")


func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--pinca"):
		_pinca()
	elif args.has("--troca"):
		_troca()
	get_tree().quit(0)


# --- a pinca ------------------------------------------------------------------

func _rumo() -> Vector3:
	var d_mundo := (FONE.origin + Vector3(0.0, 0.03, 0.0) - OMBRO).normalized()
	return (FONE.basis.inverse() * d_mundo).normalized()


func _pinca() -> void:
	var rumo := _rumo()
	var mz := M.z + INFLA + 0.0006
	var pol_x := float(_env("PX", "0.012"))
	var melhor := {}
	var nota_m := INF
	var i := 0
	for fx: float in [0.008, 0.014]:
		for dx: float in [0.034, 0.042, 0.050]:
			for dz: float in [-0.004, 0.006, 0.014]:
				for gd: float in [-30.0, 0.0, 30.0]:
					var metas := [
						{"tipo": &"polpa", "dedo": 4, "p": Vector3(M.x - pol_x, -0.004, mz), "n": Vector3(0, 0, 1),
							"peso": 1.0, "peso_n": 0.3},
						{"tipo": &"polpa", "dedo": 0, "p": Vector3(M.x - fx, 0.020, -mz), "n": Vector3(0, 0, -1),
							"peso": 1.0, "peso_n": 0.3},
						{"tipo": &"polpa", "dedo": 1, "p": Vector3(M.x - fx, 0.000, -mz), "n": Vector3(0, 0, -1),
							"peso": 1.0, "peso_n": 0.3},
						{"tipo": &"polpa", "dedo": 2, "p": Vector3(M.x - fx + 0.002, -0.020, -mz), "n": Vector3(0, 0, -1),
							"peso": 0.8, "peso_n": 0.2},
						{"tipo": &"polpa", "dedo": 3, "p": Vector3(M.x - fx + 0.004, -0.038, -mz), "n": Vector3(0, 0, -1),
							"peso": 0.4, "peso_n": 0.1},
						{"tipo": &"rumo", "d": rumo, "peso": 0.4},
					]
					var d0 := rumo
					var s0 := Vector3(1, 0, 0) - d0 * d0.x
					s0 = s0.normalized().rotated(d0, deg_to_rad(gd))
					var chute := {"o": Vector3(dx, -0.006, dz), "d": d0, "dorso": s0,
						"pose": {"dedos": [[60.0, 60.0, 40.0, 0.0], [60.0, 62.0, 42.0, 0.0], [60.0, 60.0, 40.0, 4.0],
						[55.0, 55.0, 35.0, 8.0]], "polegar": [40.0, 40.0, 0.0, 20.0, 18.0]}}
					var aj := AjusteDaMao.new(M + Vector3.ONE * INFLA, RC + INFLA, true)
					aj.metas = metas
					var p := aj.resolver(chute, 250)
					var erro: Array = aj.medir(p)["metas_mm"]
					var soma := 0.0
					for x in erro:
						soma += float(x)
					var malha := _pior_malha(p)
					var fora := _fora_da_cabine(p)
					var sob := _sobre(p)
					var sob_dedos := maxf(maxf(sob[0], sob[1]), maxf(sob[2], sob[3]))
					var nota := soma + malha * 1000.0 * 20.0 + maxf(0.0, 0.004 - fora) * 1000.0 * 30.0 \
						+ sob_dedos * 1000.0 * 5.0
					print("[pinca %d] fx %.3f dx %.3f dz %.3f g %.0f | erros %s | malha %.1f mm cabine %.1f mm sobre %.0f mm | nota %.0f" % [
						i, fx, dx, dz, gd, erro, malha * 1000.0, fora * 1000.0, sob_dedos * 1000.0, nota])
					if nota < nota_m:
						nota_m = nota
						melhor = p
					i += 1
	print("[pinca] MELHOR nota %.0f %s" % [nota_m, _gd(melhor)])
	print("[pinca] %s" % _linha(melhor))
	var f := FileAccess.open(PASTA.path_join("pinca_c.txt"), FileAccess.WRITE)
	f.store_string(var_to_str(melhor))


func _env(k: String, padrao: String) -> String:
	var v := OS.get_environment(k)
	return padrao if v.is_empty() else v


# --- a troca ------------------------------------------------------------------

func _troca() -> void:
	var pinca: Dictionary = str_to_var(FileAccess.get_file_as_string(PASTA.path_join("pinca_c.txt")))
	var leitura := BracoVivo.pega(MotoristaCena.LEITURA_O, MotoristaCena.LEITURA_D,
		MotoristaCena.LEITURA_DORSO, MotoristaCena.LEITURA_POSE)
	# O fim de verdade: a leitura com o polegar no repouso de depois do apagar
	# (`MotoristaCena._polegar_em(REPOUSO_DEPOIS_UV, REPOUSO_ALTURA)`), que e o
	# `_pol_agora` quando ele pega o aparelho do chao.
	var ajr := AjusteDaMao.new(M, RC, true)
	ajr.metas = [{"tipo": &"polpa", "dedo": 4, "p": Iphone4S.ponto_da_tela(MotoristaCena.REPOUSO_DEPOIS_UV)
		+ Vector3(0.0, 0.0, MotoristaCena.REPOUSO_ALTURA), "n": Vector3(0.25, 0.0, 1.0), "peso_n": 0.5}]
	ajr.so_polegar()
	leitura = ajr.resolver(leitura, 30)
	print("[troca] polegar do repouso %s" % [leitura["pose"]["polegar"]])
	var mz := M.z + INFLA + 0.0006
	var e0 := MaoPosada.esqueleto(pinca["o"], pinca["d"], pinca["dorso"], pinca["pose"], true)
	var e1 := MaoPosada.esqueleto(leitura["o"], leitura["d"], leitura["dorso"], leitura["pose"], true)
	var de := []
	var ate := []
	for i in 5:
		de.append(MaoPosada.polpa(e0, i)["centro"])
		ate.append(MaoPosada.polpa(e1, i)["centro"])
	print("[troca] pinca %s" % _linha(pinca))
	print("[troca] leitura %s" % _linha(leitura))

	# A chegada: o C aberto, a palma parada; os dedos 1,4 cm para a direita da
	# borda (ja abaixo das costas) e o polegar 8 mm acima do vidro.
	var ajc := AjusteDaMao.new(M + Vector3.ONE * INFLA, RC + INFLA, true)
	var mc := []
	for i in 4:
		var p: Vector3 = de[i]
		mc.append({"tipo": &"polpa", "dedo": i, "p": Vector3(M.x + 0.014 + float(i) * 0.001, p.y, p.z - 0.002),
			"n": Vector3(-1, 0, 0), "peso": 1.0 if i < 3 else 0.5, "peso_n": 0.05})
	mc.append({"tipo": &"polpa", "dedo": 4, "p": (de[4] as Vector3) + Vector3(0.002, 0.0, 0.008),
		"n": Vector3(0, 0, 1), "peso": 1.0, "peso_n": 0.1})
	ajc.metas = mc
	ajc.livres = PackedInt32Array(range(AjusteDaMao.I_DEDOS, AjusteDaMao.N))
	var chega := ajc.resolver(pinca, 200)
	print("[chega] erros %s | %s" % [ajc.medir(chega)["metas_mm"], _linha(chega)])
	_conferir_trecho("fecha", chega, pinca, 20, true)

	# A troca: a palma contorna a borda direita por baixo das costas e vai para
	# o meio delas; os dedos deslizam nas costas ate perto da borda esquerda e so
	# no fim dobram a quina; o polegar escorrega no vidro e sobe para o repouso.
	var n := int(_env("NQ", "20"))
	var palma := PackedVector3Array([pinca["o"],
		Vector3(M.x + 0.030, lerpf((pinca["o"] as Vector3).y, (leitura["o"] as Vector3).y, 0.25), -0.010),
		Vector3(M.x - 0.004, lerpf((pinca["o"] as Vector3).y, (leitura["o"] as Vector3).y, 0.6), -M.z - 0.010),
		leitura["o"]])
	var q0 := _quat(pinca)
	var q1 := _quat(leitura)
	var chaves := [pinca]
	var ant := pinca
	var costas_ate := float(_env("CA", "0.72"))
	for k in range(1, n):
		var t := float(k) / float(n)
		var metas := _metas_da_troca(t, de, ate, q0, q1, mz, costas_ate)
		var gira := smoothstep(0.0, 0.85, t)
		var bq := Basis(q0.slerp(q1, gira))
		var chute := BracoVivo._misturar(ant, leitura, 1.0 / float(n - k + 1))
		var t_ant := float(k - 1) / float(n)
		chute["o"] = (ant["o"] as Vector3) + Traj.ponto(palma, t) - Traj.ponto(palma, t_ant)
		var bq_ant := Basis(q0.slerp(q1, smoothstep(0.0, 0.85, t_ant)))
		var passo := Basis(bq.get_rotation_quaternion() * bq_ant.get_rotation_quaternion().inverse())
		var ba := Basis(_quat(ant))
		var bn := passo * ba
		chute["d"] = bn.z
		chute["dorso"] = bn.y
		var aj := AjusteDaMao.new(M + Vector3.ONE * INFLA, RC + INFLA, true)
		aj.metas = metas
		var q := aj.resolver(chute, 200)
		chaves.append(q)
		print("[k %02d] o=%s erros %s | %s" % [k, (q["o"] as Vector3) * 1000.0, aj.medir(q)["metas_mm"], _linha(q)])
		ant = q
	chaves.append(leitura)
	if _env("PASSE2", "1") == "1":
		chaves = _passe2(chaves, de, ate, q0, q1, mz, costas_ate)
	if _env("PASSE3", "1") == "1":
		chaves = _passe3(chaves, de, ate, q0, q1, mz, costas_ate)
	if _env("PASSE4", "1") == "1":
		chaves = _passe4(chaves)
	var pior := 0.0
	for i in chaves.size() - 1:
		pior = maxf(pior, _conferir_trecho("t%02d" % i, chaves[i], chaves[i + 1], 10, false))
	print("[troca] PIOR malha entre chaves %.2f mm" % (pior * 1000.0))
	print("[troca] maior salto de angulo por chave: %s" % [_saltos(chaves)])
	var linhas := []
	for q: Dictionary in chaves.slice(0, chaves.size() - 1):
		linhas.append(_gd(q))
	var f := FileAccess.open(PASTA.path_join("troca_c.txt"), FileAccess.WRITE)
	f.store_string("const PINCA := %s\nconst CHEGA := %s\nconst TROCA := [\n\t%s,\n]\n" % [_gd(pinca), _gd(chega),
		",\n\t".join(linhas)])
	print("[troca] gravado em troca_c.txt")


func _quat(p: Dictionary) -> Quaternion:
	var d: Vector3 = p["d"]
	var s: Vector3 = p["dorso"]
	return Basis(s.cross(d).normalized(), s, d).orthonormalized().get_rotation_quaternion()


## Confere de `a` a `b` em `n` passos: malha dentro do aparelho, dedos sobre a
## tela e (no chao) a cabine. Devolve a pior malha (m).
func _conferir_trecho(nome: String, a: Dictionary, b: Dictionary, n: int, chao: bool) -> float:
	var pior := 0.0
	var sob_m := 0.0
	var cab := INF
	for s in n + 1:
		var q := BracoVivo._misturar(a, b, float(s) / float(n))
		pior = maxf(pior, _pior_malha(q))
		var sob := _sobre(q)
		sob_m = maxf(sob_m, maxf(maxf(sob[0], sob[1]), maxf(sob[2], sob[3])))
		if chao:
			cab = minf(cab, _fora_da_cabine(q))
	print("[trecho %s] malha %.2f mm | dedos sobre a tela %.1f mm%s" % [nome, pior * 1000.0, sob_m * 1000.0,
		(" | cabine %.1f mm" % (cab * 1000.0)) if chao else ""])
	return pior


func _saltos(chaves: Array) -> Array:
	var maior := 0.0
	var onde := -1
	for i in chaves.size() - 1:
		var a: Dictionary = chaves[i]["pose"]
		var b: Dictionary = chaves[i + 1]["pose"]
		for d in 4:
			for j in 4:
				var x := absf(float(a["dedos"][d][j]) - float(b["dedos"][d][j]))
				if x > maior:
					maior = x
					onde = i
		for j in 5:
			var x := absf(float(a["polegar"][j]) - float(b["polegar"][j]))
			if x > maior:
				maior = x
				onde = i
	return [maior, onde]


# --- reguas -------------------------------------------------------------------

func _linha(p: Dictionary) -> String:
	var e := MaoPosada.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
	var s := ""
	var nomes := ["ind", "med", "anel", "min", "pol"]
	for i in 5:
		var c: Vector3 = MaoPosada.polpa(e, i)["centro"]
		var r := float(MaoPosada.raios_do_dedo(i)[3])
		var d := (AjusteDaMao.distancia(c, M, RC) - r) * 1000.0
		s += "%s(%.0f,%.0f,%.0f|%.1f) " % [nomes[i], c.x * 1000, c.y * 1000, c.z * 1000, d]
	var sob := _sobre(p)
	s += "sobre=%.0f/%.0f/%.0f/%.0f/%.0f " % [sob[0] * 1000, sob[1] * 1000, sob[2] * 1000, sob[3] * 1000, sob[4] * 1000]
	var md := _malha_dentro(p)
	s += "malha=%.1f/%.1f/%.1f/%.1f/%.1f/%.1f cabine=%.1f" % [md[0][0] * 1000, md[1][0] * 1000, md[2][0] * 1000,
		md[3][0] * 1000, md[4][0] * 1000, md[5][0] * 1000, _fora_da_cabine(p) * 1000.0]
	return s


func _gd(p: Dictionary) -> String:
	var o: Vector3 = p["o"]
	var d: Vector3 = p["d"]
	var s: Vector3 = p["dorso"]
	return "{\"o\": Vector3(%.6f, %.6f, %.6f), \"d\": Vector3(%.6f, %.6f, %.6f), \"dorso\": Vector3(%.6f, %.6f, %.6f), \"pose\": %s}" % [
		o.x, o.y, o.z, d.x, d.y, d.z, s.x, s.y, s.z, JSON.stringify(p["pose"])]


## O pior da mao (esferas) contra o carpete e o corta-fogo, com o aparelho no
## chao (m, negativo = dentro).
func _fora_da_cabine(p: Dictionary) -> float:
	var aj := AjusteDaMao.new(M, RC, true)
	var e := MaoPosada.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
	var pior := INF
	for esf: Array in aj._esferas(e, false):
		var c: Vector3 = FONE * (esf[0] as Vector3)
		var r := float(esf[1])
		var chao := PISO + (0.010 if c.z > -0.78 and c.x > 0.20 and c.x < 0.60 else 0.0)
		pior = minf(pior, c.y - r - chao)
		pior = minf(pior, c.z - r - CORTA_FOGO)
	return pior


func _sobre(p: Dictionary) -> Array:
	var e := MaoPosada.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
	var out := []
	for i in 5:
		var dedo: Dictionary = e["polegar"] if i == 4 else e["dedos"][i]
		var js: Array[Vector3] = dedo["juntas"]
		var rs := MaoPosada.raios_do_dedo(i)
		var pior := 0.0
		for k in js.size():
			var c := js[k]
			var r := float(rs[mini(k, 3)])
			if k == js.size() - 1:
				c = MaoPosada.polpa(e, i)["centro"]
				r = float(rs[3])
			if i < 4 and k == 0:
				continue
			if c.z + r * MaoModelada.DEDO_ACHATA <= M.z:
				continue
			var ox := T.x + r - absf(c.x)
			var oy := T.y + r - absf(c.y)
			if ox > 0.0 and oy > 0.0:
				pior = maxf(pior, minf(ox, oy))
		out.append(pior)
	return out


func _malha_dentro(p: Dictionary) -> Array:
	if _cores.is_empty():
		_cores = MaoModelada._tons(Color(0.78, 0.62, 0.50))
		_uvp = MaoModelada._uv_liso(Aparencia.PECA_MAO, 0.14)
	var e := MaoPosada.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
	var dd: Vector3 = e["dd"]
	var ds: Vector3 = e["ds"]
	var out := []
	for i in 6:
		var m := PSXMesh.dados_vazios()
		if i < 4:
			var dedo: Dictionary = e["dedos"][i]
			MaoModelada._corrente(m, dedo["juntas"], dedo["dorsos"], MaoPosada.raios_do_dedo(i),
				_cores, _uvp, dd, ds)
		elif i == 4:
			var pol: Dictionary = e["polegar"]
			MaoModelada._corrente(m, pol["juntas"], pol["dorsos"], MaoPosada.raios_do_dedo(4),
				_cores, _uvp, Vector3.ZERO, Vector3.ZERO)
		else:
			MaoModelada._palma(m, e["q"], e["ld"], 0.0, _cores, _uvp)
		var pior := 0.0
		var soma := 0.0
		for v: Vector3 in (m["v"] as PackedVector3Array):
			var sd := AjusteDaMao.distancia(v, M, RC)
			if sd < 0.0:
				pior = maxf(pior, -sd)
				soma += -sd
		out.append([pior, soma])
	return out


func _pior_malha(p: Dictionary) -> float:
	var pior := 0.0
	for x: Array in _malha_dentro(p):
		pior = maxf(pior, float(x[0]))
	return pior


func _metas_da_troca(t: float, de: Array, ate: Array, q0: Quaternion, q1: Quaternion, mz: float,
		costas_ate: float) -> Array:
	var metas := []
	for i in 4:
		var s: Vector3 = de[i]
		var f: Vector3 = ate[i]
		var p: Vector3
		var a := clampf(t / costas_ate, 0.0, 1.0)
		var ea := a * a * (3.0 - 2.0 * a)
		var fy := f.y if i < 3 else maxf(f.y, -M.y + 0.010)
		var costas := Vector3(lerpf(s.x, -M.x + 0.006, ea), lerpf(s.y, fy, ea), -mz)
		var b := clampf((t - costas_ate) / (1.0 - costas_ate), 0.0, 1.0)
		var eb := b * b * (3.0 - 2.0 * b)
		p = costas.lerp(f, eb) + Vector3(-0.010, 0.0, -0.004) * sin(eb * PI)
		var n_ := Vector3(0, 0, -1).lerp(Vector3(-1, 0, 0), eb).normalized()
		metas.append({"tipo": &"polpa", "dedo": i, "p": p, "peso": 1.0 if i < 3 else float(_env("PM", "0.15")),
			"n": n_, "peso_n": 0.05})
	var ps: Vector3 = de[4]
	var pf: Vector3 = ate[4]
	var c := clampf(t / 0.8, 0.0, 1.0)
	var pol := Vector3(lerpf(ps.x, pf.x, c), lerpf(ps.y, pf.y, c), ps.z)
	pol = pol.lerp(pf, smoothstep(0.6, 1.0, t))
	metas.append({"tipo": &"polpa", "dedo": 4, "p": pol, "peso": 1.0, "n": Vector3(0, 0, 1), "peso_n": 0.1})
	var bq := Basis(q0.slerp(q1, smoothstep(0.0, 0.85, t)))
	metas.append({"tipo": &"rumo", "d": bq.z, "peso": 0.3})
	return metas


## Segundo passe: a palma de cada chave alisada entre as vizinhas (o salto de
## uma chave vira caminho de varias), empurrada para fora do aparelho se o
## alisado cortou a quina, e os dedos resolvidos de novo com ela parada.
func _passe2(chaves: Array, de: Array, ate: Array, q0: Quaternion, q1: Quaternion, mz: float,
		costas_ate: float) -> Array:
	var n := chaves.size() - 1
	var os_ := []
	var qs := []
	for c: Dictionary in chaves:
		os_.append(c["o"])
		qs.append(_quat(c))
	for it in int(_env("ALISA", "40")):
		var no := os_.duplicate()
		var nq := qs.duplicate()
		for k in range(1, n):
			no[k] = (os_[k] as Vector3) * 0.5 + ((os_[k - 1] as Vector3) + (os_[k + 1] as Vector3)) * 0.25
			var mq := (qs[k - 1] as Quaternion).slerp(qs[k + 1], 0.5)
			nq[k] = (qs[k] as Quaternion).slerp(mq, 0.5)
		os_ = no
		qs = nq
	var dmin := float(_env("DMIN", "0.003"))
	for k in range(1, n):
		var o: Vector3 = os_[k]
		for passo in 40:
			var d := AjusteDaMao.distancia(o, M, RC)
			if d >= dmin:
				break
			var g := Vector3(AjusteDaMao.distancia(o + Vector3(1e-4, 0, 0), M, RC) - d,
				AjusteDaMao.distancia(o + Vector3(0, 1e-4, 0), M, RC) - d,
				AjusteDaMao.distancia(o + Vector3(0, 0, 1e-4), M, RC) - d).normalized()
			o += g * (dmin - d + 0.0002)
		os_[k] = o
	var out := [chaves[0]]
	var ant: Dictionary = chaves[0]
	for k in range(1, n):
		var t := float(k) / float(n)
		var b := Basis(qs[k] as Quaternion)
		var chute: Dictionary = (chaves[k] as Dictionary).duplicate(true)
		chute["pose"] = MaoPosada.misturar(chute["pose"], ant["pose"], 0.5)
		chute["o"] = os_[k]
		chute["d"] = b.z
		chute["dorso"] = b.y
		var aj := AjusteDaMao.new(M + Vector3.ONE * INFLA, RC + INFLA, true)
		aj.metas = _metas_da_troca(t, de, ate, q0, q1, mz, costas_ate)
		aj.livres = PackedInt32Array(range(AjusteDaMao.I_DEDOS, AjusteDaMao.N))
		var q := aj.resolver(chute, 200)
		print("[p2 %02d] palma anda %.1f mm | erros %s | %s" % [k, ((q["o"] as Vector3) - (ant["o"] as Vector3)).length() * 1000.0,
			aj.medir(q)["metas_mm"], _linha(q)])
		out.append(q)
		ant = q
	out.append(chaves[n])
	return out


## Terceiro passe: o polegar por poses de passagem (a polpa rente ao vidro em
## 1/4, 1/2 e 3/4 da troca, cada uma resolvida a partir da anterior) e, entre
## elas, os angulos interpolados: sem trocar de giro no meio e sem subir no ar.
func _passe3(chaves: Array, de: Array, ate: Array, q0: Quaternion, q1: Quaternion, mz: float,
		costas_ate: float) -> Array:
	var n := chaves.size() - 1
	var ps: Vector3 = de[4]
	var pf: Vector3 = ate[4]
	var rp := float(MaoPosada.raios_do_dedo(4)[3])
	var sobe := float(_env("SOBE", "0.75"))
	var ts := [0.0, 0.25, 0.5, 0.75, 1.0]
	var ws := [chaves[0]["pose"]["polegar"]]
	for w in range(1, 4):
		var t: float = ts[w]
		var k := roundi(t * float(n))
		var q: Dictionary = (chaves[k] as Dictionary).duplicate(true)
		var fim: Array = chaves[n]["pose"]["polegar"]
		var ant: Array = ws[w - 1]
		var seed := []
		for j in 5:
			seed.append(lerpf(float(ant[j]), float(fim[j]), 1.0 / float(5 - w)))
		q["pose"]["polegar"] = seed
		var rente := Vector3(lerpf(ps.x, pf.x, t), lerpf(ps.y, pf.y, t), M.z + rp + 0.001)
		var alvo := rente.lerp(pf, smoothstep(sobe, 1.0, t))
		var aj := AjusteDaMao.new(M + Vector3.ONE * INFLA, RC + INFLA, true)
		aj.metas = [{"tipo": &"polpa", "dedo": 4, "p": alvo, "n": Vector3(0, 0, 1), "peso": 1.0, "peso_n": 0.2}]
		for j in 5:
			aj._descanso[AjusteDaMao.I_POLEGAR + j] = float(seed[j])
		aj.so_polegar()
		var r := aj.resolver(q, 40)
		print("[p3 w%d] polegar %s erro %.1f mm" % [w, r["pose"]["polegar"], aj.medir(r)["metas_mm"][0]])
		ws.append(r["pose"]["polegar"])
	ws.append(chaves[n]["pose"]["polegar"])
	var out := [chaves[0]]
	for k in range(1, n):
		var t := float(k) / float(n)
		var seg := mini(int(t * 4.0), 3)
		var u := smoothstep(0.0, 1.0, (t - float(ts[seg])) * 4.0)
		var a: Array = ws[seg]
		var b: Array = ws[seg + 1]
		var pol := []
		for j in 5:
			# Catmull-Rom nos angulos entre as passagens.
			var p0 := float((ws[maxi(seg - 1, 0)] as Array)[j])
			var p1 := float(a[j])
			var p2 := float(b[j])
			var p3 := float((ws[mini(seg + 2, 4)] as Array)[j])
			var v := (t - float(ts[seg])) * 4.0
			pol.append(0.5 * ((2.0 * p1) + (-p0 + p2) * v + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * v * v
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * v * v * v))
		var q: Dictionary = (chaves[k] as Dictionary).duplicate(true)
		q["pose"]["polegar"] = pol
		print("[p3 %02d] %s" % [k, _linha(q)])
		out.append(q)
	out.append(chaves[n])
	return out


## Quarto passe: os angulos dos quatro dedos alisados entre chaves vizinhas
## (os saltos de abertura e do minimo viram rampa). Uma chave cuja malha passa de
## 1 mm dentro do aparelho depois de alisada volta a de antes.
func _passe4(chaves: Array) -> Array:
	var n := chaves.size() - 1
	var cur := chaves.duplicate(true)
	for it in int(_env("ALISA4", "4")):
		var nov := cur.duplicate(true)
		for k in range(1, n):
			for d in 4:
				for j in 4:
					var a := float(cur[k - 1]["pose"]["dedos"][d][j])
					var b := float(cur[k]["pose"]["dedos"][d][j])
					var c := float(cur[k + 1]["pose"]["dedos"][d][j])
					nov[k]["pose"]["dedos"][d][j] = 0.25 * a + 0.5 * b + 0.25 * c
		cur = nov
	var voltou := 0
	for k in range(1, n):
		if _pior_malha(cur[k]) > 0.001:
			cur[k] = chaves[k]
			voltou += 1
	print("[p4] alisado; %d chaves voltaram" % voltou)
	return cur
