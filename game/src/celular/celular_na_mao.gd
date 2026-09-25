## O celular na mao do personagem, em primeira pessoa: o iPhone do jogo, o braco
## direito que o segura e o gesto de tirar do bolso, erguer ate o rosto e
## guardar de volta.
##
## Como fica na tela
## -----------------
## O aparelho mora na camera: e ela que o jogador move, e o telefone tem de estar
## sempre no mesmo lugar do quadro, como numa mao de verdade. A cabeca baixa um
## pouco quando ele sobe (`PITCH_LEITURA`) e a lente fecha (`FOV_LEITURA`): e o
## olho que se concentra no vidro, e e o que faz a tela ocupar metade da altura
## do quadro e as letras serem letras em 4K. Guardar devolve a cabeca e a lente
## para onde estavam.
##
## A mao e a da abertura (`BracoDoCelular`, `MaoDoCelular`), com uma pegada
## propria do jogo (`PEGADA_*`, ver abaixo). Os dedos nao se mexem: quem toca na
## tela e o jogador, com o mouse, a tecla ou o controle, e o aparelho so cede um
## nada no ponto tocado.
##
## O ombro vem do corpo e nao da camera: a cabeca baixa, o ombro fica, e o braco
## dobra no cotovelo para acompanhar.
class_name CelularNaMao
extends Node3D

## Onde o aparelho fica na leitura, no espaco da camera (m): o braco meio
## esticado, um pouco a direita e abaixo do meio do quadro. A 21 cm (a primeira
## versao) so a mao aparecia, colada na lente, e o aparelho passava da borda de
## baixo; a 28,5 o antebraco entrava no quadro mas a letra ficava pequena. A 25
## a tela le com folga e o punho ainda aparece no canto.
const LEITURA := Vector3(0.020, -0.006, -0.250)
## O quanto a tela deita para tras alem de olhar para a lente (graus): quem le
## no telefone o segura um pouco reclinado.
const RECLINA := 7.0
## E o quanto ele gira na mao para a direita (graus em volta do eixo vertical):
## a mao direita segura torcida para dentro.
const TORCE := -4.0
## Onde ele estava antes de subir (o bolso da calca, fora do quadro, embaixo a
## direita) e como estava deitado.
const BOLSO := Vector3(0.22, -0.48, -0.14)
const BOLSO_GIRO := Vector3(1.25, 0.35, -0.6)
## Por onde a mao passa no meio da subida: faz o arco de quem traz do bolso.
const ARCO := Vector3(0.12, -0.18, -0.32)
## Tempos (s). A subida ficou mais longa que a primeira versao (0,52): com as
## trilhas desencontradas (ver `_process`), tudo em meio segundo virava tranco.
const SOBE := 0.6
const DESCE := 0.36
## A cabeca: para onde a lente baixa ao ler (rad; negativo e para baixo), e a
## lente.
const PITCH_LEITURA := -0.17
## Com o aparelho a 25 cm, 34 graus deixam a tela em quase metade da altura do
## quadro: legivel em 1080p e com folga em 4K.
const FOV_LEITURA := 34.0
## O plano de corte perto da lente enquanto o aparelho esta na mao (m): o padrao
## da camera do jogo (8 cm) cortaria o polegar.
const PERTO := 0.012

## A pegada, no espaco do aparelho, achada pelo `AjusteDaMao` com as metas do
## jogo (`bancada_celular_jogo --resolver`, `metas_do_jogo`): as polpas do
## indicador, do medio e do anelar na LATERAL esquerda, com a ponta saindo
## alem da borda — de frente, ao lado da tela e nunca em cima dela (a bancada
## escolhe por isso); o minimo de prateleira embaixo; as falanges nas costas;
## e o POLEGAR deitado ao longo da lateral direita, apontando para cima, com a
## polpa no aluminio (o risco que o jogador fez na foto). Ele e mais grosso que
## o aparelho e aparece de frente ao lado dele, mas nunca sobre a tela.
##
## Duas versoes antes desta: a da abertura (`MotoristaCena.LEITURA_*`), achada
## para a lente da cabine, cruzava o aparelho com o medio, o anelar e o minimo
## na frente do vidro; a segunda desta classe deixava o polegar atravessado na
## moldura de baixo, a direita do botao de inicio — de frente ele lia como um
## dedo cruzando o telefone.
const PEGADA_O := Vector3(-0.0171, -0.0119, -0.0224)
const PEGADA_D := Vector3(-0.5032, 0.8579, 0.1039)
const PEGADA_DORSO := Vector3(0.3995, 0.3376, -0.8523)
const PEGADA_POSE := {"dedos": [[1.45, 49.25, 67.29, -18.0], [20.62, 91.75, 66.48, -3.18],
	[41.14, 88.27, 63.25, 18.0], [95.0, 60.43, 40.01, -13.22]],
	"polegar": [44.94, 12.14, -43.6, 0.96, 75.68]}
## A mao que aperta o botao de inicio para acordar a tela, achada por
## `bancada_mao_celular --resolver-botao`: so o polegar nao alcanca (para 1 cm a
## direita e acima do botao, no limite das juntas), e a mao inteira escorrega
## 6 mm pela lateral, como quem ajeita o aparelho para chegar nele.
const BOTAO_O := Vector3(-0.0139, -0.0109, -0.0252)
const BOTAO_D := Vector3(-0.6334, 0.7271, 0.2647)
const BOTAO_DORSO := Vector3(0.3035, 0.5481, -0.7794)
const BOTAO_POSE := {"dedos": [[-9.38, 65.31, 57.08, -18.0], [16.37, 91.53, 59.28, -6.02],
	[38.68, 79.09, 55.45, 18.0], [85.6, 42.98, 31.11, -18.0]],
	"polegar": [73.32, 72.64, -64.18, 58.6, 28.16]}
