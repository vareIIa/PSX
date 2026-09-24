## O interior de verdade do carro: painel esculpido, cluster com quatro
## mostradores, toca-fitas, comandos do ar, porta-trecos com a tomada, console
## com cambio e freio de mao, coluna de direcao com chave, pedais, bancos e o
## forro das portas.
##
## Por que existe
## --------------
## O interior era a casca (`CabineCasca`) com pecas do atlas coladas por dentro:
## um painel de 11 cm de altura feito de duas placas, tres mostradores de pixel,
## um radio que era uma celula da textura e um console que era uma caixa com um
## palito e um cubo em cima. Do banco do motorista, em 4K, a unica coisa que lia
## como carro era o volante.
##
## Referencia: os populares brasileiros dos anos 90 — Uno, Marea, Gol quadrado,
## e o Fusca pelo que ele tem de acolhedor. Painel em dois tons (o de cima
## escuro, contra o reflexo no para-brisa, o de baixo cor de camurca), cluster
## sob uma pala, retroiluminacao ambar, toca-fitas de gaveta, madeira falsa do
## lado do passageiro, e o porta-trecos cheio do que se esquece no carro.
##
## Um interior so para todos os modelos
## ------------------------------------
## Tudo aqui se mede do que a cabine devolve — o assoalho, o olho, a borda do
## painel, a parede da casca, o para-brisa — e nunca da largura do carro. O que
## mudar de um modelo para outro vai para `CabineFicha`, como a casca ja faz.
##
## Espaco
## ------
## O mesmo da `CarroCabine`: -Z e a frente, +X a direita de quem dirige, e a
## origem no plano em que o pneu toca o chao.
class_name CabineInterior
extends Node3D

## A tomada de 12 V fica ONDE o carregador de `AoVolante` e plugado: o olho mais
## este deslocamento (x para o meio do carro), com a boca virada 25 graus para
## cima. E o mesmo numero de `AoVolante.ISQUEIRO`, copiado e nao referenciado:
## ler de la faria a cabine depender do celular, e a cabine monta em `--script`
## sem autoload. Se um mudar, o outro tem de mudar junto.
const TOMADA_DO_OLHO := Vector3(0.36, -0.50, -0.46)
const TOMADA_INCLINACAO := 25.0

# --- cores, em sRGB (o shader converte). O alfa e o acabamento. -------------
# Tons quentes e baixos: o interior e SILHUETA a noite (ver `CarroCabine`), e o
# que tem de brilhar e o mostrador, nao o plastico.

const COR_TOPO := Color(0.120, 0.112, 0.104, 1.0)
const COR_FACE := Color(0.205, 0.186, 0.166, 1.0)
const COR_BAIXO := Color(0.168, 0.155, 0.142, 1.0)
const COR_CENTRO := Color(0.118, 0.112, 0.106, 1.0)
const COR_PECA := Color(0.070, 0.068, 0.066, 0.85)
const COR_PECA_LISA := Color(0.055, 0.053, 0.052, 0.15)
const COR_TECLA := Color(0.120, 0.118, 0.115, 0.45)
const COR_CONSOLE := Color(0.160, 0.149, 0.137, 1.0)
const COR_COURO := Color(0.105, 0.080, 0.064, 0.9)
const COR_BORRACHA := Color(0.045, 0.044, 0.043, 1.0)
const COR_CROMO := Color(0.80, 0.80, 0.82, 0.10)
const COR_ALUMINIO := Color(0.62, 0.62, 0.64, 0.55)
const COR_LATAO := Color(0.78, 0.62, 0.32, 0.30)

## Quanto o ponteiro acende com o painel.
const PONTEIRO_COR := Color(1.0, 0.36, 0.08)

## As malhas em construcao, por material.
var malhas: Dictionary = {}
## Os materiais desta cabine.
var mats: Dictionary = {}
## As medidas de onde tudo sai (ver `CarroCabine._medidas_do_interior`).
var g: Dictionary = {}

## Pivos que se mexem. Ligados pelo nome depois que os nos nascem.
var ponteiros: Dictionary = {}
var alavanca: Node3D
var freio: Node3D

