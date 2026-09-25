## A blunt da casa da fumaca: folha de tabaco enrolada, piteira de papelao,
## brasa que respira, cinza que cresce e cai, fumaca na ponta e na boca.
##
## O que ela substitui
## -------------------
## O baseado do Convidado era um paralelepipedo de 13 x 1,3 x 1,3 cm com a
## celula de papel do casa_atlas, pendurado no antebraco por um BoneAttachment3D
## e com um segundo paralelepipedo laranja na ponta. De perto era um palito
## bege, e nao encostava na boca nunca — a mao nao chegava la (ver
## `Corpo._levar_a_boca`) e, quando chegasse, o bastao estava parafusado na mao
## num angulo fixo, apontando para a orelha.
##
## O que ela e
## -----------
##   papel    cilindro de doze lados e treze aneis, levemente torto e mais fino
##            na boca, onde a folha foi apertada; a folha da textura `blunt` tem
##            nervura em diagonal e a costura em espiral. Os ultimos 7 mm
##            escurecem por cor de vertice: e o papel tostado junto da brasa.
##   brasa    o anel de 3,5 mm que queima, com a propria face na ponta (aparece
##            quando a cinza acabou de cair). Material com emissao que respira:
##            fio baixo parado, forte na puxada, e demora a esfriar.
##   cinza    cresce a cada tragada e cai quando a pessoa bate (Tragada.CINZA),
##            com farelo caindo de verdade.
##   queima   a blunt encurta a cada tragada, ate o toco de pouco mais da metade.
##
## Onde ela fica
## -------------
## NAO e filha de BoneAttachment3D. E `top_level` e se posiciona sozinha a cada
## quadro, lendo do Corpo a pega da mao e os labios depois que a pose foi
## escrita. Assim da para fazer o que um objeto parafusado no osso nao faz:
## longe da boca ela segue a mao no angulo de quem segura entre os dedos; perto
## dela, ela MIRA — a boca da blunt vai aos labios e o corpo dela passa pela
## pega. E essa mira que faz a tragada ler como tragada a um metro da lente.
##
## Os dois estilos
## ---------------
## A textura e uma so, com as duas fidelidades do resto do jogo: 128 px com
## filtro ponto no PS1 STYLE e o conjunto HD de 1024 px com normal e rugosidade
## no MODERNO (TexturasHD, pelo nome `blunt`). O material troca de shader junto
## com o preset, igual aos materiais de superficie do EstiloVisual — so que
## aqui e ela mesma quem confere, porque a blunt nao e um .tres da pasta de
## materiais.
class_name Blunt
extends Node3D

const TEXTURA := "res://assets/textures/blunt.png"
const NOME_HD := &"blunt"
## Os mesmos dois caminhos de EstiloVisual.SHADER_VERTEX e SHADER_PIXEL. Copiados
## e nao lidos de la: a bancada roda com --script, sem autoload, e uma referencia
## ao autoload nao compila fora do jogo.
const SHADER_VERTEX := "res://shaders/psx_surface.gdshader"
const SHADER_PIXEL := "res://shaders/psx_surface_pixel.gdshader"

## Regioes do atlas (ver tools/gerar_blunt.py).
const V_FOLHA := 0.625
const V_CINZA := Vector2(0.625, 0.8125)
const V_BAIXO := 0.8125
const U_PITEIRA := 0.1875
const U_BRASA := 0.25

# --- medidas, em metros -----------------------------------------------------
## Da boca a ponta, inteira. Blunt de verdade tem de 11 a 13 cm.
const COMPRIMENTO := 0.118
## Raio no meio. 1,36 cm de diametro: mais grossa que um baseado de seda, que e
## o que separa uma blunt de um cigarro a distancia.
const RAIO := 0.0068
const LADOS := 12
const ANEIS := 12
## Largura do anel que queima.
const BRASA := 0.0035
## Cinza no maximo, antes de cair.
const CINZA_MAX := 0.017
## Da boca da blunt ate onde os dedos seguram.
const PEGA := 0.034
## A blunt em repouso, no referencial do antebraco: a ponta acesa para fora da
## mao (+X e as costas da mao direita) e um tico para o lado dos dedos (-Y).
## Com o antebraco dobrado do repouso, isso aponta a brasa para a frente e para
## baixo, longe da roupa — e nao para cima como um lapis, que foi a primeira.
const DIR_REPOUSO := Vector3(0.85, -0.35, 0.15)

