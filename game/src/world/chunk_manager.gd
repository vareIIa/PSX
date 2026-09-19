## Autoload. Carrega e descarrega a cidade em pedacos de 32 m em volta do jogador.
##
## Dois raios diferentes, e a diferenca importa:
##
##   raio de carga    quantos chunks existem na memoria. Vem do preset de nevoa,
##                    porque nevoa e o sistema de oclusao do jogo.
##   raio de render   ate onde a malha e efetivamente desenhada. Vem do fim da
##                    nevoa, sempre menor. Chunk carregado alem disso continua
##                    existindo, com colisao, mas nao entra em draw call.
##
## Sem o segundo raio a conta nao fecha: no preset leve sao 49 chunks carregados,
## e desenhar todos passaria de 90 mil triangulos contra um teto de 25 mil. Com
## ele, a nevoa esconde o corte e o custo cai para o que da para pagar.
##
## A margem por malha, que nao e detalhe
## -------------------------------------
## `visibility_range_end` mede a distancia da camera ate o CENTRO da malha, e a
## malha de um chunk e um bloco de 32 m: do centro dela ate a quina vao 22,6 m
## no chao e mais ainda com predio em cima. Sem somar esse raio ao alcance, um
## chunk inteiro sumia quando o CENTRO passava do fim da nevoa — ou seja, com a
## borda ainda a 22 m do jogador, dentro do campo de visao.
##
## No preset padrao do jogo (neblina_chuva, nevoa fechando a 18 m) isso dava um
## corte efetivo a poucos metros do nariz: a rua acabava numa linha reta no meio
## da nevoa, e prop que devia estar la nao aparecia. Por isso o alcance de cada
## malha e `alcance + meia diagonal da malha`: assim ela so sai de cena quando o
## volume INTEIRO ja passou do fim da nevoa.
##
## A construcao roda em WorkerThreadPool. O ChunkBuilder devolve dados puros, e so
## a criacao de ArrayMesh e dos nos acontece na thread principal, no maximo um
## chunk por frame, porque criar recurso de renderizacao fora dela nao e seguro.
extends Node

const TAM := 32.0
const MAT_DIR := "res://resources/materials/mat_%s.tres"

## Altura minima para uma caixa de colisao contar como PREDIO e virar oclusor.
const OCLUSOR_ALTURA_MIN := 3.0
## Quanto o oclusor encolhe em cada lado, em metros. Ver `_oclusor`.
const OCLUSOR_FOLGA := 0.15
## Os oito cantos de uma caixa, em sinais.
const CANTOS: Array[Vector3] = [
	Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
	Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1),
]
## As doze faces da caixa, com a volta para FORA.
const FACES: Array[int] = [
	0, 3, 2, 0, 2, 1,  # -Z
	4, 5, 6, 4, 6, 7,  # +Z
	0, 4, 7, 0, 7, 3,  # -X
	1, 2, 6, 1, 6, 5,  # +X
	0, 1, 5, 0, 5, 4,  # -Y
	3, 7, 6, 3, 6, 2,  # +Y
]

## Superficies fundidas que NAO projetam sombra: chao, e so chao.
##
## Nao e economia, e correcao. Um plano de asfalto lancando sombra sobre si mesmo
## produz o listrado de auto-sombra e nao acrescenta nada — chao nao tem o que
## projetar. Massa de predio, muro, toldo, vitrine e telha projetam, e e de la
## que vem a sombra que da peso e hora do dia para a rua.
##
## Isto vale nos DOIS estilos, e de proposito. Declarar a geometria como
## projetora custa zero no PS1 STYLE, porque la nenhuma luz tem sombra ligada:
## quem decide se existe sombra na cena e o DiretorSombra, e a malha so declara
## se ela e capaz de projetar. Assim o estilo troca no menu sem precisar
## remontar chunk nenhum.
const SEM_SOMBRA: Array[StringName] = [
	&"asfalto", &"asfalto_faixa", &"asfalto_remendo", &"marca_via",
	&"calcada", &"calcada_ladrilho", &"meio_fio",
	&"grama", &"terra", &"areia", &"leito", &"piso",
]

