## A vida do salao: quem bebe, quem brinda, quem conversa na mesa, quem grita o
## gol da TV — e quem atende, que anda atras do balcao e SERVE o que o jogador
## pede.
##
## Por que um diretor, e nao o Convidado
## ------------------------------------
## O `Convidado` e a pessoa que fica num lugar, e o arquivo dele e de toda a
## cidade (casa da fumaca, mercado, estufa). O que e de BAR — o copo na mao, o
## brinde dos dois da mesma mesa no mesmo quadro, o gol que levanta o salao — e
## combinado entre pessoas, e ninguem na mesa sabe da outra. Aqui fica a mesa;
## o Convidado continua sendo so gente. Tudo o que se usa dele e publico:
## `corpo()`, `dizer`, `encarar`, `estacionar`, `liberar` e `pontos`.
##
## Custo
## -----
## Um Timer de 0,2 s. Com o jogador a mais de `PERTO` o tique volta na primeira
## linha, o `_process` desliga e os copos somem. Perto, o `_process` so poe os
## seis copos na mao (uma leitura de osso cada). O gole e do relogio `Gole`, que
## o proprio Corpo avanca.
##
## O copo na mao
## -------------
## Nao vai pendurado no osso. O punho do boneco e um bloco de 9 cm, do tamanho do
## copo americano, e o eixo do antebraco muda com o IK: preso ao osso, o copo
## sumia dentro da mao no repouso e atravessava a cabeca no gole. Aqui ele e
## posto a cada quadro: em pe ao lado da palma, e no gole inclinado com a BORDA
## nos labios — e a mao vai por IK para o lado dele (`ALVO_DO_COPO`).
class_name VidaDoBar
extends Node3D

const TIQUE := 0.2
## Alem disto o bar dorme: ninguem brinda, ninguem conversa, ninguem serve.
const PERTO := 30.0
## A fala da mesa so sai com o jogador perto: murmurio a trinta metros e ruido.
const OUVIDO := 10.0
## Distancia maxima entre o assento anotado e o convidado que sentou nele.
const CASAR := 0.35
## Intervalo entre brindes numa mesa, e entre uma fala e a proxima.
const BRINDE := Vector2(24.0, 70.0)
const PAUSA_FALA := Vector2(2.5, 7.0)
const PAPO_DO_BALCAO := Vector2(18.0, 40.0)
## Onde a mao pega o copo: no terco de baixo, e fora da palma o raio mais o
## dedo. Pego pelo meio, o copo sumia dentro do punho e so a espuma aparecia.
const COPO_MEIO := 0.022
const COPO_PALMA := 0.052
const COPO_ALTURA := 0.093
## Altura do encontro dos copos no brinde, do chao.
const ALTURA_DO_BRINDE := 1.0
## Inclinacao do copo no gole, a partir da vertical: a borda vem para o rosto.
## O golao vira quase deitado.
const INCLINA_GOLE := 58.0
const INCLINA_GOLAO := 82.0
## Onde a pega da mao vai no gole, em relacao aos labios (cabeca: -Z a frente,
## +Y cima, +X direita): do lado de fora do copo inclinado, no terco de baixo
## dele. Sai da mesma conta de `_por_copo` com INCLINA_GOLE.
const ALVO_DO_COPO := Vector3(0.052, -0.037, -0.06)

## Tempos do servico, em segundos.
const T_VIRAR := 0.55
const T_PEGAR := 1.0
const T_POUSAR := 0.5
## Andando atras do balcao: desiste de chegar e segue do lugar onde esta.
const T_ANDAR_MAX := 6.0
## O Convidado para a 0,35 m do ponto (Convidado.CHEGOU): chegar e isso.
const CHEGOU := 0.4
## Quanto o copo continua sendo posto por quadro depois do gole: a mao leva a
## mistura de pose (Corpo.MISTURA) e um passo para voltar ao tampo.
const MEXE_DEPOIS := 0.6

const FALAS_DA_MESA: Array[String] = [
	"E o Galo, hein? Esse ano vai.", "Aquele juiz ta comprado, rapaz.",
	"Ce viu o preco da gasolina?", "Amanha tem servico cedo...",
	"Mais uma e eu vou embora.", "O cunhado arrumou emprego na fabrica.",
	"Essa cerveja ta quente, ou e impressao?", "Choveu tudo la em cima da serra.",
	"Eu falei pra ele: nao vende o Fusca.", "Minha mulher vai me matar.",
	"Rapaz, e a eleicao?", "O Cruzeiro nao ganha de ninguem.",
]
const FALAS_DO_BRINDE: Array[String] = ["Saude!", "Tim-tim!", "A nos!", "Ao Galo!",
	"Um brinde!"]
