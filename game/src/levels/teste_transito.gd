## Rotina de verificacao do transito da cidade.
##
## Por que este teste existe
## -------------------------
## Porque o defeito que ele mede nao aparecia em nenhum outro. O carro dirigivel
## tinha 47 criterios verdes e a rua estava travada do mesmo jeito: o jogador
## relatou carros parando no lugar errado nos cruzamentos e carros se prendendo
## uns nos outros, e nao havia UMA medida no projeto que olhasse para o transito
## de fora. `verificar_cidade.py` conta geometria, `verificar_carro.py` mede o
## carro do jogador. O que ninguem media era a rua andando.
##
## O defeito, depois de achado, era aritmetico e cabia numa linha: a IA parava
## "assim que entrar na zona do sinal" em vez de "na linha de retencao", e a
## zona era maior que a distancia de freio. O carro entrava a 11 m/s, freava a
## 8 m/s2 e parava a 1,60 m do CENTRO do cruzamento — tres metros alem da linha,
## atravessado na frente de quem tinha verde, pelo vermelho inteiro.
##
## Por que as situacoes sao MONTADAS
## ---------------------------------
## A primeira versao so observava o transito rodando e media o que aparecesse.
## Duas execucoes seguidas, sem uma linha de codigo mudada, deram 0,53 e 1,00 de
## frota em movimento — porque o que a rua faz depende de onde o jogador nasceu,
## de quantos carros couberam na coroa e de quais semaforos eles pegaram. Um
## criterio construido em cima disso reprova e aprova sozinho.
##
## Entao o que vira criterio e montado: um carro e plantado numa faixa, a uma
## distancia conhecida de um cruzamento conhecido, com a luz conhecida. Dai o
## numero que sai e sempre do mesmo experimento. A observacao livre continua no
## relatorio como informacao — ela serve para ler, e nao para reprovar.
##
## O que se afirma aqui
## --------------------
##   parada     o carro para ANTES da linha de retencao, e nao dentro do
##              cruzamento
##   fila       quem chega atras encosta atras, com folga de para-choque, e nao
##              dentro da lataria do outro
##   verde      quando a luz abre, ele sai. Um criterio de parada sem criterio
##              de partida aprovaria uma cidade de estatuas
##   contorno   um carro parado na pista nao tranca a faixa. E a situacao que o
##              jogo produz toda vez que o jogador estaciona um carro tomado e
##              desce
##
## Imprime linhas `[transito] chave=valor` que tools/verificar_transito.py
## confere.
class_name TesteTransito
extends RefCounted

## Duracao de um passo de fisica. Nao e `get_process_delta_time()` — a mesma
## armadilha que ja falseou a arrancada do carro em `TesteCarro`.
const PASSO := 1.0 / 60.0

## Quanto esperar a rua se povoar.
const ESPERA_TRANSITO := 7.0
## Quanto tempo observar o transito rodando sozinho, em segundos. So informa.
const T_OBSERVAR := 26.0
## Quanto tempo observar o contorno, em segundos.
const T_CONTORNO := 14.0

## Parado, para efeito de medida, em m/s.
const PARADO := 0.35

## De que distancia do cruzamento o carro plantado larga, em metros. Longe o
## bastante para ele estar a toda quando comeca a enxergar o sinal.
const LARGADA := 34.0
## Quanto tempo esperar o carro plantado parar, em segundos.
const T_PARAR := 14.0
## Quanto vermelho ainda tem de faltar para valer a pena largar o carro.
##
## Ele leva uns tres segundos para cobrir os 34 m a 14 m/s, mais a frenagem.
## Doze segundos cobrem a viagem inteira com folga; com sete, a luz abria no
## meio da aproximacao e nao sobrava parada para medir.
const VERMELHO_MINIMO := 12.0


