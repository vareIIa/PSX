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
	&"asfalto", &"asfalto_faixa", &"asfalto_remendo", &"marca_via", &"paralelepipedo",
	&"calcada", &"calcada_ladrilho", &"meio_fio",
	&"grama", &"terra", &"areia", &"leito", &"piso",
	# Vidro da loja da rua: transparente, nao corta luz nenhuma.
	&"vitrine_loja",
]

## Ate onde vai o balde "material@perto" (flor, vaso, comodo atras da janela
## aberta), em metros ate o centro do chunk: miudeza que custa triangulo e nao
## se le de longe.
const ALCANCE_PERTO := 40.0

## Histerese: descarrega um anel alem do que carrega, senao andar em cima da
## fronteira faz o mesmo chunk carregar e descarregar a cada passo.
const FOLGA_DESCARGA := 1

## Teto de construcoes simultaneas na piscina de threads.
const MAX_EM_VOO := 4

## Prioridade de carga (Horizonte, passo 1). A fila deixa de ser "do mais perto
## para o mais longe" e passa a ser "do que o jogador vai ver primeiro": a
## distancia ate a BORDA do chunk, menos o que a velocidade anda na direcao dele
## em ANTECIPACAO_S, menos BONUS_OLHAR na direcao da camera. E o que o streaming
## de um mundo aberto faz: nao descarrega o que esta atras (virar a camera e
## instantaneo), mas chega primeiro ao que esta na frente.
const ANTECIPACAO_S := 2.0
const BONUS_OLHAR := 16.0
## O anel do jogador (chao debaixo dos pes) passa na frente de tudo.
const CHAO_PRIMEIRO := 100000.0
## Acima desta velocidade (m/s) o anel logo alem do raio, na direcao do
## movimento, ja e construido na thread: quando o jogador cruza a fronteira os
## dados estao prontos e so falta pendurar.
const VEL_ANTECIPAR := 4.0
## Cone da antecipacao: cosseno do angulo entre a velocidade e o chunk (60 graus).
const COS_ANTECIPAR := 0.5
## Salto de posicao que zera a velocidade medida (teleporte, troca de alvo).
const SALTO_M := 30.0
## Constante de tempo da media da velocidade, em segundos.
const SUAVE_VEL := 0.25

## O que a tarefa da thread monta de malha. O chunk completo leva todas; a CASCA
## (anel visual) nao leva o balde @perto, que nao se ve de longe; a promocao de
## casca a completo so leva o @perto, porque o resto ja esta pendurado.
enum Modo { TUDO, CASCA, PERTO }

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
## Liga quem precisa do chao do chunk depois de montado (GramaViva).
var guardar_superficies := false
## coord -> id da tarefa na piscina. Precisa do id para esperar no desligamento.
var _em_voo: Dictionary[Vector2i, int] = {}
var _prontos: Array[Dictionary] = []
## Chunks virando no aos poucos (`MontagemDeChunk`). So contam como carregados
## quando a montagem termina.
var _montando: Dictionary[Vector2i, MontagemDeChunk] = {}
## `--montagem-inteira`: todo chunk vira no num quadro so, como ate 24/09/2026.
## E o par da bancada.
var montagem_inteira := false
## As ArrayMesh do chunk saem prontas da thread do ChunkBuilder (`_tarefa`): a
## conversao dos arrays para o formato da GPU sai do fio principal, e a
## montagem so pendura. `--malhas-no-fio` volta a montar no fio principal: e o
## par da bancada.
var malhas_na_thread := true
var _mutex := Mutex.new()

var _materiais: Dictionary[StringName, ShaderMaterial] = {}
var _coord_atual := Vector2i(2147483647, 0)
## Chunk sendo montado agora. O item precisa saber para registrar no WorldState
## que ja foi pego.
var _coord_do_prop := Vector2i.ZERO
var _raio_carga: int = 2
var _alcance_render: float = 26.0

## Raio de simulacao e raio visual (Horizonte, passo 1).
##
## `_raio_carga` e o de SIMULACAO: chunk completo, com colisao, prop e gente, e
## so ele conta como carregado — mapa, transito, multidao e blitz perguntam
## `esta_carregado` e continuam vendo exatamente o mesmo conjunto.
##
## Entre ele e `_raio_visual` o chunk entra como CASCA: as malhas fundidas (sem
## o balde @perto) e o oclusor, nada que simule. Quando o jogador chega, a casca
## e promovida (colisao, @perto e props entram no mesmo no); quando se afasta,
## volta a casca. E o anel que deixa a distancia de visao crescer sem pagar
## cidade inteira.
##
## Padrao: `raio_visual_m = 0`, o raio visual e o de simulacao e nao existe
## casca nenhuma — a imagem e a mesma de antes. `--raio-visual=METROS` abre o
## anel (e, sem nevoa, o alcance de desenho junto).
var raio_visual_m := 0.0
## `--raio-sim=METROS`: raio de simulacao no lugar do `stream_radius` do preset.
## So para a bancada medir a casca contra o chunk completo na mesma distancia.
var raio_sim_m := 0.0
var _raio_visual: int = 2
var _cascas: Dictionary[Vector2i, Node3D] = {}
## Dados montados na thread ANTES de o chunk entrar no raio (antecipacao pela
## velocidade). Nao sao no nenhum ainda; entram na fila na hora que precisar.
var _adiantados: Dictionary[Vector2i, Dictionary] = {}
## `--streaming-antigo`: fila do mais perto para o mais longe, sem antecipacao,
## como ate 24/09/2026. E o par da bancada.
var prioridade_antiga := false
var _pos_antes := Vector3.INF
var _pos := Vector2.ZERO
var _vel := Vector2.ZERO
var _olhar := Vector2.ZERO
## Desde quando cada chunk do raio de simulacao esta faltando (usec). Mede o
## atraso entre o chunk passar a ser preciso e ficar pronto.
var _falta_desde: Dictionary[Vector2i, int] = {}

