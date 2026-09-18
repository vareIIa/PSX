## Rotina de verificacao do carro dirigivel.
##
## Dirigir nao da para afirmar de fora do jogo. A lataria, a suspensao, o atrito
## de pneu e o cambio sao numeros que so viram carro depois de rodar: um erro de
## sinal no esterco compila, passa no nivel 1 e so aparece quando alguem vira o
## volante e o carro vai para o outro lado. Por isso este teste PILOTA — ele
## injeta acelerador e esterco de verdade no mesmo caminho que o jogador usa, e
## mede o que saiu.
##
## O que se afirma aqui:
##
##   acesso     ha carro ao alcance, e a tecla de entrar entrega o volante. Sem
##              conversa, sem abordagem: qualquer carro, como foi pedido.
##   cambio     na BANCADA, sem cidade: as cinco marchas entram, entram mais
##              cedo com o pe leve, o carro tem 0 a 100 e velocidade final de
##              carro de rua, e o limitador corta quando a roda force o motor.
##              Fora da bancada nao daria: ver `_medir_cambio_offline`.
##   arrancada  com a ignicao ligada e o acelerador no fundo, o carro sai do
##              lugar e cruza os 40 km/h. A medida e distancia percorrida, nao
##              `engine_force` aplicada: o segundo passa com a roda no ar.
##   esterco    virando para a esquerda o carro VIRA para a esquerda. Mede-se o
##              rumo, e nao o deslocamento lateral, porque o quarteirao acaba
##              antes dos tres segundos — ver `_medir_esterco`. Este e o teste
##              barato que pega inversao de sinal, que ja aconteceu tres vezes
##              nesta frente: na face da lataria, na tracao e no volante.
##   freio      a desaceleracao com o pedal no fundo e de carro, e nao de
##              caminhao nem de carrinho de rolima.
##   painel     o mostrador existe, esta visivel, e o ponteiro acompanha o que o
##              corpo rigido esta fazendo — medido ANDANDO, por mediana.
##   som        o motor esta soando de verdade enquanto se acelera: camadas
##              tocando, volume audivel e afinacao na faixa util.
##   saida      sair devolve o jogador ao chao, de pe, fora da lataria.
##
## Imprime linhas `[carro] chave=valor` que tools/verificar_carro.py confere.
class_name TesteCarro
extends RefCounted

## Quanto esperar a rua se povoar antes de procurar carro.
const ESPERA_TRANSITO := 6.0

## Duracao de um passo de fisica, em segundos.
##
## Nao e `get_process_delta_time()`, e essa distincao ja custou uma rodada de
## numeros inteiros. Num laco de `await physics_frame`, o delta de PROCESSO e o
## do quadro de video — que em `--headless` corre solto, sem janela e sem
## sincronismo. Somando ele, "seis segundos de arrancada" eram na verdade vinte,
## e o relatorio acusou um sedan fazendo 0 a 40 km/h em 0,86 s a 1,3 g, que e
## mais aderencia do que qualquer pneu tem. O relogio da fisica e fixo; e este.
const PASSO := 1.0 / 60.0

## Quanto tempo o piloto automatico segura cada comando.
const T_ARRANCADA := 6.0
const T_ESTERCO := 3.0
const T_FREIO := 4.0

## Criterios. Cada um e um numero que um carro de cidade cumpre e um objeto
## qualquer com rodas nao cumpre.
##
## 25 m em 6 s com o pe no fundo sao 15 km/h de media — teto baixo de proposito:
## o teste roda em rua com semaforo e meio-fio, e nao numa pista reta.
const MIN_ARRANCADA := 25.0
## Velocidade de pico da arrancada, em m/s. Abaixo disso o carro nao passa da
## segunda e o cambio nunca e exercitado.
const MIN_PICO := 12.0
## Desvio lateral minimo com o volante todo para um lado, em metros.
const MIN_DESVIO := 3.0
## Desaceleracao minima com o pedal no fundo, em m/s^2. 6,5 sao 0,66 g — abaixo
## disso o carro nao para, ele desiste. Medir aceleracao e nao distancia porque a
## velocidade de entrada muda de execucao para execucao conforme o quarteirao.
const MIN_DESACEL := 6.5
## Quantas marchas diferentes o cambio tem de mostrar na arrancada.
const MIN_MARCHAS := 3


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	_relatar("inicio", 1)
	_medir_constantes()
	_medir_som_offline()
	_medir_cambio_offline()
	_medir_farois()
	_medir_motores_distintos()

	var carro := await _pegar_carro(cena, jogador)
	if carro == null:
		_relatar("acesso", 0)
		_relatar("fim", 1)
		AudioDirector.silenciar_tudo()
		await arvore.process_frame
		arvore.quit(0)
		return

	# A rua para de se mexer a partir daqui.
	#
	# O que as medidas abaixo afirmam e sobre o CARRO, e o transito e a variavel
	# que ninguem esta controlando: a faixa escolhida livre para a arrancada
	# pode ter um carro dentro dois segundos depois, a batida contra a fachada
	# pode ser contra uma lataria andando, e a corrida de aproximacao da
	# derrapagem pode terminar num para-choque — e batida em cheio AFOGA o
	# motor, entao a secao seguinte inteira mede um carro morto.
	#
	# Aconteceu duas vezes em tres execucoes, com cinco criterios vermelhos e
	# uma causa que nao era nenhum dos cinco. A diferenca entre a execucao que
	# passou e as que nao passaram foi por onde os carros da IA andaram.
	#
	# As medidas que PRECISAM de transito — quantos carros ha na rua, quantos
	# motores distintos, entrar num carro que tem motorista — ja foram feitas
	# acima. Daqui para baixo ele so atrapalha.
	Transito.ativo = false
	Transito.limpar()
	await arvore.physics_frame

	await _medir_arrancada(cena, carro)
	await _medir_esterco(cena, carro)
	await _medir_freio(cena, carro)
	await _medir_chuva(cena, carro)
	await _medir_derrapagem(cena, carro)
	await _medir_batida(cena, carro)
	await _medir_vento(cena, carro)
	await _medir_capotamento(cena, carro)
	await _medir_painel(cena, jogador, carro)
	await _medir_saida(cena, jogador, carro)

	_relatar("fim", 1)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[carro] %s=%s" % [chave, valor])


# --- o que da para medir sem rodar ------------------------------------------