static func executar(cena: Node, jogador: Node) -> void:
	var arvore := cena.get_tree()
	_relatar("inicio", 1)
	var t := 0.0
	while t < ESPERA_TRANSITO:
		await arvore.physics_frame
		t += PASSO
	_relatar("vivos", Transito.vivos())

	await _observar(cena)
	await _medir_no_sinal(cena, jogador)
	await _medir_contorno(cena)

	_relatar("fim", 1)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[transito] %s=%s" % [chave, valor])


# --- observacao livre (informa, nao reprova) ---------------------------------

## O transito rodando sozinho. Os numeros daqui NAO viram criterio — ver o
## cabecalho —, mas sao o que se le quando um criterio montado falha e a
## pergunta vira "a cidade estava andando naquela hora?".
static func _observar(cena: Node) -> void:
	var arvore := cena.get_tree()
	var parada_maxima := 0.0
	var motivo_da_maior: StringName = &"-"
	var parados := {}
	var andado := 0.0
	var onde_estava := {}
	var amostras := 0
	var moveis := 0

	var t := 0.0
	while t < T_OBSERVAR:
		await arvore.physics_frame
		t += PASSO
		for c: Carro in Transito.lista():
			if not is_instance_valid(c) or c.motorista != Carro.Motorista.IA:
				continue
			var id := c.get_instance_id()
			if onde_estava.has(id):
				var antes: Vector3 = onde_estava[id]
				var passo_m := antes.distance_to(c.global_position)
				# Salto grande e nascimento ou reciclagem, e nao deslocamento.
				if passo_m < 1.0:
					andado += passo_m
			onde_estava[id] = c.global_position
			amostras += 1
			if absf(c.velocidade()) >= PARADO:
				moveis += 1
				parados[id] = 0.0
				continue
			var acum := float(parados.get(id, 0.0)) + PASSO
			parados[id] = acum
			if acum > parada_maxima:
				parada_maxima = acum
				motivo_da_maior = c.motivo_da_parada()

	_relatar("obs_fracao_andando", "%.2f" % (
		float(moveis) / float(maxi(1, amostras))))
	_relatar("obs_andado_m", "%.0f" % andado)
	_relatar("obs_parada_mais_longa_s", "%.1f" % parada_maxima)
	_relatar("obs_motivo_da_maior", motivo_da_maior)


# --- o experimento do sinal --------------------------------------------------

