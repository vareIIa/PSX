## A agua que o carro da Estrada Velha levanta: o leque continuo das rodas e a
## explosao de quando uma delas entra numa poca.
##
## Por que nao e o `SprayRoda`
## ---------------------------
## O `SprayRoda` acompanha `VehicleWheel3D`, e nao ha nenhuma aqui: o carro desta
## cena e um `CarroCena`, que anda sobre trilhos porque a estrada nem colisao tem
## (ver o cabecalho de `carro_cena.gd`). O que ele tem sao dois eixos visuais no
## centro do carro — para saber onde a roda TOCA o chao e preciso somar a bitola
## e o raio, que sao medidas da `Carroceria`.
##
## E ha uma segunda coisa que o spray da cidade nao faz, e que e o pedido desta
## cena: o carro passando POR CIMA da poca. Na cidade a poca e um decal sorteado
## por celula de asfalto e o carro nao sabe que ela existe. Aqui a agua e uma
## funcao de `s` (`PocasEstrada.mergulho`), entao a roda pode perguntar, a cada
## quadro, se esta dentro de uma — e responder com um jato lateral de verdade,
## que e a diferenca entre "chove e o carro anda" e "o carro atravessou aquela
## poca ali".
##
## Duas particulas, e nao uma
## --------------------------
## O leque continuo e uma nevoa fina atras das rodas: muitas particulas pequenas,
## vida curta, sempre ligada enquanto ha agua no chao e velocidade. A explosao e
## o oposto — poucas gotas, grandes, rapidas, saindo de LADO e para cima, e so
## enquanto a roda esta dentro da lamina. Somar as duas num emissor so daria uma
## media das duas: um leque grosso demais para o asfalto e fraco demais para a
## poca.
class_name SprayEstrada
extends Node3D

const SHADER := "res://shaders/psx_chuva.gdshader"

## Abaixo desta velocidade a roda nao tem energia para levantar lamina, em m/s.
const VEL_MINIMA := 4.0
## Velocidade em que o leque ja esta no maximo, em m/s. 20 m/s = 72 km/h.
const VEL_CHEIA := 20.0
## Abaixo deste molhado nao ha lamina para levantar. Mesmo numero do `SprayRoda`.
const MOLHADO_MINIMO := 0.3
## Particulas no leque cheio, por roda de tras.
const QUANTIDADE := 420
## Particulas na explosao cheia, por roda.
## Particulas na explosao cheia, por roda. Muitas e pequenas.
##
## Era 260 gotas de 7,5 x 13 cm, e 13 cm de gota a um metro de uma lente de
## 58 graus e uma BOLA DE NEVE: a captura saiu com quinze discos brancos
## chapados pendurados na frente do carro. Agua que salta se le pela
## QUANTIDADE e pela velocidade, nunca pelo tamanho de cada gota — o dobro
## delas com metade do tamanho custa o mesmo preenchimento e vira lamina.
const QUANTIDADE_POCA := 460

## Cor da agua levantada. Puxada para o barro, e nao para o branco do `SprayRoda`:
## o que a roda levanta numa estrada de terra nao e agua limpa, e a lama de cima
## do sulco. Branco aqui lia como espuma de sabao sobre a terra vermelha.
const COR_LEQUE := Color(0.62, 0.58, 0.52, 1.0)
const COR_POCA := Color(0.70, 0.66, 0.58, 1.0)

## O som da lamina sendo rasgada pelo pneu.
const SOM_POCA := &"poca_pneu"
## Acima deste mergulho a roda entrou na agua de verdade. Abaixo ela so
## roçou a borda, e borda de poca nao faz barulho.
const SOM_LIMIAR := 0.45
## Silencio minimo entre dois disparos da MESMA roda, em segundos. Sem ele,
## uma poca comprida atravessada a 68 km/h dispara em cada quadro em que o
## mergulho oscila em volta do limiar, e o que se ouve e uma metralhadora.
const SOM_ESPERA := 0.35
## A roda de tras entra na MESMA poca que a da frente, 2,57 m depois: a 68 km/h
## sao 0,14 s. Cada poca virava dois estalos seguidos por lado, e com uma poca a
## cada meio segundo, de dentro do carro, o que se ouvia era um "PA PA PA"
## (medido com `--medir-sons`: 26 disparos em 5 s de estrada). A de tras so
## soa se a da frente do mesmo lado ficou calada por este tempo.
const SOM_TRAS_DEPOIS := 0.5
## E as duas rodas da frente entram juntas numa poca larga: um so chape para o
## carro inteiro neste intervalo (s).
const SOM_CARRO_ESPERA := 0.3
var _desde_som_carro: float = 9.0
## De dentro do carro a poca e agua batendo embaixo do assoalho: abafada (o
## bus `Abafado` do `AudioDirector`) e mais baixa. Seca e alta, como sai no
## plano de fora, ela e um estalo de chicote no ouvido de quem esta no banco.
const SOM_DENTRO_DB := -9.0
const DENTRO_RAIO := 2.6

