## Autoload. Entra e sai de interiores sem tela de carregamento.
##
## A promessa da Fase 4 e que a porta abra e o jogador entre, sem corte. O truque
## tem tres partes:
##
##   1. O interior e construido numa thread, no mesmo formato do chunk.
##   2. A construcao comeca junto com a animacao da porta, que dura 1,2 s.
##   3. Os chunks da rua ficam carregados, so escondidos, entao sair e imediato.
##
## Manter a cidade na memoria custa uns 48 MB e paga com uma saida instantanea.
## Descarregar e recarregar levaria os mesmos 49 chunks de volta pela fila.
extends Node

## Interiores vivem bem acima da cidade. Separar por espaco em vez de por cena
## evita trocar de arvore, que e o que faria a rua ter de recarregar na volta.
const DESLOCAMENTO := Vector3(0.0, 2000.0, 0.0)

## Duracao da abertura da porta. E o orcamento de tempo da construcao, e ainda
## sobra a cortina depois dela para esconder a troca.
const ABERTURA := 1.2

const MAT_DIR := "res://resources/materials/mat_%s.tres"

## Quantas vezes a luz do leitor do balcao pisca antes de a camera virar.
##
## Tres, e nao uma. Um pisca so le como clique de botao; tres leem como aparelho
## trabalhando, e sao eles que dao ao gesto o segundo de duracao que separa
## apertar uma tecla de atender alguem.
const BIPES_DO_LEITOR := 3
const ENERGIA_DO_LEITOR := 3.2

## A luz vermelha do leitor CONTA no orcamento de lampadas do comodo.
##
## Ela nao e uma `Lampada` — e uma OmniLight3D crua, porque nao pisca por padrao
## nem tem alcance de poste —, mas o renderizador nao sabe dessa distincao. A
## loja tem treze lampadas mais esta, e o limite por objeto do compatibility esta
## em 16 (ver project.godot). Sobram duas vagas; quem gastar as duas e acrescentar
## uma terceira nao recebe aviso nenhum: as excedentes somem em silencio.
const LUZES_AVULSAS_DO_MERCADO := 1

## Quanto tempo a camera leva do balcao ate o monitor.
##
## Meio segundo e o limite: mais que isso o jogador percebe que perdeu o controle
## da cabeca e tenta reagir contra a virada.
const VIRADA_DA_CAMERA := 0.5

signal entrou()
signal saiu()

var dentro: bool = false

var _raiz: Node3D
var _no: Node3D
var _retorno := Transform3D()

## A pose da PORTA por onde se entrou, quando quem chamou soube informar.
##
## O retorno guarda onde o jogador estava, que e o certo para devolve-lo ao
## sair. Mas um comodo pode ter mais de uma boca para a rua — a loja tem a porta
## automatica do salao e o portao da garagem, um do lado do outro na mesma
## calcada — e ai a saida alternativa precisa de um eixo estavel para se medir.
##
## A pose do jogador nao serve para isso: ele pode ter entrado de lado, e o
## portao apareceria alguns metros torto a cada partida. A da porta e sempre a
## mesma, com o +X correndo pela fachada e o +Z apontando para a rua.
var _fachada := Transform3D()
var _semente: int = 0
var _tipo: StringName = &"apartamento"

## Comodos abertos por dentro de outro comodo, do mais antigo para o mais novo.
##
## Existe por causa da estufa. A porta dos fundos da casa da fumaca nao leva a
## rua: leva a outro interior, e sair de la tem de devolver o jogador para a
## SALA, e nao para a calcada. Sem pilha, `sair` so conhece um destino.
##
## Cada item guarda o que e preciso para reconstruir o comodo de tras — semente
## e planta — mais onde o jogador reaparece nele, que e do lado de dentro da
## porta que ele acabou de atravessar.
var _pilha: Array[Dictionary] = []

## Entrada forcada do proximo comodo, quando ele nao e entrado pela porta da
## frente. Vazio quer dizer "use a entrada da planta".
var _forcado: Dictionary = {}
var _tarefa: int = -1
var _dados: Dictionary = {}
var _mutex := Mutex.new()
var _pronto_em: float = 0.0
var _materiais: Dictionary[StringName, ShaderMaterial] = {}
var _imediato: bool = false

## Cortina preta da troca. Sem ela o jogador e teleportado no meio de um quadro
## e o corte aparece, o que joga fora todo o trabalho de esconder a construcao.
const FECHA := 0.22
const ABRE := 0.34
var _cortina: ColorRect


func _ready() -> void:
	set_process(false)
	_montar_cortina()


func _montar_cortina() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 140
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)

	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_cortina)
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)


func _escurecer(duracao: float) -> void:
	var t := create_tween()
	t.tween_property(_cortina, "color:a", 1.0, duracao)
	await t.finished


func _clarear(duracao: float) -> void:
	create_tween().tween_property(_cortina, "color:a", 0.0, duracao)


## Comeca a entrada. `retorno` e para onde o jogador volta ao sair, e `tipo` diz
## que planta montar: &"apartamento" ou &"casa".
##
## `fachada` e a pose da porta, para quem a tem. Identidade quer dizer "nao sei",
## e ai o retorno faz as vezes dela — que e o que valia antes de a loja ganhar
## uma segunda boca para a rua. Ver `_fachada`.
func entrar(semente: int, retorno: Transform3D,
		tipo: StringName = &"apartamento", imediato: bool = false,
		fachada: Transform3D = Transform3D()) -> void:
	if dentro or _tarefa >= 0:
		return
	_retorno = retorno
	_fachada = retorno if fachada.is_equal_approx(Transform3D()) else fachada
	_pilha.clear()
	_forcado = {}
	_iniciar(semente, tipo, 0.05 if imediato else ABERTURA)


