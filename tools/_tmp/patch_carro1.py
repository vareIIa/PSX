from pathlib import Path
src = Path(r"game/src/world/carro_cena.gd")
t = src.read_text(encoding="utf-8")
repls = []
repls.append((
"""## Tinta do carro do protagonista. Nao e sorteada: e o verde escuro da print, e
## e a mesma cor em toda partida porque este carro e dele.
const TINTA := Color(0.34, 0.42, 0.34)
const SEMENTE := 4407""",
"""## Hatch claro das refs de chase (nao o verde do corte cinematografico antigo).
const TINTA := Color(0.86, 0.86, 0.82)
const SEMENTE := 4407
const MODELO := Carroceria.Modelo.HATCH
const DESVIO_JOGAVEL := 1.35"""))
repls.append((
"""const CHACOALHO_ONDA := [
	{"amp": 0.011, "onda": 3.7},
	{"amp": 0.006, "onda": 1.9},
	{"amp": 0.017, "onda": 11.3},
]
## Amplitude do arfar e do rolar, em graus, na mesma logica.
const ARFAR := 0.55
const ROLAR := 0.42
## Quanto o carro inclina para fora na curva, em graus por unidade de curvatura.
const INCLINA_CURVA := 2.6""",
"""const CHACOALHO_ONDA := [
	{"amp": 0.014, "onda": 3.4},
	{"amp": 0.008, "onda": 1.7},
	{"amp": 0.022, "onda": 9.8},
]
## Amplitude do arfar e do rolar — terra treme mais que asfalto.
const ARFAR := 0.72
const ROLAR := 0.55
## Quanto o carro inclina para fora na curva, em graus por unidade de curvatura.
const INCLINA_CURVA := 3.1"""))
repls.append((
"""## Marchas por velocidade, em km/h. A tabela e a da print: 68 km/h e terceira.
const MARCHAS := [15.0, 32.0, 70.0, 95.0]

var estrada: EstradaBuilder
## Distancia percorrida ao longo da estrada, em metros.
var distancia: float = 0.0
## Velocidade em km/h. A cena mexe nisto para o carro chegar e sair de cena.
var velocidade: float = 0.0

var cabine: CarroCabine
## Onde a camera de dentro do carro se pendura.
var suporte_camera: Node3D

var _medidas: Dictionary = {}
var _corpo: MeshInstance3D
var _luzes: MeshInstance3D
var _eixo_frente: Node3D
var _eixo_tras: Node3D
var _som: MotorSom
var _rolo: float = 0.0
var _curva: float = 0.0""",
"""## Marchas por velocidade, em km/h. Terra: teto mais baixo que asfalto.
const MARCHAS := [12.0, 28.0, 55.0, 78.0]
const VEL_MAX_JOGAVEL := 72.0
const ACEL_JOGAVEL := 18.0
const FREIO_JOGAVEL := 32.0
const MOTOR_JOGAVEL := 9.0
const ESTERCO_RESPOSTA := 1.7
const MAT_CONE := "res://resources/materials/mat_cone_luz.tres"

var estrada: EstradaBuilder
## Distancia percorrida ao longo da estrada, em metros.
var distancia: float = 0.0
## Velocidade em km/h. A cena mexe nisto para o carro chegar e sair de cena.
var velocidade: float = 0.0
## Quando true, WASD manda na velocidade e no desvio lateral.
var jogavel: bool = false
var farois_acesos: bool = false

var cabine: CarroCabine
## Onde a camera de dentro do carro se pendura.
var suporte_camera: Node3D
## Pivo atras do hatch para a chase cam (3P).
var suporte_chase: Node3D

var _medidas: Dictionary = {}
var _corpo: MeshInstance3D
var _luzes: MeshInstance3D
var _eixo_frente: Node3D
var _eixo_tras: Node3D
var _som: MotorSom
var _farol: SpotLight3D
var _facho: MeshInstance3D
var _rolo: float = 0.0
var _curva: float = 0.0
var _desvio: float = DESVIO_LATERAL
var _esterco_jogador: float = 0.0"""))
for a,b in repls:
    if a not in t:
        raise SystemExit("MISSING BLOCK:\n"+a[:80])
    t = t.replace(a,b,1)
src.write_text(t, encoding="utf-8")
print("pass1 ok", len(t))
