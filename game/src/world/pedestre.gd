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

enum Estado { ANDANDO, PAUSA, SOCIAL, ATENDENDO, SUSTO, TROPECANDO, CAIDO }

## Corpo que bate em corpo: quanto da velocidade de quem esbarra vira empurrao
## (ver `_sentir_esbarrao`). Massas em kg; a do jogador e a da capsula dele com
## roupa e mochila.
const MASSA := 70.0
const MASSA_JOGADOR := 78.0
## Abaixo disto (m/s de aproximacao) e encostar, e o desvio de sempre resolve.
const ESBARRAO_MINIMO := 1.3
## Um esbarrao por pessoa a cada tanto: encostado andando, o contato dura varios
## quadros e cada um seria um empurrao novo.
const ESPERA_ESBARRAO := 0.8
## Carro: ate que rapidez e empurrao (tropeca ou cai de pe) em vez de atropelo
## (boneco de pano).
const CARRO_EMPURRA := 3.4
## Altura do para-choque, onde o golpe do carro entra cheio.
const PARA_CHOQUE := 0.5


## Area de interacao. Existe so para responder a tecla e devolver o rotulo; toda
## a decisao continua no Pedestre, que e quem sabe o que esta acontecendo.
class Gatilho extends Interativo:
	var dono: Pedestre

	func rotulo_atual() -> String:
		if dono == null or Conversa.ativo or not dono.de_pe():
			return ""
		return "Falar com %s" % FalasNpc.rotulo(dono.ficha)

	func interagir(quem: Node) -> void:
		if dono != null:
			dono.abordar(quem)


var ficha: Dictionary = {}

var _corpo: Corpo
var _voz: Voz
## A fala curta da rua (grito, gemido, papo com o parceiro): boca e voz na
## mesma silaba. Criada no primeiro uso.
var _fala: Fala
## Tempo ate o proximo gemido no chao, e quanto ainda manca depois de levantar.
var _t_gemido := 1.2
var _t_manca := 0.0
## Quem a testemunha esta olhando (o atropelado no chao), e por quanto tempo.
var _olhando: Node3D
var _t_olhando := 0.0
var _gatilho: Gatilho
var _jogador: Node3D

var _no := Vector4i.ZERO
var _destino := Vector4i.ZERO
## A travessia da perna atual, se ela atravessa rua de carro: espera o boneco
## ou a brecha na esquina (PLANO_TRANSITO_AAA, Passo 3; ver TravessiaDePedestre).
var _travessia: TravessiaDePedestre
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

## Tropeco e tombo (ver `Equilibrio` e `BonecoDePano`).
var _equilibrio: Equilibrio
var _boneco: BonecoDePano
var _desde_esbarrao: float = 9.0
## De onde veio o empurrao ou o carro: e para la que a pessoa olha depois.
var _de_onde := Vector3.ZERO


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
	# O jeito da pessoa: como anda, fica parada e mexe as maos (ver `Jeito`).
	_corpo.jeito = Jeito.de(ficha)


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
	_travessia = TravessiaDePedestre.trocar(_travessia, self, _no, _destino)
	var reta := Rotas.ponto(_destino) - Rotas.ponto(_no)
	if reta.length_squared() < 0.01:
		_alvo = Rotas.ponto(_destino)
		return
	var lado := Vector3(-reta.z, 0.0, reta.x).normalized()
	# A folga sai da via do trecho, e nao de uma constante. Ver Rotas.
	var k := 1 if _destino.x == _no.x else 0
	_alvo = Rotas.ponto(_destino) + lado * _desvio * Rotas.folga_da_aresta(_no, k)
	if _travessia != null:
		_alvo = _travessia.alvo(_alvo)


## `--medir-pedestre`: o pior passo de fisica de um pedestre na rodada, com a
## etapa que pesou, o estado e a idade dele. Lido pela bancada de direcao.
static var medir := OS.get_cmdline_user_args().has("--medir-pedestre")
static var pior_passo := {"ms": 0.0}
## Todo `move_and_slide` acima de 5 ms, com o que ele tocou (ate 20).
static var lentos: Array = []
var _t_etapa := 0
var _etapas_ms := {}


