## O mapa de agua do carro: onde a agua do vidro passa a ter memoria.
##
## Por que isto existe
## -------------------
## Ate a Fase 3 a agua era `cobertura`, UM float por carro. Com um numero so,
## tudo o que acontece no vidro acontece no vidro inteiro, e tres coisas que o
## olho reconhece como chuva simplesmente nao cabiam:
##
##   * o rastro da corredora, que limpa a faixa por onde ela desceu;
##   * o residuo que a borracha deixa no fim de cada passada;
##   * a sujeira, o leque fosco que todo para-brisa velho tem.
##
## O leque do limpador ainda deu para resolver em forma fechada (invertendo o
## cosseno da manivela), mas isso e um truque que so funciona para uma coisa que
## se repete. Rastro nao se repete.
##
## Aqui o estado e uma textura de um `SubViewport` que NAO LIMPA. Um
## `BackBufferCopy` copia o quadro anterior antes de o `ColorRect` desenhar, e
## `psx_agua_sim.gdshader` le esse quadro e escreve o proximo. Cada vidro ocupa
## um retangulo do mapa, e todos com a MESMA escala em texels por metro — e isso
## que faz a gota ter o mesmo tamanho no para-brisa e no quebra-vento.
##
## `use_hdr_2d` nao e enfeite (medido em 16/09/2026)
## -------------------------------------------------
## O passo real do mapa e da ordem de 0,003 por quadro. No RGBA8 um passo de
## 0,0005 desaparece INTEIRO: vinte quadros somaram 0,0000 nos dois
## renderizadores. Arredondamento estocastico entregou 0,0039 de 0,0100 no
## Forward+ e nada no Compatibility. Com `use_hdr_2d`, 0,0098 de 0,0100 nos dois.
class_name AguaVidro
extends Node

const SHADER := "res://shaders/psx_agua_mapa.gdshader"
## O passo de antes da reacao (`--agua-antiga`): sem sangue, sem pancada.
const SHADER_ANTIGO := "res://shaders/psx_agua_sim.gdshader"
## O sangue diluido, num segundo mapa (ver o shader).
const SHADER_ROSA := "res://shaders/psx_agua_rosa.gdshader"

## Tamanho do mapa: MODERNO e PS1 STYLE.
##
## O MODERNO roda em Vulkan, na resolucao da janela: com 512x256 o para-brisa
## tinha 188 texels por metro, e a borda do leque e o rastro da corredora
## saiam em degrau de 5 mm — visivel a 1280x720. Com 1024x512 sao ~375 por
## metro, e o passo de simulacao continua sendo UMA chamada de desenho num alvo
## de meio megapixel. O PS1 fica em 256x128 porque a tela dele e 480x270: um
## mapa mais fino que o pixel nao aparece.
const TAM_MODERNO := Vector2i(1024, 512)
const TAM_PS1 := Vector2i(256, 128)

## Segundos, com chuva cheia e exposicao cheia, para o vidro PARADO encher de
## gota; e para secar sem chuva. Os dois vivem aqui porque a CPU faz a mesma
## conta (`CarroCabine._mover_cobertura_cpu`) e as duas nao podem divergir.
##
## Era 5,0 s. Medido na captura a 60 km/h: com o limpador na velocidade 2 o leque
## e varrido a cada 0,84 s, e entre duas passadas a cobertura chegava a 0,25 —
## o vidro que o motorista olha ficava quase sempre limpo, e o temporal nao
## aparecia. Num temporal de verdade a gota volta logo atras da borracha.
const TEMPO_ENCHER := 1.8
const TEMPO_SECAR := 45.0

## Teto dos vetores do shader. Tem de bater com `psx_agua_sim.gdshader`.
const MAX_PAINEIS := 10
const MAX_TRILHAS := 64
const MAX_TRILHAS_ANTIGO := 48
const MAX_EVENTOS := 4
const MAX_SANGUE := 8

## Calha entre os retangulos, em texels. Sem ela o `filter_linear` do vidro
## puxa agua de uma janela para a outra na borda.
const CALHA := 2

