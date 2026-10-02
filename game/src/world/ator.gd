## Personagem com nome, dirigido por roteiro. Hoje: o Berg.
##
## Jota, Helmer e o dono da casa continuam sendo `Convidado` (eles ja tem
## rotina, fumo e fala la dentro); a cena os acha por `Elenco.no` e usa
## `Convidado.estacionar/encarar/dizer` mais `Corpo.fazer_gesto`.
##
## Por que nao e Pedestre nem Convidado
## ------------------------------------
## Os dois tem cerebro proprio: o pedestre anda pela malha de rotas e o
## convidado circula pela sala (e o `_ir` dele nao avisa quando chega). Um personagem de cena precisa do contrario —
## ficar exatamente onde o roteiro mandou, andar ate o ponto que o roteiro
## disse, e AVISAR quando chegou, para o corte seguinte esperar por ele. Os
## verbos aqui sao todos `await`aveis por isso.
##
## Fora de cena ele tem um modo solto so: `vagar_em`, que e o Berg andando em
## volta da igreja ate o jogador falar com ele (roteiro 4B-NPC: vai ate a
## escadaria, olha a torre, fuma, encosta no carro).
##
## O corpo e o mesmo Corpo de todo mundo. A ficha vem do `Elenco`, e nao do
## registro civil sorteado: o Berg tem de ser o Berg em toda partida.
##
## Andar
## -----
## `move_and_slide` no plano, com giro suave e o Corpo animado pela rapidez de
## verdade (o passo casa com o chao). A altura vem de um raio para baixo, e nao
## de gravidade: a capsula comeca a 30 cm do chao, entao degrau de escadaria
## passa por baixo dela e o raio sobe o corpo — a escadaria da igreja (C7-07,
## "sobe dois degraus") sem controlador de degrau. Arranca e freia em rampa:
## parar seco na marca le como boneco.
class_name Ator
extends CharacterBody3D

## Velocidade de caminhada e de corrida, em m/s.
const VEL_ANDAR := 1.35
const VEL_CORRER := 3.4
## Arranque e freada, em m/s^2. Ate a velocidade de andar em meio segundo.
const ACELERACAO := 2.8
## Giro do corpo para a direcao do passo, em 1/s (fracao por segundo).
const GIRO := 7.0
## Chegou: a esta distancia do ponto, no plano.
const PERTO := 0.12
## Sem andar nem isto em PRESO_TEMPO segundos, desiste do ponto e avisa que
## chegou: cena que espera um personagem preso numa quina trava o jogo inteiro.
const PRESO_TEMPO := 1.6
const PRESO_MIN := 0.05
## O raio do chao: de onde comeca acima do pe e ate quanto sobe ou desce.
const RAIO_CHAO_CIMA := 0.6
const DEGRAU_MAX := 0.45
const QUEDA_MAX := 1.2
## Ate onde a mao do papel joga a folha, se ninguem disse onde (m a frente).
const PAPEL_LONGE := 1.4
## Alturas do carro que o Ator usa sem medida da carroceria: o capo (a mao
## passando) e a borda do paralama onde o quadril encosta.
const CAPO_Y := 0.80
const FOLGA_PORTA := 0.55

## O jogador apertou interagir perto dele, fora de cena.
signal interagido(quem: Node)
## Chegou no ponto de `andar_ate`.
signal chegou()
## O papel do telefone pousou no chao (ver `soltar_papel`).
signal papel_caiu(papel: BilheteNoAr)

## Quem e, pela chave do Elenco (&"berg").
var quem: StringName = &""
var ficha: Dictionary = {}
## Texto do prompt de interacao. Vazio desliga a interacao.
var rotulo: String = "":
	set(v):
		rotulo = v
		if _gatilho != null:
			_gatilho.rotulo = v
			_gatilho.habilitado = not v.is_empty()

var _corpo: Corpo
var _gatilho: Interativo
var _voz: Voz
var _fala: Fala
var _rng := RandomNumberGenerator.new()

# Andar
var _alvo := Vector3.INF
var _correr := false
var _vel := 0.0
var _giro_alvo := 0.0
var _t_preso := 0.0
var _ultima_pos := Vector3.ZERO
# Olhar
var _olhar_no: Node3D
var _t_olhada := 0.0
# Vagar
var _vagar_id := 0
var _vagando := false
# Carro
var _no_carro: Carro
## Posto por tween (entrando ou saindo do carro): nao anda nem assenta no chao.
var _conduzido := false
## A mao no capo: o carro em volta do qual ele anda (ver `contornar_carro`).
var _capo_de: Carro
# Objetos de mao
var _cigarro: Cigarro
var _chaveiro: MeshInstance3D
var _papel_na_mao: MeshInstance3D
var _papel: BilheteNoAr
## Para onde o proximo papel cai (o pe do jogador). INF: a frente do Ator.
var _destino_papel := Vector3.INF