## O anel distante (Horizonte, passos 2 e 3). Ligado por padrao a
## RAIO_HORIZONTE m, so no MODERNO (Horizonte._deve_desenhar); com nevoa, ele
## vai so ate onde ela apaga (FogPreset.alcance_visivel) — e ele que da a
## silhueta que a nevoa exponencial deixa ver alem dos chunks.
## `--horizonte=METROS` troca o raio; zero desliga. Com ele desenhando, a planta
## de cada chunk construido sai na mesma tarefa (`_tarefa`) e todo chunk
## carregado desenha sem corte por distancia: a borda do chunk de verdade
## encosta na do anel, sem fresta (a mascara do Horizonte some com o anel onde o
## chunk esta).
const RAIO_HORIZONTE := 2500.0
var raio_horizonte_m := RAIO_HORIZONTE
var horizonte: Horizonte
var _horizonte_ativo := false
## Sobe a cada troca no que o ChunkManager desenha (chunk que entra, sai, vira
## casca). O Horizonte so refaz a mascara quando ele muda.
var versao_desenho := 0

## Medidas do streaming, zeradas pela bancada (`zerar_medidas`).
var medida_atraso_ms: PackedFloat32Array = []
var medida_tarefa_ms: PackedFloat32Array = []
var medida_adiantados_usados := 0
var medida_promovidos := 0
var medida_rebaixados := 0
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
	montagem_inteira = OS.get_cmdline_user_args().has("--montagem-inteira")
	malhas_na_thread = not OS.get_cmdline_user_args().has("--malhas-no-fio")
	prioridade_antiga = OS.get_cmdline_user_args().has("--streaming-antigo")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--raio-visual="):
			raio_visual_m = maxf(0.0, arg.trim_prefix("--raio-visual=").to_float())
		elif arg.begins_with("--horizonte="):
			raio_horizonte_m = maxf(0.0, arg.trim_prefix("--horizonte=").to_float())
		elif arg.begins_with("--raio-sim="):
			raio_sim_m = maxf(0.0, arg.trim_prefix("--raio-sim=").to_float())
	# Shader de prop nao morre com o ultimo prop (Fase 2): ver ReservaDeShaders.
	if not OS.get_cmdline_user_args().has("--sem-reserva-de-shaders"):
		ReservaDeShaders.iniciar(get_tree())
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
	if raio_horizonte_m > 0.0 and horizonte == null:
		horizonte = Horizonte.new(raio_horizonte_m)
		raiz.add_child(horizonte)
	set_process(true)


func parar() -> void:
	ativo = false
	set_process(false)
	aguardar_tarefas()
	if horizonte != null and is_instance_valid(horizonte):
		horizonte.free()
	horizonte = null
	_horizonte_ativo = false
	# free imediato, nao queue_free: no desligamento a fila de liberacao pode
	# nao ser processada, e os nos ficam para tras como vazamento.
	for coord: Vector2i in _carregados.keys():
		var no: Node3D = _carregados[coord]
		tris_carregados -= int(no.get_meta(&"triangulos", 0))
		if is_instance_valid(no):
			no.free()
	_carregados.clear()
	for coord: Vector2i in _cascas.keys():
		if is_instance_valid(_cascas[coord]):
			_cascas[coord].free()
	_cascas.clear()
	for coord: Vector2i in _montando:
		_montando[coord].cancelar()
	_montando.clear()
	_prontos.clear()
	_adiantados.clear()
	_falta_desde.clear()
	_pos_antes = Vector3.INF
	_vel = Vector2.ZERO
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
	# O corpo e a carroceria encomendados (Fase 2) rodam na mesma piscina, e
	# ninguem mais espera por eles na saida: com o servidor de render ja fechado,
	# a tarefa que ainda montava malha derrubava o processo (falha de segmento em
	# 5 de 10 rodadas de dia_sol, 24/09/2026).
	VariantesDeCorpo.esperar_encomendas()
	Carroceria.esperar_encomendas()


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
	var simulacao := preset.stream_radius if raio_sim_m <= 0.0 else raio_sim_m
	_raio_carga = maxi(1, ceili(simulacao / TAM)) + raio_extra
	_raio_visual = maxi(_raio_carga, ceili(raio_visual_m / TAM) + raio_extra)
	# Ate onde da para VER: com nevoa, o fim dela mais a folga de entrada; sem
	# nevoa, o horizonte de streaming (ou o anel visual, se for maior), que e o
	# unico limite que sobra e nao ganha folga nenhuma porque nao ha nada
	# carregado depois dele.
	var alcance := (preset.fog_end * ALCANCE_EXTRA) if preset.fog_enabled 		else maxf(preset.stream_radius, raio_visual_m)
	if preset.nevoa_exponencial(Settings.luz_por_pixel):
		# Nevoa exponencial (FogPreset): no `fog_end` ainda se ve 30%, e o corte
		# ali seria sumico. So onde nem a lampada atravessa (alcance_visivel).
		alcance = preset.alcance_visivel()
	_alcance_render = maxf(alcance, ALCANCE_MINIMO)
	for coord: Vector2i in _carregados:
		_aplicar_alcance(_carregados[coord])
	for coord: Vector2i in _cascas:
		_aplicar_alcance(_cascas[coord])
	# Forca reavaliacao do conjunto desejado no proximo frame.
	_coord_atual = Vector2i(2147483647, 0)


