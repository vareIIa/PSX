## A medida do final da abertura da estrada (`INTRO-PADRE/PLANO_JOGADO_PARA_FORA.md`,
## secao 5). So nasce com as flags, e nao muda nada na cena.
##
##   --jogado-sonda        a cada quadro, da janela ao branco, o C1: o padre
##                         principal fora do volume do carro. Cada osso do
##                         `Corpo` (e amostras nos segmentos entre eles) e seis
##                         pontos da cabeca (cara, testa, topo, nuca, queixo,
##                         nariz). Acima do peitoril (y >= `PEITORIL`) conta a
##                         distancia ao plano do vidro do motorista, positiva
##                         para fora, e o criterio e d >= `C1_VIDRO`. Abaixo
##                         dele conta a porta (x <= `PORTA_X` - `C1_PORTA`). Os
##                         bracos (`BracoDoPadre`) nao contam: sao o que entra
##                         pelo vao. Uma linha `[jogado]` a cada 0,1 s de
##                         relogio da cena e, no branco, o pior por trecho (de
##                         uma marca `[susto]` a outra). Tambem: a cara na tela
##                         e a distancia dela a lente, e o padre do carona
##                         (raiz e testa ao vidro dele), para provar que ele
##                         nao muda.
##   --jogado-lentes=DIR   tres lentes fixas no espaco da cabine, um quadro a
##                         cada `LENTES_PASSO` s de relogio, em
##                         DIR/<lente>/r_<t>.png (o formato do
##                         `tools/mosaico_rajada.py`): `carona` (do banco do
##                         carona olhando a janela do motorista), `perfil` (de
##                         fora, na frente do carro, o lado do motorista) e
##                         `janela_carona` (do banco do motorista olhando a
##                         janela do carona). As fotos travam o quadro: com
##                         `--fixed-fps` a cena anda igual.
extends Node

## A linha de baixo da janela do motorista (y no carro) e a lataria da porta
## (x), medidas na sonda do plano (`porta_frente`, lado -1).
const PEITORIL := 0.93
const PORTA_X := -0.84
## Os criterios do C1 (m): acima do peitoril, o d minimo; abaixo, a folga da
## porta.
const C1_VIDRO := 0.03
const C1_PORTA := 0.02
## Os pontos da cabeca, na malha da `CabecaDoPadre` (rosto para -Z).
const CABECA_PONTOS := {
	"cara": Vector3(0.0, -0.03, -0.09),
	"testa": Vector3(0.0, 0.052, -0.088),
	"topo": Vector3(0.0, 0.14, 0.0),
	"nuca": Vector3(0.0, 0.05, 0.12),
	"queixo": Vector3(0.0, -0.155, -0.075),
	"nariz": Vector3(0.0, -0.02, -0.114),
}
## Os segmentos do `Corpo` amostrados (osso de, osso para; -1 = tornozelo).
const SEGMENTOS := [["quadril", 0, 1], ["tronco", 1, 2], ["coxa_e", 7, 8], ["coxa_d", 9, 10],
	["canela_e", 8, -1], ["canela_d", 10, -2], ["ombros", 3, 5]]
const OSSOS := {"quadril": 0, "torso": 1, "pescoco": 2, "ombro_e": 3, "ombro_d": 5,
	"anca_e": 7, "joelho_e": 8, "anca_d": 9, "joelho_d": 10}
const Y_JOELHO := 0.46
const Y_TORNOZELO := 0.07
const Y_QUADRIL := 0.90
const LENTES_PASSO := 0.25
## [de, para, campo], no espaco da cabine.
const LENTES := {
	"carona": [Vector3(0.45, 1.25, -0.05), Vector3(-0.9, 1.05, -0.1), 75.0],
	"perfil": [Vector3(-1.05, 1.25, -2.9), Vector3(-1.05, 1.05, 0.0), 40.0],
	"janela_carona": [Vector3(-0.25, 1.2, 0.05), Vector3(0.9, 1.08, -0.1), 60.0],
}

