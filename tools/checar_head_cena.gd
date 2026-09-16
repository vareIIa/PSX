extends Node
## Cena de verificacao do `tools/checar_head.sh` (criterio A1 do PLANO_AAA_4K).
##
## Roda DENTRO de uma copia de uma revisao do git, como cena principal de uma
## execucao normal — e nao por `--script`, porque no `--script` os nomes dos
## autoloads nao existem para o compilador, e todo script que usa `Settings` ou
## `Clima` pareceria quebrado sem estar (memoria "teste de nivel 2 nao alcanca
## classe de tela").
##
## Ordem: scripts, shaders, recursos, cenas. Scripts primeiro para que cada erro
## de analise saia na carga do PROPRIO script, e nao dentro de uma cena que o usa
## (a cena carrega mesmo com o script quebrado).
##
## `can_instantiate()` NAO basta como veredito: um script cuja dependencia nao
## compila ("Failed to compile depended scripts") foi medido voltando verdadeiro.
## Por isso o veredito final e do `checar_head.sh`, que le as mensagens do motor;
## esta cena conta o que consegue e acrescenta o que o motor nao ve no modo
## headless: `global uniform` sem declaracao em `[shader_globals]`, que so
## quebraria com janela aberta, na hora de desenhar.
##
##   [checar_head] falha script res://src/x.gd
##   [checar_head] falha global psx_chuva res://shaders/y.gdshader
##   [checar_head] scripts=412 cenas=88 recursos=301 shaders=31 falhas=0

const PULAR := ["res://.godot", "res://addons"]
const ORDEM := ["gd", "gdshader", "gdshaderinc", "tres", "tscn"]

var _falhas := 0
var _re_global := RegEx.create_from_string(
	"(?m)^\\s*global\\s+uniform\\s+\\w+\\s+(\\w+)")


func _ready() -> void:
	var arquivos: Array[String] = []
	_listar("res://", arquivos)
	arquivos.sort()
	var contagem := {}
	for ext in ORDEM:
		contagem[ext] = 0
		for caminho in arquivos:
			if caminho.get_extension() != ext:
				continue
			contagem[ext] += 1
			match ext:
				"gd":
					_checar_script(caminho)
				"gdshader", "gdshaderinc":
					_checar_globais(caminho)
					if ext == "gdshader":
						_checar_recurso(caminho, "shader")
				"tres":
					_checar_recurso(caminho, "recurso")
				"tscn":
					_checar_recurso(caminho, "cena")
	print("[checar_head] scripts=%d cenas=%d recursos=%d shaders=%d falhas=%d" % [
		contagem["gd"], contagem["tscn"], contagem["tres"],
		contagem["gdshader"] + contagem["gdshaderinc"], _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


func _checar_script(caminho: String) -> void:
	var s := ResourceLoader.load(caminho, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
	if s == null or not s.can_instantiate():
		_falhar("script", caminho)


func _checar_recurso(caminho: String, tipo: String) -> void:
	if ResourceLoader.load(caminho, "", ResourceLoader.CACHE_MODE_REUSE) == null:
		_falhar(tipo, caminho)


## O modo headless nao compila shader; um `global uniform` sem declaracao no
## `project.godot` so falharia com janela. Isto le o texto e confere.
func _checar_globais(caminho: String) -> void:
	var texto := FileAccess.get_file_as_string(caminho)
	for m in _re_global.search_all(texto):
		var nome := m.get_string(1)
		if not ProjectSettings.has_setting("shader_globals/" + nome):
			_falhar("global " + nome, caminho)


func _falhar(tipo: String, caminho: String) -> void:
	_falhas += 1
	print("[checar_head] falha %s %s" % [tipo, caminho])


func _listar(pasta: String, saida: Array[String]) -> void:
	if pasta.trim_suffix("/") in PULAR:
		return
	var d := DirAccess.open(pasta)
	if d == null:
		return
	for f in d.get_files():
		saida.append(pasta.path_join(f))
	for sub in d.get_directories():
		_listar(pasta.path_join(sub), saida)
