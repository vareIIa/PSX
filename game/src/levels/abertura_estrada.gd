## A cena da estrada: o primeiro minuto do jogo, antes da cidade.
##
## Onde ela entra
## --------------
## Antes da `Abertura`. A ordem do jogo passa a ser:
##
##     titulo -> NOVO JOGO -> [estrada] -> [abertura] -> primeira missao
##
## A `Abertura` comeca com ele acordado no chao de um parque dizendo "eu tava
## indo pra Sao Thome das Letras". Esta cena e esse "tava indo": a viagem, de
## dentro do carro, na estrada de terra, com a duvida que ele carregava antes de
## acontecer o que acontece. As duas se emendam no preto — esta nao devolve o
## controle ao jogador, so entrega a tarja fechada para a seguinte.
##
## Onde ela ACONTECE
## -----------------
## Quatro mil metros acima da cidade, pelo mesmo motivo que os interiores moram
## dois mil acima: separar por espaco em vez de por cena. Trocar de arvore de
## cena aqui faria a cidade descarregar e recarregar inteira no meio da abertura
## — e a cidade e justamente o que precisa estar pronto quando esta cena acabar.
## Enquanto o carro anda, o ChunkManager monta o bairro do respawn la embaixo,
## de graca, no tempo que a cena ja ia gastar.
##
## Os planos, na ordem
## -------------------
##   1. A camera baixa na beira da estrada; o carro vem de longe e passa rente.
##   2. De cima, acima da copa, acompanhando: a estrada serpenteando na mata e o
##      poente no fundo.
##   3. Rasante ao lado do carro, arvore passando rapido no primeiro plano.
##   4. Dentro do carro: painel, volante, capo, estrada — e o HUD, que so existe
##      neste plano.
##   5. O carro se afastando, engolido pela nevoa. Preto, e entrega.
##
## A camera segue o carro a mao, e nao pelo `Cinema.mover`
## -------------------------------------------------------
## `Cinema.mover` interpola entre dois pontos FIXOS, o que e o certo para uma
## cena em que o assunto esta parado — e e o caso da abertura da cidade inteira.
## Aqui o assunto anda a dezoito metros por segundo: em nove segundos ele
## percorre cento e sessenta metros, e qualquer par de pontos fixos ou perde o
## carro no comeco ou perde no fim. Entao o enquadramento e recalculado por
## quadro a partir de onde o carro esta, que e o que uma camera de verdade em
## cima de um carro de apoio faria.
class_name AberturaEstrada
extends Node

signal terminou()

const PRESET := "res://resources/fog/fog_estrada.tres"
## Climas da Estrada Velha (refs). `--estrada-clima=` escolhe.
const CLIMAS_ESTRADA := {
	"entardecer": "res://resources/fog/fog_estrada.tres",
	"noite": "res://resources/fog/fog_estrada_noite.tres",
	"amanhecer": "res://resources/fog/fog_estrada_amanhecer.tres",
	"dia": "res://resources/fog/fog_estrada_dia.tres",
}

## Nevoa so do plano aereo, na noite.
##
## O plano de dentro do carro e o plano de cima pedem alcances OPOSTOS, e as
## duas prints de referencia mostram exatamente isso: na cabine a bruma fecha
## num paredao a trinta metros, e na aerea o vale inteiro aparece com a estrada
## serpenteando ate o pe da serra. Com um preset so, ou a cabine perde o paredao
## ou a aerea vira uma tela cinza com duas copas de arvore.
##
## E trapaca, e e trapaca de cinema: quem esta assistindo nunca ve os dois
## alcances no mesmo quadro — ha um corte no preto entre eles.
const CLIMA_AEREA := "res://resources/fog/fog_estrada_noite_aerea.tres"


## Altura em que a estrada e montada, acima da cidade. Ver o cabecalho.
##
## Nao e 2000: essa altura e dos interiores, e a `Abertura` que vem depois entra
## em dois deles. Quatro mil deixa os dois mundos sem chance de se encostarem.
const ALTURA := 4000.0

