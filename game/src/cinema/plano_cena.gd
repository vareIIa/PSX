## O vocabulario de planos da cena cortada.
##
## A Cinematica sabe por a camera num ponto e mover entre dois. Isto sabe ONDE
## por a camera para um plano com nome — close no Berg, dois-shot dentro do
## carro, grua subindo para o ceu — a partir de quem esta em cena. O roteiro
## escreve `Cinema.plano(PlanoCena.Tipo.CLOSE, berg)` e nao um Vector3.
##
## Calcular a partir dos atores, e nao gravar posicao, e obrigatorio aqui: a
## cidade e gerada, entao a casa da fumaca e a calcada em frente a ela nunca
## estao no mesmo lugar duas partidas seguidas. Movimento de camera em curva
## (grua, acompanhamento) reaproveita `TrilhoDeCamera`.
##
## STUB da branch missao1/base: todo tipo devolve um enquadramento medio de
## frente. A tarefa A implementa cada tipo, com teste de oclusao contra parede.
class_name PlanoCena
extends RefCounted

enum Tipo {
	ESTABELECIMENTO,   ## geral do lugar, alto e longe
	DOIS_MEDIO,        ## dois personagens da cintura para cima
	CLOSE,             ## rosto e ombros
	CLOSE_EXTREMO,     ## so olhos, ou so a mao, ou so o oculos
	SOBRE_OMBRO,       ## por cima do ombro de `outro`, olhando `alvo`
	CONTRA_PLONGEE,    ## de baixo para cima (low angle)
	PLONGEE,           ## de cima para baixo (high angle)
	CARRO_INTERIOR,    ## dentro do carro, pelo para-brisa, os dois bancos
	CEU_GRUA,          ## grua subindo ate o ceu, alvo ficando pequeno
	ACOMPANHAMENTO,    ## tracking: segue `alvo` andando ou o carro rodando
	DOLLY_IN,          ## aproxima devagar
	DOLLY_OUT,         ## afasta devagar
	POV,               ## o olho de `alvo`, olhando para `outro`
}

## Enquadramento calculado. Chaves:
##   de, para: Vector3        camera e ponto olhado no inicio
##   ate, para_ate: Vector3   fim do movimento (iguais ao inicio em plano fixo)
##   fov, fov_ate: float
##   movel: bool              se a camera anda durante `duracao`
##   seguir: Node3D           para ACOMPANHAMENTO, quem a camera persegue
## `opcoes` aceita: lado (-1/1), altura, distancia, fov — sobrescrevem o padrao.
static func calcular(tipo: Tipo, alvo: Node3D, outro: Node3D = null,
		opcoes: Dictionary = {}) -> Dictionary:
	var olho := alvo.global_position + Vector3.UP * float(opcoes.get("altura", 1.55))
	var frente := -alvo.global_transform.basis.z
	var de := olho + frente * float(opcoes.get("distancia", 2.4))
	var fov := float(opcoes.get("fov", 55.0))
	if outro != null:
		olho = olho.lerp(outro.global_position + Vector3.UP * 1.55, 0.5)
	return {
		"de": de, "para": olho, "ate": de, "para_ate": olho,
		"fov": fov, "fov_ate": fov, "movel": false, "tipo": tipo,
	}
