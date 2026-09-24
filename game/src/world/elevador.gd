## O elevador de carga da estufa: cabine de barra, talha de corrente e uma
## botoeira de dez andares.
##
## E o unico jeito de descer o poco, e a viagem e o ponto: as galerias passando
## pela grade, a placa de cada andar pendurada na frente e a planta de cada um
## aparecendo na janela da cabine. Teleporte entregaria o andar e roubaria o
## predio.
##
## A cabine e um AnimatableBody3D, e o jogador vai em pe no piso dela como iria
## numa plataforma qualquer: o CharacterBody3D herda a velocidade do chao. Ele
## vai travado so para nao andar — a camera continua livre, porque olhar em
## volta e o que se faz num elevador de obra.
##
## Para em todo andar. Cada andar do meio cultiva uma variedade (Variedades), e
## Jota e Helmer descem nele para regar e colher: chamam do patamar, esperam a
## grade abrir, entram, apertam o andar e saem do outro lado. A cabine atende uma
## fila de chamadas, na ordem em que chegaram, e segura a grade aberta para quem
## esta entrando ou saindo (`segurar`). Quem vai dentro vai junto: se o Jota
## chamou do 6 com o jogador parado na cabine, o jogador desce ao 6 com ele.
class_name Elevador
extends Node3D

const MATERIAL := "res://resources/materials/mat_estufa.tres"
const MATERIAL_LUZ := "res://resources/materials/mat_estufa_luz.tres"
const MATERIAL_QUADROS := "res://resources/materials/mat_estufa_quadros.tres"

## A cabine, em planta e em altura. Cabe no vao de 2 x 2 do andaime com 15 cm
## de folga de cada lado: menos que isso, a barra raspa no montante a cada
## andar que passa.
const LADO := 1.7
const ALTO := 2.3
## Metros por segundo no meio da viagem. Talha de obra: devagar o bastante para
## ler a placa de cada andar, rapido o bastante para nao virar cutscene.
const VELOCIDADE := 2.4
## Barras por parede. Doze dao 14 cm de vao, que e grade e nao janela.
const BARRAS := 12
## Tinta de maquina de obra. Vai sobre a celula de lona, que e branca: sobre a
## mangueira, que e preta, qualquer tinta sai preta.
const AMARELO := Color(0.90, 0.70, 0.12)
## Quanto a grade fica aberta em cada parada antes de atender a proxima chamada.
const PARADA := 3.0
## Quem segura a grade (entrando ou saindo) segura no maximo isto.
const SEGURAR_MAX := 6.0

const ANDARES: PackedStringArray = [
	"LAVOURA", "SECAGEM", "MUDA", "MUDA TAMBEM", "MUDA AINDA",
	"NAO DESCER", "NAO DESCER (SERIO)", "O ANDAR DO CHEIRO", "???",
	"SO O JOTA E O HELMER",
]

## Onde o piso da cabine para no andar 10, em coordenada do comodo. O 10 e o
## FUNDO do poco: o numero e negativo, e a cabine desce ate ele.
@export var topo: float = -29.25
## Onde a corrente termina, na polia da talha, no nicho acima da lavoura.
@export var polia: float = 2.88

## Na hora em que a cabine sai do lugar, com a grade ja fechada. Quem esta no
## andar de destino tem a viagem inteira para se arrumar. `com_jogador` diz se o
## jogador vai dentro: o SuperQuarto so encena para quem viaja.
signal partiu(para: int, com_jogador: bool)
signal chegou(andar: int, com_jogador: bool)

var _cabine: AnimatableBody3D
var _porta: CollisionShape3D
var _barras_porta: Array[Node3D] = []
var _corrente: MeshInstance3D
var _motor: AudioStreamPlayer3D
var _chapa: Interativo
var _luz_recusa: MeshInstance3D
## Os dez botoes da cabine, do 1 ao 10.
var _botoes: Array[Interativo] = []
## O botao de chamar de cada patamar, do 1 ao 10.
var _chamadas: Array[Interativo] = []
## andar -> [barra, corpo]: a cancela da boca do vao em cada andar em que ela e
## um buraco (1 a 9). So abre com a cabine parada ali.
var _cancelas: Dictionary = {}
## andar -> as luzes da galeria: a do meio do poco e uma sobre cada rack. So as
## de perto do jogador acendem.
var _luzes: Dictionary = {}

