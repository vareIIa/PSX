## Um pedestre atravessando uma rua (PLANO_TRANSITO_AAA, Passo 3).
##
## O pedestre de antes descia da calcada assim que chegava na esquina, com
## qualquer luz e com carro vindo, e o carro so o via se ele cruzasse um dos tres
## raios retos do bico. "Nunca atropelar" nao existe com gente que nao olha nada e
## carro que nao preve nada.
##
## Agora quem vai atravessar espera na esquina ate poder:
##   com sinal   o boneco em ANDA (`Semaforo.estado_pedestre`) e tempo de chegar
##               do outro lado antes do verde dos carros, apertando o passo se
##               preciso (`PRESSA_MAX`). Nao comeca no PARE piscando. Carro que
##               ja nao para (entrou no amarelo, esta convertendo em cima) ele
##               deixa passar; o resto cede a ele (`JuizDeCruzamento.pedestre`).
##   sem sinal   olha (`OLHAR_*`) e espera uma brecha: todo carro que vai passar
##               pela faixa dele passa antes de ele chegar na frente do carro, ou
##               chega depois de ele ter saido, com folga (`PET_*`). Carro parado
##               no PARE nao conta — ele espera.
## E atravessa reto pela zebra: anda ate a beira do meio-fio, na linha da faixa
## (`alvo_agora`), espera ali, cruza e sai na mesma linha do outro lado (`alvo`).
## A perna do `Rotas` vai de canto a canto de calcada, e no lado fechado de um
## entroncamento em T o canto fica no eixo da rua que nao existe: a perna cruzava
## o miolo do cruzamento em diagonal, e a rua solta da bancada achou gente
## atropelada ali, tres metros fora da zebra.
##
## O pedestre (`Pedestre`) so pergunta: `passo` devolve 0 para esperar e o fator
## de passo para andar. `--ia-antiga` desliga tudo (linha de base da bancada).
class_name TravessiaDePedestre
extends RefCounted

enum Etapa { ESPERANDO, ATRAVESSANDO }

static var ativo := not MotoristaIA.ia_antiga
## As travessias em andamento (gente no asfalto agora), para o carro que passa
## fora do cruzamento em que o juiz olha — no meio do quarteirao, onde uma viela
## encosta — ver quem atravessa na frente (`MotoristaIA._travessia_a_frente`).
static var ativas: Array[TravessiaDePedestre] = []
## Quantas travessias comecaram, no total e em esquina com sinal.
static var inicios := 0
static var inicios_com_sinal := 0

## Quanto o passo aperta quando o tempo do boneco nao da (fator).
const PRESSA_MAX := 1.4
## Olhada antes de descer da calcada sem sinal, em segundos, de pessoa para
## pessoa.
const OLHAR_MIN := 0.4
const OLHAR_MAX := 1.1
## Brecha do pedestre: o carro sai da frente dele PET_ANTES antes de ele chegar,
## ou chega PET_DEPOIS depois de ele ter passado, em segundos. Maiores que as do
## carro (`JuizDeCruzamento.PED_DEPOIS` e `PED_ANTES`), e a margem maior que a
## dele (`PED_MARGEM`): a brecha que a pessoa aceita o carro tambem aceita, e
## ninguem freia por quem atravessou certo.
const PET_ANTES := 2.0
const PET_DEPOIS := 1.5
## Com o boneco verde, so conta o carro que ja nao para: o que chega ate aqui.
const IMINENTE_S := 2.2
## Margem em volta da lataria, ao longo da zebra, em metros. Nao so maior que a
## do carro (`JuizDeCruzamento.PED_MARGEM`): quem fica na faixa ao lado de um
## carro passando a 50 km/h leva susto (`Carro.RAIO_SUSTO`, 3,2 m de centro a
## centro) — a rua solta da bancada pegou isso no meio da avenida.
const MARGEM := 2.5
## Do primeiro passo ate o corpo andar, em segundos.
const ARRANQUE := 0.3
## Espalhamento de quem atravessa em volta do meio da zebra, em metros, e onde
## espera: na calcada, a isto do meio-fio.
const ESPALHA := 0.3
const BEIRA := 0.7
const ALCANCE_CARRO := 110.0
## Carro parado com a lataria a menos disto da pintura (m) esta em cima da faixa;
## e ocupa a faixa por este tempo (s) — quem espera olha de novo a cada quadro.
const EM_CIMA := 0.5
const PARADO_S := 60.0