## Histerese: descarrega um anel alem do que carrega, senao andar em cima da
## fronteira faz o mesmo chunk carregar e descarregar a cada passo.
const FOLGA_DESCARGA := 1

## Teto de construcoes simultaneas na piscina de threads.
const MAX_EM_VOO := 4

## Quanto se desenha alem do fim da nevoa. So a folga para o chunk entrar em
## cena ja apagado, e nao mais: depois de `fog_end` a nevoa esta em 100% e cada
## metro a mais e triangulo pago para desenhar cor de ceu.
##
## Era 1,5 e servia de gambiarra para a margem que faltava por malha (ver o
## cabecalho). Com a margem certa no lugar, 1,15 chega — e e o que permitiu
## abrir a nevoa dos presets sem carregar um chunk a mais.
const ALCANCE_EXTRA := 1.15

## Piso do alcance de desenho, em metros. Existe para o momento em que um lugar
## impoe outro clima (FogController.forcar) ou o jogador troca de preset: o
## alcance acompanha, mas nunca cai a ponto de a rua acabar a vista.
const ALCANCE_MINIMO := 40.0

signal chunk_carregado(coord: Vector2i)
signal chunk_descarregado(coord: Vector2i)

## Raiz onde os chunks sao pendurados. Definida pela cena da cidade.
var raiz: Node3D
## Node3D seguido pelo streaming. Vazio faz o gerenciador procurar pelo grupo.
var alvo: Node3D

var ativo: bool = false
## So para a vista de inspecao de cima: desliga o corte de desenho por distancia.
## No jogo ele e obrigatorio — sem ele o preset leve desenharia 49 chunks e
## noventa mil triangulos contra um teto de vinte e cinco mil.
var alcance_infinito: bool = false
## Aneis de chunk a mais, tambem so para a inspecao de cima: a planta precisa de
## um pedaco de bairro, e o raio do preset da 96 m de raio.
var raio_extra: int = 0

var _carregados: Dictionary[Vector2i, Node3D] = {}
## coord -> id da tarefa na piscina. Precisa do id para esperar no desligamento.
var _em_voo: Dictionary[Vector2i, int] = {}
var _prontos: Array[Dictionary] = []
var _mutex := Mutex.new()

var _materiais: Dictionary[StringName, ShaderMaterial] = {}
var _coord_atual := Vector2i(2147483647, 0)
## Chunk sendo montado agora. O item precisa saber para registrar no WorldState
## que ja foi pego.
var _coord_do_prop := Vector2i.ZERO
var _raio_carga: int = 2
var _alcance_render: float = 26.0
## Preset em vigor de verdade. `FogController` empurra o dele para ca ao aplicar
## — inclusive o que um lugar impoe por `forcar`. Sem isto o streaming continuava
## lendo o clima escolhido em Settings: entrar numa cena de dia claro mantinha o
## corte de desenho da nevoa fechada do menu, e a rua acabava a vinte metros sem
## nevoa nenhuma para esconder o corte.
var _preset: FogPreset

# Estatisticas, lidas pelo overlay de debug e pela verificacao automatizada.
var tris_carregados: int = 0
var construcoes: int = 0


func _ready() -> void:
	KitModular.preparar()
	Settings.changed.connect(_aplicar_preset)
	_aplicar_preset()
	set_process(false)


## Liga o streaming numa cena. Chame depois de definir `raiz`.
func iniciar(nova_raiz: Node3D, novo_alvo: Node3D = null) -> void:
	raiz = nova_raiz
	alvo = novo_alvo
	ativo = true
	_coord_atual = Vector2i(2147483647, 0)
	set_process(true)