const FALAS_DO_GOL: Array[String] = ["GOOOL!", "E gol! E gol!", "Uhuuu!"]
const FALAS_DO_BALCAO: Array[String] = [
	"Ve mais uma ai, ze.", "Poe na minha conta.", "Ta gelada essa?",
	"Hoje o movimento ta fraco.", "Liga a TV mais alto ai.",
]
const FALAS_DE_QUEM_SERVE: Array[String] = ["Ta na mao.", "Aqui, gelada.",
	"Prontinho.", "Bom proveito."]

# --- o prop (posicoes relativas a `position`, na orientacao do mundo) -----------
## Grupos de assentos com gente: cada mesa e uma lista de {"pos", "mesa"} (o
## tampo na frente, INF se nao ha), o banco do balcao e uma lista de um.
var mesas: Array = []
## Quem esta no banco do balcao (conversa com quem atende). Vazio: ninguem.
var balcao_em := Vector3.INF
## Quem atende, onde fica e por onde anda atras do balcao.
var atendente_em := Vector3.INF
var ronda: Array = []
## A linha do tampo do lado do cliente (onde o pedido pousa) e a linha de
## quem atende, as duas de ponta a ponta.
var tampo: Array = []
var trilho: Array = []
## Onde a mao vai buscar cada coisa: `&"prateleira"` e `&"estufa"` (a estufa
## pede andar ate ela: `&"estufa_pe"`). O freezer e debaixo do balcao.
var fontes: Dictionary = {}
## A TV do salao: quem grita o gol le a partida dela.
var tv_em := Vector3.INF

var _timer: Timer
var _rng := RandomNumberGenerator.new()
var _jogador: Node3D
var _grupos: Array[Dictionary] = []
var _balcao: Convidado
var _atendente: Convidado
var _tv: Televisao
var _casado := false
var _tentativas := 0
var _t_balcao := 0.0
var _vez_balcao := 0
var _gol_antes := false
## Um por bebedor: {"corpo", "gole", "copo"}; no brinde, mais "encontro" (onde
## a mao leva o copo) e "de" (onde ela estava quando o brinde comecou).
var _copos: Array[Dictionary] = []
## Custo medido (microssegundos somados e quadros), para a bancada.
var _us_quadro := 0
var _quadros := 0
var _us_tique := 0
var _tiques := 0
## O tampo na frente de cada bebedor (id do Convidado -> ponto no mundo).
var _tampo_de: Dictionary = {}
var _perto := false

# --- servico ---------------------------------------------------------------------
enum Passo { NADA, ESPERA, INDO, PEGANDO, VOLTANDO, POUSANDO }
var _fila: Array[StringName] = []
var _servindo: StringName = &""
var _passo: Passo = Passo.NADA
var _t := 0.0
var _pousar_em := Vector3.ZERO
var _ficar_em := Vector3.ZERO
var _foco_do_balcao := Vector3.ZERO


static func criar(prop: Dictionary) -> VidaDoBar:
	var v := VidaDoBar.new()
	v.name = "VidaDoBar"
	v.position = prop["pos"]
	v.mesas = prop.get("mesas", [])
	v.balcao_em = prop.get("balcao", Vector3.INF)
	v.atendente_em = prop.get("atendente", Vector3.INF)
	v.ronda = prop.get("ronda", [])
	v.tampo = prop.get("tampo", [])
	v.trilho = prop.get("trilho", [])
	v.fontes = prop.get("fontes", {})
	v.tv_em = prop.get("tv", Vector3.INF)
	v._rng.seed = int(prop.get("semente", 0)) * 2654435761 + 1013904223
	return v


func _ready() -> void:
	set_process(false)
	_timer = Timer.new()
	_timer.wait_time = TIQUE
	_timer.autostart = true
	_timer.timeout.connect(_tique)
	add_child(_timer)


# --- tique -------------------------------------------------------------------------

func _tique() -> void:
	var t0 := Time.get_ticks_usec()
	_viver()
	_us_tique += Time.get_ticks_usec() - t0
	_tiques += 1