func _etapa(nome: StringName) -> void:
	var agora := Time.get_ticks_usec()
	_etapas_ms[nome] = float(agora - _t_etapa) / 1000.0
	_t_etapa = agora


func _physics_process(delta: float) -> void:
	if not medir:
		_passo_de_fisica(delta)
		return
	var t0 := Time.get_ticks_usec()
	var estado_antes := estado_nome()
	_etapas_ms.clear()
	_t_etapa = t0
	_passo_de_fisica(delta)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	if ms > float(pior_passo["ms"]):
		pior_passo = {"ms": ms, "estado": "%s->%s" % [estado_antes, estado_nome()],
			"idade": _vivo_total, "etapas": _etapas_ms.duplicate(), "nome": name}


func _passo_de_fisica(delta: float) -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D

	if _estado == Estado.CAIDO:
		_seguir_o_corpo()
		_gemer(delta)
		_animar(delta)
		if medir:
			_etapa(&"caido")
		return
	_desde_esbarrao += delta
	if _t_manca > 0.0:
		_t_manca -= delta
		if _corpo != null:
			# Os ultimos quatro segundos desmancham o mancar aos poucos.
			_corpo.mancando = minf(_corpo.mancando, clampf(_t_manca / 4.0, 0.0, 1.0))
	_sentir_carros(delta)
	if medir:
		_etapa(&"sentir_carros")
	_sentir_esbarrao()
	if medir:
		_etapa(&"sentir_esbarrao")
	if _estado == Estado.CAIDO:
		return

	match _estado:
		Estado.ANDANDO:
			_andar(delta)
			if _t_manca > 0.0 and _corpo != null:
				velocity *= 1.0 - 0.45 * _corpo.mancando
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
		Estado.TROPECANDO:
			_tropecar(delta)
			if _estado == Estado.CAIDO:
				return

	if medir:
		_etapa(&"estado")
	move_and_slide()
	if medir:
		_etapa(&"move_and_slide")
		if float(_etapas_ms[&"move_and_slide"]) > 5.0 and lentos.size() < 20:
			var tocou := PackedStringArray()
			for k in get_slide_collision_count():
				var col := get_slide_collision(k).get_collider()
				tocou.append(col.get_class() + ":" + String((col as Node).name) if col is Node else str(col))
			var coord := ChunkManager.coord_de(global_position)
			lentos.append({"ms": snappedf(float(_etapas_ms[&"move_and_slide"]), 0.1),
				"idade": snappedf(_vivo_total, 0.01), "tocou": tocou,
				"chunk": coord, "passos_do_chunk": ChunkManager.passos_desde_carga(coord),
				"vel": snappedf(velocity.length(), 0.01)})
	_assentar(delta)
	if medir:
		_etapa(&"assentar")
	_destravar(delta)
	_girar(delta)
	_animar(delta)
	if medir:
		_etapa(&"animar")


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
	# No meio da travessia, trocar de rota e sair em diagonal pelo asfalto, sem
	# travessia nenhuma que o carro enxergue: la ela continua contornando o que a
	# trava, e so desiste depois de muito.
	var paciencia := 12.0 if _travessia != null and not _travessia.esperando() else 1.5
	if _emperrado < paciencia:
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

	# Travessia: espera na esquina (o boneco, a brecha) olhando para o outro
	# lado; atravessando, aperta o passo se o tempo nao da.
	var ritmo := 1.0 if _travessia == null else _travessia.passo(delta)
	if ritmo <= 0.0:
		_estado = Estado.PAUSA
		_espera = 0.2
		velocity.x = 0.0
		velocity.z = 0.0
		_encarar(_alvo)
		return
	if _travessia != null:
		para_o_alvo = _travessia.alvo_agora(_alvo) - global_position
		para_o_alvo.y = 0.0
	var direcao := para_o_alvo.normalized()
	direcao = _desviar(direcao)
	# O passo de lado se SOMA ao caminho, e nao substitui: quem esta andando e
	# alcancado por quem corre precisa das duas coisas ao mesmo tempo.
	var fuga := _sair_da_frente()
	velocity.x = direcao.x * _velocidade * ritmo + fuga.x
	velocity.z = direcao.z * _velocidade * ritmo + fuga.z
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
	# Tropecando ninguem vira o corpo: o passo sai para o lado do empurrao e o
	# corpo vai de costas, de lado, como cair.
	if _estado == Estado.TROPECANDO:
		return
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
	if _estado == Estado.TROPECANDO and _equilibrio != null:
		_corpo.inclinacao = _equilibrio.inclinacao_local(rotation.y)
		_corpo.debater = _equilibrio.debater()
		if _equilibrio.dando_passo():
			_corpo.rumo_passo = _equilibrio.rumo_do_passo(rotation.y)
	elif _corpo.inclinacao != Vector2.ZERO or _corpo.debater > 0.0:
		_corpo.inclinacao = Vector2.ZERO
		_corpo.debater = 0.0
		_corpo.rumo_passo = 0.0
	_corpo.animar(rapidez, delta)

	if _t_olhando > 0.0:
		_t_olhando -= delta
		if is_instance_valid(_olhando):
			var alvo := _olhando.global_position + Vector3.UP * 0.25
			var caido := _olhando as Pedestre
			if caido != null and caido.de_pe():
				alvo = _olhando.global_position + Vector3.UP * 1.5
			_corpo.olhar_para(alvo)
			return
		_t_olhando = 0.0

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
	if _estado == Estado.ATENDENDO or not de_pe():
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
			_falar_curto(FalasTombo.papo(int(ficha.get("id", 0))), true)
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
		Estado.TROPECANDO:
			return &"tropecando"
		Estado.CAIDO:
			return &"caido"
		_:
			return &"atendendo"


