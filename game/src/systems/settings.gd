## Autoload. Le e grava as preferencias do jogador e avisa quem depende delas.
##
## Todo valor visual ajustavel pelo jogador passa por aqui. Nenhum sistema le o
## arquivo de configuracao direto, e nenhum sistema guarda copia do valor: eles
## escutam `changed` e reaplicam. Isso e o que faz o menu de opcoes funcionar sem
## reiniciar a cena.
extends Node

const CONFIG_PATH := "user://settings.cfg"
const SECTION_VIDEO := "video"
const SECTION_AUDIO := "audio"

## Buses ajustaveis, na ordem em que aparecem no menu.
##
## Sao os do `default_bus_layout.tres`. Existiam desde sempre e nenhum tinha
## controle: o jogo inteiro passou a vida sem uma linha de volume, e quem achava
## a chuva alta demais so tinha o mixer do sistema operacional.
##
## `Radio` fica de fora de proposito. Ele nao e uma categoria de som, e um objeto
## do mundo — o radio do carro tem o proprio botao, e um deslizador de menu
## competindo com ele daria dois volumes para a mesma coisa.
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX", &"Ambiente"]

## Nome de cada bus na tela. O jogador nao sabe o que e "Ambiente" num mixer.
const BUS_ROTULO := {
	&"Master": "GERAL",
	&"Music": "MUSICA",
	&"SFX": "EFEITOS",
	&"Ambiente": "AMBIENTE",
}

## Volume em que um bus nasce: TODOS cheios.
##
## A tentacao e nascer com musica em 0,8 e ambiente em 0,72, que e mais ou menos
## a proporcao do `default_bus_layout.tres`. Estaria errado: a atenuacao do
## layout ja e aplicada por `VOLUME_BASE`, e os dois juntos deixariam o jogo 4,5
## dB mais baixo do que era no dia anterior ao menu existir.
##
## Deslizador cheio tem de reproduzir exatamente a mistura que ja foi ajustada de
## ouvido ao longo do projeto. Ligar o menu nao pode mudar o som de quem nunca
## mexeu nele.
const VOLUME_PADRAO := {
	&"Master": 1.0,
	&"Music": 1.0,
	&"SFX": 1.0,
	&"Ambiente": 1.0,
}

## Ganho que cada bus ja tinha no `default_bus_layout.tres`, em dB. Somado por
## cima do deslizador — ver `VOLUME_PADRAO`.
const VOLUME_BASE := {
	&"Master": 0.0,
	&"Music": -4.0,
	&"SFX": 0.0,
	&"Ambiente": -8.0,
}

## Abaixo disto o bus e mudo de verdade, e nao -60 dB.
##
## Um deslizador que chega ao fim e ainda deixa um fiapo de som e um deslizador
## quebrado: o jogador arrasta ate zero justamente porque quer silencio.
const VOLUME_MUDO := 0.001

## Climas oferecidos ao jogador, na ordem em que aparecem no menu e na ordem em
## que a tecla de debug cicla. Os ids batem com FogPreset.id.
## Climas normais: dia e noite com variacoes de tempo.
## Climas especiais (neblina*): Silent Hill Vibe.
const FOG_PRESET_IDS: Array[StringName] = [
	&"dia_sol", &"dia_nuvens", &"dia_chuva",
	&"noite_estrelada", &"noite_nublada", &"noite_chuva",
	&"neblina", &"neblina_chuva",
]

## Presets que existem mas nao sao clima: interiores os impoem por `forcar` e a
## verificacao automatizada os pede por `--fog=`. Ficam carregados e fora do
## menu — sao estados de ambiente, nao tempo la fora, e oferece-los como escolha
## e o que fazia o jogo abrir preso num deles.
const FOG_PRESET_INTERNOS: Array[StringName] = [&"denso", &"leve", &"off"]

## Clima usado quando nao ha escolha valida gravada.
const FOG_PRESET_PADRAO: StringName = &"neblina_chuva"

const FOG_PRESET_DIR := "res://resources/fog/"