func _viver() -> void:
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D
		if _jogador == null:
			return
	var dist := _jogador.global_position.distance_to(global_position)
	var perto := dist <= PERTO
	if perto != _perto:
		_perto = perto
		for c: Dictionary in _copos:
			if is_instance_valid(c["copo"]):
				(c["copo"] as Node3D).visible = perto
	set_process(perto or _passo != Passo.NADA)
	if not perto and _passo == Passo.NADA:
		return
	if not _casado:
		_casar()
		return
	var ouve := dist < OUVIDO
	for g: Dictionary in _grupos:
		_viver_mesa(g, ouve)
	# Os copos parados (o `_process` so anda com quem bebe).
	for c: Dictionary in _copos:
		if is_instance_valid(c["copo"]) and is_instance_valid(c["corpo"]) 				and float(c.get("mexe", 0.0)) <= 0.0:
			_mao_do_copo(c)
			_por_copo(c)
	_papo_do_balcao(ouve)
	_olhar_o_jogo(ouve)


## Acha, entre os irmaos do chunk, quem sentou em cada assento anotado, quem
## atende e a TV. Os props do chunk entram na arvore juntos, mas o Corpo so
## poe a pose no primeiro quadro de animacao: por isso o copo espera o assento.
func _casar() -> void:
	_tentativas += 1
	var gente: Array[Convidado] = []
	for n: Node in get_parent().get_children():
		if n is Convidado:
			gente.append(n as Convidado)
	var faltou := false
	_grupos.clear()
	for mesa: Array in mesas:
		var membros: Array[Convidado] = []
		for a: Dictionary in mesa:
			var c := _perto_de(gente, global_position + Vector3(a["pos"]))
			if c == null:
				faltou = true
				continue
			membros.append(c)
			var m: Vector3 = a.get("mesa", Vector3.INF)
			if m != Vector3.INF:
				_tampo_de[c.get_instance_id()] = global_position + m
		if not membros.is_empty():
			_grupos.append({"gente": membros, "brinde": _rng.randf_range(6.0, BRINDE.y),
				"fala": _rng.randf_range(1.0, PAUSA_FALA.y), "quem": 0})
	if balcao_em != Vector3.INF:
		_balcao = _perto_de(gente, global_position + balcao_em)
	if atendente_em != Vector3.INF:
		_atendente = _perto_de(gente, global_position + atendente_em)
		if _atendente != null:
			_atendente.set_meta(&"vida_do_bar", self)
			_foco_do_balcao = _atendente.foco
			var volta: Array[Vector3] = []
			for rel: Vector3 in ronda:
				volta.append(global_position + rel)
			_atendente.pontos = volta
	if tv_em != Vector3.INF:
		for n: Node in get_tree().get_nodes_in_group(&"televisao"):
			var tv := n as Televisao
			if tv != null and tv.global_position.distance_to(global_position + tv_em) < 1.0:
				_tv = tv
	# Os props nascem juntos; se alguem faltou, e porque nao nasceu (a ficha
	# veio vazia). Tres tentativas e segue com quem veio.
	_casado = not faltou or _tentativas >= 3


func _perto_de(gente: Array[Convidado], onde: Vector3) -> Convidado:
	var melhor: Convidado = null
	var d_melhor := CASAR
	for c: Convidado in gente:
		var d := Vector2(c.global_position.x - onde.x, c.global_position.z - onde.z).length()
		if d < d_melhor and absf(c.global_position.y - onde.y) < 1.0:
			d_melhor = d
			melhor = c
	return melhor


# --- mesa --------------------------------------------------------------------------

