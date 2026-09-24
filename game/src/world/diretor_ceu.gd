## Autoload `Ceu`. Quem poe nuvem e temporal na cena que estiver em cartaz.
##
## Por que um diretor, e nao nos na cena
## -------------------------------------
## `scenes/test/cidade.tscn` tem trabalho nao commitado de outra sessao, e a
## regra de convivencia deste plano diz que trabalho novo mora em arquivo novo.
## Mas o motivo de fundo e melhor que o operacional: nuvem e relampago sao
## recursos do preset MODERNO, e nenhum dos dois pode existir no PS1 STYLE sem
## quebrar o criterio A2. Uma cena com os nos dentro precisaria escondê-los; um
## diretor simplesmente nao os cria.
##
## O mesmo desenho das sondas de reflexo (`SondasReflexo`), pelo mesmo motivo: a
## cidade e montada por streaming e nao tem um lugar fixo onde pendurar algo que
## vale para o mundo inteiro.
##
## Por que o relampago e agendado aqui e disparado la
## --------------------------------------------------
## O `Relampago` sabe fazer UM raio: o clarao, o envelope de piscadas e o trovao
## que chega depois. Ele nao sabe — e nao deve saber — com que frequencia cai
## raio num temporal, porque isso e clima, e clima e do preset. Quem junta as
## duas coisas e este no.
##
## `parar()` e `limpar()` existem pela regressao visual: um relampago no meio de
## uma captura muda a foto inteira, e duas execucoes da mesma build nunca
## cairiam no mesmo quadro. A rota de captura desliga o ceu pelo mesmo caminho
## que ja desliga transito e multidao.
class_name DiretorCeu
extends Node

const GRUPO_FOG := &"fog_controller"
## O relampago entra por CAMINHO, e nao pelo nome da classe.
##
## `relampago.gd` nasceu na frente da Estrada Velha e ainda nao esta no HEAD.
## Referenciar a classe aqui faria o HEAD deixar de compilar (criterio A1) no
## dia em que este arquivo fosse commitado sozinho. Sem o arquivo, a cidade so
## fica sem temporal.
const CAMINHO_RELAMPAGO := "res://src/world/relampago.gd"
const GRUPO_NUVENS := &"nuvens"
const GRUPO_RELAMPAGO := &"relampago"

## Quadros entre duas conferencias da cena. Trocar de cena e raro e entrar num
## interior tambem; conferir a cada quadro seria varrer a arvore 60 vezes por
## segundo para achar a mesma resposta.
const PASSO := 20

## A camada do MODERNO e mais alta e mais larga que a do PS1.
##
## A 28 m uma nuvem de 25 m de raio passa por cima da cabeca como um teto, e o
## raymarch nao tem como ler como volume: o que se ve e o interior da esfera.
## A 70 m a mesma massa cabe no quadro inteira, com topo e barriga na tela ao
## mesmo tempo — que e a unica vista em que "clara em cima, escura embaixo"
## significa alguma coisa.
const ALTITUDE_MODERNO := 70.0
const AREA_MODERNO := Vector3(160.0, 8.0, 160.0)
## Menos quads, e maiores. Com volume, cada quad e uma massa de ar com dentro;
## cento e vinte delas empilhadas viram uma placa opaca e ainda custam cento e
## vinte raymarches sobrepostos.
const QUANTAS_MODERNO := 64
## Diametro de cada massa, em metros. Maior que o do PS1: com o achatamento, a
## massa e larga e baixa, e e a sobreposicao de varias que faz a camada.
const TAMANHO_MIN := 44.0
const TAMANHO_MAX := 90.0

## Segundos entre dois raios, no temporal. Sorteado nesta faixa.
##
## Um raio a cada meio minuto e uma tempestade de verdade; um a cada cinco
## segundos e efeito de parque tematico. O piso alto tambem protege o jogo: o
## clarao e uma direcional de energia 4,2, e piscar isso de perto cansa.
const INTERVALO_MIN := 22.0
const INTERVALO_MAX := 75.0
## Distancia do raio, em quilometros. E ela que vira o atraso do trovao.
const KM_MIN := 0.4
const KM_MAX := 5.2

var _quadro := 0
var _cena: Node
var _nuvens: Nuvens
var _relampago: Node3D
var _ate_o_proximo := 0.0
var _parado := false
## `--sem-ceu`: nem nuvem nem temporal. E o par das medidas de custo e de
## regressao; `parar()` so desliga o temporal.
var _sem_ceu := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Semente fixa: a sequencia de raios de uma sessao e sempre a mesma. Nao e
	# so gosto por determinismo — e o que permite reproduzir um defeito que so
	# aparece no terceiro raio.
	_rng.seed = 20260916
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--sem-ceu":
			_sem_ceu = true
			_parado = true
	Settings.changed.connect(_conferir)


func _process(delta: float) -> void:
	_quadro += 1
	if _quadro % PASSO == 0:
		_conferir()
	if _parado or _relampago == null or not is_instance_valid(_relampago):
		return
	_ate_o_proximo -= delta
	if _ate_o_proximo > 0.0:
		return
	_ate_o_proximo = _rng.randf_range(INTERVALO_MIN, INTERVALO_MAX)
	_relampago.call(&"disparar", _rng.randf_range(KM_MIN, KM_MAX))


## Monta ou desmonta o ceu conforme o estilo e o clima em vigor.
func _conferir() -> void:
	var cena := get_tree().current_scene
	if cena == null:
		return
	if cena != _cena:
		# Cena nova: as referencias antigas morreram com a anterior.
		_cena = cena
		_nuvens = null
		_relampago = null
	var fog := get_tree().get_first_node_in_group(GRUPO_FOG) as FogController
	if fog == null:
		return
	var preset := fog.preset_atual()
	if preset == null:
		return

	var moderno := Settings.luz_por_pixel and not _sem_ceu
	_cuidar_das_nuvens(cena, moderno and preset.nuvens >= 0.05)
	_cuidar_do_relampago(cena, moderno and preset.tem_chuva and not _parado)
	_cuidar_da_serra(cena)


