## O desfoque de movimento do preset MODERNO: criterio A15 do PLANO_AAA_4K.
##
## Por que um `CompositorEffect`, e nao o pos-processo que ja existe
## -----------------------------------------------------------------
## O `ColorRect` do `psx_post` le `SCREEN_TEXTURE` e mais nada. Desfoque de
## movimento precisa da PROFUNDIDADE e das matrizes de camera do quadro
## anterior, e nenhuma das duas existe num shader de canvas. `CompositorEffect`
## e a unica porta para elas.
##
## O rastro e reconstruido, e nao lido
## -----------------------------------
## O motor tem um buffer de vetores de movimento, mas ele so existe quando o
## TAA ou o FSR 2 o pedem — e o degrau CRU da escada nao tem nenhum dos dois.
## Aqui o rastro sai da profundidade e de uma matriz de reprojecao que a
## `Lente` monta a partir da `Camera3D`. Ver o cabecalho do
## `shaders/desfoque_movimento.glsl`.
##
## Por que dois passes
## -------------------
## Cada pixel de saida le uma RETA de pixels de entrada. Escrever na mesma
## imagem que se le e corrida: o vizinho que este pixel precisa pode ja ter sido
## trocado pelo borrao dele. Entao o compute escreve num alvo proprio.
##
## E a volta e um SEGUNDO dispatch, e nao um `texture_copy`. O buffer de cor da
## cena nasce sem `TEXTURE_USAGE_CAN_COPY_TO_BIT` e o motor recusa a copia com
## um erro por quadro — sessenta por segundo, que foi como isto apareceu. Como
## imagem de armazenamento ele aceita escrita normalmente.
##
## Quem liga e desliga isto e a `Lente`, que sabe se o jogador esta dirigindo.
class_name DesfoqueMovimento
extends CompositorEffect

const CAMINHO := "res://shaders/desfoque_movimento.glsl"
## Nome do contexto em que o alvo temporario vive dentro do RenderSceneBuffers.
const CONTEXTO := &"desfoque_movimento"
## Tamanho do bloco de push constant, em bytes: uma mat4 e mais oito campos.
const AJUSTES_BYTES := 96

## Fracao do deslocamento de um quadro que vira rastro.
##
## 0,5 e o obturador de 180 graus: a pa da camera de cinema fica aberta metade
## do intervalo entre quadros, e o rastro de um objeto e metade do que ele andou.
## E o valor que o olho aceita como "filmado" — acima dele o mundo vira cometa.
var forca: float = 0.0
## Teto do rastro, em fracao da LARGURA da imagem.
##
## Fracao, e nao pixels: 22 px eram 1,7% da tela em 1280 e seriam 0,6% em 4K —
## o mesmo carro, na mesma velocidade, borraria tres vezes menos na tela maior.
var teto_fracao: float = 0.018
## Amostras ao longo do rastro. Doze: com o teto em 1,8% da largura, o rastro
## cheio em 4K tem 69 px, e menos amostras que isso sobre ele e escada.
var amostras: int = 12
## Diagnostico: 1 rastro fixo, 2 tela vermelha, 3 rastro pintado. Ver o shader.
var depurar := 0

## `vp_anterior * inverso(vp_atual)`. Quem calcula e a `Lente`, na linha
## principal, a partir da propria `Camera3D` — a convencao daquela matriz foi
## conferida ponto a ponto contra `unproject_position` antes de virar codigo.
var reprojecao := Projection()

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _amostrador: RID
var _chamadas := 0


func _init() -> void:
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	# A profundidade resolvida, e nao a de MSAA: o projeto roda com MSAA
	# desligado, mas pedir a resolvida deixa o efeito correto se um dia ligar.
	access_resolved_depth = true
	enabled = false
	_rd = RenderingServer.get_rendering_device()
	if _rd == null:
		# Perfil de Compatibility (ou headless): nao ha RenderingDevice, e o
		# efeito simplesmente nao existe. Nada de erro — o PS1 STYLE roda ali.
		return
	RenderingServer.call_on_render_thread(_compilar)


func _notification(que: int) -> void:
	if que != NOTIFICATION_PREDELETE or _rd == null:
		return
	if _shader.is_valid():
		_rd.free_rid(_shader)
	if _amostrador.is_valid():
		_rd.free_rid(_amostrador)


