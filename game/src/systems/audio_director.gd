## Autoload. Toca tudo que soa, com uma piscina de tocadores reciclados.
##
## Criar um AudioStreamPlayer3D por som e destrui-lo depois funciona ate o
## momento em que passos, chuva e tiros acontecem juntos: aí o custo de alocar no
## vira engasgo. A piscina resolve isso e ainda da um teto natural de vozes.
##
## O banco de sons e sintetizado por tools/gerar_audio.py. Nada aqui depende de
## arquivo baixado.
extends Node

const DIR := "res://assets/audio/"
const VOZES_3D := 16
const VOZES_2D := 6

## Superficies com variacao de passo. O nome casa com o arquivo.
const SUPERFICIES: Array[StringName] = [&"concreto", &"madeira", &"metal", &"terra"]
const VARIACOES := 4

var _streams: Dictionary[StringName, AudioStream] = {}
## Onde cada som mora no disco. Preenchido no arranque; e o indice que permite
## carregar sob demanda sem varrer pasta de novo.
var _caminhos: Dictionary[StringName, String] = {}
## O banco e escrito pela thread de aquecimento e lido pelo jogo.
var _mutex := Mutex.new()
var _tarefa: int = -1
var _piscina3d: Array[AudioStreamPlayer3D] = []
var _piscina2d: Array[AudioStreamPlayer] = []
var _ambientes: Dictionary[StringName, AudioStreamPlayer] = {}
var _rng := RandomNumberGenerator.new()
## Sem servidor de video nao ha saida de audio. Tocar em headless nao produz som
## nenhum e ainda deixa playback pendurado quando a execucao encerra no mesmo
## frame, que e o caso da validacao de nivel 1.
var _mudo: bool = false


func _ready() -> void:
	_rng.randomize()
	_mudo = DisplayServer.get_name() == "headless"
	_indexar()
	_montar_piscinas()
	# O banco enche em segundo plano. Ver `_indexar`.
	_tarefa = WorkerThreadPool.add_task(_aquecer, false, "banco de audio")


## So o INDICE no arranque; os arquivos vem depois.
##
## Carregar os 93 WAVs aqui custava meio segundo da largada — medido em
## `tools/medir_largada.sh --sem-cada`: tirar este autoload da lista tirava
## ~560 ms de 1,47 s. E som nenhum e preciso no primeiro quadro, porque o jogo
## abre no menu.
##
## Agora o arranque so lista a pasta, uma thread enche o banco enquanto o menu
## aparece, e quem pedir um som antes da hora o carrega na hora (`_banco`). Nao
## ha caminho em que o som simplesmente nao toque.
func _indexar() -> void:
	for caminho: String in Recursos.listar(DIR, "wav"):
		_caminhos[StringName(caminho.get_file().get_basename())] = caminho
	if _caminhos.is_empty():
		push_error("AudioDirector: nenhum som em %s" % DIR)


func _aquecer() -> void:
	for nome: StringName in _caminhos.keys():
		_banco(nome)


## O stream, do banco ou do disco.
##
## Chamado tambem pela thread de aquecimento, por isso o mutex: o dicionario e
## escrito nos dois lados. `load` e seguro em thread no Godot 4 e passa pelo
## cache do ResourceLoader, entao dois pedidos do mesmo arquivo nao lem disco
## duas vezes.
func _banco(nome: StringName) -> AudioStream:
	_mutex.lock()
	var pronto: AudioStream = _streams.get(nome)
	_mutex.unlock()
	if pronto != null:
		return pronto
	var caminho: String = _caminhos.get(nome, "")
	if caminho.is_empty():
		return null
	var s := load(caminho) as AudioStream
	if s == null:
		push_error("AudioDirector: %s nao carregou" % caminho)
		return null
	# Tudo que termina em _loop toca em ciclo. A alternativa seria uma tabela
	# de nomes, que diverge do disco no primeiro som novo.
	if s is AudioStreamWAV and String(nome).ends_with("_loop"):
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
	_mutex.lock()
	_streams[nome] = s
	_mutex.unlock()
	return s


func _montar_piscinas() -> void:
	_montar_bus_abafado()
	for i in VOZES_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		# Doppler nas vozes 3D: carro que passa muda de altura, e sem isso a
		# passagem soa como um volume subindo e descendo. `IDLE_STEP` porque
		# transito e pedestre andam no quadro, e nao na fisica.
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		p.max_distance = 34.0
		p.unit_size = 4.0
		# Atenuacao mais dura que a padrao: som que viaja longe demais destroi a
		# leitura de distancia, e distancia e informacao neste jogo.
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		add_child(p)
		_piscina3d.append(p)

	for i in VOZES_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_piscina2d.append(p)


