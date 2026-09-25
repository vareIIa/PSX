## O corpo de cada pessoa, montado uma vez e pendurado em quantos Corpo pedirem.
##
## Por que existe
## --------------
## `Corpo.montar` montava tudo no fio principal a cada pessoa que aparecia: os
## tubos da Anatomia, a roupa do Vestuario, a ArrayMesh, a pele (Skin), a barba.
## Uns 2 ms por pedestre, no quadro em que ele dobra a esquina; a 144 Hz o
## quadro inteiro tem 7. E a mesma pessoa, voltando a aparecer (o quarteirao de
## ida e volta, o convidado do bar a cada vez que se entra, o pool reciclando),
## era montada de novo do zero.
##
## Aqui cada VARIANTE (uma aparencia com as bandeiras de montagem) e montada uma
## vez e guardada; o Corpo so pendura o que ja existe. E o que ainda nao existe
## pode ser encomendado antes (`encomendar`), e sai montado no WorkerThreadPool.
##
## A chave
## -------
## TUDO que muda a malha: a aparencia inteira em bytes (`var_to_bytes`, que
## guarda o float exato — texto arredondaria duas alturas diferentes para a
## mesma pessoa), mais `detalhado` e `piscar`. Chave incompleta da a uma pessoa
## o corpo de outra, sem erro nenhum; chave a mais so custa uma montagem
## repetida (a mesma aparencia com as chaves em outra ordem, por exemplo).
## `com_rosto` nao entra: o rosto e montado por cima, no Corpo. O estilo grafico
## tambem nao: a malha do corpo e a mesma no PS1 e no MODERNO, so o material
## troca, e o material e posto pelo Corpo na hora de pendurar.
##
## Quem compartilha o que
## ----------------------
## A ArrayMesh da pele, da barba e da palpebra, a Skin e os aneis do tronco sao
## de TODOS os Corpo da mesma variante. Pode porque ninguem escreve neles: a
## pose mora no Skeleton3D de cada um, o piscar troca `visible`, o rosto e outra
## malha, e quem troca material (a chuva no jogador) troca o `material_override`
## do no, e nao o da malha. Quem um dia precisar deformar a malha de uma pessoa
## (como o `Amassado` faz com a lataria) tem de copiar antes — nunca escrever
## nesta, senao a rua inteira muda junto.
##
## Fora do fio principal
## ---------------------
## `encomendar` poe a montagem no WorkerThreadPool; `obter` (o que o
## `Corpo.montar` chama) so pendura. Se a encomenda ainda nao comecou quando o
## corpo e pedido, o fio principal a toma e monta ele mesmo, sem esperar a fila
## da thread (que pode estar cheia de chunk); se ja comecou, espera ela acabar.
## A ArrayMesh sai pronta da thread tambem (`MALHA_NA_THREAD`): e o carregamento
## em segundo plano do proprio Godot, que monta malha fora do fio principal; a
## subida para a GPU continua no fio do servidor, como em qualquer malha.
class_name VariantesDeCorpo
extends RefCounted

## Quantas variantes ficam guardadas. Uma pessoa da rua tem ~500 triangulos
## (a de perto, ~1.000): 256 sao poucos MB de GPU e cobrem o bairro em volta do
## jogador, ida e volta. Quem esta em uso nao depende disto: o MeshInstance do
## Corpo segura a malha dele.
const LIMITE := 256
## Monta a ArrayMesh na thread, e nao so os dados. Falso manda a ArrayMesh para
## o `obter`, no fio principal.
const MALHA_NA_THREAD := true

const PEDIDA := 0
const MONTANDO := 1
const PRONTA := 2


## Uma pessoa montada: o que `Corpo.montar` pendura.
class Variante:
	extends RefCounted
	## Copia congelada de quem pediu: a criacao de personagem mexe na aparencia
	## dela depois, e a thread le esta.
	var aparencia: Dictionary
	var detalhado := false
	var piscar := false
	var estado := 0
	var tarefa := -1
	## Os dados da `Corpo.dados_da_pessoa`, enquanto nao viram malha.
	var dados: Dictionary = {}
	## [nome, pai, repouso local] por osso, e as medidas.
	var ossos: Array = []
	var perfil: Array = []
	var abducao := 0.0
	var tem_pano := false
	var tem_barriga := false
	var triangulos := 0
	var malha: ArrayMesh
	var recorte: ArrayMesh
	var palpebra: ArrayMesh
	var skin: Skin


