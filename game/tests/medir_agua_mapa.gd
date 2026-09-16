## O mapa de agua em movimento: os criterios C5 e C6, medidos no proprio mapa.
##
##     godot --path game --script res://tests/medir_agua_mapa.gd -- --saida=DIR
##
## SEM --headless: o mapa e um SubViewport, e viewport sem janela nao desenha.
##
## O que se pergunta
## -----------------
## C6  "Limpa onde passa": dos texels que PERDEM agua num quadro, quantos estao
##     dentro do setor que a palheta varreu nesse quadro (ou debaixo do rastro
##     de uma corredora)? O criterio pede 90%.
##
## C5  "Sem piscar": FORA do que foi varrido, quantos texels mudam mais de 12
##     niveis entre dois quadros? O criterio pede 1,5%.
##
## Por que no mapa e nao na tela
## -----------------------------
## Porque na tela as duas perguntas nao tem resposta. Um pixel da tela pode
## mudar de nivel por dez motivos que nao sao agua — a estrada andou atras do
## vidro, o carro balancou, o dither trocou de fase. Na Fase 3 o numero que eu
## medi (2,2 a 3,4% de pixels mudando) carregava tudo isso junto, e por isso ele
## servia para comparar com o "antes" e nao servia para dizer se o sistema esta
## certo. O mapa e o ESTADO da agua: ali, um texel que perde R perdeu agua, e
## ponto.
##
## A tela continua sendo medida, porque e ela que o jogador ve — mas como numero
## comparavel com a Fase 3, e nao como criterio.
extends SceneTree

const TAMANHO := Vector2i(480, 270)
const FOV := 74.0
const PITCH := -4.0
const DT := 1.0 / 60.0

## Segundos de chuva antes de comecar a medir, para o vidro encher.
const AQUECER := 6.0
## Quadros medidos.
const QUADROS := 12

## Um "degrau" de 12 niveis de 255, que e o limiar do criterio.
const LIMIAR := 12.0 / 255.0

const MIN_C6 := 0.90
const MAX_C5 := 0.015

## 60 km/h em m/s.
const V60 := 16.67

var _saida := ""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			_saida = a.trim_prefix("--saida=")
	_rodar.call_deferred()


func _rodar() -> void:
	var vp := SubViewport.new()
	vp.size = TAMANHO
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.40, 0.42, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 1.0
	amb.environment = env
	vp.add_child(amb)

	var medidas := Carroceria.montar(Carroceria.Modelo.MAREA, CarroCena.TINTA,
		CarroCena.SEMENTE, true, false)
	var carro := Node3D.new()
	vp.add_child(carro)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"] as ArrayMesh
	lataria.material_override = load(Carroceria.MATERIAL) as ShaderMaterial
	carro.add_child(lataria)
	var cab := CarroCabine.new()
	carro.add_child(cab)
	cab.montar(medidas)

	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = 0.02
	cam.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(PITCH)), cab.olho())
	vp.add_child(cam)
	cam.make_current()

	var agua := cab.mapa_agua()
	if agua == null:
		print("=== FALHOU: a cabine nao montou mapa de agua ===")
		quit(1)
		return
	var i_frente := _achar(cab.paineis(), &"parabrisa")
	if i_frente < 0:
		print("=== FALHOU: o Marea nao tem para-brisa ===")
		quit(1)
		return
	var painel: Dictionary = cab.paineis()[i_frente]
	var rect := agua.rect(i_frente)
	var tam: Vector2 = painel["tam"]

	# A primeira execucao nao vale captura: o streaming e o shader ainda estao
	# subindo. Ver a memoria do projeto.
	for i in 8:
		await process_frame
	# Chove, o carro anda, o vidro enche.
	for i in int(AQUECER / DT):
		cab.atualizar_clima(1.0, Vector3(0.0, 0.0, -V60), Vector3.ZERO, DT)
		await process_frame
	await RenderingServer.frame_post_draw

	var mapa_ant := agua.imagem()
	var tela_ant := vp.get_texture().get_image()
	var lado := mapa_ant.get_size()
	print("mapa %dx%d, para-brisa em %s, %.2f x %.2f m, %.0f texels/m"
		% [lado.x, lado.y, rect, tam.x, tam.y, agua.texels_por_metro()])
	print("modo do limpador: %d" % int(cab.limpadores().modo))

	var linhas: Array[String] = []
	var pior_c6 := 1.0
	var pior_c5 := 0.0
	var tela_pior := 0.0
	for q in QUADROS:
		cab.atualizar_clima(1.0, Vector3(0.0, 0.0, -V60), Vector3.ZERO, DT)
		var setor := cab.setor_do_quadro()
		var trilhas := cab.trilhas_do_quadro()
		await process_frame
		await RenderingServer.frame_post_draw
		var mapa := agua.imagem()
		var tela := vp.get_texture().get_image()

		var perderam := 0
		var explicados := 0
		var mudaram_fora := 0
		var total := 0
		for ty in lado.y:
			for tx in lado.x:
				var uv := Vector2((tx + 0.5) / lado.x, (ty + 0.5) / lado.y)
				if not rect.has_point(uv):
					continue
				total += 1
				var f := (uv - rect.position) / rect.size
				var m := f * tam
				var explicado := _no_setor(m, setor) or _no_rastro(uv, trilhas,
					agua.texels_por_metro(), lado)
				var antes := mapa_ant.get_pixel(tx, ty).r
				var agora := mapa.get_pixel(tx, ty).r
				if antes - agora > LIMIAR:
					perderam += 1
					if explicado:
						explicados += 1
				if not explicado and absf(agora - antes) > LIMIAR:
					mudaram_fora += 1
		var c6 := float(explicados) / maxf(float(perderam), 1.0)
		var c5 := float(mudaram_fora) / maxf(float(total), 1.0)
		if perderam > 0:
			pior_c6 = minf(pior_c6, c6)
		pior_c5 = maxf(pior_c5, c5)

		var tela_mudou := _mudanca(tela_ant, tela)
		tela_pior = maxf(tela_pior, tela_mudou)
		linhas.append(("  quadro %2d  perderam agua %5d texels, %5.1f%% dentro do"
			+ " varrido   mudam fora do varrido %5.2f%%   tela %5.2f%%")
			% [q + 1, perderam, c6 * 100.0, c5 * 100.0, tela_mudou * 100.0])
		mapa_ant = mapa
		tela_ant = tela
		if _saida != "" and q == QUADROS - 1:
			tela.save_png(_saida.path_join("dentro_chuva_mapa.png"))
			_pintar(mapa).save_png(_saida.path_join("mapa_agua.png"))

	print("")
	for l in linhas:
		print(l)
	var v6 := "OK" if pior_c6 >= MIN_C6 else "FALHOU"
	var v5 := "OK" if pior_c5 <= MAX_C5 else "FALHOU"
	print("\nC6  pior quadro: %.1f%% dos texels que perderam agua estavam no varrido (limite %.0f%%) -> %s"
		% [pior_c6 * 100.0, MIN_C6 * 100.0, v6])
	print("C5  pior quadro: %.2f%% dos texels do vidro mudaram >12 niveis fora do varrido (limite %.1f%%) -> %s"
		% [pior_c5 * 100.0, MAX_C5 * 100.0, v5])
	print("    (para comparar com a Fase 3: %.2f%% dos pixels da TELA mudaram >12 niveis)"
		% (tela_pior * 100.0))
	quit(0 if pior_c6 >= MIN_C6 and pior_c5 <= MAX_C5 else 1)


