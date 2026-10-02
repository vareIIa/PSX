## Autoload. Missao 1: a casa da fumaca, o porao, o Berg e a igreja.
##
## O roteiro de cinema esta em /mnt/project-files/missao1/roteiro.md e o mapa de
## sistemas em docs/missao1/mapeamento.md. Este arquivo e o diretor: ouve onde
## o jogador esta (Interiores, Missoes, Ator.interagido), chama as cenas
## cortadas na ordem do roteiro e grava as escolhas no Borboleta.
##
## STUB da branch missao1/base. A tarefa E (ultima) escreve tudo.
extends Node

signal comecou()
signal terminou()


## Comeca a Missao 1. Chamado quando a missao da casa da fumaca termina
## (`Missoes.concluiu`, depois do `dono_respondeu`).
func iniciar() -> void:
	comecou.emit()


func para_dicionario() -> Dictionary:
	return {}


func de_dicionario(_dados: Dictionary) -> void:
	pass
