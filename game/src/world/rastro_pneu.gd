## O que o pneu deixa para tras.
##
## Por que isto existe
## -------------------
## Porque a derrapagem ja era medida, ja fazia barulho e nao acontecia em lugar
## nenhum. O carro tinha `escorregamento()` lendo o `get_skidinfo()` das quatro
## rodas, o `MotorSom` tinha uma camada de pneu cantando a partir de 0,14 de
## escorregao, e o asfalto continuava limpo. O jogador puxava o freio de mao,
## ouvia o grito, via o carro girar — e ao terminar a manobra nao havia nenhuma
## prova de que ela tinha acontecido.
##
## Marca de pneu e o unico registro que um jogo de carro deixa do que o jogador
## fez. Ela e a diferenca entre uma rua por onde alguem passou e uma rua que
## alguem USOU, e e o motivo pelo qual toda captura de propaganda do genero, de
## 1997 para ca, e tirada em cima de uma.
##
## Por que ela nao e filha do carro (mesmo sendo)
## ----------------------------------------------
## O no e filho do `Carro` — para nascer, morrer e ser recolhido junto com ele —
## mas com `top_level` ligado, que desliga a heranca de transformada. Os
## vertices ficam em coordenada de MUNDO. Sem isso a marca andaria junto com a
## lataria, o que e o oposto exato do que ela e: a marca fica onde o pneu
## passou, e o carro e que vai embora.
##
## Morrer junto com o carro tambem e desenho, e nao economia. O `Transito`
## recolhe carro a 74 m; a marca desse carro some junto, longe, onde ninguem
## esta olhando. A alternativa — um acumulador de marcas no nivel do mundo —
## precisaria de uma politica propria de esquecimento, e a que ele teria seria
## essa mesma.
##
## Duas superficies, dois desenhos
## -------------------------------
## A borracha no chao e a fumaca no ar sao a mesma coisa acontecendo: o pneu
## girando mais que o asfalto deixa. Sao duas superficies do mesmo no porque
## nascem do mesmo evento e no mesmo instante — separa-las em dois nos daria
## duas rodas de vida, dois limiares e a chance de uma existir sem a outra, que
## e o defeito de leitura que ninguem consegue nomear ao ver.
class_name RastroPneu
extends MeshInstance3D

const MAT_MARCA := "res://resources/materials/mat_marca_pneu.tres"
const MAT_FUMACA := "res://resources/materials/mat_fumaca_pneu.tres"

## A partir de quanto escorregamento a roda comeca a marcar.
##
## E MAIS alto que o limiar do som (`MotorSom.CANTA_LIMIAR`, 0,14) de proposito.
## Pneu chia antes de deixar borracha: o chiado e o comeco do deslizamento e a
## marca e o fim dele. Com os dois no mesmo numero, toda curva de rua deixava
## rastro e a cidade virava um circuito com dois dias de treino.
const LIMIAR := 0.36
## E o limiar para PARAR de marcar, que e mais baixo. Sem essa histerese o
## rastro nao acontece.
##
## O escorregamento de uma roda oscila de quadro a quadro: na derrapagem medida
## ele encosta em 1,00 no pico e passeia em volta do limiar o tempo todo. Com um
## limiar unico, quase toda amostra caia do outro lado, a trilha era cortada e
## recomecada, e cada recomeco PERDE um pedaco — porque o primeiro ponto de uma
## trilha nao tem de onde vir. Medido: dez pedacos em dois segundos de freio de
## mao, uns dois metros de marca numa manobra que arrastou oito.
##
## Pneu de verdade tambem nao volta a agarrar no quadro seguinte. Uma vez
## deslizando, ele desliza ate a carga cair bem abaixo do ponto em que soltou.
const LIMIAR_SOLTA := 0.22
## Escorregamento em que a marca chega na tinta cheia.
const LIMIAR_CHEIO := 0.80

