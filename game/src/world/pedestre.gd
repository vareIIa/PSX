## Uma pessoa andando na rua.
##
## Tres decisoes que definem o resto do arquivo:
##
## 1. Ele nao cai. A altura sai de um raio para baixo, e nao de gravidade com
##    colisao no pe. A calcada tem quinze centimetros de guia e um pedestre
##    atravessa isso a cada quarteirao; com capsula encostando no chao, o degrau
##    trava a pessoa e ela fica empurrando o meio-fio pelo resto da vida. Com o
##    raio, ela sobe e desce a guia sem nem saber que ela existe.
##
## 2. Ele nao e um Area3D. A base Interativo do projeto e area, mas gente
##    precisa de corpo — sem corpo o jogador atravessa as pessoas, e atravessar
##    gente estraga tudo que elas constroem. Entao o corpo e este no e a area de
##    interacao e um filho, na classe interna Gatilho.
##
## 3. Ele nao decide para onde ir. Quem decide e Rotas, lendo a malha da cidade;
##    aqui so ha "andar ate o ponto, virar o corpo, escolher a proxima esquina".
##    Foi de proposito: navegacao dentro do NPC vira dez copias da mesma regra
##    quando aparece o segundo tipo de gente que anda.
class_name Pedestre
extends CharacterBody3D

## Velocidade base. A do jogador andando e 2,4 — pedestre mais lento de
## proposito, para dar para alcancar quem passou.
const VELOCIDADE := 1.15
const GIRO := 3.4
## Distancia para considerar a esquina alcancada.
const CHEGOU := 0.9

## A que distancia ele nota o jogador e olha de lado, sem parar de andar.
const DISTANCIA_OLHAR := 3.6

## Espaco pessoal. Mais perto que isto, o pedestre para de avancar CONTRA quem
## esta na frente — continua andando de lado, mas nao entra na pessoa.
##
## Nao e educacao, e fisica. Dois CharacterBody3D sobrepostos sao separados pela
## recuperacao de penetracao do motor, e ela empurra OS DOIS: um pedestre que
## insiste em andar para dentro do jogador o arrasta pela calcada alguns metros
## por minuto. Isso apareceu como falha do teste da casa — o jogador saia do
## interior e, tres segundos depois, estava onze metros do lugar onde entrou,
## sem ter tocado em tecla nenhuma.
const ESPACO_PESSOAL := 1.15

## Largura do corredor de quem vem andando. E a soma das duas capsulas (0,32 do
## jogador e 0,26 daqui) mais quatro centimetros de folga: fora disso os dois
## corpos passam um pelo outro sem se tocar, e nao ha nada de que sair.
const CORREDOR := 0.62
## Com quantos segundos de antecedencia ele sai da frente de quem vem.
##
## Meio segundo e curto de proposito. A versao anterior reagia por DISTANCIA
## — 1,15 m mais um terco da rapidez de quem vinha, o que dava quase dois
## metros com o jogador andando — e a qualquer coisa que entrasse nesse circulo,
## inclusive alguem passando de raspao pelo lado. O resultado na tela era a rua
## inteira se afastando de voce como se voce empurrasse todo mundo.
const ANTECEDENCIA := 0.5
## Distancia em que as duas capsulas ja estao encostadas.
const CONTATO := 0.62
## Teto do passo de lado, em m/s. O desvio dura o tempo de um passo e some; nao
## e para arrancar ninguem do lugar.
const FUGA_MAXIMA := 1.05

const ALTURA_CAPSULA := 1.25
## Fundo da capsula acima do chao. E o que deixa a guia passar por baixo.
const PISO_CAPSULA := 0.3

enum Estado { ANDANDO, PAUSA, SOCIAL, ATENDENDO, SUSTO }


## Area de interacao. Existe so para responder a tecla e devolver o rotulo; toda
## a decisao continua no Pedestre, que e quem sabe o que esta acontecendo.
class Gatilho extends Interativo:
	var dono: Pedestre

	func rotulo_atual() -> String:
		if dono == null or Conversa.ativo:
			return ""
		return "Falar com %s" % FalasNpc.rotulo(dono.ficha)

	func interagir(quem: Node) -> void:
		if dono != null:
			dono.abordar(quem)


