## O motor pegando fogo depois da batida: vapor e fumaca saindo do capo, e
## depois a chama, com a luz dela tremendo dentro da cabine.
##
## Por onde o fogo sai
## -------------------
## Fogo de motor depois de batida de frente sai por onde a frente amassada
## deixa: a borda do capo sobre a grade, a fresta do capo com o para-lama do
## lado que bateu (o carona, que abracou a arvore), a quina esmagada e a grade.
## A chama nasce NESSAS frestas (`FRESTAS`, no espaco do carro, seguindo o
## amassado de verdade: `Amassado.deslocamento`) e sobe. Antes ela nascia numa
## caixa no meio do capo e subia atravessando a chapa lisa — e passava por
## dentro da batina de quem rasteja por ali. O no continua onde a cena mira
## (`INCENDIO_NO_CARRO`): so os emissores e a luz moram nas frestas.
##
## A chama
## -------
## Flipbook de uma chama simulada (Mantaflow) e fotografada no Blender
## (`tools/blender_fogo`): 48 quadros de lingua de fogo, em cinza. A cor e a
## rampa daqui (`_rampa_chama`), o brilho e HDR (o glow da tela estoura o
## miolo, como a camera faz com fogo a noite). Cada particula e uma lingua em pe
## (billboard so em Y: fogo nao deita quando a lente olha de cima), com o pe na
## fresta, e toca o flipbook em laco com fase propria. Particula suave: onde a
## lingua encosta na chapa, no vidro ou no pano, ela some pela profundidade, sem
## borda dura.
##
## A fumaca e o tufo da `FumacaParticulas`, escura e iluminada — o fogo a acende
## por baixo —, com um piso de emissao quente no pe (fumaca escura no escuro
## some ou fica marrom). Antes do fogo ela e vapor claro do radiador. As brasas
## sao faisca que sobe e apaga. As frestas brilham por dentro (`_frestas_acesas`).
##
## A luz
## -----
## Uma OmniLight COM sombra, no corpo da chama (acima da borda, fora da chapa).
## Sem sombra ela atravessava tudo: acendia a cara dentro do capuz de quem
## rastejava de costas para o fogo, o teto e a lataria deixavam passar, e a
## cabine inteira ficava laranja. Com sombra, o capuz faz sombra na cara, a
## capa no corpo, o painel e as colunas na cabine, e a lataria tapa o que esta
## atras dela. `light_size` da a penumbra de uma chama de meio metro.
##
## Quem dosa e a cena: `fumegar` e `pegar_fogo` recebem de 0 a 1 e animam ate
## la, e o resto (o tremor da luz, a quantidade de particula) sai disso.
##
## `--sonda-fogo=...` e `--fogo-gpu`: ver `SondaDoFogo`.
class_name IncendioDoCapo
extends Node3D

const ATLAS := "res://assets/textures/fx_fogo_chama.png"
const ATLAS_GRADE := Vector2(8.0, 6.0)
const ATLAS_QUADROS := 48.0
## O tamanho da lingua do flipbook (m, escala 1): a caixa do `montar_atlas`.
const LINGUA := Vector2(0.44, 0.61)
const TUFO := "res://assets/textures/fx_fumaca_puff.png"
const PERFIL_MAREA := "res://src/render/carroceria_marea.gd"

## As frestas por onde o fogo sai, no espaco do carro (+X o carona, -Z a
## frente). Cada uma: [de, ate, para fora, peso, afasta]. y < 0 pede a altura
## da chapa naquele z (a tabela do Marea); `afasta` (m) empurra o ponto para
## fora DEPOIS do amassado.
##   - a borda do capo sobre a grade, do meio para a quina do carona (comeca a
##     8 cm do meio: o do capo sobe pela quina do motorista, e a cara dele nao
##     pode sumir atras da chama);
##   - a fresta do capo com o para-lama do carona, da quina para tras;
##   - a grade, por onde o radiador rachado sopra. O para-choque amassado
##     empurra a grade uns 13 cm para dentro, para baixo do bico do capo: a
##     chama que nascia colada nela subia por dentro da chapa do bico (a sonda
##     `--sonda-fogo-folga` acusou 4 subidas furando chapa). Ela nasce um
##     palmo a frente da grade amassada.
const FRESTAS := [
	[Vector3(0.08, -1.0, -2.115), Vector3(0.44, -1.0, -2.115), Vector3(0.0, 0.5, -0.87), 1.0, 0.0],
	[Vector3(0.46, -1.0, -2.10), Vector3(0.56, -1.0, -1.50), Vector3(0.6, 0.8, 0.0), 0.8, 0.0],
	[Vector3(0.06, 0.70, -2.155), Vector3(0.38, 0.75, -2.155), Vector3(0.0, 0.25, -0.97), 0.5, 0.09],
]
## A quina esmagada pela arvore: o fogo mais forte sai dela.
const QUINA := Vector3(0.45, -1.0, -2.10)
## Quanto o ponto de nascimento fica para fora da chapa (m).
const FOLGA := 0.015