var ped: Pedestre
var no := Vector4i.ZERO
var destino := Vector4i.ZERO
var zebra: Esquina.Zebra
var sinal := false
var etapa: int = Etapa.ESPERANDO
var espera := 0.0
var _olhar := 0.6
## Atravessado (`Zebra.atravessado`) de onde sai e aonde chega, e os dois
## pontos: a beira do meio-fio de ca (onde espera) e a de la.
var _de := 0.0
var _ate := 0.0
var _espera_em := Vector2.ZERO
var _chega_em := Vector2.ZERO


## A travessia da perna `no` -> `destino`, reaproveitando `atual` se e a mesma
## (quem levou susto no meio da rua nao volta a esperar na calcada). null quando
## a perna nao atravessa rua de carro.
static func trocar(atual: TravessiaDePedestre, novo_ped: Pedestre, de_no: Vector4i,
		para_no: Vector4i) -> TravessiaDePedestre:
	if atual != null and atual.no == de_no and atual.destino == para_no:
		return atual
	if atual != null:
		ativas.erase(atual)
	return de_perna(novo_ped, de_no, para_no)


## A perna atravessa a rua quando fica no mesmo no e troca de canto (as arestas
## 2 e 3 de `Rotas.vizinhos`): trocar o `sz` cruza a via que corre em X, do lado
## `sx`; trocar o `sx` cruza a que corre em Z, do lado `sz`.
static func de_perna(novo_ped: Pedestre, de_no: Vector4i, para_no: Vector4i) -> TravessiaDePedestre:
	if not ativo or de_no.x != para_no.x or de_no.y != para_no.y:
		return null
	var braco := -1
	if para_no.z == de_no.z and para_no.w != de_no.w:
		braco = Esquina.Braco.L if de_no.z > 0 else Esquina.Braco.O
	elif para_no.w == de_no.w and para_no.z != de_no.z:
		braco = Esquina.Braco.N if de_no.w > 0 else Esquina.Braco.S
	if braco < 0:
		return null
	var ij := Vector2i(de_no.x, de_no.y)
	if not Esquina.existe_braco(ij, braco):
		return null
	var t := TravessiaDePedestre.new()
	t.ped = novo_ped
	t.no = de_no
	t.destino = para_no
	t.zebra = Esquina.zebra(ij, braco)
	t.sinal = Semaforo.tem_sinal(ij.x, ij.y)
	var a := Rotas.ponto(de_no)
	var b := Rotas.ponto(para_no)
	var lado := signf(t.zebra.atravessado(Vector2(a.x, a.z)) - t.zebra.atravessado(Vector2(b.x, b.z)))
	if lado == 0.0:
		lado = 1.0
	var id := int(novo_ped.ficha.get("id", 0)) if novo_ped != null else 0
	var ao_longo := (t.zebra.lo + t.zebra.hi) * 0.5 + ESPALHA * (float(absi(id * 31) % 21) / 10.0 - 1.0)
	t._de = lado * (t.zebra.meia + BEIRA)
	# Chega na linha de caminhada da calcada de la (a do canto do Rotas), e nao na
	# beira: o pedestre da a perna por feita a `Pedestre.CHEGOU` do alvo, e com o
	# alvo a 0,7 m do meio-fio ele ainda estava no asfalto quando seguia para a
	# proxima esquina — numa diagonal rasa pela faixa de estacionamento.
	t._ate = -lado * maxf(absf(t.zebra.atravessado(Vector2(b.x, b.z))),
		t.zebra.meia + BEIRA + Pedestre.CHEGOU + 0.3)
	t._espera_em = t.zebra.centro + t.zebra.a * ao_longo + t.zebra.u * t._de
	t._chega_em = t.zebra.centro + t.zebra.a * ao_longo + t.zebra.u * t._ate
	t._olhar = OLHAR_MIN + (OLHAR_MAX - OLHAR_MIN) * float(absi(id * 7919) % 100) / 100.0
	return t