func parar() -> void:
	ativo = false
	set_process(false)
	aguardar_tarefas()
	# free imediato, nao queue_free: no desligamento a fila de liberacao pode
	# nao ser processada, e os nos ficam para tras como vazamento.
	for coord: Vector2i in _carregados.keys():
		var no: Node3D = _carregados[coord]
		tris_carregados -= int(no.get_meta(&"triangulos", 0))
		if is_instance_valid(no):
			no.free()
	_carregados.clear()
	_prontos.clear()
	_materiais.clear()


## Espera toda tarefa em voo terminar.
##
## Sem isso o motor desliga com thread ainda mexendo em dado do jogo, e sai uma
## enxurrada de RID vazado e string estatica sem referencia no fim da execucao.
## O erro nao aparece durante o jogo, so no encerramento, que e onde ninguem olha.
func aguardar_tarefas() -> void:
	for coord: Vector2i in _em_voo.keys():
		var id: int = _em_voo[coord]
		if id >= 0:
			WorkerThreadPool.wait_for_task_completion(id)
	_em_voo.clear()
	_mutex.lock()
	_prontos.clear()
	_mutex.unlock()


func _exit_tree() -> void:
	parar()


## Reaplica o preset. So a inspecao de cima usa, depois de mexer no raio.
func recarregar_preset() -> void:
	_aplicar_preset()


## Clima em vigor, empurrado pelo FogController. Inclui o preset que um lugar
## impoe por `forcar`, que Settings nao conhece.
func usar_preset(preset: FogPreset) -> void:
	# A inspecao de cima manda no raio por conta propria (raio_extra + alcance
	# infinito) e ainda forca dia claro para a planta nao sair preta. Deixar
	# esse preset de captura mexer no raio trocaria a planta por 361 chunks.
	if alcance_infinito:
		return
	if preset == null or preset == _preset:
		return
	_preset = preset
	_aplicar_preset()


func _aplicar_preset() -> void:
	var preset := _preset if _preset != null else Settings.fog_preset()
	_raio_carga = maxi(1, ceili(preset.stream_radius / TAM)) + raio_extra
	# Ate onde da para VER: com nevoa, o fim dela mais a folga de entrada; sem
	# nevoa, o horizonte de streaming, que e o unico limite que sobra e nao
	# ganha folga nenhuma porque nao ha nada carregado depois dele.
	var alcance := (preset.fog_end * ALCANCE_EXTRA) if preset.fog_enabled 		else preset.stream_radius
	_alcance_render = maxf(alcance, ALCANCE_MINIMO)
	for coord: Vector2i in _carregados:
		_aplicar_alcance(_carregados[coord])
	# Forca reavaliacao do conjunto desejado no proximo frame.
	_coord_atual = Vector2i(2147483647, 0)


func coord_de(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / TAM), floori(pos.z / TAM))


func chunks_carregados() -> int:
	return _carregados.size()


## O chunk esta montado agora? O mapa usa para mostrar o que o jogador consegue
## enxergar mesmo sem ainda ter pisado ali.
func esta_carregado(coord: Vector2i) -> bool:
	return _carregados.has(coord)


func _process(_delta: float) -> void:
	if not ativo or raiz == null:
		return
	if alvo == null:
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo == null:
			return

	var coord := coord_de(alvo.global_position)
	_coord_atual = coord
	# Onde o jogador pisou fica marcado para sempre. E o que o mapa revela.
	WorldState.visitar(coord)

	# Carga e descarga rodam todo frame, e nao so quando o jogador troca de chunk.
	#
	# Na carga, porque so na troca a fila enchia uma vez ate o teto de tarefas em
	# voo e parava ali: o jogador ficava parado no meio de quatro chunks e o resto
	# da cidade nunca chegava.
	#
	# Na descarga, porque um chunk pode terminar de ser montado depois de o
	# jogador ja ter passado pela fronteira. Nascendo fora do alcance, ele so
	# saia na proxima troca de coordenada, e ate la ficava carregado. Com chunk
	# mais pesado de montar isso passou a acontecer com frequencia e o conjunto
	# carregado estourava o teto de sessenta.
	_descarregar_distantes(coord)
	_preencher(coord)
	_materializar_um()


