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
	for caso: Dictionary in FAIXAS:
		_checar_faixa(caso)
	_checar_prompt()
	_terminar()


## A metrica da fonte e contrato, e nao detalhe de importacao. Se ela mudar, todo
## o empilhamento muda junto — e e melhor este numero avisar do que a tela.
func _metrica() -> void:
	var nativo := UiEstilo.tamanho_nativo(_fonte)
	var linha := UiEstilo.altura_da_linha(_fonte)
	print("-- metrica: tamanho nativo %d, altura de linha %.1f" % [nativo, linha])
	_afirmar("psx_pequena e nativa em 11 (UI-BIBLE 2)", nativo == 11)
	_afirmar("altura de linha e 13 (UI-BIBLE 2)", is_equal_approx(linha, 13.0))
	# A armadilha que derrubou o cartao: pedir 16 num bitmap de 11 nao e ignorado,
	# e ESTICADO. Se um dia a fonte passar a recusar escala, esta assercao cai e
	# o motivo de `UiEstilo.aplicar` existir some junto — e bom saber na hora.
	var esticada := _fonte.get_height(16)
	_afirmar("a fonte realmente escala (por isso o tamanho e obrigatorio)",
		esticada > linha + 1.0)
	print("-- pedir 16 daria linha de %.1f px" % esticada)


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
