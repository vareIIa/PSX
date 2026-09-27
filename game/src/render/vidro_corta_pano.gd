## O vidro inteiro do carro corta a ROUPA dos padres: do lado de dentro dele,
## nenhum fragmento de batina, murca, capuz ou manga aparece.
##
## Por que existe
## --------------
## A batina AAA desenhada e a grade do `PanoGPU` mais um desvio por vertice de
## ate ~15 cm (o CUSTOM0 do `BatinaAAA`), e a manga do `BracoDoPadre` e pano de
## osso sem colisor de vidro. Colisor de pano (as esferas `_col_vidro` do cerco
## e `_vidro_no_pano` da `CabecadaDoPadre`) empurra a GRADE, e nao a malha: com
## eles ligados a roupa ainda aparecia por dentro do para-brisa e das duas
## janelas da frente, antes de qualquer vidro quebrar.
##
## Como funciona
## -------------
## Um recorte no shader da roupa. Cada vidro vira uma caixa fina do lado de
## DENTRO dele: o retangulo da abertura no plano do vidro (com `MARGEM`),
## de `DENTRO` a `PROFUNDO` metros para dentro da cabine. O fragmento de roupa
## que cai nessa caixa e descartado (na cor, na pre-passada de profundidade e
## na sombra). A caixa vai ao shader como um `mat4` do mundo para o espaco
## normalizado dela (|x| < 1, |y| < 1, 0 < z < 1): uma multiplicacao e tres
## comparacoes por vidro e fragmento.
##
## Os vidros saem das `aberturas` da propria lataria (`Carroceria.montar`, no
## espaco da `CarroCabine`): a janela do motorista (`porta_frente` e
## `quebra_vento` da esquerda), a do carona (as mesmas da direita) e o
## para-brisa. Quando a cabine abre um buraco (`CarroCabine.abrir_buraco`, o
## vidro do motorista que esfarela), o vidro daquele buraco para de cortar e o
## padre entra. E entra fundo: a mao dele chega na cara do motorista, a menos
## de 20 cm do plano do para-brisa. Por isso o buraco abre tambem uma caixa
## LIVRE, a metade da cabine do lado dele (`LIVRE_MARGEM`, `LIVRE_FUNDO`), onde
## nenhum outro vidro corta.
##
## Ligacao (poucas linhas em cada arquivo de roupa)
## ------------------------------------------------
## - o codigo do shader passa por `VidroCortaPano.costurar(SHADER)`, que poe
##   `GLSL_UNIFORMS` antes do `fragment()` e `GLSL_DESCARTA` na primeira linha
##   dele (a posicao de mundo sai de `INV_VIEW_MATRIX * VERTEX`, qualquer
##   `render_mode`);
## - todo material de roupa entra por `VidroCortaPano.registrar(material)`;
## - a `CarroCabine` chama `montar` e `buraco`.
##
## Sonda (`--vidro-sonda`): em vez de descartar, pinta o fragmento cortado de
## emissao pura (motorista magenta, carona ciano, para-brisa verde; azul o que
## passa de `SONDA_RASO` de fundo, em qualquer vidro). Contar
## esses pixels nas rajadas da abertura mede quanto de roupa estava do lado de
## dentro de cada vidro (`tools/contar_vidro_sonda.py`).
class_name VidroCortaPano
extends Node

## Quanto para dentro do plano do vidro a caixa comeca (m): a roupa que so
## encosta nele nao pisca.
const DENTRO := 0.004
## Ate onde a caixa vai (m, para dentro da cabine). A roupa que atravessa o
## vidro entra uns 15 a 30 cm; mais fundo que isso ha o banco e o motorista, e
## e ali que o padre do motorista chega depois que o vidro estoura.
const PROFUNDO := 0.45
## A caixa livre do vidro que estourou: folga em volta da abertura e fundo
## (m) para dentro da cabine. 1 m da janela do motorista para no meio do carro
## e nao alcanca a caixa do carona (que acaba a `PROFUNDO` da janela dele).
const LIVRE_MARGEM := 0.5
const LIVRE_FUNDO := 1.0
## A sonda pinta de azul o que passa deste fundo (m), em qualquer vidro.
const SONDA_RASO := 0.20
## A folga em volta do retangulo da abertura, no plano do vidro (m).
const MARGEM := 0.05
## Os vidros cortados: [tipos, lado]. O indice e o do uniform (`vcp_vidroN`).
const VIDROS := [[[&"porta_frente", &"quebra_vento"], -1], [[&"porta_frente", &"quebra_vento"], 1],
	[[&"parabrisa"], 0]]
## Os uniforms: as tres caixas de corte e a livre.
const NOMES := [&"vcp_vidro0", &"vcp_vidro1", &"vcp_vidro2", &"vcp_livre"]