## Passa de um interior para outro sem voltar a rua.
##
## `volta` e `volta_olhar` sao onde o jogador reaparece AQUI quando sair de la —
## do lado de dentro da porta que ele esta atravessando, olhando para o comodo.
## Sem isso ele voltaria ao ponto de entrada da casa, do outro lado da sala, e a
## porta dos fundos leria como teleporte.
func atravessar(semente: int, tipo: StringName, volta: Vector3,
		volta_olhar: Vector3) -> void:
	if not dentro or _tarefa >= 0:
		return
	_pilha.append({
		"semente": _semente, "tipo": _tipo,
		"pos": volta, "olhar": volta_olhar,
	})
	_iniciar(semente, tipo, ABERTURA)


## Comeca a construcao de um comodo. `espera` e o orcamento de tempo da
## animacao da porta: a construcao pode acabar antes, mas entrar antes de a
## porta terminar de abrir entrega que o interior ja estava pronto.
func _iniciar(semente: int, tipo: StringName, espera: float) -> void:
	_semente = semente
	_tipo = tipo
	# `_imediato` (entrar sem cortina, que a abertura CRT pede) sai da propria
	# espera em vez de ser um segundo parametro. Quem pede espera zero esta
	# pedindo exatamente isso, e dois parametros dizendo a mesma coisa divergem
	# no primeiro ajuste — foi por isso que os dois branches conflitaram aqui.
	_imediato = espera <= 0.06
	_pronto_em = float(Time.get_ticks_msec()) / 1000.0 + espera
	_dados = {}
	_tarefa = WorkerThreadPool.add_task(_construir.bind(semente, tipo), false, "interior")
	set_process(true)


## Que planta esta montada agora: &"casa", &"mercado", &"casa_fumaca". Vazio
## quando o jogador esta na rua.
##
## Quem pergunta e quem precisa reagir a QUAL comodo, e nao ao fato de haver um.
## A missao de chegar na casa da fumaca so fecha quando o comodo e aquele, e sem
## isto ela fecharia ao entrar em qualquer porta da cidade.
func tipo_atual() -> StringName:
	return _tipo if dentro else &""


## A calcada de onde o jogador entrou. Serve para quem precisa de um endereco de
## rua enquanto ele esta dentro de um comodo.
##
## Dentro de casa o corpo dele esta dois mil metros acima da cidade, em
## coordenadas de planta que nao tem nada a ver com o bairro: qualquer mapa lido
## a partir da posicao real ali mostraria o outro lado do mundo. O GPS usa esta,
## e por isso consegue dizer "sem sinal, ultimo ponto" em vez de mentir.
func posicao_de_retorno() -> Vector3:
	return _retorno.origin


## Sai para a rua.
##
## `deslocamento` desvia o ponto de chegada, medido no referencial da FACHADA:
## +X corre pela calcada, +Z afasta da porta. Serve a quem sai por uma boca que
## nao e aquela por onde entrou — hoje, o portao da garagem da loja, que da na
## mesma calcada alguns metros ao lado. Zero devolve o jogador exatamente a pose
## de onde ele entrou, que continua sendo o caso de toda porta comum.
func sair(deslocamento: Vector3 = Vector3.ZERO) -> void:
	if not dentro or _tarefa >= 0:
		return

	# Comodo aberto por dentro de outro: sair volta para o de tras, e nao para a
	# rua. A cortina ja esta fechada, entao a construcao nao precisa de orcamento
	# de tempo nenhum — o que ela tem de esconder ja esta escondido.
	if not _pilha.is_empty():
		var anterior: Dictionary = _pilha.pop_back()
		dentro = false
		await _escurecer(FECHA)
		_forcado = {"pos": anterior["pos"], "olhar": anterior["olhar"]}
		_iniciar(int(anterior["semente"]), StringName(anterior["tipo"]), 0.0)
		return

	dentro = false
	await _escurecer(FECHA)

	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		jogador.global_transform = _retorno
		if not deslocamento.is_zero_approx():
			# Medido a partir da PORTA e nao do retorno: e a fachada que diz onde
			# fica o portao ao lado, e a pose do jogador nao sabe disso.
			var base := _fachada.origin + _fachada.basis * deslocamento
			jogador.global_position = Vector3(base.x, _retorno.origin.y, base.z)
			# Sai de costas para a loja, olhando para a rua. Aparecer de frente
			# para o portao que se acabou de atravessar le como ter voltado.
			if jogador.has_method("olhar_para"):
				jogador.call("olhar_para",
					jogador.global_position + _fachada.basis.z * 4.0)
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")

	if _no != null:
		_no.queue_free()
		_no = null

	_mostrar_cidade(true)
	_liberar_ambiente()
	_clarear(ABRE)
	saiu.emit()


func _exit_tree() -> void:
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
	if _no != null and is_instance_valid(_no):
		_no.free()
		_no = null
	_pilha.clear()
	_dados.clear()
	_materiais.clear()


## Onde se acrescenta um lugar novo.
##
## Todo builder devolve o mesmo contrato — superficies, props, colisao, entrada,
## olhar, saida e, opcionalmente, ambiente — entao quem chama nunca precisa
## saber que planta e essa. Lugar novo custa uma linha aqui e um arquivo de
## planta; nada mais no resto do sistema muda.
static func _planta(tipo: StringName, semente: int) -> Dictionary:
	match tipo:
		&"casa":
			return CasaBuilder.construir(semente)
		&"mercado":
			return MercadoBuilder.construir(semente)
		&"casa_fumaca":
			return CasaFumacaBuilder.construir(semente)
		&"estufa":
			return EstufaBuilder.construir(semente)
		&"bar":
			return BarBuilder.construir(semente)
		_:
			return InteriorBuilder.construir(semente)