var ficha: Dictionary = {}

var _corpo: Corpo
var _voz: Voz
var _gatilho: Gatilho
var _jogador: Node3D

var _no := Vector4i.ZERO
var _destino := Vector4i.ZERO
var _alvo := Vector3.ZERO
var _desvio: float = 0.0
var _estado: Estado = Estado.ANDANDO
var _espera: float = 0.0
var _giro_alvo: float = 0.0
var _velocidade: float = VELOCIDADE
var _parceiro: Pedestre
var _murmurio: float = 0.0
var _y_suave: float = 0.0
## A altura suave comeca na posicao do PRIMEIRO quadro de fisica, e nao na do
## `_ready`: quem monta o pedestre poe a posicao depois de entrar na arvore
## (Multidao._nascer), e no `_ready` ele ainda esta na origem. No morro
## (Relevo) a calcada fica 26 m abaixo dela, e a suavizacao partindo de zero
## puxava o corpo para o alto, fora do alcance do raio de chao — e ele
## ficava ali flutuando para sempre.
var _y_pronto := false
var _sem_chao: float = 0.0
## Quanto tempo faz que ele nao sai do lugar, andando. Ver _destravar.
## Direcao do pulo de susto, no plano.
var _fuga := Vector3.ZERO
var _emperrado: float = 0.0
var _amostra: float = 0.0
var _onde_estava := Vector3.ZERO
## Janela de medicao de travamento, em segundos, e quanto se espera andar nela.
## Meio segundo a um metro por segundo da meio metro; um quarto disso ja conta
## como progresso, o que deixa espaco para desvio e para subir a guia.
const JANELA_TRAVAMENTO := 0.5
const PASSO_MINIMO := 0.13

## Vida total e tempo total emperrado, em segundos.
##
## A razao entre os dois e a unica medida honesta de "a multidao trava". Contar
## quantos estao parados AGORA nao serve: parar e comportamento, e uma foto de
## tres segundos nao distingue quem descansa de quem esta preso num poste. A
## fracao ao longo da vida distingue.
var _vivo_total: float = 0.0
var _travado_total: float = 0.0


## Chamado antes de entrar na arvore. A ficha define o corpo inteiro, entao ela
## nao pode chegar depois da montagem.
##
## `de` e `para` sao o trecho de calcada em que a pessoa esta. Quem nasce no meio
## do quarteirao ja nasce indo para algum lugar; sem isso ela pararia no ponto de
## nascimento e so entao escolheria destino, o que le como gente aparecendo do
## nada e pensando.
func preparar(nova_ficha: Dictionary, de: Vector4i, para: Vector4i) -> void:
	ficha = nova_ficha
	_no = de
	_destino = para


func _ready() -> void:
	add_to_group(&"pedestre")
	add_to_group(&"npc")
	collision_layer = 1
	collision_mask = 1
	# Sem isso o pedestre escorrega pelas rampas de colisao do cenario como se
	# fosse gelo; ele nao usa piso, mas o motor ainda resolve o deslizamento.
	floor_max_angle = deg_to_rad(60.0)

	var aparencia: Dictionary = ficha.get("aparencia", {})
	var p := Personalidade.de(int(ficha.get("personalidade", 0)))
	_velocidade = VELOCIDADE * float(aparencia.get("passo", 1.0)) * float(p["andar"])
	# Posicao dentro da faixa, de -1 a 1. A LARGURA da faixa nao e decidida aqui:
	# vem da via em que a pessoa esta andando, porque a calcada da avenida tem
	# tres metros e a da viela tem um e meio. Ver Rotas.folga_lateral.
	_desvio = float(absi(int(ficha.get("id", 0))) % 9) / 4.0 - 1.0

	_montar_corpo()
	_montar_colisao()
	_montar_gatilho()

	_y_suave = global_position.y
	_mirar()


