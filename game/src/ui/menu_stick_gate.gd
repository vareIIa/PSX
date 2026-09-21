## MenuStickGate — SPEC_A11Y_RE7 §4.2
## Stick ESQUERDO de menu: deadzone ≥0.5, cruz digital, 1 passo por cruzamento.
## Stick direito NÃO move inventário/focus (ignora JOY_AXIS_RIGHT_*).
## Retorno à deadzone (ou mudança de eixo dominante) antes do próximo passo.
class_name MenuStickGate
extends RefCounted

const DEADZONE := 0.5

## True = stick está (ou voltou) na zona morta → próximo tilt emite 1 passo.
var _na_zona: bool = true
var _ultimo: Vector2i = Vector2i.ZERO


## Lê só o stick esquerdo do device; right stick ignorado.
func poll(device: int = 0) -> Vector2i:
	var lx := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var ly := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	return passo(lx, ly)


## Quantiza (lx, ly) em Vector2i (-1/0/1). ZERO = sem passo neste frame.
func passo(lx: float, ly: float) -> Vector2i:
	var ax := absf(lx)
	var ay := absf(ly)
	if ax < DEADZONE and ay < DEADZONE:
		_na_zona = true
		_ultimo = Vector2i.ZERO
		return Vector2i.ZERO
	var step := Vector2i.ZERO
	# Cruz digital: eixo dominante.
	if ax >= ay and ax >= DEADZONE:
		step.x = 1 if lx > 0.0 else -1
	elif ay >= DEADZONE:
		step.y = 1 if ly > 0.0 else -1
	else:
		return Vector2i.ZERO
	if not _na_zona:
		# Sem retorno à deadzone: só permite se mudou o eixo dominante.
		if step == _ultimo:
			return Vector2i.ZERO
	_na_zona = false
	_ultimo = step
	return step


func reset() -> void:
	_na_zona = true
	_ultimo = Vector2i.ZERO