func _construir(semente: int, tipo: StringName) -> void:
	# A escolha da planta e feita aqui dentro, na thread, e nao antes: e o
	# trabalho pesado, e e para isso que existe a thread.
	var d := _planta(tipo, semente)
	_mutex.lock()
	_dados = d
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _tarefa < 0:
		set_process(false)
		return

	_mutex.lock()
	var pronto := not _dados.is_empty()
	_mutex.unlock()
	if not pronto:
		return
	# Espera a porta terminar de abrir mesmo que a construcao acabe antes. Entrar
	# no meio da animacao entrega que o interior ja estava pronto.
	if float(Time.get_ticks_msec()) / 1000.0 < _pronto_em:
		return

	WorkerThreadPool.wait_for_task_completion(_tarefa)
	_tarefa = -1
	set_process(false)
	# Fecha a cortina antes de trocar o mundo por baixo do jogador.
	# Na abertura CRT a UI cobre a troca: cortina curta evita esperar a porta.
	await _escurecer(0.05 if _imediato else FECHA)
	_materializar()
	_clarear(0.08 if _imediato else ABRE)
	_imediato = false


func _materializar() -> void:
	var arvore := get_tree().current_scene
	if arvore == null:
		return

	# Trocar de comodo sem voltar a rua deixa o anterior na arvore. Ele sai
	# aqui, e nao em `sair`: entre o pedido e este ponto passa a construcao
	# inteira na thread, e o jogador continuaria de pe dentro dele.
	if _no != null and is_instance_valid(_no):
		_no.queue_free()
		_no = null

	_no = Node3D.new()
	_no.name = "Interior"
	_no.position = DESLOCAMENTO

	var superficies: Dictionary = _dados["superficies"]
	for material: StringName in superficies:
		var d: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no.add_child(mi)

	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in _dados["colisao"]:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		corpo.add_child(forma)
	_no.add_child(corpo)

	for prop: Dictionary in _dados["props"]:
		var criado := _criar_prop(prop)
		if criado != null:
			_no.add_child(criado)

	_no.add_child(_saida())
	arvore.add_child(_no)

	var entrada: Vector3 = _dados["entrada"]
	var olhar: Vector3 = _dados["olhar"]
	if not _forcado.is_empty():
		entrada = _forcado["pos"]
		olhar = _forcado["olhar"]
		_forcado = {}
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador != null:
		jogador.global_position = DESLOCAMENTO + entrada + Vector3(0.0, 0.15, 0.0)
		if jogador.has_method("olhar_para"):
			jogador.call("olhar_para", DESLOCAMENTO + olhar)
		if jogador.has_method("zerar_velocidade"):
			jogador.call("zerar_velocidade")

	_mostrar_cidade(false)
	_forcar_ambiente()
	dentro = true
	entrou.emit()


## Cria um prop do interior. Mesmo esquema do ChunkManager: a thread devolve
## descricao, e a criacao de no acontece so aqui.
func _criar_prop(prop: Dictionary) -> Node3D:
	var tipo: String = prop.get("tipo", "")

	if tipo == "lampada":
		var l := Lampada.new()
		l.position = prop["pos"]
		l.padrao = prop["padrao"]
		l.semente = prop["semente"]
		l.cor = prop.get("cor", Color("ffe0b0"))
		l.energia = prop.get("energia", 1.5)
		l.alcance = prop.get("alcance", 6.0)
		l.facho_visivel = prop.get("facho", false)
		# A geometria do facho vem do prop quando ele pede. O padrao da Lampada e
		# de POSTE — 3,1 m de raio e 6,3 m de altura — e num comodo de tres
		# metros de pe direito um cone desse tamanho atravessa o teto e estoura
		# metade da imagem em branco. Foi o que a primeira captura da estufa
		# mostrou, e nao ha aviso nenhum que pegue isso.
		l.raio_topo = float(prop.get("raio_topo", l.raio_topo))
		l.raio_base = float(prop.get("raio_base", l.raio_base))
		l.altura_facho = float(prop.get("altura_facho", l.altura_facho))
		return l

	if tipo == "npc":
		var npc := Npc.new()
		npc.position = prop["pos"]
		npc.giro_inicial = prop.get("giro", 0.0)
		npc.semente = prop.get("semente", _semente)
		# A ficha e resolvida AQUI, e nao no builder. `RegistroCivil.identidade`
		# mantem cache, e o builder roda no WorkerThreadPool: consultar o
		# registro de la e uma corrida esperando a hora de acontecer. O builder
		# manda so a faixa de idade que o perfil da casa pede.
		var id := RegistroCivil.id_de_faixa(int(prop.get("semente", _semente)),
			int(prop.get("idade_min", 30)), int(prop.get("idade_max", 80)))
		npc.preparar(RegistroCivil.identidade(id), int(prop.get("perfil", 0)))
		return npc

	if tipo == "televisao":
		var tv := Televisao.new()
		tv.position = prop["pos"]
		tv.giro = prop.get("giro", 0.0)
		return tv

	if tipo == "convidado":
		return _criar_convidado(prop)

	if tipo == "ventilador":
		var v := Ventilador.new()
		v.position = prop["pos"]
		v.rotation.y = prop.get("giro", 0.0)
		v.oscila = bool(prop.get("oscila", true))
		v.fase = float(prop.get("fase", 0.0))
		return v

	if tipo == "porta_interna":
		return _porta_interna(prop)

	if tipo == "porta_batente":
		return _porta_batente(prop)

	if tipo == "portao_garagem":
		return _portao_garagem(prop)

	if tipo == "computador":
		return _computador(prop)

	if tipo == "atendimento":
		return _atendimento(prop)

	if tipo == "som_ambiente":
		return _criar_som(prop)

	if tipo == "porta_trancada":
		var porta := Porta.new()
		porta.position = prop["pos"]
		porta.rotation.y = prop.get("giro", 0.0)
		porta.trancada = true
		return porta

	if tipo == "save":
		var ponto := PontoDeSave.new()
		ponto.position = prop["pos"]
		ponto.rotation.y = prop.get("giro", 0.0)
		ponto.nome_do_local = prop.get("local", "Telefone")
		return ponto

	if tipo == "item":
		var item := ItemNoChao.new()
		item.position = prop["pos"]
		item.item_id = prop["item"]
		item.quantidade = prop.get("quantidade", 1)
		item.indice = prop.get("indice", 0)
		# Interiores nao tem coordenada de chunk, entao o item e registrado na
		# faixa reservada. Sem isso o bilhete da mesa volta toda vez que o
		# jogador entra de novo na casa.
		item.chunk = Vector2i(_semente, WorldState.INTERIOR)
		return item

	push_warning("Interiores: prop desconhecido '%s'" % tipo)
	return null


