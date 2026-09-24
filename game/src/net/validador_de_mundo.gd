## O que o servidor confere em todo pedido de mudanca de mundo (plano 04 secao 6).
##
## Funcao pura: quem chama diz o que sabe do remetente (`quem`) e se a coisa ja
## foi pega, e recebe um motivo. O primeiro que falhar e a resposta; a ordem e a
## da tabela do plano, e ela importa para o jogador: quem esta longe de um item
## ja pego ouve "Longe demais.", que e verdade, e nao "Alguem pegou antes.", que
## entregaria o que ele nao ve.
##
## `quem`: {"pronto": bool, "cota": bool (o Balde deixou; ausente = deixou),
## "espaco": int (-1 = nao se sabe), "pos": Vector3 (Vector3.INF = nao se sabe),
## "casas_perto": Array de sementes das casas que existem na rua a um chunk dele
## (ausente = nenhuma)}.
## De quem e cada chave, e onde o remetente tem de estar, e `PoliticaDeMundo`.
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

## As chaves de RUA que um cliente pode escrever (`chave_aceita`). O julgamento
## de verdade pergunta a `PoliticaDeMundo`, que conhece todas as familias.
const PREFIXOS: PackedStringArray = ["item_", "porta_"]
## Item e classe 1 (plano 04 secao 4.1): so muda por `_pedir_item`, que so grava
## true e credita a mochila. Aceitar "item_3" = false no `_pedir_mundo` poria de
## volta no chao um item ja pego, e o mesmo item seria pego de novo: duplicado.
const PREFIXO_SO_POR_PEDIDO := "item_"
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


## Pedido generico de mundo (`_pedir_mundo`, classe 2: porta, profissao, folha).
static func julgar(coord: Vector2i, chave: StringName, valor: Variant, quem: Dictionary) -> int:
	if not _verdade(quem, "pronto", false):
		return Motivo.NAO_PRONTO
	if not _verdade(quem, "cota", true):
		return Motivo.COTA
	return _julgar_valor(coord, chave, valor, quem)


## Pedido por diferenca (`_pedir_fusao`: prateleira, plantio). `base` e o que o
## servidor tem agora. Devolve [motivo, valor novo]; o valor so vale com OK.
static func julgar_fusao(coord: Vector2i, chave: StringName, remendo: Variant, base: Variant,
		quem: Dictionary) -> Array:
	if not _verdade(quem, "pronto", false):
		return [Motivo.NAO_PRONTO, null]
	if not _verdade(quem, "cota", true):
		return [Motivo.COTA, null]
	if not chave_limpa(chave):
		return [Motivo.INVALIDO, null]
	var r := PoliticaDeMundo.regra(coord, chave)
	if int(r["dono"]) != PoliticaDeMundo.Dono.MUNDO or not bool(r["fundir"]):
		return [Motivo.INVALIDO, null]
	# O remendo e conferido ANTES de aplicado: aplicar lixo ja e trabalho gasto.
	if not FusaoDeMundo.valor_limpo(remendo) \
			or var_to_bytes(remendo).size() > PoliticaDeMundo.TETO_ESTRUTURA:
		return [Motivo.INVALIDO, null]
	var novo: Variant = FusaoDeMundo.aplicar(base, remendo)
	if novo == null:
		return [Motivo.INVALIDO, null]
	return [_julgar_valor(coord, chave, novo, quem), novo]


## Conferencias 3 a 5 (chave, valor e lugar), para a chave pela politica.
static func _julgar_valor(coord: Vector2i, chave: StringName, valor: Variant, quem: Dictionary) -> int:
	if not chave_limpa(chave):
		return Motivo.INVALIDO
	var r := PoliticaDeMundo.regra(coord, chave)
	if int(r["dono"]) != PoliticaDeMundo.Dono.MUNDO:
		return Motivo.INVALIDO
	if String(chave).begins_with(PREFIXO_SO_POR_PEDIDO):
		return Motivo.INVALIDO
	if not _tipo_certo(valor, int(r["tipo"])):
		return Motivo.INVALIDO
	return _lugar_da_regra(coord, quem, int(r["lugar"]))