func esperando() -> bool:
	return etapa == Etapa.ESPERANDO


## A velocidade da travessia no plano: pela zebra, para o outro lado, no passo
## dela (com a pressa). O carro preve a pessoa por esta, e nao pela do quadro.
func velocidade_prevista() -> Vector2:
	var p := Vector2(ped.global_position.x, ped.global_position.z)
	var sentido := signf(_ate - zebra.atravessado(p))
	return zebra.u * sentido * _rapidez() * _pressa()


## O fim da perna: a beira do meio-fio do outro lado, na linha da zebra.
func alvo(atual: Vector3) -> Vector3:
	return Vector3(_chega_em.x, atual.y, _chega_em.y)


## Para onde andar agora: esperando e ainda longe da beira, ate ela; depois, o
## fim da perna.
func alvo_agora(alvo_da_perna: Vector3) -> Vector3:
	if etapa == Etapa.ESPERANDO and not _na_beira():
		return Vector3(_espera_em.x, alvo_da_perna.y, _espera_em.y)
	return alvo_da_perna


func _na_beira() -> bool:
	if ped == null or not is_instance_valid(ped):
		return true
	return Vector2(ped.global_position.x, ped.global_position.z).distance_to(_espera_em) < 0.5


## Chamado pelo pedestre a cada passo em que ele quer andar nesta perna: 0 para
## esperar na calcada; senao, o fator do passo.
func passo(delta: float) -> float:
	if etapa == Etapa.ATRAVESSANDO:
		return _pressa()
	# Primeiro chega na beira do meio-fio; a espera conta de la.
	if not _na_beira():
		return 1.0
	espera += delta
	if not _pode_ir():
		return 0.0
	etapa = Etapa.ATRAVESSANDO
	ativas.append(self)
	# Quem sumiu (reciclado pela multidao) no meio da rua sai da lista aqui.
	for k in range(ativas.size() - 1, -1, -1):
		if not is_instance_valid(ativas[k].ped):
			ativas.remove_at(k)
	inicios += 1
	if sinal:
		inicios_com_sinal += 1
	return _pressa()


func _rapidez() -> float:
	return maxf(0.6, ped._velocidade) if ped != null and is_instance_valid(ped) else Pedestre.VELOCIDADE


func _falta() -> float:
	if ped == null or not is_instance_valid(ped):
		return absf(_ate - _de)
	var p := Vector2(ped.global_position.x, ped.global_position.z)
	return absf(_ate - zebra.atravessado(p))


func _pode_ir() -> bool:
	if ped == null or not is_instance_valid(ped):
		return true
	var so_iminentes := false
	if sinal:
		var agora := Semaforo.agora()
		var ij := zebra.ij
		if Semaforo.estado_pedestre(ij.x, ij.y, zebra.eixo_carro, agora) != Semaforo.Travessia.ANDA:
			return false
		var resta := Semaforo.ate_o_verde(ij.x, ij.y, zebra.eixo_carro, agora)
		if resta < _falta() / (_rapidez() * PRESSA_MAX) + 0.5:
			return false
		so_iminentes = true
	elif espera < _olhar:
		return false
	return not _carro_vindo(so_iminentes)


## Com sinal: aperta o passo se o tempo ate o verde dos carros nao da.
func _pressa() -> float:
	if not sinal:
		return 1.0
	var ij := zebra.ij
	var agora := Semaforo.agora()
	if Semaforo.estado(ij.x, ij.y, zebra.eixo_carro, agora) != Semaforo.Luz.VERMELHO:
		return PRESSA_MAX
	var resta := Semaforo.ate_o_verde(ij.x, ij.y, zebra.eixo_carro, agora)
	return clampf(_falta() / (_rapidez() * maxf(resta - 0.5, 0.1)), 1.0, PRESSA_MAX)


