## Verificacao de layout do HUD. Nivel 2.
##
##     godot --headless --path game --script res://tests/checar_hud.gd
##
## O que ele prova
## ---------------
## Que nenhum retangulo de texto do cartao de missao encosta em outro, que todos
## cabem dentro do papel, que nenhuma string transborda a propria caixa — medida
## na fonte real, no tamanho real — e que o papel inteiro cabe na area segura.
##
## Por que ele existe
## ------------------
## Porque o cartao passou a vida com titulo e distancia nascendo no MESMO
## retangulo, com as linhas espacadas de 10 px numa fonte cuja linha tem 13, e
## com o `Label` sem prender o tamanho da fonte — o que fazia o TextServer
## esticar a bitmap de 11 para 16 e a linha real virar 18,9 px.
##
## Ninguem viu por meses. O defeito so aparece com titulo comprido ou distancia
## em quilometro, e nenhuma captura pegou as duas coisas juntas. Olhar a tela nao
## encontra isso; medir encontra. Por isso os casos aqui sao de proposito os
## PIORES que o jogo consegue produzir, e nao o caso bonito que ja se sabe que
## funciona.
##
## Ele mede `CartaoLayout`, que e funcao pura: roda em milissegundos, sem montar
## cidade, sem carregar chunk e sem abrir janela.
extends SceneTree

const FONTE_P := "res://assets/fontes/psx_pequena.fnt"
## A fonte dos itens do menu de titulo. Ver `_checar_menu_titulo`.
const FONTE_M := "res://assets/fontes/psx_media.fnt"

## Cada caso existe para quebrar uma regra diferente.
const CASOS: Array[Dictionary] = [
	{
		"nome": "curto",
		"titulo": "A CASA DA FUMACA",
		"etapa": "1/2",
		"objetivo": "Va ate a casa da fumaca.",
		"dica": "[M] abre o GPS   [E] traca a rota",
		"distancia": "270 M",
	},
	{
		"nome": "titulo que nao cabe",
		"titulo": "O ESCRITORIO DE REGISTRO CIVIL DA MATRIZ",
		"etapa": "1/4",
		"objetivo": "Procure o balcao.",
		"dica": "",
		"distancia": "1.2 KM",
	},
	{
		"nome": "objetivo de varias linhas",
		"titulo": "ENTREGA",
		"etapa": "2/3",
		"objetivo": "Leve o envelope lacrado ate o balcao do registro civil antes que o expediente termine e volte com o protocolo carimbado na mesma noite.",
		"dica": "[E] falar   [TAB] bolsa",
		"distancia": "12.4 KM",
	},
	{
		"nome": "dica comprida",
		"titulo": "BLITZ",
		"etapa": "1/2",
		"objetivo": "Pare o carro.",
		"dica": "[E] entregar documento   [Q] sair do carro   [TAB] abrir a bolsa e procurar a carteira",
		"distancia": "8 M",
	},
	{
		"nome": "sem dica e sem etapa",
		"titulo": "VOLTE",
		"etapa": "",
		"objetivo": "Volte para a praca.",
		"dica": "",
		"distancia": "640 M",
	},
	{
		"nome": "sem alvo",
		"titulo": "A CASA DA FUMACA",
		"etapa": "1/2",
		"objetivo": "Marque a casa da fumaca no mapa.",
		"dica": "[M] abre o GPS",
		"distancia": "",
	},
	{
		"nome": "objetivo cumprido",
		"titulo": "",
		"etapa": "",
		"objetivo": "OBJETIVO CUMPRIDO",
		"dica": "",
		"distancia": "",
	},
]

var _falhas: PackedStringArray = []
var _total: int = 0
var _fonte: Font


func _initialize() -> void:
	print("\n=== layout do HUD ===\n")
	_fonte = load(FONTE_P) as Font
	_afirmar("fonte pequena carrega", _fonte != null)
	if _fonte == null:
		_terminar()
		return

	_metrica()
	for caso: Dictionary in CASOS:
		for com_dica: bool in [true, false]:
			_checar(caso, com_dica)
	_relogio()
	_apagao_contrato()
	for caso: Dictionary in FAIXAS:
		_checar_faixa(caso)
	_checar_prompt()
	_checar_menu_titulo()
	_checar_opcoes()
	_checar_carteira()
	_checar_travessia()
	_terminar()


