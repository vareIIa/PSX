## A cara que mexe: boca na fala, sobrancelha e olho na expressao, piscada.
##
## A cabeca continua caixa e o rosto continua UMA celula pintada. O que mexe sao
## cinco recortes pequenos colados por cima da cara, cada um no lugar exato do
## pedaco que ele troca (boca, sobrancelha esquerda e direita, olho esquerdo e
## direito), com o desenho do estado novo tirado da propria cara pelo
## `tools/gerar_rosto.py`. Estado neutro e recorte escondido: a cara de baixo e
## o neutro. E o truque do Metal Gear Solid, e o mesmo da palpebra da criacao.
##
## Cada estado de cada recorte e uma malha de quatro vertices presa ao osso da
## cabeca, montada no primeiro uso e guardada: trocar de estado e trocar o
## `mesh` do MeshInstance, sem custo de montagem no quadro da fala.
##
## Quem escreve aqui:
## - `Fala` (a boca, silaba a silaba);
## - quem da expressao (`expressao`), e o piscar, que e do proprio Rosto.
##
## "Esquerda" e "direita" dos recortes sao da IMAGEM (a esquerda de quem olha a
## cara de frente). `olhar(lado)` traduz o lado do mundo.
class_name Rosto
extends RefCounted

enum Expressao { NEUTRA, SIMPATIA, RISO, RAIVA, DESCONFIANCA, MEDO, SURPRESA,
	TRISTEZA, NOJO, CHAPADO, BEBADO, DOR, DESACORDADO }

## [boca em repouso, sobrancelha esquerda, sobrancelha direita, olhos] por
## expressao. &"" e o neutro (a propria cara).
const TABELA := {
	Expressao.NEUTRA: [&"", &"", &"", &""],
	Expressao.SIMPATIA: [&"SORRISO", &"ERGUIDA", &"ERGUIDA", &""],
	Expressao.RISO: [&"ABERTA", &"ERGUIDA", &"ERGUIDA", &"SEMICERRADO"],
	Expressao.RAIVA: [&"CERRADA", &"FRANZIDA", &"FRANZIDA", &"SEMICERRADO"],
	Expressao.DESCONFIANCA: [&"", &"ERGUIDA", &"", &"SEMICERRADO"],
	Expressao.MEDO: [&"ENTREABERTA", &"ERGUIDA", &"ERGUIDA", &"ARREGALADO"],
	Expressao.SURPRESA: [&"REDONDA", &"ERGUIDA", &"ERGUIDA", &"ARREGALADO"],
	Expressao.TRISTEZA: [&"TRISTE", &"CAIDA", &"CAIDA", &""],
	Expressao.NOJO: [&"TRISTE", &"FRANZIDA", &"FRANZIDA", &"SEMICERRADO"],
	Expressao.CHAPADO: [&"ENTREABERTA", &"", &"", &"SEMICERRADO"],
	Expressao.BEBADO: [&"ENTREABERTA", &"CAIDA", &"CAIDA", &"SEMICERRADO"],
	# Dor: olho espremido, sobrancelha franzida, dente cerrado. E a cara do
	# corpo que bateu no chao (ver `BonecoDePano`).
	Expressao.DOR: [&"CERRADA", &"FRANZIDA", &"FRANZIDA", &"FECHADO"],
	# Apagado: olho fechado, boca mole. Nao pisca (ja esta fechado).
	Expressao.DESACORDADO: [&"ENTREABERTA", &"", &"", &"FECHADO"],
}

## Piscada: um decimo de segundo fechado a cada 2 a 5 s, as vezes dupla.
const PISCADA := 0.11
## Distancia a partir do `plano_do_rosto` (z = -0,1125; a face da caixa esta
## em -0,111 e a barba em recorte em -0,113). Olho e sobrancelha vao tres
## milimetros a frente, por cima da palpebra e dos oculos; a boca vai ENTRE a
## cara e a barba (-0,112), senao a pele em volta da boca aberta apagava o
## bigode e o cavanhaque.
const Z_FRENTE := 0.003
const Z_BOCA := -0.0005

