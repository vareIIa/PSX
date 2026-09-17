## Autoload. O eco muda com o lugar (PLANO_AAA_4K, Fase 9, A27).
##
##     godot --path game -- --eco=tunel     forca um ambiente
##     godot --path game -- --sem-eco       desliga (o antes da medida)
##
## O defeito que este arquivo conserta
## -----------------------------------
## O `default_bus_layout.tres` tem UM reverb, de sala, ligado no bus de efeitos
## desde sempre. Ou seja: o passo na avenida aberta tinha a mesma cauda que o
## passo dentro de um quarto de dois por tres. Medido em `tests/bancada_audio.gd`,
## -25,9 dB de cauda em qualquer lugar do mundo.
##
## Som nao e a imagem
## ------------------
## O olho aceita que a rua e a sala sejam iguais; o ouvido nao. Eco e a unica
## pista que uma pessoa tem, de olhos fechados, do TAMANHO do lugar onde esta —
## e e por isso que um jogo com eco de sala na rua soa como gravacao de estudio
## em vez de cidade. Nao e sutileza: e a diferenca entre estar num lugar e estar
## ouvindo um arquivo.
##
## Por que um reverb so, e nao um bus por ambiente
## -----------------------------------------------
## Porque o jogador esta num lugar de cada vez. Cinco buses com cinco reverbs
## custariam cinco caudas processadas por quadro para ouvir uma; aqui os
## parametros do mesmo reverb sao reescritos, com rampa, quando o lugar muda. A
## rampa importa: trocar de golpe corta a cauda que esta tocando e o corte se
## ouve como um clique.
class_name EcoAmbiente
extends Node

## De quanto em quanto tempo o lugar e reavaliado. Quatro vezes por segundo:
## atravessar a boca de um tunel a 60 km/h leva meio segundo.
const PASSO := 0.25
## Quanto tempo a troca leva. Meio segundo e o tempo em que o ouvido aceita a
## mudanca como "entrei em outro lugar" em vez de "mexeram no som".
const RAMPA := 0.5

## O bus onde o reverb mora. E o mesmo de sempre: ver o `default_bus_layout`.
const BUS := &"SFX"

## Cada ambiente, com os cinco numeros do `AudioEffectReverb`.
##
## `wet` e quanto do eco se ouve, `room_size` o tamanho aparente, `damping` o
## quanto o agudo morre antes do grave (parede dura reflete agudo; cortina e
## carpete comem), `predelay` o tempo ate a primeira reflexao (que e a distancia
## ate a parede mais proxima) e `spread` a largura.
##
## Os numeros vem da fisica do lugar, nao de gosto:
##
## - **rua**: ceu aberto nao devolve nada. O pouco que ha e a fachada do outro
##   lado da via, a vinte metros — predelay alto, cauda quase nula.
## - **rua_estreita**: viela de tres metros. A primeira reflexao chega quase
##   junto com o som direto (9 ms), e por isso ela soa "apertada".
## - **tunel**: concreto de todos os lados, nada absorve. Cauda longa,
##   amortecimento baixo, e o predelay do vao.
## - **sala**: o que o projeto ja tinha, e continua valendo dentro de casa.
## - **carro**: estofado, vidro e teto a meio metro. E o lugar mais MORTO do
##   jogo: quase nenhuma cauda, e o agudo some primeiro.
const AMBIENTES := {
	&"rua": {"wet": 0.03, "room": 0.85, "damp": 0.5, "predelay": 60.0, "spread": 1.0},
	&"rua_estreita": {"wet": 0.16, "room": 0.55, "damp": 0.35, "predelay": 9.0, "spread": 0.7},
	&"tunel": {"wet": 0.45, "room": 0.92, "damp": 0.12, "predelay": 24.0, "spread": 1.0},
	&"sala": {"wet": 0.16, "room": 0.42, "damp": 0.65, "predelay": 18.0, "spread": 0.6},
	&"carro": {"wet": 0.04, "room": 0.16, "damp": 0.92, "predelay": 4.0, "spread": 0.3},
}

## Largura ate a parede para a rua contar como estreita, e altura do teto para o
## lugar contar como coberto. 4,5 m de cada lado porque a viela do gerador tem
## 3 m de vao e a avenida tem 12.
const LARGURA_ESTREITA := 4.5
const TETO_COBERTO := 7.0

signal mudou(ambiente: StringName)

var ambiente: StringName = &"rua"

