## Os outros padres da cena da janela: a cabeca de criatura nos romeiros que a
## lente ve atras do principal, e um deles na janela do passageiro batendo a
## testa no vidro enquanto o principal bate na do motorista.
##
## Por que existe
## --------------
## Com o principal sozinho destruindo a cara no vidro, os outros eram figurantes
## de faixa parados na mata: a cena era um homem so. Quando a lente escapa para
## o lado no meio das cabecadas, tem de haver outro fazendo o mesmo — outro
## ritmo, outra pose, o vidro dele trincando e sujando de sangue. Mas so o
## vidro do principal estoura: o do passageiro fica, rachado.
##
## Como funciona
## -------------
## `montar` troca o rosto de faixa dos romeiros da meia-lua pela
## `CabecaDoPadre` (o mesmo rosto do principal; so este arquivo veste, a
## `MonstroDaEstrada` continua como era) e leva um deles para fora da porta do
## passageiro, curvado como o principal. A pose de cabecada e a mesma
## `CabecadaDoPadre`; quem pede cada golpe e a cena (`golpe`), com antecipacao,
## bote e forca proprios. No contato: sangue e trinca no vidro dele, o dano da
## cara subindo de 1 a 2, um baque abafado. O olho dele nao sai.
##
## A entrada tem ordem, e os golpes esperam por ela: ele chega ao vidro, as
## maos sobem de tras da porta e batem no vidro uma depois da outra (tapa, som,
## aperto), ele para um instante encarando, e so entao o primeiro golpe da cena
## sai (`golpe` fica na fila ate `_pronto_em`). O tique de pescoco fica
## desligado na janela: os estalos dele (a orelha no ombro, o queixo no peito)
## levavam a testa 50 cm para baixo, e a cabecada, para manter a testa no vidro,
## empurrava o corpo pela porta.
class_name PadresNasJanelas
extends Node

## Qual romeiro vai para a janela do passageiro: o 3 esta longe, atras, e nao
## e dos que piscam (a cena esconde um em cada tres por uns quadros).
const QUAL := 3
## A altura dele na janela (m). O romeiro 3 da meia-lua (`FIGURAS[3]`) tem
## 1,80; na janela vai outro corpo, o mesmo romeiro montado de novo nesta altura
## (`preparar_bracos`), como o do capo: com o principal e o do capo em ~1,70, o
## de 1,80 era o mais alto dos tres, e a cabeca e o capuz enchiam o vidro.
const ALTURA := 1.70
## A testa descansando longe do vidro (m), e o quanto ela passa do plano do
## vidro no golpe (a pele cede um fio). Com 12 mm a testa entrava 9,5 mm na
## cabine a cada golpe.
const PERTO := 0.11
const AMASSA := 0.003
## A testa de repouso acima do meio do vidro (m).
const SOBRE_O_MEIO := 0.09
## O dano da cara dele a cada golpe (do primeiro ao quarto em diante).
const DANO := [1.0, 1.35, 1.7, 2.0]
## As maos espalmadas no vidro, dos dois lados da cara: (para a frente do
## carro, acima do ponto da testa) em m, no plano da janela. Na altura dos
## olhos e bem abertas, fora de onde a testa e o sangue batem: a 0,25-0,27 m o
## ombro ficava a 26 cm do punho e o cotovelo fechava em 37 graus; acima da
## cabeca elas liam como quem se rende.
const MAOS := [Vector2(0.27, -0.005), Vector2(-0.28, 0.025)]
## O quanto os dedos abrem para fora do eixo.
const MAO_ABRE := 0.2
## O braco esculpido na medida dele (fracao do `BracoDoPadre.ESCALA`, o do
## principal de dois metros: 0,39 + 0,26 m do ombro ao punho). Num homem de
## 1,80 com a cara no vidro e a mao do lado dela, o ombro ficava a 26-35 cm do
## punho e o cotovelo fechava em 37-56 graus, ou o ombro recuava para dentro do
## peito (`OMBRO_FOLGA`). Vai no `escala` do braco, como o do capo.
const ESCALA_BRACO := 0.72
## A folga a mais do colisor do braco (m; `BracoNoPano.margem`, 12 mm no capo):
## o braco dele e fino (raio de 16 a 31 mm) e a grade da murca tem uma
## particula a cada 3 a 5 cm; com 12 mm a malha desenhada entrava 15 a 25 mm no
## umero enquanto as maos subiam, com 40 mm fica de 4 a 19 mm so na subida, e
## depois a murca fica a 3 cm do braco.
const MARGEM_PANO := 0.04
## A folga da murca dele (`BracoNoPano.soltar_capa`): m, de que linha da grade
## em diante e a da barra de cima. Presa, com 1 a 4 cm nos ombros, o umero que
## sai para o lado a furava.
const MURCA_FOLGA := Vector3(0.16, 3, 0.0)
## Para onde o cotovelo dobra (o `polo` do braco vivo): para baixo, para o lado
## de fora dele e para longe do vidro (`--carona-polo=b,l,f` troca, na bancada).
var POLO := _flag_v3("--carona-polo=", Vector3(0.6, 0.25, 0.7))
## Onde a mao pendura antes de subir, a partir de onde ela espalma: para fora
## do vidro, para baixo e para o lado (m; `--carona-baixo=f,b,l`).
var BAIXO := _flag_v3("--carona-baixo=", Vector3(0.24, 0.42, 0.04))
## A mao comeca pendurada na reta do braco do `Corpo` (`_mao_do_corpo`), e nao
## no `BAIXO` (`--carona-baixo-fixo` volta ao `BAIXO`).
var BAIXO_DO_CORPO := not OS.get_cmdline_user_args().has("--carona-baixo-fixo")
## O arco da subida (m, na normal do vidro: + para longe dele, para o corpo).
var ARCO := _flag_v3("--carona-arco=", Vector3(0.08, 0.0, 0.0)).x
## A folga minima do ombro ao punho (m, mundo) antes de o IK degenerar (0,13 m
## no braco de 0,75, vezes a escala, e margem): so seguranca. Na pose de agora
## o ombro fica no ombro.
const OMBRO_FOLGA_CARONA := 0.15
## A face da palma sobre o vidro (m, para fora do plano da abertura): encostada.
## Com 13 mm a mao boiava e os dedos, dobrados para a palma, entravam 1,5 cm.
const PALMA_NO_VIDRO := 0.002
## A mao no vidro: espalmada (os dedos deitados no vidro, abertos em leque) e
## apertando (a base dos dedos um pouco para tras, as pontas apertando). Os
## numeros sao por dedo, medidos no braco esculpido (`--carona-sonda`): com a
## mesma dobra nos quatro, o indicador e o minimo saiam 1-2 cm do vidro, o medio
## entrava 5 mm e o anelar ficava 5 cm fora (a dobra de repouso dele, medida
## contra a direcao da mao, esta 50 graus para tras). As poses de apoio da
## `MaoPosada` sao de estofado: a ponta afunda 1 cm.
const MAO_VIDRO := {"dedos": [[6, 6, 2, 15], [-5, 3, 1, 5], [48, 4, 2, -8], [17, 10, 3, -19]],
	"polegar": [60, 12, 16, 0, 4]}