var _cena: Node
var _ligada := false
var _prox := -INF
var _prox_lente := -INF
var _pasta_lentes := ""
var _vps := {}
var _fim := false
## O trecho de agora (a ultima marca) e o pior de cada ponto nele e no todo.
var _trecho := "janela"
var _t_estouro := INF
## Quando o vidro do motorista sumiu (a trinca some com ele): do estouro ate
## aqui a testa encosta no vidro ainda inteiro, esfarelando.
var _t_buraco := INF
var _quadros_buraco := 0
var _viol_buraco := 0
var _pior_trecho := {}
var _ordem_trechos: Array[String] = []
var _pior_todo := {}
var _pior_depois := {}
## A cara na tela: quadros na frase dentro do quadro e no terco esquerdo.
var _frase := {"n": 0, "quadro": 0, "terco": 0, "dist_min": INF, "dist_max": 0.0, "x_min": INF,
	"x_max": -INF, "x_soma": 0.0}
var _quadros := 0
var _viol_depois := 0


func _init(cena: Node) -> void:
	_cena = cena
	name = "SondaJogado"
	# Depois da cena, do agarrao (200) e de tudo que mexe no padre e na lente.
	process_priority = 1000
	_ligada = OS.get_cmdline_user_args().has("--jogado-sonda")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--jogado-lentes="):
			_pasta_lentes = a.trim_prefix("--jogado-lentes=")


func _ready() -> void:
	if not _pasta_lentes.is_empty():
		_montar_lentes()
	if _ligada:
		var cab: Node3D = _cena._carro.cabine
		var a: Dictionary = _cena._abertura(&"porta_frente", -1)
		print("[jogado] vidro do motorista (cabine): centro %s normal %s; peitoril y %.3f, porta x %.3f" % [
			_v(a["centro"]), _v((a["normal"] as Vector3).normalized()), PEITORIL, PORTA_X])
		print("[jogado] cabine no carro: %s giro %s" % [_v(cab.position), _v(cab.rotation_degrees)])
		RenderingServer.frame_pre_draw.connect(_antes_de_desenhar)


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_antes_de_desenhar):
		RenderingServer.frame_pre_draw.disconnect(_antes_de_desenhar)


