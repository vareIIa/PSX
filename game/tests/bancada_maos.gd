## As maos modeladas no aro, fotografadas de perto e de varios lados, sem carro.
##
##     godot --path game --resolution 1280x720 res://tests/bancada_maos.tscn -- --estilo=moderno --saida=<DIR ABSOLUTO> [--graus=180] [--giro=55] [--manga] [--esterco=1]
##
## Opcoes de depuracao: `--laminas` lista triangulo comprido e fino (a cara de
## anel torcido), `--so-polegar` desenha so o polegar.
##
## Por que uma bancada
## -------------------
## Na cidade a camera de dentro so ve a mao de um jeito: de cima, a meio metro,
## com o carro andando e o borrao de movimento por cima. Dedo atravessando o
## aro por baixo, polegar enterrado na palma, ordem de vertice invertida numa
## peca so — nada disso aparece daquele angulo, e tudo aparece no primeiro
## jogador que olhar para baixo numa curva. Aqui o aro e a copia do da
## `CarroCabine` (dez caixas retas, 30 graus de inclinacao) e a camera roda em
## volta da mao: do olho, do olho com lente longa, ao longo do tubo (perfil,
## sem o aro, que tamparia a lente), do dorso, do punho e das pontas.
## `--esterco` gira o volante depois de montar, como o jogo faz, e mostra o
## antebraco reapontando para o cotovelo.
##
## O que ela imprime
## -----------------
## Triangulos por mao (manga curta e comprida), e um [X ] se passar do teto.
## Triangulos cuja face (pela regra do projeto, o oposto do produto vetorial)
## contraria a normal suave dos proprios vertices: dobra de malha. Uns poucos na
## prega dos nos e na boca da manga sao esperados; uma peca com a ordem
## invertida acusaria todos os dela. E as dobras de cada no, contra a faixa da
## pegada de forca de mao de gente.
extends Node

## Era 1500, da mao para 480x270. Em 4K a ponta do dedo pediu doze lados e a
## unha virou malha (cerca de 110 triangulos por dedo): a mao fica em ~2800,
## menos que o aro do volante sozinho.
const TETO_TRIANGULOS := 3200
## Olho do motorista contado do pivo do volante, no espaco do carro. O suporte
## da `CarroCabine` fica 22 cm atras do aro (`OLHO_Z` -0,08 contra -0,30 do
## volante); a altura depende do assoalho de cada carro, e 40 cm e aproximado —
## a vista `olho` e para julgar a mao, nao o enquadramento, que se confere na
## cidade.
const OLHO_DO_PIVO := Vector3(0.0, 0.40, 0.22)

var _saida := ""
var _graus := MotoristaCena.MAO_NA_CIDADE_GRAUS
## Sem `--giro`, o giro e a obliquidade saem do cotovelo, como no jogo
## (`MotoristaCena.pegada_para_o_cotovelo`).
var _giro := NAN
## `--estrada`: a mao e o cotovelo da cena da estrada, e o olho da cutscene.
var _estrada := false
var _manga := false
## Volante girado, de -1 a 1, como `CarroCabine.estercar`: a mao vai com o pivo
## e o antebraco tem de continuar apontando para o cotovelo.
var _esterco := 0.0
var _camera: Camera3D
var _pivo: Node3D
var _bracos: Array[Dictionary] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--graus="):
			_graus = arg.trim_prefix("--graus=").to_float()
		elif arg.begins_with("--giro="):
			_giro = arg.trim_prefix("--giro=").to_float()
		elif arg == "--estrada":
			_estrada = true
			_graus = MotoristaCena.MAO_NO_ARO_GRAUS
		elif arg == "--manga":
			_manga = true
		elif arg.begins_with("--esterco="):
			_esterco = arg.trim_prefix("--esterco=").to_float()
	_medir.call_deferred()