## Velocidade de cruzeiro, em km/h. Sessenta e oito e o numero da print, e e uma
## velocidade honesta para estrada de terra: acima disso o carro estaria sendo
## irresponsavel, e o sujeito desta cena nao esta com pressa nenhuma.
const CRUZEIRO := 68.0

## Onde o carro comeca. Nao e zero: o primeiro plano precisa de estrada ATRAS da
## camera para o carro chegar de algum lugar, e a camera do plano 1 fica cento e
## vinte metros a frente do ponto de partida.
const PARTIDA := 40.0

# --- plano 1: a passagem ----------------------------------------------------
## A camera fica parada na beira e o carro vem de longe. E o unico plano em que
## a camera nao acompanha nada: ela espera.
const PASSAGEM_ADIANTE := 118.0
const PASSAGEM_LADO := 5.6
const PASSAGEM_ALTURA := 1.05
const PASSAGEM_FOV := 62.0
const PASSAGEM_DURACAO := 9.0

# --- plano 2: a aerea -------------------------------------------------------
## Acima da copa. As arvores desta mata tem ate 16 m, entao 21 e 26 passam por
## cima delas com folga — a camera atravessando uma copa e o defeito classico do
## plano aereo, e ele nao da erro nenhum: so aparece como um borrao verde.
const AEREA_ALTURA := Vector2(41.0, 33.0)
## Deslocamento lateral, do comeco ao fim: a camera cruza de um lado da estrada
## para o outro durante o plano. E o movimento inteiro dele.
const AEREA_LADO := Vector2(6.0, -4.0)
const AEREA_RECUO := Vector2(25.0, 17.0)
## Para onde olha, a frente do carro. Olhar para o carro deixaria ele no meio do
## quadro o tempo todo e a estrada sairia de cena; olhando a frente, o carro
## desce para o terco de baixo e o que ocupa a tela e a estrada e o poente.
const AEREA_MIRA := Vector2(62.0, 78.0)
const AEREA_FOV := Vector2(58.0, 52.0)
const AEREA_DURACAO := 12.0

# --- plano 3: o rasante -----------------------------------------------------
## Ao lado do carro, na altura do farol. O assunto aqui e a VELOCIDADE, e ela
## nao se filma de longe: e o mato passando rente a lente que a produz.
## Lado do rasante. Fica DENTRO do leito de proposito.
##
## Era 3,1 a 4,6 — ou seja, ate um metro e meio para dentro da beira, que e onde
## `KitEstrada.beira` planta moita. Enquanto a beira era rala dava para passar;
## depois de adensar a mata, a camera atravessava moita e a imagem virava um
## retangulo preto com uma janela no meio, que e o interior de uma caixa de
## folha vista de dentro. O rasante e sobre velocidade, e velocidade se filma
## rente ao chao da pista, nao dentro do mato.
const RASANTE_LADO := Vector2(2.5, 3.0)
const RASANTE_ALTURA := Vector2(0.75, 1.15)
## Recuo do rasante. POSITIVO: a camera trilha atras do farol.
##
## Era negativo (-0,5 a -3,2), o que em `_mover_camera` vira `+ dir * recuo` —
## a camera ia parar A FRENTE do carro, dentro do cone volumetrico do farol, que
## tem doze metros de comprimento e tres de raio. Estar dentro de um volume
## aditivo com `cull_disabled` pinta meia tela de branco chapado, e era a cunha
## dura que aparecia na captura. O plano quer o carro entrando no quadro, e para
## isso a camera tem de estar atras do nariz dele.
const RASANTE_RECUO := Vector2(1.8, 4.8)
const RASANTE_MIRA := 5.0
const RASANTE_FOV := 64.0
const RASANTE_DURACAO := 8.0

# --- plano 4: dentro do carro -----------------------------------------------
## Campo de visao do plano de dentro. Mais aberto que o resto da cena de
## proposito: e o que cabe o capo inteiro, as duas colunas e a estrada no mesmo
## quadro, que e o enquadramento da print de referencia.
const DENTRO_FOV := 70.0
## Para onde a cabeca dele olha, em graus. Um grau e meio abaixo da linha do
## horizonte — quem dirige olha a estrada, e nao o ceu.
const DENTRO_PITCH := -2.0
const DENTRO_DURACAO := 23.0

