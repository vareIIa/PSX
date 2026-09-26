## A bancada das pegadas do celular na estrada: resolve, mede e fotografa, fora
## da cena, as maos que o `MotoristaCena` usa da batida ate a leitura. O que ela
## acha vira as constantes de `src/world/pegadas_do_motorista.gd`.
##
##     godot --headless --path game res://tests/bancada_pegada_estrada.tscn -- <flags>
##     godot --path game --resolution 3840x2160 res://tests/bancada_pegada_estrada.tscn -- --fotos=<DIR ABSOLUTO>
##
## Flags:
##     --resolver-foto   a pegada da leitura (a da foto de referencia): polpas dos
##                       quatro dedos na lateral esquerda, polegar na lateral
##                       direita no terco de baixo, palma nas costas, nada sobre
##                       a tela; imprime `LEITURA`.
##     --resolver-toque  da palma da leitura, o polegar sai da borda, paira sobre
##                       o apagar, encosta nele (a mao escorrega uns milimetros) e
##                       volta; imprime `TOQUE_*`.
##     --resolver-chao   a pinca no aparelho deitado no tapete, e as pegadas-chave
##                       da troca ate a leitura; imprime `CHAO_*` e `TROCA`.
##     --checar-troca    confere as pegadas do arquivo: cada chave e o caminho
##                       entre elas de 0,02 em 0,02, com o aparelho girando na mao.
##     --medir           mede todas as pegadas do arquivo (a tabela do relatorio).
##     --fotos=<dir>     fotografa as pegadas do arquivo (precisa de janela).
##
## Tudo e contado no espaco do aparelho: x para a direita da tela, y para cima,
## z saindo do vidro, em metros (impresso em mm).
##
## As reguas sao tres, e nenhuma sozinha basta:
##     esferas   as do `AjusteDaMao` (o que o ajuste ve);
##     capsulas  cada falange como tubo de raio variavel, com a secao achatada
##               (`MaoModelada.DEDO_ACHATA`) virada para o aparelho; e delas que
##               sai a tela tapada, por raio da tela ate o olho da cena;
##     malha     a malha de verdade (`MaoPosada.montar`), amostrada por
##               TRIANGULO (15 pontos cada), e nao por vertice: falange de 29 mm
##               contra 9,3 mm de aparelho atravessa sem vertice nenhum dentro.
## E cada regua tem um controle positivo (`_controles`): uma pegada empurrada
## para dentro do aparelho, e para baixo do tapete, tem de ser reprovada.
extends Node

const CAMINHO_PEGADAS := "res://src/world/pegadas_do_motorista.gd"
const PELE := Color(0.78, 0.62, 0.50)
const MANGA := Color(0.82, 0.83, 0.86)
## Folga antes de contar como dentro (m): a mesma do `AjusteDaMao`.
const FOLGA_DENTRO := 0.0003
## Grade da tela para a tela tapada (colunas x linhas): um raio por celula de
## 0,68 mm.
const GRADE := Vector2i(73, 110)

## Copias do `MotoristaCena` (lidas de novo em `_ler_cena`, se o arquivo
## compilar): o olho da cena, onde o aparelho fica na leitura e o ombro.
var olho_da_cena := Vector3(0.0, 0.0, 0.20)
var celular_na_leitura := Vector3(0.035, -0.085, 0.03)
var ombro_d := Vector3(0.19, -0.27, 0.12)
var apagar_uv := Vector2(0.923, 0.904)
var tecla_acima := 0.011
## O giro do aparelho na mao da leitura (`_giro_do_fone`) e o polo do cotovelo
## do braco da leitura (`_braco_leitura.polo`, com o carona a direita).
const GIRO_DO_FONE_GRAUS := -20.0
const POLO_LEITURA := Vector3(1.0, -0.9, 0.2)

var M := Iphone4S.TAMANHO * 0.5
var T := Iphone4S.TELA * 0.5
## A leitura, no espaco do carro contado do olho: o aparelho, e no espaco dele
## o olho da cena, o ombro direito e o polo do cotovelo.
var fone_leitura := Transform3D()
var olho_fone := Vector3.ZERO
var ombro_fone := Vector3.ZERO
var polo_fone := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


# --- o ajuste com o tapete e a tela ----------------------------------------------