func preparar(chave: StringName, nova_ficha: Dictionary) -> void:
	quem = chave
	ficha = nova_ficha


func _ready() -> void:
	add_to_group(&"elenco")
	add_to_group(&"npc")
	collision_layer = 1
	collision_mask = 1
	_rng.seed = int(ficha.get("id", 4100001))
	_corpo = Corpo.new()
	_corpo.name = "Corpo"
	# Rosto vivo (olho, palpebra, boca): ele e filmado em close.
	_corpo.com_rosto = true
	add_child(_corpo)
	_corpo.montar(ficha.get("aparencia", {}))
	_corpo.jeito = Jeito.de(ficha)
	_corpo.marca_do_gesto.connect(_ao_marcar)
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.26
	capsula.height = 1.25
	forma.shape = capsula
	forma.position = Vector3(0.0, 0.925, 0.0)
	add_child(forma)
	_gatilho = Interativo.new()
	_gatilho.name = "Gatilho"
	add_child(_gatilho)
	var area := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.0, 1.9, 1.0)
	area.shape = caixa
	area.position = Vector3(0.0, 0.95, 0.0)
	_gatilho.add_child(area)
	_gatilho.acionado.connect(func(q: Node) -> void: interagido.emit(q))
	rotulo = rotulo
	_voz = Voz.new()
	_voz.name = "Voz"
	add_child(_voz)
	_voz.configurar(ficha)
	_giro_alvo = rotation.y
	_ultima_pos = global_position


func corpo() -> Corpo:
	return _corpo


## Para a `Conversa`, o `Dialogo` e a `Escolha`: a voz dele, silaba a silaba.
func voz_da_fala() -> Voz:
	return _voz


# --- verbos de roteiro (todos com await) ------------------------------------

## Anda ate um ponto do mundo e gira para a direcao do passo. Retorna ao chegar.
func andar_ate(alvo: Vector3, correr: bool = false) -> void:
	_parar_vagar()
	await _andar(alvo, correr)


## Gira o corpo inteiro para olhar um ponto. Instantaneo (para posicionar no
## corte); `suave` gira no passo do corpo e nao espera (ver `virar_para`).
func encarar(ponto: Vector3, suave: bool = false) -> void:
	var d := ponto - global_position
	if Vector2(d.x, d.z).length() <= 0.01:
		return
	_giro_alvo = atan2(-d.x, -d.z)
	if not suave:
		rotation.y = _giro_alvo


## Gira no passo do corpo ate ficar de frente para o ponto. Retorna virado.
func virar_para(ponto: Vector3) -> void:
	encarar(ponto, true)
	var limite := 1.5
	while absf(angle_difference(rotation.y, _giro_alvo)) > 0.06 and limite > 0.0:
		await get_tree().physics_frame
		limite -= get_physics_process_delta_time()


## A cabeca acompanha um no (o jogador, quem fala). null solta.
func olhar_para(alvo: Node3D) -> void:
	_olhar_no = alvo
	_corpo.olhada_livre = alvo == null
	if alvo == null:
		_corpo.olhar_lateral(0.0)


## Toca um gesto do corpo e espera ele terminar. `alvo` e o ponto do mundo que
## a mao toca ou aponta (o adesivo, o lugar no calcamento); `lado` +1 e a
## direita (porta que abre para a direita, olhar por cima do ombro direito).
func fazer(g: Corpo.GestoCena, alvo: Vector3 = Vector3.INF, lado: float = 1.0) -> void:
	_parar_vagar()
	_corpo.alvo_do_gesto = alvo
	_corpo.lado_do_gesto = lado
	if g == Corpo.GestoCena.RIR:
		gargalhar()
	if g == Corpo.GestoCena.DESENCOSTAR:
		await _desencostar()
		return
	await _corpo.fazer_gesto(g)


## Desencosta do carro com um passo para longe dele enquanto empurra o paralama.
func _desencostar() -> void:
	_passo_curto(-global_transform.basis.z * 0.32,
		Corpo.duracao_do_gesto(Corpo.GestoCena.DESENCOSTAR) * 0.6)
	await _corpo.fazer_gesto(Corpo.GestoCena.DESENCOSTAR)


func postura(p: Corpo.Postura) -> void:
	_parar_vagar()
	_corpo.postura(p)


## Boca e cabeca de quem esta falando. A Escolha chama isto.
func falar(ativo: bool) -> void:
	_corpo.falar(ativo)


## Fala uma linha pela `Fala`: voz silaba a silaba e boca junto, sem caixa de
## dialogo (a caixa e da `Escolha`/`Dialogo`, que usam `voz_da_fala`).
func dizer(linha: String) -> void:
	if _fala == null:
		_fala = Fala.new()
		_fala.name = "Fala"
		add_child(_fala)
		_fala.voz = _voz
		_fala.cadencia = float(Personalidade.de(int(ficha.get("personalidade", 0)))["cadencia"])
	_fala.rosto = _corpo.rosto
	_fala.dizer(linha)