var _andar := 1
var _andando := false
var _aberta := true
var _servindo := false
var _fila: Array[int] = []
## quem -> ate quando (msec) segura a grade aberta.
var _segurando: Dictionary = {}
var _passageiros: Array[Node3D] = []

## Os andares interditados dao sinal de vida quando a cabine passa: batidas na
## porta do 7 e dois olhos no escuro do 9, que fecham quando a cabine chega na
## altura deles. O cenario parado (nevoa do 8, a porta) e do EstufaBuilder.
var _olhos: MeshInstance3D
var _olho_antes := INF
var _relogio_luz := 0.0


func _ready() -> void:
	add_to_group(&"elevador")
	_cabine = AnimatableBody3D.new()
	_cabine.name = "Cabine"
	_cabine.sync_to_physics = true
	add_child(_cabine)
	_montar_cabine()
	_montar_colisao()
	_montar_porta()
	_montar_botoeira()
	_montar_corrente()
	_montar_olhos()
	_montar_patamares()
	_motor = AudioStreamPlayer3D.new()
	_motor.name = "Talha"
	_motor.stream = AudioDirector.em_loop(&"catraca_loop")
	_motor.pitch_scale = 0.62
	_motor.volume_db = -9.0
	_motor.bus = &"SFX"
	_motor.position = Vector3(0.0, ALTO + 0.3, 0.0)
	_cabine.add_child(_motor)
	_abrir_cancelas()
	_atualizar_rotulos()


func _process(delta: float) -> void:
	# A corrente vai do gancho no teto da cabine ate a polia, e encurta enquanto
	# sobe. E uma malha de um metro esticada: corrente escura a vinte metros nao
	# mostra elo nenhum.
	var base := _cabine.position.y + ALTO + 0.22
	_corrente.position = Vector3(0.0, base, 0.0)
	_corrente.scale = Vector3(1.0, maxf(0.05, polia - base), 1.0)
	_relogio_luz -= delta
	if _relogio_luz <= 0.0:
		_relogio_luz = 0.25
		_luzes_de_perto()


func _physics_process(_delta: float) -> void:
	if not _andando:
		return
	var olho := _cabine.position.y + 1.62
	if _olho_antes != INF:
		var bate := EstufaBuilder.nivel(7) + 1.3
		if (_olho_antes - bate) * (olho - bate) < 0.0:
			_bater_na_porta()
		if _olhos.visible and absf(olho - _olhos.position.y) < 1.1:
			_olhos.visible = false
	_olho_antes = olho


func _bater_na_porta() -> void:
	var porta := to_global(Vector3(0.0, EstufaBuilder.nivel(7) + 1.2,
		EstufaBuilder.FUNDO - EstufaBuilder.ELEVADOR.z - 0.1))
	for k in 3:
		AudioDirector.tocar(StringName("passo_madeira_%d" % (k + 1)), porta, 3.0, 0.7)
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(0.6).timeout
	AudioDirector.tocar(&"porta_trinco", porta, 0.0, 0.85)


## A galeria so acende perto de quem olha: o andar do jogador e os vizinhos.
## Oito fontes acesas o tempo todo estourariam o orcamento do ART-BIBLE, e uma
## galeria a dez metros abaixo so aparece pela calha acesa, que e emissao.
##
## Os olhos do 9 fecham quando o jogador chega perto: ninguem ve de quem sao.
func _luzes_de_perto() -> void:
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	if jogador == null:
		return
	var y := to_local(jogador.global_position).y
	for andar: int in _luzes:
		var dy := absf(y - y_do_andar(andar))
		var luzes: Array = _luzes[andar]
		# No andar de quem olha, as tres; no vizinho, so a do meio, que e a que
		# se ve pela grade e pelo vao.
		for k in luzes.size():
			(luzes[k] as OmniLight3D).visible = dy < 4.2 if k == 0 else dy < 1.5
	if not _andando:
		var perto := jogador.global_position.distance_to(_olhos.global_position) < 5.0
		_olhos.visible = not perto


