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

const SHADER := "res://shaders/psx_agua_sim.gdshader"

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
const MAX_TRILHAS := 48

## Calha entre os retangulos, em texels. Sem ela o `filter_linear` do vidro
## puxa agua de uma janela para a outra na borda.
const CALHA := 2

## Quadros de limpeza antes de ligar a realimentacao. Dois: um para o alvo
## nascer zerado e outro para o `BackBufferCopy` ter o que copiar.
const QUADROS_ZERO := 2

var _vp: SubViewport
var _mat: ShaderMaterial
var _rects: Array[Rect2] = []
var _zerando: int = QUADROS_ZERO
var _tpm: float = 200.0


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
	if not ResourceLoader.exists(SHADER):
		push_error("AguaVidro: shader ausente em %s" % SHADER)
		return []
	var tam := TAM_PS1 if ps1 else TAM_MODERNO
	var feito := empacotar(paineis, tam)
	if feito.is_empty():
		push_error("AguaVidro: %d vidros nao couberam em %s" % [paineis.size(), tam])
		return []
	_rects = feito["rects"]
	_tpm = feito["tpm"]

	_vp = SubViewport.new()
	_vp.name = "MapaAgua"
	_vp.size = tam
	_vp.disable_3d = true
	_vp.transparent_bg = false
	# Ver o cabecalho: sem isto o passo por quadro some na quantizacao.
	_vp.use_hdr_2d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Limpa nos primeiros quadros; `passo` troca para NEVER depois de
	# `QUADROS_ZERO`.
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(_vp)

	# ANTES do ColorRect: e assim que o shader le o quadro passado.
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_vp.add_child(bb)

	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER) as Shader
	var rect := ColorRect.new()
	rect.size = Vector2(tam)
	rect.material = _mat
	_vp.add_child(rect)

	_mat.set_shader_parameter(&"tamanho_mapa", Vector2(tam))
	_mat.set_shader_parameter(&"tpm", _tpm)
	_mat.set_shader_parameter(&"tempo_encher", TEMPO_ENCHER)
	_mat.set_shader_parameter(&"tempo_secar", TEMPO_SECAR)
	_mat.set_shader_parameter(&"n_paineis", paineis.size())
	var rects_uv := PackedVector4Array()
	var dados := PackedVector4Array()
	for i in paineis.size():
		var r := _rects[i]
		var m: Vector2 = paineis[i]["tam"]
		rects_uv.append(Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
		dados.append(Vector4(m.x, m.y, float(paineis[i].get("exposicao", 1.0)),
			1.0 if float(paineis[i].get("limpador", 0.0)) > 0.5 else 0.0))
	_mat.set_shader_parameter(&"painel_rect", rects_uv)
	_mat.set_shader_parameter(&"painel_dados", dados)
	return _rects


## A textura do mapa, para o shader do vidro e para as corredoras.
func textura() -> Texture2D:
	return _vp.get_texture() if _vp != null else null


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

	var trilhas: PackedVector4Array = estado.get("trilhas", PackedVector4Array())
	if trilhas.size() > MAX_TRILHAS:
		trilhas = trilhas.slice(0, MAX_TRILHAS)
	_mat.set_shader_parameter(&"n_trilhas", trilhas.size())
	if not trilhas.is_empty():
		_mat.set_shader_parameter(&"trilha", trilhas)


## O retangulo de um vidro no mapa, em UV.
func rect(i: int) -> Rect2:
	return _rects[i] if i >= 0 and i < _rects.size() else Rect2()


## O mapa como imagem, para teste e para captura. Custa uma leitura da GPU:
## nunca em jogo.
func imagem() -> Image:
	return _vp.get_texture().get_image() if _vp != null else null
