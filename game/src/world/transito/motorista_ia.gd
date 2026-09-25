## Quem dirige o carro da IA (PLANO_TRANSITO_AAA, Passos 1 a 3).
##
## O `Carro` e o corpo; isto e o motorista. Ele planeja o caminho uns setenta
## metros a frente como uma fila de `Manobra` — retas de faixa e curvas de
## cruzamento —, anda por ele pelo comprimento de arco e escreve a transformada
## do carro a cada passo de fisica. O corpo continua congelado (STATIC) e a
## posicao continua escrita, pelo motivo documentado no cabecalho do `Carro`.
##
## O que mudou em relacao a IA antiga
## ----------------------------------
##   curva       caminho em espiral-arco-espiral escolhido para caber na esquina
##               (`Manobra.curva_de_cruzamento`), e nao perseguicao de ponto a
##               2,3 rad/s
##   velocidade  o carro olha a curvatura dos proximos metros e chega na curva a
##               `A_LAT` de aceleracao lateral, freando antes com `FREIA_CURVA`
##   faixa       a faixa certa para a conversao (direita na de fora, esquerda na
##               de dentro) e a troca de faixa em S ANTES do cruzamento, nunca
##               dentro dele
##   saida       decidida ao entrar no quarteirao, e nao a 8,5 m do centro: da
##               tempo de trocar de faixa e de ligar a seta. Saida que leva a
##               beco sem retorno fica de fora quando ha outra
##   seta        do lado da curva (a antiga acendia o oposto) e com
##               `PISCA_ANTES_S` de antecedencia
##   contorno    o mesmo criterio de antes (`Carro._talvez_contornar`), mas o
##               carro sai e volta em S, e nao num degrau lateral de 2,1 m
##
## O pe (Passo 2, ver `Longitudinal`)
## ---------------------------------
##   seguir      o carro da frente e achado projetando os outros carros no
##               CAMINHO planejado (`_lider`), e nao por tres raios retos: na
##               curva o raio olhava a calcada e perdia quem ia a frente. A
##               distancia e a velocidade dele entram no IIDM
##   parar       sinal e PARE viram um ponto de parada no caminho, a linha de
##               retencao; a freada e de desaceleracao constante ate ela,
##               comecada cedo, com alivio no fim (`_a_de_parada`)
##   amarelo     decidido uma vez, ao ve-lo: para se precisa de ate
##               `B_AMARELO`, senao passa e nao volta atras
##   reacao      parado e liberado (verde, o da frente saiu, PARE livre), o pe
##               so vai ao acelerador depois do tempo de reacao dele: a fila sai
##               em cascata
##   pedal       a aceleracao tem curso (jerk limitado); freada forte so em
##               emergencia
## Pedestre, jogador a pe e bicicleta tambem sao achados no caminho
## (`_obstaculo_de_raio`, Passo 3); os tres raios retos do bico sairam.
##
## O cruzamento (Passo 3, ver `JuizDeCruzamento`)
## ----------------------------------------------
##   linha       a PINTADA (`Esquina.linha`): a conta antiga parava o bico em
##               cima da zebra
##   lei e juiz  a lei (sinal, amarelo, PARE) diz se ele pode entrar
##               (`_lei`); o juiz diz se deve: a esquerda cede a quem vem de
##               frente, a secundaria entra por brecha de tempo, entre dois
##               PAREs sai quem parou primeiro, e ninguem entra sem caber do
##               outro lado (`_saida_cheia`)
##   publica     o que vai fazer no proximo cruzamento, para o juiz dos outros e
##               para o pedestre (`pub_*`, `passagem`)
##   pedestre    quem atravessa numa zebra do caminho tem a vez: espera na linha
##               ou, ja dentro, antes da zebra de saida (`_a_para_pedestre`)
##
## `--ia-antiga` volta a IA de antes, para a bancada comparar as duas na mesma
## situacao (tests/bancada_transito.gd).
class_name MotoristaIA
extends RefCounted

static var ia_antiga := OS.get_cmdline_user_args().has("--ia-antiga")
## `--diag-transito`: todo carro parado ha mais de 5 s descreve por que, uma vez.
static var diag := OS.get_cmdline_user_args().has("--diag-transito")
var _diag_dito := false

enum Rumo { RETO, DIREITA, ESQUERDA, TROCA }

## Aceleracao lateral de conforto na curva, em m/s2. Motorista de rua faz a
## esquina a 0,2-0,3 g; a antiga fazia a 2,6 g.
const A_LAT := 2.5
## Amarelo: para quem consegue com ate isto de freada, em m/s2; quem precisaria
## de mais passa (e o amarelo existe para ele).
const B_AMARELO := 3.5
## A partir de quantos metros alem da linha o carro ja esta dentro do
## cruzamento e o sinal deixa de ser com ele. Parado EM CIMA da linha, nao:
## ver `_a_de_parada`.
const DENTRO_DO_CRUZAMENTO := 0.5
## O caminho que se olha a frente para achar quem vai na frente, em metros, e o
## passo das amostras.
const ALCANCE_LIDER := 50.0
const PASSO_POLI := 2.0
## Quanto alem da meia largura um carro pode estar do eixo do caminho e ainda
## contar como na frente, em metros.
const FOLGA_LATERAL := 0.3
## Ate onde, em metros, se procura gente no caminho.
const ALCANCE_RAIO := 30.0
## Curva: ate quantos metros a frente ela limita tambem a ACELERACAO, e o piso
## da distancia na conta (olhar um pouco adiante, e nao so o metro de baixo do
## carro, e o que faz a aceleracao ir a zero suave ao chegar no limite).
const CURVA_PERTO := 6.0
const CURVA_PISO := 2.0
## Quanto caminho manter planejado a frente, em metros. Cobre a distancia de
## freio de curva a 14 m/s (39 m) com folga.
const HORIZONTE := 70.0
## Troca de faixa: quanto dura (em segundos na velocidade da via), a menor e a
## maior extensao, e quanto antes do fim da reta ela tem de ter terminado.
const TROCA_S := 3.0
const TROCA_MIN := 20.0
const TROCA_MAX := 42.0
const TROCA_FOLGA_FIM := 12.0
## E so comeca este tanto depois do asfalto do cruzamento de onde se saiu (a
## zebra fica ai). Sem isto a troca comecava 2 m depois do meio do cruzamento,
## ainda dentro dele.
const SAIDA_DO_MIOLO := 4.0
## Volta para a faixa depois da blitz: extensao minima e segundos na via.
const VOLTA_MIN := 10.0
const VOLTA_S := 2.0
## Seta: segundos antes da manobra, e o minimo em metros.
const PISCA_ANTES_S := 3.0
const PISCA_ANTES_MIN := 20.0
## Pesos da escolha de saida. Com duas conversoes possiveis, seguir reto sai em
## 58% das esquinas — perto dos 62% da antiga, que ja tinham sido ajustados
## para ninguem parecer perdido.
const PESO_RETO := 4.2
const PESO_TROCA := 0.8
const PESO_VIRA := 1.5
## Contorno: extensao do S de ida e do de volta, em metros. Com 2,1 m de
## desvio, 8 m dao curvatura de 0,19 — raio de 5 m, o volante todo de um carro
## de rua em manobra.
const CONTORNO_ENTRA := 8.0
const CONTORNO_SAI := 10.0
## Juiz do cruzamento (Passo 3): consultado a partir da distancia de parar com
## JUIZ_B mais JUIZ_PERTO metros da linha.
const JUIZ_B := 2.0
const JUIZ_PERTO := 12.0
## Liberado pelo juiz, ja nao volta atras quem cruzou a linha andando ou nao para
## antes dela com esta freada (m/s2): quem entra tem de sair.
const B_COMPROMETE := 2.5
## So entra quem cabe inteiro do outro lado do cruzamento, com esta folga (m).
const SAIDA_FOLGA := 1.5
## Parado por pedestre dentro do cruzamento: a lataria fica este tanto antes da
## zebra (m).
const ANTES_DA_ZEBRA := 1.0
## Plantado com vermelho ou PARE a frente, nasce numa velocidade que para com
## esta freada (m/s2). Ver `_velocidade_de_nascer`.
const NASCER_B := 2.0
## Passando por quem atravessa na faixa ao lado: no maximo isto (m/s), abaixo da
## velocidade de susto do pedestre (`Carro.VEL_SUSTO`, 5).
const V_PERTO_DE_GENTE := 4.0
## Para nao parar em cima de outra faixa, ele aceita frear ate isto (m/s2) para
## esperar antes dela; mais que isso, para onde ia e a faixa fica ocupada (quem
## vai atravessar a de ca espera ele sair). O de `B_COMPROMETE`: com 3,0 a conta,
## somada ao curso do pedal, ja passava do teto de conforto da bancada.
const FAIXA_LIVRE_B := 2.5
## Gente a pe no caminho: para a isto dela (m, do para-choque), como quem para
## antes de uma pessoa, e nao atras de um carro.
const PESSOA_FOLGA := 2.0

## O que ele publica do proximo cruzamento para o juiz dos outros e para o
## pedestre. PARA_LEI: vermelho, amarelo em que para, PARE antes de parar.
## PARA_CEDE: a lei deixa e ele espera a vez. DENTRO: ja entrou.
enum Vez { PASSA, PARA_LEI, PARA_CEDE, DENTRO }

var carro: Carro

var _pecas: Array[Manobra] = []
## Comprimento de arco do eixo traseiro dentro de `_pecas[0]`, e o acumulado
## ate o comeco dela.
var _s := 0.0
var _s_base := 0.0
## Onde o planejamento parou: o proximo quarteirao comeca no cruzamento
## `_plano_de`, pelo trecho `_plano_trecho`, no ponto `_plano_ponto`, e o
## caminho planejado acaba em `_plano_s`.
var _plano_de := Vector2i.ZERO
var _plano_trecho := Vector4i.ZERO
var _plano_ponto := Vector2.ZERO
var _plano_s := 0.0
## Afastamento lateral e inclinacao a devolver a faixa na proxima reta
## planejada (volta da blitz, carro plantado torto).
var _reentrada := Vector2.ZERO
## Cruzamentos no caminho: {ij, eixo (de chegada), s (onde o centro do carro
## passa pelo meio dele), saida (trecho)}.
var _eventos: Array[Dictionary] = []
var _pronto := false
var _rng := RandomNumberGenerator.new()
## Manobras impostas para os proximos cruzamentos (bancada).
var _forcar: Array[int] = []
## Blitz no volante: ela manda a mira, como sempre mandou.
var _livre := false
## Contorno em curso: s global do eixo traseiro onde a ida comeca, termina, a
## volta comeca e termina, e o desvio (para a esquerda).
var _desvio := Vector4.ZERO
var _desvio_d := 0.0
var _esterco := 0.0
var _eixo := 2.55
var _comp := 4.3

