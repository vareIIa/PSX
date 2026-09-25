## O anel distante da cidade (PLANO_DESEMPENHO_E_HORIZONTE, Horizonte, passo 2).
##
## Alem dos chunks que o ChunkManager desenha, a cidade continua ate `raio` m em
## malhas simplificadas: a planta 2,5D de cada chunk (HorizonteDados) vira
## blocos, chao e copa (HorizonteMalha), numa celula por quadrado de chunks.
##
## As celulas sao uma arvore de quadrantes em volta da camera. Longe, a celula
## e grande e o ponto e grosso; perto, pequena e fino. Toda celula e uma grade
## de 64 x 64 pontos (HorizonteMalha.G), em qualquer nivel: o custo de cada anel
## e o mesmo, e e isso que deixa o raio crescer. Dobrar o horizonte e um nivel
## a mais, e nao quatro vezes mais chunks: o custo cresce com o log do raio.
##
##   nivel 0   4 x 4 chunks (128 m), ponto de 2 m
##   nivel 1   8 x 8 chunks (256 m), ponto de 4 m
##   nivel 2   16 x 16 (512 m), ponto de 8 m
##   nivel 3   32 x 32 (1 km), ponto de 16 m (daqui em diante, a media)
##   nivel 4   64 x 64 (2 km), ponto de 32 m, um por chunk
##   nivel 5+  ponto de 64 m ou mais: um chunk sorteado em cada quadrado
##   nivel 7   512 x 512 (16 km)
##
## A celula se divide enquanto a camera esta a menos de DIVIDIR vezes o lado
## dela: com 1,5, ponto de 2 m ate ~380 m, de 4 m ate ~770 m, de 8 m ate ~1,5 km.
##
## De onde vem a planta
## --------------------
## Exata (do chunk construido) ate RAIO_EXATO: e ela que casa com o chunk de
## verdade na borda. O ChunkManager ja manda a de todo chunk que ele constroi;
## o resto sai de um fio proprio, do mais perto para o mais longe. Alem disso,
## e antes de a exata chegar, a aproximada (HorizonteDados.aproximar), feita do
## quarteirao, sem construir nada.
##
## Dois fios dedicados, de prioridade baixa: um constroi planta exata, o outro
## monta malha. Nenhum ocupa a piscina, onde o streaming de chunk ja divide duas
## vagas de prioridade baixa. No fio principal so a troca da malha pronta, uma
## por quadro, e a mascara.
##
## Mascara
## -------
## Um texel por chunk em volta da camera: 1 onde o ChunkManager desenha o chunk
## de verdade (completo, casca ou montagem ja na arvore). O shader some com a
## celula ali. Chunk que ainda nao chegou aparece no anel distante, e nao como
## buraco — a borda do streaming deixa de piscar.
##
## Cache em disco
## ---------------
## A planta exata custa um `construir` (~40 ms). Ela vai para
## user://horizonte/<versao>/, uma regiao de 16 x 16 chunks por arquivo,
## comprimida. A grade de toda celula do nivel 2 para cima (so aproximada) vai
## tambem, um arquivo por celula. A versao e o hash dos scripts que geram a
## cidade: mexeu no gerador, o cache velho e apagado e tudo sai de novo.
##
## Andando rapido (VEL_RAPIDO), os fios cedem a CPU a fisica e ao streaming de
## perto, que rodam no mesmo processador (a fisica mediana subia 1 a 2 ms com
## o horizonte a 2-8 km): o de plantas exatas para (o proprio streaming manda a
## planta de todo chunk que carrega, o anel antecipado a frente inclusive), e o
## de malhas faz primeiro as celulas perto; a distante (nivel da media) so sai
## quando nao ha perto na fila, e depois dela o fio descansa 4 vezes o que ela
## custou. Parado, tudo volta.
##
## So no MODERNO (o PS1 STYLE nao tem vista panoramica: skill psx-city). Com
## nevoa ele vai so ate onde ela apaga (FogPreset.alcance_visivel): a nevoa
## exponencial deixa ver a silhueta alem dos chunks carregados, e e o anel que a
## da. O ar e o do Environment, o mesmo dos chunks: perto e longe casam.
class_name Horizonte
extends Node3D