func coord_de(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / TAM), floori(pos.z / TAM))


func chunks_carregados() -> int:
	return _carregados.size()


## O chunk esta montado agora? O mapa usa para mostrar o que o jogador consegue
## enxergar mesmo sem ainda ter pisado ali. Casca do anel visual nao conta: e so
## imagem, sem chao nem gente.
func esta_carregado(coord: Vector2i) -> bool:
	return _carregados.has(coord)


## Ha alguma coisa desenhavel do chunk: completo ou casca. A bancada usa para
## achar buraco na vista.
func esta_visivel(coord: Vector2i) -> bool:
	if _carregados.has(coord) or _cascas.has(coord):
		return true
	# Montagem que ja entrou na arvore (promocao de casca, ou chunk novo depois
	# de ENTRAR) ja desenha: so falta prop.
	var m: MontagemDeChunk = _montando.get(coord)
	return m != null and is_instance_valid(m.no) and m.no.is_inside_tree()


func cascas() -> int:
	return _cascas.size()


## Raio de simulacao e raio visual, em chunks.
func raios() -> Vector2i:
	return Vector2i(_raio_carga, _raio_visual)


## Ate onde a malha e desenhada, em metros (sem a meia diagonal).
func alcance_de_desenho() -> float:
	return _alcance_render


## Chunks que o ChunkManager desenha agora: completos, cascas e montagens ja na
## arvore. E a mascara do Horizonte.
func chunks_desenhados() -> Array[Vector2i]:
	var saida: Array[Vector2i] = []
	saida.append_array(_carregados.keys())
	saida.append_array(_cascas.keys())
	for c: Vector2i in _montando:
		var m: MontagemDeChunk = _montando[c]
		if is_instance_valid(m.no) and m.no.is_inside_tree():
			saida.append(c)
	return saida


## O Horizonte ligou ou desligou (troca de clima, interior): o corte de desenho
## dos chunks muda junto.
func horizonte_mudou() -> void:
	_horizonte_ativo = horizonte != null and horizonte.ativo()
	for coord: Vector2i in _carregados:
		_aplicar_alcance(_carregados[coord])
	for coord: Vector2i in _cascas:
		_aplicar_alcance(_cascas[coord])


func zerar_medidas() -> void:
	medida_atraso_ms = PackedFloat32Array()
	medida_tarefa_ms = PackedFloat32Array()
	medida_adiantados_usados = 0
	medida_promovidos = 0
	medida_rebaixados = 0


func _process(delta: float) -> void:
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
	_medir_movimento(delta)

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
	_andar_montagens()


## Velocidade do alvo no plano (media curta) e direcao da camera. Sao a entrada
## da prioridade e da antecipacao.
func _medir_movimento(delta: float) -> void:
	var p := alvo.global_position
	_pos = Vector2(p.x, p.z)
	if _pos_antes == Vector3.INF or delta <= 0.0 or p.distance_to(_pos_antes) > SALTO_M:
		_vel = Vector2.ZERO
	else:
		var agora := Vector2(p.x - _pos_antes.x, p.z - _pos_antes.z) / delta
		_vel = _vel.lerp(agora, 1.0 - exp(-delta / SUAVE_VEL))
	_pos_antes = p
	_olhar = Vector2.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var f := -cam.global_basis.z
		_olhar = Vector2(f.x, f.z).normalized()


## Quanto menor, antes o chunk entra na fila. Em metros: a distancia ate a borda
## dele, menos o que a velocidade anda na direcao dele em ANTECIPACAO_S, menos
## BONUS_OLHAR se ele esta para onde a camera olha. O anel do jogador sempre
## primeiro.
func _prioridade(c: Vector2i) -> float:
	if prioridade_antiga:
		return float((c - _coord_atual).length_squared())
	var x0 := c.x * TAM
	var z0 := c.y * TAM
	var dx := maxf(maxf(x0 - _pos.x, _pos.x - (x0 + TAM)), 0.0)
	var dz := maxf(maxf(z0 - _pos.y, _pos.y - (z0 + TAM)), 0.0)
	var borda := sqrt(dx * dx + dz * dz)
	if _distancia(c) <= 1:
		return borda - CHAO_PRIMEIRO
	var dir := (Vector2(x0 + TAM * 0.5, z0 + TAM * 0.5) - _pos).normalized()
	return borda - ANTECIPACAO_S * maxf(0.0, _vel.dot(dir)) \
		- BONUS_OLHAR * maxf(0.0, _olhar.dot(dir))