## O pe (Passo 2).
var _pe: Longitudinal.Pe
## Aceleracao atual, em m/s2: o que o pedal esta fazendo agora.
var _a := 0.0
## Tempo de reacao correndo (NAN: nao esta esperando nada).
var _reacao_t := NAN
## Freando para uma parada ou para uma curva: a freada, uma vez comecada, vai
## ate o fim, e nao liga e desliga em volta do limiar.
var _parando := false
var _freando_curva := false
## O amarelo decidido: o cruzamento em que ele para, e o em que ele passa.
var _parar_em := NENHUM
var _passa_em := NENHUM
## PARE: quanto tempo parado na linha, e o cruzamento em que ja cumpriu a
## parada (dali em diante quem decide e o juiz).
var _pare_espera := 0.0
var _pare_parou := NENHUM
## Passo 3: o cruzamento em que ja entrou (nao volta atras), o evento de que
## esta saindo (passou do meio; a lataria ainda esta la), ha quanto tempo cede,
## o que o juiz disse e por que, e onde o pedestre o faz parar ja dentro.
var _entrou_em := NENHUM
var _saindo: Dictionary = {}
var _cede_t := 0.0
var _veredito := 0
var _motivo_juiz := ""
var _s_pedestre := INF
var _s_pedestre_saindo := INF
var _d_pedestre := INF
## Gente atravessando fora do cruzamento do juiz (`_travessia_a_frente`): do bico
## ate onde parar, e ate onde passar devagar.
var _travessia_vista := Vector2(INF, INF)
## As travessias por quem ele decidiu parar (id da `TravessiaDePedestre`).
var _parando_por: Dictionary = {}
## A pessoa a pe mais perto no caminho (`_obstaculo_de_raio`): distancia do
## para-choque e velocidade dela ao longo do caminho; x = INF: ninguem.
var _pessoa_vista := Vector2(INF, 0.0)
var _pessoa_no: Node3D = null
## Publicado para os outros (ver `Vez`, `JuizDeCruzamento`, `passagem`).
var pub_ij := NENHUM
var pub_mov: Movimento = null
var pub_s := 0.0
var pub_vez: int = Vez.PASSA
var pub_desde := -1.0
var pub_saindo_ij := NENHUM
var pub_saindo_mov: Movimento = null
var pub_saindo_s := 0.0
## O que segurou o carro da ultima vez, para o motivo nao virar "via" durante
## a reacao.
var _motivo_parado: StringName = &"via"
## O caminho a frente em amostras, do eixo traseiro para diante: pontos e o
## comprimento de arco de cada um. Refeito a cada passo.
var _poli := PackedVector2Array()
var _poli_s := PackedFloat32Array()
var _lider_no: Node = null
var _raio_no: Node = null
## O ultimo lider visto (x = -1: nada visto ainda), e o contador de quadros da
## percepcao alternada.
var _lider_visto := Vector2(-1.0, 0.0)
var _a_curva_visto := INF
var _quadro := 0

## Desistiu de uma troca de faixa: o proximo quarteirao se planeja na faixa em
## que ele esta.
var _sem_troca := false
## Troca de faixa: brecha que o de tras na faixa nova precisa ter, em segundos
## (alem de `Pe.s0`), e a que ele mesmo precisa do da frente nela.
const TROCA_BRECHA_ATRAS := 0.9
const TROCA_BRECHA_FRENTE := 0.6

## Bancada: caminho reto fixo sem cruzamento (`caminho_de_bancada`), e
## aceleracao imposta (o lider que freia a 3 m/s2 no teste da onda).
var _fixo := false
var roteiro_a := NAN

const NENHUM := Vector2i(2147483647, 0)


func _init(novo: Carro) -> void:
	carro = novo
	_rng.seed = absi(carro.semente * 2654435761 + 97)
	_pe = Longitudinal.pe_de(carro.semente)
	# Metade da frota olha nos quadros pares, metade nos impares.
	_quadro = absi(carro.semente) % 2


## A aceleracao que o pedal esta dando agora, em m/s2.
func aceleracao() -> float:
	return _a


## O tempo de reacao deste motorista, em segundos.
func reacao() -> float:
	return _pe.reacao


## Bancada: um caminho reto de `a` a `b`, sem cruzamento nem sinal, na
## velocidade `v_via`. E onde se mede o pe sozinho: seguir, a onda de freada.
func caminho_de_bancada(a: Vector2, b: Vector2, v_via: float) -> void:
	var m := carro._medidas
	_eixo = float(m.get("entre_eixos", 2.55))
	_comp = float(m.get("comprimento", 4.3))
	var pos := carro.global_position
	var dir := (b - a).normalized()
	var tras := Vector2(pos.x, pos.z) - dir * (_eixo * 0.5)
	var r := Manobra.reta(tras, b)
	r.v_via = v_via
	r.trecho = carro.trecho
	r.trecho_fim = carro.trecho
	_pecas.clear()
	_pecas.append(r)
	_eventos.clear()
	_s = 0.0
	_s_base = 0.0
	_plano_s = INF
	_fixo = true
	_pronto = true
	_lider_visto = Vector2(-1.0, 0.0)
	carro._giro = Manobra.rumo_de(dir)


## Esterco visual da roda dianteira, em radianos (+ esquerda).
func esterco() -> float:
	return _esterco


# --- o que ele publica (Passo 3) ---------------------------------------------

## O motorista que planeja este carro, se e um: carro da IA, fora da blitz e
## fora da reta de bancada. null: quem olha de fora so ve onde ele esta.
static func ia_de(o: Carro) -> MotoristaIA:
	if o.motorista != Carro.Motorista.IA or o._ia == null:
		return null
	var ia := o._ia
	if ia._livre or not ia._pronto or ia._fixo:
		return null
	return ia


## Tem plano em `ij`? 1: e o proximo cruzamento dele (`pub_mov`, `pub_s`,
## `pub_vez`); 2: esta saindo dele (`pub_saindo_*`, sempre DENTRO); 0: nao.
func plano_em(ij: Vector2i) -> int:
	if pub_ij == ij and pub_mov != null:
		return 1
	if pub_saindo_ij == ij and pub_saindo_mov != null:
		return 2
	return 0


## Quanto falta para o pe sair do freio, se esta parado: o tempo de reacao
## correndo, ou inteiro.
func reacao_restante() -> float:
	if carro._velocidade > 0.05:
		return 0.0
	return _reacao_t if not is_nan(_reacao_t) else _pe.reacao


## Quando ele passa pela zebra `z`: (entra, sai, menor e maior atravessado da
## lataria). x = INF: nao passa (ou esta parado antes dela e cede); x = NAN:
## nao tem plano la, e quem pergunta olha de fora.
func passagem(z: Esquina.Zebra) -> Vector4:
	var p := plano_em(z.ij)
	if p == 0:
		return Vector4(NAN, 0.0, 0.0, 0.0)
	var m: Movimento = pub_mov if p == 1 else pub_saindo_mov
	var s: float = pub_s if p == 1 else pub_saindo_s
	var w := Vector4(INF, 0.0, 0.0, 0.0)
	if Esquina.braco_de_chegada(m.chegada) == z.braco:
		w = m.z_chegada
	elif Esquina.braco_de_saida(m.saida) == z.braco:
		w = m.z_saida
	if w.x == INF or s > w.y:
		return Vector4(INF, 0.0, 0.0, 0.0)
	# Parado ou parando antes da linha: nao passa agora, e quando for passar
	# cede a quem estiver na faixa.
	if p == 1 and (pub_vez == Vez.PARA_LEI or pub_vez == Vez.PARA_CEDE) \
			and s < m.s_linha + 0.5:
		return Vector4(INF, 0.0, 0.0, 0.0)
	var j := JuizDeCruzamento.janela(m, w.x, w.y, s, absf(carro._velocidade),
		reacao_restante())
	return Vector4(j.x, j.y, w.z, w.w)


## Impoe a manobra dos proximos cruzamentos, na ordem. Para a bancada.
func forcar(rumos: Array[int]) -> void:
	_forcar = rumos.duplicate()
	replanejar()


## Refaz o caminho a partir de onde o carro esta. O carro foi plantado, a
## blitz soltou o volante, ou e o primeiro passo. `seguindo`: o carro esta
## andando e so muda de plano (desistiu de uma troca de faixa) — o pe e o
## cruzamento de que ele esta saindo ficam como estao.
func replanejar(seguindo := false) -> void:
	var a_antes := _a
	var saindo_antes := _saindo
	var m := carro._medidas
	_eixo = float(m.get("entre_eixos", 2.55))
	_comp = float(m.get("comprimento", 4.3))
	_pecas.clear()
	_eventos.clear()
	_s = 0.0
	_s_base = 0.0
	_desvio = Vector4.ZERO
	_desvio_d = 0.0
	_fixo = false
	_a = a_antes if seguindo else 0.0
	_reacao_t = NAN
	_parando = false
	_freando_curva = false
	_parar_em = NENHUM
	_passa_em = NENHUM
	_pare_parou = NENHUM
	_pare_espera = 0.0
	_lider_visto = Vector2(-1.0, 0.0)
	_entrou_em = NENHUM
	_saindo = saindo_antes if seguindo else {}
	_cede_t = 0.0
	_veredito = JuizDeCruzamento.Veredito.LIVRE
	_s_pedestre = INF
	_s_pedestre_saindo = INF
	_d_pedestre = INF
	_travessia_vista = Vector2(INF, INF)
	_parando_por = {}
	_pessoa_vista = Vector2(INF, 0.0)
	_pessoa_no = null
	pub_ij = NENHUM
	pub_mov = null
	pub_vez = Vez.PASSA
	pub_desde = -1.0
	pub_saindo_ij = NENHUM
	pub_saindo_mov = null
	var t := carro.trecho
	var de := carro.cruzamento
	var dir := _dir2(t)
	var rumo_faixa := Manobra.rumo_de(dir)
	var pos := carro.global_position
	var frente := Manobra.dir_de(carro._giro)
	var tras := Vector2(pos.x, pos.z) - frente * (_eixo * 0.5)
	var base := (Vector2(Vias.linha_x(de.x, t.w, t.x), tras.y) if t.z == 0
		else Vector2(tras.x, Vias.linha_z(de.y, t.w, t.x)))
	var esq := Manobra.esquerda_de(rumo_faixa)
	var d0 := (tras - base).dot(esq)
	var erro := wrapf(carro._giro - rumo_faixa, -PI, PI)
	_reentrada = Vector2(d0, tan(clampf(erro, -1.2, 1.2)))
	if absf(_reentrada.x) < 0.02 and absf(_reentrada.y) < 0.01:
		_reentrada = Vector2.ZERO
	_plano_de = de
	_plano_trecho = t
	_plano_ponto = base
	_plano_s = 0.0
	_iniciando = true
	_garantir_horizonte()
	_iniciando = false
	_pronto = true
	_atualizar_eventos()
	if not seguindo:
		_velocidade_de_nascer()


## Plantado (o povoamento, a bancada) com vermelho ou PARE logo a frente: nasce
## numa velocidade de que ainda para com conforto. Nascia na da via, e a 14 m/s e
## 30 m da linha o primeiro quadro ja era freada de 3,3 m/s2 ou mais — o mesmo
## nascimento em cima da linha que o `--diag-transito` achou no Passo 2. Vale
## tambem para quem esta atravessando a rua logo a frente, no meio do quarteirao.
func _velocidade_de_nascer() -> void:
	if carro._velocidade <= 0.0:
		return
	if not TravessiaDePedestre.ativas.is_empty():
		_montar_poli()
		var d_gente := _travessia_a_frente(carro._velocidade).x
		if d_gente < INF:
			carro._velocidade = minf(carro._velocidade,
				sqrt(2.0 * NASCER_B * maxf(d_gente - _pe.margem, 0.0)))
	if _eventos.is_empty():
		return
	var ev: Dictionary = _eventos[0]
	var ij: Vector2i = ev["ij"]
	var d_linha := _dist_a_linha(ij, ev["chegada"])
	if d_linha < 0.0:
		return
	var para := bool(ev["pare"])
	if bool(ev["sinal"]):
		para = Semaforo.estado(ij.x, ij.y, int(ev["eixo"]), Semaforo.agora()) != Semaforo.Luz.VERDE
	if para:
		var v_max := sqrt(2.0 * NASCER_B * maxf(d_linha - _pe.margem - _pe.reserva, 0.0))
		carro._velocidade = minf(carro._velocidade, v_max)


# --- o passo ---------------------------------------------------------------