# --- plano 5: a saida -------------------------------------------------------
const SAIDA_ALTURA := 6.4
const SAIDA_RECUO := 9.0
const SAIDA_FOV := 56.0
const SAIDA_DURACAO := 6.5

## Distancia de Sao Thome no comeco da viagem, em km. So o rotulo do mapa le
## isto; nao ha destino nenhum no mundo. Serve para a viagem ter tamanho na
## cabeca de quem esta assistindo.
const FALTA_KM := 34.0

# --- textos -----------------------------------------------------------------
## Ele nao esta contando a viagem para ninguem: esta remoendo. Por isso nenhuma
## fala explica o que a imagem ja mostra, e nenhuma delas termina de fechar o
## assunto — a ultima e "ai eu peguei o carro e vim", que e uma pessoa se
## justificando sozinha dentro do proprio carro.
## As falas do trecho da estrada, ACENTUADAS.
##
## Elas eram escritas em ASCII — "Sao Thome", "nao", "ja", "Ai" — como se a
## fonte nao tivesse acento. Tem: `psx_titulo.fnt` e `psx_mono.fnt` trazem os
## 152 glifos, com á, ã, ç, é, ê, í, ó, ú e õ entre eles, e o HUD ja escrevia
## "PRAÇA DA MATRIZ" com cedilha na mesma tela. Era portugues errado impresso no
## primeiro minuto do jogo sem motivo tecnico nenhum.
const FALAS := {
	"passagem": "A gente marcou essa viagem faz uns dois meses.",
	"aerea_1": "São Thomé das Letras. Todo mundo dizia que eu tinha que conhecer.",
	"aerea_2": "Duas horas de terra depois que acaba o asfalto.",
	"rasante": "Eu que não queria vir.",
	"dentro_1": "Sem maldade, essa estrada não parece ter fim.",
	"dentro_2": "Faz uma semana que eu acordo pensando em desmarcar.",
	"dentro_3": "Cheguei a escrever a desculpa no celular. Não mandei.",
	"dentro_4": "Mas a pousada já tava paga e o pessoal já tava vindo.",
	"saida": "Aí eu peguei o carro e vim.",
}

enum Plano { NENHUM, PASSAGEM, AEREA, RASANTE, DENTRO, SAIDA, CHASE }

var _cena: Node3D
var _raiz: Node3D
var _estrada: EstradaBuilder
var _carro: CarroCena
var _ceu: CeuEstrada
var _hud: HudEstrada
var _fog: FogController
var _cam: Camera3D

var _plano: Plano = Plano.NENHUM
var _t: float = 0.0
var _duracao: float = 1.0
## Estaca em que a camera parada do plano 1 esta fincada.
var _ancora: float = 0.0
## `far` que a camera cinematica tinha antes desta cena. A abertura da cidade
## depende dele — o plano do poste enxerga a rua inteira — e esta cena o troca
## por 900.
##
## Ja foi 260, com o argumento de que "nao ha nada alem da nevoa numa estrada no
## meio do mato". Isso valia enquanto a mata acabava a 32 m do eixo e a 86 m a
## frente. Agora ela vai a 95 e 259, a cupula esta a 420 e a serra a 340, e um
## `far` curto cortaria justamente o fundo que o plano de cima existe para
## mostrar — o corte aparece como um circulo de vazio em volta da camera.
var _far_anterior: float = 600.0
## Modo jogavel (TASK AAA): WASD + V 1P/3P. Cutscene continua o default.
var _jogavel: bool = false
## True = chase 3P; false = cabine 1P (default).
var _terceira: bool = false



