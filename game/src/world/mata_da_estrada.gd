## A mata da estrada da abertura: UMA mata, de perto ate o horizonte.
##
## Mata atlantica fechada de encosta, e so ela: uma especie de dossel (a copa
## cheia e escura, fuste alto e reto) em tres portes, as arvoretas da mesma
## especie embaixo, moita e samambaia no chao da mata, e capim na beira. A
## primeira versao misturava pinheiro, ipe florido, mangueira, sibipiruna,
## embauba, bambu e samambaiacu: lia como catalogo, e o fundo (de outra mistura)
## mudava de padrao quando a camera subia. Agora a arvore de perto e a do fundo
## sao a MESMA: `arvore_do_dossel`, e o impostor e ela fotografada.
##
## Perto (6 a 30 m): a arvore de esqueleto de verdade (KitEstrada.arvore e
## .conifera caem aqui, gastando do rng do trecho os sorteios da de caixa).
## Fundo (26 a 212 m): impostor (ver `impostor_arvore.gdshader` e
## `tests/assar_impostores.gd`), a arvore fotografada de 24 angulos, um
## quadrado por arvore, mais de duzentas por trecho.
##
## Nada aqui gasta o rng do trecho alem do que a de caixa gastava: a casa, a
## cerca e o vulto continuam onde a cena os pos. `--mata-caixa` volta as
## caixas (A/B).
class_name MataDaEstrada
extends RefCounted

const DIR := "res://assets/impostores/"
## A chave de `sup` que carrega os impostores (nome -> buffer da MultiMesh).
## Comeca com "@": o EstradaBuilder pula essas chaves ao montar malha.
const CHAVE := &"@impostores"

## O fundo: as fotos da arvore do dossel em quatro portes/sementes.
const MISTURA := {&"dossel_a": 1.0, &"dossel_b": 1.0, &"dossel_c": 1.0, &"dossel_d": 1.0}
## O andar do meio (sub-dossel): a arvoreta da mesma especie, 3 a 6 m, entre o
## sub-bosque de perto e o dossel. Sem ele a mata e um corredor de troncos com
## o teto la em cima e nada no meio.
const MISTURA_MEIO := {&"arvoreta_a": 1.0, &"arvoreta_b": 1.0}
const FAIXAS_MEIO: Array = [[10.0, 24.0, 3.6], [24.0, 42.0, 4.8]]

## A arvore do dossel: forma do angico (a arvore de dossel da mata: pernadas
## abertas, cacho miudo) com a copa mais larga e mais funda que a dele, que e a
## copa que fecha o teto. Altura em metros do menor ao maior porte.
const DOSSEL_ESPECIE := &"angico"
const DOSSEL_ALTO := Vector2(11.0, 19.0)
const DOSSEL_COPA := Vector3(0.44, 0.27, 0.44)
## O verde da mata: um so, com pouca variacao (a copa de perto e a foto do
## fundo tem de ler como a mesma floresta).
const DOSSEL_TINTA := Color(0.8, 0.9, 0.78)

## Faixas do fundo: [de, ate, passo]. O passo cresce com a distancia porque a
## area cresce e a nevoa come: o dossel fica fechado ate onde o plano aereo le,
## e o custo nao vai todo para a faixa que menos aparece.
const FAIXAS: Array = [[26.0, 60.0, 5.2], [60.0, 120.0, 6.4], [120.0, 212.0, 8.8]]

static var _meta: Dictionary = {}
static var _trava := Mutex.new()
static var _materiais: Dictionary = {}
static var _quad: QuadMesh


static func ativa() -> bool:
	return not OS.get_cmdline_user_args().has("--mata-caixa") and not _variantes().is_empty()


## As variantes assadas (impostores.json), lidas uma vez.
static func _variantes() -> Dictionary:
	_trava.lock()
	if _meta.is_empty():
		var f := FileAccess.open(DIR + "impostores.json", FileAccess.READ)
		if f != null:
			var j: Variant = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				for v: Dictionary in (j as Dictionary).get("variantes", []):
					_meta[StringName(v["nome"])] = v
	_trava.unlock()
	return _meta