## O `AjusteDaMao` com tres regras a mais, sem mexer no arquivo dele (que e
## compartilhado): o tapete (nenhuma esfera abaixo de `chao_z`), a tela livre
## (nenhuma esfera na frente do vidro em cima da tela) e a ancora (a mao perto
## de onde estava, para o polegar apertar a tecla escorregando so uns
## milimetros). E duas metas: `palma` (uma esfera da palma encostando no
## aparelho) e `longe` (uma esfera da mao a pelo menos `folga` dele).
class Ajuste extends AjusteDaMao:
	var chao_z: float = -INF
	var tela_livre: bool = false
	var tela_peso: float = 2.0
	var ancora := PackedFloat64Array()
	var ancora_peso := Vector2.ZERO
	## As falanges como tubos de secao achatada, amostrados a cada quarto: as
	## esferas do ajuste sao redondas com o raio menor, e de lado o dedo e mais
	## largo que isso — a malha entrava 1,7 mm onde as esferas diziam 0,2.
	var tubos: bool = true

	func _residuos_dos_tubos(e: Dictionary, r: PackedFloat64Array) -> void:
		var ids := [4] if _so_polegar else [0, 1, 2, 3, 4]
		for i: int in ids:
			var dedo: Dictionary = e["polegar"] if i == 4 else e["dedos"][i]
			var js: Array[Vector3] = dedo["juntas"]
			var ds: Array[Vector3] = dedo["dorsos"]
			var rs := MaoPosada.raios_do_dedo(i)
			var n := js.size() - 1
			for k in range(1, n):
				var a := js[k]
				var b := js[k + 1]
				var rb := float(rs[mini(k + 1, 3)])
				if k == n - 1:
					b = MaoPosada.polpa(e, i)["centro"]
					rb = float(rs[3])
				var t_dir := (b - a).normalized()
				var n_dir: Vector3 = ds[mini(k, ds.size() - 1)]
				n_dir = (n_dir - t_dir * n_dir.dot(t_dir)).normalized()
				var s_dir := t_dir.cross(n_dir)
				for q in 4:
					var t := (float(q) + 0.5) / 4.0
					var p := a.lerp(b, t)
					var rr := lerpf(float(rs[k]), rb, t)
					var sd := distancia(p, meia, raio_canto)
					var h := 0.0001
					var g := Vector3(distancia(p + Vector3(h, 0, 0), meia, raio_canto) - sd,
						distancia(p + Vector3(0, h, 0), meia, raio_canto) - sd,
						distancia(p + Vector3(0, 0, h), meia, raio_canto) - sd)
					var u := -g
					u = u - t_dir * u.dot(t_dir)
					var r_ef := rr * MaoModelada.DEDO_ACHATA
					if u.length() > 0.2 * h:
						u = u.normalized()
						r_ef = 1.0 / sqrt(pow(u.dot(s_dir) / rr, 2.0)
							+ pow(u.dot(n_dir) / (rr * MaoModelada.DEDO_ACHATA), 2.0))
					r.append(minf(sd - r_ef - FOLGA, 0.0) * 1000.0 * PESO_DENTRO)

	func _init(meia_caixa: Vector3, raio_do_canto: float, e_direita: bool) -> void:
		super(meia_caixa, raio_do_canto, e_direita)

	func _residuos(x: PackedFloat64Array) -> PackedFloat64Array:
		var r := super._residuos(x)
		if chao_z > -1.0 or tela_livre:
			var e := _esqueleto(x)
			var tela := Iphone4S.TELA * 0.5
			for esf: Array in _esferas(e, _so_polegar):
				var c: Vector3 = esf[0]
				var rr: float = float(esf[1]) * float(esf[2])
				if chao_z > -1.0:
					r.append(minf(c.z - rr - chao_z - FOLGA, 0.0) * 1000.0 * PESO_DENTRO)
				if tela_livre:
					var ox := tela.x + rr - absf(c.x)
					var oy := tela.y + rr - absf(c.y)
					var oz := c.z + rr - meia.z
					r.append(maxf(minf(minf(ox, oy), oz), 0.0) * 1000.0 * tela_peso)
		if tubos:
			_residuos_dos_tubos(_esqueleto(x), r)
		if not ancora.is_empty():
			for j in 3:
				r.append((x[j] - ancora[j]) * ancora_peso.x)
			for j in range(3, 6):
				r.append((x[j] - ancora[j]) * ancora_peso.y)
		return r

	func _residuo_da_meta(e: Dictionary, meta: Dictionary, r: PackedFloat64Array) -> void:
		match meta["tipo"]:
			&"palma", &"longe":
				r.append(_erro_da_meta(e, meta) * 1000.0 * float(meta.get("peso", 1.0)))
			_:
				super._residuo_da_meta(e, meta, r)

	func _erro_da_meta(e: Dictionary, meta: Dictionary) -> float:
		match meta["tipo"]:
			&"palma":
				var c := esfera_da_palma(e, int(meta["fileira"]), float(meta["u"]))
				return distancia(c[0], meia, raio_canto) - float(c[1])
			&"longe":
				var dedo: Dictionary = e["polegar"] if int(meta["dedo"]) == 4 \
					else e["dedos"][int(meta["dedo"])]
				var js: Array[Vector3] = dedo["juntas"]
				var k := int(meta["falange"])
				var p := js[k].lerp(js[k + 1], float(meta.get("t", 0.5)))
				var falta := float(meta["folga"]) - distancia(p, meia, raio_canto)
				return maxf(falta, 0.0)
		return super._erro_da_meta(e, meta)

	## Uma esfera da palma: fileira de `MaoModelada.PALMA` (0 no calcanhar, 4 nos
	## nos) e `u` de -1 (lado do minimo) a 1 (lado do polegar).
	static func esfera_da_palma(e: Dictionary, fileira: int, u: float) -> Array:
		var f: Array = MaoModelada.PALMA[fileira]
		var esp: float = f[2]
		var meia_l := float(f[1]) * 0.5 - esp * 0.5
		var c := MaoModelada._na_palma(e["q"], e["ld"], float(f[3]) + u * meia_l, float(f[0]),
			esp * 0.5)
		return [c, esp * 0.5]