func _viver_mesa(g: Dictionary, ouve: bool) -> void:
	var gente: Array[Convidado] = g["gente"]
	# Um gole por pessoa, ou null para quem ainda nao pousou no assento (ou ja
	# tem outra coisa na mao): esse fica fora do brinde, mas conversa.
	var goles: Array = []
	var com_copo: Array[Gole] = []
	for c: Convidado in gente:
		if not is_instance_valid(c):
			return
		var gole := _gole_de(c)
		goles.append(gole)
		if gole != null:
			com_copo.append(gole)
	# O brinde: todos os copos da mesa no mesmo quadro, com a mao livre.
	g["brinde"] = float(g["brinde"]) - TIQUE
	if com_copo.size() >= 2 and float(g["brinde"]) <= 0.0:
		var livres := com_copo.all(func(x: Gole) -> bool: return not x.ativo())
		if livres and not _alguem_falando(gente):
			_marcar_encontro(gente)
			for x: Gole in com_copo:
				x.brindar()
			var quem: Convidado = gente[_rng.randi() % gente.size()]
			if ouve:
				quem.dizer(FALAS_DO_BRINDE[_rng.randi() % FALAS_DO_BRINDE.size()])
				# O tim-tim sai quando os copos se encontram, e nao quando a mao
				# comeca a subir. O timer e da arvore, mas a conexao morre com
				# este no: bar descarregado nao toca.
				get_tree().create_timer(com_copo[0].ate_bater()).timeout.connect(
					_tim_tim.bind(quem.global_position + Vector3(0.0, 1.0, 0.0)))
			g["brinde"] = _rng.randf_range(BRINDE.x, BRINDE.y)
		else:
			g["brinde"] = 1.0
	# A conversa: um fala, os outros olham para ele. Com uma pessoa so (quem
	# assiste a TV), ninguem fala sozinho.
	if gente.size() < 2:
		return
	g["fala"] = float(g["fala"]) - TIQUE
	if float(g["fala"]) > 0.0:
		return
	var i := (int(g["quem"]) + 1 + _rng.randi() % maxi(1, gente.size() - 1)) % gente.size()
	g["quem"] = i
	var fala: Convidado = gente[i]
	g["fala"] = _rng.randf_range(PAUSA_FALA.x, PAUSA_FALA.y)
	if Conversa.ativo and Conversa.quem() in gente:
		return
	for k in gente.size():
		var c: Convidado = gente[k]
		if k != i:
			_olhar(c, fala.global_position)
	_olhar(fala, gente[(i + 1) % gente.size()].global_position)
	if not ouve:
		return
	fala.dizer(FALAS_DA_MESA[_rng.randi() % FALAS_DA_MESA.size()])
	var corpo := fala.corpo()
	var g_fala := goles[i] as Gole
	if corpo != null and (g_fala == null or not g_fala.ativo()) and _rng.randf() < 0.55:
		var gestos: Array[int] = [ReacaoCorpo.GESTO_EXPLICA, ReacaoCorpo.GESTO_ABRE,
			ReacaoCorpo.GESTO_OMBROS, ReacaoCorpo.GESTO_NEGA]
		corpo.reagir(gestos[_rng.randi() % gestos.size()])
	# De vez em quando a mesa ri junto.
	if _rng.randf() < 0.2:
		var ri: Convidado = gente[(i + 1) % gente.size()]
		ri.gargalhar()
		fala.contagiar()


## Onde cada mao vai no brinde: acima do meio da mesa, com o copo a um raio do
## centro para o lado de cada um — os copos se tocam ali. A pega fica a direita
## de cada um pelo afastamento do copo (ele vai do lado da palma, para dentro),
## e e isso tambem que faz o `agarrar` escolher a mao direita: ele pega a mao do
## lado do alvo.
func _marcar_encontro(gente: Array[Convidado]) -> void:
	var centro := Vector3.ZERO
	for c: Convidado in gente:
		centro += c.global_position
	centro /= float(gente.size())
	for c: Convidado in gente:
		var e := _entrada_de(c)
		if e.is_empty():
			continue
		var ate := c.global_position - centro
		ate.y = 0.0
		var ponto := centro + ate.normalized() * 0.035 + c.global_basis.x * COPO_PALMA
		# A posicao do convidado sentado e o chao sob o quadril (o assento e da
		# pose): o encontro fica a um metro dele, um palmo acima do tampo.
		ponto.y = c.global_position.y + ALTURA_DO_BRINDE
		e["encontro"] = ponto
		e.erase("de")


func _entrada_de(c: Convidado) -> Dictionary:
	for e: Dictionary in _copos:
		if e["corpo"] == c.corpo():
			return e
	return {}


## Onde a pega da mao direita descansa: o fundo do copo no tampo, entre a
## pessoa e o meio dele, um palmo a direita. Sem isto a mao ficava no colo da
## pose sentada, e o copo, debaixo do tampo da mesa.
##
## A palma e a do corpo (a da mao direita olha para o meio dele), e nao a lida do
## osso: lida do osso, o alvo mudava com a pose que ele mesmo produz.
func _apoio(c: Convidado, tampo: Vector3) -> Vector3:
	var para := tampo - c.global_position
	para.y = 0.0
	var frente := para.normalized()
	var direita := frente.cross(Vector3.UP)
	var fundo := tampo - frente * minf(0.2, para.length() * 0.5) + direita * 0.1
	fundo.y = tampo.y
	return fundo + direita * COPO_PALMA + Vector3.UP * COPO_MEIO


