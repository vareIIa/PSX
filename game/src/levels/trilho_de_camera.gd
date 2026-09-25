## Camera de cinema por um caminho: posicao e mira em Catmull-Rom, fov que
## anda junto, e um PORTADOR opcional que vai no chao um pouco a frente da lente.
##
## Por que nao o `Cinema.mover`
## ----------------------------
## O `mover` e reta entre dois pontos com a mira reta entre outros dois. Serve
## para plano parado que avanca. Entrar numa loja pela porta e virar para o
## caixa e curva: a lente vem da rua, passa pelo vao e vira para a esquerda, e
## a mira vai da porta para o balcao por outro caminho.
##
## O portador
## ----------
## A loja da rua reage ao JOGADOR, e nao a camera: a porta automatica abre para
## quem esta no sensor dela, e a soleira mistura o ar da rua com o da loja pela
## posicao dele (`InteriorNoMundo`). Com o corpo dele escondido andando no chao
## `adiantado` segundos a frente da lente, a porta abre antes de a camera chegar
## no vidro e o ar muda enquanto ela atravessa — pelos sistemas da propria loja,
## sem nenhum caso especial para a abertura.
class_name TrilhoDeCamera
extends Node

signal terminou

var pontos: Array[Vector3] = []
var miras: Array[Vector3] = []
var duracao: float = 1.0
var fov := Vector2(50.0, 50.0)
## Quanto do smoothstep entra no tempo: 0 velocidade constante, 1 arranca e
## freia de todo.
var suave: float = 0.6
## Tremor de mao, em metros.
var tremor: float = 0.006
var portador: Node3D
## Altura do chao sob o caminho, no mundo (o portador anda nela).
var chao: float = 0.0
var adiantado: float = 1.0
## Chamado a cada quadro com a posicao da lente e o tempo do caminho (0 a 1):
## para quem precisa reagir a camera (o ar da loja muda quando ela passa a
## porta, e nao quando o jogador passa).
var ao_quadro: Callable

var _t: float = 0.0
var _cam: Camera3D
var _acabou: bool = false


## Monta, assume a camera do `Cinema` e poe a lente no primeiro ponto.
static func rodar(pai: Node, caminho: Array[Vector3], mira: Array[Vector3],
		dur: float, fov_de: float, fov_ate: float) -> TrilhoDeCamera:
	var t := TrilhoDeCamera.new()
	t.name = "TrilhoDeCamera"
	t.pontos = caminho
	t.miras = mira
	t.duracao = maxf(dur, 0.01)
	t.fov = Vector2(fov_de, fov_ate)
	t.process_priority = 100
	pai.add_child(t)
	t._cam = Cinema.assumir()
	t._quadro(0.0)
	# Corte: a lente nao le o pulo da camera como movimento.
	Lente.recomecar()
	return t


func _process(delta: float) -> void:
	_quadro(delta)


func _quadro(delta: float) -> void:
	_t += delta
	var u := clampf(_t / duracao, 0.0, 1.0)
	var e := _tempo(u)
	var onde := AcordarNaPraca._catmull(pontos, e)
	var alvo := AcordarNaPraca._catmull(miras, e)
	var r := _t
	var mao := Vector3(sin(r * 1.3) + 0.5 * sin(r * 3.1 + 1.0),
		sin(r * 0.9 + 2.0) + 0.5 * sin(r * 2.6), 0.0) * tremor
	if _cam != null and is_instance_valid(_cam):
		_cam.fov = lerpf(fov.x, fov.y, e)
		_cam.global_position = onde + mao
		if (alvo - onde).length() > 0.01:
			_cam.look_at(alvo, Vector3.UP)
	if ao_quadro.is_valid():
		ao_quadro.call(onde, e)
	if portador != null and is_instance_valid(portador):
		var la := AcordarNaPraca._catmull(pontos,
			_tempo(clampf((_t + adiantado) / duracao, 0.0, 1.0)))
		portador.global_position = Vector3(la.x, chao, la.z)
	if u >= 1.0 and not _acabou:
		_acabou = true
		terminou.emit()


func _tempo(u: float) -> float:
	return lerpf(u, u * u * (3.0 - 2.0 * u), suave)
