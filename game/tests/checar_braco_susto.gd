## Carrega os scripts do braco do susto com o projeto inteiro no ar (os autoloads
## existem aqui, e no `--check-only --script` nao) e diz se compilaram. Tambem
## confere as contas do `alcance_vivo.gd` que tem de dar certo por construcao.
##
##   Godot --headless --path game res://tests/checar_braco_susto.tscn
extends Node

const SCRIPTS := [
	"res://src/world/alcance_vivo.gd",
	"res://src/world/braco_sem_esporao.gd",
	"res://src/world/trajeto_do_braco.gd",
	"res://src/celular/pegada_leitura.gd",
	"res://src/world/motorista_cena.gd",
	"res://tests/diag_pegar_celular.gd",
	"res://src/levels/abertura_estrada.gd",
]


func _ready() -> void:
	var falhas := 0
	for p: String in SCRIPTS:
		var s := load(p) as GDScript
		if s == null or not s.can_instantiate():
			print("[checar] FALHOU: ", p)
			falhas += 1
		else:
			print("[checar] ok: ", p)
	var AV = load("res://src/world/alcance_vivo.gd")
	# A curva monotona: passa pelos pontos e nunca desce.
	var xs := PackedFloat32Array([0.0, 0.07, 0.13, 0.30, 0.50, 0.70, 0.86, 1.0])
	var ys := PackedFloat32Array([0.0, 0.05, 0.075, 0.42, 0.78, 0.94, 0.99, 1.0])
	var ant := -1.0
	var desce := 0
	for i in 201:
		var v: float = AV.curva(xs, ys, float(i) / 200.0)
		if v < ant - 1e-6:
			desce += 1
		ant = v
	var pontos_ok := true
	for i in xs.size():
		if absf(AV.curva(xs, ys, xs[i]) - ys[i]) > 1e-5:
			pontos_ok = false
	print("[checar] curva: desce %d vezes, passa nos pontos: %s" % [desce, pontos_ok])
	if desce > 0 or not pontos_ok:
		falhas += 1
	# O ruido fica em [-1, 1] e nao e constante.
	var mn := 9.0
	var mx := -9.0
	for i in 2000:
		var r: float = AV.ruido(float(i) * 0.037, 3.0)
		mn = minf(mn, r)
		mx = maxf(mx, r)
	print("[checar] ruido: %.2f a %.2f" % [mn, mx])
	if mn < -1.001 or mx > 1.001 or mx - mn < 0.8:
		falhas += 1
	# As tentativas: comecam recolhidas e a terceira acaba antes da pinca (1,83 s).
	var t3: Dictionary = AV.tentativa(1.80)
	print("[checar] tentativa em 1,80 s: a=%.3f garra=%.3f" % [t3["a"], t3["garra"]])
	for tc: float in [-0.3, 0.0, 0.2, 0.5, 0.8, 1.0, 1.3, 1.5, 1.7, 1.83, 2.1, 2.6, 3.4]:
		var t: Dictionary = AV.tentativa(tc)
		print("[checar]   tc=%.2f a=%.2f garra=%.2f forca=%.2f" % [tc, t["a"], t["garra"], t["forca"]])
	# A mola chega no alvo.
	var m = AV.Mola.new(2.2, 0.55)
	for i in 120:
		m.passo(Vector3.ONE, 1.0 / 60.0)
	print("[checar] mola em 2 s: %s" % m.x)
	print("[checar] %s" % ("TUDO OK" if falhas == 0 else "%d FALHAS" % falhas))
	get_tree().quit(falhas)