## Numeros de projeto do carro. Estao aqui porque um deles zerado — forca de
## motor, atrito de pneu, esterco maximo — faz o carro compilar e nao andar, e o
## relatorio deve nomear qual.
static func _medir_constantes() -> void:
	var seda := FichaTecnica.de(Carroceria.Modelo.SEDA)
	# Forca de pico na primeira marcha do sedan, em Newtons no eixo. E o numero
	# que a constante solta de 240 N escondia: 480 N num corpo de 980 kg davam
	# meio metro por segundo ao quadrado, e o carro "andava" no papel.
	var rel: Array = seda["relacoes"]
	_relatar("torque_pico_nm", "%.0f" % float(seda["torque"]))
	_relatar("forca_primeira_n", "%.0f" % (float(seda["torque"]) * float(rel[0])
		* float(seda["diferencial"]) * Motor.EFICIENCIA / Motor.RAIO_PNEU))
	_relatar("esterco_max", Carro.ESTERCO_MAX)
	_relatar("marchas", rel.size())
	_relatar("freio_max", float(seda["freio"]))
	_relatar("giro_corte", float(seda["giro_corte"]))
	# O mostrador nao pode nascer numa quina em que a vinheta o apaga.
	_relatar("painel_vinheta", "%.2f" % PainelLayout.vinheta_do_texto(
		PainelLayout.centro(Settings.vignette), Settings.vignette))
	_relatar("painel_vinheta_min", "%.2f" % UiEstilo.VINHETA_MIN)


## O motor tem loop, partida e batida de cambio? Sem os tres arquivos o carro
## anda em silencio, que e o defeito que o pedido nomeia por ultimo.
static func _medir_som_offline() -> void:
	var faltam := 0
	for nome: StringName in [&"motor_baixo", &"motor_medio", &"motor_alto",
			&"motor_corte", &"pneu_loop", &"motor_partida", &"motor_marcha",
			&"buzina_curta", &"porta_carro"]:
		if AudioDirector.stream(nome) == null:
			faltam += 1
			print("[carro] som_ausente=%s" % nome)
	_relatar("sons_faltando", faltam)


# --- bancada do cambio -------------------------------------------------------

## O trem de forca inteiro, sem cidade.
##
## Por que isto nao e medido dirigindo
## -----------------------------------
## Porque a rua nao deixa. Para ver a quinta marcha o carro precisa de uns
## quinhentos metros de reta, e a cidade tem quarteirao de trinta e dois metros
## com meio-fio na esquina: toda execucao que tentou medir cambio dirigindo
## mediu, na verdade, contra o que o carro bateu. Os numeros diziam respeito ao
## quarteirao sorteado naquela partida, e mudavam a cada rodada.
##
## O `Motor` e funcao pura de estado. Aqui ele roda contra uma massa de 980 kg e
## o mesmo arrasto do carro, em um minuto de tempo simulado que custa
## milissegundos — e ai da para afirmar coisas que dirigindo nao dariam: que as
## cinco marchas existem, em que velocidade cada uma entra, qual e a velocidade
## final, e que o limitador corta quando a roda force o motor acima do corte.
static func _medir_cambio_offline() -> void:
	_medir_frota()
	_medir_limitador()


## Um modelo na bancada, com um pe.
##
## Dois pes de proposito: um automatico troca em rotacao alta com o pe no fundo e
## em rotacao baixa com o pe leve, e uma bancada que so testa o primeiro aprova
## um cambio que so sabe correr.
static func _bancada(modelo: Carroceria.Modelo, pe: float) -> Dictionary:
	var ficha := FichaTecnica.de(modelo)
	var massa := float(ficha["massa"])
	var arrasto := float(ficha["arrasto"])
	var m := Motor.new()
	m.configurar(ficha)
	m.ligar()
	var v := 0.0
	var t := 0.0
	var cem := -1.0
	var vistas := {}
	var entrada := {}
	while t < 120.0:
		var f := m.passo(pe, 0.0, v, PASSO)
		# Duas rodas de tracao, como a Carroceria monta.
		var freia := arrasto * v * v + Carro.ROLAMENTO * massa * 9.8
		v = maxf(0.0, v + (f * 2.0 - freia) / massa * PASSO)
		if not vistas.has(m.marcha):
			entrada[m.marcha] = v
		vistas[m.marcha] = true
		if cem < 0.0 and v >= 27.78:
			cem = t
		t += PASSO
	return {
		"nome": String(ficha["nome"]),
		"marchas": vistas.size(),
		"declaradas": (ficha["relacoes"] as Array).size(),
		"final_kmh": v * 3.6,
		"cem_s": cem,
		"trocas": m.trocas,
		"entra": entrada,
	}


## Os sete carros, um por um, e a diferenca entre eles.
##
## O relatorio sai com uma linha por modelo porque a pergunta que ele responde e
## comparativa: nao adianta o Fusca fazer 0 a 100 em vinte segundos se o Marea
## tambem faz. O que o criterio exige e que a rua tenha carros DIFERENTES, e a
## medida disso e a distancia entre o mais rapido e o mais lento.
static func _medir_frota() -> void:
	var modelos: Array[Carroceria.Modelo] = [
		Carroceria.Modelo.SEDA, Carroceria.Modelo.HATCH,
		Carroceria.Modelo.PERUA, Carroceria.Modelo.PICAPE,
		Carroceria.Modelo.TAXI, Carroceria.Modelo.MAREA,
		Carroceria.Modelo.FUSCA]
	var cems: Array[float] = []
	var finais: Array[float] = []
	var marchas_erradas := PackedStringArray()
	for modelo: Carroceria.Modelo in modelos:
		var r := _bancada(modelo, 1.0)
		var leve := _bancada(modelo, 0.45)
		# Tres pes, e a uniao das marchas vistas nos tres.
		#
		# Uma relacao que nao entra em NENHUM pe e uma relacao morta na tabela —
		# foi o caso da quinta da perua e do taxi. Mas cobrar as cinco no pe no
		# fundo seria errado no outro sentido: quinta e marcha de cruzeiro, e
		# carro pesado com pouca forca termina em quarta com o pe no chao, que e
		# o comportamento certo.
		var cruzeiro := _bancada(modelo, 0.22)
		var uniao := {}
		for fonte: Dictionary in [r, leve, cruzeiro]:
			for k: int in (fonte["entra"] as Dictionary).keys():
				uniao[k] = true
		var entra := PackedStringArray()
		for k in range(1, int(r["declaradas"]) + 1):
			entra.append("%.0f" % (float((r["entra"] as Dictionary).get(k, 0.0)) * 3.6))
		print(("[carro.frota] %-7s marchas=%d/%d  final=%5.1f km/h  0a100=%5.2f s"
			+ "  entra=%s  leve_final=%5.1f") % [
			r["nome"], uniao.size(), r["declaradas"], r["final_kmh"], r["cem_s"],
			"/".join(entra), leve["final_kmh"]])
		if uniao.size() != int(r["declaradas"]):
			marchas_erradas.append("%s(%d de %d)"
				% [r["nome"], uniao.size(), r["declaradas"]])
		if float(r["cem_s"]) > 0.0:
			cems.append(float(r["cem_s"]))
		finais.append(float(r["final_kmh"]))
	cems.sort()
	finais.sort()
	_relatar("frota_marchas_erradas",
		" ".join(marchas_erradas) if not marchas_erradas.is_empty() else "-")
	_relatar("frota_cem_min", "%.2f" % cems[0])
	_relatar("frota_cem_max", "%.2f" % cems[cems.size() - 1])
	_relatar("frota_final_min", "%.1f" % finais[0])
	_relatar("frota_final_max", "%.1f" % finais[finais.size() - 1])
	# Quantos chegam aos 100 km/h. O Fusca pode nao chegar, e isso e o Fusca.
	_relatar("frota_chega_a_100", cems.size())