var corpo: Corpo
## A bancada fotografa os dois estilos sem as Settings: 1 MODERNO, 0 PS1 STYLE,
## -1 segue o jogo.
static var estilo_forcado: int = -1

## As medidas e a pele. O padrao e a blunt; o `Cigarro` troca todas no `_init`
## e herda o resto — malha, brasa, cinza, fumaca e a mira na boca.
var comprimento: float = COMPRIMENTO
var raio: float = RAIO
var lados: int = LADOS
var largura_brasa: float = BRASA
var cinza_max: float = CINZA_MAX
var pega: float = PEGA
var dir_repouso: Vector3 = DIR_REPOUSO
var textura: String = TEXTURA
var nome_hd: StringName = NOME_HD
## A forma enrolada a mao: quanto a boca aperta, quanto a barriga estufa, o
## desvio de cada anel (fracao do raio, e metros no eixo) e a curva ao
## comprido (m). Cigarro de maquina e reto: tudo perto de zero.
var aperto: float = 0.28
var barriga: float = 0.045
var torto_raio: float = 0.05
var torto_eixo: float = 0.00035
var curva: float = 0.001
## O papel tostado junto da brasa (m) e quanto ele escurece la, e o escuro da
## umidade na boca (fracao).
var tostado: float = 0.007
var queimado: float = 0.62
var umida: float = 0.18
## Quanto a brasa acende o que esta em volta (1 = o da blunt), e o brilho dela
## parada, entre uma tragada e outra (1 = o da blunt).
var luz_da_brasa: float = 1.0
var brasa_parada: float = 1.0

## Sem corpo (`montar(null, ...)`): quem segura e o pai, e quem manda na brasa
## e quem chama — a mao de primeira pessoa, a bituca caida no chao. `puxada` de
## 0 a 1 acende; `consumo` e a fracao ja queimada (-1 segue o relogio do
## corpo); `cinza` de 0 a 1; `vida` de 1 a 0 apaga a brasa.
var livre: bool = false
var puxada: float = 0.0
var consumo: float = -1.0
var cinza: float = 0.3
var vida: float = 1.0:
	set(v):
		vida = clampf(v, 0.0, 1.0)
## Quanto do fio de fumaca sai agora (0 a 1). A bituca voando zera: a brasa
## rasgando o ar desenharia uma fita de meio metro atras dela.
var fumaca: float = 1.0
## Na rua: a baforada sem luz propria (ver `FumacaParticulas.rua`).
var na_rua: bool = false

var _peca: Node3D
var _papel: MeshInstance3D
var _anel: MeshInstance3D
var _cinza: MeshInstance3D
var _mat_papel: ShaderMaterial
var _mat_brasa: ShaderMaterial
var _pixel: int = -1
var _luz: OmniLight3D
var _fio: FumacaParticulas
var _baforada: FumacaParticulas
var _farelo: GPUParticles3D
var _rng := RandomNumberGenerator.new()
## Desvio de cada anel (raio, y, z): a blunt e enrolada a mao.
var _torto: PackedVector3Array = []
var _calor: float = 0.0
var _feito_consumo: float = -1.0
var _feita_cinza: float = -1.0
var _caiu: bool = false
var _t: float = 0.0


## Monta a blunt para este corpo. O corpo precisa ter `fumo` (ver Tragada).
## Sem corpo (null), ela fica LIVRE: segue o pai e obedece `puxada`/`consumo`.
func montar(quem: Corpo, semente: int) -> void:
	corpo = quem
	livre = quem == null
	top_level = not livre
	_rng.seed = semente * 2246822519 + 3266489917
	for i in ANEIS + 1:
		_torto.append(Vector3(_rng.randf_range(-torto_raio, torto_raio),
			_rng.randf_range(-torto_eixo, torto_eixo), _rng.randf_range(-torto_eixo, torto_eixo)))
	_peca = Node3D.new()
	_peca.name = "Peca"
	add_child(_peca)
	_papel = _nova_malha("Papel")
	_anel = _nova_malha("Brasa")
	_cinza = _nova_malha("Cinza")
	_conferir_estilo()

	_luz = OmniLight3D.new()
	_luz.name = "LuzBrasa"
	_luz.omni_range = 0.35
	_luz.light_color = Color(1.0, 0.45, 0.15)
	_luz.light_energy = 0.15
	_luz.shadow_enabled = false
	_peca.add_child(_luz)

	# Fumaca da ponta: coordenada de mundo, sobe na vertical por definicao. E o
	# FIO (fitas), e nao tufos: tufo em cima da brasa le como algodao.
	_fio = FumacaParticulas.new()
	_fio.name = "FumacaDaPonta"
	_fio.tipo = FumacaParticulas.Tipo.FIO
	_fio.top_level = true
	add_child(_fio)
	_baforada = FumacaParticulas.new()
	_baforada.name = "Baforada"
	_baforada.tipo = FumacaParticulas.Tipo.BAFORADA
	_baforada.rua = na_rua
	_baforada.top_level = true
	add_child(_baforada)
	_montar_farelo()
	_reconstruir()