# --- partida -------------------------------------------------------------------

func _ready() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	_rng.seed = 20260925
	_ler_cena()
	_preparar_leitura()
	var args := OS.get_cmdline_user_args()
	var hud := get_node_or_null("/root/Celular")
	if hud != null:
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	if args.has("--controles"):
		_controles()
	if args.has("--resolver-foto"):
		resolver_foto()
	if args.has("--resolver-toque"):
		resolver_toque()
	if args.has("--resolver-chao"):
		resolver_chao()
	if args.has("--checar-troca"):
		checar_troca()
	if args.has("--medir"):
		medir_arquivo()
	for a: String in args:
		if a.begins_with("--fotos="):
			await fotos(a.trim_prefix("--fotos="))
	get_tree().quit(0)


## Le as constantes do `MotoristaCena`, se ele compilar agora (outra sessao pode
## estar no meio de uma edicao): as copias de cima valem quando nao.
func _ler_cena() -> void:
	var s: Script = load("res://src/world/motorista_cena.gd")
	var mapa: Dictionary = s.get_script_constant_map() if s != null else {}
	if mapa.is_empty():
		print("[cena] motorista_cena.gd nao compilou agora: uso as copias")
		return
	olho_da_cena = mapa.get("OLHO_DA_CENA", olho_da_cena)
	celular_na_leitura = mapa.get("CELULAR_NA_LEITURA", celular_na_leitura)
	ombro_d = mapa.get("OMBRO_D", ombro_d)
	apagar_uv = mapa.get("APAGAR_UV", apagar_uv)
	tecla_acima = mapa.get("TECLA_ACIMA", tecla_acima)
	print("[cena] olho %s, leitura %s, ombro %s, apagar %s" % [olho_da_cena, celular_na_leitura,
		ombro_d, apagar_uv])


## O aparelho na leitura como o `MotoristaCena._fone_na_leitura` o poe (sem a
## cabeca debrucada), e o olho, o ombro e o polo no espaco dele.
func _preparar_leitura() -> void:
	var pos := celular_na_leitura
	var base := Basis.looking_at((olho_da_cena - pos).normalized(), Vector3.UP, true)
	fone_leitura = Transform3D(base, pos) * Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(GIRO_DO_FONE_GRAUS), 0.0, 0.0)), Vector3.ZERO)
	var inv := fone_leitura.affine_inverse()
	olho_fone = inv * olho_da_cena
	ombro_fone = inv * (olho_da_cena + ombro_d)
	polo_fone = inv.basis * POLO_LEITURA
	print("[leitura] olho no aparelho %s mm, ombro %s mm" % [_mm(olho_fone), _mm(ombro_fone)])


# --- reguas ----------------------------------------------------------------------

static func caixa(p: Vector3) -> float:
	return AjusteDaMao.distancia(p, Iphone4S.TAMANHO * 0.5, Iphone4S.RAIO_CANTO)


static func _gradiente(p: Vector3) -> Vector3:
	var h := 0.0001
	return Vector3(caixa(p + Vector3(h, 0, 0)) - caixa(p - Vector3(h, 0, 0)),
		caixa(p + Vector3(0, h, 0)) - caixa(p - Vector3(0, h, 0)),
		caixa(p + Vector3(0, 0, h)) - caixa(p - Vector3(0, 0, h))).normalized()


## A mao em capsulas: [a, b, raio_a, raio_b, dedo, dorso]. Cada falange inteira,
## do no ao centro da ponta; o polegar da base (dentro da tenar) a ponta.
static func capsulas(e: Dictionary) -> Array:
	var out := []
	for i in 5:
		var dedo: Dictionary = e["polegar"] if i == 4 else e["dedos"][i]
		var js: Array[Vector3] = dedo["juntas"]
		var ds: Array[Vector3] = dedo["dorsos"]
		var rs := MaoPosada.raios_do_dedo(i)
		var n := js.size() - 1
		for k in n:
			var b := js[k + 1]
			var rb := float(rs[mini(k + 1, 3)])
			if k == n - 1:
				b = MaoPosada.polpa(e, i)["centro"]
				rb = float(rs[3])
			out.append([js[k], b, float(rs[k]), rb, i, ds[mini(k, ds.size() - 1)]])
	return out


## A palma em esferas (nove por fileira, sem a margem do ajuste).
static func esferas_da_palma(e: Dictionary) -> Array:
	var out := []
	for f in MaoModelada.PALMA.size():
		for j in 9:
			out.append(Ajuste.esfera_da_palma(e, f, -1.0 + float(j) * 0.25))
	return out