## A serra do horizonte (SerraDaCidade), nos dois estilos: e cenario, e nao
## recurso do MODERNO. So na cena que tem cidade de streaming; ela mesma se
## esconde no ceu proprio da Estrada Velha e dentro de interior.
func _cuidar_da_serra(cena: Node) -> void:
	if _sem_ceu:
		return
	var raiz := ChunkManager.raiz
	if raiz == null or not is_instance_valid(raiz) or not cena.is_ancestor_of(raiz):
		return
	if get_tree().get_first_node_in_group(CeuVivo.GRUPO) == null:
		# Passaro, aviao e o som de longe: mesma regra da serra, e para junto
		# com o temporal quando a rota de captura pede.
		var vivo := CeuVivo.new()
		cena.add_child(vivo)
		if _parado:
			vivo.parar()
		print("[ceu] ceu vivo: urubu, bando, teco-teco e jato")
	if get_tree().get_first_node_in_group(SerraDaCidade.GRUPO) != null:
		return
	cena.add_child(SerraDaCidade.new())
	print("[ceu] serra da cidade no horizonte")


func _cuidar_das_nuvens(cena: Node, quer: bool) -> void:
	var existe := get_tree().get_first_node_in_group(GRUPO_NUVENS) as Nuvens
	if quer:
		if existe != null:
			_nuvens = existe
			return
		var n := Nuvens.new()
		n.name = "NuvensModernas"
		n.altitude = ALTITUDE_MODERNO
		n.area = AREA_MODERNO
		n.quantidade_max = QUANTAS_MODERNO
		cena.add_child(n)
		var proc := n.process_material as ParticleProcessMaterial
		if proc != null:
			proc.scale_min = TAMANHO_MIN
			proc.scale_max = TAMANHO_MAX
		_nuvens = n
		print("[ceu] %d nuvens com volume a %.0f m" % [QUANTAS_MODERNO, ALTITUDE_MODERNO])
		return
	# So desmonta o que ESTE no criou. Uma cena que traga a propria camada de
	# nuvens (a Estrada Velha tem ceu proprio) nao pode ser desmontada por aqui.
	if _nuvens != null and is_instance_valid(_nuvens):
		_nuvens.queue_free()
	_nuvens = null


func _cuidar_do_relampago(cena: Node, quer: bool) -> void:
	var existe := get_tree().get_first_node_in_group(GRUPO_RELAMPAGO) as Node3D
	if quer:
		if existe != null:
			_relampago = existe
			return
		if not ResourceLoader.exists(CAMINHO_RELAMPAGO):
			return
		var r := (load(CAMINHO_RELAMPAGO) as GDScript).new() as Node3D
		if r == null:
			return
		r.name = "RelampagoDaCidade"
		# O grupo tambem daqui: e ele que impede um segundo temporal numa cena
		# que ja traga o seu, e nao da para contar que todo relampago se inscreva.
		r.add_to_group(GRUPO_RELAMPAGO)
		cena.add_child(r)
		_relampago = r
		# O primeiro raio nao cai no segundo zero: chegar numa cena e ver um
		# clarao imediato le como bug de carga, nao como tempestade.
		_ate_o_proximo = _rng.randf_range(INTERVALO_MIN * 0.5, INTERVALO_MAX)
		print("[ceu] temporal ligado: proximo raio em %.0f s" % _ate_o_proximo)
		return
	if _relampago != null and is_instance_valid(_relampago):
		_relampago.queue_free()
	_relampago = null
	# O clarao pode ter ficado aceso no meio do envelope. Sem isto, apagar o
	# temporal deixaria a nuvem branca para sempre.
	RenderingServer.global_shader_parameter_set(&"psx_relampago", 0.0)


## Dispara um raio agora, a `km` de distancia. Para bancada e para cutscene.
func disparar(km: float = 1.2) -> void:
	if _relampago != null and is_instance_valid(_relampago):
		_relampago.call(&"disparar", km)


## Ha temporal montado agora? Para teste e relatorio.
func tem_temporal() -> bool:
	return _relampago != null and is_instance_valid(_relampago)


## Quantas nuvens estao no ceu agora. Para teste e relatorio.
func quantas_nuvens() -> int:
	if _nuvens == null or not is_instance_valid(_nuvens):
		return 0
	return _nuvens.amount if _nuvens.emitting else 0


## Para o temporal. A rota de captura chama isto pelo mesmo caminho que ja para
## transito e multidao: raio no meio da foto e a maior fonte de ruido que existe.
func parar() -> void:
	_parado = true
	_cuidar_do_relampago(get_tree().current_scene, false)
	# A nuvem tambem para. A forma dela corre com o relogio da cena, e duas
	# execucoes da mesma build chegam a mesma parada em instantes diferentes.
	if _nuvens != null and is_instance_valid(_nuvens):
		_nuvens.congelar()
	# Urubu e aviao tambem: um passaro no meio da foto e ruido de regressao.
	var vivo := get_tree().get_first_node_in_group(CeuVivo.GRUPO) as CeuVivo
	if vivo != null:
		vivo.parar()


## Volta a chover raio.
func voltar() -> void:
	_parado = false
	var vivo := get_tree().get_first_node_in_group(CeuVivo.GRUPO) as CeuVivo
	if vivo != null:
		vivo.voltar()
	_conferir()