## Os rotulos da folha de OPCOES, como o jogo os produz hoje.
##
## Copiados de `OpcoesLista.video()`, de `Settings.BUS_ROTULO` e do VOLTAR que
## `menu.gd` acrescenta. Ficam aqui em vez de serem lidos da fonte porque
## `OpcoesLista` fala com `Settings`, que e autoload, e este teste roda sem
## SceneTree — a mesma razao pela qual `TituloLayout` existe.
## A pagina de IMAGEM e a mais cheia, e e ela que decide o passo.
const OPCOES_ROTULOS: Array[String] = [
	"ESTILO", "RESOLUCAO 3D", "NEVOA", "GRAO", "ABERRACAO", "SCANLINE",
	"VINHETA", "DITHER",
	"SOM  >", "VOLTAR",
]
## A pagina de SOM.
const OPCOES_SOM: Array[String] = [
	"GERAL", "MUSICA", "EFEITOS", "AMBIENTE", "<  IMAGEM", "VOLTAR",
]

## Os valores mais largos que cada tipo de linha consegue mostrar.
##
## A coluna de valor tem 180 px e nunca tinha sido medida contra o que entra
## nela. Os nomes de nevoa sao os dos OITO presets oferecidos no menu
## (`Settings.FOG_PRESET_IDS`), em maiuscula, que e como a lista os escreve.
const OPCOES_VALORES: Array[String] = [
	"PERSONALIZADO", "PS1 STYLE", "MODERNO",
	"1280 x 720", "480 x 270",
	"NEBLINA COM CHUVA", "NEBLINA (ESPECIAL)", "NOITE ESTRELADA", "DIA ENSOLARADO",
	"NOITE DE CHUVA", "DIA DE CHUVA", "DIA NUBLADO", "NOITE NUBLADA",
	"[##########]", "[..........]",
	"DESLIGADO", "LIGADO",
	"> PERSONALIZADO", "> NEBLINA COM CHUVA",
]


## A folha de OPCOES: a quarta tela do menu, e a ultima a entrar na regua.
func _checar_opcoes() -> void:
	var n := OPCOES_ROTULOS.size()
	var p := OpcoesLayout.passo(n)
	# A reserva da ultima linha tem de ser a altura de linha REAL da fonte. Ela
	# era o `fixed_size` (11) contra uma linha de 13, e foi assim que VOLTAR
	# entrou na moldura do papel duas vezes.
	_afirmar("opcoes: LINHA (%.0f) e a altura real da fonte (%.0f)"
		% [OpcoesLayout.LINHA, UiEstilo.altura_da_linha(_fonte)],
		is_equal_approx(OpcoesLayout.LINHA, UiEstilo.altura_da_linha(_fonte)))
	print("-- opcoes: %d linhas, passo %.1f px" % [n, p])
	_afirmar("opcoes: %d linhas cabem sem apertar abaixo da fonte" % n,
		OpcoesLayout.cabe(n))

	var creme := Rect2(OpcoesLayout.PAPEL.position.x, OpcoesLayout.CREME_TOPO,
		OpcoesLayout.PAPEL.size.x, OpcoesLayout.CREME_BASE - OpcoesLayout.CREME_TOPO)
	var anterior := Rect2()
	for i in n:
		var rot := OpcoesLayout.rotulo(i, n)
		var val := OpcoesLayout.valor(i, n)
		var nome := "opcoes[%s]" % OPCOES_ROTULOS[i]
		# A caixa tem 14 px de altura para uma fonte de 13: o que precisa caber
		# no creme e a LINHA de texto, e nao a folga da caixa.
		var tinta := Rect2(rot.position, Vector2(rot.size.x, UiEstilo.altura_da_linha(_fonte)))
		_afirmar("%s: a linha cabe no creme do papel" % nome, creme.encloses(tinta))
		_afirmar("%s: rotulo nao invade a coluna de valor" % nome,
			rot.end.x <= val.position.x)
		_afirmar("%s: texto do rotulo cabe na coluna" % nome,
			UiEstilo.largura(_fonte, OPCOES_ROTULOS[i]) <= rot.size.x)
		if i > 0:
			_afirmar("%s: nao encosta na linha de cima" % nome,
				tinta.position.y >= anterior.end.y - 0.01)
		anterior = tinta

	# O valor mais largo que o jogo consegue escrever tem de caber na coluna.
	# "NEBLINA COM CHUVA" e o pior caso real, e ninguem tinha medido.
	var coluna := OpcoesLayout.valor(0, n)
	var pior := ""
	var pior_px := 0.0
	for texto: String in OPCOES_VALORES:
		var w := UiEstilo.largura(_fonte, texto)
		if w > pior_px:
			pior_px = w
			pior = texto
		_afirmar("opcoes: valor '%s' cabe na coluna (%.0f px)" % [texto, w],
			w <= coluna.size.x)
	print("-- opcoes: valor mais largo e '%s' com %.0f px de %.0f" % [pior, pior_px, coluna.size.x])

	# A segunda pagina passa pela mesma regua.
	var ns := OPCOES_SOM.size()
	_afirmar("opcoes: pagina SOM (%d linhas) cabe" % ns, OpcoesLayout.cabe(ns))
	for i in ns:
		var caixa := OpcoesLayout.rotulo(i, ns)
		var tinta_som := Rect2(caixa.position,
			Vector2(caixa.size.x, UiEstilo.altura_da_linha(_fonte)))
		_afirmar("opcoes[SOM][%s]: linha cabe no creme" % OPCOES_SOM[i],
			creme.encloses(tinta_som))
		_afirmar("opcoes[SOM][%s]: rotulo cabe na coluna" % OPCOES_SOM[i],
			UiEstilo.largura(_fonte, OPCOES_SOM[i]) <= caixa.size.x)

	# A folha inteira dentro da tela, e a linha de teclas fora do papel.
	_afirmar("opcoes: papel dentro da tela",
		Rect2(Vector2.ZERO, UiEstilo.TELA).encloses(OpcoesLayout.PAPEL))
	_afirmar("opcoes: linha de teclas nao invade o papel",
		not OpcoesLayout.dica().intersects(OpcoesLayout.PAPEL))
	_afirmar("opcoes: linha de teclas dentro da area segura",
		Rect2(Vector2.ZERO, UiEstilo.TELA).grow(-UiEstilo.MARGEM + 1.0)
			.encloses(OpcoesLayout.dica()))


