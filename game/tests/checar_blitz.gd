## Regua da planta da blitz. Nivel 2.
##
##     godot --headless --path game --script res://tests/checar_blitz.gd
##
## O que ele prova
## ---------------
## Que nenhuma peca parada encosta em outra; que tudo cabe no comprimento que o
## BlitzManager reserva; que o carro abordado, simulado com a MESMA lei de
## esterco e freio do `Carro` da IA, entra na baia sem tocar em nada e para
## nela; que ele sai sem tocar em nada; que quem passa direto passa pela faixa
## de dentro sem derrubar cone nem invadir a contramao; e que o policial e o
## motorista andam sem atravessar carro nem pessoa.
##
## Por que ele existe
## ------------------
## A primeira blitz tinha tres policiais dentro de carros, cones em cima das
## duas faixas e 25 m de comprimento numa quadra com 15 a 17 livres — e passou por
## "AAA" porque as fotos eram encenadas com `--blitz-demo`. Nenhuma daquelas
## sobreposicoes precisava de janela para ser achada: e aritmetica de caixa.
extends SceneTree

const DT := 1.0 / 60.0
## Constantes do `Carro` (carro.gd). Copiadas, e nao lidas: o Carro depende de
## autoload e nao carrega em --script. Se mudarem la, esta regua mente.
const ACELERA := 4.2
const FREIA := 8.0
const TAXA_GIRO := 2.3
const TAXA_GIRO_DESVIO := 1.4
const VEL_AVENIDA := 14.0
## Folga minima exigida entre lataria em movimento e qualquer peca.
const FOLGA_MIN := 0.1

var _falhas := 0
var _via: int = MalhaUrbana.Via.AVENIDA


func _init() -> void:
	_checar_pecas_paradas()
	_checar_entrada()
	_checar_saida()
	var z_longe := PlantaBlitz.COMPRIMENTO + PlantaBlitz.ZONA_ANTES
	_checar_desvio(0.0, z_longe, VEL_AVENIDA)
	_checar_desvio(float(PlantaBlitz.geometria(_via)["x_dentro"]), z_longe, VEL_AVENIDA)
	# Quem entra tarde: vira da transversal de cima e sai da curva na faixa 0.
	# A ponta de montante fica na zebra de la mais 0,5 m, e o carro termina a
	# curva uns 7 m antes dela, a velocidade de curva (6 a 8 m/s). Mais perto que
	# isso nenhum carro surge; se surgir, os cones voam, que e para isso que eles
	# sao peca solta.
	# Aqui a margem e zero, e nao FOLGA_MIN: e o limite do esterco da IA (a
	# olhada curta ja esta no minimo que nao oscila), e o que se exige e nao
	# encostar. Medido: 4 e 7 cm.
	_checar_desvio(0.0, PlantaBlitz.COMPRIMENTO + 7.0, 6.0, 0.0)
	_checar_desvio(0.0, PlantaBlitz.COMPRIMENTO + 8.0, 8.0, 0.0)
	_checar_caminhos()
	_checar_encaixe()
	print("")
	print("[blitz] %s — %d falha(s)" % ["OK" if _falhas == 0 else "FALHOU", _falhas])
	quit(1 if _falhas > 0 else 0)


func _relatar(nome: String, ok: bool, detalhe: String) -> void:
	print("  %s  %-34s %s" % ["ok " if ok else "XX ", nome, detalhe])
	if not ok:
		_falhas += 1


# --- pecas paradas ------------------------------------------------------------

