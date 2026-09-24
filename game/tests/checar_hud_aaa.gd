## Verificacao do HUD vetorial. Nivel 2.
##
##     godot --headless --path game --script res://tests/checar_hud_aaa.gd
##
## O que ele prova
## ---------------
## 1. Nenhuma peca fixa do HUD cruza outra, e todas cabem na area segura.
## 2. O rastreador de objetivo, nos PIORES textos que o jogo produz, nao
##    transborda a largura, nao cruza caixa com caixa e nao passa da altura que
##    a peca reserva (a que o teste 1 confere contra o banner e a bussola).
## 3. Os prompts reais do jogo cabem em `PROMPT_MAX`, que e o que garante que o
##    prompt nunca entra na coluna de avisos.
## 4. A tecla vai para antes do verbo sem perder nem trocar pedaco.
## 5. Os titulos de banner cabem no banner.
## 6. Tudo isso em cada TAMANHO oferecido nas opcoes (80%, 100%, 120%).
## 7. `HudConfig`: o modo sobrepoe as chaves do jeito que a pagina promete, e
##    as duas paginas de opcoes cabem na folha do menu de sistema.
## 8. Botoes de controle: a familia sai do nome do SDL, toda tecla do mapa tem
##    botao desenhado, e a linha de lugar perde parte inteira em vez de cortar.
##
## Mede `HudLayout`, funcao pura: sem cidade, sem chunk, sem janela.
extends SceneTree

const OBJETIVOS: Array[Dictionary] = [
	{"titulo": "A CASA DA FUMACA", "etapa": "1/3",
		"objetivo": "Marque a casa da fumaca no mapa.",
		"dica": "[M] abre o GPS   [E] traca a rota", "distancia": "140 m"},
	{"titulo": "O ESCRITORIO DE REGISTRO CIVIL DA MATRIZ", "etapa": "12/14",
		"objetivo": "Procure o balcao.", "dica": "", "distancia": "12.4 km"},
	{"titulo": "ENTREGA", "etapa": "2/3",
		"objetivo": "Leve o envelope lacrado ate o balcao do registro civil antes que o expediente termine e volte com o protocolo carimbado na mesma noite, sem passar pela blitz da avenida.",
		"dica": "[E] falar   [TAB] bolsa   [M] abre o GPS", "distancia": "985 m"},
	{"titulo": "", "etapa": "", "objetivo": "OBJETIVO CUMPRIDO", "dica": "",
		"distancia": ""},
]

## Os prompts mais compridos que o jogo escreve hoje (ver `player.gd`,
## `carro.gd`, `porta.gd`, `iweed`), com a estacao de nome mais longo.
const PROMPTS: Array[String] = [
	"Tirar o motorista  [F]     Falar com ele  [E]",
	"SAMBA DA ESQUINA   [R] radio   [Ctrl] buzina   [F] descer",
	"Ligar o motor  [E]     Sair  [F]",
	"[E]  Entregar 3x Prensado (Beco do Ze)",
	"Capotou.     Sair  [F]",
]

const BANNERS: Array[String] = ["NOVA MISSAO", "MISSAO CUMPRIDA", "BOSQUE DO MORRO",
	"PARQUE DA CAIXA D'AGUA"]

var _falhas := 0
var _total := 0


const ESCALAS: Array[float] = [HudConfig.ESCALA_MIN, 1.0, HudConfig.ESCALA_MAX]


