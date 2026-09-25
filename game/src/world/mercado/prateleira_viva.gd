## Os produtos da loja, um por um, na prateleira em que o planograma os pos.
##
## PLANO_MERCADO_AAA, 4.3. O produto e COISA: cada unidade da fileira da frente
## e uma instancia de `MultiMesh` (uma por forma, nove para a loja inteira mais
## a das etiquetas), com o rotulo escolhido por `INSTANCE_CUSTOM` no atlas de
## marcas. Tirar uma lata zera a escala da instancia; a de tras avanca meio
## segundo depois; a coluna vazia deixa o buraco e a etiqueta sozinha — o buraco
## e a tarefa de repor, visivel do outro lado da loja.
##
## Tambem sao daqui as portas da geladeira: o produto de dentro so se pega com
## a porta aberta, e a porta so abre com a mao de alguem.
##
## Coordenadas: o no fica na origem da planta (filho da raiz do comodo, como
## todo prop), entao o que o planograma diz vale sem conversao.
class_name PrateleiraViva
extends Node3D

const MATERIAL := "res://resources/materials/mat_mercado_produto.tres"
const MATERIAL_ALUMINIO := "res://resources/materials/mat_metal.tres"
const MATERIAL_VIDRO := "res://resources/materials/mat_vitrine_loja.tres"

## Quanto tempo a unidade de tras leva para chegar na frente, depois de uma
## pausa: a mao sai primeiro, depois a fileira escorrega.
const AVANCO_ESPERA := 0.25
const AVANCO_DURACAO := 0.3
## A porta da geladeira: angulo aberto, tempo para abrir e para fechar sozinha.
const PORTA_ABERTA := deg_to_rad(96.0)
const PORTA_ABRE := 0.45
const PORTA_FECHA_SOZINHA := 3.5
## Largura da coluna do marco entre duas portas.
const MARCO := 0.05

var loja: int = 0
var faces: Array[Dictionary] = []
var vagas: Array[Dictionary] = []

var _por_face: Array = []
## forma -> MultiMesh
var _mm: Dictionary = {}
## Vector2i(vaga, coluna) -> Vector2i(forma, instancia)
var _inst: Dictionary = {}
var _etiquetas: MultiMesh
var _destaque: MultiMeshInstance3D
var _destaque_visto := -10
var _destaque_alvo := Vector2i(-1, -1)
## {chave, de, ate, t, espera}
var _animacoes: Array[Dictionary] = []
## A conta das unidades numa thread (`_calcular_produtos`): a tarefa e o que
## ela devolve (forma -> buffer do MultiMesh, e o `_inst`).
var _tarefa_produtos := -1
var _saida_produtos: Dictionary = {}

var _geladeira := -1
var _portas: Array[Node3D] = []
var _abertura: PackedFloat32Array = []
var _querer: PackedFloat32Array = []
var _fechar_em: PackedFloat32Array = []

static var _material: ShaderMaterial


static func material_produto() -> ShaderMaterial:
	if _material == null:
		_material = load(MATERIAL) as ShaderMaterial
	return _material


## Criado pelo `Interiores.criar_prop` a partir do prop `prateleira_viva`.
static func criar(prop: Dictionary) -> PrateleiraViva:
	var p := PrateleiraViva.new()
	p.name = "PrateleiraViva"
	p.loja = int(prop.get("semente", 0))
	var plano: Dictionary = prop.get("planograma", {})
	if plano.is_empty():
		plano = Planograma.montar(p.loja)
	p.faces.assign(plano["faces"])
	# Copia funda: o dicionario do prop e o mesmo da planta em cache, e as
	# colunas mudam a cada lata tirada.
	for v: Dictionary in plano["vagas"]:
		p.vagas.append(v.duplicate(true))
	return p


func _ready() -> void:
	EstoqueMercado.aplicar(loja, vagas)
	_por_face.resize(faces.size())
	for i in faces.size():
		_por_face[i] = []
	for i in vagas.size():
		(_por_face[int(vagas[i]["face"])] as Array).append(i)
	_montar_produtos()
	_montar_etiquetas()
	_montar_destaque()
	for f: Dictionary in faces:
		if int(f["tipo"]) == Planograma.Tipo.GELADEIRA:
			_geladeira = int(f["id"])
			_montar_portas(f)
		if bool(f["alcance"]):
			add_child(FaceDePrateleira.criar(self, f))
	# A mao do jogador pode estar segurando algo desta loja desde o save.
	ProdutoNaMao.da_camera(get_tree())