func _v(p: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [p.x, p.y, p.z]


func _process(_delta: float) -> void:
	if _cena == null or not is_instance_valid(_cena) or _cena._no_branco:
		return
	var t: float = _cena._relogio_cena
	if not _pasta_lentes.is_empty() and t >= _prox_lente:
		_prox_lente = t + LENTES_PASSO
		_fotografar(t)


## A medida no quadro que vai ser desenhado: a pose, a lente, a marca e o
## buraco ja sao os deste quadro (a marca e o buraco saem de corrotinas, que
## rodam depois do `_process` de todos).
func _antes_de_desenhar() -> void:
	if _cena == null or not is_instance_valid(_cena) or _fim:
		return
	if _cena._no_branco:
		_fechar()
		return
	var t: float = _cena._relogio_cena
	var trecho := _marca_de_agora()
	var tr: Node3D = _cena._trinca_testa
	if trecho == "estoura" and tr != null and is_instance_valid(tr) and not tr.visible:
		trecho = "buraco"
	if trecho != _trecho:
		_trecho = trecho
		if trecho == "estoura" and _t_estouro == INF:
			_t_estouro = t
		if trecho == "buraco" and _t_buraco == INF:
			_t_buraco = t
	if not _ordem_trechos.has(_trecho):
		_ordem_trechos.append(_trecho)
	_medir(t)


## A ultima marca `[susto]` da cena. A cena so guarda o trecho com
## `--medir-quadros`; sem ele, a sonda segue as marcas pelo que a cena ja fez.
func _marca_de_agora() -> String:
	var m: Variant = _cena.get(&"_marca_atual")
	if m is String and not (m as String).is_empty():
		return m
	return "estoura" if _trecho == "buraco" else _trecho


## Os pontos do padre principal (espaco da cabine): nome -> posicao.
func _pontos(cab: Node3D) -> Dictionary:
	var out := {}
	var padre: Node3D = _cena._padre
	if padre == null or not is_instance_valid(padre):
		return out
	var sk: Skeleton3D = padre.esqueleto()
	if sk == null:
		return out
	var inv := cab.global_transform.affine_inverse() * sk.global_transform
	var ossos := {}
	for k: String in OSSOS:
		var p := inv * sk.get_bone_global_pose(int(OSSOS[k])).origin
		ossos[int(OSSOS[k])] = p
		out[k] = p
	# Os tornozelos: a ponta da canela, no comprimento dela no repouso.
	var esc := -sk.get_bone_rest(8).origin.y / (Y_QUADRIL - Y_JOELHO)
	for par: Array in [[8, -1], [10, -2]]:
		var g := sk.get_bone_global_pose(int(par[0]))
		ossos[int(par[1])] = inv * (g * Vector3(0.0, -(Y_JOELHO - Y_TORNOZELO) * esc, 0.0))
	out["tornozelo_e"] = ossos[-1]
	out["tornozelo_d"] = ossos[-2]
	for s: Array in SEGMENTOS:
		var a: Vector3 = ossos[int(s[1])]
		var b: Vector3 = ossos[int(s[2])]
		for i in [1, 2, 3]:
			out["%s_%d" % [s[0], i]] = a.lerp(b, float(i) / 4.0)
	var rosto := padre.get_meta(&"rosto", null) as Node3D
	if rosto != null and is_instance_valid(rosto):
		var r := cab.global_transform.affine_inverse() * rosto.global_transform
		for k: String in CABECA_PONTOS:
			out[k] = r * (CABECA_PONTOS[k] as Vector3)
	return out


## A folga de `p` no C1 (m, negativa = violacao) e a medida crua: acima do
## peitoril o d ao plano do vidro, abaixo a distancia a porta.
func _folga(p: Vector3, c: Vector3, n: Vector3) -> Vector2:
	if p.y >= PEITORIL:
		var d := (p - c).dot(n)
		return Vector2(d - C1_VIDRO, d)
	var porta := PORTA_X - p.x
	return Vector2(porta - C1_PORTA, porta)


func _anotar(tab: Dictionary, k: String, f: Vector2, t: float) -> void:
	if not tab.has(k) or f.x < (tab[k] as Array)[0]:
		tab[k] = [f.x, f.y, t]


func _medir(t: float) -> void:
	var cab: Node3D = _cena._carro.cabine
	var a: Dictionary = _cena._abertura(&"porta_frente", -1)
	if cab == null or a.is_empty():
		return
	var c: Vector3 = a["centro"]
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	var pts := _pontos(cab)
	var pior_k := ""
	var pior := Vector2(INF, INF)
	if not _pior_trecho.has(_trecho):
		_pior_trecho[_trecho] = {}
	var depois := t >= _t_estouro
	for k: String in pts:
		var f := _folga(pts[k], c, n)
		_anotar(_pior_trecho[_trecho], k, f, t)
		_anotar(_pior_todo, k, f, t)
		if depois:
			_anotar(_pior_depois, k, f, t)
		if f.x < pior.x:
			pior = f
			pior_k = k
	if depois:
		_quadros += 1
		if pior.x < 0.0:
			_viol_depois += 1
	if t >= _t_buraco:
		_quadros_buraco += 1
		if pior.x < 0.0:
			_viol_buraco += 1
	var cam: Camera3D = _cena._cam
	var tela := _cara_na_tela(cam, pts, cab)
	if _trecho == "frase":
		_frase.n += 1
		if tela.z > 0.0:
			_frase.quadro += 1
			if tela.x < -1.0 / 3.0:
				_frase.terco += 1
			_frase.dist_min = minf(_frase.dist_min, tela.w)
			_frase.dist_max = maxf(_frase.dist_max, tela.w)
			_frase.x_min = minf(_frase.x_min, tela.x)
			_frase.x_max = maxf(_frase.x_max, tela.x)
			_frase.x_soma += tela.x
	if t < _prox:
		return
	_prox = t + 0.1
	var lp := cab.to_local(cam.global_position)
	var linha := "[jogado] t=%.2f %s %-11s lente %s d=%.3f fov %.1f near %.3f | C1 %s pior %s folga %+.3f (%s %.3f)" % [
		t, ("E%+.2f" % (t - _t_estouro)) if _t_estouro != INF else "E?    ", _trecho, _v(lp),
		(lp - c).dot(n), cam.fov, cam.near, "OK   " if pior.x >= 0.0 else "FALHA", pior_k, pior.x,
		"d" if pts.has(pior_k) and (pts[pior_k] as Vector3).y >= PEITORIL else "porta", pior.y]
	for k: String in ["cara", "topo", "nuca", "ombro_e", "ombro_d", "joelho_e", "joelho_d", "quadril"]:
		if pts.has(k):
			var f := _folga(pts[k], c, n)
			linha += " %s %+.3f" % [k, f.y]
	var padre: Node3D = _cena._padre
	if padre != null:
		linha += " raiz %s" % _v(cab.to_local(padre.global_position))
	if tela.z > 0.0:
		linha += " | cara na tela (%.2f, %.2f) a %.2f m" % [tela.x, tela.y, tela.w]
	else:
		linha += " | cara fora da tela"
	var maos: Array = _cena._maos_padre
	for i in maos.size():
		var b = maos[i]
		if b != null and b.visible and not (b.pegada as Dictionary).is_empty():
			var par := b.get_parent() as Node3D
			var mo := cab.to_local(par.to_global(b.pegada["o"]))
			linha += " | mao%d %s alcance %.3f" % [i, _v(mo), mo.distance_to(b.ombro)]
	print(linha)
	_carona(t, cab)


## A cara na tela da lente (x, y de -1 a 1; z > 0 se esta no quadro e na
## frente; w a distancia a lente).
func _cara_na_tela(cam: Camera3D, pts: Dictionary, cab: Node3D) -> Vector4:
	if not pts.has("cara"):
		return Vector4(0.0, 0.0, -1.0, INF)
	var p := cab.to_global(pts["cara"])
	var dist := cam.global_position.distance_to(p)
	if cam.is_position_behind(p):
		return Vector4(0.0, 0.0, -1.0, dist)
	var px := cam.unproject_position(p)
	var vp := get_viewport().get_visible_rect().size
	var x := px.x / vp.x * 2.0 - 1.0
	var y := 1.0 - px.y / vp.y * 2.0
	var dentro := 1.0 if absf(x) <= 1.0 and absf(y) <= 1.0 else -1.0
	return Vector4(x, y, dentro, dist)


## O padre do carona: a raiz dele no carro, a testa ao vidro e a pose pedida.
func _carona(t: float, cab: Node3D) -> void:
	var pnj: Node = null
	for f: Node in _cena.get_children():
		var s: Script = f.get_script()
		if s != null and s.get_global_name() == &"PadresNasJanelas":
			pnj = f
			break
	if pnj == null:
		return
	var corpo := pnj.get("_corpo") as Node3D
	var pose = pnj.get("_pose")
	if corpo == null or pose == null:
		return
	var testa: Vector3 = cab.global_transform.affine_inverse() * (pose.testa() as Vector3)
	print("[jogado] carona t=%.2f raiz %s testa %s testa_ao_vidro %.4f encara %.3f recua %.3f bote %.3f" % [
		t, _v(corpo.position), _v(testa), pose.distancia_agora(), pose.encara, pose.recua, pose.bote])


func _fechar() -> void:
	_fim = true
	if not _ligada:
		return
	print("[jogado] ---- C1 por trecho (pior folga; negativa = violacao; d = plano do vidro, porta = lataria) ----")
	for tr: String in _ordem_trechos:
		if not _pior_trecho.has(tr):
			continue
		var tab: Dictionary = _pior_trecho[tr]
		var pk := ""
		var pv := INF
		for k: String in tab:
			if (tab[k] as Array)[0] < pv:
				pv = (tab[k] as Array)[0]
				pk = k
		var cara: Array = tab.get("cara", [NAN, NAN, NAN])
		var joelho := INF
		for k: String in ["joelho_e", "joelho_d"]:
			if tab.has(k):
				joelho = minf(joelho, (tab[k] as Array)[1])
		print("[jogado] trecho %-11s C1 %s pior %-12s folga %+.3f (medida %+.3f em t=%.2f); cara d %+.3f; joelho a porta %+.3f" % [
			tr, "OK   " if pv >= 0.0 else "FALHA", pk, pv, (tab[pk] as Array)[1], (tab[pk] as Array)[2],
			cara[1], joelho])
	var s := "[jogado] pior de cada ponto do estouro ao branco (medida):"
	var chaves := _pior_depois.keys()
	chaves.sort_custom(func(x: String, y: String) -> bool:
		return (_pior_depois[x] as Array)[0] < (_pior_depois[y] as Array)[0])
	for k: String in chaves.slice(0, 14):
		s += " %s %+.3f" % [k, (_pior_depois[k] as Array)[1]]
	print(s)
	print("[jogado] C1 %s: %d de %d quadros do estouro ao branco com violacao" % [
		"OK" if _viol_depois == 0 else "FALHA", _viol_depois, _quadros])
	print("[jogado] C1 desde o buraco (E%+.2f) %s: %d de %d quadros com violacao" % [
		_t_buraco - _t_estouro, "OK" if _viol_buraco == 0 else "FALHA", _viol_buraco, _quadros_buraco])
	if _frase.n > 0:
		print("[jogado] frase: %d quadros; cara no quadro em %d (%.2f s), no terco esquerdo (x < -1/3) em %d (%.2f s); x na tela de %.2f a %.2f, media %.2f; a %.2f a %.2f m da lente" % [
			_frase.n, _frase.quadro, _frase.quadro / 30.0, _frase.terco, _frase.terco / 30.0,
			_frase.x_min, _frase.x_max, _frase.x_soma / maxf(1.0, float(_frase.quadro)),
			_frase.dist_min, _frase.dist_max])


func _montar_lentes() -> void:
	var mundo := get_viewport().find_world_3d()
	for nome: String in LENTES:
		var vp := SubViewport.new()
		vp.size = Vector2i(960, 540)
		vp.world_3d = mundo
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = float(LENTES[nome][2])
		cam.near = 0.02
		vp.add_child(cam)
		cam.current = true
		_vps[nome] = [vp, cam]
	_seguir()


func _seguir() -> void:
	var cab: Node3D = _cena._carro.cabine
	for nome: String in _vps:
		var cam: Camera3D = _vps[nome][1]
		var de: Vector3 = LENTES[nome][0]
		var para: Vector3 = LENTES[nome][1]
		cam.global_transform = cab.global_transform * Transform3D(Basis.looking_at(para - de, Vector3.UP), de)


func _fotografar(t: float) -> void:
	_seguir()
	await RenderingServer.frame_post_draw
	for nome: String in _vps:
		var vp: SubViewport = _vps[nome][0]
		var pasta := _pasta_lentes.path_join(nome)
		DirAccess.make_dir_recursive_absolute(pasta)
		vp.get_texture().get_image().save_png(pasta.path_join("r_%07.2f.png" % t))