## chave (PackedByteArray) -> Variante, da menos para a mais recente.
static var _cache: Dictionary = {}
## Tarefa ainda nao esperada -> Variante. Toda tarefa do WorkerThreadPool tem de
## ser esperada uma vez; quem espera tira daqui antes, sob a trava.
static var _tarefas: Dictionary = {}
static var _trava := Mutex.new()
static var _ligado := false
## Estatistica, para bancada: montadas no fio principal, montadas na thread e
## achadas prontas.
static var no_fio := 0
static var na_thread := 0
static var achadas := 0


## A chave da variante. Ver o cabecalho.
static func chave(aparencia: Dictionary, detalhado: bool, piscar: bool) -> PackedByteArray:
	return var_to_bytes([aparencia, detalhado, piscar])


## Comeca a montar esta pessoa no WorkerThreadPool, para o `Corpo.montar` dela,
## quando vier, so pendurar. Pode ser chamada de qualquer thread, quantas vezes
## for: a segunda encomenda da mesma variante nao faz nada.
##
## `detalhado` e `piscar` tem de ser os que o Corpo vai ter na hora do `montar`
## (a multidao e o convidado: os dois falsos).
static func encomendar(aparencia: Dictionary, detalhado := false, piscar := false) -> void:
	var k := chave(aparencia, detalhado, piscar)
	_trava.lock()
	if _cache.has(k):
		_trava.unlock()
		return
	var v := _nova(k, aparencia, detalhado, piscar)
	# Prioridade alta: a encomenda e pequena (~2 ms) e tem hora, e na fila comum
	# ela esperava chunks inteiros montando na frente dela.
	v.tarefa = WorkerThreadPool.add_task(func() -> void: _montar_na_tarefa(v), true,
		"corpo")
	_tarefas[v.tarefa] = v
	_trava.unlock()
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		_ligar()


## Ja esta montada (o `Corpo.montar` dela so pendura)?
static func pronta(aparencia: Dictionary, detalhado := false, piscar := false) -> bool:
	var k := chave(aparencia, detalhado, piscar)
	_trava.lock()
	var v: Variante = _cache.get(k)
	var sim := v != null and v.estado == PRONTA and v.malha != null
	_trava.unlock()
	return sim


## A variante montada. So no fio principal (e o `Corpo.montar`).
static func obter(aparencia: Dictionary, detalhado: bool, piscar: bool) -> Variante:
	_colher(false)
	var k := chave(aparencia, detalhado, piscar)
	var esperar := -1
	var tomar := false
	_trava.lock()
	var v: Variante = _cache.get(k)
	if v == null:
		v = _nova(k, aparencia, detalhado, piscar)
		v.estado = MONTANDO
		tomar = true
	else:
		# A mais recente vai para o fim: a poda tira da frente.
		_cache.erase(k)
		_cache[k] = v
		if v.estado == PEDIDA:
			# A thread nem comecou: o fio principal toma. A tarefa, quando
			# rodar, ve MONTANDO e sai sem fazer nada.
			v.estado = MONTANDO
			tomar = true
		elif v.estado == MONTANDO and v.tarefa >= 0:
			esperar = v.tarefa
			_tarefas.erase(esperar)
			v.tarefa = -1
	_trava.unlock()
	if tomar:
		_montar(v, true)
		_trava.lock()
		v.estado = PRONTA
		_trava.unlock()
		no_fio += 1
		return v
	if esperar >= 0:
		WorkerThreadPool.wait_for_task_completion(esperar)
	else:
		achadas += 1
	if v.malha == null:
		_malhas(v)
	return v


## Espera toda encomenda em voo. No desligamento do jogo: tarefa montando malha
## depois que o servidor de render fecha derruba o processo na saida.
static func esperar_encomendas() -> void:
	_colher(true)