## A arvore do dossel, de pe em `base`. `porte` 0..1 manda na altura; `jovem`
## e a arvoreta do sub-bosque (a mesma especie, 3 a 6 m). Todo sorteio sai de `r`.
## Devolve (altura, raio da copa, altura do pe da copa acima de `base`).
## `fina`: a copa fina de perto da ArvoreEsqueleto (balde @perto). Desligada na
## estrada: medido na bancada de lente parada (_tmp_gpu_estrada), custava 0,37 ms
## em 4K, e a copa da estrada fica de 6 a 19 m do chao, no escuro.
static func arvore_do_dossel(sup: Dictionary, base: Vector3, porte: float,
		r: RandomNumberGenerator, jovem: bool = false, fina: bool = false) -> Vector3:
	var altura := lerpf(3.0, 6.0, porte) if jovem else lerpf(DOSSEL_ALTO.x, DOSSEL_ALTO.y, porte)
	var raio := DOSSEL_COPA * altura * Vector3(r.randf_range(0.9, 1.1), r.randf_range(0.9, 1.1),
		r.randf_range(0.9, 1.1))
	var pe := base
	if jovem:
		raio *= 1.2
		# A arvoreta ramifica baixo (ainda nao subiu atras de luz): com o fuste da
		# adulta ela era um pirulito, bola de folha num cabo. O pe afunda no chao
		# e a copa desce, entre as moitas.
		pe.y -= altura * 0.3
	var tinta := DOSSEL_TINTA * Color(r.randf_range(0.95, 1.04), r.randf_range(0.97, 1.03), 1.0)
	var nada: Array[Dictionary] = []
	ArvoreEsqueleto._construir(sup, nada, pe, DOSSEL_ESPECIE, porte, r, altura, raio,
		r.randf_range(0.0, TAU), r.randf_range(-0.04, 0.04), tinta, 0.02, false, fina)
	var fuste := altura * 0.55 - (altura * 0.3 if jovem else 0.0)
	return Vector3(altura, raio.x, fuste)


## A arvore da beira (KitEstrada.arvore e .conifera, 6 a 30 m da pista): gasta do
## rng do trecho EXATAMENTE os sorteios da de caixa que ela substitui (a casa, a
## cerca e o vulto vem depois dele) e devolve o mesmo raio, que o `_mata` usa
## para espacar. `conifera` diz qual das duas de caixa esta sendo substituida.
static func da_beira(sup: Dictionary, base: Vector3, porte: float, rng: RandomNumberGenerator,
		conifera: bool) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng.state, roundi(base.x * 10.0), roundi(base.z * 10.0), 23])
	var raio_velho: float
	if conifera:
		raio_velho = lerpf(1.5, 2.4, porte)
		rng.randf_range(0.0, TAU)
		rng.randi()
		for i in 5:
			rng.randf_range(0.86, 1.1)
			rng.randf_range(0.0, 0.9)
	else:
		raio_velho = lerpf(1.8, 3.0, porte)
		rng.randf_range(0.0, TAU)
		rng.randf_range(-0.05, 0.05)
		rng.randi()
		rng.randf_range(0.0, TAU)
		var n := rng.randi_range(4, 6)
		for i in n:
			for k in 7:
				rng.randf()
	var dims := arvore_do_dossel(sup, base, clampf(porte + r.randf_range(-0.15, 0.15), 0.0, 1.0), r)
	# Cipo: pende de DENTRO da copa (o pe da copa e conhecido), nunca do ar.
	if r.randf() < CIPO_CHANCE and not EstradaBuilder._sem("cipo"):
		for _k in r.randi_range(1, 3):
			cipo(sup, base, dims, r)
	return raio_velho


## O cipo da mata: a liana que desce da copa ate perto do chao, com folha
## miuda (hera) na metade de baixo. Nasce dentro da copa: a ponta de cima fica a
## 40 % do raio do tronco para fora e um palmo ACIMA do pe da copa, onde o
## esqueleto sempre tem galho e cacho. O cipo antigo pendia do nada, a 4-6 m, e
## lia como madeira flutuando na beira da estrada. `--estrada-sem=cipo` tira (o
## sorteio e do rng proprio da arvore, entao nada mais muda de lugar).
const CIPO_CHANCE := 0.45