## Tarefas de verdade na piscina (o dado adiantado que ja entrou na fila tem id
## -1 e nao ocupa thread).
func _tarefas() -> int:
	var n := 0
	for id: int in _em_voo.values():
		if id >= 0:
			n += 1
	return n


## Pede os chunks que faltam, na ordem de `_prioridade`: primeiro o chao do
## jogador, depois o que ele vai ver antes. Completo dentro do raio de
## simulacao, casca no anel visual. Com a fila da thread folgada, adianta o anel
## seguinte na direcao do movimento.
func _preencher(centro: Vector2i) -> void:
	var agora := Time.get_ticks_usec()
	var faltando: Array[Vector2i] = []
	for dz in range(-_raio_visual, _raio_visual + 1):
		for dx in range(-_raio_visual, _raio_visual + 1):
			var c := centro + Vector2i(dx, dz)
			if _carregados.has(c):
				continue
			var completo := maxi(absi(dx), absi(dz)) <= _raio_carga
			if completo and not _falta_desde.has(c):
				_falta_desde[c] = agora
			if _em_voo.has(c) or _montando.has(c):
				continue
			if not completo and _cascas.has(c):
				continue
			faltando.append(c)

	faltando.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _prioridade(a) < _prioridade(b))

	for c: Vector2i in faltando:
		var completo := _distancia(c) <= _raio_carga
		var modo := (Modo.PERTO if _cascas.has(c) else Modo.TUDO) if completo \
			else Modo.CASCA
		if _adiantados.has(c):
			var d: Dictionary = _adiantados[c]
			_adiantados.erase(c)
			# Dado sem as malhas de longe nao serve para casca: montar essas
			# malhas no fio principal custaria o quadro que a thread poupou.
			if modo != Modo.CASCA or int(d.get("modo", Modo.TUDO)) != Modo.PERTO:
				_entregar(c, d)
				medida_adiantados_usados += 1
				continue
		if _tarefas() >= MAX_EM_VOO:
			continue
		_pedir(c, modo)

	if prioridade_antiga or _tarefas() >= MAX_EM_VOO or _vel.length() < VEL_ANTECIPAR:
		return
	_antecipar(centro)


## O anel logo alem do raio de simulacao (e do visual, se houver casca), na
## direcao do movimento, sai da thread antes de precisar. Quando o jogador cruza
## a fronteira, o chunk so e pendurado: a espera pela thread sumiu da borda.
func _antecipar(centro: Vector2i) -> void:
	var dirv := _vel.normalized()
	var aneis: Array[int] = [_raio_carga + 1]
	if _raio_visual > _raio_carga:
		aneis.append(_raio_visual + 1)
	var candidatos: Array[Vector2i] = []
	var modos: Dictionary[Vector2i, int] = {}
	for anel: int in aneis:
		for dz in range(-anel, anel + 1):
			for dx in range(-anel, anel + 1):
				if maxi(absi(dx), absi(dz)) != anel:
					continue
				var c := centro + Vector2i(dx, dz)
				if _carregados.has(c) or _em_voo.has(c) or _montando.has(c) \
						or _adiantados.has(c):
					continue
				var dir := (Vector2((c.x + 0.5) * TAM, (c.y + 0.5) * TAM) - _pos).normalized()
				if dirv.dot(dir) < COS_ANTECIPAR:
					continue
				if anel == _raio_carga + 1 and _raio_visual > _raio_carga:
					# Anel de casca: o que se adianta e a promocao dela.
					if not _cascas.has(c):
						continue
					modos[c] = Modo.PERTO
				elif anel == _raio_carga + 1:
					modos[c] = Modo.TUDO
				else:
					modos[c] = Modo.CASCA
				candidatos.append(c)
	candidatos.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _prioridade(a) < _prioridade(b))
	for c: Vector2i in candidatos:
		if _tarefas() >= MAX_EM_VOO:
			return
		_pedir(c, modos[c])


## Dado adiantado entra na fila de montagem como se a thread tivesse acabado
## agora. O id -1 marca "em voo sem tarefa": ninguem pede de novo.
func _entregar(coord: Vector2i, dados: Dictionary) -> void:
	_em_voo[coord] = -1
	_mutex.lock()
	_prontos.append(dados)
	_mutex.unlock()


func _descarregar_distantes(centro: Vector2i) -> void:
	var limite := _raio_carga + FOLGA_DESCARGA
	var limite_visual := _raio_visual + FOLGA_DESCARGA
	for c: Vector2i in _carregados.keys():
		var d := _cheb(c, centro)
		if d > limite_visual:
			_descarregar(c)
		elif d > limite:
			_rebaixar(c)
	for c: Vector2i in _cascas.keys():
		if _cheb(c, centro) > limite_visual:
			_descarregar_casca(c)
	for c: Vector2i in _montando.keys():
		var d := _cheb(c, centro)
		var m: MontagemDeChunk = _montando[c]
		if d > limite_visual or (d > limite and not m.so_casca and not m.promovendo):
			m.cancelar()
			_montando.erase(c)
			versao_desenho += 1
		elif d > limite and m.promovendo:
			# A promocao ficou para tras: a casca volta a ser casca.
			_montando.erase(c)
			MontagemDeChunk.tirar_simulacao(m.no)
			_cascas[c] = m.no
	for c: Vector2i in _adiantados.keys():
		if _cheb(c, centro) > limite_visual:
			_adiantados.erase(c)
	for c: Vector2i in _falta_desde.keys():
		if _cheb(c, centro) > _raio_carga:
			_falta_desde.erase(c)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _pedir(coord: Vector2i, modo: int = Modo.TUDO) -> void:
	_em_voo[coord] = WorkerThreadPool.add_task(
		_tarefa.bind(coord, modo), false, "chunk %d,%d" % [coord.x, coord.y])