## A mao do copo, a cada quadro. Parada, pousada no apoio (o `agarrar` leva a
## pega ao ponto em que o fundo do copo toca o tampo). No brinde, do apoio ao
## encontro pelo envelope do `Gole.brinde`. O gole vai por cima disto
## (`Corpo._levar_a_boca` parte da pose que o `agarrar` deixou).
func _mao_do_copo(e: Dictionary) -> void:
	var corpo: Corpo = e["corpo"]
	var g: Gole = e["gole"]
	var repouso: Vector3 = e.get("apoio", Vector3.INF)
	if not e.has("encontro"):
		corpo.agarrar = repouso
		return
	var k := g.brinde()
	if g.estilo != Gole.BRINDE or (not g.ativo() and k <= 0.0):
		corpo.agarrar = repouso
		e.erase("encontro")
		e.erase("de")
		return
	if not e.has("de"):
		e["de"] = repouso if repouso != Vector3.INF else corpo.pega_no_mundo().origin
	corpo.agarrar = (e["de"] as Vector3).lerp(e["encontro"], k)


func _alguem_falando(gente: Array[Convidado]) -> bool:
	if Conversa.ativo:
		for c: Convidado in gente:
			if Conversa.quem() == c:
				return true
	return false


func _tim_tim(onde: Vector3) -> void:
	AudioDirector.tocar(&"copo_brinde", onde, -9.0, _rng.randf_range(0.95, 1.05))


## A cabeca vira para o ponto, pelo pescoco (o corpo sentado nao gira). O olhar
## e na altura do rosto de quem esta sentado: sem o pitch a cabeca ficava reta.
func _olhar(c: Convidado, ponto: Vector3) -> void:
	var corpo := c.corpo()
	if corpo == null:
		return
	var d := ponto - c.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var frente := atan2(-d.x, -d.z)
	corpo.olhar_lateral(angle_difference(c.global_rotation.y, frente), 0.05)


## O relogio do copo desta pessoa, e o copo na mao — so quando ela ja esta
## sentada, porque a direcao do copo sai da mao em repouso.
func _gole_de(c: Convidado) -> Gole:
	var corpo := c.corpo()
	if corpo == null:
		return null
	if corpo.fumo is Gole:
		return corpo.fumo as Gole
	if corpo.fumo != null or corpo.postura_atual() != Corpo.Postura.ASSENTO \
			or corpo.esqueleto() == null:
		return null
	var g := Gole.new(int(c.ficha.get("id", 1)))
	corpo.fumo = g
	corpo.tragando = true
	corpo.alvo_da_pega = ALVO_DO_COPO
	# Filho do convidado (morre com ele), mas no referencial do mundo.
	var copo := PedidoNoBalcao.montar(MoveisDoBar.copo())
	copo.name = "CopoNaMao"
	copo.top_level = true
	c.add_child(copo)
	var e := {"corpo": corpo, "gole": g, "copo": copo}
	if _tampo_de.has(c.get_instance_id()):
		e["apoio"] = _apoio(c, _tampo_de[c.get_instance_id()])
	_copos.append(e)
	_por_copo(e)
	return g