## Quanto cada dedo (0 a 3, 4 o polegar, 5 a palma) entra no aparelho (mm,
## positivo e dentro), pelas capsulas com a secao achatada virada para ele.
func _dentro_por_capsula(e: Dictionary) -> Array:
	var pior := [-INF, -INF, -INF, -INF, -INF, -INF]
	for c: Array in capsulas(e):
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var t_dir := (b - a).normalized()
		var n_dir: Vector3 = c[5]
		n_dir = (n_dir - t_dir * n_dir.dot(t_dir)).normalized()
		var s_dir := t_dir.cross(n_dir)
		var passos := maxi(2, ceili(a.distance_to(b) / 0.001))
		for k in passos + 1:
			var t := float(k) / float(passos)
			var p := a.lerp(b, t)
			var r := lerpf(float(c[2]), float(c[3]), t)
			var sd := caixa(p)
			var u := -_gradiente(p)
			u = u - t_dir * u.dot(t_dir)
			var r_ef := r * MaoModelada.DEDO_ACHATA
			if u.length() > 0.2:
				u = u.normalized()
				r_ef = 1.0 / sqrt(pow(u.dot(s_dir) / r, 2.0)
					+ pow(u.dot(n_dir) / (r * MaoModelada.DEDO_ACHATA), 2.0))
			pior[int(c[4])] = maxf(pior[int(c[4])], (r_ef - sd) * 1000.0)
	for s: Array in esferas_da_palma(e):
		pior[5] = maxf(pior[5], (float(s[1]) - caixa(s[0])) * 1000.0)
	return pior


## A folga de cada polpa (mm): a bola da ponta ate a caixa. Zero e encostar.
static func folgas(e: Dictionary) -> Array:
	var out := []
	for i in 5:
		var pp := MaoPosada.polpa(e, i)
		var r := float(MaoPosada.raios_do_dedo(i)[3]) * MaoModelada.DEDO_ACHATA
		out.append(snappedf((caixa(pp["centro"]) - r) * 1000.0, 0.01))
	return out


## Quanto cada dedo fica sobre a tela (mm): o disco da falange na frente do vidro
## e dentro do retangulo dela, visto de frente.
func _sobre_a_tela(e: Dictionary) -> Array:
	var out := [0.0, 0.0, 0.0, 0.0, 0.0]
	for c: Array in capsulas(e):
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var passos := maxi(2, ceili(a.distance_to(b) / 0.001))
		for k in passos + 1:
			var t := float(k) / float(passos)
			var p := a.lerp(b, t)
			var r := lerpf(float(c[2]), float(c[3]), t)
			if p.z + r * MaoModelada.DEDO_ACHATA <= M.z:
				continue
			var ov := minf(T.x + r - absf(p.x), T.y + r - absf(p.y))
			if ov > 0.0:
				out[int(c[4])] = maxf(out[int(c[4])], ov * 1000.0)
	return out


## A tela tapada vista do olho (no espaco do aparelho): um raio de cada celula da
## grade ate o olho, contra as capsulas dos dedos e as esferas da palma. Devolve
## a fracao total, a do polegar e a do terco de baixo.
func tela_tapada(e: Dictionary, olho: Vector3) -> Dictionary:
	var caps := capsulas(e)
	var palma := esferas_da_palma(e)
	var total := 0
	var do_polegar := 0
	var baixo := 0
	var n_baixo := 0
	for iy in GRADE.y:
		for ix in GRADE.x:
			var uv := Vector2((float(ix) + 0.5) / float(GRADE.x), (float(iy) + 0.5) / float(GRADE.y))
			var s := Iphone4S.ponto_da_tela(uv)
			var terco := uv.y > 2.0 / 3.0
			if terco:
				n_baixo += 1
			var quem := -1
			for c: Array in caps:
				var sub := 4
				for j in sub:
					var a: Vector3 = (c[0] as Vector3).lerp(c[1], float(j) / float(sub))
					var b: Vector3 = (c[0] as Vector3).lerp(c[1], float(j + 1) / float(sub))
					var r := maxf(lerpf(float(c[2]), float(c[3]), float(j) / float(sub)),
						lerpf(float(c[2]), float(c[3]), float(j + 1) / float(sub)))
					if _segmento_segmento(s, olho, a, b) < r:
						quem = int(c[4])
						break
				if quem >= 0:
					break
			if quem < 0:
				for sp: Array in palma:
					if _segmento_segmento(s, olho, sp[0], sp[0]) < float(sp[1]):
						quem = 5
						break
			if quem >= 0:
				total += 1
				if quem == 4:
					do_polegar += 1
				if terco:
					baixo += 1
	var n := float(GRADE.x * GRADE.y)
	return {"total": float(total) / n * 100.0, "polegar": float(do_polegar) / n * 100.0,
		"terco_de_baixo": float(baixo) / float(maxi(n_baixo, 1)) * 100.0}