static func cipo(sup: Dictionary, base: Vector3, dims: Vector3, r: RandomNumberGenerator) -> void:
	var ob := Obra.new()
	var casca := ob.malha(KitEstrada.M_CASCA)
	var folha := ob.malha(Vegetacao.MAT)
	var az := r.randf() * TAU
	var fora := Vector3(cos(az), 0.0, sin(az))
	var topo := base + fora * dims.y * r.randf_range(0.25, 0.45) + Vector3(0.0, dims.z + dims.x * 0.08, 0.0)
	var fim_y := base.y + r.randf_range(0.9, 2.6)
	var queda := topo.y - fim_y
	# A liana desce em curva: afasta um pouco do tronco e volta, com barriga.
	var pts := PackedVector3Array()
	var raios := PackedFloat32Array()
	var lado := fora.rotated(Vector3.UP, PI * 0.5) * r.randf_range(-0.6, 0.6)
	for k in 7:
		var t := float(k) / 6.0
		pts.append(topo + Vector3(0.0, -queda * t, 0.0) + fora * sin(t * PI) * 0.5 + lado * t * t)
		raios.append(lerpf(0.035, 0.018, t))
	_tubo(casca, pts, raios, 5, Color(0.36, 0.3, 0.24), base.y, dims.x)
	var uv := Vegetacao.uv_de(Vegetacao.C_HERA)
	var tinta := DOSSEL_TINTA * r.randf_range(0.85, 1.0)
	for k in r.randi_range(4, 7):
		var t := r.randf_range(0.35, 1.0)
		var f := t * 6.0
		var i := mini(int(f), 5)
		var q := pts[i].lerp(pts[i + 1], f - float(i))
		var b := Basis(Vector3.UP, r.randf() * TAU)
		var larg := r.randf_range(0.35, 0.6)
		_pendurado(folha, q + Vector3(0.0, larg * 0.4, 0.0), b, larg, larg * 0.9, uv, q, tinta,
			base.y, dims.x)
	ob.despejar(sup)


## O fundo de um trecho: os impostores dos dois lados, de FAIXAS[0] a 212 m.
## Roda na thread da montagem.
static func fundo(sup: Dictionary, s0: float, trecho: float, indice: int, semente: int) -> void:
	var meta := _variantes()
	if meta.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash([semente, indice, &"mata_fundo"])
	var saida: Dictionary = sup.get(CHAVE, {})
	_faixas(saida, meta, MISTURA, FAIXAS, s0, trecho, r)
	_faixas(saida, meta, MISTURA_MEIO, FAIXAS_MEIO, s0, trecho, r)
	sup[CHAVE] = saida


static func _faixas(saida: Dictionary, meta: Dictionary, mistura: Dictionary, faixas: Array,
		s0: float, trecho: float, r: RandomNumberGenerator) -> void:
	var nomes: Array[StringName] = []
	var pesos := PackedFloat32Array()
	var total := 0.0
	for n: StringName in mistura:
		if meta.has(n):
			nomes.append(n)
			total += float(mistura[n])
			pesos.append(total)
	if nomes.is_empty():
		return
	for lado: float in [-1.0, 1.0]:
		for faixa: Array in faixas:
			var d0: float = faixa[0]
			var d1: float = faixa[1]
			var passo: float = faixa[2]
			# Grade com sorteio dentro da celula: cheia sem fileira.
			var ns := maxi(1, roundi(trecho / passo))
			var nd := maxi(1, roundi((d1 - d0) / passo))
			for i in ns:
				for j in nd:
					var s := s0 + (float(i) + r.randf()) * trecho / float(ns)
					var d := d0 + (float(j) + r.randf()) * (d1 - d0) / float(nd)
					# Clareira de vez em quando: o dossel de verdade tem buraco.
					if r.randf() < 0.06:
						continue
					var x := r.randf() * total
					var k := 0
					while k < pesos.size() - 1 and x > pesos[k]:
						k += 1
					var nome := nomes[k]
					var base := EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * (d * lado)
					base.y += EstradaBuilder.altura_lateral(d)
					_por(saida, nome, meta[nome], base, r)


## Uma arvore: transform 3x4 por linhas (centro da esfera, giro, raio) e a tinta.
static func _por(saida: Dictionary, nome: StringName, v: Dictionary, base: Vector3,
		r: RandomNumberGenerator) -> void:
	var escala := r.randf_range(0.82, 1.22)
	var giro := r.randf() * TAU
	var c: Array = v["centro"]
	var rot := Basis(Vector3.UP, giro)
	var centro := base + rot * (Vector3(float(c[0]), float(c[1]), float(c[2])) * escala)
	var b := rot.scaled(Vector3.ONE * float(v["raio"]) * escala)
	# Tinta: o verde de cada copa um pouco diferente do vizinho (mais escuro,
	# mais oliva, mais claro). Multiplica a foto.
	var tom := r.randf_range(0.82, 1.08)
	var oliva := r.randf_range(-0.05, 0.08)
	var buf: PackedFloat32Array = saida.get(nome, PackedFloat32Array())
	buf.append_array([b.x.x, b.y.x, b.z.x, centro.x,
		b.x.y, b.y.y, b.z.y, centro.y,
		b.x.z, b.y.z, b.z.z, centro.z,
		tom * (1.0 + oliva), tom, tom * (1.0 - oliva * 1.5), 0.0])
	saida[nome] = buf