# --- montagem -----------------------------------------------------------------

func _montar_cabine() -> void:
	var sup: Dictionary = {}
	var h := LADO * 0.5
	# O piso de chapa, rente ao chao do andar quando parada.
	AtlasKit.caixa(sup, &"e", Vector3(0.0, -0.05, 0.0), Vector3(LADO, 0.1, LADO),
		EstufaBuilder.C_PISO, Color(0.58, 0.58, 0.56))
	# Os quatro montantes e o quadro de cima.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			AtlasKit.caixa(sup, &"e", Vector3(sx * (h - 0.035), ALTO * 0.5,
				sz * (h - 0.035)), Vector3(0.07, ALTO, 0.07),
				EstufaBuilder.C_LONA, AMARELO)
	for s: float in [-1.0, 1.0]:
		AtlasKit.caixa(sup, &"e", Vector3(0.0, ALTO, s * (h - 0.035)),
			Vector3(LADO, 0.08, 0.07), EstufaBuilder.C_LONA, AMARELO)
		AtlasKit.caixa(sup, &"e", Vector3(s * (h - 0.035), ALTO, 0.0),
			Vector3(0.07, 0.08, LADO), EstufaBuilder.C_LONA, AMARELO)
	# O teto de chapa e o olhal da corrente.
	AtlasKit.caixa(sup, &"e", Vector3(0.0, ALTO + 0.055, 0.0),
		Vector3(LADO, 0.03, LADO), EstufaBuilder.C_REFLETOR, Color(0.5, 0.5, 0.5))
	AtlasKit.caixa(sup, &"e", Vector3(0.0, ALTO + 0.15, 0.0),
		Vector3(0.12, 0.18, 0.12), EstufaBuilder.C_LONA, AMARELO)
	# Tres paredes de barra, com rodape e travessa no meio. A quarta e a porta.
	var paredes: Array = [
		[Vector3(-h, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)],
		[Vector3(h, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)],
		[Vector3(0.0, 0.0, h), Vector3(1.0, 0.0, 0.0)],
	]
	for p: Array in paredes:
		var centro: Vector3 = p[0]
		var eixo: Vector3 = p[1]
		var dentro_da := centro - centro.normalized() * 0.02
		for k in BARRAS:
			var em := dentro_da + eixo * lerpf(-h + 0.1, h - 0.1,
				float(k) / float(BARRAS - 1))
			AtlasKit.tubo(sup, &"e", em + Vector3(0.0, 0.2, 0.0),
				em + Vector3(0.0, ALTO - 0.04, 0.0), 0.012,
				EstufaBuilder.C_LONA, AMARELO)
		var comp := Vector3(absf(eixo.x) * LADO + 0.04, 0.0,
			absf(eixo.z) * LADO + 0.04)
		AtlasKit.caixa(sup, &"e", dentro_da + Vector3(0.0, 0.1, 0.0),
			comp + Vector3(0.0, 0.2, 0.0) + (Vector3.ONE - eixo.abs()) * 0.02,
			EstufaBuilder.C_REFLETOR, Color(0.5, 0.5, 0.48))
		AtlasKit.caixa(sup, &"e", dentro_da + Vector3(0.0, 1.05, 0.0),
			comp + Vector3(0.0, 0.05, 0.0) + (Vector3.ONE - eixo.abs()) * 0.03,
			EstufaBuilder.C_LONA, AMARELO)
	# O trilho da porta, em cima e embaixo.
	for y: float in [0.03, ALTO - 0.1]:
		AtlasKit.tubo(sup, &"e", Vector3(-h, y, -h), Vector3(h, y, -h), 0.02,
			EstufaBuilder.C_LONA, AMARELO)
	_instanciar(_cabine, sup)