## Quadros de limpeza antes de ligar a realimentacao. Dois: um para o alvo
## nascer zerado e outro para o `BackBufferCopy` ter o que copiar.
const QUADROS_ZERO := 2

var _vp: SubViewport
var _mat: ShaderMaterial
var _vp_rosa: SubViewport
var _mat_rosa: ShaderMaterial
var _rects: Array[Rect2] = []
var _zerando: int = QUADROS_ZERO
var _tpm: float = 200.0
## As pancadas que ainda nao foram para o passo (vivem um passo so).
var _eventos := PackedVector4Array()
var _havia_eventos := false
## As marcas de sangue que alimentam o rosa, e o rosa de cada trilha.
var _sangue := PackedVector4Array()
var _rosa_trilhas := PackedFloat32Array()
static var _antiga: int = -1


## `--agua-antiga`: a agua de antes da reacao, inteira (mapa, vidro e
## corredoras), para o A/B de desempenho e de imagem.
static func antiga() -> bool:
	if _antiga < 0:
		_antiga = 1 if OS.get_cmdline_user_args().has("--agua-antiga") else 0
	return _antiga == 1


## Em que retangulo do mapa cada vidro cai, em UV.
##
## Os retangulos nascem de uma so escala em texels por metro, achada por
## bisseccao: a maior que ainda couber. Uma escala por vidro seria mais
## apertada, e faria a gota do quebra-vento sair maior que a do para-brisa —
## que e justamente o defeito que a Fase 3 tirou da cabine.
static func empacotar(paineis: Array, tam: Vector2i) -> Dictionary:
	if paineis.is_empty() or paineis.size() > MAX_PAINEIS:
		return {}
	var lo := 8.0
	var hi := 4096.0
	var melhor: Array[Rect2] = []
	var melhor_tpm := 0.0
	for _i in 22:
		var meio := (lo + hi) * 0.5
		var r := _prateleiras(paineis, tam, meio)
		if r.is_empty():
			hi = meio
		else:
			melhor = r
			melhor_tpm = meio
			lo = meio
	if melhor.is_empty():
		return {}
	return {"rects": melhor, "tpm": melhor_tpm}


## Empacotamento por prateleiras, na escala dada. Vazio se nao couber.
static func _prateleiras(paineis: Array, tam: Vector2i, tpm: float) -> Array[Rect2]:
	var ordem: Array[int] = []
	for i in paineis.size():
		ordem.append(i)
	var mais_alto := func(a: int, b: int) -> bool:
		return (paineis[a]["tam"] as Vector2).y > (paineis[b]["tam"] as Vector2).y
	ordem.sort_custom(mais_alto)

	var saida: Array[Rect2] = []
	saida.resize(paineis.size())
	var x := CALHA
	var y := CALHA
	var altura_linha := 0
	for i: int in ordem:
		var m: Vector2 = paineis[i]["tam"]
		var w := int(ceil(m.x * tpm))
		var h := int(ceil(m.y * tpm))
		if w <= 0 or h <= 0 or w + CALHA * 2 > tam.x:
			return []
		if x + w + CALHA > tam.x:
			x = CALHA
			y += altura_linha + CALHA
			altura_linha = 0
		if y + h + CALHA > tam.y:
			return []
		saida[i] = Rect2(float(x) / tam.x, float(y) / tam.y,
			float(w) / tam.x, float(h) / tam.y)
		x += w + CALHA
		altura_linha = maxi(altura_linha, h)
	return saida