## Este ponto do vidro, em metros, caiu no setor varrido neste quadro?
func _no_setor(m: Vector2, setor: Dictionary) -> bool:
	if setor.is_empty() or not setor.get("ativo", false):
		return false
	var raios: Vector2 = setor["raios"]
	var meia: float = setor["palheta"]
	var lo: float = minf(setor["ang_de"], setor["ang_ate"]) - meia
	var hi: float = maxf(setor["ang_de"], setor["ang_ate"]) + meia
	for pivo: Vector2 in [setor["pivo_a"], setor["pivo_b"]]:
		var d := m - pivo
		var r := d.length()
		if r < raios.x or r > raios.y:
			continue
		var ang := atan2(d.x, -d.y)
		if ang >= lo and ang <= hi:
			return true
	return false


## E o rastro de alguma corredora deste quadro?
func _no_rastro(uv: Vector2, trilhas: PackedVector4Array, tpm: float,
		lado: Vector2i) -> bool:
	if trilhas.is_empty():
		return false
	var px := uv * Vector2(lado)
	# A mesma largura do shader, mais um texel de folga para o filtro.
	var larg := maxf(1.0, 0.006 * tpm) + 1.0
	for t: Vector4 in trilhas:
		var a := Vector2(t.x, t.y) * Vector2(lado)
		var b := Vector2(t.z, t.w) * Vector2(lado)
		if px.distance_to(Geometry2D.get_closest_point_to_segment(px, a, b)) <= larg:
			return true
	return false


## Fracao de pixels da tela que mudaram mais de 12 niveis.
func _mudanca(a: Image, b: Image) -> float:
	var n := 0
	var tam := a.get_size()
	for y in tam.y:
		for x in tam.x:
			var c1 := a.get_pixel(x, y)
			var c2 := b.get_pixel(x, y)
			if maxf(maxf(absf(c1.r - c2.r), absf(c1.g - c2.g)),
					absf(c1.b - c2.b)) > LIMIAR:
				n += 1
	return float(n) / float(tam.x * tam.y)


## O mapa em 8 bits, para virar PNG legivel.
func _pintar(m: Image) -> Image:
	var out := Image.create(m.get_size().x, m.get_size().y, false, Image.FORMAT_RGB8)
	for y in m.get_size().y:
		for x in m.get_size().x:
			var c := m.get_pixel(x, y)
			out.set_pixel(x, y, Color(clampf(c.r, 0.0, 1.0),
				clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0)))
	return out


func _achar(paineis: Array, tipo: StringName) -> int:
	for i in paineis.size():
		if paineis[i]["tipo"] == tipo:
			return i
	return -1