const SHADER := "res://shaders/psx_horizonte.gdshader"
const TAM := 32.0
const NIVEIS := 8
const CHUNKS_NIVEL0 := 4
const DIVIDIR := 1.5
const RAIO_EXATO := 768.0
## So ate este nivel a celula usa planta exata (o nivel 2 comeca a ~770 m).
const NIVEL_EXATO := 2
## Daqui para cima o ponto e a media do chao, e nao o bloco mais alto, e o
## predio sai em bloco recuado RECUO do ponto (a rua e o vao).
const NIVEL_MEDIA := 3
const RECUO := 0.2
## A planta aproximada nunca sai com menos pontos por chunk que isto (de 8 m):
## a de 1 ponto caia no meio do quarteirao e toda casa sumia.
const LADO_APROX_MIN := 4
## Acima desta velocidade (m/s) os fios cedem a CPU (ver o cabecalho).
const VEL_RAPIDO := 8.0
const DESCANSO_LONGE := 4.0
const DESCANSO_MAX_MS := 8000
## O chunk que acaba de chegar tira o horizonte em pontilhado nisto (s).
const ESMAECER := 0.35
const MASCARA := 128
const TETO_INTERIOR := 1000.0
## O ceu (serra, estrelas) mora isto alem do raio; o far da camera, alem dele
## (CeuNoturno e SerraDaCidade ficam a 88% do far).
const FOLGA_CEU := 150.0
const FRACAO_CEU := 0.85
## Uma celula e refeita quando ganha pelo menos isto de plantas exatas novas
## (fracao dos chunks dela).
const REFAZER_FRACAO := 0.15
const INTERVALO_REVISAO := 1.0
const ACESAS_NOITE := 0.22
const CACHE := "user://horizonte"
const CACHE_FIXO := "fixo"
## Chunks por lado de uma regiao do cache.
const REGIAO := 16
## Intervalo entre gravacoes do cache, em segundos.
const GRAVAR_A_CADA := 5.0
## O que gera a cidade: a versao do cache e o hash disto.
const FONTES_DO_GERADOR: Array[String] = ["res://src/world", "res://src/render/psx_mesh.gd",
	"res://resources/horizonte/cores_materiais.json",
	"res://resources/horizonte/paleta_aproximada.json",
	"res://src/world/horizonte/horizonte_dados.gd"]
## Entra na versao do cache: suba quando a conta da grade (_grade) mudar.
const VERSAO_GRADE := 2

## Raio minimo do ceu que a serra e as estrelas respeitam (0 = o de sempre).
## Com o horizonte ligado, eles moram alem da cidade distante.
static var ceu_minimo := 0.0

## Raio do horizonte, em metros (o da opcao).
var raio := 0.0
## O raio em uso: o da opcao, ou menos, se a nevoa apaga antes.
var _raio_ef := 0.0

var _mat: ShaderMaterial
var _ativo := false
var _coord := Vector2i(1 << 30, 0)
var _folhas_desejadas: Dictionary = {}
var _celulas: Dictionary = {}
var _feito: Dictionary = {}
var _pedidas: Dictionary = {}
var _mascara_img: Image
var _mascara_tex: ImageTexture
var _mascara_origem := Vector2i(1 << 30, 0)
var _versao_mascara := -1
var _revisao := 0.0
var _vel := Vector2.ZERO
var _frente := Vector2.ZERO
var _pos_antes := Vector3.INF
var _p_plano := Vector2.ZERO
var _raio_planejado := 0.0
## Nivel de cada chunk desenhado na mascara (0..1, sobe em ESMAECER s).
var _nivel_mascara: Dictionary = {}
var _esmaecendo := false
## Lido pelo fio de plantas.
var _rapido := false

var _fio_plantas: Thread
var _fio_malhas: Thread
var _trava := Mutex.new()
var _sinal_plantas := Semaphore.new()
var _sinal_malhas := Semaphore.new()
var _sair := false
var _fila_plantas: Array[Vector2i] = []
var _fila_malhas: Array = []
var _plantas: Dictionary = {}
var _prontas: Array = []
## Cache em disco (so o fio de plantas mexe): regioes lidas e sujas.
var _pasta_cache := ""
var _regioes_lidas: Dictionary = {}
## Protegida pela trava: o fio principal (`receber`) tambem suja.
var _regioes_sujas: Dictionary = {}
## O fio de plantas ja leu do disco as regioes da primeira fila. Antes disso
## nenhuma malha e pedida: seria toda aproximada e refeita logo depois.
var _cache_lido := false
var _espera_cache := 2.0

## Medidas para a bancada.
var medida_plantas_exatas := 0
var medida_malhas := 0
var medida_triangulos := 0
var medida_vertices := 0
var medida_celulas_do_disco := 0
## Celulas prontas escondidas porque um antepassado ainda desenha o mesmo chao
## (a troca de nivel espera os irmaos). Sem o esconder, eram desenho dobrado.
var medida_escondidas := 0
var _escondidas: Dictionary = {}
## Tempo de cada malha no fio (grade + malha), em ms.
var medida_malha_ms := PackedFloat32Array()


func _init(raio_m: float) -> void:
	raio = raio_m
	name = "Horizonte"