## A travessia do tubo: `TravessiaCurva`.
##
## Ela era a única parte desta frente sem teste nenhum, e o defeito que ela pode
## ter é mudo: curva que não volta a zero deixa a tela com o vidro empenado para
## sempre, e lente que não chega ao fim deixa a câmera parada no meio do caminho.
## Nenhum dos dois dá erro, nenhum aparece em captura de um quadro só, e os dois
## são aritmética — então dão para provar aqui, em milissegundos.
func _checar_travessia() -> void:
	var c := TravessiaCurva

	# 1. As duas pontas. Um `plunge` que terminasse em 0,2 empenaria o jogo
	#    inteiro, e ninguem saberia por que.
	_afirmar("travessia: o vidro nasce plano", is_zero_approx(c.plunge(0.0)))
	_afirmar("travessia: o vidro termina plano", is_zero_approx(c.plunge(1.0)))
	_afirmar("travessia: a estatica nasce em zero", is_zero_approx(c.burst(0.0)))
	_afirmar("travessia: a estatica termina em zero", is_zero_approx(c.burst(1.0)))

	# 2. O pico mora DENTRO da janela da travessia e vale 1.
	var pico := c.plunge(c.TRAVESSIA * 0.5)
	_afirmar("travessia: o pico do vidro e 1,0 no meio da janela",
		is_equal_approx(pico, 1.0))
	_afirmar("travessia: o vidro ja acabou quando a janela acaba",
		is_zero_approx(c.plunge(c.TRAVESSIA)))

	# 3. Varredura: nada sai de [0,1] e o veu nunca desce.
	var veu_antes := -1.0
	var recuo_antes := INF
	var fov_antes := INF
	for i in 201:
		var t := float(i) / 200.0
		var p := c.plunge(t)
		var b := c.burst(t)
		var v := c.veu(t)
		var recuo := c.lente(&"recuo", t)
		var fov := c.lente(&"fov", t)
		if p < -0.001 or p > 1.001 or b < -0.001 or b > 0.901 or v < -0.001 or v > 1.001:
			_afirmar("travessia[t=%.2f]: curvas dentro de [0,1]" % t, false)
		if v < veu_antes - 0.0001:
			_afirmar("travessia[t=%.2f]: o veu nao volta atras" % t, false)
		if recuo > recuo_antes + 0.0001 or fov > fov_antes + 0.0001:
			_afirmar("travessia[t=%.2f]: a lente anda para um lado so" % t, false)
		veu_antes = v
		recuo_antes = recuo
		fov_antes = fov
	_afirmar("travessia: varredura de 201 pontos sem degrau", true)

	# 4. O veu so comeca depois de `VEU_COMECA`, e as duas metades se SOBREPOEM.
	#    Emenda seca entre os dois movimentos le como dois cortes.
	_afirmar("travessia: o veu fica cheio ate VEU_COMECA",
		is_zero_approx(c.veu(c.VEU_COMECA)))
	_afirmar("travessia: o veu chega inteiro no fim", is_equal_approx(c.veu(1.0), 1.0))
	_afirmar("travessia: o veu comeca com o vidro ainda empenado",
		c.plunge(c.VEU_COMECA) > 0.1)

	# 5. A lente: comeca no plano largo, termina no plano do carro, e nao para
	#    dentro dele. O recuo e medido do CENTRO, e foi por isso que a primeira
	#    tentativa (3,4 m) cortou a lataria na borda do quadro.
	_afirmar("lente: comeca no plano largo",
		is_equal_approx(c.lente(&"recuo", 0.0), float(c.LARGO[&"recuo"])))
	_afirmar("lente: termina no plano do carro",
		is_equal_approx(c.lente(&"recuo", 1.0), float(c.PERTO[&"recuo"])))
	var folga: float = float(c.PERTO[&"recuo"]) - c.MEIO_CARRO
	_afirmar("lente: sobra %.2f m de asfalto entre a lente e a traseira" % folga,
		folga >= 1.0)
	_afirmar("lente: o carro cresce %.2fx no quadro" % c.ganho_aparente(),
		c.ganho_aparente() >= 1.5)

	# 6. Fora do intervalo, tudo fica preso na ponta. Quem chama e um tween, e
	#    tween passa de 1,0 por arredondamento com mais frequencia do que parece.
	_afirmar("travessia: t negativo fica na ponta", is_zero_approx(c.plunge(-0.5)))
	_afirmar("travessia: t acima de 1 fica na ponta", is_equal_approx(c.veu(2.0), 1.0))
	_afirmar("lente: t acima de 1 fica no plano do carro",
		is_equal_approx(c.lente(&"fov", 5.0), float(c.PERTO[&"fov"])))
	print("-- travessia: %.1f s, pico do vidro em %.2f s, carro %.2fx maior"
		% [c.DURACAO, c.DURACAO * c.TRAVESSIA * 0.5, c.ganho_aparente()])