func _montar_colisao() -> void:
	var h := LADO * 0.5
	for c: Array in [
			[Vector3(LADO, 0.1, LADO), Vector3(0.0, -0.05, 0.0)],
			[Vector3(0.06, ALTO, LADO), Vector3(-h, ALTO * 0.5, 0.0)],
			[Vector3(0.06, ALTO, LADO), Vector3(h, ALTO * 0.5, 0.0)],
			[Vector3(LADO, ALTO, 0.06), Vector3(0.0, ALTO * 0.5, h)]]:
		_cabine.add_child(_forma(c[0], c[1]))
	# A porta so e solida com a cabine andando. Parada, a grade esta recolhida
	# num canto e o vao e livre.
	_porta = _forma(Vector3(LADO, ALTO, 0.06), Vector3(0.0, ALTO * 0.5, -h))
	_porta.disabled = true
	_cabine.add_child(_porta)


## A porta pantografica: barras que correm para o canto oeste quando abre.
func _montar_porta() -> void:
	var sup: Dictionary = {}
	AtlasKit.tubo(sup, &"e", Vector3(0.0, 0.08, 0.0),
		Vector3(0.0, ALTO - 0.14, 0.0), 0.014, EstufaBuilder.C_LONA,
		Color(0.42, 0.42, 0.40))
	var malha := PSXMesh.dados_para_mesh(sup[&"e"])
	var mat := load(MATERIAL) as Material
	for k in BARRAS:
		var barra := MeshInstance3D.new()
		barra.mesh = malha
		barra.material_override = mat
		barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		barra.position = Vector3(_x_da_barra(k, true), 0.0, -LADO * 0.5 - 0.02)
		_cabine.add_child(barra)
		_barras_porta.append(barra)


func _x_da_barra(k: int, aberta: bool) -> float:
	var h := LADO * 0.5
	if aberta:
		return -h + 0.06 + float(k) * 0.028
	return lerpf(-h + 0.06, h - 0.06, float(k) / float(BARRAS - 1))


## A botoeira de dez botoes e a chapa com a lista, na parede leste por dentro.
##
## Dez botoes em duas colunas, cada um do tamanho de um polegar a um palmo do
## olho: a 480 x 270 isso e alvo de quarenta pixels, que se acerta sem mirar.
## O nome do andar vem no prompt; a chapa ao lado e a lista pintada.
func _montar_botoeira() -> void:
	var sup: Dictionary = {}
	var h := LADO * 0.5
	var caixa := Vector3(h - 0.07, 1.25, -0.36)
	# Girada para a frente olhar para dentro (-X): o x da caixa vira o z do mundo.
	AtlasKit.caixa(sup, &"e", caixa, Vector3(0.28, 0.62, 0.08),
		EstufaBuilder.C_LONA, AMARELO, -PI * 0.5, EstufaBuilder.C_PAINEL)
	for n in range(1, 11):
		var em := _lugar_do_botao(n)
		# O 10 e vermelho: e o fundo, e so de dois.
		var cor := Color(0.85, 0.18, 0.14) if n == 10 else Color(0.2, 0.75, 0.25)
		AtlasKit.caixa(sup, &"e", em, Vector3(0.03, 0.06, 0.07),
			EstufaBuilder.C_MANGUEIRA, cor)
	# O conduite do cabo de comando, subindo ate o teto da cabine.
	AtlasKit.tubo(sup, &"e", caixa + Vector3(0.0, 0.31, 0.0),
		Vector3(caixa.x, ALTO, caixa.z), 0.018, EstufaBuilder.C_MANGUEIRA,
		Color(0.25, 0.25, 0.25))
	var chapa := Vector3(h - 0.05, 1.32, 0.3)
	EstufaBuilder.placa_atlas(sup, &"q", chapa, Vector2(0.4, 0.3), -PI * 0.5,
		EstufaBuilder.RECT_CHAPA)
	_instanciar(_cabine, sup)

	# A luzinha que acende quando o botao e apertado.
	var luz: Dictionary = {}
	AtlasKit.face(luz, &"luz", Vector2(0.04, 0.04),
		Transform3D(Basis(Vector3.UP, -PI * 0.5), caixa + Vector3(-0.042, 0.35, 0.0)),
		EstufaBuilder.C_LENTE, Color(1.0, 0.35, 0.2))
	_luz_recusa = MeshInstance3D.new()
	_luz_recusa.mesh = PSXMesh.dados_para_mesh(luz[&"luz"])
	_luz_recusa.material_override = load(MATERIAL_LUZ) as Material
	_luz_recusa.visible = false
	_cabine.add_child(_luz_recusa)

	for n in range(1, 11):
		var b := _interativo(_lugar_do_botao(n) + Vector3(-0.03, 0.0, 0.0),
			Vector3(0.1, 0.1, 0.11))
		b.name = "Botao%d" % n
		var andar := n
		b.acionado.connect(func(quem: Node) -> void: _ao_botao(andar, quem))
		_botoes.append(b)
	_chapa = _interativo(chapa + Vector3(-0.03, 0.0, 0.0), Vector3(0.1, 0.34, 0.44))
	_chapa.name = "Chapa"
	_chapa.rotulo = "Ler a lista"
	_chapa.acionado.connect(_ao_chapa)