const MAO_VIDRO_FORCA := {"dedos": [[3, 7, 3, 17], [-8, 5, 3, 6], [45, 5, 3, -10],
	[14, 13, 5, -21]], "polegar": [64, 14, 16, 0, 6]}
## Quanto os dedos mexem sozinhos no vidro (0 a 1): quase nada, dedo que mexe
## em cima do que aperta parece que solta.
const DEDOS_VIVOS := 0.25
## A entrada, em s desde o `montar`: quando cada mao comeca a subir de tras da
## porta, quanto leva ate a um palmo do vidro, e o tapa.
var MAO_COMECA := [_flag_v3("--carona-mao-comeca=", Vector3(0.22, 0.52, 0)).x,
	_flag_v3("--carona-mao-comeca=", Vector3(0.22, 0.52, 0)).y]
var MAO_SOBE := _flag_v3("--carona-mao-sobe=", Vector3(0.46, 0, 0)).x
const MAO_TAPA := 0.07
## A testa chegando ao vidro (s), e depois da segunda mao, parado, encarando,
## antes da primeira cabecada (s).
const CHEGA := 0.85
const PAUSA := 0.45
## Para onde a cara gira (0 a 1, `CabecadaDoPadre.encara`): chegando, encarando
## o motorista e batendo; e o quanto a cabeca deita enquanto encara (rad).
const ENCARA_CHEGA := 0.2
const ENCARA_OLHA := 0.55
const ENCARA_GOLPE := 0.2
const TOMBA_OLHA := 0.16

var _cena: Node
var _carro: Node3D
var _cabine: Node3D
var _a: Dictionary
var _corpo: Corpo
var _cab: CabecaDoPadre
var _pose: CabecadaDoPadre
var _sangue: SangueNoVidro
var _trinca: TrincaDeVidro
var _golpes := 0
var _meio_y := 0.0
var _tw: Tween
## As duas maos no vidro (`BracoVivo`, espaco da cabine), e onde cada uma
## espalma.
var _maos: Array[BracoVivo] = []
var _no_vidro: Array[Dictionary] = []
## Quando cada mao pousou no vidro (relogio da cena, s; -1 ainda nao).
var _pouso_t: Array[float] = []
## O relogio deste no (s, com o tempo do jogo) e quando os golpes podem sair.
var _relogio := 0.0
var _pronto_em := INF
## O corpo e da janela (`_trocar_corpo`): a cena nao o anima, este no anima.
var _anima_o_corpo := false
## O pano dele contra o braco vivo (`BracoNoPano`, o mesmo do capo): os
## colisores do braco e o braco escondido do `Corpo` seguem o braco que se ve.
var _bnp: BracoNoPano
## A medida (`sonda_do_carona.gd`), so com `--carona-sonda`/`--carona-lente`.
var _medida: Node