## O material vai no balde @perto (miudeza cortada a ALCANCE_PERTO)?
static func e_perto(material: StringName) -> bool:
	return String(material).contains("@perto")


## O material vai no balde @longe: a versao barata de uma miudeza do @perto, que
## aparece exatamente onde ela some (fiacao com menos lados, por exemplo). E
## casca: entra no anel visual e fica na casca quando o chunk volta a ela.
static func e_longe(material: StringName) -> bool:
	return String(material).contains("@longe")


## Triangulos do chunk nas duas vistas: `x` visto de longe (a casca, com o
## @longe), `y` com o jogador em volta (a casca sem o @longe, mais o @perto). A
## soma dos baldes conta os dois niveis de detalhe e nao e o custo de vista
## nenhuma. Os tetos dos verificadores (cidade, bar, lojas) sao destas duas.
static func triangulos_por_vista(superficies: Dictionary) -> Vector2i:
	var longe := 0
	var perto := 0
	for mat: StringName in superficies:
		var n := PSXMesh.dados_triangulos(superficies[mat])
		if e_perto(mat):
			perto += n
		elif e_longe(mat):
			longe += n
		else:
			longe += n
			perto += n
	return Vector2i(longe, perto)


## Marca a malha com o balde dela (`aplicar_alcance_em` e a volta a casca leem
## a meta). Um lugar so, para o chunk inteiro e a montagem fatiada.
static func marcar_balde(mi: MeshInstance3D, material: StringName) -> void:
	if e_perto(material):
		mi.set_meta(&"perto", true)
		return
	mi.set_meta(&"casca", true)
	if e_longe(material):
		mi.set_meta(&"longe", true)


## Roda fora da thread principal. Nao pode tocar em no nem em recurso.
func _tarefa(coord: Vector2i, modo: int) -> void:
	var t0 := Time.get_ticks_usec()
	var dados := ChunkBuilder.construir(coord.x, coord.y)
	dados["coord"] = coord
	dados["modo"] = modo
	if malhas_na_thread:
		# A mesma `dados_para_mesh` da montagem, com os mesmos dados: a malha e
		# a mesma. O envio para a GPU continua no fio do servidor. Cada modo so
		# monta o que vai pendurar.
		var malhas := {}
		var superficies: Dictionary = dados["superficies"]
		for material: StringName in superficies:
			if (modo == Modo.CASCA and e_perto(material)) \
					or (modo == Modo.PERTO and not e_perto(material)):
				continue
			if not PSXMesh.dados_vazio(superficies[material]):
				malhas[material] = PSXMesh.dados_para_mesh(superficies[material])
		dados["malhas"] = malhas
	if _horizonte_ativo and modo != Modo.PERTO:
		dados["planta"] = HorizonteDados.planta_de(dados["superficies"], coord.x, coord.y)
	dados["tarefa_us"] = Time.get_ticks_usec() - t0
	_mutex.lock()
	_prontos.append(dados)
	_mutex.unlock()


## No maximo um chunk por frame vira no. Instanciar em lote engasga a imagem, e
## engasgo e justamente o que a Fase 3 promete nao ter.
##
## Dos dados prontos, vira no o de melhor `_prioridade`; o que chegou de uma
## antecipacao (fora do raio) so fica guardado, sem custo de quadro.
func _materializar_um() -> void:
	_mutex.lock()
	var lote := _prontos
	_prontos = []
	_mutex.unlock()
	if lote.is_empty():
		return

	var candidatos: Array[Dictionary] = []
	for dados: Dictionary in lote:
		var coord: Vector2i = dados["coord"]
		if dados.has("tarefa_us"):
			medida_tarefa_ms.append(float(dados["tarefa_us"]) / 1000.0)
			dados.erase("tarefa_us")
		if dados.has("planta"):
			if horizonte != null and is_instance_valid(horizonte):
				horizonte.receber(coord, dados["planta"])
			dados.erase("planta")
		var d := _distancia(coord)
		# Ja montado, ou saiu do alcance enquanto a thread trabalhava.
		if _carregados.has(coord) or _montando.has(coord) \
				or d > _raio_visual + FOLGA_DESCARGA:
			_em_voo.erase(coord)
			continue
		if d > _raio_visual or (d > _raio_carga and _cascas.has(coord)):
			# Antecipacao: guarda ate precisar.
			_em_voo.erase(coord)
			_adiantados[coord] = dados
			continue
		if d > _raio_carga and int(dados.get("modo", Modo.TUDO)) == Modo.PERTO:
			# Era a promocao de uma casca que ja saiu: sem as malhas de longe,
			# nao serve para casca nova. A proxima volta pede de novo.
			_em_voo.erase(coord)
			continue
		candidatos.append(dados)
	if candidatos.is_empty():
		return

	var melhor := 0
	if not prioridade_antiga:
		for i in range(1, candidatos.size()):
			if _prioridade(candidatos[i]["coord"]) < _prioridade(candidatos[melhor]["coord"]):
				melhor = i
	var dados: Dictionary = candidatos[melhor]
	candidatos.remove_at(melhor)
	if not candidatos.is_empty():
		_mutex.lock()
		candidatos.append_array(_prontos)
		_prontos = candidatos
		_mutex.unlock()

	var coord: Vector2i = dados["coord"]
	_em_voo.erase(coord)
	var urgente := montagem_inteira or _distancia(coord) <= 1

	if _distancia(coord) > _raio_carga:
		_montando[coord] = MontagemDeChunk.casca(coord, dados)
		return

	var casca: Node3D = _cascas.get(coord)
	if casca != null:
		_cascas.erase(coord)
		var promo := MontagemDeChunk.promover(coord, dados, casca)
		medida_promovidos += 1
		if urgente:
			promo.andar(9223372036854775807)
			_concluir(coord, promo.no, dados)
			return
		_montando[coord] = promo
		return

	# O anel do jogador (a largada, o teleporte, a abertura esperando os nove
	# chunks em volta) vira no inteiro, na hora: e chao debaixo dos pes. A borda
	# do streaming — onde entra tudo o que chega dirigindo, dentro da nevoa —
	# vira no aos poucos. Ver `MontagemDeChunk`.
	if urgente:
		_concluir(coord, _montar(coord, dados), dados)
		return
	_montando[coord] = MontagemDeChunk.new(coord, dados)


