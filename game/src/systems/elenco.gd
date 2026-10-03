## Os personagens com nome da historia: ficha fixa e onde estao na cena.
##
## A aparencia de cada um mora em `Aparencia.ELENCO` (Helmer, Jota e Berg, linha
## LINHA_ELENCO do atlas). Isto junta o resto que a Missao 1 precisa: o id no
## registro civil (para o contato no celular e a ligacao), o nome e a busca do
## no na cena — o Berg e um Ator; Jota, Helmer e o dono sao Convidados marcados
## com `set_meta(&"elenco", chave)` e o grupo `elenco` quando nascem
## (`Convidado._marcar_elenco`).
##
## De onde sai cada id
## -------------------
## Jota e Helmer NAO tem id fixo: a estufa sorteia pela semente na primeira vez
## e guarda no WorldState (`Interiores._fazendeiro`, EntregasDaSuper.COORD), e
## dali em diante e aquele. Um id escrito aqui seria outra pessoa com a mesma
## cara. Entao `id()` pergunta ao WorldState e so cai na tabela se a dupla
## ainda nao nasceu nesta partida.
##
## O Berg nao nasce em comodo nenhum, entao o id dele e fixo: um homem de
## quarenta e poucos, vivo, conferido no registro pelo teste `m1_d`. O dono e de
## cada casa (sorteio do builder): nao tem id de elenco, so o no.
class_name Elenco
extends RefCounted

const BERG := &"berg"
const HELMER := &"helmer"
const JOTA := &"jota"
const DONO := &"dono"

## Id no registro civil. So o do Berg vale sempre; os outros sao a reserva de
## antes de a dupla nascer (ver o cabecalho). O teste confere que o do Berg e
## um adulto de 40 a 50 anos, homem, vivo.
const IDS := {
	BERG: 4100015,
	HELMER: 4100002,
	JOTA: 4100001,
	DONO: 4100004,
}

## O numero do papel. DDD 35 e o sul de Minas: e de la que ele veio, e e o
## mesmo DDD de Sao Thome. O papel mostra mascarado ("BERG (35) 9 ••••-••••");
## o telefone mostra inteiro.
const TELEFONE_BERG := "(35) 99147-2208"

## A Missao 1 pede Jota e Helmer no porao (Cena 2) e nao na lavoura. Quem
## dirige a missao liga isto ao comecar e desliga ao terminar; quem nasce
## enquanto esta ligado vai para o lugar do porao (`Convidado._marcar_elenco`).
## Nao vai para o save: a missao refaz no `de_dicionario` dela.
static var dupla_no_porao: bool = false


## O id do personagem no registro civil, ou -1.
static func id(quem: StringName) -> int:
	if quem == HELMER or quem == JOTA:
		var guardado := int(WorldState.obter(EntregasDaSuper.COORD, quem, -1))
		if guardado >= 0:
			return guardado
	if quem == DONO:
		return -1
	return int(IDS.get(quem, -1))


static func ficha(quem: StringName) -> Dictionary:
	var n := id(quem)
	if quem == BERG:
		# A cara e o apelido entram pelo proprio registro, como os da dupla: a
		# carteira, o contato e o Portal mostram o mesmo homem.
		RegistroCivil.marcar_personagem(n, BERG)
	var f: Dictionary = RegistroCivil.identidade(n).duplicate(true) if n >= 0 else {}
	if not Aparencia.personagem(quem).is_empty():
		f["aparencia"] = Aparencia.de_personagem(f.get("aparencia", {}), quem)
		f["nome_elenco"] = Aparencia.nome_do_personagem(quem)
		f["apelido"] = Aparencia.nome_do_personagem(quem)
	elif quem == DONO:
		f["apelido"] = "DONO"
	f["elenco"] = quem
	return f


## O no desse personagem na cena (Ator ou Convidado), ou null.
static func no(arvore: SceneTree, quem: StringName) -> Node3D:
	for n: Node in arvore.get_nodes_in_group(&"elenco"):
		var a := n as Ator
		if a != null and a.quem == quem:
			return a
		if n.get_meta(&"elenco", &"") == quem:
			return n as Node3D
	return null


## O jogador pegou o papel: o Berg vira contato. Idempotente, e chamado tambem
## pelo app de contatos ao abrir (a flag do Borboleta e a fonte da verdade, e
## um save carregado no meio da missao tem a flag sem ter passado por aqui).
static func dar_numero_do_berg() -> void:
	var n := id(BERG)
	RegistroCivil.marcar_personagem(n, BERG)
	RegistroCivil.conhecer(n)


## O jogador ja tem o numero do Berg?
static func tem_numero_do_berg() -> bool:
	return bool(Borboleta.valor(&"m1_pegou_numero_berg", false))


## Onde cada um da dupla fica no porao: {pos, olhar} em coordenada da ESTUFA
## (o pai do Convidado). Vazio para quem nao e da dupla.
static func lugar_no_porao(quem: StringName) -> Dictionary:
	var x: Transform3D
	match quem:
		HELMER:
			x = EstufaBuilder.PORAO_HELMER
		JOTA:
			x = EstufaBuilder.PORAO_JOTA
		_:
			return {}
	return {"pos": x.origin, "olhar": x.origin - x.basis.z}


## Liga (ou desliga) a dupla no porao e move quem ja esta na cena. Quem nascer
## depois ja nasce no lugar (ver `dupla_no_porao`). Desligar devolve os dois a
## rotina da estufa.
static func levar_dupla_ao_porao(arvore: SceneTree, sim: bool = true) -> void:
	dupla_no_porao = sim
	for quem: StringName in [JOTA, HELMER]:
		var c := no(arvore, quem) as Convidado
		if c == null:
			continue
		if not sim:
			c.liberar()
			continue
		var lugar := lugar_no_porao(quem)
		var pai := c.get_parent() as Node3D
		if lugar.is_empty() or pai == null or c.contexto_da_conversa != &"estufa":
			continue
		c.estacionar(pai.to_global(lugar["pos"]), pai.to_global(lugar["olhar"]))