func executar(cena: Node3D) -> void:
	_cena = cena
	Cinema.fechar_de_imediato()
	Cinema.iniciar(true)
	_montar_mundo()

	_cam = Cinema.assumir()
	_far_anterior = _cam.far
	_cam.far = 900.0
	_cam.near = 0.08
	set_process(true)

	if _quer_jogavel():
		await _correr_jogavel()
		_desmontar()
		terminou.emit()
		queue_free()
		return

	var plano_cap := _plano_captura()
	if plano_cap != Plano.NENHUM:
		await _segurar_captura(plano_cap)
		_desmontar()
		terminou.emit()
		queue_free()
		return

	await _plano_passagem()
	await _plano_aerea()
	await _plano_rasante()
	await _plano_dentro()
	await _plano_saida()

	_desmontar()
	terminou.emit()
	queue_free()


# --- montagem ---------------------------------------------------------------

func _montar_mundo() -> void:
	_raiz = Node3D.new()
	_raiz.name = "MundoEstrada"
	_raiz.position = Vector3(0.0, ALTURA, 0.0)
	_cena.add_child(_raiz)

	_estrada = EstradaBuilder.new()
	_estrada.name = "Estrada"
	_raiz.add_child(_estrada)

	_carro = CarroCena.new()
	_carro.name = "Carro"
	_carro.estrada = _estrada
	_raiz.add_child(_carro)
	_carro.distancia = PARTIDA
	_carro.velocidade = CRUZEIRO
	# Monta o chao antes de a cortina abrir. Sem isto o primeiro quadro da cena
	# e o carro suspenso no vazio enquanto os cinco trechos sobem.
	_estrada.atualizar(PARTIDA)
	_carro.assentar()

	_ceu = CeuEstrada.new()
	_ceu.name = "Ceu"
	_raiz.add_child(_ceu)

	_hud = HudEstrada.new()
	_hud.name = "HudEstrada"
	_cena.add_child(_hud)
	_hud.visible = false

	# O clima da estrada por cima do da cidade. `liberar` no fim devolve o
	# preset do jogador, e sem essa devolucao a cidade inteira ficaria em fim de
	# tarde de outro lugar.
	_fog = _cena.get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if _fog != null:
		_fog.forcar(_caminho_clima())
	_ligar_farois_se_noite()
	if _estrada != null:
		_estrada.clima_id = _clima_id()
		if _clima_id() == "noite":
			_estrada.spawn_vulto_beira(_carro.distancia if _carro else 80.0)


func _desmontar() -> void:
	set_process(false)
	if _cam != null and is_instance_valid(_cam):
		_cam.far = _far_anterior
	if _fog != null and is_instance_valid(_fog):
		_fog.liberar()
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
		_hud.queue_free()
		_hud = null
	if _raiz != null and is_instance_valid(_raiz):
		_raiz.queue_free()


# --- planos -----------------------------------------------------------------

func _plano_passagem() -> void:
	_ancora = _carro.distancia + PASSAGEM_ADIANTE
	_comecar(Plano.PASSAGEM, PASSAGEM_DURACAO)
	await Cinema.clarear(0.9)
	Cinema.legenda(FALAS["passagem"], 4.2)
	await _esperar(PASSAGEM_DURACAO - 0.9)
	await Cinema.escurecer(0.4)


func _plano_aerea() -> void:
	_nevoa_aerea(true)
	_comecar(Plano.AEREA, AEREA_DURACAO)
	await Cinema.clarear(0.6)
	Cinema.legenda(FALAS["aerea_1"], 4.6)
	await _esperar(5.4)
	Cinema.legenda(FALAS["aerea_2"], 4.0)
	await _esperar(AEREA_DURACAO - 6.0)
	await Cinema.escurecer(0.4)
	_nevoa_aerea(false)


func _plano_rasante() -> void:
	_comecar(Plano.RASANTE, RASANTE_DURACAO)
	await Cinema.clarear(0.5)
	Cinema.legenda(FALAS["rasante"], 3.2)
	await _esperar(RASANTE_DURACAO - 0.9)
	await Cinema.escurecer(0.45)


