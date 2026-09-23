## O que o servidor confere em todo pedido de mudanca de mundo (plano 04 secao 6).
##
## Funcao pura: quem chama diz o que sabe do remetente (`quem`) e se a coisa ja
## foi pega, e recebe um motivo. O primeiro que falhar e a resposta; a ordem e a
## da tabela do plano, e ela importa para o jogador: quem esta longe de um item
## ja pego ouve "Longe demais.", que e verdade, e nao "Alguem pegou antes.", que
## entregaria o que ele nao ve.
##
## `quem`: {"pronto": bool, "cota": bool (o Balde deixou; ausente = deixou),
## "espaco": int (-1 = nao se sabe), "pos": Vector3 (Vector3.INF = nao se sabe)}.
## `pos` e o ultimo estado ACEITO pelo ValidadorMovimento, nunca o declarado.
## A cota entra por `quem` porque e a conferencia 2: quem a confere no fim deixa
## pedido invalido ou de longe sem gastar ficha, e responde a todos eles.
class_name ValidadorDeMundo
extends RefCounted

## Viaja no `_negado` como u8: motivo novo entra no fim, nunca no meio.
enum Motivo { OK, NAO_PRONTO, COTA, INVALIDO, ESPACO, LONGE, JA_FOI, OCUPADO, CHEIO }
enum Faixa { RUA, INTERIOR, OUTRA }

## Descartados sem resposta. Responder a quem ainda nao recebeu o mundo, ou a
## quem manda pedido em rajada, e dar a ele um canal de eco de graca.
const SILENCIOSOS: Array[int] = [Motivo.NAO_PRONTO, Motivo.COTA]

## Balde furado: 10 pedidos por segundo, rajada de 10.
const COTA_POR_S := 10.0
const RAJADA := 10.0

const VALOR_MAX_BYTES := 256
const CHAVE_MAX := 64
## Igual a `ChunkManager.TAM`.
const CHUNK := 32.0

## Faixas de coord do WorldState (plano 04 secao 3.1).
const INTERIOR := 424242
const PESSOA := 424243
const FOLHA := 424244

## Chaves que um cliente pode escrever na Fase 3, uma a uma. Regra geral ("tudo
## que nao e faixa de pessoa") difundiria o que outra frente gravar amanha: o
## Dinheiro e o IWeed moram em (-8, 424243) e (-9, 424243) e sao POR JOGADOR, nao
## mundo. Coisa nova entra aqui quando alguem decide que ela e do mundo.
const PREFIXOS: PackedStringArray = ["item_", "porta_"]
## Item e classe 1 (plano 04 secao 4.1): so muda por `_pedir_item`, que so grava
## true e credita a mochila. Aceitar "item_3" = false no `_pedir_mundo` poria de
## volta no chao um item ja pego, e o mesmo item seria pego de novo: duplicado.
const PREFIXO_SO_POR_PEDIDO := "item_"
## O tipo do valor de cada prefixo. `valor_aceito` e o filtro geral do plano 04
## secao 5.1; este e o da coisa: um texto numa chave de porta passaria nele, iria
## a todo cliente e ao save do anfitriao, e quebraria quem le a porta como bool.
const TIPO_POR_PREFIXO: Dictionary = {"item_": TYPE_BOOL, "porta_": TYPE_BOOL}

const INDICE_MAX := 4095
const QTD_MAX := 99

## O que o jogador le. OK, NAO_PRONTO e COTA nao tem texto: nunca sao respondidos.
const TEXTO: Dictionary = {
	Motivo.ESPACO: "Longe demais.",
	Motivo.LONGE: "Longe demais.",
	Motivo.JA_FOI: "Alguem pegou antes.",
	Motivo.OCUPADO: "Ocupado.",
	Motivo.CHEIO: "Mochila cheia.",
	Motivo.INVALIDO: "Nao deu.",
}


## Texto para o jogador. Motivo que este cliente nao conhece (servidor mais novo)
## le como INVALIDO: o jogador precisa saber que nao deu, mesmo sem saber por que.
static func texto(motivo: int) -> String:
	if motivo == Motivo.OK:
		return ""
	return String(TEXTO.get(motivo, TEXTO[Motivo.INVALIDO]))