var corpo: Corpo
var _chave := Vector2i(-1, -1)
var _meta: Dictionary = {}
var _no: Dictionary = {}          # peca -> MeshInstance3D
var _malhas: Dictionary = {}      # "peca/estado" -> Mesh
var _estado: Dictionary = {}      # peca -> estado mostrado

var _expressao: Expressao = Expressao.NEUTRA
## Reacao passageira por cima da expressao de base (a opcao que o jogador
## escolheu, o susto), e quanto ela ainda dura.
var _reacao: Expressao = Expressao.NEUTRA
var _t_reacao := 0.0
## Microexpressao: sobrancelha e olho por um instante (a sobrancelha que sobe
## na pergunta, o olhar que foge nas reticencias). &"" nao mexe.
var _micro_sobr: StringName = &""
var _micro_olho: StringName = &""
var _t_micro := 0.0
var _rindo := false
var _chapado := false
var _boca_falando: StringName = &""
var _falando := false
var _olhar := 0
var _t_piscar := 2.4
var _fechado := 0.0
var _rng := RandomNumberGenerator.new()
## Pisca sozinho. Desligado quando o Corpo ja tem a palpebra da criacao.
var pisca := true

static var _mat_cache: ShaderMaterial = null


static func tem_rosto(a: Dictionary) -> bool:
	return RostoMeta.CARAS.has(_chave_de(a))


static func _chave_de(a: Dictionary) -> Vector2i:
	return Vector2i(int(a.get("rosto", -1)), int(a.get("linha_rosto", -1)))


func _init(alvo: Corpo) -> void:
	corpo = alvo
	_chave = _chave_de(corpo.aparencia())
	_meta = RostoMeta.CARAS.get(_chave, {})
	# Ritmo de piscar da pessoa, e nao do mundo (plano, regra 4).
	_rng.seed = hash(corpo.aparencia().get("rosto", 0)) * 7919 + corpo.get_instance_id() % 97
	_t_piscar = _rng.randf_range(1.0, 4.0)
	for peca: StringName in [&"boca", &"sobr_e", &"sobr_d", &"olho_e", &"olho_d"]:
		_estado[peca] = &""


func valido() -> bool:
	return not _meta.is_empty()


## Tira os recortes da cara (o LOD do Corpo solta o rosto de quem se afastou).
func desmontar() -> void:
	for no: MeshInstance3D in _no.values():
		if is_instance_valid(no):
			no.queue_free()
	_no.clear()
	_malhas.clear()


# --- estados --------------------------------------------------------------------

func expressao(tipo: Expressao) -> void:
	_expressao = tipo
	_aplicar()


func expressao_atual() -> Expressao:
	return _efetiva()


## Uma expressao por `duracao` segundos, e depois volta a de base.
func reagir(tipo: Expressao, duracao: float) -> void:
	_reacao = tipo
	_t_reacao = duracao
	_aplicar()


## Sobrancelha e/ou olho por `duracao` segundos, por cima de tudo.
func micro(sobrancelha: StringName, olho: StringName, duracao: float) -> void:
	_micro_sobr = sobrancelha
	_micro_olho = olho
	_t_micro = duracao
	_aplicar()


## A expressao que vale agora: reacao em curso, riso do corpo, a da base, e o
## chapado do corpo quando a base e neutra.
func _efetiva() -> Expressao:
	if _t_reacao > 0.0:
		return _reacao
	if _rindo:
		return Expressao.RISO
	if _chapado and _expressao == Expressao.NEUTRA:
		return Expressao.CHAPADO
	return _expressao


## A boca da fala (viseme). &"" e boca fechada da propria cara; `falando` falso
## devolve a boca a expressao.
func boca_da_fala(estado: StringName, falando: bool = true) -> void:
	_boca_falando = estado
	_falando = falando
	_aplicar()


## Olhos para o lado: -1 esquerda da imagem, 1 direita, 0 frente.
func olhar(lado: int) -> void:
	_olhar = clampi(lado, -1, 1)
	_aplicar()


