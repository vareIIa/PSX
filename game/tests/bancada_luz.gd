## Oclusao, cor que sangra e penumbra: os criterios A11, A12 e A13 do
## PLANO_AAA_4K.
##
##     godot --path game --script res://tests/bancada_luz.gd
##     (SEM --headless: shader e pos-processamento so existem com janela)
##     --saida=DIR grava as fotos
##
## Por que bancada, e nao a cidade
## -------------------------------
## Na rua as tres coisas acontecem ao mesmo tempo, em cima de textura, nevoa,
## chuva e trinta luzes. A pergunta "o canto escureceu 15%?" nao tem resposta
## ali: nao ha canto isolado, nao ha "antes" com a mesma luz, e o transito muda o
## quadro entre uma captura e outra. Aqui ha tres paredes cinzas, uma luz e um
## cubo — e a unica coisa que muda entre as duas fotos e o recurso medido.
##
## O que cada medida faz
## ---------------------
## A11  Oclusao de ambiente. Le a luminancia numa faixa colada na QUINA (onde
##      parede encontra chao) e noutra a um metro dela, com e sem SSAO. O
##      criterio e a quina ficar ao menos 15% mais escura que a faixa longe, a
##      mais do que ja ficava.
## A12  Cor que sangra. Um painel VERMELHO de pe sobre o chao cinza. Mede o
##      vermelho do chao ao lado dele, com e sem luz indireta. Sem GI o chao e
##      cinza; com GI, o vermelho aparece no chao — que e o que "a cor de um
##      letreiro pinta a rua" quer dizer.
## A13  Penumbra. Um cubo lanca sombra no chao. Mede em quantos PIXELS a borda
##      da sombra atravessa de 20% para 80% de luminancia. Zero (ou um) e borda
##      dura; mais que isso e penumbra.
extends SceneTree

const QUADROS := 14
## Largura da faixa de leitura, em fracao da tela.
const FAIXA := 0.06

var _raiz: Node3D
var _saida := ""
var _camera: Camera3D
var _qualidade: Node
## `--blur=N` so para sondar a bancada; o jogo usa o valor da escada.
var _forca_blur := 1.2


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=")
		elif arg.begins_with("--blur="):
			_forca_blur = arg.trim_prefix("--blur=").to_float()
	root.add_child.call_deferred(_montar())
	_medir()


func _montar() -> Node3D:
	_raiz = Node3D.new()

	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Ambiente FORTE e sol fraco, de proposito.
	#
	# Oclusao de ambiente age sobre a luz que chega de todo lado — e essa que a
	# quina bloqueia. Com o sol dominando (energia 2,2 contra 0,3 de ambiente), a
	# oclusao mexia em 0,5% do que se via e o criterio A11 media quase zero. Numa
	# rua isso corresponde a sombra de predio, ceu nublado ou interior: os casos
	# em que canto escuro se nota.
	env.ambient_light_color = Color(0.62, 0.64, 0.70)
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambiente.environment = env
	ambiente.add_to_group(&"fog_controller")
	_raiz.add_child(ambiente)

	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 1.6, 4.2)
	_camera.rotation = Vector3(deg_to_rad(-16.0), 0.0, 0.0)
	_camera.fov = 60.0
	_raiz.add_child(_camera)

	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	# Sol baixo: penumbra cresce com a distancia entre quem tapa e quem recebe, e
	# sombra curta nao tem onde crescer. A 20 graus a sombra do cubo corre metros
	# pelo chao, e e la que a borda macia aparece.
	sol.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(28.0), 0.0)
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 40.0
	sol.add_to_group(&"luz_sombra")
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	_raiz.add_child(sol)

	_raiz.add_child(_placa(Vector3(0, 0, 0), Vector3(-90, 0, 0), Vector2(8, 8),
		Color(0.55, 0.55, 0.55)))            # chao
	_raiz.add_child(_placa(Vector3(0, 2, -2), Vector3.ZERO, Vector2(8, 4),
		Color(0.55, 0.55, 0.55)))            # parede do fundo
	# Painel vermelho de pe, a 1,2 m do chao: a fonte da cor que deve sangrar.
	# EMISSIVO, e nao so vermelho: o criterio A12 fala de letreiro, e letreiro
	# emite. Uma placa apenas pintada depende do que o sol devolve dela, e com sol
	# fraco (que e o que a oclusao pede) ela quase nao tem luz para espalhar.
	var vermelho := _placa(Vector3(-1.6, 0.9, 0.4), Vector3(0, 90, 0),
		Vector2(1.8, 1.8), Color(0.75, 0.05, 0.05))
	var mat_v := vermelho.material_override as StandardMaterial3D
	mat_v.emission_enabled = true
	mat_v.emission = Color(1.0, 0.06, 0.03)
	mat_v.emission_energy_multiplier = 6.0
	_raiz.add_child(vermelho)

	var cubo := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.7, 1.4, 0.7)
	cubo.mesh = caixa
	cubo.position = Vector3(1.5, 0.7, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.52)
	cubo.material_override = mat
	_raiz.add_child(cubo)
	return _raiz