## O copo desta pessoa agora: em pe ao lado da palma, e no gole (`alcance`)
## inclinado com a borda nos labios.
func _por_copo(e: Dictionary) -> void:
	var corpo: Corpo = e["corpo"]
	var g: Gole = e["gole"]
	var copo: Node3D = e["copo"]
	var pega := corpo.pega_no_mundo()
	var palma := -pega.basis.x.normalized()
	palma.y = 0.0
	palma = palma.normalized() if palma.length() > 0.1 else -corpo.global_basis.x
	# O copo segue a MAO de verdade: o que se mistura e o deslocamento dele em
	# relacao a pega (em pe ao lado da palma -> inclinado com a borda na boca),
	# e nao a posicao. Misturando a posicao, o copo chegava a boca antes da mao
	# e ficava boiando entre as duas.
	var desloca := palma * COPO_PALMA - Vector3.UP * COPO_MEIO
	var eixo := Vector3.UP
	var k := smoothstep(0.0, 1.0, g.alcance())
	if k > 0.0:
		var boca := corpo.boca_no_mundo()
		var tras := boca.basis.z.normalized()
		var inclina := deg_to_rad(INCLINA_GOLAO if g.estilo == Gole.GOLAO else INCLINA_GOLE)
		var eixo_gole := (Vector3.UP * cos(inclina) + tras * sin(inclina)).normalized()
		# A borda no labio de baixo, meio centimetro para fora do rosto, e a mao
		# onde o IK a leva (`ALVO_DO_COPO`, no referencial da cabeca).
		var fundo_gole := boca.origin - tras * 0.005 - eixo_gole * COPO_ALTURA
		var mao_gole := boca.origin + boca.basis * ALVO_DO_COPO
		eixo = eixo.slerp(eixo_gole, k)
		desloca = desloca.lerp(fundo_gole - mao_gole, k)
	var fundo := pega.origin + desloca
	# No brinde o braco de quem esta sentado nao chega ao meio da mesa (o IK
	# fica 6 a 10 cm curto): o copo vai 90% do caminho ate o encontro, na ponta
	# dos dedos, e os dois se tocam.
	var kb := g.brinde()
	if kb > 0.0 and e.has("encontro"):
		var direita := corpo.global_basis.x
		var ideal := Vector3(e["encontro"]) - direita * COPO_PALMA - Vector3.UP * COPO_MEIO
		fundo = fundo.lerp(ideal, kb * 0.9)
	var z := palma - eixo * palma.dot(eixo)
	z = z.normalized() if z.length() > 0.01 else Vector3.FORWARD
	copo.global_transform = Transform3D(Basis(eixo.cross(z), eixo, z), fundo)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_passo_do_quadro(delta)
	_us_quadro += Time.get_ticks_usec() - t0
	_quadros += 1


func _passo_do_quadro(delta: float) -> void:
	if _perto:
		for c: Dictionary in _copos:
			if not is_instance_valid(c["copo"]) or not is_instance_valid(c["corpo"]):
				continue
			# Copo parado na mesa nao muda de lugar: so quem esta bebendo ou
			# brindando anda por quadro, e mais meio segundo depois, enquanto a mao
			# volta ao tampo. Os parados sao postos no tique.
			var g: Gole = c["gole"]
			if g.ativo() or c.has("encontro"):
				c["mexe"] = MEXE_DEPOIS
			elif float(c.get("mexe", 0.0)) > 0.0:
				c["mexe"] = float(c["mexe"]) - delta
			else:
				continue
			_mao_do_copo(c)
			_por_copo(c)
	if _passo != Passo.NADA:
		_servir(delta)


# --- balcao e TV -----------------------------------------------------------------

## Quem esta no banco do balcao e quem atende trocam duas falas de tempos em
## tempos — so quando ninguem esta pedindo nada.
func _papo_do_balcao(ouve: bool) -> void:
	if _balcao == null or _atendente == null or not is_instance_valid(_balcao) \
			or not is_instance_valid(_atendente) or _passo != Passo.NADA or Conversa.ativo:
		return
	_t_balcao -= TIQUE
	if _t_balcao > 0.0:
		return
	_t_balcao = _rng.randf_range(PAPO_DO_BALCAO.x, PAPO_DO_BALCAO.y)
	if not ouve or _atendente.global_position.distance_to(_balcao.global_position) > 2.6:
		return
	_olhar(_balcao, _atendente.global_position)
	_balcao.dizer(FALAS_DO_BALCAO[_rng.randi() % FALAS_DO_BALCAO.size()])
	_atendente.encarar(_balcao.global_position)
	_vez_balcao += 1


## Saiu gol na TV: quem esta no bar vira para ela, uns levantam os bracos, uns
## poem a mao na cabeca. Le o estado da partida, que ja e publico.
func _olhar_o_jogo(ouve: bool) -> void:
	if _tv == null or not is_instance_valid(_tv) or _tv.partida() == null:
		return
	var gol := _tv.partida().estado == PartidaPS2.Estado.GOL
	if gol and not _gol_antes:
		var torcida: Array[Convidado] = []
		for g: Dictionary in _grupos:
			for c: Convidado in (g["gente"] as Array[Convidado]):
				if is_instance_valid(c):
					torcida.append(c)
		if _balcao != null and is_instance_valid(_balcao):
			torcida.append(_balcao)
		var gritou := false
		for c: Convidado in torcida:
			_olhar(c, _tv.global_position)
			var corpo := c.corpo()
			if corpo == null or _rng.randf() < 0.35:
				continue
			var comemora := _rng.randf() < 0.65
			corpo.reagir(ReacaoCorpo.REACAO_MAOS_ALTO if comemora
				else ReacaoCorpo.REACAO_MAO_NA_CABECA)
			if comemora and ouve and not gritou:
				c.dizer(FALAS_DO_GOL[_rng.randi() % FALAS_DO_GOL.size()])
				gritou = true
	_gol_antes = gol