## O empilhamento da tela de titulo.
##
## A pendencia que o PLANO_UI_AAA deixou aberta na Fase 7 estava escrita com
## todas as letras: *"checar_hud.gd cobre o CartaoLayout e nao o menu de titulo.
## A lista passou de 7 para 11 linhas e a ultima transbordou o papel em 3 px — a
## captura pegou, o teste nao pegaria."* Isto e o teste que pegaria.
##
## Mede as CONSTANTES do menu e a fonte de verdade, sem instanciar a tela: o
## menu monta `SubViewport` com estrada, mata e serra, e um teste de layout que
## precisasse disso nao rodaria em nivel 2.
func _checar_menu_titulo() -> void:
	var fonte_m := load(FONTE_M) as Font
	_afirmar("fonte media carrega", fonte_m != null)
	if fonte_m == null:
		return
	var largura := TituloLayout.largura_da_placa(fonte_m)
	print("-- menu: placa de %.0f px para %d itens" % [largura, TituloLayout.ITENS.size()])

	var tela := Rect2(Vector2.ZERO, UiEstilo.TELA)
	var titulo := Rect2(TituloLayout.TITULO_ONDE_MENU, TituloLayout.TITULO_CAIXA)
	_afirmar("titulo dentro da tela", tela.encloses(titulo))

	var dica := TituloLayout.dica()
	var anterior := Rect2()
	for i in TituloLayout.ITENS.size():
		var placa := TituloLayout.placa(i, largura)
		var rot := "menu[%s]" % TituloLayout.ITENS[i]
		_afirmar("%s: placa dentro da area segura" % rot,
			tela.grow(-UiEstilo.MARGEM + 1.0).encloses(placa))
		_afirmar("%s: texto cabe na placa" % rot,
			UiEstilo.largura(fonte_m, TituloLayout.ITENS[i]) <= largura - 2.0)
		_afirmar("%s: nao encosta no titulo" % rot, not placa.intersects(titulo))
		_afirmar("%s: nao encosta na linha de teclas" % rot, not placa.intersects(dica))
		if i > 0:
			_afirmar("%s: nao encosta no item de cima" % rot,
				not placa.intersects(anterior))
		anterior = placa

	# O subtitulo mora entre o titulo e o primeiro item, e os tres se mexem
	# juntos: a caixa dele sai da posicao do titulo mais `SUBTITULO_DESCE`.
	var sub := TituloLayout.subtitulo()
	_afirmar("subtitulo: cabe entre o titulo e o primeiro item",
		sub.end.y <= TituloLayout.TOPO_LISTA - 2.0)
	_afirmar("subtitulo: texto cabe na caixa",
		UiEstilo.largura(_fonte, TituloLayout.SUBTITULO_TEXTO) <= sub.size.x)

	# A nota que explica o item escolhido. Ela entrou junto com CARREGAR e e o
	# motivo de o passo da lista ter deixado de ser fixo: com seis itens de 24 px
	# a partir de 96, o ultimo terminava em 234 e a nota nao tinha onde caber.
	var nota := TituloLayout.nota()
	var ultima := TituloLayout.placa(TituloLayout.ITENS.size() - 1, largura)
	_afirmar("nota: nao encosta no ultimo item", not nota.intersects(ultima))
	_afirmar("nota: nao encosta na linha de teclas", not nota.intersects(dica))
	_afirmar("nota: dentro da area segura",
		tela.grow(-UiEstilo.MARGEM + 1.0).encloses(nota))
	for texto: String in ["nao ha jogo gravado", "espaco livre", "volta para o menu"]:
		_afirmar("nota: '%s' cabe na caixa" % texto,
			UiEstilo.largura(_fonte, texto) <= nota.size.x)

	# A pagina dos tres espacos de save usa a MESMA pilha, com quatro itens.
	var largura_esp := TituloLayout.largura_da_placa(fonte_m, TituloLayout.ESPACOS)
	var n_esp := TituloLayout.ESPACOS.size()
	var anterior_esp := Rect2()
	for i in n_esp:
		var placa_esp := TituloLayout.placa(i, largura_esp, n_esp)
		var rot := "carregar[%s]" % TituloLayout.ESPACOS[i]
		_afirmar("%s: dentro da area segura" % rot,
			tela.grow(-UiEstilo.MARGEM + 1.0).encloses(placa_esp))
		_afirmar("%s: texto cabe na placa" % rot,
			UiEstilo.largura(fonte_m, TituloLayout.ESPACOS[i]) <= largura_esp - 2.0)
		_afirmar("%s: nao encosta no titulo" % rot, not placa_esp.intersects(titulo))
		_afirmar("%s: nao encosta na nota" % rot, not placa_esp.intersects(nota))
		if i > 0:
			_afirmar("%s: nao encosta no item de cima" % rot,
				not placa_esp.intersects(anterior_esp))
		anterior_esp = placa_esp

	# O passo se aperta para caber, mas nao abaixo do minimo: dai em diante a
	# lista precisa de outra solucao, e nao de mais aperto.
	for n: int in [4, 6, 8, 11]:
		var p := TituloLayout.passo(n)
		var fim := TituloLayout.TOPO_LISTA + float(n - 1) * p + TituloLayout.ITEM_ALTURA
		_afirmar("lista de %d: passo %.1f >= minimo" % [n, p], p >= TituloLayout.PASSO_MIN)
		if p > TituloLayout.PASSO_MIN + 0.01:
			_afirmar("lista de %d: acaba antes da nota (%.1f)" % [n, fim],
				fim <= TituloLayout.fundo_da_lista() + 0.5)
	print("-- menu: passo de %.1f com %d itens, %.1f com %d espacos"
		% [TituloLayout.passo(TituloLayout.ITENS.size()), TituloLayout.ITENS.size(),
			TituloLayout.passo(n_esp), n_esp])