## A malha de uma superficie do chunk: a que a thread ja montou, ou montada
## agora (quem pediu com `--malhas-no-fio`, ou dados que nao passaram por
## `_tarefa`).
static func malha_de(dados: Dictionary, material: StringName) -> ArrayMesh:
	var pronta: ArrayMesh = (dados.get("malhas", {}) as Dictionary).get(material)
	if pronta != null:
		return pronta
	return PSXMesh.dados_para_mesh(dados["superficies"][material])


## Distancia do chunk ao do jogador, em chunks (a maior das duas).
func _distancia(coord: Vector2i) -> int:
	return maxi(absi(coord.x - _coord_atual.x), absi(coord.y - _coord_atual.y))


## As montagens em andamento, da mais perto para a mais longe, ate o orcamento
## do quadro. A que o jogador ja alcancou (anel dele) termina neste quadro.
func _andar_montagens() -> void:
	if _montando.is_empty():
		return
	var fila: Array[Vector2i] = []
	fila.assign(_montando.keys())
	if prioridade_antiga:
		fila.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _distancia(a) < _distancia(b))
	else:
		fila.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _prioridade(a) < _prioridade(b))
	var prazo := Time.get_ticks_usec() + MontagemDeChunk.ORCAMENTO_US
	for coord in fila:
		var m: MontagemDeChunk = _montando[coord]
		var urgente := _distancia(coord) <= 1
		if not urgente and Time.get_ticks_usec() >= prazo:
			break
		if m.andar(9223372036854775807 if urgente else prazo):
			_montando.erase(coord)
			if m.so_casca:
				_cascas[coord] = m.no
				versao_desenho += 1
			else:
				_concluir(coord, m.no, m.dados)


## Passos de fisica desde que o chunk desta coordenada ficou pronto, ou -1.
## Diagnostico: coisa que so custa no chunk recem-chegado aparece aqui.
func passos_desde_carga(coord: Vector2i) -> int:
	var no: Node3D = _carregados.get(coord)
	if no == null:
		return -1
	return Engine.get_physics_frames() - int(no.get_meta(&"quadro_de_fisica", 0))


## O chunk pronto passa a contar: e so aqui que ele e "carregado".
func _concluir(coord: Vector2i, no: Node3D, dados: Dictionary) -> void:
	if _falta_desde.has(coord):
		medida_atraso_ms.append((Time.get_ticks_usec() - _falta_desde[coord]) / 1000.0)
		_falta_desde.erase(coord)
	versao_desenho += 1
	_carregados[coord] = no
	no.set_meta(&"quadro_de_fisica", Engine.get_physics_frames())
	construcoes += 1
	tris_carregados += int(dados["triangulos"])
	chunk_carregado.emit(coord)


func _montar(coord: Vector2i, dados: Dictionary) -> Node3D:
	var no := Node3D.new()
	no.name = "chunk_%03d_%03d" % [coord.x, coord.y]
	no.position = Vector3(coord.x * TAM, 0.0, coord.y * TAM)
	no.set_meta(&"triangulos", dados["triangulos"])

	var superficies: Dictionary = dados["superficies"]
	# A GramaViva (so MODERNO) le o chao daqui, sem ler de volta a malha da GPU
	# (`surface_get_arrays` do calcamento custava ate 9 ms). Ela tira a meta
	# assim que le.
	if guardar_superficies:
		no.set_meta(&"superficies", superficies)
	for material: StringName in superficies:
		var d: Dictionary = superficies[material]
		if PSXMesh.dados_vazio(d):
			continue
		var mi := MeshInstance3D.new()
		mi.name = String(material)
		mi.mesh = malha_de(dados, material)
		# Balde "material@perto" (flor, comodo atras da janela aberta, miudeza de
		# fachada): o mesmo material, cortado bem antes da nevoa (ALCANCE_PERTO).
		# "material@longe" e a versao de longe dela, que entra no mesmo ponto.
		var base_mat := StringName(String(material).get_slice("@", 0))
		marcar_balde(mi, material)
		mi.material_override = _material(base_mat)
		mi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if SEM_SOMBRA.has(base_mat)
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		no.add_child(mi)

	montar_colisao(no, dados)

	_coord_do_prop = coord
	for prop: Dictionary in dados["props"]:
		var criado := _criar_prop(prop)
		if criado != null:
			no.add_child(criado)

	raiz.add_child(no)
	_aplicar_alcance(no)
	return no


