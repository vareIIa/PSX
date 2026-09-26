## A cabeca dos padres de fundo (romeiros, vigias, a roda em volta do carro):
## a mesma criatura do padre principal (`CabecaDoPadre`), variada por semente e
## barata o bastante para vinte ou trinta em cena.
##
## Por que existe
## --------------
## Os de fundo tinham a faixa (`RostoEnfaixado`); o pedido e "a cabeca real
## tambem". A `CabecaDoPadre` foi feita para UMA cabeca: cada uma monta os seus
## cinco materiais, a lingua anda num `_process` a cada quadro e o globo do olho
## tem 6 mil triangulos. Trinta assim sao 150 materiais e trinta processos
## mexendo em uniforme por quadro, para cabecas que, a 5 m, sao cem pixels.
## E trinta caras iguais leem como clone, e nao como gente que morreu.
##
## Como funciona
## -------------
## E uma `CabecaDoPadre` (quem pergunta `rosto is CabecaDoPadre` continua
## achando: `PadresNasJanelas.vestir_cabeca`, o cerco do capo), montada de
## outro jeito:
## - material e textura divididos. A pele sai de um punhado de materiais, um
##   por (tom, abertura da queixada); o olho, um por tom de olho; a boca, um so;
##   o ponto de longe, um por (forca, tamanho). A textura 4K e a mesma do
##   principal (o `load` e um so);
## - parada: sem `_process`. A lingua e a fala sao do principal; a boca fica na
##   abertura da semente, e o morph dela e escrito uma vez;
## - o globo do olho mais leve (24 x 32 em vez de 48 x 64): a meio metro, em 4K,
##   o contorno de 32 lados de um olho de 2,5 cm ainda e redondo;
## - a variacao e por fora, sem mexer no arquivo do principal: escala nao
##   uniforme do cranio (mais comprido, mais estreito), um giro de leve, cada
##   olho de um tamanho e numa altura, mais ou menos saltado e vesgo, o tom da
##   pele e da olheira, o olho leitoso ou injetado, a boca mais ou menos caida.
##   E a mesma criatura, e nao outro monstro.
##
## Quem pede o que e so de uma cabeca — `por_dano`, `por_sangue`,
## `por_orbita_vazia`, `falar` (o do capo, o da janela do carona) — ganha
## material proprio naquele instante (`_tornar_propria`) e volta a ser uma
## `CabecaDoPadre` inteira, com `_process`. Sem isso o amassado de um iria
## para todos.
class_name CabecaDeFundo
extends CabecaDoPadre

## Os tons de pele: [pele, mancha quente, mancha fria, veia, racha, olheira do
## fundo, olheira da borda, labio, metros por repeticao da textura, relevo].
## O primeiro e o do principal, um fio mais escuro.
const TONS := [
	[Color(0.72, 0.71, 0.68), Color(0.64, 0.53, 0.49), Color(0.58, 0.63, 0.62),
		Color(0.33, 0.32, 0.46), Color(0.13, 0.11, 0.10), Color(0.035, 0.018, 0.016),
		Color(0.30, 0.17, 0.16), Color(0.10, 0.045, 0.042), 0.15, 1.6],
	# Cera amarelada, racha mais miuda.
	[Color(0.74, 0.69, 0.57), Color(0.68, 0.52, 0.40), Color(0.60, 0.61, 0.53),
		Color(0.36, 0.30, 0.40), Color(0.15, 0.11, 0.07), Color(0.04, 0.02, 0.012),
		Color(0.36, 0.21, 0.12), Color(0.14, 0.06, 0.035), 0.12, 1.5],
	# Livida, azulada, a veia mais roxa e a olheira arroxeada.
	[Color(0.63, 0.66, 0.70), Color(0.58, 0.50, 0.52), Color(0.50, 0.56, 0.63),
		Color(0.27, 0.26, 0.50), Color(0.11, 0.10, 0.12), Color(0.03, 0.015, 0.03),
		Color(0.24, 0.13, 0.24), Color(0.12, 0.05, 0.08), 0.17, 1.7],
	# Podre: mais escura, esverdeada, placa grande e funda.
	[Color(0.56, 0.57, 0.49), Color(0.54, 0.41, 0.33), Color(0.45, 0.51, 0.44),
		Color(0.30, 0.30, 0.36), Color(0.09, 0.075, 0.05), Color(0.03, 0.016, 0.01),
		Color(0.27, 0.13, 0.09), Color(0.09, 0.04, 0.03), 0.11, 1.9],
]
## Os olhos: [esclera, iris, escala da iris (maior, iris menor)]. O normal, o
## leitoso (catarata, a iris quase some) e o injetado.
const OLHOS := [
	[Color.WHITE, Color(0.95, 0.95, 0.9), 3.5],
	[Color(0.93, 0.91, 0.84), Color(0.90, 0.92, 0.94), 5.2],
	[Color(0.95, 0.84, 0.80), Color(0.93, 0.93, 0.88), 3.8],
]
## A queixada caida que a semente da, somada ao `sorriso` pedido.
const QUEIXADA_BASE := [0.0, 0.1, 0.22, 0.38]
## A abertura da queixada anda de tanto em tanto: cada passo e um material.
const PASSO_ABRE := 0.05
## O cranio: faixa de escala em x (largura), y (altura) e z (fundo), e o giro
## (rad) em volta de z e de x.
const ESCALA_X := Vector2(0.92, 1.04)
const ESCALA_Y := Vector2(0.98, 1.11)
const ESCALA_Z := Vector2(0.96, 1.05)
const GIRO_Z := 0.06
const GIRO_X := 0.05
## O olho: faixa do tamanho, quanto sobe ou desce (m) e o vesgo (rad).
const OLHO_TAMANHO := Vector2(0.92, 1.14)
const OLHO_ALTURA := 0.0025
const OLHO_VESGO := Vector2(0.03, 0.13)
## O globo leve: aneis e lados.
const GLOBO_ANEIS := 24
const GLOBO_LADOS := 32

