## Quadro a quadro dirigindo pela cidade de verdade: o "lag" que o jogador sente.
##
##     godot --path game --resolution 3840x2160 res://tests/bancada_fps_dirigir.tscn -- --pular-menu --estilo=moderno
##     ... -- --vel=70          velocidade alvo em km/h (padrao 70)
##     ... -- --duracao=30      segundos dirigindo (padrao 30)
##     ... -- --parado=6        segundos parado no mesmo lugar antes, como base
##     ... -- --sem-sondas      desliga as sondas de reflexo que seguem o jogador
##     ... -- --sem-vida        tira transito e pedestres depois de pegar o carro
##     ... -- --foto=ARQ.png    uma foto no fim, FORA da medida
##     ... -- --foto-andando=ARQ.png  so a foto, 3 s depois de chegar na
##                              velocidade, e sai (nao mede nada)
##     ... -- --dentro          vista de dentro da cabine (padrao: a de perseguicao)
##     ... -- --sem-suavidade   (Suavidade) sem interpolacao de fisica: o "antes"
##     ... -- --alternar=20     parado, liga e desliga a interpolacao a cada
##                              segundo (N janelas) e compara o quadro: o custo
##                              dela medido DENTRO da rodada, imune a deriva da
##                              maquina entre uma execucao e outra
##     ... -- --modelo=HATCH    carro deste modelo, nascido para a bancada
##                              (SEDA, HATCH, PERUA, PICAPE, TAXI, MAREA, FUSCA).
##                              Sem isto pega o carro do transito mais perto, e o
##                              modelo muda de execucao para execucao: o custo de
##                              dentro do carro muda com ele (13,8 ms no hatch,
##                              25 ms no taxi, medido em 24/09/2026).
##     ... -- --medir           (Medidor) desliga vsync e mede o custo cru
##
## Monta a cidade inteira (o mesmo `scenes/test/cidade.tscn` do jogo) como filha,
## pega um carro pela porta do jogador (`TesteCarro._pegar_carro`), poe o carro
## na faixa da avenida mais proxima e segura a velocidade no eixo dela.
##
## Mede duas coisas diferentes, e as duas importam:
##
##   custo       quadro, CPU de script, fisica, GPU; e quem estava no quadro caro
##               (chunk materializado, sonda de reflexo refeita, nos que nasceram).
##   cadencia    quantos quadros DESENHADOS saem com a camera parada enquanto o
##               carro anda. A camera do carro anda no passo de fisica (60 Hz); a
##               165 Hz, dois em cada tres quadros repetem a imagem e o seguinte
##               salta o passo inteiro, com o desfoque de movimento acendendo so
##               nele.
##
## Imprime `[fps] chave=valor`.
extends Node

const PASSO := 1.0 / 60.0

var _vel_kmh := 70.0
var _duracao := 30.0
var _parado := 6.0
var _sem_sondas := false
var _sem_vida := false
var _foto := ""
## Onde o carro larga, no eixo da avenida. Fixo para duas execucoes compararem
## o mesmo trecho de cidade.
var _z0 := 100.0
var _modelo := ""
var _dentro := false
var _foto_andando := ""
var _alternar := 0
var _faixas: Faixas
var _janela_desf := -1
var _fatias: FatiasDoCarro
var _faixas_proc: FaixasProc
## `--aquecer`: carrega e desenha uma vez todo material de chunk antes de medir.
var _aquecer := false
## `--alternar-radar`: dirigindo, o radar da HUD liga e desliga a cada segundo.
var _alternar_radar := false
## `--duas-voltas`: no fim, o carro volta a largada e faz o mesmo trecho de novo
## (fase "volta2"). O que so custa na primeira vez (material, textura, pipeline)
## some na segunda; o que e de todo chunk, nao.
var _duas_voltas := false
## `--segurar-shaders`: todo shader e material do projeto, e um material por
## shader interno de tudo que entra na arvore, presos ate o fim. Se o engasgo
## que volta na segunda volta some, o defeito e shader saindo do cache com o
## ultimo dono.
var _segurar := false
var _guardados := {}
var _guardar_pendentes: Array[Node] = []
var _janela_radar := -1
## Contador de quadros da amostra do horizonte (um laco nas celulas, 1 em 15).
var _quadro_hz := 0
## `--alternar-desfoque`: dirigindo, o obturador liga e desliga a cada segundo.
var _alternar_desfoque := false

var _fase := &""
var _carro: Carro
var _faixa_x := 0.0
var _v_alvo := 0.0

var _sondas: Node
var _fila_antes := 0
var _chunks_no_quadro := 0
## O que entrou nos chunks, por quadro de processo, e por indice da serie ao
## qual o custo foi cobrado.
var _desc_do_frame := {}
var _descargas_do_frame := {}
var _desc_por_quadro := {}
## Materiais de chunk ja vistos na rodada: o que aparece pela primeira vez
## carrega (e compila) ali.
var _mat_vistos := {}
## Pipelines compiladas por fase (do contador do motor).
var _pipes_fase := {}
var _pipes_antes := -1
var _nos_antes := 0
var _cam_antes := Vector3.ZERO
var _tem_cam := false

## Uma lista por grandeza, por fase.
var _dados := {}
## Quadros em que o carro da bancada esteve de re (ver `_estacionar`).
var _quadros_de_re := 0


## Marcos do quadro: um roda PRIMEIRO e outro por ULTIMO em `_process` e em
## `_physics_process`, e a diferenca e o tempo de script e de fisica do quadro
## inteiro. O `Performance` nao serve para isso: TIME_PROCESS e o maximo do
## ultimo segundo (memoria "time-process-e-o-maximo-do-segundo").
class Marco extends Node:
	static var _ini_proc := 0
	static var _ini_fis := 0
	static var _fis_acum := 0.0
	## Do quadro anterior, completos: quem le no meio do quadro le estes.
	static var script_ms := 0.0
	static var fisica_ms := 0.0
	## O intervalo que o delta DESTE quadro mede, em pedacos (ms): do fim do
	## `_process` anterior ao comeco do desenho (fila de liberacao, chamadas
	## adiadas), o desenho (todas as vistas, sondas, pipeline), do fim do desenho
	## ao primeiro passo de fisica (apresentacao, espera da GPU) e a fisica.
	static var seg := {"pos": 0.0, "pos_fila": 0.0, "desenho": 0.0, "entre": 0.0, "fisica": 0.0}
	## Carimbo do meio do "pos": um SceneTreeTimer de zero segundo dispara em
	## `process_timers`, depois da fila de chamadas adiadas e da de liberacao.
	static var _t_timer := 0
	static var _t_proc_fim := 0
	static var _t_pre := 0
	static var _t_post := 0
	static var _t_fis_primeiro := 0
	static var _fis_desde_desenho := 0.0
	var fim := false
	var _pre: Callable
	var _post: Callable

	func _ready() -> void:
		if fim:
			_pre = func() -> void:
				Marco._t_pre = Time.get_ticks_usec()
			_post = func() -> void:
				Marco._t_post = Time.get_ticks_usec()
				Marco._t_fis_primeiro = 0
				Marco._fis_desde_desenho = 0.0
			RenderingServer.frame_pre_draw.connect(_pre)
			RenderingServer.frame_post_draw.connect(_post)

	func _exit_tree() -> void:
		if fim and _pre.is_valid():
			RenderingServer.frame_pre_draw.disconnect(_pre)
			RenderingServer.frame_post_draw.disconnect(_post)

	func _process(_d: float) -> void:
		var agora := Time.get_ticks_usec()
		if fim:
			script_ms = float(agora - _ini_proc) / 1000.0
			fisica_ms = _fis_acum
			_fis_acum = 0.0
			_t_proc_fim = agora
			_t_timer = 0
			get_tree().create_timer(0.0, true, false, true).timeout.connect(func() -> void:
				Marco._t_timer = Time.get_ticks_usec())
		else:
			_ini_proc = agora
			if _t_post > 0 and _t_pre > 0 and _t_proc_fim > 0:
				seg["pos"] = float(_t_pre - _t_proc_fim) / 1000.0
				seg["pos_fila"] = float(_t_timer - _t_proc_fim) / 1000.0 if _t_timer > 0 else -1.0
				seg["desenho"] = float(_t_post - _t_pre) / 1000.0
				seg["entre"] = float((_t_fis_primeiro if _t_fis_primeiro > 0 else agora) - _t_post) / 1000.0
				seg["fisica"] = _fis_desde_desenho

	func _physics_process(_d: float) -> void:
		var agora := Time.get_ticks_usec()
		if fim:
			var ms := float(agora - _ini_fis) / 1000.0
			_fis_acum += ms
			_fis_desde_desenho += ms
		else:
			_ini_fis = agora
			if _t_fis_primeiro == 0:
				_t_fis_primeiro = agora


