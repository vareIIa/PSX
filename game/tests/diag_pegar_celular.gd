## Diagnostico da pegada do celular no susto da estrada (Fase 1: so MEDE, nao
## conserta nada). Ligado por `--diag-pegar` (gancho de tres linhas no fim de
## `MotoristaCena.montar`), carregado pelo caminho, sem `class_name` (nao pede
## import).
##
## O que faz, da batida ate o celular de volta na leitura:
##   - refaz, fora do motor, a MESMA malha que o `BracoVivo.refazer` desenhou no
##     quadro (mesmas funcoes da `MaoPosada`/`MaoModelada`, com o `_t`, o tremor
##     e a pose viva do braco), mas separada por peca (palma, cada dedo,
##     polegar, antebraco, esporao alem do cotovelo, braco de cima). Confere a
##     copia contra o `punho_montado`/`cotovelo_montado` e o numero de vertices
##     da malha de verdade;
##   - SONDAS: (a) vertice do braco dentro de cada solido da cabine (painel,
##     centro, console, tunel, cambio, freio, volante, coluna, bancos, fivelas,
##     piso, tapete, corta-fogo, porta), e o solido fino (haste do cambio, aro)
##     dentro das capsulas do braco; (b) vertice da mao dentro do aparelho e a
##     folga de cada dedo ate ele; (c) polegar na frente da tela e quanto da tela
##     ele tapa visto da lente; (d) o ponto mais baixo do aparelho contra o chao
##     e o aparelho dentro dos solidos na queda; (e) salto por quadro do aparelho
##     e da mao (e da mao no espaco do aparelho); (f) braco contra braco
##     (capsula contra capsula); (g) folga ate a fivela do cinto (a faixa nao
##     existe na cabine); o zoom da tela do app e os angulos da pose desenhada;
##   - CONTROLE POSITIVO de cada sonda, impresso no comeco: um caso montado para
##     falhar tem de falhar; e o de PIXEL: as silhuetas dos casos montados,
##     contadas pela cor (magenta, azul, branco), tem de mostrar a cor;
##   - SILHUETAS: SubViewports no mesmo World3D (lado, cima, 3/4 de fora, de
##     frente do porta-luvas, a lente so com as copias, e tres no espaco do
##     aparelho: frente, lado e topo, com ele translucido) que so veem copias
##     chapadas em camadas proprias: braco vermelho, mao laranja, polegar
##     amarelo, maos do aro em tom de pele, fone verde, solidos translucidos;
##     vertice dentro de solido em MAGENTA, dentro do fone em AZUL, dentro do
##     outro braco em BRANCO (os tres tambem num passe de raio X, sem teste de
##     profundidade), polegar sobre a tela em ciano;
##   - uma linha JSON por quadro (`diag.jsonl`) e, a cada captura, o quadro da
##     lente em 4K (`lente/`), as silhuetas (`sil/`), a textura da tela do app
##     (`tela/`) e uma copia pequena para o mosaico (`r/`, no formato do
##     `tools/mosaico_rajada.py`).
##
## Rode com `--fixed-fps 60` (antes do `--`): o jogo anda 1/60 s por quadro,
## seja qual for o custo da medida. No trecho `DENSO` todo passo e medido e
## capturado, e o tempo fica parado (`Engine.time_scale` quase zero) nos quadros
## em que as silhuetas ainda estao sendo desenhadas.
##
## O estado medido e o do quadro DESENHADO: a medida roda no `process_frame` do
## quadro seguinte (antes de qualquer `_process`), quando tudo o que o quadro N
## mexeu (inclusive tweens, que andam depois do `_process`) ja foi desenhado, e a
## textura da janela ainda e a do quadro N. `q` no log e esse N.
extends Node3D

## Relogio da cena (`AberturaEstrada._relogio_cena`): de onde a onde medir.
const JANELA := Vector2(13.0, 30.5)
## Camadas das copias: bracos e fone, solidos, e o que cerca a vista de frente.
const L_FANT := 1 << 13
const L_OBST := 1 << 14
const L_PAINEL := 1 << 15
## As copias dos bracos numa camada propria: a vista "lente_tela" (so o fone)
## nao as ve, e e ela que da a area inteira da tela para a regua de pixel.
const L_BRACO := 1 << 12
## O aparelho translucido com as arestas (so as vistas no espaco dele), e o
## raio X: os triangulos do braco que entram em solido ou no fone, sem teste de
## profundidade, por cima de tudo.
const L_FONE_T := 1 << 16
const L_XRAY := 1 << 19
const SIL := Vector2i(960, 540)
const SIL_FONE := Vector2i(720, 720)
## A lente copiada, na largura da regua de pixel.
const SIL_LENTE_L := 1920
## Trecho denso: cada passo de 1/60 s e medido E capturado (lente 4K e todas as
## silhuetas). Com `--fixed-fps 60` o passo do jogo nao depende do relogio da
## parede; enquanto as silhuetas nao voltam, o tempo do jogo fica parado
## (`Engine.time_scale` quase zero, como o `--sonda-gpu` da abertura: zero da
## NaN no `corpo.gd` e na `lente.gd`), e so um passo cheio anda por vez.
const DENSO := Vector2(14.3, 24.2)
const ESCALA_PARADA := 0.0001
## Um passo que andou menos que isto no relogio da cena e quadro parado.
const PASSO_MIN := 0.002
const COR_BRACO_X := Color(1.0, 1.0, 1.0)
const COR_ARO_MAO := Color(0.95, 0.70, 0.35)
const COR_ARO_BRACO := Color(0.75, 0.30, 0.30)
## Quanto a mais que o pior anterior abre uma captura extra (cm; mm; %).
const LIMIAR_CM := 0.3
const LIMIAR_MM := 1.0
const LIMIAR_PCT := 2.0
## Grade da cobertura da tela (celulas de ~2 mm).
const COB_NX := 25
const COB_NY := 37
## Cores das copias.
const COR_BRACO := Color(0.80, 0.12, 0.10)
const COR_ANTEBRACO := Color(0.95, 0.32, 0.14)
const COR_ESPORAO := Color(0.50, 0.06, 0.06)
const COR_MAO := Color(1.0, 0.58, 0.12)
const COR_POLEGAR := Color(1.0, 0.88, 0.10)
const COR_DENTRO := Color(1.0, 0.0, 1.0)
const COR_NO_FONE := Color(0.25, 0.35, 1.0)
const COR_SOBRE_TELA := Color(0.0, 1.0, 1.0)
const COR_FONE := Color(0.15, 0.80, 0.30)
const COR_TELA := Color(0.60, 1.0, 0.65)
const COR_GRUPO := {
	"painel": Color(0.62, 0.62, 0.68), "console": Color(0.50, 0.56, 0.74),
	"marcha": Color(0.35, 0.72, 1.0), "freio": Color(0.50, 0.60, 0.80),
	"volante": Color(0.66, 0.52, 0.92), "banco_carona": Color(0.45, 0.62, 0.55),
	"banco_motorista": Color(0.42, 0.55, 0.50), "cinto": Color(0.95, 0.92, 0.50),
	"piso": Color(0.38, 0.38, 0.40), "corta_fogo": Color(0.40, 0.40, 0.46),
	"porta": Color(0.40, 0.40, 0.46),
}
const LUZ := Vector3(0.35, 0.80, 0.50)

var mot: MotoristaCena
var cab: CarroCabine
var it: CabineInterior
var abertura: Node
var pasta := ""
var _pronto := false
var _falhou_preparo := 0
var solidos: Array[Dictionary] = []
var _amostras: Array[Dictionary] = []
var _jsonl: FileAccess
var _tarefas: Array[int] = []
var _vistas: Array[Dictionary] = []
var _fant: Dictionary = {}
var _fant_fone: MeshInstance3D
var _fant_tela: MeshInstance3D
var _obst_fant: Array[Dictionary] = []
var _prox_captura: float = 0.0
var _pend_sil: Dictionary = {}
var _anterior: Dictionary = {}
var _hist_fone: Array[float] = []
var _pior: Dictionary = {}
var _ult_evento: int = -100
var _n_quadros: int = 0
var _n_capturas: int = 0
var _fim := false
var _estado_ant := ""
var _contorno_fone := PackedVector3Array()
var _piso: float = 0.0
var _olho := Vector3.ZERO
var _tapetes: Array[Dictionary] = []
var _mat_braco: StandardMaterial3D
var _mat_obst: StandardMaterial3D
var _mat_linha: StandardMaterial3D
var _t_medida_ms: float = 0.0
var _n_atrasos: int = 0
## A raiz das copias, solta do carro (`top_level`): recebe a pose do carro do
## quadro medido na captura e fica parada ate o SubViewport desenhar. Presa ao
## carro, a copia andava com o carro no quadro seguinte e a camera da vista nao.
var _raiz_fant: Node3D
var _fant_fone_t: MeshInstance3D
var _xray: Dictionary = {}
var _aro_fant: Array[MeshInstance3D] = []
var _aro_cache: Dictionary = {}
var _mat_xray: StandardMaterial3D
var _mat_fone_t: StandardMaterial3D
## O relogio da cena do ultimo passo medido: quadro com o relogio parado nao e
## estado novo.
var _t_medido: float = -1.0
var _parado := false
var _n_perdidas: int = 0
var _n_passos_denso: int = 0
var _controle_fila: Array = []
var _controle_linhas: Array = []
## As medidas da cabine COM as chaves que so existem enquanto ela e construida
## (`_perfil`, `_centro`, `_porta_trecos`): a cabine da cena vem do cache
## (`CabineInterior._prontos`) e o `g` dela nao as tem. Refeitas num interior
## de rascunho, fora da arvore (`_construir` e so dado).
var _g: Dictionary = {}


func _ready() -> void:
	mot = get_parent() as MotoristaCena
	# Tudo aqui e teleportado a cada captura: interpolado, a copia saia no meio
	# do caminho entre a captura anterior e esta (FTI ligada na arvore,
	# `suavidade.gd`).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--diag-pasta="):
			pasta = a.trim_prefix("--diag-pasta=")
	if pasta.is_empty():
		pasta = OS.get_user_data_dir().path_join("diag_pegar")
	for sub: String in ["lente", "sil", "r", "controle", "tela"]:
		DirAccess.make_dir_recursive_absolute(pasta.path_join(sub))
	_jsonl = FileAccess.open(pasta.path_join("diag.jsonl"), FileAccess.WRITE)
	get_tree().process_frame.connect(_quadro)
	_raiz_fant = Node3D.new()
	_raiz_fant.name = "Copias"
	_raiz_fant.top_level = true
	add_child(_raiz_fant)
	print("[diag] ligado; pasta=%s (rode com --fixed-fps 60: o passo do trecho denso sai no dt_cena do log)" % pasta)


func _exit_tree() -> void:
	if _parado:
		Engine.time_scale = 1.0
		_parado = false


# --- preparo -----------------------------------------------------------------

func _preparar() -> bool:
	if mot == null or mot._carro == null or mot._carro.cabine == null:
		return false
	cab = mot._carro.cabine
	it = cab.interior()
	if it == null or not it.pronto() or it.alavanca == null or cab.pivo_do_volante() == null:
		return false
	abertura = _achar_abertura()
	var tmp := CabineInterior.new()
	tmp.g = it.g.duplicate()
	tmp._construir()
	_g = tmp.g
	tmp.free()
	_olho = cab.olho()
	_piso = cab.piso_da_cabine()
	_montar_solidos()
	_montar_contorno_fone()
	_montar_materiais()
	_montar_fantasmas_obstaculos()
	_montar_vistas()
	_controles()
	print("[diag] pronto: %d solidos, abertura=%s, olho=%s piso=%.3f" % [solidos.size(),
		abertura != null, _olho, _piso])
	var cadeia := ""
	var n: Node = mot
	while n != null:
		cadeia += " %s:%d%s" % [n.name, n.physics_interpolation_mode,
			"(interp)" if n.is_physics_interpolated_and_enabled() else ""]
		n = n.get_parent()
	print("[diag] FTI arvore=%s cadeia do motorista:%s" % [get_tree().physics_interpolation, cadeia])
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		print("[diag] camera %s interp=%s" % [cam.get_path(), cam.is_physics_interpolated_and_enabled()])
	return true


func _achar_abertura() -> Node:
	var pilha: Array[Node] = [get_tree().root]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		var s: Script = n.get_script()
		if s != null and s.get_global_name() == &"AberturaEstrada":
			return n
		for c: Node in n.get_children():
			pilha.append(c)
	return null


func _relogio() -> float:
	if abertura == null or not is_instance_valid(abertura):
		return -1.0
	return float(abertura.get("_relogio_cena"))


# --- solidos da cabine ---------------------------------------------------------
## No espaco da MotoristaCena (= da cabine = do carro): -Z frente, +X carona.
## As medidas saem das mesmas contas das pecas (`cabine_painel.gd`,
## `cabine_console.gd`, `cabine_bancos.gd`, `carro_cabine.gd`,
## `volante_esportivo.gd`); o cambio, o freio e o volante andam, e sao relidos
## dos nos a cada quadro.

func _obb(nome: String, grupo: String, c: Vector3, b: Basis, h: Vector3, camada: int = L_OBST) -> void:
	var bb := b.orthonormalized()
	solidos.append({"nome": nome, "grupo": grupo, "tipo": &"obb", "c": c, "b": bb,
		"bt": bb.transposed(), "h": h, "camada": camada, "aabb": _aabb_obb(c, bb, h)})


static func _aabb_obb(c: Vector3, b: Basis, h: Vector3) -> AABB:
	var e := Vector3(absf(b.x.x) * h.x + absf(b.y.x) * h.y + absf(b.z.x) * h.z,
		absf(b.x.y) * h.x + absf(b.y.y) * h.y + absf(b.z.y) * h.z,
		absf(b.x.z) * h.x + absf(b.y.z) * h.y + absf(b.z.z) * h.z)
	return AABB(c - e, e * 2.0)


