## Aplica o FogPreset ativo ao ambiente. Anexe a um WorldEnvironment.
##
## A nevoa mora no Environment e nao num shader de superficie porque precisa
## incidir depois da iluminacao. Ver docs/ART-BIBLE.md secao 8.
##
## Tambem gerencia uma DirectionalLight3D interna que simula sol (dia) ou lua
## (noite). A energia e angulo vem do FogPreset para que cada clima tenha sua
## iluminacao propria sem precisar de nos extras na cena.
class_name FogController
extends WorldEnvironment


## A nevoa da Praca da Matriz, num lugar so.
##
## Mora aqui, e nao em `abertura.gd`, porque quem forca esta nevoa sao DOIS
## arquivos: o roteiro da abertura e a `cidade.gd`, que precisa dela tambem no
## caminho sem cutscene (`--ir-para=270`). Posta em `Abertura`, a `cidade.gd`
## passava a depender da classe `Abertura` em tempo de compilacao e as duas
## fechavam ciclo — o projeto inteiro parava de carregar com "Cannot infer the
## type". `FogController` ja e dependencia das duas, entao aqui nao cria aresta
## nova.
##
## Preset proprio, e nao `noite_nublada`: aquele tem ceu 0,086, que na tela da
## 10 de 255. Medido em `PRINTS/ref_praca_matriz/01_acordar.png` o ceu da 37 e
## a nevoa ao fundo da 50 — na print a praca e ILUMINADA PELA NEVOA e o casario
## do fundo se dissolve em cinza claro em vez de sumir no preto.
const PRESET_PRACA := "res://resources/fog/fog_praca_noite.tres"

## Onde o branco satura, no estilo MODERNO. Acima de 1 o brilho deixa de estourar
## de uma vez e passa a rolar: e o que da forma ao miolo de uma lente acesa.
##
## Tres, e nao dez. Ponto branco alto comprime o brilho tanto que letreiro e
## farol voltam a ser a mesma coisa, so que agora cinzentos — trocar branco
## chapado por cinza chapado nao resolve nada. Tres e o menor valor em que a
## lente do farol ainda tem miolo branco com borda amarela.
const TONEMAP_BRANCO := 3.0

## Piso do albedo do volume. Ver `_aplicar_atmosfera`.
##
## Gotícula de chuva e poeira espalham luz de forma praticamente neutra: o ar nao
## escolhe cor, quem escolhe e a lampada. Oitenta e cinco centesimos e o valor em
## que o facho do poste aparece na chuva sem que o volume comece a levantar o
## preto da noite por conta propria.
const ALBEDO_MINIMO := 0.85

## Luz ambiente que o volume espalha, sobre a conta cor-do-ar / (ambiente x
## albedo). Calibrado na foto: a faixa da cidade no fim da nevoa = o ceu.
## `--injecao-ambiente=X` troca na bancada.
const AJUSTE_INJECAO := 1.0
const INJECAO_MAXIMA := 16.0

## Quando ligado, segue o preset escolhido pelo jogador em Settings.
## Desligue em interior, onde a nevoa e sempre off e a grade e propria.
@export var follow_settings: bool = true

## Preset usado quando follow_settings esta desligado.
@export var override_preset: FogPreset

## Se este controller responde por `get_first_node_in_group(&"fog_controller")`.
##
## O jogo inteiro descobre o clima em vigor por esse grupo, e a busca e na ARVORE
## toda — nao no World3D. Entao um segundo controller num SubViewport de mundo
## proprio (o fundo da criacao de personagem e um) passaria a atender pelo clima
## da rua, e a cidade inteira poderia acordar com a nevoa de outro lugar.
##
## Quem monta um ambiente fechado desliga isto e entrega o controller a mao a
## quem precisa dele — ver `CeuEstrada.fog`.
@export var registrar_global: bool = true

## Raio de streaming em metros do preset em uso. O ChunkManager le daqui.
var stream_radius: float = 64.0

## Preset imposto por cima de tudo. Nulo devolve o controle ao jogador.
var _forcado: FogPreset

## Luz direcional (sol ou lua) gerenciada por este controller.
var _luz_direcional: DirectionalLight3D

signal preset_applied(preset: FogPreset)


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--nevoa-linear"):
		FogPreset.forcar_linear = true
	if registrar_global:
		add_to_group(&"fog_controller")
	if environment == null:
		environment = Environment.new()
	_montar_luz_direcional()
	if follow_settings:
		Settings.changed.connect(_on_settings_changed)
	_apply()