## Com quem esta conversando agora, ou null. A verificacao usa para saber se uma
## conversa de rua acabou mesmo, e nao se a pessoa entrou em outra.
func parceiro() -> Pedestre:
	return _parceiro


func esta_livre() -> bool:
	# No meio da travessia ninguem para para conversar: a Multidao juntava dois
	# que se cruzavam na zebra, e eles ficavam de papo no meio da rua.
	if _travessia != null and not _travessia.esperando():
		return false
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
	if not de_pe():
		return
	# O reflexo e do temperamento. O bebado nao ve o carro chegando; o sonhador
	# e o melancolico veem tarde. Sem isso a rua inteira desviava de tudo com o
	# mesmo reflexo de dublê, e atropelo era coisa que so acontecia na calcada.
	var reflexo := _reflexo()
	if reflexo < 0.0:
		return
	if reflexo > 0.0 and _estado != Estado.SUSTO:
		get_tree().create_timer(reflexo).timeout.connect(func() -> void:
			if is_instance_valid(self) and de_pe() and _estado != Estado.SUSTO:
				_pular_de_susto(de_onde, forca))
		return
	_pular_de_susto(de_onde, forca)


## Segundos ate reagir a um susto; negativo e nao reagir.
func _reflexo() -> float:
	match int(ficha.get("personalidade", 0)):
		5:  # BEBADO
			return -1.0
		3, 10:  # MELANCOLICO, SONHADOR
			return 0.35
		_:
			return 0.0


## Para no lugar por `segundos` (cena roteirizada, e a regua que precisa de
## alguem parado na faixa).
func esperar_parado(segundos: float) -> void:
	if not de_pe():
		return
	_estado = Estado.PAUSA
	_espera = segundos
	velocity = Vector3.ZERO


func _pular_de_susto(de_onde: Vector3, forca: float) -> void:
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
	# A voz nasce aqui se ainda nao existia: quem nunca tinha falado assustava
	# mudo.
	_falar_curto("[medo]Eh!", false)
	# O corpo se protege no pulo: os bracos na frente do rosto, e nao so a
	# pessoa escorregando para tras de braco pendurado.
	if _corpo != null:
		_corpo.reagir(ReacaoCorpo.REACAO_PROTEGE)
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
		_depois_do_susto()