func _montar_solidos() -> void:
	var g: Dictionary = _g
	var topo: float = g["topo"]
	var zl: float = g["lip_z"]
	var zf: float = g["z_frente"]
	var zt: float = g["z_tras"]
	var bancos: Vector2 = g["bancos"]
	var pf: Dictionary = g["_perfil"]
	var pts: Array[Vector2] = pf["pts"]
	var w := it.parede(topo, topo, zl) - 0.012
	# O painel: o perfil (z, y) de `cabine_painel.gd` fechado ate o corta-fogo,
	# extrudado de parede a parede. So as arestas do perfil sao superficie.
	var poly := PackedVector2Array()
	for q: Vector2 in pts:
		poly.append(q)
	var n_real := poly.size() - 1
	poly.append(Vector2(zf - 0.05, pts[pts.size() - 1].y))
	poly.append(Vector2(zf - 0.05, pts[0].y + 0.02))
	var ymin := INF
	var ymax := -INF
	var zmin := INF
	var zmax := -INF
	for q: Vector2 in poly:
		ymin = minf(ymin, q.y)
		ymax = maxf(ymax, q.y)
		zmin = minf(zmin, q.x)
		zmax = maxf(zmax, q.x)
	solidos.append({"nome": "painel", "grupo": "painel", "tipo": &"prisma", "poly": poly,
		"n_real": n_real, "w": w, "camada": L_PAINEL,
		"aabb": AABB(Vector3(-w, ymin, zmin), Vector3(2.0 * w, ymax - ymin, zmax - zmin))})
	# O centro do painel (radio e ar).
	var c: Dictionary = g["_centro"]
	var base := CabinePainel._centro_xf(it, pf)
	var y0: float = c["y0"]
	var y1: float = c["y1"]
	var meio := CabinePainel._no_centro(base, 0.0, (y0 + y1) * 0.5, 0.0)
	_obb("centro_radio", "painel", meio * Vector3(0.0, 0.0, -0.045), meio.basis,
		Vector3(float(c["meia"]), (y0 - y1) * 0.5, 0.045), L_PAINEL)
	# A frente do console e o tunel.
	var pt: Dictionary = g["_porta_trecos"]
	var hw: float = c["meia"]
	var y_prat: float = pt["y_prat"]
	var z_fundo: float = pt["z_fundo"]
	var z_fr_c: float = c["z_frente"]
	_obb("console_frente", "console", Vector3(0.0, (_piso - 0.02 + y_prat - 0.014) * 0.5,
		(z_fundo - 0.03 + z_fr_c + 0.03) * 0.5), Basis(),
		Vector3(hw, (y_prat - 0.014 - _piso + 0.02) * 0.5, (z_fr_c - z_fundo + 0.06) * 0.5))
	var cw := clampf(bancos.x - bancos.y * 0.5 - 0.014, 0.075, 0.125)
	var z_fim := _olho.z + 0.52
	_obb("tunel", "console", Vector3(0.0, _piso + 0.105, (z_fr_c + 0.07 + z_fim) * 0.5), Basis(),
		Vector3(cw + 0.004, 0.12, (z_fim - z_fr_c - 0.07) * 0.5))
	# O cambio (no Alavanca: coifa em cone, haste, pomo) e a moldura da coifa.
	var z_cambio := _olho.z - 0.13
	solidos.append({"nome": "moldura_coifa", "grupo": "marcha", "tipo": &"cilindro_y",
		"xf": Transform3D(Basis(), Vector3(0.0, _piso + 0.200, z_cambio)), "r": 0.069,
		"y0": -0.002, "y1": 0.006, "no": null, "camada": L_OBST, "aabb": AABB()})
	solidos.append({"nome": "coifa", "grupo": "marcha", "tipo": &"coifa", "xf": Transform3D(),
		"no": it.alavanca, "camada": L_OBST, "aabb": AABB()})
	solidos.append({"nome": "haste", "grupo": "marcha", "tipo": &"capsula_local",
		"xf": Transform3D(), "a": Vector3.ZERO, "b": Vector3(0.0, 0.197, 0.0), "r": 0.0064,
		"no": it.alavanca, "camada": L_OBST, "aabb": AABB()})
	solidos.append({"nome": "pomo", "grupo": "marcha", "tipo": &"elipsoide", "xf": Transform3D(),
		"centro": Vector3(0.0, 0.215, 0.0), "semi": Vector3(0.0215, 0.026, 0.0215),
		"no": it.alavanca, "camada": L_OBST, "aabb": AABB()})
	# O freio de mao (no FreioDeMao).
	if it.freio != null:
		solidos.append({"nome": "freio_de_mao", "grupo": "freio", "tipo": &"obb_local",
			"xf": Transform3D(), "lc": Vector3(0.0, 0.006, 0.16), "h": Vector3(0.017, 0.018, 0.10),
			"no": it.freio, "camada": L_OBST, "aabb": AABB()})
	# Os bancos: assento, base, encosto, encosto de cabeca e a fivela do cinto.
	var meia := bancos.y * 0.5
	var tampo := CabineBancos.TAMPO
	for lado: float in [1.0, -1.0]:
		var nome := "carona" if lado > 0.0 else "motorista"
		var grupo := "banco_" + nome
		var onde := Vector3(lado * bancos.x, _piso, _olho.z + CabineBancos.ASSENTO_Z)
		var ab := Basis(Vector3.RIGHT, deg_to_rad(3.0))
		_obb(nome + "_assento", grupo, onde + ab * Vector3(0.0, (0.135 + tampo) * 0.5, 0.0), ab,
			Vector3(meia, (tampo - 0.135) * 0.5, 0.235))
		_obb(nome + "_base", grupo, onde + Vector3(0.0, 0.10, -0.01), Basis(),
			Vector3(meia - 0.035, 0.055, 0.205))
		var dob := onde + Vector3(0.0, tampo - 0.06, 0.225)
		var eb := Basis(Vector3.RIGHT, deg_to_rad(CabineBancos.ENCOSTO_INCLINACAO))
		var alt := CabineBancos.ENCOSTO_ALTURA
		_obb(nome + "_encosto", grupo, dob + eb * Vector3(0.0, alt * 0.5, 0.005), eb,
			Vector3(meia, alt * 0.5 + 0.01, 0.075))
		_obb(nome + "_cabeca", grupo, dob + eb * Vector3(0.0, alt + 0.075, 0.012), eb,
			Vector3(minf(meia * 0.56, 0.135), 0.072, 0.048))
		_obb(nome + "_fivela", "cinto", onde + Vector3(-lado * (meia + 0.018), tampo - 0.02, 0.17),
			Basis(Vector3.RIGHT, deg_to_rad(-15.0)), Vector3(0.012, 0.035, 0.018))
	# O volante (no Volante: aro em toro no plano XY, cubo, tres raios) e a coluna.
	var pv := cab.pivo_do_volante()
	solidos.append({"nome": "volante_aro", "grupo": "volante", "tipo": &"toro", "xf": Transform3D(),
		"R": CarroCabine.VOLANTE_RAIO, "r": VolanteEsportivo.TUBO, "no": pv, "camada": L_OBST,
		"aabb": AABB()})
	solidos.append({"nome": "volante_cubo", "grupo": "volante", "tipo": &"cilindro_z",
		"xf": Transform3D(), "r": VolanteEsportivo.CUBO_RAIO, "z0": -VolanteEsportivo.PRATO,
		"z1": VolanteEsportivo.BUZINA_ALTURA, "no": pv, "camada": L_OBST, "aabb": AABB()})
	for k in VolanteEsportivo.RAIOS_GRAUS.size():
		var ang := deg_to_rad(float(VolanteEsportivo.RAIOS_GRAUS[k]))
		var dirr := Vector3(cos(ang), sin(ang), 0.0)
		var a := dirr * VolanteEsportivo.RAIO_NASCE + Vector3(0.0, 0.0, -VolanteEsportivo.PRATO * 0.85)
		var b := dirr * (CarroCabine.VOLANTE_RAIO - 0.012) + Vector3(0.0, 0.0, -0.004)
		var ex := (b - a).normalized()
		var ey := Vector3(-dirr.y, dirr.x, 0.0)
		var ez := ex.cross(ey).normalized()
		solidos.append({"nome": "volante_raio%d" % k, "grupo": "volante", "tipo": &"obb_local",
			"xf": Transform3D(), "lc": (a + b) * 0.5, "lb": Basis(ex, ey, ez),
			"h": Vector3((b - a).length() * 0.5, VolanteEsportivo.RAIO_LARGO_CUBO * 0.85,
				VolanteEsportivo.RAIO_CHAPA * 0.5 + 0.002), "no": pv, "camada": L_OBST,
			"aabb": AABB()})
	var w0: Vector3 = g["volante"]
	var exf := Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(float(g["volante_incl"]))), w0)
	_obb("coluna", "volante", exf * Vector3(0.0, -0.006, -0.226), exf.basis,
		Vector3(0.060, 0.056, 0.134))
	# Piso, tapetes, corta-fogo.
	var z0 := maxf(zf + 0.10, _olho.z - 0.72)
	var z1 := _olho.z - 0.02
	var meia_x := minf(0.20, bancos.y * 0.5)
	for lado: float in [1.0, -1.0]:
		var x := lado * bancos.x
		var wt := it.parede(_piso + 0.01, _piso + 0.02, (z0 + z1) * 0.5)
		var xm := clampf(x, -(wt - meia_x - 0.01), wt - meia_x - 0.01)
		var nome := "tapete_carona" if lado > 0.0 else "tapete_motorista"
		_obb(nome, "piso", Vector3(xm, _piso + 0.005, (z0 + z1) * 0.5), Basis(),
			Vector3(meia_x, 0.005, (z1 - z0) * 0.5))
		_tapetes.append({"x0": xm - meia_x, "x1": xm + meia_x, "z0": z0, "z1": z1,
			"topo": _piso + 0.010})
	_obb("piso", "piso", Vector3(0.0, _piso - 0.05, (zf + zt) * 0.5), Basis(),
		Vector3(0.9, 0.05, (zt - zf) * 0.5))
	_obb("corta_fogo", "corta_fogo", Vector3(0.0, _piso + 0.5, zf - 0.05), Basis(),
		Vector3(0.9, 0.5, 0.05), L_PAINEL)
	# As portas: dentro do forro e x alem da parede da casca naquela altura e z.
	for lado: float in [1.0, -1.0]:
		solidos.append({"nome": "porta_carona" if lado > 0.0 else "porta_motorista",
			"grupo": "porta", "tipo": &"porta", "lado": lado, "camada": 0,
			"aabb": AABB(Vector3(0.62 if lado > 0.0 else -0.98, _piso, zf),
				Vector3(0.36, 1.0, zt - zf))})
	_atualizar_solidos()
	# Amostras dos solidos finos, para o teste contrario (o solido dentro do
	# braco): a haste do cambio e o aro do volante sao mais finos que o braco,
	# e nenhum vertice do braco cai dentro deles mesmo com a haste atravessando
	# o antebraco.
	_montar_amostras()


## Relê os nos que andam (cambio, freio, volante) e refaz os AABB.
func _atualizar_solidos() -> void:
	var inv := mot.global_transform.affine_inverse()
	for s: Dictionary in solidos:
		var no: Node3D = s.get("no")
		if no != null and is_instance_valid(no):
			s["xf"] = inv * no.global_transform
			s["xfi"] = (s["xf"] as Transform3D).affine_inverse()
		elif s.has("xf"):
			s["xfi"] = (s["xf"] as Transform3D).affine_inverse()
		match s["tipo"]:
			&"coifa":
				s["aabb"] = _aabb_local(s["xf"], AABB(Vector3(-0.057, -0.024, -0.057),
					Vector3(0.114, 0.209, 0.114)))
			&"capsula_local":
				var r: float = s["r"]
				s["aabb"] = _aabb_local(s["xf"], AABB(Vector3(-r, -r, -r),
					Vector3(2.0 * r, 0.197 + 2.0 * r, 2.0 * r)))
			&"elipsoide":
				var sm: Vector3 = s["semi"]
				s["aabb"] = _aabb_local(s["xf"], AABB((s["centro"] as Vector3) - sm, sm * 2.0))
			&"obb_local":
				var lb: Basis = s.get("lb", Basis())
				var xf: Transform3D = s["xf"]
				var b := (xf.basis * lb).orthonormalized()
				var c := xf * (s["lc"] as Vector3)
				s["c"] = c
				s["b"] = b
				s["bt"] = b.transposed()
				s["aabb"] = _aabb_obb(c, b, s["h"])
			&"toro":
				var rr: float = float(s["R"]) + float(s["r"])
				s["aabb"] = _aabb_local(s["xf"], AABB(Vector3(-rr, -rr, -float(s["r"])),
					Vector3(2.0 * rr, 2.0 * rr, 2.0 * float(s["r"]))))
			&"cilindro_z":
				var r: float = s["r"]
				s["aabb"] = _aabb_local(s["xf"], AABB(Vector3(-r, -r, float(s["z0"])),
					Vector3(2.0 * r, 2.0 * r, float(s["z1"]) - float(s["z0"]))))
			&"cilindro_y":
				var r: float = s["r"]
				s["aabb"] = _aabb_local(s["xf"], AABB(Vector3(-r, float(s["y0"]), -r),
					Vector3(2.0 * r, float(s["y1"]) - float(s["y0"]), 2.0 * r)))


static func _aabb_local(xf: Transform3D, a: AABB) -> AABB:
	return xf * a


func _montar_amostras() -> void:
	_amostras.clear()
	for s: Dictionary in solidos:
		if s["tipo"] == &"coifa":
			# O eixo do cambio inteiro, com o raio da peca naquela altura: a
			# coifa ate 0,185, a haste, o pomo.
			var pts := []
			var y := -0.02
			while y <= 0.240:
				pts.append([Vector3(0.0, y, 0.0), _raio_do_cambio(y)])
				y += 0.01
			_amostras.append({"nome": "cambio(eixo)", "grupo": "marcha", "solido": s,
				"local": pts})
		elif s["tipo"] == &"toro":
			var pts := []
			for k in 48:
				var a := TAU * float(k) / 48.0
				pts.append([Vector3(cos(a), sin(a), 0.0) * float(s["R"]), float(s["r"])])
			_amostras.append({"nome": "volante_aro", "grupo": "volante", "solido": s,
				"local": pts})
	# A borda do labio e do joelho do painel (linhas finas; o vertice do braco
	# pega o corpo do painel, isto pega o braco dobrado por cima da quina).
	var pf: Dictionary = _g["_perfil"]
	var pts2: Array[Vector2] = pf["pts"]
	var lab: Vector2 = pts2[7]
	var joe: Vector2 = pts2[int(pf["i_joelho"])]
	var bordas := []
	var x := -0.7
	while x <= 0.7:
		bordas.append([Vector3(x, lab.y, lab.x), 0.0])
		bordas.append([Vector3(x, joe.y, joe.x), 0.0])
		x += 0.02
	_amostras.append({"nome": "painel_bordas", "grupo": "painel", "solido": null,
		"local": bordas})


static func _raio_do_cambio(y: float) -> float:
	var r := 0.0
	if y >= -0.024 and y <= 0.185:
		var t := (y + 0.024) / 0.209
		r = maxf(r, lerpf(0.052, 0.0105, pow(t, 0.62)))
	if y >= 0.0 and y <= 0.197:
		r = maxf(r, 0.0064)
	var dy := (y - 0.215) / 0.026
	if absf(dy) < 1.0:
		r = maxf(r, 0.0215 * sqrt(1.0 - dy * dy))
	return r


## Profundidade de `p` (espaco da cabine) dentro do solido: positiva dentro,
## em metros, ate a superficie mais perto.
func _prof(s: Dictionary, p: Vector3) -> float:
	match s["tipo"]:
		&"obb":
			var q: Vector3 = (s["bt"] as Basis) * (p - (s["c"] as Vector3))
			var h: Vector3 = s["h"]
			return minf(h.x - absf(q.x), minf(h.y - absf(q.y), h.z - absf(q.z)))
		&"obb_local":
			var q: Vector3 = (s["bt"] as Basis) * (p - (s["c"] as Vector3))
			var h: Vector3 = s["h"]
			return minf(h.x - absf(q.x), minf(h.y - absf(q.y), h.z - absf(q.z)))
		&"prisma":
			var w: float = s["w"]
			var dx := w - absf(p.x)
			if dx <= 0.0:
				return dx
			var poly: PackedVector2Array = s["poly"]
			var p2 := Vector2(p.z, p.y)
			if not Geometry2D.is_point_in_polygon(p2, poly):
				return -0.001
			var dmin := dx
			var n_real: int = s["n_real"]
			for j in n_real:
				var cp := Geometry2D.get_closest_point_to_segment(p2, poly[j], poly[j + 1])
				dmin = minf(dmin, cp.distance_to(p2))
			return dmin
		&"coifa":
			var q: Vector3 = (s["xfi"] as Transform3D) * p
			if q.y < -0.024 or q.y > 0.185:
				return -0.001
			var t := (q.y + 0.024) / 0.209
			var r := lerpf(0.052, 0.0105, pow(t, 0.62))
			var rad := Vector2(q.x, q.z).length()
			return minf(r - rad, minf(q.y + 0.024, 0.185 - q.y))
		&"capsula_local":
			var q: Vector3 = (s["xfi"] as Transform3D) * p
			return float(s["r"]) - _ate_segmento(q, s["a"], s["b"])
		&"elipsoide":
			var q: Vector3 = (s["xfi"] as Transform3D) * p - (s["centro"] as Vector3)
			var sm: Vector3 = s["semi"]
			var l := (q / sm).length()
			return (1.0 - l) * minf(sm.x, minf(sm.y, sm.z))
		&"toro":
			var q: Vector3 = (s["xfi"] as Transform3D) * p
			var d := Vector2(Vector2(q.x, q.y).length() - float(s["R"]), q.z).length()
			return float(s["r"]) - d
		&"cilindro_z":
			var q: Vector3 = (s["xfi"] as Transform3D) * p
			return minf(float(s["r"]) - Vector2(q.x, q.y).length(),
				minf(q.z - float(s["z0"]), float(s["z1"]) - q.z))
		&"cilindro_y":
			var q: Vector3 = (s["xfi"] as Transform3D) * p
			return minf(float(s["r"]) - Vector2(q.x, q.z).length(),
				minf(q.y - float(s["y0"]), float(s["y1"]) - q.y))
		&"porta":
			var lado: float = s["lado"]
			var parede := it.parede(p.y, p.y, p.z)
			return p.x * lado - parede
	return -1.0


static func _ate_segmento(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-10), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- a copia do braco ----------------------------------------------------------