func _checar_pecas_paradas() -> void:
	print("[blitz] pecas paradas")
	var pecas := PlantaBlitz.pecas_fixas(_via)
	var g := PlantaBlitz.geometria(_via)
	var pior := INF
	var par := ""
	for i in pecas.size():
		for j in range(i + 1, pecas.size()):
			var d := _dist_caixas(pecas[i], pecas[j])
			if d < pior:
				pior = d
				par = "%s x %s" % [pecas[i]["nome"], pecas[j]["nome"]]
	_relatar("nada encosta em nada", pior >= 0.05, "menor folga %.2f m (%s)" % [pior, par])
	var fora := ""
	for p: Dictionary in pecas:
		var c: Vector3 = p["centro"]
		var m: Vector3 = p["meia"]
		if c.z - m.z < 0.0 or c.z + m.z > PlantaBlitz.COMPRIMENTO:
			fora += " %s(z %.2f..%.2f)" % [p["nome"], c.z - m.z, c.z + m.z]
		# Nada alem do fim da calcada nem na contramao.
		if c.x + m.x > float(g["x_calcada_fim"]) or c.x - m.x < float(g["x_eixo"]):
			fora += " %s(x %.2f..%.2f)" % [p["nome"], c.x - m.x, c.x + m.x]
	_relatar("tudo dentro da reserva", fora.is_empty(),
		"z 0..%.1f, x %.2f..%.2f%s" % [PlantaBlitz.COMPRIMENTO, g["x_eixo"],
			g["x_calcada_fim"], fora])
	# A viatura com a maior parte na calcada, e o corredor do policial largo.
	var p := PlantaBlitz.planta(_via)
	var v: Vector3 = p["viatura"]
	var mf: float = g["x_meio_fio"]
	var na_calcada := clampf((v.x + PlantaBlitz.MEIA_CARRO.x - mf) / (2.0 * PlantaBlitz.MEIA_CARRO.x),
		0.0, 1.0)
	_relatar("viatura com 2 rodas na calcada", na_calcada >= 0.6,
		"%.0f%% da largura alem do meio-fio" % (na_calcada * 100.0))
	_relatar("viatura antes do fim da calcada",
		v.x + PlantaBlitz.MEIA_CARRO.x <= float(g["x_calcada_fim"]) - 0.5,
		"lataria ate x %.2f, calcada ate %.2f" % [v.x + PlantaBlitz.MEIA_CARRO.x,
			g["x_calcada_fim"]])


# --- carro simulado -------------------------------------------------------------

## Um passo do carro da IA como `Carro._dirigir_ia` faz: velocidade para o
## teto com ACELERA/FREIA, e rumo para a mira com giro limitado — e, parado no
## teto zero, sem girar (o `blitz_parado`).
func _passo(carro: Dictionary, mira: Vector3, teto: float, taxa: float) -> void:
	var v: float = carro["v"]
	if teto > v:
		v = minf(teto, v + ACELERA * DT)
	else:
		v = maxf(teto, v - FREIA * DT)
	var pos: Vector3 = carro["pos"]
	var giro: float = carro["giro"]
	var para := mira - pos
	para.y = 0.0
	var parado := teto <= 0.05 and v < 0.45
	if para.length() > 0.05 and not parado:
		var quero := atan2(-para.x, -para.z)
		giro += clampf(wrapf(quero - giro, -PI, PI), -taxa * DT, taxa * DT)
	var frente := Vector3(-sin(giro), 0.0, -cos(giro))
	carro["pos"] = pos + frente * v * DT
	carro["giro"] = giro
	carro["v"] = v


## Os quatro cantos do carro no plano do chao.
func _cantos(carro: Dictionary, folga: float) -> PackedVector2Array:
	var pos: Vector3 = carro["pos"]
	var giro: float = carro["giro"]
	var hx := PlantaBlitz.MEIA_CARRO.x + folga
	var hz := PlantaBlitz.MEIA_CARRO.z
	var out := PackedVector2Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var lx := s.x * hx
		var lz := s.y * hz
		# Basis(UP, giro): x' = x cos + z sin ; z' = -x sin + z cos
		out.append(Vector2(pos.x + lx * cos(giro) + lz * sin(giro),
			pos.z - lx * sin(giro) + lz * cos(giro)))
	return out


## Quanto falta para o canto mais a direita do carro chegar ao meio-fio.
func _folga_da_guia(carro: Dictionary) -> float:
	var mf: float = PlantaBlitz.geometria(_via)["x_meio_fio"]
	var mais := -INF
	for c: Vector2 in _cantos(carro, 0.0):
		mais = maxf(mais, c.x)
	return mf - mais