static var _peles: Dictionary = {}
static var _mats_olho: Dictionary = {}
static var _boca_comum: ShaderMaterial
static var _longes: Dictionary = {}
static var _globo_fundo: ArrayMesh

var _propria := false
var _tom := 0
var _abre_base := 0.0
var _no_pele: MeshInstance3D
var _longe_nos: Array[MeshInstance3D] = []
## O desvio de cada olho (posicao) sobre o lugar do principal: `por_dano` do
## principal devolve o olho ao lugar dele, e aqui o desvio volta por cima.
var _desvio_olho: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]


## Poe a cabeca em `c`, debaixo de `capuz`, variada pela `semente`. Null se a
## malha nao existe.
static func vestir_fundo(c: Corpo, _capuz: CapuzMacabro, semente: int) -> CabecaDeFundo:
	if not CabecaDoPadre._carregar():
		push_warning("CabecaDeFundo: %s nao carrega" % CabecaDoPadre.CENA)
		return null
	var no := MonstroDaEstrada.no_da_cabeca(c, "CabecaDoPadre")
	if no == null:
		return null
	var cab := CabecaDeFundo.new()
	cab.name = "Cabeca"
	no.add_child(cab)
	var s := c.tamanho_do_rosto().y / CabecaDoPadre.CAIXA_ALTURA
	cab.position = Vector3(0.0, c.plano_do_rosto().origin.y, 0.0)
	cab.scale = Vector3(lerpf(ESCALA_X.x, ESCALA_X.y, _h(semente, 1)),
		lerpf(ESCALA_Y.x, ESCALA_Y.y, _h(semente, 2)),
		lerpf(ESCALA_Z.x, ESCALA_Z.y, _h(semente, 3))) * s
	cab.rotation = Vector3((_h(semente, 4) * 2.0 - 1.0) * GIRO_X, 0.0,
		(_h(semente, 5) * 2.0 - 1.0) * GIRO_Z)
	cab._montar_fundo(semente)
	return cab


func _ready() -> void:
	# Parada ate alguem pedir o que e so dela.
	set_process(_propria)


## O cranio no espaco do pai, com a escala de cada eixo (o capuz assenta nele).
func elipsoide() -> AABB:
	var e := Vector3(0.082, 0.116, 0.112) * scale
	var c := position + Vector3(0.0, 0.0, -0.003 * scale.z)
	return AABB(c - e, e * 2.0)


func por_sorriso(v: float) -> void:
	if _propria:
		super(v)
		return
	_sorriso = snappedf(clampf(v + _abre_base, 0.0, 1.0), PASSO_ABRE)
	_mat_pele = _pele_de(_tom, _sorriso)
	if _no_pele != null:
		_no_pele.material_override = _mat_pele
	_aplicar_boca()


func por_olhos(forca: float, tamanho: float) -> void:
	if _propria:
		super(forca, tamanho)
		return
	_mat_longe = _longe_de(forca, tamanho)
	for n in _longe_nos:
		n.material_override = _mat_longe


func falar(trilha: Array) -> void:
	_tornar_propria()
	super(trilha)


func por_sangue(progresso: float) -> void:
	if progresso <= 0.0 and not _propria:
		return
	_tornar_propria()
	super(progresso)


func por_dano(nivel: float) -> void:
	if nivel <= 0.0 and not _propria:
		return
	_tornar_propria()
	super(nivel)
	for i in mini(_olhos.size(), _desvio_olho.size()):
		var o := _olhos[i]
		if o != null and is_instance_valid(o) and o.get_parent() == self:
			o.position += _desvio_olho[i]