## Pede os chunks que faltam, do mais perto para o mais longe. O jogador olha
## para o que esta perto, entao e esse que nao pode faltar.
func _preencher(centro: Vector2i) -> void:
	if _em_voo.size() >= MAX_EM_VOO:
		return

	var faltando: Array[Vector2i] = []
	for dz in range(-_raio_carga, _raio_carga + 1):
		for dx in range(-_raio_carga, _raio_carga + 1):
			var c := centro + Vector2i(dx, dz)
			if not _carregados.has(c) and not _em_voo.has(c):
				faltando.append(c)
	if faltando.is_empty():
		return

	faltando.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - centro).length_squared() < (b - centro).length_squared())

	for c: Vector2i in faltando:
		if _em_voo.size() >= MAX_EM_VOO:
			break
		_pedir(c)


func _descarregar_distantes(centro: Vector2i) -> void:
	var limite := _raio_carga + FOLGA_DESCARGA
	for c: Vector2i in _carregados.keys():
		var d := c - centro
		if absi(d.x) > limite or absi(d.y) > limite:
			_descarregar(c)


func _pedir(coord: Vector2i) -> void:
	_em_voo[coord] = WorkerThreadPool.add_task(
		_tarefa.bind(coord), false, "chunk %d,%d" % [coord.x, coord.y])


## Roda fora da thread principal. Nao pode tocar em no nem em recurso.
func _tarefa(coord: Vector2i) -> void:
	var dados := ChunkBuilder.construir(coord.x, coord.y)
	dados["coord"] = coord
	_mutex.lock()
	_prontos.append(dados)
	_mutex.unlock()


## No maximo um chunk por frame vira no. Instanciar em lote engasga a imagem, e
## engasgo e justamente o que a Fase 3 promete nao ter.
func _materializar_um() -> void:
	_mutex.lock()
	var dados: Dictionary = _prontos.pop_front() if not _prontos.is_empty() else {}
	_mutex.unlock()
	if dados.is_empty():
		return

	var coord: Vector2i = dados["coord"]
	_em_voo.erase(coord)

	# Pode ter saido do alcance enquanto a thread trabalhava.
	if absi(coord.x - _coord_atual.x) > _raio_carga + FOLGA_DESCARGA \
			or absi(coord.y - _coord_atual.y) > _raio_carga + FOLGA_DESCARGA:
		return
	if _carregados.has(coord):
		return

	_carregados[coord] = _montar(coord, dados)
	construcoes += 1
	tris_carregados += int(dados["triangulos"])
	chunk_carregado.emit(coord)


func _montar(coord: Vector2i, dados: Dictionary) -> Node3D:
	var no := Node3D.new()
	no.name = "chunk_%03d_%03d" % [coord.x, coord.y]
	no.position = Vector3(coord.x * TAM, 0.0, coord.y * TAM)
	no.set_meta(&"triangulos", dados["triangulos"])

	var superficies: Dictionary = dados["superficies"]
	for material: StringName in superficies:
		var d: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = PSXMesh.dados_para_mesh(d)
		mi.material_override = _material(material)
		mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if SEM_SOMBRA.has(material)
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		no.add_child(mi)

	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in dados["colisao"]:
		var forma := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		if caixa.has("giro"):
			forma.rotation = caixa["giro"]
		corpo.add_child(forma)
	no.add_child(corpo)

	var oclusor := _oclusor(dados["colisao"])
	if oclusor != null:
		no.add_child(oclusor)

	_coord_do_prop = coord
	for prop: Dictionary in dados["props"]:
		var criado := _criar_prop(prop)
		if criado != null:
			no.add_child(criado)

	raiz.add_child(no)
	_aplicar_alcance(no)
	return no


