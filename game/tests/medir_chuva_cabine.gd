## Chove dentro da cabine? Criterio C12, com a cabine em cor chapada.
##
##     godot --path game --script res://tests/medir_chuva_cabine.gd -- --saida=DIR
##
## SEM --headless: e uma medida de pixel.
##
## Como a pergunta vira numero
## ---------------------------
## Cabine em PRETO chapado, lataria e limpador em AZUL, fundo VERDE. De dentro
## do carro, um pixel preto e uma superficie da cabine vista direto, sem nada no
## meio — entao qualquer risco de chuva desenhado por cima de um pixel preto
## esta, por construcao, DENTRO da cabine. Por cima de azul ou verde, esta
## atras do vidro, do lado de fora.
##
## Dois campos de chuva, um de cada vez, com a mesma geometria de risco e o
## mesmo shader da chuva do jogo (`psx_chuva.gdshader`):
##
##   DENTRO  riscos com o centro dentro da cabine, com folga. Sem teto eles tem
##           de aparecer (senao o teste nao esta vendo nada); com teto, ZERO.
##   CUNHA   riscos na frente do para-brisa, dentro da caixa da cabine mas fora
##           do plano do vidro. E o ar em cima do capo, onde o motorista mais ve
##           a chuva, e a caixa sozinha o engoliria. Com teto, tem de sobreviver
##           inteiro.
##
## O carro fica girado e a 4 km de altura, como na Estrada Velha: a matriz
## mundo -> carro tem de estar certa, e nao apenas ser a identidade.
extends SceneTree

const TAMANHO := Vector2i(480, 270)
const FOV := 74.0
const PITCH := -4.0
const YAWS := [0.0, -35.0]
const MODELOS := {
	"MAREA": Carroceria.Modelo.MAREA,
	"FUSCA": Carroceria.Modelo.FUSCA,
	"PICAPE": Carroceria.Modelo.PICAPE,
}
const RISCOS := 2500
## A mesma geometria do risco da `Chuva`.
const RISCO := Vector2(0.028, 0.42)
## Folga do centro do risco ate a borda do volume, em metros: meio risco mais
## um pouco, para o risco inteiro ficar do lado certo.
const FOLGA := 0.26
const ONDE := Vector3(100.0, 4000.0, -50.0)
const GIRO := 30.0

const PRETO := Color(0.0, 0.0, 0.0)
const AZUL := Color(0.0, 0.0, 1.0)
const VERDE := Color(0.0, 1.0, 0.0)

var _saida := ""
var _falhas := 0


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
	_rodar.call_deferred()


func _rodar() -> void:
	var linhas: Array[String] = []
	for nome: String in MODELOS:
		for yaw: float in YAWS:
			linhas.append(await _medir(nome, MODELOS[nome], yaw))
	print("\n=== C12: riscos de chuva por cima da cabine ===")
	print("modelo  yaw   dentro sem teto  dentro COM teto   cunha sem teto  cunha COM teto")
	for l in linhas:
		print(l)
	if linhas.is_empty():
		_falhas += 1
	print("\n=== %s ===" % ("C12 OK" if _falhas == 0 else "FALHOU: %d caso(s)" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _medir(nome: String, modelo: int, yaw: float) -> String:
	var vp := SubViewport.new()
	vp.size = TAMANHO
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = VERDE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	amb.environment = env
	vp.add_child(amb)

	var medidas := Carroceria.montar(modelo, CarroCena.TINTA, CarroCena.SEMENTE,
		true, false)
	var carro := Node3D.new()
	carro.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(GIRO)), ONDE)
	vp.add_child(carro)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"] as ArrayMesh
	lataria.material_override = _chapado(AZUL)
	carro.add_child(lataria)
	var cab := CarroCabine.new()
	carro.add_child(cab)
	cab.montar(medidas)
	_pintar(cab)

	var teto := cab.teto_da_chuva()
	if teto.is_empty():
		_falhas += 1
		vp.queue_free()
		return "%-7s %+4.0f  SEM TETO (cabine sem casca)" % [nome, yaw]

	var olho := cab.olho()
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = 0.02
	vp.add_child(cam)
	cam.global_transform = carro.global_transform * Transform3D(
		Basis(Vector3.UP, deg_to_rad(yaw)) * Basis(Vector3.RIGHT, deg_to_rad(PITCH)),
		olho)
	cam.make_current()

	var mat := _material_chuva()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var p_dentro := _pontos(teto, rng, true)
	var p_cunha := _pontos(teto, rng, false)
	var dentro := _campo(carro, mat, p_dentro)
	var cunha := _campo(carro, mat, p_cunha)
	vp.add_child(dentro)
	vp.add_child(cunha)

	dentro.visible = false
	cunha.visible = false
	var ref := await _foto(vp)

	var r := {}
	for caso: Array in [["dentro", dentro], ["cunha", cunha]]:
		for com_teto: bool in [false, true]:
			if com_teto:
				TetoChuva.escrever(mat, cab.global_transform, teto)
			else:
				TetoChuva.apagar(mat)
			(caso[1] as Node3D).visible = true
			var img := await _foto(vp)
			(caso[1] as Node3D).visible = false
			r["%s_%s" % [caso[0], com_teto]] = _contar(ref, img)
			if _saida != "" and caso[0] == "dentro" and yaw == 0.0:
				img.save_png(_saida.path_join("chuva_%s_%s_%s.png" % [
					nome.to_lower(), caso[0], "teto" if com_teto else "sem_teto"]))

	var d0: int = r["dentro_false"]["cabine"]
	var d1: int = r["dentro_true"]["cabine"]
	var c0: int = r["cunha_false"]["fora"]
	var c1: int = r["cunha_true"]["fora"]
	# Sem cunha nao ha o que proteger: no carro de para-brisa em pe a caixa e o
	# vidro quase coincidem. Isso e dito, e nao escondido — e a metade de
	# dentro continua tendo de passar.
	var sem_cunha := p_cunha.size() < 20
	var ok := d0 > 50 and d1 == 0 \
		and (sem_cunha or (c0 > 50 and float(c1) >= float(c0) * 0.99))
	if not ok:
		_falhas += 1
	vp.queue_free()
	await process_frame
	var nota := "  (%d riscos dentro, %d na cunha%s)" % [p_dentro.size(),
		p_cunha.size(), ": cunha menor que a folga, nao se aplica" if sem_cunha else ""]
	return "%-7s %+4.0f  %15d  %15d  %15d  %14d   %s%s" % [nome, yaw, d0, d1, c0, c1,
		"OK" if ok else "FALHOU", nota]