func _montar_luz_direcional() -> void:
	_luz_direcional = DirectionalLight3D.new()
	_luz_direcional.name = "LuzDirecional"
	# Nasce apagada e se inscreve no grupo. Quem decide e o DiretorSombra, pela
	# ENERGIA do clima: sol de meio-dia projeta, lua de 0,05 de energia nao —
	# seria uma mancha que ninguem ve e todo mundo paga. No PS1 STYLE nenhuma
	# projeta e o clima fica igual ao de sempre.
	_luz_direcional.shadow_enabled = false
	_luz_direcional.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_luz_direcional.add_to_group(DiretorSombra.GRUPO)
	# Sol e lua nao entram na casa que existe na rua: o telhado dela e casca sem
	# corpo, e sem sombra o sol do meio-dia acenderia a sala inteira.
	_luz_direcional.light_cull_mask &= ~InteriorNoMundo.CAMADA
	add_child(_luz_direcional)


## Os recursos de atmosfera que o estilo decide.
##
## Isto era um bloco de cinco `= false` com o comentario "o PS1 nao tinha". A
## frase continua verdadeira no PS1 STYLE e deixou de ser uma lei do jogo: no
## MODERNO e justamente daqui que sai a noite chuvosa.
##
## Uma armadilha achada na marra: este metodo roda a CADA troca de preset —
## inclusive ao entrar num interior. Enquanto ele zerava `ssr_enabled` de forma
## incondicional, o reflexo de tela que o Clima havia ligado morria em silencio
## na primeira troca de clima, e o Clima nunca religava porque achava que ja
## estava ligado. Por isso SSR NAO e decidido aqui: ele e do Clima, que sabe se
## ha agua no chao. Este metodo so o desliga no estilo em que ele nem existe.
func _aplicar_atmosfera(env: Environment, preset: FogPreset) -> void:
	var moderno := Settings.luz_por_pixel

	# SDFGI, SSAO e SSIL NAO sao decididos aqui, pelo mesmo motivo que o SSR nao
	# e: este metodo roda a cada troca de preset, e zerar o que outro sistema
	# ligou mata o recurso em silencio na primeira troca de clima. Quem manda
	# neles e a `QualidadeGrafica`, que sabe em que degrau da escada o jogador
	# esta. Aqui eles so morrem no estilo em que nem existem.
	if not moderno:
		env.sdfgi_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
		env.ssr_enabled = false
		env.volumetric_fog_enabled = false
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		# Volta ao corte duro. No PS1 STYLE e o certo: o console nao tinha faixa
		# dinamica nenhuma e tudo que passava do branco virava branco mesmo.
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_white = 1.0
		return

	# Um CEU so para reflexo, e nao para desenhar.
	#
	# Sem isto, superficie lisa nao tem o que refletir: o ambiente e
	# `AMBIENT_SOURCE_COLOR`, que ilumina mas nao e um mapa de radiancia. A poca
	# ficava preta como buraco, e eu disfarcei pintando a cor do ceu no ALBEDO
	# dela — o que inverteu a fisica e, num dia de sol, deixou a poca mais clara
	# que o asfalto por ser tinta clara, nao por refletir.
	#
	# O `background_mode` continua BG_COLOR, entao o ceu VISIVEL e a linha de
	# horizonte nao mudam em nada: o Sky aqui so alimenta o reflexo, e a cor dele
	# e a mesma do preset, entao o que a agua devolve e exatamente o ceu que o
	# jogador ve. Ver ART-BIBLE secao 8.
	_aplicar_ceu_de_reflexo(env, preset)

	# Glow com corte alto: so letreiro, farol, janela acesa e brasa estouram. E
	# o efeito de noite mais barato que existe, e o corte e o que separa "noite
	# com luzes" de "tudo brilhando".
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	# 1,25 e nao 1,05: o corte mais alto deixa o glow para quem EMITE — letreiro,
	# farol, janela acesa, brasa — e tira dele o realce especular de superficie
	# molhada, que passa de 1,0 com facilidade e nao e fonte de luz nenhuma.
	env.glow_hdr_threshold = 1.25
	env.glow_strength = 1.0
	# SOMADO, e nao SOFTLIGHT.
	#
	# O padrao do Godot e `GLOW_BLEND_MODE_SOFTLIGHT`, que foi desenhado para
	# foto diurna: ele levanta o meio-tom e e quase invisivel sobre preto. Numa
	# rua noturna da exatamente o que se via — o farol como um retangulo amarelo
	# chapado, sem halo. O glow estava LIGADO o tempo todo; ele so nao tinha como
	# desenhar, porque o unico modo que aparece sobre fundo escuro e o somado.
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# Sem isto, TODA luz e o mesmo branco.
	#
	# O tonemap padrao e LINEAR com ponto branco 1,0: qualquer coisa acima de 1
	# vira #ffffff exato. A lente do farol (emissao 2,4), o letreiro (2,2) e um
	# realce especular em poca (1,1) saiam os TRES como a mesma chapa branca — e
	# e por isso que a fonte de luz nao tinha forma. Nao havia degrade DENTRO da
	# parte brilhante para o olho ler como intensidade.
	#
	# Com ponto branco em 3,0 o degrade volta: o miolo da lente fica branco, a
	# borda continua amarela, e o halo do glow tem de onde sair. E tambem o que
	# separa o farol de longe do farol de perto, que antes eram o mesmo pixel.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = TONEMAP_BRANCO

	# Nevoa volumetrica: o facho do poste atravessando a chuva.
	#
	# A densidade acompanha a nevoa do preset em vez de ser fixa. Um preset de
	# neblina fechada ja e ar carregado, e o facho ali e grosso; um dia de sol
	# tem ar limpo, e o mesmo valor deixaria o mundo leitoso.
	env.volumetric_fog_enabled = true
	var fechamento := 0.0
	if preset.fog_enabled:
		# fog_end de 18 m (denso) -> 1,0; de 60 m (leve) -> perto de 0.
		fechamento = clampf(inverse_lerp(70.0, 16.0, preset.fog_end), 0.0, 1.0)
	# A chuva engrossa o ar. E o que faz o facho aparecer no aguaceiro e sumir
	# quando o tempo abre, sem ninguem mexer em preset.
	var chovendo := Clima.chuva if Clima != null else 0.0
	# Valores BAIXOS de proposito. A oclusao a distancia ja e da nevoa de
	# profundidade; o volume esta aqui para o facho aparecer no ar, nao para
	# encher a rua de leite. Na primeira tentativa a faixa ia a 0,032 e o preset
	# de neblina virava uma parede branca com a nevoa antiga somada por cima.
	env.volumetric_fog_density = lerpf(0.002, 0.011, fechamento) + chovendo * 0.006
	# ALBEDO E ESPALHAMENTO, NAO COR DE NEVOA.
	#
	# Aqui estava a razao de o facho volumetrico nunca acender. O albedo diz
	# quanta luz o ar DEVOLVE; a cor da nevoa de profundidade diz com que cor o
	# mundo some ao longe. Sao coisas opostas, e passar uma para a outra
	# funcionava de dia por acidente — de dia a nevoa e clara — e falhava
	# exatamente onde o facho importa: a noite, onde `fog_color` e 0,07.
	#
	# Ar com albedo 0,07 absorve e nao espalha. Subir a densidade so escurecia a
	# rua, que e o que eu media e nao sabia ler: seis vezes mais volume, nenhum
	# facho, e a cena cada vez mais preta.
	#
	# A tonalidade do preset fica, o VALOR sobe. Assim a neblina continua
	# esverdeada e a noite continua azulada, mas as duas passam a devolver luz —
	# e o facho do poste na chuva deixa de ser geometria e vira ar aceso.
	var espalha := preset.fog_color
	env.volumetric_fog_albedo = Color.from_hsv(
		espalha.h, espalha.s * 0.5, maxf(espalha.v, ALBEDO_MINIMO))
	env.volumetric_fog_emission = preset.ambient_color
	# O volume ESPALHA a luz ambiente, na medida da cor do ar (plano, D7).
	#
	# Sem isto o volume so absorvia: a geometria atras dele saia a cor da nevoa
	# vezes a transmitancia do volume, e o ceu (que o volume nao pinta, ver
	# `volumetric_fog_sky_affect`) ficava na cor da nevoa. A silhueta da cidade
	# no fim da nevoa era MAIS ESCURA que o fundo (140 contra 148 de 255), e o
	# corte parecia sumico. Com o ar do volume da cor da nevoa, o que a nevoa
	# ja cobriu some no fundo de verdade.
	#
	# So nos climas do passo 3 (FogPreset.atmosfera_moderna): os de
	# cena foram afinados com o volume que so absorve.
	var amb := preset.ambient_color * preset.ambient_energy
	var ar := preset.cor_do_ar()
	var alb := env.volumetric_fog_albedo
	var luz := maxf((amb.r + amb.g + amb.b) / 3.0, 0.001) * maxf((alb.r + alb.g + alb.b) / 3.0, 0.01)
	env.volumetric_fog_ambient_inject = 0.0
	if preset.atmosfera_moderna and not FogPreset.forcar_linear:
		env.volumetric_fog_ambient_inject = clampf(
			(ar.r + ar.g + ar.b) / 3.0 / luz * _ajuste_injecao(), 0.0, INJECAO_MAXIMA)
	# Emissao ZERO. O volume existe para as LUZES aparecerem no ar; luz emitida
	# pelo proprio ar, numa densidade tao baixa, sai borrada em manchas do tamanho
	# do froxel — no preset de noite de chuva elas apareceram como bolhas verdes
	# espalhadas pelo ceu. Quem ilumina o volume e o poste, nao o volume.
	env.volumetric_fog_emission_energy = 0.0
	# Comprimento curto: o volume e caro e a nevoa de profundidade ja engoliu
	# tudo depois do fim do preset. Nao ha o que iluminar la atras.
	# Curto. O froxel do volume tem resolucao fixa espalhada pelo comprimento
	# pedido: pedindo 72 m, o pedaco de ar perto da camera — que e onde o facho
	# do poste acontece — fica com poucas celulas, e o ar longe fica com celulas
	# enormes que apareceram como BOLHAS VERDES no ceu noturno. Concentrar o
	# volume nos primeiros metros resolve os dois lados.
	env.volumetric_fog_length = clampf(preset.fog_end * 0.7, 18.0, 30.0)
	# O volume NAO pinta o ceu.
	#
	# O ceu esta no infinito e o volume acaba em trinta metros, entao o que o
	# motor faz por padrao e esticar a ultima fatia de froxel contra o fundo. A
	# fatia de trinta metros e enorme, e o pouco de luz de poste que cai nela vira
	# uma mancha arroxeada do tamanho de um quarteirao parada no ceu — as bolhas
	# que apareceram assim que o albedo passou a espalhar de verdade.
	#
	# O facho acontece no ar entre a lampada e a rua, nunca contra o ceu. Tirar o
	# ceu da conta nao custa nada do efeito e apaga o artefato inteiro.
	env.volumetric_fog_sky_affect = 0.0
	# Espalhamento alto empurra a resolucao do volume para longe, onde nao ha
	# facho nenhum, e deixa o perto grosseiro — que e justamente onde o facho do
	# poste precisa ser limpo.
	env.volumetric_fog_detail_spread = 1.2
	env.volumetric_fog_gi_inject = 0.0


