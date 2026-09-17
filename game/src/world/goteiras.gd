## Goteira na borda de toldo e marquise: a parte "goteira" do criterio A18 do
## PLANO_AAA_4K.
##
## Onde estao as bordas
## --------------------
## Toldo e marquise sao malha solta do chunk, sem colisao e sem no proprio — um
## raio nao os acha. A malha de CPU e jogada fora depois de ir para a GPU, e ler
## de volta de la trava o quadro. Entao `analisar` refaz o chunk pelo
## `ChunkBuilder.construir`, que e deterministico e roda fora da thread
## principal, e le as faces viradas para BAIXO entre 1,9 e 5,2 m: o forro de
## toda laje que fica sobre a calcada.
##
## Das faces sai a borda: aresta que so um triangulo virado para baixo usa. Ela
## pinga se:
##   - a laje tem fundo (`FUNDO_MINIMO`) — batente de janela nao e marquise;
##   - nao ha outra laje por cima dela (a haste do toldo esta sob a lona);
##   - do lado de fora nao ha predio (a aresta encostada na fachada nao pinga).
##
## As mesmas lajes respondem `coberto()`: e por elas que o jogador e a lente da
## camera sabem que estao debaixo de um toldo que a fisica nao ve.
class_name Goteiras
extends GPUParticles3D

const TAM := 32.0
const FAIXA_MIN := 1.9
const FAIXA_MAX := 5.2
const NORMAL_BAIXO := -0.8
## Profundidade minima da laje medida a partir da borda, em metros.
const FUNDO_MINIMO := 0.3
## Distancia entre dois pontos de pingo ao longo da borda.
const ESPACO := 0.24
## A gota nasce um pouco para fora da borda, senao o remate do toldo a esconde.
const EMPURRA := 0.05
## Duas bordas mais perto que isto no plano sao a mesma queda (lona e remate):
## fica a de baixo.
const MESMA_QUEDA := 0.12
const MAX_PONTOS := 600
## Superficies que nao entram. Copa de arvore tambem e face virada para baixo, e
## na primeira analise era a maior parte dos pontos (a planta do chunk 0,0 tinha
## um anel de goteira em volta de cada arvore da calcada). Arvore pinga por
## baixo da copa inteira, nao na borda: goteira de borda nao e o desenho dela.
const FORA := ["folha", "arbusto", "flor", "casca", "mato", "grama"]
## Pingos por ponto por segundo, com chuva cheia.
const POR_SEGUNDO := 1.3
## Altura tipica da queda. A gota que passa do chao e escondida pela
## profundidade.
const QUEDA := 2.7
const ALCANCE := 34.0

var pontos := PackedVector3Array()

## `--depurar-goteiras`: pingo grande e vermelho, aceso. Separa "a goteira nao
## existe" de "a goteira existe e nao aparece", que a olho sao a mesma foto.
static var _depurar: int = -1