## Um carro larga a 34 m de um cruzamento com a luz vermelha. Onde ele para?
##
## E o experimento que nomeia o defeito relatado. A resposta certa e "antes da
## linha de retencao"; a que o jogo dava era "tres metros depois dela",
## atravessado no meio da esquina.
##
## Logo atras vem um segundo carro, e ele responde a outra metade: quem chega
## numa fila encosta ATRAS de quem ja esta parado, com folga, e nao dentro.
static func _medir_no_sinal(cena: Node, jogador: Node) -> void:
	var arvore := cena.get_tree()
	var lista := Transito.lista()
	var quem := jogador as Node3D
	if lista.size() < 2 or quem == null:
		_relatar("sinal_montado", 0)
		return

	# O transito para de nascer e de recolher. Ver `_medir_contorno`.
	Transito.ativo = false

	var ij := Vias.cruzamento_mais_proximo(quem.global_position)
	# Um eixo e um sentido em que exista cruzamento ANTES deste, para a rota do
	# carro plantado ter (ij) como destino.
	var eixo := -1
	var sentido := 1
	for e in 2:
		for sen: int in [1, -1]:
			var antes := (Vias.proxima_z(ij.y, -sen) if e == 0
				else Vias.proxima_x(ij.x, -sen))
			var mesmo := (ij.y if e == 0 else ij.x)
			if antes != mesmo:
				eixo = e
				sentido = sen
				break
		if eixo >= 0:
			break
	if eixo < 0:
		Transito.ativo = true
		_relatar("sinal_montado", 0)
		return

	var t := Vias.trecho(eixo, sentido, 0)
	var dir := Vias.direcao(eixo, sentido)
	var centro := Vector3(float(ij.x) * Vias.TAM, quem.global_position.y,
		float(ij.y) * Vias.TAM)
	var ponto := centro - dir * LARGADA
	# Na linha da faixa, e nao no meio da rua.
	if eixo == 0:
		ponto.x = Vias.linha_x(ij.x, sentido, 0)
	else:
		ponto.z = Vias.linha_z(ij.y, sentido, 0)
	var de := (Vector2i(ij.x, Vias.proxima_z(ij.y, -sentido)) if eixo == 0
		else Vector2i(Vias.proxima_x(ij.x, -sentido), ij.y))

	# Espera VERMELHO, e nao "qualquer coisa que nao seja verde".
	#
	# A primeira versao aceitava amarelo e o experimento media outra coisa. O
	# traco contou a historia inteira: o carro largava no amarelo, entrava no
	# alcance do sinal ainda amarelo, a 14 m/s e a 7 m da linha — e a regra do
	# amarelo, que e a regra certa, manda passar quem nao consegue parar (14 m/s
	# pedem 12,25 m e havia 7). A luz fechava atras dele e o relatorio acusava
	# "atravessou o vermelho" um carro que tinha feito exatamente o que devia.
	#
	# Vermelho com folga tambem e obrigatorio: `VERMELHO_MINIMO` tem de cobrir a
	# viagem inteira dos 34 m, senao a luz abre no meio e nao ha parada para
	# medir.
	var espera := 0.0
	while espera < Semaforo.CICLO + 2.0:
		await arvore.physics_frame
		espera += PASSO
		var luz := Semaforo.estado(ij.x, ij.y, eixo, Semaforo.agora())
		if luz == Semaforo.Luz.VERMELHO and Semaforo.ate_o_verde(
				ij.x, ij.y, eixo, Semaforo.agora()) > VERMELHO_MINIMO:
			break

	var carro: Carro = lista[0]
	var segundo: Carro = lista[1]
	if not is_instance_valid(carro) or not is_instance_valid(segundo):
		Transito.ativo = true
		_relatar("sinal_montado", 0)
		return
	carro.plantar(de, t, ponto)
	segundo.plantar(de, t, ponto - dir * 15.0)
	await arvore.physics_frame
	# A rota do carro tem de apontar para ESTE cruzamento, senao ele nem olha
	# para esta luz e a medida seria sobre outro lugar.
	_relatar("sinal_montado", 1 if carro.destino == ij else 0)
	if carro.destino != ij:
		Transito.ativo = true
		return

	var tt := 0.0
	var proxima := 0.0
	while tt < T_PARAR:
		await arvore.physics_frame
		tt += PASSO
		if tt >= proxima:
			proxima += 0.4
			var pc := centro - carro.global_position
			pc.y = 0.0
			print(("[transito.traco] t=%.1f d=%.1f v=%.1f motivo=%s luz=%d "
				+ "destino=%s aprox_ok=%d") % [tt, pc.length(),
				carro.velocidade(), carro.motivo_da_parada(),
				Semaforo.estado(ij.x, ij.y, eixo, Semaforo.agora()),
				carro.destino, 1 if carro.destino == ij else 0])
		if absf(carro.velocidade()) < 0.05 and tt > 1.0:
			break
	var parou := absf(carro.velocidade()) < 0.05

	var para_centro := centro - carro.global_position
	para_centro.y = 0.0
	# A linha vem do proprio carro, porque ela leva meio comprimento dele: o que
	# tem de parar antes do cruzamento e o BICO, e a posicao medida e a do
	# centro. Um Fusca e uma picape param em lugares diferentes pela mesma
	# regra, e a regra e uma so.
	var linha := carro.linha_de_retencao(ij)
	_relatar("sinal_parou", 1 if parou else 0)
	_relatar("sinal_do_centro_m", "%.2f" % para_centro.length())
	_relatar("sinal_linha_m", "%.2f" % linha)
	_relatar("sinal_alem_da_linha_m", "%.2f" % (linha - para_centro.length()))

	# A fila: o segundo encosta atras do primeiro?
	var ff := 0.0
	while ff < 5.0:
		await arvore.physics_frame
		ff += PASSO
	_relatar("fila_folga_m", "%.2f" % (
		carro.global_position - segundo.global_position).dot(dir))
	_relatar("fila_parou", 1 if absf(segundo.velocidade()) < PARADO else 0)

	# Abriu o verde: ele sai?
	var ate_verde := Semaforo.ate_o_verde(ij.x, ij.y, eixo, Semaforo.agora())
	var vv := 0.0
	var partiu := -1.0
	while vv < ate_verde + 6.0:
		await arvore.physics_frame
		vv += PASSO
		if vv > ate_verde and absf(carro.velocidade()) > 1.5:
			partiu = vv - ate_verde
			break
	_relatar("verde_partiu_s", "%.1f" % partiu if partiu >= 0.0 else "nunca")

	Transito.ativo = true