## Uma pessoa da casa da fumaca.
##
## A ficha vem do RegistroCivil como a de qualquer pedestre, e por isso da para
## conversar com ela, perguntar o nome e ver a identidade — a mesma carteira que
## sai na rua sai aqui. A faixa de idade e estreita de proposito: e uma casa de
## amigos de vinte anos, e a idade e a primeira coisa que o rosto entrega.
func _criar_convidado(prop: Dictionary) -> Node3D:
	var semente := int(prop.get("semente", _semente))
	# A faixa vem do prop, e nao escrita aqui. A carteira que o cliente larga no
	# balcao da loja resolve a MESMA pessoa a partir da mesma semente e da mesma
	# faixa (ver MercadoBuilder.SAL_DO_CLIENTE); com o intervalo escrito a mao
	# dos dois lados, mudar um deles trocaria em silencio a carteira por a de um
	# desconhecido, e nada acusaria.
	var id := RegistroCivil.id_de_faixa(semente,
		int(prop.get("idade_min", 18)), int(prop.get("idade_max", 26)))
	var ficha := RegistroCivil.identidade(id)
	if ficha.is_empty():
		return null
	var c := Convidado.new()
	c.name = "convidado_%d" % id
	# Cada um destes precisa de tipo escrito a mao: o que sai de um Dictionary e
	# Variant, e o projeto trata declaracao sem tipo como erro. `as` nao serve
	# para enum nem para Vector3 — so para classe — entao a conversao vem da
	# anotacao, que e a forma que o resto do mundo usa (ver ChunkBuilder).
	var pontos: Array[Vector3] = []
	for bruto: Variant in prop.get("pontos", []):
		var ponto: Vector3 = bruto
		pontos.append(ponto)
	var papel: Convidado.Papel = prop.get("papel", Convidado.Papel.LIVRE)
	var foco: Vector3 = prop.get("foco", Vector3.ZERO)
	# Antes de `preparar`, que e quem monta o corpo: as duas mandam em como ele
	# e construido, e depois de montado nao adianta mais.
	c.chapado = bool(prop.get("chapado", true))
	c.olhos_vermelhos = bool(prop.get("olhos", true))
	c.rotina = StringName(prop.get("rotina", &""))
	var pouso: Vector3 = prop.get("pouso", Vector3.ZERO)
	c.pouso_compra = pouso
	c.preparar(ficha, papel, pontos, bool(prop.get("fuma", false)), foco)
	c.position = prop["pos"]
	return c


## Uma fonte de som parada no espaco.
##
## Toca em laco e atenua com a distancia, entao a musica cresce conforme o
## jogador anda em direcao a ela. Isso e o oposto de trilha sonora: e um objeto
## que faz barulho, e o jogador pode andar ate ele e ver o que e.
##
## Se houver arquivo do usuario na pasta combinada, ele ganha do som gerado —
## e assim que se troca a trilha da casa sem tocar no jogo.
func _criar_som(prop: Dictionary) -> Node3D:
	var stream: AudioStream = null
	var pasta := String(prop.get("pasta", ""))
	if not pasta.is_empty():
		stream = AudioDirector.musica_do_usuario(pasta)
	if stream == null:
		stream = AudioDirector.em_loop(StringName(prop.get("som", &"")))
	if stream == null:
		return null

	var p := AudioStreamPlayer3D.new()
	p.name = "Som"
	p.bus = &"Music"
	p.stream = stream
	p.position = prop["pos"]
	p.volume_db = float(prop.get("volume", -12.0))
	p.max_distance = float(prop.get("alcance", 12.0))
	p.unit_size = 3.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	# Os WAV gerados nao sao marcados como laco no importador, porque varios
	# tambem servem de efeito curto. O laco vai no proprio stream, e nao no
	# sinal `finished` religando `play()`: ver AudioDirector.em_loop. Vale igual
	# para o arquivo do usuario, que ja e uma instancia so desta caixa de som.
	AudioDirector.marcar_loop(stream)
	# autoplay, e nao play(): este no ainda nao entrou na arvore — quem o
	# adiciona e _materializar, depois que _criar_prop devolve — e tocar antes
	# disso e erro de execucao.
	p.autoplay = true
	return p


