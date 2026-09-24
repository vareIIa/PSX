## Onde cada peca do HUD vetorial mora. Funcao pura: sem Node, sem autoload.
##
## Mesmo contrato de `CartaoLayout` e `FaixaLayout` (UI-BIBLE secao 6): quem
## desenha e quem mede consultam a MESMA resposta, e `tests/checar_hud_aaa.gd`
## reprova o layout que cruza duas pecas ou sai da area segura.
##
## O mapa da tela (480x270 logico)
## -------------------------------
##
##     +----------------------------------------------------------------+
##     | OBJETIVO            [  BUSSOLA  ]                     [RADAR]  |
##     | titulo  1/2                                           [     ]  |
##     | texto do objetivo                                     [     ]  |
##     | <> 270 m                                        RUA / BAIRRO   |
##     |                                                  22:43 NEVOA   |
##     |                     NOVA MISSAO                        avisos   |
##     |                  (banner, centro)                      avisos   |
##     |                    [E] Abrir a porta                   avisos   |
##     | [iWeed: entrega]                                                |
##     |                                                                 |
##     | + vida  folego  lanterna  PROCURADO                             |
##     +----------------------------------------------------------------+
##
## Objetivo em cima a esquerda, radar em cima a direita, bussola no meio do topo:
## e o triangulo que todo jogo de mundo aberto usa desde GTA III, porque o olho
## ja procura la. O rodape fica quase vazio de proposito — e onde a rua esta.
class_name HudLayout
extends RefCounted

const TELA := HudTema.TELA
const M := HudTema.MARGEM

# --- pecas fixas ----------------------------------------------------------------
const OBJETIVO_LARGURA := 150.0
## Barra de acento a esquerda do objetivo, e o vao ate o texto.
const OBJETIVO_BARRA := 2.0
const OBJETIVO_RECUO := 7.0
const OBJETIVO_MAX_LINHAS := 3
## Altura que a peca reserva: titulo, tres linhas, distancia e dica. O banner
## mora logo abaixo.
const OBJETIVO_ALTURA_MAX := 80.0
## Fundo do objetivo: cheio ate FOLGA depois da coluna, esfuma em ESFUMA (a
## ponta mal alcanca a bussola, que comeca em x 178), e PENA de margem esfumada
## em cima e embaixo — a tecla da dica fica inteira dentro do trecho cheio.
const OBJETIVO_FOLGA := 4.0
const OBJETIVO_ESFUMA := 16.0
const OBJETIVO_PENA := 6.0

const BUSSOLA := Rect2(TELA.x * 0.5 - 62.0, M, 124.0, 26.0)
## Linha do GPS curva a curva, logo abaixo da fita da bussola. Mais larga que a
## fita: cabe no vao entre o objetivo (ate x 160) e o radar (desde x 394).
const GPS_ALTURA := 13.0
const GPS_LARGURA := 150.0

const RADAR_LADO := 76.0
const RADAR := Rect2(TELA.x - M - RADAR_LADO, M, RADAR_LADO, RADAR_LADO)

## Bloco de lugar embaixo do radar. Alinhado a direita com ele.
const LOCAL_LARGURA := 130.0
const LOCAL_ALTURA := 28.0
const LOCAL_VAO := 5.0

## Coluna de avisos (item recebido, dinheiro, bolsa cheia).
const AVISO := Vector2(128.0, 20.0)
const AVISO_VAO := 3.0
const AVISOS_MAX := 4

## Rodape esquerdo: vitais contextuais.
const ESTADO := Rect2(M, TELA.y - M - 12.0, 200.0, 12.0)

## Prompt de acao: centrado, ~30 px abaixo do meio da tela. Perto de onde o olho
## ja esta (a porta, o carro), e acima do cartao da entrega do iWeed, que ocupa
## o rodape esquerdo durante uma corrida inteira.
const PROMPT_Y := 166.0
## Largura maxima do papel do prompt: ate a coluna de avisos, com folga.
const PROMPT_MAX := 190.0
const PROMPT_ALTURA := 14.0

## Banner central (missao nova, missao cumprida, lugar descoberto). Abaixo do
## objetivo aberto e a esquerda do bloco de lugar.
const BANNER := Rect2(TELA.x * 0.5 - 100.0, 92.0, 200.0, 44.0)