## A luz do fogo: cor, energia cheia, alcance e onde ela mora (espaco do carro:
## no corpo da chama, na frente da quina do carona, uns 35 cm acima da chapa:
## mais baixo, a chapa embaixo dela estourava em branco).
const LUZ_COR := Color(1.0, 0.52, 0.18)
const LUZ_ENERGIA := 9.0
const LUZ_ALCANCE := 7.0
const LUZ_NO_CARRO := Vector3(0.30, 1.22, -2.02)
## A luz anda dentro do volume da chama para longe de quem esta NELA. Uma luz
## pontual com sombra dentro do peito de alguem apaga o fogo para o resto da
## cena (o corpo vira um eclipse) e estoura esse peito em branco: e o que o da
## direita, debrucado sobre o nariz, e o do capo, subindo pela quina, faziam.
## A chama de verdade tem meio metro: a luz fica na parte dela que ninguem
## tapa. Grade de candidatos (espaco do carro) e o raio de cada osso (m, com a
## batina).
const LUZ_X := [0.08, 0.28, 0.48]
const LUZ_Z := [-2.30, -2.10, -1.90, -1.70]
const LUZ_Y := [1.10, 1.32]
const RAIO_DO_OSSO := {0: 0.24, 1: 0.30, 2: 0.17, 3: 0.11, 4: 0.11, 5: 0.11, 6: 0.11,
	7: 0.13, 8: 0.11, 9: 0.13, 10: 0.11}
## O tamanho da fonte (m) para a penumbra. A chama tem meio metro, mas o PCSS
## do Godot com fonte grande vaza: com 0,3 a cara dentro do capuz, que a luz
## nao ve, recebia 0,107 de luminancia (a sonda); com 0,08, 0,002, e a borda
## da sombra ainda abre uns centimetros. `--fogo-tamanho=` e `--fogo-borrao=`
## para o A/B.
const LUZ_TAMANHO := 0.08
## O vento empurrando a fumaca e a ponta da chama, no espaco do carro (m/s^2):
## para o lado do carona e um pouco para a frente, para longe do para-brisa.
const VENTO_NO_CARRO := Vector3(0.30, 0.0, -0.12)

var _fumaca: GPUParticles3D
var _chama: GPUParticles3D
## As linguas altas da quina esmagada: poucas, grandes, mais vivas.
var _labareda: GPUParticles3D
var _brasa: GPUParticles3D
var _luz: OmniLight3D
var _frestas_acesas: MeshInstance3D
var _mat_chama: ShaderMaterial
var _mat_fumaca: ShaderMaterial
var _mat_frestas: ShaderMaterial
var _t: float = 0.0
## A luz livre: os corpos perto do fogo (revistos de tempos em tempos), para
## onde a luz vai e onde ela esta (espaco do carro).
var _corpos: Array[Corpo] = []
var _corpos_t := 0.0
var _livre_t := 0.0
var _luz_alvo := LUZ_NO_CARRO
var _luz_no_carro := LUZ_NO_CARRO
var _luz_tamanho := LUZ_TAMANHO
var _luz_borrao := 1.0
## Com que posicao do no e quantas batidas as frestas foram montadas: a cena
## poe a posicao depois do `add_child` (o `_ready` ja passou), e o amassado
## chega na batida.
var _montado_com := Vector4(INF, INF, INF, -1.0)
var fumaca: float = 0.0:
	set(v):
		fumaca = clampf(v, 0.0, 1.0)
		if _fumaca != null:
			_fumaca.emitting = fumaca > 0.01
			_fumaca.amount_ratio = maxf(0.05, fumaca)