## Onde fica o botao do andar `n` na cabine: 1 a 5 na coluna da frente, de cima
## para baixo, e 6 a 10 na de tras.
func _lugar_do_botao(n: int) -> Vector3:
	var h := LADO * 0.5
	var coluna := 0 if n <= 5 else 1
	var linha := (n - 1) % 5
	return Vector3(h - 0.105, 1.47 - float(linha) * 0.11, -0.43 + float(coluna) * 0.14)


## Dois pontos acesos no fundo da galeria do 9, olhando para o vao.
func _montar_olhos() -> void:
	var sup: Dictionary = {}
	for s: float in [-1.0, 1.0]:
		AtlasKit.face(sup, &"luz", Vector2(0.07, 0.035),
			Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0.0, 0.0, s * 0.055)),
			EstufaBuilder.C_LENTE, Color(0.72, 1.0, 0.28))
	_olhos = MeshInstance3D.new()
	_olhos.name = "Olhos"
	_olhos.mesh = PSXMesh.dados_para_mesh(sup[&"luz"])
	_olhos.material_override = load(MATERIAL_LUZ) as Material
	_olhos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# No canto nordeste do 9, atras do caixote: longe o bastante do vao para nao
	# dar para ver de quem sao, e o andar agora se pisa — chegando perto, fecham.
	_olhos.position = Vector3(5.3, EstufaBuilder.nivel(9) + 1.42, 1.6)
	add_child(_olhos)


## O que cada andar tem na boca do vao: a cancela (onde a boca da para um
## buraco, do 1 ao 9), o botao de chamar e a luz da galeria (2 a 9; o 9 e o
## apagado, e fica com a luz fraca e ciano da Vagalume, que brilha no escuro).
func _montar_patamares() -> void:
	var mat := load(MATERIAL) as Material
	for andar in range(1, 11):
		var y := y_do_andar(andar)
		if andar < 10:
			var sup: Dictionary = {}
			for alto: float in [0.5, 1.0]:
				AtlasKit.tubo(sup, &"e", Vector3(-1.0, y + alto, -1.02),
					Vector3(1.0, y + alto, -1.02), 0.05, EstufaBuilder.C_LONA, AMARELO)
			var barra := MeshInstance3D.new()
			barra.name = "Cancela%d" % andar
			barra.mesh = PSXMesh.dados_para_mesh(sup[&"e"])
			barra.material_override = mat
			barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(barra)
			var corpo := StaticBody3D.new()
			corpo.name = "CancelaColisao%d" % andar
			corpo.add_child(_forma(Vector3(2.0, 1.2, 0.08), Vector3(0.0, y + 0.6, -1.02)))
			add_child(corpo)
			_cancelas[andar] = [barra, corpo]
		# A caixa de chamar, no montante oeste do vao, virada para o patamar.
		var caixa := Vector3(-1.13, y + 1.15, -1.07)
		var cs: Dictionary = {}
		AtlasKit.caixa(cs, &"e", caixa, Vector3(0.12, 0.18, 0.06),
			EstufaBuilder.C_LONA, AMARELO, 0.0, EstufaBuilder.C_PAINEL)
		AtlasKit.caixa(cs, &"e", caixa + Vector3(0.0, 0.02, -0.035),
			Vector3(0.05, 0.05, 0.02), EstufaBuilder.C_MANGUEIRA, Color(0.2, 0.75, 0.25))
		_instanciar(self, cs)
		var chama := Interativo.new()
		chama.name = "Chamar%d" % andar
		chama.position = caixa + Vector3(0.0, 0.0, -0.05)
		chama.add_child(_forma(Vector3(0.22, 0.26, 0.14), Vector3.ZERO))
		var a := andar
		chama.acionado.connect(func(_quem: Node) -> void: _ao_chamar(a))
		add_child(chama)
		_chamadas.append(chama)
		if andar >= 2 and andar < 10:
			var luz := OmniLight3D.new()
			luz.name = "LuzDaGaleria%d" % andar
			# No meio do poco, a um palmo do forro: acende as duas galerias de
			# uma vez pelo vazio.
			luz.position = Vector3(0.0, y + 2.25, -7.0)
			luz.omni_range = 9.5
			luz.omni_attenuation = 1.2
			luz.shadow_enabled = false
			if andar == 9:
				# O 9 e o apagado: o que o acende e a Vagalume, ciano e fraco.
				luz.light_color = Color(0.36, 0.92, 0.86)
				luz.light_energy = 0.4
			else:
				luz.light_color = Color("fff0cd")
				luz.light_energy = 1.25
			luz.visible = false
			add_child(luz)
			var luzes: Array = [luz]
			# Uma sobre cada rack, embaixo das barras: sao elas que acendem a
			# planta; a do meio acende o corredor e a passarela.
			for xr: float in [1.35, EstufaBuilder.LARGURA - 1.35]:
				var r := OmniLight3D.new()
				r.name = "LuzDoRack%d" % andar
				r.position = Vector3(xr - EstufaBuilder.ELEVADOR.x, y + 1.95,
					8.5 - EstufaBuilder.ELEVADOR.z)
				r.omni_range = 6.5
				r.omni_attenuation = 1.1
				r.shadow_enabled = false
				r.light_color = luz.light_color
				r.light_energy = luz.light_energy * 1.1
				r.visible = false
				add_child(r)
				luzes.append(r)
			_luzes[andar] = luzes