## A mao que aperta o liga/desliga no topo para travar ao guardar, achada por
## `bancada_mao_celular --resolver-trava`: o INDICADOR passa por cima da quina
## esquerda e aperta o botao de cima; a mao gira um nada para cima e os dedos
## sobem 8 mm pela lateral. Com o polegar a palma teria de andar 2 cm.
const TRAVA_O := Vector3(-0.0176, -0.0056, -0.0185)
const TRAVA_D := Vector3(-0.3174, 0.9454, 0.0739)
const TRAVA_DORSO := Vector3(0.3568, 0.1913, -0.9144)
const TRAVA_POSE := {"dedos": [[-25.0, 55.59, 41.08, 18.0], [22.42, 92.09, 72.09, -17.38],
	[43.98, 95.94, 63.53, 10.27], [95.0, 55.16, 32.34, -3.83]],
	"polegar": [39.52, 4.78, -3.4, 17.72, 1.22]}
## O indicador no meio do caminho ate o botao de cima (`--caminho-trava`).
const INDICADOR_ERGUIDO := [-25.0, 60.0, 40.0, -18.0]
## Quanto a mao afrouxa (mistura com a pose aberta) no meio do caminho ate a
## pegada de travar: sem isso o minimo entrava 3 mm no aparelho enquanto a mao
## escorregava.
const SOLTA_TRAVA := 0.1
## O quanto o minimo dobra a mais (mcp, pip, dip, graus) no meio do caminho.
const MINIMO_NA_TRAVA := [-20.0, 30.0, 0.0]
## O quanto o polegar se afasta (graus a mais em cada angulo) no meio do
## escorregar.
const POLEGAR_NA_TRAVA := [10.0, 0.0, 0.0, 0.0, 0.0]
## O gesto de travar ao guardar (a pe, com o aparelho em pe no lugar): o
## indicador vai ao botao de cima com o aparelho parado, aperta — o clique, o
## aparelho cede para baixo e a tela apaga — e o aparelho desce com o dedo
## voltando para a lateral. Tempos (s), quanto a tela leva para apagar, quanto o
## aparelho cede (m) e quanto o indicador dobra a mais no clique (graus no no do
## meio e no de cima).
const TRAVA_VAI := 0.2
const TRAVA_APERTA := 0.07
const TRAVA_VOLTA := 0.26
const APAGA := 0.09
const TRAVA_CEDE := 0.0009
const TRAVA_APERTA_GRAUS := Vector2(6.0, 6.0)
## A fracao do caminho da trava em que o indicador sai da lateral (e, no fim,
## desce no botao) com a mao parada.
const TRAVA_SAI := 0.25
## O gesto de acordar a tela (so quando ela estava apagada, na trava): com o
## aparelho quase no lugar (`ACORDA_EM` da subida) o polegar sai da lateral,
## vai ao botao de inicio, aperta — o clique, o aparelho cede e a tela acende —
## e volta. Tempos (s) de cada trecho, e quanto a tela leva para acender.
const ACORDA_EM := 0.55
const ACORDA_VAI := 0.17
const ACORDA_APERTA := 0.08
const ACORDA_VOLTA := 0.28
const ACENDE := 0.14
## O botao de inicio em uv da tela (abaixo dela: y passa de 1).
const UV_BOTAO := Vector2(0.5, 0.5 - IphoneDeJogo.Y_BOTAO / IphoneDeJogo.TELA.y)
## O polegar no meio do caminho entre a lateral e o botao, dobrado e erguido
## a no maximo 2 cm do aparelho (`bancada_mao_celular --caminho-botao`, a melhor
## da grade). Misturando direto as duas pegadas ele passava pela quina direita,
## 3 mm dentro do aluminio; aberto para fora ([70, 10, 0, 0, 0]) nao entrava,
## mas saia espetado para o lado e na volta lia como um joinha.
const POLEGAR_ERGUIDO := [65.0, 20.0, -50.0, 40.0, 40.0]
## Quanto o polegar dobra a mais no clique (graus no no do meio e no de cima).
const APERTA_GRAUS := Vector2(3.0, 7.0)
## Deitado (o Mapas): as duas maos trazem o aparelho para junto do rosto, no
## meio do quadro e menos reclinado, e a lente fecha mais que na leitura
## (`FOV_DEITADO`, junto com o giro): o mapa enche o quadro e dos dedos so se
## ve o que passa da borda. A 23,5 cm e com a lente da leitura, a primeira
## versao, a tela ocupava um terco da largura e o mapa era um cartao no meio das
## maos. Tudo por distancia (10 cm) deformava os polegares, perto demais da
## lente; tudo por lente (16 graus) fazia a rua atras correr como num binoculo.
const LEITURA_DEITADO := Vector3(0.0, 0.0, -0.150)
const RECLINA_DEITADO := 4.0
const FOV_DEITADO := 24.0
## A pegada da mao DIREITA com o aparelho deitado, no referencial deitado (x
## para a direita de quem olha), achada por `bancada_celular_jogo
## --resolver-deitado` (`metas_deitado`): a palma na ponta do botao de inicio,
## virada para ela; o polegar na moldura da frente, abaixo do botao; os dedos
## pelas costas. A esquerda e o espelho (`_espelho`).
const DEITADA_O := Vector3(0.0659, -0.0092, -0.0094)
const DEITADA_D := Vector3(-0.0133, 0.8918, -0.4523)
const DEITADA_DORSO := Vector3(0.9845, -0.0675, -0.1621)
const DEITADA_POSE := {"dedos": [[23.61, 52.13, 36.39, -18.0], [30.92, 71.94, 39.8, -18.0],
	[45.45, 81.84, 53.97, 18.0], [81.43, 73.17, 53.15, -18.0]],
	"polegar": [6.94, 30.38, -23.85, -15.0, 85.0]}
