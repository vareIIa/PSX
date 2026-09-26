## Regua da luz do fogo do capo: quanto a luz do incendio acende cada rosto
## perto dele, e quanto acende o corpo (o controle positivo). Tambem mede a GPU
## da cena por trecho, em percentis.
##
## Por que existe
## --------------
## O pedido era "a luz do fogo atravessa o capuz e acende a cara dele". O olho
## julga isso mal numa rajada: a cara clara pode ser o farol, o reflexo do
## painel, a luz falsa `FogoNaCara` ou o rebote. Aqui a cena congela e so a luz
## do fogo muda entre dois quadros; a diferenca, na mascara de cada rosto, e o
## que a luz do fogo pos nele.
##
## Como mede
## ---------
## `--sonda-fogo=T1,T2,...` (segundos desde que o fogo pegou) e
## `--sonda-fogo-pasta=DIR`. Em cada T:
##   1. congela a cena (`Engine.time_scale`, nao `paused`: os timers do roteiro
##      correm na pausa) e a exposicao automatica (sensibilidade fixa: a
##      exposicao seguiria a propria luz que se mede);
##   2. esconde as particulas do fogo por `layers = 0` (os setters reacendem
##      `visible`), para medir a LUZ e nao a chama desenhada por cima;
##   3. para cada rosto (`CabecaDoPadre`) a menos de `RAIO` m do fogo, tres
##      lentes: a da cena (a janela), uma de frente para a cara (`cara`) e uma
##      no lugar da luz do fogo olhando a cara (`fogo`: o que ela ve e,
##      por definicao, o que ela acende — e o controle positivo geometrico);
##   4. quatro estados, cada um assentado por `ASSENTA` quadros (TAA, SDFGI):
##      fogo apagado, fogo aceso, mascara do rosto e mascara do corpo. A mascara
##      e uma luz de sonda que so alcanca a camada da mascara (`CAMADA_*`): o
##      pixel que acende com ela e o do rosto (ou do corpo) visivel, com a
##      oclusao certa;
##   5. imprime, por lente e mascara, a luminancia media (linear) com o fogo
##      apagado e aceso e a diferenca, e grava as imagens em DIR.
##
## `--fogo-gpu`: a GPU de cada quadro (`viewport_get_measured_render_time_gpu`)
## guardada pelo trecho da cena (`_mq_trecho` da `AberturaEstrada`, com
## `--medir-quadros`) e impressa no fim em p10/p50/p90/max. Os seis primeiros
## quadros de cada trecho saem da conta: a medida chega atrasada.
class_name SondaDoFogo
extends Node

const RAIO := 4.5
const ASSENTA := 24
const CAMADA_ROSTO := 1 << 16
const CAMADA_CORPO := 1 << 15
const TAMANHO := Vector2i(640, 640)
## A sensibilidade fixa durante a sonda: o piso de ISO da noite da `Lente`.
const ISO := 170.0

var fogo: Node3D
var _tempos: Array[float] = []
var _pasta := ""
var _t := 0.0
var _rodando := false
var _gpu := false
var _gpu_amostras: Dictionary = {}
var _gpu_trecho := ""
var _gpu_n_trecho := 0
var _folga := false
var _abertura: Node
var _env_lente: Environment
var _atr_lente: CameraAttributesPractical


## A sonda de `f`, se a linha de comando pediu uma; senao null.
static func criar(f: Node3D) -> SondaDoFogo:
	var s := SondaDoFogo.new()
	s.name = "SondaDoFogo"
	s.fogo = f
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--sonda-fogo="):
			for t: String in a.trim_prefix("--sonda-fogo=").split(","):
				s._tempos.append(float(t))
		elif a.begins_with("--sonda-fogo-pasta="):
			s._pasta = a.trim_prefix("--sonda-fogo-pasta=")
		elif a == "--fogo-gpu":
			s._gpu = true
		elif a == "--sonda-fogo-folga":
			s._folga = true
	if s._tempos.is_empty() and not s._gpu and not s._folga:
		s.free()
		return null
	s._tempos.sort()
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	return s


func _ready() -> void:
	if not _pasta.is_empty():
		DirAccess.make_dir_recursive_absolute(_pasta)
	if _gpu:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		print("[fogo_gpu] placa %s" % RenderingServer.get_video_adapter_name())