## Menor folga entre o carro e as pecas, e quem.
func _folga_do_carro(carro: Dictionary, pecas: Array[Dictionary]) -> Array:
	var poli := _cantos(carro, 0.0)
	var pior := INF
	var quem := ""
	for p: Dictionary in pecas:
		var c: Vector3 = p["centro"]
		var m: Vector3 = p["meia"]
		var ret := PackedVector2Array([Vector2(c.x - m.x, c.z - m.z), Vector2(c.x + m.x, c.z - m.z),
			Vector2(c.x + m.x, c.z + m.z), Vector2(c.x - m.x, c.z + m.z)])
		var d := _dist_poligonos(poli, ret)
		if d < pior:
			pior = d
			quem = String(p["nome"])
	return [pior, quem]


func _checar_entrada() -> void:
	print("[blitz] carro abordado entrando")
	var pecas := PlantaBlitz.pecas_fixas(_via)
	var carro := {"pos": Vector3(0.0, 0.0, PlantaBlitz.COMPRIMENTO + PlantaBlitz.ZONA_ANTES),
		"giro": 0.0, "v": VEL_AVENIDA}
	var pior := INF
	var quem := ""
	var onde := 0.0
	var guia := INF
	var parado := 0.0
	var t := 0.0
	while t < 40.0 and parado < 0.5:
		var local: Vector3 = carro["pos"]
		_passo(carro, PlantaBlitz.mira_entrada(_via, local),
			minf(VEL_AVENIDA, PlantaBlitz.teto_entrada(local.z)), TAXA_GIRO)
		var f := _folga_do_carro(carro, pecas)
		if float(f[0]) < pior:
			pior = f[0]
			quem = f[1]
			onde = (carro["pos"] as Vector3).z
		guia = minf(guia, _folga_da_guia(carro))
		parado = parado + DT if float(carro["v"]) < 0.05 else 0.0
		t += DT
	var fim: Vector3 = carro["pos"]
	var baia: Vector3 = PlantaBlitz.planta(_via)["baia"]
	_relatar("entra sem encostar", pior >= FOLGA_MIN,
		"menor folga %.2f m (%s, carro em z %.1f)" % [pior, quem, onde])
	_relatar("entra sem subir no meio-fio", guia >= 0.05, "menor folga %.2f m" % guia)
	_relatar("encosta na guia", absf(fim.x - baia.x) < 0.15,
		"lataria a %.2f m do meio-fio" % (float(PlantaBlitz.geometria(_via)["x_meio_fio"])
			- fim.x - PlantaBlitz.MEIA_CARRO.x))
	_relatar("para na baia", absf(fim.x - baia.x) < 0.3 and absf(fim.z - baia.z) < 0.4,
		"parou em (%.2f, %.2f), baia (%.2f, %.2f), %.1f s" % [fim.x, fim.z, baia.x, baia.z, t])
	_relatar("para alinhado", absf(rad_to_deg(float(carro["giro"]))) < 6.0,
		"rumo %.1f graus" % rad_to_deg(float(carro["giro"])))


func _checar_saida() -> void:
	print("[blitz] carro liberado saindo")
	var p := PlantaBlitz.planta(_via)
	var pecas := PlantaBlitz.pecas_fixas(_via)
	# O policial no ponto em que a Blitz solta o carro (`_segurando_saida`): no
	# corredor dos cones, na altura da traseira. Parado na janela ele ficava a
	# 7 cm do retrovisor, e por isso o carro espera.
	var janela: Vector3 = p["janela"]
	var solta := Vector3(janela.x - 0.05, 0.0,
		PlantaBlitz.Z_BAIA + PlantaBlitz.MEIA_CARRO.z + 0.8)
	pecas.append({"nome": "policial_saindo_da_janela", "centro": solta
		+ Vector3(0.0, PlantaBlitz.MEIA_PESSOA.y, 0.0), "meia": PlantaBlitz.MEIA_PESSOA})
	var carro := {"pos": p["baia"], "giro": 0.0, "v": 0.0}
	var pior := INF
	var quem := ""
	var guia := INF
	var t := 0.0
	while t < 20.0 and (carro["pos"] as Vector3).z > -PlantaBlitz.ZONA_DEPOIS:
		var local: Vector3 = carro["pos"]
		_passo(carro, PlantaBlitz.mira_saida(_via, local), PlantaBlitz.TETO_SAIDA, TAXA_GIRO)
		var f := _folga_do_carro(carro, pecas)
		if float(f[0]) < pior:
			pior = f[0]
			quem = f[1]
		guia = minf(guia, _folga_da_guia(carro))
		t += DT
	# Saindo da vaga a traseira abre para o lado da guia.
	_relatar("sai sem raspar o meio-fio", guia >= 0.05, "menor folga %.2f m" % guia)
	var fim: Vector3 = carro["pos"]
	_relatar("sai sem encostar", pior >= FOLGA_MIN, "menor folga %.2f m (%s)" % [pior, quem])
	_relatar("volta para a faixa 0", absf(fim.x) < 0.35,
		"x %.2f em z %.1f, %.1f s" % [fim.x, fim.z, t])