func _montar_corpo() -> void:
	_corpo = Corpo.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	_corpo.montar(ficha.get("aparencia", {}))


func _montar_colisao() -> void:
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.26
	capsula.height = ALTURA_CAPSULA
	forma.shape = capsula
	forma.position = Vector3(0.0, PISO_CAPSULA + ALTURA_CAPSULA * 0.5, 0.0)
	add_child(forma)


func _montar_gatilho() -> void:
	_gatilho = Gatilho.new()
	_gatilho.name = "Gatilho"
	_gatilho.dono = self
	add_child(_gatilho)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	# Larga e alta: o raio de mira sai da camera e o jogador nao deve precisar
	# acertar o torso de alguem que esta andando.
	caixa.size = Vector3(1.0, 1.9, 1.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.95, 0.0)
	_gatilho.add_child(forma)


# --- navegacao --------------------------------------------------------------

func _escolher_destino() -> void:
	var vizinhos := Rotas.vizinhos(_destino)
	var origem := _no
	_no = _destino

	# Peso: seguir em frente vale muito mais que atravessar, e voltar por onde
	# veio quase nao vale. Com peso igual o pedestre fica dancando na esquina, o
	# que e engracado uma vez e denuncia o sistema na segunda.
	var pesos := [7.0, 5.0, 2.0, 1.6]
	var melhor := _no
	var soma := 0.0
	var sorteio := float(absi(int(ficha.get("id", 1)) * 7919
		+ int(Time.get_ticks_msec() / 97)) % 1000) / 1000.0
	var total := 0.0
	for k in vizinhos.size():
		if vizinhos[k] == _no or vizinhos[k] == origem:
			continue
		if not Rotas.aresta_caminhavel(_no, k):
			continue
		total += (pesos[k] * Rotas.movimento(vizinhos[k])
			* Rotas.atrativo_da_aresta(_no, k))
	if total <= 0.0:
		# Beco sem saida: volta por onde veio, que e o que uma pessoa faria.
		_destino = origem if origem != _no else vizinhos[2]
		_mirar()
		return
	var corte := sorteio * total
	for k in vizinhos.size():
		if vizinhos[k] == _no or vizinhos[k] == origem:
			continue
		if not Rotas.aresta_caminhavel(_no, k):
			continue
		soma += (pesos[k] * Rotas.movimento(vizinhos[k])
			* Rotas.atrativo_da_aresta(_no, k))
		if soma >= corte:
			melhor = vizinhos[k]
			break
	_destino = melhor
	_mirar()


## Recalcula o ponto de chegada, com o desvio lateral da pessoa.
##
## Desvio lateral: cada um anda na sua linha dentro da calcada, senao todo mundo
## caminha em fila indiana pelo mesmo pixel e a rua vira desfile.
func _mirar() -> void:
	var reta := Rotas.ponto(_destino) - Rotas.ponto(_no)
	if reta.length_squared() < 0.01:
		_alvo = Rotas.ponto(_destino)
		return
	var lado := Vector3(-reta.z, 0.0, reta.x).normalized()
	# A folga sai da via do trecho, e nao de uma constante. Ver Rotas.
	var k := 1 if _destino.x == _no.x else 0
	_alvo = Rotas.ponto(_destino) + lado * _desvio * Rotas.folga_da_aresta(_no, k)


func _physics_process(delta: float) -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D

	match _estado:
		Estado.ANDANDO:
			_andar(delta)
		Estado.PAUSA:
			_espera -= delta
			velocity = _sair_da_frente()
			if _espera <= 0.0:
				_estado = Estado.ANDANDO
		Estado.SOCIAL:
			_conversar_com_parceiro(delta)
		Estado.ATENDENDO:
			velocity = Vector3.ZERO
			if _jogador != null:
				_encarar(_jogador.global_position)
		Estado.SUSTO:
			_recuar(delta)

	move_and_slide()
	_assentar(delta)
	_destravar(delta)
	_girar(delta)
	_animar(delta)