## A coluna de campos da carteira de criacao cabe na pagina.
##
## A regra que faltava, e o defeito que ela teria pego no dia: a aba AGASALHO tem
## tres campos e a coluna so tinha espaco para dois. O rotulo MODELO era impresso
## dez pixels dentro do botao SEM e a fileira de cores caia sobre a zona de
## leitura do rodape. Nenhuma das duas colisoes aparece nas outras seis abas, que
## e exatamente por que olhar a tela nao encontrava — a aba certa tinha de estar
## aberta na hora certa.
func _checar_carteira() -> void:
	var sobra_pior := INF
	var pior := ""
	for i in CarteiraLayout.ABAS.size():
		var nome := String(CarteiraLayout.ABAS[i]["nome"])
		var alto := CarteiraLayout.altura_dos_campos(i)
		var fim := CarteiraLayout.LINHA_UM + alto
		var sobra := CarteiraLayout.CAMPOS_FUNDO - fim
		if sobra < sobra_pior:
			sobra_pior = sobra
			pior = nome
		_afirmar("carteira[%s]: %d campos cabem antes da zona de leitura (sobra %.0f px)"
			% [nome, CarteiraLayout.ABAS[i]["campos"].size(), sobra], sobra >= 0.0)
	print("-- carteira: pior aba e %s, com %.0f px de sobra" % [pior, sobra_pior])

	# A pagina inteira tem de caber na tela, senao a carteira sai pela borda.
	var doc := CarteiraLayout.DOC
	_afirmar("carteira: documento dentro da tela",
		Rect2(Vector2.ZERO, UiEstilo.TELA).encloses(doc))
	_afirmar("carteira: zona de leitura abaixo do ultimo campo",
		CarteiraLayout.CAMPOS_FUNDO < doc.end.y - 5.0)