func _ready() -> void:
	HorizonteDados.preparar()
	HorizonteMalha.provoca_no_fim = \
		RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_mascara_img = Image.create(MASCARA, MASCARA, false, Image.FORMAT_R8)
	_mascara_tex = ImageTexture.create_from_image(_mascara_img)
	_mat.set_shader_parameter(&"mascara", _mascara_tex)
	_mat.set_shader_parameter(&"mascara_lado", float(MASCARA))
	_fio_plantas = Thread.new()
	_fio_plantas.start(_laco_plantas, Thread.PRIORITY_LOW)
	_fio_malhas = Thread.new()
	_fio_malhas.start(_laco_malhas, Thread.PRIORITY_LOW)


func _exit_tree() -> void:
	_sair = true
	_sinal_plantas.post()
	_sinal_malhas.post()
	if _fio_plantas != null and _fio_plantas.is_started():
		_fio_plantas.wait_to_finish()
	if _fio_malhas != null and _fio_malhas.is_started():
		_fio_malhas.wait_to_finish()
	ceu_minimo = 0.0
	_restaurar_far()


## O ChunkManager manda a planta de todo chunk que construiu (fio principal).
func receber(coord: Vector2i, planta: PackedByteArray) -> void:
	_trava.lock()
	if not _plantas.has(coord):
		_plantas[coord] = planta
		_regioes_sujas[_regiao_de(coord)] = true
	_trava.unlock()


## Esta desenhando? (a bancada e o ChunkManager perguntam)
func ativo() -> bool:
	return _ativo


## Sem trabalho pendente: toda celula desejada pronta e as filas vazias.
func ocioso() -> bool:
	_trava.lock()
	var vazio := _fila_plantas.is_empty() and _fila_malhas.is_empty() and _prontas.is_empty()
	_trava.unlock()
	return vazio and _pedidas.is_empty()


func celulas() -> int:
	return _celulas.size()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var deve := _deve_desenhar(cam)
	if deve != _ativo:
		_ativo = deve
		visible = deve
		ChunkManager.horizonte_mudou()
		if not deve:
			ceu_minimo = 0.0
			_restaurar_far()
	if not _ativo:
		return

	# O ceu mora alem da cidade distante: o far cresce, e a serra e as
	# estrelas vao junto (so o angulo delas importa).
	if not cam.has_meta(&"far_sem_horizonte"):
		cam.set_meta(&"far_sem_horizonte", cam.far)
	ceu_minimo = _raio_ef + FOLGA_CEU
	cam.far = maxf(float(cam.get_meta(&"far_sem_horizonte")), ceu_minimo / FRACAO_CEU)

	var p := cam.global_position
	if _pos_antes != Vector3.INF and delta > 0.0 and p.distance_to(_pos_antes) < 30.0:
		_vel = _vel.lerp(Vector2(p.x - _pos_antes.x, p.z - _pos_antes.z) / delta,
			1.0 - exp(-delta / 0.25))
	_pos_antes = p
	var f := -cam.global_basis.z
	_frente = Vector2(f.x, f.z).normalized()
	var coord := Vector2i(floori(p.x / TAM), floori(p.z / TAM))
	_revisao -= delta
	# Histerese: sai do rapido abaixo de 60% (velocidade oscilando em volta
	# do limite replanejaria a fila a cada quadro).
	var rapido := _vel.length() > (VEL_RAPIDO * 0.6 if _rapido else VEL_RAPIDO)
	if absf(_raio_ef - _raio_planejado) > 1.0:
		# Troca de clima: a nevoa mudou o quanto se ve.
		_raio_planejado = _raio_ef
		_coord = Vector2i(1 << 30, 0)
	if coord != _coord or rapido != _rapido:
		_coord = coord
		_rapido = rapido
		_replanejar_plantas(Vector2(p.x, p.z))
		_revisao = 0.0
	_espera_cache -= delta
	if _revisao <= 0.0 and (_cache_lido or _espera_cache <= 0.0):
		_revisao = INTERVALO_REVISAO
		_replanejar_malhas(Vector2(p.x, p.z))
	_aplicar_uma()
	_atualizar_mascara(coord, delta)
	_pintar()


func _deve_desenhar(cam: Camera3D) -> bool:
	if raio <= 0.0 or cam == null or not Settings.luz_por_pixel:
		return false
	if cam.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return false
	if cam.global_position.y > TETO_INTERIOR:
		return false
	var preset: FogPreset = ChunkManager._preset if ChunkManager._preset != null \
		else Settings.fog_preset()
	if preset == null:
		return false
	_raio_ef = minf(raio, preset.alcance_visivel())
	# Nevoa que apaga antes da borda dos chunks desenhados: nao ha o que mostrar.
	return _raio_ef > (float(ChunkManager.raios().y) + 1.0) * TAM