## O corpo de colisao do chunk e o oclusor, como filhos de `no`. Separado de
## `_montar` porque a `MontagemDeChunk` faz o mesmo passo, aos poucos. A casca
## so leva o oclusor; a promocao dela, so o corpo.
func montar_colisao(no: Node3D, dados: Dictionary, com_corpo := true,
		com_oclusor := true) -> void:
	if not com_corpo:
		_por_oclusor(no, dados, com_oclusor)
		return
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	for caixa: Dictionary in dados["colisao"]:
		var forma := CollisionShape3D.new()
		# O chao com relevo e um mapa de alturas (Relevo.mapa_de_colisao): a
		# rua sobe e a caixa nao sobe junto. O mapa e de um ponto por unidade;
		# a escala uniforme aperta os pontos para o passo dele.
		if caixa.has("altura"):
			var mapa := HeightMapShape3D.new()
			mapa.map_width = int(caixa["lado"])
			mapa.map_depth = int(caixa["lado"])
			mapa.map_data = caixa["altura"]
			forma.shape = mapa
			forma.position = caixa["pos"]
			forma.scale = Vector3.ONE * float(caixa.get("escala", 1.0))
			corpo.add_child(forma)
			continue
		var box := BoxShape3D.new()
		box.size = caixa["tamanho"]
		forma.shape = box
		forma.position = caixa["pos"]
		if caixa.has("giro"):
			forma.rotation = caixa["giro"]
		corpo.add_child(forma)
	no.add_child(corpo)
	_por_oclusor(no, dados, com_oclusor)


func _por_oclusor(no: Node3D, dados: Dictionary, com_oclusor: bool) -> void:
	if not com_oclusor:
		return
	var oclusor := _oclusor(dados["colisao"])
	if oclusor != null:
		oclusor.set_meta(&"casca", true)
		no.add_child(oclusor)


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
		if not caixa.has("tamanho"):
			continue
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
		porta.espera_dono = prop.get("espera_dono", false)
		return porta

	# Nome de rua na placa azul da esquina (NomesDeRua.placas). A placa e malha
	# do chunk; o texto nao se funde, e vira o unico no dela. Some a 30 m: de
	# longe o nome e um borrao de dois pixels, e o custo e de graca.
	if tipo == "placa_rua":
		var rotulo := Label3D.new()
		rotulo.text = prop["texto"]
		rotulo.position = prop["pos"]
		rotulo.rotation.y = prop["giro"]
		rotulo.font_size = 32
		rotulo.pixel_size = 0.0038
		rotulo.outline_size = 0
		rotulo.modulate = Color(0.95, 0.95, 0.9)
		rotulo.double_sided = false
		rotulo.visibility_range_end = 30.0
		return rotulo

	# A sala atras da porta de verdade. Nasce vazia: ela mesma se monta quando o
	# jogador chega perto (ver InteriorNoMundo).
	if tipo == "interior_mundo":
		var casa := InteriorNoMundo.new()
		casa.transform = prop["planta"]
		casa.planta = prop["interior"]
		casa.semente = prop["semente"]
		return casa

	# A loja de conveniencia na rua (PredioMercado): a porta que ve quem chega,
	# o portao que sobe e a frente acesa pelas duas luzes.
	if tipo == "porta_automatica":
		var auto := PortaAutomatica.new()
		auto.position = prop["pos"]
		auto.rotation.y = prop["giro"]
		auto.semente = prop.get("semente", 0)
		return auto
	if tipo == "portao_enrolar":
		var portao := PortaoEnrolar.new()
		portao.position = prop["pos"]
		portao.rotation.y = prop["giro"]
		portao.largura = prop.get("largura", KitMercado.LARGURA_PORTAO)
		portao.altura = prop.get("altura", KitMercado.ALTURA_PORTAO)
		portao.semente = prop.get("semente", 0)
		return portao
	if tipo == "malha_fronteira":
		var frente := MalhaFronteira.new()
		frente.name = "FrenteDaLoja"
		frente.transform = prop["planta"]
		frente.superficies = prop["superficies"]
		frente.colisao = prop.get("colisao", [])
		frente.material_de = _material
		return frente

	if tipo == "item":
		var item := ItemNoChao.new()
		item.position = prop["pos"]
		item.item_id = prop["item"]
		item.quantidade = prop["quantidade"]
		item.indice = prop["indice"]
		item.chunk = _coord_do_prop
		return item

	# A luneta do terraco do mirante (MiranteBuilder): a malha e do chunk, o no
	# e so o que responde ao [E].
	if tipo == "luneta":
		var luneta := Luneta.new()
		luneta.position = prop["pos"]
		luneta.giro = prop["giro"]
		return luneta

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

	# Lata, garrafa e maco do bar, com o rotulo do atlas do mercado.
	if tipo == "produtos":
		return ProdutosDoBar.criar(prop)

	# A mesa de sinuca jogavel do bar. Ociosa, nao processa nada.
	if tipo == "sinuca":
		return JogoSinuca.criar(prop)

	# A vida do bar: quem bebe, brinda e conversa, e quem atende servindo.
	if tipo == "vida_bar":
		return VidaDoBar.criar(prop)

	# Um bar da BarVivo se anuncia ao mapa e ao GPS quando e montado. Nao vira no.
	if tipo == "ponto_bar":
		BaresDaCidade.registrar(_coord_do_prop, prop)
		return null

	# O sino da Matriz: bate a hora cheia do `WorldState.relogio`.
	if tipo == "sino":
		var sino := SinoIgreja.new()
		sino.position = prop["pos"]
		sino.som = prop.get("som", &"sino_igreja")
		return sino

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
	# O cone de poste e o padrao; quem pendura uma luz mais baixa (a marquise da
	# loja) diz o tamanho do facho dela, senao ele atravessa a calcada.
	l.raio_base = float(prop.get("raio_base", 3.2))
	l.altura_facho = float(prop.get("altura_facho", 6.2))
	if prop.has("raio_topo"):
		l.raio_topo = float(prop["raio_topo"])
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
	var id := id_do_convidado(prop)
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
	# Quem trabalha numa loja (KitLoja): a profissao e a do balcao, a conversa e
	# a de loja (VendaDaLoja.opcoes), e o rotulo diz a funcao. A ficha do registro
	# e de cache: copia antes de trocar a profissao.
	if prop.has("profissao"):
		ficha = ficha.duplicate()
		ficha["profissao"] = String(prop["profissao"])
	c.contexto_da_conversa = StringName(prop.get("contexto", &"rua"))
	c.funcao = String(prop.get("funcao", ""))
	c.loja = prop.get("loja", {})
	c.altura_assento = float(prop.get("assento", 0.0))
	# O foco tambem vem em coordenada local do chunk. Sem a conversao, quem esta
	# sentado no bar olhava para um ponto perto da origem do mundo, e nao para a
	# mesa ou a TV (PLANO_BAR_E_CIDADE_AAA, B6).
	if prop.has("foco"):
		foco += origem
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