## O corte de giro.
##
## Ele nao aparece acelerando: o cambio troca antes de bater no limitador, que e
## como um automatico bem ajustado se comporta. Ele aparece quando a RODA forca o
## motor — uma descida longa em marcha baixa. Aqui a velocidade e imposta, e o
## que se mede e se a faisca corta.
static func _medir_limitador() -> void:
	var m := Motor.new()
	m.configurar(FichaTecnica.de(Carroceria.Modelo.SEDA))
	m.ligar()
	var cortou := false
	var t := 0.0
	while t < 3.0:
		# Velocidade que em primeira pede mais que o corte: uma descida forte.
		m.passo(1.0, 0.0, 16.0, PASSO)
		if m.cortes > 0:
			cortou = true
			break
		t += PASSO
	_relatar("limitador_corta", 1 if cortou else 0)
	_relatar("limitador_giro_max", "%.0f" % m.giro_maximo)
	_relatar("limitador_corte", "%.0f" % m.giro_corte)


## Todo modelo tem DOIS farois, e cada um do seu lado.
##
## O jogador relatou "so tem um farol aceso no meio do carro". Estava certo: o
## cone de luz nascia em x = 0 e nao no farol, entao todo carro da cidade vinha
## vindo com uma luz so no meio da frente, como moto. O cone agora sai do farol —
## e como a posicao e LIDA da malha, esta medida existe para a proxima
## carroceria nao nascer cega sem ninguem perceber.
##
## Roda em bancada: `Carroceria.montar` e estatico e devolve a malha de luzes
## sem precisar de cidade, de no ou de janela.
static func _medir_farois() -> void:
	var sem := PackedStringArray()
	var fora_do_lugar := PackedStringArray()
	for modelo: Carroceria.Modelo in [
			Carroceria.Modelo.SEDA, Carroceria.Modelo.HATCH,
			Carroceria.Modelo.PERUA, Carroceria.Modelo.PICAPE,
			Carroceria.Modelo.TAXI, Carroceria.Modelo.MAREA,
			Carroceria.Modelo.FUSCA]:
		var d := Carroceria.montar(modelo, Carroceria.TINTAS[0], 7)
		var malha := d["luzes"] as ArrayMesh
		if malha == null or malha.get_surface_count() < 1:
			sem.append(str(modelo))
			continue
		var arrays := malha.surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var onde := Carroceria.farois(arrays, uvs)
		if onde.size() != 2:
			sem.append("%d(%d)" % [modelo, onde.size()])
			continue
		# Um de cada lado, e nenhum encostado na linha de centro: dois farois
		# que caem quase no mesmo x sao um farol so em dois pedacos.
		var meia: float = float(d["largura"]) * 0.5
		if signf(onde[0].x) == signf(onde[1].x) or absf(onde[0].x) < meia * 0.15:
			fora_do_lugar.append(str(modelo))
	_relatar("modelos_sem_dois_farois", " ".join(sem) if not sem.is_empty() else "-")
	_relatar("farois_fora_do_lugar",
		" ".join(fora_do_lugar) if not fora_do_lugar.is_empty() else "-")


## A rua tem motores diferentes, ou seis copias do mesmo?
##
## O jogador perguntou, e a resposta era "copias": todo carro tocava a mesma
## amostra na mesma altura e no mesmo volume. So a buzina variava — ela ja
## sorteava a afinacao pela semente desde sempre, e o motor nao. Agora cada
## motor tem caracter proprio, e esta medida existe para ele nao voltar a ser um
## so sem ninguem reparar.
##
## Roda em bancada: `caracterizar` e conta sobre a semente, nao precisa de arvore.
static func _medir_motores_distintos() -> void:
	var vistos: Array[float] = []
	for k in 16:
		# Mesma forma de semente que `Transito._nascer` produz.
		var semente := absi(k * 73856093 + k * k * 19349663 + 40503)
		var m := MotorSom.new()
		m.caracterizar(semente)
		vistos.append(m.carater())
		m.free()
	vistos.sort()
	var faixa := vistos[vistos.size() - 1] - vistos[0]
	# Quantos motores DISTINTOS ha entre os dezesseis, agrupados de 1% em 1% de
	# afinacao — que e a ordem do menor intervalo que o ouvido separa num tom
	# continuo. Colisao de vez em quando nao e defeito: dois carros iguais na
	# cidade e o normal, e a pergunta e se a rua soa variada, nao se ha sosia.
	var grupos := {}
	for v: float in vistos:
		grupos[roundi(v * 100.0)] = true
	_relatar("motores_faixa", "%.3f" % faixa)
	_relatar("motores_distintos", grupos.size())


# --- acesso ------------------------------------------------------------------