## Escolhe outro caminho quando o atual nao anda.
##
## Numa cidade gerada nao da para provar que nenhum poste, banco ou canto de
## muro forma uma armadilha para uma capsula de 26 cm: sao milhares de
## combinacoes e nenhuma delas foi desenhada a mao. Em vez de tentar garantir que
## a armadilha nao existe, a pessoa percebe que esta parada ha um segundo e meio
## e vai por outro lugar — que e o que alguem faria.
func _destravar(delta: float) -> void:
	_vivo_total += delta
	if _estado != Estado.ANDANDO:
		_emperrado = 0.0
		_amostra = 0.0
		_onde_estava = global_position
		return

	# A medida e por JANELA, e nao por quadro. A primeira versao comparava a
	# posicao de agora com a da ultima vez que ela mudou mais de 12 cm — e a 1,15
	# m/s um quadro anda 1,9 cm, entao cinco de cada seis quadros contavam como
	# emperrado. Todo mundo que andava normalmente acumulava travamento e a
	# multidao aposentava sete pessoas por minuto sem nenhuma delas estar presa.
	_amostra += delta
	if _amostra < JANELA_TRAVAMENTO:
		return
	var andou := global_position.distance_to(_onde_estava)
	_onde_estava = global_position
	_amostra = 0.0
	if andou > PASSO_MINIMO:
		_emperrado = 0.0
		return
	_emperrado += JANELA_TRAVAMENTO
	_travado_total += JANELA_TRAVAMENTO
	if _emperrado < 1.5:
		return
	_emperrado = 0.0
	_escolher_destino()


func _andar(delta: float) -> void:
	var para_o_alvo := _alvo - global_position
	para_o_alvo.y = 0.0
	if para_o_alvo.length() < CHEGOU:
		_escolher_destino()
		# Uma parada de vez em quando. Gente que anda sem nunca parar le como
		# esteira rolante; a pausa e o que faz a rua parecer habitada.
		if absi(int(ficha.get("id", 0)) + _no.x * 31 + _no.y * 17) % 5 == 0:
			_estado = Estado.PAUSA
			_espera = 1.8 + float(absi(_no.x * 13 + _no.y) % 40) * 0.1
			return
		para_o_alvo = _alvo - global_position
		para_o_alvo.y = 0.0

	var direcao := para_o_alvo.normalized()
	direcao = _desviar(direcao)
	# O passo de lado se SOMA ao caminho, e nao substitui: quem esta andando e
	# alcancado por quem corre precisa das duas coisas ao mesmo tempo.
	var fuga := _sair_da_frente()
	velocity.x = direcao.x * _velocidade + fuga.x
	velocity.z = direcao.z * _velocidade + fuga.z
	velocity.y = 0.0
	if direcao.length_squared() > 0.01:
		_giro_alvo = atan2(-direcao.x, -direcao.z)


