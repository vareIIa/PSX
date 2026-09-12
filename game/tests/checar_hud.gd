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
