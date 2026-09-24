## De quem e cada escrita do WorldState em rede (plano 08 secao 1.4, plano 13
## item 3.4). Uma tabela so, em vez de trocar trinta `WorldState.definir` em dez
## arquivos de outras frentes: o `WorldState` pergunta aqui, e o jogo continua
## escrevendo do mesmo jeito sozinho e em rede.
##
## Tres donos:
## - MUNDO: vale para todos. Vai ao servidor, que julga e difunde. Porta, item,
##   o plantio da estufa, a prateleira da loja, quem trabalha onde.
## - PESSOA: de quem joga. Nunca sai da maquina, nao vem na carga do anfitriao, e
##   vai junto na saida: carteira, iWeed, entregas, a memoria das conversas
##   (cada um ouve o morador pela primeira vez), a missao do dono da casa.
## - LOCAL: recalculado igual em toda maquina (o personagem que a estufa marca,
##   o crescimento que o relogio explica). Mandar seria so trafego.
##
## Coisa nova que ninguem classificou cai em LOCAL — o jogo segue como sempre
## sozinho — e `MundoEmRede` avisa uma vez no console, para quem a escreveu vir
## aqui decidir.
class_name PoliticaDeMundo
extends RefCounted

enum Dono { MUNDO, PESSOA, LOCAL }
## Onde o remetente tem de estar para mexer.
enum Lugar {
	RUA,      ## na rua, a um chunk da coisa (porta, item da calcada)
	COMODO,   ## no comodo daquela semente: teleportado, ou a casa que existe na rua
	LIVRE,    ## sem posicao (folha de vagas, prateleira pelo numero da loja)
}

const INTERIOR := 424242
const PESSOA := 424243
const FOLHA := 424244
const LOJA := 424245

## Faixa de pessoa com id negativo: os cofres do jogador (Dinheiro -8, iWeed -9,
## EntregasDaSuper -7). A coord inteira e dele.
const COFRES: Array[Vector2i] = [Vector2i(-7, PESSOA), Vector2i(-8, PESSOA), Vector2i(-9, PESSOA)]

## O teto de um valor estruturado (dicionario, lista), em bytes de var_to_bytes.
## A loja com as 60 vagas mexidas fica em ~3 KB; o plantio de 12 vasos em ~1 KB.
const TETO_ESTRUTURA := 12288


## {"dono": Dono, "lugar": Lugar, "tipo": Variant.Type, "fundir": bool,
##  "conhecida": bool}. `conhecida` falso = ninguem classificou esta chave ainda.
## `fundir`: o cliente manda so a diferenca e o servidor aplica sobre o que tem,
## para dois jogadores mexendo na mesma prateleira nao apagarem um ao outro.
static func regra(coord: Vector2i, chave: StringName) -> Dictionary:
	var s := String(chave)
	if COFRES.has(coord):
		return _pessoa()
	match coord.y:
		PESSOA:
			if coord.x < 0:
				return _pessoa()
			# Memoria de conversa, a missao do dono e o livro-caixa do iWeed: de
			# quem joga. A profissao da pessoa e fato da cidade.
			if s.begins_with("npc_") or s.begins_with("dono_") or s.begins_with("iw_") \
					or s == "tarefas" or s == "colheitas":
				return _pessoa()
			if s == "funcoes":
				return _mundo(Lugar.LIVRE, TYPE_ARRAY)
			if s == "profissao":
				return _mundo(Lugar.LIVRE, TYPE_STRING_NAME)
			# `RegistroCivil.marcar_personagem`: quem monta o comodo marca, igual
			# em toda maquina.
			if s == "personagem":
				return _local(true)
			return _local()
		FOLHA:
			if coord.x == 0:
				return _mundo(Lugar.LIVRE, TYPE_ARRAY)
			return _local()
		LOJA:
			if s == "mao":
				return _pessoa()
			if s.begins_with("loja_"):
				return _mundo(Lugar.LIVRE, TYPE_DICTIONARY, true)
			return _local()
		INTERIOR:
			if s.begins_with("item_") or s.begins_with("porta_"):
				return _mundo(Lugar.COMODO, TYPE_BOOL)
			if s == "plantio":
				return _mundo(Lugar.COMODO, TYPE_DICTIONARY, true)
			if s.begins_with("falou_") or s == "repeticao":
				return _pessoa()
			return _local()
	if coord.y > INTERIOR:
		return _local()
	if s.begins_with("item_") or s.begins_with("porta_"):
		return _mundo(Lugar.RUA, TYPE_BOOL)
	return _local()


static func dono(coord: Vector2i, chave: StringName) -> int:
	return int(regra(coord, chave)["dono"])


static func pessoal(coord: Vector2i, chave: StringName) -> bool:
	return dono(coord, chave) == Dono.PESSOA


## O mundo sem o que e da pessoa. `mundo` no formato do save ("cx,cz" -> {}).
static func sem_pessoais(mundo: Dictionary) -> Dictionary:
	var saida := {}
	for k: String in mundo:
		var c: Variant = coord_de_texto(k)
		var d: Variant = mundo[k]
		if c == null or not (d is Dictionary):
			saida[k] = d
			continue
		var fica := {}
		for chave: Variant in (d as Dictionary):
			if not pessoal(c, StringName(chave)):
				fica[chave] = d[chave]
		if not fica.is_empty():
			saida[k] = fica
	return saida


## So o que e da pessoa, no mesmo formato.
static func so_pessoais(mundo: Dictionary) -> Dictionary:
	var saida := {}
	for k: String in mundo:
		var c: Variant = coord_de_texto(k)
		var d: Variant = mundo[k]
		if c == null or not (d is Dictionary):
			continue
		var fica := {}
		for chave: Variant in (d as Dictionary):
			if pessoal(c, StringName(chave)):
				fica[chave] = d[chave]
		if not fica.is_empty():
			saida[k] = fica
	return saida


## `base` com `por_cima` escrito chave a chave (os pessoais de agora sobre um
## mundo). Nao altera nenhum dos dois.
static func juntar(base: Dictionary, por_cima: Dictionary) -> Dictionary:
	var saida := base.duplicate(true)
	for k: String in por_cima:
		var d: Dictionary = (saida.get(k, {}) as Dictionary).duplicate() if saida.get(k) is Dictionary else {}
		var p: Dictionary = por_cima[k]
		for chave: Variant in p:
			d[chave] = p[chave]
		saida[k] = d
	return saida


static func coord_de_texto(k: String) -> Variant:
	var partes := k.split(",")
	if partes.size() != 2 or not partes[0].is_valid_int() or not partes[1].is_valid_int():
		return null
	return Vector2i(int(partes[0]), int(partes[1]))


static func _mundo(lugar: int, tipo: int, fundir := false) -> Dictionary:
	return {"dono": Dono.MUNDO, "lugar": lugar, "tipo": tipo, "fundir": fundir, "conhecida": true}


static func _pessoa() -> Dictionary:
	return {"dono": Dono.PESSOA, "lugar": Lugar.LIVRE, "tipo": TYPE_NIL, "fundir": false,
		"conhecida": true}


static func _local(conhecida := false) -> Dictionary:
	return {"dono": Dono.LOCAL, "lugar": Lugar.LIVRE, "tipo": TYPE_NIL, "fundir": false,
		"conhecida": conhecida}