## `--faixas`: de QUEM e o tempo de `_physics_process`. Cada script (ou classe
## nativa, pelo processamento interno) ganha uma faixa de prioridade propria com
## um marco na frente; o tempo entre dois marcos e daquele grupo. So muda a ORDEM
## entre nos que estavam na prioridade zero; quem ja tinha prioridade propria
## fica onde estava e cai no "fora das faixas".
class Faixas extends Node:
	const BASE := -60000
	const FECHO := -40000
	static var carimbos := PackedInt64Array()
	var fase := &""
	var _grupo := {}
	var _nomes: Array[String] = []
	var _contagem := PackedInt32Array()
	## fase -> ms acumulados por grupo
	var _tempo := {}
	var _pendentes: Array[Node] = []
	## grupo -> pior `_physics_process` num passo (ms), e -> passos acima de 2 ms.
	var maximos := {}
	var acima := {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var f := MarcoFaixa.new()
		f.indice = -1
		f.faixas = self
		f.process_physics_priority = FECHO
		add_child(f)
		_varrer(get_tree().root)
		get_tree().node_added.connect(func(no: Node) -> void:
			if no.get_script() == null and no is VisualInstance3D:
				return
			_pendentes.append(no))

	func _process(_d: float) -> void:
		# O processamento de fisica liga no _ready do no, depois do node_added.
		var lista := _pendentes
		_pendentes = []
		for no: Variant in lista:
			if is_instance_valid(no):
				_classificar(no as Node)

	func _varrer(no: Node) -> void:
		for filho in no.get_children():
			_varrer(filho)
		_classificar(no)

	func _classificar(no: Node) -> void:
		if no is MarcoFaixa or no is Marco or no == self:
			return
		if not (no.is_physics_processing() or no.is_physics_processing_internal()):
			return
		if no.has_meta(&"_faixa") or no.process_physics_priority != 0:
			return
		var chave := _chave(no)
		var k: int = _grupo.get(chave, -1)
		if k < 0:
			k = _nomes.size()
			_grupo[chave] = k
			_nomes.append(chave)
			_contagem.append(0)
			carimbos.append(0)
			var m := MarcoFaixa.new()
			m.indice = k
			m.faixas = self
			m.process_physics_priority = BASE + 2 * k
			add_child(m)
		no.process_physics_priority = BASE + 2 * k + 1
		no.set_meta(&"_faixa", k)
		_contagem[k] += 1

	static func _chave(no: Node) -> String:
		var s := no.get_script() as Script
		if s == null:
			return no.get_class()
		if not s.get_global_name().is_empty():
			return String(s.get_global_name())
		if not s.resource_path.is_empty():
			return s.resource_path.get_file()
		return "%s(interna)" % no.get_class()

	## Chamado pelo marco de fecho, no fim de cada passo de fisica.
	func fechar(t: int) -> void:
		if fase.is_empty():
			return
		var n := _nomes.size()
		var acum: PackedFloat64Array = _tempo.get(fase, PackedFloat64Array())
		acum.resize(n)
		for k in n:
			var ate: int = carimbos[k + 1] if k + 1 < n else t
			var ms := float(ate - carimbos[k]) / 1000.0
			acum[k] += ms
			# O pior passo de fisica de cada grupo, e quantos passaram de 2 ms.
			if ms > float(maximos.get(_nomes[k], 0.0)):
				maximos[_nomes[k]] = ms
			if ms > 2.0:
				acima[_nomes[k]] = int(acima.get(_nomes[k], 0)) + 1
		_tempo[fase] = acum

	## Os grupos mais caros da fase, em ms por quadro desenhado.
	func relatorio(f: StringName, quadros: int) -> String:
		var acum: PackedFloat64Array = _tempo.get(f, PackedFloat64Array())
		var ordem: Array[int] = []
		for k in acum.size():
			ordem.append(k)
		ordem.sort_custom(func(a: int, b: int) -> bool: return acum[a] > acum[b])
		var partes := PackedStringArray()
		var total := 0.0
		for k in ordem:
			total += acum[k]
		for k in ordem.slice(0, 12):
			partes.append("%s(%d)=%.2f" % [_nomes[k], _contagem[k],
				acum[k] / maxf(quadros, 1)])
		return "total=%.2f ms/quadro | %s" % [total / maxf(quadros, 1), " ".join(partes)]


## `--fatiar-carro`: o `_physics_process` do `Carro` parte por parte. Cada carro
## deixa de processar sozinho e esta classe chama as MESMAS partes, na mesma
## ordem (carro.gd, `_physics_process`), com relogio em volta de cada uma.
class FatiasDoCarro extends Node:
	var fase := &""
	## fase -> {parte: ms somados}
	var _tempo := {}
	## fase -> {parte: [pior ms numa chamada, quem]}
	var _pior := {}
	var _carros: Array[Carro] = []

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_physics_priority = -1
		for c: Node in get_tree().root.find_children("*", "Carro", true, false):
			_adotar(c as Carro)
		get_tree().node_added.connect(func(no: Node) -> void:
			if no is Carro:
				(no as Carro).ready.connect(_adotar.bind(no), CONNECT_ONE_SHOT))

	func _adotar(c: Carro) -> void:
		c.set_physics_process(false)
		if not _carros.has(c):
			_carros.append(c)

	func _physics_process(delta: float) -> void:
		var vivos: Array[Carro] = []
		for c: Variant in _carros:
			if is_instance_valid(c):
				vivos.append(c as Carro)
		_carros = vivos
		for c in vivos:
			if not c.is_inside_tree() or not c.can_process():
				continue
			var t := Time.get_ticks_usec()
			c._vivo += delta
			c._desde_buzina += delta
			var dirigir := &"parado"
			match c.motorista:
				Carro.Motorista.JOGADOR:
					c._dirigir_jogador(delta)
					dirigir = &"dirigir_jogador"
				Carro.Motorista.IA:
					c._dirigir_ia(delta)
					dirigir = &"dirigir_ia"
				_:
					c._velocidade = lerpf(c._velocidade, 0.0, minf(1.0, 3.0 * delta))
			t = _anotar(dirigir, t, c)
			c._sentir_batida(delta)
			t = _anotar(&"batida", t, c)
			if c._rastro != null:
				c._rastro.passo(delta, c.motorista == Carro.Motorista.JOGADOR)
			t = _anotar(&"rastro", t, c)
			c._girar_rodas(delta)
			t = _anotar(&"rodas", t, c)
			c._atualizar_luzes()
			t = _anotar(&"luzes", t, c)
			c._soar(delta)
			t = _anotar(&"som", t, c)
			c._assustar_quem_esta_perto()
			_anotar(&"susto", t, c)

	func _anotar(parte: StringName, desde: int, c: Carro) -> int:
		var agora := Time.get_ticks_usec()
		if fase.is_empty():
			return agora
		var ms := float(agora - desde) / 1000.0
		var soma: Dictionary = _tempo.get(fase, {})
		soma[parte] = float(soma.get(parte, 0.0)) + ms
		_tempo[fase] = soma
		var pior: Dictionary = _pior.get(fase, {})
		var p: Array = pior.get(parte, [0.0, ""])
		if ms > float(p[0]):
			pior[parte] = [ms, "%s/%s/%s" % [c.name, Carro.Motorista.keys()[c.motorista],
				Carroceria.Modelo.keys()[c.modelo]]]
		_pior[fase] = pior
		return Time.get_ticks_usec()

	func relatorio(f: StringName, quadros: int) -> String:
		var soma: Dictionary = _tempo.get(f, {})
		var pior: Dictionary = _pior.get(f, {})
		var partes: Array = soma.keys()
		partes.sort_custom(func(a: StringName, b: StringName) -> bool:
			return float(soma[a]) > float(soma[b]))
		var saida := PackedStringArray()
		for p: StringName in partes:
			var w: Array = pior.get(p, [0.0, ""])
			saida.append("%s=%.2f(pior %.1f %s)" % [p, float(soma[p]) / maxf(quadros, 1),
				float(w[0]), w[1]])
		return " ".join(saida)


## `--faixas-proc`: o mesmo das `Faixas`, para `_process`, e quadro a quadro:
## guarda de quem foi o tempo de cada quadro com mais de 20 ms de script.
class FaixasProc extends Node:
	const BASE := -60000
	const FECHO := -40000
	var carimbos := PackedInt64Array()
	## Devolve o indice da serie da bancada ao qual este `_process` sera cobrado.
	var indice: Callable
	var _grupo := {}
	var _nomes: Array[String] = []
	var _pendentes: Array[Node] = []
	## indice do quadro -> "grupo=ms grupo=ms ..."
	var caros := {}
	## grupo -> pior `_process` num quadro (ms), e grupo -> quadros acima de 2 ms.
	var maximos := {}
	var acima := {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		# Este no classifica os pendentes: ele fica FORA das faixas, no fim.
		process_priority = 90000
		var f := MarcoProc.new()
		f.indice = -1
		f.faixas = self
		f.process_priority = FECHO
		add_child(f)
		_varrer(get_tree().root)
		get_tree().node_added.connect(func(no: Node) -> void:
			if no.get_script() == null and no is VisualInstance3D:
				return
			_pendentes.append(no))

	func _process(_d: float) -> void:
		var lista := _pendentes
		_pendentes = []
		for no: Variant in lista:
			if is_instance_valid(no):
				_classificar(no as Node)

	func _varrer(no: Node) -> void:
		for filho in no.get_children():
			_varrer(filho)
		_classificar(no)

	func _classificar(no: Node) -> void:
		if no is MarcoProc or no is Marco or no == self:
			return
		if not (no.is_processing() or no.is_processing_internal()):
			return
		if no.has_meta(&"_faixa_proc") or no.process_priority != 0:
			return
		var chave := Faixas._chave(no)
		var k: int = _grupo.get(chave, -1)
		if k < 0:
			k = _nomes.size()
			_grupo[chave] = k
			_nomes.append(chave)
			carimbos.append(0)
			var m := MarcoProc.new()
			m.indice = k
			m.faixas = self
			m.process_priority = BASE + 2 * k
			add_child(m)
		no.process_priority = BASE + 2 * k + 1
		no.set_meta(&"_faixa_proc", k)

	func fechar(t: int) -> void:
		var n := _nomes.size()
		if n == 0:
			return
		var total := float(t - carimbos[0]) / 1000.0
		var tempos: Array = []
		for k in n:
			var ate: int = carimbos[k + 1] if k + 1 < n else t
			var ms := float(ate - carimbos[k]) / 1000.0
			tempos.append([ms, _nomes[k]])
			# O pior quadro de cada grupo na rodada inteira, e quantos quadros
			# passaram de 2 ms: o orcamento de um sistema a 144 Hz.
			if ms > float(maximos.get(_nomes[k], 0.0)):
				maximos[_nomes[k]] = ms
			if ms > 2.0:
				acima[_nomes[k]] = int(acima.get(_nomes[k], 0)) + 1
		if total < 20.0:
			return
		tempos.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var partes := PackedStringArray()
		for par: Array in tempos.slice(0, 4):
			partes.append("%s=%.1f" % [par[1], par[0]])
		caros[int(indice.call())] = " ".join(partes)


class MarcoProc extends Node:
	var indice := 0
	var faixas: FaixasProc

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_d: float) -> void:
		var t := Time.get_ticks_usec()
		if indice >= 0:
			faixas.carimbos[indice] = t
		else:
			faixas.fechar(t)


class MarcoFaixa extends Node:
	var indice := 0
	var faixas: Faixas

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _physics_process(_d: float) -> void:
		var t := Time.get_ticks_usec()
		if indice >= 0:
			Faixas.carimbos[indice] = t
		else:
			faixas.fechar(t)


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--vel="):
			_vel_kmh = arg.trim_prefix("--vel=").to_float()
		elif arg.begins_with("--duracao="):
			_duracao = arg.trim_prefix("--duracao=").to_float()
		elif arg.begins_with("--parado="):
			_parado = arg.trim_prefix("--parado=").to_float()
		elif arg == "--sem-sondas":
			_sem_sondas = true
		elif arg == "--sem-vida":
			_sem_vida = true
		elif arg.begins_with("--foto="):
			_foto = arg.trim_prefix("--foto=")
		elif arg.begins_with("--foto-andando="):
			_foto_andando = arg.trim_prefix("--foto-andando=")
		elif arg == "--dentro":
			_dentro = true
		elif arg.begins_with("--alternar="):
			_alternar = arg.trim_prefix("--alternar=").to_int()
		elif arg.begins_with("--modelo="):
			_modelo = arg.trim_prefix("--modelo=").to_upper()
		elif arg.begins_with("--z0="):
			_z0 = arg.trim_prefix("--z0=").to_float()
		elif arg == "--faixas":
			_faixas = Faixas.new()
		elif arg == "--fatiar-carro":
			_fatias = FatiasDoCarro.new()
		elif arg == "--faixas-proc":
			_faixas_proc = FaixasProc.new()
		elif arg == "--aquecer":
			_aquecer = true
		elif arg == "--alternar-radar":
			_alternar_radar = true
		elif arg == "--duas-voltas":
			_duas_voltas = true
		elif arg == "--segurar-shaders":
			_segurar = true
		elif arg == "--alternar-desfoque":
			_alternar_desfoque = true
	RenderingServer.viewport_set_measure_render_time(
		get_viewport().get_viewport_rid(), true)
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	for fim: bool in [false, true]:
		var m := Marco.new()
		m.fim = fim
		m.process_priority = 100000 if fim else -100000
		m.process_physics_priority = 100000 if fim else -100000
		m.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(m)
	ChunkManager.chunk_descarregado.connect(func(_c: Vector2i) -> void:
		var fq := Engine.get_process_frames()
		_descargas_do_frame[fq] = int(_descargas_do_frame.get(fq, 0)) + 1)
	ChunkManager.chunk_carregado.connect(func(_c: Vector2i) -> void:
		_chunks_no_quadro += 1
		# Pelo numero do quadro de processo em que o chunk virou no: o custo dele
		# cai no delta do quadro SEGUINTE, qualquer que seja a ordem dos _process.
		var fq := Engine.get_process_frames()
		_desc_do_frame[fq] = ("%s + " % _desc_do_frame[fq] if _desc_do_frame.has(fq) else "") 			+ _descrever_chunk(_c))
	_rodar(cidade)


func _relatar(chave: String, valor: Variant) -> void:
	print("[fps] %s=%s" % [chave, valor])


func _rodar(cidade: Node) -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.physics_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	_relatar("placa", "%s | %s" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_api_version()])
	var fog := arvore.get_first_node_in_group(&"fog_controller") as FogController
	if fog != null:
		var p := fog.preset_atual()
		_relatar("preset", "%s fog_end=%.0f stream=%.0f" % [p.id, p.fog_end, p.stream_radius])

	_carro = await _carro_do_modelo(jogador) if not _modelo.is_empty() 		else await TesteCarro._pegar_carro(cidade, jogador)
	if _carro == null:
		_relatar("carro", 0)
		arvore.quit(1)
		return
	if _sem_vida:
		Transito.ativo = false
		Transito.limpar()
		Multidao.ativo = false

	# Sem blitz: ela e sorteada, e quando cai na avenida os cones e a viatura
	# fecham a faixa e o carro fica parado a rodada inteira (0 m em 20 s, visto
	# com hatch e com seda). A medida e de dirigir, e nao de ser abordado.
	BlitzManager.parar()
	BlitzManager.limpar()
	# Sempre a mesma avenida (x = -160): o nascimento do jogador varia, e uma
	# execucao em outra avenida mede outra cidade.
	var i := -5
	# De frente para -Z a direita e +X: a faixa da mao fica em +meia faixa.
	_faixa_x = i * MalhaUrbana.TAM + MalhaUrbana.meia_pista(MalhaUrbana.Via.AVENIDA) * 0.5
	var z0 := _z0
	_carro.pousar(Vector3(_faixa_x, Relevo.altura(_faixa_x, z0) + 0.6, z0), 0.0)
	_carro.pilotar(0.0, 0.0, 0.0)
	if not _carro.ligado:
		_carro.alternar_ignicao()
	_estacionar()
	# Fantasma para o transito a rodada INTEIRA, e nao so dirigindo: parado na
	# largada e na espera da segunda volta ele era atingido pelo carro de tras.
	# Todo carro que o Transito puser na rua depois entra na excecao na hora.
	_fantasma()
	Transito.carro_chegou.connect(func(c: Node3D) -> void:
		if is_instance_valid(_carro) and c is PhysicsBody3D and c != _carro:
			_carro.add_collision_exception_with(c))
	_relatar("largada", "x=%.1f z=%.1f" % [_faixa_x, z0])
	if _dentro:
		var cab := _carro.get(&"_cabine_jogador") as Node
		if cab != null:
			cab.call(&"_ir_para", CabineDoJogador.Vista.DENTRO)
	_relatar("vista", "dentro" if _dentro else "perseguicao")
	_relatar("suavidade", get_tree().physics_interpolation)

	# Espera a cidade em volta do lugar novo terminar de montar.
	var espera := 0.0
	var estavel := 0.0
	var antes := -1
	while espera < 25.0 and estavel < 1.5:
		await arvore.process_frame
		espera += get_process_delta_time()
		var n := ChunkManager.chunks_carregados()
		var ocioso: bool = ChunkManager._em_voo.is_empty() and ChunkManager._prontos.is_empty() 			and ChunkManager._montando.is_empty()
		estavel = estavel + get_process_delta_time() if (n == antes and ocioso) else 0.0
		antes = n
	_relatar("montagem_s", "%.1f chunks=%d" % [espera, ChunkManager.chunks_carregados()])
	for c: Vector2i in ChunkManager._carregados:
		_descrever_chunk(c)
	# Depois da montagem, e nao na largada: a Qualidade escreve a escala do 3D
	# um quadro depois da cena, e o print de antes mostrava a do EstiloVisual.
	_relatar("janela", "%s escala=%.2f taa=%s vsync=%d max_fps=%d fisica=%d interpolacao=%s" % [
		DisplayServer.window_get_size(), get_window().scaling_3d_scale, get_window().use_taa,
		DisplayServer.window_get_vsync_mode(),
		Engine.max_fps, Engine.physics_ticks_per_second,
		ProjectSettings.get_setting("physics/common/physics_interpolation", false)])
	_relatar("qualidade", Qualidade.NIVEIS[Qualidade.nivel]["nome"])
	if _segurar:
		_segurar_tudo()
	if _faixas != null:
		arvore.root.add_child(_faixas)
	if _fatias != null:
		arvore.root.add_child(_fatias)
	if _faixas_proc != null:
		# O `_process` deste quadro aparece no delta do quadro SEGUINTE, que e o
		# proximo indice da serie.
		_faixas_proc.indice = func() -> int: return _serie(_fase, &"quadro").size()
		arvore.root.add_child(_faixas_proc)

	_sondas = _achar(arvore.root, "SondasReflexo")
	if _sem_sondas and _sondas != null:
		_sondas.set_process(false)
		for s: Node in _sondas.get_children():
			(s as ReflectionProbe).visible = false
	_relatar("sondas", "nenhuma" if _sondas == null else ("desligadas" if _sem_sondas else "ligadas"))

	await arvore.create_timer(3.0).timeout
	if _aquecer:
		await _aquecer_materiais()
	if OS.get_cmdline_user_args().has("--aquecer-shaders"):
		# O mesmo aquecimento do titulo, esperado ate o fim antes de medir.
		var t_aq := Time.get_ticks_msec()
		AquecimentoDeShaders.iniciar(self)
		while not AquecimentoDeShaders.pronto():
			await arvore.process_frame
		_relatar("aquecimento_s", "%.1f" % ((Time.get_ticks_msec() - t_aq) / 1000.0))
		ReservaDeShaders.marcar()
		await arvore.create_timer(1.0).timeout

	if _alternar > 0:
		await _alternar_suavidade()
		arvore.quit(0)
		return

	_fase = &"parado"
	if Medidor.has_method("marcar_parada"):
		Medidor.marcar_parada(&"parado")
	await arvore.create_timer(_parado).timeout

	# Acelera fora da medida: o que interessa e o regime na velocidade alvo.
	_fase = &""
	_v_alvo = _vel_kmh / 3.6
	var ate := 0.0
	while ate < 12.0 and absf(_carro.velocidade()) < _v_alvo * 0.9:
		await arvore.physics_frame
		ate += PASSO
		_pilotar()
	_relatar("aceleracao_s", "%.1f" % ate)
	if ate >= 12.0:
		_diagnosticar_travado("largada")
	if not _foto_andando.is_empty():
		# `--rastro`: o desfoque pinta o rastro de cada pixel (Lente.depurar 3).
		if OS.get_cmdline_user_args().has("--rastro"):
			Lente.depurar(3)
		var t_foto := 0.0
		while t_foto < 3.0:
			await arvore.physics_frame
			t_foto += PASSO
			_pilotar()
		get_viewport().get_texture().get_image().save_png(_foto_andando)
		_relatar("foto_andando", "%s a %.0f km/h" % [_foto_andando, absf(_carro.velocidade()) * 3.6])
		arvore.quit(0)
		return
	_fase = &"dirigindo"
	ChunkManager.zerar_medidas()
	if Medidor.has_method("marcar_parada"):
		Medidor.marcar_parada(&"dirigindo")
	var t := 0.0
	var z_ini := _carro.global_position.z
	while t < _duracao:
		await arvore.physics_frame
		t += PASSO
		_pilotar()
	_fase = &""
	_estacionar()
	_relatar("percorrido_m", "%.0f media_kmh=%.0f vel_final_kmh=%.0f travado=%s" % [
		absf(_carro.global_position.z - z_ini),
		absf(_carro.global_position.z - z_ini) / _duracao * 3.6,
		absf(_carro.velocidade()) * 3.6,
		jogador.get("travado")])
	# A marca viva redesenha 20 vezes por segundo: e o cenario do engasgo que o
	# `RastroPneu` tinha (24/09/2026). Zero aqui = a rodada nao passou por ele.
	_relatar("marcas_de_pneu", _carro.marcas_de_pneu())

	if _duas_voltas:
		await _segunda_volta(jogador)

	_resumir(&"parado")
	_resumir(&"dirigindo")
	if _duas_voltas:
		_resumir(&"volta2")
	_relatar("re_engatada", "%d quadros" % _quadros_de_re)
	_relatar_streaming()
	_relatar("reserva_de_shaders", "%d presos, guarda custou %.1f ms na rodada" % [
		ReservaDeShaders.presos(), ReservaDeShaders.custo_ms])
	var conta := {}
	for n: String in ReservaDeShaders.novos:
		conta[n] = int(conta.get(n, 0)) + 1
	for n: String in conta:
		_relatar("shader_novo_na_rodada", "%s (x%d)" % [n, conta[n]])
	if _faixas_proc != null:
		# Os dez `_process` com pior quadro na rodada inteira.
		var grupos: Array = _faixas_proc.maximos.keys()
		grupos.sort_custom(func(a: String, b: String) -> bool:
			return float(_faixas_proc.maximos[a]) > float(_faixas_proc.maximos[b]))
		for g: String in grupos.slice(0, 10):
			_relatar("proc_max", "%s pior=%.1f ms quadros_acima_2ms=%d" % [
				g, _faixas_proc.maximos[g], int(_faixas_proc.acima.get(g, 0))])
	if _faixas != null:
		# Os dez `_physics_process` com pior passo na rodada inteira.
		var grupos_f: Array = _faixas.maximos.keys()
		grupos_f.sort_custom(func(a: String, b: String) -> bool:
			return float(_faixas.maximos[a]) > float(_faixas.maximos[b]))
		for g: String in grupos_f.slice(0, 10):
			_relatar("fisica_max", "%s pior=%.1f ms passos_acima_2ms=%d" % [
				g, _faixas.maximos[g], int(_faixas.acima.get(g, 0))])
	# `--medir-pedestre`: o pior passo de fisica de um pedestre, por etapa.
	if Pedestre.medir:
		_relatar("pedestre_pior", str(Pedestre.pior_passo))
		for l: Dictionary in Pedestre.lentos:
			_relatar("pedestre_lento", str(l))
	# `--medir-povoamento`: o pior de cada etapa da Multidao e do Transito.
	for sistema: Node in [Multidao, Transito]:
		var pior: Dictionary = sistema.get(&"pior_ms")
		if pior == null or pior.is_empty():
			continue
		var partes := PackedStringArray()
		for etapa: StringName in pior:
			partes.append("%s=%.1f" % [etapa, pior[etapa]])
		_relatar("povoamento_pior", "%s %s" % [sistema.name, " ".join(partes)])
	if Transito.medir:
		_relatar("transito_fila", "nascidos=%d lentos(>2ms)=%d" % [
			Transito.nascidos_pela_fila, Transito.lentos.size()])
		for l: Dictionary in Transito.lentos:
			_relatar("transito_lento", str(l))

	if not _foto.is_empty():
		await arvore.create_timer(0.5).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png(_foto)
		_relatar("foto", _foto)
	arvore.quit(0)