## As pecas prontas, por modelo: a segunda vez que o jogador entra num carro do
## mesmo modelo nao constroi nada, so sobe as malhas a partir dos arrays.
##
## Construir o interior custa ~100 ms de GDScript (Marea, medido em 24/09/2026),
## e o carro de cutscene e o do jogador montam o mesmo interior toda vez que
## nascem. As malhas nao dependem de nada da instancia (a luz do painel e os
## ponteiros moram no material e nos pivos), entao podem ser as mesmas.
##
## O cache guarda ARRAYS, e cada interior sobe o proprio `ArrayMesh`: o
## `Amassado` do carro do jogador deforma a malha no lugar, e uma malha
## compartilhada amassaria o painel de todo carro do mesmo modelo.
static var _prontos: Dictionary = {}

## Pronto: as pecas estao penduradas. Na construcao assincrona chega alguns
## quadros depois de `montar`; quem precisa das malhas (o amassado das portas)
## espera por ele.
signal montado
## Os pivos registrados na construcao: nome, lugar e as malhas de cada um.
var _pivos: Array = []
## Os forros de porta, construidos a parte. Ver `_construir`.
var _portas: Dictionary = {}
var _tarefa: int = -1
var _chave: String = ""
## Pecas do cache esperando o proximo quadro para nascer. Ver `montar`.
var _pendente: Dictionary = {}

const _NOMES_DOS_PONTEIROS := {
	"Velocidade": &"velocidade", "Giro": &"giro",
	"Combustivel": &"combustivel", "Temperatura": &"temperatura",
}

var _kmh: float = 0.0
var _rpm: float = 850.0
var _marcha: String = "N"
var _freio_puxado: bool = false
## Ninguem escreveu giro nem marcha ainda (o carro da cutscene so escreve a
## velocidade): o painel estima os dois pela velocidade, com um cambio de cinco
## marchas de mentira, para o conta-giros nao ficar parado em marcha lenta a
## 80 km/h e a alavanca nao ficar em ponto morto com o carro andando.
var _giro_do_carro: bool = false
var _alavanca_giro := Vector2.ZERO
var _freio_giro: float = 0.0
var _mat_ponteiro: StandardMaterial3D
var _visor_texto: String = ""
var _espias := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])


## Monta o interior inteiro. `medidas` vem de `CarroCabine`.
##
## `assincrono` constroi a geometria num `WorkerThreadPool` e pendura os nos
## quando ela fica pronta. E o que o carro do jogador usa: ele entra com a
## camera de fora, e os ~100 ms da primeira construcao viravam um tranco na
## hora de sentar. A cutscene e as bancadas pedem sincrono, porque fotografam
## o interior no quadro seguinte.
func montar(medidas: Dictionary, assincrono: bool = false) -> void:
	g = medidas
	mats = {
		&"plastico": CabineMateriais.plastico(),
		&"metal": CabineMateriais.metal(),
		&"impresso": CabineMateriais.impresso(),
		&"lente": CabineMateriais.lente(),
		&"visor": CabineMateriais.visor(),
		&"madeira": CabineMateriais.madeira(),
		&"tecido": CabineMateriais.tecido(),
	}
	_mat_ponteiro = StandardMaterial3D.new()
	_mat_ponteiro.albedo_color = PONTEIRO_COR
	_mat_ponteiro.roughness = 0.35
	_mat_ponteiro.emission_enabled = true
	_mat_ponteiro.emission = PONTEIRO_COR
	mats[&"ponteiro"] = _mat_ponteiro
	acender_painel(1.0)
	visor_relogio(12, 0)

	_chave = _chave_de(g)
	if _prontos.has(_chave):
		# Assincrono, ate o cache espera um quadro: o `Carro` le de volta, na
		# hora de assumir, toda malha que a cabine ja tiver, e ler o interior
		# inteiro da GPU seria o tranco que a thread veio evitar.
		if assincrono:
			_pendente = _prontos[_chave]
		else:
			_instanciar(_prontos[_chave])
		return
	if assincrono:
		_tarefa = WorkerThreadPool.add_task(_construir, false, "interior do carro")
		return
	_construir()
	_terminar()


## A geometria inteira, sem nenhum no: so `malhas`, `_portas` e `_pivos`. Pode
## rodar fora da thread principal.
func _construir() -> void:
	malhas = {}
	_pivos = []
	CabinePainel.montar(self)
	CabineConsole.montar(self)
	CabineBancos.montar(self)
	# Os forros de porta num grupo proprio: sao as unicas pecas encostadas na
	# lataria, e o amassado do carro precisa delas separadas (ver `portas`).
	var raiz := malhas
	malhas = {}
	CabinePortas.montar(self)
	_portas = malhas
	malhas = raiz


