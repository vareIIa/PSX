## Quem esta no andar 10, e o que dizem la.
##
## Jota e Helmer sao os fazendeiros da lavoura, e nao ha uma segunda copia
## deles la em cima: quando a cabine parte para o 10, os dois saem da rotina e
## aparecem no quarto; quando ela parte para o 1, ja estao esperando na porta do
## elevador. A viagem leva onze segundos e eles "vieram de escada" — e e a unica
## explicacao que o jogo da, na primeira descida, pela boca do Jota.
##
## As falas da primeira subida sao uma cena curta, em legenda, uma frase de cada
## vez e com quem fala virado para o jogador. Nas subidas seguintes sai uma frase
## so: ninguem conta a mesma historia duas vezes. O bloco inteiro continua a mao
## na conversa, no assunto "E ESSA PLANTA AI?" (FalasNpc.SUPER_MACONHA).
class_name SuperQuarto
extends Node3D

## Onde os dois ficam la em cima e embaixo, em coordenada do comodo. Em cima,
## debaixo da placa "SO O JOTA E O HELMER", de frente para a porta da cabine.
## Embaixo, um de cada lado da grade, esperando.
const EM_CIMA: Array[Vector3] = [Vector3(5.1, 0.0, 12.9), Vector3(6.9, 0.0, 12.7)]
const EMBAIXO: Array[Vector3] = [Vector3(4.9, 0.0, 13.8), Vector3(7.1, 0.0, 13.6)]

## A cena da primeira subida. [quem, frase]; 0 e Jota, 1 e Helmer.
const CENA: Array = [
	[0, "Essa aqui nao e pra vender na praca nao."],
	[0, "Dois trago e o cliente fica com olho de gato: enxerga no escuro, atravessa o beco sem tropecar no meio-fio."],
	[1, "Olho de gato e em nove de cada dez. O decimo enxerga som. A gente ainda nao sabe o que fazer com esse."],
	[0, "Tem a linha de cima tambem. Metade dos cliente explode..."],
	[0, "...e pros mais ousado, voam."],
	[1, "A gente separou por prateleira: explode na de baixo, voa na de cima. Ja trocou uma vez. Foi um dia comprido."],
	[0, "Quem voa sempre volta. Nunca no mesmo bairro, mas volta."],
]
## Uma frase por subida, depois da primeira.
const DE_NOVO: Array = [
	[0, "Ja testei no gato da vizinha. Ficou com olho de gente. Deu errado ao contrario."],
	[1, "Nao encosta na planta. Ela lembra."],
	[0, "Voltou? Os que voam tambem voltam."],
	[1, "Hoje ninguem explodiu. Ainda."],
]
const NOMES: PackedStringArray = ["JOTA", "HELMER"]

## Altura do piso do andar 10, em coordenada do comodo.
@export var piso: float = 25.15

## Por sessao de jogo, e nao por visita ao comodo: sair e entrar de novo na
## estufa nao pode repetir a cena inteira.
static var _subidas := 0
static var _desceu_uma_vez := false

var _dupla: Array[Convidado] = []
var _em_cima := false
var _cena := 0
var _relogio := 0.0
var _colas: MeshInstance3D
var _planta: Interativo


func _ready() -> void:
	add_to_group(&"super_quarto")
	_montar_colheita()
	# O elevador e irmao, e pode nascer depois deste no.
	_ligar.call_deferred()


func _ligar() -> void:
	var el := get_tree().get_first_node_in_group(&"elevador") as Elevador
	if el == null:
		push_warning("SuperQuarto: sem elevador no comodo")
		return
	el.partiu.connect(_ao_partir)
	el.chegou.connect(_ao_chegar)


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = 0.3
	# A planta volta a dar enquanto o jogador esta em qualquer lugar: quem conta
	# o tempo e o EntregasDaSuper, e aqui so se le.
	var pronta := EntregasDaSuper.planta_pronta()
	_colas.visible = pronta
	_planta.rotulo = "Colher a Super" if pronta 		else "Crescendo (umas %d h)" % EntregasDaSuper.horas_para_crescer()
	if not _em_cima:
		return
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return
	for c in _dupla:
		if is_instance_valid(c):
			c.encarar(jogador.global_position)