# --- desenho ------------------------------------------------------------------

func _montar_produtos() -> void:
	var contagem: Dictionary = {}
	for v: Dictionary in vagas:
		var forma := int(CatalogoMercado.produto(v["sku"])["forma"])
		contagem[forma] = int(contagem.get(forma, 0)) + int(v["frentes"])
	for forma: int in contagem:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = ProdutoMalhas.malha(forma)
		mm.instance_count = int(contagem[forma])
		# Nada desenha ate a conta da thread chegar (`_garantir_produtos`).
		mm.visible_instance_count = 0
		_mm[forma] = mm
		var mi := MultiMeshInstance3D.new()
		mi.name = "Forma%d" % forma
		mi.multimesh = mm
		mi.material_override = material_produto()
		# Sombra de lata em prateleira e sub-pixel a 480x270, e custa uma
		# passada de profundidade por forma.
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# O vidro da vitrine so fica transparente a menos de 36 m.
		mi.visibility_range_end = 40.0
		add_child(mi)
	# As unidades numa thread (`_calcular_produtos`). Os indices do catalogo e do
	# atlas sao montados no primeiro uso: ficam prontos aqui, e a thread so le.
	CatalogoMercado.produto(&"")
	RotulosAtlas.celula(&"")
	_saida_produtos = {}
	_tarefa_produtos = WorkerThreadPool.add_task(_calcular_produtos.bind(
		vagas, faces, loja, contagem, _saida_produtos), false, "prateleira do mercado")


## A transformada da unidade da frente de uma coluna, recuada `atras` unidades.
func _transformada(vi: int, c: int, atras: float) -> Transform3D:
	var v: Dictionary = vagas[vi]
	return _transformada_de(v, faces[int(v["face"])], vi, c, atras, loja)


## A mesma conta sem o no: e o que a thread de `_calcular_produtos` usa, e por
## isso as duas dao o mesmo numero.
static func _transformada_de(v: Dictionary, f: Dictionary, vi: int, c: int,
		atras: float, loja_: int) -> Transform3D:
	var md := CatalogoMercado.medida(v["sku"])
	var base := Planograma.base_da_coluna(f, v, c)
	base -= Vector3(f["normal"]) * atras * (md.z + Planograma.FOLGA)
	var b := Planograma.base_de(f)
	# Um grau ou dois de desalinho por unidade: fileira perfeita e maquete.
	var torto := (fposmod(float(hash(Vector3i(vi, c, loja_))) * 0.618, 1.0) - 0.5) * 0.06
	b = b * Basis(Vector3.UP, torto)
	return Transform3D(Basis(b.x * md.x, b.y * md.y, b.z * md.z), base)