## Um oclusor por chunk, feito das caixas de PREDIO que a colisao ja tem.
##
## O Godot 4 faz oclusao por rasterizacao em CPU: o que esta atras de um oclusor
## nao e enviado para a GPU. Numa cidade de quarteiroes fechados isso e o maior
## corte disponivel — da calcada, metade do que esta carregado esta atras de um
## predio.
##
## As caixas vem de graca: o `ChunkBuilder` ja monta colisao, e as de tres
## metros ou mais sao predio (4 a 6 por chunk, ate 15 m de altura, medido). As
## baixas — calcada, meio-fio, chao — nao ocluem nada e so custariam rasterizacao.
##
## Cada caixa ENCOLHE `OCLUSOR_FOLGA` antes de virar oclusor. Oclusor tem de
## ficar por DENTRO da geometria que representa: um que sobra um centimetro
## apaga a parede que deveria esconder, e o defeito aparece como pedaco de
## cidade sumindo em certos angulos — caro de achar depois.
##
## Tudo num `ArrayOccluder3D` so: um no por chunk em vez de um por predio.
func _oclusor(caixas: Array) -> OccluderInstance3D:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for caixa: Dictionary in caixas:
		var tam: Vector3 = caixa["tamanho"]
		if tam.y < OCLUSOR_ALTURA_MIN:
			continue
		var meio := Vector3(
			maxf(tam.x * 0.5 - OCLUSOR_FOLGA, 0.05),
			maxf(tam.y * 0.5 - OCLUSOR_FOLGA, 0.05),
			maxf(tam.z * 0.5 - OCLUSOR_FOLGA, 0.05))
		var base := Basis.IDENTITY
		if caixa.has("giro"):
			base = Basis.from_euler(caixa["giro"])
		var centro: Vector3 = caixa["pos"]
		var i0 := vertices.size()
		for sinal: Vector3 in CANTOS:
			vertices.append(centro + base * (sinal * meio))
		for k: int in FACES:
			indices.append(i0 + k)
	if vertices.is_empty():
		return null
	var oclusor := ArrayOccluder3D.new()
	oclusor.set_arrays(vertices, indices)
	var no := OccluderInstance3D.new()
	no.name = "Oclusor"
	no.occluder = oclusor
	return no


func _criar_prop(prop: Dictionary) -> Node3D:
	var tipo: String = prop.get("tipo", "")

	if tipo == "porta":
		var porta := Porta.new()
		porta.position = prop["pos"]
		porta.rotation.y = prop["giro"]
		porta.semente = prop["semente"]
		porta.interior = prop.get("interior", &"apartamento")
		porta.deslizante = prop.get("deslizante", false)
		porta.mundo = prop.get("mundo", false)
		return porta

	# A sala atras da porta de verdade. Nasce vazia: ela mesma se monta quando o
	# jogador chega perto (ver InteriorNoMundo).
	if tipo == "interior_mundo":
		var casa := InteriorNoMundo.new()
		casa.transform = prop["planta"]
		casa.planta = prop["interior"]
		casa.semente = prop["semente"]
		return casa

	if tipo == "item":
		var item := ItemNoChao.new()
		item.position = prop["pos"]
		item.item_id = prop["item"]
		item.quantidade = prop["quantidade"]
		item.indice = prop["indice"]
		item.chunk = _coord_do_prop
		return item

	if tipo == "save":
		var ponto := PontoDeSave.new()
		ponto.position = prop["pos"]
		ponto.rotation.y = prop["giro"]
		ponto.nome_do_local = prop["local"]
		return ponto

	if tipo == "inimigo":
		var inimigo := Inimigo.new()
		inimigo.position = prop["pos"]
		inimigo.semente = prop["semente"]
		return inimigo

	if tipo == "semaforo":
		var sem := Semaforo.new()
		sem.position = prop["pos"]
		sem.cruzamento = prop["cruzamento"]
		sem.eixo = prop["eixo"]
		sem.giro = prop["giro"]
		sem.com_halo = prop.get("halo", true)
		return sem

	if tipo == "sinal_pedestre":
		var sp := SinalPedestre.new()
		sp.position = prop["pos"]
		sp.cruzamento = prop["cruzamento"]
		sp.eixo_conflito = prop["eixo_conflito"]
		sp.giro = prop["giro"]
		return sp

	if tipo == "folhagem":
		var folhas := Folhagem.new()
		folhas.position = prop["pos"]
		folhas.semente = prop["semente"]
		return folhas

	if tipo == "convidado" or tipo == "morador":
		return _criar_convidado(prop, tipo == "morador")

	# A TV do bar. O bar mora no chunk, e nao num interior, entao o prop que
	# era so de Interiores precisa existir aqui tambem.
	if tipo == "televisao":
		var tv := Televisao.new()
		tv.position = prop["pos"]
		tv.giro = prop.get("giro", 0.0)
		return tv

	if tipo == "som_ambiente":
		return _criar_som(prop)

	if tipo == "fumaca":
		var f := FumacaParticulas.new()
		f.position = prop["pos"]
		# Tipado pela anotacao, e nao por `as`: `as` com enum devolve nulo.
		var qual: FumacaParticulas.Tipo = prop.get("fumaca", FumacaParticulas.Tipo.NUVEM)
		f.tipo = qual
		return f

	if tipo != "lampada":
		push_warning("ChunkManager: prop desconhecido '%s'" % tipo)
		return null

	var l := Lampada.new()
	l.position = prop["pos"]
	l.padrao = prop["padrao"]
	l.semente = prop["semente"]
	l.cor = prop.get("cor", Color("ffb763"))
	l.energia = prop.get("energia", 3.6)
	l.alcance = prop.get("alcance", 11.5)
	# A queda nao era exposta e todo poste do jogo herdava 1,1, que espalha a luz
	# ate o fim do alcance. E o que fazia o lampiao da Praca da Matriz ler como
	# holofote: energia e alcance mudam o TAMANHO da poca, so a atenuacao muda o
	# formato dela em halo.
	l.atenuacao = prop.get("atenuacao", 1.1)
	l.facho_visivel = prop.get("facho", true)
	l.raio_base = 3.2
	l.altura_facho = 6.2
	return l