func por_orbita_vazia(v: float) -> void:
	if v <= 0.0 and not _propria:
		return
	_tornar_propria()
	super(v)


func _process(delta: float) -> void:
	if _propria:
		super(delta)


## Se esta cabeca ja deixou os materiais divididos (para quem mede).
func e_propria() -> bool:
	return _propria


## O tom de pele (indice em `TONS`): os bracos pegam o mesmo.
func tom() -> int:
	return _tom


## Material proprio para tudo que a cena pode mexer so nesta cabeca, e o
## `_process` do principal de volta (a lingua, a fala).
func _tornar_propria() -> void:
	if _propria:
		return
	_propria = true
	_mat_pele = _mat_pele.duplicate() as ShaderMaterial
	if _no_pele != null:
		_no_pele.material_override = _mat_pele
	_mat_boca = _mat_boca.duplicate() as ShaderMaterial
	if _boca != null:
		_boca.material_override = _mat_boca
	_mat_longe = _mat_longe.duplicate() as ShaderMaterial
	for n in _longe_nos:
		n.material_override = _mat_longe
	if not _olhos.is_empty() and _olhos[0] != null and is_instance_valid(_olhos[0]):
		_mat_olho_e = (_olhos[0].material_override as ShaderMaterial).duplicate() as ShaderMaterial
		_olhos[0].material_override = _mat_olho_e
	set_process(true)