var _carro: CarroCena
## Quem sabe onde ha agua parada. E a MESMA instancia que materializa os
## decais: se cada um tivesse a sua, o espirro sairia onde nao ha poca
## desenhada e a cena mentiria em dois lugares ao mesmo tempo.
var _pocas: PocasEstrada

## Velocidade em km/h para fingir, quando >= 0. So a captura usa.
##
## O plano da poca e fotografado com o carro PARADO em cima da agua — e a
## regra da captura desta cena, e ela existe porque a fisica anda trinta
## metros nos cem quadros que a captura espera, e nada do que foi posto no
## quadro continuaria no quadro. Mas roda parada nao levanta agua, entao a
## foto do efeito sairia sem o efeito. Aqui se diz "finja que esta a 68" sem
## mover o carro, do mesmo jeito que `--molhado=` finge noventa segundos de
## chuva sem esperar por eles.
var velocidade_forcada: float = -1.0
## Deslocamento lateral de cada roda em relacao ao eixo do carro, em metros.
## Negativo e a esquerda de quem dirige.
var _bitola: float = 0.72
var _eixo: float = 1.28

## Quatro leques (um por roda) e quatro explosoes, na mesma ordem:
## 0 = frente esquerda, 1 = frente direita, 2 = tras esquerda, 3 = tras direita.
var _leques: Array[GPUParticles3D] = []
var _mats_leque: Array[ShaderMaterial] = []
var _jatos: Array[GPUParticles3D] = []
var _mats_jato: Array[ShaderMaterial] = []
## Ha quanto tempo cada roda tocou o som da poca, em segundos.
var _desde_som := PackedFloat32Array([9.0, 9.0, 9.0, 9.0])


## Mesma assinatura em espirito do `SprayRoda.acompanhar`: quem acompanha quem, e
## as medidas de onde a roda toca o chao.
func acompanhar(carro: CarroCena, medidas: Dictionary,
		pocas: PocasEstrada) -> void:
	_carro = carro
	_pocas = pocas
	_bitola = float(medidas.get("bitola", 1.44)) * 0.5
	_eixo = float(medidas.get("entre_eixos", 2.57)) * 0.5
	_montar()


## Onde as quatro rodas passam, medido do eixo da estrada.
##
## A `PocasEstrada` planta a agua exatamente nestes dois numeros, e por isso
## eles saem daqui: e o carro que decide onde a roda passa, e a poca que segue
## a roda. Ao contrario — a roda procurando a poca — a agua ficaria no sulco
## desenhado e o carro passaria meio metro ao lado dela.
func caminhos_de_roda() -> PackedFloat32Array:
	return PackedFloat32Array([
		CarroCena.DESVIO_LATERAL - _bitola,
		CarroCena.DESVIO_LATERAL + _bitola])