## Comprimento de cada pedaco de marca, em metros.
##
## Compromisso entre curva e orcamento: com 0,30 m uma manobra de freio de mao
## em raio de 6 m vira um poligono de 20 lados, que a 480x270 nao se distingue
## de um arco.
const PASSO := 0.30
## Quantos pedacos cabem. As quatro rodas dividem o mesmo anel: numa derrapagem
## de traseira sao duas rodas marcando, entao cada uma leva 96 pedacos, que sao
## 28 m de rastro por roda.
const PEDACOS := 192
## Quanto tempo a marca leva para sumir, em segundos.
##
## Nao e "para sempre" nem e um piscar. Vinte e dois segundos e o tempo de dar
## a volta no quarteirao e voltar para ver o que se fez — que e a unica coisa
## que alguem faz com a marca depois de fazer a marca.
const VIDA := 22.0
## Largura da marca. Um pouco menor que o pneu: a borracha marca com a banda de
## rodagem e nao com o flanco.
const LARGURA := Carroceria.LARGURA_RODA * 0.82
## Quanto a marca sobe do chao, em metros.
##
## Tres centimetros e nao um e meio, e a diferenca saiu da medida: com 1,5 cm a
## marca ficou 3 mm acima do asfalto medido por raio — o raio do pneu e o raio
## do teste caem em pontos diferentes de uma pista que tem caimento, e a
## discordancia entre os dois e da ordem de um centimetro. Tres centimetros
## cobrem essa folga com margem e continuam invisiveis: a 480x270, de seis
## metros de camera, tres centimetros de flutuacao nao chegam a um pixel.
const ALTURA := 0.03

## Quantas vezes por segundo a malha e reconstruida.
##
## A marca nasce do passo de fisica, que roda a 60 Hz, e reconstruir 192
## quadrilateros sessenta vezes por segundo em GDScript e trabalho de verdade
## para nada: a 20 Hz o pedaco que falta e o que esta debaixo do carro, tapado
## pela propria lataria.
const REDESENHO := 20.0

# --- fumaca ------------------------------------------------------------------
## A partir de quanto escorregamento sai fumaca. Mais alto que o da marca: pneu
## solta borracha antes de solta-la QUEIMADA.
const LIMIAR_FUMACA := 0.58
## Quantos bafos existem ao mesmo tempo.
const BAFOS := 14
## Quanto tempo cada bafo dura, em segundos.
const VIDA_BAFO := 1.35
## Intervalo entre dois bafos da mesma roda, em segundos.
const ESPERA_BAFO := 0.075
## Tamanho do bafo ao nascer e ao morrer, em metros.
const BAFO_NASCE := 0.34
const BAFO_MORRE := 1.65
## Quanto o bafo sobe por segundo. Fumaca de pneu nao sobe como fumaca de
## chamine: ela e empurrada para fora e so depois levanta.
const BAFO_SOBE := 0.85
## Quanto da velocidade do carro o bafo herda. Ele fica para tras, mas nao
## instantaneamente: o ar arrastado pelo carro leva um pouco junto.
const BAFO_ARRASTA := 0.22

## Uma roda que marcou no quadro anterior. Guarda a continuidade: sem ela, cada
## pedaco seria um retangulo solto e a marca sairia pontilhada.
class Trilha:
	var ativo: bool = false
	var ponto := Vector3.ZERO
	var espera_bafo: float = 0.0


var _carro: Carro
var _rodas: Array[VehicleWheel3D] = []
var _trilhas: Array[Trilha] = []

## Anel de pedacos de marca. Quatro vertices e um nascimento por pedaco.
var _cantos := PackedVector3Array()
var _nascido := PackedFloat32Array()
var _tinta := PackedFloat32Array()
var _proximo: int = 0
var _vivos: int = 0

## Anel de bafos de fumaca.
var _bafo_onde := PackedVector3Array()
var _bafo_vel := PackedVector3Array()
var _bafo_nascido := PackedFloat32Array()
var _bafo_tinta := PackedFloat32Array()
var _bafo_proximo: int = 0

var _relogio: float = 0.0
var _desde_desenho: float = 999.0
var _sujo: bool = false
## Total de pedacos marcados desde que o carro foi assumido. So o teste le.
var _marcados: int = 0
var _bafos_soltos: int = 0

var _malha := ArrayMesh.new()


func _ready() -> void:
	# A transformada e do MUNDO: os vertices sao absolutos. Ver o cabecalho.
	top_level = true
	transform = Transform3D.IDENTITY
	mesh = _malha
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Nada de nevoa nem de luz: os dois materiais sao unshaded. O que tira a
	# marca de longe e o fade do proprio shader.
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED

	_cantos.resize(PEDACOS * 4)
	_nascido.resize(PEDACOS)
	_tinta.resize(PEDACOS)
	_bafo_onde.resize(BAFOS)
	_bafo_vel.resize(BAFOS)
	_bafo_nascido.resize(BAFOS)
	_bafo_tinta.resize(BAFOS)
	for k in PEDACOS:
		_nascido[k] = -999.0
	for k in BAFOS:
		_bafo_nascido[k] = -999.0