## Na thread: onde cada unidade de cada vaga fica, escrito direto no buffer do
## MultiMesh de cada forma, no formato que o `set_instance_transform` grava (base
## por LINHA e a origem na quarta coluna) mais os quatro do `custom_data`.
##
## Eram duas chamadas ao RenderingServer por unidade, e a loja tem 2.385:
## 6,7 ms no quadro em que a prateleira nascia (tests/bancada_custo_interior.gd).
## So le `vagas` e `faces`: quem as muda (`pegar`, `devolver`) espera a tarefa
## antes (`_garantir_produtos`).
static func _calcular_produtos(vagas_: Array[Dictionary], faces_: Array[Dictionary],
		loja_: int, contagem: Dictionary, saida: Dictionary) -> void:
	# Primeiro quem vai em que instancia (a mesma ordem de sempre), depois um
	# buffer por forma escrito de uma vez: PackedFloat32Array guardado no
	# dicionario e copiado a cada escrita.
	var ordem := {}
	for forma: int in contagem:
		ordem[forma] = []
	var inst := {}
	for vi in vagas_.size():
		var v: Dictionary = vagas_[vi]
		var forma := int(CatalogoMercado.produto(v["sku"])["forma"])
		var lista: Array = ordem[forma]
		for c in int(v["frentes"]):
			inst[Vector2i(vi, c)] = Vector2i(forma, lista.size())
			lista.append(Vector2i(vi, c))
	var nada := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var buffers := {}
	for forma: int in ordem:
		var lista: Array = ordem[forma]
		var b := PackedFloat32Array()
		b.resize(lista.size() * 16)
		for k in lista.size():
			var par: Vector2i = lista[k]
			var v: Dictionary = vagas_[par.x]
			var cols: PackedInt32Array = v["colunas"]
			var t := nada if cols[par.y] <= 0 				else _transformada_de(v, faces_[int(v["face"])], par.x, par.y, 0.0, loja_)
			var r := RotulosAtlas.celula(v["sku"])
			var o := k * 16
			b[o] = t.basis.x.x
			b[o + 1] = t.basis.y.x
			b[o + 2] = t.basis.z.x
			b[o + 3] = t.origin.x
			b[o + 4] = t.basis.x.y
			b[o + 5] = t.basis.y.y
			b[o + 6] = t.basis.z.y
			b[o + 7] = t.origin.y
			b[o + 8] = t.basis.x.z
			b[o + 9] = t.basis.y.z
			b[o + 10] = t.basis.z.z
			b[o + 11] = t.origin.z
			b[o + 12] = r.position.x
			b[o + 13] = r.position.y
			b[o + 14] = r.size.x
			b[o + 15] = r.size.y
		buffers[forma] = b
	# As etiquetas de preco, uma por vaga, no mesmo formato.
	var e := PackedFloat32Array()
	e.resize(vagas_.size() * 16)
	for vi in vagas_.size():
		var v: Dictionary = vagas_[vi]
		var t := Planograma.etiqueta(faces_[int(v["face"])], v)
		var r := RotulosAtlas.etiqueta(v["sku"])
		var o := vi * 16
		e[o] = t.basis.x.x
		e[o + 1] = t.basis.y.x
		e[o + 2] = t.basis.z.x
		e[o + 3] = t.origin.x
		e[o + 4] = t.basis.x.y
		e[o + 5] = t.basis.y.y
		e[o + 6] = t.basis.z.y
		e[o + 7] = t.origin.y
		e[o + 8] = t.basis.x.z
		e[o + 9] = t.basis.y.z
		e[o + 10] = t.basis.z.z
		e[o + 11] = t.origin.z
		e[o + 12] = r.position.x
		e[o + 13] = r.position.y
		e[o + 14] = r.size.x
		e[o + 15] = r.size.y
	saida["buffers"] = buffers
	saida["etiquetas"] = e
	saida["inst"] = inst


## Se a conta das unidades chegou (ou `esperar`, espera por ela), sobe os
## buffers e o `_inst`. Verdadeiro quando os produtos estao na prateleira.
func _garantir_produtos(esperar: bool = true) -> bool:
	if _tarefa_produtos < 0:
		return true
	if not esperar and not WorkerThreadPool.is_task_completed(_tarefa_produtos):
		return false
	WorkerThreadPool.wait_for_task_completion(_tarefa_produtos)
	_tarefa_produtos = -1
	var buffers: Dictionary = _saida_produtos["buffers"]
	for forma: int in buffers:
		var mm: MultiMesh = _mm[forma]
		mm.buffer = buffers[forma]
		mm.visible_instance_count = -1
	if _etiquetas != null:
		_etiquetas.buffer = _saida_produtos["etiquetas"]
		_etiquetas.visible_instance_count = -1
	_inst = _saida_produtos["inst"]
	_saida_produtos = {}
	return true


func _pousar(vi: int, c: int, atras: float) -> void:
	_garantir_produtos()
	var qual: Vector2i = _inst[Vector2i(vi, c)]
	var mm: MultiMesh = _mm[qual.x]
	var cols: PackedInt32Array = vagas[vi]["colunas"]
	if cols[c] <= 0:
		mm.set_instance_transform(qual.y, Transform3D(Basis.from_scale(Vector3.ZERO),
			Vector3.ZERO))
	else:
		mm.set_instance_transform(qual.y, _transformada(vi, c, atras))


func _montar_etiquetas() -> void:
	_etiquetas = MultiMesh.new()
	_etiquetas.transform_format = MultiMesh.TRANSFORM_3D
	_etiquetas.use_custom_data = true
	_etiquetas.mesh = ProdutoMalhas.malha(ProdutoMalhas.ETIQUETA)
	_etiquetas.instance_count = vagas.size()
	# O buffer vem da mesma thread das unidades (`_calcular_produtos`); ate la
	# nada desenha. Se ela ja subiu (quem chama fora de ordem), sobe agora.
	_etiquetas.visible_instance_count = 0
	if _tarefa_produtos < 0 and _saida_produtos.has("etiquetas"):
		_etiquetas.buffer = _saida_produtos["etiquetas"]
		_etiquetas.visible_instance_count = -1
	var mi := MultiMeshInstance3D.new()
	mi.name = "Etiquetas"
	mi.multimesh = _etiquetas
	mi.material_override = material_produto()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 24.0
	add_child(mi)