## A metrica da fonte e contrato, e nao detalhe de importacao. Se ela mudar, todo
## o empilhamento muda junto — e e melhor este numero avisar do que a tela.
func _metrica() -> void:
	var nativo := UiEstilo.tamanho_nativo(_fonte)
	var linha := UiEstilo.altura_da_linha(_fonte)
	print("-- metrica: tamanho nativo %d, altura de linha %.1f" % [nativo, linha])
	_afirmar("psx_pequena e nativa em 11 (UI-BIBLE 2)", nativo == 11)
	_afirmar("altura de linha e 13 (UI-BIBLE 2)", is_equal_approx(linha, 13.0))
	# Por que o tamanho continua obrigatorio, com a regra NOVA da importacao.
	#
	# Esta assercao dizia "a fonte realmente escala" e media `get_height(16) >
	# 13`. Era verdade quando as quatro `.fnt` estavam em escala livre: pedir 16
	# numa bitmap de 11 esticava o glifo 1,4545x e era isso que deixava o HUD
	# mole. As importacoes passaram a escala INTEIRA, entao 16 devolve 1x e a
	# assercao virou falsa — o motor parou de esticar.
	#
	# O que NAO mudou e a obrigacao de prender o tamanho, so mudou o modo de
	# falhar: em escala inteira o erro nao e um glifo borrado, e um SALTO. Pedir
	# 18 nesta fonte devolve 2x, ou seja 26 px de linha onde o layout conta com
	# 13. As duas medidas abaixo travam exatamente isso.
	_afirmar("escala inteira: pedir 16 devolve 1x", is_equal_approx(_fonte.get_height(16), linha))
	var dobrada := _fonte.get_height(18)
	_afirmar("escala inteira: pedir 18 DOBRA (por isso o tamanho e obrigatorio)",
		dobrada >= linha * 2.0 - 0.5)
	print("-- pedir 18 daria linha de %.1f px" % dobrada)


func _checar(caso: Dictionary, com_dica: bool) -> void:
	var rotulo := "%s%s" % [caso["nome"], "" if com_dica else " (tira)"]
	var plano := CartaoLayout.montar(_fonte, caso, com_dica)
	var papel: Rect2 = plano["papel"]
	var caixas: Array = plano["caixas"]

	_afirmar("%s: ha conteudo" % rotulo, caixas.size() > 0)

	# 1. Nenhum retangulo cruza outro. E a regra que o cartao quebrava.
	for i in caixas.size():
		for j in range(i + 1, caixas.size()):
			var a: Rect2 = caixas[i]["rect"]
			var b: Rect2 = caixas[j]["rect"]
			_afirmar("%s: %s nao cruza %s" % [rotulo, caixas[i]["nome"],
				caixas[j]["nome"]], not a.intersects(b))

	for caixa: Dictionary in caixas:
		var r: Rect2 = caixa["rect"]
		var nome := String(caixa["nome"])

		# 2. Tudo dentro do papel. Texto fora do papel fica boiando na rua.
		_afirmar("%s: %s cabe no papel" % [rotulo, nome], papel.encloses(r))

		# 3. Nenhuma caixa de altura ou largura zero. Um retangulo degenerado
		#    passa em qualquer teste de colisao e ainda assim e um buraco.
		_afirmar("%s: %s tem area" % [rotulo, nome],
			r.size.x > 0.0 and r.size.y > 0.0)

		# 4. Nenhuma linha transborda, medida na fonte real no tamanho real.
		var linhas: PackedStringArray = caixa["linhas"]
		for linha_txt: String in linhas:
			var w := UiEstilo.largura(_fonte, linha_txt)
			_afirmar("%s: %s cabe na largura (%.0f <= %.0f) \"%s\""
				% [rotulo, nome, w, r.size.x, linha_txt], w <= r.size.x + 0.5)
		var alto := float(linhas.size()) * UiEstilo.altura_da_linha(_fonte)
		_afirmar("%s: %s cabe na altura (%.0f <= %.0f)"
			% [rotulo, nome, alto, r.size.y], alto <= r.size.y + 0.5)

	# 5. O papel inteiro, ja na posicao da tela, dentro da area segura.
	var na_tela := Rect2(Vector2(UiEstilo.MARGEM, UiEstilo.MARGEM), papel.size)
	var segura := Rect2(Vector2.ZERO, UiEstilo.TELA).grow(-UiEstilo.MARGEM + 1.0)
	_afirmar("%s: papel de %.0fx%.0f dentro da area segura"
		% [rotulo, papel.size.x, papel.size.y], segura.encloses(na_tela))

	# 6. A tira nunca e mais alta que o cartao aberto. Se fosse, o papel
	#    "encolheria" crescendo, que e pior que nao encolher.
	if not com_dica:
		var aberto: Rect2 = CartaoLayout.montar(_fonte, caso, true)["papel"]
		_afirmar("%s: tira (%.0f) nao passa do aberto (%.0f)"
			% [rotulo, papel.size.y, aberto.size.y],
			papel.size.y <= aberto.size.y + 0.5)