## Um carro do modelo pedido, sem motorista, e o jogador entra pela porta (a
## mesma chamada da tecla). Fica registrado como estacionado para a porta achar.
func _carro_do_modelo(jogador: Node3D) -> Carro:
	var arvore := get_tree()
	while Transito.raiz == null:
		await arvore.physics_frame
	if not Carroceria.Modelo.has(_modelo):
		_relatar("modelo_invalido", _modelo)
		return null
	var c := Carro.new()
	c.name = "carro_da_bancada"
	c.preparar({}, Vector2i.ZERO, Vector4i.ZERO, 4242)
	c.modelo = Carroceria.Modelo[_modelo]
	Transito.raiz.add_child(c)
	var x := -5 * MalhaUrbana.TAM + MalhaUrbana.meia_pista(MalhaUrbana.Via.AVENIDA) * 0.5
	c.pousar(Vector3(x, Relevo.altura(x, _z0) + 0.6, _z0), 0.0)
	Transito.registrar_estacionado(c)
	jogador.global_position = c.global_position + Vector3(-2.2, 0.3, 0.0)
	await arvore.create_timer(1.0).timeout
	jogador.call("entrar_no_veiculo_mais_perto")
	await arvore.physics_frame
	if jogador.call("carro") != c:
		_relatar("acesso", "falhou")
		return null
	if not c.ligado:
		c.alternar_ignicao()
	_relatar("modelo", _modelo)
	c.tree_exiting.connect(func() -> void:
		_relatar("carro_saiu_da_arvore", "t=%.1fs fase=%s pos=%s" % [
			Time.get_ticks_msec() / 1000.0, _fase, c.global_position])
		print_stack())
	return c