## A malha que o `BracoVivo.refazer` desenhou, refeita com o estado dele, por
## peca. Espelho de `BracoVivo.refazer` + `MaoPosada.montar` (working tree).
func _replica(b: BracoVivo) -> Dictionary:
	var pg: Dictionary = b.pegada
	var tt: float = b._t
	var d: Vector3 = pg["d"]
	var dorso: Vector3 = pg["dorso"]
	var treme := Vector3(sin(tt * 83.0) + 0.5 * sin(tt * 37.0),
		sin(tt * 71.0 + 1.3) + 0.5 * sin(tt * 29.0),
		sin(tt * 97.0 + 2.1)) * BracoVivo.TREMOR * b.tremor
	var o: Vector3 = (pg["o"] as Vector3) + treme
	var p := MaoPosada.viva(pg["pose"], tt,
		(BracoVivo.DEDOS_VIVOS + BracoVivo.DEDOS_COM_MEDO * clampf(b.tremor, 0.0, 1.5)) * b.dedos_vivos,
		b._semente)
	var punho := MaoPosada.punho_de(o, d, dorso)
	var cot := BracoVivo.cotovelo_entre(punho, b.ombro, b.polo)
	var r := _montar_braco(o, d, dorso, p, b.direita, cot, b.ombro, b._pele, b._manga, b._longa)
	r["o_pedido"] = pg["o"]
	r["tremor"] = b.tremor
	r["dedos_vivos"] = b.dedos_vivos
	return r


func _montar_braco(o: Vector3, d: Vector3, dorso: Vector3, p: Dictionary, direita: bool,
		cot: Vector3, ombro: Vector3, pele: Color, manga: Color, longa: bool) -> Dictionary:
	var dados := PSXMesh.dados_vazios()
	var m := PSXMesh.dados_vazios()
	var e := MaoPosada.esqueleto(o, d, dorso, p, direita)
	var dd: Vector3 = e["dd"]
	var ds: Vector3 = e["ds"]
	var ld: Vector3 = e["ld"]
	var q: Dictionary = e["q"]
	var uv_pele := MaoModelada._uv_liso(Aparencia.PECA_MAO, 0.14)
	var uv_pano := MaoModelada._uv_liso(Aparencia.PECA_MANGA, 0.30)
	var cores := MaoModelada._tons(pele)
	var faixas := {}
	var fi := {}
	var mv: PackedVector3Array = m["v"]
	MaoModelada._palma(m, q, ld, 0.0, cores, uv_pele)
	faixas["palma"] = Vector2i(0, (m["v"] as PackedVector3Array).size())
	fi["palma"] = Vector2i(0, (m["i"] as PackedInt32Array).size())
	for i in 4:
		var n0 := (m["v"] as PackedVector3Array).size()
		var i0 := (m["i"] as PackedInt32Array).size()
		var dedo: Dictionary = e["dedos"][i]
		MaoModelada._corrente(m, dedo["juntas"], dedo["dorsos"], MaoPosada.raios_do_dedo(i),
			cores, uv_pele, dd, ds)
		faixas["dedo%d" % i] = Vector2i(n0, (m["v"] as PackedVector3Array).size())
		fi["dedo%d" % i] = Vector2i(i0, (m["i"] as PackedInt32Array).size())
	var pol: Dictionary = e["polegar"]
	var np0 := (m["v"] as PackedVector3Array).size()
	var ip0 := (m["i"] as PackedInt32Array).size()
	MaoModelada._corrente(m, pol["juntas"], pol["dorsos"], MaoPosada.raios_do_dedo(4), cores,
		uv_pele, Vector3.ZERO, Vector3.ZERO)
	faixas["polegar"] = Vector2i(np0, (m["v"] as PackedVector3Array).size())
	fi["polegar"] = Vector2i(ip0, (m["i"] as PackedInt32Array).size())
	var no_indicador: Vector3 = (e["dedos"][0]["juntas"] as Array[Vector3])[0]
	var nm0 := (m["v"] as PackedVector3Array).size()
	var im0 := (m["i"] as PackedInt32Array).size()
	MaoPosada._membrana(m, (pol["juntas"] as Array[Vector3])[1], no_indicador, ds, cores, uv_pele)
	faixas["membrana"] = Vector2i(nm0, (m["v"] as PackedVector3Array).size())
	fi["membrana"] = Vector2i(im0, (m["i"] as PackedInt32Array).size())
	var na0 := (m["v"] as PackedVector3Array).size()
	var braco := MaoModelada._antebraco(m, q, ld, 0.0, cot, manga, longa, cores, uv_pele, uv_pano)
	faixas["antebraco"] = Vector2i(na0, (m["v"] as PackedVector3Array).size())
	faixas["mao"] = Vector2i(0, na0)
	PSXMesh.acumular(dados, m, Transform3D.IDENTITY)
	var pu: Vector3 = braco["punho"]
	var eixo: Vector3 = braco["eixo"]
	var comp := clampf(cot.distance_to(pu), 0.10, MaoModelada.ANTEBRACO)
	var fim := pu + eixo * comp
	var nb0 := (dados["v"] as PackedVector3Array).size()
	MaoModelada.braco_de_cima(dados, fim, ombro, pele, manga, longa)
	faixas["braco"] = Vector2i(nb0, (dados["v"] as PackedVector3Array).size())
	mv = dados["v"]
	return {"dados": dados, "faixas": faixas, "fi": fi, "o": o, "d": dd, "dorso": ds,
		"ld": ld, "pose": p, "esq": e, "punho": pu, "eixo": eixo, "comp": comp, "fim": fim,
		"ombro": ombro, "cot": cot, "n": mv.size()}


# --- sondas ------------------------------------------------------------------

## As sondas (a) da cabine sobre uma copia de braco: por solido, quantos
## vertices dentro e o mais fundo (cm), e em que peca. Marca `dentro` por
## vertice para a silhueta.
func _sondar_braco(rep: Dictionary) -> Dictionary:
	var v: PackedVector3Array = (rep["dados"] as Dictionary)["v"]
	var dentro := PackedByteArray()
	dentro.resize(v.size())
	var faixas: Dictionary = rep["faixas"]
	var pu: Vector3 = rep["punho"]
	var eixo: Vector3 = rep["eixo"]
	var comp: float = rep["comp"]
	var res := {}
	var tudo := AABB(v[0], Vector3.ZERO)
	for parte: String in ["mao", "antebraco", "braco"]:
		var fx: Vector2i = faixas[parte]
		if fx.y <= fx.x:
			continue
		var mn := v[fx.x]
		var mx := v[fx.x]
		for k in range(fx.x, fx.y):
			mn = mn.min(v[k])
			mx = mx.max(v[k])
		var caixa := AABB(mn, mx - mn).grow(0.001)
		tudo = tudo.merge(caixa)
		for s: Dictionary in solidos:
			var sa: AABB = s["aabb"]
			if not sa.intersects(caixa):
				continue
			var nome: String = s["nome"]
			for k in range(fx.x, fx.y):
				var p := v[k]
				if not sa.has_point(p):
					continue
				var pr := _prof(s, p)
				if pr <= 0.0:
					continue
				dentro[k] = 1
				var nome_parte := parte
				if parte == "antebraco" and (p - pu).dot(eixo) > comp + 0.005:
					nome_parte = "esporao"
				var r: Array = res.get(nome, [0, 0.0, ""])
				r[0] = int(r[0]) + 1
				if pr > float(r[1]):
					r[1] = pr
					r[2] = nome_parte
				res[nome] = r
	# O contrario: amostras dos solidos finos dentro das capsulas do braco.
	var caps := _capsulas(rep)
	var vol := {}
	var perto := tudo.grow(0.07)
	for am: Dictionary in _amostras:
		var s: Variant = am["solido"]
		var xf := Transform3D()
		if s != null:
			xf = (s as Dictionary)["xf"]
		for par: Array in am["local"]:
			var p: Vector3 = xf * (par[0] as Vector3)
			if not perto.has_point(p):
				continue
			var rs: float = par[1]
			for cp: Array in caps:
				var pen := float(cp[3]) + rs - _ate_segmento(p, cp[1], cp[2])
				if pen > 0.0:
					var nome: String = am["nome"]
					var r: Array = vol.get(nome, [0.0, ""])
					if pen > float(r[0]):
						r[0] = pen
						r[1] = cp[0]
					vol[nome] = r
	return {"sol": res, "vol": vol, "dentro": dentro}


## As capsulas do braco montado: nome, a, b, raio.
func _capsulas(rep: Dictionary) -> Array:
	var pu: Vector3 = rep["punho"]
	var fim: Vector3 = rep["fim"]
	var eixo: Vector3 = rep["eixo"]
	var ombro: Vector3 = rep["ombro"]
	var caps := [["braco", fim, ombro, 0.050], ["antebraco", pu, fim, 0.038],
		["esporao", fim, fim + eixo * MaoModelada.ALEM_DO_COTOVELO, 0.043]]
	var e: Dictionary = rep["esq"]
	for i in 4:
		var jt: Array[Vector3] = e["dedos"][i]["juntas"]
		var rr := MaoPosada.raios_do_dedo(i)
		for k in 3:
			caps.append(["dedo%d" % i, jt[k], jt[k + 1], float(rr[k + 1]) * 0.9])
	var jp: Array[Vector3] = e["polegar"]["juntas"]
	var rp := MaoPosada.raios_do_dedo(4)
	for k in jp.size() - 1:
		caps.append(["polegar", jp[k], jp[k + 1], float(rp[mini(k + 1, 3)]) * 0.9])
	# A palma: tres capsulas ao longo dela, do calcanhar aos nos.
	var o: Vector3 = rep["o"]
	var dd: Vector3 = rep["d"]
	var ds: Vector3 = rep["dorso"]
	var ld: Vector3 = rep["ld"]
	var meio := o + ds * 0.0125
	for lx: float in [-0.025, 0.0, 0.025]:
		caps.append(["palma", meio + ld * lx - dd * 0.085, meio + ld * lx, 0.0125])
	return caps


## Braco contra braco: a maior sobreposicao de capsula (cm) e as pecas. Com
## sobreposicao, marca de branco (4) os vertices de um dentro das capsulas do
## outro.
func _braco_x_braco(ra: Dictionary, rb: Dictionary) -> Dictionary:
	var ca := _capsulas(ra)
	var cb := _capsulas(rb)
	var pen := 0.0
	var pa := ""
	var pb := ""
	for x: Array in ca:
		for y: Array in cb:
			var pts := Geometry3D.get_closest_points_between_segments(x[1], x[2], y[1], y[2])
			var d := (pts[0] as Vector3).distance_to(pts[1])
			var p := float(x[3]) + float(y[3]) - d
			if p > pen:
				pen = p
				pa = x[0]
				pb = y[0]
	var n := 0
	if pen > 0.0:
		n = _marcar_em_capsulas(ra, cb) + _marcar_em_capsulas(rb, ca)
	return {"pen": pen, "a": pa, "b": pb, "n": n}


func _marcar_em_capsulas(rep: Dictionary, caps: Array) -> int:
	var v: PackedVector3Array = (rep["dados"] as Dictionary)["v"]
	var dentro: PackedByteArray = rep.get("dentro", PackedByteArray())
	if dentro.size() != v.size():
		dentro.resize(v.size())
	var caixa := AABB()
	var primeiro := true
	for cp: Array in caps:
		var r := float(cp[3])
		var c := AABB(cp[1], Vector3.ZERO).expand(cp[2]).grow(r)
		caixa = c if primeiro else caixa.merge(c)
		primeiro = false
	var n := 0
	for k in v.size():
		var p := v[k]
		if not caixa.has_point(p):
			continue
		for cp: Array in caps:
			if _ate_segmento(p, cp[1], cp[2]) < float(cp[3]):
				n += 1
				if dentro[k] == 0:
					dentro[k] = 4
				break
	rep["dentro"] = dentro
	return n


## A menor folga (cm) do braco ate as fivelas do cinto (o cinto nao tem faixa:
## so as fivelas existem na cabine). Negativa dentro.
func _folga_fivela(rep: Dictionary) -> Array:
	var v: PackedVector3Array = (rep["dados"] as Dictionary)["v"]
	var melhor := INF
	var nome := ""
	for s: Dictionary in solidos:
		if s["grupo"] != "cinto":
			continue
		var c: Vector3 = s["c"]
		var bt: Basis = s["bt"]
		var h: Vector3 = s["h"]
		var perto := (s["aabb"] as AABB).grow(0.5)
		for p: Vector3 in v:
			if not perto.has_point(p):
				continue
			var q := bt * (p - c)
			var e := Vector3(absf(q.x) - h.x, absf(q.y) - h.y, absf(q.z) - h.z)
			var d := Vector3(maxf(e.x, 0.0), maxf(e.y, 0.0), maxf(e.z, 0.0)).length() \
				+ minf(maxf(e.x, maxf(e.y, e.z)), 0.0)
			if d < melhor:
				melhor = d
				nome = s["nome"]
	if melhor == INF:
		return [99.0, ""]
	return [snappedf(melhor * 100.0, 0.1), nome]


## Os angulos da pose desenhada (graus, 0,1).
static func _pose_json(p: Dictionary) -> Dictionary:
	var out := {}
	var dd: Array = p.get("dedos", [])
	var ds := []
	for d: Variant in dd:
		var a := []
		for x: Variant in d:
			a.append(snappedf(float(x), 0.1))
		ds.append(a)
	out["dedos"] = ds
	var pol := []
	for x: Variant in p.get("polegar", []):
		pol.append(snappedf(float(x), 0.1))
	out["pol"] = pol
	return out


## O aparelho: contorno arredondado nas duas faces, no espaco dele.
func _montar_contorno_fone() -> void:
	var m := Iphone4S.TAMANHO * 0.5
	var rc := Iphone4S.RAIO_CANTO
	var cantos := [Vector2(m.x - rc, m.y - rc), Vector2(-m.x + rc, m.y - rc),
		Vector2(-m.x + rc, -m.y + rc), Vector2(m.x - rc, -m.y + rc)]
	var xy := PackedVector2Array()
	for k in 4:
		for j in 8:
			var a := PI * 0.5 * float(k) + PI * 0.5 * float(j) / 7.0
			xy.append((cantos[k] as Vector2) + Vector2(cos(a), sin(a)) * rc)
	for z: float in [m.z, -m.z]:
		for p: Vector2 in xy:
			_contorno_fone.append(Vector3(p.x, p.y, z))
	for z: float in [m.z, -m.z]:
		_contorno_fone.append(Vector3(0.0, 0.0, z))


## Distancia com sinal ao aparelho (caixa de cantos arredondados em xy), no
## espaco dele. Negativa dentro.
static func _sdf_fone(p: Vector3) -> float:
	var m := Iphone4S.TAMANHO * 0.5
	var rc := Iphone4S.RAIO_CANTO
	var qx := absf(p.x) - (m.x - rc)
	var qy := absf(p.y) - (m.y - rc)
	var d2 := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - rc
	var dz := absf(p.z) - m.z
	return Vector2(maxf(d2, 0.0), maxf(dz, 0.0)).length() + minf(maxf(d2, dz), 0.0)