## Passado o susto, o temperamento fala: quem enfrenta sacode o punho para o
## carro que ja foi embora; o resto so resmunga.
func _depois_do_susto() -> void:
	if _corpo == null:
		return
	var p := int(ficha.get("personalidade", 0))
	if FalasTombo.depois(p) == FalasTombo.Depois.ENFRENTA:
		_corpo.reagir(ReacaoCorpo.REACAO_XINGA)
		_gritar(["Olha o carro!", "Ta maluco?!", "Vai devagar!"][absi(int(ficha.get("id", 0))) % 3], true)


func acordar() -> void:
	if _estado == Estado.PAUSA or _estado == Estado.SOCIAL:
		_estado = Estado.ANDANDO
		_espera = 0.0
		_parceiro = null
		if _corpo != null:
			_corpo.falar(false)


# --- conversa com o jogador -------------------------------------------------

func abordar(quem: Node) -> void:
	if Conversa.ativo or Dialogo.ativo or not de_pe():
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


## O corpo no mundo, para a `Conversa` gesticular com ele.
func corpo() -> Corpo:
	return _corpo


## A voz desta pessoa, criada no primeiro uso (a `Fala` conduz o ritmo).
func voz_da_fala() -> Voz:
	if _voz == null:
		_voz = Voz.new()
		_voz.name = "Voz"
		add_child(_voz)
		_voz.configurar(ficha)
		_voz.position = Vector3(0.0, _corpo.altura_da_boca() if _corpo != null else 1.5, 0.0)
	return _voz


func triangulos() -> int:
	return _corpo.triangulos() if _corpo != null else 0


# --- tropeco e tombo --------------------------------------------------------
#
# O GTA IV em duas camadas (ver `Equilibrio` e `BonecoDePano`): esbarrao e
# carro devagar fazem a pessoa cambalear, com passo e braco no ar, e ela se
# recupera ou cai; carro rapido derruba na hora. Caida, a pessoa e boneco de
# pano ate levantar sozinha, e o que ela faz depois e do temperamento.

## Esta de pe e no controle do proprio corpo (nem tropecando, nem no chao).
func de_pe() -> bool:
	return _estado != Estado.CAIDO and _estado != Estado.TROPECANDO


func caido() -> bool:
	return _estado == Estado.CAIDO


## Empurrao: `dv` e a velocidade que o centro de massa ganha (m/s). Pequeno
## balanca, medio tropeca, grande derruba — quem decide e o `Equilibrio`.
func empurrar(dv: Vector3, de_onde: Vector3) -> void:
	if _estado == Estado.CAIDO or _corpo == null:
		return
	if Conversa.ativo and Conversa.quem() == self:
		return
	dv.y = 0.0
	if _equilibrio == null:
		_equilibrio = Equilibrio.new(_corpo.altura())
	_equilibrio.empurrar(dv)
	_de_onde = de_onde
	if _estado != Estado.TROPECANDO:
		_estado = Estado.TROPECANDO
		_parceiro = null
		_corpo.falar(false)
		if _corpo.rosto != null:
			_corpo.rosto.reagir(Rosto.Expressao.SURPRESA, 0.9)
		if dv.length() > 0.5:
			_gritar(FalasTombo.esbarrao(int(ficha.get("personalidade", 0)),
				int(ficha.get("id", 0))), true)


## Quem tropeca se segura em quem estiver do lado: a mao vai ao ombro do
## outro, e o outro leva um tanto do empurrao — balanca, ou tropeca tambem.
## E o "grab" do Euphoria, e a cadeia de gente se segurando que o IV mostra
## numa calcada cheia.
const ALCANCE_AGARRAR := 1.3
var _agarrado: Node3D