## Passo de lado para o jogador passar, valido em qualquer estado.
##
## Quem esta descansando na esquina ou conversando com outra pessoa tambem sai da
## frente — gente faz isso. E aqui isso nao e so educacao: dois CharacterBody3D
## sobrepostos sao separados pela recuperacao de penetracao do motor, que empurra
## OS DOIS. Um pedestre parado no meio da calcada empurra o JOGADOR de lado
## enquanto ele anda, e foi assim que a verificacao de movimento acusou 1,4 m de
## deriva num controlador que anda reto.
##
## O gatilho e o CORREDOR de quem vem, e nao um circulo em volta dele.
##
## Circulo era a primeira versao: raio de 1,15 m mais um terco da rapidez, o que
## com o jogador andando dava 1,9 m. So que passar A UM METRO DO LADO de alguem
## e o caso normal da calcada — nem encosta — e todo mundo dentro do circulo
## levava o empurrao de 2,4 m/s assim mesmo. Na tela isso le como se o jogador
## tivesse um campo de forca: as duas pessoas que estavam conversando se abrem
## quando voce passa atras delas.
##
## Aqui o desvio so acontece quando os dois corpos VAO se tocar: o pedestre
## precisa estar dentro do corredor da caminhada (a largura das duas capsulas) e
## a meio segundo de contato. Quem passa de lado nao e tocado.
func _sair_da_frente() -> Vector3:
	if _jogador == null:
		return Vector3.ZERO
	var para_mim := global_position - _jogador.global_position
	para_mim.y = 0.0
	var d := para_mim.length()
	if d < 0.01:
		return Vector3.ZERO
	var normal := para_mim / d

	# Encostados: separa na marra, e so o quanto falta para descolar. Este e o
	# termo que impede o par de capsulas de ficar se empurrando em circulo, e
	# vale mesmo com o jogador parado — parado em cima de alguem tambem afunda.
	if d < CONTATO:
		return normal * FUGA_MAXIMA * (1.0 - d / CONTATO)

	var corpo := _jogador as CharacterBody3D
	if corpo == null:
		return Vector3.ZERO
	var passo := Vector3(corpo.velocity.x, 0.0, corpo.velocity.z)
	var rapidez := passo.length()
	# Jogador parado ou quase: nao ha rota para sair da frente de.
	if rapidez < 0.25:
		return Vector3.ZERO
	var rumo := passo / rapidez

	# Quanto falta ao longo da caminhada, e o quanto ele erra de lado.
	var avanco := para_mim.dot(rumo)
	var alcance := CONTATO + rapidez * ANTECEDENCIA
	if avanco <= 0.0 or avanco > alcance:
		return Vector3.ZERO
	var desvio := para_mim - rumo * avanco
	var lateral := desvio.length()
	if lateral > CORREDOR:
		return Vector3.ZERO

	# Sai PARA O LADO da caminhada, nunca para longe na linha dela: de lado sao
	# trinta centimetros e acabou, enquanto na linha a pessoa vira um carrinho
	# empurrado pelo jogador pelo resto do quarteirao.
	var lado := Vector3.ZERO
	if lateral > 0.05:
		lado = desvio / lateral
	else:
		# De frente exata nao ha lado nenhum na geometria: o lado sai do id, que e
		# estavel. Sorteado por quadro, a pessoa treme no lugar em vez de desviar.
		var giro := 1.0 if int(ficha.get("id", 0)) % 2 == 0 else -1.0
		lado = Vector3(-rumo.z, 0.0, rumo.x) * giro
	# A pressa cresce quando o contato esta perto, e nao com a rapidez de quem
	# vem: o que assusta e a proximidade.
	var pressa := 1.0 - avanco / alcance
	return lado * minf(FUGA_MAXIMA, VELOCIDADE * 0.9 * pressa + 0.25)


## Contorna quem estiver na frente: o jogador e os outros pedestres.
##
## Tira da direcao a componente que aponta para dentro do outro e acrescenta um
## empurrao lateral. O que sobra e movimento de lado, entao a pessoa CONTORNA em
## vez de parar seca — parar seco a um metro le como boneco travado.
##
## O empurrao lateral nao e enfeite: sem ele, dois pedestres que se encontram de
## frente ficam ambos com velocidade zero e travam um contra o outro para
## sempre. Com ele, cada um sai por um lado. O lado sai do id, entao os dois
## escolhem lados opostos de forma estavel em vez de dancarem.
##
## Contra o jogador isto tem uma segunda funcao, maior: dois CharacterBody3D
## sobrepostos sao separados pela recuperacao de penetracao do motor, e ela
## empurra OS DOIS. Um pedestre insistindo em andar para dentro do jogador o
## arrasta calcada afora — foi assim que o teste da casa achou o jogador onze
## metros longe de onde tinha entrado, sem ninguem tocar em tecla.
func _desviar(direcao: Vector3) -> Vector3:
	var saida := direcao
	if _jogador != null:
		saida = _contornar(saida, _jogador.global_position, ESPACO_PESSOAL)
	# Em rede, o amigo tambem e gente na calcada: sem isto o pedestre desta
	# maquina atravessa o boneco dele (plano multiplayer 06 secao 5). Sozinho,
	# `corpos()` so tem o jogador, que ja foi contornado acima.
	if Sessao.em_rede():
		for c: Node3D in Sessao.corpos():
			if c != _jogador:
				saida = _contornar(saida, c.global_position, ESPACO_PESSOAL)
	for outro: Node in get_tree().get_nodes_in_group(&"pedestre"):
		if outro == self or not is_instance_valid(outro):
			continue
		var p := outro as Node3D
		# Corta cedo pelo quadrado da distancia: sao dez pessoas na rua e este
		# laco roda por quadro de fisica para cada uma delas.
		if p.global_position.distance_squared_to(global_position) > 0.9:
			continue
		# Entre pedestres a folga e bem menor que com o jogador. Na calcada de
		# verdade as pessoas se cruzam a meio metro; com a folga cheia, nove
		# pessoas num quarteirao passam o tempo todo desviando umas das outras e
		# a rua anda menos de meio metro por segundo.
		saida = _contornar(saida, p.global_position, ESPACO_PESSOAL * 0.62)
	return saida