var fogo: float = 0.0:
	set(v):
		fogo = clampf(v, 0.0, 1.0)
		if _chama != null:
			_chama.emitting = fogo > 0.01
			_chama.amount_ratio = maxf(0.05, fogo)
			_labareda.emitting = fogo > 0.2
			_labareda.amount_ratio = maxf(0.05, fogo)
			_brasa.emitting = fogo > 0.3
			_luz.visible = fogo > 0.01
			_frestas_acesas.visible = fogo > 0.01
			_mat_chama.set_shader_parameter(&"fogo", fogo)
			_mat_fumaca.set_shader_parameter(&"fogo", fogo)
			_mat_frestas.set_shader_parameter(&"fogo", fogo)


func _ready() -> void:
	_mat_chama = _material_chama()
	_mat_fumaca = _material_fumaca()
	_mat_frestas = _material_frestas()
	_fumaca = _emissor(40, 4.0, _mat_fumaca, _processo_fumaca(), Vector2(1.0, 1.0), 0.0)
	_chama = _emissor(44, 0.9, _mat_chama, _processo_chama(0.8, 1.3), LINGUA, LINGUA.y * 0.5)
	_labareda = _emissor(16, 1.2, _mat_chama, _processo_chama(1.5, 2.2), LINGUA, LINGUA.y * 0.5)
	_brasa = _emissor(24, 1.6, _mat_brasa(), _processo_brasa(), Vector2(0.035, 0.035), 0.0)
	_frestas_acesas = MeshInstance3D.new()
	_frestas_acesas.name = "FrestasAcesas"
	_frestas_acesas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_frestas_acesas.material_override = _mat_frestas
	_frestas_acesas.visible = false
	add_child(_frestas_acesas)
	_luz = OmniLight3D.new()
	_luz.name = "LuzDoFogo"
	_luz.light_color = LUZ_COR
	_luz.omni_range = LUZ_ALCANCE
	_luz.omni_attenuation = 1.4
	_luz.shadow_enabled = true
	_luz.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	# A/B de desempenho (`--fogo-sombra=cubo|dp|nenhuma`): o cubo sao seis
	# passes de sombra, o paraboloide duplo dois.
	for a: String in OS.get_cmdline_user_args():
		if a == "--fogo-sombra=dp":
			_luz.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		elif a == "--fogo-sombra=nenhuma":
			_luz.shadow_enabled = false
		elif a.begins_with("--fogo-tamanho="):
			_luz_tamanho = float(a.trim_prefix("--fogo-tamanho="))
		elif a.begins_with("--fogo-borrao="):
			_luz_borrao = float(a.trim_prefix("--fogo-borrao="))
	_luz.light_size = _luz_tamanho
	_luz.shadow_blur = _luz_borrao
	# Pano fino e de dois lados (capuz, batina): com o vies padrao a sombra do
	# capuz na cara descolava; com vies de menos o pano se sombreia em listras.
	_luz.shadow_bias = 0.03
	_luz.shadow_normal_bias = 1.0
	# A nevoa volumetrica da cena acende em volta de uma luz pontual como uma
	# bola: com a energia cheia ela era um sol boiando na frente do do capo
	# (09f3). Um fio de ar alaranjado basta; quem acende a fumaca e o shader dela.
	_luz.light_volumetric_fog_energy = 0.12
	_luz.light_energy = 0.0
	_luz.visible = false
	add_child(_luz)
	fumaca = 0.0
	fogo = 0.0
	var sonda := SondaDoFogo.criar(self)
	if sonda != null:
		add_child(sonda)


## Anima a fumaca ate `alvo` em `duracao` segundos.
func fumegar(alvo: float, duracao: float) -> void:
	_atualizar_frestas()
	create_tween().tween_property(self, "fumaca", alvo, duracao) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## A chama pega: sobe de onde esta ate `alvo`. Pega depressa e cresce devagar.