func _procurar_onde_agarrar() -> void:
	if _agarrado != null and is_instance_valid(_agarrado):
		return
	var melhor: Node3D = null
	var perto := ALCANCE_AGARRAR
	var candidatos: Array = get_tree().get_nodes_in_group(&"pedestre")
	if _jogador != null:
		candidatos.append(_jogador)
	for n: Node in candidatos:
		var outro := n as Node3D
		if outro == null or outro == self or not is_instance_valid(outro):
			continue
		var ped := outro as Pedestre
		if ped != null and ped.caido():
			continue
		var d := outro.global_position.distance_to(global_position)
		if d < perto:
			perto = d
			melhor = outro
	if melhor == null:
		return
	_agarrado = melhor
	var ped := melhor as Pedestre
	if ped != null and ped.de_pe() and _equilibrio != null:
		# O outro leva um terco do que sobrou do empurrao, na direcao de quem
		# se segurou nele.
		var puxao := (global_position - melhor.global_position)
		puxao.y = 0.0
		var v := _equilibrio.velocidade_3d()
		ped.empurrar(puxao.normalized() * minf(0.35 * v.length() + 0.3, 1.2), global_position)


func _tropecar(delta: float) -> void:
	var pe := _equilibrio.passo(delta)
	velocity = Vector3(pe.x, 0.0, pe.z)
	_procurar_onde_agarrar()
	if _corpo != null:
		_corpo.agarrar = _agarrado.global_position + Vector3.UP * 1.3 \
			if _agarrado != null and is_instance_valid(_agarrado) else Vector3.INF
	if _equilibrio.caiu():
		_soltar()
		derrubar(_equilibrio.velocidade_3d() + pe, Vector3.ZERO, 0.35)
		return
	if not _equilibrio.ativo():
		_equilibrio = null
		velocity = Vector3.ZERO
		_soltar()
		# Recuperado: para, vira para quem empurrou e fica um instante olhando —
		# e reclama com o corpo: quem enfrenta sacode o punho, o resto abre os
		# bracos ("que isso?").
		_estado = Estado.PAUSA
		_espera = 1.4
		_encarar(_de_onde)
		if _corpo != null:
			var enfrenta := FalasTombo.depois(int(ficha.get("personalidade", 0))) \
				== FalasTombo.Depois.ENFRENTA
			_corpo.reagir(ReacaoCorpo.REACAO_XINGA if enfrenta else ReacaoCorpo.GESTO_ABRE)
			# O olhar de estranhamento de quem nao briga ("que isso?").
			if not enfrenta and _corpo.rosto != null:
				_corpo.rosto.reagir(Rosto.Expressao.DESCONFIANCA, 2.2)


func _soltar() -> void:
	_agarrado = null
	if _corpo != null:
		_corpo.agarrar = Vector3.INF


## Cai: o corpo vira boneco de pano. `vel` e a velocidade do corpo inteiro;
## `golpe` a que a pancada acrescenta, cheia na altura `altura_golpe`.
func derrubar(vel: Vector3, golpe: Vector3, pancada: float,
		altura_golpe: float = PARA_CHOQUE) -> void:
	if _estado == Estado.CAIDO or _corpo == null:
		return
	if _voz != null:
		_voz.parar()
	_estado = Estado.CAIDO
	_equilibrio = null
	_parceiro = null
	velocity = Vector3.ZERO
	_corpo.inclinacao = Vector2.ZERO
	_corpo.debater = 0.0
	_corpo.rumo_passo = 0.0
	# A capsula FICA na camada do mundo, e o raio de obstaculo da IA a ve: o
	# transito para diante de gente caida em vez de passar por cima. Mas
	# ninguem tromba nela — carro e jogador ganham excecao — e o carro que
	# derrubou atravessa o lugar onde a pessoa estava e bate nas pecas, que tem
	# massa e empurram de verdade.
	collision_mask = 0
	_excecoes_de_caido(true)
	_boneco = BonecoDePano.derrubar(_corpo, vel, golpe, altura_golpe, pancada, [self])
	_boneco.levantou.connect(_ao_levantar, CONNECT_ONE_SHOT)
	if pancada > 0.3:
		_avisar_testemunhas()
	if pancada > 0.3:
		_gritar(FalasTombo.pancada(int(ficha.get("id", 0))), false)


