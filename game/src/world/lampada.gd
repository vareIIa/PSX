## Lampada com facho de luz geometrico e defeito proprio.
##
## Junta tres coisas que tem que piscar juntas ou o efeito quebra: a fonte
## dinamica, o cone de luz somado e a emissao do corpo da luminaria. Piscar so a
## luz e deixar o facho aceso denuncia o truque na hora.
##
## Os padroes nao sao ruido aleatorio. Lampada de sodio de rua morre de um jeito
## especifico: apaga de vez, fica escura alguns segundos e volta devagar, porque
## o vapor precisa reaquecer. Fluorescente faz o oposto, surta em rajada rapida e
## volta. Errar isso faz o cenario parecer discoteca em vez de rua abandonada.
class_name Lampada
extends Node3D

const MAT_CONE := "res://resources/materials/mat_cone_luz.tres"

## Quanto a lampada empurra para dentro da nevoa volumetrica no MODERNO.
##
## Vale 1,0 por padrao no Godot, e com 1,0 o halo no ar quase nao aparece nesta
## cidade: a densidade da nevoa noturna e baixa de proposito, para a rua nao
## virar leite.
##
## Calibrado por captura na rota `luz`. Medindo o contraste do halo (anel de
## 30 a 90 px em volta da lampada) contra o ceu longe, na parada
## `poste_de_baixo`: 8 da 73, 18 da 98 e 36 da 124, e o ceu longe sobe de
## 17,3 para 22,4 no caminho.
##
## Mesmo assim o valor e 8, e quem decidiu foi a outra parada: em 18, a
## `poste_perto` — a 4,5 m da lampada, ou seja DENTRO do halo — sai lavada,
## com o quadro inteiro embranquecido e os aneis da grade da nevoa
## volumetrica visiveis. Contraste maior num enquadramento nao vale o
## quadro estragado no outro.
const VOLUME_MODERNO := 8.0

enum Padrao {
	ESTAVEL,          ## acesa, com uma ondulacao quase imperceptivel
	SODIO_FALHANDO,   ## apaga de vez e reacende devagar
	FLUORESCENTE,     ## rajadas rapidas de tremulacao
	MORTA,            ## apagada, com um estalo raro
	VELA,             ## respira: onda lenta e irregular, e nunca apaga
}

@export var padrao: Padrao = Padrao.ESTAVEL
@export var cor: Color = Color("ffb763")
@export_range(0.0, 12.0, 0.1) var energia: float = 3.6
@export_range(0.5, 40.0, 0.5) var alcance: float = 11.5
@export_range(0.0, 4.0, 0.05) var atenuacao: float = 1.1

@export_group("Facho")
@export var facho_visivel: bool = true
@export_range(0.05, 3.0, 0.05) var raio_topo: float = 0.28
@export_range(0.2, 12.0, 0.1) var raio_base: float = 3.1
@export_range(0.5, 20.0, 0.1) var altura_facho: float = 6.3

## Semente do defeito. Duas lampadas com a mesma semente piscam iguais, o que
## fica obviamente artificial numa fileira de postes.
@export var semente: int = 0

## Nivel atual, de 0 a 1. Outros sistemas podem ler, por exemplo para o radio
## chiar quando a luz cai.
var nivel: float = 1.0

signal apagou()
signal acendeu()

var _luz: OmniLight3D
var _facho: MeshInstance3D
var _rng := RandomNumberGenerator.new()

var _estado: int = 0
var _restante: float = 0.0
var _t: float = 0.0
var _alvo: float = 1.0
var _de: float = 1.0
var _dur: float = 1.0
var _estava_aceso: bool = true


func _ready() -> void:
	add_to_group(&"lampada")
	_rng.seed = semente if semente != 0 else hash(get_path())
	_montar()
	_sortear_estado_inicial()
	Settings.changed.connect(_aplicar_densidade)
	_aplicar_densidade()