func _placa(pos: Vector3, giro_graus: Vector3, tam: Vector2, cor: Color) -> MeshInstance3D:
	var plano := PlaneMesh.new()
	plano.size = tam
	plano.orientation = PlaneMesh.FACE_Z
	var mi := MeshInstance3D.new()
	mi.mesh = plano
	mi.position = pos
	mi.rotation = Vector3(deg_to_rad(giro_graus.x), deg_to_rad(giro_graus.y),
		deg_to_rad(giro_graus.z))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.95
	mi.material_override = mat
	return mi


func _medir() -> void:
	await process_frame
	await process_frame
	_qualidade = root.get_node_or_null(^"Qualidade")
	if _qualidade == null:
		print("[luz] autoload Qualidade ausente; nada a medir")
		quit(1)
		return

	# Um par de fotos POR CRITERIO, mudando so o recurso medido.
	#
	# A primeira versao comparava "tudo ligado" contra "tudo desligado" e mediu a
	# quina 8% mais CLARA com oclusao: a luz indireta, ligada no mesmo par,
	# devolve ao canto mais luz do que a oclusao tira. Dois recursos num par so
	# nao respondem por nenhum dos dois.
	var com_ao := await _foto("ao_com", true, false, 0.0)
	var sem_ao := await _foto("ao_sem", false, false, 0.0)
	var com_gi := await _foto("gi_com", false, true, 0.0)
	var sem_gi := await _foto("gi_sem", false, false, 0.0)
	var com_blur := await _foto("blur_com", false, false, _forca_blur)
	var sem_blur := await _foto("blur_sem", false, false, 0.0)
	var com := com_ao
	var sem := sem_ao
	if com == null or sem == null:
		quit(1)
		return

	var passou := 0
	# A11: quina contra longe.
	# A quina (encontro de parede e chao) corre em 0,47 da altura; a faixa colada
	# nela vai de 0,45 a 0,50, e a de comparacao fica bem longe, no chao da
	# frente. As duas evitam o painel vermelho e o cubo, que ficam nas laterais.
	# A quina e ACHADA, e nao assumida: e a linha de maior degrau vertical de
	# luminancia na coluna do meio. Chutar a altura dela poe a faixa na parede e
	# mede chao limpo — foi o que devolveu 0,2%.
	var linha := _linha_da_quina(sem_ao)
	var h := float(sem_ao.get_height())
	var y0 := (linha + 1.0) / h
	var y1 := (linha + 9.0) / h
	print("[luz] quina achada na linha %d (%.3f da altura)" % [linha, linha / h])
	var quina_com := _faixa(com_ao, y0, y1)
	var longe_com := _faixa(com_ao, 0.78, 0.88)
	var quina_sem := _faixa(sem_ao, y0, y1)
	var longe_sem := _faixa(sem_ao, 0.78, 0.88)
	var razao_com := quina_com / maxf(longe_com, 0.001)
	var razao_sem := quina_sem / maxf(longe_sem, 0.001)
	var escureceu := (1.0 - razao_com / maxf(razao_sem, 0.001)) * 100.0
	print("[luz] A11 quina/longe com AO %.3f, sem AO %.3f -> quina %.1f%% mais escura"
		% [razao_com, razao_sem, escureceu])
	if escureceu >= 15.0:
		passou += 1

	# A12: vermelho no chao ao lado do painel.
	var chao_com := _cor(com_gi, 0.18, 0.30, 0.62, 0.72)
	var chao_sem := _cor(sem_gi, 0.18, 0.30, 0.62, 0.72)
	var vies_com := chao_com.r - (chao_com.g + chao_com.b) * 0.5
	var vies_sem := chao_sem.r - (chao_sem.g + chao_sem.b) * 0.5
	print("[luz] A12 vies vermelho do chao: com luz indireta %.3f, sem %.3f (+%.3f)"
		% [vies_com, vies_sem, vies_com - vies_sem])
	if vies_com - vies_sem >= 0.01:
		passou += 1

	# A13: largura da borda da sombra.
	# Penumbra medida como AREA DE MEIA-SOMBRA, e nao como largura de uma borda.
	#
	# Largura de borda depende de ONDE se mede: no pe do objeto a penumbra e zero
	# por definicao, e foi la que o localizador caiu (3 px com e sem). A meia-
	# sombra nao depende de escolher ponto: e a fracao do chao que nao esta nem
	# na luz nem na sombra. Sombra dura quase nao tem esses pixels; sombra macia
	# vive deles.
	var largura_com := _meia_sombra(com_blur, linha)
	var largura_sem := _meia_sombra(sem_blur, linha)
	print("[luz] A13 dureza da borda (menor e mais macio): com penumbra %.1f, sem %.1f (x%.2f)"
		% [largura_com, largura_sem, largura_sem / maxf(largura_com, 0.001)])
	if largura_com <= largura_sem * 0.80:
		passou += 1

	print("[luz] %d de 3 criterios" % passou)
	quit(0 if passou == 3 else 1)