static func valor_aceito(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL, TYPE_INT, TYPE_VECTOR2I:
			return true
		TYPE_FLOAT:
			return is_finite(float(v))
		TYPE_STRING, TYPE_STRING_NAME:
			var s := String(v)
			# Todo caractere tem ao menos 1 byte em UTF-8: comprimento acima do teto
			# ja reprova sem codificar a string inteira.
			return s.length() <= VALOR_MAX_BYTES and s.to_utf8_buffer().size() <= VALOR_MAX_BYTES
		TYPE_VECTOR3:
			var p: Vector3 = v
			return is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
		TYPE_PACKED_INT32_ARRAY:
			return (v as PackedInt32Array).size() * 4 <= VALOR_MAX_BYTES
	return false


## 1..CHAVE_MAX caracteres em [a-z0-9_-], comecando por um dos PREFIXOS e com
## alguma coisa depois dele.
static func chave_aceita(chave: StringName) -> bool:
	var s := String(chave)
	if s.is_empty() or s.length() > CHAVE_MAX:
		return false
	var com_prefixo := false
	for p: String in PREFIXOS:
		if s.begins_with(p) and s.length() > p.length():
			com_prefixo = true
			break
	if not com_prefixo:
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 45
		if not ok:
			return false
	return true


## Coord de rua e pequena (|cz| abaixo de ~31 mil ate no XZ_MAX); as faixas
## reservadas moram de 424242 para cima.
static func faixa(coord: Vector2i) -> int:
	if coord.y == INTERIOR:
		return Faixa.INTERIOR
	if coord.y >= INTERIOR:
		return Faixa.OUTRA
	return Faixa.RUA


## Pedido generico de mundo (`_pedir_mundo`, classe 2: porta, luz, gaveta).
static func julgar(coord: Vector2i, chave: StringName, valor: Variant, quem: Dictionary) -> int:
	if not _verdade(quem, "pronto", false):
		return Motivo.NAO_PRONTO
	if not _verdade(quem, "cota", true):
		return Motivo.COTA
	if not chave_aceita(chave) or not valor_aceito(valor):
		return Motivo.INVALIDO
	var s := String(chave)
	if s.begins_with(PREFIXO_SO_POR_PEDIDO) or not _tipo_do_prefixo(s, valor):
		return Motivo.INVALIDO
	return _lugar(coord, quem)


## Pedido de item (`_pedir_item`, classe 1). `item_valido`: o item esta na tabela
## de coisas que nascem no chao. `cabe`: a mochila do remetente no servidor tem
## lugar; vem por ultimo, como na tabela.
static func julgar_item(coord: Vector2i, indice: int, item_valido: bool, qtd: int,
		quem: Dictionary, ja_pego: bool, cabe: bool = true) -> int:
	if not _verdade(quem, "pronto", false):
		return Motivo.NAO_PRONTO
	if not _verdade(quem, "cota", true):
		return Motivo.COTA
	if indice < 0 or indice > INDICE_MAX or qtd < 1 or qtd > QTD_MAX or not item_valido:
		return Motivo.INVALIDO
	var r := _lugar(coord, quem)
	if r != Motivo.OK:
		return r
	if ja_pego:
		return Motivo.JA_FOI
	if not cabe:
		return Motivo.CHEIO
	return Motivo.OK


## Campo do `quem` que nao pode quebrar a funcao. `bool(null)` e `int(null)` sao
## erro de script, e funcao de GDScript que para no erro devolve o valor padrao
## do tipo: 0, que aqui e OK, pedido de qualquer lugar aceito sem conferencia
## nenhuma. Campo de tipo errado le como o pior caso para quem pediu.
static func _verdade(quem: Dictionary, campo: String, padrao: bool) -> bool:
	var v: Variant = quem.get(campo, padrao)
	return typeof(v) == TYPE_BOOL and bool(v)


static func _espaco(quem: Dictionary) -> int:
	var v: Variant = quem.get("espaco", -1)
	return int(v) if typeof(v) == TYPE_INT else -1


## Prefixo fora da tabela de tipos fica so com o filtro geral.
static func _tipo_do_prefixo(chave: String, valor: Variant) -> bool:
	for p: String in TIPO_POR_PREFIXO:
		if chave.begins_with(p):
			return typeof(valor) == int(TIPO_POR_PREFIXO[p])
	return true


## Conferencias 3 e 4: mesmo espaco e alcance.
static func _lugar(coord: Vector2i, quem: Dictionary) -> int:
	var espaco := _espaco(quem)
	match faixa(coord):
		Faixa.RUA:
			if espaco != ProtocoloRede.ESPACO_RUA:
				return Motivo.ESPACO
			var pos: Variant = quem.get("pos", Vector3.INF)
			if typeof(pos) != TYPE_VECTOR3:
				return Motivo.LONGE
			var p: Vector3 = pos
			if not (is_finite(p.x) and is_finite(p.z)):
				return Motivo.LONGE
			# Em float: posicao absurda nao estoura o int, so fica longe.
			if absf(floorf(p.x / CHUNK) - float(coord.x)) > 1.0 \
					or absf(floorf(p.z / CHUNK) - float(coord.y)) > 1.0:
				return Motivo.LONGE
			return Motivo.OK
		Faixa.INTERIOR:
			# Limite honesto da Fase 3 (plano 04 secao 6): o servidor nao monta
			# interior, entao nao sabe onde a coisa esta, e nem QUAL interior e o do
			# remetente: o espaco e um hash de (tipo, semente) e a coord so traz a
			# semente. Confere so que ele esta em algum interior. Fecha na Fase 8.
			if espaco < ProtocoloRede.ESPACO_INTERIOR_BASE:
				return Motivo.ESPACO
			return Motivo.OK
	return Motivo.INVALIDO


## Cota de pedidos por jogador. Comeca cheio: quem acabou de entrar pode abrir
## tres portas seguidas sem ser calado.
class Balde:
	extends RefCounted

	var fichas := RAJADA
	var _t := -INF

	func gastar(agora: float) -> bool:
		if is_finite(agora):
			if _t == -INF:
				_t = agora
			elif agora > _t:
				fichas = minf(RAJADA, fichas + (agora - _t) * COTA_POR_S)
				_t = agora
		if fichas >= 1.0:
			fichas -= 1.0
			return true
		return false