func passo(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_passo(delta)
	soma_passo_ms += float(Time.get_ticks_usec() - t0) / 1000.0
	passos += 1


func _passo(delta: float) -> void:
	if not _pronto:
		replanejar()

	var blitz := Blitz.efeito(carro)
	if not blitz.is_empty():
		_passo_livre(delta, blitz)
		return
	if _livre:
		_livre = false
		carro._ocultar_motorista_visual(false)
		replanejar()

	if not _fixo:
		_garantir_horizonte()
		_atualizar_eventos()
	_atualizar_pisca(delta)

	var v := carro._velocidade
	# Quem vai na frente: distancia de para-choque a para-choque e velocidade.
	# Tambem e o que o contorno e o teste leem (`_obst_dist`, `_obst_quem`).
	# Olhar custa (amostrar o caminho, projetar os carros, tres raios): cada
	# carro olha em quadros alternados, e no do meio a distancia anda com a
	# diferenca de velocidade. 16 ms de atraso, contra meio segundo de reacao
	# de gente.
	_quadro += 1
	var lider: Vector2
	var olhar := _quadro % 2 == 0 or _lider_visto.x == -1.0
	if olhar:
		_montar_poli()
		if not _fixo and _conferir_troca():
			_montar_poli()
		lider = _lider()
		var perto := minf(lider.x, _pessoa_vista.x)
		carro._obst_dist = perto - 0.1 if perto < INF else INF
		carro._obst_quem = _pessoa_no if _pessoa_vista.x < lider.x else _lider_no
	else:
		lider = _lider_visto
		if lider.x < INF:
			lider.x = maxf(lider.x - (v - lider.y) * delta, 0.05)
		if _pessoa_vista.x < INF:
			_pessoa_vista.x = maxf(_pessoa_vista.x - (v - _pessoa_vista.y) * delta, 0.05)
		var perto := minf(lider.x, _pessoa_vista.x)
		if perto < INF:
			carro._obst_dist = perto - 0.1
	_lider_visto = lider
	var d_linha := _parada_no_cruzamento(v, delta, olhar)
	var sinal := d_linha < 40.0
	_contornar(delta, sinal)
	var v0 := _pecas[0].v_via
	if carro._contorno > 0.0:
		v0 = minf(v0, Carro.VEL_CONTORNO)

	# Cada coisa pede uma aceleracao; vale a menor, e ela da o motivo.
	var a_livre := Longitudinal.livre(v, v0, _pe)
	var a_quero := Longitudinal.iidm(v, v0, lider.x, lider.y, _pe)
	var motivo: StringName = &"via" if a_quero >= a_livre - 0.05 else &"fila"
	# Gente a pe no caminho: para antes dela. Como lider do IIDM ela pedia a folga
	# de carro (2 m mais 1,5 s mais a aproximacao): a 1 m/s, a meio metro de onde
	# ele ja ia parar, uma pessoa vindo na direcao dele virava freada de 3,2 m/s2
	# (bancada, conversao_fluxo).
	if _pessoa_vista.x < INF:
		var a_gente := _a_para_pedestre(v, _pessoa_vista.x - PESSOA_FOLGA)
		if a_gente < a_quero:
			a_quero = a_gente
			motivo = &"fila"
	# A curva tambem so nos quadros em que ele olha: ela muda devagar.
	if olhar:
		_a_curva_visto = _a_de_curva(v)
	var a_curva := _a_curva_visto
	if a_curva < a_quero:
		a_quero = a_curva
		motivo = &"curva"
	var a_parada := _a_de_parada(v, d_linha)
	if a_parada < a_quero:
		a_quero = a_parada
		motivo = &"sinal"
	# Gente na zebra de saida com o carro ja dentro do cruzamento. O motivo e o
	# do cruzamento: quem vem atras nao contorna quem espera pedestre.
	if _d_pedestre < INF:
		var a_ped := _a_para_pedestre(v, _d_pedestre)
		if a_ped < a_quero:
			a_quero = a_ped
			motivo = &"sinal"
	# Gente atravessando a rua na frente, fora do cruzamento do juiz: para antes
	# da faixa dela, ou passa devagar se ela esta na faixa ao lado.
	if olhar:
		_travessia_vista = _travessia_a_frente(v)
	else:
		_travessia_vista -= Vector2(v, v) * delta
	if _travessia_vista.x < INF:
		var a_tr := _a_para_pedestre(v, _travessia_vista.x)
		if a_tr < a_quero:
			a_quero = a_tr
			motivo = &"sinal"
	if _travessia_vista.y < INF and v > V_PERTO_DE_GENTE:
		# Devagar ja alguns metros antes da faixa: o susto do pedestre dispara a
		# 3,2 m do carro (`Carro.RAIO_SUSTO`), antes de o bico chegar nela.
		var a_dev := maxf(Longitudinal.para_chegar(v, V_PERTO_DE_GENTE,
			maxf(_travessia_vista.y - 5.0, 2.0)), -3.0)
		if a_dev < a_quero:
			a_quero = a_dev
			motivo = &"sinal"

	# Parado e liberado: o pe so sai do freio depois do tempo de reacao.
	if v < 0.05 and is_nan(roteiro_a):
		if a_quero > 0.05:
			if is_nan(_reacao_t):
				_reacao_t = _pe.reacao
			if _reacao_t > 0.0:
				_reacao_t -= delta
				a_quero = 0.0
				motivo = _motivo_parado
		else:
			_reacao_t = NAN
			_motivo_parado = motivo
	else:
		_reacao_t = NAN
	# Saindo do parado: ate pegar embalo, o motivo e o que o segurou (o
	# relatorio do transito conta como parado ate 0,35 m/s).
	if v < 0.4 and motivo == &"via":
		motivo = _motivo_parado

	if not is_nan(roteiro_a):
		_a = roteiro_a
	else:
		_a = Longitudinal.com_jerk(_a, maxf(a_quero, -_pe.b_emergencia), delta, _pe)
	var nv := v + _a * delta
	if nv <= 0.0:
		nv = 0.0
		_a = maxf(_a, 0.0)
	carro._velocidade = nv
	carro._motivo = motivo
	# Luz de freio: pisando no freio, ou segurando o carro parado — como quem
	# espera o sinal com o pe no pedal.
	carro._freando = _a < -0.6 or (nv < 0.05 and a_quero <= 0.05)
	if nv < 0.4:
		carro._parado += delta
		# Preso atras de carro; parado por gente a pe nao e fila (nao se reclama).
		var preso := (motivo == &"fila" and _lider_no is Carro and not sinal
			and _pessoa_vista.x >= _lider_visto.x)
		carro._reclamar(preso)
		if diag and carro._parado > 5.0 and not _diag_dito:
			_diag_dito = true
			print(("[diag_transito] %s parado %.1f s em %s: motivo=%s a_quero=%.2f livre=%.2f"
				+ " curva=%s parada=%s d_linha=%.2f lider=(%.2f, %.2f) quem=%s reacao=%s"
				+ " parando=%s cruz=%s trecho=%s eventos=%s contorno=%.1f vez=%s juiz=%s %s")
				% [carro.name, carro._parado, carro.global_position.snappedf(0.1), motivo,
				a_quero, a_livre, str(a_curva), str(a_parada), d_linha, lider.x, lider.y,
				str(_lider_no), str(_reacao_t), str(_parando), carro.cruzamento, carro.trecho,
				str(_eventos.map(func(e: Dictionary) -> String: return str(e["ij"]))),
				carro._contorno, Vez.keys()[pub_vez],
				JuizDeCruzamento.Veredito.keys()[_veredito], _motivo_juiz])
	else:
		carro._parado = 0.0
		_diag_dito = false
	_andar(delta)


## O pe antigo, em degrau: so para a blitz, cujo funil e baia foram medidos
## com ele (teste da blitz).
func _pe_degrau(alvo_vel: float, delta: float, preso: bool) -> void:
	var v := carro._velocidade
	if alvo_vel > v:
		v = minf(alvo_vel, v + Carro.ACELERA * delta)
		carro._parado = 0.0
	else:
		v = maxf(alvo_vel, v - Carro.FREIA * delta)
	carro._freando = alvo_vel < v - 0.5
	carro._velocidade = v
	if v < 0.4:
		carro._parado += delta
		carro._reclamar(preso)
	else:
		carro._parado = 0.0


## Anda `v * delta` pelo caminho e escreve a transformada.
func _andar(delta: float) -> void:
	_s += carro._velocidade * delta
	while _s > _pecas[0].comprimento and _pecas.size() > 1:
		_s -= _pecas[0].comprimento
		_s_base += _pecas[0].comprimento
		_pecas.pop_front()
	var peca := _pecas[0]
	# Pelo centro do carro, que e por onde o cruzamento conta como passado.
	carro.trecho = peca.trecho_fim if _s + _eixo * 0.5 >= peca.s_troca else peca.trecho
	var a := peca.amostra(minf(_s, peca.comprimento))
	var tras := Vector2(a.x, a.y)
	var rumo := a.z
	var kappa := a.w
	if _desvio_d != 0.0:
		var dd := _desvio_em(_s_base + _s)
		tras += Manobra.esquerda_de(rumo) * dd.x
		rumo += atan(dd.y)
		kappa += dd.z
	var f2 := Manobra.dir_de(rumo)
	var centro := tras + f2 * (_eixo * 0.5)
	var nova := Vector3(centro.x, carro.global_position.y, centro.y)
	nova.y = carro._altura_do_chao(nova)
	carro._giro = rumo
	carro.global_transform = Transform3D(
		carro._base_na_ladeira(nova, Vector3(f2.x, 0.0, f2.y)), nova)
	carro._balancar(delta)
	_esterco = clampf(atan(_eixo * kappa), -Carro.ESTERCO_MAX, Carro.ESTERCO_MAX)


## Com a blitz no volante: persegue a mira dela, como a IA antiga, porque e
## assim que o funil e a baia foram medidos (teste da blitz). Quando ela solta,
## `replanejar` devolve o carro a faixa em S.
func _passo_livre(delta: float, blitz: Dictionary) -> void:
	_livre = true
	if int(blitz.get("faixa", -1)) >= 0 and carro.trecho.z == int(blitz.get("eixo", carro.trecho.z)):
		carro.trecho = Vias.trecho(carro.trecho.z, carro.trecho.w, int(blitz["faixa"]))
	carro._ocultar_motorista_visual(bool(blitz.get("ocultar_motorista", false)))
	carro._medir_obstaculo()
	var teto_sinal := carro._teto_do_sinal()
	var teto := minf(_pecas[0].v_via if not _pecas.is_empty() else Carro.VEL_CRUZEIRO,
		float(blitz.get("teto", INF)))
	var teto_obst := carro._teto_do_obstaculo()
	var alvo_vel := minf(teto, minf(teto_sinal, teto_obst))
	var parar := float(blitz.get("teto", 1.0)) <= 0.05
	if parar:
		alvo_vel = 0.0
	carro._motivo = &"blitz"
	var v_antes := carro._velocidade
	_pe_degrau(alvo_vel, delta, false)
	_a = (carro._velocidade - v_antes) / maxf(delta, 1e-4)
	var para_alvo := (blitz["mira"] as Vector3) - carro.global_position
	para_alvo.y = 0.0
	var quero := carro._giro
	if para_alvo.length() > 0.05 and not (parar and carro._velocidade < 0.45):
		quero = atan2(-para_alvo.x, -para_alvo.z)
		var taxa := 1.4 if not bool(blitz.get("parar", false)) else 2.3
		carro._giro = Carro._aproximar_angulo(carro._giro, quero, taxa * delta)
	_esterco = clampf(wrapf(quero - carro._giro, -PI, PI), -Carro.ESTERCO_MAX,
		Carro.ESTERCO_MAX)
	var frente := Vector3(-sin(carro._giro), 0.0, -cos(carro._giro))
	var nova := carro.global_position + frente * carro._velocidade * delta
	nova.y = carro._altura_do_chao(nova)
	carro.global_transform = Transform3D(carro._base_na_ladeira(nova, frente), nova)
	carro._balancar(delta)


# --- velocidade de curva ---------------------------------------------------

## A aceleracao que a curva pede: para cada metro dos proximos, a aceleracao
## constante que chega nele a `A_LAT` de aceleracao lateral; vale a pior.
##
## Negativa (esta rapido demais para a curva que vem): como a parada, comeca a
## frear quando passa de `Pe.b_inicio` e vai ate o fim; antes disso so tira o pe.
## Positiva, nos metros logo a frente (`CURVA_PERTO`): e o teto da aceleracao.
## Sem ele o carro que sai do PARE direto para a curva acelerava ate passar do
## limite e so entao freava — com o pedal tendo curso, a virada de acelerar
## para frear passava do ponto (3,2 m/s2 de lateral na bancada).
func _a_de_curva(v: float) -> float:
	var alcance := minf(v * v / (2.0 * _pe.b_alivio), HORIZONTE)
	alcance = maxf(alcance, CURVA_PERTO)
	var pior := INF
	var acc := -_s
	var v2 := v * v
	for m: Manobra in _pecas:
		if acc > alcance:
			break
		if not m.kbins.is_empty():
			var b0 := maxi(0, floori(-acc))
			var b1 := mini(m.kbins.size() - 1, floori(alcance - acc))
			# `Longitudinal.para_chegar` escrita aqui, no quadrado da velocidade
			# limite (A_LAT / k): e o laco mais quente do motorista, ate setenta
			# metros por passo.
			for b in range(b0, b1 + 1):
				var k := m.kbins[b]
				if k > 1e-4:
					var d := maxf(0.0, acc + float(b))
					if v2 * k > A_LAT or d <= CURVA_PERTO:
						var a := (A_LAT / k - v2) / (2.0 * maxf(d, CURVA_PISO))
						if a < pior:
							pior = a
		acc += m.comprimento
	# O S do contorno (ida e volta).
	if _desvio_d != 0.0:
		var s := _s_base + _s
		var k_ida := absf(_desvio_d) * 5.7735 / (CONTORNO_ENTRA * CONTORNO_ENTRA)
		var k_volta := absf(_desvio_d) * 5.7735 / (CONTORNO_SAI * CONTORNO_SAI)
		for par: Vector2 in [Vector2(k_ida, _desvio.x), Vector2(k_volta, _desvio.z)]:
			var v_lim := sqrt(A_LAT / par.x)
			var d := maxf(0.0, par.y - s)
			if s < par.y + 3.0 and (v > v_lim or d <= CURVA_PERTO):
				pior = minf(pior, Longitudinal.para_chegar(v, v_lim, maxf(d, CURVA_PISO)))
	if pior == INF:
		_freando_curva = false
		return INF
	if pior >= 0.0:
		_freando_curva = false
		return pior
	if _freando_curva or pior < -_pe.b_inicio:
		_freando_curva = pior < -0.15
		return maxf(pior * 1.05, -3.0)
	if pior < -_pe.b_alivio:
		return -_pe.alivio
	return pior


# --- parar no cruzamento ------------------------------------------------------

## Quanto falta para o BICO chegar onde ele tem de parar no proximo cruzamento
## — a linha de retencao —, ou INF se nao tem de parar. Primeiro a lei (`_lei`:
## sinal, amarelo, PARE), depois o juiz (`JuizDeCruzamento`); publica o que
## decidiu (`pub_*`). Ja dentro, so o pedestre na zebra de saida o para, e isso
## vai por `_d_pedestre`.
func _parada_no_cruzamento(v: float, delta: float, olhar: bool) -> float:
	_d_pedestre = INF
	_atualizar_saindo()
	if pub_saindo_mov != null:
		_pedestre_dentro(pub_saindo_mov, pub_saindo_s, v, olhar, true)
	if _eventos.is_empty():
		pub_ij = NENHUM
		pub_mov = null
		return INF
	var ev: Dictionary = _eventos[0]
	var ij: Vector2i = ev["ij"]
	var d_linha := _dist_a_linha(ij, ev["chegada"])
	var mov := _movimento_de(ev)
	var s_mov := _s_em(ev, mov)
	pub_ij = ij if mov != null else NENHUM
	pub_mov = mov
	pub_s = s_mov
	# Parado na linha: desde quando (quem parou primeiro no PARE sai primeiro).
	if v < 0.3 and d_linha < 1.5 and d_linha > -DENTRO_DO_CRUZAMENTO:
		if pub_desde < 0.0:
			pub_desde = Semaforo.agora()
	elif v > 1.0:
		pub_desde = -1.0
	# Ja passou da linha, ou entrou no amarelo decidido a passar: a lei ficou
	# para tras. Liberado pelo juiz e comprometido, so a lei o segura ainda (o
	# amarelo que acende antes da linha).
	var lei := INF
	var dentro := d_linha < -DENTRO_DO_CRUZAMENTO or _passa_em == ij
	if not dentro:
		lei = _lei(ev, ij, d_linha, v, delta)
		dentro = _passa_em == ij
	if dentro or (_entrou_em == ij and lei == INF):
		_entrou_em = ij
		pub_vez = Vez.DENTRO
		_veredito = JuizDeCruzamento.Veredito.LIVRE
		_pedestre_dentro(mov, s_mov, v, olhar)
		return INF
	_entrou_em = NENHUM
	if lei < INF:
		pub_vez = Vez.PARA_LEI
		_cede_t = 0.0
		_veredito = JuizDeCruzamento.Veredito.LIVRE
		return lei
	if mov == null:
		pub_vez = Vez.PASSA
		return INF
	# A lei deixa. O juiz, perto o bastante para importar, nos quadros em que
	# ele olha.
	if d_linha > v * v / (2.0 * JUIZ_B) + JUIZ_PERTO:
		pub_vez = Vez.PASSA
		_veredito = JuizDeCruzamento.Veredito.LIVRE
		_cede_t = 0.0
		return INF
	if olhar:
		var antes := _veredito
		_julgar(ev, mov, s_mov, v)
		# Mandado ceder ja andando, quando parar pede mais que o conforto: se
		# ainda passa com a folga minima (`JuizDeCruzamento.PET_MINIMO`), passa —
		# e o que gente faz; senao freia, que seguranca vem antes.
		if antes == JuizDeCruzamento.Veredito.LIVRE \
				and _veredito == JuizDeCruzamento.Veredito.CEDE_CARRO and v > 1.0 \
				and Longitudinal.para_chegar(v, 0.0, d_linha - _pe.margem - _pe.reserva) \
				< -B_COMPROMETE and JuizDeCruzamento.avaliar(self, mov, s_mov, v, 0.0,
				bool(ev["sinal"]), int(ev["pref"]), JuizDeCruzamento.PET_MINIMO) \
				== JuizDeCruzamento.Veredito.LIVRE:
			_veredito = JuizDeCruzamento.Veredito.LIVRE
			_entrou_em = ij
			pub_vez = Vez.DENTRO
			return INF
	if _veredito != JuizDeCruzamento.Veredito.LIVRE:
		pub_vez = Vez.PARA_CEDE
		_cede_t += delta
		return d_linha
	pub_vez = Vez.PASSA
	_cede_t = 0.0
	# Liberado com gente na zebra de saida (virando a direita, `_julgar`): anda ate
	# rente a ela.
	if _s_pedestre < INF and s_mov < _s_pedestre - 0.1:
		_d_pedestre = minf(_d_pedestre, _s_pedestre - s_mov - ANTES_DA_ZEBRA)
	# Liberado e ja sem chao para parar com conforto, ou cruzando a linha
	# andando: entrou, e nao volta atras.
	if (d_linha <= 0.3 and v > 0.3) or (v > 1.0 and d_linha < v * v / (2.0 * B_COMPROMETE)):
		_entrou_em = ij
		pub_vez = Vez.DENTRO
	return INF


## O que o juiz diz agora: carro com a vez, a saida sem espaco, gente na zebra.
func _julgar(ev: Dictionary, mov: Movimento, s_mov: float, v: float) -> void:
	_s_pedestre = INF
	_veredito = JuizDeCruzamento.avaliar(self, mov, s_mov, v, _cede_t, bool(ev["sinal"]),
		int(ev["pref"]))
	if _veredito != JuizDeCruzamento.Veredito.LIVRE:
		_motivo_juiz = JuizDeCruzamento.ultimo_motivo
		return
	if _saida_cheia(mov, s_mov):
		_veredito = JuizDeCruzamento.Veredito.SAIDA_CHEIA
		_motivo_juiz = "saida: %s a %.1f m" % [str(_lider_no), _lider_visto.x]
		return
	var s_ped := JuizDeCruzamento.pedestre(self, mov, s_mov, v)
	if s_ped == INF:
		return
	_motivo_juiz = JuizDeCruzamento.ultimo_motivo
	# Virando a direita com gente so na zebra de saida: entra e espera rente a ela
	# (`_d_pedestre`), como quem vira de verdade. Esperando na linha, a janela dele
	# ate a zebra era de 3-4 s, cada pessoa que chegava cabia nela, e na esquina
	# cheia o boneco anda o verde inteiro: na rua solta um carro perdeu dois verdes
	# seguidos (60 s parado). A esquerda nao: parada no miolo, a lataria fica no
	# caminho do contrafluxo.
	if mov.tipo == Movimento.Tipo.DIREITA and is_equal_approx(s_ped, mov.z_saida.x):
		_s_pedestre = s_ped
		return
	_veredito = JuizDeCruzamento.Veredito.OCUPADO


## A lei do cruzamento `ij`: a distancia ate a linha se ele tem de parar nela
## (vermelho, amarelo em que para, PARE ainda nao cumprido), ou INF. Decide o
## amarelo (uma vez) e conta a espera no PARE.
func _lei(ev: Dictionary, ij: Vector2i, d_linha: float, v: float, delta: float) -> float:
	if bool(ev["sinal"]):
		var luz := Semaforo.estado(ij.x, ij.y, int(ev["eixo"]), Semaforo.agora())
		if luz == Semaforo.Luz.VERDE:
			_parar_em = NENHUM
			_passa_em = NENHUM
			return INF
		# Entrou no amarelo decidido a passar: o vermelho que vem depois nao o
		# pega mais (o vermelho geral de 1 s e para ele).
		if _passa_em == ij:
			return INF
		if luz == Semaforo.Luz.AMARELO and _parar_em != ij:
			var precisa := Longitudinal.freada_para_parar(v,
				d_linha - _pe.margem - _pe.reserva, _pe)
			if d_linha <= 0.0 or precisa > B_AMARELO:
				_passa_em = ij
				return INF
			_parar_em = ij
		return d_linha
	# PARE: so quem chega pela rua que nao e a preferencial, e ate cumprir a
	# parada. Dali em diante quem decide a hora de entrar e o juiz, por brecha.
	if not bool(ev["pare"]) or _pare_parou == ij:
		return INF
	if v < 0.3 and d_linha < 1.5:
		_pare_espera += delta
		if _pare_espera >= Carro.ESPERA_PARE:
			_pare_parou = ij
			_pare_espera = 0.0
			return INF
	else:
		_pare_espera = 0.0
	return d_linha


## Ja dentro do cruzamento: alguem numa zebra do caminho? Olha nos quadros de
## olhar e guarda onde parar (`_d_pedestre`, do bico). `saindo`: o movimento de
## que ele esta saindo — o evento acaba no meio da curva, e a zebra de saida fica
## depois dele: sem isto quem virava perdia de vista a pessoa na zebra justo
## ali (a rua solta pegou um carro saindo da curva encostando nela).
func _pedestre_dentro(mov: Movimento, s_mov: float, v: float, olhar: bool,
		saindo := false) -> void:
	if mov == null:
		return
	if olhar:
		var s_p := JuizDeCruzamento.pedestre(self, mov, s_mov, v)
		if saindo:
			_s_pedestre_saindo = s_p
		else:
			_s_pedestre = s_p
		if s_p < INF:
			_motivo_juiz = JuizDeCruzamento.ultimo_motivo
	# So para quem ainda nao chegou na zebra: em cima dela, parar nao tira
	# ninguem do caminho (o pe cuida de quem esta na frente).
	var s_ped := _s_pedestre_saindo if saindo else _s_pedestre
	if s_ped < INF and s_mov < s_ped - 0.1:
		_d_pedestre = minf(_d_pedestre, s_ped - s_mov - ANTES_DA_ZEBRA)


## A aceleracao para parar em `d` metros por causa de um pedestre, sem as regras
## de "ja passou, entao segue" da linha: gente na frente nao se atravessa.
func _a_para_pedestre(v: float, d: float) -> float:
	if v < 0.3 and d < 1.0:
		return -0.5
	if d <= 0.05:
		# Chegou no ponto ainda rolando: a menos de 1 m/s passa uns centimetros (o
		# ponto ja tem 1 m de folga antes da faixa) com freio firme; a emergencia
		# ali era um tranco de 4,8 m/s2 a meio metro por segundo (bancada, meio_par).
		return -_pe.b_emergencia if v > 1.0 else -2.0
	var precisa := Longitudinal.para_chegar(v, 0.0, d)
	if precisa < -_pe.b_alivio:
		return maxf(Longitudinal.assentar(v, precisa * 1.05), -_pe.b_emergencia)
	return INF


## Nao tranca o cruzamento: o da frente depois do cruzamento para (ou vai
## parar) sem deixar espaco para a lataria inteira passar da zebra de saida.
func _saida_cheia(mov: Movimento, s_mov: float) -> bool:
	var lider := _lider_visto
	if lider.x == INF or lider.x < 0.0 or not (_lider_no is Carro):
		return false
	var nariz := _eixo * 0.5 + _comp * 0.5
	var tras_lider := s_mov + nariz + lider.x
	# Na fila antes da linha: e o pe (IIDM) que cuida.
	if tras_lider < mov.s_linha + Movimento.BICO:
		return false
	if lider.y > 3.0:
		return false
	var para := tras_lider + maxf(lider.y, 0.0) * maxf(lider.y, 0.0) / (2.0 * 2.5)
	return para < mov.s_fim + nariz + SAIDA_FOLGA


## O movimento do evento, montado uma vez (a meia volta do fim de linha nao tem).
func _movimento_de(ev: Dictionary) -> Movimento:
	var pronto: Variant = ev.get("mov")
	if pronto != null or ev.has("mov"):
		return pronto
	var m: Movimento = null
	if not bool(ev.get("retorno", false)):
		m = Movimento.de(ev["ij"], ev["chegada"], ev["saida"])
	ev["mov"] = m
	return m


## Onde o eixo traseiro esta no referencial do movimento do evento.
func _s_em(ev: Dictionary, mov: Movimento) -> float:
	if mov == null:
		return 0.0
	return mov.s_ref + (_s_base + _s - float(ev["s_ref"]))


## O cruzamento de que ele esta saindo: publicado ate a traseira passar da zebra
## de saida.
func _atualizar_saindo() -> void:
	if _saindo.is_empty():
		pub_saindo_ij = NENHUM
		pub_saindo_mov = null
		_s_pedestre_saindo = INF
		return
	var m: Movimento = _saindo.get("mov")
	var s_m := _s_em(_saindo, m)
	if m == null or s_m > m.s_fim:
		_saindo = {}
		pub_saindo_ij = NENHUM
		pub_saindo_mov = null
		_s_pedestre_saindo = INF
		return
	pub_saindo_ij = _saindo["ij"]
	pub_saindo_mov = m
	pub_saindo_s = s_m


## Distancia do bico do carro a linha de retencao de `ij` para quem chega pelo
## trecho `chegada`, medida ao longo da rua de chegada. A linha e a PINTADA
## (`Esquina.linha`).
func _dist_a_linha(ij: Vector2i, chegada: Vector4i) -> float:
	var a := Vias.direcao(chegada.z, chegada.w)
	var c := Vector3(float(ij.x) * Vias.TAM, 0.0, float(ij.y) * Vias.TAM)
	var f := Manobra.dir_de(carro._giro)
	var bico := carro.global_position + Vector3(f.x, 0.0, f.y) * (_comp * 0.5)
	var ao_longo := Vector2(bico.x - c.x, bico.z - c.z).dot(Vector2(a.x, a.z))
	return -Esquina.linha(ij, chegada.z) - ao_longo


## A aceleracao para parar com o bico a `Pe.margem` da linha. Desaceleracao
## constante, comecada quando a necessaria passa de `Pe.b_inicio` e mantida ate
## o fim, com o freio aliviando nos ultimos metros (`Longitudinal.assentar`).
## Antes disso, entre `b_alivio` e `b_inicio`, so tira o pe.
##
## Parado na linha fica parado: e a regra que a IA antiga aprendeu apanhando
## (memoria "parar e uma distancia") — "ja passou da linha, entao atravessa" so
## vale para quem esta ANDANDO.
func _a_de_parada(v: float, d_linha: float) -> float:
	if d_linha == INF:
		_parando = false
		return INF
	if v < 0.3 and d_linha < 1.2:
		return -0.5
	# Andando em cima da linha, ou sem chao para parar antes dela nem com a
	# freada de emergencia (nasceu ali, foi plantado ali): segue. Parar dentro do
	# cruzamento trancaria quem tem verde, que e pior que atravessar — a regra
	# da IA antiga, que continua valendo.
	if not _parando and ((d_linha <= 0.0 and v > 1.0) or Longitudinal.para_chegar(
			v, 0.0, d_linha) < -_pe.b_emergencia):
		if not _eventos.is_empty():
			_passa_em = _eventos[0]["ij"]
			_entrou_em = _passa_em
		return INF
	# Parado ANTES da linha (atras de quem ja saiu, na fila do PARE): a freada
	# comprometida acabou, e ele pode encostar. Sem isto a freada "ate o fim"
	# segurava o carro a 6 m da linha para sempre — e o PARE, que so libera quem
	# esta nela, nunca o liberava.
	if v < 0.05:
		_parando = false
	var precisa := Longitudinal.para_chegar(v, 0.0, d_linha - _pe.margem - _pe.reserva)
	if _parando or precisa < -_pe.b_inicio:
		_parando = true
		var alvo := Longitudinal.assentar(v, precisa * 1.03)
		if d_linha < 0.2:
			alvo = minf(alvo, -2.5)
		return alvo
	if precisa < -_pe.b_alivio:
		return -_pe.alivio
	return INF


# --- quem vai na frente -------------------------------------------------------

## O caminho dos proximos `ALCANCE_LIDER` metros, a cada `PASSO_POLI`, a partir
## do eixo traseiro, com o desvio do contorno.
func _montar_poli() -> void:
	_poli.resize(0)
	_poli_s.resize(0)
	var s_ini := _s_base + _s
	var k := 0
	# A que distancia (do eixo traseiro) comeca o pedaco k.
	var inicio := -_s
	var d := 0.0
	while d <= ALCANCE_LIDER and k < _pecas.size():
		var m := _pecas[k]
		var s_local := d - inicio
		if s_local > m.comprimento:
			if k + 1 < _pecas.size():
				inicio += m.comprimento
				k += 1
				continue
			s_local = m.comprimento
		var a := m.amostra(s_local)
		var p := Vector2(a.x, a.y)
		if _desvio_d != 0.0:
			p += Manobra.esquerda_de(a.z) * _desvio_em(s_ini + d).x
		_poli.append(p)
		_poli_s.append(d)
		if s_local >= m.comprimento and k + 1 >= _pecas.size():
			break
		d += PASSO_POLI


## (s ao longo do caminho a partir do eixo traseiro, afastamento lateral,
## indice do segmento) do ponto `p`; s INF se ele nao esta ao lado do caminho.
func _projetar(p: Vector2) -> Vector3:
	var melhor := INF
	var saida := Vector3(INF, 0.0, -1.0)
	for k in _poli.size() - 1:
		var a := _poli[k]
		var b := _poli[k + 1]
		var ab := b - a
		var l2 := ab.length_squared()
		if l2 < 1e-6:
			continue
		var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		var q := a + ab * t
		var d2 := p.distance_squared_to(q)
		if d2 < melhor:
			melhor = d2
			var lado := ab.normalized()
			saida = Vector3(_poli_s[k] + t * sqrt(l2), lado.cross(p - q), float(k))
	return saida


## A direcao do caminho no segmento `k`.
func _tangente(k: int) -> Vector2:
	var k0 := clampi(k, 0, maxi(0, _poli.size() - 2))
	if _poli.size() < 2:
		return Manobra.dir_de(carro._giro)
	return (_poli[k0 + 1] - _poli[k0]).normalized()


## O mais perto na frente: (distancia de para-choque a para-choque, velocidade
## dele ao longo do caminho). Carros pela projecao no caminho — acha quem esta
## na faixa, na curva e atravessado no miolo do cruzamento —; o resto
## (pedestre, jogador a pe, bicicleta) pelos raios. INF: ninguem.
func _lider() -> Vector2:
	_lider_no = null
	var melhor := Vector2(INF, 0.0)
	if _poli.size() < 2:
		_pessoa_vista = Vector2(INF, 0.0)
		_pessoa_no = null
		return melhor
	var pos := carro.global_position
	var p2 := Vector2(pos.x, pos.z)
	var frente := Manobra.dir_de(carro._giro)
	var s_bico := _eixo * 0.5 + _comp * 0.5
	var meia_larg := float(carro._medidas.get("largura", 1.7)) * 0.5
	for no: Node in carro.get_tree().get_nodes_in_group(&"carro"):
		if no == carro:
			continue
		var o := no as Carro
		if o == null or not is_instance_valid(o) or o.has_meta(&"ignorar_ia"):
			continue
		# Quem estamos contornando nao conta enquanto o contorno dura: o desvio
		# existe justamente porque ele NAO vai andar.
		if o == carro._contornado and carro._contorno > 0.0:
			continue
		var op := Vector2(o.global_position.x, o.global_position.z)
		var d := op - p2
		if d.length_squared() > (ALCANCE_LIDER + 10.0) * (ALCANCE_LIDER + 10.0) \
				or d.dot(frente) < -3.0:
			continue
		var proj := _projetar(op)
		if proj.x == INF:
			continue
		var tang := _tangente(int(proj.z))
		var fo := -o.global_transform.basis.z
		var ho := Vector2(fo.x, fo.z).normalized()
		var cosd := absf(ho.dot(tang))
		var sind := absf(ho.cross(tang))
		var oc := float(o._medidas.get("comprimento", 4.3))
		var ol := float(o._medidas.get("largura", 1.7))
		var meia_ao_longo := cosd * oc * 0.5 + sind * ol * 0.5
		var meia_lado := sind * oc * 0.5 + cosd * ol * 0.5
		if absf(proj.y) - meia_lado > meia_larg + FOLGA_LATERAL:
			continue
		if proj.x + meia_ao_longo < s_bico:
			continue
		var gap := maxf(proj.x - meia_ao_longo - s_bico, 0.05)
		var vo := _velocidade_de(o)
		# Atravessando o caminho (Passo 3): quem cruza a frente e sai do corredor
		# antes de eu chegar la nao e o carro da frente, e quem cuida dele e o juiz.
		# Como "da frente" parado, ele fazia quem virava a esquerda cravar 7 m/s2
		# dentro do cruzamento atras de um carro que ja estava indo embora.
		var v_lat := vo.dot(Vector2(-tang.y, tang.x))
		if absf(v_lat) > 1.5:
			var t_sai := (meia_lado + meia_larg + FOLGA_LATERAL - proj.y * signf(v_lat)) \
				/ absf(v_lat)
			if t_sai + 0.5 < gap / maxf(carro._velocidade, 0.5):
				continue
		if gap < melhor.x:
			melhor = Vector2(gap, vo.dot(tang))
			_lider_no = o
	var raio := _obstaculo_de_raio(s_bico)
	if raio.x < melhor.x:
		melhor = raio
		_lider_no = _raio_no
	return melhor


## A velocidade de um carro no mundo, em planta. O da IA e congelado e anda pela
## escrita: a velocidade dele e a do motorista, na direcao do nariz.
static func _velocidade_de(o: Carro) -> Vector2:
	if not o.freeze:
		return Vector2(o.linear_velocity.x, o.linear_velocity.z)
	var f := -o.global_transform.basis.z
	return Vector2(f.x, f.z).normalized() * o.velocidade()


## Gente no caminho: pedestre, jogador a pe e bicicleta, projetados no caminho
## planejado como os carros (`_lider`). Eram tres raios retos do bico: na curva
## eles apontavam para a calcada da esquina e achavam quem esperava nela, e o carro
## cravava o freio atras de ninguem (achado no Passo 3; e o D4 do plano).
## (distancia de para-choque ate a pessoa, velocidade dela ao longo do caminho).
func _obstaculo_de_raio(s_bico: float) -> Vector2:
	var saida := Vector2(INF, 0.0)
	_raio_no = null
	_pessoa_vista = Vector2(INF, 0.0)
	_pessoa_no = null
	if _poli.size() < 2:
		return saida
	var p2 := Vector2(carro.global_position.x, carro.global_position.z)
	var frente := Manobra.dir_de(carro._giro)
	var meia_larg := float(carro._medidas.get("largura", 1.7)) * 0.5
	var arvore := carro.get_tree()
	var gente: Array[Node] = arvore.get_nodes_in_group(&"pedestre")
	gente.append_array(arvore.get_nodes_in_group(&"bicicleta"))
	var jogador := arvore.get_first_node_in_group(&"player")
	if jogador != null:
		gente.append(jogador)
	var alcance2 := (ALCANCE_RAIO + s_bico) * (ALCANCE_RAIO + s_bico)
	for no: Node in gente:
		var n3 := no as Node3D
		if n3 == null or not is_instance_valid(n3) or not n3.is_visible_in_tree():
			continue
		if n3.has_meta(&"ignorar_ia"):
			continue
		var q := Vector2(n3.global_position.x, n3.global_position.z)
		var d := q - p2
		if d.length_squared() > alcance2 or d.dot(frente) < 0.0:
			continue
		# Na calcada nao e obstaculo: o carro saindo da baia da blitz, colado no
		# meio-fio, esperava quem passava na calcada ao lado (teste da blitz).
		if not _no_leito(n3.global_position):
			continue
		var proj := _projetar(q)
		if proj.x == INF:
			continue
		var raio := 0.9 if n3 is Bicicleta else 0.35
		if absf(proj.y) > meia_larg + FOLGA_LATERAL + raio or proj.x + raio < s_bico:
			continue
		var gap := maxf(proj.x - raio - s_bico, 0.05)
		var vel := Vector2.ZERO
		if n3 is CharacterBody3D:
			var cb := n3 as CharacterBody3D
			vel = Vector2(cb.velocity.x, cb.velocity.z)
		var tang := _tangente(int(proj.z))
		# Atravessando e saindo do corredor bem antes de o carro chegar: nao e o da
		# frente (a zebra e com o juiz). Folga maior que a do carro: e gente.
		var v_lat := vel.dot(Vector2(-tang.y, tang.x))
		if absf(v_lat) > 0.8:
			var t_sai := (meia_larg + FOLGA_LATERAL + raio - proj.y * signf(v_lat)) / absf(v_lat)
			if t_sai + 1.5 < gap / maxf(carro._velocidade, 0.5):
				continue
		# Bicicleta anda na faixa: e seguida como um carro. Gente a pe e um ponto
		# de parada (`_pessoa_vista`).
		if n3 is Bicicleta:
			if gap < saida.x:
				saida = Vector2(gap, vel.dot(tang))
				_raio_no = n3
		elif gap < _pessoa_vista.x:
			_pessoa_vista = Vector2(gap, vel.dot(tang))
			_pessoa_no = n3
	return saida


## O ponto esta no leito da rua — pista ou faixa de estacionamento, ate o
## meio-fio —, e nao na calcada? (`Vias.no_asfalto` conta so a pista.)
static func _no_leito(pos: Vector3) -> bool:
	var i0 := roundi(pos.x / Vias.TAM)
	var j0 := roundi(pos.z / Vias.TAM)
	var linha_j := floori(pos.z / Vias.TAM)
	var linha_i := floori(pos.x / Vias.TAM)
	for di in range(-1, 2):
		var i := i0 + di
		var v := MalhaUrbana.via_x_em(i, linha_j)
		if Vias.dirigivel(v) and absf(pos.x - float(i) * Vias.TAM) <= MalhaUrbana.meia_asfalto(v):
			return true
	for dj in range(-1, 2):
		var j := j0 + dj
		var v := MalhaUrbana.via_z_em(j, linha_i)
		if Vias.dirigivel(v) and absf(pos.z - float(j) * Vias.TAM) <= MalhaUrbana.meia_asfalto(v):
			return true
	return false


# --- troca de faixa (Passo 3) -------------------------------------------------

## A troca de faixa do Passo 1 e planejada setenta metros antes, e o S so olhava
## a geometria: na rua solta da bancada o carro entrou duas vezes na frente de
## quem vinha na faixa ao lado, no mesmo ponto da avenida. Agora, a uns metros de
## comecar o S, ele confere a faixa nova (`_brecha_na_faixa`); sem brecha,
## desiste e replaneja seguindo na faixa em que esta (outra saida no cruzamento),
## como quem perdeu a vez de mudar de faixa. Ja no S, segue: o de tras o ve
## entrar no corredor dele. Mudar de faixa para passar alguem (MOBIL) e o Passo 5.
## Devolve true se replanejou.
func _conferir_troca() -> bool:
	var acc := -_s
	var v := carro._velocidade
	for k in mini(_pecas.size(), 2):
		var m := _pecas[k]
		if m.tipo == Manobra.Tipo.RETA and m.pisca != 0:
			var falta := acc + m.pisca_ini
			if falta > -0.5 and falta < maxf(8.0, v * 1.2):
				if not _brecha_na_faixa(m, falta):
					_sem_troca = true
					replanejar(true)
					return true
			return false
		acc += m.comprimento
	return false


## A faixa de destino da troca da reta `m` tem espaco para ele entrar, daqui a
## `falta` metros e o meio do S? Olha quem vai estar ao lado, logo atras ou logo
## a frente nela quando ele chegar la, na velocidade de cada um.
func _brecha_na_faixa(m: Manobra, falta: float) -> bool:
	var v := carro._velocidade
	var t_meio := (falta + (m._l_fim - m._l_ini) * 0.5) / maxf(v, 1.0)
	var tras := (Vector2(carro.global_position.x, carro.global_position.z)
		- Manobra.dir_de(carro._giro) * (_eixo * 0.5))
	var meu := (tras - m._a).dot(m._dir) + v * t_meio
	var meu_frente := meu + _eixo * 0.5 + _comp * 0.5
	var meu_tras := meu + _eixo * 0.5 - _comp * 0.5
	for no: Node in carro.get_tree().get_nodes_in_group(&"carro"):
		var o := no as Carro
		if o == null or o == carro or not is_instance_valid(o) or o.has_meta(&"ignorar_ia"):
			continue
		var op := Vector2(o.global_position.x, o.global_position.z)
		var rel := op - m._a
		var lat := rel.dot(m._esq)
		if absf(lat - m._d1) > 1.6:
			continue
		var vo := _velocidade_de(o).dot(m._dir)
		if vo < -0.5:
			continue
		var comp_o := float(o._medidas.get("comprimento", 4.3))
		var ele := rel.dot(m._dir) + vo * t_meio
		if ele > meu_frente + 40.0 or ele < meu_tras - 60.0:
			continue
		var ele_frente := ele + comp_o * 0.5
		var ele_tras := ele - comp_o * 0.5
		if ele_frente <= meu_tras:
			if meu_tras - ele_frente < _pe.s0 + maxf(vo, 0.0) * TROCA_BRECHA_ATRAS:
				return false
		elif ele_tras >= meu_frente:
			if ele_tras - meu_frente < _pe.s0 + v * TROCA_BRECHA_FRENTE:
				return false
		else:
			return false
	return true


## Quem esta atravessando a rua na frente (`TravessiaDePedestre.ativas`) fora do
## cruzamento em que o juiz olha — no meio do quarteirao, onde uma viela encosta
## na avenida e a calcada atravessa sem sinal nem PARE. La o carro nao tinha
## evento nenhum, e so via a pessoa quando ela entrava no corredor dele: na rua
## solta da bancada, tres atropelos no mesmo ponto. (distancia do bico ate onde
## parar, ate onde passar devagar); INF: nada.
func _travessia_a_frente(v: float) -> Vector2:
	var saida := Vector2(INF, INF)
	if TravessiaDePedestre.ativas.is_empty() or _poli.size() < 2:
		_parando_por.clear()
		return saida
	var s_bico := _eixo * 0.5 + _comp * 0.5
	var meia := float(carro._medidas.get("largura", 1.7)) * 0.5
	var p2 := Vector2(carro.global_position.x, carro.global_position.z)
	var longe := (ALCANCE_LIDER + 15.0) * (ALCANCE_LIDER + 15.0)
	var parando: Dictionary = {}
	for tr: TravessiaDePedestre in TravessiaDePedestre.ativas:
		if tr == null or not is_instance_valid(tr.ped) or tr.esperando():
			continue
		var z := tr.zebra
		if z.ij == pub_ij or z.ij == pub_saindo_ij or z.centro.distance_squared_to(p2) > longe:
			continue
		var na := _na_zebra(z, s_bico)
		var d_bico := na.x
		if d_bico == INF or d_bico < -2.0:
			continue
		var ac := na.y
		var t_in := Longitudinal.tempo_ate(maxf(d_bico, 0.0), v, 2.0, maxf(v, 1.0))
		var t_out := t_in + (z.hi - z.lo + 5.0 + _comp) / maxf(v, 2.0)
		var lo := ac - meia - JuizDeCruzamento.PED_MARGEM
		var hi := ac + meia + JuizDeCruzamento.PED_MARGEM
		var id := tr.get_instance_id()
		var parar := JuizDeCruzamento._pessoa_na_faixa(tr.ped, z, lo, hi, Vector2(t_in, t_out))
		# Decidiu parar por ela: espera ela SAIR da faixa dele, onde ela esta, e nao
		# onde a previsao diz que vai estar. So pela previsao a decisao piscava a
		# cada passo dela (mais devagar, chega depois, ela ja passou; anda, chega
		# antes, ela esta la), e o carro ia rolando a 2-3 m/s para cima de quem
		# atravessava (bancada, meio_par).
		if not parar and _parando_por.has(id):
			var q := Vector2(tr.ped.global_position.x, tr.ped.global_position.z)
			var ac_q := z.atravessado(q)
			parar = ac_q >= lo - 0.5 and ac_q <= hi + 0.5
		if parar:
			var alvo := _parar_fora_das_faixas(z, d_bico - 1.0, s_bico, v,
				int(_parando_por.get(id, -1)))
			parando[id] = int(alvo.y)
			saida.x = minf(saida.x, alvo.x)
		# Devagar so se ela estiver na faixa ao lado ENQUANTO ele passa, sem as
		# folgas de antes e depois: essas ja estao na decisao dela de descer
		# (`TravessiaDePedestre` da 2 s e 2,5 m de lataria ao carro).
		elif JuizDeCruzamento._pessoa_na_faixa(tr.ped, z, lo - 2.0, hi + 2.0,
				Vector2(t_in, t_out), 0.0, 0.0):
			saida.y = minf(saida.y, d_bico)
	_parando_por = parando
	return saida


## Onde o caminho planejado entra na zebra `z`, com 2,5 m de folga antes da
## pintura: (distancia do bico ate la, atravessado do caminho nela); x = INF: nao
## a cruza. A borda e interpolada entre as amostras do caminho (a cada
## `PASSO_POLI`, 2 m): pelo primeiro ponto dentro, o alvo de parada andava aos
## saltos de ate 2 m junto com o carro, e o fim da parada virava freada de
## emergencia (bancada, meio_par: 7,5 m/s2 a 1,4 m/s).
func _na_zebra(z: Esquina.Zebra, s_bico: float) -> Vector2:
	var lo := z.lo - 2.5
	var hi := z.hi + 2.5
	for k in _poli.size():
		var al := z.ao_longo(_poli[k])
		var ac := z.atravessado(_poli[k])
		if al < lo or al > hi or absf(ac) > z.meia + 0.5:
			continue
		var s := _poli_s[k]
		if k > 0:
			var al0 := z.ao_longo(_poli[k - 1])
			if (al0 < lo or al0 > hi) and not is_equal_approx(al, al0):
				var borda := lo if al0 < lo else hi
				s = lerpf(_poli_s[k - 1], _poli_s[k], clampf((borda - al0) / (al - al0), 0.0, 1.0))
		return Vector2(s - s_bico, ac)
	return Vector2(INF, 0.0)


## Onde parar antes da zebra `z` (`d_parar`, do bico) sem ficar com a lataria
## em cima de outra zebra do mesmo no. No meio do quarteirao as duas faixas da
## avenida ficam a 5 m uma da outra, e o carro que parava para a de la cobria a
## de ca inteira: quem atravessava a de ca passava rente a ele, e levava um
## empurrao quando ele arrancava (rua solta da bancada, duas vezes no mesmo
## ponto). Para antes da primeira se a freada ate la couber
## (`FAIXA_LIVRE_B`); senao fica onde ia, e quem vai atravessar a de ca espera
## (`TravessiaDePedestre._passagem_vista`). `ja`: o braco da zebra antes da qual
## ele ja decidiu parar. Devolve (onde parar, do bico; antes de que braco).
func _parar_fora_das_faixas(z: Esquina.Zebra, d_parar: float, s_bico: float,
		v: float, ja := -1) -> Vector2:
	var d := d_parar
	var escolha := z.braco
	for b in 4:
		if b == z.braco or not Esquina.existe_braco(z.ij, b):
			continue
		var z2 := Esquina.zebra(z.ij, b)
		var d_in := _na_zebra(z2, s_bico).x
		if d_in == INF or d_in > d:
			continue
		# Fim da pintura, do bico: o caminho anda ao longo do braco.
		var d_fim := d_in + 2.5 + (z2.hi - z2.lo)
		if d - _comp > d_fim + 0.5:
			continue
		# Ja parado ali (com meio metro de sobra no freio), continua valendo.
		var antes := d_in - 1.0
		if antes < -0.5:
			continue
		# A conta do conforto so decide; decidido, fica. Refeita a cada quadro, perto
		# do ponto e devagar ela passava do teto, o alvo pulava para a outra faixa e
		# o carro rolava para cima desta (bancada, meio_par: 112 quadros parado em
		# cima dela e 7,5 m/s2 no fim).
		if b != ja and v * v / (2.0 * maxf(antes, 0.1)) > FAIXA_LIVRE_B:
			continue
		if antes < d:
			d = antes
			escolha = b
	return Vector2(d, escolha)


# --- contorno ---------------------------------------------------------------

## O criterio de contornar e o de sempre (`Carro._talvez_contornar`); o que
## muda e a forma: S de ida em `CONTORNO_ENTRA`, reto ao lado do parado, S de
## volta em `CONTORNO_SAI` depois que a traseira passou dele.
func _contornar(delta: float, sinal: bool) -> void:
	var s := _s_base + _s
	if _desvio_d != 0.0:
		if s >= _desvio.w:
			_desvio_d = 0.0
			carro._contorno = 0.0
			carro._contornado = null
			carro._contorno_lado = 0.0
		else:
			carro._contorno = Carro.TEMPO_CONTORNO
		return
	carro._talvez_contornar(delta, sinal)
	if carro._contorno <= 0.0 or carro._obst_dist == INF:
		return
	var outro := carro._contornado as Carro
	var comp_outro := 4.5
	if outro != null and is_instance_valid(outro):
		comp_outro = float(outro._medidas.get("comprimento", 4.5))
	var balanco := (_comp - _eixo) * 0.5
	var frente := s + _eixo * 0.5 + _comp * 0.5
	var fim_outro := frente + 0.1 + carro._obst_dist + comp_outro
	var ida := s + CONTORNO_ENTRA
	var volta := maxf(ida, fim_outro + 1.0 + balanco)
	_desvio = Vector4(s, ida, volta, volta + CONTORNO_SAI)
	# Pela esquerda, como antes (`Carro._contorno_lado = -1`).
	_desvio_d = Carro.CONTORNO_LATERAL


## Desvio lateral do contorno em `s`: (d, d', d'').
func _desvio_em(s: float) -> Vector3:
	var d := _desvio_d
	if s <= _desvio.x or s >= _desvio.w:
		return Vector3.ZERO
	if s < _desvio.y:
		var l := _desvio.y - _desvio.x
		var q := Manobra._suave((s - _desvio.x) / l)
		return Vector3(d * q.x, d * q.y / l, d * q.z / (l * l))
	if s <= _desvio.z:
		return Vector3(d, 0.0, 0.0)
	var l2 := _desvio.w - _desvio.z
	var q2 := Manobra._suave((s - _desvio.z) / l2)
	return Vector3(d * (1.0 - q2.x), -d * q2.y / l2, -d * q2.z / (l2 * l2))


# --- seta -------------------------------------------------------------------

func _atualizar_pisca(delta: float) -> void:
	carro._pisca_tempo += delta
	var lado := 0
	var v := carro._velocidade
	var antes := maxf(v * PISCA_ANTES_S, PISCA_ANTES_MIN)
	var acc := -_s
	for m: Manobra in _pecas:
		if acc > antes + 5.0:
			break
		if m.pisca != 0 and acc + m.pisca_ini <= antes and acc + m.pisca_fim > 0.0:
			lado = m.pisca
			break
		acc += m.comprimento
	if lado != carro._pisca_lado:
		carro._pisca_lado = lado
		carro._pisca_tempo = 0.0


# --- cruzamentos ------------------------------------------------------------

## Passou do meio de um cruzamento: ele vira o de onde se veio, e o proximo
## passa a ser o que o sinal e o PARE olham (`Carro._aproxima`).
func _atualizar_eventos() -> void:
	var centro_s := _s_base + _s + _eixo * 0.5
	while not _eventos.is_empty() and centro_s >= float(_eventos[0]["s"]):
		var ev: Dictionary = _eventos.pop_front()
		carro.cruzamento = ev["ij"]
		carro.trecho = ev["saida"]
		# O que era decidido para este cruzamento fica com ele. A lataria ainda
		# esta la: ele segue publicado como DENTRO ate sair (`_atualizar_saindo`).
		_saindo = ev
		# O que o carro via de gente na zebra de saida passa para o movimento de
		# que ele esta saindo.
		_s_pedestre_saindo = _s_pedestre
		_parar_em = NENHUM
		_passa_em = NENHUM
		_pare_parou = NENHUM
		_pare_espera = 0.0
		_parando = false
		_entrou_em = NENHUM
		_veredito = JuizDeCruzamento.Veredito.LIVRE
		_s_pedestre = INF
		_cede_t = 0.0
		pub_desde = -1.0
	if _eventos.is_empty():
		_garantir_horizonte()
	var prox: Vector2i = (_eventos[0]["ij"] if not _eventos.is_empty()
		else Vias.proximo_cruzamento(carro.cruzamento.x, carro.cruzamento.y, carro.trecho))
	carro.destino = prox
	carro._aproxima = prox
	carro._curvando = false


# --- planejamento -----------------------------------------------------------

func _garantir_horizonte() -> void:
	var ate := _s_base + _s + HORIZONTE
	var voltas := 0
	while _plano_s < ate and voltas < 6:
		var t0 := Time.get_ticks_usec()
		_planejar_proximo()
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		if _iniciando:
			pior_inicial_ms = maxf(pior_inicial_ms, ms)
		else:
			pior_planejar_ms = maxf(pior_planejar_ms, ms)
			if planejamentos.size() < 400:
				planejamentos.append(ms)
		voltas += 1


# --- aquecer a malha ----------------------------------------------------------

## Cruzamentos em volta dos quais a malha ja foi consultada: o `Tracado` e o
## `Relevo` guardam o resultado (com trava), e a segunda pergunta custa 0,03 a
## 1 ms em vez de 7 a 60 ms (tests/_tmp_perfil_planejar, 25/09/2026). Escrito
## pelo fio de fundo.
static var _quentes: Dictionary = {}
static var _trava_quentes := Mutex.new()
## Pedidos ja feitos. So o fio principal mexe.
static var _pedidos: Dictionary = {}
const TETO_AQUECIDOS := 4000


static func _quente(ij: Vector2i) -> bool:
	_trava_quentes.lock()
	var sim := _quentes.has(ij)
	_trava_quentes.unlock()
	return sim


## Consulta, no WorkerThreadPool, o que vai ser perguntado para planejar a
## chegada em `ij` por `t`: as saidas dele e, para cada uma, as saidas do
## cruzamento seguinte (a pergunta de beco). `Vias` e funcao pura da malha, e as
## unicas memorias no caminho sao as do `Tracado` e do `Relevo`, que tem trava.
static func aquecer(ij: Vector2i, t: Vector4i) -> void:
	var chave := Vector4i(ij.x, ij.y, t.z, t.w)
	if _pedidos.has(chave):
		return
	if _pedidos.size() >= TETO_AQUECIDOS:
		_pedidos.clear()
	_pedidos[chave] = true
	WorkerThreadPool.add_task(MotoristaIA._aquecer_no_fundo.bind(ij, t), false,
		"transito: malha")


static func _aquecer_no_fundo(ij: Vector2i, t: Vector4i) -> void:
	for e: Vector4i in Vias.saidas(ij.x, ij.y, t):
		var prox := Vias.proximo_cruzamento(ij.x, ij.y, e)
		Vias.saidas(prox.x, prox.y, e)
		_marcar_quente(prox)
	_marcar_quente(ij)


static func _marcar_quente(ij: Vector2i) -> void:
	_trava_quentes.lock()
	if _quentes.size() >= TETO_AQUECIDOS:
		_quentes.clear()
	_quentes[ij] = true
	_trava_quentes.unlock()


## Custo, lido pela bancada: o pior planejamento de um quarteirao (fora o
## primeiro de cada carro, que sai do `replanejar`), o pior primeiro, e a soma
## dos passos (para a media), em ms.
static var pior_planejar_ms := 0.0
static var pior_inicial_ms := 0.0
static var planejamentos := PackedFloat32Array()
var _iniciando := false
static var soma_passo_ms := 0.0
static var passos := 0


## Velocidade da via da linha em que o trecho `t` corre saindo de `de`.
static func _v_via(de: Vector2i, t: Vector4i) -> float:
	var classe := Vias.classe_x(de.x) if t.z == 0 else Vias.classe_z(de.y)
	return Carro.VEL_AVENIDA if classe == MalhaUrbana.Via.AVENIDA else Carro.VEL_CRUZEIRO


static func _dir2(t: Vector4i) -> Vector2:
	var d := Vias.direcao(t.z, t.w)
	return Vector2(d.x, d.z)


static func _plano(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _faixas_da_linha(ij: Vector2i, eixo: int) -> int:
	return Vias.faixas(MalhaUrbana.via_x(ij.x) if eixo == 0 else MalhaUrbana.via_z(ij.y))


## Planeja o proximo quarteirao: a reta ate o cruzamento, a escolha de saida
## e, se for conversao, a curva.
func _planejar_proximo() -> void:
	var de := _plano_de
	var t := _plano_trecho
	var p0 := _plano_ponto
	var dir := _dir2(t)
	var ij := Vias.proximo_cruzamento(de.x, de.y, t)
	var v_via := _v_via(de, t)
	if ij == de:
		_planejar_retorno_aqui(p0, t, v_via)
		return
	# Replanejado ja alem do meio do cruzamento (plantado ou solto pela blitz em
	# cima dele): ele fica para tras, e o planejamento segue do mesmo ponto.
	if (Manobra.encontro(ij.x, ij.y, t, t) - p0).dot(dir) <= 0.0:
		_plano_de = ij
		if _pecas.is_empty():
			carro.cruzamento = ij
		return
	# Troca de faixa so fora do cruzamento de onde se sai: depois do asfalto da
	# transversal e da zebra. Voltando para a faixa (blitz, plantado), comeca ja.
	var ini := 0.0
	if _reentrada == Vector2.ZERO:
		var c_de := Vector2(float(de.x) * Vias.TAM, float(de.y) * Vias.TAM)
		var miolo := (Vias.meia_asfalto_z_no(de.x, de.y) if t.z == 0
			else Vias.meia_asfalto_x_no(de.x, de.y))
		ini = maxf(2.0, (c_de - p0).dot(dir) + miolo + SAIDA_DO_MIOLO)
	# Desistiu de uma troca de faixa (`_conferir_troca`): este quarteirao sai pela
	# faixa em que ele esta, se der.
	var sem_troca := _sem_troca
	_sem_troca = false
	var opcoes := _opcoes(ij, t, p0, v_via, _reentrada != Vector2.ZERO, ini, sem_troca)
	if opcoes.is_empty() and sem_troca:
		opcoes = _opcoes(ij, t, p0, v_via, _reentrada != Vector2.ZERO, ini)
	if opcoes.is_empty() and _reentrada != Vector2.ZERO:
		# Sem reta para voltar a faixa com calma: volta no que houver.
		opcoes = _opcoes(ij, t, p0, v_via, false, ini)
	if opcoes.is_empty():
		_planejar_retorno(ij, t, p0, v_via)
		return
	var o := _sortear(opcoes)
	var fa: int = o["faixa"]
	var t_fa := Vias.trecho(t.z, t.w, fa)
	var para: Vector4i = o["para"]
	# O quarteirao seguinte se planeja daqui a uns segundos: a malha dele vai
	# sendo consultada agora, fora do fio principal.
	aquecer(o["prox"], para)
	var curva: Manobra = o.get("curva")
	var fim_reta: Vector2 = (curva.inicio() if curva != null
		else Manobra.encontro(ij.x, ij.y, t_fa, t_fa))
	var l_reta := maxf((fim_reta - p0).dot(dir), 0.05)
	var b := p0 + dir * l_reta
	var esq := Manobra.esquerda_de(Manobra.rumo_de(dir))
	var desloc := 0.0
	if fa != t.x:
		desloc = (Manobra.encontro(ij.x, ij.y, t_fa, t_fa)
			- Manobra.encontro(ij.x, ij.y, t, t)).dot(esq)
	var reta: Manobra
	if desloc != 0.0 or _reentrada != Vector2.ZERO:
		var l_troca: float = o.get("l_troca", 0.0)
		if desloc == 0.0:
			l_troca = clampf(maxf(VOLTA_MIN, v_via * VOLTA_S), 0.05, l_reta * 0.8)
		reta = Manobra.reta_desviada(p0, b, _reentrada.x, _reentrada.y, desloc,
			ini, minf(ini + l_troca, l_reta))
		reta.trecho = t
		reta.trecho_fim = t_fa
		reta.s_troca = ini + l_troca * 0.5
		if desloc != 0.0:
			reta.pisca = 1 if desloc < 0.0 else -1
			reta.pisca_ini = ini
			reta.pisca_fim = ini + l_troca
	else:
		reta = Manobra.reta(p0, b)
		reta.trecho = t
		reta.trecho_fim = t
	_reentrada = Vector2.ZERO
	reta.v_via = v_via
	reta.preparar_faixas()
	_pecas.append(reta)
	_plano_s += reta.comprimento
	if curva != null:
		curva.trecho = t_fa
		curva.trecho_fim = para
		curva.s_troca = curva.comprimento * 0.5
		curva.v_via = minf(v_via, _v_via(ij, para))
		curva.pisca = Manobra.lado_da_curva(t_fa, para)
		curva.pisca_ini = 0.0
		curva.pisca_fim = curva.comprimento
		curva.preparar_faixas()
		_pecas.append(curva)
		_eventos.append(_evento(ij, t, _plano_s + curva.comprimento * 0.5, para, t_fa,
			_plano_s))
		_plano_s += curva.comprimento
		_plano_ponto = curva.fim()
	else:
		_eventos.append(_evento(ij, t, _plano_s, para, t_fa, _plano_s))
		_plano_ponto = fim_reta
	_plano_de = ij
	_plano_trecho = para


## Um cruzamento no caminho. O que ele e (sinal, PARE para quem chega por `t`,
## a preferencial) se pergunta a malha uma vez, aqui, e nao a cada passo: cada
## pergunta passa pela trava do `Tracado`. `s_ref` e o `s` do comeco da curva
## (ou do encontro das faixas, seguindo reto): liga o carro ao `Movimento`.
static func _evento(ij: Vector2i, t: Vector4i, s: float, saida: Vector4i,
		chegada: Vector4i, s_ref: float, retorno := false) -> Dictionary:
	var sinal := Semaforo.tem_sinal(ij.x, ij.y)
	var existe := Vias.existe_cruzamento(ij.x, ij.y)
	var pref := Vias.preferencial(ij.x, ij.y) if existe and not sinal else -1
	var pare := not sinal and existe and t.z != pref
	return {"ij": ij, "eixo": t.z, "s": s, "saida": saida, "chegada": chegada,
		"sinal": sinal, "pare": pare, "pref": pref, "s_ref": s_ref, "retorno": retorno}


## As saidas possiveis em `ij` para quem chega por `t` a partir de `p0`, cada
## uma com a faixa de chegada que ela exige, o trecho de saida (com faixa), a
## curva (se houver), a extensao da troca de faixa e o peso.
func _opcoes(ij: Vector2i, t: Vector4i, p0: Vector2, v_via: float,
		com_volta: bool, ini: float, sem_troca := false) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var dir := _dir2(t)
	var faixas_ap := _faixas_da_linha(ij, t.z)
	var outro := 1 - t.z
	var faixas_sai := _faixas_da_linha(ij, outro)
	var pi_reto := Manobra.encontro(ij.x, ij.y, t, t)
	var l_pi := (pi_reto - p0).dot(dir)
	var candidatos: Array[Dictionary] = []
	var reto := Vias.trecho(t.z, t.w, t.x)
	if Vias.proximo_cruzamento(ij.x, ij.y, reto) != ij:
		candidatos.append({"rumo": Rumo.RETO, "faixa": t.x, "para": reto, "peso": PESO_RETO})
		if faixas_ap > 1:
			var troca := Vias.trecho(t.z, t.w, 1 - clampi(t.x, 0, 1))
			candidatos.append({"rumo": Rumo.TROCA, "faixa": troca.x, "para": troca,
				"peso": PESO_TROCA})
	for s: int in [1, -1]:
		var vira := Vias.trecho(outro, s, 0)
		if Vias.proximo_cruzamento(ij.x, ij.y, vira) == ij:
			continue
		var lado := Manobra.lado_da_curva(t, vira)
		if lado > 0:
			candidatos.append({"rumo": Rumo.DIREITA, "faixa": 0, "para": vira,
				"peso": PESO_VIRA})
		else:
			candidatos.append({"rumo": Rumo.ESQUERDA, "faixa": 1 if faixas_ap > 1 else 0,
				"para": Vias.trecho(outro, s, 1 if faixas_sai > 1 else 0), "peso": PESO_VIRA})
	for c: Dictionary in candidatos:
		var fa: int = c["faixa"]
		var t_fa := Vias.trecho(t.z, t.w, fa)
		var l_reta := l_pi
		if c["rumo"] == Rumo.DIREITA or c["rumo"] == Rumo.ESQUERDA:
			var curva := Manobra.curva_de_cruzamento(ij.x, ij.y, t_fa, c["para"])
			c["curva"] = curva
			l_reta = (curva.inicio() - p0).dot(dir)
		# A volta para a faixa (blitz, carro plantado torto) tambem precisa de reta.
		var precisa := VOLTA_MIN if com_volta else 0.5
		if fa != t.x:
			if sem_troca:
				continue
			var l_troca := minf(TROCA_MAX, maxf(TROCA_MIN, v_via * TROCA_S))
			l_troca = minf(l_troca, l_reta - ini - TROCA_FOLGA_FIM)
			if l_troca < TROCA_MIN:
				continue
			c["l_troca"] = l_troca
		elif l_reta < precisa:
			continue
		# Saida que leva a um cruzamento sem saida nenhuma: beco. So se a malha
		# de la ja foi consultada (`aquecer`): fria, a pergunta custava ate 60 ms
		# num quadro, e um beco que escapa acaba em meia volta, nao em defeito.
		var prox := Vias.proximo_cruzamento(ij.x, ij.y, c["para"])
		c["prox"] = prox
		c["beco"] = _quente(prox) and Vias.saidas(prox.x, prox.y, c["para"]).is_empty()
		saida.append(c)
	var sem_beco: Array[Dictionary] = []
	for c: Dictionary in saida:
		if not bool(c["beco"]):
			sem_beco.append(c)
	return sem_beco if not sem_beco.is_empty() else saida


func _sortear(opcoes: Array[Dictionary]) -> Dictionary:
	while not _forcar.is_empty():
		var quero: int = _forcar.pop_front()
		for o: Dictionary in opcoes:
			if o["rumo"] == quero:
				return o
		push_warning("MotoristaIA: manobra forcada %s impossivel aqui" % Rumo.keys()[quero])
	var total := 0.0
	for o: Dictionary in opcoes:
		total += float(o["peso"])
	var corte := _rng.randf() * total
	for o: Dictionary in opcoes:
		corte -= float(o["peso"])
		if corte <= 0.0:
			return o
	return opcoes[opcoes.size() - 1]


## Nenhuma saida em `ij`: meia volta no cruzamento, para a faixa do outro
## sentido. A escolha de saida evita chegar aqui; e o ultimo recurso.
func _planejar_retorno(ij: Vector2i, t: Vector4i, p0: Vector2, v_via: float) -> void:
	var dir := _dir2(t)
	var pi_reto := Manobra.encontro(ij.x, ij.y, t, t)
	var l_reta := maxf((pi_reto - p0).dot(dir), 0.05)
	var reta := Manobra.reta(p0, p0 + dir * l_reta)
	reta.trecho = t
	reta.trecho_fim = t
	reta.v_via = v_via
	_pecas.append(reta)
	_plano_s += reta.comprimento
	var volta := Vias.trecho(t.z, -t.w, 0)
	var eixo_linha := (Vector2(float(ij.x) * Vias.TAM, pi_reto.y) if t.z == 0
		else Vector2(pi_reto.x, float(ij.y) * Vias.TAM))
	var alvo := Manobra.encontro(ij.x, ij.y, volta, volta)
	var raio := maxf(0.5 * pi_reto.distance_to(eixo_linha) + 0.5 * alvo.distance_to(eixo_linha), 1.0)
	var arco := Manobra.retorno(pi_reto, dir, raio)
	arco.trecho = t
	arco.trecho_fim = volta
	arco.s_troca = arco.comprimento * 0.5
	arco.v_via = v_via
	arco.pisca = -1
	arco.pisca_fim = arco.comprimento
	arco.preparar_faixas()
	_pecas.append(arco)
	_eventos.append(_evento(ij, t, _plano_s + arco.comprimento * 0.5, volta, t, _plano_s,
		true))
	_plano_s += arco.comprimento
	_plano_ponto = arco.fim()
	_plano_de = ij
	_plano_trecho = volta


## A reta em que o carro esta nao leva a cruzamento nenhum (estado de partida
## ruim): meia volta onde ele esta.
func _planejar_retorno_aqui(p0: Vector2, t: Vector4i, v_via: float) -> void:
	var dir := _dir2(t)
	var volta := Vias.trecho(t.z, -t.w, 0)
	var arco := Manobra.retorno(p0 + dir * 2.0, dir, 2.5)
	var reta := Manobra.reta(p0, p0 + dir * 2.0)
	reta.trecho = t
	reta.trecho_fim = t
	reta.v_via = v_via
	_pecas.append(reta)
	arco.trecho = t
	arco.trecho_fim = volta
	arco.s_troca = arco.comprimento
	arco.v_via = v_via
	arco.pisca = -1
	arco.pisca_fim = arco.comprimento
	arco.preparar_faixas()
	_pecas.append(arco)
	_plano_s += reta.comprimento + arco.comprimento
	_plano_ponto = arco.fim()
	_plano_trecho = volta