func _checar_desvio(x0: float, z0: float, v0: float, folga_min: float = FOLGA_MIN) -> void:
	print("[blitz] carro passando direto, vindo de x %.2f z %.1f a %.0f m/s" % [x0, z0, v0])
	var g := PlantaBlitz.geometria(_via)
	var pecas := PlantaBlitz.pecas_fixas(_via)
	var carro := {"pos": Vector3(x0, 0.0, z0), "giro": 0.0, "v": v0}
	var t := 0.0
	var pior := INF
	var quem := ""
	var contramao := -INF
	while (carro["pos"] as Vector3).z > -PlantaBlitz.ZONA_DEPOIS and t < 30.0:
		t += DT
		var local: Vector3 = carro["pos"]
		_passo(carro, PlantaBlitz.mira_desvio(_via, local),
			minf(VEL_AVENIDA, PlantaBlitz.teto_desvio(_via, local)), TAXA_GIRO_DESVIO)
		var f := _folga_do_carro(carro, pecas)
		if float(f[0]) < pior:
			pior = f[0]
			quem = f[1]
		for c: Vector2 in _cantos(carro, 0.0):
			contramao = maxf(contramao, float(g["x_eixo"]) - c.x)
	_relatar("passa sem encostar", pior >= folga_min, "menor folga %.2f m (%s)" % [pior, quem])
	_relatar("passa e nao empaca", t < 30.0, "%.1f s ate sair da zona" % t)
	_relatar("nao invade a contramao", contramao <= 0.0,
		"canto mais a esquerda %.2f m alem do eixo" % contramao)


# --- gente andando ----------------------------------------------------------------

func _checar_caminhos() -> void:
	print("[blitz] gente andando")
	var p := PlantaBlitz.planta(_via)
	var baia: Vector3 = p["baia"]
	var carro_baia := {"nome": "carro_na_baia", "centro": baia
		+ Vector3(0.0, PlantaBlitz.MEIA_CARRO.y, 0.0), "meia": PlantaBlitz.MEIA_CARRO}
	var fixas := PlantaBlitz.pecas_fixas(_via)
	var sem_posto_0: Array[Dictionary] = []
	for f: Dictionary in fixas:
		if String(f["nome"]) != "policial_0":
			sem_posto_0.append(f)
	sem_posto_0.append(carro_baia)
	var r := _folga_caminho(_poligonal(p["posto_0"], p["caminho_ida"]), sem_posto_0)
	_relatar("policial vai a janela", float(r[0]) >= 0.05, "menor folga %.2f m (%s)" % r)
	r = _folga_caminho(_poligonal(p["janela"], p["caminho_revista"]), sem_posto_0)
	_relatar("policial vai a revista", float(r[0]) >= 0.05, "menor folga %.2f m (%s)" % r)
	r = _folga_caminho(_poligonal(p["janela"], p["caminho_volta"]), sem_posto_0)
	_relatar("policial volta da janela", float(r[0]) >= 0.05, "menor folga %.2f m (%s)" % r)
	r = _folga_caminho(_poligonal(p["revista_oficial"], p["caminho_volta_revista"]), sem_posto_0)
	_relatar("policial volta da revista", float(r[0]) >= 0.05, "menor folga %.2f m (%s)" % r)
	# O motorista desce com o policial ja na revista.
	var com_oficial := sem_posto_0.duplicate()
	com_oficial.append({"nome": "policial_na_revista", "centro": (p["revista_oficial"] as Vector3)
		+ Vector3(0.0, PlantaBlitz.MEIA_PESSOA.y, 0.0), "meia": PlantaBlitz.MEIA_PESSOA})
	r = _folga_caminho(_poligonal(p["porta"], p["caminho_motorista"]), com_oficial)
	_relatar("motorista desce e vai a revista", float(r[0]) >= 0.05, "menor folga %.2f m (%s)" % r)
	r = _folga_caminho(_poligonal(p["revista_motorista"], p["caminho_motorista_volta"]),
		com_oficial)
	_relatar("motorista volta ao carro", float(r[0]) >= 0.05, "menor folga %.2f m (%s)" % r)
	var frente: Vector3 = (p["revista_motorista"] as Vector3) - (p["revista_oficial"] as Vector3)
	frente.y = 0.0
	_relatar("revista frente a frente", frente.length() > 0.8 and frente.length() < 1.6,
		"%.2f m entre os dois" % frente.length())