const GLSL_UNIFORMS := """
// VidroCortaPano: a caixa de dentro de cada vidro inteiro, do mundo para o
// espaco normalizado dela (zero = vidro que nao corta).
uniform mat4 vcp_vidro0 = mat4(0.0);
uniform mat4 vcp_vidro1 = mat4(0.0);
uniform mat4 vcp_vidro2 = mat4(0.0);
// Depois que um vidro estoura: a metade da cabine por onde o padre entra, onde
// nenhum vidro corta.
uniform mat4 vcp_livre = mat4(0.0);
uniform bool vcp_sonda = false;
// Sonda: a partir de que fundo (normalizado) o fragmento conta como fundo.
uniform float vcp_raso = 2.0;
bool vcp_na_caixa(vec3 q) {
	return q.z > 0.0 && q.z < 1.0 && abs(q.x) < 1.0 && abs(q.y) < 1.0;
}
int vcp_vidro(vec3 p) {
	vec3 a = (vcp_vidro0 * vec4(p, 1.0)).xyz;
	vec3 b = (vcp_vidro1 * vec4(p, 1.0)).xyz;
	vec3 c = (vcp_vidro2 * vec4(p, 1.0)).xyz;
	// So dentro da cabine: do lado de dentro dos tres planos (o vidro
	// desligado da zero e nao conta). Sem isto a caixa da janela passava pelo
	// para-brisa e cortava a mao espalmada nele por fora.
	if (min(a.z, min(b.z, c.z)) < 0.0 || vcp_na_caixa((vcp_livre * vec4(p, 1.0)).xyz)) {
		return -1;
	}
	if (vcp_na_caixa(a)) { return a.z < vcp_raso ? 0 : 3; }
	if (vcp_na_caixa(b)) { return b.z < vcp_raso ? 1 : 3; }
	if (vcp_na_caixa(c)) { return c.z < vcp_raso ? 2 : 3; }
	return -1;
}
"""

const GLSL_DESCARTA := """
	{
		int vcp_k = vcp_vidro((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
		if (vcp_k >= 0) {
			if (!vcp_sonda) { discard; }
			EMISSION = (vcp_k == 0 ? vec3(1.0, 0.0, 1.0) : (vcp_k == 1 ? vec3(0.0, 1.0, 1.0)
				: (vcp_k == 2 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0)))) * 3.0;
		}
	}
"""

## Os materiais de roupa (fracos: o padre que sai leva o dele).
static var _materiais: Array[WeakRef] = []
## Os nos de cabine dentro da arvore, na ordem em que entraram. Manda o mais novo que esta no mundo
## da janela principal: o carro de fundo da `Criacao` monta a cabine dele num
## `SubViewport` de mundo proprio, e roubava os vidros do carro da estrada.
static var _nos: Array[VidroCortaPano] = []
## As caixas postas por ultimo (Projection, ou null antes da primeira).
static var _ultimo: Array = [null, null, null, null]
static var _sonda: bool = OS.get_cmdline_user_args().has("--vidro-sonda")

var _cabine: Node3D
## Por vidro: do espaco da cabine para o da caixa de corte e para o da livre
## (Transform3D), ou null.
var _caixas: Array = [null, null, null]
var _livres: Array = [null, null, null]
## Por vidro: o centro da abertura (espaco da cabine) e se o vidro existe.
var _centros: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _existe: Array[bool] = [true, true, true]


## `codigo` com o recorte: os uniforms antes do `fragment()` e o descarte na
## primeira linha dele.
static func costurar(codigo: String) -> String:
	var i := codigo.find("void fragment()")
	var abre := codigo.find("{", i) if i >= 0 else -1
	if abre < 0:
		push_warning("VidroCortaPano: shader sem fragment()")
		return codigo
	return codigo.substr(0, i) + GLSL_UNIFORMS + "\n" + codigo.substr(i, abre + 1 - i) \
		+ GLSL_DESCARTA + codigo.substr(abre + 1)