# --- o experimento do carro parado na pista ----------------------------------

## Um carro parado na pista tranca a faixa?
##
## A situacao e montada e nao esperada, porque e a situacao que o jogo produz
## toda vez que o jogador estaciona um carro tomado e desce — e, esperando, ela
## pode nao acontecer na janela do teste. O bloqueio e um carro da propria rua
## com o motorista expulso: para de andar e vira lataria parada na faixa, que e
## exatamente o que o carro estacionado do jogador e.
static func _medir_contorno(cena: Node) -> void:
	var arvore := cena.get_tree()
	var lista := Transito.lista()
	if lista.size() < 2:
		_relatar("contorno_montado", 0)
		return

	# O transito para de nascer e de recolher durante a medida.
	#
	# Sem isto ela nao termina: o carro que passa pelo bloqueio segue rua
	# abaixo, passa dos 74 m de `RAIO_SUMIR` e e liberado no meio do laco — e a
	# medida morreu exatamente assim, com "acesso a global_position num objeto
	# ja liberado". Congelar a populacao e o certo aqui: o que se mede e o que
	# dois carros fazem um com o outro, e nao a politica de reciclagem.
	Transito.ativo = false

	var bloqueio: Carro = lista[0]
	var atras: Carro = lista[1]
	if not is_instance_valid(bloqueio) or not is_instance_valid(atras):
		Transito.ativo = true
		_relatar("contorno_montado", 0)
		return

	var trechos := Vias.trechos_perto(bloqueio.global_position, 0.0, 40.0)
	if trechos.is_empty():
		Transito.ativo = true
		_relatar("contorno_montado", 0)
		return
	var t: Dictionary = trechos[0]
	var quadro: Vector4i = t["trecho"]
	var de: Vector2i = t["de"]
	var dir := Vias.direcao(Vias.trecho_eixo(quadro), Vias.trecho_sentido(quadro))
	var ponto: Vector3 = Transito.ponto_de_nascimento(t)

	bloqueio.plantar(de, quadro, ponto)
	# Motorista fora: a lataria fica na faixa e nao anda mais.
	bloqueio.expulsar_motorista()
	atras.plantar(de, quadro, ponto - dir * 18.0)
	await arvore.physics_frame
	_relatar("contorno_montado", 1)

	var comecou := (atras.global_position - bloqueio.global_position).dot(dir)
	var passou := false
	var contornou := false
	var preso := 0.0
	var tt := 0.0
	while tt < T_CONTORNO:
		await arvore.physics_frame
		tt += PASSO
		if not is_instance_valid(atras) or not is_instance_valid(bloqueio):
			break
		if atras.contornando():
			contornou = true
		if absf(atras.velocidade()) < PARADO:
			preso += PASSO
		if (atras.global_position - bloqueio.global_position).dot(dir) > 2.5:
			passou = true
			break

	Transito.ativo = true
	_relatar("contorno_partiu_de_m", "%.1f" % comecou)
	_relatar("contorno_decidiu", 1 if contornou else 0)
	_relatar("contorno_passou", 1 if passou else 0)
	_relatar("contorno_preso_s", "%.1f" % preso)