# --- estilo visual ----------------------------------------------------------

## Como o jogo desenha. Nao e "qualidade": e a estetica escolhida.
##
## MODERNO e o padrao. PS1_STYLE reproduz a build anterior ao interruptor —
## nao "parecido com", e sim identico: os valores abaixo sao exatamente os do
## ART-BIBLE secoes 2, 3, 4 e 9, e o teste de aceite compara captura por captura.
## PERSONALIZADO nao e escolhido no menu; ele aparece sozinho quando o jogador
## mexe em um controle individual.
enum Estilo { MODERNO, PS1_STYLE, PERSONALIZADO }

const ESTILO_ROTULO := {
	Estilo.MODERNO: "MODERNO",
	Estilo.PS1_STYLE: "PS1 STYLE",
	Estilo.PERSONALIZADO: "PERSONALIZADO",
}

## Estilos oferecidos no menu, na ordem. PERSONALIZADO fica fora: ele e um
## estado em que o jogador cai, nao uma opcao que ele escolhe.
const ESTILOS_OFERECIDOS: Array[Estilo] = [Estilo.MODERNO, Estilo.PS1_STYLE]

## Os dois presets, controle por controle.
##
## O que MUDA entre eles e resolucao, ruido de imagem e modelo de iluminacao.
## O que NAO muda, e nao deve mudar, e o filtro de textura (ponto nos dois) e a
## geometria low-poly: sao eles que sustentam a identidade. Sem isso o MODERNO
## deixaria de ser o mesmo jogo com luz melhor e viraria outro jogo.
const ESTILO_PRESETS := {
	Estilo.MODERNO: {
		&"resolucao_3d": Vector2i(1280, 720),
		&"dither": false,
		&"scanline": 0.0,
		&"grain": 0.02,
		&"chromatic": 0.15,
		&"vignette": 0.18,
		&"snap": false,
		&"affine": false,
		&"luz_por_pixel": true,
		&"sombras": true,
	},
	# ART-BIBLE secoes 2, 3, 4 e 9. Mexer aqui quebra o teste de identidade.
	Estilo.PS1_STYLE: {
		&"resolucao_3d": Vector2i(480, 270),
		&"dither": true,
		&"scanline": 0.12,
		&"grain": 0.08,
		&"chromatic": 0.6,
		&"vignette": 0.45,
		&"snap": true,
		&"affine": true,
		&"luz_por_pixel": false,
		&"sombras": false,
	},
}

## Resolucao interna de referencia do snap. A grade do ART-BIBLE e metade de
## 480x270; ao subir a resolucao, `psx_snap_escala` mantem a PROPORCAO em vez do
## numero, senao o tremor de vertice desaparece sozinho na resolucao alta.
const RESOLUCAO_BASE := Vector2i(480, 270)

## Emitido depois de qualquer alteracao ja aplicada ao estado interno.
signal changed()

# --- estado -----------------------------------------------------------------
# Padroes vindos de docs/ART-BIBLE.md secao 9.

var fog_preset_id: StringName = FOG_PRESET_PADRAO
var chromatic: float = 0.6
var grain: float = 0.08
var scanline: float = 0.12
var vignette: float = 0.45
var dither: bool = true

## Estilo em vigor. E a fonte de verdade: enquanto ele nao for PERSONALIZADO, os
## controles individuais sao DERIVADOS do preset e o que estiver gravado neles no
## arquivo e ignorado. Isso e o que garante que PS1_STYLE seja sempre identico —
## sem essa regra, um valor solto de uma versao antiga faria o preset divergir em
## silencio e o teste de identidade quebraria sem ninguem saber por que.
var estilo: Estilo = Estilo.MODERNO