## Algum carro vai passar pela faixa enquanto ele estiver na frente dele?
func _carro_vindo(so_iminentes: bool) -> bool:
	var p := Vector2(ped.global_position.x, ped.global_position.z)
	var u0 := zebra.atravessado(p)
	var sentido := signf(_ate - u0)
	var rapidez := _rapidez()
	var t_total := absf(_ate - u0) / rapidez + ARRANQUE
	for no_c: Node in ped.get_tree().get_nodes_in_group(&"carro"):
		var o := no_c as Carro
		if o == null or not is_instance_valid(o) or o.has_meta(&"ignorar_ia"):
			continue
		var op := Vector2(o.global_position.x, o.global_position.z)
		if op.distance_squared_to(zebra.centro) > ALCANCE_CARRO * ALCANCE_CARRO:
			continue
		var w := Vector4(NAN, 0.0, 0.0, 0.0)
		var ia := MotoristaIA.ia_de(o)
		if ia != null:
			w = ia.passagem(zebra)
		if is_nan(w.x):
			w = _passagem_vista(o)
		if w.x == INF:
			continue
		if so_iminentes and w.x > IMINENTE_S:
			continue
		var lo := w.z - MARGEM
		var hi := w.w + MARGEM
		var ta: float
		var tb: float
		if sentido >= 0.0:
			ta = (lo - u0) / rapidez
			tb = (hi - u0) / rapidez
		else:
			ta = (u0 - hi) / rapidez
			tb = (u0 - lo) / rapidez
		if tb < 0.0 or ta > t_total:
			continue
		ta = maxf(ta, 0.0) + ARRANQUE
		tb += ARRANQUE
		if w.y + PET_ANTES <= ta or w.x >= tb + PET_DEPOIS:
			continue
		return true
	return false


## Quando um carro sem plano aqui (o do jogador, o da blitz) passa pela faixa,
## seguindo reto na velocidade dele: (entra, sai, menor e maior atravessado da
## lataria). INF: nao passa. Parado em cima da pintura com alguem ao volante,
## ocupa a faixa ate sair:
## o carro que esperava alguem na outra faixa do meio do quarteirao ficava por
## cima desta, quem atravessava passava rente a lataria e levava um empurrao
## quando ele arrancava.
func _passagem_vista(o: Carro) -> Vector4:
	var vel := MotoristaIA._velocidade_de(o)
	var va := vel.dot(zebra.a)
	var op := Vector2(o.global_position.x, o.global_position.z)
	var fo := -o.global_transform.basis.z
	var h := Vector2(fo.x, fo.z).normalized()
	var comp := float(o._medidas.get("comprimento", 4.5))
	var larg := float(o._medidas.get("largura", 1.8))
	var meio_al := absf(h.dot(zebra.a)) * comp * 0.5 + absf(h.dot(zebra.u)) * larg * 0.5
	var meio_ac := absf(h.dot(zebra.u)) * comp * 0.5 + absf(h.dot(zebra.a)) * larg * 0.5
	var al := zebra.ao_longo(op)
	if absf(va) < 0.5:
		# Sem ninguem ao volante (estacionado, largado) nao sai do lugar: contorna.
		if (o.motorista != Carro.Motorista.NINGUEM
				and al + meio_al > zebra.lo - EM_CIMA and al - meio_al < zebra.hi + EM_CIMA):
			var ac0 := zebra.atravessado(op)
			return Vector4(0.0, PARADO_S, ac0 - meio_ac, ac0 + meio_ac)
		return Vector4(INF, 0.0, 0.0, 0.0)
	var t_in: float
	var t_out: float
	if va > 0.0:
		t_in = (zebra.lo - meio_al - al) / va
		t_out = (zebra.hi + meio_al - al) / va
	else:
		t_in = (al - meio_al - zebra.hi) / -va
		t_out = (al + meio_al - zebra.lo) / -va
	if t_out < 0.0 or t_in > 10.0:
		return Vector4(INF, 0.0, 0.0, 0.0)
	t_in = maxf(t_in, 0.0)
	var ac := zebra.atravessado(op) + vel.dot(zebra.u) * t_in
	return Vector4(t_in, t_out, ac - meio_ac, ac + meio_ac)