## Menor distancia entre dois segmentos.
static func _segmento_segmento(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= 1e-12 and e <= 1e-12:
		return p1.distance_to(p2)
	if a <= 1e-12:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= 1e-12:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-14 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


## A malha de verdade (mao e antebraco ate `cotovelo`, no espaco do aparelho),
## amostrada por triangulo: quantos pontos entram no aparelho (e o mais fundo, e
## de que dedo), e o ponto mais baixo (para o tapete).
func medir_malha(p: Dictionary, cotovelo: Vector3) -> Dictionary:
	var dados := PSXMesh.dados_vazios()
	MaoModelada.forma = {}
	MaoPosada.montar(dados, p["o"], p["d"], p["dorso"], p["pose"], true, cotovelo, PELE, MANGA,
		true)
	var vs: PackedVector3Array = dados["v"]
	var ids: PackedInt32Array = dados["i"]
	var e := MaoPosada.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
	var caps := capsulas(e)
	var dentro := 0
	var pior := 0.0
	var quem := -1
	var mais_baixo := INF
	var por_dedo := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for v in vs:
		mais_baixo = minf(mais_baixo, v.z)
	for t in range(0, ids.size(), 3):
		var a := vs[ids[t]]
		var b := vs[ids[t + 1]]
		var c := vs[ids[t + 2]]
		for i in 5:
			for j in 5 - i:
				var w1 := float(i) / 4.0
				var w2 := float(j) / 4.0
				var q := a * w1 + b * w2 + c * (1.0 - w1 - w2)
				var sd := caixa(q)
				if sd < -FOLGA_DENTRO:
					dentro += 1
					var dq := _dedo_perto(caps, q)
					por_dedo[dq] = minf(float(por_dedo[dq]), sd * 1000.0)
					if sd < pior:
						pior = sd
						quem = dq
	return {"dentro": dentro, "pior_mm": pior * 1000.0, "dedo": quem, "triangulos": ids.size() / 3,
		"por_dedo_mm": por_dedo,
		"mais_baixo_mm": mais_baixo * 1000.0}


static func _dedo_perto(caps: Array, q: Vector3) -> int:
	var melhor := INF
	var quem := 5
	for c: Array in caps:
		var d := _segmento_segmento(q, q, c[0], c[1]) - float(c[3])
		if d < melhor:
			melhor = d
			quem = int(c[4])
	return quem if melhor < 0.004 else 5


## O punho, o cotovelo pelo IK do `BracoVivo` e o quanto o pulso dobra: extensao
## (positiva com a mao para o dorso) e desvio (positivo para o polegar), em graus
## entre o antebraco e `d`; e a distancia do punho ao ombro (o braco alcanca
## 0,549 m).
static func pulso(p: Dictionary, ombro: Vector3, polo: Vector3) -> Dictionary:
	var pu := MaoPosada.punho_de(p["o"], p["d"], p["dorso"])
	var cot := BracoVivo.cotovelo_entre(pu, ombro, polo)
	var f := (pu - cot).normalized()
	var ref := MaoPosada.referencial(p["o"], p["d"], p["dorso"], true)
	var fl := ref.basis.inverse() * f
	return {"punho": pu, "cotovelo": cot, "extensao": rad_to_deg(atan2(-fl.y, fl.z)),
		"desvio": rad_to_deg(atan2(-fl.x, fl.z)), "alcance": pu.distance_to(ombro)}


## Os angulos no limite do `AjusteDaMao` (nomes).
static func no_limite(p: Dictionary) -> Array:
	var out := []
	var nomes := ["ind", "med", "anel", "min"]
	for i in 4:
		for j in 4:
			var v := float(p["pose"]["dedos"][i][j])
			if v <= float(AjusteDaMao.DEDO_MIN[j]) + 0.05 or v >= float(AjusteDaMao.DEDO_MAX[j]) - 0.05:
				out.append("%s[%d]=%.0f" % [nomes[i], j, v])
	for j in 5:
		var v := float(p["pose"]["polegar"][j])
		if v <= float(AjusteDaMao.POLEGAR_MIN[j]) + 0.05 or v >= float(AjusteDaMao.POLEGAR_MAX[j]) - 0.05:
			out.append("pol[%d]=%.0f" % [j, v])
	return out


## Todas as reguas numa pegada. `ctx`: `olho` (tela tapada), `chao` (o plano do
## tapete em z), `ombro` e `polo` (o pulso), `metas` (o erro de cada uma), e
## `malha` (false pula a malha, que e a regua cara).
func medir(nome: String, p: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var aj := Ajuste.new(M, Iphone4S.RAIO_CANTO, true)
	aj.metas = ctx.get("metas", [])
	var med := aj.medir(p)
	var e := MaoPosada.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
	var r := {"esferas_dentro": med["dentro"], "esferas_pior_mm": med["pior_mm"],
		"metas_mm": med["metas_mm"], "custo": med["custo"]}
	r["capsulas_mm"] = _dentro_por_capsula(e)
	r["folgas_mm"] = folgas(e)
	r["sobre_mm"] = _sobre_a_tela(e)
	var polegar: Vector3 = MaoPosada.polpa(e, 4)["centro"]
	r["polpa_polegar_mm"] = _mm(polegar)
	if ctx.has("olho"):
		r["tapada"] = tela_tapada(e, ctx["olho"])
	var ombro: Vector3 = ctx.get("ombro", ombro_fone)
	var polo: Vector3 = ctx.get("polo", polo_fone)
	var pu := pulso(p, ombro, polo)
	r["pulso"] = pu
	var baixo := INF
	for c: Array in capsulas(e):
		for k in 5:
			var t := float(k) / 4.0
			baixo = minf(baixo, (c[0] as Vector3).lerp(c[1], t).z
				- lerpf(float(c[2]), float(c[3]), t) * MaoModelada.DEDO_ACHATA)
	for s: Array in esferas_da_palma(e):
		baixo = minf(baixo, (s[0] as Vector3).z - float(s[1]))
	r["mais_baixo_mm"] = baixo * 1000.0
	if ctx.get("malha", true):
		r["malha"] = medir_malha(p, pu["cotovelo"])
	r["limites"] = no_limite(p)
	var linha := "[%s] esferas dentro=%d pior=%.2f | capsulas entram (mm) ind %.1f med %.1f anel %.1f min %.1f pol %.1f palma %.1f" % [
		nome, med["dentro"], med["pior_mm"], r["capsulas_mm"][0], r["capsulas_mm"][1],
		r["capsulas_mm"][2], r["capsulas_mm"][3], r["capsulas_mm"][4], r["capsulas_mm"][5]]
	if r.has("malha"):
		linha += " | malha: %d pontos dentro, pior %.2f mm (dedo %d; por dedo %s)" % [r["malha"]["dentro"],
			r["malha"]["pior_mm"], r["malha"]["dedo"], r["malha"]["por_dedo_mm"]]
	linha += "\n   folga das polpas (mm): ind %.2f med %.2f anel %.2f min %.2f pol %.2f | polpa do polegar %s" % [
		r["folgas_mm"][0], r["folgas_mm"][1], r["folgas_mm"][2], r["folgas_mm"][3], r["folgas_mm"][4],
		r["polpa_polegar_mm"]]
	linha += "\n   sobre a tela (mm): ind %.1f med %.1f anel %.1f min %.1f pol %.1f" % [
		r["sobre_mm"][0], r["sobre_mm"][1], r["sobre_mm"][2], r["sobre_mm"][3], r["sobre_mm"][4]]
	if r.has("tapada"):
		linha += " | tela tapada da lente %.1f%% (polegar %.1f%%, terco de baixo %.1f%%)" % [
			r["tapada"]["total"], r["tapada"]["polegar"], r["tapada"]["terco_de_baixo"]]
	linha += "\n   pulso: extensao %.0f, desvio %.0f graus; punho->ombro %.0f mm; punho %s mm" % [
		pu["extensao"], pu["desvio"], pu["alcance"] * 1000.0, _mm(pu["punho"])]
	linha += " | ponto mais baixo z=%.1f mm" % r["mais_baixo_mm"]
	if r.has("malha"):
		linha += " (malha %.1f)" % r["malha"]["mais_baixo_mm"]
	if not (r["limites"] as Array).is_empty():
		linha += "\n   no limite: %s" % [r["limites"]]
	if not (med["metas_mm"] as Array).is_empty():
		linha += "\n   metas (mm): %s" % [med["metas_mm"]]
	print(linha)
	return r


static func _mm(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x * 1000.0, v.y * 1000.0, v.z * 1000.0]


static func _v(v: Vector3) -> String:
	return "Vector3(%.4f, %.4f, %.4f)" % [v.x, v.y, v.z]


static func _pose_txt(pose: Dictionary) -> String:
	return JSON.stringify(pose)


## Uma pegada como texto de constante do arquivo de pegadas.
static func texto(nome: String, p: Dictionary) -> String:
	return "const %s := {\"o\": %s, \"d\": %s,\n\t\"dorso\": %s,\n\t\"pose\": %s}" % [nome,
		_v(p["o"]), _v(p["d"]), _v(p["dorso"]), _pose_txt(p["pose"])]


# --- controles positivos --------------------------------------------------------

## Cada regua reprova o defeito de proposito: a pegada da foto de rascunho
## empurrada 6 mm para dentro do aparelho (as tres reguas acusam), a mesma
## descida 15 mm (o tapete acusa), e um polegar posto em cima do vidro (a tela
## tapada sobe).
func _controles() -> void:
	var p := chute_foto_rascunho()
	print("\n[controle] a pegada de rascunho, como esta:")
	var ok := medir("controle base", p, {"olho": olho_fone})
	var dentro := p.duplicate()
	dentro["o"] = (p["o"] as Vector3) + Vector3(0.0, 0.0, 0.006)
	print("[controle] empurrada 6 mm para dentro (tem de acusar):")
	var r := medir("controle dentro", dentro, {"olho": olho_fone})
	var acusa := int(r["esferas_dentro"]) > int(ok["esferas_dentro"]) \
		and float(r["capsulas_mm"].max()) > 3.0 and int(r["malha"]["dentro"]) > 20
	print("[controle] dentro: %s" % ("ACUSA" if acusa else "CEGA"))
	var pol := p.duplicate(true)
	pol["pose"]["polegar"] = [40.0, 62.0, -90.0, 55.0, 18.0]
	var r2 := medir("controle polegar no vidro", pol, {"olho": olho_fone, "malha": false})
	print("[controle] tela tapada: %.1f%% -> %.1f%% (%s)" % [ok["tapada"]["total"], r2["tapada"]["total"],
		"ACUSA" if float(r2["tapada"]["total"]) > float(ok["tapada"]["total"]) + 5.0 else "CEGA"])


## A pegada da foto achada no rascunho do diagnostico (pegada_foto2): ponto de
## partida e controle.
static func chute_foto_rascunho() -> Dictionary:
	return {"o": Vector3(-0.019186, -0.035555, -0.015103), "d": Vector3(-0.461957, 0.886797, -0.013693),
		"dorso": Vector3(0.245788, 0.113173, -0.962694),
		"pose": {"dedos": [[5.64, 34.07, 68.43, -18.0], [20.38, 94.56, 78.18, -8.86],
			[28.75, 97.16, 75.46, 18.0], [29.24, 85.78, 57.58, 18.0]],
			"polegar": [38.42, 6.09, 34.86, -15.0, 85.0]}}


# --- G1: a pegada da leitura ------------------------------------------------------

## O rumo do antebraco na leitura (no espaco do aparelho): do cotovelo que o IK
## do braco acha para um punho em `punho`, ate o punho. E para la que `d` tem de
## apontar, e nao para a linha do ombro: o antebraco sai do cotovelo.
func rumo_leitura(punho: Vector3) -> Vector3:
	var cot := BracoVivo.cotovelo_entre(punho, ombro_fone, polo_fone)
	return (punho - cot).normalized()


## As metas da foto: as polpas dos quatro dedos na lateral esquerda, 1 mm para
## fora, a unha para fora; a primeira falange deitada nas costas; o polegar com a
## polpa na lateral direita (1 mm para fora) e a falange de cima encostada; e o
## rumo do antebraco. As alturas das pontas sao as da foto (41, 61, 74 e 90% da
## altura do aparelho); a do polegar e pedida abaixo, porque o ajuste o deixa
## 5 a 10 mm acima do pedido.
func metas_foto(pol_y: float, rumo: Vector3, pol_z: float = -0.0005) -> Array:
	var lado := Vector3(-1.0, 0.0, 0.0)
	var x := -M.x - 0.001
	return [
		{"tipo": &"polpa", "dedo": 0, "p": Vector3(x, 0.010, -0.0008), "n": lado, "peso_n": 0.6},
		{"tipo": &"polpa", "dedo": 1, "p": Vector3(x, -0.013, -0.0008), "n": lado, "peso_n": 0.6},
		{"tipo": &"polpa", "dedo": 2, "p": Vector3(x, -0.028, -0.0008), "n": lado, "peso_n": 0.6},
		{"tipo": &"polpa", "dedo": 3, "p": Vector3(x, -0.044, -0.0015), "n": lado,
			"peso": 0.7, "peso_n": 0.4},
		{"tipo": &"encosta", "dedo": 0, "falange": 0, "t": 0.8, "peso": 0.8},
		{"tipo": &"encosta", "dedo": 1, "falange": 0, "t": 0.7, "peso": 1.0},
		{"tipo": &"encosta", "dedo": 2, "falange": 0, "t": 0.7, "peso": 1.0},
		{"tipo": &"encosta", "dedo": 4, "falange": 0, "t": 0.55, "peso": 0.8},
		{"tipo": &"polpa", "dedo": 4, "p": Vector3(M.x + 0.001, pol_y, pol_z),
			"n": Vector3(1.0, 0.0, 0.0), "peso": 0.8, "peso_n": 0.6},
		{"tipo": &"encosta", "dedo": 4, "falange": 1, "t": 0.5, "peso": 0.5},
		{"tipo": &"rumo", "d": rumo, "peso": 0.25},
	]


## Os chutes da foto: o do rascunho, a pegada do celular do jogo (copiada de
## `CelularNaMao.PEGADA_*`, que esta em obra de outra sessao), a mesma 20 mm
## abaixo, e sorteios em volta do rascunho.
func chutes_foto(n_sorteio: int) -> Array:
	var jogo := {"o": Vector3(-0.0171, -0.0119, -0.0224), "d": Vector3(-0.5032, 0.8579, 0.1039),
		"dorso": Vector3(0.3995, 0.3376, -0.8523),
		"pose": {"dedos": [[1.45, 49.25, 67.29, -18.0], [20.62, 91.75, 66.48, -3.18],
			[41.14, 88.27, 63.25, 18.0], [95.0, 60.43, 40.01, -13.22]],
			"polegar": [44.94, 12.14, -43.6, 0.96, 75.68]}}
	var jogo_baixo := jogo.duplicate(true)
	jogo_baixo["o"] = (jogo["o"] as Vector3) + Vector3(0.0, -0.020, 0.0)
	var rasc := chute_foto_rascunho()
	var out := [rasc, jogo, jogo_baixo,
		{"o": Vector3(0.006, -0.040, -0.018), "d": Vector3(-0.6, 0.75, -0.1),
			"dorso": Vector3(0.2, 0.0, -1.0),
			"pose": {"dedos": [[10, 40, 30, 0], [20, 50, 38, 0], [28, 52, 40, 0], [45, 55, 35, 0]],
				"polegar": [64, 22, 36, 0, 4]}}]
	for i in n_sorteio:
		out.append(sortear_em_volta(rasc if i % 2 == 0 else jogo_baixo, 0.008, 14.0, 18.0))
	return out


func sortear_em_volta(p: Dictionary, mexe_o: float, mexe_giro: float, mexe_pose: float) -> Dictionary:
	var eixo := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	if eixo.length() < 0.01:
		eixo = Vector3.UP
	var giro := Basis(eixo.normalized(), deg_to_rad(_rng.randf_range(-mexe_giro, mexe_giro)))
	var dedos := []
	for i in 4:
		var f := []
		for j in 4:
			f.append(float(p["pose"]["dedos"][i][j]) + _rng.randf_range(-mexe_pose, mexe_pose))
		dedos.append(f)
	var pol := []
	for j in 5:
		pol.append(float(p["pose"]["polegar"][j]) + _rng.randf_range(-mexe_pose, mexe_pose))
	return {"o": (p["o"] as Vector3) + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1),
		_rng.randf_range(-1, 1)) * mexe_o, "d": giro * (p["d"] as Vector3),
		"dorso": giro * (p["dorso"] as Vector3), "pose": {"dedos": dedos, "polegar": pol}}