## (b) e (c): a mao contra o aparelho. `fxi` leva da cabine ao aparelho,
## `lente` e a lente no espaco do aparelho.
func _sondar_mao_no_fone(rep: Dictionary, fxi: Transform3D, lente: Vector3,
		com_cobertura: bool, marca: PackedByteArray) -> Dictionary:
	var dados: Dictionary = rep["dados"]
	var v: PackedVector3Array = dados["v"]
	var faixas: Dictionary = rep["faixas"]
	var fx: Vector2i = faixas["mao"]
	var m := Iphone4S.TAMANHO * 0.5
	var tela := Iphone4S.TELA * 0.5
	var vidro := m.z
	var n_dentro := 0
	var pior := 0.0
	var pior_parte := ""
	var folga := {}
	var pol: Vector2i = faixas["polegar"]
	var pol_tela := 0
	var pol_alto := 0.0
	var pol_baixo := INF
	var ded_tela := 0
	var ded_alto := 0.0
	var ded_parte := ""
	var por_parte := {}
	var loc := PackedVector3Array()
	loc.resize(v.size())
	for k in range(fx.x, fx.y):
		var q := fxi * v[k]
		loc[k] = q
		var sd := _sdf_fone(q)
		var parte := _parte_da_mao(faixas, k)
		folga[parte] = minf(float(folga.get(parte, INF)), sd)
		if sd < 0.0:
			n_dentro += 1
			por_parte[parte] = int(por_parte.get(parte, 0)) + 1
			marca[k] = 2
			if -sd > pior:
				pior = -sd
				pior_parte = parte
		var sobre := q.z > vidro and absf(q.x) < tela.x and absf(q.y) < tela.y
		if sobre and k >= pol.x and k < pol.y:
			pol_tela += 1
			pol_alto = maxf(pol_alto, q.z - vidro)
			pol_baixo = minf(pol_baixo, q.z - vidro)
			if marca[k] == 0:
				marca[k] = 3
		elif sobre and parte.begins_with("dedo"):
			ded_tela += 1
			if q.z - vidro > ded_alto:
				ded_alto = q.z - vidro
				ded_parte = parte
	var r := {"n": n_dentro, "prof_mm": pior * 1000.0, "parte": pior_parte,
		"n_por_parte": por_parte,
		"pol_tela_n": pol_tela, "pol_tela_mm": pol_alto * 1000.0,
		"pol_tela_min_mm": (pol_baixo * 1000.0) if pol_tela > 0 else -1.0,
		"dedos_tela_n": ded_tela, "dedos_tela_mm": ded_alto * 1000.0, "dedos_tela_parte": ded_parte,
		"_marca": marca}
	# A ponta do polegar (centro da ultima junta do esqueleto), no aparelho.
	var jp: Array[Vector3] = ((rep["esq"] as Dictionary)["polegar"] as Dictionary)["juntas"]
	var ponta := fxi * jp[jp.size() - 1]
	r["pol_ponta_mm"] = _v(ponta * 1000.0)
	r["pol_ponta_vidro_mm"] = snappedf((ponta.z - vidro) * 1000.0, 0.1)
	r["pol_ponta_uv"] = [snappedf(ponta.x / Iphone4S.TELA.x + 0.5, 0.01),
		snappedf(0.5 - ponta.y / Iphone4S.TELA.y, 0.01)]
	var fol := {}
	for k2: String in folga:
		fol[k2] = snappedf(float(folga[k2]) * 1000.0, 0.1)
	r["folga_mm"] = fol
	# O fone dentro das capsulas da mao (a borda do aparelho passando por dentro
	# do dedo, que o vertice nao ve se o dedo e mais largo que o aparelho).
	var caps := _capsulas(rep)
	var fxt := fxi.affine_inverse()
	var pen_max := 0.0
	var pen_parte := ""
	for p0: Vector3 in _contorno_fone:
		var p := fxt * p0
		for cp: Array in caps:
			if String(cp[0]) in ["braco", "antebraco", "esporao"]:
				continue
			var pen := float(cp[3]) - _ate_segmento(p, cp[1], cp[2])
			if pen > pen_max:
				pen_max = pen
				pen_parte = cp[0]
	r["fone_na_capsula_mm"] = pen_max * 1000.0
	r["fone_na_capsula_parte"] = pen_parte
	if com_cobertura:
		var idx: PackedInt32Array = dados["i"]
		var fi: Dictionary = rep["fi"]
		r["cob_pol"] = _cobertura(loc, idx, [fi["polegar"]], lente)
		r["cob_mao"] = _cobertura(loc, idx, [fi["palma"], fi["dedo0"], fi["dedo1"], fi["dedo2"],
			fi["dedo3"], fi["polegar"], fi["membrana"]], lente)
	return r


static func _parte_da_mao(faixas: Dictionary, k: int) -> String:
	for nome: String in ["palma", "dedo0", "dedo1", "dedo2", "dedo3", "polegar", "membrana"]:
		var f: Vector2i = faixas[nome]
		if k >= f.x and k < f.y:
			return nome
	return "?"


## Fracao da tela (%) tapada pelos triangulos das faixas, vista da lente: cada
## triangulo na frente do vidro projetado da lente no plano do vidro, e a
## grade da tela marcada. `loc` ja no espaco do aparelho.
static func _cobertura(loc: PackedVector3Array, idx: PackedInt32Array, faixas_i: Array,
		lente: Vector3) -> float:
	var tela := Iphone4S.TELA
	var vidro := Iphone4S.TAMANHO.z * 0.5
	var grade := PackedByteArray()
	grade.resize(COB_NX * COB_NY)
	var cx := tela.x / float(COB_NX)
	var cy := tela.y / float(COB_NY)
	var x0 := -tela.x * 0.5
	var y0 := -tela.y * 0.5
	for f: Vector2i in faixas_i:
		var k := f.x
		while k + 2 < f.y:
			var a := loc[idx[k]]
			var b := loc[idx[k + 1]]
			var c := loc[idx[k + 2]]
			k += 3
			if a.z <= vidro and b.z <= vidro and c.z <= vidro:
				continue
			# So o pedaco do triangulo na FRENTE do vidro tapa a tela: o resto esta
			# dentro do aparelho (atravessando) e o vidro o esconde. Sem este
			# recorte o triangulo que cruza o vidro era projetado inteiro e a
			# regua de triangulo contava a mais que a de pixel.
			var poli := _recortar_no_vidro([a, b, c], vidro)
			if poli.size() < 3:
				continue
			var pp: Array[Vector2] = []
			for p: Vector3 in poli:
				pp.append(_projetar(p, lente, vidro))
			for m in range(1, pp.size() - 1):
				_marcar_na_grade(grade, pp[0], pp[m], pp[m + 1], x0, y0, cx, cy)
	var n := 0
	for g in grade:
		n += g
	return 100.0 * float(n) / float(COB_NX * COB_NY)


## Sutherland-Hodgman do triangulo contra o semiespaco z >= vidro.
static func _recortar_no_vidro(tri: Array, z0: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 3:
		var a: Vector3 = tri[i]
		var b: Vector3 = tri[(i + 1) % 3]
		var a_in := a.z >= z0
		var b_in := b.z >= z0
		if a_in:
			out.append(a)
		if a_in != b_in:
			out.append(a.lerp(b, (z0 - a.z) / (b.z - a.z)))
	return out


static func _marcar_na_grade(grade: PackedByteArray, pa: Vector2, pb: Vector2, pc: Vector2,
		x0: float, y0: float, cx: float, cy: float) -> void:
	var i0 := maxi(0, int(floor((minf(pa.x, minf(pb.x, pc.x)) - x0) / cx)))
	var i1 := mini(COB_NX - 1, int(floor((maxf(pa.x, maxf(pb.x, pc.x)) - x0) / cx)))
	var j0 := maxi(0, int(floor((minf(pa.y, minf(pb.y, pc.y)) - y0) / cy)))
	var j1 := mini(COB_NY - 1, int(floor((maxf(pa.y, maxf(pb.y, pc.y)) - y0) / cy)))
	if i1 < i0 or j1 < j0:
		return
	var den := (pb.y - pc.y) * (pa.x - pc.x) + (pc.x - pb.x) * (pa.y - pc.y)
	if absf(den) < 1e-12:
		return
	for j in range(j0, j1 + 1):
		var py := y0 + (float(j) + 0.5) * cy
		for i in range(i0, i1 + 1):
			var px := x0 + (float(i) + 0.5) * cx
			var l1 := ((pb.y - pc.y) * (px - pc.x) + (pc.x - pb.x) * (py - pc.y)) / den
			var l2 := ((pc.y - pa.y) * (px - pc.x) + (pa.x - pc.x) * (py - pc.y)) / den
			if l1 >= 0.0 and l2 >= 0.0 and l1 + l2 <= 1.0:
				grade[j * COB_NX + i] = 1


static func _projetar(v: Vector3, lente: Vector3, vidro: float) -> Vector2:
	if v.z <= vidro or absf(v.z - lente.z) < 1e-6:
		return Vector2(v.x, v.y)
	var s := (vidro - lente.z) / (v.z - lente.z)
	var p := lente + (v - lente) * s
	return Vector2(p.x, p.y)


## (d) O aparelho contra a cabine: o ponto mais baixo contra o chao embaixo
## dele (tapete ou carpete) e cada solido.
func _sondar_fone(fx: Transform3D) -> Dictionary:
	var baixo := INF
	var p_baixo := Vector3.ZERO
	var res := {}
	var pts := PackedVector3Array()
	for p0: Vector3 in _contorno_fone:
		var p := fx * p0
		pts.append(p)
		if p.y < baixo:
			baixo = p.y
			p_baixo = p
	var caixa := AABB(pts[0], Vector3.ZERO)
	for p: Vector3 in pts:
		caixa = caixa.expand(p)
	for s: Dictionary in solidos:
		var sa: AABB = s["aabb"]
		if not sa.intersects(caixa.grow(0.001)):
			continue
		for p: Vector3 in pts:
			if not sa.has_point(p):
				continue
			var pr := _prof(s, p)
			if pr > 0.0:
				var r: Array = res.get(s["nome"], [0, 0.0])
				r[0] = int(r[0]) + 1
				r[1] = maxf(float(r[1]), pr)
				res[s["nome"]] = r
	var chao := _piso
	var sob := "carpete"
	for tp: Dictionary in _tapetes:
		if p_baixo.x >= float(tp["x0"]) and p_baixo.x <= float(tp["x1"]) \
				and p_baixo.z >= float(tp["z0"]) and p_baixo.z <= float(tp["z1"]):
			chao = tp["topo"]
			sob = "tapete"
	return {"baixo_cm": (baixo - chao) * 100.0, "sob": sob, "sol": res,
		"p_baixo": p_baixo}


# --- o quadro -----------------------------------------------------------------

func _quadro() -> void:
	if _fim:
		return
	if not _pronto:
		_pronto = _preparar()
		if not _pronto:
			_falhou_preparo += 1
			return
	if not _pend_sil.is_empty():
		_salvar_silhuetas()
	var t := _relogio()
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		cam.cull_mask &= ~(L_FANT | L_OBST | L_PAINEL | L_BRACO | L_FONE_T | L_XRAY)
	if t < JANELA.x:
		return
	# Os controles de pixel: um de cada vez, antes de medir.
	if not _controle_fila.is_empty():
		if _pend_sil.is_empty():
			_passo_controle(_controle_fila.pop_front())
		return
	if not _pend_sil.is_empty() and String(_pend_sil.get("pasta", "")) == "controle":
		return
	if t > JANELA.y:
		_terminar()
		return
	var denso := t >= DENSO.x and t <= DENSO.y
	# So o quadro em que o relogio da cena andou e estado novo (no trecho denso
	# os quadros parados so desenham as silhuetas).
	if _t_medido < 0.0 or t - _t_medido >= PASSO_MIN:
		var us := Time.get_ticks_usec()
		_atualizar_solidos()
		var med := _medir(t, cam)
		med["dt_cena"] = snappedf(t - _t_medido, 0.0001) if _t_medido >= 0.0 else 0.0
		med["passo60"] = roundi(t * 60.0)
		_t_medido = t
		_t_medida_ms = float(Time.get_ticks_usec() - us) * 0.001
		med["ms"] = snappedf(_t_medida_ms, 0.1)
		var passo := 0.5 if t < DENSO.x else 0.2
		var evento: String = med.get("evento", "")
		var q: int = med["q"]
		var capturar := denso or t >= _prox_captura
		if not evento.is_empty() and q - _ult_evento >= 2:
			capturar = true
			_ult_evento = q
		# A silhueta anterior ainda nao voltou do servidor: sem captura nova.
		if capturar and not _pend_sil.is_empty():
			capturar = false
			med["cap_adiada"] = true
			if denso:
				_n_perdidas += 1
				print("[diag] PERDIDA: q=%d t=%.3f sem silhueta (a anterior nao voltou)" % [q, t])
		if denso:
			_n_passos_denso += 1
		if capturar:
			if t >= _prox_captura:
				_prox_captura = t + passo
			med["cap"] = true
			_capturar(med, cam)
		_jsonl.store_line(JSON.stringify(_para_json(med)))
		_n_quadros += 1
		if (capturar and not denso) or _n_quadros % 30 == 0:
			print(_linha(med))
	_decidir_tempo(denso)


## O tempo do proximo quadro. No trecho denso so anda um passo cheio quando
## nada esta pendente E o quadro que roda agora e parado: o `time_scale` escrito
## aqui so vale do proximo quadro em diante, e o quadro que ja roda com passo
## cheio vira estado novo, medido e capturado no quadro seguinte.
func _decidir_tempo(denso: bool) -> void:
	if not denso:
		if _parado:
			Engine.time_scale = 1.0
			_parado = false
		return
	var anda_agora := get_process_delta_time() >= PASSO_MIN
	if _pend_sil.is_empty() and not anda_agora:
		if _parado:
			Engine.time_scale = 1.0
			_parado = false
	elif not _parado:
		if not is_equal_approx(Engine.time_scale, 1.0):
			print("[diag] AVISO: time_scale=%.4f da cena no trecho denso" % Engine.time_scale)
		Engine.time_scale = ESCALA_PARADA
		_parado = true


func _medir(t: float, cam: Camera3D) -> Dictionary:
	var q := Engine.get_process_frames() - 1
	var inv := mot.global_transform.affine_inverse()
	# O passo do jogo desde a medida anterior (relogio da cena): no trecho denso
	# os quadros parados entre dois passos nao contam.
	var dt_c := (t - _t_medido) if _t_medido >= 0.0 else 1.0 / 60.0
	var med := {"q": q, "t": snappedf(t, 0.001), "dt": snappedf(dt_c, 0.0001),
		"d": String(mot._direita_em), "e": String(mot._esquerda_em),
		"esforco": snappedf(mot.esforco, 0.01), "apoio": snappedf(mot.apoio_forca, 0.01),
		"medo": snappedf(mot.medo, 0.01), "cot_baixo": snappedf(mot._cotovelo_baixo, 0.01),
		"debruca": _v(mot.debruca_olho)}
	if abertura != null:
		med["deb_cena"] = snappedf(float(abertura.get("_debruca")), 0.01)
	var lente := Vector3.ZERO
	if cam != null:
		lente = inv * cam.global_position
		med["lente"] = _v(lente)
		med["fov"] = snappedf(cam.fov, 0.01)
		med["cam_interp_cm"] = snappedf(cam.global_position.distance_to(
			cam.get_global_transform_interpolated().origin) * 100.0, 0.01)
	var eventos: Array[String] = []
	# Os bracos.
	var reps := {}
	var bracos := {"D": mot._braco_d, "E": mot._braco_e, "L": mot._braco_leitura}
	var bm := {}
	for k: String in bracos:
		var b: BracoVivo = bracos[k]
		if b == null or not b.is_visible_in_tree() or b.pegada.is_empty():
			continue
		var rep := _replica(b)
		var son := _sondar_braco(rep)
		rep["dentro"] = son["dentro"]
		reps[k] = rep
		var fim: Vector3 = rep["fim"]
		var ombro: Vector3 = rep["ombro"]
		var pu: Vector3 = rep["punho"]
		var n_malha := -1
		var malha := b.mesh as ArrayMesh
		if malha != null and malha.get_surface_count() > 0:
			n_malha = malha.surface_get_array_len(0)
		var lmin := INF
		var vv: PackedVector3Array = (rep["dados"] as Dictionary)["v"]
		for p: Vector3 in vv:
			lmin = minf(lmin, p.distance_squared_to(lente))
		var x := {"rep_mm": [snappedf(pu.distance_to(b.punho_montado) * 1000.0, 0.1),
				snappedf(fim.distance_to(b.cotovelo_montado) * 1000.0, 0.1)],
			"n": rep["n"], "n_malha": n_malha,
			"ombro_punho_cm": snappedf(ombro.distance_to(pu) * 100.0, 0.1),
			"braco_cima_cm": snappedf(ombro.distance_to(fim) * 100.0, 0.1),
			"estica_cm": snappedf((ombro.distance_to(fim) - BracoVivo.BRACO_DE_CIMA) * 100.0, 0.1),
			"lente_cm": snappedf(sqrt(lmin) * 100.0, 0.1),
			"o": _v(rep["o"]), "punho": _v(pu), "cotovelo": _v(fim), "ombro": _v(ombro),
			"tremor": snappedf(float(rep["tremor"]), 0.01),
			"dedos_vivos": snappedf(float(rep["dedos_vivos"]), 0.01),
			"pose": _pose_json(rep["pose"]), "fivela_cm": _folga_fivela(rep)}
		var sol := {}
		for nome: String in son["sol"]:
			var r: Array = son["sol"][nome]
			sol[nome] = [r[0], snappedf(float(r[1]) * 100.0, 0.01), r[2]]
		x["sol"] = sol
		var vol := {}
		for nome: String in son["vol"]:
			var r: Array = son["vol"][nome]
			vol[nome] = [snappedf(float(r[0]) * 100.0, 0.01), r[1]]
		x["vol"] = vol
		# Grupos: o pior por grupo (vertice dentro ou solido fino dentro da
		# capsula).
		var grupos := {}
		for s: Dictionary in solidos:
			var nome: String = s["nome"]
			if sol.has(nome):
				var gnome: String = s["grupo"]
				var r: Array = sol[nome]
				var gr: Array = grupos.get(gnome, [0, 0.0, "", ""])
				gr[0] = int(gr[0]) + int(r[0])
				if float(r[1]) > float(gr[1]):
					gr[1] = r[1]
					gr[2] = r[2]
					gr[3] = nome
				grupos[gnome] = gr
		for am: Dictionary in _amostras:
			var nome: String = am["nome"]
			if vol.has(nome):
				var gnome: String = am["grupo"]
				var r: Array = vol[nome]
				var gr: Array = grupos.get(gnome, [0, 0.0, "", ""])
				if float(r[0]) > float(gr[1]):
					gr[1] = r[0]
					gr[2] = r[1]
					gr[3] = nome + "(vol)"
				grupos[gnome] = gr
		x["grupos"] = grupos
		for gnome: String in grupos:
			var cat := "%s_%s" % [k, gnome]
			var val := float((grupos[gnome] as Array)[1])
			if val > float(_pior.get(cat, 0.0)) + LIMIAR_CM:
				_pior[cat] = val
				eventos.append("%s=%.1fcm" % [cat, val])
		# Salto da mao por quadro.
		var o: Vector3 = rep["o"]
		if _anterior.has("o_" + k):
			x["salto_cm"] = snappedf(o.distance_to(_anterior["o_" + k]) * 100.0, 0.01)
		_anterior["o_" + k] = o
		bm[k] = x
	med["bracos"] = bm
	# Braco contra braco: capsula contra capsula, e o vertice de um dentro das
	# capsulas do outro (branco na silhueta).
	var bxb := {}
	var chaves := reps.keys()
	for i in chaves.size():
		for j in range(i + 1, chaves.size()):
			var ka: String = chaves[i]
			var kb: String = chaves[j]
			var cx := _braco_x_braco(reps[ka], reps[kb])
			if float(cx["pen"]) > 0.0:
				bxb["%s_%s" % [ka, kb]] = [snappedf(float(cx["pen"]) * 100.0, 0.01), cx["a"], cx["b"],
					cx["n"]]
				var cat := "bxb_%s_%s" % [ka, kb]
				var val := float(cx["pen"]) * 100.0
				if val > float(_pior.get(cat, 0.0)) + LIMIAR_CM:
					_pior[cat] = val
					eventos.append("%s=%.1fcm" % [cat, val])
	med["braco_x_braco"] = bxb
	# Quem esta visivel: o braco da leitura, a mao que segura o fone e as maos
	# do aro (as silhuetas desenham as do aro tambem).
	var vis := {"mao_direita": mot._mao_direita != null and mot._mao_direita.is_visible_in_tree()}
	for k: String in bracos:
		var b: BracoVivo = bracos[k]
		vis[k] = b != null and b.is_visible_in_tree()
	var aro: Array[String] = []
	for b: Dictionary in mot._bracos:
		var e: Node3D = b.get("esqueleto")
		if e != null and is_instance_valid(e) and e.is_visible_in_tree():
			aro.append(String(e.name))
	vis["aro"] = aro
	vis["motorista"] = mot.is_visible_in_tree()
	med["vis"] = vis
	var tela := mot.tela()
	if tela != null and is_instance_valid(tela):
		med["tela_zoom"] = snappedf(tela.zoom, 0.01)
	# O aparelho (medido tambem fora de quadro: no plano de fora ele some da
	# arvore visivel, mas continua onde esta).
	var fone := mot._fone
	if fone != null and is_instance_valid(fone) and fone.is_inside_tree():
		var fx := inv * fone.global_transform
		var fxi := fx.affine_inverse()
		var f := _sondar_fone(fx)
		var fsol := {}
		for nome: String in f["sol"]:
			var r: Array = f["sol"][nome]
			fsol[nome] = [r[0], snappedf(float(r[1]) * 100.0, 0.01)]
		var fm := {"c": _v(fx.origin), "pai": String(fone.get_parent().name),
			"vis": fone.is_visible_in_tree(), "brilho": snappedf(fone.brilho_atual(), 0.01),
			"p_baixo": _v(f["p_baixo"]),
			"interp_cm": snappedf(fone.global_position.distance_to(
				fone.get_global_transform_interpolated().origin) * 100.0, 0.01),
			"baixo_cm": snappedf(float(f["baixo_cm"]), 0.01), "sob": f["sob"], "sol": fsol,
			"eixo_y": _v(fx.basis.y), "eixo_z": _v(fx.basis.z)}
		if _anterior.has("fone"):
			var dsal := fx.origin.distance_to(_anterior["fone"])
			fm["salto_cm"] = snappedf(dsal * 100.0, 0.01)
			var dtq := maxf(dt_c, 1e-4)
			var vel := dsal / dtq
			fm["vel"] = snappedf(vel, 0.01)
			var mediana := _mediana(_hist_fone)
			if dsal > 0.015 and _hist_fone.size() >= 4 and vel > 3.0 * maxf(mediana, 0.05):
				eventos.append("salto_fone=%.1fcm" % (dsal * 100.0))
				fm["salto_flag"] = true
			_hist_fone.append(vel)
			if _hist_fone.size() > 8:
				_hist_fone.pop_front()
		_anterior["fone"] = fx.origin
		for nome: String in fsol:
			var cat := "fone_" + nome
			var val := float((fsol[nome] as Array)[1])
			if val > float(_pior.get(cat, 0.0)) + LIMIAR_CM:
				_pior[cat] = val
				eventos.append("%s=%.1fcm" % [cat, val])
		# A mao contra o aparelho: o braco com a mao mais perto dele.
		var lente_f := fxi * lente
		fm["lente_cm"] = snappedf(fx.origin.distance_to(lente) * 100.0, 0.1)
		var melhor := {}
		var melhor_k := ""
		for k: String in reps:
			var rep: Dictionary = reps[k]
			if (rep["o"] as Vector3).distance_to(fx.origin) > 0.16:
				continue
			var marca: PackedByteArray = rep["dentro"]
			var mf := _sondar_mao_no_fone(rep, fxi, lente_f, true, marca)
			rep["dentro"] = mf["_marca"]
			mf.erase("_marca")
			var folgas: Dictionary = mf["folga_mm"]
			var menor := INF
			for pk: String in folgas:
				menor = minf(menor, float(folgas[pk]))
			mf["menor_folga_mm"] = snappedf(menor, 0.1)
			if melhor.is_empty() or menor < float(melhor["menor_folga_mm"]):
				melhor = mf
				melhor_k = k
			# A mao no espaco do aparelho, e o salto dela ali (pai atrasado).
			var o_f := fxi * (rep["o"] as Vector3)
			if _anterior.has("of_" + k) and String(_anterior.get("of_pai_" + k, "")) == fm["pai"]:
				mf["salto_rel_mm"] = snappedf(o_f.distance_to(_anterior["of_" + k]) * 1000.0, 0.01)
			_anterior["of_" + k] = o_f
			_anterior["of_pai_" + k] = fm["pai"]
			mf["o_no_fone_mm"] = _v(o_f * 1000.0)
			fm["mao_" + k] = mf
		if not melhor.is_empty():
			fm["mao"] = melhor_k
			var cats := {"fone_mao_mm": float(melhor["prof_mm"]),
				"fone_capsula_mm": float(melhor["fone_na_capsula_mm"]),
				"cob_pol": float(melhor.get("cob_pol", 0.0))}
			var lim := {"fone_mao_mm": LIMIAR_MM, "fone_capsula_mm": LIMIAR_MM, "cob_pol": LIMIAR_PCT}
			for cat: String in cats:
				if cats[cat] > float(_pior.get(cat, 0.0)) + float(lim[cat]):
					_pior[cat] = cats[cat]
					eventos.append("%s=%.1f" % [cat, cats[cat]])
		med["fone"] = fm
		med["_fx"] = fx
		if cam != null:
			var vs := get_viewport().get_visible_rect().size
			med["px_fone"] = _v2(cam.unproject_position(fone.global_position))
			med["vp"] = [vs.x, vs.y]
			if reps.has("D") or reps.has("L") or reps.has("E"):
				var kk := melhor_k if not melhor_k.is_empty() else (reps.keys()[0] as String)
				var og := mot.global_transform * ((reps[kk] as Dictionary)["o"] as Vector3)
				if not cam.is_position_behind(og):
					med["px_mao"] = _v2(cam.unproject_position(og))
	# Mudanca de estado tambem e evento.
	var estado := "%s|%s|%s" % [med["d"], med["e"], (med.get("fone", {}) as Dictionary).get("pai", "")]
	if estado != _estado_ant:
		eventos.append("estado=" + estado)
		_estado_ant = estado
	med["_reps"] = reps
	if not eventos.is_empty():
		med["evento"] = ",".join(eventos)
	return med


static func _mediana(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001)]


