## Preferencias do HUD: o que aparece, de que tamanho e com que peso.
##
## Por que arquivo proprio, e nao `Settings`
## ------------------------------------------
## Porque `settings.cfg` tem dono e varias frentes mexendo nele, e o HUD precisa
## de dezesseis chaves que nenhum outro sistema le. Arquivo separado
## (`user://hud.cfg`) nao disputa gravacao com ninguem, e apagar ele devolve o
## HUD padrao sem mexer em imagem e som.
##
## Quem le
## -------
## Cada peca pergunta a cada quadro (`ver`, `escala`, ...). Sao variaveis
## estaticas: o custo e o de ler um campo, e mudar uma opcao aparece no quadro
## seguinte sem sinal nem religacao.
class_name HudConfig
extends RefCounted

# Enum guardado em `int`, nunca `as Modo`: o cast para enum devolve null em
# silencio neste Godot (ver a memoria do projeto sobre armadilhas mudas).

const ARQUIVO := "user://hud.cfg"
const SECAO := "hud"

enum Modo { COMPLETO, MINIMO, DESLIGADO }
enum Vitais { CONTEXTUAIS, SEMPRE, DESLIGADOS }
enum Dano { TODOS, SO_CLARAO, SO_ALARME, NENHUM }

const MODO_ROTULO := ["COMPLETO", "MINIMO", "DESLIGADO"]
const VITAIS_ROTULO := ["QUANDO MUDAM", "SEMPRE", "DESLIGADOS"]
const DANO_ROTULO := ["TUDO", "SO CLARAO", "SO ALARME", "NENHUM"]
## Cor de destaque. Ferrugem e o padrao; azul e amarelo sao os dois que
## protanopia e deuteranopia continuam separando do verde do "ok" e do vermelho
## do perigo.
const DESTAQUE_ROTULO := ["FERRUGEM", "AZUL", "AMARELO"]
const DESTAQUE_COR: Array[Color] = [Color("e0764f"), Color("4fa3ff"), Color("f5c542")]
## Legenda de cena. Corpo em pixel logico: 11 e o que a legenda sempre teve; 14
## e o "grande" que qualquer AAA oferece para quem joga longe da tela.
const LEGENDA_ROTULO := ["PEQUENA", "MEDIA", "GRANDE"]
const LEGENDA_TAM: Array[int] = [9, 11, 14]
const LEGENDA_TAM_NOME: Array[int] = [6, 7, 9]
const FUNDO_ROTULO := ["LEVE", "FECHADO"]
const FUNDO_ALFA: Array[float] = [0.62, 0.92]

const ESCALA_MIN := 0.8
const ESCALA_MAX := 1.2
const ESCALA_PASSO := 0.05
const OPACIDADE_MIN := 0.4

## Pecas que se ligam e desligam uma a uma, na ordem da pagina.
const PECAS: Array[StringName] = [&"objetivo", &"bussola", &"radar", &"lugar", &"avisos",
	&"banners", &"prompt", &"iweed", &"painel_carro"]
const PECA_ROTULO := {
	&"objetivo": "OBJETIVO", &"bussola": "BUSSOLA", &"radar": "RADAR",
	&"lugar": "LUGAR E HORA", &"avisos": "AVISOS", &"banners": "BANNERS E RADIO",
	&"prompt": "ACAO NA TELA", &"iweed": "IWEED", &"painel_carro": "PAINEL DO CARRO",
}
## No modo MINIMO fica so o que o jogador precisa para agir: o que apertar, o
## que entrou na bolsa, e o carro (velocidade nao e enfeite).
const MINIMO: Array[StringName] = [&"prompt", &"avisos", &"painel_carro"]

static var modo: int = Modo.COMPLETO
static var escala_hud := 1.0
static var opacidade := 1.0
static var vitais: int = Vitais.CONTEXTUAIS
static var dano: int = Dano.TODOS
static var dica := true
static var radar_gira := true
static var contraste := false
static var marcador := true
static var gps_curvas := true
static var destaque: int = 0
## Pontinho sobre o que da para acionar perto (`HudPontos`).
static var pontos := true
static var legenda_tam: int = 1
static var legenda_fundo: int = 0
static var legenda_nome := true
static var _pecas: Dictionary = {}
## TAB segurado (`PausaHub`): o HUD inteiro aparece enquanto a tecla estiver
## apertada, qualquer que seja o modo — como o "expandir HUD" do RDR2. Nao grava.
static var expandido := false
static var _carregado := false


