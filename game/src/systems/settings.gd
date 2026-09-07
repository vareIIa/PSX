## Autoload. Le e grava as preferencias do jogador e avisa quem depende delas.
##
## Todo valor visual ajustavel pelo jogador passa por aqui. Nenhum sistema le o
## arquivo de configuracao direto, e nenhum sistema guarda copia do valor: eles
## escutam `changed` e reaplicam. Isso e o que faz o menu de opcoes funcionar sem
## reiniciar a cena.
extends Node

const CONFIG_PATH := "user://settings.cfg"
const SECTION_VIDEO := "video"

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

var _presets: Dictionary[StringName, FogPreset] = {}
var _loading: bool = false


func _ready() -> void:
	_load_presets()
	load_config()
	_apply_cmdline_overrides()


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

func set_post(key: StringName, value: Variant) -> void:
	match key:
		&"chromatic": chromatic = clampf(float(value), 0.0, 2.0)
		&"grain": grain = clampf(float(value), 0.0, 0.2)
		&"scanline": scanline = clampf(float(value), 0.0, 0.5)
		&"vignette": vignette = clampf(float(value), 0.0, 1.0)
		&"dither": dither = bool(value)
		_:
			push_warning("Settings: chave de pos-processo desconhecida '%s'" % key)
			return
	_commit()


# --- persistencia -----------------------------------------------------------

func load_config() -> void:
	_loading = true
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		fog_preset_id = StringName(cfg.get_value(SECTION_VIDEO, "fog_preset", String(fog_preset_id)))
		chromatic = float(cfg.get_value(SECTION_VIDEO, "chromatic", chromatic))
		grain = float(cfg.get_value(SECTION_VIDEO, "grain", grain))
		scanline = float(cfg.get_value(SECTION_VIDEO, "scanline", scanline))
		vignette = float(cfg.get_value(SECTION_VIDEO, "vignette", vignette))
		dither = bool(cfg.get_value(SECTION_VIDEO, "dither", dither))
		# Escolha gravada que nao e mais um clima — id apagado, ou um dos
		# internos que ja apareceram no menu — volta ao padrao. Sem isso o
		# jogador que parou num deles abre o jogo nele para sempre.
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
	cfg.set_value(SECTION_VIDEO, "chromatic", chromatic)
	cfg.set_value(SECTION_VIDEO, "grain", grain)
	cfg.set_value(SECTION_VIDEO, "scanline", scanline)
	cfg.set_value(SECTION_VIDEO, "vignette", vignette)
	cfg.set_value(SECTION_VIDEO, "dither", dither)
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_error("Settings: falha ao gravar %s (erro %d)" % [CONFIG_PATH, err])


func _commit() -> void:
	if _loading:
		return
	changed.emit()
	save_config()