## Veste a `CabecaDoPadre` em `c` no lugar do rosto que ele tinha (a faixa).
## Devolve a cabeca, ou null se nao deu (e o rosto velho continua).
static func vestir_cabeca(c: Corpo) -> CabecaDoPadre:
	if c == null or c.get_meta(&"rosto", null) is CabecaDoPadre:
		return c.get_meta(&"rosto", null) as CabecaDoPadre if c != null else null
	var capuz := c.get_meta(&"capuz", null) as CapuzMacabro
	var velho := c.get_meta(&"rosto", null) as Node3D
	var cab := CabecaDoPadre.vestir(c, capuz)
	if cab == null:
		return null
	if velho != null and is_instance_valid(velho):
		velho.visible = false
	if capuz != null:
		capuz.abrir_para_rosto(cab)
	c.set_meta(&"rosto", cab)
	return cab


## Um braco dos padres de fora: o `BracoDoPadre` (o braco esculpido, com
## esqueleto e manga de pano, o mesmo do principal), ou com `--braco-antigo` o
## `BracoVivo` de tubos com as `MaosPodres`. Escondido, sem pai.
static func braco(nome: String, direita: bool) -> BracoVivo:
	if OS.get_cmdline_user_args().has("--braco-antigo"):
		var b := BracoVivo.criar(nome, direita, BracosPodres.PELE, BracosPodres.MANGA, true)
		MaosPodres.vestir(b)
		b.visible = false
		return b
	return BracoDoPadre.novo(nome, direita)


## A menor distancia (m) do ombro do braco a palma. O braco esculpido tem 0,39 m
## ate o cotovelo e 0,26 m dali ao punho: com o ombro a menos de 0,13 m do punho
## nao ha triangulo, e o IK poe o cotovelo na reta, alem da mao — atravessando o
## vidro. Com esta folga ele dobra de verdade (o cotovelo sai ~0,25 m da reta).
const OMBRO_FOLGA := 0.34


## O ombro de onde o braco sai: o do esqueleto, recuado na reta da mao ate a
## folga quando esta perto demais dela (o recuo entra no tronco, debaixo da
## murca). Sem pegada ainda, o do esqueleto.
## `folga` no espaco do braco (o capo usa a de sempre).
static func ombro_com_folga(b: BracoVivo, ombro: Vector3, folga: float = OMBRO_FOLGA) -> Vector3:
	if b.pegada.is_empty():
		return ombro
	var mao: Vector3 = b.pegada["o"]
	var v := ombro - mao
	if v.length() >= folga or v.length() < 1e-4:
		return ombro
	return mao + v.normalized() * folga


## O pano do braco (manga e faixas) assenta onde o braco esta agora: depois de
## um `pular` de longe, sem isto ele chicoteia por uns quadros.
static func assentar_pano(b: BracoVivo) -> void:
	var pano := b.find_child("Pano", true, false) as SpringBoneSimulator3D
	if pano != null:
		pano.reset()


## Os dois bracos do da janela do passageiro, montados de antemao na `cabine`
## (debaixo do preto, pelo `CercoNoCarro`, que tambem os aquece): montar o
## esculpido na hora das maos subirem custava um quadro de centenas de ms, e
## os que o `BracoDoPadre.aquecer` deixa prontos sao do principal. Ficam no meta
## `bracos_carona` da cabine, [esquerdo, direito].
##
## O corpo dele na `ALTURA` nasce aqui tambem (`_preparar_corpo`).
static func preparar_bracos(cabine: Node3D) -> Array:
	if cabine == null:
		return []
	_preparar_corpo(cabine)
	var ja: Array = cabine.get_meta(&"bracos_carona", [])
	if not ja.is_empty():
		return ja
	var bs: Array = []
	for direita: bool in [false, true]:
		var b := braco("MaoCaronaPronta%s" % ("D" if direita else "E"), direita)
		b.layers = 1
		cabine.add_child(b)
		bs.append(b)
	cabine.set_meta(&"bracos_carona", bs)
	return bs


## O corpo da janela, montado de antemao (debaixo do preto, com os bracos): o
## romeiro `QUAL` de novo, na `ALTURA`, pelo `_encapuzado` da cena (a mesma
## aparencia pela mesma semente: capuz, batina e corpo AAA, cruz, aura, treva e
## tique) e ja com a `CabecaDoPadre`. Apagado, no meta `corpo_carona` da cabine;
## o `_na_janela` o troca pelo da meia-lua.
static func _preparar_corpo(cabine: Node3D) -> void:
	if cabine.has_meta(&"corpo_carona"):
		return
	var cena := _cena_de(cabine)
	if cena == null:
		return
	var us := Time.get_ticks_usec()
	var c := _montar_corpo(cena)
	if c == null:
		return
	cabine.set_meta(&"corpo_carona", c)
	print("[outros] o da janela: corpo de %.2f m no lugar do romeiro %d, montado em %.1f ms" % [
		c.altura(), QUAL, float(Time.get_ticks_usec() - us) / 1000.0])


## Quem monta os encapuzados (`_encapuzado`): a abertura, irma de algum pai da
## `cabine`, ou a bancada, que e pai dela.
static func _cena_de(no: Node) -> Node:
	var p := no.get_parent()
	while p != null:
		if p.has_method(&"_encapuzado"):
			return p
		for f: Node in p.get_children():
			if f.has_method(&"_encapuzado") and "_romeiros" in f:
				return f
		p = p.get_parent()
	return null