## Cria o viewport e o passo de simulacao. `paineis` vem de `VidroCabine`.
##
## Devolve os retangulos em UV, na mesma ordem dos paineis, para quem monta a
## malha de vidro escrever o UV do mapa em cada vertice.
func montar(paineis: Array, ps1: bool) -> Array[Rect2]:
	var shader := SHADER_ANTIGO if antiga() else SHADER
	if not ResourceLoader.exists(shader):
		push_error("AguaVidro: shader ausente em %s" % shader)
		return []
	var tam := TAM_PS1 if ps1 else TAM_MODERNO
	var feito := empacotar(paineis, tam)
	if feito.is_empty():
		push_error("AguaVidro: %d vidros nao couberam em %s" % [paineis.size(), tam])
		return []
	_rects = feito["rects"]
	_tpm = feito["tpm"]

	_vp = _viewport("MapaAgua", tam)
	_mat = _passo_em(_vp, shader)
	_mat.set_shader_parameter(&"tempo_encher", TEMPO_ENCHER)
	_mat.set_shader_parameter(&"tempo_secar", TEMPO_SECAR)
	var rects_uv := PackedVector4Array()
	var dados := PackedVector4Array()
	for i in paineis.size():
		var r := _rects[i]
		var m: Vector2 = paineis[i]["tam"]
		rects_uv.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		dados.append(Vector4(m.x, m.y, float(paineis[i].get("exposicao", 1.0)),
			1.0 if float(paineis[i].get("limpador", 0.0)) > 0.5 else 0.0))
	var mats: Array[ShaderMaterial] = [_mat]
	# O sangue diluido: um segundo mapa, com os mesmos retangulos.
	if not antiga() and ResourceLoader.exists(SHADER_ROSA):
		_vp_rosa = _viewport("MapaRosa", tam)
		_mat_rosa = _passo_em(_vp_rosa, SHADER_ROSA)
		_mat_rosa.set_shader_parameter(&"mapa", _vp.get_texture())
		mats.append(_mat_rosa)
	for mat: ShaderMaterial in mats:
		mat.set_shader_parameter(&"tamanho_mapa", Vector2(tam))
		mat.set_shader_parameter(&"tpm", _tpm)
		mat.set_shader_parameter(&"n_paineis", paineis.size())
		mat.set_shader_parameter(&"painel_rect", rects_uv)
		mat.set_shader_parameter(&"painel_dados", dados)
	return _rects