static var _injecao := -1.0


static func _ajuste_injecao() -> float:
	if _injecao < 0.0:
		_injecao = AJUSTE_INJECAO
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--injecao-ambiente="):
				_injecao = maxf(0.0, arg.trim_prefix("--injecao-ambiente=").to_float())
	return _injecao


## Ceu de radiancia com a cor do preset. Reaproveitado entre aplicacoes.
func _aplicar_ceu_de_reflexo(env: Environment, preset: FogPreset) -> void:
	if env.sky == null:
		env.sky = Sky.new()
		env.sky.sky_material = ProceduralSkyMaterial.new()
	var mat := env.sky.sky_material as ProceduralSkyMaterial
	if mat == null:
		return
	# Chapado: as quatro cores iguais. Um degrade de horizonte apareceria no
	# reflexo da poca como uma faixa que o ceu desenhado nao tem, e o jogador
	# veria a agua refletindo um ceu que nao existe.
	mat.sky_top_color = preset.sky_color
	mat.sky_horizon_color = preset.sky_color
	mat.ground_bottom_color = preset.sky_color
	mat.ground_horizon_color = preset.sky_color
	mat.sun_angle_max = 0.0
	mat.energy_multiplier = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY


func _on_settings_changed() -> void:
	_apply()


func _apply() -> void:
	var preset := _resolve_preset()
	if preset == null:
		push_error("FogController em %s: nenhum preset resolvido" % name)
		return

	var env := environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = preset.sky_color

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.ambient_color
	env.ambient_light_energy = preset.ambient_energy
	if env.sdfgi_enabled:
		env.sdfgi_energy = QualidadeGrafica.SDFGI_ENERGIA * preset.gi_escala

	# Inicio e fim ficam gravados nos dois estilos: a linear do PS1 usa, e o
	# Mirante e a serra leem o fim para abrir a vista (FogPreset.alcance_visivel).
	# No MODERNO, nos climas da cidade, o ar e exponencial, com nevoa ou sem
	# (a perspectiva aerea do ar limpo): FogPreset, "O ar do MODERNO".
	env.fog_depth_begin = preset.fog_begin
	env.fog_depth_end = preset.fog_end
	env.fog_depth_curve = 1.0
	env.fog_light_energy = 1.0
	env.fog_height_density = 0.0
	env.fog_aerial_perspective = 0.0
	var densidade := preset.densidade_exponencial() if Settings.luz_por_pixel else 0.0
	if densidade > 0.0:
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = densidade
		env.fog_light_color = preset.cor_do_ar()
		# Com nevoa o fundo E a nevoa; sem ela o ceu esta no infinito e o ar
		# nao o pinta (a bruma do pe da serra ja e desenhada nela).
		env.fog_sky_affect = 1.0 if preset.fog_enabled else 0.0
	else:
		env.fog_enabled = preset.fog_enabled
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = preset.fog_color
		env.fog_density = 1.0
		env.fog_sky_affect = 1.0

	_aplicar_atmosfera(env, preset)

	# Aplica a luz direcional (sol ou lua) do preset.
	_aplicar_luz_direcional(preset)

	stream_radius = preset.stream_radius
	# O streaming corta o desenho no fim da nevoa, entao ele precisa do preset
	# EM VIGOR e nao do escolhido no menu: um lugar que impoe outro clima por
	# `forcar` muda o quanto se enxerga, e o corte tem de acompanhar. Sem isto,
	# entrar numa cena de dia claro mantinha o corte da nevoa fechada do menu e
	# a rua acabava a vinte metros, sem nevoa nenhuma para esconder o corte.
	#
	# So o controller global fala pelo mundo: o de um SubViewport (o fundo da
	# criacao de personagem) nao manda no streaming da rua.
	if registrar_global:
		ChunkManager.usar_preset(preset)
	preset_applied.emit(preset)