## Cartao da entrega do iWeed. Mora no rodape esquerdo, logo acima dos vitais.
const IWEED_CARTAO := Rect2(M, ESTADO.position.y - 6.0 - 54.0, 164.0, 54.0)
## Largura da notificacao do iWeed: o vao entre o objetivo (ate x 160) e o bloco
## de lugar (desde x 340). Com 196 ela invadia o objetivo.
const IWEED_TOAST_LARGURA := 150.0
## Feed da sessao (entrou, saiu, chat), na faixa livre da coluna esquerda:
## abaixo do objetivo (ate a 120%) e acima do cartao do iWeed, a esquerda do
## banner. Quem desenha e `PainelOnline`.
const FEED := Rect2(M, 112.0, 128.0, 72.0)

## Onde a notificacao do iWeed comeca a descer: abaixo da bussola e do GPS.
const IWEED_TOPO := BUSSOLA.end.y + GPS_ALTURA + 6.0


static func local_rect(com_radar: bool) -> Rect2:
	var y := RADAR.end.y + LOCAL_VAO if com_radar else M
	return Rect2(TELA.x - M - LOCAL_LARGURA, y, LOCAL_LARGURA, LOCAL_ALTURA)


# --- escala ------------------------------------------------------------------
#
# Cada peca cresce a partir do proprio canto (o pivo), e nao do meio da tela:
# a 120% o radar continua encostado na margem, e nao sai dela. Objetivo,
# bussola, avisos e prompt mantem a LARGURA na tela e so crescem para baixo —
# o texto reflui. Sem isso, a 120% o objetivo (150 px) encostava na bussola.

const PIVO_OBJETIVO := Vector2(M, M)
const PIVO_BUSSOLA := Vector2(TELA.x * 0.5, M)
const PIVO_RADAR := Vector2(TELA.x - M, M)
const PIVO_ESTADO := Vector2(M, TELA.y - M)
const PIVO_PROMPT := Vector2(TELA.x * 0.5, PROMPT_Y)


## Um ponto logico da peca, na tela, com a escala em volta do pivo.
static func na_tela(p: Vector2, pivo: Vector2, s: float) -> Vector2:
	return pivo + (p - pivo) * s


static func rect_na_tela(r: Rect2, pivo: Vector2, s: float) -> Rect2:
	return Rect2(na_tela(r.position, pivo, s), r.size * s)


## Largura logica para a peca ocupar `largura` na tela depois da escala.
static func largura_logica(largura: float, s: float) -> float:
	return largura / maxf(s, 0.01)


## Onde a coluna de avisos comeca na tela: embaixo do bloco de lugar ja escalado.
static func avisos_topo(s: float, com_radar: bool) -> float:
	var r := rect_na_tela(local_rect(com_radar), PIVO_RADAR, s)
	return r.end.y + 8.0


## Retangulo de um aviso na tela. A largura e fixa na tela; a altura escala.
static func aviso_rect(indice: int, com_radar: bool, s: float = 1.0) -> Rect2:
	var y := avisos_topo(s, com_radar) + float(indice) * (AVISO.y + AVISO_VAO) * s
	return Rect2(TELA.x - M - AVISO.x, y, AVISO.x, AVISO.y * s)


## Quantos avisos cabem acima de `limite_y` (o topo do mostrador do carro, ao
## dirigir). Sem limite, `AVISOS_MAX`.
static func avisos_que_cabem(s: float, com_radar: bool, limite_y: float = INF) -> int:
	if not is_finite(limite_y):
		return AVISOS_MAX
	var passo := (AVISO.y + AVISO_VAO) * s
	var n := floori((limite_y - avisos_topo(s, com_radar) + AVISO_VAO * s) / passo)
	return clampi(n, 0, AVISOS_MAX)


## O banner desce quando o objetivo cresce: nunca por baixo dele.
static func banner_rect(s: float) -> Rect2:
	var r := BANNER
	r.position.y = maxf(BANNER.position.y, M + OBJETIVO_ALTURA_MAX * s + 4.0)
	return r