## O brilho do produto sob a mira: uma copia um pouco maior, somada por cima.
func _montar_destaque() -> void:
	_destaque = MultiMeshInstance3D.new()
	_destaque.name = "Destaque"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.22, 0.2, 0.14)
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_destaque.material_override = mat
	_destaque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_destaque.visible = false
	add_child(_destaque)


func _mostrar_destaque(alvo: Vector2i) -> void:
	_destaque_visto = Engine.get_process_frames()
	if alvo == _destaque_alvo and _destaque.visible:
		return
	_destaque_alvo = alvo
	if alvo.x < 0:
		_destaque.visible = false
		return
	var v: Dictionary = vagas[alvo.x]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ProdutoMalhas.malha(int(CatalogoMercado.produto(v["sku"])["forma"]))
	mm.instance_count = 1
	var t := _transformada(alvo.x, alvo.y, 0.0)
	# Cresce a partir do centro, e nao da base: 4% de folga em toda volta.
	var centro := t.origin + t.basis.y * 0.5
	var b := t.basis.scaled_local(Vector3(1.04, 1.04, 1.04))
	mm.set_instance_transform(0, Transform3D(b, centro - b.y * 0.5))
	_destaque.multimesh = mm
	_destaque.visible = true


# --- geladeira ----------------------------------------------------------------

## As portas de vidro: um no por porta, girando na dobradica, em pares que
## abrem para fora a partir do meio de cada par.
func _montar_portas(f: Dictionary) -> void:
	var n := Planograma.PORTAS_GELADEIRA
	var comp: float = f["comprimento"]
	var largura := comp / float(n)
	var eixo: Vector3 = f["eixo"]
	var normal: Vector3 = f["normal"]
	var aluminio := load(MATERIAL_ALUMINIO) as Material
	var vidro := load(MATERIAL_VIDRO) as Material
	_abertura.resize(n)
	_querer.resize(n)
	_fechar_em.resize(n)
	for k in n:
		# Porta par dobra na esquerda de quem olha, impar na direita.
		var esquerda := k % 2 == 0
		var borda := float(k) * largura + (MARCO * 0.5 if esquerda else largura - MARCO * 0.5)
		var dobradica := Node3D.new()
		dobradica.name = "Porta%d" % k
		dobradica.position = Vector3(f["origem"]) + eixo * borda + normal * 0.035 \
			+ Vector3.UP * 0.08
		dobradica.basis = Planograma.base_de(f)
		add_child(dobradica)
		var sinal := 1.0 if esquerda else -1.0
		var larg := largura - MARCO
		var alto := 1.9
		var meio := Vector3(sinal * larg * 0.5, alto * 0.5, 0.0)
		# Moldura: quatro barras de aluminio e o puxador do lado que abre.
		for barra: Array in [
				[meio + Vector3(0, alto * 0.5 - 0.03, 0), Vector3(larg, 0.06, 0.04)],
				[meio - Vector3(0, alto * 0.5 - 0.05, 0), Vector3(larg, 0.1, 0.04)],
				[Vector3(sinal * 0.025, alto * 0.5, 0), Vector3(0.05, alto, 0.04)],
				[Vector3(sinal * (larg - 0.025), alto * 0.5, 0), Vector3(0.05, alto, 0.04)],
				[Vector3(sinal * (larg - 0.08), 1.05, 0.045), Vector3(0.03, 0.9, 0.03)]]:
			var caixa := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = barra[1]
			caixa.mesh = bm
			caixa.position = barra[0]
			caixa.material_override = aluminio
			caixa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dobradica.add_child(caixa)
		var placa := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(larg - 0.1, alto - 0.16)
		placa.mesh = qm
		placa.position = meio + Vector3(0, 0.02, 0)
		placa.material_override = vidro
		placa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dobradica.add_child(placa)
		dobradica.set_meta(&"sinal", sinal)
		_portas.append(dobradica)