## Os nos dos impostores de um trecho (quadro principal).
static func pendurar(no: Node3D, sup: Dictionary) -> int:
	var dados: Dictionary = sup.get(CHAVE, {})
	var n_total := 0
	for nome: StringName in dados:
		var buf: PackedFloat32Array = dados[nome]
		var n := buf.size() / 16
		if n == 0:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _quadrado()
		mm.instance_count = n
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "impostor_" + String(nome)
		mmi.multimesh = mm
		mmi.material_override = _material(nome)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(mmi)
		n_total += n
	return n_total * 2


## O quadrado de lado 2 (vertices em +-1). A caixa de corte e um cubo: o
## shader gira o quadrado para a camera, e a caixa plana da malha cortaria a
## arvore vista de lado.
static func _quadrado() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2.0, 2.0)
		_quad.custom_aabb = AABB(Vector3(-1.2, -1.2, -1.2), Vector3(2.4, 2.4, 2.4))
	return _quad


static func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/impostor_arvore.gdshader")
	m.set_shader_parameter(&"atlas_cor", load(DIR + String(nome) + "_cor.png"))
	m.set_shader_parameter(&"atlas_nrm", load(DIR + String(nome) + "_nrm.png"))
	_materiais[nome] = m
	return m


# --- beira --------------------------------------------------------------------

## O capim da beira, de BEIRA_DE a BEIRA_ATE metros do eixo: o matagal.
##
## A beira tinha cinco tufos por metro e oitenta de cada lado, de 45 cm a 1 m, na
## celula de 256 px do `mato_atlas`: de dentro do carro, barro vermelho com um
## tufo aqui e outro ali. Beira de estrada de terra em Minas e parede de capim:
## coloniao e braquiaria passando do joelho, capim-gordura com a pluma vinho,
## samambaia-do-campo nos barrancos, picao e assa-peixe. Ralo e baixo rente ao
## leito (o farol e o vulto na beira precisam dele baixo), cheio e alto a partir
## de meio metro de barranco.
##
## Geometria de verdade no balde do material (e nao MultiMesh): a clareira da
## batida corta `vegetacao` e `plantas` no shader, e o carro batido nao fica
## com capim atravessando a cabine.
const BEIRA_DE := KitEstrada.MEIA_PISTA + 0.45
const BEIRA_ATE := 8.0
## Touceiras por metro quadrado, na borda de dentro e no meio da faixa.
const BEIRA_DENSA := 3.2
const BEIRA_RALA := 0.9
## Ate onde o capim da beira e desenhado, da lente ao centro do trecho.
const BEIRA_ALCANCE := 60.0
## Ate onde a beira e rocada (capim baixo), em metros do eixo.
const ROCADO := 6.3