func _poligonal(inicio: Vector3, resto: Array) -> Array[Vector3]:
	var pontos: Array[Vector3] = [inicio]
	for q: Vector3 in resto:
		pontos.append(q)
	return pontos


## Menor folga de uma pessoa (caixa MEIA_PESSOA) andando pela poligonal.
func _folga_caminho(pontos: Array[Vector3], pecas: Array[Dictionary]) -> Array:
	var pior := INF
	var quem := ""
	for k in range(pontos.size() - 1):
		var a := pontos[k]
		var b := pontos[k + 1]
		var n := maxi(2, int(a.distance_to(b) / 0.05))
		for s in n + 1:
			var c := a.lerp(b, float(s) / float(n))
			var eu := {"centro": c + Vector3(0.0, PlantaBlitz.MEIA_PESSOA.y, 0.0),
				"meia": PlantaBlitz.MEIA_PESSOA}
			for p: Dictionary in pecas:
				var d := _dist_caixas(eu, p)
				if d < pior:
					pior = d
					quem = String(p["nome"])
	return [pior, quem]


# --- encaixe na cidade ------------------------------------------------------------

## Conta onde a blitz cabe numa janela grande da cidade, e confere, em cada
## encaixe, que as duas pontas guardam a folga do cruzamento.
func _checar_encaixe() -> void:
	print("[blitz] encaixe na malha")
	var achados := 0
	var ruins := ""
	var pintura := ""
	var com_avenida := 0
	var vistos := {}
	for i in range(-40, 41):
		for j in range(-40, 41):
			for eixo: int in [0, 1]:
				for sentido: int in [1, -1]:
					var t := Vias.trecho(eixo, sentido, 0)
					var de := Vector2i(i, j)
					var ponto := Vector3(float(i) * 32.0, 0.0, float(j) * 32.0 + 16.0) \
						if eixo == 0 else Vector3(float(i) * 32.0 + 16.0, 0.0, float(j) * 32.0)
					var e := PlantaBlitz.encaixar(t, de, ponto)
					if e.is_empty():
						continue
					var chave := "%d/%d/%d/%d" % [eixo, e["linha"], e["quadra"], sentido]
					if vistos.has(chave):
						continue
					vistos[chave] = true
					achados += 1
					var origem: Vector3 = e["origem"]
					var dir: Vector3 = e["dir"]
					var montante := origem - dir * PlantaBlitz.COMPRIMENTO
					var s0 := origem.z if eixo == 0 else origem.x
					var s1 := montante.z if eixo == 0 else montante.x
					var k: int = e["quadra"]
					var lo := minf(s0, s1) - float(k) * 32.0
					var hi := maxf(s0, s1) - float(k) * 32.0
					if lo < 0.0 or hi > 32.0:
						ruins += " %s(%.1f..%.1f)" % [chave, lo, hi]
					# A ponta de jusante antes da linha de retencao pintada, e a
					# de montante depois da zebra — medidas daqui, pela largura
					# do asfalto no no, e nao pela conta da planta.
					var no_jus := k + 1 if sentido > 0 else k
					var no_mon := k if sentido > 0 else k + 1
					var linha: int = e["linha"]
					var d_jus := absf(s0 - float(no_jus) * 32.0)
					var d_mon := absf(s1 - float(no_mon) * 32.0)
					var ret := _asfalto_no(eixo, linha, no_jus) + Vias.FOLGA_RETENCAO + 0.14
					var zeb := _asfalto_no(eixo, linha, no_mon) + 1.75
					if _tem_transversal(eixo, linha, no_jus) and d_jus < ret:
						pintura += " %s(jusante %.2f < retencao %.2f)" % [chave, d_jus, ret]
					if _tem_transversal(eixo, linha, no_mon) and d_mon < zeb:
						pintura += " %s(montante %.2f < zebra %.2f)" % [chave, d_mon, zeb]
					if ret > 9.0 or zeb > 8.0:
						com_avenida += 1
	_relatar("a blitz cabe em algum lugar", achados > 0, "%d encaixes" % achados)
	_relatar("encaixe dentro da quadra", ruins.is_empty(), ruins)
	_relatar("longe da retencao e da zebra", pintura.is_empty(), pintura.substr(0, 300))
	# A quadra mais apertada: avenida transversal numa das pontas.
	_relatar("cabe com avenida numa ponta", com_avenida > 0,
		"%d quadras com avenida transversal" % com_avenida)