## "(x,z) convidado x3 televisao" — so o que nao e malha, colisao ou oclusor.
func _descrever_chunk(c: Vector2i) -> String:
	var no: Node3D = ChunkManager._carregados.get(c)
	if no == null:
		return "(%d,%d)?" % [c.x, c.y]
	var conta := {}
	var novos := PackedStringArray()
	for filho in no.get_children():
		if filho is MeshInstance3D:
			var mat := String(filho.name).get_slice("@", 0)
			if not _mat_vistos.has(mat):
				_mat_vistos[mat] = true
				novos.append(mat)
			continue
		if filho is StaticBody3D or filho is OccluderInstance3D:
			continue
		var s := filho.get_script() as Script
		var nome: String = String(s.get_global_name()) if s != null and not s.get_global_name().is_empty() 			else filho.get_class()
		conta[nome] = int(conta.get(nome, 0)) + 1
	var partes := PackedStringArray()
	for k: String in conta:
		partes.append("%s%s" % [k, "" if conta[k] == 1 else "x%d" % conta[k]])
	var txt := "(%d,%d) %s" % [c.x, c.y, " ".join(partes)]
	if not novos.is_empty():
		txt += " | materiais novos: " + " ".join(novos)
	return txt


func _segurar_tudo() -> void:
	var t0 := Time.get_ticks_usec()
	var n_arq := 0
	for pasta in ["res://shaders", "res://resources/materials"]:
		for arq in DirAccess.get_files_at(pasta):
			var a := arq.trim_suffix(".remap")
			if a.ends_with(".gdshader") or a.ends_with(".tres"):
				var r := load(pasta + "/" + a)
				if r != null:
					_guardados["arq:" + a] = r
					n_arq += 1
	_varrer_materiais(get_tree().root)
	get_tree().node_added.connect(func(no: Node) -> void:
		if no is GeometryInstance3D:
			_guardar_pendentes.append(no))
	_relatar("segurar", "%d arquivos, %d shaders internos, %.0f ms" % [
		n_arq, _guardados.size() - n_arq, float(Time.get_ticks_usec() - t0) / 1000.0])