## Pecas fixas na tela, para o teste conferir que nenhuma cruza outra em
## nenhuma escala oferecida.
static func pecas(s: float = 1.0) -> Dictionary:
	var local := rect_na_tela(local_rect(true), PIVO_RADAR, s)
	# O bloco de lugar alinha a direita com largura fixa na tela.
	local = Rect2(TELA.x - M - LOCAL_LARGURA, local.position.y, LOCAL_LARGURA, local.size.y)
	return {
		"objetivo": Rect2(M, M, OBJETIVO_LARGURA, OBJETIVO_ALTURA_MAX * s),
		"bussola": Rect2(BUSSOLA.position.x, M, BUSSOLA.size.x, BUSSOLA.size.y * s),
		"gps": Rect2(TELA.x * 0.5 - GPS_LARGURA * 0.5, M + BUSSOLA.size.y * s,
			GPS_LARGURA, GPS_ALTURA * s),
		"radar": rect_na_tela(RADAR, PIVO_RADAR, s),
		"local": local,
		"avisos": Rect2(TELA.x - M - AVISO.x, avisos_topo(s, true), AVISO.x,
			(AVISOS_MAX * (AVISO.y + AVISO_VAO) - AVISO_VAO) * s),
		"iweed": IWEED_CARTAO,
		"feed": FEED,
		"estado": rect_na_tela(ESTADO, PIVO_ESTADO, s),
		"banner": banner_rect(s),
		"prompt": Rect2(TELA.x * 0.5 - PROMPT_MAX * 0.5, PROMPT_Y - 3.0 * s, PROMPT_MAX,
			(PROMPT_ALTURA + 6.0) * s),
	}


# --- objetivo -------------------------------------------------------------------

## Empilha o rastreador de objetivo.
##
## `dados`: titulo, etapa ("1/2" ou vazio), objetivo, dica, distancia (vazio
## quando nao ha alvo ou o jogador esta dentro de casa).
##
## Devolve `{altura, caixas: [{nome, rect, linhas}]}`. Coordenadas relativas ao
## canto de cima da esquerda da peca.
static func objetivo(dados: Dictionary, com_dica: bool,
		largura: float = OBJETIVO_LARGURA) -> Dictionary:
	var f_rot := HudTema.rotulo()
	var f_corpo := HudTema.regular()
	var f_semi := HudTema.semi()
	var x := OBJETIVO_BARRA + OBJETIVO_RECUO
	var util := largura - x
	var y := 0.0
	var caixas: Array[Dictionary] = []

	var etapa := String(dados.get("etapa", ""))
	var w_etapa := 0.0
	if not etapa.is_empty():
		w_etapa = HudTema.largura(f_semi, etapa, HudTema.T_ROTULO)
	var titulo := String(dados.get("titulo", "")).to_upper()
	if not titulo.is_empty():
		var h := HudTema.altura(f_rot, HudTema.T_ROTULO)
		var cabe := util - (w_etapa + 6.0 if w_etapa > 0.0 else 0.0)
		caixas.append({"nome": "titulo", "rect": Rect2(x, y, cabe, h),
			"linhas": PackedStringArray([HudTema.encurtar(f_rot, titulo, HudTema.T_ROTULO, cabe)])})
		if w_etapa > 0.0:
			caixas.append({"nome": "etapa", "rect": Rect2(x + util - w_etapa, y, w_etapa, h),
				"linhas": PackedStringArray([etapa])})
		y += h + 2.0

	var texto := String(dados.get("objetivo", ""))
	if not texto.is_empty():
		var linhas := HudTema.quebrar(f_corpo, texto, HudTema.T_CORPO, util)
		if linhas.size() > OBJETIVO_MAX_LINHAS:
			var cortadas := linhas.slice(0, OBJETIVO_MAX_LINHAS)
			var resto := " ".join(linhas.slice(OBJETIVO_MAX_LINHAS - 1))
			cortadas[OBJETIVO_MAX_LINHAS - 1] = HudTema.encurtar(f_corpo, resto,
				HudTema.T_CORPO, util)
			linhas = cortadas
		var h := HudTema.altura(f_corpo, HudTema.T_CORPO) * float(linhas.size())
		caixas.append({"nome": "objetivo", "rect": Rect2(x, y, util, h), "linhas": linhas})
		y += h + 3.0

	var dist := String(dados.get("distancia", ""))
	if not dist.is_empty():
		var h := HudTema.altura(f_semi, HudTema.T_ROTULO)
		caixas.append({"nome": "distancia", "rect": Rect2(x, y, util, h),
			"linhas": PackedStringArray([dist])})
		y += h + 3.0

	var dica := dica_que_cabe(String(dados.get("dica", "")), HudTema.T_MICRO + 1, util)
	if com_dica and not dica.is_empty():
		var h := HudTema.altura(f_semi, HudTema.T_ROTULO) + 2.0
		caixas.append({"nome": "dica", "rect": Rect2(x, y, util, h),
			"linhas": PackedStringArray([dica])})
		y += h + 2.0

	return {"altura": maxf(0.0, y - 2.0), "caixas": caixas}