## Uma foto da bancada com exatamente os recursos pedidos.
##
## Escreve no ambiente direto, e nao pelo nivel da escada: o nivel muda quatro
## coisas de uma vez, e a bancada precisa mudar uma.
func _foto(nome: String, ao: bool, indireta: bool, blur: float) -> Image:
	var fog := root.get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
	if fog == null or fog.environment == null:
		return null
	var e := fog.environment
	e.ssao_enabled = ao
	e.ssao_radius = 0.7
	e.ssao_intensity = 5.0
	e.ssao_power = 2.0
	e.ssao_light_affect = 0.35
	e.ssil_enabled = indireta
	e.ssil_radius = 3.0
	e.ssil_intensity = 1.1
	e.sdfgi_enabled = indireta
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.2
	e.sdfgi_bounce_feedback = 0.5
	for no: Node in root.get_tree().get_nodes_in_group(&"luz_sombra"):
		var l := no as Light3D
		if l == null:
			continue
		if l is DirectionalLight3D:
			# No sol, penumbra e tamanho angular; `shadow_blur` nao faz nada.
			# O fator vem da escada, para bancada e jogo nao divergirem.
			(l as DirectionalLight3D).light_angular_distance = 				blur * QualidadeGrafica.ANGULO_POR_BLUR
		else:
			l.shadow_blur = blur
	# A luz global acumula por quadro; um punhado de quadros nao basta para ela
	# assentar. Sem isso, a foto "com GI" mede um GI pela metade.
	for i in (QUADROS * 6 if indireta else QUADROS):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img != null and _saida != "":
		img.save_png("%s/luz_%s.png" % [_saida, nome])
	return img


## Luminancia media de uma faixa horizontal da tela, dada em fracao da altura.
func _faixa(img: Image, y0: float, y1: float) -> float:
	return _cor(img, 0.30, 0.70, y0, y1).get_luminance()


func _cor(img: Image, x0: float, x1: float, y0: float, y1: float) -> Color:
	var soma := Color(0, 0, 0)
	var n := 0
	for y in range(int(img.get_height() * y0), int(img.get_height() * y1), 2):
		for x in range(int(img.get_width() * x0), int(img.get_width() * x1), 2):
			soma += img.get_pixel(x, y)
			n += 1
	return soma / maxf(float(n), 1.0)


## A linha de tela em que parede encontra chao: o maior degrau vertical.
func _linha_da_quina(img: Image) -> int:
	var x0 := int(img.get_width() * 0.35)
	var x1 := int(img.get_width() * 0.50)
	var melhor := 0
	var maior := 0.0
	for y in range(int(img.get_height() * 0.30), int(img.get_height() * 0.70)):
		var acima := 0.0
		var abaixo := 0.0
		for x in range(x0, x1, 3):
			acima += img.get_pixel(x, y - 3).get_luminance()
			abaixo += img.get_pixel(x, y + 3).get_luminance()
		var d := absf(abaixo - acima)
		if d > maior:
			maior = d
			melhor = y
	return melhor