static func _garantir() -> void:
	if _carregado:
		return
	_carregado = true
	for p: StringName in PECAS:
		_pecas[p] = true
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return
	modo = clampi(int(cfg.get_value(SECAO, "modo", modo)), 0, 2)
	escala_hud = clampf(float(cfg.get_value(SECAO, "escala", escala_hud)), ESCALA_MIN, ESCALA_MAX)
	opacidade = clampf(float(cfg.get_value(SECAO, "opacidade", opacidade)), OPACIDADE_MIN, 1.0)
	vitais = clampi(int(cfg.get_value(SECAO, "vitais", vitais)), 0, 2)
	dano = clampi(int(cfg.get_value(SECAO, "dano", dano)), 0, 3)
	dica = bool(cfg.get_value(SECAO, "dica", dica))
	radar_gira = bool(cfg.get_value(SECAO, "radar_gira", radar_gira))
	contraste = bool(cfg.get_value(SECAO, "contraste", contraste))
	marcador = bool(cfg.get_value(SECAO, "marcador", marcador))
	gps_curvas = bool(cfg.get_value(SECAO, "gps_curvas", gps_curvas))
	destaque = clampi(int(cfg.get_value(SECAO, "destaque", destaque)), 0,
		DESTAQUE_COR.size() - 1)
	pontos = bool(cfg.get_value(SECAO, "pontos", pontos))
	legenda_tam = clampi(int(cfg.get_value(SECAO, "legenda_tam", legenda_tam)), 0, 2)
	legenda_fundo = clampi(int(cfg.get_value(SECAO, "legenda_fundo", legenda_fundo)), 0, 1)
	legenda_nome = bool(cfg.get_value(SECAO, "legenda_nome", legenda_nome))
	for p: StringName in PECAS:
		_pecas[p] = bool(cfg.get_value(SECAO, "peca_" + String(p), true))


static func salvar() -> void:
	_garantir()
	var cfg := ConfigFile.new()
	cfg.set_value(SECAO, "modo", int(modo))
	cfg.set_value(SECAO, "escala", escala_hud)
	cfg.set_value(SECAO, "opacidade", opacidade)
	cfg.set_value(SECAO, "vitais", int(vitais))
	cfg.set_value(SECAO, "dano", int(dano))
	cfg.set_value(SECAO, "dica", dica)
	cfg.set_value(SECAO, "radar_gira", radar_gira)
	cfg.set_value(SECAO, "contraste", contraste)
	cfg.set_value(SECAO, "marcador", marcador)
	cfg.set_value(SECAO, "gps_curvas", gps_curvas)
	cfg.set_value(SECAO, "destaque", destaque)
	cfg.set_value(SECAO, "pontos", pontos)
	cfg.set_value(SECAO, "legenda_tam", legenda_tam)
	cfg.set_value(SECAO, "legenda_fundo", legenda_fundo)
	cfg.set_value(SECAO, "legenda_nome", legenda_nome)
	for p: StringName in PECAS:
		cfg.set_value(SECAO, "peca_" + String(p), bool(_pecas[p]))
	cfg.save(ARQUIVO)


# --- leitura ---------------------------------------------------------------------

## A peca aparece? Junta o modo e a chave dela.
static func ver(peca: StringName) -> bool:
	_garantir()
	if expandido:
		return true
	if modo == Modo.DESLIGADO:
		return false
	if modo == Modo.MINIMO and not MINIMO.has(peca):
		return false
	return bool(_pecas.get(peca, true))


## A chave da peca, sem o modo. E o que a pagina de opcoes mostra.
static func peca_ligada(peca: StringName) -> bool:
	_garantir()
	return bool(_pecas.get(peca, true))


static func escala() -> float:
	_garantir()
	return escala_hud


static func alfa() -> float:
	_garantir()
	return opacidade


static func modo_vitais() -> int:
	_garantir()
	if expandido:
		return Vitais.SEMPRE
	if modo == Modo.DESLIGADO:
		return Vitais.DESLIGADOS
	return vitais


static func clarao() -> bool:
	_garantir()
	return dano == Dano.TODOS or dano == Dano.SO_CLARAO


static func alarme() -> bool:
	_garantir()
	return modo != Modo.DESLIGADO and (dano == Dano.TODOS or dano == Dano.SO_ALARME)


static func com_dica() -> bool:
	_garantir()
	return dica


static func gira() -> bool:
	_garantir()
	return radar_gira