static func _montar_corpo(cena: Node) -> Corpo:
	var tipo := 0
	var romeiros: Array = cena.get("_romeiros") if "_romeiros" in cena else []
	if romeiros.size() > QUAL and romeiros[QUAL] is Corpo:
		var curv := float((romeiros[QUAL] as Corpo).jeito.get("curvatura", 0.05))
		tipo = maxi([0.05, 0.16, 0.03, 0.22].find(curv), 0)
	var c := cena.call(&"_encapuzado", "RomeiroDaJanela", QUAL + 1, ALTURA, tipo) as Corpo
	if c == null:
		return null
	vestir_cabeca(c)
	# O pano dele (capuz, murca e batina) so liga as texturas no primeiro quadro
	# aceso: aceso agora por uns quadros, longe de tudo, para o primeiro quadro
	# na janela ja ter o pano (sem isto ele saia careca e sem batina ali).
	var onde := c.position
	c.position = onde + Vector3.DOWN * 60.0
	c.visible = true
	var apagar := func() -> void:
		if is_instance_valid(c) and c.position.y < onde.y - 30.0:
			c.visible = false
			c.position = onde
	c.get_tree().create_timer(0.15).timeout.connect(apagar)
	return c


## Monta os padres da janela: as cabecas nos `romeiros` e o do passageiro na
## abertura `a` (a janela da frente do lado +1, espaco da cabine).
static func montar(cena: Node, carro: Node3D, romeiros: Array, cam: Camera3D,
		a: Dictionary) -> PadresNasJanelas:
	for c: Corpo in romeiros:
		vestir_cabeca(c)
	var p := PadresNasJanelas.new()
	p.name = "PadresNasJanelas"
	# Depois do laco da cena (que anima os corpos): a pose de cabecada vai por
	# cima. E antes do pano (`PanoGPU`, 100), que le os ossos: com os dois em
	# 100 a ordem era a da arvore, e o pano podia simular a pose sem a cabecada.
	p.process_priority = 99
	cena.add_child(p)
	if romeiros.size() > QUAL and carro != null and not a.is_empty():
		p._na_janela(carro, romeiros[QUAL] as Corpo, cam, a)
	return p


func _na_janela(carro: Node3D, c: Corpo, cam: Camera3D, a: Dictionary) -> void:
	_carro = carro
	_cabine = carro.get("cabine") as Node3D
	_a = a
	c = _trocar_corpo(c)
	_corpo = c
	_cab = c.get_meta(&"rosto", null) as CabecaDoPadre
	if _cabine == null or _cab == null:
		_corpo = null
		return
	if c.get_parent() != carro:
		c.get_parent().remove_child(c)
		carro.add_child(c)
	var n: Vector3 = (a["normal"] as Vector3).normalized()
	var centro: Vector3 = a["centro"]
	var n_carro := (carro.global_basis.inverse() * (_cabine.global_basis * n)).normalized()
	var c_carro := carro.to_local(_cabine.to_global(centro))
	_meio_y = c_carro.y
	var fora := Vector3(n_carro.x, 0.0, n_carro.z).normalized()
	# Do lado de fora da porta, como o principal do outro lado (0,63 m do
	# vidro), e um palmo mais para tras: nao e o espelho dele.
	c.position = Vector3(c_carro.x, 0.0, c_carro.z) + fora * 0.63 + Vector3(0.0, 0.0, 0.08)
	c.basis = Basis.looking_at(-fora, Vector3.UP)
	# Parado: sem alvo para andar.
	c.set_meta(&"rapidez", 0.0)
	# Em pe e curvado: e mais baixo que o principal, e agachado a testa batia
	# rente ao peitoril, com a cabeca escondida pela porta.
	c.agachado = false
	c.inclinacao = Vector2(0.04, 0.24)
	c.agarrar = Vector3.INF
	c.olhar_lateral(0.1, -0.8)
	var tique := c.get_meta(&"tique", null) as TiqueMacabro
	if tique != null:
		tique.modo = TiqueMacabro.Modo.JANELA
		# Sem estalo nem tremor na janela: quem move a cabeca e a cabecada.
		tique.fixar_cabeca(Vector3.ZERO, 0.2)
		tique.intensidade = 0.0
	# A corrente do crucifixo depois da cabecada (le o tronco): antes, com a
	# pose da cabecada ainda por vir, ela simulava contra o peito de antes.
	for f: Node in c.get_children():
		if f is CruzNoPeito:
			f.process_priority = 150
	for _i in 30:
		c.animar(0.0, 0.05)
	var o_vidro := carro.to_local(_cabine.to_global(centro + n * SangueNoVidro.PARA_FORA))
	_pose = CabecadaDoPadre.new(c, _cab, cam, o_vidro, n_carro)
	# A altura: em pe a testa dele fica ~56 cm acima do meio do vidro, e no
	# bote (tronco e queixo) ela desce uns 20 cm. O corpo desce o que faltar
	# para a testa de repouso ficar `SOBRE_O_MEIO` acima do meio do vidro: o
	# golpe cai no meio dele (as pernas ficam atras da porta).
	c.position.y += (c_carro.y + SOBRE_O_MEIO) - _pose.testa_no_carro().y
	_pose = CabecadaDoPadre.new(c, _cab, cam, o_vidro, n_carro)
	var capuz := c.get_meta(&"capuz", null) as CapuzMacabro
	if capuz != null:
		_pose.prender_pano(capuz.pano)
		capuz.sorriso = 0.7
	_pose.distancia = _pose.distancia_agora()
	_pose.encara = ENCARA_CHEGA
	# Chega ao vidro e freia nele.
	var chega := create_tween()
	chega.tween_property(_pose, "distancia", PERTO, CHEGA) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_sangue = SangueNoVidro.na_abertura(a, 9.0)
	if _sangue != null:
		_cabine.add_child(_sangue)
		_sangue.visible = false
	c.visible = true
	_maos_no_vidro()
	_ligar_a_medida()