## Liga o rastro a um carro e as rodas dele.
func acompanhar(c: Carro, rodas: Array[VehicleWheel3D]) -> void:
	_carro = c
	_rodas = rodas
	_trilhas.clear()
	for _k in rodas.size():
		_trilhas.append(Trilha.new())


## Um passo de fisica. Quem chama e o `Carro`, do `_physics_process` dele, para
## a amostragem acontecer na mesma taxa em que a suspensao anda.
## `marcando` e falso quando ninguem esta ao volante. O rastro CONTINUA vivo
## nesse caso, so para de crescer: o momento em que o jogador desce do carro e
## exatamente o momento em que ele vai olhar o que deixou no chao, e apagar
## tudo ali seria apagar o unico registro da manobra no instante em que ela
## termina. As marcas desbotam sozinhas, como desbotariam com ele dentro.
func passo(delta: float, marcando: bool) -> void:
	_relogio += delta
	_desde_desenho += delta
	if marcando and _carro != null and is_instance_valid(_carro):
		_amostrar(delta)
	if _desde_desenho >= 1.0 / REDESENHO:
		_desde_desenho = 0.0
		if _sujo or _vivos > 0:
			_reconstruir()


## Onde cada roda esta escorregando, e quanto.
##
## O escorregamento e por RODA e nao o do carro inteiro: numa derrapagem de
## traseira as duas da frente continuam agarradas, e usar a media do carro
## poria marca embaixo de roda que nao estava deslizando — que e o defeito que
## faz um rastro de jogo parecer decalque em vez de consequencia.
func _amostrar(delta: float) -> void:
	var cima := _carro.global_transform.basis.y
	var vel := _carro.linear_velocity
	for k in _rodas.size():
		var r := _rodas[k]
		var t: Trilha = _trilhas[k]
		t.espera_bafo = maxf(0.0, t.espera_bafo - delta)
		if not r.is_in_contact():
			t.ativo = false
			continue
		var escorrega := 1.0 - clampf(r.get_skidinfo(), 0.0, 1.0)
		# Histerese: comeca alto, larga baixo. Ver `LIMIAR_SOLTA`.
		if escorrega < (LIMIAR_SOLTA if t.ativo else LIMIAR):
			t.ativo = false
			continue
		var chao := _onde_encosta(r, cima)
		if not t.ativo:
			t.ativo = true
			t.ponto = chao
			continue
		var corrido := chao - t.ponto
		if corrido.length() < PASSO:
			continue
		# Piso alto, e nao 0,12. A marca mais fraca que o jogo desenha ainda
		# tem de ser uma marca: com piso baixo, um escorregao de 0,4 — que e o
		# de uma curva forte — pintava o asfalto com 17% de escurecimento, que
		# e o mesmo que nao pintar.
		var forca := clampf((escorrega - LIMIAR) / (LIMIAR_CHEIO - LIMIAR),
			0.55, 1.0)
		_marcar(t.ponto, chao, cima, forca)
		t.ponto = chao
		if escorrega >= LIMIAR_FUMACA and t.espera_bafo <= 0.0:
			t.espera_bafo = ESPERA_BAFO
			_bafejar(chao, vel, forca)


## Onde a borracha encosta, medido e nao suposto.
##
## A primeira versao fazia a conta de projeto — centro da roda menos o raio, na
## vertical do carro — e ela esta errada em 5 cm. O `VehicleBody3D` move o no da
## roda junto com a suspensao, e a origem do `Carro` nao fica no asfalto quando
## o carro esta apoiado nas molas: fica uns dez centimetros acima. O relatorio
## acusou a marca 3,6 cm ABAIXO do plano do carro, ou seja, enterrada no
## asfalto — desenhada, contada pelo teste e invisivel na tela, que e o pior
## tipo de defeito que existe.
##
## Um raio curto para baixo devolve a superficie em que o pneu esta passando,
## seja ela asfalto, meio-fio ou a rampa de uma garagem, e a normal dela da a
## direcao certa para levantar a marca do chao. Custa uma consulta por pedaco
## marcado — nao por quadro —, e so enquanto ha derrapagem acontecendo.
func _onde_encosta(r: VehicleWheel3D, cima: Vector3) -> Vector3:
	var centro := r.global_position
	var espaco := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		centro + cima * 0.05, centro - cima * (r.wheel_radius + 0.35), 1)
	consulta.exclude = [_carro.get_rid()]
	var achado := espaco.intersect_ray(consulta)
	if achado.is_empty():
		# Sem chao debaixo da roda — acontece na borda de uma rampa. Cai na
		# conta de projeto, que erra por centimetros e nao por metros.
		return centro - cima * (r.wheel_radius - ALTURA)
	return (achado["position"] as Vector3) + (achado["normal"] as Vector3) * ALTURA