## A risada (o gesto e o som). `qual` escolhe o arquivo do banco (1 ou 2; 0
## sorteia): o roteiro pede `risada_m_1` no C4B-08 e `risada_m_2` no telefone.
func gargalhar(qual: int = 0) -> void:
	if not _corpo.rindo() and _corpo.gesto_de_cena() != Corpo.GestoCena.RIR:
		_corpo.rir(1.4)
	var banco := "f" if StringName(ficha.get("sexo", &"M")) == &"F" else "m"
	var n := qual if qual > 0 else 1 + _rng.randi() % 2
	var nome := StringName("risada_%s_%d" % [banco, n])
	if _voz == null or not AudioDirector.tem(nome):
		return
	var aparencia: Dictionary = ficha.get("aparencia", {})
	_voz.stream = AudioDirector.stream(nome)
	_voz.pitch_scale = clampf(float(aparencia.get("voz", 1.0)), 0.7, 1.5)
	_voz.volume_db = -9.0
	_voz.play()


## O loop de quem esta inquieto em pe: troca de perna, gira o chaveiro (C3-05).
func ouricado(ligado: bool) -> void:
	_corpo.ouricado = ligado
	if ligado:
		_montar_chaveiro()
	if _chaveiro != null:
		_chaveiro.visible = ligado


## Solta o papel com o telefone no chao a frente dele. Devolve o no do papel,
## que o jogador pode pegar (vira o item &"bilhete_berg" no inventario).
##
## Sai da mao (ou do peito, se a mao nao estiver no lugar) e cai em `para`: o pe
## do jogador, no C4B-03. Sem `para`, PAPEL_LONGE a frente. Dentro do gesto
## JOGAR_PAPEL quem chama isto e a marca "solta" — chamar de fora durante o
## gesto devolve o mesmo papel, nunca dois.
func soltar_papel(para: Vector3 = Vector3.INF) -> Node3D:
	if para.is_finite():
		_destino_papel = para
	if _papel != null and is_instance_valid(_papel) and not _papel.no_chao():
		return _papel
	if _papel_na_mao != null:
		_papel_na_mao.visible = false
	var de := _corpo.pega_no_mundo().origin if _corpo.esqueleto() != null \
		else global_position + Vector3.UP * 1.1
	var destino := _destino_papel
	if not destino.is_finite():
		destino = global_position - global_transform.basis.z * PAPEL_LONGE
	destino = _no_chao(destino)
	_papel = BilheteNoAr.new()
	_papel.name = "BilheteDoBerg"
	# No mundo, e nao no Ator: ele vai embora de carro e o papel fica.
	var mundo := get_parent() if get_parent() != null else self
	mundo.add_child(_papel)
	# A letra de frente para quem esta do lado do destino olhando para ele.
	var d := destino - global_position
	var giro := atan2(d.x, d.z) if Vector2(d.x, d.z).length() > 0.01 else rotation.y
	_papel.lancar(de, destino, giro)
	_papel.pousou.connect(func() -> void: papel_caiu.emit(_papel), CONNECT_ONE_SHOT)
	AudioDirector.tocar(&"papel", de, -10.0)
	_destino_papel = Vector3.INF
	return _papel


## Para onde o papel do proximo JOGAR_PAPEL cai.
func mirar_papel(para: Vector3) -> void:
	_destino_papel = para


## Anda devagar, parando e olhando em volta, dentro de um raio. Para quando o
## roteiro chama qualquer outro verbo.
##
## Com `ponto_alto` (a torre da capela) ele para e olha para cima; com `carro`
## vai encostar no paralama de vez em quando, e fuma — a rotina da igreja do
## roteiro (4B-NPC). Nao espera: volta na hora e a rotina segue sozinha.
func vagar_em(centro: Vector3, raio: float, ponto_alto: Vector3 = Vector3.INF,
		carro: Carro = null) -> void:
	_parar_vagar()
	_vagar_id += 1
	_vagando = true
	_rotina(_vagar_id, centro, raio, ponto_alto, carro)


func vagando() -> bool:
	return _vagando