## O corpo da `ALTURA` no lugar do romeiro da meia-lua (que sai de cena como
## saia antes, levado para a janela). Sem o preparado (sem o cerco), monta agora
## (e custa o quadro); sem quem monte, fica o da meia-lua.
func _trocar_corpo(c: Corpo) -> Corpo:
	if _cabine == null or c == null or absf(c.altura() - ALTURA) < 0.005:
		return c
	var novo := _cabine.get_meta(&"corpo_carona", null) as Corpo
	if (novo == null or not is_instance_valid(novo)) and _cena != null \
			and _cena.has_method(&"_encapuzado"):
		var us := Time.get_ticks_usec()
		novo = _montar_corpo(_cena)
		push_warning("[outros] o da janela montado na hora: %.1f ms" % [
			float(Time.get_ticks_usec() - us) / 1000.0])
	if novo == null or not is_instance_valid(novo):
		return c
	c.visible = false
	c.set_meta(&"em_cena", false)
	# Aceso como a cena acende quem entra (a aura na fila dela). Quem o anima e
	# este no: ele nao esta nos `_romeiros` que o laco da cena anima.
	if _cena != null and _cena.has_method(&"_mostrar"):
		_cena.call(&"_mostrar", novo)
		novo.set_meta(&"em_cena", false)
	_anima_o_corpo = true
	return novo


## `nome` + "x,y,z" na linha de comando (o que faltar fica o do `padrao`).
static func _flag_v3(nome: String, padrao: Vector3) -> Vector3:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(nome):
			var p := a.trim_prefix(nome).split(",")
			var v := padrao
			for k in mini(p.size(), 3):
				v[k] = float(p[k])
			return v
	return padrao


## A sonda e as lentes da bancada (`sonda_do_carona.gd`), so com as flags.
func _ligar_a_medida() -> void:
	var sc := load("res://src/levels/sonda_do_carona.gd") as GDScript
	if sc == null or not sc.call(&"quer"):
		return
	_medida = sc.new() as Node
	_medida.set(&"dono", self)
	add_child(_medida)


## O relogio da cena (s), ou o do jogo fora dela.
func _agora() -> float:
	if _cena != null and "_relogio_cena" in _cena:
		return float(_cena.get("_relogio_cena"))
	return Time.get_ticks_msec() / 1000.0


## Onde esta a cara dele (mundo), para a lente olhar; INF se nao ha ninguem.
func rosto() -> Vector3:
	if _corpo == null or _pose == null:
		return Vector3.INF
	return _pose.testa() + Vector3.DOWN * 0.08


## Um golpe: `recua` s de antecipacao (a cabeca para tras, `longe` m do
## vidro), `bote` s ate o vidro, e o contato com `forca` 0 a 1. O contato
## acontece `recua + bote` s depois de o golpe sair; ele sai na hora pedida, ou
## quando a entrada acabar (as duas maos no vidro e a pausa), o que vier depois.
##
## O ritmo e dele: a cabeca vai para tras e PARA la em cima um instante (o
## ultimo quarto do `recua`), e o bote sai de uma vez; colada, a cara fica, e
## descola devagar.
func golpe(recua: float, bote: float, longe: float, forca: float) -> void:
	if _pose == null:
		return
	while _relogio < _pronto_em:
		await get_tree().process_frame
		if _pose == null or not is_inside_tree():
			return
	# Um golpe de cada vez: o descolar do anterior brigava com o bote deste.
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var t := create_tween().set_parallel(true)
	_tw = t
	var vai := recua * 0.75
	t.tween_property(_pose, "recua", 1.0, vai).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(_pose, "bote", 0.0, vai * 0.6)
	t.tween_property(_pose, "distancia", PERTO + longe, vai).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(_pose, "tombo", 0.0, vai).set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(_pose, "encara", ENCARA_GOLPE, vai).set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)
	# La em cima, quase parado: so um fio mais para tras.
	t.tween_property(_pose, "distancia", PERTO + longe * 1.08, recua - vai).set_delay(vai)
	await get_tree().create_timer(recua).timeout
	if _pose == null:
		return
	if _tw != t:
		return
	var b := create_tween().set_parallel(true)
	_tw = b
	b.tween_property(_pose, "distancia", -AMASSA, bote).set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	b.tween_property(_pose, "recua", 0.0, bote).set_ease(Tween.EASE_IN)
	b.tween_property(_pose, "bote", 1.0, bote).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(bote).timeout
	# O quadro em que a pose chega no vidro (`aplicar` roda depois da cena).
	await get_tree().process_frame
	await get_tree().process_frame
	if _tw != b:
		return
	_bater(forca)
	await get_tree().create_timer(0.2).timeout
	if _pose == null or _tw != b:
		return
	var d := create_tween().set_parallel(true)
	_tw = d
	d.tween_property(_pose, "distancia", PERTO, 0.38).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_SINE)
	d.tween_property(_pose, "bote", 0.15, 0.38)


