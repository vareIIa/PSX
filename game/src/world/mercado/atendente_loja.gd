## Quem esta atras do balcao da loja. Fica no posto.
##
## E um Convidado — tem ficha, voz, carteira, conversa — com tres diferencas, e
## as tres sao o que separa um funcionario de um visitante:
##
##   posto      nao sai de tras do balcao. O Convidado na CasaViva vai atras de
##              quem quer conversar e sai da frente quando o jogador encosta; o
##              atendente que faz isso atravessa o balcao, e nao volta.
##   conversa   com quem para NA FRENTE do caixa, e do lugar dele: o balcao fica
##              entre os dois, como fica numa loja.
##   porta      o dim-dom da porta automatica e ele levantando a cabeca. Quem
##              entra ouve "boa noite" — do cliente de sempre e do jogador.
##
## O resto — pegar a compra, passar no leitor, dar o troco — e da F3 e da F4.
class_name AtendenteLoja
extends Convidado

const SAUDACOES: Array[String] = ["Boa noite.", "Boa noite!", "Noite.", "Opa, boa noite."]
const NO_CAIXA: Array[String] = ["Pois nao?", "Pode falar.", "Vai querer mais alguma coisa?"]
## Quem esta a menos disto do atendente, do outro lado do balcao, esta no caixa.
const CAIXA := 2.0

var _posto := Vector3.INF
var _posto_giro: float = 0.0
var _falou_caixa := false
var _porta_loja: PortaAutomatica
var _olhar_ate: float = 0.0
var _olhar_para := Vector3.ZERO


func _ready() -> void:
	super()
	_posto = global_position
	Interiores.entrou.connect(_ao_entrar_jogador)
	# A porta e do predio, e pode nascer depois da loja: procura no primeiro
	# quadro em que o atendente ganha vida, e de novo se ela for recriada.
	call_deferred(&"_achar_porta")


func _exit_tree() -> void:
	if Interiores.entrou.is_connected(_ao_entrar_jogador):
		Interiores.entrou.disconnect(_ao_entrar_jogador)


func _achar_porta() -> void:
	var perto := 25.0
	for no: Node in get_tree().get_nodes_in_group(&"porta_automatica"):
		var p := no as PortaAutomatica
		if p == null:
			continue
		var d := p.global_position.distance_to(global_position)
		if d < perto:
			perto = d
			_porta_loja = p
	if _porta_loja != null and not _porta_loja.alguem_entrou.is_connected(_ao_entrar_alguem):
		_porta_loja.alguem_entrou.connect(_ao_entrar_alguem)


# --- o posto ------------------------------------------------------------------

## Parado com a espera vencida: volta ao posto se saiu dele, e olha para a frente
## do balcao. Nunca sorteia um uso nem um ponto.
func _decidir_na_casa() -> void:
	if _posto != Vector3.INF and global_position.distance_to(_posto) > 0.35:
		_ir(_posto)
		return
	_espera = _rng.randf_range(6.0, 14.0)
	_encarar(foco)


## Conversa so com quem para no caixa, e sem sair do lugar.
func _procurar_papo() -> bool:
	if _espera > 1.5 or _rng.randf() > 0.006:
		return false
	for outro: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := outro as Convidado
		if c == null or c == self or not is_instance_valid(c):
			continue
		if not c.esta_livre() or c._estado != Estado.PARADO:
			continue
		if c.global_position.distance_to(global_position) > CAIXA:
			continue
		var duracao := _rng.randf_range(DURACAO_PAPO.x, DURACAO_PAPO.y)
		iniciar_papo(c, duracao)
		c.iniciar_papo(self, duracao)
		return true
	return false


## A cabeca acompanha o jogador, e quem chega no caixa ouve "pois nao". Nunca
## sai da frente: o jogador encostado nele esta do lado de dentro do balcao, e
## quem tem de sair dali e o jogador.
func _reagir_ao_jogador(delta: float) -> void:
	if _jogador == null or _estado == Estado.ATENDENDO:
		return
	var alvo := _jogador.global_position
	if _olhar_ate > 0.0:
		_olhar_ate -= delta
		alvo = _olhar_para
	var d := alvo - global_position
	d.y = 0.0
	var dist := (_jogador.global_position - global_position).length()
	if dist > 7.0 and _olhar_ate <= 0.0:
		_corpo.olhar_lateral(0.0)
		if dist > 9.0:
			_falou_caixa = false
		return
	_corpo.olhar_lateral(angle_difference(global_rotation.y, atan2(-d.x, -d.z)))
	if not _falou_caixa and dist < CAIXA and _estado == Estado.PARADO \
			and _casa != null and _casa.pode_cumprimentar():
		_falou_caixa = true
		dizer(NO_CAIXA[_rng.randi() % NO_CAIXA.size()])


# --- a porta ------------------------------------------------------------------

func _ao_entrar_jogador() -> void:
	if not is_inside_tree() or not can_process():
		return
	# So na loja da rua. No comodo teleportado a entrada e cena da abertura, que
	# tem as falas dela, e um "boa noite" solto passaria por cima.
	if not Interiores.no_mundo or Interiores.tipo_atual() != &"mercado" \
			or _jogador == null:
		return
	if _jogador.global_position.distance_to(global_position) > 20.0:
		return
	_saudar(_jogador)


func _ao_entrar_alguem(quem: Node3D) -> void:
	if quem == _jogador or not can_process():
		return
	# O freguês de sempre ganha um "noite" de passagem, e nem sempre: com o sino
	# e a saudacao a cada um, a loja cheia viraria uma ladainha.
	if _rng.randf() < 0.55:
		_saudar(quem)


func _saudar(quem: Node3D) -> void:
	# Meio segundo depois do sino: e o tempo de levantar a cabeca.
	await get_tree().create_timer(_rng.randf_range(0.45, 0.9)).timeout
	if not is_instance_valid(self) or not is_instance_valid(quem) or not can_process():
		return
	if _estado == Estado.CONVERSANDO or _estado == Estado.ATENDENDO:
		return
	_olhar_para = quem.global_position + Vector3(0.0, 1.5, 0.0)
	_olhar_ate = 2.2
	dizer(SAUDACOES[_rng.randi() % SAUDACOES.size()])
	# Levanta a cabeca e acena com ela: o "boa noite" de balcao.
	if _corpo != null and _corpo.reacao() == 0:
		_corpo.reagir(ReacaoCorpo.GESTO_CONCORDA)
		if _corpo.rosto != null:
			_corpo.rosto.reagir(Rosto.Expressao.SIMPATIA, 1.6)