## Ao volante (`AoVolante`): o aparelho no espaco da camera de dentro, com a
## cabeca ja baixada para ele — logo acima do aro, na frente do peito, onde quem
## digita dirigindo o segura para "ainda ver a rua" por cima dele —, e de onde
## ele sai (o colo). Na frente do cubo do volante, a primeira versao, a cabeca
## descia tanto que a rua sumia do quadro, e o braco passava pelo aro. Descer
## e mais rapido: e o susto de quem levanta os olhos para a rua.
const LEITURA_CARRO := Vector3(0.012, -0.040, -0.255)
const RECLINA_CARRO := 10.0
const COLO := Vector3(0.16, -0.40, -0.12)
const DESCE_CARRO := 0.24
## De onde a mao esquerda vem quando o aparelho deita (espaco do corpo): de
## baixo e da esquerda, fora do quadro.
const CHEGA_ESQ := Vector3(-0.08, -0.22, 0.06)
## O ombro direito, a partir do olho, no espaco do corpo (sem a inclinacao da
## cabeca): para a direita, abaixo e um pouco atras.
const OMBRO := Vector3(0.19, -0.27, 0.10)
## Para onde o cotovelo dobra, no espaco do corpo.
const POLO := Vector3(0.9, -0.8, 0.25)
## Com as duas maos no aparelho deitado os cotovelos descem para junto do
## corpo: com o polo de uma mao so, vistos de cima, os dois bracos abriam como
## asas.
const POLO_DEITADO := Vector3(0.3, -1.0, 0.15)

## A mao viva: balanco (m e graus) e o quanto o aparelho cede no toque.
const BALANCO := 0.0019
const BALANCO_GRAUS := 0.65
const CEDE := 0.0008
const CEDE_GRAUS := 0.7
const VIBRA := 0.0014
const VIBRA_HZ := 42.0

## O braco balanca com a cabeca (`_balancar`): o aparelho fica para tras do giro
## (`BALANCO_ATRASO` s por rad/s de giro, ate `BALANCO_MAX` rad), numa mola
## de `BALANCO_MOLA` Hz amortecida em `BALANCO_AMORTECE`, e tomba de lado
## (`BALANCO_TOMBA` do atraso). Olhando devagar e um nada; sacudindo o mouse o
## aparelho sai do lugar, a tela vira e nao da para ler.
const BALANCO_ATRASO := 0.055
const BALANCO_MAX := 0.3
const BALANCO_MOLA := 2.6
const BALANCO_AMORTECE := 0.3
const BALANCO_TOMBA := 0.7

## A lanterna: o flash de LED atras do aparelho.
const FLASH_ALCANCE := 9.0
const FLASH_FORCA := 2.4
const FLASH_ANGULO := 38.0
## Quanto a tela acesa clareia a polpa que esta a um dedo dela.
const TELA_NA_PELE := 0.35

signal guardado()

## O brilho do vidro escolhido nos Ajustes (0 a 1).
var brilho_max: float = 1.0
## 0 em pe, 1 deitado nas duas maos (o Mapas). Quem anima e o `Celular`, no
## mesmo quadro em que gira o desenho da tela.
var giro: float = 0.0
## A tela estava apagada no bolso (o aparelho abre na trava): a subida acaba no
## polegar apertando o botao de inicio. Quem abre (`Celular`) diz antes de
## `erguer`.
var acordar: bool = false

var fone: IphoneDeJogo
var braco: BracoDoCelular
## A mao esquerda, que so aparece com o aparelho deitado.
var braco_esq: BracoDoCelular
var flash: SpotLight3D

var _jogador: Node
var _camera: Camera3D
var _camera_do_jogador: Camera3D
## 0 no bolso, 1 na leitura.
var _k: float = 0.0
var _subindo: bool = false
var _t: float = 0.0
var _pitch_antes: float = 0.0
var _pitch_alvo: float = 0.0
var _perto_antes: float = 0.08
var _terceira_antes: bool = false
var _cede: float = 0.0
var _cede_alvo: float = 0.0
var _cede_uv := Vector2(0.5, 0.5)
var _vibra: float = 0.0
## O gesto de acordar: a hora dele (negativa parado), a tela ja acesa, o quanto
## ela acendeu, o polegar no botao (0 na lateral, 1 nele) e o quanto aperta.
var _acorda_t: float = -1.0
var _acesa: bool = true
var _luz_k: float = 1.0
var _no_botao: float = 0.0
var _aperto: float = 0.0
## O gesto de travar: a hora dele (negativa parado), se ainda vai apertar (um
## `erguer` no meio desiste do clique), o indicador no caminho do botao de cima
## (0 na lateral, 1 nele) e o quanto aperta.
var _trava_t: float = -1.0
## O balanco: o atraso (guinada, arfagem; rad) e a velocidade dele, e o giro da
## camera no quadro anterior.
var _bal := Vector2.ZERO
var _bal_v := Vector2.ZERO
var _q_antes := Quaternion.IDENTITY
var _q_valido: bool = false
var _trava_aperta: bool = false
var _na_trava: float = 0.0
var _aperto_trava: float = 0.0
## Ao volante (`AoVolante`): a cabine do carro, a camera de dentro, e o que
## voltar a como estava quando o telefone descer. Nulo a pe.
var _volante: AoVolante


## Monta tudo pendurado na camera do jogador. Devolve false sem camera.
func montar(jogador: Node) -> bool:
	_jogador = jogador
	if jogador != null and jogador.has_method("camera"):
		_camera = jogador.call("camera") as Camera3D
	if _camera == null:
		_camera = get_viewport().get_camera_3d() if is_inside_tree() else null
	if _camera == null:
		return false
	name = "CelularNaMao"
	_camera.add_child(self)
	_camera_do_jogador = _camera
	fone = IphoneDeJogo.new()
	# A luz da tela nao acende o ar: a nevoa em volta do aparelho virava veu.
	fone.luz.light_volumetric_fog_energy = 0.0
	add_child(fone)
	var cores := _cores_do_jogador()
	braco = BracoDoCelular.criar("BracoDoCelular", true, cores["pele"], cores["manga"],
		cores["longa"])
	braco.dedos_vivos = 0.0
	add_child(braco)
	flash = SpotLight3D.new()
	flash.name = "Flash"
	flash.light_color = Color(1.0, 0.97, 0.9)
	flash.spot_range = FLASH_ALCANCE
	flash.spot_angle = FLASH_ANGULO
	flash.spot_attenuation = 1.2
	flash.light_energy = 0.0
	flash.shadow_enabled = true
	flash.visible = false
	# O proprio aparelho e a mao ficam fora: a luz nasce atras deles, e com eles
	# dentro os dedos das costas faziam sombra na rua inteira.
	flash.light_cull_mask = 0xFFFFF & ~IphoneDeJogo.CAMADA & ~BracoDoCelular.CAMADA
	fone.add_child(flash)
	# O flash fica atras, no canto de cima (`IphoneDeJogo.FLASH`). A luz de
	# holofote sai pelo -Z dela, que e o -Z do aparelho: para longe da tela.
	flash.position = Vector3(IphoneDeJogo.FLASH.x, IphoneDeJogo.FLASH.y,
		-IphoneDeJogo.TAMANHO.z * 0.5 - 0.001)
	visible = false
	set_process(false)
	return true