func pegar_fogo(alvo: float, duracao: float) -> void:
	_atualizar_frestas()
	var t := create_tween()
	t.tween_property(self, "fogo", minf(alvo, 0.35), 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	t.tween_property(self, "fogo", alvo, maxf(0.01, duracao - 0.25)) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Acende tudo por alguns quadros debaixo do preto do comeco, e apaga sem deixar
## particula no ar: chama, brasa e fumaca compilam o pipeline no primeiro quadro
## em que aparecem (e a luz com sombra, o passe de sombra dela), e isso caia
## quando a cabeca vira para o capo pegando fogo.
func aquecer(ligar: bool) -> void:
	_atualizar_frestas()
	fumaca = 1.0 if ligar else 0.0
	fogo = 1.0 if ligar else 0.0
	if ligar:
		_luz.light_energy = LUZ_ENERGIA
	else:
		for p: GPUParticles3D in [_fumaca, _chama, _labareda, _brasa]:
			p.restart()
			p.emitting = false


func _process(delta: float) -> void:
	_t += delta
	if fogo <= 0.01:
		return
	# A chama tremendo: tres senos desencontrados e um sopro lento. Uma luz de
	# fogo que so pulsa num ritmo le como pisca-pisca.
	var f := 0.72 + 0.12 * sin(_t * 11.3) + 0.09 * sin(_t * 17.9 + 1.3) \
		+ 0.07 * sin(_t * 5.1 + 0.4) + 0.1 * sin(_t * 1.3)
	_luz.light_energy = LUZ_ENERGIA * fogo * f
	_mat_fumaca.set_shader_parameter(&"luz_pos", _luz.global_position)
	_mat_fumaca.set_shader_parameter(&"luz_forca", _luz.light_energy / LUZ_ENERGIA)
	_livre_t -= delta
	if _livre_t <= 0.0:
		_livre_t = 0.15
		_luz_alvo = _lugar_livre()
	_luz_no_carro = _luz_no_carro.move_toward(_luz_alvo, 1.5 * delta)
	# O centro da chama anda: a sombra respira com ela.
	_luz.position = _no_local(_luz_no_carro) + Vector3(0.05 * sin(_t * 7.0),
		0.06 * sin(_t * 9.0 + 2.0), 0.03 * sin(_t * 5.3 + 0.7))


## O candidato dentro da chama mais longe de qualquer corpo (e, empatado, mais
## perto do centro dela). Sem ninguem perto, e o centro.
func _lugar_livre() -> Vector3:
	var c := _carro()
	if c == null or not c.is_inside_tree():
		return LUZ_NO_CARRO
	# Quem pode estar no fogo: os corpos da cena, revistos a cada 10 s (o
	# elenco nasce no comeco do plano; varrer a arvore toda custa).
	_corpos_t -= 0.15
	if _corpos_t <= 0.0:
		_corpos_t = 10.0
		_corpos.clear()
		var us := Time.get_ticks_usec()
		var cena := c.get_parent()
		if cena != null:
			for n: Node in cena.find_children("*", "Corpo", true, false):
				_corpos.append(n as Corpo)
		if OS.get_cmdline_user_args().has("--fogo-pontos"):
			print("[incendio] %d corpos em %.2f ms" % [_corpos.size(),
				(Time.get_ticks_usec() - us) / 1000.0])
	var ossos: Array[Vector4] = []
	for corpo: Corpo in _corpos:
		if not is_instance_valid(corpo) or not corpo.is_visible_in_tree():
			continue
		if corpo.global_position.distance_to(global_position) > 3.0:
			continue
		var esq := corpo.esqueleto()
		if esq == null:
			continue
		for i: int in RAIO_DO_OSSO:
			if i >= esq.get_bone_count():
				continue
			var p := c.to_local(esq.global_transform * esq.get_bone_global_pose(i).origin)
			ossos.append(Vector4(p.x, p.y, p.z, float(RAIO_DO_OSSO[i])))
	if ossos.is_empty():
		return LUZ_NO_CARRO
	var melhor := LUZ_NO_CARRO
	var nota := -INF
	for x: float in LUZ_X:
		for z: float in LUZ_Z:
			for y: float in LUZ_Y:
				var p := Vector3(x, y, z)
				var folga := 0.45
				for o: Vector4 in ossos:
					folga = minf(folga, p.distance_to(Vector3(o.x, o.y, o.z)) - o.w)
				var n := folga - 0.35 * p.distance_to(LUZ_NO_CARRO)
				if n > nota:
					nota = n
					melhor = p
	return melhor


# --- onde o fogo sai --------------------------------------------------------

## O carro dono (a lataria amassada e o referencial das frestas). O no e filho
## direto dele, so com posicao: direcao no carro e direcao aqui.
func _carro() -> Node3D:
	return get_parent() as Node3D


## Um ponto do espaco do carro no espaco deste no.
func _no_local(p: Vector3) -> Vector3:
	return p - position


static var _perfil: Array = []


## A altura da chapa de cima do Marea num z do carro (a tabela `PERFIL`, que
## e autorada com a frente em +Z: o carro montado da meia volta).
static func _altura_da_chapa(z_carro: float) -> float:
	if _perfil.is_empty():
		var s := load(PERFIL_MAREA) as GDScript
		if s != null:
			_perfil = s.get_script_constant_map().get("PERFIL", [])
	if _perfil.is_empty():
		return 0.88
	return float(CarroceriaVarrida.estacao(_perfil, -z_carro)[2])


func _amassado() -> Amassado:
	var c := _carro()
	if c == null:
		return null
	return c.get(&"_amassado") as Amassado


## O ponto de nascimento no espaco do carro: na chapa (altura da tabela quando
## y < 0), um fio para fora, e deslocado pelo amassado da batida.
func _na_chapa(p: Vector3, fora: Vector3) -> Vector3:
	var q := p
	if q.y < 0.0:
		q.y = _altura_da_chapa(q.z)
	q += fora.normalized() * FOLGA
	var am := _amassado()
	if am != null:
		q += am.deslocamento(q)
	return q


func _fresta(f: Array, t: float) -> Vector3:
	var p: Vector3 = (f[0] as Vector3).lerp(f[1], t)
	if (f[0] as Vector3).y < 0.0:
		p.y = -1.0
	return _no_local(_na_chapa(p, f[2]) + (f[2] as Vector3).normalized() * float(f[4]))


## Os pontos de nascimento no espaco do carro, cada um com a direcao "para
## fora" da chapa ali: [[ponto, fora], ...]. E o que a `SondaDoFogo` mede
## contra a lataria (`--sonda-fogo-folga`).
func nascimentos() -> Array:
	var r: Array = []
	for f: Array in FRESTAS:
		for i in 12:
			var t := (float(i) + 0.5) / 12.0
			r.append([_fresta(f, t) + position, (f[2] as Vector3).normalized()])
	r.append([_na_chapa(QUINA, Vector3(0.3, 0.6, -0.7)), Vector3(0.3, 0.6, -0.7).normalized()])
	return r


## As frestas em pontos (espaco deste no), com o peso de cada uma em repeticao,
## e a quina esmagada mais cheia.
func _pontos_das_frestas() -> PackedVector3Array:
	var r := PackedVector3Array()
	for f: Array in FRESTAS:
		var n := int(round(14.0 * float(f[3])))
		for i in n:
			r.append(_fresta(f, (float(i) + 0.5) / float(n)))
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 7
	for i in 8:
		var p := QUINA + Vector3(sorte.randf_range(-0.05, 0.03), 0.0,
			sorte.randf_range(-0.01, 0.06))
		r.append(_no_local(_na_chapa(p, Vector3(0.3, 0.6, -0.7))))
	return r


static func _textura_de_pontos(pts: PackedVector3Array, sobe: float) -> ImageTexture:
	var img := Image.create(pts.size(), 1, false, Image.FORMAT_RGBF)
	for i in pts.size():
		var p := pts[i] + Vector3.UP * sobe
		img.set_pixel(i, 0, Color(p.x, p.y, p.z))
	return ImageTexture.create_from_image(img)


## Aponta os emissores para as frestas de agora: na batida o amassado muda a
## chapa, e as frestas vao junto (uma vez, na primeira deixa depois dela).
func _montar_frestas() -> void:
	var pts := _pontos_das_frestas()
	if OS.get_cmdline_user_args().has("--fogo-pontos"):
		var am := _amassado()
		print("[incendio] frestas com %d batidas, no em %s:" % [
			am.batidas.size() if am != null else -1, position])
		for q: Vector3 in pts:
			var c := q + position
			print("[incendio]   %s (chapa %.3f)" % [c, _altura_da_chapa(c.z)])
	# As labaredas: os pontos a menos de um palmo e meio da quina.
	var quina := _no_local(_na_chapa(QUINA, Vector3(0.3, 0.6, -0.7)))
	var perto := PackedVector3Array()
	for q: Vector3 in pts:
		if q.distance_to(quina) < 0.2:
			perto.append(q)
	for par: Array in [[_chama, 0.0, pts], [_labareda, 0.0, perto], [_brasa, 0.02, pts],
			[_fumaca, 0.32, pts]]:
		var pm := (par[0] as GPUParticles3D).process_material as ParticleProcessMaterial
		var lista: PackedVector3Array = par[2]
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
		pm.emission_point_texture = _textura_de_pontos(lista, float(par[1]))
		pm.emission_point_count = lista.size()
	_frestas_acesas.mesh = _malha_das_frestas()
	var vento := VENTO_NO_CARRO
	var c := _carro()
	if c != null and c.is_inside_tree():
		vento = c.global_basis * VENTO_NO_CARRO
	(_fumaca.process_material as ParticleProcessMaterial).gravity = Vector3(0.0, 0.25, 0.0) + vento
	(_chama.process_material as ParticleProcessMaterial).gravity = Vector3(0.0, 0.9, 0.0) + vento * 0.5
	(_labareda.process_material as ParticleProcessMaterial).gravity = Vector3(0.0, 1.2, 0.0) + vento * 0.5
	(_brasa.process_material as ParticleProcessMaterial).gravity = Vector3(0.0, 0.4, 0.0) + vento * 2.0
	_mat_chama.set_shader_parameter(&"vento", vento * 0.25)
	_luz.position = _no_local(_luz_no_carro)


func _atualizar_frestas() -> void:
	var am := _amassado()
	var chave := Vector4(position.x, position.y, position.z,
		float(am.batidas.size()) if am != null else 0.0)
	if chave == _montado_com:
		return
	_montado_com = chave
	_montar_frestas()


## As frestas acesas por dentro: uma fita fina deitada em cada fresta, um fio
## acima da chapa, somada e tremendo. E o brilho do cofre em chamas visto pela
## fresta, que a chama sozinha nao da.
func _malha_das_frestas() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 10
	# Sem a grade: fita em pe na frente dela lia como neon.
	for f: Array in FRESTAS.slice(0, 2):
		var fora: Vector3 = (f[2] as Vector3).normalized()
		var qs: Array[Vector3] = []
		for i in N + 1:
			qs.append(_fresta(f, float(i) / float(N)) - fora * (FOLGA - 0.004))
		for i in N:
			var a := qs[i]
			var b := qs[i + 1]
			var lado := (b - a).cross(fora).normalized() * 0.006
			var t0 := float(i) / float(N)
			var t1 := float(i + 1) / float(N)
			for v: Array in [[a - lado, 0.0, t0], [a + lado, 1.0, t0], [b + lado, 1.0, t1],
					[a - lado, 0.0, t0], [b + lado, 1.0, t1], [b - lado, 0.0, t1]]:
				st.set_uv(Vector2(float(v[1]), float(v[2])))
				st.add_vertex(v[0])
	return st.commit()


# --- emissores ----------------------------------------------------------------

func _emissor(n: int, vida: float, mat: Material, proc: ParticleProcessMaterial,
		tamanho: Vector2, pe: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = n
	p.lifetime = vida
	p.local_coords = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = proc
	var q := QuadMesh.new()
	q.size = tamanho
	# A lingua de fogo tem o pe na fresta: o quad cresce para cima dela.
	q.center_offset = Vector3(0.0, pe, 0.0)
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-3.0, -1.5, -3.0), Vector3(6.0, 6.0, 6.0))
	add_child(p)
	return p