func _afirmar(msg: String, cond: bool) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _terminar() -> void:
	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)


## --- faixa de estado da cidade ----------------------------------------------

## Cada caso quebra uma regra diferente da faixa, como os do cartao.
const FAIXAS: Array[Dictionary] = [
	{"nome": "so hora", "lugar": "", "hora": "22:43",
		"com_vida": false, "com_lanterna": false},
	{"nome": "jogo a pe", "lugar": "CENTRO", "hora": "23:15",
		"com_vida": false, "com_lanterna": true},
	{"nome": "ferido", "lugar": "VILA OPERARIA", "hora": "01:07", "vida": 0.31,
		"com_vida": true, "com_lanterna": true},
	{"nome": "nome comprido", "vida": 0.05,
		"lugar": "PRACA DA MATRIZ DE SANTO ANTONIO DO MONTE",
		"hora": "04:59", "com_vida": true, "com_lanterna": true},
	{"nome": "hora sem lugar", "lugar": "", "hora": "00:00", "vida": 1.0,
		"com_vida": true, "com_lanterna": true},
]


## O relogio e conta pura; se ele errar, a faixa mostra o numero errado com o
## layout certo, que e o defeito mais dificil de ver numa captura.
func _relogio() -> void:
	var r := Relogio.new()
	_afirmar("relogio comeca 22:43", r.texto() == "22:43")
	_afirmar("22:43 e noite", r.e_noite())
	# 377 minutos de jogo ate as 05:00, a RITMO 2,0, sao 188 minutos reais.
	_afirmar("faltam 377 min de jogo para a aurora", r.ate_a_aurora() == 377)
	r.avancar(30.0)
	_afirmar("30 s reais viram 1 minuto de jogo (22:44)", r.texto() == "22:44")
	r.definir_minutos(23 * 60 + 59)
	r.avancar(30.0)
	_afirmar("vira o dia sem estourar (00:00)", r.texto() == "00:00")
	_afirmar("00:00 ainda e noite", r.e_noite())
	_afirmar("texto invalido nao mexe no relogio",
		not r.definir_texto("banana") and r.texto() == "00:00")
	_afirmar("texto valido mexe",
		r.definir_texto("14:05") and r.texto() == "14:05")
	_afirmar("14:05 nao e noite", not r.e_noite())
	r.definir_minutos(22 * 60 + 43)
	r.definir_minutos(r.minutos() + 4 * 60)
	_afirmar("4 horas depois de 22:43 e 02:43", r.texto() == "02:43")


## O apagao e contrato de UI: a camada e a unica autorizada a cobrir a tela
## inteira. As constantes de vida e de horas moram em `desmaio.gd` e
## `checar_ameaca.gd` as le no fonte — este arquivo nao carrega `Desmaio`
## porque ele fala com autoload, e em `--script` autoload nao e identificador.
func _apagao_contrato() -> void:
	_afirmar("apagao na camada 200 (UI-BIBLE 3)",
		UiEstilo.CAMADA_APAGAO == 200)
	_afirmar("apagao acima da excecao do pos",
		UiEstilo.CAMADA_APAGAO > UiEstilo.CAMADA_ACIMA_DO_POS)