## Transforma o que `_construir` deixou em arrays, guarda no cache e pendura.
## Na thread principal.
func _terminar() -> void:
	var pronto := {"raiz": _para_arrays(malhas), "portas": _para_arrays(_portas),
		"pivos": []}
	for p: Dictionary in _pivos:
		(pronto["pivos"] as Array).append({"nome": p["nome"], "xf": p["xf"],
			"malhas": _para_arrays(p["malhas"])})
	malhas = {}
	_portas = {}
	_pivos = []
	_prontos[_chave] = pronto
	_instanciar(pronto)


static func _para_arrays(lista: Dictionary) -> Dictionary:
	var out := {}
	for chave: StringName in lista:
		var a := (lista[chave] as MalhaLisa).arrays()
		if not a.is_empty():
			out[chave] = a
	return out


func _instanciar(pronto: Dictionary) -> void:
	_pendurar(pronto["raiz"], self)
	var portas := Node3D.new()
	portas.name = "Portas"
	add_child(portas)
	_pendurar(pronto["portas"], portas)
	for p: Dictionary in pronto["pivos"]:
		var no := Node3D.new()
		no.name = String(p["nome"])
		no.transform = p["xf"]
		add_child(no)
		_pendurar(p["malhas"], no)
		if _NOMES_DOS_PONTEIROS.has(String(no.name)):
			ponteiros[_NOMES_DOS_PONTEIROS[String(no.name)]] = no
		elif no.name == &"Alavanca":
			alavanca = no
		elif no.name == &"FreioDeMao":
			freio = no
	_mover_ponteiros()
	_mover_alavancas(1.0)
	montado.emit()


func _pendurar(lista: Dictionary, pai: Node3D) -> void:
	for chave: StringName in lista:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, lista[chave])
		var mi := MeshInstance3D.new()
		mi.name = String(chave)
		mi.mesh = mesh
		mi.material_override = mats[chave]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mi)


## O que faz dois interiores iguais: o modelo e as medidas de onde tudo sai.
static func _chave_de(medidas: Dictionary) -> String:
	return "%s|%.3f|%.3f|%.3f|%.3f|%.3f" % [medidas.get("modelo", -1),
		medidas["piso"], medidas["topo"], medidas["lado"], medidas["z_frente"],
		medidas["z_tras"]]


## Ja tem pecas penduradas? Falso enquanto a construcao assincrona corre.
func pronto() -> bool:
	return _tarefa < 0 and _pendente.is_empty() and get_child_count() > 0


## As malhas dos forros de porta. O `Amassado` do carro reaplica nelas as
## batidas de antes: porta amassada por fora com forro liso por dentro era o
## defeito que a cabine antiga ja tinha resolvido.
func portas() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var no := get_node_or_null(^"Portas")
	if no == null:
		return out
	for f: Node in no.get_children():
		if f is MeshInstance3D:
			out.append(f as MeshInstance3D)
	return out


func _exit_tree() -> void:
	# Uma tarefa ainda correndo escreve em `malhas` desta instancia: espera ela
	# acabar antes de o no morrer.
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1


## A malha de um material, criada na primeira pergunta.
func m(material: StringName) -> MalhaLisa:
	if not malhas.has(material):
		malhas[material] = MalhaLisa.new()
	return malhas[material]


## Um pivo com as proprias malhas: `construir` usa `m` normalmente, e o que ele
## fizer vai para o pivo e nao para a raiz. E como o ponteiro, a alavanca e o
## freio ganham malha propria sem um segundo jeito de construir peca. O no nasce
## so em `_instanciar`: aqui e dado, para poder rodar fora da thread principal.
func pivo(nome: String, onde: Transform3D, construir: Callable) -> void:
	var antes := malhas
	malhas = {}
	construir.call()
	_pivos.append({"nome": nome, "xf": onde, "malhas": malhas})
	malhas = antes


# --- o que o carro escreve --------------------------------------------------

## A retroiluminacao: 0 apagada (dia, farol desligado), 1 acesa.
func acender_painel(t: float) -> void:
	var v := clampf(t, 0.0, 1.0)
	(mats[&"impresso"] as ShaderMaterial).set_shader_parameter(&"aceso", v)
	_mat_ponteiro.emission_energy_multiplier = lerpf(0.15, 1.6, v)
	(mats[&"visor"] as ShaderMaterial).set_shader_parameter(&"brilho", lerpf(0.7, 1.0, v))