## Marcador 3D do objetivo. Segue a chave do objetivo: sem rastreador, o
## losango no mundo seria uma marca sem legenda.
static func ver_marcador() -> bool:
	_garantir()
	return marcador and ver(&"objetivo")


## "Vire a direita em 40 m" embaixo da bussola. Segue a chave da bussola.
static func ver_gps() -> bool:
	_garantir()
	return gps_curvas and ver(&"bussola")


## Pontos de interacao. Seguem a chave da ACAO NA TELA: o ponto e o convite, o
## prompt e a resposta; um sem o outro fica pela metade.
static func ver_pontos() -> bool:
	_garantir()
	return pontos and ver(&"prompt")


## Legenda de cena: corpo do texto, corpo do nome, alfa do fundo, e se o nome
## de quem fala aparece. A legenda nao e peca do HUD: nao some com o modo.
static func legenda_corpo() -> int:
	_garantir()
	return LEGENDA_TAM[legenda_tam]


static func legenda_corpo_nome() -> int:
	_garantir()
	return LEGENDA_TAM_NOME[legenda_tam]


static func legenda_alfa_fundo() -> float:
	_garantir()
	return 0.95 if contraste else FUNDO_ALFA[legenda_fundo]


static func legenda_com_nome() -> bool:
	_garantir()
	return legenda_nome


static func alto_contraste() -> bool:
	_garantir()
	return contraste


static func cor_destaque() -> Color:
	_garantir()
	return DESTAQUE_COR[destaque]


# --- escrita (pagina de opcoes) ----------------------------------------------

static func alternar_peca(peca: StringName) -> void:
	_garantir()
	_pecas[peca] = not bool(_pecas.get(peca, true))
	salvar()


static func passo_modo(p: int) -> void:
	_garantir()
	modo = posmod(int(modo) + p, 3)
	salvar()


static func passo_escala(p: int) -> void:
	_garantir()
	escala_hud = clampf(snappedf(escala_hud + float(p) * ESCALA_PASSO, ESCALA_PASSO),
		ESCALA_MIN, ESCALA_MAX)
	salvar()


static func passo_opacidade(p: int) -> void:
	_garantir()
	opacidade = clampf(snappedf(opacidade + float(p) * 0.1, 0.1), OPACIDADE_MIN, 1.0)
	salvar()


static func passo_vitais(p: int) -> void:
	_garantir()
	vitais = posmod(int(vitais) + p, 3)
	salvar()


static func passo_dano(p: int) -> void:
	_garantir()
	dano = posmod(int(dano) + p, 4)
	salvar()


static func alternar_dica() -> void:
	_garantir()
	dica = not dica
	salvar()


static func alternar_giro() -> void:
	_garantir()
	radar_gira = not radar_gira
	salvar()


static func alternar_marcador() -> void:
	_garantir()
	marcador = not marcador
	salvar()


static func alternar_gps() -> void:
	_garantir()
	gps_curvas = not gps_curvas
	salvar()


static func alternar_contraste() -> void:
	_garantir()
	contraste = not contraste
	salvar()


static func alternar_pontos() -> void:
	_garantir()
	pontos = not pontos
	salvar()


static func passo_legenda(p: int) -> void:
	_garantir()
	legenda_tam = clampi(legenda_tam + p, 0, 2)
	salvar()


static func alternar_fundo_legenda() -> void:
	_garantir()
	legenda_fundo = 1 - legenda_fundo
	salvar()


static func alternar_nome_legenda() -> void:
	_garantir()
	legenda_nome = not legenda_nome
	salvar()


static func passo_destaque(p: int) -> void:
	_garantir()
	destaque = posmod(destaque + p, DESTAQUE_COR.size())
	salvar()


## Volta tudo ao padrao. Nao grava: quem chama decide (o teste usa para partir de
## um estado conhecido sem sujar o arquivo do jogador).
static func padrao() -> void:
	_carregado = true
	modo = Modo.COMPLETO
	escala_hud = 1.0
	opacidade = 1.0
	vitais = Vitais.CONTEXTUAIS
	dano = Dano.TODOS
	dica = true
	radar_gira = true
	contraste = false
	marcador = true
	gps_curvas = true
	destaque = 0
	pontos = true
	legenda_tam = 1
	legenda_fundo = 0
	legenda_nome = true
	for p: StringName in PECAS:
		_pecas[p] = true