func _processo_fumaca() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.damping_min = 0.15
	p.damping_max = 0.35
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -25.0
	p.angular_velocity_max = 25.0
	p.turbulence_enabled = true
	p.turbulence_noise_scale = 3.0
	p.turbulence_noise_strength = 0.6
	p.turbulence_influence_min = 0.05
	p.turbulence_influence_max = 0.15
	p.scale_min = 0.6
	p.scale_max = 1.1
	p.scale_curve = FumacaParticulas._curva([Vector2(0.0, 0.3), Vector2(0.4, 1.1),
		Vector2(1.0, 2.4)])
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.75),
		Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	return p


func _processo_chama(menor: float, maior: float) -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3.UP
	p.spread = 6.0
	# Devagar: quem sobe e a lingua dentro do flipbook. Se a particula corre, o
	# pe descola da fresta e a chama vira bola subindo.
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.3
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.scale_min = menor
	p.scale_max = maior
	# Nasce baixa, cresce e baixa de novo: a lingua sai da fresta e recolhe.
	p.scale_curve = FumacaParticulas._curva([Vector2(0.0, 0.45), Vector2(0.3, 1.0),
		Vector2(1.0, 0.75)])
	# A fase do flipbook de cada lingua (o shader le em INSTANCE_CUSTOM.z).
	p.anim_offset_min = 0.0
	p.anim_offset_max = 1.0
	return p