## Vai ate a porta, abre, entra e senta. Retorna sentado e com a porta fechada.
## Depende do Carro (tarefa C) para porta e banco.
##
## A mao puxa a macaneta e a porta abre no mesmo quadro (marca "puxa"); o
## corpo abaixa e gira para o banco enquanto o Ator desliza ate ele, e o carro
## assume (`sentar_no_banco`) com o corpo ja no lugar; a mao de fora puxa a
## porta e ela fecha na marca "fecha".
func entrar_no_carro(c: Carro, banco: Carro.Banco) -> void:
	_parar_vagar()
	var porta := c.ponto_da_porta(banco)
	await _andar(porta.origin)
	var frente := porta.origin - porta.basis.z
	await virar_para(frente)
	var lado := -1.0 if banco == Carro.Banco.MOTORISTA else 1.0
	var abriu := [false]
	c.porta_abriu.connect(func(_b: Carro.Banco) -> void: abriu[0] = true, CONNECT_ONE_SHOT)
	var puxou := func(g: Corpo.GestoCena, m: StringName) -> void:
		if g == Corpo.GestoCena.ABRIR_PORTA and m == &"puxa":
			c.abrir_porta(banco)
	_corpo.marca_do_gesto.connect(puxou)
	_corpo.lado_do_gesto = lado
	_corpo.alvo_do_gesto = Vector3.INF
	await _corpo.fazer_gesto(Corpo.GestoCena.ABRIR_PORTA)
	_corpo.marca_do_gesto.disconnect(puxou)
	if not abriu[0]:
		await c.porta_abriu

	_fisica_de_carro(true)
	_corpo.sentar_como = Corpo.Postura.DIRIGINDO if banco == Carro.Banco.MOTORISTA \
		else Corpo.Postura.CARONA
	_corpo.altura_assento = 0.30
	var dur := Corpo.duracao_do_gesto(Corpo.GestoCena.ENTRAR_CARRO)
	var assento := _banco_no_mundo(c, banco)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position", assento.origin, dur * 0.75) \
		.set_delay(dur * 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var giro_final := rotation.y + angle_difference(rotation.y, assento.basis.get_euler().y)
	t.tween_property(self, "rotation:y", giro_final, dur * 0.7) \
		.set_delay(dur * 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _corpo.fazer_gesto(Corpo.GestoCena.ENTRAR_CARRO)
	if t.is_running():
		await t.finished
	_giro_alvo = rotation.y
	c.sentar_no_banco(self, banco)
	_no_carro = c
	# O carro de verdade poe a postura; o de mentira (stub da base) nao.
	if _corpo.postura_atual() != _corpo.sentar_como:
		_corpo.postura(_corpo.sentar_como)

	var fechou := [false]
	c.porta_fechou.connect(func(_b: Carro.Banco) -> void: fechou[0] = true, CONNECT_ONE_SHOT)
	var fecha := func(g: Corpo.GestoCena, m: StringName) -> void:
		if g == Corpo.GestoCena.FECHAR_PORTA and m == &"fecha":
			c.fechar_porta(banco)
	_corpo.marca_do_gesto.connect(fecha)
	_corpo.lado_do_gesto = lado
	await _corpo.fazer_gesto(Corpo.GestoCena.FECHAR_PORTA)
	_corpo.marca_do_gesto.disconnect(fecha)
	if not fechou[0]:
		await c.porta_fechou


## O contrario de `entrar_no_carro`. Retorna de pe, do lado de fora, de frente
## para o carro e com a porta fechada.
func sair_do_carro(c: Carro, banco: Carro.Banco) -> void:
	_parar_vagar()
	var porta := c.ponto_da_porta(banco)
	await c.abrir_porta(banco)
	var dur := Corpo.duracao_do_gesto(Corpo.GestoCena.SAIR_CARRO)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "global_position", porta.origin, dur * 0.7) \
		.set_delay(dur * 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var giro_final := rotation.y + angle_difference(rotation.y, porta.basis.get_euler().y + PI)
	t.tween_property(self, "rotation:y", giro_final, dur * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _corpo.fazer_gesto(Corpo.GestoCena.SAIR_CARRO)
	if t.is_running():
		await t.finished
	c.levantar_do_banco(banco)
	_no_carro = null
	visible = true
	_fisica_de_carro(false)
	global_position = _no_chao(porta.origin)
	# Vira para o carro e empurra a porta.
	encarar(porta.origin - porta.basis.z)
	var fechou := [false]
	c.porta_fechou.connect(func(_b: Carro.Banco) -> void: fechou[0] = true, CONNECT_ONE_SHOT)
	var fecha := func(g: Corpo.GestoCena, m: StringName) -> void:
		if g == Corpo.GestoCena.FECHAR_PORTA and m == &"fecha":
			c.fechar_porta(banco)
	_corpo.marca_do_gesto.connect(fecha)
	_corpo.lado_do_gesto = -1.0 if banco == Carro.Banco.MOTORISTA else 1.0
	_corpo.alvo_do_gesto = Vector3.INF
	await _corpo.fazer_gesto(Corpo.GestoCena.FECHAR_PORTA)
	_corpo.marca_do_gesto.disconnect(fecha)
	if not fechou[0]:
		await c.porta_fechou


## Da a volta pela frente do carro ate a porta do banco, com a mao passando no
## capo (C4A-02, C4B-04). Retorna parado na porta, de frente para ela.
func contornar_carro(c: Carro, banco: Carro.Banco) -> void:
	_parar_vagar()
	var m := c.medidas()
	var meia_l := float(m.get("comprimento", 4.3)) * 0.5
	var meia_w := float(m.get("largura", 1.7)) * 0.5
	var local := c.global_transform.affine_inverse() * global_position
	var lado_carro := signf(local.x) if absf(local.x) > 0.01 else 1.0
	var destino := -1.0 if banco == Carro.Banco.MOTORISTA else 1.0
	var pontos: Array[Vector3] = []
	if signf(destino) != lado_carro:
		# Do paralama de um lado ao do outro, rente ao para-choque.
		pontos.append(Vector3(lado_carro * (meia_w + 0.40), 0.0, -meia_l + 0.35))
		pontos.append(Vector3(lado_carro * meia_w * 0.55, 0.0, -meia_l - 0.42))
		pontos.append(Vector3(-lado_carro * meia_w * 0.55, 0.0, -meia_l - 0.42))
		pontos.append(Vector3(-lado_carro * (meia_w + 0.40), 0.0, -meia_l + 0.35))
	var porta := c.ponto_da_porta(banco)
	# A mao do lado do carro: andando pela frente com o carro a direita, e a
	# direita. Quem vem do lado direito (x > 0) anda para -x e o carro fica a
	# esquerda.
	_corpo.lado_do_gesto = -lado_carro
	_capo_de = c
	var tempo := 0.0
	var antes := global_position
	for p: Vector3 in pontos:
		var w := c.global_transform * p
		tempo += antes.distance_to(w) / VEL_ANDAR
		antes = w
	if not pontos.is_empty():
		_corpo.alvo_do_gesto = _ponto_no_capo(c)
		_corpo.fazer_gesto(Corpo.GestoCena.MAO_NO_CAPO, tempo + 0.5)
	for p: Vector3 in pontos:
		await _andar(c.global_transform * p)
	_capo_de = null
	await _andar(porta.origin)
	await virar_para(porta.origin - porta.basis.z)


## Vai encostar no paralama dianteiro do lado `lado` (+1 direita do carro) e
## fica de bracos cruzados (Postura.ENCOSTADO_CARRO). Retorna encostado.
func encostar_no_carro(c: Carro, lado: float = 1.0) -> void:
	_parar_vagar()
	await _encostar(c, lado)


## Acende um cigarro na mao direita: ele vai a boca sozinho na tragada (em pe
## FUMANDO, encostado no carro ou na parede).
func acender_cigarro() -> void:
	if _cigarro != null and is_instance_valid(_cigarro):
		return
	var semente := int(ficha.get("id", 1))
	_corpo.fumo = Tragada.new(semente)
	_cigarro = Cigarro.new()
	_cigarro.name = "Cigarro"
	add_child(_cigarro)
	_cigarro.montar(_corpo, semente)


func fumando() -> bool:
	return _cigarro != null and is_instance_valid(_cigarro)


## Joga a bituca no chao (C3-03): o cigarro sai da mao e cai a meio metro, e
## fica la.
func jogar_bituca() -> void:
	if not fumando():
		return
	_corpo.fumo = null
	var de := _cigarro.global_transform
	var mundo := get_parent() if get_parent() != null else self
	_cigarro.reparent(mundo)
	# Solta da mao: o cigarro livre segue o pai e queima sozinho no chao.
	_cigarro.corpo = null
	_cigarro.livre = true
	_cigarro.global_transform = de
	var chao := _no_chao(global_position - global_transform.basis.z * 0.5
		+ global_transform.basis.x * 0.25) + Vector3.UP * 0.006
	var t := _cigarro.create_tween().set_parallel(true)
	t.tween_property(_cigarro, "global_position", chao, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_cigarro, "rotation", Vector3(0.0, rotation.y + 1.1, PI * 0.5), 0.45)
	var bituca := _cigarro
	_cigarro = null
	get_tree().create_timer(40.0).timeout.connect(func() -> void:
		if is_instance_valid(bituca):
			bituca.queue_free())


# --- por dentro ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _conduzido or (_no_carro != null and is_instance_valid(_no_carro)):
		_corpo.animar(0.0, delta)
		_seguir_olhar(delta)
		return
	_no_carro = null
	var v_alvo := 0.0
	var dir := Vector3.ZERO
	if _alvo.is_finite():
		var d := _alvo - global_position
		d.y = 0.0
		var dist := d.length()
		if dist <= PERTO:
			_chegar()
		else:
			dir = d / dist
			_giro_alvo = atan2(-dir.x, -dir.z)
			v_alvo = VEL_CORRER if _correr else VEL_ANDAR
			# Freia chegando: velocidade que para em PERTO com a mesma rampa.
			v_alvo = minf(v_alvo, sqrt(2.0 * ACELERACAO * maxf(dist - PERTO * 0.5, 0.0)) + 0.15)
			# Nao anda de lado: so acelera quando ja esta mais ou menos virado.
			var desvio := absf(angle_difference(rotation.y, _giro_alvo))
			v_alvo *= clampf(1.4 - desvio, 0.0, 1.0)
	_vel = move_toward(_vel, v_alvo, ACELERACAO * delta)
	var frente := -global_transform.basis.z
	if dir != Vector3.ZERO:
		# Anda na direcao do alvo, e nao da frente: a frente ainda esta girando.
		frente = dir
	velocity = Vector3(frente.x, 0.0, frente.z) * _vel
	if _vel > 0.001:
		move_and_slide()
	_assentar_no_chao()
	rotation.y = lerp_angle(rotation.y, _giro_alvo, 1.0 - exp(-GIRO * delta))
	var andou := Vector2(global_position.x - _ultima_pos.x,
		global_position.z - _ultima_pos.z).length()
	_ultima_pos = global_position
	_corpo.animar(andou / maxf(delta, 0.0001), delta)
	if _alvo.is_finite():
		_vigiar_preso(andou, delta)
	if _capo_de != null and is_instance_valid(_capo_de):
		_corpo.alvo_do_gesto = _ponto_no_capo(_capo_de)
	_seguir_olhar(delta)
	_seguir_mao()


func _process(_delta: float) -> void:
	_seguir_mao()


func _andar(alvo: Vector3, correr: bool = false) -> void:
	_alvo = alvo
	_correr = correr
	_t_preso = 0.0
	# Quem estava sentado ou encostado levanta antes de andar.
	var p := _corpo.postura_atual()
	if p != Corpo.Postura.LIVRE and _no_carro == null:
		_corpo.postura(Corpo.Postura.LIVRE)
	await chegou


func _chegar() -> void:
	_alvo = Vector3.INF
	_t_preso = 0.0
	chegou.emit()


func _vigiar_preso(andou: float, delta: float) -> void:
	if andou >= PRESO_MIN * delta:
		_t_preso = 0.0
		return
	if _vel < VEL_ANDAR * 0.5:
		return
	_t_preso += delta
	if _t_preso >= PRESO_TEMPO:
		push_warning("Ator %s preso a caminho de %s" % [quem, _alvo])
		_chegar()


## O chao embaixo do pe, por raio. Sobe degrau ate DEGRAU_MAX e desce ate
## QUEDA_MAX; fora disso (sem chao carregado) fica onde esta.
func _assentar_no_chao() -> void:
	var y := _altura_do_chao(global_position)
	if not is_nan(y):
		global_position.y = y


func _altura_do_chao(p: Vector3) -> float:
	if not is_inside_tree():
		return NAN
	var espaco := get_world_3d().direct_space_state
	var de := p + Vector3.UP * RAIO_CHAO_CIMA
	var para := p + Vector3.DOWN * QUEDA_MAX
	var q := PhysicsRayQueryParameters3D.create(de, para, 1, [get_rid()])
	var hit := espaco.intersect_ray(q)
	if hit.is_empty():
		return NAN
	var y := float((hit["position"] as Vector3).y)
	if y - p.y > DEGRAU_MAX:
		return NAN
	return y


func _no_chao(p: Vector3) -> Vector3:
	var y := _altura_do_chao(p)
	return Vector3(p.x, p.y if is_nan(y) else y, p.z)


## Um passo curto sem animar caminhada: o desencostar, o recuo de susto.
func _passo_curto(desloca: Vector3, dur: float) -> void:
	var t := create_tween()
	t.tween_property(self, "global_position", global_position + Vector3(desloca.x, 0.0, desloca.z), dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _seguir_olhar(delta: float) -> void:
	if _olhar_no != null and not is_instance_valid(_olhar_no):
		_olhar_no = null
		_corpo.olhada_livre = true
	if _olhar_no != null:
		_corpo.olhar_para(_olhos_de(_olhar_no))
		return
	if _corpo.ouricado and _alvo == Vector3.INF:
		# Ouricado olha em volta: rua, porta, rua — a cada dois segundos e meio.
		_t_olhada -= delta
		if _t_olhada <= 0.0:
			_t_olhada = _rng.randf_range(1.8, 3.2)
			_corpo.olhar_lateral(_rng.randf_range(-0.9, 0.9), _rng.randf_range(-0.1, 0.05))


## Os olhos de quem ele olha: a camera, se for uma, ou a cabeca do corpo.
static func _olhos_de(n: Node3D) -> Vector3:
	if n is Camera3D:
		return n.global_position
	if n.has_method("corpo"):
		var c := n.call("corpo") as Corpo
		if c != null:
			return c.global_position + Vector3.UP * c.altura_da_boca()
	return n.global_position + Vector3.UP * 1.55


## Chaveiro e papel seguem a pega da mao direita.
func _seguir_mao() -> void:
	if _corpo == null or _corpo.esqueleto() == null:
		return
	var vivo := (_chaveiro != null and _chaveiro.visible) \
		or (_papel_na_mao != null and _papel_na_mao.visible)
	if not vivo:
		return
	var pega := _corpo.pega_no_mundo()
	if _chaveiro != null and _chaveiro.visible:
		# Pendurado no dedo, rodando em volta dele: o chaveiro gira na
		# frequencia da mao (ver `Corpo._ouricado_na_carga`).
		var t := Time.get_ticks_msec() * 0.001
		var giro := floorf(t * 15.0) / 15.0 * 17.0
		_chaveiro.global_transform = Transform3D(
			pega.basis * Basis(Vector3.RIGHT, giro), pega.origin)
	if _papel_na_mao != null and _papel_na_mao.visible:
		_papel_na_mao.global_transform = Transform3D(pega.basis, pega.origin
			+ pega.basis * Vector3(0.0, -0.035, -0.02))


## O que cada gesto faz fora do corpo: som, papel, objeto na mao.
func _ao_marcar(g: Corpo.GestoCena, marca: StringName) -> void:
	match g:
		Corpo.GestoCena.JOGAR_PAPEL:
			if marca == &"pega":
				_montar_papel_na_mao()
				_papel_na_mao.visible = true
				AudioDirector.tocar(&"papel", global_position + Vector3.UP * 1.2, -12.0)
			elif marca == &"solta":
				soltar_papel()
		Corpo.GestoCena.BATER_NO_VIDRO:
			if marca == &"bate":
				# O no do dedo no vidro: o clique da interface, grave.
				AudioDirector.tocar(&"clique", _corpo.pega_no_mundo().origin, -2.0, 0.55)
		Corpo.GestoCena.MEXER_NO_RADIO:
			if marca == &"clique":
				AudioDirector.tocar(&"radio_click", _corpo.pega_no_mundo().origin, -6.0)


func _montar_papel_na_mao() -> void:
	if _papel_na_mao != null:
		return
	_papel_na_mao = MeshInstance3D.new()
	_papel_na_mao.name = "PapelNaMao"
	var quad := QuadMesh.new()
	# Dobrado em quatro na mao: metade da folha que cai.
	quad.size = BilheteNoAr.TAMANHO * 0.55
	_papel_na_mao.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/psx_surface.gdshader")
	mat.set_shader_parameter(&"tint", BilheteNoAr.COR_PAPEL)
	mat.set_shader_parameter(&"use_affine", false)
	mat.set_shader_parameter(&"cull_off", true)
	_papel_na_mao.material_override = mat
	_papel_na_mao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_papel_na_mao.visible = false
	add_child(_papel_na_mao)


## Argola e duas chaves, em caixas: cinco centimetros de metal que brilham
## quando giram na luz do poste. Nasce so quando ele fica ouricado.
func _montar_chaveiro() -> void:
	if _chaveiro != null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_caixa(st, Vector3(0.004, 0.024, 0.024), Vector3(0.0, -0.012, 0.0), Color(0.62, 0.62, 0.60))
	_caixa(st, Vector3(0.003, 0.046, 0.012), Vector3(0.0, -0.045, 0.006), Color(0.78, 0.72, 0.52))
	_caixa(st, Vector3(0.003, 0.040, 0.011), Vector3(0.0, -0.040, -0.008), Color(0.70, 0.70, 0.68))
	# O chaveiro de borracha preta da Fiat.
	_caixa(st, Vector3(0.010, 0.030, 0.020), Vector3(0.0, -0.032, 0.0), Color(0.08, 0.08, 0.09))
	st.generate_normals()
	_chaveiro = MeshInstance3D.new()
	_chaveiro.name = "Chaveiro"
	_chaveiro.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/psx_surface.gdshader")
	mat.set_shader_parameter(&"use_affine", false)
	_chaveiro.material_override = mat
	_chaveiro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_chaveiro)


static func _caixa(st: SurfaceTool, tam: Vector3, centro: Vector3, cor: Color) -> void:
	var m := tam * 0.5
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var c := centro + n * m
		var du := u * m
		var dv := v * m
		var a := c - du - dv
		var b := c + du - dv
		var cc := c + du + dv
		var d := c - du + dv
		st.set_color(cor)
		for p: Vector3 in [a, b, cc, a, cc, d]:
			st.add_vertex(p)


func _fisica_de_carro(dentro: bool) -> void:
	# Dentro do carro a capsula brigaria com a lataria e o raio do chao acharia o
	# banco: os dois saem, e o Ator e posto pelo tween e depois pelo carro.
	collision_layer = 0 if dentro else 1
	collision_mask = 0 if dentro else 1
	_conduzido = dentro
	_alvo = Vector3.INF
	_vel = 0.0
	_ultima_pos = global_position


## Onde o Ator fica sentado no banco, no mundo: a mesma conta de `Carro.sentar`
## (banco das medidas, quadril `QUADRIL_SOBRE_BANCO` acima da almofada), olhando
## para a frente do carro. O carona e o espelho do motorista.
func _banco_no_mundo(c: Carro, banco: Carro.Banco) -> Transform3D:
	var m := c.medidas()
	var largura := float(m.get("largura", 1.7))
	var comprimento := float(m.get("comprimento", 4.3))
	var b: Vector3 = m.get("banco_motorista",
		Vector3(-largura * 0.24, 0.46, -comprimento * 0.04))
	if banco == Carro.Banco.PASSAGEIRO:
		b.x = -b.x
	var local := Vector3(b.x, b.y - 0.30 - 0.05 + Carro.QUADRIL_SOBRE_BANCO, b.z)
	return Transform3D(c.global_transform.basis.orthonormalized(), c.global_transform * local)


## O ponto da borda do capo mais perto do Ator, a altura do capo.
func _ponto_no_capo(c: Carro) -> Vector3:
	var m := c.medidas()
	var meia_l := float(m.get("comprimento", 4.3)) * 0.5
	var meia_w := float(m.get("largura", 1.7)) * 0.5
	var local := c.global_transform.affine_inverse() * global_position
	var x := clampf(local.x, -meia_w + 0.12, meia_w - 0.12)
	var z := clampf(local.z, -meia_l + 0.12, -meia_l + 0.95)
	return c.global_transform * Vector3(x, CAPO_Y, z)


func _encostar(c: Carro, lado: float) -> void:
	var m := c.medidas()
	var meia_l := float(m.get("comprimento", 4.3)) * 0.5
	var meia_w := float(m.get("largura", 1.7)) * 0.5
	var s := 1.0 if lado >= 0.0 else -1.0
	var ponto := c.global_transform * Vector3(s * (meia_w + 0.28), 0.0, -meia_l + 0.75)
	await _andar(ponto)
	# De costas para o carro: olhando para fora, na direcao do lado.
	var fora := c.global_transform.basis.x * s
	await virar_para(global_position + fora)
	_corpo.postura(Corpo.Postura.ENCOSTADO_CARRO)


func _parar_vagar() -> void:
	if not _vagando:
		return
	_vagar_id += 1
	_vagando = false
	_alvo = Vector3.INF
	var p := _corpo.postura_atual()
	if p == Corpo.Postura.FUMANDO:
		_corpo.postura(Corpo.Postura.LIVRE)


## A rotina solta (roteiro 4B-NPC): anda a um ponto do raio, para, e faz uma
## coisa — olha a torre, fuma, olha em volta, encosta no carro. A ordem e
## sorteada pela semente da ficha, e nao repete a mesma coisa duas vezes.
func _rotina(id: int, centro: Vector3, raio: float, ponto_alto: Vector3, carro: Carro) -> void:
	var ultima := -1
	while id == _vagar_id and is_inside_tree():
		var opcoes: Array[int] = [0, 1, 2]
		if ponto_alto.is_finite():
			opcoes.append(3)
		if carro != null and is_instance_valid(carro):
			opcoes.append(4)
		opcoes.erase(ultima)
		var qual: int = opcoes[_rng.randi() % opcoes.size()]
		ultima = qual
		if qual == 4:
			await _encostar(carro, 1.0)
			if id != _vagar_id:
				return
			acender_cigarro()
			if not await _esperar(id, _rng.randf_range(10.0, 16.0)):
				return
			await _desencostar()
			continue
		var ang := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * raio
		var p := centro + Vector3(cos(ang), 0.0, sin(ang)) * r
		if qual == 3:
			# Para ao pe do que vai olhar: o ponto alto visto de perto, o mais
			# perto dele que a area deixa.
			var base := Vector3(ponto_alto.x, centro.y, ponto_alto.z)
			p = centro + (base - centro).limit_length(raio * 0.8) \
				+ Vector3(cos(ang), 0.0, sin(ang)) * raio * 0.15
		await _andar(p)
		if id != _vagar_id:
			return
		match qual:
			0:
				# Parado, olhando em volta.
				_corpo.reagir(ReacaoCorpo.OCIO_OLHAR)
				if not await _esperar(id, _rng.randf_range(3.0, 5.0)):
					return
			1:
				# Fuma em pe.
				acender_cigarro()
				_corpo.postura(Corpo.Postura.FUMANDO)
				if not await _esperar(id, _rng.randf_range(9.0, 14.0)):
					return
				_corpo.postura(Corpo.Postura.LIVRE)
			2:
				_corpo.reagir(ReacaoCorpo.OCIO_BOLSO)
				if not await _esperar(id, _rng.randf_range(4.0, 6.0)):
					return
			3:
				_corpo.olhar_para(ponto_alto)
				if not await _esperar(id, _rng.randf_range(4.0, 6.5)):
					return
				_corpo.olhar_lateral(0.0)


## Espera `s` segundos se a rotina `id` ainda for a da vez. Falso: foi parada.
func _esperar(id: int, s: float) -> bool:
	var falta := s
	while falta > 0.0:
		await get_tree().create_timer(0.25).timeout
		falta -= 0.25
		if id != _vagar_id or not is_inside_tree():
			return false
	return true
