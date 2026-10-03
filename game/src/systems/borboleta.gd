## Autoload. O que o jogador escolheu e que o futuro vai lembrar.
##
## Efeito borboleta e uma tabela de chave e valor, e nada mais. Quem escolhe
## grava aqui; quem depende da escolha (uma fala, um NPC que aparece ou nao, um
## final) pergunta aqui. Nenhum sistema guarda a propria copia de uma escolha:
## duas copias divergem no primeiro save carregado pela metade.
##
## O olho que olha para os dois lados e consequencia de `marcar` com
## `mostrar_olho`, e nao de quem chamou: a regra "escolha com peso mostra o
## olho" mora num lugar so. Quem desenha o olho e o `OlhoBorboleta`.
##
## Chaves da Missao 1 (as do roteiro, secao 8.2; ver docs/missao1/mapeamento.md):
##   m1_contou_ao_dono            E1  contou da estrada ao dono (olho)
##   m1_fumou_com_a_dupla         E2  fumou com Jota e Helmer no porao (olho)
##   m1_aceitou_carona_berg       E3  entrou no carro do Berg (olho)
##   m1_pegou_numero_berg         E4  pegou o papel com o telefone (olho)
##   m1_contou_do_padre_ao_berg   E5  contou do padre ao Berg (olho)
##   m1_falou_do_bonde            E6  falou do Lucas e da Mari (olho)
##   m1_desceu_ao_porao           estado, sem olho
##   m1_concluida                 estado, sem olho
extends Node

## Uma escolha foi gravada. `olho` diz se ela pede o olho na tela.
signal marcou(chave: StringName, valor: Variant, olho: bool)

var _flags: Dictionary[StringName, Variant] = {}


func marcar(chave: StringName, valor: Variant = true, mostrar_olho: bool = true) -> void:
	_flags[chave] = valor
	marcou.emit(chave, valor, mostrar_olho)


func valor(chave: StringName, padrao: Variant = null) -> Variant:
	return _flags.get(chave, padrao)


func tem(chave: StringName) -> bool:
	return _flags.has(chave)


func limpar() -> void:
	_flags.clear()


# --- save -------------------------------------------------------------------

func para_dicionario() -> Dictionary:
	var fora := {}
	for k: StringName in _flags:
		fora[String(k)] = _flags[k]
	return fora


func de_dicionario(dados: Dictionary) -> void:
	_flags.clear()
	for k: Variant in dados:
		_flags[StringName(str(k))] = dados[k]