func _compilar() -> void:
	var arquivo := ResourceLoader.load(CAMINHO) as RDShaderFile
	if arquivo == null:
		push_error("DesfoqueMovimento: %s nao carregou" % CAMINHO)
		return
	var spirv := arquivo.get_spirv()
	if spirv == null:
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if _shader.is_valid():
		_pipeline = _rd.compute_pipeline_create(_shader)
	# Ponto, e preso na borda: a profundidade e lida no centro do proprio pixel,
	# entao filtro linear so misturaria a silhueta do vizinho na reprojecao.
	var estado := RDSamplerState.new()
	estado.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	estado.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	estado.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	estado.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_amostrador = _rd.sampler_create(estado)


func _render_callback(_tipo: int, dados: RenderData) -> void:
	if _rd == null or not _pipeline.is_valid():
		return
	var buffers := dados.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var tam := buffers.get_internal_size()
	if tam.x <= 0 or tam.y <= 0:
		return
	_chamadas += 1

	# O alvo temporario acompanha o tamanho interno sozinho: `create_texture` no
	# mesmo contexto devolve a que ja existe, e o motor a recria quando a janela
	# muda de tamanho. Guardar a RID aqui seria guardar a do tamanho anterior.
	buffers.create_texture(CONTEXTO, &"alvo",
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT,
		RenderingDevice.TEXTURE_SAMPLES_1, tam, 1, 1, true, false)

	var grupos_x := int(ceil(float(tam.x) / 8.0))
	var grupos_y := int(ceil(float(tam.y) / 8.0))
	for vista in buffers.get_view_count():
		if forca <= 0.0 and depurar == 0:
			continue

		var cor := buffers.get_color_layer(vista)
		var prof := buffers.get_depth_layer(vista)
		if not cor.is_valid() or not prof.is_valid():
			continue
		var alvo := buffers.get_texture_slice(CONTEXTO, &"alvo", vista, 0, 1, 1)

		var borrar := UniformSetCacheRD.get_cache(_shader, 0,
			[_imagem(0, cor), _imagem(1, alvo), _amostrada(2, prof)] as Array[RDUniform])
		var devolver := UniformSetCacheRD.get_cache(_shader, 0,
			[_imagem(0, alvo), _imagem(1, cor), _amostrada(2, prof)] as Array[RDUniform])

		var lista := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(lista, _pipeline)
		_rd.compute_list_bind_uniform_set(lista, borrar, 0)
		_rd.compute_list_set_push_constant(lista,
			_ajustes(tam, 0, reprojecao), AJUSTES_BYTES)
		_rd.compute_list_dispatch(lista, grupos_x, grupos_y, 1)
		# A barreira nao e formalidade: sem ela o passe de volta comeca a ler o
		# alvo enquanto o primeiro ainda escreve nele, e o resultado e uma faixa
		# de tela borrada e o resto nao.
		_rd.compute_list_add_barrier(lista)
		_rd.compute_list_bind_uniform_set(lista, devolver, 0)
		_rd.compute_list_set_push_constant(lista,
			_ajustes(tam, 1, reprojecao), AJUSTES_BYTES)
		_rd.compute_list_dispatch(lista, grupos_x, grupos_y, 1)
		_rd.compute_list_end()


## Quantas vezes o callback rodou. Diagnostico.
func chamadas() -> int:
	return _chamadas


func _ajustes(tam: Vector2i, modo: int, m: Projection) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(AJUSTES_BYTES)
	# std430 poe a mat4 como quatro colunas de vec4, na ordem das colunas — que
	# e exatamente como o `Projection` guarda x, y, z e w.
	var colunas: Array[Vector4] = [m.x, m.y, m.z, m.w]
	for c in 4:
		for r in 4:
			b.encode_float(c * 16 + r * 4, colunas[c][r])
	b.encode_s32(64, tam.x)
	b.encode_s32(68, tam.y)
	b.encode_float(72, forca)
	b.encode_float(76, teto_fracao * float(tam.x))
	b.encode_s32(80, amostras)
	b.encode_s32(84, modo)
	b.encode_s32(88, depurar)
	b.encode_float(92, float(_chamadas % 64) * 7.0)
	return b


static func _imagem(binding: int, textura: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(textura)
	return u


func _amostrada(binding: int, textura: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(_amostrador)
	u.add_id(textura)
	return u
