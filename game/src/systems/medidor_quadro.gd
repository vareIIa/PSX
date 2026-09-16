## Autoload. Medida de quadro do PLANO_AAA_4K (criterios A3, A4, A5, A6, A10).
##
## Dorme sem `--medir`: sem a flag, nao processa nada e nao custa quadro nenhum.
##
##     godot --path game -- --medir=medida.csv --rota=noite_chuva
##     godot --path game -- --medir                  (so o resumo no terminal)
##     --medir-cada=N                                (uma amostra a cada N quadros)
##
## Por que nao dentro do `CaptureTool`: o `--stats` de la responde "esta rapido?"
## com fps e pior quadro, e mais nada. Para decidir oclusao, instanciamento,
## 4K e texturas 2K e preciso saber CHAMADAS DE DESENHO, TRIANGULOS, VRAM e
## quanto do quadro e CPU e quanto e GPU — senao a fase seguinte mexe no que nao
## era o gargalo. (E o CaptureTool tem trabalho nao commitado de outra sessao.)
##
## Uma medida que so este medidor da: compilacao de PIPELINE por quadro. O
## engasgo de carga vira duas causas diferentes conforme esse numero suba ou nao
## junto com o quadro ruim — shader compilando, ou CPU montando cidade.
##
## O CSV sai com uma linha por amostra e uma coluna por grandeza; o resumo sai
## no terminal em `[medidor]`, com mediana, 95, 99 e pior, separando a CARGA
## (o primeiro segundo) do REGIME (o resto), porque sao dois defeitos distintos
## e a media junta os dois num numero que nao quer dizer nada.
class_name MedidorQuadro
extends Node

## Acima disto o quadro e engasgo, e sai no terminal na hora, com a causa
## provavel ao lado. 33,3 ms e o alvo do criterio A3 para a carga da cidade.
const ENGASGO_MS := 33.3
## Quanto tempo, no comeco, conta como CARGA e nao como regime.
const CARGA_S := 1.0
## Colunas do CSV, na ordem em que sao escritas.
const COLUNAS := "quadro,t_s,quadro_ms,processo_ms,fisica_ms,render_cpu_ms," \
	+ "render_gpu_ms,chamadas,primitivas,objetos,vram_mb,textura_mb,buffer_mb," \
	+ "pipelines,memoria_mb,nos,chunks,chunks_novos,parada"

var _ligado := false
var _arquivo := ""
var _cada := 1
var _parada := &"" ## Nome da parada da rota, se houver. Ver `marcar_parada`.

var _t0 := 0
var _quadros := 0
var _pipelines_antes := 0
var _rid: RID
## Chunks que viraram no neste quadro, contados pelo sinal do ChunkManager.
##
## O que a linha do CSV guarda e o do quadro ANTERIOR, de proposito: `delta` mede
## a duracao do quadro que acabou, e o ChunkManager materializa antes deste
## `_process` rodar. Atribuir o chunk do quadro corrente ao `delta` corrente
## acusaria o quadro seguinte ao caro — o inocente.
var _chunks_no_quadro := 0
var _chunks_antes := 0
## Quando o primeiro quadro desenhou, contado desde o inicio do motor.
##
## O `delta` do primeiro quadro nao serve para isso: ele vem CEIFADO em 150,000
## ms, identico em execucao com e sem janela. O que vale e o relogio.
var _primeiro_quadro_ms := 0
## Quando este autoload ficou pronto.
##
## Este e o PRIMEIRO autoload do `project.godot`, e isso divide a largada em
## duas metades medidas: ate aqui e motor mais a INSTANCIACAO de tudo (compilar
## script, `_init`); daqui ao primeiro quadro sao os `_ready` de todos os
## autoloads, a montagem da cena e o primeiro desenho.
##
## Nao da para dividir mais de dentro de uma execucao so: quando o `_ready` do
## primeiro autoload roda, os 26 filhos de /root JA existem (medido), inclusive a
## cena principal — o motor instancia tudo e so depois propaga `_ready`. Por isso
## `node_added` nao ve nada, e o custo de cada autoload sai de execucoes
## separadas, em `tools/medir_largada.sh`.
var _pronto_ms := 0
var _engasgos := 0
var _engasgos_com_chunk := 0

var _linhas: PackedStringArray = []
## Uma coluna, guardada a parte, porque o resumo a percorre varias vezes.
var _ms: PackedFloat32Array = []
var _t: PackedFloat32Array = []
var _chamadas: PackedInt32Array = []
var _primitivas: PackedInt64Array = []
var _paradas: PackedStringArray = []