var _com_excecao: Array[PhysicsBody3D] = []


func _excecoes_de_caido(ligar: bool) -> void:
	if ligar:
		for grupo: StringName in [&"carro", &"player"]:
			for n: Node in get_tree().get_nodes_in_group(grupo):
				var corpo := n as PhysicsBody3D
				if corpo != null and corpo != self:
					corpo.add_collision_exception_with(self)
					_com_excecao.append(corpo)
		return
	for corpo in _com_excecao:
		if is_instance_valid(corpo):
			corpo.remove_collision_exception_with(self)
	_com_excecao.clear()


## Quem viu o atropelo de perto para, vira e reage: o assustado se protege, o
## devoto se benze, quem enfrenta xinga o motorista, o resto leva a mao a
## cabeca. E o que faz a rua perceber — no GTA IV a calcada inteira vira para
## ver.
const RAIO_TESTEMUNHA := 12.0


func _avisar_testemunhas() -> void:
	for n: Node in get_tree().get_nodes_in_group(&"pedestre"):
		var outro := n as Pedestre
		if outro == null or outro == self or not is_instance_valid(outro):
			continue
		if outro.global_position.distance_to(global_position) < RAIO_TESTEMUNHA:
			outro.testemunhar(global_position, self)


func testemunhar(onde: Vector3, quem: Node3D = null) -> void:
	if not de_pe() or _estado == Estado.ATENDENDO:
		return
	_estado = Estado.PAUSA
	_espera = 3.5
	# Os olhos vao atras do corpo que voa e ficam nele no chao.
	_olhando = quem
	_t_olhando = 6.0
	velocity = Vector3.ZERO
	_encarar(onde)
	if _corpo == null:
		return
	var p := int(ficha.get("personalidade", 0))
	match p:
		8, 3:  # ASSUSTADO, MELANCOLICO
			_corpo.reagir(ReacaoCorpo.REACAO_PROTEGE)
		6:  # DEVOTO
			_corpo.reagir(ReacaoCorpo.OCIO_BENZE)
		_:
			if FalasTombo.depois(p) == FalasTombo.Depois.ENFRENTA:
				_corpo.reagir(ReacaoCorpo.REACAO_XINGA)
			else:
				_corpo.reagir(ReacaoCorpo.OCIO_NUCA)
	if absi(int(ficha.get("id", 0))) % 3 == 0:
		_gritar(["Meu Deus!", "Atropelaram o cara!", "Chama alguem!"][absi(int(ficha.get("id", 0))) % 3], false)


## Caida, o no da pessoa acompanha o quadril: a multidao mede distancia, a voz
## sai daqui e o gatilho de conversa fica em cima do corpo.
func _seguir_o_corpo() -> void:
	velocity = Vector3.ZERO
	if _boneco == null or not is_instance_valid(_boneco):
		return
	var p := _boneco.onde_esta()
	global_position.x = p.x
	global_position.z = p.z


func _ao_levantar(onde: Vector3, rumo: float) -> void:
	var dor: Dictionary = _boneco.onde_doi() if is_instance_valid(_boneco) else {}
	var de_brucos := is_instance_valid(_boneco) and _boneco.de_brucos()
	_boneco = null
	global_position = onde
	rotation.y = rumo
	_giro_alvo = rumo
	_y_suave = onde.y
	collision_layer = 1
	collision_mask = 1
	_excecoes_de_caido(false)
	var p := int(ficha.get("personalidade", 0))
	_gritar(FalasTombo.levantando(p, int(ficha.get("id", 0))), true)
	_sentir_a_pancada(dor, de_brucos, FalasTombo.depois(p) != FalasTombo.Depois.FOGE)
	match FalasTombo.depois(p):
		FalasTombo.Depois.FOGE:
			_estado = Estado.ANDANDO
			assustar(_de_onde, 1.0)
		FalasTombo.Depois.ENFRENTA:
			_estado = Estado.PAUSA
			_espera = 3.0
			_encarar(_de_onde)
		_:
			# Atordoado: fica parado olhando o nada, e o corpo balanca um
			# pouco — a cabeca ainda nao voltou.
			_estado = Estado.PAUSA
			_espera = 2.2
			if _corpo != null:
				_corpo.chapado = true
				get_tree().create_timer(2.4).timeout.connect(func() -> void:
					if is_instance_valid(_corpo):
						_corpo.chapado = false)