## Nota de uma pegada da leitura (menor e melhor): o custo do ajuste, esfera
## dentro, dedo sobre a tela, tela tapada acima de 5%, polegar longe do terco de
## baixo, e pulso dobrado demais.
func nota_foto(p: Dictionary, aj: Ajuste, alvo_y: float) -> Dictionary:
	var med := aj.medir(p)
	var e := MaoPosada.esqueleto(p["o"], p["d"], p["dorso"], p["pose"], true)
	var sobre := _sobre_a_tela(e)
	var caps := _dentro_por_capsula(e)
	var pp: Vector3 = MaoPosada.polpa(e, 4)["centro"]
	var pu := pulso(p, ombro_fone, polo_fone)
	var tap := tela_tapada(e, olho_fone)
	var dentro_caps := 0.0
	for v: float in caps:
		dentro_caps += maxf(v - 0.3, 0.0)
	var nota := float(med["custo"]) + float(med["dentro"]) * 60.0 - float(med["pior_mm"]) * 400.0 \
		+ dentro_caps * 300.0 + float(sobre.max()) * 150.0 \
		+ maxf(float(tap["total"]) - 5.0, 0.0) * 60.0 + absf(pp.y - alvo_y) * 1000.0 * 8.0 \
		+ maxf(absf(float(pu["extensao"])) - 40.0, 0.0) * 6.0 + maxf(absf(float(pu["desvio"])) - 20.0, 0.0) * 6.0
	return {"nota": nota, "dentro": med["dentro"], "pior": med["pior_mm"], "sobre": sobre.max(),
		"tapada": tap["total"], "pol_y": pp.y * 1000.0, "ext": pu["extensao"], "desvio": pu["desvio"],
		"caps": caps.max(), "custo": med["custo"]}