func velocidade(kmh: float) -> void:
	_kmh = absf(kmh)


func giro(rpm: float) -> void:
	_giro_do_carro = true
	_rpm = maxf(0.0, rpm)


## "1".."5", "R" ou "N".
func marcha(rotulo: String) -> void:
	_giro_do_carro = true
	_marcha = rotulo


## Giro e marcha de mentira pela velocidade. Ver `_giro_do_carro`.
func _estimar_giro() -> void:
	const TROCAS := [0.0, 20.0, 38.0, 58.0, 82.0, 400.0]
	if _kmh < 2.0:
		_marcha = "N"
		_rpm = 850.0
		return
	for k in 5:
		if _kmh < TROCAS[k + 1] or k == 4:
			_marcha = str(k + 1)
			var t := clampf((_kmh - TROCAS[k]) / (TROCAS[k + 1] - TROCAS[k]), 0.0, 1.0)
			_rpm = lerpf(1500.0 if k > 0 else 900.0, 4200.0, t) if k < 4 				else 1800.0 + _kmh * 22.0
			return


func freio_de_mao(puxado: bool) -> void:
	_freio_puxado = puxado
	_espias[ImpressosCabine.Espia.FREIO] = 1.0 if puxado else 0.0


## `lado` -1, 0 ou 1; `acesa` e a metade acesa do ciclo.
func seta(lado: int, acesa: bool) -> void:
	_espias[ImpressosCabine.Espia.SETA_ESQ] = 1.0 if lado < 0 and acesa else 0.0
	_espias[ImpressosCabine.Espia.SETA_DIR] = 1.0 if lado > 0 and acesa else 0.0


func farol_alto(aceso: bool) -> void:
	_espias[ImpressosCabine.Espia.FAROL_ALTO] = 1.0 if aceso else 0.0


## Motor desligado com a chave virada: bateria e oleo acendem, como em todo
## carro.
func motor_ligado(ligado: bool) -> void:
	var v := 0.0 if ligado else 1.0
	_espias[ImpressosCabine.Espia.BATERIA] = v
	_espias[ImpressosCabine.Espia.OLEO] = v


## O visor do toca-fitas mostrando uma estacao ("FM 92,7", "AM 780").
func visor_estacao(dial: String) -> void:
	if dial == _visor_texto:
		return
	_visor_texto = dial
	var banda := dial.substr(0, 2)
	var num := dial.substr(3).replace(",", ".").strip_edges()
	var segs := PackedInt32Array([0, 0, 0, 0, 0])
	segs[0] = _segmentos(banda[0])
	var ponto := -1.0
	var digitos := num.replace(".", "")
	if num.contains("."):
		ponto = 3.0
	for k in digitos.length():
		var celula := 5 - digitos.length() + k
		if celula >= 1:
			segs[celula] = _segmentos(digitos[k])
	var mat := mats[&"visor"] as ShaderMaterial
	mat.set_shader_parameter(&"segs", segs)
	mat.set_shader_parameter(&"pontos", Vector2(ponto, 0.0))


## O visor com o radio desligado: o relogio, com os dois-pontos.
func visor_relogio(h: int, minuto: int) -> void:
	var texto := "%02d%02d" % [h, minuto]
	if texto == _visor_texto:
		return
	_visor_texto = texto
	var segs := PackedInt32Array([0, 0, 0, 0, 0])
	for k in 4:
		segs[k + 1] = _segmentos(texto[k])
	if texto[0] == "0":
		segs[1] = 0
	var mat := mats[&"visor"] as ShaderMaterial
	mat.set_shader_parameter(&"segs", segs)
	mat.set_shader_parameter(&"pontos", Vector2(-1.0, 1.0))


## A mascara de sete segmentos de um caractere (bit 0 = a, em cima, ate bit 6
## = g, no meio). O que o visor nao sabe escrever sai apagado.
static func _segmentos(ch: String) -> int:
	const MAPA := {"0": 0x3F, "1": 0x06, "2": 0x5B, "3": 0x4F, "4": 0x66,
		"5": 0x6D, "6": 0x7D, "7": 0x07, "8": 0x7F, "9": 0x6F, "F": 0x71,
		"A": 0x77, "-": 0x40, "P": 0x73, "C": 0x39, "E": 0x79}
	return int(MAPA.get(ch.to_upper(), 0))