func _medir() -> void:
	_contar()
	_dobras()
	_montar_cena()
	# Depois de montar: no jogo a mao e montada com o volante reto e o
	# `estercar` gira o pivo por baixo dela.
	_pivo.rotation.z = deg_to_rad(-CarroCabine.VOLANTE_CURSO * clampf(_esterco, -1.0, 1.0))
	for b: Dictionary in _bracos:
		MotoristaCena._apontar_antebraco(b)
	if _saida.is_empty():
		print("[bancada_maos] sem --saida, nada fotografado")
		get_tree().quit(0)
		return
	DirAccess.make_dir_recursive_absolute(_saida)
	# O estilo e aplicado pelos autoloads no primeiro quadro, e a primeira
	# compilacao de shader come mais alguns.
	for _q in 30:
		await get_tree().process_frame
	var olho := _olho()
	# As vistas de perto sao contadas na base da propria pegada: ao longo do
	# tubo (o perfil, que e onde se ve se os dedos fecham), do dorso, do lado do
	# punho (o polegar) e do lado das pontas.
	var giro_esq: float = _bracos[0].get("giro", 0.0) if not _bracos.is_empty() else 0.0
	var q := MaoModelada._eixos(MotoristaCena._no_aro(_graus), deg_to_rad(giro_esq))
	var b := _pivo.global_transform.basis
	var centro := _pivo.global_transform * (q["o"] as Vector3)
	var tubo: Vector3 = b * (q["tubo"] as Vector3)
	var dorso: Vector3 = b * (q["dorso"] as Vector3)
	var dedos: Vector3 = b * (q["d"] as Vector3)
	var vistas := {
		"olho": [olho, _pivo.position + Vector3(0.0, 0.0, -0.05), 74.0],
		"olho_baixo": [olho, _pivo.position + Vector3(0.0, -0.12, 0.0), 74.0],
		# Do olho, com lente longa: o que a camera da cidade ve da mao esquerda,
		# ampliado.
		"olho_zoom": [olho, centro, 22.0],
		"olho_zoom2": [olho, centro + dorso * 0.02 - dedos * 0.02 - tubo * 0.035, 9.0],
		"perfil": [centro + tubo * 0.22, centro, 40.0],
		"perfil_avesso": [centro - tubo * 0.22, centro, 40.0],
		"dorso": [centro + dorso * 0.22 + tubo * 0.03, centro, 40.0],
		"punho": [centro - dedos * 0.24 + dorso * 0.06, centro, 40.0],
		"pontas": [centro + dedos * 0.2 - dorso * 0.12, centro, 40.0],
	}
	for nome: String in vistas:
		var par: Array = vistas[nome]
		_camera.position = par[0]
		_camera.fov = par[2]
		var cima := Vector3.UP
		if absf((par[1] - par[0]).normalized().dot(cima)) > 0.95:
			cima = Vector3.FORWARD
		_camera.look_at(par[1], cima)
		# De perfil o aro vem direto na lente e tampa a mao inteira.
		for peca: String in ["Aro", "Raios", "Buzina"]:
			(_pivo.get_node(peca) as Node3D).visible = not nome.begins_with("perfil")
		for _q in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var caminho := _saida.path_join("maos_%s.png" % nome)
		img.save_png(caminho)
		print("[bancada_maos] ", caminho)
	get_tree().quit(0)


## Triangulos e normais, das duas maos, com as duas mangas.
func _contar() -> void:
	for longa: bool in [false, true]:
		for direita: bool in [false, true]:
			var d := PSXMesh.dados_vazios()
			var graus := _graus if not direita else 180.0 - _graus
			var no_aro := func(s: float) -> Transform3D:
				return MotoristaCena._no_aro(graus + rad_to_deg(s / CarroCabine.VOLANTE_RAIO))
			MaoModelada.segurando(d, no_aro, MotoristaCena.RAIO_DA_PEGADA, direita,
				Vector3(0.1 if direita else -0.1, -0.3, 0.45),
				Color(0.88, 0.72, 0.58), Color(0.35, 0.38, 0.45), longa, _giro_fixo())
			var tri := PSXMesh.dados_triangulos(d)
			print("%s mao %s, manga %s: %d triangulos (teto %d)" % [
				"[ok]" if tri <= TETO_TRIANGULOS else "[X ]",
				"direita" if direita else "esquerda",
				"comprida" if longa else "curta", tri, TETO_TRIANGULOS])
			_conferir_normais(d)