## Sem servidor de video nao ha saida de audio. Quem cria tocador proprio, como
## a folhagem do parque, precisa saber disso antes de criar.
## Carrega um audio que nao veio no pacote.
##
## Existe para o jogador poder trocar a trilha sem tocar no jogo: a roleta do
## radio do carro e a caixa de som da casa procuram arquivo em `user://` antes
## de usar o som gerado. `res://` passa pelo importador e sai como recurso;
## `user://` nao existia quando o jogo foi exportado e tem de ser lido como
## bytes. Sao dois caminhos porque sao dois mundos.
func carregar_externo(caminho: String) -> AudioStream:
	if caminho.begins_with("res://"):
		return load(caminho) as AudioStream if ResourceLoader.exists(caminho) else null
	if not FileAccess.file_exists(caminho):
		return null
	var bytes := FileAccess.get_file_as_bytes(caminho)
	if bytes.is_empty():
		return null
	match caminho.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_buffer(bytes)
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		_:
			return null


## O primeiro arquivo de audio de uma pasta de usuario, ou vazio.
##
## `user://musica/<pasta>/` e o lugar combinado. A pasta e criada no arranque
## para quem for por musica achar onde — uma pasta que existe e um convite, e
## uma que nao existe e um obstaculo.
func musica_do_usuario(pasta: String) -> AudioStream:
	var base := "user://musica/" + pasta
	DirAccess.make_dir_recursive_absolute(base)
	var dir := DirAccess.open(base)
	if dir == null:
		return null
	var nomes := dir.get_files()
	nomes.sort()
	for nome: String in nomes:
		var limpo := nome.trim_suffix(".import")
		var ext := limpo.get_extension().to_lower()
		if ext != "mp3" and ext != "ogg":
			continue
		var s := carregar_externo(base.path_join(limpo))
		if s != null:
			return s
	return null


func silencioso() -> bool:
	return _mudo


func tem(nome: StringName) -> bool:
	return _caminhos.has(nome)


## Stream cru, para quem precisa de um tocador proprio em vez da piscina. O
## radio e o caso: ele toca em loop continuo num bus proprio.
func stream(nome: StringName) -> AudioStream:
	return _banco(nome)


## Copia de um stream marcada para tocar em ciclo, ou null se ele nao existir.
##
## Existe porque a alternativa espalhou o mesmo defeito por quatro arquivos: o
## dono do tocador ligava `finished` de volta em `play()` para o som nao acabar.
## Isso quebra em dois lugares. O intervalo — o sinal chega no quadro seguinte ao
## fim, e o buraco se ouve como um pulso ritmado, que e justamente o que denuncia
## a amostra. E a pausa — a prancha de inventario para a arvore inteira, e um
## tocador que termina com a arvore parada volta a chamar `play()` sem nunca
## andar, ficando preso num ciclo de comeco-e-fim que soa como som travando.
## Marcado no proprio stream, quem repete e o servidor de audio, que nao depende
## de quadro nem de pausa.
##
## A COPIA nao e detalhe: o banco daqui e compartilhado, e marcar laco no
## original entregaria um som que nunca termina a quem so queria o efeito curto
## — o chiado do radio de mao e o mesmo arquivo do radio do carro fora do ar.
func em_loop(nome: StringName) -> AudioStream:
	var base := _banco(nome)
	return marcar_loop(base.duplicate() as AudioStream) if base != null else null


## Marca um stream ja em maos para tocar em ciclo. Serve para o que nao veio do
## banco, como o MP3 que o jogador largou na pasta de musica.
func marcar_loop(s: AudioStream) -> AudioStream:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


## Toca um som no mundo. Devolve o tocador, ou null se nao havia voz livre.
func tocar(nome: StringName, pos: Vector3, volume_db: float = 0.0,
		afinacao: float = 1.0) -> AudioStreamPlayer3D:
	if _mudo:
		return null
	var s := _banco(nome)
	if s == null:
		push_warning("AudioDirector: som desconhecido '%s'" % nome)
		return null
	var oc := oclusao(pos, _ouvinte())
	for p: AudioStreamPlayer3D in _piscina3d:
		if p.playing:
			continue
		p.stream = s
		p.global_position = pos
		p.volume_db = volume_db + float(oc["db"])
		p.bus = BUS_ABAFADO if bool(oc["abafado"]) else &"SFX"
		p.pitch_scale = afinacao
		p.play()
		return p
	# Sem voz livre e um resultado valido, nao um erro: e o teto de vozes agindo.
	return null