func _process(delta: float) -> void:
	if not _pendente.is_empty():
		var p := _pendente
		_pendente = {}
		_instanciar(p)
	if _tarefa >= 0:
		if not WorkerThreadPool.is_task_completed(_tarefa):
			return
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
		_terminar()
	if not _giro_do_carro:
		_estimar_giro()
	_mover_ponteiros(delta)
	_mover_alavancas(delta)
	(mats[&"impresso"] as ShaderMaterial).set_shader_parameter(&"espias", _espias)


## Os ponteiros nao pulam: tem a inercia de um mostrador mecanico, que e a
## mola e o oleo do galvanometro. O de combustivel e temperatura quase nao anda.
func _mover_ponteiros(delta: float = 1.0) -> void:
	var alvos := {
		&"velocidade": ImpressosCabine.angulo_velocidade(_kmh),
		&"giro": ImpressosCabine.angulo_giro(_rpm),
		&"combustivel": ImpressosCabine.angulo_pequeno(0.62),
		&"temperatura": ImpressosCabine.angulo_pequeno(0.46 if _rpm > 0.0 else 0.0),
	}
	for nome: StringName in alvos:
		var p: Node3D = ponteiros.get(nome)
		if p == null:
			continue
		p.rotation.z = lerp_angle(p.rotation.z, float(alvos[nome]),
			1.0 - exp(-9.0 * delta))


func _mover_alavancas(delta: float) -> void:
	if alavanca != null:
		var alvo := CabineConsole.posicao_da_marcha(_marcha)
		_alavanca_giro = _alavanca_giro.lerp(alvo, 1.0 - exp(-14.0 * delta))
		alavanca.basis = CabineConsole.base_da_alavanca(_alavanca_giro)
	if freio != null:
		var a := CabineConsole.FREIO_PUXADO if _freio_puxado else CabineConsole.FREIO_SOLTO
		_freio_giro = lerpf(_freio_giro, a, 1.0 - exp(-12.0 * delta))
		freio.rotation.x = deg_to_rad(_freio_giro)


# --- conta comum ------------------------------------------------------------

## Uma base com o +Z olhando para `frente` e o +Y o mais perto de `cima`.
static func base_olhando(frente: Vector3, cima: Vector3 = Vector3.UP) -> Basis:
	var z := frente.normalized()
	var x := cima.cross(z)
	if x.length_squared() < 1e-8:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


## A parede da casca em x, para uma peca que ocupa de `y0` a `y1` em `z`: a mais
## estreita das duas alturas, porque a secao do carro afina para baixo.
func parede(y0: float, y1: float, z: float) -> float:
	var info: Dictionary = g["info"]
	return minf(absf(CabineCasca.parede_x(info, y0, z, 1.0)),
		absf(CabineCasca.parede_x(info, y1, z, 1.0)))


## Quanto um ponto passa da lataria, em metros (negativo = dentro). A mesma
## conta de `checar_cabine_contida`: a largura do casco naquela altura e z, e o
## teto e o fundo da secao. Serve para a peca que pode nao caber — o encosto do
## banco de tras sob o vidro traseiro de um fastback — perguntar antes.
func sobra(p: Vector3) -> float:
	var info: Dictionary = g["info"]
	var perfil: Array = info["perfil"]
	var ombro: Vector2 = info["ombro"]
	var escala: Vector3 = info["escala"]
	var q := Vector3(-p.x / escala.x, p.y / escala.y, -p.z / escala.z)
	var meia := CarroceriaVarrida.x_casco_fino(perfil, ombro, q.z, q.y)
	var e := CarroceriaVarrida.estacao(perfil, q.z)
	var por_cima: float = q.y - e[CarroceriaVarrida.TOPO]
	var por_baixo: float = e[CarroceriaVarrida.BOT] - q.y
	return maxf(absf(q.x) - meia, maxf(por_cima, por_baixo)) * escala.x


## Onde fica a tomada de 12 V, e para onde a boca dela olha.
func tomada() -> Transform3D:
	var olho: Vector3 = g["olho"]
	var lado: float = g["lado"]
	var dentro := -signf(lado) if absf(lado) > 0.01 else 1.0
	var p := olho + Vector3(TOMADA_DO_OLHO.x * dentro, TOMADA_DO_OLHO.y,
		TOMADA_DO_OLHO.z)
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-TOMADA_INCLINACAO)), p)