## Um alvo que NAO limpa (depois dos primeiros quadros), em HDR.
func _viewport(nome: String, tam: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = nome
	vp.size = tam
	vp.disable_3d = true
	vp.transparent_bg = false
	# Ver o cabecalho: sem isto o passo por quadro some na quantizacao.
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Limpa nos primeiros quadros; `passo` troca para NEVER depois de
	# `QUADROS_ZERO`.
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(vp)
	return vp


## O passo de simulacao dentro de `vp`: a copia do quadro passado e o
## retangulo que desenha o proximo.
func _passo_em(vp: SubViewport, caminho: String) -> ShaderMaterial:
	# ANTES do ColorRect: e assim que o shader le o quadro passado.
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	vp.add_child(bb)
	var mat := ShaderMaterial.new()
	mat.shader = load(caminho) as Shader
	var rect := ColorRect.new()
	rect.size = Vector2(vp.size)
	rect.material = mat
	vp.add_child(rect)
	return mat


## A textura do mapa, para o shader do vidro e para as corredoras.
func textura() -> Texture2D:
	return _vp.get_texture() if _vp != null else null


## O mapa do sangue diluido (R), para o shader do vidro. Nulo no antigo.
func textura_rosa() -> Texture2D:
	return _vp_rosa.get_texture() if _vp_rosa != null else null


func texels_por_metro() -> float:
	return _tpm


## Um passo. `estado` traz o clima, o setor do limpador e as trilhas do quadro.
func passo(estado: Dictionary, delta: float) -> void:
	if _mat == null:
		return
	if _zerando > 0:
		_zerando -= 1
		if _zerando == 0:
			# Agora o alvo guarda o quadro: e isto que faz a agua ter memoria.
			_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
			if _vp_rosa != null:
				_vp_rosa.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	# Um quadro longo demais (carga de chunk) daria um salto de agua visivel.
	_mat.set_shader_parameter(&"dt", minf(delta, 0.05))
	for chave: StringName in [&"chuva", &"vento", &"umidade", &"desembacador"]:
		_mat.set_shader_parameter(chave, float(estado.get(chave, 0.0)))

	var setor: Dictionary = estado.get("limpador", {})
	_mat.set_shader_parameter(&"limpador_ativo",
		1.0 if setor.get("ativo", false) else 0.0)
	if not setor.is_empty():
		_mat.set_shader_parameter(&"limpador_painel", int(setor["painel"]))
		_mat.set_shader_parameter(&"pivo_a", setor["pivo_a"])
		_mat.set_shader_parameter(&"pivo_b", setor["pivo_b"])
		_mat.set_shader_parameter(&"raios", setor["raios"])
		_mat.set_shader_parameter(&"ang_de", setor["ang_de"])
		_mat.set_shader_parameter(&"ang_ate", setor["ang_ate"])

	var teto := MAX_TRILHAS_ANTIGO if antiga() else MAX_TRILHAS
	var trilhas: PackedVector4Array = estado.get("trilhas", PackedVector4Array())
	if trilhas.size() > teto:
		trilhas = trilhas.slice(0, teto)
	_mat.set_shader_parameter(&"n_trilhas", trilhas.size())
	if not trilhas.is_empty():
		_mat.set_shader_parameter(&"trilha", trilhas)
	if antiga():
		return
	if _mat_rosa != null:
		_mat_rosa.set_shader_parameter(&"dt", minf(delta, 0.05))
		_mat_rosa.set_shader_parameter(&"chuva", float(estado.get(&"chuva", 0.0)))
		_mat_rosa.set_shader_parameter(&"n_trilhas", trilhas.size())
		if not trilhas.is_empty():
			var rosa := _rosa_trilhas
			if rosa.size() != trilhas.size():
				rosa = PackedFloat32Array()
				rosa.resize(trilhas.size())
			_mat_rosa.set_shader_parameter(&"trilha", trilhas)
			_mat_rosa.set_shader_parameter(&"trilha_rosa", rosa)
		_mat_rosa.set_shader_parameter(&"n_sangue", _sangue.size())
		if not _sangue.is_empty():
			_mat_rosa.set_shader_parameter(&"sangue", _sangue)
		_mat_rosa.set_shader_parameter(&"limpador_ativo",
			1.0 if setor.get("ativo", false) else 0.0)
		if not setor.is_empty():
			for chave: String in ["pivo_a", "pivo_b", "raios", "ang_de", "ang_ate"]:
				_mat_rosa.set_shader_parameter(StringName(chave), setor[chave])
			_mat_rosa.set_shader_parameter(&"limpador_painel", int(setor["painel"]))
	_rosa_trilhas = PackedFloat32Array()
	# A pancada vale um passo: o quadro em que ela chega, e so.
	if not _eventos.is_empty():
		_mat.set_shader_parameter(&"n_eventos", _eventos.size())
		_mat.set_shader_parameter(&"evento", _eventos)
		_eventos = PackedVector4Array()
		_havia_eventos = true
	elif _havia_eventos:
		_mat.set_shader_parameter(&"n_eventos", 0)
		_havia_eventos = false


## Uma pancada no ponto `uv` do mapa: a gota cai num raio de `raio_m` metros e
## a agua vira lamina em volta. Entra no proximo passo.
func bater(uv: Vector2, raio_m: float, forca: float) -> void:
	if _eventos.size() >= MAX_EVENTOS:
		return
	_eventos.append(Vector4(uv.x, uv.y, raio_m, clampf(forca, 0.0, 1.0)))


## As marcas de sangue que o vidro tem agora: (u, v no mapa, raio em m, forca).
func fontes_de_sangue(fontes: PackedVector4Array) -> void:
	_sangue = fontes.slice(0, MAX_SANGUE) if fontes.size() > MAX_SANGUE else fontes


## O sangue que cada trilha deste quadro carrega, na ordem das trilhas.
func rosa_das_trilhas(rosa: PackedFloat32Array) -> void:
	_rosa_trilhas = rosa


## O retangulo de um vidro no mapa, em UV.
func rect(i: int) -> Rect2:
	return _rects[i] if i >= 0 and i < _rects.size() else Rect2()


## O mapa como imagem, para teste e para captura. Custa uma leitura da GPU:
## nunca em jogo.
func imagem() -> Image:
	return _vp.get_texture().get_image() if _vp != null else null