## A cola que se colhe e o [E] na planta.
func _montar_colheita() -> void:
	var p := EstufaBuilder.PLANTA + Vector3(0.0, piso, 0.0)
	var sup: Dictionary = {}
	EstufaBuilder.colas_da_colheita(sup, p)
	_colas = MeshInstance3D.new()
	_colas.name = "Colas"
	_colas.mesh = PSXMesh.dados_para_mesh(sup[EstufaBuilder.MAT_FOLHA])
	_colas.material_override = load("res://resources/materials/mat_estufa_folha.tres") as Material
	_colas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_colas)
	_planta = Interativo.new()
	_planta.name = "ColherSuper"
	_planta.position = p + Vector3(0.0, 1.3, 0.0)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.3, 2.4, 1.3)
	forma.shape = caixa
	_planta.add_child(forma)
	add_child(_planta)
	_planta.acionado.connect(_ao_colher)


func planta() -> Interativo:
	return _planta


func colas_visiveis() -> bool:
	return _colas.visible


func _ao_colher(_quem: Node) -> void:
	if not EntregasDaSuper.planta_pronta():
		Cinema.fala("HELMER: Ainda nao. Da umas %d horas." % EntregasDaSuper.horas_para_crescer())
		return
	var n := EntregasDaSuper.colher()
	if n <= 0:
		Cinema.fala("Nao cabe mais nada no bolso.")
		return
	_colas.visible = false
	AudioDirector.tocar(&"pegar", _planta.global_position, -3.0)
	Cinema.fala("HELMER: %d doses. Entrega e com a gente: e so passar pra mim ou pro Jota." % n)


## Jota e Helmer, pela marca de personagem da ficha. Os contratados da rua
## ficam na lavoura: o quarto e dos dois.
func _achar_dupla() -> Array[Convidado]:
	var dupla: Array[Convidado] = [null, null]
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or c.ficha.is_empty():
			continue
		match RegistroCivil.personagem_de(int(c.ficha["id"])):
			&"jota":
				dupla[0] = c
			&"helmer":
				dupla[1] = c
	return dupla


func _ao_partir(para: int) -> void:
	_cena += 1
	var minha := _cena
	_em_cima = false
	# Tres segundos: o bastante para a cabine ter saido do campo de visao de
	# quem ficou. Trocar na partida fazia o Jota sumir na frente do jogador.
	await get_tree().create_timer(3.0).timeout
	if minha != _cena:
		return
	_dupla = _achar_dupla()
	var raiz := get_parent() as Node3D
	var porta := raiz.to_global(Vector3(EstufaBuilder.ELEVADOR.x, 0.0,
		EstufaBuilder.VAO_Z.x + 0.6))
	for k in 2:
		var c := _dupla[k]
		if c == null:
			continue
		if para == 10:
			var onde := raiz.to_global(EM_CIMA[k] + Vector3(0.0, piso, 0.0))
			c.estacionar(onde, porta + Vector3(0.0, piso, 0.0))
		else:
			c.estacionar(raiz.to_global(EMBAIXO[k]), porta)
	_em_cima = para == 10
	FalasNpc.andar_dez = _em_cima


func _ao_chegar(andar: int) -> void:
	var minha := _cena
	if andar == 10:
		var fala: Array = CENA if _subidas == 0 else [DE_NOVO[(_subidas - 1) % DE_NOVO.size()]]
		_subidas += 1
		await get_tree().create_timer(1.2).timeout
		await _dizer(fala, minha)
		return
	# Embaixo: a explicacao, uma vez, e cada um volta para o seu vaso.
	if not _desceu_uma_vez:
		_desceu_uma_vez = true
		await get_tree().create_timer(0.6).timeout
		await _dizer([[0, "A gente veio de escada."]], minha)
	else:
		await get_tree().create_timer(1.5).timeout
	if minha != _cena:
		return
	for c in _dupla:
		if is_instance_valid(c):
			c.liberar()
	_dupla.clear()


## Uma frase de cada vez, cada uma com o tempo de leitura dela. Para no meio se
## a cabine partir de novo: `minha` e o numero da viagem em que a cena comecou.
func _dizer(falas: Array, minha: int) -> void:
	for f: Array in falas:
		if minha != _cena:
			return
		var quem: int = f[0]
		var texto: String = f[1]
		var c: Convidado = _dupla[quem] if quem < _dupla.size() else null
		if is_instance_valid(c):
			c.dizer(texto)
		Cinema.fala("%s: %s" % [NOMES[quem], texto])
		await get_tree().create_timer(Cinema.tempo_de_leitura(texto) + 0.5).timeout