## Grito curto, com voz; com legenda quando o jogador esta perto o bastante para
## ouvir. Sem o gesto de conversa: e reflexo, nao fala.
func _gritar(linha: String, legenda: bool) -> void:
	if linha.is_empty():
		return
	_falar_curto(linha, false)
	var limpa := Fala.sem_marcas(linha)
	if legenda and _jogador != null \
			and _jogador.global_position.distance_to(global_position) < 12.0:
		var cinema := get_node_or_null(^"/root/Cinema")
		if cinema != null and limpa != "...":
			cinema.call(&"fala", "%s: %s" % [FalasNpc.rotulo(ficha), limpa])


## Linha curta pela `Fala`: a boca faz cada silaba que a voz toca. Antes o grito
## ia direto na `Voz` e saia de boca fechada — "Atropelaram o cara!" com a cara
## parada. `gesticula` liga os gestos da frase (o papo com o parceiro); o grito
## e reflexo e nao gesticula. Quem esta em conversa com o jogador fala pela
## `Conversa`, e nao por aqui.
func _falar_curto(linha: String, gesticula: bool) -> void:
	if Conversa.ativo and Conversa.quem() == self:
		return
	if _fala == null:
		_fala = Fala.new()
		_fala.name = "Fala"
		add_child(_fala)
		_fala.voz = voz_da_fala()
		var p := int(ficha.get("personalidade", 0))
		_fala.cadencia = float(Personalidade.de(p)["cadencia"])
	_fala.rosto = _corpo.rosto if _corpo != null else null
	var corpos: Array[Corpo] = []
	if gesticula and _corpo != null and de_pe():
		corpos.append(_corpo)
		_fala.personalidade = int(ficha.get("personalidade", 0))
		_fala.gesticula = float(_corpo.jeito.get("gesto", 1.0))
	else:
		_fala.personalidade = -1
	_fala.corpos = corpos
	_fala.dizer(linha)


## No chao e acordado: geme de tempos em tempos, com careta (a marca [dor]).
func _gemer(delta: float) -> void:
	if _boneco == null or not is_instance_valid(_boneco) or not _boneco.gemendo():
		return
	_t_gemido -= delta
	if _t_gemido > 0.0:
		return
	_t_gemido = 2.2 + float(absi(int(ficha.get("id", 0)) * 31 + Time.get_ticks_msec() / 211) % 25) * 0.1
	_falar_curto(FalasTombo.gemido(int(ficha.get("id", 0))), false)


## De pe de novo, o corpo lembra onde bateu: a mao vai a cabeca, a lombar, a
## barriga ou ao braco; perna batida manca por uns quinze segundos. Quem foge
## nao para para sentir — so manca.
func _sentir_a_pancada(dor: Dictionary, de_brucos: bool, com_gesto: bool) -> void:
	if _corpo == null or dor.is_empty():
		return
	var parte: StringName = dor["parte"]
	var forca := float(dor["forca"])
	if parte == &"perna_e" or parte == &"perna_d":
		_corpo.perna_ruim = -1 if parte == &"perna_e" else 1
		_corpo.mancando = clampf(forca / 9.0, 0.45, 1.0)
		_t_manca = lerpf(9.0, 18.0, clampf((forca - 4.0) / 8.0, 0.0, 1.0))
		return
	if not com_gesto:
		return
	match parte:
		&"cabeca":
			_corpo.reagir(ReacaoCorpo.REACAO_DOR_CABECA)
		&"tronco":
			_corpo.reagir(ReacaoCorpo.REACAO_DOR_BARRIGA if de_brucos
				else ReacaoCorpo.REACAO_DOR_COSTAS)
		_:
			_corpo.reagir(ReacaoCorpo.REACAO_DOR_BRACO)