## Resolucao interna do 3D. Fora do `set_post` porque nao e pos-processo.
var resolucao_3d: Vector2i = Vector2i(1280, 720)
## Tremor de vertice e textura nadando, os dois tracos de geometria do PS1.
var snap: bool = false
var affine: bool = false
## Modelo de iluminacao. `false` = por vertice (psx_surface),
## `true` = por pixel (psx_surface_pixel). Quem troca o shader e o EstiloVisual.
var luz_por_pixel: bool = true
## Sombra projetada. Quem decide QUAIS luzes projetam e o DiretorSombra, que
## trabalha com orcamento: ligar sombra em toda luz da rua nao e mais bonito, e
## mais caro e mais chapado.
var sombras: bool = true

## Volume por bus, de 0 a 1. Linear na tela, decibel no motor: ver `_db`.
var volume: Dictionary[StringName, float] = {}

## Joypad: ligacoes, olhar pelo analogico e qual dispositivo esta no comando.
## A interface le `Settings.controle.dispositivo` para escrever a dica certa.
var controle: Controle

var _presets: Dictionary[StringName, FogPreset] = {}
var _loading: bool = false


func _ready() -> void:
	for bus: StringName in BUSES:
		volume[bus] = float(VOLUME_PADRAO.get(bus, 1.0))
	# Instalacao nova nasce no preset, e nao nos padroes soltos das variaveis.
	# Sem esta linha o jogo sem settings.cfg abriria misturado: resolucao de
	# MODERNO com o grao e o dither de PS1 STYLE.
	_derivar_do_preset(Estilo.MODERNO)
	_load_presets()
	load_config()
	_apply_cmdline_overrides()
	_aplicar_audio()
	# O controle de videogame nasce aqui, e nao como autoload: `project.godot` e
	# o arquivo que mais sofre com sessoes paralelas. Ver `Controle`.
	controle = Controle.new()
	controle.name = "Controle"
	add_child(controle)


## Sobrescreve preferencias pela linha de comando, sem gravar em disco.
## Usado pela captura automatizada para varrer presets:
##     godot --path game -- --fog=denso --shot=denso.png
func _apply_cmdline_overrides() -> void:
	var mudou := false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fog="):
			var id := StringName(arg.trim_prefix("--fog="))
			if _presets.has(id):
				fog_preset_id = id
				mudou = true
			else:
				push_warning("Settings: --fog=%s desconhecido, ignorado" % id)
		elif arg == "--no-post":
			chromatic = 0.0
			grain = 0.0
			scanline = 0.0
			vignette = 0.0
			mudou = true
		elif arg.begins_with("--estilo="):
			# `--estilo=ps1` e o que a verificacao usa para provar que o preset
			# reproduz a build antiga captura por captura.
			var nome := arg.trim_prefix("--estilo=").to_lower()
			if nome in ["ps1", "ps1_style", "psx"]:
				estilo = Estilo.PS1_STYLE
			elif nome in ["moderno", "modern"]:
				estilo = Estilo.MODERNO
			else:
				push_warning("Settings: --estilo=%s desconhecido, ignorado" % nome)
				continue
			_derivar_do_preset(estilo)
			mudou = true
	if mudou:
		changed.emit()


# --- presets ----------------------------------------------------------------

func _load_presets() -> void:
	for id: StringName in (FOG_PRESET_IDS + FOG_PRESET_INTERNOS):
		var path := "%sfog_%s.tres" % [FOG_PRESET_DIR, id]
		if not ResourceLoader.exists(path):
			push_error("Settings: preset de nevoa ausente em %s" % path)
			continue
		var preset := load(path) as FogPreset
		if preset == null:
			push_error("Settings: %s nao e um FogPreset" % path)
			continue
		_presets[id] = preset


## Preset de nevoa ativo. Nunca retorna null: cai no primeiro disponivel.
func fog_preset() -> FogPreset:
	if _presets.has(fog_preset_id):
		return _presets[fog_preset_id]
	push_warning("Settings: preset '%s' indisponivel, usando fallback" % fog_preset_id)
	if _presets.has(FOG_PRESET_PADRAO):
		return _presets[FOG_PRESET_PADRAO]
	for id: StringName in FOG_PRESET_IDS:
		if _presets.has(id):
			return _presets[id]
	return FogPreset.new()