func _bater(forca: float) -> void:
	var ponto := _cabine.to_local(_carro.to_global(_pose.ponto_no_vidro()))
	print("[outros] golpe %d: testa a %.2f m de altura (meio do vidro %.2f), a %.3f m dele" % [
		_golpes, _pose.testa_no_carro().y, _meio_y, _pose.distancia_agora()])
	if _medida != null:
		_medida.call(&"golpe", _golpes)
	# Sem encostar (o golpe curto nao chega), so o baque: sangue e trinca so
	# onde a testa tocou.
	if _pose.distancia_agora() > 0.04:
		return
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	# A agua do vidro (quem estiver no grupo): ver `CercoNoCarro.GRUPO_AGUA`.
	get_tree().call_group(CercoNoCarro.GRUPO_AGUA, &"impacto", _cabine.to_global(ponto),
		(_cabine.global_basis * n).normalized(), clampf(forca, 0.0, 1.0))
	if _sangue != null:
		_sangue.visible = true
		_sangue.golpe(ponto, forca, 1.0 + 0.12 * float(_golpes))
	# A trinca e de dentro do vidro, por cima do sangue. Ela cresce, mas este
	# vidro nao estoura: so o do principal.
	if _trinca == null:
		_trinca = TrincaDeVidro.na_abertura(_a, ponto - n * 0.024, 23.0)
		if _trinca != null:
			_cabine.add_child(_trinca)
			_trinca.ajustar(&"miolo", 0.03)
			_trinca.ajustar(&"alcance", 0.14)
			_trinca.material_override.render_priority = 2
	if _trinca != null:
		_trinca.ajustar(&"alcance", minf(0.14 + 0.1 * float(_golpes), 0.5))
		_trinca.crescer(minf(0.5 + 0.15 * float(_golpes), 0.95), 0.06)
	var dano: float = DANO[mini(_golpes, DANO.size() - 1)]
	var de := _cab.dano()
	var cab := _cab
	create_tween().tween_method(func(v: float) -> void: cab.por_dano(v), de, dano, 0.045)
	_cab.por_sangue(minf(0.2 + 0.2 * float(_golpes), 0.7))
	_golpes += 1
	_maos_no_golpe(forca)
	if _cena != null and _cena.has_method(&"_som"):
		_cena.call(&"_som", &"cabecada_vidro_1", -13.0 + 2.0 * forca, 0.92)
	if _carro != null and _carro.has_method(&"pancada"):
		_carro.call(&"pancada", 0.015 * forca, 0.12 * forca)


func _process(delta: float) -> void:
	_relogio += delta
	if _medida != null:
		# Antes do pano deste quadro (`SondaBracoCapa.passo`).
		_medida.call(&"antes", delta)
	if _pose != null and _corpo != null and is_instance_valid(_corpo) and _corpo.visible:
		if _anima_o_corpo:
			# Como o laco da cena (`_assombrar`): `dominado` derruba a assinatura
			# da pose e o corpo a escreve inteira de novo; sem isto a cabecada,
			# que multiplica por cima do osso, se acumulava quadro a quadro.
			_corpo.dominado = false
			_corpo.animar(0.0, delta)
		_pose.aplicar()
		_maos_no_quadro(delta)


## A cara dele nao tem luz propria. Havia uma (`FogoNaCara`): uma omni sem
## sombra meio metro a frente da testa, que acendia a cara inteira dentro do
## capuz. Quem acende a cara agora e a luz do fogo do capo (`IncendioDoCapo`),
## com sombra: so onde a boca do capuz encara o fogo.