## O tipo que a politica pede. Texto e StringName sao o mesmo (o save em JSON
## devolve String onde o jogo gravou StringName). Estrutura passa pelo filtro de
## dado de jogo e pelo teto em bytes.
static func _tipo_certo(valor: Variant, tipo: int) -> bool:
	var t := typeof(valor)
	match tipo:
		TYPE_STRING, TYPE_STRING_NAME:
			return (t == TYPE_STRING or t == TYPE_STRING_NAME) and valor_aceito(valor)
		TYPE_ARRAY, TYPE_DICTIONARY:
			return t == tipo and FusaoDeMundo.valor_limpo(valor) \
				and var_to_bytes(valor).size() <= PoliticaDeMundo.TETO_ESTRUTURA
	return t == tipo and valor_aceito(valor)


## Chave de 1..CHAVE_MAX caracteres em [a-z0-9_-]. Quem decide se ela existe e a
## politica.
static func chave_limpa(chave: StringName) -> bool:
	var s := String(chave)
	if s.is_empty() or s.length() > CHAVE_MAX:
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 45):
			return false
	return true


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
	var regra := PoliticaDeMundo.regra(coord, StringName("item_%d" % indice))
	if int(regra["dono"]) != PoliticaDeMundo.Dono.MUNDO:
		return Motivo.INVALIDO
	var r := _lugar_da_regra(coord, quem, int(regra["lugar"]))
	if r != Motivo.OK:
		return r
	if ja_pego:
		return Motivo.JA_FOI
	if not cabe:
		return Motivo.CHEIO
	return Motivo.OK


## A ordem de julgamento dos pedidos de um mesmo item dentro da janela da
## disputa: quem agiu antes (`instante`, a chegada menos meia ida e volta medida
## pelo servidor), e no empate quem chegou antes, e depois o menor id. O primeiro
## leva; os outros ouvem JA_FOI do proprio julgamento.
static func ordem_da_disputa(candidatos: Array) -> Array:
	var saida := candidatos.duplicate()
	saida.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["instante"]), float(b["instante"])):
			return float(a["instante"]) < float(b["instante"])
		if not is_equal_approx(float(a["chegada"]), float(b["chegada"])):
			return float(a["chegada"]) < float(b["chegada"])
		return int(a["id"]) < int(b["id"]))
	return saida


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


## Conferencias 4 e 5: mesmo espaco e alcance.
static func _lugar_da_regra(coord: Vector2i, quem: Dictionary, lugar: int) -> int:
	var espaco := _espaco(quem)
	match lugar:
		PoliticaDeMundo.Lugar.RUA:
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
		PoliticaDeMundo.Lugar.COMODO:
			# O comodo e o da semente em coord.x. Teleportado: o espaco do
			# remetente e o hash de (tipo, semente), e o servidor confere contra
			# cada tipo de interior, entao quem esta no bar nao mexe no mercado.
			# Casa que existe na rua: o remetente esta na RUA, e a casa tem de
			# estar a um chunk dele (o servidor acha as casas pelo mapa, que e puro).
			if espaco == ProtocoloRede.ESPACO_RUA:
				var casas: Variant = quem.get("casas_perto", [])
				if casas is Array and (casas as Array).has(coord.x):
					return Motivo.OK
				return Motivo.ESPACO
			if espaco < ProtocoloRede.ESPACO_INTERIOR_BASE:
				return Motivo.ESPACO
			for tipo: StringName in ProtocoloRede.TIPOS_DE_INTERIOR:
				if ProtocoloRede.espaco_interior(tipo, coord.x) == espaco:
					return Motivo.OK
			return Motivo.ESPACO
		PoliticaDeMundo.Lugar.LIVRE:
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