func _montar() -> void:
	_luz = OmniLight3D.new()
	_luz.name = "Fonte"
	_luz.light_color = cor
	_luz.light_energy = energia
	_luz.omni_range = alcance
	_luz.omni_attenuation = atenuacao
	# Nasce sem sombra e se inscreve para concorrer a ela. Quem liga e o
	# DiretorSombra, que mantem so as duas mais proximas projetando — no estilo
	# PS1 STYLE nenhuma projeta, e a lampada continua exatamente como era.
	_luz.shadow_enabled = false
	_luz.add_to_group(DiretorSombra.GRUPO)
	# Luz de rua nao atravessa parede de casa que existe na rua: sem sombra, uma
	# Omni de poste acenderia o piso da sala pelo lado de dentro da fachada. A
	# lampada que nasce DENTRO de uma dessas casas recebe a mascara da casa logo
	# em seguida (InteriorNoMundo._marcar).
	_luz.light_cull_mask &= ~InteriorNoMundo.CAMADA
	add_child(_luz)

	if not facho_visivel:
		return

	_facho = MeshInstance3D.new()
	_facho.name = "Facho"
	# A cor entra na malha, nao no material: o material e compartilhado.
	_facho.mesh = PSXMesh.cone(raio_topo, raio_base, altura_facho, 8, 3,
		Color(cor.r, cor.g, cor.b, 0.5), Color(cor.r, cor.g, cor.b, 0.0))
	if ResourceLoader.exists(MAT_CONE):
		_facho.material_override = load(MAT_CONE)
	else:
		push_error("Lampada: material do facho ausente em %s" % MAT_CONE)
	_facho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# O facho e translucido e somado: entra depois de tudo que e opaco.
	_facho.sorting_offset = -1.0
	add_child(_facho)


## O facho so tem o que iluminar se houver nevoa. Com nevoa densa ele domina a
## cena, com nevoa desligada ele quase some. Isso e o que amarra o efeito ao
## sistema de oclusao em vez de deixar solto como enfeite.
##
## No MODERNO o cone de malha NAO e desenhado. Medido em 16/09/2026, na rota
## `luz`, parada `poste_perto`: o tronco de cone somado acendia 29,9% da tela,
## com +45,7/255 de media e +162/255 de pico, e apagava o predio atras dele —
## um triangulo de nevoa branca com bordas retas, que e exatamente o que o
## jogador descreve como "a luz parece um cone, da para ver a linha".
##
## E redundante, ainda por cima: o Forward+ ja desenha o facho de verdade, em
## nevoa volumetrica (ver `FogController._volumetrica`). Duas camadas de ar
## aceso para a mesma lampada, uma delas com silhueta. No MODERNO fica so a de
## verdade, e a lampada empurra mais luz para dentro dela; no PS1 STYLE fica so
## a malha, que e o que o console fazia e o que o ART-BIBLE manda.
func _aplicar_densidade() -> void:
	var moderno: bool = Settings.luz_por_pixel
	if _luz != null:
		# So quem TINHA cone ganha halo: o halo existe para substituir a malha.
		# A lampada de teto de um comodo nasce com `facho_visivel = false` e
		# nunca teve cone; dar o mesmo empurrao a ela encheu a sala de bruma —
		# medido, +11,2/255 em 80% dos blocos do interior da rota.
		var halo := moderno and facho_visivel
		_luz.light_volumetric_fog_energy = VOLUME_MODERNO if halo else 1.0
	if _facho == null:
		return
	_facho.visible = not moderno
	if moderno:
		return
	# Densidade e global, entao vai no material compartilhado mesmo.
	_facho.material_override.set_shader_parameter(
		&"intensidade", Settings.fog_preset().facho_forca)


func _physics_process(delta: float) -> void:
	if padrao == Padrao.ESTAVEL:
		_t += delta
		# Ondulacao minima. Nao e para ser notada, e para a luz nao parecer
		# congelada quando o jogador fica parado olhando para ela.
		nivel = 1.0 + sin(_t * 2.3) * 0.015
	else:
		_avancar(delta)

	_aplicar_nivel()


func _aplicar_nivel() -> void:
	_luz.light_energy = energia * nivel
	if _facho != null:
		_facho.set_instance_shader_parameter(&"piscar", nivel)

	var aceso := nivel > 0.25
	if aceso != _estava_aceso:
		_estava_aceso = aceso
		if aceso:
			acendeu.emit()
		else:
			apagou.emit()


# --- maquina de estados do defeito ------------------------------------------

func _avancar(delta: float) -> void:
	_restante -= delta
	_t += delta

	if _restante > 0.0:
		nivel = _interpolar()
		return

	match padrao:
		Padrao.SODIO_FALHANDO: _proximo_sodio()
		Padrao.FLUORESCENTE: _proximo_fluorescente()
		Padrao.MORTA: _proximo_morta()
		Padrao.VELA: _proximo_vela()
		_: nivel = 1.0


func _interpolar() -> float:
	if _dur <= 0.0:
		return _alvo
	var k := clampf(1.0 - _restante / _dur, 0.0, 1.0)
	return lerpf(_de, _alvo, k)