func all_fog_presets() -> Array[FogPreset]:
	var out: Array[FogPreset] = []
	for id: StringName in FOG_PRESET_IDS:
		if _presets.has(id):
			out.append(_presets[id])
	return out


func set_fog_preset(id: StringName) -> void:
	if id == fog_preset_id:
		return
	if not _presets.has(id):
		push_warning("Settings: preset desconhecido '%s', ignorado" % id)
		return
	fog_preset_id = id
	_commit()


## Alterna para o proximo preset. Usado pela tecla de atalho de debug.
func cycle_fog_preset() -> void:
	var i := FOG_PRESET_IDS.find(fog_preset_id)
	set_fog_preset(FOG_PRESET_IDS[(i + 1) % FOG_PRESET_IDS.size()])


# --- ajustes de pos-processo ------------------------------------------------

# --- audio ------------------------------------------------------------------

## Volume de um bus, de 0 a 1.
func set_volume(bus: StringName, valor: float) -> void:
	if not volume.has(bus):
		push_warning("Settings: bus desconhecido '%s'" % bus)
		return
	volume[bus] = clampf(valor, 0.0, 1.0)
	_aplicar_audio()
	_commit()


func get_volume(bus: StringName) -> float:
	return float(volume.get(bus, 1.0))


## Escreve os volumes no AudioServer.
##
## O deslizador e linear porque e assim que um deslizador de volume tem de se
## comportar na mao de quem arrasta; o motor quer decibel. A conversao nao e
## linear->dB direto: `linear_to_db(0.5)` da -6 dB, que soa quase igual ao cheio.
## Elevar a 2,4 primeiro faz o meio do curso soar como meio volume, que e o que a
## pessoa espera ao parar o dedo no meio.
func _aplicar_audio() -> void:
	for bus: StringName in BUSES:
		var i := AudioServer.get_bus_index(String(bus))
		if i < 0:
			continue
		var v: float = volume.get(bus, 1.0)
		AudioServer.set_bus_mute(i, v <= VOLUME_MUDO)
		AudioServer.set_bus_volume_db(i, _db(v) + float(VOLUME_BASE.get(bus, 0.0)))


static func _db(linear: float) -> float:
	if linear <= VOLUME_MUDO:
		return -80.0
	return linear_to_db(pow(linear, 2.4))



# --- estilo visual ----------------------------------------------------------

## Troca o estilo e deriva TODOS os controles do preset.
##
## Unico caminho para entrar num preset. Nao aceita PERSONALIZADO: nele nao ha
## preset para derivar, e ele so e alcancado mexendo num controle individual.
func aplicar_estilo(novo: Estilo) -> void:
	if not ESTILO_PRESETS.has(novo):
		push_warning("Settings: estilo '%s' nao tem preset, ignorado" % novo)
		return
	estilo = novo
	_derivar_do_preset(novo)
	_commit()


## Copia o preset para os controles individuais. Cast explicito em tudo: o
## dicionario e Variant e o projeto roda com `unsafe_property_access` ligado.
func _derivar_do_preset(e: Estilo) -> void:
	var p: Dictionary = ESTILO_PRESETS.get(e, {})
	if p.is_empty():
		return
	resolucao_3d = p[&"resolucao_3d"] as Vector2i
	dither = bool(p[&"dither"])
	scanline = float(p[&"scanline"])
	grain = float(p[&"grain"])
	chromatic = float(p[&"chromatic"])
	vignette = float(p[&"vignette"])
	snap = bool(p[&"snap"])
	affine = bool(p[&"affine"])
	luz_por_pixel = bool(p[&"luz_por_pixel"])
	sombras = bool(p[&"sombras"])


