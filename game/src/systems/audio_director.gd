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
	_carregar()
	_montar_piscinas()


func _carregar() -> void:
	for caminho: String in Recursos.listar(DIR, "wav"):
		var nome := StringName(caminho.get_file().get_basename())
		var s := load(caminho) as AudioStream
		if s == null:
			push_error("AudioDirector: %s nao carregou" % caminho)
			continue
		# Tudo que termina em _loop toca em ciclo. A alternativa seria uma tabela
		# de nomes, que diverge do disco no primeiro som novo.
		if s is AudioStreamWAV and String(nome).ends_with("_loop"):
			(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			(s as AudioStreamWAV).loop_end = (s as AudioStreamWAV).data.size() / 2
		_streams[nome] = s

	if _streams.is_empty():
		push_error("AudioDirector: nenhum som carregado de %s" % DIR)


func _montar_piscinas() -> void:
	for i in VOZES_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
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
	return _streams.has(nome)


## Stream cru, para quem precisa de um tocador proprio em vez da piscina. O
## radio e o caso: ele toca em loop continuo num bus proprio.
func stream(nome: StringName) -> AudioStream:
	return _streams.get(nome)


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
	var base := _streams.get(nome) as AudioStream
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
	if not _streams.has(nome):
		push_warning("AudioDirector: som desconhecido '%s'" % nome)
		return null
	for p: AudioStreamPlayer3D in _piscina3d:
		if p.playing:
			continue
		p.stream = _streams[nome]
		p.global_position = pos
		p.volume_db = volume_db
		p.pitch_scale = afinacao
		p.play()
		return p
	# Sem voz livre e um resultado valido, nao um erro: e o teto de vozes agindo.
	return null


func tocar_ui(nome: StringName, volume_db: float = 0.0) -> void:
	if _mudo or not _streams.has(nome):
		return
	for p: AudioStreamPlayer in _piscina2d:
		if p.playing:
			continue
		p.stream = _streams[nome]
		p.volume_db = volume_db
		p.play()
		return


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
	if not _streams.has(nome):
		push_warning("AudioDirector: ambiente desconhecido '%s'" % nome)
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[nome]
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