static func beira(sup: Dictionary, s0: float, trecho: float, indice: int, semente: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([semente, indice, &"beira"])
	var casas: Array = sup.get(&"@casas", [])
	var muros: Array = sup.get(&"@muros", [])
	var ob := Obra.new()
	var veg := ob.malha(Vegetacao.MAT)
	var pl := ob.malha(Plantas.MAT)
	# Onde a faixa e alta e onde e rala anda em manchas ao longo da estrada
	# (rocado ha pouco, ou nao), e nao igual o trecho inteiro.
	var fase := r.randf() * 100.0
	for lado: float in [-1.0, 1.0]:
		var area := trecho * (BEIRA_ATE - BEIRA_DE)
		var n := roundi(area * BEIRA_DENSA)
		for _i in n:
			var s := s0 + r.randf() * trecho
			var u := r.randf()
			var d := lerpf(BEIRA_DE, BEIRA_ATE, u)
			# Rala na borda do leito: a densidade sobe no primeiro meio metro.
			var dens := smoothstep(0.0, 0.18, u)
			var mancha := 0.55 + 0.45 * sin(s * 0.21 + fase + lado * 2.0) * sin(s * 0.057 + fase)
			if r.randf() > lerpf(BEIRA_RALA / BEIRA_DENSA, 1.0, dens) * clampf(mancha + 0.35, 0.2, 1.0):
				continue
			var p := EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * (d * lado)
			p.y += EstradaBuilder.altura_lateral(d)
			if _perto(p, casas, 4.0) or _no_muro(p, muros):
				continue
			# Altura: a faixa ROCADA (ate ROCADO do eixo) e capim baixo, como a
			# prefeitura deixa a beira; o capim alto comeca atras dela. Nao e so
			# realismo: as lentes da passagem e do bicho ficam a 5,6 m do eixo, a
			# 1,05 e 1,5 m do chao, e no capim alto o carro sumia atras do mato.
			var alto := lerpf(0.35, 1.0, dens) * lerpf(0.7, 1.15, mancha)
			if d < ROCADO:
				alto = r.randf_range(0.2, 0.5) * lerpf(0.8, 1.1, mancha)
			var giro := r.randf() * TAU
			var tinta := Color.WHITE.lerp(Color(0.82, 0.86, 0.7), r.randf())
			var x := r.randf()
			if x < 0.38:
				Plantas.em_pe(veg, p, alto * r.randf_range(0.9, 1.35), alto * r.randf_range(0.9, 1.2),
					Vegetacao.C_TOUCEIRA, giro, 3, tinta)
			elif x < 0.58:
				Plantas.em_pe(pl, p, alto * r.randf_range(0.7, 1.05), alto * r.randf_range(0.9, 1.3),
					Plantas.C_CAPIM_GORDURA, giro, 2, tinta)
			elif x < 0.74:
				Plantas.em_pe(pl, p, alto * r.randf_range(0.6, 0.95), alto * r.randf_range(1.0, 1.4),
					Plantas.C_SAMAMBAIA, giro, 3, tinta)
			elif x < 0.92:
				Plantas.em_pe(pl, p, alto * r.randf_range(0.4, 0.7), alto * r.randf_range(0.7, 1.0),
					Plantas.C_MATO, giro, 2, tinta)
			elif dens > 0.8:
				# Assa-peixe e moita-de-beira: o arbusto baixo que escapa do rocado.
				Vegetacao.arbusto(ob, p, r.randf_range(0.8, 1.4), Vegetacao.C_ARBUSTO, r)
	# Balde proprio (`vegetacao@beira`, `plantas@beira`): o EstradaBuilder corta a
	# BEIRA_ALCANCE. Na chuva da noite capim alem disso nao se ve, e o cartao de
	# capim rente a lente e o que mais custa (0,39 ms em 4K na bancada parada).
	var local := {}
	ob.despejar(local)
	for k: StringName in local:
		sup[StringName(String(k) + "@beira")] = local[k]


# --- sub-bosque ---------------------------------------------------------------

## O andar de baixo da mata, de SUB_DE a SUB_ATE metros do eixo.
##
## Era feito de caixas de folha (`_sub_bosque` e a "parede" do `_mata`): de dia
## a caixa recortada lia como cubo, e a noite, no farol, como um bloco escuro
## com textura. Aqui e o andar de baixo da MESMA mata: a arvoreta do dossel,
## a moita com a folha dele, a samambaia e a taioba do chao umido. Perto da
## pista e rasteiro e miudo; no fundo, alto e fechado: e o que tapa o vao entre
## o capim e o dossel.
##
## Grade em (s, d) com sorteio dentro da celula: cheio sem fileira. Desvia do
## tronco das arvores da beira (`@arvores`, do `_mata`) e da casa do trecho
## (`@casas`, do `_detalhes`). rng proprio.
const SUB_DE := 7.0
const SUB_ATE := 30.0
const SUB_PASSO := 2.4
## Teto por trecho do que e caro (arvore de esqueleto e taquara).
const ARVORETAS_MAX := 6


static func sub_bosque(sup: Dictionary, s0: float, trecho: float, indice: int, semente: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([semente, indice, &"sub_bosque"])
	var arvores: Array = sup.get(&"@arvores", [])
	var casas: Array = sup.get(&"@casas", [])
	var ob := Obra.new()
	var ns := maxi(1, roundi(trecho / SUB_PASSO))
	var nd := maxi(1, roundi((SUB_ATE - SUB_DE) / SUB_PASSO))
	var arvoretas := 0
	for lado: float in [-1.0, 1.0]:
		for i in ns:
			for j in nd:
				var s := s0 + (float(i) + r.randf()) * trecho / float(ns)
				var t := (float(j) + r.randf()) / float(nd)
				var d := lerpf(SUB_DE, SUB_ATE, t)
				var p := EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * (d * lado)
				p.y += EstradaBuilder.altura_lateral(d)
				var x := r.randf()
				var giro := r.randf() * TAU
				# O fundo e mais escuro e mais azulado: menos luz embaixo do dossel.
				var tinta := Color.WHITE.lerp(Color(0.74, 0.8, 0.72), clampf(t * 0.8
					+ r.randf_range(-0.1, 0.1), 0.0, 1.0))
				if _perto(p, arvores, 0.9) or _perto(p, casas, 6.5):
					continue
				# Uma mata so: a arvoreta do dossel (a mesma especie, jovem), a moita
				# com a folha dele, a samambaia e a taioba do chao umido. Perto da
				# pista e rasteiro; no fundo, alto e fechado.
				if d < 13.0:
					if x < 0.36:
						Vegetacao.arbusto(ob, p, r.randf_range(1.0, 2.0),
							Vegetacao.C_MIUDO if r.randf() < 0.75 else Vegetacao.C_ARBUSTO, r)
					elif x < 0.60:
						Plantas.em_pe(ob.malha(Plantas.MAT), p, r.randf_range(0.8, 1.4),
							r.randf_range(1.3, 2.1), Plantas.C_SAMAMBAIA, giro, 3, tinta)
					elif x < 0.66:
						Plantas.em_pe(ob.malha(Plantas.MAT), p, r.randf_range(0.6, 1.0),
							r.randf_range(0.8, 1.2), Plantas.C_TAIOBA, giro, 3, tinta)
					elif x < 0.70 and arvoretas < ARVORETAS_MAX:
						arvoretas += 1
						arvore_do_dossel(sup, p, r.randf_range(0.0, 0.6), r, true)
				else:
					if x < 0.40:
						Vegetacao.arbusto(ob, p, r.randf_range(1.8, 3.0),
							Vegetacao.C_MIUDO if r.randf() < 0.75 else Vegetacao.C_ARBUSTO, r)
					elif x < 0.58:
						Plantas.em_pe(ob.malha(Plantas.MAT), p, r.randf_range(1.0, 1.6),
							r.randf_range(1.5, 2.3), Plantas.C_SAMAMBAIA, giro, 3, tinta)
					elif x < 0.70 and arvoretas < ARVORETAS_MAX:
						arvoretas += 1
						arvore_do_dossel(sup, p, r.randf_range(0.3, 1.0), r, true)
	ob.despejar(sup)


## O capim nao atravessa a pedra: fora de 35 cm da linha do muro baixo.
static func _no_muro(p: Vector3, muros: Array) -> bool:
	for m: Array in muros:
		var a := Vector2((m[0] as Vector3).x, (m[0] as Vector3).z)
		var b := Vector2((m[1] as Vector3).x, (m[1] as Vector3).z)
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
		if q.distance_squared_to(Vector2(p.x, p.z)) < 0.35 * 0.35:
			return true
	return false


static func _perto(p: Vector3, pontos: Array, raio: float) -> bool:
	for q: Vector3 in pontos:
		if Vector2(p.x - q.x, p.z - q.z).length_squared() < raio * raio:
			return true
	return false


## Samambaiacu (Cyathea): o feto arboreo da mata atlantica mineira. Tronco fino
## e escuro, coberto das bases das folhas velhas, e no topo a coroa de frondes
## que sobem e caem em arco. A celula da samambaia do atlas `plantas` e
## exatamente esse arco visto de lado, entao a coroa e ela pendurada do topo,
## em estrela, mais uma camada menor e mais alta (as frondes novas).
static func samambaiacu(ob: Obra, base: Vector3, alto: float, r: RandomNumberGenerator) -> void:
	var casca := ob.malha(KitEstrada.M_CASCA)
	var folha := ob.malha(Plantas.MAT)
	var torto := Vector3(r.randf_range(-1.0, 1.0), 0.0, r.randf_range(-1.0, 1.0)) * alto * 0.06
	var pts := PackedVector3Array([base - Vector3(0.0, 0.15, 0.0),
		base + Vector3(0.0, alto * 0.5, 0.0) + torto * 0.6, base + Vector3(0.0, alto, 0.0) + torto])
	var raios := PackedFloat32Array([0.13, 0.1, 0.085])
	_tubo(casca, pts, raios, 6, Color(0.42, 0.36, 0.3), base.y, alto)
	var topo := pts[2]
	var uv := Vegetacao.uv_de(Plantas.C_SAMAMBAIA)
	var tinta := Color.WHITE.lerp(Color(0.8, 0.9, 0.7), r.randf())
	var larg := alto * r.randf_range(0.75, 0.95) + 0.9
	var cai := larg * 0.62
	var fase := r.randf() * PI
	for k in 3:
		var b := Basis(Vector3.UP, fase + PI / 3.0 * float(k))
		_pendurado(folha, topo + Vector3(0.0, 0.18, 0.0), b, larg, cai, uv, topo, tinta,
			base.y, alto)
	for k in 2:
		var b := Basis(Vector3.UP, fase + PI * 0.25 + PI * 0.5 * float(k))
		_pendurado(folha, topo + Vector3(0.0, 0.42, 0.0), b, larg * 0.6, cai * 0.55, uv, topo,
			tinta * Color(1.08, 1.1, 1.0), base.y, alto)


## Cartao pendurado pelo topo: a borda de cima centrada em `topo`, `larg` de
## lado e `cai` para baixo, as duas faces. Normal esferica em volta de `centro`
## (a coroa acende como volume) e a rigidez ao vento crescendo para as pontas.
static func _pendurado(m: ParedeVazada.Malha, topo: Vector3, b: Basis, larg: float, cai: float,
		uv: Rect2, centro: Vector3, tinta: Color, y_base: float, alto: float) -> void:
	var ex := b.x * larg * 0.5
	var cantos: Array[Vector3] = [topo - ex - Vector3(0.0, cai, 0.0), topo + ex - Vector3(0.0, cai, 0.0),
		topo + ex, topo - ex]
	var uvs: Array[Vector2] = [Vector2(uv.position.x, uv.end.y), uv.end,
		Vector2(uv.end.x, uv.position.y), uv.position]
	var face := b.z
	var ids: Array[int] = []
	for i in 4:
		var q := cantos[i]
		var nrm := (q - centro + Vector3(0.0, cai * 0.6, 0.0)).normalized()
		var ponta := clampf(absf((q - topo).dot(b.x)) / (larg * 0.5), 0.0, 1.0)
		var luz := lerpf(0.62, 1.0, clampf((q.y - y_base) / maxf(alto + 0.5, 0.1), 0.0, 1.0))
		ids.append(m.vertice(q, nrm, uvs[i], Vector2.ZERO,
			Color(tinta.r * luz, tinta.g * luz, tinta.b * luz, lerpf(0.25, 0.9, ponta))))
	m.quad(ids[0], ids[1], ids[2], ids[3], face)
	m.quad(ids[0], ids[1], ids[2], ids[3], -face)


## Tubo de `lados` faces por uma linha de pontos, normal radial, sem tampa.
static func _tubo(m: ParedeVazada.Malha, pts: PackedVector3Array, raios: PackedFloat32Array,
		lados: int, cor: Color, y_base: float, alto: float) -> void:
	var aneis: Array = []
	var v_acum := 0.0
	for i in pts.size():
		var eixo := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.RIGHT if absf(eixo.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var ax := eixo.cross(ref).normalized()
		var az := eixo.cross(ax).normalized()
		if i > 0:
			v_acum += pts[i].distance_to(pts[i - 1])
		var anel: Array[int] = []
		var sobe := clampf((pts[i].y - y_base) / maxf(alto, 0.1), 0.0, 1.0)
		for k in lados + 1:
			var a := TAU * float(k) / float(lados)
			var n := ax * cos(a) + az * sin(a)
			anel.append(m.vertice(pts[i] + n * raios[i], n,
				Vector2(float(k) / float(lados) * raios[i] * 6.0, v_acum * 0.9), Vector2.ZERO,
				Color(cor.r, cor.g, cor.b, KitEstrada.CEDE_TRONCO * sobe * sobe)))
		aneis.append(anel)
	for i in pts.size() - 1:
		var a0: Array[int] = aneis[i]
		var a1: Array[int] = aneis[i + 1]
		for k in lados:
			var fora := (m.v[a0[k]] + m.v[a0[k + 1]]) * 0.5 - pts[i]
			m.quad(a0[k], a0[k + 1], a1[k + 1], a1[k], fora)


# --- a toca do bicho ------------------------------------------------------------

## A moldura do plano do bicho (EstradaBuilder.spawn_toca): o que esta em volta
## do olho de quem espia da mata. Era capim de 256 px pendurado de cabeca para
## baixo (lia como varetas em V no alto do quadro) e duas caixas de tronco.
## Agora: ramos de folha que descem do alto (a copa da arvoreta em cima dele),
## samambaia e taioba subindo por baixo, mais perto da lente que a copa, e dois
## troncos de verdade com casca nas bordas, que varrem o quadro quando a cabeca
## vira. Tudo nas BORDAS do quadro (ver o comentario de `spawn_toca`).
static func toca(sup: Dictionary, olho: Vector3, mira: Vector3, transversal: Vector3,
		altura_olho: float, r: RandomNumberGenerator) -> void:
	var ob := Obra.new()
	var veg := ob.malha(Vegetacao.MAT)
	var pl := ob.malha(Plantas.MAT)
	var y_chao := olho.y - altura_olho
	# O alto: ramos pendurados, em arco de -47 a 47 graus, a 1 a 1,6 m.
	for i in 11:
		var ang := lerpf(-0.82, 0.82, float(i) / 10.0) + r.randf_range(-0.08, 0.08)
		var dist := r.randf_range(1.0, 1.6)
		var onde := olho + (mira * cos(ang) + transversal * sin(ang)) * dist
		onde.y += r.randf_range(0.5, 0.85)
		var b := Basis(Vector3.UP, r.randf() * TAU)
		var larg := r.randf_range(0.7, 1.1)
		var cai := r.randf_range(0.45, 0.75)
		var cel := Vegetacao.C_ARBUSTO if r.randf() < 0.6 else Vegetacao.C_MATA
		var tinta := Color(0.62, 0.7, 0.52).lerp(Color(0.34, 0.4, 0.3), r.randf_range(0.0, 0.7))
		_pendurado(veg, onde, b, larg, cai, Vegetacao.uv_de(cel), onde + Vector3(0.0, 0.4, 0.0),
			tinta, y_chao, altura_olho + 1.5)
		# Um segundo cartao cruzado: de perfil o primeiro some.
		_pendurado(veg, onde, b.rotated(Vector3.UP, PI * 0.5), larg * 0.8, cai * 0.9,
			Vegetacao.uv_de(cel), onde + Vector3(0.0, 0.4, 0.0), tinta, y_chao, altura_olho + 1.5)
	# Frondes de samambaia caindo entre os ramos.
	for i in 4:
		var ang := lerpf(-0.7, 0.7, float(i) / 3.0) + r.randf_range(-0.1, 0.1)
		var onde := olho + (mira * cos(ang) + transversal * sin(ang)) * r.randf_range(1.1, 1.5)
		onde.y += r.randf_range(0.55, 0.8)
		_pendurado(pl, onde, Basis(Vector3.UP, r.randf() * TAU), r.randf_range(0.9, 1.2),
			r.randf_range(0.5, 0.7), Vegetacao.uv_de(Plantas.C_SAMAMBAIA), onde,
			Color(0.55, 0.62, 0.46), y_chao, altura_olho + 1.5)
	# O pe: samambaia, taioba e capim, subindo por baixo, mais perto da lente.
	for i in 9:
		var ang := lerpf(-0.75, 0.75, float(i) / 8.0) + r.randf_range(-0.1, 0.1)
		var dist := r.randf_range(0.85, 1.35)
		var onde := olho + (mira * cos(ang) + transversal * sin(ang)) * dist
		onde.y = y_chao
		var cel := [Plantas.C_SAMAMBAIA, Plantas.C_SAMAMBAIA, Plantas.C_TAIOBA,
			Plantas.C_CAPIM_GORDURA][r.randi() % 4] as Vector2i
		var alto := altura_olho * r.randf_range(0.55, 0.85)
		Plantas.em_pe(pl, onde, alto, alto * r.randf_range(1.0, 1.4), cel, r.randf() * TAU, 3,
			Color(0.6, 0.66, 0.5).lerp(Color(0.3, 0.35, 0.26), r.randf_range(0.0, 0.6)))
	# Os dois troncos, a batente da janela (33 a 43 graus), com casca.
	for lado_t: float in [-1.0, 1.0]:
		var ang := lado_t * r.randf_range(0.58, 0.76)
		var dist := r.randf_range(1.9, 2.7)
		var pe := olho + (mira * cos(ang) + transversal * sin(ang)) * dist
		pe.y = y_chao
		var alt := altura_olho + r.randf_range(2.6, 3.8)
		var inclina := Vector3(r.randf_range(-1.0, 1.0), 0.0, r.randf_range(-1.0, 1.0)) * 0.12
		var raio := r.randf_range(0.09, 0.14)
		var pts := PackedVector3Array()
		var raios := PackedFloat32Array()
		for k in 5:
			var t := float(k) / 4.0
			pts.append(pe + Vector3(0.0, alt * t - (0.2 if k == 0 else 0.0), 0.0) + inclina * alt * t
				+ Vector3(sin(t * 5.0 + ang) , 0.0, cos(t * 4.0 + ang)) * 0.03)
			raios.append(raio * lerpf(1.15, 0.8, t))
		_tubo(ob.malha(KitEstrada.M_CASCA), pts, raios, 7, KitEstrada.CASCA_TOM, y_chao, alt)
	ob.despejar(sup)