## Os controles atuais reproduzem este preset exatamente?
func _bate_com_preset(e: Estilo) -> bool:
	var p: Dictionary = ESTILO_PRESETS.get(e, {})
	if p.is_empty():
		return false
	return resolucao_3d == (p[&"resolucao_3d"] as Vector2i) \
		and dither == bool(p[&"dither"]) \
		and snap == bool(p[&"snap"]) \
		and affine == bool(p[&"affine"]) \
		and luz_por_pixel == bool(p[&"luz_por_pixel"]) \
		and sombras == bool(p[&"sombras"]) \
		and is_equal_approx(scanline, float(p[&"scanline"])) \
		and is_equal_approx(grain, float(p[&"grain"])) \
		and is_equal_approx(chromatic, float(p[&"chromatic"])) \
		and is_equal_approx(vignette, float(p[&"vignette"]))


## Que estilo os controles descrevem agora.
##
## Chamado depois de toda mexida individual. Serve para os dois lados: tira o
## jogador do preset quando ele muda um controle, e o DEVOLVE ao preset se ele
## desfizer a mudanca. Sem a volta, quem mexesse e voltasse atras ficaria preso
## em PERSONALIZADO para sempre, olhando um rotulo que mente.
func _estilo_dos_controles() -> Estilo:
	for e: Estilo in ESTILOS_OFERECIDOS:
		if _bate_com_preset(e):
			return e
	return Estilo.PERSONALIZADO


## Escala da grade de snap em relacao a 480x270. Ver RESOLUCAO_BASE.
func snap_escala() -> float:
	return float(resolucao_3d.x) / float(RESOLUCAO_BASE.x)


func estilo_rotulo() -> String:
	return String(ESTILO_ROTULO.get(estilo, "?"))


## Reaplica os valores do estilo em vigor, sem gravar.
##
## Usado para sair de um override de apresentacao, como o da tela CRT de
## abertura, e devolver ao jogador o que ele escolheu.
func reaplicar_estilo() -> void:
	if not ESTILO_PRESETS.has(estilo):
		return
	_derivar_do_preset(estilo)
	changed.emit()


## `persistir = false` para override de APRESENTACAO, nao de preferencia.
##
## A tela CRT de abertura empurra grao 0,14, scanline 0,28, vinheta 0,7 e
## aberracao 0,9 para imitar um tubo. Isso e cenario, nao escolha — e ate agora
## ia parar no `settings.cfg` do jogador: quem abrisse o jogo uma vez ficava com
## os quatro valores do CRT gravados como se tivesse mexido nos controles, e o
## estilo caia em PERSONALIZADO sozinho. Foi assim que os valores "customizados"
## apareceram no arquivo desta maquina sem ninguem ter tocado no menu.
func set_post(key: StringName, value: Variant, persistir: bool = true) -> void:
	match key:
		&"chromatic": chromatic = clampf(float(value), 0.0, 2.0)
		&"grain": grain = clampf(float(value), 0.0, 0.2)
		&"scanline": scanline = clampf(float(value), 0.0, 0.5)
		&"vignette": vignette = clampf(float(value), 0.0, 1.0)
		&"dither": dither = bool(value)
		&"snap": snap = bool(value)
		&"affine": affine = bool(value)
		&"luz_por_pixel": luz_por_pixel = bool(value)
		&"sombras": sombras = bool(value)
		&"resolucao_3d": resolucao_3d = value as Vector2i
		_:
			push_warning("Settings: chave de pos-processo desconhecida '%s'" % key)
			return
	if not persistir:
		# Override de apresentacao: muda a imagem e nao toca no estilo nem no
		# disco, para que `reaplicar_estilo()` consiga desfazer depois.
		changed.emit()
		return
	estilo = _estilo_dos_controles()
	_commit()


# --- persistencia -----------------------------------------------------------