func _nova_malha(nome: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_peca.add_child(mi)
	return mi


## O farelo da cinza que cai quando a pessoa bate.
func _montar_farelo() -> void:
	_farelo = GPUParticles3D.new()
	_farelo.name = "Farelo"
	_farelo.top_level = true
	_farelo.local_coords = false
	_farelo.one_shot = true
	_farelo.emitting = false
	_farelo.amount = 9
	_farelo.lifetime = 1.1
	_farelo.explosiveness = 0.85
	_farelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3.DOWN
	p.spread = 35.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.gravity = Vector3(0.0, -5.5, 0.0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_min = 0.5
	p.scale_max = 1.4
	_farelo.process_material = p
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.004, 0.0015, 0.004)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.61, 0.59)
	m.roughness = 1.0
	caixa.material = m
	_farelo.draw_pass_1 = caixa
	add_child(_farelo)


# --- quadro -----------------------------------------------------------------

func _process(delta: float) -> void:
	atualizar(delta)


## Posiciona a blunt e acende brasa e fumaca. Publica para a bancada chamar
## depois de animar o corpo na mao.
func atualizar(delta: float) -> void:
	if livre:
		_t += delta
		_conferir_estilo()
		_reconstruir()
		_acender(null, false, delta)
		_baforada.amount_ratio = 0.0
		return
	if corpo == null or not is_instance_valid(corpo) or corpo.esqueleto() == null:
		return
	_t += delta
	_conferir_estilo()
	var fumo := corpo.fumo
	var fuma := corpo.fumando_agora()
	if fumo != null:
		_reconstruir()
	_posicionar(fumo, fuma)
	_acender(fumo, fuma, delta)
	_soltar(fumo)


func _posicionar(fumo: Tragada, fuma: bool) -> void:
	var mao := corpo.pega_no_mundo()
	var eixo := (mao.basis * dir_repouso).normalized()
	var boca_da_blunt := mao.origin - eixo * pega
	var k := fumo.alcance() if fumo != null and fuma else 0.0
	var w := smoothstep(0.55, 0.95, k)
	if w > 0.0:
		var boca := corpo.boca_no_mundo()
		# Quatro milimetros para dentro dos labios: a blunt entra na boca.
		var labio := boca.origin + boca.basis * Vector3(0.0, 0.0, 0.004)
		var ate_pega := mao.origin - labio
		var mira := ate_pega.normalized() if ate_pega.length() > 0.012 \
			else -boca.basis.z.normalized()
		eixo = eixo.slerp(mira, w).normalized()
		boca_da_blunt = boca_da_blunt.lerp(labio, w)
	global_transform = Transform3D(_base(eixo), boca_da_blunt)


## Base com X no eixo da blunt. O rolo em volta do eixo sai do "para cima" do
## mundo; a blunt e redonda, e o rolo so decide onde cai a costura.
static func _base(eixo: Vector3) -> Basis:
	var cima := Vector3.UP if absf(eixo.dot(Vector3.UP)) < 0.95 else Vector3.BACK
	var y := (cima - eixo * cima.dot(eixo)).normalized()
	return Basis(eixo, y, eixo.cross(y))