## Gente parada na calcada, do lado de fora de um lugar.
##
## E o mesmo `Convidado` dos interiores, e nao um tipo novo. A classe ja e "a
## pessoa que fica num lugar" — a casa da fumaca, o balcao do mercado, a mesa da
## TV do bar — e o que ela faz de diferente aqui e nada: papel fixo, `pontos`
## vazio, nao anda. Quem anda na rua e o Pedestre, que e dirigido por rota e por
## Multidao, e plantar um Pedestre num ponto seria lutar contra o proprio
## arquivo dele.
##
## A ficha e resolvida AQUI e nao no builder, pela mesma razao do Interiores:
## `RegistroCivil` mantem cache e o builder do chunk roda no WorkerThreadPool.
func _criar_convidado(prop: Dictionary, mora_aqui: bool = false) -> Node3D:
	var semente := int(prop.get("semente", 0))
	var id := RegistroCivil.id_de_faixa(semente,
		int(prop.get("idade_min", 18)), int(prop.get("idade_max", 30)))
	var ficha := RegistroCivil.identidade(id)
	if ficha.is_empty():
		return null
	# `MoradorPraca` e `Convidado` com casa. Nao reescreve nada da maquina de
	# estados da mae: o ciclo de entrar e sair vive no `_process`, que
	# `Convidado` nao usa. Ver o cabecalho daquele arquivo.
	var c := MoradorPraca.new() if mora_aqui else Convidado.new()
	c.name = ("morador_%d" if mora_aqui else "convidado_%d") % id
	var papel: Convidado.Papel = prop.get("papel", Convidado.Papel.LIVRE)
	var foco: Vector3 = prop.get("foco", Vector3.ZERO)
	# Chapado e olho vermelho sao da SALA, nao da calcada. Ver Convidado.
	c.chapado = bool(prop.get("chapado", false))
	c.olhos_vermelhos = bool(prop.get("olhos", false))
	c.com_controle = bool(prop.get("controle", false))
	# Os pontos de caminhada vem do builder em coordenada LOCAL do chunk, e
	# `Convidado` compara o alvo com `global_position`: sem a conversao a pessoa
	# anda em direcao a origem do mundo e atravessa a cidade inteira.
	#
	# Estavam cravados como lista vazia, o que fazia todo convidado de rua
	# nascer parado para sempre - `_escolher_alvo` devolve na hora quando
	# `pontos` esta vazio. Para quem esta encostado na parede da casa da fumaca
	# isso e o correto e continua sendo, porque aquele prop nao manda pontos.
	var origem := Vector3(_coord_do_prop.x * TAM, 0.0, _coord_do_prop.y * TAM)
	var rota: Array[Vector3] = []
	for ponto: Vector3 in prop.get("pontos", [] as Array[Vector3]):
		rota.append(ponto + origem)
	c.preparar(ficha, papel, rota, bool(prop.get("fuma", false)),
		foco)
	c.position = prop["pos"]
	c.rotation.y = float(prop.get("giro", 0.0))
	if mora_aqui:
		var morador := c as MoradorPraca
		# A soleira vem em coordenada local do chunk, como todo `pos` de prop, e
		# o morador compara com `global_position`. Mesma conversao da rota.
		morador.soleira = (prop.get("soleira", prop["pos"]) as Vector3) + origem
		morador.giro_da_casa = float(prop.get("giro_da_casa", 0.0))
	return c


