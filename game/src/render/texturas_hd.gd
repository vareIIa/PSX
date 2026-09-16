## O conjunto de texturas de 1024 px do preset MODERNO (PLANO_AAA_4K, Fase 3).
##
## Quem chama e o `EstiloVisual`, no mesmo ponto em que ele troca o shader de
## superficie: MODERNO liga o conjunto HD, PS1 STYLE desliga e o material volta a
## usar o `albedo_tex` de 256 px, com filtro ponto, exatamente como antes.
##
## Uma fonte, duas fidelidades
## ---------------------------
## As duas versoes saem da MESMA foto CC0 do ambientCG. `tools/baixar_texturas.py`
## reduz para 256 px e aumenta o contraste (o PS1 precisa disso para sobreviver a
## quantizacao); `tools/texturas_hd.py` pega o mesmo zip e guarda 1024 px de cor,
## normal, rugosidade e oclusao. Nenhuma das duas e mantida a mao, e por isso elas
## nao divergem.
##
## Por que o material nao e trocado, so os parametros
## --------------------------------------------------
## A alternativa seria uma pasta `materials_hd/` com uma copia de cada `.tres`.
## Duas copias do mesmo material sao duas verdades sobre a mesma superficie: a
## molhabilidade, o vento e o corte de alfa teriam de ser mantidos iguais nos dois
## lugares para sempre. Aqui o material e um so; o que muda e qual textura ele le.
class_name TexturasHD
extends RefCounted

const DIR := "res://assets/textures_hd/"

## Superficies que ainda nao tem conjunto HD ficam sem ele e continuam corretas:
## `usa_hd` vai a falso e o shader le o albedo de sempre. Isso permite a Fase 3
## crescer superficie por superficie, com medida, em vez de tudo de uma vez.
static var _existe: Dictionary[StringName, bool] = {}
## `--sem-hd` desliga o conjunto inteiro, para a mesma cena poder ser medida com
## e sem ele. E o interruptor de diagnostico da Fase 3, irmao do `--sem-facho`.
static var _desligado: int = -1


static func desligado() -> bool:
	if _desligado < 0:
		_desligado = 1 if OS.get_cmdline_user_args().has("--sem-hd") else 0
	return _desligado == 1


## Liga (ou desliga) o conjunto HD neste material. Devolve se ele tem conjunto.
static func aplicar(mat: ShaderMaterial, nome: StringName, hd: bool) -> bool:
	if mat == null:
		return false
	if desligado() or not tem(nome):
		mat.set_shader_parameter(&"usa_hd", false)
		return false
	if not hd:
		mat.set_shader_parameter(&"usa_hd", false)
		return true
	mat.set_shader_parameter(&"albedo_hd", load(_achar(nome, "")))
	var normal := _achar(nome, "_n")
	if not normal.is_empty():
		mat.set_shader_parameter(&"normal_hd", load(normal))
	var ru := _achar(nome, "_ru")
	if not ru.is_empty():
		mat.set_shader_parameter(&"rugosidade_hd", load(ru))
	# `--sem-relevo` zera so o mapa de normal, mantendo cor e rugosidade. E o A/B
	# do criterio A9: comparar HD contra a textura de 256 px mediria as duas
	# coisas juntas (resolucao e relevo), e o filtro ponto da de 256 px ainda
	# INFLA o desvio de luminancia com degrau de pixel — medido, a parede de
	# metal deu desvio maior sem HD.
	mat.set_shader_parameter(&"relevo", _forca_do_relevo())
	mat.set_shader_parameter(&"usa_hd", true)
	return true


## Forca do relevo, com `--sem-relevo` e `--relevo=N` por cima, para calibrar.
static func _forca_do_relevo() -> float:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--sem-relevo":
			return 0.0
		if arg.begins_with("--relevo="):
			return maxf(arg.trim_prefix("--relevo=").to_float(), 0.0)
	return 1.0


static func tem(nome: StringName) -> bool:
	if not _existe.has(nome):
		_existe[nome] = not _achar(nome, "").is_empty()
	return _existe[nome]


## O arquivo do mapa, seja ele JPG ou PNG, ou vazio se nao houver.
##
## Foto do ambientCG sai em JPG; textura DESENHADA por script (folhagem, tinta de
## via) sai em PNG, porque tem alfa ou porque o bloco do JPG estragaria o traco.
## Quem pede o mapa nao precisa saber de qual dos dois veio.
static func _achar(nome: StringName, sufixo: String) -> String:
	for ext: String in [".png", ".jpg"]:
		var caminho := DIR + String(nome) + sufixo + ext
		if ResourceLoader.exists(caminho):
			return caminho
	return ""


## Quantas superficies do conjunto existem em disco. Para relatorio e teste.
static func quantas() -> int:
	var d := DirAccess.open(DIR)
	if d == null:
		return 0
	var n := 0
	for f: String in d.get_files():
		var nome := f.trim_suffix(".remap")
		if not (nome.ends_with(".jpg") or nome.ends_with(".png")):
			continue
		var base := nome.get_basename()
		if not base.ends_with("_n") and not base.ends_with("_ru"):
			n += 1
	return n