## Roda em thread de trabalho: nao toca em no nem em recurso de cena.
##
## Devolve `pontos` (onde pinga) e `lajes` (triangulos virados para baixo, em
## XZ, com a altura), tudo no espaco do chunk.
static func analisar(cx: int, cz: int) -> Dictionary:
	var dados := ChunkBuilder.construir(cx, cz)
	var tris: Array[Dictionary] = []
	var sup: Dictionary = dados["superficies"]
	for mat: StringName in sup:
		if _de_planta(String(mat)):
			continue
		var d: Dictionary = sup[mat]
		var v: PackedVector3Array = d["v"]
		var n: PackedVector3Array = d["n"]
		var ix: PackedInt32Array = d["i"]
		var t := 0
		while t < ix.size():
			var i0 := ix[t]
			if n[i0].y <= NORMAL_BAIXO:
				var a := v[i0]
				var b := v[ix[t + 1]]
				var c := v[ix[t + 2]]
				var y := (a.y + b.y + c.y) / 3.0
				if y >= FAIXA_MIN and y <= FAIXA_MAX:
					tris.append({"a": a, "b": b, "c": c, "y": y})
			t += 3

	# Aresta de borda: usada por um triangulo so. Chave pelo centimetro.
	var uso := {}
	for k in tris.size():
		var tri: Dictionary = tris[k]
		for par: Array in [[tri["a"], tri["b"]], [tri["b"], tri["c"]], [tri["c"], tri["a"]]]:
			var chave := _chave(par[0], par[1])
			uso[chave] = int(uso.get(chave, 0)) + 1

	var caixas: Array = dados["colisao"]
	var brutos: Array[Vector3] = []
	for k in tris.size():
		var tri: Dictionary = tris[k]
		var vs: Array[Vector3] = [tri["a"], tri["b"], tri["c"]]
		for e in 3:
			var p0 := vs[e]
			var p1 := vs[(e + 1) % 3]
			var oposto := vs[(e + 2) % 3]
			if int(uso[_chave(p0, p1)]) != 1:
				continue
			var ao_longo := Vector2(p1.x - p0.x, p1.z - p0.z)
			var comprimento := ao_longo.length()
			if comprimento < 0.2:
				continue
			ao_longo /= comprimento
			var fora := Vector2(-ao_longo.y, ao_longo.x)
			var meio := (p0 + p1) * 0.5
			var para_dentro := Vector2(oposto.x - meio.x, oposto.z - meio.z)
			if fora.dot(para_dentro) > 0.0:
				fora = -fora
			if not _tem_fundo(tris, k, meio, fora):
				continue
			var y := minf(p0.y, p1.y)
			var teste := Vector3(meio.x + fora.x * 0.15, y - 0.15, meio.z + fora.y * 0.15)
			if _dentro_de_caixa(caixas, teste):
				continue
			var passos := maxi(1, int(comprimento / ESPACO))
			for s in passos:
				var f := (float(s) + 0.5) / float(passos)
				var p := p0.lerp(p1, f)
				var q := Vector3(p.x + fora.x * EMPURRA, p.y - 0.01, p.z + fora.y * EMPURRA)
				if _sob_laje(tris, q):
					continue
				brutos.append(q)

	# Lona e remate do toldo caem no mesmo lugar: fica o ponto mais baixo.
	brutos.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	var pontos := PackedVector3Array()
	for p: Vector3 in brutos:
		var repetido := false
		for q: Vector3 in pontos:
			if absf(q.x - p.x) < MESMA_QUEDA and absf(q.z - p.z) < MESMA_QUEDA:
				repetido = true
				break
		if not repetido:
			pontos.append(p)
			if pontos.size() >= MAX_PONTOS:
				break

	var lajes: Array[Dictionary] = []
	for tri: Dictionary in tris:
		var a: Vector3 = tri["a"]
		var b: Vector3 = tri["b"]
		var c: Vector3 = tri["c"]
		lajes.append({
			"tri": PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]),
			"y": tri["y"],
		})
	return {"pontos": pontos, "lajes": lajes, "coord": Vector2i(cx, cz)}


static func _de_planta(nome: String) -> bool:
	for parte: String in FORA:
		if nome.contains(parte):
			return true
	return false


static func _chave(a: Vector3, b: Vector3) -> String:
	var ka := Vector3i((a * 100.0).round())
	var kb := Vector3i((b * 100.0).round())
	if ka.x > kb.x or (ka.x == kb.x and (ka.z > kb.z or (ka.z == kb.z and ka.y > kb.y))):
		var tmp := ka
		ka = kb
		kb = tmp
	return "%d,%d,%d|%d,%d,%d" % [ka.x, ka.y, ka.z, kb.x, kb.y, kb.z]


## A laje continua para dentro por pelo menos `FUNDO_MINIMO`?
##
## Mede andando para dentro a partir do meio da borda e perguntando se o ponto
## ainda esta sob algum triangulo da mesma altura. Laje subdividida conta como
## uma so.
static func _tem_fundo(tris: Array[Dictionary], k: int, meio: Vector3, fora: Vector2) -> bool:
	var y: float = tris[k]["y"]
	var alvo := Vector2(meio.x, meio.z) - fora * FUNDO_MINIMO
	for tri: Dictionary in tris:
		if absf(float(tri["y"]) - y) > 0.35:
			continue
		if _no_triangulo(alvo, tri["a"], tri["b"], tri["c"]):
			return true
	return false