func load_config() -> void:
	_loading = true
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		fog_preset_id = StringName(cfg.get_value(SECTION_VIDEO, "fog_preset", String(fog_preset_id)))

		# O estilo manda. Num preset nomeado os controles vem do preset e o que
		# estiver gravado neles e IGNORADO — e essa regra que impede um valor
		# solto de uma versao antiga de fazer o PS1 STYLE divergir em silencio.
		# So PERSONALIZADO le os controles do arquivo, porque so ali eles sao a
		# escolha do jogador e nao uma copia derivada.
		# `valor as Estilo` NAO funciona: `as` nao converte para enum em GDScript
		# e devolve null em silencio, o que jogava toda carga no ramo de baixo —
		# o jogo abria em PERSONALIZADO com os valores antigos mesmo tendo
		# `estilo=0` gravado. Comparar o inteiro e o unico jeito honesto.
		var salvo := int(cfg.get_value(SECTION_VIDEO, "estilo", int(Estilo.MODERNO)))
		var achado := false
		for e: Estilo in ESTILO_PRESETS:
			if int(e) == salvo:
				estilo = e
				achado = true
				break
		if achado:
			_derivar_do_preset(estilo)
		else:
			estilo = Estilo.PERSONALIZADO
			chromatic = float(cfg.get_value(SECTION_VIDEO, "chromatic", chromatic))
			grain = float(cfg.get_value(SECTION_VIDEO, "grain", grain))
			scanline = float(cfg.get_value(SECTION_VIDEO, "scanline", scanline))
			vignette = float(cfg.get_value(SECTION_VIDEO, "vignette", vignette))
			dither = bool(cfg.get_value(SECTION_VIDEO, "dither", dither))
			snap = bool(cfg.get_value(SECTION_VIDEO, "snap", snap))
			affine = bool(cfg.get_value(SECTION_VIDEO, "affine", affine))
			luz_por_pixel = bool(cfg.get_value(SECTION_VIDEO, "luz_por_pixel", luz_por_pixel))
			sombras = bool(cfg.get_value(SECTION_VIDEO, "sombras", sombras))
			resolucao_3d = cfg.get_value(SECTION_VIDEO, "resolucao_3d", resolucao_3d) as Vector2i
			# Mexeu e voltou ao ponto de partida: devolve o nome do preset.
			estilo = _estilo_dos_controles()
		# Escolha gravada que nao e mais um clima — id apagado, ou um dos
		# internos que ja apareceram no menu — volta ao padrao. Sem isso o
		# jogador que parou num deles abre o jogo nele para sempre.
		for bus: StringName in BUSES:
			volume[bus] = clampf(float(cfg.get_value(SECTION_AUDIO, String(bus),
				volume[bus])), 0.0, 1.0)
		if not FOG_PRESET_IDS.has(fog_preset_id):
			# `print`, e nao `push_warning`. A migracao funcionando nao e um
			# aviso: TODA instalacao anterior a lista de climas cai aqui uma
			# vez, e o nivel 1 da validacao reprova qualquer WARNING na carga.
			# Com push_warning, o proprio conserto reprovava o projeto inteiro.
			print("Settings: clima gravado '%s' nao e mais oferecido, voltando a '%s'"
				% [fog_preset_id, FOG_PRESET_PADRAO])
			fog_preset_id = FOG_PRESET_PADRAO
	_loading = false
	changed.emit()


func save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION_VIDEO, "fog_preset", String(fog_preset_id))
	cfg.set_value(SECTION_VIDEO, "estilo", int(estilo))
	cfg.set_value(SECTION_VIDEO, "chromatic", chromatic)
	cfg.set_value(SECTION_VIDEO, "grain", grain)
	cfg.set_value(SECTION_VIDEO, "scanline", scanline)
	cfg.set_value(SECTION_VIDEO, "vignette", vignette)
	cfg.set_value(SECTION_VIDEO, "dither", dither)
	cfg.set_value(SECTION_VIDEO, "snap", snap)
	cfg.set_value(SECTION_VIDEO, "affine", affine)
	cfg.set_value(SECTION_VIDEO, "luz_por_pixel", luz_por_pixel)
	cfg.set_value(SECTION_VIDEO, "sombras", sombras)
	cfg.set_value(SECTION_VIDEO, "resolucao_3d", resolucao_3d)
	for bus: StringName in BUSES:
		cfg.set_value(SECTION_AUDIO, String(bus), volume[bus])
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_error("Settings: falha ao gravar %s (erro %d)" % [CONFIG_PATH, err])


func _commit() -> void:
	if _loading:
		return
	changed.emit()
	save_config()