func _restaurar_far() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam != null and cam.has_meta(&"far_sem_horizonte"):
		cam.far = float(cam.get_meta(&"far_sem_horizonte"))
		cam.remove_meta(&"far_sem_horizonte")


# --- arvore de celulas --------------------------------------------------------

static func _lado_chunks(nivel: int) -> int:
	return CHUNKS_NIVEL0 << nivel


## Lado do ponto da grade no nivel, em m: 2, 4, 8, ...
static func _passo(nivel: int) -> float:
	return _lado_chunks(nivel) * TAM / HorizonteMalha.G


static func _retangulo(k: Vector3i) -> Rect2:
	var n := _lado_chunks(k.x) * TAM
	return Rect2(k.y * n, k.z * n, n, n)


static func _distancia(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)


func _folhas(p: Vector2) -> Array[Vector3i]:
	var saida: Array[Vector3i] = []
	var topo := NIVEIS - 1
	var m := _lado_chunks(topo) * TAM
	for j in range(floori((p.y - _raio_ef) / m), floori((p.y + _raio_ef) / m) + 1):
		for i in range(floori((p.x - _raio_ef) / m), floori((p.x + _raio_ef) / m) + 1):
			_dividir(Vector3i(topo, i, j), p, saida)
	return saida


func _dividir(k: Vector3i, p: Vector2, saida: Array[Vector3i]) -> void:
	var r := _retangulo(k)
	var d := _distancia(r, p)
	if d > _raio_ef:
		return
	if k.x > 0 and d < DIVIDIR * r.size.x:
		for b in 2:
			for a in 2:
				_dividir(Vector3i(k.x - 1, k.y * 2 + a, k.z * 2 + b), p, saida)
		return
	saida.append(k)


## Plantas exatas que faltam ate RAIO_EXATO, da mais perto (e mais a frente)
## para a mais longe. So na troca de chunk. O chunk que o ChunkManager carrega
## vem por `receber`. Ordenado por chave pronta (Vector3 com a prioridade na
## frente, sort nativo): com comparador em GDScript eram 40 ms.
func _replanejar_plantas(p: Vector2) -> void:
	var desenhados := {}
	for c: Vector2i in ChunkManager.chunks_desenhados():
		desenhados[c] = true
	var chaves: Array[Vector3] = []
	var n := 0 if _rapido else ceili(minf(RAIO_EXATO, _raio_ef + 2.0 * TAM) / TAM)
	var frente := _vel.normalized() if _vel.length() > 2.0 else Vector2.ZERO
	_trava.lock()
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var c := _coord + Vector2i(dx, dz)
			if _plantas.has(c) or desenhados.has(c):
				continue
			var centro := Vector2((c.x + 0.5) * TAM, (c.y + 0.5) * TAM) - p
			var dir := centro.normalized()
			var chave := centro.length() - 2.0 * maxf(0.0, _vel.dot(dir)) \
				- 64.0 * maxf(0.0, frente.dot(dir))
			chaves.append(Vector3(chave, c.x, c.y))
	_trava.unlock()
	chaves.sort()
	var fila: Array[Vector2i] = []
	fila.resize(chaves.size())
	for i in chaves.size():
		fila[i] = Vector2i(int(chaves[i].y), int(chaves[i].z))
	_trava.lock()
	_fila_plantas = fila
	_trava.unlock()
	_sinal_plantas.post()


## Folhas desejadas e malhas a pedir: folha sem celula, ou que ganhou plantas
## exatas. Na troca de chunk e a cada INTERVALO_REVISAO.
func _replanejar_malhas(p: Vector2) -> void:
	_p_plano = p
	var folhas := _folhas(p)
	_folhas_desejadas.clear()
	for k: Vector3i in folhas:
		_folhas_desejadas[k] = true
	var chaves: Array[Vector4] = []
	for k: Vector3i in folhas:
		if _pedidas.has(k):
			continue
		var pedir := not _celulas.has(k)
		if not pedir:
			var n := _lado_chunks(k.x)
			pedir = _exatas_em(k) > int(_feito.get(k, 0)) \
				+ maxi(2, int(REFAZER_FRACAO * n * n))
		if pedir:
			chaves.append(Vector4(_chave_malha(k, p), k.x, k.y, k.z))
	if not chaves.is_empty():
		_trava.lock()
		for k: Vector3i in _fila_malhas:
			chaves.append(Vector4(_chave_malha(k, p), k.x, k.y, k.z))
		chaves.sort()
		_fila_malhas.clear()
		for c: Vector4 in chaves:
			var k := Vector3i(int(c.y), int(c.z), int(c.w))
			_pedidas[k] = true
			_fila_malhas.append(k)
		_trava.unlock()
		_sinal_malhas.post()
	_podar()