## As maos dele sobem de tras da porta e batem no vidro, uma depois da outra,
## dos dois lados da cara: a palma no plano da janela e os dedos abertos. O
## braco de esqueleto (a mao do `Corpo` e rigida no antebraco, nao deita a
## palma) se apaga; quem aparece sao os `BracoVivo` preparados, com o ombro no
## do esqueleto a cada quadro. Tudo aqui e no espaco da cabine (o pai dos
## bracos).
func _maos_no_vidro() -> void:
	var esq := _corpo.esqueleto()
	if esq == null:
		_pronto_em = 0.0
		return
	for nome: String in ["BracoPodreE", "BracoPodreD"]:
		var bp := esq.get_node_or_null(nome) as Node3D
		if bp != null:
			bp.visible = false
	_ligar_o_pano()
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	var pts: PackedVector3Array = _a["pontos"]
	var cima := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
	var frente := pts[0] - pts[1]
	frente = (frente - n * n.dot(frente)).normalized()
	var centro: Vector3 = _a["centro"]
	var testa := _cabine.to_local(_carro.to_global(_pose.ponto_no_vidro()))
	# Ele olha para dentro (-n): a direita dele e (-n) x cima.
	var direita_dele := (-n).cross(Vector3.UP).normalized()
	var prontos: Array = _cabine.get_meta(&"bracos_carona", [])
	# Onde o braco do `Corpo` pende agora (antes de o `BracoNoPano` gira-lo): a
	# mao viva comeca nessa reta, e o pano, que reinicia no repouso por cima
	# dele, ja esta por cima do braco que se ve.
	var pendurada := {}
	for direita: bool in [false, true]:
		pendurada[direita] = _mao_do_corpo(esq, direita)
	for k in MAOS.size():
		var m: Vector2 = MAOS[k]
		var direita := (frente * m.x).dot(direita_dele) > 0.0
		var b: BracoVivo = null
		for p: Variant in prontos:
			if is_instance_valid(p) and (p as BracoVivo).direita == direita:
				b = p as BracoVivo
				prontos.erase(p)
				break
		if b == null:
			b = braco("MaoCarona%d" % k, direita)
			_cabine.add_child(b)
		b.name = "MaoCarona%d" % k
		b.layers = 1
		if b is BracoDoPadre:
			(b as BracoDoPadre).escala = BracoDoPadre.ESCALA * ESCALA_BRACO
		b.dedos_vivos = DEDOS_VIVOS
		b.tremor = 0.0
		var lado := signf(m.x)
		# No plano do vidro, do lado de fora (a palma encosta, o dorso para fora).
		var onde := testa + frente * m.x + cima * m.y
		onde += n * (PALMA_NO_VIDRO - n.dot(onde - centro))
		var d := (cima + frente * lado * MAO_ABRE).normalized()
		# Pendurada atras da porta, abaixo do peitoril; a um palmo do vidro,
		# aberta; e espalmada nele.
		var baixo := BracoVivo.pega(onde + n * BAIXO.x - cima * BAIXO.y + frente * lado * BAIXO.z,
			(cima * 0.2 - n * 0.3 + frente * lado * 0.2).normalized(), n, &"relaxada")
		if not (pendurada[direita] as Dictionary).is_empty() and BAIXO_DO_CORPO:
			baixo = pendurada[direita]
		var perto := BracoVivo.pega(onde + n * 0.06 - cima * 0.02, d, n, &"aberta")
		var pousa := BracoVivo.pega(onde, d, n, MAO_VIDRO)
		_maos.append(b)
		_no_vidro.append(pousa)
		_pouso_t.append(-1.0)
		if _bnp != null:
			_bnp.por_braco(b.direita, b)
		b.pular(baixo)
		# Aceso antes de montar a pose: apagado, o `passo` nao remonta, e o
		# primeiro quadro aceso mostrava o braco onde o aquecimento o deixou.
		b.visible = true
		_mao_no_quadro(b, k, 0.0)
		assentar_pano(b)
		_subir(b, k, perto, pousa, float(MAO_COMECA[mini(k, MAO_COMECA.size() - 1)]))


## A mao pendurada do braco do `Corpo` do lado `direita` (a pegada, espaco da
## cabine), na reta do ombro a palma dele e no alcance do braco vivo; vazio sem
## esqueleto.
func _mao_do_corpo(esq: Skeleton3D, direita: bool) -> Dictionary:
	var ob := Corpo.Osso.BRACO_D if direita else Corpo.Osso.BRACO_E
	var oa := Corpo.Osso.ANTEBRACO_D if direita else Corpo.Osso.ANTEBRACO_E
	var s := _corpo.altura() / Corpo.ALTURA_REF
	var gx := esq.global_transform
	var ombro := gx * esq.get_bone_global_pose(ob).origin
	var ga := gx * esq.get_bone_global_pose(oa)
	var punho := ga * Vector3(0.0, -(Corpo.Y_COTOVELO - Corpo.Y_PUNHO) * s, 0.0)
	var ante := (punho - ga.origin).normalized()
	var palma := punho + ante * 0.06 * s
	var reta := palma - ombro
	if reta.length() < 0.05:
		return {}
	var alcance := (BracoDoPadre.ESCALA * ESCALA_BRACO) * 0.87 + 0.06
	var o := ombro + reta.normalized() * minf(reta.length(), alcance)
	# O dorso para fora do corpo: a palma olha a coxa.
	var meio := gx * esq.get_bone_global_pose(Corpo.Osso.TORSO).origin
	var fora := o - meio
	var d := reta.normalized()
	var dorso := (fora - d * fora.dot(d)).normalized()
	var inv := _cabine.global_transform.affine_inverse()
	return BracoVivo.pega(inv * o, (inv.basis * d).normalized(), (inv.basis * dorso).normalized(),
		&"relaxada")