## Passo do relogio: reacao e micro que acabam, o corpo que ri ou esta
## chapado, e a piscada.
func passo(delta: float) -> void:
	var mudou := false
	if _t_reacao > 0.0:
		_t_reacao -= delta
		mudou = mudou or _t_reacao <= 0.0
	if _t_micro > 0.0:
		_t_micro -= delta
		mudou = mudou or _t_micro <= 0.0
	if corpo.rindo() != _rindo or corpo.chapado != _chapado:
		_rindo = corpo.rindo()
		_chapado = corpo.chapado
		mudou = true
	if mudou:
		_aplicar()
	if not pisca:
		return
	if _fechado > 0.0:
		_fechado -= delta
		if _fechado <= 0.0:
			_aplicar()
		return
	_t_piscar -= delta
	if _t_piscar > 0.0:
		return
	_fechado = PISCADA
	# Assustado pisca mais; chapado, devagar e mais tempo fechado.
	var base := Vector2(2.2, 5.2)
	if _expressao == Expressao.MEDO:
		base = Vector2(0.8, 2.0)
	elif _expressao == Expressao.CHAPADO or _expressao == Expressao.BEBADO:
		_fechado = PISCADA * 2.5
	_t_piscar = 0.22 if _rng.randf() < 0.18 else _rng.randf_range(base.x, base.y)
	_aplicar()


func piscando() -> bool:
	return _fechado > 0.0


func estado(peca: StringName) -> StringName:
	return _estado.get(peca, &"")


func _aplicar() -> void:
	if not valido():
		return
	var t: Array = TABELA[_efetiva()]
	var boca: StringName = _boca_falando if _falando else t[0]
	var olho: StringName = t[3]
	var sobr_e: StringName = t[1]
	var sobr_d: StringName = t[2]
	if _t_micro > 0.0:
		if _micro_sobr != &"":
			sobr_e = _micro_sobr
			sobr_d = _micro_sobr
		if _micro_olho != &"":
			olho = _micro_olho
	if _olhar != 0 and (olho == &"" or olho == &"OLHA_ESQ" or olho == &"OLHA_DIR"):
		olho = &"OLHA_ESQ" if _olhar < 0 else &"OLHA_DIR"
	if _fechado > 0.0:
		olho = &"FECHADO"
	_mostrar(&"boca", boca)
	_mostrar(&"sobr_e", sobr_e)
	_mostrar(&"sobr_d", sobr_d)
	_mostrar(&"olho_e", olho)
	_mostrar(&"olho_d", olho)


func _mostrar(peca: StringName, estado_novo: StringName) -> void:
	if _estado.get(peca, &"") == estado_novo and _no.has(peca):
		return
	_estado[peca] = estado_novo
	var no := _no_da(peca)
	if no == null:
		return
	if estado_novo == &"":
		no.visible = false
		return
	var malha := _malha(peca, estado_novo)
	if malha == null:
		no.visible = false
		return
	no.mesh = malha
	no.visible = true


# --- geometria ------------------------------------------------------------------

func _no_da(peca: StringName) -> MeshInstance3D:
	if _no.has(peca):
		return _no[peca]
	var sk := corpo.esqueleto()
	var pele := corpo.get_node_or_null(^"Esqueleto/Pele") as MeshInstance3D
	if sk == null or pele == null:
		return null
	var no := MeshInstance3D.new()
	no.name = "Rosto_%s" % peca
	no.material_override = _material_de(pele.material_override as ShaderMaterial)
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.visible = false
	sk.add_child(no)
	no.skeleton = NodePath("..")
	no.skin = pele.skin
	_no[peca] = no
	return no