func _ir_para(alvo: float, duracao: float) -> void:
	_de = nivel
	_alvo = alvo
	_dur = maxf(0.0001, duracao)
	_restante = _dur


## Sodio: aceso muito tempo, apaga rapido, fica escuro e reacende devagar.
## O reacendimento lento e a assinatura: o vapor precisa reaquecer.
func _proximo_sodio() -> void:
	match _estado:
		0:  # aceso
			_estado = 1
			_ir_para(0.04, 0.12)
		1:  # apagado, esperando esfriar
			_estado = 2
			_ir_para(0.03, _rng.randf_range(0.5, 2.2))
		2:  # religando devagar
			_estado = 3
			_ir_para(1.0, _rng.randf_range(0.9, 2.1))
		_:  # de volta ao normal
			_estado = 0
			_ir_para(1.0, _rng.randf_range(3.5, 11.0))


## Fluorescente: rajada de tremulacao rapida, depois estabilidade.
func _proximo_fluorescente() -> void:
	if _estado == 0:
		_estado = 1
		_ir_para(1.0, _rng.randf_range(2.0, 7.0))
		return

	# Dentro da rajada alterna entre quase apagada e cheia, a cerca de 15 Hz
	if _estado < 14 and _rng.randf() < 0.82:
		_estado += 1
		var claro := _estado % 2 == 0
		_ir_para(1.0 if claro else _rng.randf_range(0.06, 0.3),
			_rng.randf_range(0.03, 0.09))
		return

	_estado = 0
	_ir_para(1.0, 0.12)


## Vela: respiracao, e nao piscada.
##
## Existe porque nenhum dos outros quatro padroes serve a uma chama, e o erro
## obvio seria usar FLUORESCENTE: rajada de quinze hertz le como contato solto
## de reator, que e defeito ELETRICO. Chama nao tem defeito, tem corrente de ar.
##
## Tres coisas separam uma da outra, e as tres estao nos numeros abaixo:
##
##   - O piso nunca e zero. Vela que apaga e vela apagada; enquanto queima, ela
##     varia entre 0,72 e 1,0. Uma igreja cuja luz some de vez em quando diz
##     "a instalacao esta ruim"; uma que respira diz "tem alguem la dentro".
##   - O tempo e LONGO. Meio segundo a um segundo e meio por batida, contra os
##     trinta a noventa milissegundos da fluorescente.
##   - De vez em quando uma queda mais funda, como quando a porta abre em algum
##     lugar. E o unico evento do ciclo, e por isso e o que o olho nota.
const VELA_MIN := 0.72
const VELA_SOPRO := 0.38
## Uma batida em sete e o sopro. Menos que isso e enfeite que nunca acontece;
## mais e uma vela num vendaval.
const VELA_CHANCE_SOPRO := 0.14


func _proximo_vela() -> void:
	if _rng.randf() < VELA_CHANCE_SOPRO:
		# O sopro: cai depressa e volta devagar. Cair e voltar no mesmo tempo
		# le como oscilacao de tensao, nao como ar batendo na chama.
		if _estado == 0:
			_estado = 1
			_ir_para(VELA_SOPRO, _rng.randf_range(0.10, 0.22))
			return
		_estado = 0
		_ir_para(_rng.randf_range(0.88, 1.0), _rng.randf_range(0.5, 1.1))
		return
	_estado = 0
	_ir_para(_rng.randf_range(VELA_MIN, 1.0), _rng.randf_range(0.45, 1.5))


## Morta: apagada, com um estalo curto de vez em quando.
func _proximo_morta() -> void:
	if _estado == 0:
		_estado = 1
		_ir_para(_rng.randf_range(0.5, 0.9), 0.05)
	elif _estado == 1:
		_estado = 2
		_ir_para(0.0, 0.08)
	else:
		_estado = 0
		_ir_para(0.0, _rng.randf_range(4.0, 15.0))


## Comeca em ponto aleatorio do ciclo. Sem isso uma rua inteira de postes
## apagaria em sincronia no primeiro segundo de jogo.
func _sortear_estado_inicial() -> void:
	nivel = 1.0
	match padrao:
		Padrao.MORTA:
			nivel = 0.0
			_ir_para(0.0, _rng.randf_range(0.5, 12.0))
		Padrao.SODIO_FALHANDO:
			_estado = 0
			_ir_para(1.0, _rng.randf_range(0.5, 11.0))
		Padrao.FLUORESCENTE:
			_estado = 0
			_ir_para(1.0, _rng.randf_range(0.5, 7.0))
		_:
			_t = _rng.randf_range(0.0, 10.0)