## Um pedaco de marca, do ponto anterior ate o atual.
func _marcar(de: Vector3, ate: Vector3, cima: Vector3, forca: float) -> void:
	var rumo := ate - de
	var lado := rumo.cross(cima)
	if lado.length() < 0.0001:
		return
	lado = lado.normalized() * (LARGURA * 0.5)
	var i := _proximo * 4
	_cantos[i] = de - lado
	_cantos[i + 1] = de + lado
	_cantos[i + 2] = ate + lado
	_cantos[i + 3] = ate - lado
	_nascido[_proximo] = _relogio
	_tinta[_proximo] = forca
	_proximo = (_proximo + 1) % PEDACOS
	_marcados += 1
	_sujo = true


func _bafejar(onde: Vector3, vel_carro: Vector3, forca: float) -> void:
	_bafo_onde[_bafo_proximo] = onde
	# Sai para o lado de fora da curva e para cima, levando um resto do que o
	# carro estava fazendo. Sem o resto, a fumaca nasce parada ao lado de um
	# carro a 60 km/h e le como nuvem pintada no chao.
	_bafo_vel[_bafo_proximo] = vel_carro * BAFO_ARRASTA + Vector3(
		randf_range(-0.5, 0.5), BAFO_SOBE, randf_range(-0.5, 0.5))
	_bafo_nascido[_bafo_proximo] = _relogio
	_bafo_tinta[_bafo_proximo] = forca
	_bafo_proximo = (_bafo_proximo + 1) % BAFOS
	_bafos_soltos += 1
	_sujo = true


# --- desenho ------------------------------------------------------------------

## Reconstroi as duas superficies.
##
## Reconstruir e nao remendar: atualizar regiao de vertice num `ArrayMesh` do
## Godot pede que o formato e o tamanho nao mudem, e aqui os dois mudam — o
## anel enche, os pedacos velhos saem e a fumaca vira para a camera. Refazer
## 192 quadrilateros vinte vezes por segundo custa menos do que o cuidado que a
## outra saida exigiria.
func _reconstruir() -> void:
	_malha.clear_surfaces()
	_sujo = false
	_vivos = 0
	_superficie_marcas()
	_superficie_fumaca()


func _superficie_marcas() -> void:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for k in PEDACOS:
		var idade := _relogio - _nascido[k]
		if idade < 0.0 or idade > VIDA:
			continue
		_vivos += 1
		# A marca some por desbotamento e nao por corte: uma tira que desaparece
		# de uma vez le como objeto apagado, e uma que clareia le como borracha
		# que o transito levou.
		#
		# O desbotamento e QUADRATICO e nao linear: linear, a marca ja nasce
		# perdendo e passa metade da vida a meia tinta. Assim ela fica forte
		# quase ate o fim e some depressa, que e como marca de pneu some de
		# verdade — a borracha resiste e depois o transito leva tudo de uma vez.
		var t_vida := idade / VIDA
		var a := _tinta[k] * (1.0 - t_vida * t_vida)
		var cor := Color(1.0, 1.0, 1.0, a)
		var base := v.size()
		for j in 4:
			v.append(_cantos[k * 4 + j])
			c.append(cor)
		idx.append_array(PackedInt32Array([
			base, base + 1, base + 2, base, base + 2, base + 3]))
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	_malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_malha.surface_set_material(_malha.get_surface_count() - 1, _material(MAT_MARCA))