## Porta que leva a outro interior, dentro deste.
##
## E irma da porta de saida e nao da porta da rua: a folha e a mesma, o tempo de
## abertura e o mesmo, e o que muda e o destino — em vez de `sair`, ela chama
## `atravessar`, que empilha este comodo antes de construir o proximo.
func _porta_interna(prop: Dictionary) -> Node3D:
	var area := Interativo.new()
	area.name = "PortaInterna"
	area.rotulo = String(prop.get("rotulo", "Abrir"))
	area.position = prop["pos"]

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = prop.get("tamanho", Vector3(1.3, 2.1, 1.0))
	forma.shape = box
	area.add_child(forma)

	var folha := Node3D.new()
	folha.name = "Folha"
	var dobradica: Vector3 = prop["dobradica"]
	folha.position = dobradica - area.position
	folha.rotation.y = float(prop.get("giro", 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = PSXMesh.box(Vector3(0.9, 2.05, 0.07), 1.0)
	mi.material_override = _material(&"porta")
	mi.position = Vector3(0.45, 1.025, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	folha.add_child(mi)
	area.add_child(folha)

	area.acionado.connect(func(_quem: Node) -> void:
		_abrir_interna(area, folha, prop))
	return area


## O atendimento do balcao: a carteira do cliente, o leitor e o monitor.
##
## Os tres viram UM no so, e nao tres props independentes, porque eles nao sao
## tres objetos — sao tres passos do mesmo gesto. A carteira arma o leitor, o
## leitor vira a camera, a camera entrega o monitor. Como props separados, cada
## um precisaria procurar os outros na arvore por nome, e a ordem em que o
## `_materializar` os cria passaria a importar.
##
## A ficha nao e passada de um para o outro: os dois a resolvem do MESMO
## `id_de_faixa(semente, ...)` que criou o cliente parado no balcao. O registro
## civil e uma funcao pura da semente, entao tres lugares que perguntam a mesma
## coisa recebem a mesma pessoa sem precisar combinar nada. E o que faz a
## carteira em cima do balcao ser a carteira DAQUELE cliente, e nao de um
## desconhecido com o mesmo endereco.
func _atendimento(prop: Dictionary) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "AtendimentoBalcao"

	var id := RegistroCivil.id_de_faixa(int(prop.get("semente", _semente)),
		int(prop.get("idade_min", 18)), int(prop.get("idade_max", 70)))
	var ficha := RegistroCivil.identidade(id)
	# O id fica gravado no no. E o unico jeito de a verificacao automatizada
	# conferir a afirmacao central deste prop — que a carteira em cima do balcao
	# e a do cliente parado ali, e nao a de outra pessoa qualquer. A ficha vive
	# dentro de lambdas e de fora nao se alcanca.
	raiz.set_meta(&"id_da_carteira", id)

	var carteira := _area(raiz, "Identidade", prop["pos"],
		prop.get("tamanho", Vector3(0.5, 0.45, 0.5)), "Ver a identidade")
	var leitor := _area(raiz, "Leitor", prop["leitor"],
		prop.get("tamanho_leitor", Vector3(0.5, 0.5, 0.5)), "Passar no sensor")
	# O leitor nasce desligado. Ele so tem o que ler depois que o jogador pegou a
	# carteira, e um sensor que aceita ser acionado com o balcao vazio ensina ao
	# jogador que a ordem nao importa — quando ela e a coisa toda.
	leitor.habilitado = false

	# A luz vermelha. Nasce apagada e mora no proprio leitor: e ela que responde,
	# porque o aparelho nao tem mostrador nem texto.
	var luz := OmniLight3D.new()
	luz.name = "LuzLeitor"
	luz.position = prop["luz"]
	luz.light_color = Color("ff2a1e")
	luz.light_energy = 0.0
	luz.omni_range = 1.6
	luz.shadow_enabled = false
	raiz.add_child(luz)

	var monitor: Vector3 = prop.get("monitor", Vector3.ZERO)
	carteira.acionado.connect(func(_quem: Node) -> void:
		_ler_identidade(carteira, leitor, ficha)
		_encarar_quem_pegou(id))
	leitor.acionado.connect(func(_quem: Node) -> void:
		_passar_no_leitor(leitor, luz, ficha, monitor))
	return raiz


## Uma area de acionamento simples, filha de `pai`.
func _area(pai: Node3D, nome: String, pos: Vector3, tamanho: Vector3,
		rotulo: String) -> Interativo:
	var area := Interativo.new()
	area.name = nome
	area.rotulo = rotulo
	area.position = pos
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tamanho
	forma.shape = box
	area.add_child(forma)
	pai.add_child(area)
	return area


## Abrir a carteira e o que arma o leitor.
##
## A carteira em tela cheia e a mesma `Documento` que o NPC tira do bolso na rua,
## sem uma linha de diferenca. Nao e economia: e a afirmacao de que o documento
## em cima do balcao e um documento do mesmo mundo, com o mesmo CPF que o
## terminal vai devolver daqui a dez segundos.
func _ler_identidade(carteira: Interativo, leitor: Interativo,
		ficha: Dictionary) -> void:
	if not carteira.habilitado or ficha.is_empty():
		return
	AudioDirector.tocar(&"papel", carteira.global_position, -6.0)
	Documento.abrir(ficha)

	# Armar so quando a carteira FECHA. Armando na abertura, o prompt do leitor
	# acenderia por tras da tela cheia e o jogador leria dois pedidos ao mesmo
	# tempo.
	var armar := func() -> void:
		# O comodo pode ter sumido enquanto a carteira estava aberta em tela
		# cheia: sair da loja e uma tecla, e a cortina cobre a tela toda. Sem
		# esta guarda, fechar o documento depois disso mexe em nos liberados.
		if not is_instance_valid(leitor) or not is_instance_valid(carteira):
			return
		leitor.habilitado = true
		carteira.rotulo = "Ver de novo"
	Documento.fechou.connect(armar, CONNECT_ONE_SHOT)


## O dono da carteira vira e olha para quem a pegou.
##
## Procura pelo id e nao por posicao: os dois no balcao sao Convidados parecidos,
## e o que distingue o cliente do atendente e de quem e o documento na mao do
## jogador. E a mesma pergunta que o resto deste prop faz — quem e esta pessoa —
## respondida pela mesma chave.
func _encarar_quem_pegou(id: int) -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null or _no == null:
		return
	for no: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := no as Convidado
		if c == null or not is_instance_valid(c):
			continue
		if int(c.ficha.get("id", -1)) != id:
			continue
		c.encarar(jogador.global_position)
		return


## O sensor: pisca, apita, e a camera vai sozinha para o monitor.
##
## Nao ha acerto nem erro, e nao deve haver. Passar um documento num leitor de
## balcao nao e um desafio — e a confirmacao de que o turno andou. O que o
## jogador ganha aqui e o TEMPO: um segundo de luz vermelha em que ele nao faz
## nada e o que separa "apertei um botao" de "atendi uma pessoa".
##
## A camera virar sozinha e a outra metade. Daria para so abrir o terminal, mas
## ai o monitor seria uma tela e nao um objeto em cima do balcao; virar a cabeca
## do jogador ate ele e o que amarra as duas coisas no mesmo lugar.
func _passar_no_leitor(leitor: Interativo, luz: OmniLight3D,
		ficha: Dictionary, monitor: Vector3) -> void:
	if not leitor.habilitado:
		return
	leitor.habilitado = false

	await _piscar_leitor(leitor, luz)
	# Entre o primeiro bipe e este ponto passou mais de um segundo, e o jogador
	# andou solto o tempo todo — a porta automatica fica a cinco passos do caixa.
	# Se ele saiu, o comodo inteiro ja foi liberado.
	if not is_instance_valid(leitor) or not dentro:
		return

	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var travei := false
	if jogador != null and not monitor.is_zero_approx() and _no != null:
		if jogador.has_method("travar"):
			jogador.call("travar", true)
			travei = true
		await _virar_para(jogador, _no.global_position + monitor).finished
		if not is_instance_valid(leitor) or not dentro:
			_destravar(jogador, travei)
			return

	# Quem travou destrava. O terminal recusa abrir com telefone na mao, conversa
	# em andamento ou jogo pausado, e nesse caso ninguem mais viria destravar —
	# o jogador ficava preso olhando para o monitor sem tecla que resolvesse.
	if not Terminal.abrir_com_ficha(ficha):
		_destravar(jogador, travei)
	if is_instance_valid(leitor):
		leitor.habilitado = true


## Os bipes. Separado porque a guarda de validade tem de estar DENTRO de cada
## passo, e nao so no fim: um `tween` do autoload sobrevive ao comodo que o
## pediu, e continuaria acendendo uma luz que ja foi liberada.
func _piscar_leitor(leitor: Interativo, luz: OmniLight3D) -> void:
	var t := create_tween()
	for k in BIPES_DO_LEITOR:
		t.tween_callback(func() -> void:
			if not is_instance_valid(luz) or not is_instance_valid(leitor):
				return
			luz.light_energy = ENERGIA_DO_LEITOR
			AudioDirector.tocar(&"bipe_curto", leitor.global_position, -8.0))
		t.tween_interval(0.11)
		t.tween_callback(func() -> void:
			if is_instance_valid(luz):
				luz.light_energy = 0.0)
		t.tween_interval(0.13)
	await t.finished


## Devolve o controle ao jogador, se foi esta sequencia que o tirou.
##
## `travei` existe para nao destravar quem nunca foi travado por aqui: o jogador
## pode estar preso por uma conversa que comecou no meio da leitura, e solta-lo
## seria pior que o defeito que esta funcao conserta.
func _destravar(jogador: Node3D, travei: bool) -> void:
	if not travei or jogador == null or not is_instance_valid(jogador):
		return
	if jogador.has_method("travar"):
		jogador.call("travar", false)


## Gira a cabeca do jogador ate `alvo`, pelo caminho curto.
##
## Pelo caminho CURTO: sem o `wrapf`, virar de -170 para +170 graus faz a camera
## dar a volta inteira pelo lado errado, e o que era um olhar vira um rodopio.
##
## O pitch desconta a altura do olho porque ele e medido a partir do PE do
## jogador, e o olho esta 1,62 m acima — a mesma pedra em que as capturas do
## mercado ja tropecaram, com nove fotos seguidas do forro.
func _virar_para(jogador: Node3D, alvo: Vector3) -> Tween:
	var d := alvo - jogador.global_position
	var horiz := maxf(Vector2(d.x, d.z).length(), 0.001)

	var de_y: float = jogador.rotation.y
	var para_y := de_y + wrapf(atan2(-d.x, -d.z) - de_y, -PI, PI)
	var de_pitch := 0.0
	if jogador.has_method("pitch_atual"):
		de_pitch = float(jogador.call("pitch_atual"))
	var para_pitch := atan2(d.y - Player.ALTURA_OLHO, horiz)

	var mover_pitch := func(v: float) -> void:
		if jogador.has_method("definir_pitch"):
			jogador.call("definir_pitch", v)

	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(jogador, "rotation:y", para_y, VIRADA_DA_CAMERA)
	t.tween_method(mover_pitch, de_pitch, para_pitch, VIRADA_DA_CAMERA)
	return t


## Porta que abre no lugar e nao leva a lugar nenhum.
##
## E a terceira porta do sistema, e a diferenca entre ela e as outras duas e o
## que ela NAO faz. A porta da rua constroi um interior; a porta interna empilha
## o comodo atual e constroi outro. Esta so gira a folha — porque os comodos dos
## dois lados dela ja estao montados, na mesma planta.
##
## E o que permite ao bloco de servico da loja ser quatro comodos e uma travessia
## so: sem cortina, sem carregamento e sem o jogador perder o passo. Uma porta
## com tela preta entre o corredor e o banheiro faria os dois lerem como dois
## lugares, e o ponto do bloco e ele ser UM lugar com quatro partes.
##
## Fecha de novo ao ser acionada aberta. Porta de servico que fica escancarada
## depois da primeira passagem tira do comodo justamente o que ele tem: a
## sensacao de estar nos fundos de um lugar fechado.
func _porta_batente(prop: Dictionary) -> Node3D:
	var area := Interativo.new()
	area.rotulo = String(prop.get("rotulo", "Abrir"))
	# O nome leva o rotulo junto. Tres portas chamadas "PortaBatente" viram
	# "PortaBatente", "@PortaBatente@2" e "@PortaBatente@3" na renomeacao
	# automatica do motor, e ai quem for procurar por elas na arvore acha uma so
	# — foi assim que o teste do mercado passou a contar uma porta em vez de tres.
	area.name = "PortaBatente" + area.rotulo.replace(" ", "")
	area.position = prop["pos"]

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = prop.get("tamanho", Vector3(1.3, 2.1, 1.0))
	forma.shape = box
	area.add_child(forma)

	var folha := Node3D.new()
	folha.name = "Folha"
	var dobradica: Vector3 = prop["dobradica"]
	folha.position = dobradica - area.position
	var fechada := float(prop.get("giro", 0.0))
	folha.rotation.y = fechada
	var mi := MeshInstance3D.new()
	mi.mesh = PSXMesh.box(Vector3(0.88, 2.05, 0.06), 1.0)
	mi.material_override = _material(&"porta")
	mi.position = Vector3(0.44, 1.025, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	folha.add_child(mi)
	# Macaneta. Doze triangulos, e sao eles que dizem de que lado a coisa abre.
	var mac := MeshInstance3D.new()
	mac.mesh = PSXMesh.box(Vector3(0.05, 0.05, 0.15), 2.0)
	mac.material_override = _material(&"metal")
	mac.position = Vector3(0.77, 1.02, 0.0)
	mac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	folha.add_child(mac)
	area.add_child(folha)

	var aberta := [false]
	area.acionado.connect(func(_quem: Node) -> void:
		if not area.habilitado:
			return
		area.habilitado = false
		var alvo := fechada
		if not aberta[0]:
			alvo = fechada + deg_to_rad(float(prop.get("angulo", 92.0)))
		AudioDirector.tocar(&"porta_trinco", area.global_position, -6.0)
		var t := create_tween()
		t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		t.tween_callback(func() -> void:
			AudioDirector.tocar(&"porta_abre", area.global_position, -8.0))
		t.tween_property(folha, "rotation:y", alvo, 0.38)
		t.tween_callback(func() -> void:
			aberta[0] = not aberta[0]
			area.rotulo = ("Fechar" if aberta[0]
				else String(prop.get("rotulo", "Abrir")))
			area.habilitado = true))
	return area


## O portao de enrolar da garagem: sobe e joga o jogador na rua.
##
## E uma saida, e nao uma porta interna, e por isso mora aqui e nao no builder:
## acionar o portao E sair da loja. O que ele tem de diferente da porta
## automatica do salao e o `deslocamento` — a rua para onde ele da fica alguns
## metros ao lado, na frente do portao que o ChunkBuilder desenhou na calcada.
##
## A folha nao sobe transladando: ela ENCOLHE de baixo para cima, com o pivo na
## verga. Transladada, ela atravessaria o forro da garagem e apareceria inteira
## do lado de fora do comodo; encolhida, ela some para dentro do tambor, que e o
## que um portao de enrolar faz de verdade. A textura espreme junto, e a 480x270
## em meio segundo isso nao se ve.
func _portao_garagem(prop: Dictionary) -> Node3D:
	var area := Interativo.new()
	area.name = "PortaoGaragem"
	area.rotulo = String(prop.get("rotulo", "Abrir o portao"))
	area.position = prop["pos"]

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = prop.get("tamanho", Vector3(3.0, 2.2, 1.4))
	forma.shape = box
	area.add_child(forma)

	var largura := float(prop.get("largura", KitMercado.LARGURA_PORTAO))
	var altura := KitMercado.ALTURA_PORTAO
	var centro: Vector3 = prop["centro"]

	# Pivo na verga, com a folha pendurada abaixo dele.
	var pivo := Node3D.new()
	pivo.name = "Folha"
	pivo.position = centro - area.position + Vector3(0.0, altura, 0.0)
	pivo.rotation.y = float(prop.get("giro", 0.0))
	area.add_child(pivo)

	var chapa := MeshInstance3D.new()
	chapa.mesh = PSXMesh.box(Vector3(largura, altura, 0.07), 1.0)
	chapa.material_override = _material(&"mercado_portao")
	chapa.position = Vector3(0.0, -altura * 0.5, 0.06)
	chapa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivo.add_child(chapa)

	var deslocamento: Vector3 = prop.get("deslocamento", Vector3.ZERO)
	area.acionado.connect(func(_quem: Node) -> void:
		if not area.habilitado:
			return
		area.habilitado = false
		AudioDirector.tocar(&"porta_desliza", area.global_position, -2.0)
		var t := create_tween()
		t.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		t.tween_property(pivo, "scale:y", 0.04, 0.62)
		# A cortina de `sair` cobre o resto: a folha nao precisa terminar o curso
		# para o corte funcionar, precisa ter comecado a subir.
		t.tween_callback(func() -> void: sair(deslocamento)))
	return area


## O computador do balcao. Uma area de acionamento, e nada mais.
##
## O monitor, o teclado e o gabinete sao geometria do KitMercado e ja estao na
## malha fundida do comodo — nao ha por que criar no para eles. O que precisa ser
## no e o gatilho, porque ele responde a tecla.
func _computador(prop: Dictionary) -> Node3D:
	var area := Interativo.new()
	area.name = "Computador"
	area.rotulo = String(prop.get("rotulo", "Consultar CPF"))
	area.position = prop["pos"]

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = prop.get("tamanho", Vector3(0.9, 0.9, 0.8))
	forma.shape = box
	area.add_child(forma)

	area.acionado.connect(func(_quem: Node) -> void: Terminal.abrir())
	return area


func _abrir_interna(area: Interativo, folha: Node3D, prop: Dictionary) -> void:
	if not area.habilitado:
		return
	area.habilitado = false
	AudioDirector.tocar(&"porta_trinco", area.global_position, -4.0)

	var giro := folha.rotation.y
	var angulo := deg_to_rad(float(prop.get("angulo", 92.0)))
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func() -> void:
		AudioDirector.tocar(&"porta_abre", area.global_position, -6.0))
	t.tween_property(folha, "rotation:y", giro + angulo, 0.42)

	# A construcao comeca JUNTO com a folha, e nao depois dela: e a mesma
	# promessa da porta da rua, e o tempo da animacao e o orcamento dela.
	var volta: Vector3 = prop["volta"]
	var olhar: Vector3 = prop["volta_olhar"]
	atravessar(int(prop.get("semente", _semente)),
		StringName(prop.get("destino", &"apartamento")), volta, olhar)


## Porta de saida: area de acionamento mais a folha, que abre antes de o jogador
## sair. A folha existe pelo mesmo motivo da porta da rua — sem ela o jogador
## atravessaria um vao vazio e a casa nao teria fechado nunca.
func _saida() -> Node3D:
	var s: Dictionary = _dados.get("saida", {})
	var area := Interativo.new()
	area.name = "Saida"
	area.rotulo = "Sair"
	area.position = s.get("pos", Vector3(0.25, 1.0, InteriorBuilder.ENTRADA.z))

	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = s.get("tamanho", Vector3(0.7, 2.0, 1.4))
	forma.shape = box
	area.add_child(forma)

	if s.has("deslizante"):
		var par := _folhas_deslizantes(area, s["deslizante"])
		area.acionado.connect(func(_quem: Node) -> void:
			_abrir_deslizante(area, par, s["deslizante"]))
		return area

	if not s.has("dobradica"):
		area.acionado.connect(func(_quem: Node) -> void: sair())
		return area

	var folha := Node3D.new()
	folha.name = "FolhaSaida"
	folha.position = s["dobradica"] - area.position
	folha.rotation.y = s.get("giro", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = PSXMesh.box(Vector3(0.9, 2.05, 0.07), 1.0)
	mi.material_override = _material(&"porta")
	mi.position = Vector3(0.45, 1.025, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	folha.add_child(mi)
	area.add_child(folha)

	area.acionado.connect(func(_quem: Node) -> void: _abrir_saida(area, folha, s))
	return area


## Duas folhas de vidro que correm para os lados. Devolve as duas, na ordem
## esquerda e direita em coordenada local da porta.
func _folhas_deslizantes(area: Interativo, d: Dictionary) -> Array[Node3D]:
	var giro: float = d.get("giro", 0.0)
	var largura: float = d.get("largura", 0.9)
	var altura: float = d.get("altura", 2.2)
	var centro: Vector3 = d["centro"] - area.position

	# O giro fica num no acima das folhas. Se ele estivesse na propria folha, o
	# deslizamento em X aconteceria no eixo do pai e nao no da porta, e uma porta
	# virada para outra direcao correria de lado errado.
	var base := Node3D.new()
	base.name = "PortaAutomatica"
	base.position = centro
	base.rotation.y = giro
	area.add_child(base)

	var par: Array[Node3D] = []
	for lado: float in [-1.0, 1.0]:
		var trilho := Node3D.new()
		trilho.name = "Folha%s" % ("E" if lado < 0.0 else "D")
		base.add_child(trilho)

		var mi := MeshInstance3D.new()
		# Vidro com caixilho: o quadro de aluminio e o que faz a folha ler como
		# porta de loja em vez de painel solto no vao.
		mi.mesh = PSXMesh.box(Vector3(largura, altura, 0.05), 1.0)
		mi.material_override = _material(&"mercado_vidro")
		mi.position = Vector3(lado * largura * 0.5, altura * 0.5, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trilho.add_child(mi)

		var caixilho := MeshInstance3D.new()
		caixilho.mesh = PSXMesh.box(Vector3(0.06, altura, 0.08), 1.0)
		caixilho.material_override = _material(&"metal")
		caixilho.position = Vector3(lado * (largura - 0.03), altura * 0.5, 0.0)
		caixilho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trilho.add_child(caixilho)

		par.append(trilho)
	return par


## Porta automatica: as folhas correm, esperam e o jogador sai.
##
## O tempo e mais curto que o da porta de dobradica porque porta automatica abre
## rapido, e uma que demora um segundo le como defeito.
func _abrir_deslizante(area: Interativo, par: Array[Node3D], d: Dictionary) -> void:
	if not area.habilitado:
		return
	area.habilitado = false
	AudioDirector.tocar(&"porta_desliza", area.global_position, -5.0)

	var curso: float = d.get("curso", 0.85)
	var t := create_tween().set_parallel(true)
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for k in par.size():
		var lado := -1.0 if k == 0 else 1.0
		t.tween_property(par[k], "position:x", par[k].position.x + lado * curso, 0.5)
	t.chain().tween_callback(sair)


func _abrir_saida(area: Interativo, folha: Node3D, s: Dictionary) -> void:
	if not area.habilitado:
		return
	area.habilitado = false
	AudioDirector.tocar(&"porta_trinco", area.global_position, -4.0)

	var giro := folha.rotation.y
	var angulo := deg_to_rad(float(s.get("angulo", 96.0)))
	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func() -> void:
		AudioDirector.tocar(&"porta_abre", area.global_position, -6.0))
	t.tween_property(folha, "rotation:y", giro + angulo, 0.42)
	# A cortina de `sair` cobre o resto: a folha nao precisa terminar o curso
	# para o corte funcionar, precisa ter comecado.
	t.tween_callback(sair)


func _mostrar_cidade(visivel: bool) -> void:
	if ChunkManager.raiz != null:
		ChunkManager.raiz.visible = visivel
	var chuva := get_tree().current_scene.get_node_or_null("Chuva") as GPUParticles3D
	if chuva != null:
		chuva.visible = visivel
		chuva.emitting = visivel


## Ambiente do lugar. Cada planta pode pedir o seu: a casa e quente e baixa, e a
## loja de conveniencia e branca e chapada. Metade do que separa os dois comodos
## esta aqui, e nao daria para conseguir so com lampada.
func _forcar_ambiente() -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog == null:
		return
	fog.forcar(String(_dados.get("ambiente", "res://resources/fog/fog_interior.tres")))


func _liberar_ambiente() -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		fog.liberar()


func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := MAT_DIR % nome
	if not ResourceLoader.exists(caminho):
		push_error("Interiores: material ausente %s" % caminho)
		return null
	var m := load(caminho) as ShaderMaterial
	_materiais[nome] = m
	return m