func _porta_da_coluna(p: Vector2) -> int:
	if _geladeira < 0:
		return -1
	var comp: float = faces[_geladeira]["comprimento"]
	return clampi(int(p.x / (comp / float(_portas.size()))), 0, _portas.size() - 1)


func porta_aberta(k: int) -> bool:
	return k >= 0 and k < _abertura.size() and _abertura[k] > 0.85


func abrir_porta(k: int) -> void:
	if k < 0 or k >= _portas.size():
		return
	if _querer[k] < 0.5:
		AudioDirector.tocar(&"geladeira_abre", _portas[k].global_position, -4.0,
			randf_range(0.95, 1.05))
	_querer[k] = 1.0
	_fechar_em[k] = PORTA_FECHA_SOZINHA


# --- mira, pegar, devolver ----------------------------------------------------

func _aceita_pegar(v: Dictionary, c: int) -> bool:
	return (v["colunas"] as PackedInt32Array)[c] > 0


func _alvo(face: int, ponto: Vector3) -> Vector2i:
	if ponto == Vector3.INF:
		return Vector2i(-1, -1)
	var f: Dictionary = faces[face]
	var p := Planograma.na_face(f, ponto)
	var na_mao := StringName(EstoqueMercado.na_mao().get("sku", ""))
	var aceita: Callable
	if na_mao == &"":
		aceita = _aceita_pegar
	else:
		# Com a mao cheia, a mira procura o LUGAR do produto: a mesma vaga,
		# com espaco atras.
		aceita = func(v: Dictionary, c: int) -> bool:
			return StringName(v["sku"]) == na_mao \
				and (v["colunas"] as PackedInt32Array)[c] < int(v["fundo"])
	return Planograma.coluna_no_ponto(f, _por_face[face], vagas, p, aceita)


func rotulo_na_face(face: int, ponto: Vector3) -> String:
	var na_mao := StringName(EstoqueMercado.na_mao().get("sku", ""))
	var f: Dictionary = faces[face]
	if face == _geladeira and ponto != Vector3.INF:
		var k := _porta_da_coluna(Planograma.na_face(f, ponto))
		if not porta_aberta(k):
			_mostrar_destaque(Vector2i(-1, -1))
			return "Abrir a geladeira"
		_fechar_em[k] = PORTA_FECHA_SOZINHA
	var alvo := _alvo(face, ponto)
	_mostrar_destaque(alvo)
	if alvo.x < 0:
		if na_mao != &"":
			return "O lugar do %s não é aqui" % String(CatalogoMercado.produto(na_mao)["nome"])
		return ""
	var p := CatalogoMercado.produto(vagas[alvo.x]["sku"])
	var verbo := "Devolver" if na_mao != &"" else "Pegar"
	return "%s  %s  ·  %s" % [verbo, p["nome"], CatalogoMercado.reais(int(p["preco"]))]


func acionar_na_face(face: int, ponto: Vector3, _quem: Node) -> void:
	var f: Dictionary = faces[face]
	if face == _geladeira and ponto != Vector3.INF:
		var k := _porta_da_coluna(Planograma.na_face(f, ponto))
		if not porta_aberta(k):
			abrir_porta(k)
			return
		_fechar_em[k] = PORTA_FECHA_SOZINHA
	var alvo := _alvo(face, ponto)
	if alvo.x < 0:
		return
	if StringName(EstoqueMercado.na_mao().get("sku", "")) == &"":
		pegar(alvo.x, alvo.y)
	else:
		devolver(alvo.x, alvo.y)