static func _cores_do_jogador() -> Dictionary:
	var aparencia: Dictionary = RegistroCivil.jogador.get("aparencia", {})
	var pele: Color = aparencia.get("pele", Color(0.78, 0.62, 0.50))
	if not aparencia.has("camisa_cor"):
		return {"pele": pele, "manga": Color(0.45, 0.47, 0.52), "longa": true}
	var longa := Aparencia.manga_longa(aparencia)
	return {"pele": pele, "manga": Aparencia.cor_da_manga(aparencia) if longa else pele,
		"longa": longa}


func ligar_tela(textura: Texture2D) -> void:
	fone.ligar(textura)


func erguido() -> bool:
	return _subindo and _k >= 1.0


## Tira do bolso e ergue ate o rosto.
func erguer() -> void:
	if _subindo:
		return
	_subindo = true
	visible = true
	set_process(true)
	if _trava_t >= 0.0:
		# Tirou de novo no meio do gesto de travar: o dedo volta de onde esta,
		# sem o clique.
		_trava_aperta = false
		_trava_t = maxf(_trava_t, TRAVA_VAI + TRAVA_APERTA + TRAVA_VOLTA * (1.0 - _na_trava))
	if _k <= 0.0:
		_t = 0.0
		_bal = Vector2.ZERO
		_bal_v = Vector2.ZERO
		_q_valido = false
		_acorda_t = -1.0
		_acesa = not acordar
		_luz_k = 1.0 if _acesa else 0.0
		# Ao volante o aparelho mora na camera de dentro da cabine; a pe, na do
		# jogador.
		_volante = AoVolante.achar(_jogador)
		_anexar(_volante.camera if _volante != null else _camera_do_jogador)
		if _volante != null:
			_volante.pegar()
		_pitch_antes = float(_jogador.call("pitch_atual")) if _jogador != null \
			and _jogador.has_method("pitch_atual") else 0.0
		_perto_antes = _camera.near
		_terceira_antes = false
		if _jogador != null and _jogador.has_method("forcar_primeira_pessoa"):
			_terceira_antes = bool(_jogador.call("forcar_primeira_pessoa", true))
	# Olhando para baixo alem da leitura, a cabeca fica: so quem olha para a
	# frente ou para cima baixa os olhos para o aparelho. Ao volante a camera e a
	# de perseguicao, e o pitch do pivo nao e a cabeca: fica onde esta.
	_pitch_alvo = minf(_pitch_antes, PITCH_LEITURA)
	if _volante != null or (_jogador != null and _jogador.has_method("dirigindo")
			and bool(_jogador.call("dirigindo"))):
		_pitch_alvo = _pitch_antes
	_camera.near = PERTO


## Quantos quadros o rig fica desenhado no aquecimento, e a escala e a
## distancia em que ele fica na frente da lente: menor que um pixel, mas dentro
## do quadro e desenhado (e o que faz o motor compilar), sombra inclusive.
const AQUECE_QUADROS := 3
const AQUECE_ESCALA := 0.004
const AQUECE_LONGE := 0.5


## Desenha o aparelho, os dois bracos e a tela acesa uma vez, minusculos na
## frente da lente, e guarda tudo de novo (ver `Celular._aquecer_rig`). So com
## o rig parado no bolso.
func aquecer() -> void:
	if _subindo or visible or _camera == null:
		return
	visible = true
	scale = Vector3.ONE * AQUECE_ESCALA
	position = Vector3(0.0, 0.0, -AQUECE_LONGE)
	fone.transform = Transform3D(Basis(), LEITURA)
	fone.brilho(1.0)
	var pega := BracoDoCelular.levar(fone.transform, BracoDoCelular.pega(PEGADA_O, PEGADA_D,
		PEGADA_DORSO, PEGADA_POSE))
	braco.ombro = OMBRO
	braco.polo = POLO
	braco.pular(pega)
	braco.visible = true
	braco.refazer()
	_encostar_pele(1.0)
	giro = 1.0
	_montar_braco_esquerdo(Basis(), 0.0)
	giro = 0.0
	for _i in AQUECE_QUADROS:
		await get_tree().process_frame
	if _subindo:
		# O jogador tirou o aparelho no meio: o gesto ja assumiu.
		scale = Vector3.ONE
		position = Vector3.ZERO
		return
	scale = Vector3.ONE
	position = Vector3.ZERO
	fone.brilho(0.0)
	braco.visible = false
	if braco_esq != null:
		braco_esq.visible = false
	visible = false


## O mouse move a cabeca com o aparelho na mao (ver `Celular.mouse_livre`): o
## corpo gira, e o pitch da leitura anda junto com o de antes — guardando, a
## cabeca volta para onde o jogador a deixou, e nao para onde estava ao tirar.
## Ao volante e o olhar da cabine (`AoVolante.olhar`).
func olhar(relativo: Vector2) -> void:
	var sens := Player.SENSIBILIDADE
	if _volante != null:
		_volante.olhar(relativo, sens)
		return
	if _jogador is Node3D:
		(_jogador as Node3D).rotate_y(-relativo.x * sens)
	var d := -relativo.y * sens
	_pitch_antes = clampf(_pitch_antes + d, Player.PITCH_MIN, Player.PITCH_MAX)
	_pitch_alvo = clampf(_pitch_alvo + d, Player.PITCH_MIN, Player.PITCH_MAX)