func _varrer_materiais(no: Node) -> void:
	if no is GeometryInstance3D:
		_guardar_de(no as GeometryInstance3D)
	for f in no.get_children():
		_varrer_materiais(f)


func _guardar_de(g: GeometryInstance3D) -> void:
	var mats: Array[Material] = [g.material_override, g.material_overlay]
	var mi := g as MeshInstance3D
	if mi != null:
		for i in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(i))
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				mats.append(mi.mesh.surface_get_material(i))
	var gp := g as GPUParticles3D
	if gp != null:
		mats.append(gp.process_material)
		for i in gp.draw_passes:
			var m := gp.get_draw_pass_mesh(i)
			if m != null:
				for s in m.get_surface_count():
					mats.append(m.surface_get_material(s))
	# `get_shader_rid` nao existe para script no 4.7: ShaderMaterial e guardado
	# pelo Shader dele; material gerado (Standard, particula), por instancia —
	# segurar qualquer um com as mesmas opcoes segura o shader interno.
	for m in mats:
		while m != null:
			if m is ShaderMaterial:
				var sh := (m as ShaderMaterial).shader
				if sh != null and not _guardados.has(sh):
					_guardados[sh] = m
			else:
				_guardados[m.get_instance_id()] = m
			m = m.next_pass


## O carro nao saiu do lugar: o que ele toca, onde esta, e o que ha na frente.
func _diagnosticar_travado(onde: String) -> void:
	if not is_instance_valid(_carro):
		_relatar("travou_" + onde, "carro liberado")
		return
	var toca := PackedStringArray()
	for b: Node in _carro.get_colliding_bodies():
		toca.append("%s(%s)" % [b.name, b.get_class() if b.get_script() == null
			else String((b.get_script() as Script).get_global_name())])
	var frente := -_carro.global_transform.basis.z
	var espaco := _carro.get_world_3d().direct_space_state
	var achados := PackedStringArray()
	for alt: float in [0.3, 0.8]:
		var de := _carro.global_position + Vector3.UP * alt
		var q := PhysicsRayQueryParameters3D.create(de, de + frente * 4.0)
		q.exclude = [_carro.get_rid()]
		var r := espaco.intersect_ray(q)
		if not r.is_empty():
			var col: Object = r["collider"]
			achados.append("%.1fm:%s" % [de.distance_to(r["position"] as Vector3),
				(col as Node).get_path() if col is Node else str(col)])
	_relatar("travou_" + onde, "pos=%s vel=%.2f rodas_no_chao=%d marcha=%d toca=[%s] frente=[%s] excecoes=%d" % [
		_carro.global_position, _carro.linear_velocity.length(), _carro.rodas_no_chao(),
		_carro.marcha(), ", ".join(toca), ", ".join(achados),
		_carro.get_collision_exceptions().size()])


## A largada de novo, a cidade em volta remontada, e o mesmo trecho.
func _segunda_volta(jogador: Node3D) -> void:
	var arvore := get_tree()
	_carro.pousar(Vector3(_faixa_x, Relevo.altura(_faixa_x, _z0) + 0.6, _z0), 0.0)
	_estacionar()
	Lente.recomecar()
	var espera := 0.0
	var estavel := 0.0
	var antes := -1
	while espera < 25.0 and estavel < 1.5:
		await arvore.process_frame
		espera += get_process_delta_time()
		var n := ChunkManager.chunks_carregados()
		var ocioso: bool = ChunkManager._em_voo.is_empty() and ChunkManager._prontos.is_empty() 			and ChunkManager._montando.is_empty()
		estavel = estavel + get_process_delta_time() if (n == antes and ocioso) else 0.0
		antes = n
	await arvore.create_timer(2.0).timeout
	var ate := 0.0
	while ate < 12.0 and absf(_carro.velocidade()) < _v_alvo * 0.9:
		await arvore.physics_frame
		ate += PASSO
		_pilotar()
	if ate >= 12.0:
		_diagnosticar_travado("volta2")
	_fase = &"volta2"
	var t := 0.0
	var z_ini := _carro.global_position.z
	while t < _duracao:
		await arvore.physics_frame
		t += PASSO
		_pilotar()
	_fase = &""
	_estacionar()
	_relatar("volta2_percorrido_m", "%.0f" % absf(_carro.global_position.z - z_ini))


## Todo `mat_*.tres` carregado pelo `ChunkManager` e desenhado uma vez na frente
## da camera, nos dois formatos de malha de chunk (com e sem UV2): o experimento
## que diz se o engasgo do bar e material e pipeline de primeira vez.
func _aquecer_materiais() -> void:
	var t0 := Time.get_ticks_usec()
	var nomes: Array[StringName] = []
	for arq in DirAccess.get_files_at("res://resources/materials"):
		var a := arq.trim_suffix(".remap")
		if a.begins_with("mat_") and a.ends_with(".tres"):
			nomes.append(StringName(a.trim_prefix("mat_").trim_suffix(".tres")))
	var cam := get_viewport().get_camera_3d()
	var base := cam.global_transform
	var nos: Array[Node] = []
	var k := 0
	for nome in nomes:
		var mat := ChunkManager._material(nome)
		if mat == null:
			continue
		for com_uv2 in [false, true]:
			var d := PSXMesh.plane_dados(Vector2(0.2, 0.2))
			if com_uv2:
				var uv2 := PackedVector2Array()
				for v in (d["v"] as PackedVector3Array):
					uv2.append(Vector2(v.x, v.y))
				d["uv2"] = uv2
			var mi := MeshInstance3D.new()
			mi.mesh = PSXMesh.dados_para_mesh(d)
			mi.material_override = mat
			add_child(mi)
			# Uma grade de quadradinhos a 3 m, dentro da vista.
			mi.global_transform = Transform3D(base.basis,
				base * Vector3(-1.2 + (k % 24) * 0.1, -0.6 + (k / 24) * 0.1, -3.0))
			nos.append(mi)
			k += 1
	var t_carga := Time.get_ticks_usec()
	var p0 := _pipelines_agora()
	for _q in 4:
		await get_tree().process_frame
	for no in nos:
		no.queue_free()
	await get_tree().process_frame
	_relatar("aquecer", "%d materiais, %d malhas | carga %.0f ms, desenho de 4 quadros %.0f ms, pipelines +%d" % [
		nomes.size(), nos.size(), float(t_carga - t0) / 1000.0,
		float(Time.get_ticks_usec() - t_carga) / 1000.0, _pipelines_agora() - p0])


func _pipelines_agora() -> int:
	var total := 0
	for info in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		total += RenderingServer.get_rendering_info(info)
	return total