## `--sonda-fogo-folga`: cada ponto em que a chama nasce contra a lataria de
## verdade (a malha amassada do carro, lida de volta uma vez): a distancia ate
## a chapa para dentro, se ha chapa por cima dele (nasceria debaixo do metal),
## e se a subida dele (0,8 m para cima) atravessa chapa.
func _folgas() -> void:
	var carro := fogo.get_parent()
	var corpo := carro.get(&"_corpo") as MeshInstance3D if carro != null else null
	if corpo == null or corpo.mesh == null or not fogo.has_method(&"nascimentos"):
		print("[sonda_fogo] folga: sem lataria")
		return
	var tris := PackedVector3Array()
	for si in corpo.mesh.get_surface_count():
		var arr := corpo.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var x := corpo.transform
		if idx.is_empty():
			for k in v.size():
				tris.append(x * v[k])
		else:
			for k in idx.size():
				tris.append(x * v[idx[k]])
	var dentro_min := INF
	var dentro_max := 0.0
	var sob_metal := 0
	var sobe_fura := 0
	var sem_chapa := 0
	var pts: Array = fogo.call(&"nascimentos")
	for par: Array in pts:
		var p: Vector3 = par[0]
		var fora: Vector3 = par[1]
		var d_in := _raio(tris, p, -fora, 0.3)
		var d_out := _raio(tris, p, fora, 0.5)
		var d_up := _raio(tris, p + Vector3.UP * 0.005, Vector3.UP, 0.8)
		if d_in < INF:
			dentro_min = minf(dentro_min, d_in)
			dentro_max = maxf(dentro_max, d_in)
		else:
			sem_chapa += 1
		if d_out < INF:
			sob_metal += 1
			print("[sonda_fogo] folga:   debaixo de metal: %s fora %s (chapa a %.3f m)" % [p, fora, d_out])
		if d_up < INF:
			sobe_fura += 1
			print("[sonda_fogo] folga:   subida fura: %s (chapa a %.3f m acima)" % [p, d_up])
	print("[sonda_fogo] folga: %d pontos, %d triangulos; chapa por dentro a %.3f..%.3f m (%d sem chapa em 0,3 m); debaixo de metal %d; subida furando chapa %d" % [
		pts.size(), tris.size() / 3, dentro_min, dentro_max, sem_chapa, sob_metal, sobe_fura])


static func _raio(tris: PackedVector3Array, de: Vector3, dir: Vector3, ate: float) -> float:
	var melhor := INF
	for k in range(0, tris.size(), 3):
		var a := tris[k]
		# Poda barata: o triangulo longe da reta nao conta.
		if a.distance_to(de) > ate + 0.6:
			continue
		var h: Variant = Geometry3D.ray_intersects_triangle(de, dir, a, tris[k + 1], tris[k + 2])
		if h != null:
			var d := ((h as Vector3) - de).length()
			if d <= ate and d < melhor:
				melhor = d
	return melhor


func _process(delta: float) -> void:
	if _gpu and not _rodando:
		_amostrar_gpu()
	# Um segundo de fogo: o amassado sobe para a malha alguns quadros depois
	# da batida (thread), e na bancada o fogo nasce no mesmo quadro dela.
	if _folga and _t >= 1.0:
		_folga = false
		_folgas()
	if fogo != null and float(fogo.get(&"fogo")) > 0.01:
		_t += delta
	if _rodando or _tempos.is_empty() or fogo == null:
		return
	if _t >= _tempos[0]:
		var t := _tempos.pop_front() as float
		_rodando = true
		await _sondar(t)
		_rodando = false


func _amostrar_gpu() -> void:
	# O trecho vem da `AberturaEstrada` (`_mq_trecho`, com `--medir-quadros`);
	# ela nao e a raiz da cena (a raiz e a `Cidade`).
	if _abertura == null:
		var achados := get_tree().root.find_children("*", "AberturaEstrada", true, false)
		_abertura = achados[0] if not achados.is_empty() else get_tree().current_scene
	var trecho := "?"
	if _abertura != null and &"_mq_trecho" in _abertura:
		trecho = str(_abertura.get(&"_mq_trecho"))
	if trecho != _gpu_trecho:
		_gpu_trecho = trecho
		_gpu_n_trecho = 0
	_gpu_n_trecho += 1
	if _gpu_n_trecho <= 6:
		return
	var ms := RenderingServer.viewport_get_measured_render_time_gpu(
		get_viewport().get_viewport_rid())
	if not _gpu_amostras.has(trecho):
		_gpu_amostras[trecho] = PackedFloat32Array()
	var a: PackedFloat32Array = _gpu_amostras[trecho]
	a.append(ms)
	_gpu_amostras[trecho] = a