## O plano de dentro do carro. E o unico que dura o bastante para quatro falas.
##
## Sem HUD. A barra de vida, o icone de lanterna e o cartao LOCAL/HORA ficavam
## ligados durante a cutscene: o cartao brigava com a legenda pelo mesmo canto
## da tela e a barra anunciava controle onde o jogador nao tem nenhum. O HUD e
## da parte JOGAVEL — sobe em `_modo_jogavel` e na troca de camera, e so.
func _plano_dentro() -> void:
	_comecar(Plano.DENTRO, DENTRO_DURACAO)
	await Cinema.clarear(0.7)
	var falas := ["dentro_1", "dentro_2", "dentro_3", "dentro_4"]
	var durs := [4.0, 4.2, 4.2, 4.4]
	for i in falas.size():
		Cinema.legenda(FALAS[falas[i]], durs[i])
		await _esperar(5.4)
	await _esperar(maxf(0.0, DENTRO_DURACAO - 5.4 * float(falas.size())))
	await Cinema.escurecer(0.5)


## Troca para a nevoa aberta do plano de cima, e devolve depois. So a noite: nos
## outros climas o alcance ja e outro e nao ha paredao para abrir.
func _nevoa_aerea(ligar: bool) -> void:
	if _fog == null or not is_instance_valid(_fog) or _clima_id() != "noite":
		return
	_fog.forcar(CLIMA_AEREA if ligar else _caminho_clima())


func _plano_saida() -> void:
	_ancora = _carro.distancia - SAIDA_RECUO
	_comecar(Plano.SAIDA, SAIDA_DURACAO)
	await Cinema.clarear(0.6)
	Cinema.legenda(FALAS["saida"], 3.6)
	await _esperar(SAIDA_DURACAO - 1.2)
	# Emenda Estrada -> Praca: esconde o HUD no COMECO do fade-to-black.
	# Se sumir so no _desmontar (depois do preto), o LOCAL: ESTRADA VELHA
	# ainda pode piscar por um quadro na troca. A cortina e o unico ponto
	# de costura — cidade._rodar_abertura ja esta no preto quando chama Abertura.
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = false
	await Cinema.escurecer(0.8)


func _comecar(plano: Plano, duracao: float) -> void:
	_plano = plano
	_t = 0.0
	_duracao = maxf(0.01, duracao)
	# Um quadro de camera ANTES de a cortina abrir. Sem isto o primeiro quadro
	# visivel do plano e o enquadramento do plano anterior, e o corte aparece.
	_mover_camera(0.0)


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(maxf(0.0, segundos)).timeout


# --- camera -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _carro == null or not is_instance_valid(_carro):
		return
	_carro.avancar(delta)
	_t += delta
	_mover_camera(clampf(_t / _duracao, 0.0, 1.0))
	if _hud != null and _hud.visible:
		_hud.mostrar(_carro.position, _carro.rotation.y, _carro.velocidade,
			_carro.marcha(), FALTA_KM - _carro.distancia * 0.001)