## A celula que esta na frente da camera sai antes da que esta atras.
func _chave_malha(k: Vector3i, p: Vector2) -> float:
	var r := _retangulo(k)
	var d := _distancia(r, p)
	var dir := (r.get_center() - p).normalized()
	return d * (1.0 - 0.5 * maxf(0.0, _frente.dot(dir)))


func _exatas_em(k: Vector3i) -> int:
	if k.x >= NIVEL_EXATO:
		return 0
	var n := _lado_chunks(k.x)
	var c0 := Vector2i(k.y * n, k.z * n)
	var conta := 0
	_trava.lock()
	for j in n:
		for i in n:
			if _plantas.has(c0 + Vector2i(i, j)):
				conta += 1
	_trava.unlock()
	return conta


## Tira a celula que nao e mais folha, mas so quando toda folha nova que cobre o
## mesmo chao ja esta pronta: dividir ou juntar nunca abre buraco. Pela arvore
## (o antepassado ou os descendentes que sao folha), sem comparar celula com
## celula.
##
## E nunca desenha o mesmo chao duas vezes: a filha que fica pronta antes das
## irmas espera escondida sob a mae, e a troca e inteira num quadro so (a mae sai
## e as quatro entram). Antes a filha aparecia na hora, por cima da mae, e o
## chao ficava com dois niveis ao mesmo tempo ate a ultima irma chegar: a mae
## furava a filha onde era mais alta, e o desenho dobrava dirigindo.
func _podar() -> void:
	var mudou := false
	for k: Vector3i in _celulas.keys():
		if _folhas_desejadas.has(k) or not _coberta(k):
			continue
		(_celulas[k] as Node).queue_free()
		_celulas.erase(k)
		_feito.erase(k)
		mudou = true
	if mudou:
		_mostrar_sem_antepassado()


## A celula escondida cujo antepassado saiu passa a desenhar.
func _mostrar_sem_antepassado() -> void:
	for k: Vector3i in _escondidas.keys():
		if not _celulas.has(k):
			_escondidas.erase(k)
		elif not _tem_antepassado(k):
			(_celulas[k] as MeshInstance3D).visible = true
			_escondidas.erase(k)
	medida_escondidas = _escondidas.size()


func _tem_antepassado(k: Vector3i) -> bool:
	for nivel in range(k.x + 1, NIVEIS):
		var d := nivel - k.x
		if _celulas.has(Vector3i(nivel, k.y >> d, k.z >> d)):
			return true
	return false


func _coberta(k: Vector3i) -> bool:
	for nivel in range(k.x + 1, NIVEIS):
		var d := nivel - k.x
		var pai := Vector3i(nivel, k.y >> d, k.z >> d)
		if _folhas_desejadas.has(pai):
			return _celulas.has(pai)
	return _descendentes_prontos(k)


func _descendentes_prontos(k: Vector3i) -> bool:
	if _folhas_desejadas.has(k):
		return _celulas.has(k)
	if k.x == 0 or _distancia(_retangulo(k), _p_plano) > _raio_ef:
		# Chao fora do horizonte agora: nada ha de cobrir.
		return true
	for b in 2:
		for a in 2:
			if not _descendentes_prontos(Vector3i(k.x - 1, k.y * 2 + a, k.z * 2 + b)):
				return false
	return true


func _aplicar_uma() -> void:
	_trava.lock()
	var pronta: Array = _prontas.pop_front() if not _prontas.is_empty() else []
	_trava.unlock()
	if pronta.is_empty():
		return
	var k: Vector3i = pronta[0]
	var malha: ArrayMesh = pronta[1]
	_pedidas.erase(k)
	_feito[k] = int(pronta[2])
	medida_malhas += 1
	if not _folhas_desejadas.has(k):
		return
	var mi: MeshInstance3D = _celulas.get(k)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Fora da GI: o SDFGI revoxelizaria a cidade distante a cada troca.
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var n := _lado_chunks(k.x)
		mi.position = Vector3(k.y * n * TAM, 0.0, k.z * n * TAM)
		# A mae ainda desenha este chao: espera as irmas (_podar).
		if _tem_antepassado(k):
			mi.visible = false
			_escondidas[k] = true
			medida_escondidas = _escondidas.size()
		add_child(mi)
		_celulas[k] = mi
	else:
		medida_triangulos -= int(mi.get_meta(&"triangulos", 0))
		medida_vertices -= int(mi.get_meta(&"vertices", 0))
	mi.mesh = malha
	var tris := 0 if malha == null else malha.surface_get_array_index_len(0) / 3
	var verts := 0 if malha == null else malha.surface_get_array_len(0)
	mi.set_meta(&"triangulos", tris)
	mi.set_meta(&"vertices", verts)
	medida_triangulos += tris
	medida_vertices += verts
	_podar()