## Esbarrao do jogador: so conta indo DE ENCONTRO, e com rapidez de quem nao
## desviou. A troca de velocidade e a de dois corpos que batem (a fracao da
## massa do outro), menos um tanto que o proprio corpo absorve.
func _sentir_esbarrao() -> void:
	if _desde_esbarrao < ESPERA_ESBARRAO or _estado == Estado.ATENDENDO:
		return
	var corpo := _jogador as CharacterBody3D
	if corpo == null:
		return
	var para_mim := global_position - corpo.global_position
	para_mim.y = 0.0
	var d := para_mim.length()
	if d > CONTATO + 0.06 or d < 0.01:
		return
	var normal := para_mim / d
	var dele := Vector3(corpo.velocity.x, 0.0, corpo.velocity.z).dot(normal)
	if dele - velocity.dot(normal) < ESBARRAO_MINIMO or dele <= 0.0:
		return
	_desde_esbarrao = 0.0
	var fracao := MASSA_JOGADOR / (MASSA_JOGADOR + MASSA)
	# So o passo de quem vem empurra; o proprio passo do pedestre para quando
	# ele tropeca (ver `_ser_atingido`).
	var dv := normal * dele * fracao * 0.75
	# Um tanto da direcao de quem vinha: o ombro que passa de raspao gira a
	# pessoa para o lado, nao so a empurra para longe.
	dv += Vector3(corpo.velocity.x, 0.0, corpo.velocity.z) * 0.06
	empurrar(dv, corpo.global_position)
	var audio := get_node_or_null(^"/root/AudioDirector")
	if audio != null:
		audio.call(&"tocar", &"baque_corpo_%d" % (1 + int(ficha.get("id", 0)) % 3),
			global_position + Vector3.UP, -14.0, 1.25)


## Carro encostando, empurrando ou atropelando (a conta mora em `Atropelo`).
func _sentir_carros(delta: float) -> void:
	var bate := Atropelo.quem_bate(get_tree(), global_position, velocity, 0.28, delta)
	if not bate.is_empty():
		_ser_atingido(bate["carro"], bate["rel"], bate["vc"])


func _ser_atingido(carro: Node3D, rel: Vector3, vc: Vector3) -> void:
	var v := rel.length()
	_de_onde = carro.global_position
	var audio := get_node_or_null(^"/root/AudioDirector")
	if v < CARRO_EMPURRA:
		# Carro devagar: empurra. O equilibrio decide se da passo ou cai. Um
		# empurrao por vez: encostado, o contato dura varios quadros, e cada um
		# somando velocidade derrubava quem so devia cambalear.
		if _desde_esbarrao < ESPERA_ESBARRAO:
			return
		_desde_esbarrao = 0.0
		# O empurrao e a velocidade do CARRO, e nao a relativa: quem andava de
		# encontro ao carro para de andar ao tropecar, e o passo dele nao vira
		# empurrao. Com a relativa, pedestre andando contra carro a 2 m/s caia.
		vc.y = 0.0
		empurrar(vc * 0.9, carro.global_position)
		if audio != null:
			audio.call(&"tocar", &"baque_corpo_2", global_position + Vector3.UP * 0.6, -10.0, 0.9)
		return
	# Atropelo (golpe e pancada: ver `Atropelo`).
	derrubar(velocity, Atropelo.golpe(rel), Atropelo.pancada(v), PARA_CHOQUE)
	# O corpo sente o carro pelo perfil de sedan (capo, para-brisa, teto), e
	# nao pela caixa de colisao dele — e o que faz rolar por cima do capo.
	if _boneco != null:
		LatariaParaCorpo.criar(carro, Atropelo.caixa_do_carro(carro), _boneco.pecas())
	Atropelo.tranco_no_carro(carro, rel, MASSA)
	if audio != null:
		audio.call(&"tocar", &"atropelo_pancada", global_position + Vector3.UP * 0.6,
			linear_to_db(clampf(v / 10.0, 0.4, 1.3)), randf_range(0.9, 1.08))
