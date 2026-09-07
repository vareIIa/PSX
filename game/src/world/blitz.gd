## Uma blitz montada na pista: funil de cones, viatura, oficiais e carros
## encostados no acostamento.
##
## Convencao local: +Z e a direcao do fluxo (frente dos carros), origem no
## comeco do funil. O BlitzManager posiciona e gira este no no mundo.
class_name Blitz
extends Node3D

const COMPRIMENTO_FUNIL := 18.0
const LARGURA_INSPCAO := 2.2
const MARGEM_ACOST := 3.2
const GIROFLEX_PERIODO := 0.28

## Identidade estavel desta blitz (semente de spawn).
var id_blitz: int = 0
## Trecho de via onde esta plantada.
var trecho := Vector4i.ZERO
var de := Vector2i.ZERO
var para := Vector2i.ZERO

var _t: float = 0.0
var _giroflex: Node3D
var _ponto_parada := Vector3.ZERO
var _faixa_inspcao: int = 0



## Consulta usada pela IA do Carro. Devolve dicionario vazio ou:
##   parar  bool   — frear ate zero no funil
##   teto   float  — teto de velocidade m/s
##   faixa  int    — faixa sugerida (-1 = nao muda)
##   eixo   int    — eixo da via da blitz
##   mira   Vector3 — ponto de mira (parado ou desvio)
static func efeito(carro: Carro) -> Dictionary:
	if carro == null or not is_instance_valid(carro):
		return {}
	var info := BlitzManager.consulta(carro.global_position, carro.trecho, carro.semente)
	if info.is_empty():
		return {}
	var b: Blitz = info["blitz"]
	var parar: bool = bool(info["parar"])
	# Quem nao para muda para a faixa de dentro (1) se a via tiver.
	var faixa := -1
	if not parar:
		var via := (MalhaUrbana.via_x(b.de.x) if b.trecho.z == 0
			else MalhaUrbana.via_z(b.de.y))
		if Vias.faixas(via) > 1:
			faixa = 1
	return {
		"parar": parar,
		"teto": float(info["teto"]),
		"faixa": faixa,
		"eixo": b.trecho.z,
		"mira": info["mira"],
	}


func montar(semente: int, t: Dictionary) -> void:
	id_blitz = semente
	trecho = t["trecho"]
	de = t["de"]
	para = t["para"]
	_faixa_inspcao = 0  # faixa de fora (meio-fio), onde a blitz funila
	_montar_cones()
	_montar_placas()
	_montar_bollard()
	_montar_viatura(semente)
	_montar_oficiais(semente)
	_montar_encostados(semente)
	# Ponto de parada: meio do funil, na faixa de inspecao.
	_ponto_parada = Vector3(0.0, 0.0, COMPRIMENTO_FUNIL * 0.55)
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	if _giroflex == null:
		return
	# Alterna R/B: um aceso enquanto o outro apaga.
	var fase := int(floor(_t / GIROFLEX_PERIODO)) % 2
	var r: OmniLight3D = _giroflex.get_node_or_null("R") as OmniLight3D
	var b: OmniLight3D = _giroflex.get_node_or_null("B") as OmniLight3D
	if r != null:
		r.light_energy = 4.2 if fase == 0 else 0.15
	if b != null:
		b.light_energy = 4.2 if fase == 1 else 0.15


## O carro nesta posicao/trecho esta dentro da zona de influencia?
func influencia(pos_mundo: Vector3, trecho_carro: Vector4i) -> bool:
	if trecho_carro.z != trecho.z or trecho_carro.w != trecho.w:
		return false
	var local := to_local(pos_mundo)
	if local.z < -4.0 or local.z > COMPRIMENTO_FUNIL + 8.0:
		return false
	if absf(local.x) > 6.0:
		return false
	return true


## Este carro deve parar no funil? Deterministico por (blitz, semente do carro).
func selecionado_para_parar(semente_carro: int) -> bool:
	var h := absi(id_blitz * 2654435761 ^ semente_carro * 40503) % 100
	return h < 32


## Ponto mundial onde o selecionado deve frear.
func ponto_de_parada() -> Vector3:
	return to_global(_ponto_parada)


## Mira lateral para quem NAO para: empurra para a faixa de dentro (desvio).
func mira_desvio(pos_mundo: Vector3) -> Vector3:
	var local := to_local(pos_mundo)
	# Faixa interna fica em -X no espaco local (direita do fluxo e +X = meio-fio).
	var alvo := Vector3(-2.2, 0.0, clampf(local.z + 6.0, 0.0, COMPRIMENTO_FUNIL + 6.0))
	return to_global(alvo)


## Teto de velocidade sugerido na zona (m/s).
func teto_na_zona(pos_mundo: Vector3, deve_parar: bool) -> float:
	var local := to_local(pos_mundo)
	if deve_parar:
		var d := local.distance_to(_ponto_parada)
		if d < 3.5:
			return 0.0
		if local.z > _ponto_parada.z - 1.0:
			return 0.0
		return 3.5
	# Quem desvia passa lento pelo funil.
	if local.z > 0.0 and local.z < COMPRIMENTO_FUNIL:
		return 5.0
	return 8.0



func _colisao_caixa(centro: Vector3, tamanho: Vector3) -> void:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = tamanho
	shape.shape = box
	corpo.add_child(shape)
	corpo.position = centro
	add_child(corpo)