## Entra num carro pela mesma porta que o jogador usa.
##
## Nao chama `Carro.assumir` direto de proposito: o que esta sob teste e a
## TECLA, e um teste que pula a tecla passa com a tecla quebrada.
static func _pegar_carro(cena: Node, jogador: Node3D) -> Carro:
	var arvore := cena.get_tree()
	await arvore.create_timer(ESPERA_TRANSITO).timeout
	_relatar("transito_vivos", Transito.vivos())

	# A cidade tambem esta jogando enquanto o teste mede.
	#
	# A blitz aborda quem passa pelo funil e TRAVA o jogador para a conversa; a
	# `Conversa` faz o mesmo. Nos dois casos `Player._alternar_veiculo` recusa
	# abrir porta, e com razao — quem esta sendo abordado nao entra num carro.
	# So que isso e o jogo acontecendo, e nao o que esta sob teste: uma execucao
	# em tres caia aqui, o relatorio saia com metade dos criterios vazios, e
	# nada dizia por que. Destravar e a mesma decisao do `--atravessar` de
	# `verificar_streaming`, e fica ANOTADA no relatorio.
	_relatar("estava_travado", 1 if bool(jogador.get("travado")) else 0)
	_relatar("conversa_aberta", 1 if Conversa.ativo else 0)
	if Conversa.ativo:
		Conversa.fechar_a_forca()
		await arvore.physics_frame
	if bool(jogador.get("travado")):
		jogador.call("travar", false)

	var perto: Carro = Transito.mais_perto(jogador.global_position, 90.0)
	if perto == null:
		_relatar("acesso_motivo", "nao havia carro num raio de 90 m")
		return null
	# Aproxima o jogador do carro — o teste mede a porta, nao a caminhada.
	jogador.global_position = perto.global_position + Vector3(0.0, 0.2, 2.0)
	await arvore.physics_frame

	var antes := perto.motorista
	_relatar("tinha_motorista", 1 if antes == Carro.Motorista.IA else 0)
	_relatar("fachos_no_carro", perto.fachos_acesos())
	# Qual carro caiu no teste. Freio, arrancada e volante dependem do
	# modelo agora, e um relatorio que nao diz de QUEM fala nao da para ler.
	_relatar("modelo", String(FichaTecnica.de(perto.modelo)["nome"]))

	if not jogador.has_method("entrar_no_veiculo_mais_perto"):
		_relatar("acesso", 0)
		_relatar("acesso_motivo", "o jogador nao expoe a porta")
		return null
	var ok: bool = jogador.call("entrar_no_veiculo_mais_perto")
	await arvore.physics_frame
	var dentro: Carro = jogador.call("carro") as Carro
	var certo: bool = (ok and dentro == perto
		and perto.motorista == Carro.Motorista.JOGADOR)
	_relatar("acesso", 1 if certo else 0)
	if not certo:
		_relatar("acesso_motivo", "a tecla devolveu %s e o carro ficou com %d"
			% [ok, perto.motorista])
		return null

	# Tomar um carro que estava andando entrega o motor JA LIGADO — obrigar a dar
	# a partida num carro em movimento seria desliga-lo no instante em que o
	# jogador assume o volante. Por isso a ignicao aqui e condicional: um teste
	# que alterna as cegas DESLIGA o motor e depois mede um carro que so estava
	# deslizando por inercia. Foi exatamente o que aconteceu na primeira medida.
	_relatar("ja_ligado", 1 if perto.ligado else 0)
	if not perto.ligado:
		perto.alternar_ignicao()
	await arvore.create_timer(0.4).timeout
	_relatar("ignicao", 1 if perto.ligado else 0)
	return perto


# --- pilotagem ---------------------------------------------------------------