## O carro medido atravessa o transito: uma batida para o carro e a medida
## passa a ser de um carro parado. O transito continua existindo e custando.
func _fantasma() -> void:
	for c: Carro in Transito.lista():
		if c != _carro and is_instance_valid(c):
			_carro.add_collision_exception_with(c)


## O custo da interpolacao, parado no carro: janelas de um segundo alternadas,
## com e sem. O primeiro quadro de cada janela sai da conta (a troca em si).
func _alternar_suavidade() -> void:
	var arvore := get_tree()
	var com := PackedFloat32Array()
	var sem := PackedFloat32Array()
	for j in _alternar:
		var ligada := j % 2 == 0
		arvore.physics_interpolation = ligada
		await arvore.process_frame
		await arvore.process_frame
		_fase = &"alternando"
		_dados.erase("alternando/quadro")
		await arvore.create_timer(1.0).timeout
		_fase = &""
		var s := _serie(&"alternando", &"quadro")
		if ligada:
			com.append_array(s)
		else:
			sem.append_array(s)
	com.sort()
	sem.sort()
	_relatar("alternar", "com: n=%d mediana=%.3f p90=%.3f | sem: n=%d mediana=%.3f p90=%.3f | diferenca_mediana=%+.3f ms" % [
		com.size(), _pct(com, 0.5), _pct(com, 0.9), sem.size(), _pct(sem, 0.5), _pct(sem, 0.9),
		_pct(com, 0.5) - _pct(sem, 0.5)])


## Segura a velocidade e o eixo da faixa. O esterco e proporcional ao desvio
## lateral e ao rumo; de frente para -Z, girar a direita DIMINUI o rumo.
## Segura o carro parado: FREIO DE MAO e pedais soltos, nunca o pedal de freio.
##
## O cambio automatico do jogo engata a re quando o carro esta quase parado com
## o freio pisado (`Motor._escolher_sentido`), e ai o freio vira acelerador de
## re. A bancada segurava o carro com `pilotar(0, 1, 0)` na largada e na espera
## da cidade montar: o carro dava re e batia no de tras em toda rodada, e o
## usuario tinha de arrumar na mao (24/09/2026). `re_engatada` no fim conta os
## quadros de re: tem de dar zero.
func _estacionar() -> void:
	_carro.pilotar(0.0, 0.0, 0.0)
	_carro.puxar_freio_de_mao(true)


func _pilotar() -> void:
	_carro.puxar_freio_de_mao(false)
	_fantasma()
	var v := absf(_carro.velocidade())
	var acel := clampf((_v_alvo - v) * 0.6, 0.0, 1.0)
	var freio := clampf((v - _v_alvo - 1.5) * 0.3, 0.0, 1.0)
	var rumo := wrapf(_carro.global_rotation.y, -PI, PI)
	var erro := _faixa_x - _carro.global_position.x
	var esterco := clampf(erro * 0.12 + rumo * 1.6, -1.0, 1.0)
	_carro.pilotar(acel, freio, esterco)


func _process(delta: float) -> void:
	if _carro != null and is_instance_valid(_carro) and bool(_carro.get(&"_re")):
		_quadros_de_re += 1
	var chunks := _chunks_no_quadro
	_chunks_no_quadro = 0
	if _segurar and not _guardar_pendentes.is_empty():
		var lista := _guardar_pendentes
		_guardar_pendentes = []
		for g: Variant in lista:
			if is_instance_valid(g):
				_guardar_de(g as GeometryInstance3D)
	# O delta deste quadro paga o _process do quadro anterior.
	var anterior := Engine.get_process_frames() - 1
	if _desc_do_frame.has(anterior) and not _fase.is_empty():
		_desc_por_quadro["%s/%d" % [_fase, _serie(_fase, &"quadro").size()]] = _desc_do_frame[anterior]
	_desc_do_frame.erase(anterior)
	if not _fase.is_empty():
		_somar(&"descargas", float(_descargas_do_frame.get(anterior, 0)))
	_descargas_do_frame.erase(anterior)
	var nos := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var nasceram := nos - _nos_antes
	_nos_antes = nos
	var fila := 0
	if _sondas != null and not _sem_sondas:
		fila = (_sondas.get("_fila") as Array).size()
	# A fila perde um item no quadro em que uma sonda e mandada refazer.
	var sonda := 1 if fila < _fila_antes else 0
	_fila_antes = fila
	var cam := get_viewport().get_camera_3d()
	var passo := 0.0
	if cam != null:
		# A lente como sai NA TELA: com a interpolacao de fisica ligada, a
		# `global_position` e a do passo de fisica, e nao a desenhada.
		var agora := Suavidade.lente(cam).origin
		if _tem_cam:
			passo = agora.distance_to(_cam_antes)
		_cam_antes = agora
		_tem_cam = true
	if _faixas != null:
		_faixas.fase = _fase
	if _fatias != null:
		_fatias.fase = _fase
	if _fase.is_empty():
		return
	var rid := get_viewport().get_viewport_rid()
	var desf := 1.0
	if _alternar_desfoque and _fase == &"dirigindo":
		# Janelas de um segundo; o quadro da troca sai da conta.
		var janela := int(Time.get_ticks_msec() / 1000) % 2
		Lente.travar_desfoque(-1.0 if janela == 0 else 0.0)
		desf = 1.0 if janela == 0 else 0.0
		if janela != _janela_desf:
			_janela_desf = janela
			desf = -1.0
	_somar(&"desfoque", desf)
	var radar := 1.0
	if _alternar_radar and _fase == &"dirigindo":
		var janela_r := int(Time.get_ticks_msec() / 1000) % 2
		for r: Node in get_tree().root.find_children("*", "HudRadar", true, false):
			r.set(&"ver_radar", janela_r == 0)
		radar = 1.0 if janela_r == 0 else 0.0
		if janela_r != _janela_radar:
			_janela_radar = janela_r
			radar = -1.0
	_somar(&"radar", radar)
	# Quanto tempo de movimento o rastro deste quadro carrega, em ms.
	_somar(&"rastro_ms", Lente.forca_aplicada() * delta * 1000.0)
	_somar(&"quadro", delta * 1000.0)
	var pipes := _pipelines_agora()
	if _pipes_antes >= 0:
		_pipes_fase[_fase] = int(_pipes_fase.get(_fase, 0)) + pipes - _pipes_antes
	_pipes_antes = pipes
	# Do quadro anterior, que e o que `delta` mede.
	_somar(&"script", Marco.script_ms)
	_somar(&"fisica", Marco.fisica_ms)
	for k: String in Marco.seg:
		_somar(StringName("seg_" + k), float(Marco.seg[k]))
	_somar(&"gpu", RenderingServer.viewport_get_measured_render_time_gpu(rid))
	_somar(&"render_cpu", RenderingServer.viewport_get_measured_render_time_cpu(rid))
	_somar(&"chamadas", float(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	_somar(&"chunk", float(chunks))
	var buracos := _buracos_na_vista(cam) if cam != null else Vector2i.ZERO
	_somar(&"buracos", float(buracos.x))
	_somar(&"vistos", float(buracos.y))
	_somar(&"sonda", float(sonda))
	_somar(&"nasceram", float(maxi(nasceram, 0)))
	_somar(&"passo_cam", passo)
	_somar(&"vel", absf(_carro.velocidade()) if _carro != null else 0.0)
	# Carros do transito encostados no carro medido (menos de 5 m): o fantasma
	# atravessa, e a fisica pode estar pagando o contato do outro lado.
	var encostados := 0
	if _carro != null:
		for c: Carro in Transito.lista():
			if c != _carro and is_instance_valid(c) 					and c.global_position.distance_to(_carro.global_position) < 5.0:
				encostados += 1
	_somar(&"encostados", float(encostados))
	_somar(&"transito", float(Transito.vivos()))
	_somar(&"pedestres", float(Multidao.vivos()))
	_somar(&"ativos", float(PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ACTIVE_OBJECTS)))
	_somar(&"pares", float(PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_COLLISION_PAIRS)))
	_somar(&"ilhas", float(PhysicsServer3D.get_process_info(PhysicsServer3D.INFO_ISLAND_COUNT)))
	_amostrar_horizonte()


## Celulas do horizonte, e as que desenham o mesmo chao que um antepassado
## visivel (troca de nivel sem esperar as irmas: desenho dobrado). A cada 15
## quadros, que e um laco em todas as celulas.
func _amostrar_horizonte() -> void:
	_quadro_hz += 1
	var hz: Horizonte = ChunkManager.horizonte
	if hz == null or not is_instance_valid(hz) or not hz.ativo() or _quadro_hz % 15 != 0:
		return
	var dobradas := 0
	var escondidas := 0
	for k: Vector3i in hz._celulas:
		if not (hz._celulas[k] as MeshInstance3D).visible:
			escondidas += 1
			continue
		for nivel in range(k.x + 1, Horizonte.NIVEIS):
			var d := nivel - k.x
			var pai := Vector3i(nivel, k.y >> d, k.z >> d)
			if hz._celulas.has(pai) and (hz._celulas[pai] as MeshInstance3D).visible:
				dobradas += 1
				break
	_somar(&"hz_celulas", float(hz._celulas.size()))
	_somar(&"hz_dobradas", float(dobradas))
	_somar(&"hz_escondidas", float(escondidas))