func _montar_cones() -> void:
	# Funil: cones em diagonal da faixa interna para a de inspecao.
	var n := 7
	for i in n:
		var t := float(i) / float(n - 1)
		var z := 1.5 + t * (COMPRIMENTO_FUNIL - 3.0)
		# Comeca afastado (-X) e fecha em +X (faixa do meio-fio).
		var x := lerpf(-2.4, 0.9, t)
		var c := KitBlitz.cone_transito()
		c.position = Vector3(x, 0.68, z)
		add_child(c)
		_colisao_caixa(Vector3(x, 0.35, z), Vector3(0.4, 0.7, 0.4))
	# Fileira no acostamento (nao atravessar).
	for i in 4:
		var c2 := KitBlitz.cone_transito()
		c2.position = Vector3(MARGEM_ACOST - 0.3, 0.68, 4.0 + float(i) * 3.5)
		add_child(c2)
		_colisao_caixa(Vector3(MARGEM_ACOST - 0.3, 0.35, 4.0 + float(i) * 3.5), Vector3(0.4, 0.7, 0.4))


func _montar_placas() -> void:
	for z: float in [2.0, 10.0]:
		var p := KitBlitz.placa()
		p.position = Vector3(1.6, 0.0, z)
		add_child(p)


func _montar_bollard() -> void:
	var b := KitBlitz.bollard()
	b.position = Vector3(MARGEM_ACOST + 0.2, 0.0, 3.0)
	add_child(b)


func _montar_viatura(semente: int) -> void:
	var viatura := Node3D.new()
	viatura.name = "Viatura"
	# Branca da PM.
	var medidas := Carroceria.montar(Carroceria.Modelo.SEDA, Color(0.92, 0.92, 0.94), semente)
	var lataria := MeshInstance3D.new()
	lataria.mesh = medidas["corpo"]
	lataria.material_override = load(Carroceria.MATERIAL)
	lataria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viatura.add_child(lataria)
	var luzes := MeshInstance3D.new()
	luzes.mesh = medidas["luzes"]
	luzes.material_override = load(Carroceria.MATERIAL_LUZ)
	luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viatura.add_child(luzes)
	# No acostamento, de frente para o fluxo (contra mao visual = vigia).
	viatura.position = Vector3(MARGEM_ACOST + 0.6, 0.05, COMPRIMENTO_FUNIL * 0.35)
	viatura.rotation.y = PI  # olhando para -Z local = contra o fluxo
	add_child(viatura)
	_colisao_caixa(viatura.position + Vector3(0.0, 0.7, 0.0), Vector3(1.8, 1.4, 4.4))
	_giroflex = KitBlitz.giroflex()
	_giroflex.position = Vector3(0.0, float(medidas["altura"]) + 0.05, 0.0)
	viatura.add_child(_giroflex)


func _montar_oficiais(semente: int) -> void:
	# Tres oficiais: um no funil, dois no acostamento.
	var postos: Array[Vector3] = [
		Vector3(0.6, 0.0, COMPRIMENTO_FUNIL * 0.55),
		Vector3(MARGEM_ACOST - 0.2, 0.0, COMPRIMENTO_FUNIL * 0.4),
		Vector3(MARGEM_ACOST + 0.4, 0.0, COMPRIMENTO_FUNIL * 0.6),
	]
	for i in postos.size():
		var corp := Corpo.new()
		corp.name = "Oficial_%d" % i
		corp.montar(_aparencia_pm(semente + i * 97))
		corp.position = postos[i]
		# Olham para o fluxo (-Z no local do oficial = rotacao 0 se frente e -Z).
		corp.rotation.y = PI if i == 0 else -PI * 0.5
		add_child(corp)


func _montar_encostados(semente: int) -> void:
	for i in 2:
		var seed_c := semente + 500 + i * 131
		var modelo: Carroceria.Modelo = (
			Carroceria.Modelo.HATCH if i == 0 else Carroceria.Modelo.SEDA)
		var tinta: Color = Carroceria.TINTAS[absi(seed_c * 7919) % Carroceria.TINTAS.size()]
		var medidas := Carroceria.montar(modelo, tinta, seed_c)
		var no := Node3D.new()
		no.name = "Encostado_%d" % i
		var lataria := MeshInstance3D.new()
		lataria.mesh = medidas["corpo"]
		lataria.material_override = load(Carroceria.MATERIAL)
		lataria.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(lataria)
		var luzes := MeshInstance3D.new()
		luzes.mesh = medidas["luzes"]
		luzes.material_override = load(Carroceria.MATERIAL_LUZ)
		luzes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(luzes)
		no.position = Vector3(MARGEM_ACOST + 1.1, 0.05,
			COMPRIMENTO_FUNIL * 0.7 + float(i) * 5.0)
		no.rotation.y = PI * 0.08 * (1 if i == 0 else -1)
		add_child(no)
		_colisao_caixa(no.position + Vector3(0.0, 0.7, 0.0), Vector3(1.7, 1.3, 4.0))


## Uniforme PM legivel em escala PSX: calca cinza, colete neon, bone branco.
static func _aparencia_pm(semente: int) -> Dictionary:
	var base := Aparencia.de_ficha({
		"id": absi(semente),
		"sexo": &"M",
		"idade": 28 + absi(semente) % 20,
	})
	base["casaco"] = true
	base["casaco_cor"] = Color(0.78, 0.92, 0.12)  # colete amarelo reflexivo
	base["casaco_cel"] = 0
	base["camisa_cor"] = Color(0.45, 0.48, 0.5)  # fatiga cinza
	base["calca_cor"] = Color(0.4, 0.42, 0.45)
	base["chapeu"] = true
	base["chapeu_cor"] = Color(0.95, 0.95, 0.93)  # bone branco
	base["chapeu_tipo"] = 1
	base["sapato_cor"] = Color(0.12, 0.12, 0.12)
	return base