func _processo_brasa() -> ParticleProcessMaterial:
	var p := ParticleProcessMaterial.new()
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.8
	p.turbulence_enabled = true
	p.turbulence_noise_scale = 2.0
	p.turbulence_noise_strength = 1.4
	p.turbulence_influence_min = 0.2
	p.turbulence_influence_max = 0.5
	p.scale_min = 0.4
	p.scale_max = 1.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.4, 0.1, 0.8),
		Color(0.6, 0.1, 0.02, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	p.color_ramp = gt
	return p


# --- materiais ----------------------------------------------------------------

const SHADER_CHAMA := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled, skip_vertex_transform;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D rampa : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec2 grade = vec2(8.0, 6.0);
uniform float quadros = 48.0;
uniform float fps = 30.0;
// O brilho (HDR) do miolo, e quanto o fogo esta aceso (0 a 1).
uniform float forca = 2.6;
uniform float fogo = 1.0;
// A particula suave: a distancia (m) em que ela some contra o que esta atras.
uniform float suave = 0.14;
// A fracao de baixo da lingua que nasce do escuro (o pe, atras da borda).
uniform float pe = 0.16;
// A ponta da chama deitando com o vento (m de desvio por m de altura, ao
// quadrado).
uniform vec3 vento = vec3(0.0);

varying vec2 uv0;
varying vec2 uv1;
varying float mistura;
varying float vida;

vec2 celula(float f, vec2 uv) {
	float c = mod(f, grade.x);
	float l = floor(f / grade.x);
	return (vec2(c, l) + uv) / grade;
}

void vertex() {
	vec3 centro = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	// Em pe: gira so em Y para a lente.
	vec3 para_lente = INV_VIEW_MATRIX[3].xyz - centro;
	para_lente.y = 0.0;
	para_lente = length(para_lente) > 1e-4 ? normalize(para_lente) : vec3(0.0, 0.0, 1.0);
	vec3 lado = normalize(cross(vec3(0.0, 1.0, 0.0), para_lente));
	float h = VERTEX.y * sy;
	vec3 mundo = centro + lado * VERTEX.x * sx + vec3(0.0, h, 0.0) + vento * h * h;
	VERTEX = (VIEW_MATRIX * vec4(mundo, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(para_lente, 0.0)).xyz);
	// O flipbook em laco, com fase e ritmo proprios de cada lingua.
	float rnd = INSTANCE_CUSTOM.z;
	float f = mod(TIME * fps * (0.85 + 0.3 * fract(rnd * 7.13)) + rnd * quadros, quadros);
	float f0 = floor(f);
	uv0 = celula(f0, UV);
	uv1 = celula(mod(f0 + 1.0, quadros), UV);
	mistura = f - f0;
	vida = INSTANCE_CUSTOM.y;
}

void fragment() {
	float i = mix(texture(atlas, uv0).r, texture(atlas, uv1).r, mistura);
	float k = smoothstep(0.0, pe, 1.0 - UV.y);
	k *= smoothstep(0.0, 0.12, vida) * (1.0 - smoothstep(0.55, 1.0, vida));
	float z = texture(depth_texture, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float fundo = -v.z / v.w;
	float eu = -VERTEX.z;
	k *= clamp((fundo - eu) / suave, 0.0, 1.0);
	// Colada na lente, some: nada de lingua do tamanho da tela.
	k *= smoothstep(0.2, 0.6, eu);
	// A cor sai da intensidade: ponta vermelha escura, miolo amarelo. Com o
	// fogo baixo o miolo esfria.
	vec3 cor = texture(rampa, vec2(clamp(i * (0.7 + 0.3 * fogo), 0.0, 1.0), 0.5)).rgb;
	ALBEDO = cor * forca * i * k * fogo;
	ALPHA = 1.0;
}
"""

const SHADER_FUMACA := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, vertex_lighting, specular_disabled, shadows_disabled;

uniform sampler2D tufo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// Vapor claro do radiador antes do fogo; fuligem de gasolina depois.
uniform vec3 vapor : source_color = vec3(0.50, 0.51, 0.53);
uniform vec3 fuligem : source_color = vec3(0.06, 0.055, 0.05);
// O pe da coluna aceso por baixo pela chama (piso de emissao): sem ele a
// fumaca escura no escuro some, ou fica marrom.
uniform vec3 brasa : source_color = vec3(1.0, 0.38, 0.10);
uniform float brilho = 0.35;
uniform float fogo = 0.0;
uniform float suave = 0.35;
// A luz do fogo acendendo a fumaca por dentro (espalhamento): a posicao e a
// energia de agora (o tremor), e a queda com a distancia. A luz da cena so
// acende a face virada para ela, e a face do tufo olha a lente: por baixo da
// coluna a fumaca ficava preta.
uniform vec3 luz_pos = vec3(0.0);
uniform float luz_forca = 0.0;
uniform float luz_raio = 0.7;

varying float vida;
varying float alfa;
varying float perto_da_luz;

void vertex() {
	// Billboard girando no proprio eixo (o angulo da particula).
	float s = length(MODEL_MATRIX[0].xyz);
	float a = INSTANCE_CUSTOM.x;
	VERTEX.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy * s;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vida = INSTANCE_CUSTOM.y;
	alfa = COLOR.a;
	float d = distance(MODEL_MATRIX[3].xyz, luz_pos) / luz_raio;
	perto_da_luz = 1.0 / (1.0 + d * d);
}

void fragment() {
	float t = texture(tufo, UV).a;
	vec3 base = mix(vapor, fuligem, fogo);
	ALBEDO = base;
	float quente = 1.0 - smoothstep(0.0, 0.45, vida);
	EMISSION = brasa * quente * quente * brilho * fogo
		+ brasa * base * 6.0 * perto_da_luz * luz_forca;
	float z = texture(depth_texture, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	float fundo = -v.z / v.w;
	float macio = clamp((fundo + VERTEX.z) / suave, 0.0, 1.0) * smoothstep(0.3, 0.9, -VERTEX.z);
	// A fuligem e mais densa que o vapor.
	ALPHA = clamp(t * alfa * macio * mix(1.4, 2.4, fogo), 0.0, 1.0);
}
"""

const SHADER_FRESTAS := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 cor : source_color = vec3(1.0, 0.45, 0.12);
uniform float forca = 0.9;
uniform float fogo = 0.0;

float h1(float x) { return fract(sin(x * 91.7 + 3.1) * 43758.5); }
float ruido(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(h1(i), h1(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	// UV.x atravessa a fita (0 a 1), UV.y corre ao longo dela.
	float miolo = 1.0 - abs(UV.x * 2.0 - 1.0);
	float pisca = 0.45 + 0.55 * ruido(UV.y * 23.0 + TIME * 6.0) * ruido(UV.y * 7.0 - TIME * 3.1 + 5.0);
	ALBEDO = cor * forca * miolo * miolo * pisca * fogo;
	ALPHA = 1.0;
}
"""

static var _shaders: Dictionary = {}


static func _shader(nome: StringName, codigo: String) -> Shader:
	if not _shaders.has(nome):
		var s := Shader.new()
		s.code = codigo
		_shaders[nome] = s
	return _shaders[nome]


## A lingua de fogo: o flipbook somado, colorido pela rampa.
func _material_chama() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(&"chama", SHADER_CHAMA)
	m.set_shader_parameter(&"atlas", load(ATLAS))
	m.set_shader_parameter(&"rampa", _rampa_chama())
	m.set_shader_parameter(&"grade", ATLAS_GRADE)
	m.set_shader_parameter(&"quadros", ATLAS_QUADROS)
	return m


## Da ponta da lingua (pouca chama: vermelho fundo, quase fuligem) ao miolo
## (amarelo, nunca branco: o branco e o que o glow faz em cima).
static func _rampa_chama() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.4, 0.65, 0.85, 1.0])
	g.colors = PackedColorArray([Color(0.22, 0.02, 0.0), Color(0.62, 0.07, 0.0),
		Color(0.95, 0.22, 0.02), Color(1.0, 0.40, 0.06), Color(1.0, 0.58, 0.16),
		Color(1.0, 0.72, 0.34)])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	return t


func _material_fumaca() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(&"fumaca", SHADER_FUMACA)
	m.set_shader_parameter(&"tufo", load(TUFO))
	return m


func _material_frestas() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(&"frestas", SHADER_FRESTAS)
	return m


## A brasa: um ponto quente e pequeno, sem textura.
func _mat_brasa() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(3.0, 2.2, 1.4, 1.0)
	m.albedo_texture = load(TUFO) as Texture2D
	return m