## Resolve a pegada da leitura. Varre a altura pedida ao polegar e fica com a de
## melhor nota; o rumo e recontado do punho achado (duas voltas).
func resolver_foto() -> Dictionary:
	var alvo_y := -0.022
	var rumo := rumo_leitura(MaoPosada.punho_de(chute_foto_rascunho()["o"],
		chute_foto_rascunho()["d"], chute_foto_rascunho()["dorso"]))
	var melhor := {}
	var nota_m := INF
	var chutes := chutes_foto(20)
	for volta in 2:
		for pedido: float in [-0.030, -0.036, -0.042]:
			var aj := Ajuste.new(M, Iphone4S.RAIO_CANTO, true)
			aj.metas = metas_foto(pedido, rumo)
			aj.tela_livre = true
			for i in chutes.size():
				var p := aj.resolver(chutes[i], 260)
				var n := nota_foto(p, aj, alvo_y)
				if float(n["nota"]) < nota_m:
					nota_m = n["nota"]
					melhor = p
					print("[foto] volta %d pedido %.0f chute %d: nota %.0f dentro %d pior %.2f caps %.2f sobre %.1f tapada %.1f%% pol_y %.1f ext %.0f desvio %.0f" % [
						volta, pedido * 1000.0, i, n["nota"], n["dentro"], n["pior"], n["caps"], n["sobre"],
						n["tapada"], n["pol_y"], n["ext"], n["desvio"]])
		rumo = rumo_leitura(MaoPosada.punho_de(melhor["o"], melhor["d"], melhor["dorso"]))
		chutes = [melhor]
		for i in 10:
			chutes.append(sortear_em_volta(melhor, 0.004, 8.0, 10.0))
	medir("LEITURA", melhor, {"olho": olho_fone, "metas": metas_foto(-0.036, rumo)})
	print(texto("LEITURA", melhor))
	return melhor


# --- stubs das outras etapas (preenchidas adiante) ----------------------------------

func resolver_toque() -> void:
	pass


func resolver_chao() -> void:
	pass


func checar_troca() -> void:
	pass


func medir_arquivo() -> void:
	pass


func fotos(_pasta: String) -> void:
	pass