func _initialize() -> void:
	for s: float in ESCALAS:
		_checar_pecas(s)
		_checar_objetivo(s)
		_checar_prompts(s)
	_checar_acao()
	_checar_banners()
	_checar_config()
	_checar_navegacao()
	_checar_dias()
	print("checar_hud_aaa: %d/%d ok" % [_total - _falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas += 1
		print("  FALHOU: ", msg)


func _checar_pecas(s: float) -> void:
	var seguro := Rect2(Vector2.ONE * (HudTema.MARGEM - 0.5),
		HudTema.TELA - Vector2.ONE * (HudTema.MARGEM - 0.5) * 2.0)
	var pecas := HudLayout.pecas(s)
	var nomes := pecas.keys()
	for n: String in nomes:
		var r: Rect2 = pecas[n]
		_afirmar("[%d%%] %s dentro da area segura (%s)" % [roundi(s * 100.0), n, r],
			seguro.encloses(r))
	for i in nomes.size():
		for j in range(i + 1, nomes.size()):
			var a: Rect2 = pecas[nomes[i]]
			var b: Rect2 = pecas[nomes[j]]
			_afirmar("[%d%%] %s nao cruza %s" % [roundi(s * 100.0), nomes[i], nomes[j]],
				not a.intersects(b))
	# Sem radar (dentro de casa) o bloco de lugar sobe para o canto; tem de
	# continuar fora da bussola.
	_afirmar("lugar sem radar fora da bussola",
		not HudLayout.local_rect(false).intersects(HudLayout.BUSSOLA))


func _checar_objetivo(s: float) -> void:
	# A peca e desenhada em escala `s` com largura logica 150/s; a altura
	# logica tem de caber na reservada ANTES da escala.
	var largura := HudLayout.largura_logica(HudLayout.OBJETIVO_LARGURA, s)
	for caso: Dictionary in OBJETIVOS:
		for com_dica: bool in [true, false]:
			var nome := "[%d%%] %s/%s" % [roundi(s * 100.0), String(caso["titulo"]).left(16),
				"dica" if com_dica else "tira"]
			var plano := HudLayout.objetivo(caso, com_dica, largura)
			var caixas: Array = plano["caixas"]
			_afirmar("objetivo %s cabe na altura reservada (%.1f)" % [nome, plano["altura"]],
				float(plano["altura"]) <= HudLayout.OBJETIVO_ALTURA_MAX)
			for k in caixas.size():
				var c: Dictionary = caixas[k]
				var r: Rect2 = c["rect"]
				_afirmar("objetivo %s: %s tem area" % [nome, c["nome"]],
					r.size.x > 0.0 and r.size.y > 0.0)
				_afirmar("objetivo %s: %s dentro da largura" % [nome, c["nome"]],
					r.end.x <= largura + 0.5)
				for m in range(k + 1, caixas.size()):
					var r2: Rect2 = (caixas[m] as Dictionary)["rect"]
					_afirmar("objetivo %s: %s nao cruza %s" % [nome, c["nome"],
						(caixas[m] as Dictionary)["nome"]], not r.intersects(r2))
				_afirmar("objetivo %s: texto de %s cabe" % [nome, c["nome"]],
					_texto_cabe(c))


func _texto_cabe(c: Dictionary) -> bool:
	var r: Rect2 = c["rect"]
	var linhas: PackedStringArray = c["linhas"]
	match String(c["nome"]):
		"titulo":
			return HudTema.largura(HudTema.rotulo(), linhas[0], HudTema.T_ROTULO) <= r.size.x + 0.5
		"etapa", "distancia":
			return HudTema.largura(HudTema.semi(), linhas[0], HudTema.T_ROTULO) + 9.0 <= r.size.x + 9.5
		"objetivo":
			for l: String in linhas:
				if HudTema.largura(HudTema.regular(), l, HudTema.T_CORPO) > r.size.x + 0.5:
					return false
			return true
		"dica":
			return HudLayout.largura_pedacos(HudLayout.pedacos(linhas[0]),
				HudTema.T_MICRO + 1, true) <= r.size.x + 0.5 \
				and HudLayout.largura_pedacos(HudLayout.pedacos(linhas[0]),
				HudTema.T_MICRO + 1, false) <= r.size.x + 0.5
	return true


func _checar_prompts(s: float) -> void:
	for t: String in PROMPTS:
		for pad: bool in [false, true]:
			# +12: o painel passa 6 px de cada lado do texto (`HudPrompt._draw`).
			# Medido na TELA: largura logica vezes a escala.
			var cabe := HudLayout.prompt_que_cabe(t, pad, s)
			var w := (HudLayout.largura_pedacos(cabe["pedacos"], int(cabe["tam"]), pad) + 12.0) * s
			_afirmar("prompt \"%s\" mantem toda tecla" % t,
				_teclas(HudLayout.pedacos(t)) == _teclas(cabe["pedacos"]))
			_afirmar("prompt \"%s\" (%s) cabe: %.1f <= %.1f" % [t, "pad" if pad else "teclado",
				w, HudLayout.PROMPT_MAX], w <= HudLayout.PROMPT_MAX)


func _teclas(pp: Array) -> int:
	var n := 0
	for p: Dictionary in pp:
		if bool(p["tecla"]):
			n += 1
	return n


func _checar_acao() -> void:
	var casos := {
		"Entrar no carro  [F]": "[F] Entrar no carro",
		"[E]  Abrir": "[E] Abrir",
		"Ligar o motor  [E]     Sair  [F]": "[E] Ligar o motor|[F] Sair",
		"Capotou.     Sair  [F]": "Capotou.|[F] Sair",
		"SAMBA DA ESQUINA   [R] radio   [Ctrl] buzina": "SAMBA DA ESQUINA|[R] radio|[Ctrl] buzina",
	}
	for entrada: String in casos:
		var saida := _serializar(HudLayout.acao(entrada))
		_afirmar("acao(\"%s\") = \"%s\" (deu \"%s\")" % [entrada, casos[entrada], saida],
			saida == String(casos[entrada]))
	_afirmar("glifo E vira o botao A no controle", HudLayout.glifo("E", true) == "@A")
	_afirmar("glifo desconhecido fica tecla", HudLayout.glifo("Z", true) == "Z")
	_afirmar("glifo no teclado fica", HudLayout.glifo("F", false) == "F")
	_afirmar("glifo ja marcado nao dobra", HudLayout.glifo("@LB", true) == "@LB")
	_afirmar("zoom do mapa vira os dois gatilhos", HudLayout.glifo("Z X", true) == "@LT RT")
	_afirmar("MOUSE continua tecla no controle", HudLayout.glifo("MOUSE", true) == "MOUSE")
	_checar_glifos()
	_checar_linha_de_lugar()
	_checar_chegada()
	_checar_controles()


## Onda 5: a chegada so dispara depois de o jogador ter estado longe, e de carro
## o raio e maior.
func _checar_chegada() -> void:
	var dest := Vector2(100.0, 0.0)
	var r := HudNavegacao.vigiar_chegada(dest, Vector2(95.0, 0.0), false, false)
	_afirmar("marcar onde ja se esta nao chega", not bool(r["chegou"]) and not bool(r["armada"]))
	r = HudNavegacao.vigiar_chegada(dest, Vector2(0.0, 0.0), false, false)
	_afirmar("longe arma a vigia", bool(r["armada"]) and not bool(r["chegou"]))
	r = HudNavegacao.vigiar_chegada(dest, Vector2(92.0, 0.0), false, true)
	_afirmar("a pe, a 8 m chega", bool(r["chegou"]) and not bool(r["armada"]))
	r = HudNavegacao.vigiar_chegada(dest, Vector2(82.0, 0.0), false, true)
	_afirmar("a pe, a 18 m ainda nao", not bool(r["chegou"]) and bool(r["armada"]))
	r = HudNavegacao.vigiar_chegada(dest, Vector2(82.0, 0.0), true, true)
	_afirmar("de carro, a 18 m chega", bool(r["chegou"]))


## A tabela da tela CONTROLES: toda acao tem tecla, todo botao tem desenho, e
## so o GPS (que mora no celular) fica sem botao.
func _checar_controles() -> void:
	var linhas := HudControles.linhas()
	_afirmar("controles: %d acoes" % linhas.size(), linhas.size() == HudControles.ACOES.size())
	for l: Dictionary in linhas:
		var acao: StringName = l["acao"]
		_afirmar("controles: %s tem tecla (%s)" % [acao, l["tecla"]], not String(l["tecla"]).is_empty())
		var b := String(l["botao"])
		if acao == &"gps":
			_afirmar("controles: GPS sem botao", b.is_empty())
		else:
			_afirmar("controles: %s tem botao desenhavel (%s)" % [acao, b], HudGlifos.eh_glifo(b))
	_afirmar("controles: interagir e E / A", HudControles.tecla_de(&"interagir") == "E"
		and HudControles.botao_de(&"interagir") == "A")
	_afirmar("controles: pausa e ESC / START", HudControles.tecla_de(&"pausa") == "ESC"
		and HudControles.botao_de(&"pausa") == "START")
	_afirmar("controles: agachar e o gatilho esquerdo", HudControles.botao_de(&"agachar") == "LT")
	# 14 linhas de 11 px mais o cabecalho cabem na coluna da SISTEMA (192 - 22).
	_afirmar("controles: tabela cabe na coluna",
		10.0 + float(linhas.size()) * HudControles.LINHA <= 192.0 - 22.0)
	HudConfig.padrao()
	_afirmar("pontos ligados no padrao", HudConfig.ver_pontos())
	HudConfig._pecas[&"prompt"] = false  # sem salvar(): o teste nao grava o hud.cfg
	_afirmar("pontos seguem a acao na tela", not HudConfig.ver_pontos())
	HudConfig.padrao()
	_afirmar("legenda media e 11", HudConfig.legenda_corpo() == 11)
	HudConfig.legenda_tam = 2
	_afirmar("legenda grande maior que media", HudConfig.legenda_corpo() > 11)
	HudConfig.padrao()


## 2.8: botoes desenhados. A familia sai do nome do SDL; a largura do botao e a
## que o prompt usa para caber; toda tecla do mapa de controle tem desenho.
func _checar_glifos() -> void:
	var familias := {
		"Xbox Series Controller": HudGlifos.XBOX,
		"XInput Gamepad (GLFW)": HudGlifos.XBOX,
		"PS4 Controller": HudGlifos.PLAYSTATION,
		"Wireless Controller": HudGlifos.PLAYSTATION,
		"DualSense Wireless Controller": HudGlifos.PLAYSTATION,
		"Sony Interactive Entertainment Controller": HudGlifos.PLAYSTATION,
		"8BitDo Pro 2": HudGlifos.XBOX,
	}
	for nome: String in familias:
		_afirmar("familia de \"%s\"" % nome, HudGlifos.familia_do_nome(nome) == int(familias[nome]))
	for tecla: String in HudLayout._PAD:
		var g := HudLayout.glifo(tecla, true)
		_afirmar("tecla %s tem botao desenhado (%s)" % [tecla, g],
			g.begins_with(HudLayout.MARCA_PAD) and HudGlifos.eh_glifo(g.substr(1)))
	_afirmar("\"LT X\" e glifo, \"LT Z\" nao", HudGlifos.eh_glifo("LT X") and not HudGlifos.eh_glifo("LT Z"))
	for tam: int in [HudTema.T_MICRO, HudTema.T_MICRO + 1, HudTema.T_ROTULO, HudTema.T_CORPO]:
		var alto := HudTema.altura(HudTema.semi(), tam) + 2.0
		_afirmar("botao redondo e quadrado em %d" % tam,
			is_equal_approx(HudTema.largura_tecla("@A", tam), alto))
		_afirmar("ombro mais largo que botao em %d" % tam,
			HudTema.largura_tecla("@LB", tam) > HudTema.largura_tecla("@A", tam))
		_afirmar("par de gatilhos soma os dois e o vao em %d" % tam, is_equal_approx(
			HudTema.largura_tecla("@LT RT", tam),
			HudTema.largura_tecla("@LT", tam) + HudTema.largura_tecla("@RT", tam) + HudGlifos.VAO))


## Segunda linha do bloco de lugar: sai o tempo INTEIRO, nunca "NEBLI...".
func _checar_linha_de_lugar() -> void:
	var w := HudLayout.LOCAL_LARGURA
	var cheia := HudLayout.linha_de_lugar("CENTRO", "SEX 22:43", "CHUVA", w)
	_afirmar("linha curta leva as tres partes (%s)" % cheia, cheia.count("·") == 2)
	var longa := HudLayout.linha_de_lugar("TERRENO BALDIO", "SEX 22:43", "NEBLINA DENSA", w)
	_afirmar("linha longa perde o tempo inteiro (%s)" % longa,
		not longa.contains("...") and not longa.contains("NEB") and longa.contains("22:43"))
	var enorme := HudLayout.linha_de_lugar("PARQUE DA CAIXA D'AGUA DO ALTO DA SERRA", "SEX 22:43",
		"NEBLINA", w)
	_afirmar("bairro enorme sai, a hora fica (%s)" % enorme, enorme.contains("22:43"))
	for t: String in [cheia, longa, enorme]:
		_afirmar("\"%s\" cabe no bloco" % t,
			HudTema.largura(HudTema.regular(), t, HudTema.T_ROTULO) <= w + 0.01)


## "[E] Ligar o motor|[F] Sair": tecla colada no verbo seguinte, par separado
## por barra.
func _serializar(pp: Array[Dictionary]) -> String:
	var grupos: PackedStringArray = []
	var atual := ""
	for p: Dictionary in pp:
		if bool(p["tecla"]):
			if not atual.is_empty():
				grupos.append(atual)
			atual = "[%s]" % p["texto"]
		else:
			if atual.begins_with("[") and not atual.contains(" "):
				atual += " " + String(p["texto"])
			else:
				if not atual.is_empty():
					grupos.append(atual)
				atual = String(p["texto"])
	if not atual.is_empty():
		grupos.append(atual)
	return "|".join(grupos)


func _checar_banners() -> void:
	var f := HudTema.fonte(700, 2)
	for t: String in BANNERS:
		var w := HudTema.largura(f, t, HudLayout.tamanho_banner(t))
		_afirmar("banner \"%s\" cabe: %.1f <= %.1f" % [t, w, HudLayout.BANNER.size.x],
			w <= HudLayout.BANNER.size.x)


func _checar_config() -> void:
	HudConfig.padrao()
	_afirmar("padrao mostra o radar", HudConfig.ver(&"radar"))
	HudConfig.modo = HudConfig.Modo.MINIMO
	_afirmar("minimo esconde o radar", not HudConfig.ver(&"radar"))
	_afirmar("minimo mantem o prompt", HudConfig.ver(&"prompt"))
	HudConfig.modo = HudConfig.Modo.DESLIGADO
	_afirmar("desligado esconde o prompt", not HudConfig.ver(&"prompt"))
	_afirmar("desligado apaga os vitais",
		HudConfig.modo_vitais() == HudConfig.Vitais.DESLIGADOS)
	_afirmar("desligado cala o alarme de vida", not HudConfig.alarme())
	HudConfig.modo = HudConfig.Modo.COMPLETO
	HudConfig._pecas[&"bussola"] = false
	_afirmar("chave desligada esconde a peca", not HudConfig.ver(&"bussola"))
	HudConfig.padrao()
	for i in 20:
		HudConfig.escala_hud = clampf(snappedf(HudConfig.escala_hud + HudConfig.ESCALA_PASSO,
			HudConfig.ESCALA_PASSO), HudConfig.ESCALA_MIN, HudConfig.ESCALA_MAX)
	_afirmar("tamanho para no maximo", is_equal_approx(HudConfig.escala_hud, HudConfig.ESCALA_MAX))
	HudConfig.padrao()
	# A folha do menu de sistema cabe ~10 linhas (`MenuSistema._folha`, 12 px do
	# topo, altura = 36 + linhas*18 + 22 + divisores). Mais uma linha e ela passa
	# do pe da tela.
	# Pause: + EXIBICAO, PECAS DO HUD e VOLTAR na pagina HUD; + VOLTAR nas outras.
	var paginas := {
		"HUD": [HudConfig.linhas().size() + 3, 3],
		"EXIBICAO": [HudConfig.linhas_exibicao().size() + 1, 0],
		"PECAS": [HudConfig.linhas_pecas().size() + 1, 0],
		"LEGENDAS": [HudConfig.linhas_legenda().size() + 1, 0],
	}
	for nome: String in paginas:
		var n: int = paginas[nome][0]
		var alto := 36.0 + float(n) * 18.0 + 22.0 + 7.0 * float(paginas[nome][1])
		_afirmar("pause: pagina %s cabe na tela (%.0f)" % [nome, alto],
			alto <= HudTema.TELA.y - 24.0)
		# Titulo: as mesmas linhas + "< VOLTAR PAGINA" e VOLTAR (ver `menu.gd`).
		_afirmar("titulo: pagina %s cabe no papel (%d linhas)" % [nome, n + 1],
			OpcoesLayout.cabe(n + 1))
	# No titulo a pagina HUD leva tambem "LEGENDAS >": cinco linhas de pagina.
	_afirmar("titulo: pagina HUD com LEGENDAS cabe no papel",
		OpcoesLayout.cabe(HudConfig.linhas().size() + 5))
	for linha: Dictionary in HudConfig.linhas() + HudConfig.linhas_exibicao() 			+ HudConfig.linhas_pecas() + HudConfig.linhas_legenda():
		var ler: Callable = linha["ler"]
		_afirmar("opcao %s tem valor" % linha["rotulo"], not String(ler.call()).is_empty())


## Rota em L, em U e reta, andando por ela. Norte e -y: indo para o norte e
## virando para o leste, a curva e a DIREITA.
func _checar_navegacao() -> void:
	var l := PackedVector2Array([Vector2(0, 0), Vector2(0, -100), Vector2(80, -100)])
	var m := HudNavegacao.proxima(l, Vector2(0, -20))
	_afirmar("L: vira a direita (%s)" % m.get("tipo"), m.get("tipo") == &"direita")
	_afirmar("L: faltam 80 m (%.1f)" % float(m.get("dist", -1.0)),
		is_equal_approx(float(m.get("dist", -1.0)), 80.0))
	var l2 := PackedVector2Array([Vector2(0, 0), Vector2(0, -100), Vector2(-80, -100)])
	_afirmar("L espelhado: esquerda", HudNavegacao.proxima(l2, Vector2(0, -20)).get("tipo") == &"esquerda")
	var depois := HudNavegacao.proxima(l, Vector2(40, -100))
	_afirmar("depois da curva: chegada (%s)" % depois.get("tipo"), depois.get("tipo") == &"chegada")
	_afirmar("chegada: faltam 40 m", is_equal_approx(float(depois.get("dist", -1.0)), 40.0))
	var u := PackedVector2Array([Vector2(0, 0), Vector2(0, -50), Vector2(1, 0)])
	_afirmar("U: retorno", HudNavegacao.proxima(u, Vector2(0, -10)).get("tipo") == &"retorno")
	var longe := PackedVector2Array([Vector2(0, 0), Vector2(0, -900), Vector2(80, -900)])
	_afirmar("curva a 880 m: siga", HudNavegacao.proxima(longe, Vector2(0, -20)).get("tipo") == &"siga")
	var torta := PackedVector2Array([Vector2(0, 0), Vector2(3, -60), Vector2(6, -120)])
	_afirmar("desvio de faixa nao e curva",
		HudNavegacao.proxima(torta, Vector2(0, -5)).get("tipo") == &"chegada")
	_afirmar("sem rota, nada", HudNavegacao.proxima(PackedVector2Array(), Vector2.ZERO).is_empty())
	# A pagina EXIBICAO ganhou duas linhas: continua cabendo.
	var n := HudConfig.linhas_exibicao().size() + 1
	_afirmar("pause: EXIBICAO cabe (%d linhas)" % n, 36.0 + float(n) * 18.0 + 22.0 <= HudTema.TELA.y - 24.0)
	# Dirigindo: os avisos que cabem acima do mostrador (topo em 229 - 34 - 4,
	# centro medido pela bancada do painel) nao descem sobre ele.
	for esc: float in ESCALAS:
		var limite := 229.0 - PainelLayout.RAIO - 4.0
		var cabem := HudLayout.avisos_que_cabem(esc, true, limite)
		var fim := HudLayout.aviso_rect(cabem - 1, true, esc).end.y if cabem > 0 else 0.0
		_afirmar("[%d%%] dirigindo: %d avisos acabam em %.1f <= %.1f" % [roundi(esc * 100.0), cabem,
			fim, limite], cabem == 0 or fim <= limite + 0.01)
		_afirmar("[%d%%] dirigindo: ao menos 1 aviso cabe" % roundi(esc * 100.0), cabem >= 1)


## O dia conta nos tres caminhos que mexem no relogio: o tempo correndo, o
## desmaio (`definir_minutos` alem da meia-noite) e o servidor em rede, que
## escreve `segundos` direto.
func _checar_dias() -> void:
	var r := Relogio.new()
	_afirmar("dia 1 e sexta (%s)" % r.dia_da_semana(), r.dia == 1 and r.dia_da_semana() == "SEX")
	# 22:43 -> 00:43 correndo: 120 minutos de jogo sao 3600 s reais (ritmo 2),
	# em passos de um minuto real.
	for i in 60:
		r.avancar(60.0)
	_afirmar("passou da meia-noite correndo: dia 2 (%d, %s)" % [r.dia, r.texto()], r.dia == 2)
	_afirmar("dia 2 e sabado", r.dia_da_semana() == "SAB")
	r.definir_minutos(23 * 60)
	r.definir_minutos(r.minutos() + 4 * 60)
	_afirmar("desmaio de 4 h atravessa a meia-noite: dia 3 (%d)" % r.dia, r.dia == 3)
	r.segundos = 23.9 * 3600.0
	r.segundos = 30.0
	_afirmar("servidor acerta depois da meia-noite: dia 4 (%d)" % r.dia, r.dia == 4)
	r.segundos = 100.0
	_afirmar("acerto pequeno para frente nao conta dia", r.dia == 4)
	r.segundos = 50.0
	_afirmar("acerto pequeno para tras nao conta dia", r.dia == 4)
	var semana := PackedStringArray()
	for k in 7:
		r.dia = 1 + k
		semana.append(r.dia_da_semana())
	_afirmar("a semana gira (%s)" % " ".join(semana), " ".join(semana) == "SEX SAB DOM SEG TER QUA QUI")