## Quem nasce deste prop de convidado ou morador: a conta do `_criar_convidado`,
## sem criar nada. A `MontagemDeChunk` pergunta aqui para encomendar o corpo
## antes (`VariantesDeCorpo`), e as duas pontas dao a mesma pessoa.
static func id_do_convidado(prop: Dictionary) -> int:
	return RegistroCivil.id_de_faixa(int(prop.get("semente", 0)),
		int(prop.get("idade_min", 18)), int(prop.get("idade_max", 30)))


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
		if g != null:
			aplicar_alcance_em(g)


## O alcance de uma malha so. A promocao de casca usa na hora de pendurar a
## malha @perto num no que ja esta na arvore: sem isso ela aparece um quadro
## inteira, sem corte, a 70 m.
func aplicar_alcance_em(g: GeometryInstance3D) -> void:
	if g.has_meta(&"perto"):
		# Miudeza de fachada: nao passa de ALCANCE_PERTO nem com alcance
		# infinito. A distancia e ate o centro da malha, que e o chunk todo.
		var ate := ALCANCE_PERTO if alcance_infinito \
			else minf(_alcance_render, ALCANCE_PERTO)
		g.visibility_range_end = ate + _raio_da_malha(g)
		return
	if g.has_meta(&"longe"):
		# Comeca onde o @perto acaba, na mesma conta, e segue como casca. Troca
		# seca, sem margem: com o psx_surface o esmaecimento do Godot apaga as
		# DUAS malhas na faixa inteira (tests/bancada_esmaecer.gd, 25/09/2026),
		# e o que troca aqui e sub-pixel nessa distancia.
		var de := ALCANCE_PERTO if alcance_infinito \
			else minf(_alcance_render, ALCANCE_PERTO)
		g.visibility_range_begin = de + _raio_da_malha(g)
	if alcance_infinito or _horizonte_ativo:
		g.visibility_range_end = 0.0
		return
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
	versao_desenho += 1
	chunk_descarregado.emit(coord)


## O chunk saiu do raio de simulacao mas continua no visual: fica so a casca
## (malhas de longe e oclusor). Para o resto do jogo e uma descarga.
func _rebaixar(coord: Vector2i) -> void:
	var no: Node3D = _carregados.get(coord)
	if no == null:
		return
	tris_carregados -= int(no.get_meta(&"triangulos", 0))
	_carregados.erase(coord)
	MontagemDeChunk.tirar_simulacao(no)
	_cascas[coord] = no
	medida_rebaixados += 1
	versao_desenho += 1
	chunk_descarregado.emit(coord)


func _descarregar_casca(coord: Vector2i) -> void:
	var no: Node3D = _cascas.get(coord)
	_cascas.erase(coord)
	versao_desenho += 1
	if no != null and is_instance_valid(no):
		no.queue_free()


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