## Chunks que a camera veria agora e que nao existem: dentro do frustum, com a
## borda mais perto que o alcance visivel (o fim da nevoa, ou o alcance de
## desenho sem nevoa), e nem completos nem casca. E o "buraco na vista" do
## Horizonte: um chunk aparecendo do nada. Devolve (buracos, vistos).
func _buracos_na_vista(cam: Camera3D) -> Vector2i:
	var preset: FogPreset = ChunkManager._preset if ChunkManager._preset != null 		else Settings.fog_preset()
	var alcance := ChunkManager.alcance_de_desenho()
	if preset.fog_enabled:
		alcance = minf(alcance, preset.fog_end)
	var planos := cam.get_frustum()
	var o := cam.global_position
	var centro := ChunkManager.coord_de(o)
	var n := ceili(alcance / ChunkManager.TAM) + 1
	var buracos := 0
	var vistos := 0
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var c := centro + Vector2i(dx, dz)
			var x0 := c.x * ChunkManager.TAM
			var z0 := c.y * ChunkManager.TAM
			var ex := maxf(maxf(x0 - o.x, o.x - (x0 + ChunkManager.TAM)), 0.0)
			var ez := maxf(maxf(z0 - o.z, o.z - (z0 + ChunkManager.TAM)), 0.0)
			if ex * ex + ez * ez > alcance * alcance:
				continue
			var caixa := AABB(Vector3(x0, o.y - 45.0, z0),
				Vector3(ChunkManager.TAM, 90.0, ChunkManager.TAM))
			if not _no_frustum(planos, caixa):
				continue
			vistos += 1
			if not ChunkManager.esta_visivel(c):
				buracos += 1
	return Vector2i(buracos, vistos)


## A caixa toca o frustum? Os planos da camera apontam para FORA: se ate o canto
## mais para dentro de algum plano esta do lado de fora, a caixa inteira esta.
static func _no_frustum(planos: Array[Plane], caixa: AABB) -> bool:
	for p: Plane in planos:
		var canto := caixa.position
		if p.normal.x < 0.0:
			canto.x += caixa.size.x
		if p.normal.y < 0.0:
			canto.y += caixa.size.y
		if p.normal.z < 0.0:
			canto.z += caixa.size.z
		if p.distance_to(canto) > 0.0:
			return false
	return true


func _relatar_streaming() -> void:
	for fase: StringName in [&"parado", &"dirigindo", &"volta2"]:
		var b := _serie(fase, &"buracos")
		if b.is_empty():
			continue
		var com := 0
		var soma := 0.0
		var pior := 0.0
		for v: float in b:
			if v > 0.0:
				com += 1
			soma += v
			pior = maxf(pior, v)
		var vi := _serie(fase, &"vistos").duplicate()
		vi.sort()
		_relatar("%s.buracos" % fase, "quadros_com_buraco=%d de %d chunk_quadros=%.0f pior=%.0f vistos_mediana=%.0f" % [
			com, b.size(), soma, pior, _pct(vi, 0.5)])
	for fase_hz: StringName in [&"parado", &"dirigindo"]:
		var cel := _serie(fase_hz, &"hz_celulas").duplicate()
		if cel.is_empty():
			continue
		cel.sort()
		var dob := _serie(fase_hz, &"hz_dobradas").duplicate()
		dob.sort()
		var esc := _serie(fase_hz, &"hz_escondidas").duplicate()
		esc.sort()
		var com_dobra := 0
		for v: float in dob:
			if v > 0.0:
				com_dobra += 1
		_relatar("%s.horizonte" % fase_hz, "amostras=%d celulas_mediana=%.0f dobradas: com=%d mediana=%.0f p95=%.0f pior=%.0f | escondidas mediana=%.0f pior=%.0f" % [
			cel.size(), _pct(cel, 0.5), com_dobra, _pct(dob, 0.5), _pct(dob, 0.95),
			dob[dob.size() - 1], _pct(esc, 0.5), esc[esc.size() - 1]])
	var r := ChunkManager.raios()
	_relatar("streaming", "raio_sim=%d raio_visual=%d alcance=%.0fm cascas=%d carregados=%d antigo=%s adiantados_usados=%d promovidos=%d rebaixados=%d" % [
		r.x, r.y, ChunkManager.alcance_de_desenho(), ChunkManager.cascas(),
		ChunkManager.chunks_carregados(), ChunkManager.prioridade_antiga,
		ChunkManager.medida_adiantados_usados, ChunkManager.medida_promovidos,
		ChunkManager.medida_rebaixados])
	for par: Array in [["atraso_ms", ChunkManager.medida_atraso_ms],
			["thread_ms", ChunkManager.medida_tarefa_ms]]:
		var s: PackedFloat32Array = (par[1] as PackedFloat32Array).duplicate()
		if s.is_empty():
			_relatar("streaming.%s" % par[0], "n=0")
			continue
		s.sort()
		_relatar("streaming.%s" % par[0], "n=%d mediana=%.0f p95=%.0f pior=%.0f" % [
			s.size(), _pct(s, 0.5), _pct(s, 0.95), s[s.size() - 1]])


func _somar(chave: StringName, valor: float) -> void:
	var k := "%s/%s" % [_fase, chave]
	# Packed*Array lido de Dictionary e copia: o append tem de voltar para la.
	var serie: PackedFloat32Array = _dados.get(k, PackedFloat32Array())
	serie.append(valor)
	_dados[k] = serie


func _serie(fase: StringName, chave: StringName) -> PackedFloat32Array:
	return _dados.get("%s/%s" % [fase, chave], PackedFloat32Array())