func _acender(fumo: Tragada, fuma: bool, delta: float) -> void:
	var puxa := fumo.puxada() if fumo != null and fuma else (puxada if livre else 0.0)
	# A brasa acende rapido e esfria devagar.
	if puxa > _calor:
		_calor = lerpf(_calor, puxa, minf(1.0, delta * 9.0))
	else:
		_calor = maxf(puxa, _calor - delta / 1.6)
	var tremor := 0.06 * sin(_t * 13.1) + 0.04 * sin(_t * 29.7 + 1.3)
	if _mat_brasa != null:
		_mat_brasa.set_shader_parameter(&"emission_energy",
			maxf(0.2, brasa_parada + _calor * 5.5 + tremor) * vida)
	# Brasa e fonte de centimetro: acende o queixo e os dedos, nao o rosto
	# inteiro. Com 1,4 na puxada o rosto estourava em amarelo na foto de perto, e
	# com 0,47 ainda estourava o rosto de pele clara: a luz esta a 6 cm dele.
	# No jogo, com 0,2, a cabeca inteira ainda saia laranja na casa escura — e
	# com 0,11 tambem (captura de 24/09, tragada funda: o rosto todo cor de
	# tijolo). A luz a um palmo cai com 1/d: a 8 cm, 0,11 vira quase 1,4 na pele.
	# Com 0,04 o rosto ainda saia laranja na casa (captura do jogo depois da
	# primeira baixa). Com 0,018 no auge fica o que a brasa faz de verdade: um
	# calor no queixo e nos dedos.
	_luz.light_energy = maxf(0.0, 0.004 + _calor * 0.014 + tremor * 0.003) \
		* luz_da_brasa * vida
	var ponta := _ponta_no_mundo()
	_luz.global_position = ponta
	_fio.global_position = ponta + Vector3(0.0, 0.004, 0.0)
	_fio.amount_ratio = clampf(0.55 + 0.45 * _calor, 0.0, 1.0) * clampf(vida * 1.4, 0.0, 1.0) \
		* fumaca


func _soltar(fumo: Tragada) -> void:
	if fumo == null:
		_baforada.amount_ratio = 0.0
		return
	var forca := fumo.baforada()
	_baforada.amount_ratio = clampf(forca, 0.0, 1.0)
	if forca > 0.0:
		var de := corpo.nariz_no_mundo() if fumo.pelo_nariz() else corpo.boca_no_mundo()
		var dir := (de.basis * fumo.direcao_baforada()).normalized()
		var cima := Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK
		_baforada.global_transform = Transform3D(Basis.looking_at(dir, cima),
			de.origin + dir * 0.012)
	# Bater a cinza: no toque, o farelo cai e a cinza some da ponta.
	var caindo := fumo.cinza_caindo()
	if caindo and not _caiu:
		_farelo.global_position = _ponta_no_mundo()
		_farelo.restart()
		_farelo.emitting = true
	_caiu = caindo


# --- forma ------------------------------------------------------------------

## Comprimento do papel agora (sem brasa e sem cinza).
func _papel_agora() -> float:
	var queimou := consumo
	if queimou < 0.0:
		queimou = corpo.fumo.consumido if corpo != null and corpo.fumo != null else 0.0
	return comprimento * (1.0 - queimou) - largura_brasa


func _cinza_agora() -> float:
	if livre:
		return cinza
	var fumo := corpo.fumo if corpo != null else null
	if fumo == null:
		return 0.3
	# A cinza some no toque, e nao no fim da tragada de bater.
	if fumo.estilo == Tragada.Estilo.CINZA and (fumo.cinza_caindo()
			or fumo.fase() > Tragada.Fase.PUXA):
		return 0.0
	return fumo.cinza


## Onde fica a ponta acesa, no mundo (a cara da brasa, debaixo da cinza).
func _ponta_no_mundo() -> Vector3:
	return global_transform * Vector3(_papel_agora() + largura_brasa + 0.002, 0.0, 0.0)


## Refaz as malhas quando a blunt queimou ou a cinza mudou. Acontece uma vez por
## tragada, e sao algumas centenas de vertices.
func _reconstruir() -> void:
	var lp := _papel_agora()
	var cz := _cinza_agora()
	if absf(lp - _feito_consumo) > 0.0004:
		_feito_consumo = lp
		_papel.mesh = _malha_papel(lp)
		_anel.mesh = _malha_brasa(lp)
		_feita_cinza = -1.0
	if absf(cz - _feita_cinza) > 0.01:
		_feita_cinza = cz
		_cinza.mesh = _malha_cinza(lp, cz)
		_cinza.visible = cz > 0.02


func _raio(i: int, x: float) -> float:
	# A boca apertada, a barriga no meio e o desvio da mao que enrolou.
	var boca := 1.0 - aperto + aperto * smoothstep(0.0, 0.012, x)
	var estufa := 1.0 + barriga * sin(PI * clampf(x / comprimento, 0.0, 1.0))
	return raio * boca * estufa * (1.0 + _torto[mini(i, _torto.size() - 1)].x)


func _centro(i: int, x: float) -> Vector3:
	var t := _torto[mini(i, _torto.size() - 1)]
	# Uma curvinha de um milimetro ao comprido: nada enrolado a mao e reto.
	return Vector3(x, curva * sin(PI * x / comprimento) + t.y, t.z)