func _montar_corrente() -> void:
	var sup: Dictionary = {}
	AtlasKit.tubo(sup, &"e", Vector3.ZERO, Vector3(0.0, 1.0, 0.0), 0.025,
		EstufaBuilder.C_MANGUEIRA, Color(0.2, 0.2, 0.2))
	_corrente = MeshInstance3D.new()
	_corrente.name = "Corrente"
	_corrente.mesh = PSXMesh.dados_para_mesh(sup[&"e"])
	_corrente.material_override = load(MATERIAL) as Material
	_corrente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_corrente)


func _instanciar(pai: Node3D, sup: Dictionary) -> void:
	var caminhos := {&"e": MATERIAL, &"luz": MATERIAL_LUZ, &"q": MATERIAL_QUADROS}
	for chave: StringName in sup:
		var mi := MeshInstance3D.new()
		mi.mesh = PSXMesh.dados_para_mesh(sup[chave])
		mi.material_override = load(caminhos[chave]) as Material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mi)


func _forma(tam: Vector3, pos: Vector3) -> CollisionShape3D:
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	f.shape = b
	f.position = pos
	return f


func _interativo(pos: Vector3, tam: Vector3) -> Interativo:
	var a := Interativo.new()
	a.position = pos
	a.add_child(_forma(tam, Vector3.ZERO))
	_cabine.add_child(a)
	return a


# --- leitura ------------------------------------------------------------------

## A altura do piso do andar `n`, em coordenada deste no (a mesma do comodo:
## o elevador fica no y zero da estufa).
func y_do_andar(n: int) -> float:
	if n >= 10:
		return topo
	return EstufaBuilder.nivel(n)


## O andar em que a cabine esta, ou o ultimo em que parou.
func andar() -> int:
	return _andar


## Parada no andar `n` com a grade aberta: da para entrar e sair.
func parada_em(n: int) -> bool:
	return not _andando and _aberta and _andar == n


## Se o jogador (ou qualquer um) esta em pe dentro da cabine. O botao se alcanca
## do vao da porta, e sem esta conta a cabine partia com quem so esticou o braco.
func dentro(quem: Node3D) -> bool:
	var local := _cabine.to_local(quem.global_position)
	return absf(local.x) < LADO * 0.5 and absf(local.z) < LADO * 0.5 \
		and local.y > -0.4 and local.y < 1.2