func _ready() -> void:
	# Imune a pausa, como o CaptureTool: a rota pode abrir um painel que pausa a
	# arvore, e um medidor que para junto perde justamente o quadro caro.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--medir":
			_ligado = true
		elif arg.begins_with("--medir="):
			_ligado = true
			_arquivo = arg.trim_prefix("--medir=")
		elif arg.begins_with("--medir-cada="):
			_cada = maxi(1, arg.trim_prefix("--medir-cada=").to_int())
	set_process(_ligado)
	# A rota vive aqui dentro, e nao num autoload proprio: ela so existe com
	# `--rota=`, e quem a usa sempre quer o medidor junto.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rota="):
			var rota := RotaCaptura.new()
			rota.name = "Rota"
			rota.medidor = self
			add_child(rota)
			break
	if not _ligado:
		return
	# A medida de CPU e GPU do viewport nao vem de graca; so e ligada aqui.
	var vp := get_viewport()
	if vp != null:
		_rid = vp.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_rid, true)
	# Sem vsync, senao a medida e do monitor e nao do jogo: com vsync toda parada
	# desta cidade devolve exatamente 6,1 ms (165 Hz), inclusive um interior de
	# 24 chamadas de desenho. Nao da para ver folga nem perda assim.
	if not OS.get_cmdline_user_args().has("--medir-com-vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_t0 = Time.get_ticks_usec()
	_pipelines_antes = _pipelines()
	# Quem materializa chunk avisa. Sem isto, "o quadro de 66 ms" e um numero sem
	# reu: com isto, da para dizer se ele cai SEMPRE no quadro em que um chunk
	# virou no, que e outra frase.
	var cm := get_node_or_null(^"/root/ChunkManager")
	if cm != null and cm.has_signal(&"chunk_carregado"):
		cm.connect(&"chunk_carregado", _ao_carregar_chunk)
	_pronto_ms = Time.get_ticks_msec()
	# A placa entra no relatorio porque esta maquina tem duas: a RX 9070 XT e a
	# integrada. Duas medidas do mesmo quadro deram 2,8 ms e 7,1 ms, e a unica
	# diferenca era em qual delas o Godot abriu — sem esta linha, a conclusao
	# natural (e falsa) seria que a mudanca do meio custou 4 ms.
	print("[medidor] ligado%s | %s, driver %s"
		% ["" if _arquivo.is_empty() else " -> " + _arquivo,
			RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_api_version()])


func _ao_carregar_chunk(_coord: Vector2i) -> void:
	_chunks_no_quadro += 1


## Quem materializa chunk avisa. Sem isto, "o quadro de 66 ms" e um numero sem
## reu: com isto, da para dizer se ele cai no quadro em que um chunk virou no,
## que e outra frase.
##
## Tardia porque este autoload e o PRIMEIRO da lista, e no `_ready` dele o
## ChunkManager ainda nao esta pronto.
func _ligar_no_chunk_manager() -> void:
	var cm := get_node_or_null(^"/root/ChunkManager")
	if cm == null or not cm.has_signal(&"chunk_carregado"):
		return
	if not cm.is_connected(&"chunk_carregado", _ao_carregar_chunk):
		cm.connect(&"chunk_carregado", _ao_carregar_chunk)


## A rota diz em que parada o jogo esta; o resumo separa por parada.
func marcar_parada(nome: StringName) -> void:
	_parada = nome


func _process(delta: float) -> void:
	_quadros += 1
	if _quadros == 1:
		_primeiro_quadro_ms = Time.get_ticks_msec()
		_ligar_no_chunk_manager()
	var pipes := _pipelines()
	var novas := pipes - _pipelines_antes
	_pipelines_antes = pipes
	var ms := delta * 1000.0
	var chunks_novos := _chunks_antes
	_chunks_antes = _chunks_no_quadro
	_chunks_no_quadro = 0
	if ms >= ENGASGO_MS:
		_engasgos += 1
		if chunks_novos > 0:
			_engasgos_com_chunk += 1
		# Na hora, e nao so no CSV: quem olha o terminal precisa ver o engasgo
		# com a causa ao lado.
		print("[engasgo] quadro=%d t=%.2fs %.1f ms pipelines=+%d chunks_novos=%d chamadas=%d nos=%d%s"
			% [_quadros, _agora(), ms, novas, chunks_novos,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				"" if _parada.is_empty() else " parada=" + _parada])
	if _quadros % _cada != 0:
		return
	_amostrar(ms, novas, chunks_novos)


func _amostrar(ms: float, pipes_novas: int, chunks_novos: int) -> void:
	var t := _agora()
	var chamadas := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitivas := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var objetos := RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	_ms.append(ms)
	_t.append(t)
	_chamadas.append(chamadas)
	_primitivas.append(primitivas)
	_paradas.append(String(_parada))
	if _arquivo.is_empty():
		return
	_linhas.append("%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%.1f,%.1f,%.1f,%d,%.1f,%d,%d,%d,%s" % [
		_quadros, t, ms,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.viewport_get_measured_render_time_cpu(_rid)
			+ RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(_rid),
		chamadas, primitivas, objetos,
		_mb(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED),
		_mb(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),
		_mb(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED),
		pipes_novas,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		_chunks(), chunks_novos, String(_parada)])


func _exit_tree() -> void:
	if not _ligado or _ms.is_empty():
		return
	_resumir()
	if _arquivo.is_empty():
		return
	var dir := _arquivo.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(_arquivo, FileAccess.WRITE)
	if f == null:
		push_error("[medidor] nao consegui gravar %s" % _arquivo)
		return
	f.store_line(COLUNAS)
	for l: String in _linhas:
		f.store_line(l)
	f.close()
	print("[medidor] %d amostras em %s" % [_linhas.size(), _arquivo])


func _resumir() -> void:
	var carga: PackedFloat32Array = []
	var regime: PackedFloat32Array = []
	for i in _ms.size():
		if _t[i] <= CARGA_S:
			carga.append(_ms[i])
		else:
			regime.append(_ms[i])
	print("[medidor] %d quadros em %.1f s" % [_quadros, _agora()])
	print("[medidor] largada: motor+autoloads %d ms, cena ate o 1o quadro %d ms, total %d ms"
		% [_pronto_ms, _primeiro_quadro_ms - _pronto_ms, _primeiro_quadro_ms])
	print("[medidor] engasgos (>= %.0f ms): %d, dos quais %d no quadro de um chunk novo"
		% [ENGASGO_MS, _engasgos, _engasgos_com_chunk])
	_linha_de_tempo("carga (ate %.0f s)" % CARGA_S, carga)
	_linha_de_tempo("regime", regime)
	print("[medidor] chamadas mediana=%d pior=%d | triangulos mediana=%d pior=%d"
		% [_mediana_i(_chamadas), _maior_i(_chamadas),
			_mediana_l(_primitivas), _maior_l(_primitivas)])
	# Por parada: e o que permite comparar a mesma vista antes e depois de uma
	# fase, sem que a media de uma rota inteira esconda a rua que piorou.
	var vistas: Array[String] = []
	for p: String in _paradas:
		if not p.is_empty() and not vistas.has(p):
			vistas.append(p)
	for p: String in vistas:
		var so: PackedFloat32Array = []
		var ch := 0
		var n := 0
		for i in _ms.size():
			if _paradas[i] != p:
				continue
			so.append(_ms[i])
			ch += _chamadas[i]
			n += 1
		_linha_de_tempo("parada %s (chamadas %d)" % [p, ch / maxi(n, 1)], so)


func _linha_de_tempo(rotulo: String, v: PackedFloat32Array) -> void:
	if v.is_empty():
		return
	var ordenado := v.duplicate()
	ordenado.sort()
	print("[medidor] %-28s n=%4d  mediana=%5.1f ms  95=%5.1f  99=%5.1f  pior=%6.1f  fps_mediana=%d"
		% [rotulo, ordenado.size(), _pct(ordenado, 0.5), _pct(ordenado, 0.95),
			_pct(ordenado, 0.99), ordenado[ordenado.size() - 1],
			int(round(1000.0 / maxf(_pct(ordenado, 0.5), 0.001)))])


static func _pct(ordenado: PackedFloat32Array, q: float) -> float:
	if ordenado.is_empty():
		return 0.0
	return ordenado[clampi(int(q * (ordenado.size() - 1)), 0, ordenado.size() - 1)]


func _agora() -> float:
	return float(Time.get_ticks_usec() - _t0) / 1_000_000.0


func _pipelines() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW) \
		+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)


func _mb(info: RenderingServer.RenderingInfo) -> float:
	return float(RenderingServer.get_rendering_info(info)) / 1048576.0


## O medidor nao exige a cidade: pela arvore, e nao pelo autoload, ele tambem
## mede uma bancada ou um interior sem streaming nenhum.
func _chunks() -> int:
	var cm := get_node_or_null(^"/root/ChunkManager")
	if cm == null:
		return 0
	return int(cm.call("chunks_carregados"))


static func _mediana_i(v: PackedInt32Array) -> int:
	if v.is_empty():
		return 0
	var o := v.duplicate()
	o.sort()
	return o[o.size() / 2]


static func _maior_i(v: PackedInt32Array) -> int:
	var m := 0
	for x: int in v:
		m = maxi(m, x)
	return m


static func _mediana_l(v: PackedInt64Array) -> int:
	if v.is_empty():
		return 0
	var o := v.duplicate()
	o.sort()
	return o[o.size() / 2]


static func _maior_l(v: PackedInt64Array) -> int:
	var m := 0
	for x: int in v:
		m = maxi(m, x)
	return m