func _contornar(direcao: Vector3, alvo: Vector3, folga: float) -> Vector3:
	var para_ele := alvo - global_position
	para_ele.y = 0.0
	var d := para_ele.length()
	if d > folga or d < 0.01:
		return direcao
	var normal := para_ele / d
	var avanco := direcao.dot(normal)
	if avanco <= 0.0:
		return direcao
	# O lado sai SEMPRE do mesmo giro de noventa graus sobre a normal, e nunca
	# de sorteio por pessoa. E o que faz os dois passarem um pelo outro.
	#
	# Para A, a normal aponta para B; para B, aponta para A — ou seja, ao
	# contrario. Girando as duas do mesmo jeito, os desvios saem em sentidos
	# OPOSTOS no mundo e cada um sai por um lado, que e o que gente faz na
	# calcada. A primeira versao invertia o lado conforme a paridade do id, e com
	# isso metade dos pares escolhia o MESMO lado do mundo, batia de novo, e os
	# dois travavam ali para sempre. Foi o que o teste viu como pedestre imovel
	# sem estar em pausa.
	var lado := Vector3(-normal.z, 0.0, normal.x)
	var desviada := direcao - normal * avanco + lado * avanco * 0.9
	return desviada.normalized() * direcao.length() if desviada.length() > 0.01 else Vector3.ZERO


## Altura pelo chao, e nao por gravidade. Ver o cabecalho do arquivo.
func _assentar(delta: float) -> void:
	var espaco := get_world_3d().direct_space_state
	var de := global_position + Vector3.UP * 1.4
	var para := global_position + Vector3.DOWN * 2.0
	var consulta := PhysicsRayQueryParameters3D.create(de, para, 1)
	consulta.exclude = [get_rid()]
	if not _y_pronto:
		_y_suave = global_position.y
		_y_pronto = true
	var achado := espaco.intersect_ray(consulta)
	if achado.is_empty():
		# Sem chao embaixo: o chunk ainda nao materializou. Segurar a altura por
		# um tempo e melhor que despencar — a alternativa vista em teste foi o
		# pedestre sumindo por baixo da cidade enquanto ela carregava.
		_sem_chao += delta
		return
	_sem_chao = 0.0
	var y: float = (achado["position"] as Vector3).y
	# Suaviza a subida da guia. Instantaneo, o corpo pula quinze centimetros num
	# quadro e a cabeca da um salto que se ve de longe.
	_y_suave = lerpf(_y_suave, y, minf(1.0, 12.0 * delta))
	global_position.y = _y_suave


func _girar(delta: float) -> void:
	var d := angle_difference(rotation.y, _giro_alvo)
	rotation.y += clampf(d, -GIRO * delta, GIRO * delta)


func _encarar(ponto: Vector3) -> void:
	var d := ponto - global_position
	d.y = 0.0
	if d.length_squared() > 0.01:
		_giro_alvo = atan2(-d.x, -d.z)