## O atraso do aparelho no giro da camera: a mola persegue um alvo que e a
## velocidade de giro vezes `BALANCO_ATRASO`, e passa do ponto quando o giro para
## ou volta. No carro as curvas e os buracos balancam tambem.
func _balancar(delta: float) -> void:
	if _camera == null:
		return
	var q := _camera.global_basis.get_rotation_quaternion()
	var w := Vector2.ZERO
	var dt := minf(delta, 1.0 / 30.0)
	if _q_valido and delta > 0.0:
		var dl := (_q_antes.inverse() * q).normalized()
		var ang := dl.get_angle()
		if ang > PI:
			ang -= TAU
		if absf(ang) > 1e-6:
			var wl := dl.get_axis() * ang / delta
			w = Vector2(wl.y, wl.x)
	_q_antes = q
	_q_valido = true
	var alvo := (-w * BALANCO_ATRASO).limit_length(BALANCO_MAX)
	var om := TAU * BALANCO_MOLA
	_bal_v += ((alvo - _bal) * om * om - _bal_v * 2.0 * BALANCO_AMORTECE * om) * dt
	_bal = (_bal + _bal_v * dt).limit_length(BALANCO_MAX * 1.4)


## Pendura o rig numa camera (a do jogador ou a de dentro do carro).
func _anexar(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	if get_parent() != cam:
		if get_parent() != null:
			reparent(cam, false)
		else:
			cam.add_child(self)
	_camera = cam


## Com o telefone ao volante (camera de dentro do carro).
func ao_volante() -> bool:
	return _volante != null


## Guarda no bolso; `guardado` sai quando ele some do quadro.
## Guarda no bolso. A pe, com o aparelho em pe no lugar e a tela acesa, o
## indicador trava antes (`travar`): devolve se vai haver esse gesto — e o clique
## dele e o som de travar.
func guardar(travar: bool = true) -> bool:
	if not _subindo:
		return false
	_subindo = false
	lanterna(false)
	var com_gesto := travar and _volante == null and _k >= 0.9 and giro <= 0.01 and _acesa \
		and _acorda_t < 0.0
	if com_gesto:
		_trava_t = 0.0
		_trava_aperta = true
	return com_gesto


func tocou(uv: Vector2) -> void:
	_cede_uv = uv
	_cede_alvo = 1.0


func soltou() -> void:
	_cede_alvo = 0.0


func vibrar(duracao: float = 0.4) -> void:
	_vibra = maxf(_vibra, duracao)


func lanterna(ligada: bool) -> void:
	if flash == null:
		return
	flash.visible = ligada
	flash.light_energy = FLASH_FORCA if ligada else 0.0


func lanterna_ligada() -> bool:
	return flash != null and flash.visible


## Onde o raio do ponteiro `pos` (coordenada do viewport) cruza a tela, em uv de
## (0, 0) no canto de cima a esquerda a (1, 1) no de baixo a direita. Fora do
## vidro, (-1, -1).
func uv_da_tela(pos: Vector2) -> Vector2:
	if _camera == null or fone == null or not visible:
		return Vector2(-1.0, -1.0)
	var origem := _camera.project_ray_origin(pos)
	var dir := _camera.project_ray_normal(pos)
	var xf := fone.global_transform
	var n := xf.basis.z.normalized()
	var ponto := xf * Vector3(0.0, 0.0, IphoneDeJogo.TAMANHO.z * 0.5)
	var den := n.dot(dir)
	if absf(den) < 1e-5:
		return Vector2(-1.0, -1.0)
	var t := n.dot(ponto - origem) / den
	if t <= 0.0:
		return Vector2(-1.0, -1.0)
	var local := xf.affine_inverse() * (origem + dir * t)
	var uv := Vector2(local.x / IphoneDeJogo.TELA.x + 0.5, 0.5 - local.y / IphoneDeJogo.TELA.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1.0, -1.0)
	return uv


## Onde o ponto `uv` da tela aparece no viewport: para quem desenha a dica ao
## lado do aparelho.
func na_tela(uv: Vector2) -> Vector2:
	if _camera == null or fone == null:
		return Vector2.ZERO
	return _camera.unproject_position(fone.global_transform * IphoneDeJogo.ponto_da_tela(uv))


func _process(delta: float) -> void:
	_t += delta
	var alvo := 1.0 if _subindo else 0.0
	if not _subindo and _trava_t >= 0.0 and _trava_t < TRAVA_VAI + TRAVA_APERTA:
		# O aparelho espera no lugar o dedo travar.
		alvo = _k
	var dur := SOBE if _subindo else DESCE
	if _volante != null and not _subindo:
		# Ao volante os olhos voltam para a rua no susto: mais depressa.
		dur = DESCE_CARRO
	_k = move_toward(_k, alvo, delta / dur)
	# Quatro trilhas desencontradas, e nao uma so: o aparelho sai do bolso na
	# frente; o pulso vira a tela para o rosto um pouco depois (antes ele subia
	# ja de frente, como colado na lente); a cabeca baixa atras dele, e a lente
	# fecha por ultimo, a partir de quando ele entra no quadro — com as quatro
	# juntas o mundo dava zoom na parede antes de o aparelho aparecer.
	# Subindo, ele sai depressa do bolso e assenta devagar, passando um nada do
	# ponto. Descendo, a tela vira para o corpo logo no comeco, a cabeca levanta
	# logo depois que ele comecou a cair, e ele larga devagar e cai depressa.
	var e: float
	var vira: float
	var cab: float
	var foco: float
	if _subindo:
		e = _volta(_k, 1.4)
		vira = _suave((_k - 0.08) / 0.8)
		cab = _suave((_k - 0.12) / 0.88)
		foco = _suave((_k - 0.15) / 0.85)
	else:
		e = _suave(_k)
		vira = _suave((_k - 0.35) / 0.65)
		# A cabeca e o foco voltam enquanto ele cai, e acabam quando ele sai do
		# quadro (por volta de k = 0,5): acabando so em k = 0, a lente ainda abria
		# um quinto de segundo em cima da parede vazia.
		cab = _suave((_k - 0.3) / 0.55)
		foco = _suave((_k - 0.4) / 0.5)
	_mover_cabeca(cab, foco)
	_travar_passo(delta)
	_acordar_passo(delta)
	_balancar(delta)
	_pousar_aparelho(e, vira, delta)
	_montar_braco(delta)
	_luz_k = move_toward(_luz_k, 1.0 if _acesa else 0.0, delta / (ACENDE if _acesa else APAGA))
	# Fora do bolso: a luz da tela nao acende a calca por dentro.
	var aceso := _luz_k * clampf(_k * 2.5 - 0.1, 0.0, 1.0)
	fone.luz_ganho = AoVolante.LUZ if _volante != null else 1.0
	fone.brilho(aceso * lerpf(0.35, 1.0, brilho_max))
	_encostar_pele(aceso * lerpf(0.35, 1.0, brilho_max))
	if not _subindo and _k <= 0.0:
		_devolver_cabeca()
		visible = false
		set_process(false)
		guardado.emit()


## Suave de 0 a 1 (fora disso, preso na ponta).
static func _suave(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Sai depressa e passa um nada do fim antes de assentar (`c` o quanto passa).
static func _volta(x: float, c: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


## A cabeca (`cab`: 0 como estava, 1 baixada para o aparelho) e a lente (`foco`:
## 0 a do jogo, 1 fechada na leitura).
func _mover_cabeca(cab: float, foco: float) -> void:
	if _jogador == null:
		return
	if _volante != null:
		_volante.passo(cab, get_process_delta_time())
		return
	if _jogador.has_method("definir_pitch"):
		var alvo := lerpf(_pitch_antes, _pitch_alvo, cab)
		# Guardando, a cabeca volta para onde estava.
		_jogador.call("definir_pitch", alvo)
	if _jogador.has_method("definir_fov"):
		var base := float(Player.FOV_BASE)
		_jogador.call("definir_fov", lerpf(base, lerpf(FOV_LEITURA, FOV_DEITADO, giro), foco))


## O indicador no botao de cima, pela hora do gesto (ver `TRAVA_*`): ida com o
## aparelho parado, clique (a tela apaga) e volta enquanto ele desce.
func _travar_passo(delta: float) -> void:
	if _trava_t < 0.0:
		_na_trava = 0.0
		_aperto_trava = 0.0
		return
	_trava_t += delta
	var t := _trava_t
	var solta_em := TRAVA_VAI + TRAVA_APERTA
	if t < TRAVA_VAI:
		_na_trava = t / TRAVA_VAI
	elif t < solta_em:
		_na_trava = 1.0
	else:
		_na_trava = 1.0 - clampf((t - solta_em) / TRAVA_VOLTA, 0.0, 1.0)
	_aperto_trava = sin(PI * clampf((t - TRAVA_VAI) / TRAVA_APERTA, 0.0, 1.0)) \
		if _trava_aperta else 0.0
	if _trava_aperta and _acesa and t >= TRAVA_VAI + TRAVA_APERTA * 0.4:
		_acesa = false
		AudioDirector.tocar_ui(&"clique", -16.0, 0.9)
	if t >= solta_em + TRAVA_VOLTA:
		_trava_t = -1.0
		_na_trava = 0.0
		_aperto_trava = 0.0


## O polegar no botao de inicio, pela hora do gesto (ver `ACORDA_*`): ida,
## clique e volta. A tela acende no clique.
func _acordar_passo(delta: float) -> void:
	if _acorda_t < 0.0:
		if not (_subindo and not _acesa and _k >= ACORDA_EM and _trava_t < 0.0):
			_no_botao = 0.0
			_aperto = 0.0
			return
		_acorda_t = 0.0
	_acorda_t += delta
	var t := _acorda_t
	var solta_em := ACORDA_VAI + ACORDA_APERTA
	if t < ACORDA_VAI:
		_no_botao = _suave(t / ACORDA_VAI)
	elif t < solta_em:
		_no_botao = 1.0
	else:
		_no_botao = 1.0 - _suave((t - solta_em) / ACORDA_VOLTA)
	_aperto = sin(PI * clampf((t - ACORDA_VAI) / ACORDA_APERTA, 0.0, 1.0))
	if not _acesa and t >= ACORDA_VAI + ACORDA_APERTA * 0.4:
		_acesa = true
		# O botao afunda: o aparelho cede ali, como num toque na tela.
		_cede_uv = UV_BOTAO
		_cede_alvo = 1.0
		AudioDirector.tocar_ui(&"clique", -20.0, 1.3)
	if t >= solta_em and _cede_uv == UV_BOTAO:
		_cede_alvo = 0.0
	if t >= solta_em + ACORDA_VOLTA:
		_acorda_t = -1.0
		_no_botao = 0.0
		_aperto = 0.0


func _devolver_cabeca() -> void:
	if _jogador == null:
		return
	if _volante != null:
		_volante.devolver()
		_volante = null
		if _camera != null:
			_camera.near = _perto_antes
		call_deferred(&"_anexar", _camera_do_jogador)
		return
	if _jogador.has_method("definir_pitch"):
		_jogador.call("definir_pitch", _pitch_antes)
	if _jogador.has_method("liberar_fov"):
		_jogador.call("liberar_fov")
	if _jogador.has_method("forcar_primeira_pessoa") and _terceira_antes:
		_jogador.call("forcar_primeira_pessoa", false)
	if _camera != null:
		_camera.near = _perto_antes


## O aparelho no caminho do bolso ate a leitura, virado para a lente, e vivo: o
## balanco da mao, a respiracao, o ceder no toque e a vibracao.
func _pousar_aparelho(e: float, vira: float, delta: float) -> void:
	# Bezier de tres pontos: bolso, arco, leitura.
	var u := clampf(e, 0.0, 1.15)
	# Deitado nas duas maos ele vem para o meio do quadro e perde a torcao da mao
	# direita: sao as duas que seguram.
	var alvo := LEITURA.lerp(LEITURA_DEITADO, giro)
	var bolso_pos := BOLSO
	if _volante != null:
		alvo = LEITURA_CARRO
		bolso_pos = COLO
	var a := bolso_pos.lerp(ARCO, u)
	var b := ARCO.lerp(alvo, u)
	var pos := a.lerp(b, u)
	var olhar := Basis.looking_at(-alvo.normalized(), Vector3.UP, true)
	var reclina := lerpf(RECLINA, RECLINA_DEITADO, giro) if _volante == null else RECLINA_CARRO
	var leitura := olhar * Basis.from_euler(Vector3(deg_to_rad(-reclina),
		deg_to_rad(TORCE * (1.0 - giro)), 0.0)) * Basis(Vector3.BACK, giro * PI * 0.5)
	var bolso := Basis.from_euler(BOLSO_GIRO)
	var base := Basis(bolso.get_rotation_quaternion().slerp(leitura.get_rotation_quaternion(),
		vira))
	# A mao viva: tres ondas lentas desencontradas e a respiracao.
	var t := _t
	var vivo := clampf(e, 0.0, 1.0)
	var bal := Vector3(sin(t * 1.9) + 0.6 * sin(t * 0.73 + 1.1),
		sin(t * 1.5 + 0.7) + 0.5 * sin(t * 0.51 + 2.3) + 0.6 * sin(t * TAU * 0.22),
		sin(t * 1.2 + 2.0) * 0.5) * BALANCO * 0.6 * vivo
	var g := Vector3(sin(t * 1.4 + 0.4), sin(t * 1.1 + 1.9), sin(t * 1.7 + 3.1)) \
		* deg_to_rad(BALANCO_GRAUS) * 0.6 * vivo
	_cede = move_toward(_cede, _cede_alvo, delta * (30.0 if _cede_alvo > _cede else 8.0))
	var cede := Vector3.ZERO
	var giro_cede := Basis()
	if _cede > 0.001:
		var ponto := IphoneDeJogo.ponto_da_tela(_cede_uv)
		cede = Vector3(0.0, 0.0, -CEDE * _cede)
		var eixo := Vector3(-ponto.y, ponto.x, 0.0)
		if eixo.length_squared() > 1e-8:
			giro_cede = Basis(eixo.normalized(), deg_to_rad(CEDE_GRAUS) * _cede)
	var vibra := Vector3.ZERO
	if _vibra > 0.0:
		_vibra -= delta
		var liga := 1.0 if fmod(_vibra, 0.2) > 0.06 else 0.3
		vibra = Vector3(sin(t * TAU * VIBRA_HZ), sin(t * TAU * VIBRA_HZ * 1.13 + 1.0), 0.0) * VIBRA * liga
	# O balanco: o aparelho gira em volta do olho, ficando para tras do giro da
	# cabeca, e tomba de lado.
	var balanco := Basis(Vector3.UP, _bal.x) * Basis(Vector3.RIGHT, _bal.y)
	pos = balanco * pos
	base = balanco * base * Basis(Vector3.BACK, _bal.x * BALANCO_TOMBA)
	fone.transform = Transform3D(base * Basis.from_euler(g) * giro_cede,
		pos + bal + base * (cede + vibra + Vector3(0.0, -TRAVA_CEDE * _aperto_trava, 0.0)))


## A pele dos bracos sabe onde o aparelho esta: escurece onde encosta nele e
## pega a luz da tela de perto (ver `BracoDoCelular.encostar_no_fone`). Sem isso
## a mao e o telefone eram duas pecas iluminadas cada uma por si, e os dedos
## pareciam colados por fora do aluminio.
func _encostar_pele(brilho_tela: float) -> void:
	var xf := fone.global_transform
	var luz := IphoneDeJogo.LUZ_COR * (brilho_tela * TELA_NA_PELE)
	for b: BracoDoCelular in [braco, braco_esq]:
		if b != null and b.visible:
			b.encostar_no_fone(xf, 1.0, luz)


## O braco refeito em volta do aparelho: a mao na pegada da leitura, o ombro
## preso ao corpo (a cabeca inclina, o ombro nao).
func _montar_braco(delta: float) -> void:
	if braco == null:
		return
	# O corpo no espaco deste no (que e o da camera): desfaz a inclinacao da
	# cabeca, que mora no pivo.
	var cabeca := Basis()
	if _volante != null:
		# Na cabine, a camera mora no espaco do carro, e o giro dela ali e a
		# cabeca inteira (a arfagem e a guinada do olhar, e o balanco).
		cabeca = _camera.transform.basis.orthonormalized()
	elif _jogador != null and _jogador.has_method("pitch_atual"):
		cabeca = Basis(Vector3.RIGHT, float(_jogador.call("pitch_atual")))
	var corpo := cabeca.inverse()
	# Subindo do bolso, o ombro desce um nada junto: o braco vem de baixo.
	braco.ombro = corpo * OMBRO
	braco.polo = corpo * POLO.lerp(POLO_DEITADO, giro)
	var pega := BracoDoCelular.pega(PEGADA_O, PEGADA_D, PEGADA_DORSO, PEGADA_POSE)
	if _na_trava > 0.001:
		pega = pegada_da_trava(_na_trava)
		if _aperto_trava > 0.0:
			var dedos: Array = (pega["pose"]["dedos"] as Array).duplicate(true)
			dedos[0][1] = float(dedos[0][1]) + TRAVA_APERTA_GRAUS.x * _aperto_trava
			dedos[0][2] = float(dedos[0][2]) + TRAVA_APERTA_GRAUS.y * _aperto_trava
			pega["pose"] = {"dedos": dedos, "polegar": pega["pose"]["polegar"]}
	elif _no_botao > 0.001:
		pega = _pegada_do_botao(pega)
	if giro > 0.001:
		# A mao direita troca de pegada no espaco do aparelho enquanto ele gira, e
		# abre um pouco no meio do caminho: e ela que vira o telefone.
		var deitada := BracoDoCelular.levar(_do_deitado(), BracoDoCelular.pega(DEITADA_O, DEITADA_D,
			DEITADA_DORSO, DEITADA_POSE))
		pega = BracoDoCelular._misturar(pega, deitada, giro)
		pega["pose"] = MaoDoCelular.misturar(pega["pose"], MaoDoCelular.pose(&"aberta"),
			sin(giro * PI) * 0.3)
	braco.pular(BracoDoCelular.levar(fone.transform, pega))
	braco.tremor = 0.0
	braco.visible = true
	braco.passo(delta)
	_montar_braco_esquerdo(corpo, delta)


## A pegada no caminho do botao de inicio: a mao escorrega para a do botao
## (`BOTAO_*`), o polegar se abre para fora no meio (`POLEGAR_ERGUIDO`) e, no
## botao, dobra um nada apertando.
func _pegada_do_botao(pega: Dictionary) -> Dictionary:
	var botao := BracoDoCelular.pega(BOTAO_O, BOTAO_D, BOTAO_DORSO, BOTAO_POSE)
	var p := BracoDoCelular._misturar(pega, botao, _no_botao)
	var pose: Dictionary = p["pose"]
	var ergue := sin(PI * _no_botao)
	var pol: Array = []
	for j in 5:
		pol.append(lerpf(float(pose["polegar"][j]), float(POLEGAR_ERGUIDO[j]), ergue))
	pol[3] = float(pol[3]) + APERTA_GRAUS.x * _aperto
	pol[4] = float(pol[4]) + APERTA_GRAUS.y * _aperto
	p["pose"] = {"dedos": pose["dedos"], "polegar": pol}
	return p


## A pegada no caminho da trava, `k` de 0 (a do jogo) a 1 (o indicador no
## botao de cima), em tres tempos: o indicador sai da lateral com a mao parada,
## a mao escorrega afrouxando (`SOLTA_TRAVA`), e ele desce no botao. Tudo junto
## (a primeira versao) a mao girava e levava o indicador para dentro da lateral,
## 3 mm no aluminio. `ergue` e a pose do indicador fora do aparelho.
static func pegada_da_trava(k: float, ergue: Array = INDICADOR_ERGUIDO,
		minimo: Array = MINIMO_NA_TRAVA, solta: float = SOLTA_TRAVA,
		polegar: Array = POLEGAR_NA_TRAVA) -> Dictionary:
	var jogo := BracoDoCelular.pega(PEGADA_O, PEGADA_D, PEGADA_DORSO, PEGADA_POSE)
	var trava := BracoDoCelular.pega(TRAVA_O, TRAVA_D, TRAVA_DORSO, TRAVA_POSE)
	var mao := _suave((k - TRAVA_SAI) / (1.0 - 2.0 * TRAVA_SAI))
	var p := BracoDoCelular._misturar(jogo, trava, mao)
	# A mao afrouxa ja quando o indicador sai, e nao so no meio do escorregar:
	# afrouxando tarde, o minimo entrava 2,6 mm no comeco do caminho. O medio e o
	# anelar abrem um nada; o minimo, que e prateleira embaixo do aparelho, DOBRA
	# (`MINIMO_NA_TRAVA`) — aberto, ele subia para dentro do fundo.
	var sai := minf(_suave(k / TRAVA_SAI), _suave((1.0 - k) / TRAVA_SAI))
	var aberta: Array = MaoDoCelular.pose(&"aberta")["dedos"]
	var dedos: Array = (p["pose"]["dedos"] as Array).duplicate(true)
	for j in 4:
		dedos[0][j] = lerpf(float(dedos[0][j]), float(ergue[j]), sai)
		for i in [1, 2]:
			dedos[i][j] = lerpf(float(dedos[i][j]), float(aberta[i][j]), sai * solta)
		if j < 3:
			dedos[3][j] = float(dedos[3][j]) + float(minimo[j]) * sai
	# O polegar se afasta da lateral enquanto a mao escorrega: esticando o no de
	# cima no caminho, a ponta dele entrava 2 mm no aluminio.
	var pol: Array = (p["pose"]["polegar"] as Array).duplicate()
	for j in 5:
		pol[j] = float(pol[j]) + float(polegar[j]) * sin(PI * mao)
	p["pose"] = {"dedos": dedos, "polegar": pol}
	return p


## A mao esquerda so entra com o aparelho deitado: sobe de fora do quadro,
## aberta, e fecha na ponta esquerda, no espelho da pegada da direita.
func _montar_braco_esquerdo(corpo: Basis, delta: float) -> void:
	if giro <= 0.01:
		if braco_esq != null:
			braco_esq.visible = false
		return
	if braco_esq == null:
		var cores := _cores_do_jogador()
		braco_esq = BracoDoCelular.criar("BracoEsquerdo", false, cores["pele"], cores["manga"],
			cores["longa"])
		braco_esq.dedos_vivos = 0.0
		add_child(braco_esq)
	var k := giro * giro * (3.0 - 2.0 * giro)
	var pega := BracoDoCelular.levar(_do_deitado(), _espelho(BracoDoCelular.pega(DEITADA_O, DEITADA_D,
		DEITADA_DORSO, DEITADA_POSE)))
	var p := BracoDoCelular.levar(fone.transform, pega)
	p["o"] = (p["o"] as Vector3) + corpo * CHEGA_ESQ * pow(1.0 - k, 2.0)
	p["pose"] = MaoDoCelular.misturar(p["pose"], MaoDoCelular.pose(&"aberta"), (1.0 - k) * 0.8)
	braco_esq.ombro = corpo * Vector3(-OMBRO.x, OMBRO.y, OMBRO.z)
	braco_esq.polo = corpo * Vector3(-POLO_DEITADO.x, POLO_DEITADO.y, POLO_DEITADO.z)
	braco_esq.pular(p)
	braco_esq.tremor = 0.0
	braco_esq.visible = true
	braco_esq.passo(delta)


## Do referencial deitado (x para a direita de quem olha) para o do aparelho:
## o aparelho deitado e o de pe girado 90 graus para a esquerda.
static func _do_deitado() -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, -PI * 0.5), Vector3.ZERO)


## A pegada da mao direita refletida no plano do meio: a da esquerda.
static func _espelho(p: Dictionary) -> Dictionary:
	var q := p.duplicate()
	var s := Vector3(-1.0, 1.0, 1.0)
	q["o"] = (p["o"] as Vector3) * s
	q["d"] = (p["d"] as Vector3) * s
	q["dorso"] = (p["dorso"] as Vector3) * s
	return q