## Quanto uma parede entre a fonte e o ouvinte tira deste som.
##
## Devolve `{"db": ..., "corte": ...}`: quanto baixar, e em que frequencia
## cortar o agudo (PLANO_AAA_4K, Fase 9, A27).
##
## Por que o corte de agudo importa mais que o volume
## --------------------------------------------------
## Som atras de parede e som DE OUTRO LUGAR, e o que diz isso ao ouvido nao e o
## volume: e a falta de agudo. Alvenaria deixa passar o grave quase inteiro e
## come o agudo — e a razao de so se ouvir o baixo da festa do vizinho. Baixar o
## volume sem cortar o agudo produz outra coisa: uma fonte LONGE, nitida e
## fraca, que o ouvido poe do lado de fora do lugar errado.
##
## Cada obstaculo conta: parede e porta somam. O teto e -18 dB, que e o ponto em
## que a fonte e mais fundo do que informacao.
##
## O raio ignora area (gatilho de missao nao e parede) e o que estiver no grupo
## `sem_oclusao` — vidro de vitrine e tela de arame sao colisao e nao barreira.
## Quanto a parede tira, e onde ela corta o agudo.
const OCLUSAO_DB := -7.0
const OCLUSAO_CORTE := 900.0
const SEM_OCLUSAO := 20000.0
## O bus do som abafado. Criado em tempo de execucao e enviado ao `SFX`, para o
## deslizador de efeitos do jogador continuar mandando nele.
const BUS_ABAFADO := &"Abafado"


func oclusao(de: Vector3, ate: Vector3) -> Dictionary:
	var solto := {"db": 0.0, "corte": SEM_OCLUSAO, "abafado": false}
	if de.distance_squared_to(ate) < 0.04:
		return solto
	var arvore := get_tree()
	if arvore == null:
		return solto
	var viewport := arvore.root
	if viewport == null:
		return solto
	var mundo := viewport.find_world_3d()
	if mundo == null:
		return solto
	var consulta := PhysicsRayQueryParameters3D.create(de, ate)
	consulta.collide_with_areas = false
	var bate := mundo.direct_space_state.intersect_ray(consulta)
	if bate.is_empty():
		return solto
	var no := bate.get("collider") as Node
	if no != null and no.is_in_group(&"sem_oclusao"):
		return solto
	return {
		"db": OCLUSAO_DB,
		"corte": OCLUSAO_CORTE,
		"abafado": true,
		"obstaculo": no.name if no != null else "",
	}


## O bus do som abafado, criado uma vez.
##
## Por que um BUS e nao o filtro do proprio tocador. O `AudioStreamPlayer3D` tem
## `attenuation_filter_cutoff_hz`, que seria o caminho obvio — e ele nao faz
## efeito nenhum: medido em `tests/bancada_audio.gd`, baixar o corte de 20 kHz
## para 500 Hz mudou a energia do som de 0,2891 para 0,2875, ou seja nada. O bus
## com `AudioEffectLowPassFilter` funciona, e tem a vantagem de o filtro ser um
## so para todas as vozes abafadas em vez de um por voz.
##
## Ele ENVIA para o `SFX` em vez de ir direto ao Master: assim o volume de
## efeitos do jogador continua valendo, e o eco do ambiente (que mora no `SFX`)
## tambem alcanca o som abafado — som atras da parede tambem ecoa no lugar onde
## quem ouve esta.
func _montar_bus_abafado() -> void:
	if AudioServer.get_bus_index(BUS_ABAFADO) >= 0:
		return
	var i := AudioServer.get_bus_count()
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, BUS_ABAFADO)
	AudioServer.set_bus_send(i, &"SFX")
	var filtro := AudioEffectLowPassFilter.new()
	filtro.cutoff_hz = OCLUSAO_CORTE
	filtro.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(i, filtro)


## Onde esta o ouvido: a camera corrente, que e quem o Godot usa para posicionar
## som 3D quando nao ha `AudioListener3D`.
func _ouvinte() -> Vector3:
	var arvore := get_tree()
	if arvore == null or arvore.root == null:
		return Vector3.ZERO
	var ouvinte := arvore.root.get_viewport().get_camera_3d()
	if ouvinte != null:
		return ouvinte.global_position
	return Vector3.ZERO