## Uma fonte de som parada no mundo. Gemea da do Interiores.
##
## O `corte_hz` e o que nao existe la dentro: na rua o som que interessa e o que
## ATRAVESSA uma parede, e o que atravessa alvenaria e o grave. Sem o filtro, a
## batida da casa da fumaca soa como se a caixa estivesse na calcada.
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
	p.volume_db = float(prop.get("volume", -16.0))
	p.max_distance = float(prop.get("alcance", 14.0))
	p.unit_size = 3.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	p.attenuation_filter_cutoff_hz = float(prop.get("corte_hz", 5000.0))
	p.attenuation_filter_db = -28.0
	AudioDirector.marcar_loop(stream)
	# autoplay, e nao play(): o no ainda nao entrou na arvore.
	p.autoplay = true
	return p


## Corta o desenho no fim da nevoa. A malha continua carregada e com colisao.
##
## O alcance e por malha, e nao um numero so: `visibility_range_end` mede ate o
## CENTRO da malha, entao cada uma ganha de volta a propria meia diagonal. Ver o
## cabecalho do arquivo — sem isso o corte acontecia 22 m antes do que se pediu,
## e no preset padrao a rua sumia dentro do campo de visao.
func _aplicar_alcance(no: Node3D) -> void:
	for filho: Node in no.get_children():
		var g := filho as GeometryInstance3D
		if g == null:
			continue
		if alcance_infinito:
			g.visibility_range_end = 0.0
			continue
		g.visibility_range_end = _alcance_render + _raio_da_malha(g)


## Meia diagonal da malha, em metros. E o quanto ela se estende alem do proprio
## centro — a margem que o corte por distancia precisa para nao comer geometria
## que ainda esta perto.
static func _raio_da_malha(g: GeometryInstance3D) -> float:
	var mi := g as MeshInstance3D
	if mi == null or mi.mesh == null:
		return TAM * 0.71
	return mi.mesh.get_aabb().size.length() * 0.5


func _descarregar(coord: Vector2i) -> void:
	var no: Node3D = _carregados.get(coord)
	if no == null:
		return
	tris_carregados -= int(no.get_meta(&"triangulos", 0))
	_carregados.erase(coord)
	no.queue_free()
	chunk_descarregado.emit(coord)


func _material(nome: StringName) -> ShaderMaterial:
	if _materiais.has(nome):
		return _materiais[nome]
	var caminho := MAT_DIR % nome
	if not ResourceLoader.exists(caminho):
		push_error("ChunkManager: material ausente %s" % caminho)
		return null
	var m := load(caminho) as ShaderMaterial
	_materiais[nome] = m
	return m