# --- servico ----------------------------------------------------------------------

## Um pedido pago no balcao (VendaDoBar). Entra na fila; quem atende serve um
## de cada vez, depois que a conversa fecha.
func pedir(id: StringName) -> void:
	_fila.append(id)
	if _passo == Passo.NADA:
		_proximo()


func _proximo() -> void:
	if _fila.is_empty() or _atendente == null or not is_instance_valid(_atendente):
		_passo = Passo.NADA
		_servindo = &""
		set_process(_perto)
		return
	_servindo = _fila.pop_front()
	_passo = Passo.ESPERA
	_t = 0.0
	set_process(true)


func _servir(delta: float) -> void:
	if _atendente == null or not is_instance_valid(_atendente):
		_fila.clear()
		_proximo()
		return
	# Enquanto o jogador conversa com quem atende, o servico espera.
	if Conversa.ativo and Conversa.quem() == _atendente:
		return
	_t += delta
	var corpo := _atendente.corpo()
	match _passo:
		Passo.ESPERA:
			_comecar()
		Passo.INDO:
			if _chegou(_ficar_em) or _t > T_ANDAR_MAX:
				_parar_e_olhar(_alvo_da_fonte())
				_passo = Passo.PEGANDO
				_t = -T_VIRAR
		Passo.PEGANDO:
			if _t < 0.0:
				return
			var de := _de_onde()
			if de == &"freezer":
				if not corpo.agachado:
					corpo.agachado = true
					AudioDirector.tocar(&"geladeira_abre", _atendente.global_position, -10.0)
			elif corpo.agarrar == Vector3.INF:
				corpo.agarrar = _alvo_da_fonte()
			if _t >= T_PEGAR:
				if corpo.agachado:
					corpo.agachado = false
					AudioDirector.tocar(&"geladeira_fecha", _atendente.global_position, -12.0)
				corpo.agarrar = Vector3.INF
				_ficar_em = _ponto_de_servir()
				_andar_ate(_ficar_em)
				_passo = Passo.VOLTANDO
				_t = 0.0
		Passo.VOLTANDO:
			if _chegou(_ficar_em) or _t > T_ANDAR_MAX:
				_parar_e_olhar(_pousar_em)
				_passo = Passo.POUSANDO
				_t = -T_VIRAR
		Passo.POUSANDO:
			if _t < 0.0:
				return
			corpo.agarrar = _pousar_em + Vector3(0.0, 0.06, 0.0)
			if _t >= T_POUSAR:
				corpo.agarrar = Vector3.INF
				_entregar()
				_atendente.encarar(_foco_do_balcao)
				_atendente.liberar()
				_proximo()


func _comecar() -> void:
	# O pedido pousa na frente de quem pediu: o ponto do tampo mais perto do
	# jogador, e quem atende vai ate a altura dele.
	_pousar_em = _no_segmento(tampo, _jogador.global_position if _jogador != null
		else _atendente.global_position)
	var de := _de_onde()
	if de == &"estufa":
		_ficar_em = global_position + Vector3(fontes.get(&"estufa_pe", Vector3.ZERO))
	else:
		_ficar_em = _no_segmento(trilho, _atendente.global_position)
	_andar_ate(_ficar_em)
	_passo = Passo.INDO
	_t = 0.0


func _de_onde() -> StringName:
	return StringName(VendaDoBar.item(_servindo).get("de", &"freezer"))


func _alvo_da_fonte() -> Vector3:
	var de := _de_onde()
	if de == &"freezer":
		# Debaixo do balcao: olha para o tampo e abaixa.
		return _no_segmento(tampo, _atendente.global_position) + Vector3(0.0, -0.4, 0.0)
	if de == &"prateleira":
		# A prateleira corre paralela ao trilho, na parede de tras: a garrafa de
		# cachaca e a da altura de quem esta, na prateleira do meio.
		var parede := global_position + Vector3(fontes.get(&"prateleira", Vector3.ZERO))
		return _no_segmento(trilho, _atendente.global_position) \
			+ (parede - _no_segmento(trilho, parede))
	return global_position + Vector3(fontes.get(&"estufa", Vector3.ZERO))


func _ponto_de_servir() -> Vector3:
	return _no_segmento(trilho, _pousar_em)