## Pontos de risco: dentro do volume com folga, ou na cunha na frente do
## para-brisa. Mesma conta do shader, feita na CPU.
func _pontos(teto: Dictionary, rng: RandomNumberGenerator, dentro: bool) -> PackedVector3Array:
	var lo: Vector3 = teto["min"]
	var hi: Vector3 = teto["max"]
	var planos: PackedVector4Array = teto["planos"]
	var para_brisa: Vector4 = planos[0]
	var out := PackedVector3Array()
	var tentativas := 0
	while out.size() < RISCOS and tentativas < RISCOS * 200:
		tentativas += 1
		var p := Vector3(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y),
			rng.randf_range(lo.z, hi.z))
		if dentro:
			if not _na_caixa(p, lo + Vector3.ONE * FOLGA, hi - Vector3.ONE * FOLGA):
				continue
			var todos := true
			for pl: Vector4 in planos:
				if Vector3(pl.x, pl.y, pl.z).dot(p) - pl.w > -FOLGA:
					todos = false
					break
			if todos:
				out.append(p)
		else:
			# Na caixa, mas do lado de FORA do para-brisa, com folga.
			if not _na_caixa(p, lo, hi):
				continue
			var n := Vector3(para_brisa.x, para_brisa.y, para_brisa.z)
			var fora := n.dot(p) - para_brisa.w
			# O risco e vertical: meia altura so pesa pela componente vertical
			# da normal. Num para-brisa em pe, 26 cm de folga fixa nao cabem.
			var folga := RISCO.y * 0.5 * absf(n.y) + RISCO.x * 0.5 + 0.03
			if fora > folga and fora < 0.9:
				out.append(p)
	return out


func _na_caixa(p: Vector3, lo: Vector3, hi: Vector3) -> bool:
	return p.x >= lo.x and p.y >= lo.y and p.z >= lo.z \
		and p.x <= hi.x and p.y <= hi.y and p.z <= hi.z


## Um campo de riscos parados, no espaco do carro, como MultiMesh em mundo.
func _campo(carro: Node3D, mat: ShaderMaterial, pontos: PackedVector3Array) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = RISCO
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = pontos.size()
	for i in pontos.size():
		# Risco em pe, virado para o olho so pelo giro do carro: o shader nao
		# depende da orientacao, e em pe e como a chuva cai.
		mm.set_instance_transform(i, carro.global_transform
			* Transform3D(Basis.IDENTITY, pontos[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi


func _material_chuva() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(TetoChuva.SHADER_CHUVA) as Shader
	# Magenta cheio: soma por cima do preto e do azul e se separa dos dois.
	m.set_shader_parameter(&"cor", Color(1.0, 0.0, 1.0))
	m.set_shader_parameter(&"intensidade", 3.0)
	# Sem o desvanecer de perto: a pergunta e geometrica, e um risco a 30 cm do
	# olho que o jogo apaga continua sendo um risco dentro do carro.
	m.set_shader_parameter(&"perto", 0.02)
	return m


func _chapado(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Cabine preta, limpador azul (ele esta do lado de fora), agua escondida.
func _pintar(cab: CarroCabine) -> void:
	var preto := _chapado(PRETO)
	var azul := _chapado(AZUL)
	for no: Node in cab.find_children("*", "GeometryInstance3D", true, false):
		var gi := no as GeometryInstance3D
		if gi.name == "Vidros" or gi is MultiMeshInstance3D:
			gi.visible = false
			continue
		var fora := false
		var p: Node = gi
		while p != null and p != cab:
			if p is Limpador:
				fora = true
			p = p.get_parent()
		# A cabine usa o lado que desenha para o olho; chapado com `cull_back`
		# mantem essa regra.
		gi.material_override = azul if fora else preto


func _foto(vp: SubViewport) -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


## Quantos pixels ganharam risco por cima de cabine, e por cima do que esta fora.
func _contar(ref: Image, img: Image) -> Dictionary:
	var cabine := 0
	var fora := 0
	for y in TAMANHO.y:
		for x in TAMANHO.x:
			var a := ref.get_pixel(x, y)
			var b := img.get_pixel(x, y)
			# O risco soma magenta: vermelho sobe onde antes nao havia.
			if b.r - a.r < 0.2:
				continue
			if a.r < 0.05 and a.g < 0.05 and a.b < 0.05:
				cabine += 1
			else:
				fora += 1
	return {"cabine": cabine, "fora": fora}