## As dobras de cada no, em graus, e a distancia da ponta ao eixo do tubo. Uma
## pegada de forca de mao de gente dobra 45 a 70 graus no no da base, 90 a 110
## no do meio e 20 a 50 no da ponta.
func _dobras() -> void:
	var raio := MotoristaCena.RAIO_DA_PEGADA
	var nomes := ["indicador", "medio", "anelar", "minimo"]
	for i in MaoModelada.DEDOS.size():
		var dedo: Dictionary = MaoModelada.DEDOS[i]
		var r: float = dedo["r"]
		var j := MaoModelada._fechar(Vector2(float(dedo["x"]) + MaoModelada.AVANCO, raio + MaoModelada.NO_DA_BASE),
			dedo["f"], raio + r * MaoModelada.APERTO, true,
			deg_to_rad(MaoModelada.DOBRA_DA_PONTA), raio + r * 0.82 * 0.8)
		var txt := ""
		var antes := Vector2(1.0, 0.0)
		for k in 3:
			var d := (j[k + 1] - j[k]).normalized()
			txt += "%.0f  " % rad_to_deg(absf(antes.angle_to(d)))
			antes = d
		print("     %-9s dobras %s| ponta a %.1f mm do eixo, %.0f graus em volta" % [
			nomes[i], txt, j[3].length() * 1000.0, rad_to_deg(j[3].angle())])
	# O polegar: o metacarpo sai da palma, fora do plano da secao.
	var giro_esq: float = _bracos[0].get("giro", 0.0) if not _bracos.is_empty() else 0.0
	var q := MaoModelada._eixos(MotoristaCena._no_aro(_graus), deg_to_rad(giro_esq))
	var qp := MaoModelada._eixos(MotoristaCena._no_aro(_graus
		- rad_to_deg(MaoModelada.POLEGAR_S / CarroCabine.VOLANTE_RAIO)), deg_to_rad(_giro_fixo()))
	var lado_s: Vector3 = -(q["tubo"] as Vector3)
	var rp := MaoModelada.POLEGAR_R
	var ang := deg_to_rad(MaoModelada.POLEGAR_NO_GRAUS)
	var jp := MaoModelada._fechar(Vector2(cos(ang), sin(ang))
		* (raio + rp * MaoModelada.APERTO + 0.004), MaoModelada.POLEGAR_F,
		raio + rp * MaoModelada.APERTO, false, deg_to_rad(MaoModelada.DOBRA_DA_PONTA),
		raio + rp * 0.88 * 0.8)
	var base := MaoModelada._na_palma(q, lado_s, MaoModelada.POLEGAR_BASE.x,
		MaoModelada.POLEGAR_BASE.y, raio - 0.002 + MaoModelada.POLEGAR_BASE.z)
	var p0 := MaoModelada._no_plano(qp, jp[0])
	var p1 := MaoModelada._no_plano(qp, jp[1])
	var p2 := MaoModelada._no_plano(qp, jp[2])
	print("     polegar   metacarpo %.1f cm, dobras %.0f  %.0f" % [
		base.distance_to(p0) * 100.0,
		rad_to_deg((p0 - base).angle_to(p1 - p0)),
		rad_to_deg((p1 - p0).angle_to(p2 - p1))])


## A normal de cada triangulo (o oposto do produto vetorial, pela regra do
## projeto) contra a normal suave dos tres vertices: sinal trocado e dobra
## da malha — anel atravessando o anel vizinho num no dobrado demais.
func _conferir_normais(d: Dictionary) -> void:
	var v: PackedVector3Array = d["v"]
	var n: PackedVector3Array = d["n"]
	var idx: PackedInt32Array = d["i"]
	var ruins := 0
	for t in range(0, idx.size(), 3):
		var a := v[idx[t]]
		var fn := -(v[idx[t + 1]] - a).cross(v[idx[t + 2]] - a)
		if fn.length_squared() < 1e-14:
			continue
		var media := n[idx[t]] + n[idx[t + 1]] + n[idx[t + 2]]
		if fn.dot(media) < 0.0:
			ruins += 1
		# Lamina: triangulo comprido e fino, que e a cara de anel torcido.
		var l0 := v[idx[t]].distance_to(v[idx[t + 1]])
		var l1 := v[idx[t + 1]].distance_to(v[idx[t + 2]])
		var l2 := v[idx[t + 2]].distance_to(v[idx[t]])
		var maior := maxf(l0, maxf(l1, l2))
		var area := fn.length() * 0.5
		if maior > 0.008 and area / (maior * maior) < 0.06 and OS.get_cmdline_user_args().has("--laminas"):
			print("     lamina t=%d  %.1f cm  %s %s %s" % [t / 3, maior * 100.0,
				v[idx[t]], v[idx[t + 1]], v[idx[t + 2]]])
	print("     triangulos com a face contra a normal suave: %d de %d" % [ruins,
		idx.size() / 3])