## Uma mao: espera a vez, sobe ate um palmo do vidro, bate (o som e a agua no
## quadro do contato) e aperta.
func _subir(b: BracoVivo, k: int, perto: Dictionary, pousa: Dictionary, espera: float) -> void:
	await get_tree().create_timer(espera).timeout
	if not is_instance_valid(b):
		return
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	b.ir(perto, MAO_SOBE, n * ARCO, 0.35)
	await get_tree().create_timer(MAO_SOBE).timeout
	if not is_instance_valid(b):
		return
	b.ir(pousa, MAO_TAPA)
	await get_tree().create_timer(MAO_TAPA).timeout
	if not is_instance_valid(b):
		return
	if _cena != null and _cena.has_method(&"_som"):
		_cena.call(&"_som", &"mao_pousa_vidro", -13.0 + 2.0 * float(k), 0.95)
	get_tree().call_group(CercoNoCarro.GRUPO_AGUA, &"impacto",
		_cabine.to_global(pousa["o"] as Vector3), (_cabine.global_basis * n).normalized(), 0.35)
	_pouso_t[k] = _agora()
	# Aperta: os dedos cravam e a palma escorrega um fio no vidro molhado.
	var cima := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
	var aperta := pousa.duplicate()
	aperta["o"] = (pousa["o"] as Vector3) - cima * 0.004
	aperta["pose"] = MAO_VIDRO_FORCA
	_no_vidro[k] = aperta
	b.ir(aperta, 0.22)
	if _pouso_t.count(-1.0) == 0:
		_encarar()


## As duas maos no vidro: ele para e encara o motorista, a cabeca deitando
## devagar. Os golpes saem depois da `PAUSA`.
func _encarar() -> void:
	_pronto_em = _relogio + PAUSA
	if _pose == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(_pose, "encara", ENCARA_OLHA, PAUSA * 0.9).set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)
	t.tween_property(_pose, "tombo", TOMBA_OLHA, PAUSA).set_ease(Tween.EASE_IN_OUT) \
		.set_trans(Tween.TRANS_SINE)


func _maos_no_quadro(delta: float) -> void:
	for k in _maos.size():
		_mao_no_quadro(_maos[k], k, delta)


## O ombro do braco vivo no do esqueleto, do mesmo lado (o corpo vai e volta
## nas cabecadas e o cotovelo dobra de novo entre ele e a mao presa), e o
## cotovelo para baixo, para fora do corpo e um pouco para longe do vidro: o
## braco de quem se apoia numa janela. A folga do ombro e so seguranca do IK.
func _mao_no_quadro(b: BracoVivo, k: int, delta: float) -> void:
	if not is_instance_valid(b):
		return
	var esq := _corpo.esqueleto()
	var n: Vector3 = (_a["normal"] as Vector3).normalized()
	var osso := Corpo.Osso.BRACO_D if b.direita else Corpo.Osso.BRACO_E
	var ombro := _cabine.to_local(esq.global_transform * esq.get_bone_global_pose(osso).origin)
	b.ombro = ombro_com_folga(b, ombro, OMBRO_FOLGA_CARONA)
	var lado := signf((MAOS[k] as Vector2).x)
	var pts: PackedVector3Array = _a["pontos"]
	var frente := (pts[0] - pts[1]).normalized()
	b.polo = (Vector3.DOWN * POLO.x + frente * lado * POLO.y + n * POLO.z).normalized()
	b.tremor = 0.0
	b.passo(delta)
	if _bnp != null:
		_bnp.aplicar()


## O pano dele contra o braco vivo: o `BracoNoPano` do capo (os colisores do
## braco do `CorpoAAA` e o braco escondido do `Corpo` na reta do braco vivo).
## Aplicado a mao, depois do `passo` dos bracos (`automatico` falso), e antes do
## `PanoGPU` (este no roda em 99, o pano em 100). `soltar_capa` (a murca e a
## borda da cava subindo com o umero) so sem `--carona-capa-presa`.
func _ligar_o_pano() -> void:
	var capuz := _corpo.get_meta(&"capuz", null) as CapuzMacabro
	if capuz == null or capuz.pano == null:
		return
	_bnp = BracoNoPano.ligar(_corpo, capuz.pano)
	if _bnp == null:
		return
	_bnp.automatico = false
	_bnp.margem = _flag_v3("--carona-margem=", Vector3(MARGEM_PANO, 0, 0)).x
	var modo := "folga"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--carona-capa="):
			modo = a.trim_prefix("--carona-capa=")
	match modo:
		"capo":
			_bnp.soltar_capa()
		"folga":
			# So a folga (a murca da linha 3 para baixo, a borda da cava) e a
			# batina vendo o umero, sem ligar o pano ao osso nem o colisor de um
			# lado: medido na malha desenhada, foi o que menos entrou no braco.
			_bnp.soltar_capa(MURCA_FOLGA, BracoNoPano.BATINA_FOLGA, {}, Vector3.ZERO, {})


## O golpe passa pelas maos: elas apertam o vidro e escorregam um nada.
func _maos_no_golpe(forca: float) -> void:
	for k in _maos.size():
		var b := _maos[k]
		if not is_instance_valid(b) or k >= _no_vidro.size() or _pouso_t[k] < 0.0:
			continue
		var n: Vector3 = (_a["normal"] as Vector3).normalized()
		var cima := (Vector3.UP - n * n.dot(Vector3.UP)).normalized()
		var q := (_no_vidro[k] as Dictionary).duplicate()
		q["o"] = (q["o"] as Vector3) - cima * 0.006 * forca
		q["pose"] = MAO_VIDRO_FORCA
		_no_vidro[k] = q
		b.ir(q, 0.08)


func _enter_tree() -> void:
	_cena = get_parent()