func _exit_tree() -> void:
	if not _gpu:
		return
	for trecho: String in _gpu_amostras:
		var a: PackedFloat32Array = _gpu_amostras[trecho]
		if a.size() < 5:
			continue
		var s := Array(a)
		s.sort()
		var n := s.size()
		print("[fogo_gpu] %-14s n=%4d  p10 %5.2f  p50 %5.2f  p90 %5.2f  max %5.2f ms" % [
			trecho, n, s[int(n * 0.1)], s[int(n * 0.5)], s[mini(n - 1, int(n * 0.9))],
			s[n - 1]])


# --- a sonda ---------------------------------------------------------------

func _sondar(t: float) -> void:
	var escala := Engine.time_scale
	Engine.time_scale = 0.0001
	var atrib := _atributos()
	# O brilho (glow) espalha o rosto aceso pela luz de mascara em um halo, e a
	# mascara saia uma bolha do tamanho da cabeca: desligado durante a sonda.
	var env := _ambiente()
	var glow_antes := env != null and env.glow_enabled
	if env != null:
		env.glow_enabled = false
	var auto_antes := true
	var iso_antes := 100.0
	if atrib != null:
		auto_antes = atrib.auto_exposure_enabled
		iso_antes = atrib.exposure_sensitivity
		atrib.auto_exposure_enabled = false
		atrib.exposure_sensitivity = ISO
	# O fogo: as luzes dele (e a falsa da cara do carona, se houver), com a
	# energia deste instante, e as particulas fora da imagem.
	var luzes: Array[Light3D] = []
	for n: Node in fogo.find_children("*", "Light3D", true, false):
		luzes.append(n as Light3D)
	var falsa := get_tree().root.find_child("FogoNaCara", true, false) as Light3D
	if falsa != null:
		luzes.append(falsa)
	var estado_luz: Array = []
	for l: Light3D in luzes:
		estado_luz.append(l.visible)
	var particulas: Array = []
	for n: Node in fogo.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		particulas.append([g, g.layers])
		g.layers = 0
	# O inventario: toda luz acesa a menos de RAIO do fogo (sombra ou nao).
	for n: Node in get_tree().root.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if not l.is_visible_in_tree() or l.light_energy <= 0.0:
			continue
		var d := l.global_position.distance_to(fogo.global_position)
		if d > RAIO and not l is DirectionalLight3D:
			continue
		var alcance := 0.0
		if l is OmniLight3D:
			alcance = (l as OmniLight3D).omni_range
		elif l is SpotLight3D:
			alcance = (l as SpotLight3D).spot_range
		print("[sonda_fogo] t=%.1f luz %-40s %-16s energia %5.2f alcance %5.1f sombra %s a %.2f m do fogo" % [
			t, str(get_tree().root.get_path_to(l)).right(40), l.get_class(), l.light_energy,
			alcance, l.shadow_enabled, d])
	# Os alvos.
	var alvos: Array[Dictionary] = []
	for n: Node in get_tree().root.find_children("*", "CabecaDoPadre", true, false):
		var cab := n as Node3D
		if not cab.is_visible_in_tree():
			continue
		if cab.global_position.distance_to(fogo.global_position) > RAIO:
			continue
		alvos.append(_alvo(cab))
	var principal := get_viewport()
	var lentes: Array[Dictionary] = [{"nome": "cena", "vp": principal, "de": ""}]
	var luz_fogo := _luz_principal(luzes)
	if luz_fogo != null and fogo.get_parent() is Node3D:
		print("[sonda_fogo] t=%.1f luz do fogo no carro em %s" % [t,
			(fogo.get_parent() as Node3D).to_local(luz_fogo.global_position)])
	for a: Dictionary in alvos:
		var centro: Vector3 = a["centro"]
		var frente: Vector3 = a["frente"]
		lentes.append(_lente("cara_" + str(a["nome"]), centro + frente * 0.6
			+ Vector3.UP * 0.04, centro, 34.0, a["nome"]))
		if luz_fogo != null:
			lentes.append(_lente("fogo_" + str(a["nome"]), luz_fogo.global_position,
				centro, 40.0, a["nome"]))
	# Os quatro estados.
	for i in luzes.size():
		luzes[i].visible = false
	var img_off := await _fotografar(lentes)
	for i in luzes.size():
		luzes[i].visible = bool(estado_luz[i])
	var img_on := await _fotografar(lentes)
	for i in luzes.size():
		luzes[i].visible = false
	var mascaras := {}
	# Na mascara, sem SSIL: ele leva a luz de mascara do rosto para a mao e a
	# gola ao lado. (O SDFGI fica: desligar e religar as cascatas no meio da
	# cena esgotou a VRAM.)
	var ssil_antes := env != null and env.ssil_enabled
	if env != null:
		env.ssil_enabled = false
	for tipo: String in ["rosto", "corpo"]:
		var camada := CAMADA_ROSTO if tipo == "rosto" else CAMADA_CORPO
		# A ordem importa: mudar a camada de uma malha no mesmo quadro em que
		# a luz de mascara morre derruba o motor ("indexing did not unpair
		# geometries from light", e depois falha de segmentacao). A camada entra
		# antes das luzes nascerem e sai quadros depois de elas morrerem.
		for a: Dictionary in alvos:
			for g: GeometryInstance3D in a[tipo]:
				if is_instance_valid(g):
					g.layers |= camada
		await _quadros(2)
		var sondas: Array[Light3D] = []
		for a: Dictionary in alvos:
			sondas.append_array(_luzes_de_mascara(a["centro"], camada))
		var img_m := await _fotografar(lentes)
		for l: Light3D in sondas:
			l.queue_free()
		await _quadros(3)
		for a: Dictionary in alvos:
			for g: GeometryInstance3D in a[tipo]:
				if is_instance_valid(g):
					g.layers &= ~camada
		await _quadros(2)
		mascaras[tipo] = img_m
	if env != null:
		env.ssil_enabled = ssil_antes
	for i in luzes.size():
		luzes[i].visible = bool(estado_luz[i])
	# A conta.
	for k in lentes.size():
		var nome: String = lentes[k]["nome"]
		var off: Image = img_off[k]
		var on: Image = img_on[k]
		for tipo: String in ["rosto", "corpo"]:
			var m: Image = (mascaras[tipo] as Array)[k]
			var r := _medir(off, on, m)
			print("[sonda_fogo] t=%.1f lente=%-18s mascara=%-5s n=%6d  apagado %.4f  aceso %.4f  delta %.4f" % [
				t, nome, tipo, r[0], r[1], r[2], r[2] - r[1]])
			if not _pasta.is_empty():
				_mascara_png(m, off).save_png(_pasta.path_join("t%04.1f_%s_m_%s.png" % [t, nome, tipo]))
		if not _pasta.is_empty():
			off.save_png(_pasta.path_join("t%04.1f_%s_apagado.png" % [t, nome]))
			on.save_png(_pasta.path_join("t%04.1f_%s_aceso.png" % [t, nome]))
	for k in range(1, lentes.size()):
		(lentes[k]["vp"] as Node).queue_free()
	for p: Array in particulas:
		(p[0] as GeometryInstance3D).layers = int(p[1])
	if atrib != null:
		atrib.auto_exposure_enabled = auto_antes
		atrib.exposure_sensitivity = iso_antes
	if env != null:
		env.glow_enabled = glow_antes
	Engine.time_scale = escala