## Ha laje ACIMA deste ponto? Entao a chuva nao chega aqui para pingar.
static func _sob_laje(tris: Array[Dictionary], p: Vector3) -> bool:
	var xz := Vector2(p.x, p.z)
	for tri: Dictionary in tris:
		if float(tri["y"]) <= p.y + 0.05:
			continue
		if _no_triangulo(xz, tri["a"], tri["b"], tri["c"]):
			return true
	return false


static func _no_triangulo(p: Vector2, a3: Vector3, b3: Vector3, c3: Vector3) -> bool:
	return Geometry2D.point_is_inside_triangle(p, Vector2(a3.x, a3.z),
		Vector2(b3.x, b3.z), Vector2(c3.x, c3.z))


static func _dentro_de_caixa(caixas: Array, p: Vector3) -> bool:
	for caixa: Dictionary in caixas:
		var tam: Vector3 = caixa["tamanho"]
		var local: Vector3 = p - (caixa["pos"] as Vector3)
		if caixa.has("giro"):
			local = Basis.from_euler(caixa["giro"]).inverse() * local
		var meia := tam * 0.5 + Vector3(0.02, 0.02, 0.02)
		if absf(local.x) <= meia.x and absf(local.y) <= meia.y and absf(local.z) <= meia.z:
			return true
	return false


## Monta o emissor com os pontos de um chunk. Os pontos estao no espaco do
## chunk, e o no e filho dele.
func montar(novos: PackedVector3Array) -> void:
	name = "Goteiras"
	pontos = novos
	add_to_group(&"goteiras")
	var img := Image.create(pontos.size(), 1, false, Image.FORMAT_RGBF)
	for i in pontos.size():
		var p := pontos[i]
		img.set_pixel(i, 0, Color(p.x, p.y, p.z))
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	proc.emission_point_texture = ImageTexture.create_from_image(img)
	proc.emission_point_count = pontos.size()
	proc.direction = Vector3.DOWN
	proc.spread = 2.0
	proc.initial_velocity_min = 0.2
	proc.initial_velocity_max = 0.6
	proc.gravity = Vector3(0.0, -9.8, 0.0)
	proc.scale_min = 0.7
	proc.scale_max = 1.2
	process_material = proc

	var vida := sqrt(2.0 * QUEDA / 9.8)
	lifetime = vida
	amount = clampi(int(pontos.size() * POR_SEGUNDO * vida) + 1, 1, 800)
	randomness = 1.0
	explosiveness = 0.0
	fixed_fps = 0
	interpolate = false
	local_coords = false
	visibility_aabb = _caixa()
	visibility_range_end = ALCANCE
	visibility_range_end_margin = 4.0
	visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	use_fixed_seed = true
	seed = 20260917

	if _depurar < 0:
		_depurar = 1 if OS.get_cmdline_user_args().has("--depurar-goteiras") else 0
	var quad := QuadMesh.new()
	# Gota em queda e um risco, nao um ponto: o rastro de uma gota caindo a
	# 5 m/s num obturador de 1/30. Com 1,5 cm e 42% de opacidade a goteira
	# existia e nao se via a 7 m, nem contra a vitrine acesa.
	quad.size = Vector2(0.022, 0.17)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.albedo_color = Color(0.86, 0.9, 0.95, 0.62)
	mat.roughness = 0.15
	mat.metallic_specular = 0.8
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.disable_receive_shadows = true
	if _depurar == 1:
		quad.size = Vector2(0.08, 0.3)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	quad.material = mat
	draw_pass_1 = quad
	emitting = false


## Liga, desliga e dosa pela chuva.
func chover(forca: float) -> void:
	var quer := forca > 0.05
	amount_ratio = clampf(forca, 0.0, 1.0)
	if quer != emitting:
		emitting = quer


func _caixa() -> AABB:
	if pontos.is_empty():
		return AABB()
	var caixa := AABB(pontos[0], Vector3.ZERO)
	for p: Vector3 in pontos:
		caixa = caixa.expand(p)
	caixa.position.y -= QUEDA + 0.5
	caixa.size.y += QUEDA + 0.5
	return caixa.grow(0.3)