func _montar() -> void:
	for k in 4:
		# Coordenadas de MUNDO nas duas: a gota sai da roda e FICA PARA TRAS. Em
		# coordenadas locais ela viajaria junto com o carro e o leque ficaria
		# colado na roda como um pompom — mesmo defeito que o `SprayRoda` ja
		# registra.
		var leque := GPUParticles3D.new()
		leque.name = "Leque%d" % k
		leque.lifetime = 0.5
		leque.randomness = 1.0
		leque.fixed_fps = 30
		leque.interpolate = false
		leque.local_coords = false
		leque.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		leque.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 3.0, 6.0))
		leque.emitting = false

		var proc := ParticleProcessMaterial.new()
		proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		proc.emission_sphere_radius = 0.15
		proc.direction = Vector3(0.0, 0.45, 1.0)
		proc.spread = 36.0
		proc.initial_velocity_min = 1.5
		proc.initial_velocity_max = 4.0
		proc.gravity = Vector3(0.0, -9.0, 0.0)
		proc.scale_min = 0.45
		proc.scale_max = 1.1
		leque.process_material = proc

		var quad := QuadMesh.new()
		quad.size = Vector2(0.036, 0.065)
		quad.orientation = PlaneMesh.FACE_Z
		leque.draw_pass_1 = quad

		var m := ShaderMaterial.new()
		m.shader = load(SHADER)
		m.set_shader_parameter(&"perto", 0.5)
		m.set_shader_parameter(&"longe", 18.0)
		m.set_shader_parameter(&"cor", COR_LEQUE)
		leque.material_override = m
		add_child(leque)
		_leques.append(leque)
		_mats_leque.append(m)

		var jato := GPUParticles3D.new()
		jato.name = "Jato%d" % k
		# Vida mais longa que a do leque: a agua da poca sobe, abre em leque e
		# CAI, e a queda e metade do efeito. Cortada em meio segundo, a gota
		# desaparece no alto do arco e o olho le sumico, nao gravidade.
		jato.lifetime = 0.85
		jato.randomness = 0.9
		jato.fixed_fps = 30
		jato.interpolate = false
		jato.local_coords = false
		jato.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		jato.visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 5.0, 8.0))
		jato.emitting = false

		var pj := ParticleProcessMaterial.new()
		pj.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		# Caixa achatada e comprida: a agua sai da LINHA de contato do pneu, e
		# nao de um ponto. De um ponto o jato vira um chafariz.
		pj.emission_box_extents = Vector3(0.10, 0.02, 0.22)
		# Para FORA e para cima. O X e preenchido por roda em `_montar_jato`:
		# a roda da esquerda joga agua para a esquerda, a da direita para a
		# direita, e as duas jogando para o mesmo lado leria como vento.
		pj.direction = Vector3(0.0, 0.85, 0.35)
		pj.spread = 42.0
		pj.initial_velocity_min = 2.6
		pj.initial_velocity_max = 6.4
		pj.gravity = Vector3(0.0, -11.0, 0.0)
		pj.scale_min = 0.6
		pj.scale_max = 1.45
		jato.process_material = pj

		var quad_j := QuadMesh.new()
		quad_j.size = Vector2(0.038, 0.07)
		quad_j.orientation = PlaneMesh.FACE_Z
		jato.draw_pass_1 = quad_j

		var mj := ShaderMaterial.new()
		mj.shader = load(SHADER)
		# Desvanece bem mais longe da lente que o leque: o jato nasce a um metro
		# da camera no plano da poca, e gota colada na lente vira mancha chapada
		# em vez de agua. `perto` e a distancia em que ela termina de aparecer.
		mj.set_shader_parameter(&"perto", 0.95)
		mj.set_shader_parameter(&"longe", 22.0)
		mj.set_shader_parameter(&"cor", COR_POCA)
		jato.material_override = mj
		add_child(jato)
		_jatos.append(jato)
		_mats_jato.append(mj)

	_apontar_jatos()


## Cada jato joga agua para o lado de fora do carro.
func _apontar_jatos() -> void:
	for k in _jatos.size():
		var proc := _jatos[k].process_material as ParticleProcessMaterial
		var lado := -1.0 if (k % 2) == 0 else 1.0
		proc.direction = Vector3(lado * 0.9, 0.85, 0.35).normalized()


## Onde a roda `k` toca o chao, em coordenada local da estrada.
func _roda_local(k: int) -> Vector3:
	var s := _carro.distancia + (_eixo if k < 2 else -_eixo)
	var e := CarroCena.DESVIO_LATERAL + (-_bitola if (k % 2) == 0 else _bitola)
	var p := EstradaBuilder.ponto_em(s) + EstradaBuilder.lado_em(s) * e
	p.y = PocasEstrada.altura_do_leito(s, e)
	return p