# --- mascara e ar -------------------------------------------------------------

## O chunk que o ChunkManager passa a desenhar sobe de 0 a 1 em ESMAECER s (o
## horizonte sai em pontilhado por cima dele); o que ele deixa de desenhar cai
## a 0 na hora (senao abriria buraco).
func _atualizar_mascara(coord: Vector2i, delta: float) -> void:
	var origem := coord - Vector2i(MASCARA / 2, MASCARA / 2)
	var mudou := origem != _mascara_origem
	if ChunkManager.versao_desenho != _versao_mascara:
		_versao_mascara = ChunkManager.versao_desenho
		var novos := {}
		for c: Vector2i in ChunkManager.chunks_desenhados():
			var v: float = _nivel_mascara.get(c, 0.0)
			novos[c] = v
			if v < 1.0:
				_esmaecendo = true
		_nivel_mascara = novos
		mudou = true
	if _esmaecendo:
		_esmaecendo = false
		var passo := delta / ESMAECER
		for c: Vector2i in _nivel_mascara:
			var v: float = _nivel_mascara[c]
			if v < 1.0:
				_nivel_mascara[c] = minf(1.0, v + passo)
				_esmaecendo = true
				mudou = true
	if not mudou:
		return
	var dados := PackedByteArray()
	dados.resize(MASCARA * MASCARA)
	for c: Vector2i in _nivel_mascara:
		var t := c - origem
		if t.x >= 0 and t.y >= 0 and t.x < MASCARA and t.y < MASCARA:
			dados[t.y * MASCARA + t.x] = roundi(float(_nivel_mascara[c]) * 255.0)
	_mascara_img.set_data(MASCARA, MASCARA, false, Image.FORMAT_R8, dados)
	_mascara_tex.update(_mascara_img)
	if origem != _mascara_origem:
		_mascara_origem = origem
		_mat.set_shader_parameter(&"mascara_origem", Vector2(origem))


func _pintar() -> void:
	var preset: FogPreset = ChunkManager._preset if ChunkManager._preset != null \
		else Settings.fog_preset()
	# O ar e o do Environment (FogController, nevoa exponencial): o mesmo que
	# cobre os chunks, e por isso perto e longe casam na borda.
	var dia := preset.hora_do_dia == FogPreset.HoraDoDia.DIA
	_mat.set_shader_parameter(&"noite", 0.0 if dia else 1.0)
	_mat.set_shader_parameter(&"janelas_acesas", 0.0 if dia else ACESAS_NOITE)


# --- fios ---------------------------------------------------------------------

func _laco_plantas() -> void:
	_abrir_cache()
	var gravado := Time.get_ticks_msec()
	while true:
		_sinal_plantas.wait()
		# Primeiro o disco: toda regiao que a fila toca.
		_trava.lock()
		var copia := _fila_plantas.duplicate()
		_trava.unlock()
		var regioes := {}
		for c: Vector2i in copia:
			regioes[_regiao_de(c)] = true
		for r: Vector2i in regioes:
			if _sair:
				break
			_ler_regiao(r)
		_cache_lido = true
		while not _sair:
			_trava.lock()
			var tem := not _fila_plantas.is_empty()
			var c := Vector2i.ZERO
			if tem:
				c = _fila_plantas.pop_front()
			_trava.unlock()
			if not tem:
				break
			if _rapido:
				# A fila volta quando o carro parar (_replanejar_plantas).
				break
			_ler_regiao(_regiao_de(c))
			_trava.lock()
			var ja := _plantas.has(c)
			_trava.unlock()
			if ja:
				continue
			var planta := HorizonteDados.amostrar(c.x, c.y)
			_trava.lock()
			if not _plantas.has(c):
				_plantas[c] = planta
				medida_plantas_exatas += 1
			_regioes_sujas[_regiao_de(c)] = true
			_trava.unlock()
			if Time.get_ticks_msec() - gravado > GRAVAR_A_CADA * 1000.0:
				_gravar_regioes()
				gravado = Time.get_ticks_msec()
		_gravar_regioes()
		if _sair:
			return


# --- cache em disco (so o fio de plantas) -------------------------------------

static func _regiao_de(c: Vector2i) -> Vector2i:
	return Vector2i(floori(float(c.x) / REGIAO), floori(float(c.y) / REGIAO))