## Som de interface. `afinacao` existe pelo mesmo motivo que existe em `passo`:
## repetir a MESMA amostra e o que faz o jogador reparar que e uma amostra, e
## nenhum lugar repete tanto quanto uma tecla sendo digitada. Vale tambem para
## reaproveitar um som em outro papel — o mesmo estalo de interruptor a 0,55
## vira a batida de um carimbo de borracha.
##
## O tocador guarda a afinacao do uso anterior, entao ela e escrita SEMPRE, e
## nao so quando o chamador pede: sem isso, o primeiro som agudo deixaria agudo
## o proximo que pegasse a mesma voz da piscina.
func tocar_ui(nome: StringName, volume_db: float = 0.0,
		afinacao: float = 1.0) -> void:
	if _mudo:
		return
	var s := _banco(nome)
	if s == null:
		return
	for p: AudioStreamPlayer in _piscina2d:
		if p.playing:
			continue
		p.stream = s
		p.volume_db = volume_db
		p.pitch_scale = afinacao
		p.play()
		return


## Para todos os sons de UI da piscina 2D (one-shots ainda tocando).
func parar_ui() -> void:
	for p: AudioStreamPlayer in _piscina2d:
		p.stop()
		p.stream = null


## Passo com variacao. Repetir a mesma amostra e o que faz o jogador reparar que
## e uma amostra; quatro variacoes com afinacao aleatoria ja resolve.
func passo(superficie: StringName, pos: Vector3, forca: float = 1.0) -> void:
	var sup := superficie if superficie in SUPERFICIES else &"concreto"
	var nome := StringName("passo_%s_%d" % [sup, _rng.randi_range(1, VARIACOES)])
	tocar(nome, pos, linear_to_db(clampf(forca, 0.05, 1.5)),
		_rng.randf_range(0.92, 1.08))


# --- ambiente ---------------------------------------------------------------

## Liga um loop de ambiente. Chamar de novo com o mesmo nome nao reinicia.
##
## Comeca um frame depois de propósito. O servidor de audio so devolve o
## playback no frame seguinte ao stop, entao um ambiente iniciado no mesmo frame
## em que o motor encerra fica pendurado segurando o WAV. Esperar um frame
## elimina a classe inteira de vazamento de encerramento, e um frame de silencio
## a mais no comeco nao se percebe.
func ambiente(nome: StringName, volume_db: float = -8.0, bus: StringName = &"Ambiente") -> void:
	if _ambientes.has(nome):
		_ambientes[nome].volume_db = volume_db
		return
	if _mudo:
		return
	await get_tree().process_frame
	if not is_inside_tree() or _ambientes.has(nome):
		return
	var s := _banco(nome)
	if s == null:
		push_warning("AudioDirector: ambiente desconhecido '%s'" % nome)
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.autoplay = false
	add_child(p)
	p.play()
	_ambientes[nome] = p


func parar_ambiente(nome: StringName) -> void:
	if not _ambientes.has(nome):
		return
	var p: AudioStreamPlayer = _ambientes[nome]
	_ambientes.erase(nome)
	# Parar, soltar o stream e liberar na hora. queue_free nao e processado no
	# desligamento, e o loop de ambiente fica pendurado segurando o WAV: e
	# exatamente esse o "recurso ainda em uso na saida" que o motor acusa.
	p.stop()
	p.stream = null
	if is_instance_valid(p):
		p.free()


func volume_ambiente(nome: StringName, volume_db: float) -> void:
	if _ambientes.has(nome):
		_ambientes[nome].volume_db = volume_db


## Solta tudo no desligamento. Sem isso o motor reclama de recurso ainda em uso
## na saida, porque os streams ficam presos aos tocadores da piscina.
func _exit_tree() -> void:
	# A thread de aquecimento pode estar no meio de um `load`; sair sem esperar
	# por ela deixa o motor desligando o servidor de recursos por baixo dela.
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
	silenciar_tudo()
	for p: AudioStreamPlayer3D in _piscina3d:
		p.stream = null
	for p: AudioStreamPlayer in _piscina2d:
		p.stream = null
	_streams.clear()


func silenciar_tudo() -> void:
	for nome: StringName in _ambientes.keys():
		parar_ambiente(nome)
	for p: AudioStreamPlayer3D in _piscina3d:
		p.stop()
	for p: AudioStreamPlayer in _piscina2d:
		p.stop()