# --- linhas da pagina de opcoes ---------------------------------------------
#
# Formato de `OpcoesLista`: {rotulo, ler() -> String, aplicar(passo)}.

static func linhas() -> Array[Dictionary]:
	return [
		{
			"rotulo": "HUD",
			"ler": func() -> String: return String(MODO_ROTULO[modo]),
			"aplicar": func(p: int) -> void: passo_modo(p),
		},
		{
			"rotulo": "TAMANHO",
			"ler": func() -> String: return "%d%%" % roundi(escala() * 100.0),
			"aplicar": func(p: int) -> void: passo_escala(p),
		},
		{
			"rotulo": "OPACIDADE",
			"ler": func() -> String: return "%d%%" % roundi(alfa() * 100.0),
			"aplicar": func(p: int) -> void: passo_opacidade(p),
		},
		{
			"rotulo": "CONTRASTE ALTO",
			"ler": func() -> String: return _liga(alto_contraste()),
			"aplicar": func(_p: int) -> void: alternar_contraste(),
		},
		{
			"rotulo": "DESTAQUE",
			"ler": func() -> String:
				_garantir()
				return String(DESTAQUE_ROTULO[destaque]),
			"aplicar": func(p: int) -> void: passo_destaque(p),
		},
	]


## Pagina EXIBICAO: como as pecas se comportam, e nao se elas existem.
static func linhas_exibicao() -> Array[Dictionary]:
	return [
		{
			"rotulo": "VITAIS",
			"ler": func() -> String:
				_garantir()
				return String(VITAIS_ROTULO[vitais]),
			"aplicar": func(p: int) -> void: passo_vitais(p),
		},
		{
			"rotulo": "AVISO DE DANO",
			"ler": func() -> String:
				_garantir()
				return String(DANO_ROTULO[dano]),
			"aplicar": func(p: int) -> void: passo_dano(p),
		},
		{
			"rotulo": "DICA DE TECLAS",
			"ler": func() -> String: return _liga(com_dica()),
			"aplicar": func(_p: int) -> void: alternar_dica(),
		},
		{
			"rotulo": "RADAR",
			"ler": func() -> String: return "GIRA COM O OLHAR" if gira() else "NORTE FIXO",
			"aplicar": func(_p: int) -> void: alternar_giro(),
		},
		{
			"rotulo": "MARCADOR NO MUNDO",
			"ler": func() -> String:
				_garantir()
				return _liga(marcador),
			"aplicar": func(_p: int) -> void: alternar_marcador(),
		},
		{
			"rotulo": "GPS CURVA A CURVA",
			"ler": func() -> String:
				_garantir()
				return _liga(gps_curvas),
			"aplicar": func(_p: int) -> void: alternar_gps(),
		},
		{
			"rotulo": "PONTOS DE INTERACAO",
			"ler": func() -> String:
				_garantir()
				return _liga(pontos),
			"aplicar": func(_p: int) -> void: alternar_pontos(),
		},
	]


## Pagina LEGENDAS. Fica fora do HUD de proposito: com o HUD desligado a fala
## continua tendo de ser lida.
static func linhas_legenda() -> Array[Dictionary]:
	return [
		{
			"rotulo": "TAMANHO DA LEGENDA",
			"ler": func() -> String:
				_garantir()
				return String(LEGENDA_ROTULO[legenda_tam]),
			"aplicar": func(p: int) -> void: passo_legenda(p),
		},
		{
			"rotulo": "FUNDO DA LEGENDA",
			"ler": func() -> String:
				_garantir()
				return String(FUNDO_ROTULO[legenda_fundo]),
			"aplicar": func(_p: int) -> void: alternar_fundo_legenda(),
		},
		{
			"rotulo": "QUEM FALA",
			"ler": func() -> String: return _liga(legenda_com_nome()),
			"aplicar": func(_p: int) -> void: alternar_nome_legenda(),
		},
	]


## Uma chave por peca, na ordem de `PECAS`. Com o HUD em MINIMO ou DESLIGADO a
## chave continua valendo e aparece; o modo so a sobrepoe enquanto estiver
## ligado.
static func linhas_pecas() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for peca: StringName in PECAS:
		var p := peca
		saida.append({
			"rotulo": String(PECA_ROTULO.get(p, String(p))),
			"ler": func() -> String: return _liga(peca_ligada(p)),
			"aplicar": func(_passo: int) -> void: alternar_peca(p),
		})
	return saida


static func _liga(sim: bool) -> String:
	return "LIGADO" if sim else "DESLIGADO"
