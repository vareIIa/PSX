## Os personagens com nome da historia: ficha fixa e onde estao na cena.
##
## A aparencia de cada um ja mora em `Aparencia.ELENCO` (Helmer e Jota, linha
## LINHA_ELENCO do atlas). Isto junta o resto que a Missao 1 precisa: um id
## fixo no registro civil (para o contato no celular e a ligacao), o nome e a
## busca do no na cena — o Berg e um Ator; Jota, Helmer e o dono sao
## Convidados marcados com `set_meta(&"elenco", chave)` e o grupo `elenco`.
##
## STUB da branch missao1/base. A tarefa D poe o Berg em Aparencia.ELENCO (com
## oculos escuro) e marca dono, Jota e Helmer quando nascem.
class_name Elenco
extends RefCounted

const BERG := &"berg"
const HELMER := &"helmer"
const JOTA := &"jota"
const DONO := &"dono"

## Id fixo no registro civil. Dentro da populacao e longe de qualquer sorteio
## que importe; a tarefa D confere que nenhum id destes cai em quem ja existe.
const IDS := {
	BERG: 4100001,
	HELMER: 4100002,
	JOTA: 4100003,
	DONO: 4100004,
}


static func ficha(quem: StringName) -> Dictionary:
	var f: Dictionary = RegistroCivil.identidade(int(IDS.get(quem, 4100000))).duplicate(true)
	if not Aparencia.personagem(quem).is_empty():
		f["aparencia"] = Aparencia.de_personagem(f.get("aparencia", {}), quem)
		f["nome"] = Aparencia.nome_do_personagem(quem)
	elif quem == BERG:
		f["nome"] = "Berg"
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