static func _v2(p: Vector2) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]


func _para_json(med: Dictionary) -> Dictionary:
	var out := {}
	for k: String in med:
		if k.begins_with("_"):
			continue
		out[k] = med[k]
	return out


func _linha(med: Dictionary) -> String:
	var s := "[diag] q=%d t=%.2f d=%s e=%s" % [med["q"], med["t"], med["d"], med["e"]]
	var bm: Dictionary = med.get("bracos", {})
	for k: String in bm:
		var x: Dictionary = bm[k]
		var gs := ""
		var grupos: Dictionary = x["grupos"]
		for g: String in grupos:
			var r: Array = grupos[g]
			gs += " %s:%d/%.1f(%s)" % [g, r[0], r[1], r[2]]
		s += " | %s estica=%.0fcm lente=%.0fcm%s" % [k, x["estica_cm"], x["lente_cm"], gs]
	var fm: Dictionary = med.get("fone", {})
	if not fm.is_empty():
		s += " | fone %s baixo=%.1fcm" % [fm["pai"], fm["baixo_cm"]]
		var fsol: Dictionary = fm["sol"]
		for n: String in fsol:
			s += " %s=%.1f" % [n, (fsol[n] as Array)[1]]
		if fm.has("mao"):
			var mf: Dictionary = fm["mao_" + String(fm["mao"])]
			s += " mao%s dentro=%d/%.1fmm cap=%.1fmm folga=%.1fmm pol_tela=%d cob_pol=%.1f%% cob=%.1f%%" % [
				fm["mao"], mf["n"], mf["prof_mm"], mf["fone_na_capsula_mm"], mf["menor_folga_mm"],
				mf["pol_tela_n"], mf.get("cob_pol", 0.0), mf.get("cob_mao", 0.0)]
	if med.has("evento"):
		s += " EVENTO " + String(med["evento"])
	s += " (%.1f ms)" % _t_medida_ms
	return s


# --- capturas -------------------------------------------------------------------