func _mover_camera(k: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var s := _carro.distancia
	var carro := _carro.position
	var dir := EstradaBuilder.direcao_em(s)
	var lado := EstradaBuilder.lado_em(s)

	match _plano:
		Plano.PASSAGEM:
			var p := EstradaBuilder.ponto_em(_ancora)
			var l := EstradaBuilder.lado_em(_ancora)
			_enquadrar(p + l * PASSAGEM_LADO + Vector3.UP * PASSAGEM_ALTURA,
				carro + Vector3.UP * 0.7, PASSAGEM_FOV)
		Plano.AEREA:
			var de := carro + lado * lerpf(AEREA_LADO.x, AEREA_LADO.y, k) \
				- dir * lerpf(AEREA_RECUO.x, AEREA_RECUO.y, k) \
				+ Vector3.UP * lerpf(AEREA_ALTURA.x, AEREA_ALTURA.y, k)
			var mira := EstradaBuilder.ponto_em(
				s + lerpf(AEREA_MIRA.x, AEREA_MIRA.y, k))
			_enquadrar(de, mira, lerpf(AEREA_FOV.x, AEREA_FOV.y, k))
		Plano.RASANTE:
			var de := carro + lado * lerpf(RASANTE_LADO.x, RASANTE_LADO.y, k) \
				- dir * lerpf(RASANTE_RECUO.x, RASANTE_RECUO.y, k) \
				+ Vector3.UP * lerpf(RASANTE_ALTURA.x, RASANTE_ALTURA.y, k)
			_enquadrar(de, carro + dir * RASANTE_MIRA + Vector3.UP * 0.8,
				RASANTE_FOV)
		Plano.DENTRO:
			_de_dentro()
		Plano.SAIDA:
			var p := EstradaBuilder.ponto_em(_ancora)
			var l := EstradaBuilder.lado_em(_ancora)
			_enquadrar(p + l * 1.6 + Vector3.UP * SAIDA_ALTURA,
				carro + Vector3.UP * 0.9, SAIDA_FOV)
		Plano.CHASE:
			# 3a pessoa atras do hatch (ref 03): mais perto, menos alto.
			var de_chase := carro - dir * 6.2 + Vector3.UP * 1.55 + lado * 0.2
			_enquadrar(de_chase, carro + dir * 8.0 + Vector3.UP * 0.55, 56.0)
		_:
			pass


## O plano de dentro nao "enquadra": ele HERDA a pose do suporte de camera, que
## e filho do carro e por isso ja carrega o chacoalho da estrada, a inclinacao
## da curva e o arfar da lombada. Calcular esse balanco de novo aqui daria duas
## versoes do mesmo movimento, e elas divergiriam no primeiro ajuste.
func _de_dentro() -> void:
	var pose := _carro.suporte_camera.global_transform
	_cam.fov = DENTRO_FOV
	_cam.global_transform = Transform3D(
		pose.basis * Basis(Vector3.RIGHT, deg_to_rad(DENTRO_PITCH)),
		pose.origin)


## Poe a camera num ponto olhando para outro, os dois em coordenada da estrada.
##
## A conversao para mundo acontece AQUI, e num lugar so. Todo plano trabalha em
## coordenada local da estrada — que e onde o caminho, o carro e o mapa vivem —
## e esquecer de somar os quatro mil metros num deles daria uma camera apontada
## para o chao da cidade, que e uma imagem preta sem nenhuma mensagem de erro.
func _enquadrar(de: Vector3, para: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.global_position = de + Vector3(0.0, ALTURA, 0.0)
	var alvo := para + Vector3(0.0, ALTURA, 0.0)
	if _cam.global_position.distance_squared_to(alvo) < 0.0001:
		return
	_cam.look_at(alvo, Vector3.UP)


# --- captura / clima / jogavel (TASK AAA) ------------------------------------


## Overrides de captura: --hora=HH:MM, --vida=N, --lanterna-off, --local=NOME.
func _aplicar_overrides_hud() -> void:
	if _hud == null:
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hora="):
			_hud.definir_hora(arg.trim_prefix("--hora="))
		elif arg.begins_with("--vida="):
			_hud.definir_vida(int(arg.trim_prefix("--vida=")), 10)
		elif arg.begins_with("--local="):
			_hud.definir_local(arg.trim_prefix("--local=").replace("_", " "))
		elif arg == "--lanterna-off":
			_hud.definir_lanterna(false)


func _flag_estrada_qualquer() -> bool:
	var args := OS.get_cmdline_user_args()
	return (args.has("--ver-estrada")
		or args.has("--ver-estrada-cabine")
		or args.has("--ver-estrada-jogavel"))


func _quer_jogavel() -> bool:
	var args := OS.get_cmdline_user_args()
	# Flag preferida do contrato com Renatin / CaptureTool.
	if args.has("--ver-estrada-cabine") or args.has("--ver-estrada-jogavel"):
		return true
	for arg: String in args:
		if arg == "--estrada-modo=jogavel" or arg == "--estrada-modo=playable":
			return true
	return false


func _clima_id() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--estrada-clima="):
			return arg.trim_prefix("--estrada-clima=")
	# Padrao das refs de horror: noite com farois.
	if _flag_estrada_qualquer():
		return "noite"
	return "entardecer"


func _caminho_clima() -> String:
	var id := _clima_id()
	if CLIMAS_ESTRADA.has(id):
		return String(CLIMAS_ESTRADA[id])
	return PRESET


func _plano_captura() -> Plano:
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--estrada-plano="):
			continue
		match arg.trim_prefix("--estrada-plano="):
			"passagem":
				return Plano.PASSAGEM
			"aerea":
				return Plano.AEREA
			"rasante":
				return Plano.RASANTE
			"dentro", "fp", "cabine":
				return Plano.DENTRO
			"saida":
				return Plano.SAIDA
			"chase", "tp":
				return Plano.CHASE
	# --ver-estrada sem plano: segura FP cabine (ref 01). Jogavel nao passa aqui.
	if OS.get_cmdline_user_args().has("--ver-estrada") and not _quer_jogavel():
		return Plano.DENTRO
	return Plano.NENHUM


## Segura um plano ate o CaptureTool matar o processo (--shot-quit).
func _segurar_captura(plano: Plano) -> void:
	# Carro PARADO na captura.
	#
	# Ele andava: `_process` chama `avancar` mesmo com o plano congelado, e a 68
	# km/h os cem quadros de fisica da captura sao trinta e um metros. Tudo que
	# `garantir_props_facho` promete colocar no cone do farol — a casa, a cerca,
	# o vulto — era colocado em relacao ao metro 120 e fotografado do metro 151,
	# ou seja, atras do carro. A captura mostrava um trecho generico e nao o que
	# a funcao garantiu, e duas capturas seguidas nunca eram o mesmo quadro.
	_carro.distancia = 120.0
	_carro.velocidade = 0.0
	_estrada.atualizar(_carro.distancia)
	_carro.assentar()
	if _clima_id() == "noite":
		_ligar_farois_se_noite()
		_estrada.spawn_vulto_beira(_carro.distancia)
		_estrada.garantir_props_facho(_carro.distancia)
	if plano == Plano.AEREA:
		_nevoa_aerea(true)
	_ancora = _carro.distancia + PASSAGEM_ADIANTE
	_comecar(plano, 9999.0)
	# HUD camera-agnostic: ligado em 1P e 3P.
	if plano == Plano.CHASE:
		_terceira = true
		if _carro != null:
			_carro.mostrar_cabine(false)
	await Cinema.clarear(0.35)
	await get_tree().create_timer(120.0).timeout


func _ligar_farois_se_noite() -> void:
	if _clima_id() not in ["noite", "amanhecer"]:
		return
	if _carro == null:
		return
	_carro.acender_farois(true)


## Cabine jogavel: default 1P, V alterna chase 3P. HUD sempre visivel.
func _correr_jogavel() -> void:
	_jogavel = true
	_terceira = false
	_carro.jogavel = true
	_carro.distancia = 80.0
	_carro.velocidade = 42.0
	_estrada.atualizar(_carro.distancia)
	_carro.assentar()
	_carro.mostrar_cabine(true)
	_comecar(Plano.DENTRO, 9999.0)
	if _hud != null:
		_hud.visible = true
		_hud.definir_local("ESTRADA VELHA")
		_hud.definir_hora("22:43")
		_hud.definir_vida(4, 10)
		_hud.definir_lanterna(true)
		_aplicar_overrides_hud()
	await Cinema.clarear(0.4)
	await get_tree().create_timer(180.0).timeout


func _unhandled_input(event: InputEvent) -> void:
	if not _jogavel:
		return
	if event.is_action_pressed("alternar_camera"):
		_alternar_camera_jogavel()
		get_viewport().set_input_as_handled()


func _alternar_camera_jogavel() -> void:
	_terceira = not _terceira
	if _terceira:
		_plano = Plano.CHASE
		if _carro != null:
			_carro.mostrar_cabine(false)
	else:
		_plano = Plano.DENTRO
		if _carro != null:
			_carro.mostrar_cabine(true)
	if _hud != null:
		_hud.visible = true
	_mover_camera(0.0)