## Poe `mat` (um material cujo shader passou por `costurar`) no recorte.
static func registrar(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	for w: WeakRef in _materiais:
		if w.get_ref() == mat:
			return
	_materiais.append(weakref(mat))
	mat.set_shader_parameter(&"vcp_sonda", _sonda)
	if _sonda:
		mat.set_shader_parameter(&"vcp_raso", (SONDA_RASO - DENTRO) / (PROFUNDO - DENTRO))
	for k in NOMES.size():
		if _ultimo[k] != null:
			mat.set_shader_parameter(NOMES[k], _ultimo[k])


## Os vidros de `cabine`, das `aberturas` dela (espaco da cabine).
## `--vidro-sem-corte` desliga o recorte (A/B).
static func montar(cabine: Node3D, aberturas: Array) -> void:
	if OS.get_cmdline_user_args().has("--vidro-sem-corte"):
		return
	var no := VidroCortaPano.new()
	no.name = "VidroCortaPano"
	no._cabine = cabine
	for k in VIDROS.size():
		var tipos: Array = VIDROS[k][0]
		var lado := int(VIDROS[k][1])
		var principal := {}
		var pontos := PackedVector3Array()
		for a: Dictionary in aberturas:
			if not tipos.has(a["tipo"]) or (lado != 0 and int(a["lado"]) != lado):
				continue
			if a["tipo"] == tipos[0]:
				principal = a
			pontos.append_array(a.get("contorno", a["pontos"]))
		if principal.is_empty():
			continue
		no._caixas[k] = _caixa(principal, pontos, MARGEM, DENTRO, PROFUNDO)
		no._livres[k] = _caixa(principal, pontos, LIVRE_MARGEM, -LIVRE_MARGEM, LIVRE_FUNDO)
		no._centros[k] = principal["centro"]
		if _sonda:
			var n := (principal["normal"] as Vector3).normalized()
			var fora := PackedFloat32Array()
			for q: Vector3 in pontos:
				fora.append(snappedf((q - (principal["centro"] as Vector3)).dot(n), 0.001))
			print("VidroCortaPano: vidro %d centro %s normal %s pontos %d fora do plano %s" % [k,
				principal["centro"], n, pontos.size(), fora])
	cabine.add_child(no)


## A cabine abriu o buraco `caixa` (espaco dela): o vidro dali nao corta mais.
static func buraco(cabine: Node3D, caixa: AABB) -> void:
	for no: VidroCortaPano in _nos:
		if is_instance_valid(no) and no._cabine == cabine:
			for k in VIDROS.size():
				if no._caixas[k] != null and caixa.grow(0.05).has_point(no._centros[k]):
					no._existe[k] = false
					if _sonda:
						print("VidroCortaPano: vidro %d estourou" % k)


## Do espaco da cabine para o da caixa de dentro do vidro `a`: o retangulo que
## cobre os `pontos` (o contorno dele e dos vizinhos no mesmo plano) com
## `margem`, de `de` a `ate` metros para dentro.
static func _caixa(a: Dictionary, pontos: PackedVector3Array, margem: float, de: float,
		ate: float) -> Transform3D:
	var n := (a["normal"] as Vector3).normalized()
	var o: Vector3 = a["centro"]
	var v := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
	var u := v.cross(n).normalized()
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q: Vector3 in pontos:
		var p := Vector2((q - o).dot(u), (q - o).dot(v))
		mn = mn.min(p)
		mx = mx.max(p)
	mn -= Vector2.ONE * margem
	mx += Vector2.ONE * margem
	var meio := (mn + mx) * 0.5
	var meia := (mx - mn) * 0.5
	var fundo := ate - de
	# Linhas da base: x = u / meia.x, y = v / meia.y, z = -n / fundo (z cresce
	# para dentro da cabine).
	var b := Basis(u / meia.x, v / meia.y, -n / fundo).transposed()
	return Transform3D(b, -(b * o) - Vector3(meio.x / meia.x, meio.y / meia.y, de / fundo))


## O no que manda: o mais novo com a cabine no mundo da janela principal.
static func _eleito() -> VidroCortaPano:
	for i in range(_nos.size() - 1, -1, -1):
		var no := _nos[i]
		if no._cabine == null or not is_instance_valid(no._cabine):
			continue
		if no.get_viewport().find_world_3d() == no.get_tree().root.find_world_3d():
			return no
	return null


func _enter_tree() -> void:
	if not _nos.has(self):
		_nos.append(self)
	if not RenderingServer.frame_pre_draw.is_connected(_atualizar):
		RenderingServer.frame_pre_draw.connect(_atualizar)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_atualizar):
		RenderingServer.frame_pre_draw.disconnect(_atualizar)
	_nos.erase(self)
	if _eleito() == null:
		_por([Projection.ZERO, Projection.ZERO, Projection.ZERO, Projection.ZERO])


## Antes de desenhar: as caixas no mundo de agora, em todo material vivo.
func _atualizar() -> void:
	if _eleito() != self:
		return
	var inv := _cabine.global_transform.affine_inverse()
	var m: Array = []
	var livre := Projection.ZERO
	for k in VIDROS.size():
		if _caixas[k] == null or not _existe[k]:
			m.append(Projection.ZERO)
			if _caixas[k] != null and livre == Projection.ZERO:
				livre = Projection((_livres[k] as Transform3D) * inv)
		else:
			m.append(Projection((_caixas[k] as Transform3D) * inv))
	m.append(livre)
	_por(m)


static func _por(m: Array) -> void:
	var muda := false
	for k in NOMES.size():
		if _ultimo[k] == null or _ultimo[k] != m[k]:
			muda = true
	if not muda:
		return
	_ultimo = m
	var vivos: Array[WeakRef] = []
	for w: WeakRef in _materiais:
		var mat := w.get_ref() as ShaderMaterial
		if mat == null:
			continue
		vivos.append(w)
		for k in NOMES.size():
			mat.set_shader_parameter(NOMES[k], m[k])
	_materiais = vivos