func _resumir(fase: StringName) -> void:
	var q := _serie(fase, &"quadro")
	if q.is_empty():
		_relatar(fase, "sem amostras")
		return
	for chave: StringName in [&"quadro", &"script", &"fisica", &"render_cpu", &"gpu", &"chamadas"]:
		var s := _serie(fase, chave).duplicate()
		s.sort()
		_relatar("%s.%s" % [fase, chave], "n=%d mediana=%.2f p95=%.2f p99=%.2f pior=%.2f" % [
			s.size(), _pct(s, 0.5), _pct(s, 0.95), _pct(s, 0.99), s[s.size() - 1]])
	var ord := q.duplicate()
	ord.sort()
	var mediana := _pct(ord, 0.5)
	var acima16 := 0
	var acima33 := 0
	for ms: float in q:
		if ms > 16.7:
			acima16 += 1
		if ms > 33.3:
			acima33 += 1
	_relatar("%s.fps_mediana" % fase, "%.0f  acima_16.7ms=%d  acima_33ms=%d" % [
		1000.0 / maxf(mediana, 0.001), acima16, acima33])

	# Quem estava no quadro caro. "Caro" e o dobro da mediana e pelo menos 12 ms.
	var chunk := _serie(fase, &"chunk")
	var sonda := _serie(fase, &"sonda")
	var nasc := _serie(fase, &"nasceram")
	var limite := maxf(mediana * 2.0, 12.0)
	var caros := 0
	var com_chunk := 0
	var com_sonda := 0
	var com_nasc := 0
	var sem_dono := 0
	var lista := PackedStringArray()
	# O custo de um quadro aparece no delta do quadro SEGUINTE, entao o evento
	# do quadro i conta para o delta de i ou de i + 1.
	for i in q.size():
		if q[i] < limite:
			continue
		caros += 1
		var c := chunk[i] > 0 or (i > 0 and chunk[i - 1] > 0)
		var s := sonda[i] > 0 or (i > 0 and sonda[i - 1] > 0)
		var n := nasc[i] >= 4 or (i > 0 and nasc[i - 1] >= 4)
		if c:
			com_chunk += 1
		if s:
			com_sonda += 1
		if n:
			com_nasc += 1
		if not (c or s or n):
			sem_dono += 1
		if lista.size() < 24:
			lista.append("%.0f%s%s%s" % [q[i], "c" if c else "", "s" if s else "",
				"n" if n else ""])
	_relatar("%s.caros" % fase, "limite=%.1fms n=%d com_chunk=%d com_sonda=%d com_nascimento=%d sem_dono=%d" % [
		limite, caros, com_chunk, com_sonda, com_nasc, sem_dono])
	_relatar("%s.caros_lista" % fase, " ".join(lista))
	# A linha do tempo de um quadro tipico: medianas de cada pedaco.
	var med := PackedStringArray()
	for chave: StringName in [&"quadro", &"script", &"seg_pos", &"seg_pos_fila", &"seg_desenho",
			&"seg_entre", &"seg_fisica", &"gpu"]:
		var s := _serie(fase, chave).duplicate()
		s.sort()
		med.append("%s=%.2f" % [chave, _pct(s, 0.5)])
	_relatar("%s.linha_mediana" % fase, " ".join(med))
	# Os cinco quadros mais caros, divididos: de que linha e o tempo.
	var sc := _serie(fase, &"script")
	var fi := _serie(fase, &"fisica")
	var rc := _serie(fase, &"render_cpu")
	var gp := _serie(fase, &"gpu")
	var idx: Array[int] = []
	for i in q.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool: return q[a] > q[b])
	for i in idx.slice(0, 5):
		_relatar("%s.dividido" % fase, "#%d %.0f ms = script %.1f fisica %.1f render_cpu %.1f gpu %.1f | seguinte: render_cpu %.1f gpu %.1f" % [
			i, q[i], sc[i], fi[i], rc[i], gp[i],
			rc[i + 1] if i + 1 < rc.size() else -1.0, gp[i + 1] if i + 1 < gp.size() else -1.0])
		if _faixas_proc != null:
			_relatar("%s.dividido_script" % fase, "#%d %s" % [i, _faixas_proc.caros.get(i, "-")])
		_relatar("%s.dividido_linha" % fase, "#%d script_anterior %.1f | pos %.1f (ate o timer %.1f) desenho %.1f entre %.1f fisica %.1f | descargas %d" % [
			i, sc[i], _serie(fase, &"seg_pos")[i], _serie(fase, &"seg_pos_fila")[i], _serie(fase, &"seg_desenho")[i],
			_serie(fase, &"seg_entre")[i], _serie(fase, &"seg_fisica")[i],
			int(_serie(fase, &"descargas")[i])])
	# Os quadros caros com chunk: o que o chunk trouxe.
	var n_desc := 0
	for i in q.size():
		if q[i] < maxf(limite, 25.0) or n_desc >= 12:
			continue
		for j in [i]:
			var d: String = _desc_por_quadro.get("%s/%d" % [fase, j], "")
			if not d.is_empty():
				_relatar("%s.caro_chunk" % fase, "%.0f ms <- %s" % [q[i], d])
				n_desc += 1
				break
	var soma_chunk := 0.0
	var soma_sonda := 0.0
	for x: float in chunk:
		soma_chunk += x
	for x: float in sonda:
		soma_sonda += x
	_relatar("%s.eventos" % fase, "chunks=%d sondas_refeitas=%d pipelines=%d" % [soma_chunk, soma_sonda,
		int(_pipes_fase.get(fase, 0))])

	# Fisica contra carro encostado: o estado lento e de fisica (24/09/2026).
	var fis := _serie(fase, &"fisica")
	var enc := _serie(fase, &"encostados")
	var com_enc := PackedFloat32Array()
	var sem_enc := PackedFloat32Array()
	for i in mini(fis.size(), enc.size()):
		if enc[i] > 0.0:
			com_enc.append(fis[i])
		else:
			sem_enc.append(fis[i])
	com_enc.sort()
	sem_enc.sort()
	var tr := _serie(fase, &"transito").duplicate()
	var pe := _serie(fase, &"pedestres").duplicate()
	tr.sort()
	pe.sort()
	var at := _serie(fase, &"ativos").duplicate()
	var pa := _serie(fase, &"pares").duplicate()
	var il := _serie(fase, &"ilhas").duplicate()
	at.sort()
	pa.sort()
	il.sort()
	_relatar("%s.servidor_fisica" % fase, "ativos mediana=%.0f max=%.0f | pares mediana=%.0f max=%.0f | ilhas mediana=%.0f" % [
		_pct(at, 0.5), _pct(at, 1.0), _pct(pa, 0.5), _pct(pa, 1.0), _pct(il, 0.5)])
	if _faixas != null:
		_relatar("%s.faixas" % fase, _faixas.relatorio(fase, q.size()))
	if _fatias != null:
		_relatar("%s.fatias_carro" % fase, _fatias.relatorio(fase, q.size()))
	if _alternar_desfoque and fase == &"dirigindo":
		_comparar_desfoque(fase)
	if _alternar_radar and fase == &"dirigindo":
		var rd := _serie(fase, &"radar")
		for chave: StringName in [&"quadro", &"seg_pos"]:
			var s := _serie(fase, chave)
			var com := PackedFloat32Array()
			var sem := PackedFloat32Array()
			# O "pos" de um quadro cai no delta do seguinte: a janela e a do anterior.
			for i in range(1, mini(s.size(), rd.size())):
				if rd[i - 1] > 0.5 and rd[i] > 0.5:
					com.append(s[i])
				elif rd[i - 1] > -0.5 and rd[i - 1] < 0.5 and rd[i] > -0.5 and rd[i] < 0.5:
					sem.append(s[i])
			com.sort()
			sem.sort()
			_relatar("%s.radar_%s" % [fase, chave], "com: n=%d mediana=%.2f p95=%.2f p99=%.2f pior=%.2f | sem: n=%d mediana=%.2f p95=%.2f p99=%.2f pior=%.2f" % [
				com.size(), _pct(com, 0.5), _pct(com, 0.95), _pct(com, 0.99), com[com.size() - 1] if com.size() > 0 else 0.0,
				sem.size(), _pct(sem, 0.5), _pct(sem, 0.95), _pct(sem, 0.99), sem[sem.size() - 1] if sem.size() > 0 else 0.0])
	# O rastro em regime (obturador cheio, acima de 16 m/s): o pico contra a
	# mediana e o "clarao" que um quadro longo acendia.
	var rastro := PackedFloat32Array()
	var vel_r := _serie(fase, &"vel")
	var r_ms := _serie(fase, &"rastro_ms")
	for i in mini(r_ms.size(), vel_r.size()):
		if vel_r[i] > 16.5:
			rastro.append(r_ms[i])
	if not rastro.is_empty():
		rastro.sort()
		_relatar("%s.rastro_ms" % fase, "n=%d mediana=%.2f p99=%.2f pior=%.2f pico/mediana=%.1f" % [
			rastro.size(), _pct(rastro, 0.5), _pct(rastro, 0.99), rastro[rastro.size() - 1],
			rastro[rastro.size() - 1] / maxf(_pct(rastro, 0.5), 0.001)])
	_relatar("%s.fisica_x_encostado" % fase, "com carro encostado: n=%d mediana=%.2f | sem: n=%d mediana=%.2f | transito mediana=%.0f pedestres mediana=%.0f" % [
		com_enc.size(), _pct(com_enc, 0.5), sem_enc.size(), _pct(sem_enc, 0.5),
		_pct(tr, 0.5), _pct(pe, 0.5)])

	# Cadencia: quadros desenhados com a camera parada enquanto o carro anda.
	var passo := _serie(fase, &"passo_cam")
	var vel := _serie(fase, &"vel")
	var andando := 0
	var parados := 0
	var razoes := PackedFloat32Array()
	for i in passo.size():
		if vel[i] < 5.0:
			continue
		andando += 1
		if passo[i] < 0.0005:
			parados += 1
		# Quanto a camera andou neste quadro sobre o que devia ter andado.
		razoes.append(passo[i] / maxf(vel[i] * q[i] * 0.001, 0.0001))
	if andando > 0:
		razoes.sort()
		_relatar("%s.cadencia" % fase, "quadros_andando=%d camera_parada=%d (%.0f%%) passo/esperado p10=%.2f mediana=%.2f p90=%.2f" % [
			andando, parados, 100.0 * parados / andando,
			_pct(razoes, 0.1), _pct(razoes, 0.5), _pct(razoes, 0.9)])


## Quadro e GPU com e sem obturador, nas janelas alternadas da mesma rodada.
func _comparar_desfoque(fase: StringName) -> void:
	var d := _serie(fase, &"desfoque")
	for chave: StringName in [&"quadro", &"gpu", &"fisica"]:
		var s := _serie(fase, chave)
		var com := PackedFloat32Array()
		var sem := PackedFloat32Array()
		for i in mini(s.size(), d.size()):
			if d[i] > 0.5:
				com.append(s[i])
			elif d[i] > -0.5:
				sem.append(s[i])
		com.sort()
		sem.sort()
		_relatar("%s.desfoque_%s" % [fase, chave], "com: n=%d mediana=%.2f p95=%.2f | sem: n=%d mediana=%.2f p95=%.2f" % [
			com.size(), _pct(com, 0.5), _pct(com, 0.95), sem.size(), _pct(sem, 0.5), _pct(sem, 0.95)])


static func _pct(ordenado: PackedFloat32Array, q: float) -> float:
	if ordenado.is_empty():
		return 0.0
	return ordenado[clampi(int(round(q * (ordenado.size() - 1))), 0, ordenado.size() - 1)]


static func _achar(no: Node, classe: String) -> Node:
	var script := no.get_script() as Script
	if script != null and script.get_global_name() == classe:
		return no
	for filho: Node in no.get_children():
		var achado := _achar(filho, classe)
		if achado != null:
			return achado
	return null