# --- dica com teclas ----------------------------------------------------------

## Parte "[M] abre o GPS   [E] traca a rota" em pedacos de tecla e de texto.
##
## Devolve `[{tecla: bool, texto}]`, sem pedaco vazio. Os espacos entre dois
## pares viram vao de desenho, e nao caractere: tres espacos em fonte
## proporcional nao tem largura previsivel.
static func pedacos(frase: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var resto := frase
	while not resto.is_empty():
		var a := resto.find("[")
		if a < 0:
			_juntar_texto(saida, resto)
			break
		var b := resto.find("]", a)
		if b < 0:
			_juntar_texto(saida, resto)
			break
		_juntar_texto(saida, resto.substr(0, a))
		var nome := resto.substr(a + 1, b - a - 1).strip_edges()
		if not nome.is_empty():
			saida.append({"tecla": true, "texto": nome})
		resto = resto.substr(b + 1)
	return saida


static func _juntar_texto(saida: Array[Dictionary], t: String) -> void:
	# Tres espacos ou mais separam duas coisas ("Capotou.     Sair"): viram dois
	# pedacos, para o vao ser desenhado e para a tecla casar com o verbo certo.
	var re := RegEx.create_from_string("\\s{3,}")
	for parte: String in re.sub(t.strip_edges(), "\n", true).split("\n", false):
		var limpo := parte.strip_edges()
		if not limpo.is_empty():
			saida.append({"tecla": false, "texto": limpo})


## Pedacos de um prompt de acao, com a tecla SEMPRE antes do verbo.
##
## O jogo escreve dos dois jeitos: "[E]  Abrir" e "Entrar no carro  [F]",
## "Ligar o motor  [E]     Sair  [F]". Lido em voz alta os dois funcionam; na
## tela, uma fila de acoes com a tecla ora antes ora depois obriga o olho a
## procurar. Quando a frase TERMINA em tecla, cada tecla casa com o texto que a
## precede e o par e invertido. Texto sem tecla (o nome da estacao, "Capotou.")
## fica onde estava.
static func acao(frase: String) -> Array[Dictionary]:
	var pp := pedacos(frase)
	if pp.is_empty() or not bool(pp[pp.size() - 1]["tecla"]):
		return pp
	var saida: Array[Dictionary] = []
	var i := pp.size() - 1
	while i >= 0:
		var p: Dictionary = pp[i]
		if bool(p["tecla"]) and i > 0 and not bool(pp[i - 1]["tecla"]):
			saida.push_front(pp[i - 1])
			saida.push_front(p)
			i -= 2
			continue
		saida.push_front(p)
		i -= 1
	return saida


## Tecla de teclado para o botao do controle, pelo layout escrito em `Controle`.
## As de baixo sao as dicas da pausa: andar e escolher e o analogico esquerdo (o
## direcional vai junto), zoom do mapa e gatilho, recentrar e o Y.
const _PAD := {
	"E": "A", "ESC": "B", "F": "RT", "R": "RB", "Q": "Y", "CTRL": "LT",
	"TAB": "SELECT", "M": "LB", "SHIFT": "L3", "ESPACO": "A",
	"ENTER": "A", "WASD": "LS", "W S": "LS", "A D": "LS", "Z X": "LT RT", "H": "Y",
}

## Prefixo de botao de controle. "A" sozinho e a tecla A; "@A" e o botao A, e
## `HudTema.tecla` o desenha redondo e verde (`HudGlifos`).
const MARCA_PAD := "@"


## Nome a desenhar para a tecla `tecla`. No controle devolve o botao marcado com
## `MARCA_PAD`; tecla sem botao (o "MOUSE" da inspecao) continua tecla.
static func glifo(tecla: String, pad: bool) -> String:
	if not pad or tecla.begins_with(MARCA_PAD):
		return tecla
	var b := String(_PAD.get(tecla.to_upper(), tecla))
	return MARCA_PAD + b if HudGlifos.eh_glifo(b) else tecla


## Tira pares do FIM da dica ate ela caber, no pior dos dois glifos (teclado ou
## controle). "[E] falar [TAB] bolsa [M] abre o GPS" vira "[E] falar [TAB]
## bolsa": a primeira tecla e a que a etapa pede; as de depois sao lembrete.
static func dica_que_cabe(dica: String, tam: int, largura_max: float) -> String:
	var pp := pedacos(dica)
	while not pp.is_empty() and maxf(largura_pedacos(pp, tam, false),
			largura_pedacos(pp, tam, true)) > largura_max:
		pp.pop_back()
		if not pp.is_empty() and bool(pp[pp.size() - 1]["tecla"]):
			pp.pop_back()
	var partes: PackedStringArray = []
	for p: Dictionary in pp:
		partes.append("[%s]" % p["texto"] if bool(p["tecla"]) else String(p["texto"]))
	return "   ".join(partes).replace("]   ", "] ")


## O prompt que cabe em `PROMPT_MAX`, e o tamanho de letra dele.
##
## Primeiro sai o texto solto sem tecla da frente — no carro e o nome da
## estacao, que a legenda do radio ja mostra quando muda. Depois a letra desce
## um ponto. Devolve `{pedacos, tam}`.
static func prompt_que_cabe(frase: String, pad: bool, s: float = 1.0) -> Dictionary:
	var pp := acao(frase)
	var tam := HudTema.T_CORPO
	var util := largura_logica(PROMPT_MAX, s) - 12.0
	while largura_pedacos(pp, tam, pad) > util and pp.size() > 1 \
			and not bool(pp[0]["tecla"]):
		pp.pop_front()
	while largura_pedacos(pp, tam, pad) > util and tam > HudTema.T_MICRO:
		tam -= 1
	return {"pedacos": pp, "tam": tam}


## Corpo do titulo do banner: 16 quando cabe, descendo ate 10. Nome de parque
## ("PARQUE DA CAIXA D'AGUA") e o que chega mais perto da borda.
static func tamanho_banner(titulo: String) -> int:
	var f := HudTema.fonte(700, 2)
	var tam := HudTema.T_DESTAQUE + 3
	while tam > 10 and HudTema.largura(f, titulo, tam) > BANNER.size.x - 8.0:
		tam -= 1
	return tam


## Segunda linha do bloco de lugar: "BAIRRO · SEX 22:43 · TEMPO".
##
## Quando nao cabe, sai uma parte INTEIRA do fim — o tempo primeiro, que o ceu
## ja mostra — em vez de cortar a palavra ("NEBLI..." nao le como nada). So o
## que restar sozinho e encurtado.
static func linha_de_lugar(bairro: String, hora: String, tempo: String, largura_max: float) -> String:
	var f := HudTema.regular()
	var partes: PackedStringArray = []
	for p: String in [bairro, hora, tempo]:
		if not p.is_empty():
			partes.append(p)
	while partes.size() > 1 and HudTema.largura(f, "  ·  ".join(partes), HudTema.T_ROTULO) > largura_max:
		# A hora fica: e ela que muda e que o jogador consulta.
		partes.remove_at(partes.size() - 1 if partes[partes.size() - 1] != hora else 0)
	return HudTema.encurtar(f, "  ·  ".join(partes), HudTema.T_ROTULO, largura_max)


## Largura de uma frase com teclas desenhadas, no tamanho dado.
static func largura_pedacos(pp: Array[Dictionary], tam: int, pad: bool = false) -> float:
	var f := HudTema.semi()
	var w := 0.0
	for i in pp.size():
		var p: Dictionary = pp[i]
		if i > 0:
			# Tecla seguida do proprio verbo fica colada; verbo seguido da proxima
			# tecla ganha vao largo, que e o que separa uma acao da outra.
			w += 3.0 if bool(pp[i - 1]["tecla"]) and not bool(p["tecla"]) else 8.0
		if bool(p["tecla"]):
			w += HudTema.largura_tecla(glifo(String(p["texto"]), pad), tam)
		else:
			w += HudTema.largura(f, String(p["texto"]), tam)
	return w