func _process(delta: float) -> void:
	for k in _desde_som.size():
		_desde_som[k] += delta
	_desde_som_carro += delta
	if _carro == null or not is_instance_valid(_carro) or _leques.is_empty():
		return

	# Os mesmos tres portoes do `SprayRoda`, e pelos mesmos motivos: tem de haver
	# agua no chao, o carro tem de estar andando, e o estilo tem de ser o MODERNO
	# — no PS1 STYLE o preset e a build de antes e conteudo novo de chuva nao
	# entra.
	var molhado := Clima.molhado_visivel()
	var vel := absf(velocidade_forcada if velocidade_forcada >= 0.0
		else _carro.velocidade) / 3.6
	if molhado < MOLHADO_MINIMO or not Settings.luz_por_pixel or vel < VEL_MINIMA:
		for p: GPUParticles3D in _leques:
			p.emitting = false
		for p: GPUParticles3D in _jatos:
			p.emitting = false
		return

	var f := clampf(inverse_lerp(VEL_MINIMA, VEL_CHEIA, vel), 0.0, 1.0)
	var forca := f * clampf(inverse_lerp(MOLHADO_MINIMO, 1.0, molhado), 0.0, 1.0)
	var base := _carro.global_basis
	# A altura da cena entra UMA vez, aqui: as contas de roda e de poca todas
	# moram em coordenada local da estrada, e o no vive dentro do `MundoEstrada`,
	# que ja carrega os quatro mil metros. Somar de novo poria a agua no ceu.
	for k in 4:
		var onde := to_global(_roda_local(k))
		# Do CHAO, nao do centro da roda: a agua e levantada pelo ponto de
		# contato, e nascer no eixo poe o leque na altura do para-lama.
		var leque := _leques[k]
		leque.global_position = onde
		leque.global_basis = base
		# So as de TRAS levantam leque visivel. Na dianteira ele nasce debaixo da
		# lataria e some sem nunca ser visto, custando o mesmo — mesma conta do
		# `SprayRoda`. As quatro continuam podendo pegar poca.
		var atras := k >= 2
		leque.emitting = atras
		if atras:
			leque.amount = maxi(12, int(QUANTIDADE * forca))
			_mats_leque[k].set_shader_parameter(&"intensidade", 0.55 + 1.0 * forca)

		var jato := _jatos[k]
		jato.global_position = onde
		jato.global_basis = base
		var s := _carro.distancia + (_eixo if k < 2 else -_eixo)
		var e := CarroCena.DESVIO_LATERAL + (-_bitola if (k % 2) == 0 else _bitola)
		var dentro := _pocas.mergulho(s, e) if _pocas != null else 0.0
		jato.emitting = dentro > 0.02
		var calada := (k < 2 or _desde_som[k - 2] > SOM_TRAS_DEPOIS) \
			and _desde_som_carro > SOM_CARRO_ESPERA
		if dentro > SOM_LIMIAR and _desde_som[k] > SOM_ESPERA and calada:
			_desde_som[k] = 0.0
			_desde_som_carro = 0.0
			# Afinacao pela velocidade: a mesma poca atravessada devagar e um
			# chape e atravessada rapido e um assobio. Uma amostra so cobre as
			# duas, e sem isso as quatro rodas soam identicas uma atras da outra.
			var som := AudioDirector.tocar(SOM_POCA, onde,
				lerpf(-14.0, -3.0, dentro * forca),
				lerpf(0.84, 1.16, f) + (0.03 if k >= 2 else -0.03))
			if som != null and _ouvinte_dentro():
				som.volume_db += SOM_DENTRO_DB
				if AudioServer.get_bus_index(AudioDirector.BUS_ABAFADO) >= 0:
					som.bus = AudioDirector.BUS_ABAFADO
		if jato.emitting:
			jato.amount = maxi(20, int(QUANTIDADE_POCA * dentro * forca))
			# Teto em 1,0, e nao em 2,4.
			#
			# O shader da chuva e `blend_add` e satura o alfa em 1: qualquer valor
			# acima disso pinta a gota de branco CHAPADO, e o que aparece na tela
			# sao discos brancos opacos em vez de agua. Agua nao e opaca nem quando
			# e muita; o que muda com a forca do espirro e a QUANTIDADE de gota, e
			# essa ja esta no `amount` logo acima.
			_mats_jato[k].set_shader_parameter(&"intensidade",
				0.34 + 0.46 * dentro * forca)


## A camera esta dentro do carro (o plano da cabine)?
func _ouvinte_dentro() -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to(_carro.global_position) < DENTRO_RAIO