## A pasta da versao atual do gerador; apaga as de versoes velhas.
##
## `--horizonte-cache-fixo` (bancada): a pasta CACHE_FIXO, sem hash e nunca
## apagada. Com outras frentes salvando o gerador a cada minuto, a versao mudava
## entre duas rodadas e a medida pegava o preenchimento, e nao o regime.
func _abrir_cache() -> void:
	var versao := CACHE_FIXO
	if not OS.get_cmdline_user_args().has("--horizonte-cache-fixo"):
		var partes := PackedStringArray()
		for fonte: String in FONTES_DO_GERADOR:
			_hashes(fonte, partes)
		partes.sort()
		partes.append("grade %d" % VERSAO_GRADE)
		versao = "\n".join(partes).md5_text().left(12)
	_pasta_cache = CACHE.path_join(versao)
	DirAccess.make_dir_recursive_absolute(_pasta_cache)
	var raiz := DirAccess.open(CACHE)
	if raiz != null:
		for d: String in raiz.get_directories():
			if d != versao and d != CACHE_FIXO:
				var velha := DirAccess.open(CACHE.path_join(d))
				if velha != null:
					for f: String in velha.get_files():
						velha.remove(f)
				raiz.remove(d)


static func _hashes(caminho: String, saida: PackedStringArray) -> void:
	if caminho.get_extension() != "":
		if FileAccess.file_exists(caminho):
			saida.append("%s %s" % [caminho, FileAccess.get_md5(caminho)])
		return
	var d := DirAccess.open(caminho)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdc") or f.ends_with(".remap"):
			_hashes(caminho.path_join(f), saida)
	for sub: String in d.get_directories():
		if sub != "horizonte":
			_hashes(caminho.path_join(sub), saida)


func _arquivo_da_regiao(r: Vector2i) -> String:
	return _pasta_cache.path_join("r_%d_%d.bin" % [r.x, r.y])


func _ler_regiao(r: Vector2i) -> void:
	if _regioes_lidas.has(r):
		return
	_regioes_lidas[r] = true
	var arq := _arquivo_da_regiao(r)
	if not FileAccess.file_exists(arq):
		return
	var bruto := FileAccess.get_file_as_bytes(arq)
	if bruto.size() < 8:
		return
	var tamanho := bruto.decode_u32(0)
	var dados: Variant = bytes_to_var(bruto.slice(4).decompress(tamanho,
		FileAccess.COMPRESSION_ZSTD))
	if not dados is Dictionary:
		return
	_trava.lock()
	for c: Variant in dados:
		if c is Vector2i and not _plantas.has(c):
			_plantas[c] = dados[c]
	_trava.unlock()


func _gravar_regioes() -> void:
	if _pasta_cache.is_empty():
		return
	_trava.lock()
	var sujas := _regioes_sujas.keys()
	_regioes_sujas.clear()
	_trava.unlock()
	for r: Vector2i in sujas:
		var dados := {}
		_trava.lock()
		for j in REGIAO:
			for i in REGIAO:
				var c := Vector2i(r.x * REGIAO + i, r.y * REGIAO + j)
				if _plantas.has(c):
					dados[c] = _plantas[c]
		_trava.unlock()
		var bruto := var_to_bytes(dados)
		var saida := PackedByteArray()
		saida.resize(4)
		saida.encode_u32(0, bruto.size())
		saida.append_array(bruto.compress(FileAccess.COMPRESSION_ZSTD))
		var f := FileAccess.open(_arquivo_da_regiao(r), FileAccess.WRITE)
		if f != null:
			f.store_buffer(saida)
			f.close()


## A grade G x G da celula, as lampadas dela (locais ao canto), quantos postes
## cada lampada representa e quantas plantas exatas entraram.
func _grade(k: Vector3i) -> Array:
	var n := _lado_chunks(k.x)
	var origem := Vector2i(k.y * n, k.z * n)
	var canto := Vector3(origem.x * TAM, 0.0, origem.y * TAM)
	var g := HorizonteMalha.G
	var grade := PackedByteArray()
	grade.resize(g * g * HorizonteDados.BYTES)
	var lampadas := PackedVector3Array()
	var exatas := 0
	var peso := 1.0
	if n <= g:
		# Um ou mais pontos por chunk.
		var lc := g / n
		for j in n:
			for i in n:
				var c := origem + Vector2i(i, j)
				var planta := PackedByteArray()
				if k.x < NIVEL_EXATO:
					_trava.lock()
					planta = _plantas.get(c, PackedByteArray())
					_trava.unlock()
				if planta.is_empty():
					planta = HorizonteDados.aproximar(c.x, c.y, maxi(lc, LADO_APROX_MIN))
				else:
					exatas += 1
				planta = HorizonteDados.reduzir(planta, lc, k.x >= NIVEL_MEDIA)
				_copiar(planta, lc, grade, i * lc, j * lc)
				var l := HorizonteDados.lampada(c.x, c.y)
				if l != Vector3.INF:
					lampadas.append(l - canto)
	else:
		# Um chunk sorteado em cada quadrado de m x m: a 6 km a quadra nao se
		# le, a textura da cidade sim. A lampada dele vale por m.
		var m := n / g
		peso = float(m)
		for pz in g:
			for px in g:
				var h := absi(hash(Vector3i(k.x, origem.x + px * m, origem.y + pz * m)))
				var c := origem + Vector2i(px * m + h % m, pz * m + (h / m) % m)
				var planta := HorizonteDados.reduzir(
					HorizonteDados.aproximar(c.x, c.y, LADO_APROX_MIN), 1, true)
				_copiar(planta, 1, grade, px, pz)
				var l := HorizonteDados.lampada(c.x, c.y)
				if l != Vector3.INF:
					lampadas.append(l - canto)
	return [grade, lampadas, peso, exatas]