func _capturar(med: Dictionary, _cam: Camera3D) -> void:
	var q: int = med["q"]
	var t: float = med["t"]
	_n_capturas += 1
	# A lente: a textura da janela ainda e a do quadro medido.
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var nome_l := pasta.path_join("lente/q%06d_t%07.3f.jpg" % [q, t])
		var nome_r := pasta.path_join("r/r_%07.2f.png" % t)
		_tarefa(func() -> void:
			if img.get_format() != Image.FORMAT_RGB8:
				img.convert(Image.FORMAT_RGB8)
			img.save_jpg(nome_l, 0.92)
			var pq := img.duplicate() as Image
			pq.resize(640, 360, Image.INTERPOLATE_BILINEAR)
			pq.save_png(nome_r))
	# A tela do aparelho como ela esta (a textura do app), pequena.
	var tela := mot.tela()
	if tela != null and is_instance_valid(tela) and med.has("_fx"):
		var ti := tela.textura().get_image()
		if ti != null and not ti.is_empty():
			var nome_t := pasta.path_join("tela/q%06d.png" % q)
			_tarefa(func() -> void:
				ti.resize(292, 438, Image.INTERPOLATE_BILINEAR)
				ti.save_png(nome_t))
	# As silhuetas: as copias no estado do quadro medido, desenhadas no proximo.
	_por_fantasmas(med)
	var id := _n_capturas % 509
	var fx_g: Variant = null
	if med.has("_fx"):
		fx_g = mot.global_transform * (med["_fx"] as Transform3D)
	for vw: Dictionary in _vistas:
		_posicionar_vista(vw, fx_g)
		_marcar(vw, id)
		(vw["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	_pend_sil = {"q": q, "t": t, "pasta": "sil", "id": id, "tentativas": 0}
	med["cap_id"] = id
	if med.has("_fx"):
		for vw: Dictionary in _vistas:
			if not vw.get("lente", false):
				continue
			var cam: Camera3D = vw["cam"]
			var fxg := mot.global_transform * (med["_fx"] as Transform3D)
			var cantos := []
			for uv: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				cantos.append(_v2(cam.unproject_position(fxg * Iphone4S.ponto_da_tela(uv))))
			med["tela_px_lente"] = cantos
			med["lente_px"] = [(vw["vp"] as SubViewport).size.x, (vw["vp"] as SubViewport).size.y]
		var principal := get_viewport().get_camera_3d()
		if principal != null:
			var fxg2 := mot.global_transform * (med["_fx"] as Transform3D)
			var cantos2 := []
			for uv: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				cantos2.append(_v2(principal.unproject_position(fxg2 * Iphone4S.ponto_da_tela(uv))))
			med["tela_px_principal"] = cantos2
			# Os oito cantos do corpo do aparelho, para o recorte da lente pegar o
			# aparelho inteiro.
			var m := Iphone4S.TAMANHO * 0.5
			var corpo := []
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					for sz: float in [-1.0, 1.0]:
						var pg := fxg2 * Vector3(sx * m.x, sy * m.y, sz * m.z)
						if not principal.is_position_behind(pg):
							corpo.append(_v2(principal.unproject_position(pg)))
			med["fone_px_principal"] = corpo
	# A mao (o ponto da palma) de cada braco na lente, para o recorte.
	var principal2 := get_viewport().get_camera_3d()
	if principal2 != null:
		var maos := {}
		for k: String in (med.get("_reps", {}) as Dictionary):
			var rep: Dictionary = med["_reps"][k]
			var pts := []
			for chave: String in ["o", "punho", "fim"]:
				var pg := mot.global_transform * (rep[chave] as Vector3)
				if not principal2.is_position_behind(pg):
					pts.append(_v2(principal2.unproject_position(pg)))
			maos[k] = pts
		med["bracos_px"] = maos


## Guarda as silhuetas pedidas, mas so as que ja voltaram com a marca da
## captura pedida: o `UPDATE_ONCE` do SubViewport as vezes desenha um quadro
## depois, e a imagem lida ainda era a da captura anterior.
func _salvar_silhuetas() -> void:
	var q: int = _pend_sil["q"]
	var sub: String = _pend_sil["pasta"]
	var sufixo: String = _pend_sil.get("sufixo", "")
	var id: int = _pend_sil.get("id", -1)
	var imgs := []
	var todas := true
	for vw: Dictionary in _vistas:
		var img := (vw["vp"] as SubViewport).get_texture().get_image()
		if img == null or img.is_empty():
			imgs.append(null)
			continue
		var lido := _ler_marca(img)
		if id >= 0 and lido != id:
			todas = false
		imgs.append(img)
	var tent: int = _pend_sil.get("tentativas", 0)
	if not todas and tent < 6:
		_pend_sil["tentativas"] = tent + 1
		for vw: Dictionary in _vistas:
			(vw["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	if tent > 0 or not todas:
		print("[diag] silhueta q=%d: %d quadro(s) de atraso%s" % [q, tent,
			"" if todas else ", MARCA ERRADA (descartada)"])
	_n_atrasos += tent
	if todas:
		for k in _vistas.size():
			var img: Image = imgs[k]
			if img == null:
				continue
			var nome := pasta.path_join("%s/q%06d_%s%s.png" % [sub, q, _vistas[k]["nome"], sufixo])
			_tarefa(func() -> void: img.save_png(nome))
		if _pend_sil.get("contar", false):
			_contar_controle(imgs, _pend_sil)
	_pend_sil = {}
	_esconder_fantasmas()


## O controle de pixel: quantos pixels magenta (dentro de solido), azuis
## (dentro do fone) e brancos (dentro do outro braco) cada vista mostra.
func _contar_controle(imgs: Array, pend: Dictionary) -> void:
	var sufixo: String = pend["sufixo"]
	var partes: Array[String] = []
	var tot := {"magenta": 0, "azul": 0, "branco": 0}
	var por_vista := {}
	for k in _vistas.size():
		var img: Image = imgs[k]
		var nome: String = _vistas[k]["nome"]
		if img == null or nome.begins_with("lente"):
			continue
		var c := _contar_cores(img)
		por_vista[nome] = c
		for cor: String in tot:
			tot[cor] = int(tot[cor]) + int(c[cor])
		partes.append("%s m%d/a%d/b%d" % [nome, c["magenta"], c["azul"], c["branco"]])
	var esperado: Dictionary = pend.get("esperado", {})
	var ok := true
	var exig: Array[String] = []
	for chave: String in esperado:
		# "azul@fone_frente": > 0 naquela vista; "azul": > 0 na soma.
		var cor := chave.get_slice("@", 0)
		var vista := chave.get_slice("@", 1) if chave.contains("@") else ""
		var n := int(tot[cor]) if vista.is_empty() else int((por_vista.get(vista, {}) as Dictionary).get(cor, 0))
		var quer: String = esperado[chave]
		var bom := n > 0 if quer == ">0" else n == 0
		ok = ok and bom
		exig.append("%s %s: %d %s" % [chave, quer, n, "OK" if bom else "FALHOU"])
	var linha := "[diag-controle] pixel %s: %s | %s %s" % [sufixo, ", ".join(partes),
		"; ".join(exig), ("OK" if ok else "FALHOU") if not esperado.is_empty() else "(so registro)"]
	print(linha)
	_controle_linhas.append(linha)
	_gravar_controle()


static func _contar_cores(img: Image) -> Dictionary:
	var dados := img.get_data()
	var w := img.get_width()
	var h := img.get_height()
	var passo := 3 if img.get_format() == Image.FORMAT_RGB8 else 4
	if img.get_format() != Image.FORMAT_RGB8 and img.get_format() != Image.FORMAT_RGBA8:
		var cp := img.duplicate() as Image
		cp.convert(Image.FORMAT_RGBA8)
		dados = cp.get_data()
		passo = 4
	var m := 0
	var a := 0
	var b := 0
	var n := w * h
	for i in n:
		var o := i * passo
		var r := dados[o]
		var g := dados[o + 1]
		var bl := dados[o + 2]
		if r > 180 and bl > 180 and g < 90:
			m += 1
		elif bl > 200 and bl - r > 60 and bl - g > 50:
			a += 1
		elif r > 235 and g > 235 and bl > 235:
			b += 1
	return {"magenta": m, "azul": a, "branco": b}


func _gravar_controle() -> void:
	var f := FileAccess.open(pasta.path_join("controle/controle.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_controle_linhas) + "\n")
	f.close()


## A marca da captura: um quadradinho no canto de cima a direita de cada vista,
## na cor do numero da captura (tres digitos de base 8 em R, G e B), sem teste
## de profundidade.
func _marcar(vw: Dictionary, id: int) -> void:
	var cam: Camera3D = vw["cam"]
	var mi: MeshInstance3D = vw["marca"]
	var vp: SubViewport = vw["vp"]
	var aspecto := float(vp.size.x) / float(vp.size.y)
	var dz := cam.near * 1.5
	var h := cam.size * 0.5 if cam.projection == Camera3D.PROJECTION_ORTHOGONAL 		else dz * tan(deg_to_rad(cam.fov) * 0.5)
	var w := h * aspecto
	var lado := h * 0.10
	mi.transform = Transform3D(Basis.from_scale(Vector3(lado, lado, 1.0)),
		Vector3(w * 0.93, h * 0.88, -dz))
	var cor := Color(float(id % 8) / 7.0, float((id / 8) % 8) / 7.0, float((id / 64) % 8) / 7.0)
	(mi.material_override as StandardMaterial3D).albedo_color = cor
	mi.visible = true


func _ler_marca(img: Image) -> int:
	var x := clampi(roundi(float(img.get_width()) * (0.5 + 0.465)), 0, img.get_width() - 1)
	var y := clampi(roundi(float(img.get_height()) * (0.5 - 0.44)), 0, img.get_height() - 1)
	var c := img.get_pixel(x, y)
	return roundi(c.r * 7.0) + roundi(c.g * 7.0) * 8 + roundi(c.b * 7.0) * 64


func _tarefa(f: Callable) -> void:
	_tarefas.append(WorkerThreadPool.add_task(f))
	while _tarefas.size() > 10:
		WorkerThreadPool.wait_for_task_completion(_tarefas.pop_front())


func _terminar() -> void:
	_fim = true
	if _parado:
		Engine.time_scale = 1.0
		_parado = false
	if not _pend_sil.is_empty():
		_salvar_silhuetas()
	for id: int in _tarefas:
		WorkerThreadPool.wait_for_task_completion(id)
	_tarefas.clear()
	var piores := JSON.stringify(_pior)
	print("[diag] fim: %d quadros medidos (%d no trecho denso), %d capturas, %d perdidas no denso, %d quadros de atraso nas silhuetas; piores=%s" % [
		_n_quadros, _n_passos_denso, _n_capturas, _n_perdidas, _n_atrasos, piores])
	_jsonl.store_line(JSON.stringify({"fim": true, "piores": _pior, "quadros": _n_quadros,
		"capturas": _n_capturas, "denso": _n_passos_denso, "perdidas": _n_perdidas}))
	_jsonl.close()
	get_tree().quit(0)


# --- as copias chapadas ------------------------------------------------------------

func _montar_materiais() -> void:
	_mat_braco = StandardMaterial3D.new()
	_mat_braco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_braco.vertex_color_use_as_albedo = true
	_mat_braco.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_obst = StandardMaterial3D.new()
	_mat_obst.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_obst.vertex_color_use_as_albedo = true
	_mat_obst.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_obst.albedo_color = Color(1.0, 1.0, 1.0, 0.30)
	_mat_obst.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_obst.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat_linha = StandardMaterial3D.new()
	_mat_linha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_linha.vertex_color_use_as_albedo = true
	# Raio X: sem teste de profundidade e desenhado por ultimo (passe
	# transparente, prioridade alta), opaco.
	_mat_xray = StandardMaterial3D.new()
	_mat_xray.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_xray.vertex_color_use_as_albedo = true
	_mat_xray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_xray.no_depth_test = true
	_mat_xray.render_priority = 120
	_mat_xray.cull_mode = BaseMaterial3D.CULL_DISABLED
	# O aparelho translucido das vistas no espaco dele.
	_mat_fone_t = StandardMaterial3D.new()
	_mat_fone_t.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_fone_t.vertex_color_use_as_albedo = true
	_mat_fone_t.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_fone_t.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	_mat_fone_t.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat_fone_t.cull_mode = BaseMaterial3D.CULL_DISABLED


static func _sombreado(cor: Color, n: Vector3) -> Color:
	var k := 0.50 + 0.50 * maxf(0.0, n.normalized().dot(LUZ.normalized()))
	return Color(cor.r * k, cor.g * k, cor.b * k, cor.a)


## Uma malha primitiva com a cor assada pela normal (sem luz na cena) e as
## arestas de contorno numa segunda superficie de linhas.
func _malha_obst(prim: PrimitiveMesh, cor: Color) -> ArrayMesh:
	var arr := prim.get_mesh_arrays()
	var nv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var cs := PackedColorArray()
	for k in nv.size():
		cs.append(_sombreado(cor, nn[k]))
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _mat_obst)
	return m


func _malha_prisma(poly: PackedVector2Array, n_real: int, w: float, cor: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(poly)
	for sx: float in [-w, w]:
		var n := Vector3(signf(sx), 0.0, 0.0)
		for k in tri.size():
			var p := poly[tri[k]]
			st.set_color(_sombreado(cor, n))
			st.add_vertex(Vector3(sx, p.y, p.x))
	for j in poly.size():
		var a := poly[j]
		var b := poly[(j + 1) % poly.size()]
		var ed := b - a
		var n := Vector3(0.0, -ed.x, ed.y).normalized()
		var c := _sombreado(cor, n) if j < n_real else _sombreado(cor * 0.7, n)
		for p: Vector3 in [Vector3(-w, a.y, a.x), Vector3(w, a.y, a.x), Vector3(w, b.y, b.x),
				Vector3(-w, a.y, a.x), Vector3(w, b.y, b.x), Vector3(-w, b.y, b.x)]:
			st.set_color(c)
			st.add_vertex(p)
	var m := st.commit()
	m.surface_set_material(0, _mat_obst)
	# Contorno do perfil nas duas faces e as quinas ao longo de x.
	var ln := PackedVector3Array()
	for j in n_real:
		for sx: float in [-w, w, 0.0]:
			ln.append(Vector3(sx, poly[j].y, poly[j].x))
			ln.append(Vector3(sx, poly[j + 1].y, poly[j + 1].x))
	for j: int in [0, 7, 12, 15, n_real]:
		if j >= poly.size():
			continue
		ln.append(Vector3(-w, poly[j].y, poly[j].x))
		ln.append(Vector3(w, poly[j].y, poly[j].x))
	_linhas(m, ln, cor.lightened(0.3))
	return m


func _linhas(m: ArrayMesh, ln: PackedVector3Array, cor: Color) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = ln
	var cs := PackedColorArray()
	cs.resize(ln.size())
	cs.fill(cor)
	arr[Mesh.ARRAY_COLOR] = cs
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	m.surface_set_material(m.get_surface_count() - 1, _mat_linha)


static func _arestas_caixa(h: Vector3) -> PackedVector3Array:
	var ln := PackedVector3Array()
	for a in 3:
		for s1: float in [-1.0, 1.0]:
			for s2: float in [-1.0, 1.0]:
				var p := Vector3.ZERO
				var q := Vector3.ZERO
				p[a] = -h[a]
				q[a] = h[a]
				var b := (a + 1) % 3
				var c := (a + 2) % 3
				p[b] = s1 * h[b]
				q[b] = s1 * h[b]
				p[c] = s2 * h[c]
				q[c] = s2 * h[c]
				ln.append(p)
				ln.append(q)
	return ln


static func _circulo(r: float, eixo: int, alt: float, n: int = 32) -> PackedVector3Array:
	var ln := PackedVector3Array()
	for k in n:
		for j in [k, (k + 1) % n]:
			var a := TAU * float(j) / float(n)
			var p := Vector3.ZERO
			var u := (eixo + 1) % 3
			var v := (eixo + 2) % 3
			p[u] = cos(a) * r
			p[v] = sin(a) * r
			p[eixo] = alt
			ln.append(p)
	return ln


func _montar_fantasmas_obstaculos() -> void:
	for s: Dictionary in solidos:
		var cor: Color = COR_GRUPO.get(s["grupo"], Color(0.6, 0.6, 0.6))
		var m: ArrayMesh = null
		var local := Transform3D()
		match s["tipo"]:
			&"obb", &"obb_local":
				var bx := BoxMesh.new()
				bx.size = (s["h"] as Vector3) * 2.0
				m = _malha_obst(bx, cor)
				_linhas(m, _arestas_caixa(s["h"]), cor.lightened(0.35))
			&"prisma":
				m = _malha_prisma(s["poly"], s["n_real"], s["w"], cor)
			&"coifa":
				var cy := CylinderMesh.new()
				cy.bottom_radius = 0.052
				cy.top_radius = 0.0105
				cy.height = 0.209
				m = _malha_obst(cy, cor)
				_linhas(m, _circulo(0.052, 1, -0.1045), cor.lightened(0.35))
				local = Transform3D(Basis(), Vector3(0.0, 0.0805, 0.0))
			&"capsula_local":
				var cy := CylinderMesh.new()
				cy.bottom_radius = float(s["r"])
				cy.top_radius = float(s["r"])
				cy.height = 0.197
				m = _malha_obst(cy, cor)
				local = Transform3D(Basis(), Vector3(0.0, 0.0985, 0.0))
			&"elipsoide":
				var sp := SphereMesh.new()
				sp.radius = 1.0
				sp.height = 2.0
				m = _malha_obst(sp, cor)
				local = Transform3D(Basis.from_scale(s["semi"]), s["centro"])
			&"toro":
				var tr := TorusMesh.new()
				tr.inner_radius = float(s["R"]) - float(s["r"])
				tr.outer_radius = float(s["R"]) + float(s["r"])
				tr.rings = 48
				m = _malha_obst(tr, cor)
				_linhas(m, _circulo(float(s["R"]), 1, 0.0, 48), cor.lightened(0.35))
				local = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
			&"cilindro_z":
				var cy := CylinderMesh.new()
				cy.bottom_radius = float(s["r"])
				cy.top_radius = float(s["r"])
				cy.height = float(s["z1"]) - float(s["z0"])
				m = _malha_obst(cy, cor)
				local = Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
					Vector3(0.0, 0.0, (float(s["z0"]) + float(s["z1"])) * 0.5))
			&"cilindro_y":
				var cy := CylinderMesh.new()
				cy.bottom_radius = float(s["r"])
				cy.top_radius = float(s["r"])
				cy.height = float(s["y1"]) - float(s["y0"])
				m = _malha_obst(cy, cor)
				local = Transform3D(Basis(), Vector3(0.0, (float(s["y0"]) + float(s["y1"])) * 0.5, 0.0))
		if m == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.layers = s["camada"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_raiz_fant.add_child(mi)
		_obst_fant.append({"mi": mi, "s": s, "local": local})


func _posicionar_obstaculos() -> void:
	for of: Dictionary in _obst_fant:
		var s: Dictionary = of["s"]
		var mi: MeshInstance3D = of["mi"]
		match s["tipo"]:
			&"obb", &"obb_local":
				mi.transform = Transform3D(s["b"], s["c"])
			&"prisma":
				mi.transform = Transform3D()
			_:
				mi.transform = (s["xf"] as Transform3D) * (of["local"] as Transform3D)
		mi.visible = true


func _por_fantasmas(med: Dictionary) -> void:
	_raiz_fant.global_transform = mot.global_transform
	_raiz_fant.reset_physics_interpolation()
	_posicionar_obstaculos()
	var reps: Dictionary = med.get("_reps", {})
	for k: String in ["D", "E", "L"]:
		var mi: MeshInstance3D = _fant.get(k)
		if mi == null:
			mi = MeshInstance3D.new()
			mi.layers = L_BRACO
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_raiz_fant.add_child(mi)
			_fant[k] = mi
		var xr: MeshInstance3D = _xray.get(k)
		if xr == null:
			xr = MeshInstance3D.new()
			xr.layers = L_XRAY
			xr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_raiz_fant.add_child(xr)
			_xray[k] = xr
		if not reps.has(k):
			mi.visible = false
			xr.visible = false
			continue
		mi.mesh = _malha_fantasma(reps[k])
		mi.visible = true
		var mx := _malha_xray(reps[k])
		xr.mesh = mx
		xr.visible = mx != null
	# As maos do aro (esqueleto de dois ossos): copia com a pele calculada aqui.
	var aros := _aro_malhas() if not med.get("sem_aro", false) else []
	for i in maxi(aros.size(), _aro_fant.size()):
		if i >= _aro_fant.size():
			var ma := MeshInstance3D.new()
			ma.layers = L_BRACO
			ma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_raiz_fant.add_child(ma)
			_aro_fant.append(ma)
		if i < aros.size():
			_aro_fant[i].mesh = aros[i]
			_aro_fant[i].visible = true
		else:
			_aro_fant[i].visible = false
	# O aparelho.
	if _fant_fone == null:
		_fant_fone = MeshInstance3D.new()
		_fant_fone.layers = L_FANT
		_fant_fone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_raiz_fant.add_child(_fant_fone)
		_fant_tela = MeshInstance3D.new()
		_fant_tela.layers = L_FANT
		var qm := QuadMesh.new()
		qm.size = Iphone4S.TELA
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = COR_TELA
		mt.cull_mode = BaseMaterial3D.CULL_DISABLED
		qm.material = mt
		_fant_tela.mesh = qm
		_fant_tela.position = Vector3(0.0, 0.0, Iphone4S.TAMANHO.z * 0.5 + 0.0008)
		_fant_fone.add_child(_fant_tela)
	if _fant_fone_t == null:
		_fant_fone_t = MeshInstance3D.new()
		_fant_fone_t.layers = L_FONE_T
		_fant_fone_t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_raiz_fant.add_child(_fant_fone_t)
	if med.has("_fx"):
		var fx: Transform3D = med["_fx"]
		_fant_fone.transform = fx
		var mf := _malha_fone(fx)
		_fant_fone.mesh = mf
		_fant_fone.visible = true
		# A mesma malha, translucida, com as arestas e o retangulo da tela.
		var mt := _malha_fone(fx)
		mt.surface_set_material(0, _mat_fone_t)
		_linhas(mt, _arestas_fone(), Color(0.05, 0.45, 0.15))
		_fant_fone_t.mesh = mt
		_fant_fone_t.transform = fx
		_fant_fone_t.visible = true
	else:
		_fant_fone.visible = false
		_fant_fone_t.visible = false


func _esconder_fantasmas() -> void:
	for of: Dictionary in _obst_fant:
		(of["mi"] as MeshInstance3D).visible = false
	for k: String in _fant:
		(_fant[k] as MeshInstance3D).visible = false
	for k: String in _xray:
		(_xray[k] as MeshInstance3D).visible = false
	for ma: MeshInstance3D in _aro_fant:
		ma.visible = false
	if _fant_fone != null:
		_fant_fone.visible = false
	if _fant_fone_t != null:
		_fant_fone_t.visible = false


## As arestas do aparelho (contorno das duas faces, as quinas) e o retangulo
## da tela, no espaco dele.
func _arestas_fone() -> PackedVector3Array:
	var ln := PackedVector3Array()
	var n := 32
	for face in 2:
		for k in n:
			ln.append(_contorno_fone[face * n + k])
			ln.append(_contorno_fone[face * n + (k + 1) % n])
	for k: int in [4, 12, 20, 28]:
		ln.append(_contorno_fone[k])
		ln.append(_contorno_fone[n + k])
	var t := Iphone4S.TELA * 0.5
	var z := Iphone4S.TAMANHO.z * 0.5 + 0.0004
	var c := [Vector3(-t.x, -t.y, z), Vector3(t.x, -t.y, z), Vector3(t.x, t.y, z), Vector3(-t.x, t.y, z)]
	for k in 4:
		ln.append(c[k])
		ln.append(c[(k + 1) % 4])
	return ln


## Raio X: so os triangulos do braco com vertice dentro de solido (magenta),
## do fone (azul) ou do outro braco (branco), sem teste de profundidade.
func _malha_xray(rep: Dictionary) -> ArrayMesh:
	var dados: Dictionary = rep["dados"]
	var v: PackedVector3Array = dados["v"]
	var idx: PackedInt32Array = dados["i"]
	var dentro: PackedByteArray = rep["dentro"]
	var vv := PackedVector3Array()
	var cs := PackedColorArray()
	var k := 0
	while k + 2 < idx.size():
		var a := idx[k]
		var b := idx[k + 1]
		var c := idx[k + 2]
		k += 3
		var ma := dentro[a]
		var mb := dentro[b]
		var mc := dentro[c]
		var cor := Color()
		if ma == 2 or mb == 2 or mc == 2:
			cor = COR_NO_FONE
		elif ma == 1 or mb == 1 or mc == 1:
			cor = COR_DENTRO
		elif ma == 4 or mb == 4 or mc == 4:
			cor = COR_BRACO_X
		else:
			continue
		for x: int in [a, b, c]:
			vv.append(v[x])
			cs.append(cor)
	if vv.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vv
	arr[Mesh.ARRAY_COLOR] = cs
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _mat_xray)
	return m


## As maos do aro: a malha com pele (dois ossos) calculada na CPU, no espaco do
## motorista. A malha e lida uma vez por esqueleto.
func _aro_malhas() -> Array:
	var out := []
	var inv := mot.global_transform.affine_inverse()
	for b: Dictionary in mot._bracos:
		var e := b.get("esqueleto") as Skeleton3D
		if e == null or not is_instance_valid(e) or not e.is_visible_in_tree():
			continue
		var mi := e.get_node_or_null("Malha") as MeshInstance3D
		if mi == null or mi.mesh == null or mi.skin == null:
			continue
		var chave := mi.get_instance_id()
		var cache: Dictionary = _aro_cache.get(chave, {})
		if cache.is_empty() or cache["mesh"] != mi.mesh:
			var arr := mi.mesh.surface_get_arrays(0)
			var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES] if arr[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS] if arr[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			cache = {"mesh": mi.mesh, "v": vv, "n": arr[Mesh.ARRAY_NORMAL], "o": ossos, "w": pesos,
				"i": ii, "k": (ossos.size() / vv.size()) if vv.size() > 0 else 0}
			_aro_cache[chave] = cache
			print("[diag] mao do aro %s: %d vertices, %d ossos por vertice" % [e.name, vv.size(), cache["k"]])
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		for j in skin.get_bind_count():
			var osso := skin.get_bind_bone(j)
			if osso < 0:
				osso = e.find_bone(skin.get_bind_name(j))
			mats.append(inv * e.global_transform * e.get_bone_global_pose(osso) * skin.get_bind_pose(j))
		var v: PackedVector3Array = cache["v"]
		var nn: PackedVector3Array = cache["n"]
		var kk: int = cache["k"]
		var ossos2: PackedInt32Array = cache["o"]
		var pesos2: PackedFloat32Array = cache["w"]
		var pv := PackedVector3Array()
		pv.resize(v.size())
		var cs := PackedColorArray()
		cs.resize(v.size())
		for i in v.size():
			var p := Vector3.ZERO
			var ws := 0.0
			var w_braco := 0.0
			var dom := 0
			var wdom := -1.0
			for j in kk:
				var w := pesos2[i * kk + j]
				if w <= 0.0:
					continue
				var bi := ossos2[i * kk + j]
				p += (mats[bi] * v[i]) * w
				ws += w
				if bi == 1:
					w_braco += w
				if w > wdom:
					wdom = w
					dom = bi
			pv[i] = p / ws if ws > 0.0 else mats[0] * v[i]
			var n := (mats[dom].basis * nn[i]) if nn.size() == v.size() else Vector3.UP
			cs[i] = _sombreado(COR_ARO_BRACO if w_braco > 0.5 else COR_ARO_MAO, n)
		var a2 := []
		a2.resize(Mesh.ARRAY_MAX)
		a2[Mesh.ARRAY_VERTEX] = pv
		a2[Mesh.ARRAY_COLOR] = cs
		if (cache["i"] as PackedInt32Array).size() > 0:
			a2[Mesh.ARRAY_INDEX] = cache["i"]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
		m.surface_set_material(0, _mat_braco)
		out.append(m)
	return out


## A copia do braco em cores chapadas: peca por peca, e o vertice dentro de
## solido em magenta, dentro do fone em azul, o polegar sobre a tela em ciano.
func _malha_fantasma(rep: Dictionary) -> ArrayMesh:
	var dados: Dictionary = rep["dados"]
	var v: PackedVector3Array = dados["v"]
	var n: PackedVector3Array = dados["n"]
	var faixas: Dictionary = rep["faixas"]
	var dentro: PackedByteArray = rep["dentro"]
	var pu: Vector3 = rep["punho"]
	var eixo: Vector3 = rep["eixo"]
	var comp: float = rep["comp"]
	var cs := PackedColorArray()
	cs.resize(v.size())
	var fm: Vector2i = faixas["mao"]
	var fa: Vector2i = faixas["antebraco"]
	var fp: Vector2i = faixas["polegar"]
	for k in v.size():
		var cor := COR_BRACO
		if k < fm.y:
			cor = COR_POLEGAR if (k >= fp.x and k < fp.y) else COR_MAO
		elif k < fa.y:
			cor = COR_ESPORAO if (v[k] - pu).dot(eixo) > comp + 0.005 else COR_ANTEBRACO
		match dentro[k]:
			1:
				cor = COR_DENTRO
			2:
				cor = COR_NO_FONE
			3:
				cor = COR_SOBRE_TELA
		cs[k] = _sombreado(cor, n[k]) if dentro[k] == 0 else cor
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_INDEX] = dados["i"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _mat_braco)
	return m


## O aparelho chapado (contorno arredondado), com o vertice dentro de solido
## em magenta.
func _malha_fone(fx: Transform3D) -> ArrayMesh:
	var n := 32
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cor_de := func(p: Vector3) -> Color:
		var g := fx * p
		for s: Dictionary in solidos:
			if (s["aabb"] as AABB).has_point(g) and _prof(s, g) > 0.0:
				return COR_DENTRO
		return COR_FONE
	var cf := []
	for k in _contorno_fone.size():
		cf.append(cor_de.call(_contorno_fone[k]))
	for face in 2:
		var c0 := _contorno_fone[2 * n + face]
		for k in n:
			var a := _contorno_fone[face * n + k]
			var b := _contorno_fone[face * n + (k + 1) % n]
			for p: Vector3 in [c0, a, b]:
				st.set_color(_sombreado(COR_FONE, Vector3(0, 0, 1 if face == 0 else -1)))
				st.add_vertex(p)
	for k in n:
		var a := k
		var b := (k + 1) % n
		var quad := [a, b, n + b, a, n + b, n + a]
		for j: int in quad:
			var cc: Color = cf[j]
			st.set_color(cc if cc == COR_DENTRO else _sombreado(cc, Vector3(_contorno_fone[j].x,
				_contorno_fone[j].y, 0.0)))
			st.add_vertex(_contorno_fone[j])
	var m := st.commit()
	m.surface_set_material(0, _mat_braco)
	return m


# --- vistas --------------------------------------------------------------------

func _montar_vistas() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.10, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.glow_enabled = false
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false
	env.sdfgi_enabled = false
	var attr := CameraAttributesPractical.new()
	attr.auto_exposure_enabled = false
	attr.dof_blur_far_enabled = false
	attr.dof_blur_near_enabled = false
	var defs := [
		{"nome": "lado", "orto": true, "tam": 1.15, "de": Vector3(1.4, 0.70, -0.28),
			"para": Vector3(0.0, 0.70, -0.28), "up": Vector3.UP,
			"mask": L_FANT | L_OBST | L_PAINEL | L_BRACO},
		{"nome": "cima", "orto": true, "tam": 1.20, "de": Vector3(0.05, 2.4, -0.30),
			"para": Vector3(0.05, 0.0, -0.30), "up": Vector3.FORWARD,
			"mask": L_FANT | L_OBST | L_PAINEL | L_BRACO},
		{"nome": "fora", "orto": false, "fov": 64.0,
			"de": Vector3(0.58, _piso + 0.98, _olho.z - 0.02),
			"para": Vector3(0.02, _piso + 0.28, _olho.z - 0.34), "up": Vector3.UP,
			"mask": L_FANT | L_OBST | L_PAINEL | L_BRACO},
		{"nome": "frente", "orto": false, "fov": 74.0, "de": Vector3(0.30, 0.99, -0.41),
			"para": Vector3(-0.12, 0.60, 0.08), "up": Vector3.UP,
			"mask": L_FANT | L_OBST | L_BRACO},
		# A lente da cena, so com as copias: a tela chapada e a mao por cima dela.
		# E a regua de pixel da cobertura (o `_cobertura` e a de triangulo).
		{"nome": "lente", "orto": false, "fov": 60.0, "de": Vector3.ZERO,
			"para": Vector3.FORWARD, "up": Vector3.UP, "mask": L_FANT | L_BRACO, "lente": true},
		{"nome": "lente_tela", "orto": false, "fov": 60.0, "de": Vector3.ZERO,
			"para": Vector3.FORWARD, "up": Vector3.UP, "mask": L_FANT, "lente": true},
		# No espaco do aparelho, com ele translucido e o raio X por cima: e onde o
		# "dentro do fone" (azul) aparece, e a folga dedo-costas se mede.
		# Frente: +X a direita, +Y para cima (a tela como o leitor a ve).
		{"nome": "fone_frente", "orto": true, "tam": 0.20,
			"no_fone": Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(0, 0, 0.30)),
			"mask": L_BRACO | L_FONE_T | L_XRAY, "tamanho": SIL_FONE},
		# Lado, de +X (borda direita): o vidro a ESQUERDA da imagem, as costas a
		# direita, +Y para cima.
		{"nome": "fone_lado", "orto": true, "tam": 0.20,
			"no_fone": Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP), Vector3(0.30, 0, 0)),
			"mask": L_BRACO | L_FONE_T | L_XRAY, "tamanho": SIL_FONE},
		# Topo, de +Y (borda de cima) para baixo: +X a direita, o vidro EMBAIXO e
		# as costas em cima.
		{"nome": "fone_topo", "orto": true, "tam": 0.12,
			"no_fone": Transform3D(Basis.looking_at(Vector3(0, -1, 0), Vector3(0, 0, -1)), Vector3(0, 0.30, 0)),
			"mask": L_BRACO | L_FONE_T | L_XRAY, "tamanho": SIL_FONE},
	]
	var vs := get_viewport().get_visible_rect().size
	for d: Dictionary in defs:
		var vp := SubViewport.new()
		vp.size = d.get("tamanho", SIL)
		if d.get("lente", false) and vs.x > 0.0:
			vp.size = Vector2i(SIL_LENTE_L, roundi(float(SIL_LENTE_L) * vs.y / vs.x))
		elif not d.has("no_fone"):
			d["mask"] = int(d["mask"]) | L_XRAY
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.positional_shadow_atlas_size = 0
		vp.use_taa = false
		add_child(vp)
		var cam := Camera3D.new()
		cam.environment = env
		cam.attributes = attr
		cam.compositor = Compositor.new()
		cam.cull_mask = d["mask"]
		cam.near = 0.02
		cam.far = 8.0
		if d["orto"]:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = d["tam"]
		else:
			cam.fov = d["fov"]
		vp.add_child(cam)
		cam.current = true
		var marca := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2.0, 2.0)
		marca.mesh = qm
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.no_depth_test = true
		mm.render_priority = 127
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		marca.material_override = mm
		# As vistas do aparelho nao veem a camada da copia opaca dele.
		marca.layers = L_FONE_T if d.has("no_fone") else L_FANT
		marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cam.add_child(marca)
		d["marca"] = marca
		d["vp"] = vp
		d["cam"] = cam
		_vistas.append(d)