func _montar_fundo(semente: int) -> void:
	_tom = int(_h(semente, 6) * float(TONS.size())) % TONS.size()
	_abre_base = float(QUEIXADA_BASE[int(_h(semente, 7) * float(QUEIXADA_BASE.size()))
		% QUEIXADA_BASE.size()])
	_sorriso = snappedf(_abre_base, PASSO_ABRE)
	_mat_pele = _pele_de(_tom, _sorriso)
	_no_pele = MeshInstance3D.new()
	_no_pele.name = "Pele"
	_no_pele.mesh = CabecaDoPadre._malha_pele
	_no_pele.material_override = _mat_pele
	add_child(_no_pele)

	if _boca_comum == null:
		_boca_comum = ShaderMaterial.new()
		_boca_comum.shader = CabecaDoPadre._shader(&"boca", CabecaDoPadre.BOCA_SHADER)
	_mat_boca = _boca_comum
	var boca := MeshInstance3D.new()
	boca.name = "Boca"
	boca.mesh = CabecaDoPadre._malha_boca_vit if CabecaDoPadre._malha_boca_vit != null \
		else CabecaDoPadre._malha_boca
	boca.material_override = _mat_boca
	boca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boca = boca
	add_child(boca)
	_aplicar_boca()

	var globo := _globo_leve()
	var mat_olho := _olho_de(int(_h(semente, 8) * float(OLHOS.size())) % OLHOS.size())
	_mat_olho_e = mat_olho
	_mat_longe = _longe_de(1.0, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(CabecaDoPadre.LONGE_QUAD, CabecaDoPadre.LONGE_QUAD)
	# Um olho maior que o outro, um mais alto; o maior sai mais da orbita.
	var vesgo := lerpf(OLHO_VESGO.x, OLHO_VESGO.y, _h(semente, 9))
	for k in 2:
		var lado := -1.0 if k == 0 else 1.0
		var tam := lerpf(OLHO_TAMANHO.x, OLHO_TAMANHO.y, _h(semente, 10 + k))
		var desvio := Vector3(0.0, (_h(semente, 12 + k) * 2.0 - 1.0) * OLHO_ALTURA,
			-CabecaDoPadre.OLHO_R * (tam - 1.0) * 0.8)
		_desvio_olho[k] = desvio
		var olho := MeshInstance3D.new()
		olho.name = "Olho" + ("E" if lado < 0.0 else "D")
		olho.mesh = globo
		olho.material_override = mat_olho
		olho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_olhos.append(olho)
		add_child(olho)
		olho.position = Vector3(CabecaDoPadre.OLHO.x * lado, CabecaDoPadre.OLHO.y,
			CabecaDoPadre.OLHO.z) + desvio
		olho.scale = Vector3.ONE * tam
		# O polo da pupila para a frente, e o olhar que nao converge: cada um
		# para um lado, e um deles um fio para baixo.
		olho.rotation = Vector3(-PI * 0.5 + (0.06 if k == int(_h(semente, 14) * 2.0) else 0.0),
			vesgo * lado, 0.0)
		var longe := MeshInstance3D.new()
		longe.name = "Longe" + ("E" if lado < 0.0 else "D")
		longe.mesh = quad
		longe.material_override = _mat_longe
		longe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(longe)
		longe.position = olho.position + Vector3(0.0, 0.0, -CabecaDoPadre.OLHO_R * tam - 0.002)
		_longe_nos.append(longe)


## A pele do tom `tom` com a queixada em `abre`, dividida por quem pede igual.
static func _pele_de(tom: int, abre: float) -> ShaderMaterial:
	var chave := "%d_%d" % [tom, roundi(abre / PASSO_ABRE)]
	if _peles.has(chave):
		return _peles[chave]
	var m := ShaderMaterial.new()
	m.shader = CabecaDoPadre._shader(&"pele", CabecaDoPadre.PELE_SHADER)
	m.set_shader_parameter(&"mapa", load(CabecaDoPadre.MAPA))
	m.set_shader_parameter(&"mapa_n", load(CabecaDoPadre.MAPA_N))
	# O sangue e o gore ficam carregados: quem vira propria (o do capo) os usa.
	if ResourceLoader.exists(CabecaDoPadre.SANGUE):
		m.set_shader_parameter(&"sangue_mapa", load(CabecaDoPadre.SANGUE))
	if ResourceLoader.exists(CabecaDoPadre.GORE):
		m.set_shader_parameter(&"gore_mapa", load(CabecaDoPadre.GORE))
	m.set_shader_parameter(&"pivo", CabecaDoPadre.PIVO)
	m.set_shader_parameter(&"giro_max", CabecaDoPadre.GIRO_QUEIXADA)
	var t: Array = TONS[tom]
	var nomes := [&"pele", &"mancha_quente", &"mancha_fria", &"veia", &"racha",
		&"olheira_fundo", &"olheira_borda", &"labio"]
	for k in nomes.size():
		m.set_shader_parameter(nomes[k], t[k])
	m.set_shader_parameter(&"tile", t[8])
	m.set_shader_parameter(&"relevo", t[9])
	m.set_shader_parameter(&"abre", abre)
	_peles[chave] = m
	return m


static func _olho_de(qual: int) -> ShaderMaterial:
	if _mats_olho.has(qual):
		return _mats_olho[qual]
	var m := CabecaDoPadre._material_do_olho()
	var o: Array = OLHOS[qual]
	m.set_shader_parameter(&"sclera_albedo", o[0])
	m.set_shader_parameter(&"iris_albedo", o[1])
	m.set_shader_parameter(&"iris_scale", o[2])
	_mats_olho[qual] = m
	return m


## O ponto de longe com `forca` e `tamanho`, dividido por quem pede igual.
static func _longe_de(forca: float, tamanho: float) -> ShaderMaterial:
	var chave := Vector2i(roundi(forca * 20.0), roundi(tamanho * 20.0))
	if _longes.has(chave):
		return _longes[chave]
	var m := ShaderMaterial.new()
	m.shader = CabecaDoPadre._shader(&"longe", CabecaDoPadre.OLHO_LONGE_SHADER)
	m.set_shader_parameter(&"de", CabecaDoPadre.LONGE_DE)
	m.set_shader_parameter(&"ate", CabecaDoPadre.LONGE_ATE)
	m.set_shader_parameter(&"forca", float(chave.x) / 20.0)
	m.set_shader_parameter(&"escala", float(chave.y) / 20.0)
	_longes[chave] = m
	return m


## O globo do principal (`CabecaDoPadre._globo`), com menos aneis e lados: a
## mesma UV de frente que o shader do olho espera.
static func _globo_leve() -> ArrayMesh:
	if _globo_fundo != null:
		return _globo_fundo
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in GLOBO_ANEIS + 1:
		var th := PI * float(i) / float(GLOBO_ANEIS)
		for j in GLOBO_LADOS + 1:
			var ph := TAU * float(j) / float(GLOBO_LADOS)
			var q := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			st.set_normal(q)
			st.set_uv(Vector2(0.5, 0.5) + Vector2(cos(ph), sin(ph)) * (th / PI) * 0.5)
			st.add_vertex(q * CabecaDoPadre.OLHO_R)
	for i in GLOBO_ANEIS:
		for j in GLOBO_LADOS:
			var a := i * (GLOBO_LADOS + 1) + j
			var b := a + GLOBO_LADOS + 1
			# Horario visto de fora: a frente do Godot.
			for v: int in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(v)
	st.generate_tangents()
	_globo_fundo = st.commit()
	return _globo_fundo


## Um numero de 0 a 1 da semente e do canal `k`, sempre o mesmo.
static func _h(semente: int, k: int) -> float:
	var x := sin(float(semente) * 12.9898 + float(k) * 78.233 + 0.5) * 43758.5453
	return x - floorf(x)