func _mundo() -> WorldEnvironment:
	var we := get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
	if we == null:
		var todos := get_tree().root.find_children("*", "WorldEnvironment", true, false)
		if not todos.is_empty():
			we = todos[0] as WorldEnvironment
	return we


func _atributos() -> CameraAttributesPractical:
	var we := _mundo()
	return we.camera_attributes as CameraAttributesPractical if we != null else null


func _ambiente() -> Environment:
	var we := _mundo()
	return we.environment if we != null else null


func _luz_principal(luzes: Array[Light3D]) -> Light3D:
	var melhor: Light3D = null
	for l: Light3D in luzes:
		if l.name == "FogoNaCara":
			continue
		if melhor == null or l.light_energy > melhor.light_energy:
			melhor = l
	return melhor


func _alvo(cab: Node3D) -> Dictionary:
	var dono: Node = cab
	while dono != null and not dono is Corpo:
		dono = dono.get_parent()
	var rosto: Array[GeometryInstance3D] = []
	for n: Node in cab.find_children("*", "GeometryInstance3D", true, false):
		rosto.append(n as GeometryInstance3D)
	var corpo: Array[GeometryInstance3D] = []
	if dono != null:
		for n: Node in dono.find_children("*", "GeometryInstance3D", true, false):
			if not cab.is_ancestor_of(n):
				corpo.append(n as GeometryInstance3D)
	if OS.get_cmdline_user_args().has("--sonda-fogo-nomes"):
		var nomes: Array = []
		for g: GeometryInstance3D in rosto:
			nomes.append(str(cab.get_path_to(g)))
		print("[sonda_fogo] rosto de %s: %s" % [dono.name if dono != null else cab.name, nomes])
	var pele := cab.get_node_or_null("Pele") as MeshInstance3D
	var centro := cab.global_position
	if pele != null and pele.mesh != null:
		centro = pele.global_transform * pele.mesh.get_aabb().get_center()
	return {"nome": dono.name if dono != null else cab.name, "centro": centro,
		"frente": -cab.global_basis.z.normalized(), "rosto": rosto, "corpo": corpo}