static func _copiar(planta: PackedByteArray, lado: int, grade: PackedByteArray, ox: int,
		oz: int) -> void:
	var g := HorizonteMalha.G
	var linha := lado * HorizonteDados.BYTES
	for pz in lado:
		var de := pz * linha
		var para := ((oz + pz) * g + ox) * HorizonteDados.BYTES
		for b in linha:
			grade[para + b] = planta[de + b]


func _arquivo_da_celula(k: Vector3i) -> String:
	return _pasta_cache.path_join("c_%d_%d_%d.bin" % [k.x, k.y, k.z])


func _grade_do_disco(k: Vector3i) -> Array:
	if k.x < NIVEL_EXATO or _pasta_cache.is_empty():
		return []
	var arq := _arquivo_da_celula(k)
	if not FileAccess.file_exists(arq):
		return []
	var bruto := FileAccess.get_file_as_bytes(arq)
	if bruto.size() < 8:
		return []
	var dados: Variant = bytes_to_var(bruto.slice(4).decompress(bruto.decode_u32(0),
		FileAccess.COMPRESSION_ZSTD))
	if not dados is Array or (dados as Array).size() != 4:
		return []
	medida_celulas_do_disco += 1
	return dados


func _grade_para_o_disco(k: Vector3i, g: Array) -> void:
	if _pasta_cache.is_empty():
		return
	var bruto := var_to_bytes(g)
	var saida := PackedByteArray()
	saida.resize(4)
	saida.encode_u32(0, bruto.size())
	saida.append_array(bruto.compress(FileAccess.COMPRESSION_ZSTD))
	var f := FileAccess.open(_arquivo_da_celula(k), FileAccess.WRITE)
	if f != null:
		f.store_buffer(saida)
		f.close()


## Pausa do fio de malhas andando rapido; acaba antes se o carro parar, se o
## jogo sair ou se chegar celula perto na fila.
func _descansar(ms: int) -> void:
	var fim := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < fim and _rapido and not _sair:
		_trava.lock()
		var perto := false
		for k: Vector3i in _fila_malhas:
			if k.x < NIVEL_MEDIA:
				perto = true
				break
		_trava.unlock()
		if perto:
			return
		OS.delay_msec(50)


func _laco_malhas() -> void:
	while true:
		_sinal_malhas.wait()
		while not _sair:
			_trava.lock()
			var tem := not _fila_malhas.is_empty()
			var k := Vector3i.ZERO
			if tem:
				k = _fila_malhas.pop_front()
				if _rapido and k.x >= NIVEL_MEDIA:
					# Andando rapido, a perto passa na frente da distante.
					for i in _fila_malhas.size():
						var perto: Vector3i = _fila_malhas[i]
						if perto.x < NIVEL_MEDIA:
							_fila_malhas[i] = k
							k = perto
							break
			_trava.unlock()
			if not tem:
				break
			var t0 := Time.get_ticks_usec()
			var g := _grade_do_disco(k)
			if g.is_empty():
				g = _grade(k)
				if k.x >= NIVEL_EXATO:
					_grade_para_o_disco(k, g)
			var malha := HorizonteMalha.montar(g[0], _passo(k.x), g[1], g[2],
				RECUO if k.x >= NIVEL_MEDIA else 0.0)
			var custo_ms := (Time.get_ticks_usec() - t0) / 1000.0
			_trava.lock()
			_prontas.append([k, malha, g[3]])
			medida_malha_ms.append(custo_ms)
			_trava.unlock()
			if _rapido and k.x >= NIVEL_MEDIA:
				_descansar(mini(int(custo_ms * DESCANSO_LONGE), DESCANSO_MAX_MS))
		if _sair:
			return