## Esquece tudo o que esta guardado (o que esta pendurado continua).
static func limpar() -> void:
	_colher(true)
	_trava.lock()
	_cache.clear()
	_trava.unlock()


static func quantas() -> int:
	return _cache.size()


# --- montagem ---------------------------------------------------------------------

## Sob a trava.
static func _nova(k: PackedByteArray, aparencia: Dictionary, detalhado: bool,
		piscar: bool) -> Variante:
	var v := Variante.new()
	v.aparencia = aparencia.duplicate(true)
	v.detalhado = detalhado
	v.piscar = piscar
	_cache[k] = v
	_podar()
	return v


## Tira as mais antigas acima do LIMITE. So as prontas: a pedida ou em
## montagem ainda tem quem a espere.
static func _podar() -> void:
	var sobra := _cache.size() - LIMITE
	if sobra <= 0:
		return
	for k: PackedByteArray in _cache.keys():
		if sobra <= 0:
			break
		var v: Variante = _cache[k]
		if v.estado != PRONTA:
			continue
		_cache.erase(k)
		sobra -= 1


static func _montar_na_tarefa(v: Variante) -> void:
	_trava.lock()
	if v.estado != PEDIDA:
		_trava.unlock()
		return
	v.estado = MONTANDO
	_trava.unlock()
	_montar(v, MALHA_NA_THREAD)
	_trava.lock()
	v.estado = PRONTA
	_trava.unlock()
	na_thread += 1


## Os dados e, com `com_malha`, as malhas. Em qualquer thread.
static func _montar(v: Variante, com_malha: bool) -> void:
	var d := Corpo.dados_da_pessoa(v.aparencia, v.detalhado, v.piscar)
	v.ossos = d["ossos"]
	v.perfil = d["perfil"]
	v.abducao = float(d["abducao"])
	v.tem_pano = bool(d["tem_pano"])
	v.tem_barriga = bool(d["tem_barriga"])
	# A conta de triangulos de sempre: pele e barba (a palpebra nao entra).
	v.triangulos = PSXMesh.dados_triangulos(d["pele"])
	if not PSXMesh.dados_vazio(d["recorte"]):
		v.triangulos += PSXMesh.dados_triangulos(d["recorte"])
	v.skin = Corpo.pele_dos_ossos(v.ossos)
	v.dados = d
	if com_malha:
		_malhas(v)


static func _malhas(v: Variante) -> void:
	var d := v.dados
	var malha := PSXMesh.dados_para_mesh(d["pele"])
	var recorte: ArrayMesh = null
	if not PSXMesh.dados_vazio(d["recorte"]):
		recorte = PSXMesh.dados_para_mesh(d["recorte"])
	var palpebra: ArrayMesh = null
	if v.piscar:
		palpebra = PSXMesh.dados_para_mesh(d["palpebra"])
	v.recorte = recorte
	v.palpebra = palpebra
	v.dados = {}
	# Por ultimo: `pronta` le `malha` para saber se acabou.
	v.malha = malha


# --- tarefas ----------------------------------------------------------------------

## Espera, a cada quadro, as tarefas que ja acabaram (o WorkerThreadPool pede
## que toda tarefa seja esperada). Sem custo quando nao ha encomenda.
static func _ligar() -> void:
	if _ligado:
		return
	var arvore := Engine.get_main_loop() as SceneTree
	if arvore == null:
		return
	_ligado = true
	arvore.process_frame.connect(func() -> void: _colher(false))


static func _colher(todas: bool) -> void:
	if _tarefas.is_empty():
		return
	var acabadas: Array[int] = []
	_trava.lock()
	for t: int in _tarefas.keys():
		if todas or WorkerThreadPool.is_task_completed(t):
			acabadas.append(t)
			var v: Variante = _tarefas[t]
			if v.tarefa == t:
				v.tarefa = -1
			_tarefas.erase(t)
	_trava.unlock()
	for t in acabadas:
		WorkerThreadPool.wait_for_task_completion(t)