## Em que x do comprimento cada anel do papel fica, de 0 a 1. Mais juntos nas
## duas pontas, onde a forma muda. O `Cigarro` poe um anel na emenda do filtro.
func _aneis_do_papel(lp: float) -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	for i in ANEIS + 1:
		var s := float(i) / ANEIS
		xs.append(lp * (s * s * (3.0 - 2.0 * s) * 0.6 + s * 0.4))
	return xs


## O cilindro de folha, da boca (x = 0) ate a brasa (x = lp).
func _malha_papel(lp: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var xs := _aneis_do_papel(lp)
	for i in xs.size():
		var x := xs[i]
		var r := _raio(i, x)
		var meio := _centro(i, x)
		# Tostado junto da brasa, e a umidade da boca nos tres primeiros mm.
		var tom := 1.0 - queimado * smoothstep(lp - tostado, lp, x)
		tom *= 1.0 - umida * smoothstep(0.004, 0.0, x)
		for j in lados + 1:
			var a := TAU * float(j) / lados
			var dir := Vector3(0.0, cos(a), sin(a))
			v.append(meio + dir * r)
			n.append(dir)
			uv.append(Vector2(x / comprimento, V_FOLHA * float(j) / lados))
			c.append(Color(tom, tom * 0.97, tom * 0.95))
	var passo := lados + 1
	for i in xs.size() - 1:
		for j in lados:
			var a := i * passo + j
			idx.append_array([a, a + passo, a + 1, a + 1, a + passo, a + passo + 1])
	# A boca: o disco da piteira, virado para -X.
	var centro := v.size()
	var r0 := _raio(0, 0.0)
	v.append(_centro(0, 0.0) + Vector3(-0.0004, 0.0, 0.0))
	n.append(Vector3.LEFT)
	uv.append(Vector2(U_PITEIRA * 0.5, V_BAIXO + (1.0 - V_BAIXO) * 0.5))
	c.append(Color.WHITE)
	for j in lados + 1:
		var a := TAU * float(j) / lados
		v.append(_centro(0, 0.0) + Vector3(0.0, cos(a), sin(a)) * r0)
		n.append(Vector3.LEFT)
		uv.append(Vector2(U_PITEIRA * (0.5 + 0.49 * sin(a)),
			V_BAIXO + (1.0 - V_BAIXO) * (0.5 - 0.49 * cos(a))))
		c.append(Color.WHITE)
	for j in lados:
		idx.append_array([centro, centro + 1 + j, centro + 2 + j])
	return _malha(v, n, uv, c, idx)


## O anel que queima e a cara dele na ponta.
func _malha_brasa(lp: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var r0 := _raio(ANEIS, lp)
	var meio := _centro(ANEIS, lp)
	for i in 2:
		var x := lp + largura_brasa * i
		var r := r0 * (1.0 - 0.05 * i)
		for j in lados + 1:
			var a := TAU * float(j) / lados
			var dir := Vector3(0.0, cos(a), sin(a))
			v.append(Vector3(x, meio.y, meio.z) + dir * r)
			n.append(dir)
			uv.append(Vector2(U_BRASA + (1.0 - U_BRASA) * float(j) / lados,
				V_BAIXO + (1.0 - V_BAIXO) * (0.1 + 0.8 * i)))
			c.append(Color.WHITE)
	var passo := lados + 1
	for j in lados:
		idx.append_array([j, j + passo, j + 1, j + 1, j + passo, j + passo + 1])
	# A cara da brasa, virada para +X: aparece quando a cinza cai.
	var centro := v.size()
	var x1 := lp + largura_brasa
	v.append(Vector3(x1 + 0.0006, meio.y, meio.z))
	n.append(Vector3.RIGHT)
	uv.append(Vector2(U_BRASA + (1.0 - U_BRASA) * 0.5, V_BAIXO + (1.0 - V_BAIXO) * 0.45))
	c.append(Color.WHITE)
	for j in lados + 1:
		var a := TAU * float(j) / lados
		v.append(Vector3(x1, meio.y, meio.z) + Vector3(0.0, cos(a), sin(a)) * r0 * 0.95)
		n.append(Vector3.RIGHT)
		uv.append(Vector2(U_BRASA + (1.0 - U_BRASA) * float(j) / lados,
			V_BAIXO + (1.0 - V_BAIXO) * 0.75))
		c.append(Color.WHITE)
	for j in lados:
		idx.append_array([centro, centro + 2 + j, centro + 1 + j])
	return _malha(v, n, uv, c, idx)


## A cinza: um tronco de cone arredondado na ponta.
func _malha_cinza(lp: float, quanto: float) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var tam := maxf(0.0015, cinza_max * quanto)
	var r0 := _raio(ANEIS, lp) * 0.97
	var meio := _centro(ANEIS, lp)
	var x0 := lp + largura_brasa
	# Quatro aneis: o corpo, o ombro da ponta e o fecho.
	var perfil := [[0.0, 1.0], [0.7, 0.93], [0.92, 0.72], [1.0, 0.3]]
	for i in perfil.size():
		var f: float = perfil[i][0]
		var r: float = r0 * float(perfil[i][1])
		var x := x0 + tam * f
		for j in lados + 1:
			var a := TAU * float(j) / lados
			var dir := Vector3(0.0, cos(a), sin(a))
			v.append(Vector3(x, meio.y, meio.z) + dir * r)
			# A normal inclina para a frente no fecho: a ponta e redonda.
			n.append((dir + Vector3.RIGHT * f * f * 1.4).normalized())
			uv.append(Vector2(tam * f / 0.03, V_CINZA.x + (V_CINZA.y - V_CINZA.x)
				* float(j) / lados))
			c.append(Color.WHITE)
	var passo := lados + 1
	for i in perfil.size() - 1:
		for j in lados:
			var a := i * passo + j
			idx.append_array([a, a + passo, a + 1, a + 1, a + passo, a + passo + 1])
	var centro := v.size()
	v.append(Vector3(x0 + tam + 0.0005, meio.y, meio.z))
	n.append(Vector3.RIGHT)
	uv.append(Vector2(tam / 0.03, (V_CINZA.x + V_CINZA.y) * 0.5))
	c.append(Color.WHITE)
	var ultimo := (perfil.size() - 1) * passo
	for j in lados:
		idx.append_array([centro, ultimo + j + 1, ultimo + j])
	return _malha(v, n, uv, c, idx)


static func _malha(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array,
		c: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# --- material ---------------------------------------------------------------

## Luz por pixel (MODERNO) ou por vertice (PS1 STYLE), lida das Settings do
## jogo. Sem o autoload (bancada), fica no MODERNO.
static func _luz_por_pixel() -> bool:
	if estilo_forcado >= 0:
		return estilo_forcado == 1
	var arvore := Engine.get_main_loop() as SceneTree
	var s := arvore.root.get_node_or_null(^"Settings") if arvore != null else null
	if s == null:
		return true
	return bool(s.get(&"luz_por_pixel"))


func _conferir_estilo() -> void:
	var pixel := 1 if _luz_por_pixel() else 0
	if pixel == _pixel:
		return
	_pixel = pixel
	_mat_papel = _material(pixel == 1, false, textura, nome_hd)
	_mat_brasa = _material(pixel == 1, true, textura, nome_hd)
	_papel.material_override = _mat_papel
	_cinza.material_override = _mat_papel
	_anel.material_override = _mat_brasa


static func _material(pixel: bool, brasa: bool, tex: String = TEXTURA,
		hd: StringName = NOME_HD) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_PIXEL if pixel else SHADER_VERTEX) as Shader
	m.set_shader_parameter(&"albedo_tex", load(tex) as Texture2D)
	m.set_shader_parameter(&"tint", Color.WHITE)
	m.set_shader_parameter(&"uv_tile", Vector2.ONE)
	# Um objeto de centimetro nao ganha nada com a grade de vertice nem com a UV
	# afim: a 1,4 cm de diametro as duas so tremem a costura da folha.
	m.set_shader_parameter(&"use_snap", false)
	m.set_shader_parameter(&"use_affine", false)
	m.set_shader_parameter(&"alpha_cutoff", 0.0)
	# Dentro de casa, e fora da tabela de molhabilidade: sem isto o padrao do
	# shader faz a blunt virar espelho na chuva.
	m.set_shader_parameter(&"molha", 0.0)
	m.set_shader_parameter(&"rugosidade", 0.72)
	m.set_shader_parameter(&"brilho", 0.18)
	if brasa:
		m.set_shader_parameter(&"emission_color", Color(1.0, 0.62, 0.34))
		m.set_shader_parameter(&"emission_energy", 1.0)
	TexturasHD.aplicar(m, hd, pixel)
	return m