func _checar_faixa(caso: Dictionary) -> void:
	var rotulo := "faixa[%s]" % caso["nome"]
	var montado := FaixaLayout.montar(_fonte, caso)
	var papel: Rect2 = montado["papel"]
	var caixas: Array = montado["caixas"]

	# 1. O papel cabe na area segura e nao passa da largura medida.
	var segura := Rect2(Vector2.ZERO, UiEstilo.TELA).grow(-UiEstilo.MARGEM + 1.0)
	_afirmar("%s: papel %.0fx%.0f na area segura" % [rotulo, papel.size.x, papel.size.y],
		segura.encloses(papel))
	_afirmar("%s: papel nao passa de LARGURA_MAX (%.0f <= %.0f)"
		% [rotulo, papel.size.x, FaixaLayout.LARGURA_MAX],
		papel.size.x <= FaixaLayout.LARGURA_MAX + 0.5)
	_afirmar("%s: papel centrado (|%.1f| <= 1)"
		% [rotulo, papel.get_center().x - UiEstilo.TELA.x * 0.5],
		absf(papel.get_center().x - UiEstilo.TELA.x * 0.5) <= 1.0)

	# 2. Nenhuma caixa encosta na outra, e todas ficam dentro do papel.
	for i in caixas.size():
		var a: Dictionary = caixas[i]
		var ra: Rect2 = a["rect"]
		_afirmar("%s: %s dentro do papel" % [rotulo, a["nome"]],
			papel.grow(-0.5).encloses(ra))
		# Caixa de area zero e o lugar sem nome: nada desenha, nada colide.
		if ra.size.x <= 0.0 or ra.size.y <= 0.0:
			continue
		for j in range(i + 1, caixas.size()):
			var b: Dictionary = caixas[j]
			var rb: Rect2 = b["rect"]
			if rb.size.x <= 0.0 or rb.size.y <= 0.0:
				continue
			# `intersects` sem bordas: encostar lado a lado e o empilhamento
			# funcionando, sobrepor e o defeito.
			_afirmar("%s: %s nao invade %s" % [rotulo, a["nome"], b["nome"]],
				not ra.intersects(rb))

	# 3. Texto cabe na propria caixa, medido na fonte real.
	for c: Dictionary in caixas:
		var texto := String(c["texto"])
		if texto.is_empty():
			continue
		var r: Rect2 = c["rect"]
		var w := UiEstilo.largura(_fonte, texto)
		_afirmar("%s: %s cabe (%.0f <= %.0f) \"%s\""
			% [rotulo, c["nome"], w, r.size.x, texto], w <= r.size.x + 0.5)

	# 4. A regra que decidiu a camada: na 100 o pos-processamento come o canto.
	#    Nenhum canto de caixa pode cair abaixo do piso medido. Esta assercao e
	#    o motivo de a faixa nao morar no canto da tela; se alguem a mover para
	#    la, ela reprova aqui e nao seis meses depois numa captura.
	for c: Dictionary in caixas:
		var r: Rect2 = c["rect"]
		var f := UiEstilo.vinheta_do_rect(r)
		_afirmar("%s: %s sobrevive a vinheta (%.2f >= %.2f)"
			% [rotulo, c["nome"], f, UiEstilo.VINHETA_MIN],
			f >= UiEstilo.VINHETA_MIN)

	# 5. Nao colide com o cartao de missao (canto superior esquerdo) nem com o
	#    minimapa (canto superior direito). As tres pecas dividem a mesma tela.
	var cartao := Rect2(Vector2(UiEstilo.MARGEM, UiEstilo.MARGEM),
		Vector2(CartaoLayout.LARGURA, 120.0))
	var mini := Rect2(Vector2(UiEstilo.TELA.x - 82.0 - UiEstilo.MARGEM, UiEstilo.MARGEM),
		Vector2(82.0, 96.0))
	_afirmar("%s: nao encosta no cartao de missao" % rotulo, not papel.intersects(cartao))
	_afirmar("%s: nao encosta no minimapa" % rotulo, not papel.intersects(mini))


## O prompt de acao. A colisao que ele tinha com a faixa era invisivel porque os
## dois numeros moravam em arquivos diferentes; aqui eles se encontram.
func _checar_prompt() -> void:
	var vazio := FaixaLayout.prompt(_fonte, "")
	_afirmar("prompt vazio nao ocupa tela",
		(vazio["papel"] as Rect2).size == Vector2.ZERO)

	var textos: PackedStringArray = [
		"[E]  falar",
		"[E]  abrir o portao",
		"[E]  bater na porta da casa da fumaca antes que ela apague",
	]
	for t: String in textos:
		var m := FaixaLayout.prompt(_fonte, t)
		var papel: Rect2 = m["papel"]
		var caixa: Rect2 = m["texto"]
		var rot := "prompt[%s]" % t.substr(0, 18)

		var segura := Rect2(Vector2.ZERO, UiEstilo.TELA).grow(-UiEstilo.MARGEM + 1.0)
		_afirmar("%s: dentro da area segura" % rot, segura.encloses(papel))
		_afirmar("%s: texto dentro do papel" % rot, papel.grow(-0.5).encloses(caixa))
		_afirmar("%s: nao passa de LARGURA_MAX" % rot,
			papel.size.x <= FaixaLayout.LARGURA_MAX + 0.5)
		_afirmar("%s: centrado" % rot,
			absf(papel.get_center().x - UiEstilo.TELA.x * 0.5) <= 1.0)
		_afirmar("%s: sobrevive a vinheta (%.2f)" % [rot, UiEstilo.vinheta_do_rect(caixa)],
			UiEstilo.vinheta_do_rect(caixa) >= UiEstilo.VINHETA_MIN)
		_afirmar("%s: texto cabe na caixa" % rot,
			UiEstilo.largura(_fonte, String(m["cortado"])) <= caixa.size.x + 0.5)

		# A razao de existir deste bloco: prompt e faixa miravam o mesmo rodape.
		for caso: Dictionary in FAIXAS:
			var faixa: Rect2 = FaixaLayout.montar(_fonte, caso)["papel"]
			_afirmar("%s: nao encosta na faixa[%s]" % [rot, caso["nome"]],
				not papel.intersects(faixa))