func no_topo() -> bool:
	return _andar == 10 and not _andando


func andando() -> bool:
	return _andando


func cabine() -> AnimatableBody3D:
	return _cabine


## O botao que leva a outra ponta: ao 10 de qualquer andar, e do 10 a lavoura.
## E o botao da viagem de sempre, e o que as capturas apertam.
func botao() -> Interativo:
	return _botoes[0] if _andar == 10 else _botoes[9]


func botao_do_andar(n: int) -> Interativo:
	return _botoes[clampi(n, 1, 10) - 1]


func chamada(n: int) -> Interativo:
	return _chamadas[clampi(n, 1, 10) - 1]


func chapa() -> Interativo:
	return _chapa


# --- quem usa: jogador e fazendeiro -------------------------------------------

## Pede a cabine no andar `n` (do patamar) ou leva a cabine ao andar `n` (de
## dentro). Para a talha e a mesma coisa: mais uma parada na fila.
func chamar(n: int) -> void:
	n = clampi(n, 1, 10)
	if parada_em(n):
		return
	if not _andando and _andar == n and not _aberta:
		return
	if not _fila.has(n):
		_fila.append(n)
	_servir()


## Segura a grade aberta enquanto `quem` entra ou sai. Solta sozinho.
func segurar(quem: Object, segundos: float = 4.0) -> void:
	_segurando[quem] = Time.get_ticks_msec() + int(minf(segundos, SEGURAR_MAX) * 1000.0)


func soltar(quem: Object) -> void:
	_segurando.erase(quem)


## Quem vai dentro sem ser o jogador: o fazendeiro se registra para a cabine
## saber que leva alguem, e o Convidado segue o piso dela (ver `a_bordo_de`).
func embarcar(quem: Node3D) -> void:
	if not _passageiros.has(quem):
		_passageiros.append(quem)


func desembarcar(quem: Node3D) -> void:
	_passageiros.erase(quem)


func a_bordo(quem: Node3D) -> bool:
	return _passageiros.has(quem)


# --- viagem -------------------------------------------------------------------

func _atualizar_rotulos() -> void:
	for n in range(1, 11):
		var b := _botoes[n - 1]
		var nome := ANDARES[n - 1]
		var v := Variedades.do_andar(n)
		if n >= 2 and n <= 9:
			nome += " · " + Variedades.nome(v)
		b.rotulo = ("%d  %s" % [n, nome]) if n != _andar or _andando \
			else "%d  %s (aqui)" % [n, nome]
		b.habilitado = not _andando
	for n in range(1, 11):
		var c := _chamadas[n - 1]
		if parada_em(n):
			c.rotulo = "O elevador esta aqui"
		elif _fila.has(n):
			c.rotulo = "Ja chamou (vem vindo)"
		else:
			c.rotulo = "Chamar o elevador"


func _ao_botao(n: int, quem: Node) -> void:
	var jogador := quem as Node3D
	if _andando or jogador == null:
		return
	if not dentro(jogador):
		Cinema.fala("Entra na cabine primeiro.")
		return
	AudioDirector.tocar(&"clique", _botoes[n - 1].global_position, -6.0)
	_piscar()
	if n == _andar:
		return
	chamar(n)


func _ao_chamar(n: int) -> void:
	AudioDirector.tocar(&"clique", _chamadas[n - 1].global_position, -6.0)
	chamar(n)
	_atualizar_rotulos()


## A lista inteira, pela boca do elevador: andar, placa e o que cresce la.
func _ao_chapa(_quem: Node) -> void:
	var linhas := PackedStringArray()
	for n in range(1, 11):
		var extra := ""
		if n >= 2 and n <= 9:
			extra = " - " + Variedades.nome(Variedades.do_andar(n))
		linhas.append("%d  %s%s" % [n, ANDARES[n - 1], extra])
	Cinema.fala("\n".join(linhas))


func _piscar() -> void:
	_luz_recusa.visible = true
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		if is_instance_valid(_luz_recusa):
			_luz_recusa.visible = false)