## Os bafos, como placas viradas para a camera.
##
## Viradas na CAMERA e nao no carro: fumaca e volume, e a unica forma de um
## quadrilatero passar por volume e nunca mostrar que e plano. Na epoca isso
## chamava sprite, e era como todo jogo de PS1 desenhava fogo, poeira e faisca.
func _superficie_fumaca() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var olho := camera.global_transform
	var dir := olho.basis.x
	var sobe := olho.basis.y
	# A normal e a propria frente da camera. Nao e enfeite: o `psx_fumaca` faz
	# uma conta de encaramento com ela, e malha sem normal chega no shader com
	# um vetor nulo — `normalize` de nulo e indefinido, e o NaN que sai dali
	# atravessa a multiplicacao por zero e apaga a fumaca inteira em algumas
	# placas de video e nao em outras. Escrita, a conta da 1 e some do caminho.
	var frente := -olho.basis.z

	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for k in BAFOS:
		var idade := _relogio - _bafo_nascido[k]
		if idade < 0.0 or idade > VIDA_BAFO:
			continue
		_vivos += 1
		var t := idade / VIDA_BAFO
		# Cresce depressa e para: fumaca de pneu abre no primeiro terco e depois
		# so dilui. Crescer linear ate o fim da a um balao inflando.
		var raio := lerpf(BAFO_NASCE, BAFO_MORRE, sqrt(t)) * 0.5
		var onde := _bafo_onde[k] + _bafo_vel[k] * idade * (1.0 - t * 0.55)
		# Nasce transparente, engrossa e some. O nascimento nao pode ser em
		# cheio: o bafo aparecendo do nada em cima do pneu e um estalo visual.
		var a := _bafo_tinta[k] * smoothstep(0.0, 0.14, t) * (1.0 - t) * 0.72
		var cor := Color(1.0, 1.0, 1.0, a)
		var base := v.size()
		v.append(onde - dir * raio - sobe * raio)
		v.append(onde + dir * raio - sobe * raio)
		v.append(onde + dir * raio + sobe * raio)
		v.append(onde - dir * raio + sobe * raio)
		uv.append(Vector2(0.0, 1.0))
		uv.append(Vector2(1.0, 1.0))
		uv.append(Vector2(1.0, 0.0))
		uv.append(Vector2(0.0, 0.0))
		for _j in 4:
			n.append(frente)
			c.append(cor)
		idx.append_array(PackedInt32Array([
			base, base + 1, base + 2, base, base + 2, base + 3]))
	if v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	_malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_malha.surface_set_material(_malha.get_surface_count() - 1, _material(MAT_FUMACA))


func _material(caminho: String) -> Material:
	if not ResourceLoader.exists(caminho):
		push_error("RastroPneu: material ausente em %s" % caminho)
		return null
	return load(caminho) as Material


# --- o que o teste le ---------------------------------------------------------

## Quantos pedacos de marca foram deixados desde que o carro foi assumido.
func marcas() -> int:
	return _marcados


## Quantos bafos de fumaca sairam.
func bafos() -> int:
	return _bafos_soltos


## Quantos pedacos ainda estao desenhados.
func marcas_vivas() -> int:
	var n := 0
	for k in PEDACOS:
		var idade := _relogio - _nascido[k]
		if idade >= 0.0 and idade <= VIDA:
			n += 1
	return n


## O que este no realmente tem montado. Existe porque "20 pedacos marcados" e
## uma contagem interna, e uma contagem interna nao prova que alguma coisa foi
## DESENHADA: entre contar e aparecer ha a superficie, o material, a
## transformada e o modo de mistura, e qualquer um dos quatro apaga o rastro
## sem um erro sequer.
func diagnostico() -> Dictionary:
	return {
		"superficies": _malha.get_surface_count(),
		"mat0": ("-" if _malha.get_surface_count() < 1
			else str(_malha.surface_get_material(0))),
		"vertices0": (0 if _malha.get_surface_count() < 1
			else _malha.surface_get_array_len(0)),
		"top_level": top_level,
		"origem": global_transform.origin,
		"visivel": is_visible_in_tree(),
		"vivos": marcas_vivas(),
	}


## O meio das marcas vivas, em coordenada de mundo. A captura mira nisto: o
## carro termina uma derrapagem longe de onde a comecou, e apontar a camera
## para o carro fotografa o lugar onde o rastro ACABA, que e a ponta dele.
func centro_das_marcas() -> Vector3:
	var soma := Vector3.ZERO
	var n := 0
	for k in PEDACOS:
		var idade := _relogio - _nascido[k]
		if idade < 0.0 or idade > VIDA:
			continue
		soma += _cantos[k * 4]
		n += 1
	return soma / float(n) if n > 0 else Vector3.ZERO


## Altura do pedaco mais novo acima de um ponto de referencia. O teste usa para
## provar que a marca encostou no CHAO, e nao ficou no ar debaixo do carro.
func altura_da_ultima() -> float:
	var k := (_proximo - 1 + PEDACOS) % PEDACOS
	if _nascido[k] < 0.0:
		return NAN
	return _cantos[k * 4].y