var _reverb: AudioEffectReverb
var _relogio := 0.0
var _forcado: StringName = &""
var _desligado := false
var _rampa: Tween
var _alvo: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--sem-eco":
			_desligado = true
		elif arg.begins_with("--eco="):
			_forcado = StringName(arg.trim_prefix("--eco="))
	_reverb = _achar_reverb()
	if _reverb == null:
		push_warning("EcoAmbiente: o bus %s nao tem AudioEffectReverb" % BUS)
		return
	if _forcado != &"":
		forcar(String(_forcado))
	else:
		_escrever(AMBIENTES[&"rua"], true)


func _achar_reverb() -> AudioEffectReverb:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		return null
	for e in AudioServer.get_bus_effect_count(i):
		var efeito := AudioServer.get_bus_effect(i, e) as AudioEffectReverb
		if efeito != null:
			return efeito
	return null


func _process(delta: float) -> void:
	if _reverb == null or _desligado or _forcado != &"":
		return
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = PASSO
	var novo := _onde_estou()
	if novo == ambiente:
		return
	var antes := ambiente
	ambiente = novo
	_escrever(AMBIENTES[novo], false)
	mudou.emit(novo)
	print("[eco] %s -> %s" % [antes, novo])


## Que lugar e este, pela ordem em que as respostas mandam umas nas outras.
##
## Dentro do carro vence tudo: um carro dentro de um tunel soa como carro, e o
## tunel entra pela janela como som de fora, que e outro caminho. Interior vence
## rua. So depois disso a geometria decide entre avenida, viela e tunel.
func _onde_estou() -> StringName:
	var jogador := get_tree().get_first_node_in_group(&"player")
	if jogador != null and jogador.has_method(&"dirigindo") \
			and bool(jogador.call(&"dirigindo")):
		return &"carro"
	var interiores := get_node_or_null(^"/root/Interiores")
	if interiores != null and bool(interiores.get(&"dentro")):
		return &"sala"
	var no := jogador as Node3D
	if no == null:
		return &"rua"
	var pos := no.global_position + Vector3.UP
	var esq := _distancia(pos, Vector3.LEFT)
	var dir := _distancia(pos, Vector3.RIGHT)
	var teto := _distancia(pos, Vector3.UP)
	if teto <= TETO_COBERTO and esq <= LARGURA_ESTREITA and dir <= LARGURA_ESTREITA:
		return &"tunel"
	if esq <= LARGURA_ESTREITA and dir <= LARGURA_ESTREITA:
		return &"rua_estreita"
	return &"rua"


## Quantos metros ate a primeira parede naquela direcao.
func _distancia(de: Vector3, dir: Vector3) -> float:
	var mundo := get_viewport().find_world_3d()
	if mundo == null:
		return 999.0
	var alcance := maxf(LARGURA_ESTREITA, TETO_COBERTO) + 1.0
	var consulta := PhysicsRayQueryParameters3D.create(de, de + dir * alcance)
	consulta.collide_with_areas = false
	var bate := mundo.direct_space_state.intersect_ray(consulta)
	if bate.is_empty():
		return 999.0
	return de.distance_to(bate["position"] as Vector3)


## Escreve os cinco numeros, com rampa.
func _escrever(d: Dictionary, imediato: bool) -> void:
	if _reverb == null:
		return
	_alvo = d
	if _rampa != null and _rampa.is_valid():
		_rampa.kill()
	if imediato:
		_reverb.wet = float(d["wet"])
		_reverb.room_size = float(d["room"])
		_reverb.damping = float(d["damp"])
		_reverb.predelay_msec = float(d["predelay"])
		_reverb.spread = float(d["spread"])
		return
	_rampa = create_tween().set_parallel(true)
	_rampa.tween_property(_reverb, "wet", float(d["wet"]), RAMPA)
	_rampa.tween_property(_reverb, "room_size", float(d["room"]), RAMPA)
	_rampa.tween_property(_reverb, "damping", float(d["damp"]), RAMPA)
	_rampa.tween_property(_reverb, "predelay_msec", float(d["predelay"]), RAMPA)
	_rampa.tween_property(_reverb, "spread", float(d["spread"]), RAMPA)


# --- para a bancada e para a depuracao --------------------------------------

func nomes() -> PackedStringArray:
	var saida := PackedStringArray()
	for n: StringName in AMBIENTES:
		saida.append(String(n))
	return saida


## Fixa um ambiente e para de decidir sozinho.
func forcar(nome: String) -> bool:
	var chave := StringName(nome)
	if not AMBIENTES.has(chave):
		return false
	_forcado = chave
	ambiente = chave
	_escrever(AMBIENTES[chave], true)
	mudou.emit(chave)
	return true


## Volta a decidir pelo mundo.
func soltar() -> void:
	_forcado = &""
	_relogio = 0.0