func _animar(delta: float) -> void:
	if _corpo == null:
		return
	var rapidez := Vector2(velocity.x, velocity.z).length()
	_corpo.animar(rapidez, delta)

	# A cabeca acompanha quem esta perto. E o detalhe mais barato que existe
	# para uma multidao deixar de ser cenario: alguem reparou em voce.
	var olhar := 0.0
	var alvo_do_olhar: Node3D = _parceiro if _estado == Estado.SOCIAL else _jogador
	if _estado == Estado.ATENDENDO:
		alvo_do_olhar = _jogador
	if alvo_do_olhar != null:
		var d := alvo_do_olhar.global_position - global_position
		d.y = 0.0
		if d.length() < DISTANCIA_OLHAR or _estado != Estado.ANDANDO:
			olhar = -angle_difference(rotation.y, atan2(-d.x, -d.z))
	_corpo.olhar_lateral(olhar)


# --- convivio ---------------------------------------------------------------

## Para e conversa com outro pedestre. Quem casa os dois e a Multidao, que ja
## percorre a lista inteira: cada um procurando o proprio par seria a mesma
## varredura repetida uma vez por pessoa.
func iniciar_conversa(outro: Pedestre, duracao: float) -> void:
	if _estado == Estado.ATENDENDO:
		return
	_parceiro = outro
	_estado = Estado.SOCIAL
	_espera = duracao
	_murmurio = 0.4
	velocity = Vector3.ZERO


func _conversar_com_parceiro(delta: float) -> void:
	velocity = _sair_da_frente()
	_espera -= delta
	if _parceiro == null or not is_instance_valid(_parceiro) or _espera <= 0.0:
		_parceiro = null
		_estado = Estado.ANDANDO
		if _corpo != null:
			_corpo.falar(false)
		return
	_encarar(_parceiro.global_position)

	# Reveza: enquanto um murmura o outro fica quieto. Dois falando ao mesmo
	# tempo soa como radio fora de estacao, nao como conversa.
	_murmurio -= delta
	if _murmurio <= 0.0:
		var minha_vez := (int(_espera * 0.5) % 2 == 0) == (int(ficha.get("id", 0)) % 2 == 0)
		if minha_vez:
			dizer("murmurio curto de rua")
			if _corpo != null:
				_corpo.falar(true)
		elif _corpo != null:
			_corpo.falar(false)
		_murmurio = 1.4 + float(absi(int(ficha.get("id", 0))) % 7) * 0.2


## Ha quantos segundos ele esta na rua.
func vivo_ha() -> float:
	return _vivo_total


## Fracao da vida que ele passou andando sem sair do lugar, de 0 a 1.
func fracao_travada() -> float:
	return _travado_total / maxf(0.5, _vivo_total)


## Nome do estado atual. Para o overlay de depuracao e para a verificacao poder
## dizer POR QUE alguem nao andou, em vez de so acusar que nao andou.
func estado_nome() -> StringName:
	match _estado:
		Estado.ANDANDO:
			return &"andando"
		Estado.PAUSA:
			return &"pausa"
		Estado.SOCIAL:
			return &"social"
		Estado.SUSTO:
			return &"susto"
		_:
			return &"atendendo"


## Com quem esta conversando agora, ou null. A verificacao usa para saber se uma
## conversa de rua acabou mesmo, e nao se a pessoa entrou em outra.
func parceiro() -> Pedestre:
	return _parceiro


func esta_livre() -> bool:
	return _estado == Estado.ANDANDO or _estado == Estado.PAUSA


## Interrompe descanso ou conversa de rua e volta a andar.
##
## Existe para a verificacao. "Alguem andou nos ultimos tres segundos" e uma
## afirmacao que depende de ninguem estar parado por motivo legitimo, e ha dois:
## a pausa de descanso, que dura de 1,8 a 5,8 segundos, e a conversa entre
## pedestres, que dura de 7 a 16. Com dois pedestres na rua, isso reprovava o
## jogo por coincidencia com frequencia alta.
##
## Nao mexe em ATENDENDO: quem esta falando com o jogador continua falando.
# --- susto ------------------------------------------------------------------