## Anda ate `ponto` pelas proprias pernas: um ponto so na ronda e a espera
## curta de `liberar` fazem o Convidado sair andando no proximo meio segundo.
func _andar_ate(ponto: Vector3) -> void:
	var um: Array[Vector3] = [ponto]
	_atendente.pontos = um
	if not _atendente.estacionado():
		_atendente.estacionar(_atendente.global_position,
			_atendente.global_position - _atendente.global_basis.z)
	_atendente.liberar()


func _chegou(ponto: Vector3) -> bool:
	var d := _atendente.global_position - ponto
	d.y = 0.0
	return d.length() < CHEGOU


## Para onde esta (sem teleporte: `estacionar` no proprio lugar) e vira devagar
## para `ponto` — o giro instantaneo do estacionar e so para a direcao atual.
func _parar_e_olhar(ponto: Vector3) -> void:
	var volta: Array[Vector3] = []
	for rel: Vector3 in ronda:
		volta.append(global_position + rel)
	_atendente.estacionar(_atendente.global_position,
		_atendente.global_position - _atendente.global_basis.z)
	_atendente.pontos = volta
	_atendente.encarar(ponto)


func _entregar() -> void:
	var p := PedidoNoBalcao.novo(_servindo)
	get_parent().add_child(p)
	var olhar := (_jogador.global_position if _jogador != null else _pousar_em) - _pousar_em
	p.global_position = _pousar_em
	p.rotation.y = atan2(olhar.x, olhar.z)
	var som := &"pires_balcao" if _de_onde() == &"estufa" else &"garrafa_balcao"
	AudioDirector.tocar(som, _pousar_em, -6.0)
	if _jogador != null and _jogador.global_position.distance_to(_pousar_em) < OUVIDO:
		_atendente.dizer(FALAS_DE_QUEM_SERVE[_rng.randi() % FALAS_DE_QUEM_SERVE.size()])


## O ponto de um segmento [a, b] (relativos) mais perto de `p`, no mundo.
func _no_segmento(seg: Array, p: Vector3) -> Vector3:
	if seg.size() < 2:
		return p
	var a := global_position + Vector3(seg[0])
	var b := global_position + Vector3(seg[1])
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * t


# --- para a bancada (TesteBar) ------------------------------------------------------

## Quantas pessoas ganharam copo, quantos goles ja deram, quantas mesas, e se ha
## quem atende e TV.
func censo() -> Dictionary:
	var copos := 0
	var goles := 0
	var brindes := 0
	for c: Convidado in bebedores():
		var g := c.corpo().fumo as Gole
		if g != null:
			copos += 1
			goles += g.goles
			if g.estilo == Gole.BRINDE and g.ativo():
				brindes += 1
	return {"casado": _casado, "grupos": _grupos.size(), "copos": copos, "goles": goles,
		"brindando": brindes, "atendente": _atendente != null, "tv": _tv != null,
		"servindo": _passo != Passo.NADA,
		"us_por_quadro": float(_us_quadro) / float(maxi(1, _quadros)),
		"us_por_tique": float(_us_tique) / float(maxi(1, _tiques))}


func bebedores() -> Array[Convidado]:
	var saida: Array[Convidado] = []
	for g: Dictionary in _grupos:
		for c: Convidado in (g["gente"] as Array[Convidado]):
			if is_instance_valid(c) and c.corpo() != null:
				saida.append(c)
	return saida


func atendente() -> Convidado:
	return _atendente


## Onde fica quem pede: meio metro para fora do tampo, em `t` do comprimento
## dele (0 e a ponta da rua, 1 a do fundo).
func lugar_do_cliente(t: float = 0.5) -> Vector3:
	if tampo.size() < 2 or trilho.size() < 2:
		return global_position
	var meio := Vector3(tampo[0]).lerp(Vector3(tampo[1]), t)
	var fora := meio - (Vector3(trilho[0]) + Vector3(trilho[1])) * 0.5
	fora.y = 0.0
	var p := global_position + meio + fora.normalized() * 0.55
	p.y = global_position.y
	return p


## Brinda a primeira mesa de duas ou mais com as maos livres. Devolve quem
## brindou (vazio: ninguem estava com a mao livre).
func forcar_brinde() -> Array[Convidado]:
	for g: Dictionary in _grupos:
		if (g["gente"] as Array).size() < 2:
			continue
		g["brinde"] = 0.0
		var antes := censo()["brindando"] as int
		_viver_mesa(g, true)
		if int(censo()["brindando"]) > antes:
			var quem: Array[Convidado] = g["gente"]
			return quem
	return []