## A malha de um estado de uma peca: o recorte do tamanho exato dos texels que
## ele troca, no lugar exato deles na cara.
##
## A cara usa `Aparencia.uv_da_celula`: 31 texels esticados na largura da face
## (meio texel de folga em cada borda). A borda do texel `px` fica em
## u = (px - 0,5) / 31, e o recorte usa a MESMA conta — senao ele nasce meio
## texel deslocado e a boca aberta aparece ao lado da boca fechada.
func _malha(peca: StringName, estado_novo: StringName) -> Mesh:
	var k := "%s/%s" % [peca, estado_novo]
	if _malhas.has(k):
		return _malhas[k]
	var origem: Vector2i = _meta.get(peca, Vector2i(-1, -1))
	if origem.x < 0:
		return null
	var bloco: Vector2i = _meta["bloco"]
	var tam := Vector2i.ZERO
	var na_folha := Vector2i.ZERO
	match peca:
		&"boca":
			tam = RostoMeta.TAM_BOCA
			na_folha = bloco + Vector2i(RostoMeta.BOCAS.find(estado_novo) * tam.x, 0)
		&"sobr_e", &"sobr_d":
			tam = RostoMeta.TAM_SOBR
			var lado := 0 if peca == &"sobr_e" else 1
			na_folha = bloco + Vector2i(RostoMeta.BOCAS.size() * RostoMeta.TAM_BOCA.x
				+ (lado * RostoMeta.SOBRANCELHAS.size() + RostoMeta.SOBRANCELHAS.find(estado_novo))
				* tam.x, 0)
		_:
			tam = RostoMeta.TAM_OLHO
			var lado := 0 if peca == &"olho_e" else 1
			na_folha = bloco + Vector2i((lado * RostoMeta.OLHOS.size()
				+ RostoMeta.OLHOS.find(estado_novo)) * tam.x, RostoMeta.TAM_BOCA.y)
	var face := corpo.tamanho_do_rosto()
	var u0 := (float(origem.x) - 0.5) / 31.0
	var u1 := (float(origem.x + tam.x) - 0.5) / 31.0
	var v0 := (float(origem.y) - 0.5) / 31.0
	var v1 := (float(origem.y + tam.y) - 0.5) / 31.0
	var tamanho := Vector2((u1 - u0) * face.x, (v1 - v0) * face.y)
	var centro := Vector2(((u0 + u1) * 0.5 - 0.5) * face.x, (0.5 - (v0 + v1) * 0.5) * face.y)
	var lado_da_cara := corpo.plano_do_rosto()
	var z := Z_BOCA if peca == &"boca" else Z_FRENTE
	# O plano do rosto esta no osso da cabeca; a malha e em espaco do modelo
	# (o repouso da cabeca e so translacao, ver `Corpo._criar_ossos`).
	var cabeca := corpo.esqueleto().get_bone_global_rest(corpo.osso_da_cabeca())
	var xform := cabeca * lado_da_cara * Transform3D(Basis(), Vector3(centro.x, centro.y, z))
	var lado_atlas := float(RostoMeta.LADO_ATLAS)
	var uv := Rect2((float(na_folha.x) + 0.02) / lado_atlas, (float(na_folha.y) + 0.02) / lado_atlas,
		(float(tam.x) - 0.04) / lado_atlas, (float(tam.y) - 0.04) / lado_atlas)
	var d := PSXMesh.dados_com_ossos()
	corpo._face(d, tamanho, xform, corpo.aparencia().get("pele", Color.WHITE), uv,
		corpo.osso_da_cabeca())
	var malha := PSXMesh.dados_para_mesh(d)
	_malhas[k] = malha
	return malha


## O material do corpo, com recorte e com a folha de rosto no lugar do atlas de
## gente. Um so para todo mundo, refeito se o estilo trocou o shader.
static func _material_de(base: ShaderMaterial) -> ShaderMaterial:
	if base == null:
		return null
	if _mat_cache == null or _mat_cache.shader != base.shader:
		_mat_cache = base.duplicate() as ShaderMaterial
		_mat_cache.set_shader_parameter(&"alpha_cutoff", 0.5)
		_mat_cache.set_shader_parameter(&"albedo_tex", load(RostoMeta.ATLAS))
		var hd := "res://assets/textures_hd/rosto_atlas.png"
		if ResourceLoader.exists(hd):
			_mat_cache.set_shader_parameter(&"albedo_hd", load(hd))
		# O rosto e desenho, e nao tecido: sem relevo (o mapa de normal do atlas
		# de gente cairia em cima da boca errada).
		_mat_cache.set_shader_parameter(&"relevo", 0.0)
	return _mat_cache