## Quanto tempo dura o recuo, e quantas vezes a velocidade normal ele tem.
const SUSTO_DURACAO := 1.15
const SUSTO_IMPULSO := 2.6


## Alguem passou perto demais.
##
## O pedido e "pessoas se assustam caso passe perto delas e quase atropela", e
## o que vende isso nao e a animacao — e o corpo saindo do lugar. Uma pessoa que
## so vira a cabeca enquanto um carro passa a meio metro le como boneco. Aqui
## ela pula PARA LONGE da coisa que passou, olha para ela, e so depois volta a
## andar.
##
## O recuo e na direcao oposta ao carro, projetada no plano: pular na diagonal
## para cima do meio-fio jogaria metade das pessoas na parede.
func assustar(de_onde: Vector3, forca: float) -> void:
	if _estado == Estado.ATENDENDO or Conversa.ativo and Conversa.quem() == self:
		return
	if _estado == Estado.SUSTO:
		# Ja esta assustado; so renova o tempo, senao um carro passando devagar
		# reinicia o pulo a cada quadro e a pessoa desliza pela calcada.
		_espera = maxf(_espera, SUSTO_DURACAO * 0.6)
		return
	var fuga := global_position - de_onde
	fuga.y = 0.0
	if fuga.length() < 0.05:
		fuga = -global_transform.basis.z
	_fuga = fuga.normalized() * clampf(forca, 0.3, 1.0)
	_estado = Estado.SUSTO
	_espera = SUSTO_DURACAO
	_encarar(de_onde)
	if _voz != null:
		_voz.dizer("Eh!")
	if _parceiro != null and is_instance_valid(_parceiro):
		_parceiro = null


func _recuar(delta: float) -> void:
	_espera -= delta
	# O impulso morre ao longo do susto: o primeiro terco e o pulo, o resto e a
	# pessoa parada olhando o carro se afastar.
	var t := clampf(_espera / SUSTO_DURACAO, 0.0, 1.0)
	var empurrao := _fuga * _velocidade * SUSTO_IMPULSO * pow(t, 2.2)
	velocity = Vector3(empurrao.x, velocity.y, empurrao.z)
	if _espera <= 0.0:
		_estado = Estado.ANDANDO
		_mirar()


func acordar() -> void:
	if _estado == Estado.PAUSA or _estado == Estado.SOCIAL:
		_estado = Estado.ANDANDO
		_espera = 0.0
		_parceiro = null
		if _corpo != null:
			_corpo.falar(false)


# --- conversa com o jogador -------------------------------------------------

func abordar(quem: Node) -> void:
	if Conversa.ativo or Dialogo.ativo:
		return
	_estado = Estado.ATENDENDO
	_parceiro = null
	velocity = Vector3.ZERO
	if quem is Node3D:
		_encarar((quem as Node3D).global_position)
	RegistroCivil.conhecer(int(ficha.get("id", -1)))
	Conversa.abrir(self, ficha)
	Conversa.fechou.connect(_ao_encerrar, CONNECT_ONE_SHOT)


func _ao_encerrar() -> void:
	if _corpo != null:
		_corpo.falar(false)
	if _voz != null:
		_voz.parar()
	_estado = Estado.PAUSA
	# Fica parado um instante depois da conversa antes de seguir. Sair andando no
	# quadro seguinte a ultima fala entrega que aquilo era uma maquina de estado.
	_espera = 1.5


## Murmura uma linha. O texto nao e falado — so o tamanho e a pontuacao dele
## chegam na voz. Ver src/systems/voz.gd.
func dizer(linha: String) -> void:
	if _voz == null:
		_voz = Voz.new()
		_voz.name = "Voz"
		add_child(_voz)
		_voz.configurar(ficha)
		_voz.position = Vector3(0.0, _corpo.altura_da_boca() if _corpo != null else 1.5, 0.0)
	_voz.dizer(linha)
	if _corpo != null:
		_corpo.falar(true)


func triangulos() -> int:
	return _corpo.triangulos() if _corpo != null else 0