## Atende a fila: uma parada de cada vez, na ordem das chamadas, com a grade
## aberta pelo menos PARADA segundos em cada uma.
func _servir() -> void:
	if _servindo:
		return
	_servindo = true
	_atualizar_rotulos()
	while not _fila.is_empty():
		await _esperar_quem_entra()
		if _fila.is_empty():
			break
		var alvo: int = _fila.pop_front()
		if alvo == _andar:
			if not _aberta:
				await _grade(true)
			continue
		await _viajar(alvo)
		await get_tree().create_timer(PARADA).timeout
	_servindo = false
	_atualizar_rotulos()


func _esperar_quem_entra() -> void:
	while true:
		var agora := Time.get_ticks_msec()
		var alguem := false
		for quem: Variant in _segurando.keys():
			if not is_instance_valid(quem) or int(_segurando[quem]) < agora:
				_segurando.erase(quem)
			else:
				alguem = true
		if not alguem:
			return
		await get_tree().create_timer(0.2).timeout


func _viajar(alvo: int) -> void:
	_andando = true
	_atualizar_rotulos()
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var com_jogador := jogador != null and dentro(jogador)
	if com_jogador:
		jogador.call("travar", true)
		# A grade fecha no lugar em que ela corre, e quem estiver em pe no vao
		# seria empurrado por uma colisao que nasce por dentro dele.
		var local := _cabine.to_local(jogador.global_position)
		if local.z < -0.45:
			local.z = -0.45
			jogador.global_position = _cabine.to_global(local)
	_fechar_todas()
	await _grade(false)
	_porta.set_deferred(&"disabled", false)
	_olho_antes = INF
	_motor.play()
	partiu.emit(alvo, com_jogador)
	var y := y_do_andar(alvo)
	var tempo := absf(y - _cabine.position.y) / VELOCIDADE + 1.2
	var t := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# O tranco de talha velha antes de pegar: cinco centimetros para o lado
	# errado. E o que diz "isto e uma corrente segurando voce".
	t.tween_property(_cabine, ^"position:y",
		_cabine.position.y - signf(y - _cabine.position.y) * 0.05, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_cabine, ^"position:y", y, tempo) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	_motor.stop()
	AudioDirector.tocar(&"porta_trava", _cabine.global_position + Vector3(0.0, 1.0, 0.0), -4.0)
	_andar = alvo
	_porta.set_deferred(&"disabled", true)
	_andando = false
	# Os botoes voltam junto com a parada, e nao depois da grade: nos 0,7 s da
	# grade abrindo quem apertava um andar era ignorado sem aviso.
	_atualizar_rotulos()
	await _grade(true)
	# Depois de `_andando` cair: com ele de pe, toda cancela conta como fechada,
	# e a do andar de chegada ficava fechada na cara de quem ia entrar.
	_abrir_cancelas()
	if com_jogador and is_instance_valid(jogador):
		jogador.call("travar", false)
	_atualizar_rotulos()
	if com_jogador:
		var extra := ""
		if alvo >= 2 and alvo <= 9:
			extra = "\n" + Variedades.nome(Variedades.do_andar(alvo))
		Cinema.fala("%d  %s%s" % [alvo, ANDARES[alvo - 1], extra])
	chegou.emit(alvo, com_jogador)


## So a cancela do andar em que a cabine esta parada fica aberta.
func _abrir_cancelas() -> void:
	for n: int in _cancelas:
		_por_cancela(n, _andando or n != _andar)


func _fechar_todas() -> void:
	for n: int in _cancelas:
		_por_cancela(n, true)


func _por_cancela(n: int, fechada: bool) -> void:
	var par: Array = _cancelas[n]
	(par[0] as MeshInstance3D).visible = fechada
	for f: Node in (par[1] as StaticBody3D).get_children():
		(f as CollisionShape3D).set_deferred(&"disabled", not fechada)


func _grade(aberta: bool) -> void:
	_aberta = aberta
	AudioDirector.tocar(&"porta_desliza", _cabine.global_position + Vector3(0.0, 1.0, -0.8), -6.0)
	var t := create_tween().set_parallel(true)
	for k in _barras_porta.size():
		t.tween_property(_barras_porta[k], ^"position:x", _x_da_barra(k, aberta), 0.7) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await t.finished
