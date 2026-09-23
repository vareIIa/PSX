## O desnivel da calcada ao longo da fachada da loja, loja por loja.
##
##     godot --headless --path game --script res://tests/sonda_calcada_mercado.gd
##
## Por que existe
## -------------
## Na captura `a21_fachada` a loja assenta numa calcada que desce ao longo da
## propria fachada. O `PredioMercado._passeio` ja mede isso na montagem e da a
## cada boca a sua rampa, mas ninguem sabia QUANTO era o desnivel na pior loja
## da cidade — e sem esse numero nao se dimensiona embasamento nenhum. Numero
## antes de geometria (memoria "medir antes de mexer").
##
## O que mede, por loja: a altura da calcada em vinte pontos ao longo da
## fachada, em coordenada de planta, e reporta a queda entre o ponto mais alto e
## o mais baixo. Reporta tambem o degrau na soleira da porta e no portao, que
## sao os dois lugares onde o jogador atravessa.
##
## Nao falha: e regua, nao critério. Sai com 0 sempre, e imprime a lista das
## dez piores lojas para o plano decidir o que fazer.
extends SceneTree

## A superficie do passeio na frente da loja.
const PASSEIO: Array[StringName] = [&"calcada", &"paralelepipedo"]
## Onde amostrar, em Z de planta: um palmo a frente da fachada.
const Z_AMOSTRA := -0.3
const PONTOS := 20


func _initialize() -> void:
	process_frame.connect(_rodar, CONNECT_ONE_SHOT)


func _rodar() -> void:
	var CB: GDScript = load("res://src/world/chunk_builder.gd")
	var MB: GDScript = load("res://src/world/mercado_builder.gd")
	var largura: float = MB.LARGURA
	var piores: Array[Dictionary] = []
	var lojas := 0
	var soma := 0.0
	for cx in range(-12, 13):
		for cz in range(-12, 13):
			var tem := false
			for ponto: Dictionary in CB.pontos_de_interesse(cx, cz):
				if ponto.get("interior", &"") == &"mercado" and bool(ponto.get("mundo", false)):
					tem = true
			if not tem:
				continue
			var dados: Dictionary = CB.construir(cx, cz)
			var planta := Transform3D()
			var achou := false
			for prop: Dictionary in dados["props"]:
				if prop.get("tipo", "") == "interior_mundo" \
						and prop.get("interior", &"") == &"mercado":
					planta = prop["planta"]
					achou = true
			if not achou:
				continue
			lojas += 1
			var inv := planta.affine_inverse()
			var alturas := PackedFloat32Array()
			for k in PONTOS:
				var x := largura * float(k) / float(PONTOS - 1)
				alturas.append(_altura(dados["superficies"], inv,
					Vector2(x, Z_AMOSTRA)))
			var alto := -1000.0
			var baixo := 1000.0
			for y in alturas:
				if y > -900.0:
					alto = maxf(alto, y)
					baixo = minf(baixo, y)
			if alto < -900.0:
				continue
			soma += alto - baixo
			piores.append({
				"onde": Vector2i(cx, cz), "queda": alto - baixo,
				"porta": _altura(dados["superficies"], inv,
					Vector2(MB.CENTRO_PORTA, Z_AMOSTRA)),
				"portao": _altura(dados["superficies"], inv,
					Vector2(MB.EIXO_PORTAO, Z_AMOSTRA)),
			})
	piores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["queda"]) > float(b["queda"]))
	print("[calcada] lojas=%d media_queda=%.2f m" % [lojas,
		soma / maxf(1.0, float(lojas))])
	for k in mini(10, piores.size()):
		var p: Dictionary = piores[k]
		print("[calcada] chunk=%s queda=%.2f m porta=%+.2f portao=%+.2f" % [
			p["onde"], p["queda"], p["porta"], p["portao"]])
	quit(0)


## A altura do passeio no ponto `xz` de planta, ou -1000 se nao ha passeio ali.
##
## Amostra por triangulo: o passeio e uma malha deformada pelo relevo, entao nao
## ha grade de onde ler. Devolve o Y do triangulo que contem o ponto.
static func _altura(sup: Dictionary, inv: Transform3D, xz: Vector2) -> float:
	var melhor := -1000.0
	for nome: StringName in sup:
		if not PASSEIO.has(nome):
			continue
		var d: Dictionary = sup[nome]
		var vs: PackedVector3Array = d["v"]
		var idx: PackedInt32Array = d["i"]
		for t in range(0, idx.size(), 3):
			var a := inv * vs[idx[t]]
			var b := inv * vs[idx[t + 1]]
			var c := inv * vs[idx[t + 2]]
			var pa := Vector2(a.x, a.z)
			var pb := Vector2(b.x, b.z)
			var pc := Vector2(c.x, c.z)
			var area := (pb - pa).cross(pc - pa)
			if absf(area) < 1e-9:
				continue
			var u := (pb - xz).cross(pc - xz) / area
			var v := (pc - xz).cross(pa - xz) / area
			var w := 1.0 - u - v
			if u < -0.001 or v < -0.001 or w < -0.001:
				continue
			melhor = maxf(melhor, a.y * u + b.y * v + c.y * w)
	return melhor