## Pe no fundo em linha reta.
##
## Mede distancia percorrida e pico de velocidade, e de quebra conta quantas
## marchas o cambio mostrou e quantos cortes de giro o motor deu. A conta das
## marchas anda junto com a arrancada porque separar as duas dobraria o tempo do
## teste para medir a mesma aceleracao duas vezes.
static func _medir_arrancada(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	# Do zero e na faixa. O carro foi tomado em movimento, no angulo em que
	# estava; medir arrancada dali mede a inercia da IA e depois a fachada em que
	# o carro bate. As duas coisas ja aconteceram neste teste.
	_relatar("na_faixa", 1 if await _por_na_reta(cena, carro) else 0)

	var partida := carro.global_position
	var pico := 0.0
	var escorrega := 0.0
	var patinou := 0.0
	var vistas := {}
	var trocas0 := carro.trocas_de_marcha()
	var cortes0 := carro.cortes_de_giro()
	var t := 0.0
	var proxima := 0.5
	## Quando o carro cruzou 40 km/h. E a medida limpa de aceleracao: distancia
	## percorrida em seis segundos fala do QUARTEIRAO — o carro chega a um muro,
	## a um poste ou a um meio-fio de esquina e para, e a partir dai o numero
	## mede a cidade e nao o motor.
	var t_40 := -1.0
	carro.pilotar(1.0, 0.0, 0.0)
	while t < T_ARRANCADA:
		await arvore.physics_frame
		t += PASSO
		pico = maxf(pico, absf(carro.velocidade()))
		var esc := carro.escorregamento()
		escorrega = maxf(escorrega, esc)
		if esc > 0.14:
			patinou += PASSO
		vistas[carro.marcha()] = true
		if t_40 < 0.0 and carro.velocidade() >= 11.1:
			t_40 = t
		# O traco existe porque distancia sozinha nao distingue motor fraco de
		# carro que bateu num meio-fio: nos dois casos o carro para. Com a curva
		# de velocidade no relatorio, a diferenca e obvia — motor fraco sobe
		# devagar do comeco, batida sobe e cai de um golpe.
		if t >= proxima:
			proxima += 0.5
			print("[carro.traco] t=%.1f v=%.2f marcha=%d giro=%.0f forca=%.0f rodas=%d"
				% [t, carro.velocidade(), carro.marcha(), carro.giro(),
					carro.engine_force, carro.rodas_no_chao()])
	carro.pilotar(0.0, 0.0, 0.0)

	var andou := partida.distance_to(carro.global_position)
	_relatar("arrancada_m", "%.2f" % andou)
	_relatar("t_40kmh", "%.2f" % t_40)
	_relatar("escorrega_arrancada", "%.2f" % escorrega)
	_relatar("patinou_s", "%.2f" % patinou)
	_relatar("pico_ms", "%.2f" % pico)
	_relatar("marchas_vistas", vistas.size())
	_relatar("trocas", carro.trocas_de_marcha() - trocas0)
	_relatar("cortes_de_giro", carro.cortes_de_giro() - cortes0)
	_relatar("giro_max", "%.2f" % carro.giro_maximo_visto())


## Poe o carro parado no meio de uma faixa, apontando ao longo dela.
##
## Sem isto nao ha medida de aceleracao nenhuma: o carro e tomado em movimento,
## no angulo em que estava, e seis segundos de pe no fundo terminam contra uma
## fachada. A primeira execucao acusou "24,7 m de arrancada" num carro que fez 0
## a 42 km/h em um segundo e depois bateu num predio — o numero falava do
## quarteirao, e nao do motor.
##
## Devolve falso quando nao ha rua por perto, e ai quem chamou mede o que der.
static func _por_na_reta(cena: Node, carro: Carro) -> bool:
	var arvore := cena.get_tree()
	var trechos := Vias.trechos_perto(carro.global_position, 0.0, 40.0)
	if trechos.is_empty():
		return false
	# A faixa com mais rua LIVRE a frente, e nao a primeira da lista.
	#
	# A arrancada e o unico teste que precisa de reta, e ele estava aceitando o
	# que o acaso desse. Uma execucao mediu 4,34 m em seis segundos de pe no
	# fundo — o carro tinha sido posto a quatro metros de alguma coisa —, e o
	# relatorio acusou dois criterios de MOTOR vermelhos por causa de onde o
	# carro nasceu. Mesma armadilha do controlador que nascia de cara para um
	# muro.
	var t: Dictionary = faixa_mais_livre(cena, carro, trechos)
	var quadro: Vector4i = t["trecho"]
	var dir := Vias.direcao(Vias.trecho_eixo(quadro), Vias.trecho_sentido(quadro))
	# A frente do carro e -Z; este yaw poe -Z ao longo da faixa. Mesma conta de
	# `Carro._alinhar_na_faixa` e da mira da IA.
	carro.pousar(Transito.ponto_de_nascimento(t), atan2(-dir.x, -dir.z))
	carro.pilotar(0.0, 0.0, 0.0)
	# Da a partida de novo, que e o que um motorista faz.
	#
	# Batida em cheio afoga o motor — comportamento certo, e deliberado. So que o
	# teste nao religava, e a primeira medida depois de uma batida forte corria
	# com o carro DESLIGADO: esterco, freio, derrapagem e vento saiam todos zero
	# e pareciam sete defeitos, quando o defeito era um so e estava no teste.
	if not carro.ligado:
		carro.alternar_ignicao()
	# Espera assentar, e nao um numero fixo de quadros.
	#
	# O ponto da faixa pode estar ocupado por outro carro do transito; a fisica
	# separa os dois empurrando, e o carro sai dali com velocidade que nao veio
	# do motor. Uma execucao acusou "0 a 40 km/h em 0,92 s" — 1,2 g, mais do que
	# qualquer pneu segura — porque o cronometro largou com o carro ja andando.
	var espera := 0.0
	while espera < 2.0:
		await arvore.physics_frame
		espera += PASSO
		if espera > 0.2 and absf(carro.velocidade()) < 0.3:
			break
	return absf(carro.velocidade()) < 0.6


## De todas as faixas perto, a que tem mais asfalto livre pela frente.
##
## Mede com um raio rasteiro a partir do ponto de nascimento, na direcao da
## faixa. Para na primeira que tiver `RETA_BOA` livre — nao ha motivo para
## examinar as trinta se a segunda ja serve.
##
## Publica porque a CAPTURA precisa da mesma coisa pelo mesmo motivo: a rotina
## de `--ver-marca` acelera dois segundos antes de atravessar o carro, e tres
## tentativas terminaram com a lataria enfiada num gradil de praca. Duas copias
## desta escolha seriam duas definicoes de "reta boa".
const RETA_BOA := 34.0
const RETA_OLHAR := 44.0

static func faixa_mais_livre(cena: Node, carro: Carro,
		trechos: Array[Dictionary]) -> Dictionary:
	var espaco: PhysicsDirectSpaceState3D = cena.get_world_3d().direct_space_state
	var melhor: Dictionary = trechos[0]
	var melhor_livre := -1.0
	var candidatas := 0
	for t: Dictionary in trechos:
		var ponto: Vector3 = Transito.ponto_de_nascimento(t)
		# Chao PRIMEIRO, e depois reta. Sem esta ordem o criterio se contradiz:
		# "nada na frente" inclui "nada em lugar nenhum", entao uma faixa num
		# chunk que ainda nao montou tirava a nota maxima e o carro era posto no
		# vazio. Foi o que aconteceu — a partir da freada tudo media zero, com
		# 1,10 m/s2 de desaceleracao, que e o arrasto do ar de um carro caindo.
		if not ChunkManager.esta_carregado(ChunkManager.coord_de(ponto)):
			continue
		var pe := PhysicsRayQueryParameters3D.create(
			ponto + Vector3.UP * 1.0, ponto + Vector3.DOWN * 2.0, 1)
		pe.exclude = [carro.get_rid()]
		if espaco.intersect_ray(pe).is_empty():
			continue
		candidatas += 1

		var quadro: Vector4i = t["trecho"]
		var dir := Vias.direcao(Vias.trecho_eixo(quadro), Vias.trecho_sentido(quadro))
		var de := ponto + Vector3.UP * 0.7
		var consulta := PhysicsRayQueryParameters3D.create(
			de, de + dir * RETA_OLHAR, 1)
		consulta.exclude = [carro.get_rid()]
		var achado: Dictionary = espaco.intersect_ray(consulta)
		var livre := (RETA_OLHAR if achado.is_empty()
			else de.distance_to(achado["position"] as Vector3))
		if livre > melhor_livre:
			melhor_livre = livre
			melhor = t
		if livre >= RETA_BOA:
			break
	_relatar("reta_candidatas", candidatas)
	_relatar("reta_livre_m", "%.1f" % melhor_livre)
	return melhor


## Freia ate parar. Devolve com o carro parado e sem comando nenhum.
static func _parar(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	var t := 0.0
	carro.pilotar(0.0, 1.0, 0.0)
	while absf(carro.velocidade()) > 0.4 and t < 8.0:
		await arvore.physics_frame
		t += PASSO
	carro.pilotar(0.0, 0.0, 0.0)
	# Dois quadros de folga para o cambio largar a re que o freio parado engata.
	await arvore.physics_frame
	await arvore.physics_frame


## Volante todo para a esquerda. O carro tem de virar para a ESQUERDA.
##
## O sinal do esterco e a coisa mais barata de inverter e a mais cara de
## descobrir tarde: o carro dirige, responde ao volante, e so o jogador percebe
## que ele responde ao contrario. Ja aconteceu duas vezes neste repositorio em
## geometria de carro, e uma terceira nesta mesma frente — a forca de tracao
## saiu invertida e o carro acelerava de re.
##
## O que se mede e o RUMO, e nao o deslocamento lateral.
##
## Deslocamento lateral parecia a medida obvia e nao e: ele depende de quanto
## chao o carro teve para percorrer, e na cidade ele quase sempre bate numa
## fachada antes dos tres segundos. A medida acusava "-2,86 m" e reprovava um
## volante perfeito, porque o carro tinha ficado preso contra um muro no
## primeiro segundo. Rumo nao tem esse problema: um carro que virou meia volta
## virou meia volta, tenha ele andado dez metros ou trinta.
static func _medir_esterco(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	await _por_na_reta(cena, carro)
	var base := carro.global_transform
	var rumo0 := carro.global_rotation.y
	var rumo := 0.0
	var lateral := 0.0
	var escorrega := 0.0
	var t := 0.0
	carro.pilotar(0.8, 0.0, -1.0)
	while t < T_ESTERCO:
		await arvore.physics_frame
		t += PASSO
		# Desenrolado: tres segundos de volante no batente passam de PI, e um
		# angulo preso a [-PI, PI] daria meia volta como se fosse meia volta para
		# o outro lado.
		rumo += angle_difference(rumo0, carro.global_rotation.y)
		rumo0 = carro.global_rotation.y
		var d := (carro.global_position - base.origin).dot(base.basis.x)
		if absf(d) > absf(lateral):
			lateral = d
		escorrega = maxf(escorrega, carro.escorregamento())
	carro.pilotar(0.0, 0.0, 0.0)

	# +X e a direita do carro; virar a esquerda da lateral NEGATIVA e rumo
	# POSITIVO (com a frente em -Z, crescer o yaw leva a frente para -X).
	_relatar("esterco_lateral_m", "%.2f" % lateral)
	_relatar("esterco_rumo_rad", "%.2f" % rumo)
	_relatar("escorrega_curva", "%.2f" % escorrega)
	_relatar("esterco_percorrido_m", "%.2f"
		% base.origin.distance_to(carro.global_position))
	_relatar("esterco_lado_certo", 1 if (rumo > 0.35 and lateral < 0.0) else 0)


## Freia a partir de 60 km/h e mede em quantos metros para.
static func _medir_freio(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	await _por_na_reta(cena, carro)
	# Acelera ate a velocidade de medida, com teto de tempo para o teste nao
	# ficar preso atras de um meio-fio.
	# 11 m/s, e nao 16,6. O carro chega aos 40 km/h em menos de um segundo e a
	# uns dez metros da partida; aos 60 km/h ele ja saiu do quarteirao e a medida
	# vira "bateu num predio e parou em zero metro", que foi o que a execucao
	# anterior relatou.
	var t := 0.0
	carro.pilotar(1.0, 0.0, 0.0)
	while absf(carro.velocidade()) < 11.0 and t < 6.0:
		await arvore.physics_frame
		t += PASSO
	var v0 := absf(carro.velocidade())
	var inicio := carro.global_position

	t = 0.0
	carro.pilotar(0.0, 1.0, 0.0)
	while absf(carro.velocidade()) > 0.6 and t < T_FREIO:
		await arvore.physics_frame
		t += PASSO
	carro.pilotar(0.0, 0.0, 0.0)

	var d := inicio.distance_to(carro.global_position)
	_relatar("freio_v0_ms", "%.2f" % v0)
	_relatar("freio_m", "%.2f" % d)
	# A desaceleracao e o numero que vale: metros de frenagem dependem da
	# velocidade em que o teste conseguiu chegar naquele quarteirao, e ela nao e
	# a mesma de uma execucao para a outra.
	_relatar("freio_ms2", "%.2f" % (v0 * v0 / maxf(0.01, 2.0 * d)))


# --- chuva, derrapagem e batida ----------------------------------------------

## A chuva chega no pneu?
##
## O jogo tem clima com chuva desde sempre e o pneu ignorava: `wheel_friction_slip`
## era o mesmo numero chovendo ou fazendo sol. O que se mede aqui NAO e a tabela
## — essa da para ler — e sim a ligacao: trocar o preset no meio da partida tem
## de chegar nas quatro rodas sem ninguem recarregar nada.
static func _medir_chuva(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	var antes := carro.atrito_das_rodas()
	Settings.set_fog_preset(&"noite_chuva")
	await arvore.physics_frame
	var molhado := carro.atrito_das_rodas()
	Settings.set_fog_preset(&"neblina")
	await arvore.physics_frame
	var seco := carro.atrito_das_rodas()
	_relatar("atrito_seco", "%.2f" % maxf(antes, seco))
	_relatar("atrito_molhado", "%.2f" % molhado)
	# Relativo, e nao 0,2 de diferenca: desde 18/09/2026 o atrito da ficha e em g
	# (0,76 a 0,98), e no Fusca os 28% da chuva dao 0,21 — o limiar absoluto
	# passava no fio, e um pneu um pouco mais fino reprovaria sem defeito nenhum.
	_relatar("chuva_muda_atrito", 1 if molhado < seco * 0.9 else 0)


## O pneu canta quando escorrega?
##
## Freio de mao com o carro em movimento e volante no batente: e a receita de
## derrapagem, e o pneu tem de gritar. Mede o escorregao de verdade — o que sai
## da roda, via `get_skidinfo` — e o volume que o som chegou a por na tela.
static func _medir_derrapagem(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	await _por_na_reta(cena, carro)
	# Ganha velocidade primeiro: derrapagem parado nao existe.
	var t := 0.0
	carro.pilotar(1.0, 0.0, 0.0)
	while absf(carro.velocidade()) < 10.0 and t < 6.0:
		await arvore.physics_frame
		t += PASSO
	# A corrida de aproximacao pode terminar numa parede.
	#
	# Derrapar precisa de velocidade, e ganhar velocidade numa rua de cidade
	# tem oito metros de quarteirao livre em media. Batida em cheio AFOGA o
	# motor — comportamento certo, deliberado —, e a secao inteira passava a
	# medir um carro morto: escorregao 0,00, pneu mudo, nenhum pedaco de marca.
	# Tres criterios vermelhos com uma causa que nao era nenhum dos tres.
	#
	# Uma segunda tentativa, de outro ponto da faixa, e o que um motorista
	# faria. Se a segunda tambem bater, os numeros saem e `derrapagem_v0` diz
	# por que — que e melhor do que um relatorio que culpa o rastro.
	if not carro.ligado or absf(carro.velocidade()) < 5.0:
		await _por_na_reta(cena, carro)
		carro.pilotar(1.0, 0.0, 0.0)
		t = 0.0
		while absf(carro.velocidade()) < 10.0 and t < 6.0:
			await arvore.physics_frame
			t += PASSO
	_relatar("derrapagem_v0", "%.1f" % absf(carro.velocidade()))
	_relatar("derrapagem_ligado", 1 if carro.ligado else 0)
	# Quantas marcas o carro deixou ACELERANDO EM LINHA RETA. Tem de ser zero:
	# um limiar mal posto pinta borracha em toda arrancada, e a cidade amanhece
	# com rastro debaixo de cada carro. E a metade do criterio que a contagem da
	# derrapagem sozinha nao cobre.
	# O contador do rastro e ACUMULADO desde que o jogador assumiu o carro, e
	# nao desta secao. Lido cru, ele ja trazia as marcas legitimas do esterco no
	# batente e da freada, e o criterio "acelerar em linha reta nao pinta o
	# asfalto" reprovava com quatro pedacos e escorregao 0,00 no pico — dois
	# numeros que nao podem ser verdade ao mesmo tempo, que e como se viu que a
	# leitura e que estava errada.
	var antes_reta := carro.marcas_de_pneu()
	var roda_reta := 0.0
	# Uma segunda passada em linha reta so para saber quanto UMA roda escorrega
	# acelerando. E o numero que diz se o limiar da marca esta alto ou baixo: a
	# media do eixo esconde a roda que patina sozinha.
	carro.pilotar(1.0, 0.0, 0.0)
	t = 0.0
	while t < 1.2:
		await arvore.physics_frame
		t += PASSO
		roda_reta = maxf(roda_reta, carro.escorrega_por_roda())
	var marcas_reta := carro.marcas_de_pneu() - antes_reta
	var antes_derrapar := carro.marcas_de_pneu()
	# Volante no batente e freio de mao: o eixo de tras larga.
	carro.puxar_freio_de_mao(true)
	carro.pilotar(0.3, 0.0, -1.0)
	var pico := 0.0
	var roda_pico := 0.0
	var pico_db := -99.0
	var acima := NAN
	t = 0.0
	while t < 2.0:
		await arvore.physics_frame
		t += PASSO
		pico = maxf(pico, carro.escorregamento())
		roda_pico = maxf(roda_pico, carro.escorrega_por_roda())
		var d := carro.som_diagnostico()
		pico_db = maxf(pico_db, float(d.get("canta_db", -99.0)))
		# A altura da marca contra a do carro, medida NO MESMO quadro. A origem
		# do Carro e o plano de contato do pneu (ver `Transito`), entao a
		# diferenca e literalmente o quanto a borracha ficou acima do asfalto.
		# Medir depois nao serve: o carro anda, o chao muda de cota.
		var h := carro.altura_da_marca()
		if is_finite(h):
			# Contra o ASFALTO medido, e nao contra a origem do carro. A origem
			# do carro fica uns dez centimetros acima do chao quando ele esta
			# apoiado nas molas, e comparar com ela deu uma medida que parecia
			# defeito e nao era — e escondeu o defeito que era.
			var chao := _altura_do_asfalto(cena, carro)
			if is_finite(chao):
				acima = h - chao
	carro.puxar_freio_de_mao(false)
	carro.pilotar(0.0, 0.0, 0.0)
	_relatar("escorrega_pico", "%.2f" % pico)
	_relatar("canta_db", "%.1f" % pico_db)
	_relatar("marcas_reta", marcas_reta)
	_relatar("escorrega_roda_reta", "%.2f" % roda_reta)
	_relatar("escorrega_roda_derrapando", "%.2f" % roda_pico)
	_relatar("marcas_derrapando", carro.marcas_de_pneu() - antes_derrapar)
	_relatar("bafos_derrapando", carro.bafos_de_pneu())
	_relatar("marca_acima_chao", "%.3f" % acima if is_finite(acima) else "nan")
	_relatar("marca_alvo_acima", "%.3f" % RastroPneu.ALTURA)


## A cota do asfalto embaixo do carro, por raio. Devolve NAN sem chao.
static func _altura_do_asfalto(cena: Node, carro: Carro) -> float:
	var espaco: PhysicsDirectSpaceState3D = cena.get_world_3d().direct_space_state
	var de := carro.global_position + Vector3.UP * 1.0
	var consulta := PhysicsRayQueryParameters3D.create(
		de, de + Vector3.DOWN * 3.0, 1)
	consulta.exclude = [carro.get_rid()]
	var achado: Dictionary = espaco.intersect_ray(consulta)
	if achado.is_empty():
		return NAN
	return (achado["position"] as Vector3).y


## Bater faz alguma coisa?
##
## O carro e apontado para FORA da faixa e acelerado: em rua de cidade, a uns
## poucos metros do meio-fio ha calcada, poste ou fachada. O que se afirma e que
## o impacto foi NOTADO — sinal emitido, com forca — e nao que havia um muro
## naquele lugar especifico.
static func _medir_batida(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	await _por_na_reta(cena, carro)
	var batidas := {"n": 0, "forca": 0.0}
	var ouvir := func(f: float) -> void:
		batidas["n"] = int(batidas["n"]) + 1
		batidas["forca"] = maxf(float(batidas["forca"]), f)
	carro.bateu.connect(ouvir)
	# Meia volta a partir do rumo da faixa: sai da pista em direcao a calcada.
	carro.pousar(carro.global_position, carro.global_rotation.y + PI * 0.5)
	await arvore.physics_frame
	var partida := carro.global_position
	carro.pilotar(1.0, 0.0, 0.0)
	var t := 0.0
	while t < 8.0 and int(batidas["n"]) == 0:
		await arvore.physics_frame
		t += PASSO
	carro.pilotar(0.0, 0.0, 0.0)
	carro.bateu.disconnect(ouvir)
	# Quanto ele andou antes de bater (ou de desistir). Zero batidas com zero
	# metros e um carro que nao saiu do lugar; zero batidas com trinta metros e
	# uma rua que estava livre — sao defeitos diferentes.
	_relatar("batida_percorreu_m", "%.1f" % partida.distance_to(carro.global_position))
	_relatar("batidas", int(batidas["n"]))
	_relatar("batida_forca", "%.2f" % float(batidas["forca"]))
	await _parar(cena, carro)


## Capotar nao pode ser beco sem saida.
##
## Este e o unico estado do carro em que o jogador podia ficar PRESO: de rodas
## para cima, o ponto de saida saia por dentro do asfalto, e a rede de seguranca
## — subir 1,2 m — o punha debaixo da lataria virada. Sem sair e sem desvirar, a
## unica saida era fechar o jogo.
##
## Afirma tres coisas: o carro sabe que capotou, o motor morre (carro de pernas
## para o ar roncando e a coisa mais absurda que esta fisica produz), e o ponto
## de saida fica ACIMA do chao e FORA da lataria.
static func _medir_capotamento(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	await _por_na_reta(cena, carro)
	if not carro.ligado:
		carro.alternar_ignicao()
	var chao := carro.global_position
	carro.pousar(chao + Vector3.UP * 0.6, carro.global_rotation.y, PI)
	var t := 0.0
	while t < 1.2:
		await arvore.physics_frame
		t += PASSO
	_relatar("capotou", 1 if carro.capotado() else 0)
	_relatar("capotado_motor_morreu", 0 if carro.ligado else 1)
	var saida := carro.ponto_de_saida()
	_relatar("capotado_saida_acima_m", "%.2f" % (saida.y - carro.global_position.y))
	_relatar("capotado_saida_longe_m", "%.2f"
		% Vector2(saida.x - carro.global_position.x,
			saida.z - carro.global_position.z).length())
	# Devolve o carro ao mundo dos vivos para as medidas seguintes.
	carro.pousar(chao, carro.global_rotation.y)
	if not carro.ligado:
		carro.alternar_ignicao()
	await arvore.physics_frame


## O vento existe e cresce com a velocidade?
static func _medir_vento(cena: Node, carro: Carro) -> void:
	var arvore := cena.get_tree()
	# O retorno de `_por_na_reta` importa aqui: "carro parado nao faz vento" e
	# uma afirmacao sobre um carro PARADO, e se ele nao parou o numero mede
	# outra coisa. Sem a linha, uma execucao acusou -32,3 dB de vento num carro
	# que o relatorio chamava de parado.
	_relatar("vento_assentou", 1 if await _por_na_reta(cena, carro) else 0)
	_relatar("vento_parado_v", "%.2f" % absf(carro.velocidade()))
	var parado := float(carro.som_diagnostico().get("vento_db", -99.0))
	var medida := await _ventar(cena, carro)
	# Nao saiu do lugar? Entao a medida foi sobre a RUA, e nao sobre o vento.
	#
	# Esta secao vem logo depois da batida, e a batida deixa o carro encostado
	# numa fachada. `_por_na_reta` o devolve a uma faixa, mas a faixa que sobra
	# perto de onde ele bateu pode ter tres metros livres — e cinco segundos de
	# pe no fundo contra um muro dao -60 dB a 0,0 m/s, que o relatorio acusou
	# como "o vento nao funciona".
	if medida.y < 8.0:
		await _por_na_reta(cena, carro)
		medida = await _ventar(cena, carro)
	_relatar("vento_parado_db", "%.1f" % parado)
	_relatar("vento_andando_db", "%.1f" % medida.x)
	_relatar("vento_a_ms", "%.1f" % medida.y)
	await _parar(cena, carro)


## Cinco segundos de pe no fundo. Devolve (pico de vento em dB, velocidade em
## que o pico aconteceu).
static func _ventar(cena: Node, carro: Carro) -> Vector2:
	var arvore := cena.get_tree()
	var t := 0.0
	var pico := -99.0
	var v_pico := 0.0
	carro.pilotar(1.0, 0.0, 0.0)
	while t < 5.0:
		await arvore.physics_frame
		t += PASSO
		var d := carro.som_diagnostico()
		if float(d.get("vento_db", -99.0)) > pico:
			pico = float(d["vento_db"])
			v_pico = absf(carro.velocidade())
	carro.pilotar(0.0, 0.0, 0.0)
	return Vector2(pico, v_pico)


# --- painel -------------------------------------------------------------------

## O velocimetro existe, esta na tela e marca o que o carro esta fazendo.
##
## Medido ANDANDO, e nao parado. Um painel parado marca zero, e zero e o unico
## valor que um mostrador quebrado tambem marca. O que se quer afirmar e que o
## ponteiro acompanha: por isso o carro acelera, o painel e lido em movimento, e
## o erro contra a velocidade real do corpo rigido entra no relatorio.
##
## O ponteiro tem inercia de proposito (`PainelCarro.INERCIA_KMH`), entao ele
## atrasa alguns km/h numa aceleracao forte. E atraso de agulha, e nao de leitura
## errada, e o criterio aceita isso — o que ele nao aceita e o mostrador marcar
## outra coisa.
static func _medir_painel(cena: Node, jogador: Node3D, carro: Carro) -> void:
	var arvore := cena.get_tree()
	var painel := jogador.get_tree().get_first_node_in_group(
		&"painel_carro") as PainelCarro
	if painel == null:
		_relatar("painel", 0)
		return
	_relatar("painel", 1)
	_relatar("painel_visivel", 1 if painel.mostrado() else 0)

	await _por_na_reta(cena, carro)
	# A MEDIANA do erro ao longo de toda a aceleracao, e nao a leitura de um
	# quadro escolhido.
	#
	# Um quadro so nao serve: se o carro bater numa fachada no instante da
	# leitura, a velocidade real cai a zero e o ponteiro — que tem inercia de
	# proposito — ainda marca vinte e cinco. O relatorio acusava "25,2 contra
	# 0,7 km/h" e reprovava um mostrador certo por causa de um muro. A mediana
	# de duzentos quadros nao se move por causa de um.
	var erros: Array[float] = []
	var erros_giro: Array[float] = []
	var som_camadas := 0
	var som_db := -99.0
	var som_afinacao := 0.0
	var som_detalhado := false
	var kmh := 0.0
	var esperado := 0.0
	var giro := 0.0
	var giro_esperado := 0.0
	var marcha := "1"
	var marcha_esperada := "1"
	var t := 0.0
	carro.pilotar(0.85, 0.0, 0.0)
	while t < 2.6:
		await arvore.physics_frame
		t += PASSO
		if t < 0.6:
			continue
		kmh = painel.kmh_mostrado()
		esperado = absf(carro.velocidade()) * 3.6
		giro = painel.giro_mostrado()
		giro_esperado = carro.giro_normalizado()
		marcha = painel.marcha_mostrada()
		marcha_esperada = carro.rotulo_marcha()
		erros.append(absf(kmh - esperado))
		erros_giro.append(absf(giro - giro_esperado))
		# O motor esta soando NESTE instante? Guarda o melhor quadro: o
		# volume e suavizado e comeca no fundo, e reprovar pela primeira
		# leitura mediria a rampa, e nao o motor.
		var d := carro.som_diagnostico()
		som_camadas = maxi(som_camadas, int(d.get("tocando", 0)))
		som_db = maxf(som_db, float(d.get("db_max", -99.0)))
		som_afinacao = maxf(som_afinacao, float(d.get("afinacao", 0.0)))
		som_detalhado = som_detalhado or bool(d.get("detalhado", false))
	carro.pilotar(0.0, 0.0, 0.0)

	erros.sort()
	erros_giro.sort()
	var meio := erros[erros.size() / 2] if not erros.is_empty() else -1.0
	var meio_giro := (erros_giro[erros_giro.size() / 2]
		if not erros_giro.is_empty() else -1.0)
	_relatar("painel_kmh", "%.1f" % kmh)
	_relatar("painel_kmh_esperado", "%.1f" % esperado)
	_relatar("painel_erro_kmh", "%.1f" % meio)
	_relatar("painel_giro", "%.2f" % giro)
	_relatar("painel_giro_esperado", "%.2f" % giro_esperado)
	_relatar("painel_erro_giro", "%.3f" % meio_giro)
	_relatar("painel_marcha", marcha)
	_relatar("painel_marcha_esperada", marcha_esperada)
	_relatar("som_detalhado", 1 if som_detalhado else 0)
	_relatar("som_camadas", som_camadas)
	_relatar("som_db", "%.1f" % som_db)
	_relatar("som_afinacao", "%.2f" % som_afinacao)
	await _parar(cena, carro)


# --- saida --------------------------------------------------------------------

static func _medir_saida(cena: Node, jogador: Node3D, carro: Carro) -> void:
	var arvore := cena.get_tree()
	var dentro_antes: Carro = jogador.call("carro") as Carro
	_relatar("saida_estava_dentro", 1 if dentro_antes == carro else 0)
	_relatar("saida_carro_vel", "%.2f" % absf(carro.velocidade()))
	var onde_carro := carro.global_position
	jogador.call("entrar_no_veiculo_mais_perto")
	await arvore.physics_frame
	# O carro nao pode ANDAR ao ser devolvido. Este numero pegou um salto de
	# 21 m que o congelamento causava; ele fica no relatorio como sentinela.
	_relatar("saida_carro_andou_m", "%.2f"
		% onde_carro.distance_to(carro.global_position))
	var fora: Carro = jogador.call("carro") as Carro
	var largou: bool = (fora == null
		and carro.motorista != Carro.Motorista.JOGADOR)
	_relatar("saida", 1 if largou else 0)
	_relatar("saida_visivel", 1 if jogador.visible else 0)
	var d := jogador.global_position.distance_to(carro.global_position)
	_relatar("saida_dist_m", "%.2f" % d)
	var painel := arvore.get_first_node_in_group(&"painel_carro") as PainelCarro
	_relatar("painel_sumiu", 1 if (painel == null or not painel.mostrado()) else 0)