func _lente(nome: String, de: Vector3, para: Vector3, fov: float, alvo: String) -> Dictionary:
	var vp := SubViewport.new()
	vp.name = "Sonda_" + nome
	vp.size = TAMANHO
	vp.world_3d = get_viewport().world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.02
	# Ambiente proprio, sem SDFGI: cada lente com o ambiente da cena montava
	# as cascatas dela, e sete lentes e a janela 4K esgotaram a VRAM
	# (VkResult -2, e o motor caiu). A lente de sonda mede a luz direta; o
	# rebote fica na lente da cena.
	if _env_lente == null:
		var env := _ambiente()
		if env != null:
			_env_lente = env.duplicate() as Environment
			_env_lente.sdfgi_enabled = false
			_env_lente.ssil_enabled = false
			_env_lente.glow_enabled = false
		_atr_lente = CameraAttributesPractical.new()
		_atr_lente.auto_exposure_enabled = false
		_atr_lente.exposure_sensitivity = ISO
	cam.environment = _env_lente
	cam.attributes = _atr_lente
	vp.add_child(cam)
	var cima := Vector3.UP if absf((para - de).normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	cam.look_at_from_position(de, para, cima)
	cam.current = true
	return {"nome": nome, "vp": vp, "de": alvo}


## Seis luzes curtas em volta do alvo, so na camada da mascara, sem sombra:
## todo pixel visivel dele acende por algum lado.
func _luzes_de_mascara(centro: Vector3, camada: int) -> Array[Light3D]:
	var r: Array[Light3D] = []
	for d: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT,
			Vector3.FORWARD, Vector3.BACK]:
		var l := OmniLight3D.new()
		l.light_cull_mask = camada
		l.omni_range = 2.5
		l.light_energy = 1.5
		l.light_specular = 0.0
		l.shadow_enabled = false
		l.light_volumetric_fog_energy = 0.0
		add_child(l)
		l.global_position = centro + d * 0.9
		r.append(l)
	return r


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fotografar(lentes: Array[Dictionary]) -> Array:
	for i in ASSENTA:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var imgs: Array = []
	for l: Dictionary in lentes:
		var vp: Viewport = l["vp"]
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if img.get_width() > 1280:
			img.resize(img.get_width() / 3, img.get_height() / 3, Image.INTERPOLATE_BILINEAR)
		imgs.append(img)
	return imgs


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _y(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


## [pixels da mascara, luminancia media apagado, aceso]. Mascara: o pixel que a
## luz de sonda clareou mais que LIMIAR (luminancia linear).
func _medir(off: Image, on: Image, m: Image) -> Array:
	const LIMIAR := 0.02
	var n := 0
	var so := 0.0
	var sa := 0.0
	var w := mini(off.get_width(), m.get_width())
	var h := mini(off.get_height(), m.get_height())
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var o := _y(off.get_pixel(x, y))
			if _y(m.get_pixel(x, y)) - o < LIMIAR:
				continue
			n += 1
			so += o
			sa += _y(on.get_pixel(x, y))
	if n == 0:
		return [0, 0.0, 0.0]
	return [n, so / n, sa / n]


func _mascara_png(m: Image, off: Image) -> Image:
	var r := off.duplicate() as Image
	for y in range(0, r.get_height()):
		for x in range(0, r.get_width()):
			if _y(m.get_pixel(x, y)) - _y(off.get_pixel(x, y)) >= 0.02:
				r.set_pixel(x, y, Color(1.0, 0.0, 1.0))
	return r