## O jogador tira a unidade da frente de uma coluna.
func pegar(vi: int, c: int) -> bool:
	_garantir_produtos()
	var de := global_transform * _transformada(vi, c, 0.0)
	var sku: StringName = vagas[vi]["sku"]
	if not EstoqueMercado.tirar(loja, vagas, vi, c, EstoqueMercado.Destino.MAO):
		return false
	EstoqueMercado.segurar(sku, loja)
	var mao := ProdutoNaMao.da_camera(get_tree())
	if mao != null:
		mao.segurar(sku, de.origin + de.basis.y * 0.5)
	_som_do_produto(sku, de.origin)
	# A unidade da frente some; se havia outra atras, ela escorrega para a
	# frente depois de um instante.
	var qual: Vector2i = _inst[Vector2i(vi, c)]
	(_mm[qual.x] as MultiMesh).set_instance_transform(qual.y,
		Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	if (vagas[vi]["colunas"] as PackedInt32Array)[c] > 0:
		_animacoes.append({"chave": Vector2i(vi, c), "de": 1.0, "ate": 0.0,
			"t": -AVANCO_ESPERA})
	_destaque_alvo = Vector2i(-2, -2)
	return true


## O jogador poe a unidade da mao de volta numa coluna do mesmo produto.
func devolver(vi: int, c: int) -> bool:
	_garantir_produtos()
	var sku: StringName = vagas[vi]["sku"]
	if StringName(EstoqueMercado.na_mao().get("sku", "")) != sku:
		return false
	if not EstoqueMercado.por(loja, vagas, vi, c, EstoqueMercado.Destino.MAO):
		return false
	EstoqueMercado.soltar()
	var mao := ProdutoNaMao.da_camera(get_tree())
	if mao != null:
		mao.soltar()
	var cols: PackedInt32Array = vagas[vi]["colunas"]
	if cols[c] == 1:
		# A coluna estava vazia: a lata entra de frente, empurrada pela mao.
		_animacoes.append({"chave": Vector2i(vi, c), "de": -0.6, "ate": 0.0, "t": 0.0})
		_pousar(vi, c, -0.6)
	_som_do_produto(sku, global_transform * _transformada(vi, c, 0.0).origin)
	_destaque_alvo = Vector2i(-2, -2)
	return true


func _som_do_produto(sku: StringName, onde: Vector3) -> void:
	var forma := int(CatalogoMercado.produto(sku)["forma"])
	var nome := &"pega_caixa"
	match forma:
		CatalogoMercado.Forma.LATA:
			nome = &"pega_lata"
		CatalogoMercado.Forma.GARRAFA:
			nome = &"pega_vidro"
		CatalogoMercado.Forma.PACOTE, CatalogoMercado.Forma.PET:
			nome = &"pega_pacote"
	AudioDirector.tocar(nome, onde, -8.0, randf_range(0.92, 1.08))


# --- tempo --------------------------------------------------------------------

func _exit_tree() -> void:
	# A tarefa le `vagas` e escreve em `_saida_produtos`: nao sobrevive ao no.
	if _tarefa_produtos >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa_produtos)
		_tarefa_produtos = -1


func _process(delta: float) -> void:
	_garantir_produtos(false)
	# O destaque some sozinho quando ninguem mais pergunta pela face.
	if _destaque.visible and Engine.get_process_frames() - _destaque_visto > 2:
		_destaque.visible = false
		_destaque_alvo = Vector2i(-1, -1)
	elif _destaque.visible:
		var pulso := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
		(_destaque.material_override as StandardMaterial3D).albedo_color = \
			Color(0.12, 0.11, 0.08).lerp(Color(0.26, 0.24, 0.17), pulso)

	var i := 0
	while i < _animacoes.size():
		var a: Dictionary = _animacoes[i]
		a["t"] = float(a["t"]) + delta
		var t := clampf(float(a["t"]) / AVANCO_DURACAO, 0.0, 1.0)
		var s := t * t * (3.0 - 2.0 * t)
		var chave: Vector2i = a["chave"]
		if (vagas[chave.x]["colunas"] as PackedInt32Array)[chave.y] > 0 and float(a["t"]) >= 0.0:
			_pousar(chave.x, chave.y, lerpf(float(a["de"]), float(a["ate"]), s))
		if t >= 1.0:
			_animacoes.remove_at(i)
		else:
			i += 1

	for k in _portas.size():
		if _querer[k] > 0.5:
			_fechar_em[k] -= delta
			if _fechar_em[k] <= 0.0:
				_querer[k] = 0.0
		var antes := _abertura[k]
		_abertura[k] = move_toward(_abertura[k], _querer[k], delta / PORTA_ABRE)
		if antes > 0.0 and _abertura[k] == 0.0:
			AudioDirector.tocar(&"geladeira_fecha", _portas[k].global_position, -5.0,
				randf_range(0.95, 1.05))
		var e := _abertura[k]
		# Abre rapido e freia no fim: a mola da porta de geladeira comercial.
		var giro := PORTA_ABERTA * (1.0 - pow(1.0 - e, 2.2))
		var sinal := float(_portas[k].get_meta(&"sinal"))
		var f: Dictionary = faces[_geladeira]
		_portas[k].basis = Planograma.base_de(f) * Basis(Vector3.UP, -sinal * giro)