## Configura a DirectionalLight3D conforme o clima.
## Em climas diurnos e uma luz solar quente; em climas noturnos e a lua fria.
func _aplicar_luz_direcional(preset: FogPreset) -> void:
	if _luz_direcional == null:
		return
	_luz_direcional.light_energy = preset.sol_energia
	_luz_direcional.light_color = preset.sol_cor
	# sol_rotacao.x = elevacao em graus (negativo = vindo de cima do horizonte)
	# sol_rotacao.y = azimute em graus (direcao horizontal)
	_luz_direcional.rotation_degrees = Vector3(
		preset.sol_rotacao.x,
		preset.sol_rotacao.y,
		0.0
	)


## Impoe um preset por cima da escolha do jogador. Usado ao entrar num interior,
## onde a nevoa da rua nao faz sentido e o ambiente e propriedade do lugar.
func forcar(caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		push_error("FogController: preset ausente %s" % caminho)
		return
	_forcado = load(caminho) as FogPreset
	_apply()


## O mesmo que `forcar`, com um preset que ja esta na memoria.
##
## Existe para quem monta um clima DERIVADO de outro em vez de escolher entre
## arquivos. A abertura da Estrada Velha faz isso: cada um dos sete planos
## quer a nevoa e a grade de cor um pouco diferentes do plano anterior — a
## cabine fecha mais que o rasante, a saida fecha mais que todos porque o
## carro tem de sumir nela — e escrever sete `.tres` para guardar sete
## variacoes de dois numeros do mesmo clima seria transformar direcao de
## fotografia em conteudo de disco. Multiplicado sobre o preset do clima em
## vigor, o mesmo ajuste vale nos cinco climas da estrada.
##
## Quem chama e dono do recurso: passe um `duplicate()`, nunca o preset
## carregado, ou o ajuste de um plano fica gravado no clima para sempre.
func forcar_preset(preset: FogPreset) -> void:
	if preset == null:
		return
	_forcado = preset
	_apply()


## Preset em vigor agora, ja considerando o que um interior tenha imposto por
## `forcar`. Quem depende do clima — chuva, nuvens, ceu noturno — le daqui e
## escuta `preset_applied`, nunca Settings direto: Settings so sabe a escolha do
## jogador para a rua e ignora o preset forcado do lugar onde ele esta.
func preset_atual() -> FogPreset:
	return _resolve_preset()


## Id do preset em vigor agora. Serve a verificacao automatizada, que precisa
## afirmar que entrar num lugar trocou o ambiente de verdade.
func preset_ativo() -> StringName:
	var p := _resolve_preset()
	return p.id if p != null else &""


func liberar() -> void:
	_forcado = null
	_apply()


func _resolve_preset() -> FogPreset:
	if _forcado != null:
		return _forcado
	if follow_settings:
		return Settings.fog_preset()
	return override_preset