func _montar_cena() -> void:
	var raiz := Node3D.new()
	raiz.name = "Bancada"
	add_child(raiz)

	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.22, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = env
	raiz.add_child(amb)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, 25.0, 0.0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	raiz.add_child(sol)

	_camera = Camera3D.new()
	_camera.fov = 74.0
	_camera.near = 0.02
	raiz.add_child(_camera)
	_camera.make_current()

	_pivo = Node3D.new()
	_pivo.name = "Volante"
	_pivo.position = Vector3(0.0, 0.0, -0.30)
	_pivo.rotation = Vector3(deg_to_rad(-CarroCabine.VOLANTE_INCLINACAO), 0.0, 0.0)
	raiz.add_child(_pivo)

	# O volante: o mesmo da `CarroCabine._montar_volante`.
	VolanteEsportivo.montar(_pivo, CarroCabine.VOLANTE_RAIO)

	# As duas maos, com o cotovelo da cidade (ou o da estrada).
	for direita: bool in [false, true]:
		var graus := _graus if not direita else 180.0 - _graus
		var cot := MotoristaCena.COTOVELO_ESQ if _estrada else MotoristaCena.COTOVELO_NA_CIDADE
		if direita:
			cot.x = -cot.x
		var cot_carro := _pivo.transform * MotoristaCena._no_aro(graus).origin + cot
		var cotovelo := _pivo.transform.affine_inverse() * cot_carro
		var pegada := MotoristaCena.pegada_para_o_cotovelo(MotoristaCena._no_aro(graus),
			cotovelo, direita)
		if not is_nan(_giro):
			pegada = Vector3(_giro, 0.0, 0.0)
		print("[bancada_maos] %s: giro %.1f, obliqua %.1f, pulso dobra %.1f de lado" % [
			"direita" if direita else "esquerda", pegada.x, pegada.y, pegada.z])
		var no_aro := func(s: float) -> Transform3D:
			return MotoristaCena._no_aro(graus + rad_to_deg(s / CarroCabine.VOLANTE_RAIO))
		var nome := "MaoDireita" if direita else "MaoEsquerda"
		if not OS.get_cmdline_user_args().has("--so-polegar"):
			# O mesmo caminho da cabine: esqueleto de dois ossos no pivo.
			var dados := PSXMesh.dados_com_ossos()
			var braco := MaoModelada.segurando(dados, no_aro,
				MotoristaCena.RAIO_DA_PEGADA, direita, cotovelo,
				Color(0.88, 0.72, 0.58), Color(0.35, 0.38, 0.45), _manga, pegada.x,
				pegada.y)
			var b := MotoristaCena._pendurar_mao(_pivo, dados, braco, nome, cot_carro)
			b["giro"] = pegada.x
			_bracos.append(b)
			continue
		# Depuracao: so o polegar, para achar de quem e uma lamina.
		var d := PSXMesh.dados_vazios()
		var sinal := 1.0 if direita else -1.0
		var q := MaoModelada._eixos(no_aro.call(0.0), deg_to_rad(pegada.x))
		MaoModelada._polegar(d, q, (q["tubo"] as Vector3) * sinal, no_aro, sinal,
			MotoristaCena.RAIO_DA_PEGADA, MotoristaCena.RAIO_DA_PEGADA - 0.002,
			deg_to_rad(pegada.x), MaoModelada._tons(Color(0.88, 0.72, 0.58)),
			Vector2(0.5, 0.5))
		var mi := MeshInstance3D.new()
		mi.name = nome
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = load(Corpo.MATERIAL) as Material
		_pivo.add_child(mi)


## O olho do motorista: o do suporte, ou vinte centimetros atras dele na
## estrada (`AberturaEstrada.DENTRO_OLHO_RECUA`).
func _olho() -> Vector3:
	return _pivo.position + OLHO_DO_PIVO + (Vector3(0.0, 0.0, 0.20) if _estrada else Vector3.ZERO)


## O giro das contagens, que nao tem cotovelo: o de `--giro`, ou zero.
func _giro_fixo() -> float:
	return 0.0 if is_nan(_giro) else _giro