## Em quantos pixels a borda da sombra do cubo atravessa de 20% a 80%.
##
## Varre uma linha horizontal no chao, a direita do cubo, e acha a transicao mais
## larga entre o escuro da sombra e o claro do chao.
## A INCLINACAO da transicao mais dura do chao, em niveis por pixel.
##
## E o que separa sombra dura de macia sem depender de escolher ponto: a borda
## dura muda tudo num pixel e da inclinacao alta; a macia espalha a mesma
## diferenca por varios e da inclinacao baixa. O percentil 99,5 pega a borda e
## ignora o grao.
##
## Duas metricas foram descartadas antes desta: largura de borda num ponto (no pe
## do objeto a penumbra e zero por definicao, e era la que o localizador caia) e
## fracao de meia-sombra no chao inteiro (o degrade natural do chao ja responde
## por 32%, e a penumbra se perdia dentro dele).
func _meia_sombra(img: Image, linha_quina: int) -> float:
	var grads: PackedFloat32Array = []
	for y in range(linha_quina + 14, int(img.get_height() * 0.92), 2):
		for x in range(int(img.get_width() * 0.10) + 2, int(img.get_width() * 0.90) - 2, 1):
			grads.append(absf(img.get_pixel(x + 2, y).get_luminance()
				- img.get_pixel(x - 2, y).get_luminance()))
	if grads.size() < 100:
		return 0.0
	grads.sort()
	return grads[int(grads.size() * 0.995)] * 255.0


## Onde esta a borda de sombra mais forte do chao: devolve (x, y) em pixels.
func _achar_borda(img: Image, linha_quina: int) -> Vector2i:
	var x0 := int(img.get_width() * 0.12)
	var x1 := int(img.get_width() * 0.88)
	var melhor := Vector2i(x0 + 40, linha_quina + 40)
	var maior := 0.0
	for y in range(linha_quina + 14, int(img.get_height() * 0.88), 2):
		for x in range(x0 + 6, x1 - 6, 2):
			var d := absf(img.get_pixel(x + 6, y).get_luminance()
				- img.get_pixel(x - 6, y).get_luminance())
			if d > maior:
				maior = d
				melhor = Vector2i(x, y)
	return melhor


## Em quantos pixels a borda da sombra atravessa de 20% para 80% de luminancia,
## medida numa LINHA e num CENTRO dados — os mesmos nas duas fotos.
func _borda(img: Image, y: int, x_centro: int) -> float:
	var x0 := maxi(x_centro - 40, 0)
	var x1 := mini(x_centro + 40, img.get_width() - 1)
	var vals: PackedFloat32Array = []
	for x in range(x0, x1):
		vals.append(img.get_pixel(x, y).get_luminance())
	if vals.size() < 8:
		return 0.0
	# A varredura nao comeca no escuro: ela entra pelo chao claro, atravessa a
	# sombra e sai no chao de novo. Procurar "o primeiro pixel acima de 20%"
	# devolvia o primeiro pixel da linha e media zero. O que vale e achar a
	# TRANSICAO mais forte e medir a largura dela.
	var i_borda := 1
	var maior := 0.0
	for i in range(2, vals.size() - 2):
		var d := absf(vals[i + 2] - vals[i - 2])
		if d > maior:
			maior = d
			i_borda = i
	if maior < 0.02:
		return 0.0
	# A leitura fica PRESA a vizinhanca da borda: soltando os limites, a
	# varredura corria ate a ponta da linha e devolvia a largura inteira (286 px
	# medidos).
	var i0 := maxi(i_borda - 25, 0)
	var i1 := mini(i_borda + 25, vals.size() - 1)
	var lo := vals[i0]
	var hi := vals[i0]
	for i in range(i0, i1 + 1):
		lo = minf(lo, vals[i])
		hi = maxf(hi, vals[i])
	if hi - lo < 0.02:
		return 0.0
	var a := lo + (hi - lo) * 0.2
	var b := lo + (hi - lo) * 0.8
	# A borda tanto pode subir quanto descer; o lado escuro e o que estiver mais
	# perto do minimo.
	var sobe := vals[i1] > vals[i0]
	var i_escuro := i_borda
	var i_claro := i_borda
	while i_escuro > i0 and (vals[i_escuro] > a if sobe else vals[i_escuro] < b):
		i_escuro -= 1
	while i_claro < i1 and (vals[i_claro] < b if sobe else vals[i_claro] > a):
		i_claro += 1
	return float(absi(i_claro - i_escuro))
