## As sondas de reflexo da rua: o criterio A14 do PLANO_AAA_4K.
##
## O reflexo de tela (SSR) so mostra o que ESTA na tela — a poca reflete o poste
## enquanto ele aparece e o apaga quando ele sai do quadro. A sonda guarda o
## arredor num cubo e devolve justamente o que saiu. Medido em
## `tests/bancada_luz.gd`: com sonda, um painel fora do enquadramento aparece na
## poca com +0,210 de vies de cor; sem ela, nada.
##
## Por que um DIRETOR, e nao uma sonda por chunk
## ---------------------------------------------
## A primeira versao punha uma `ReflectionProbe` em cada chunk, montada junto com
## ele. Cada sonda custa seis renderizacoes da cena no quadro em que nasce, e o
## resultado foi medido: **oito engasgos numa rota, cinco deles no quadro de um
## chunk novo** — exatamente o que o criterio A3 proibe. Reduzir o atlas de 256
## para 128 px nao mudou nada, porque o custo nao e de resolucao: sao seis
## varreduras da cena.
##
## Aqui as sondas sao POUCAS e VIVEM: um punhado segue o jogador, e no maximo uma
## se refaz por quadro. O custo deixa de crescer com o tamanho da cidade e passa
## a ser constante.
##
## `UPDATE_ONCE` e nao `ALWAYS`: a cidade e estatica. O que se move — carro,
## gente, chuva — nao entra no reflexo, e para poca de rua isso nao se nota.
class_name SondasReflexo
extends Node3D

## Quantas sondas seguem o jogador. Quatro cobrem o cruzamento inteiro em volta
## dele: o chunk em que esta e os tres vizinhos na direcao em que anda.
const QUANTAS := 4
## Lado do chunk, em metros. Espelha `ChunkManager.TAM`.
const TAM := 32.0
## Altura da caixa da sonda. Rua e fachada baixa, nao o ceu do quarteirao.
const ALTURA := 14.0
## Quadros entre duas conferencias. A sonda so se refaz quando o jogador troca de
## chunk, entao conferir todo quadro seria desperdicio.
const PASSO := 12

var _sondas: Array[ReflectionProbe] = []
var _onde: Array[Vector2i] = []
var _quadro := 0
var _fila: Array[int] = []


func _ready() -> void:
	for i in QUANTAS:
		var p := ReflectionProbe.new()
		p.name = "Sonda%d" % i
		p.size = Vector3(TAM, ALTURA, TAM)
		p.update_mode = ReflectionProbe.UPDATE_ONCE
		p.max_distance = 48.0
		p.enable_shadows = false
		# Mistura com o ambiente em vez de substitui-lo: a sonda acrescenta o que
		# o SSR nao alcanca, e nao apaga a nevoa.
		p.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
		p.visible = false
		add_child(p)
		_sondas.append(p)
		_onde.append(Vector2i(9999, 9999))


func _process(_delta: float) -> void:
	_quadro += 1
	# Uma refeita por quadro, no maximo. E o que transforma o custo de "seis
	# renderizacoes vezes o numero de chunks" em "seis renderizacoes, as vezes".
	if not _fila.is_empty():
		var i: int = _fila.pop_front()
		_sondas[i].visible = true
		_sondas[i].update_mode = ReflectionProbe.UPDATE_ONCE
		return
	if _quadro % PASSO != 0:
		return
	var alvo := get_tree().get_first_node_in_group(&"player") as Node3D
	if alvo == null:
		return
	_arrumar(Vector2i(floori(alvo.global_position.x / TAM),
		floori(alvo.global_position.z / TAM)))


## Poe as sondas nos chunks em volta do jogador, e enfileira as que mudaram.
func _arrumar(centro: Vector2i) -> void:
	var quer: Array[Vector2i] = [
		centro,
		centro + Vector2i(1, 0),
		centro + Vector2i(0, 1),
		centro + Vector2i(1, 1),
	]
	for i in mini(QUANTAS, quer.size()):
		if _onde[i] == quer[i]:
			continue
		_onde[i] = quer[i]
		_sondas[i].global_position = Vector3(
			(float(quer[i].x) + 0.5) * TAM, ALTURA * 0.35,
			(float(quer[i].y) + 0.5) * TAM)
		# Some ate a vez dela na fila: sonda parada em lugar errado devolve o
		# reflexo do quarteirao anterior, que e pior que reflexo nenhum.
		_sondas[i].visible = false
		if not _fila.has(i):
			_fila.append(i)


## Manda refazer as quatro, na ordem, uma por quadro.
##
## A rota de captura chama isto DEPOIS que a cena assenta. A primeira refeita
## acontece logo depois do salto, com o clima do lugar ainda sendo forcado e a
## camada de nuvens reiniciando — e a poca da praca refletia um ceu diferente a
## cada execucao.
func refazer_todas() -> void:
	for i in QUANTAS:
		if _onde[i] == Vector2i(9999, 9999):
			continue
		if not _fila.has(i):
			_fila.append(i)


## Todas as sondas no lugar e refeitas? A rota de captura espera por isto antes
## de fotografar: sem essa espera, duas execucoes da mesma parada pegam a sonda
## em estados diferentes e a regressao visual acusa diferenca que nao existe.
func pronta() -> bool:
	return _fila.is_empty() and acesas() == QUANTAS


## Quantas sondas estao acesas agora. Para teste e relatorio.
func acesas() -> int:
	var n := 0
	for p: ReflectionProbe in _sondas:
		if p.visible:
			n += 1
	return n