func _asfalto_no(eixo: int, linha: int, k: int) -> float:
	return Vias.meia_asfalto_z_no(linha, k) if eixo == 0 else Vias.meia_asfalto_x_no(k, linha)


func _tem_transversal(eixo: int, linha: int, k: int) -> bool:
	if eixo == 0:
		return (MalhaUrbana.via_z_em(k, linha) != MalhaUrbana.Via.NENHUMA
			or MalhaUrbana.via_z_em(k, linha - 1) != MalhaUrbana.Via.NENHUMA)
	return (MalhaUrbana.via_x_em(k, linha) != MalhaUrbana.Via.NENHUMA
		or MalhaUrbana.via_x_em(k, linha - 1) != MalhaUrbana.Via.NENHUMA)


# --- geometria ----------------------------------------------------------------------

## Distancia entre duas caixas alinhadas {centro, meia}. Negativa = penetracao.
func _dist_caixas(a: Dictionary, b: Dictionary) -> float:
	var ca: Vector3 = a["centro"]
	var ma: Vector3 = a["meia"]
	var cb: Vector3 = b["centro"]
	var mb: Vector3 = b["meia"]
	var d := Vector3(absf(ca.x - cb.x) - ma.x - mb.x, absf(ca.y - cb.y) - ma.y - mb.y,
		absf(ca.z - cb.z) - ma.z - mb.z)
	if d.x < 0.0 and d.y < 0.0 and d.z < 0.0:
		return maxf(d.x, maxf(d.y, d.z))
	return Vector3(maxf(d.x, 0.0), maxf(d.y, 0.0), maxf(d.z, 0.0)).length()


## Distancia entre dois poligonos convexos no plano. Negativa se sobrepoem.
func _dist_poligonos(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if _sobrepoem(a, b):
		return -_penetracao(a, b)
	var pior := INF
	for p: Vector2 in a:
		pior = minf(pior, _dist_ponto_poligono(p, b))
	for p: Vector2 in b:
		pior = minf(pior, _dist_ponto_poligono(p, a))
	return pior


func _dist_ponto_poligono(p: Vector2, poli: PackedVector2Array) -> float:
	var pior := INF
	for k in poli.size():
		var a := poli[k]
		var b := poli[(k + 1) % poli.size()]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		pior = minf(pior, p.distance_to(a + ab * t))
	return pior


## SAT: sobreposicao de convexos.
func _sobrepoem(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return _penetracao(a, b) > 0.0


## Menor penetracao por SAT (<= 0 se separados).
func _penetracao(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var menor := INF
	for poli: PackedVector2Array in [a, b]:
		for k in poli.size():
			var e := poli[(k + 1) % poli.size()] - poli[k]
			var n := Vector2(-e.y, e.x).normalized()
			var amin := INF
			var amax := -INF
			for p: Vector2 in a:
				amin = minf(amin, p.dot(n))
				amax = maxf(amax, p.dot(n))
			var bmin := INF
			var bmax := -INF
			for p: Vector2 in b:
				bmin = minf(bmin, p.dot(n))
				bmax = maxf(bmax, p.dot(n))
			var sob := minf(amax, bmax) - maxf(amin, bmin)
			if sob <= 0.0:
				return sob
			menor = minf(menor, sob)
	return menor