func _posicionar_vista(vw: Dictionary, fx_g: Variant = null) -> void:
	if vw.has("no_fone"):
		# No espaco do aparelho: a camera anda com ele.
		if fx_g != null:
			(vw["cam"] as Camera3D).global_transform = (fx_g as Transform3D) * (vw["no_fone"] as Transform3D)
			(vw["cam"] as Camera3D).reset_physics_interpolation()
		return
	if vw.get("lente", false):
		var principal := get_viewport().get_camera_3d()
		var cam: Camera3D = vw["cam"]
		if principal != null:
			cam.global_transform = principal.global_transform
			cam.fov = principal.fov
			cam.near = principal.near
			cam.reset_physics_interpolation()
		return
	var de: Vector3 = vw["de"]
	var para: Vector3 = vw["para"]
	var xf := Transform3D(Basis.looking_at(para - de, vw["up"]), de)
	(vw["cam"] as Camera3D).global_transform = mot.global_transform * xf
	(vw["cam"] as Camera3D).reset_physics_interpolation()


# --- controle positivo ---------------------------------------------------------------

## Cada sonda com um caso montado para falhar. Imprime e grava; a silhueta do
## controle sai nos dois quadros seguintes.
func _controles() -> void:
	var ok_todos := true
	var linhas: Array = []
	for s: Dictionary in solidos:
		var dentro := Vector3.ZERO
		var fora := Vector3.ZERO
		match s["tipo"]:
			&"obb", &"obb_local":
				var b: Basis = s["b"]
				var h: Vector3 = s["h"]
				var eixo := 0
				if h.y < h[eixo]:
					eixo = 1
				if h.z < h[eixo]:
					eixo = 2
				dentro = (s["c"] as Vector3) + b[eixo] * h[eixo] * 0.5
				fora = (s["c"] as Vector3) + b[eixo] * (h[eixo] + 0.01)
			&"prisma":
				var topo: float = _g["topo"]
				dentro = Vector3(0.2, topo - 0.01, -0.60)
				fora = Vector3(0.2, topo + 0.01, -0.60)
			&"coifa":
				dentro = (s["xf"] as Transform3D) * Vector3(0.0, 0.05, 0.0)
				fora = (s["xf"] as Transform3D) * Vector3(0.07, 0.05, 0.0)
			&"capsula_local":
				dentro = (s["xf"] as Transform3D) * Vector3(0.0, 0.195, 0.0)
				fora = (s["xf"] as Transform3D) * Vector3(0.0, 0.215, 0.034)
			&"elipsoide":
				dentro = (s["xf"] as Transform3D) * (s["centro"] as Vector3)
				fora = (s["xf"] as Transform3D) * ((s["centro"] as Vector3) + Vector3(0.032, 0.0, 0.0))
			&"toro":
				dentro = (s["xf"] as Transform3D) * Vector3(float(s["R"]), 0.0, 0.0)
				fora = (s["xf"] as Transform3D) * Vector3(float(s["R"]), 0.0, 0.03)
			&"cilindro_z":
				dentro = (s["xf"] as Transform3D) * Vector3(0.0, 0.0, -0.01)
				fora = (s["xf"] as Transform3D) * Vector3(float(s["r"]) + 0.01, 0.0, -0.01)
			&"cilindro_y":
				dentro = (s["xf"] as Transform3D) * Vector3(float(s["r"]) - 0.005, 0.002, 0.0)
				fora = (s["xf"] as Transform3D) * Vector3(float(s["r"]) + 0.01, 0.002, 0.0)
			&"porta":
				var lado: float = s["lado"]
				var y := _piso + 0.3
				var z := -0.3
				var pr := it.parede(y, y, z)
				dentro = Vector3(lado * (pr + 0.01), y, z)
				fora = Vector3(lado * (pr - 0.01), y, z)
		var pd := _prof(s, dentro) if (s["aabb"] as AABB).has_point(dentro) else -9.0
		var pf := _prof(s, fora)
		var ok := pd > 0.0 and pf <= 0.0
		ok_todos = ok_todos and ok
		linhas.append("[diag-controle] solido %-18s dentro=%+.2f cm fora=%+.2f cm %s" % [s["nome"],
			pd * 100.0, pf * 100.0, "OK" if ok else "FALHOU"])
	# O braco inteiro: a mao fechada em volta do pomo, e o antebraco cruzando a
	# haste (a haste e mais fina que o braco: so a amostra contraria a ve).
	var pomo: Dictionary = _solido("pomo")
	var xf_pomo: Transform3D = pomo["xf"]
	var c_pomo := xf_pomo * Vector3(0.0, 0.215, 0.0)
	var pele := Color(0.78, 0.62, 0.50)
	var manga := Color(0.45, 0.47, 0.52)
	var r1 := _montar_braco(c_pomo + Vector3(0.0, 0.01, 0.0), Vector3(0.0, 0.0, -1.0), Vector3.UP,
		MaoPosada.pose(&"punho"), true, c_pomo + Vector3(-0.1, 0.15, 0.25),
		c_pomo + Vector3(-0.15, 0.30, 0.45), pele, manga, true)
	var s1 := _sondar_braco(r1)
	r1["dentro"] = s1["dentro"]
	var c_haste := xf_pomo * Vector3(0.0, 0.12, 0.0)
	var o2 := c_haste + Vector3(0.20, 0.0, 0.0)
	var d2 := Vector3(1.0, 0.0, 0.0)
	var pu2 := MaoPosada.punho_de(o2, d2, Vector3.UP)
	var cot2 := pu2 - d2 * 0.25
	var r2 := _montar_braco(o2, d2, Vector3.UP, MaoPosada.pose(&"aberta"), true, cot2,
		cot2 + Vector3(-0.1, 0.2, 0.2), pele, manga, true)
	var s2 := _sondar_braco(r2)
	r2["dentro"] = s2["dentro"]
	var marcha1 := 0
	for nome: String in ["coifa", "haste", "pomo"]:
		if (s1["sol"] as Dictionary).has(nome):
			marcha1 += int((s1["sol"][nome] as Array)[0])
	var vol2: float = float(((s2["vol"] as Dictionary).get("cambio(eixo)", [0.0, ""]) as Array)[0])
	var vert2 := 0
	for nome: String in ["haste"]:
		if (s2["sol"] as Dictionary).has(nome):
			vert2 += int((s2["sol"][nome] as Array)[0])
	var ok1 := marcha1 > 0
	var ok2 := vol2 > 0.0
	ok_todos = ok_todos and ok1 and ok2
	linhas.append("[diag-controle] braco com a mao no pomo: %d vertices dentro do cambio (%s) %s" % [
		marcha1, s1["sol"], "OK" if ok1 else "FALHOU"])
	linhas.append("[diag-controle] antebraco cruzando a haste: vertices dentro da haste=%d (cego, esperado ~0), eixo do cambio dentro da capsula=%.1f cm %s" % [
		vert2, vol2 * 100.0, "OK" if ok2 else "FALHOU"])
	# A mao no aparelho: a pegada de leitura, com o aparelho empurrado 15 mm para
	# dentro da palma, tem de acusar.
	var fx0 := Transform3D(Basis(), Vector3(0.0, 0.8, -0.3))
	var pl := BracoVivo.levar(fx0, mot._pegada_de_leitura())
	var pu3 := MaoPosada.punho_de(pl["o"], pl["d"], pl["dorso"])
	var r3 := _montar_braco(pl["o"], pl["d"], pl["dorso"], pl["pose"], true,
		pu3 + Vector3(0.1, -0.2, 0.1), pu3 + Vector3(0.2, -0.2, 0.35), pele, manga, true)
	var lente0 := Vector3(0.0, -0.066, 0.182)
	var marca3 := PackedByteArray()
	marca3.resize(int(r3["n"]))
	var m_certo := _sondar_mao_no_fone(r3, fx0.affine_inverse(), lente0, true, marca3)
	marca3 = m_certo["_marca"]
	m_certo.erase("_marca")
	var fx_errado := fx0 * Transform3D(Basis(), Vector3(0.0, 0.0, -0.015))
	var marca4 := PackedByteArray()
	marca4.resize(int(r3["n"]))
	var m_errado := _sondar_mao_no_fone(r3, fx_errado.affine_inverse(), lente0, false, marca4)
	marca4 = m_errado["_marca"]
	m_errado.erase("_marca")
	# A profundidade dentro do aparelho satura em 4,65 mm (meia espessura dele):
	# o que cresce e a contagem.
	var ok3 := int(m_errado["n"]) > int(m_certo["n"]) + 20 and float(m_errado["prof_mm"]) > 3.0
	ok_todos = ok_todos and ok3
	linhas.append("[diag-controle] mao da leitura no fone: certo %d vert/%.1f mm, fone 15 mm dentro da palma %d vert/%.1f mm %s" % [
		m_certo["n"], m_certo["prof_mm"], m_errado["n"], m_errado["prof_mm"], "OK" if ok3 else "FALHOU"])
	linhas.append("[diag-controle] leitura (referencia): polegar sobre a tela %d vert, %.1f mm acima; cobre %.1f%% (mao %.1f%%)" % [
		m_certo["pol_tela_n"], m_certo["pol_tela_mm"], m_certo["cob_pol"], m_certo["cob_mao"]])
	# A cobertura: um disco de 15 mm de raio a 10 mm do vidro, no meio da tela.
	var disco := PackedVector3Array()
	var idx := PackedInt32Array()
	disco.append(Vector3(0.0, 0.0, Iphone4S.TAMANHO.z * 0.5 + 0.010))
	for k in 32:
		var a := TAU * float(k) / 32.0
		disco.append(Vector3(cos(a) * 0.015, sin(a) * 0.015, Iphone4S.TAMANHO.z * 0.5 + 0.010))
	for k in 32:
		idx.append(0)
		idx.append(1 + k)
		idx.append(1 + (k + 1) % 32)
	var cob := _cobertura(disco, idx, [Vector2i(0, idx.size())], lente0)
	var esperado := PI * 0.015 * 0.015 / (Iphone4S.TELA.x * Iphone4S.TELA.y) * 100.0
	var ok4 := absf(cob - esperado * 1.1) < esperado * 0.35
	ok_todos = ok_todos and ok4
	linhas.append("[diag-controle] cobertura de um disco de 15 mm a 10 mm do vidro: %.1f%% (area pura %.1f%%, com paralaxe ~%.1f%%) %s" % [
		cob, esperado, esperado * 1.1, "OK" if ok4 else "FALHOU"])
	# O chao: o aparelho deitado com a face de baixo 1 cm dentro do carpete.
	var fx5 := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5),
		Vector3(0.40, _piso + Iphone4S.TAMANHO.z * 0.5 - 0.01, 0.60))
	var f5 := _sondar_fone(fx5)
	var ok5 := absf(float(f5["baixo_cm"]) + 1.0) < 0.05 and (f5["sol"] as Dictionary).has("piso")
	ok_todos = ok_todos and ok5
	linhas.append("[diag-controle] fone 1 cm dentro do carpete: baixo=%.2f cm, solidos=%s %s" % [
		f5["baixo_cm"], f5["sol"], "OK" if ok5 else "FALHOU"])
	# O fone dentro do painel.
	var fx6 := Transform3D(Basis(), Vector3(0.3, float(_g["topo"]) - 0.05, -0.62))
	var f6 := _sondar_fone(fx6)
	var ok6 := (f6["sol"] as Dictionary).has("painel")
	ok_todos = ok_todos and ok6
	linhas.append("[diag-controle] fone dentro do painel: %s %s" % [f6["sol"], "OK" if ok6 else "FALHOU"])
	# O salto: velocidades de 5 quadros e um pulo de 5 cm.
	var hist: Array[float] = [0.12, 0.10, 0.14, 0.11, 0.13]
	var vel := 0.05 / 0.016
	var ok7 := 0.05 > 0.015 and vel > 3.0 * maxf(_mediana(hist), 0.05)
	ok_todos = ok_todos and ok7
	linhas.append("[diag-controle] salto de 5 cm num quadro (mediana %.2f m/s, agora %.2f m/s): %s" % [
		_mediana(hist), vel, "OK" if ok7 else "FALHOU"])
	# A cobertura recortada no vidro: o mesmo triangulo inteiro na frente do vidro
	# e com a base 4 mm DENTRO do aparelho (so a ponta, 1/4 da area, na frente).
	var vid := Iphone4S.TAMANHO.z * 0.5
	var tri_a := PackedVector3Array([Vector3(-0.015, -0.02, vid + 0.004), Vector3(0.015, -0.02, vid + 0.004),
		Vector3(0.0, 0.02, vid + 0.004)])
	var tri_b := PackedVector3Array([Vector3(-0.015, -0.02, vid - 0.004), Vector3(0.015, -0.02, vid - 0.004),
		Vector3(0.0, 0.02, vid + 0.004)])
	var i3 := PackedInt32Array([0, 1, 2])
	var cob_a := _cobertura(tri_a, i3, [Vector2i(0, 3)], lente0)
	var cob_b := _cobertura(tri_b, i3, [Vector2i(0, 3)], lente0)
	var ok8 := cob_b < cob_a * 0.5 and cob_b > cob_a * 0.1
	ok_todos = ok_todos and ok8
	linhas.append("[diag-controle] cobertura recortada no vidro: triangulo na frente %.2f%%, com a base 4 mm dentro do fone %.2f%% (esperado ~1/4) %s" % [
		cob_a, cob_b, "OK" if ok8 else "FALHOU"])
	# Braco contra braco: a mesma mao no pomo, deslocada 3 cm (tem de cruzar) e
	# 40 cm (nao pode cruzar).
	var ra := _montar_braco(c_pomo + Vector3(0.0, 0.01, 0.0), Vector3(0.0, 0.0, -1.0), Vector3.UP,
		MaoPosada.pose(&"punho"), true, c_pomo + Vector3(-0.1, 0.15, 0.25),
		c_pomo + Vector3(-0.15, 0.30, 0.45), pele, manga, true)
	var rb := _montar_braco(c_pomo + Vector3(0.03, 0.01, 0.0), Vector3(0.0, 0.0, -1.0), Vector3.UP,
		MaoPosada.pose(&"punho"), true, c_pomo + Vector3(-0.07, 0.15, 0.25),
		c_pomo + Vector3(-0.12, 0.30, 0.45), pele, manga, true)
	var rc := _montar_braco(c_pomo + Vector3(0.40, 0.01, 0.0), Vector3(0.0, 0.0, -1.0), Vector3.UP,
		MaoPosada.pose(&"punho"), true, c_pomo + Vector3(0.30, 0.15, 0.25),
		c_pomo + Vector3(0.25, 0.30, 0.45), pele, manga, true)
	for rr: Dictionary in [ra, rb, rc]:
		var dz := PackedByteArray()
		dz.resize(int(rr["n"]))
		rr["dentro"] = dz
	var x_ab := _braco_x_braco(ra, rb)
	var x_ac := _braco_x_braco(ra, rc)
	var ok9 := float(x_ab["pen"]) > 0.0 and int(x_ab["n"]) > 0 and float(x_ac["pen"]) <= 0.0
	ok_todos = ok_todos and ok9
	linhas.append("[diag-controle] braco x braco: deslocado 3 cm %.1f cm (%s x %s, %d vert), 40 cm %.1f cm %s" % [
		float(x_ab["pen"]) * 100.0, x_ab["a"], x_ab["b"], x_ab["n"], float(x_ac["pen"]) * 100.0,
		"OK" if ok9 else "FALHOU"])
	# A copia confere com a malha de verdade? So da para ver com o braco na tela;
	# o `rep_mm` e o `n_malha` do log fazem isso a cada quadro.
	linhas.append("[diag-controle] TODOS (sondas) %s" % ("OK" if ok_todos else "FALHOU"))
	for l: String in linhas:
		print(l)
	_controle_linhas = linhas
	_gravar_controle()
	# O controle de PIXEL: as silhuetas dos casos montados para falhar, contadas
	# pela cor. Sai no primeiro quadro da janela (no preparo a janela ainda nao
	# tem o tamanho final).
	var r3_errado := r3.duplicate()
	r3_errado["dentro"] = marca4
	var r3_certo := r3.duplicate()
	r3_certo["dentro"] = marca3
	_controle_fila = [
		{"reps": {"D": r1, "E": r2}, "sufixo": "_controle",
			"esperado": {"magenta@lado": ">0", "magenta@cima": ">0", "magenta@fora": ">0",
				"magenta@frente": ">0"}},
		{"reps": {"D": r3_errado}, "fx": fx_errado, "sufixo": "_controle_fone15mm",
			"esperado": {"azul@fone_frente": ">0", "azul@fone_lado": ">0", "azul@fone_topo": ">0",
				"azul@lado": ">0"}},
		{"reps": {"D": r3_certo}, "fx": fx0, "sufixo": "_controle_fone_certo", "esperado": {}},
		{"reps": {"D": ra, "E": rb}, "sufixo": "_controle_bracos", "esperado": {"branco": ">0"}},
	]


func _solido(nome: String) -> Dictionary:
	for s: Dictionary in solidos:
		if s["nome"] == nome:
			return s
	return {}


## A silhueta do controle: as duas copias montadas para falhar (mao no pomo,
## antebraco na haste), em magenta onde entram.
func _passo_controle(item: Dictionary) -> void:
	_atualizar_solidos()
	var med := {"_reps": item["reps"], "sem_aro": true}
	var fx_g: Variant = null
	if item.has("fx"):
		med["_fx"] = item["fx"]
		fx_g = mot.global_transform * (item["fx"] as Transform3D)
	_por_fantasmas(med)
	for vw: Dictionary in _vistas:
		_posicionar_vista(vw, fx_g)
		_marcar(vw, 510)
		(vw["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	_pend_sil = {"q": 0, "t": 0.0, "pasta": "controle", "sufixo": item["sufixo"], "id": 510,
		"tentativas": 0, "contar": true, "esperado": item.get("esperado", {})}
