## Quem esta na casa da fumaca.
##
## E primo do Pedestre e nao irmao. O Pedestre resolve problemas que aqui nao
## existem — grafo de calcada, altura por raio, chunk que descarrega debaixo dos
## pes — e nao resolve o unico que aqui importa: ficar num comodo de nove metros
## com mais cinco pessoas sem que a sala vire uma fila indiana.
##
## O que muda de intencao
## ----------------------
## Pedestre vai a algum lugar. Convidado NAO vai a lugar nenhum: ele circula,
## para, encosta em alguem, volta. Um comodo em que todos andam com proposito
## le como corredor de reparticao; o que faz uma sala parecer uma sala e a
## maioria estar parada e o movimento ser a excecao.
##
## Papeis
## ------
##   LIVRE      circula pelos pontos da sala, para, fuma, conversa
##   SENTADO    no chao, de frente para a TV, controle na mao — nao sai dali
##   EM_PE      atras do que esta sentado, tambem com controle
##
## Os dois ultimos sao os jogadores da partida e sao fixos de proposito: quem
## esta jogando Bomba Patch nao levanta no meio do primeiro tempo.
class_name Convidado
extends CharacterBody3D

enum Papel { LIVRE, SENTADO, EM_PE }
enum Estado { PARADO, ANDANDO, CONVERSANDO, ATENDENDO }

const VELOCIDADE := 0.85
const GIRO := 4.2
const CHEGOU := 0.35

const ALTURA_CAPSULA := 1.25
const PISO_CAPSULA := 0.3

## Quanto tempo alguem fica parado antes de procurar outro canto. Longo: numa
## sala pequena, gente trocando de lugar a cada tres segundos vira formigueiro.
const ESPERA := Vector2(4.0, 11.0)

## Alcance em que dois convidados se juntam para conversar, e quanto dura.
const DISTANCIA_PAPO := 2.2
const DURACAO_PAPO := Vector2(6.0, 15.0)

const MATERIAL_RECORTE := "res://resources/materials/mat_casa_recorte.tres"
const MATERIAL_BRASA := "res://resources/materials/mat_casa_brasa.tres"
const MATERIAL_OLHOS := "res://resources/materials/mat_olhos_vermelhos.tres"
const MATERIAL_FUMACA := "res://resources/materials/mat_fumaca_baseado.tres"

## Intervalo entre risadas, em segundos. Ninguem ri de dois em dois segundos —
## isso le como boneco quebrado — e ninguem passa um minuto serio numa sala
## dessas.
const INTERVALO_RISADA := Vector2(7.0, 20.0)

## Pedacos de fala da sala. Ver _murmurar: o conteudo nao chega ao jogador, so o
## comprimento — mas o comprimento e o ritmo, e o ritmo e o que se ouve.
const FALAS: Array[String] = [
	"Ahn...",
	"Sei la, mano",
	"Nao, mas espera ai",
	"Que isso, cara",
	"Ta ligado?",
	"Eu falei, eu falei",
	"Perai, esqueci o que eu ia dizer",
]

## Celulas do atlas da casa. Ver tools/gerar_casa.py.
const C_BASEADO := Vector2i(0, 3)
const C_CONTROLE := Vector2i(4, 1)


## Area de interacao. Igual a do Pedestre: so responde a tecla e devolve o
## rotulo; quem sabe o que esta acontecendo e o Convidado.
class Gatilho extends Interativo:
	var dono: Convidado

	func rotulo_atual() -> String:
		if dono == null or Conversa.ativo:
			return ""
		return "Falar com %s" % FalasNpc.rotulo(dono.ficha)

	func interagir(quem: Node) -> void:
		if dono != null:
			dono.abordar(quem)


@export var papel: Papel = Papel.LIVRE
## Se este convidado esta com um baseado na mao.
@export var fumando: bool = false
## Para onde ele olha quando nao tem nada melhor a fazer. Os jogadores olham
## para a TV; os outros, para o meio da sala.
@export var foco := Vector3.ZERO

var ficha: Dictionary = {}
## Chapado e olho vermelho sao da CASA, e nao de toda pessoa que este script
## anima.
##
## Ate agora Convidado so existia dentro da casa da fumaca, entao os dois eram
## incondicionais. Quem atende o balcao do mercado as tres da manha usa o mesmo
## corpo, a mesma conversa e a mesma postura, e nao pode usar o mesmo pescoco
## mole nem os mesmos olhos — sao os dois unicos detalhes daquele comodo que nao
## viajam para fora dele.
var chapado: bool = true
var olhos_vermelhos: bool = true
var pontos: Array[Vector3] = []

var _corpo: Corpo
var _voz: Voz
var _gatilho: Gatilho
var _jogador: Node3D
var _mao: BoneAttachment3D
## O ponto do punho, filho do osso. Ver _montar_mao: o deslocamento NAO pode
## morar no BoneAttachment3D.
var _punho: Node3D
var _brasa: OmniLight3D
## A ponta acesa, que muda de brilho com a tragada.
var _ponta: MeshInstance3D

var _estado: Estado = Estado.PARADO
var _alvo := Vector3.ZERO
var _espera: float = 0.0
var _giro_alvo: float = 0.0
## O primeiro giro e um SALTO, e nao uma virada.
##
## Quem nasce ja tendo de encarar a TV nasce olhando para a parede e roda ate o
## alvo a 4,2 rad/s, o que na hora em que o comodo aparece na tela le como oito
## pessoas girando em torno do proprio eixo ao mesmo tempo. Ninguem entra numa
## sala girando: entra ja virado para onde estava olhando.
var _primeiro_giro: bool = true
var _parceiro: Convidado
var _murmurio: float = 0.0
var _ate_rir: float = 0.0
var _olhos: MeshInstance3D
var _fumaca: MeshInstance3D
var _y_piso: float = 0.0
var _rng := RandomNumberGenerator.new()

## Compra da loja: entra, pega da gondola, deixa no balcao junto da identidade.
## Vazio fora do mercado. Ver MercadoBuilder._gente.
var rotina: StringName = &""
## Onde o produto pousa no tampo, em coordenada local do interior.
var pouso_compra := Vector3.ZERO
var _indice_compra: int = 0
var _sacola: MeshInstance3D


func preparar(nova_ficha: Dictionary, novo_papel: Papel,
		novos_pontos: Array[Vector3], fuma: bool, novo_foco: Vector3) -> void:
	ficha = nova_ficha
	papel = novo_papel
	pontos = novos_pontos
	fumando = fuma
	foco = novo_foco


func _ready() -> void:
	add_to_group(&"convidado")
	add_to_group(&"npc")
	collision_layer = 1
	collision_mask = 1
	floor_max_angle = deg_to_rad(60.0)
	_rng.seed = int(ficha.get("id", 1)) * 2654435761
	_y_piso = position.y

	_montar_corpo()
	_montar_colisao()
	_montar_gatilho()
	_montar_mao()
	if olhos_vermelhos:
		_montar_olhos()
	_montar_fumaca()
	# Na casa, todo mundo esta chapado, e o corpo mostra isso antes da fala:
	# pescoco mole, balanco lento, ombro caido.
	_corpo.chapado = chapado
	_ate_rir = _rng.randf_range(INTERVALO_RISADA.x, INTERVALO_RISADA.y)

	_giro_alvo = rotation.y
	_espera = _rng.randf_range(ESPERA.x, ESPERA.y)
	_aplicar_postura()
	if rotina == &"compra" and pontos.size() >= 2:
		_indice_compra = 0
		_alvo = pontos[0]
		_estado = Estado.ANDANDO
		_aplicar_postura()
	if papel != Papel.LIVRE:
		_encarar(foco)
		# Ja nasce virado. Sem isto o primeiro quadro do comodo pega os dois que
		# jogam ainda de costas para a TV, girando.
		rotation.y = _giro_alvo
		_primeiro_giro = false


func _montar_corpo() -> void:
	_corpo = Corpo.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	_corpo.montar(ficha.get("aparencia", {}))

	_voz = Voz.new()
	_voz.name = "Voz"
	add_child(_voz)
	_voz.configurar(ficha)


func _montar_colisao() -> void:
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.26
	capsula.height = ALTURA_CAPSULA
	forma.shape = capsula
	# Quem esta sentado no chao ocupa meio metro de altura, e nao um metro e
	# oitenta. Sem isto o jogador esbarra numa coluna invisivel em cima de
	# alguem agachado, que e um dos jeitos mais rapidos de quebrar um comodo.
	if papel == Papel.SENTADO:
		capsula.height = 0.7
		forma.position = Vector3(0.0, 0.35, 0.0)
	else:
		forma.position = Vector3(0.0, PISO_CAPSULA + ALTURA_CAPSULA * 0.5, 0.0)
	add_child(forma)


func _montar_gatilho() -> void:
	_gatilho = Gatilho.new()
	_gatilho.name = "Gatilho"
	_gatilho.dono = self
	add_child(_gatilho)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.0, 1.9, 1.0)
	forma.shape = caixa
	forma.position = Vector3(0.0, 0.95 if papel != Papel.SENTADO else 0.5, 0.0)
	_gatilho.add_child(forma)


## O que a mao direita segura, pendurado no osso do antebraco.
##
## BoneAttachment3D e nao posicao fixa: o braco se mexe — sobe ate a boca na
## tragada, se inclina no lance do jogo — e um objeto colado em coordenada do
## corpo ficaria flutuando ao lado da mao o tempo todo. Pendurado no osso, ele
## acompanha de graca.
func _montar_mao() -> void:
	var esqueleto := _corpo.esqueleto()
	if esqueleto == null:
		return
	_mao = BoneAttachment3D.new()
	_mao.name = "Mao"
	esqueleto.add_child(_mao)
	_mao.bone_idx = _corpo.osso_da_mao()

	# O deslocamento ate o punho vai num FILHO, e nao no proprio
	# BoneAttachment3D.
	#
	# BoneAttachment3D reescreve a propria transformada com a pose do osso a
	# cada quadro. Qualquer posicao escrita nele e apagada no quadro seguinte, e
	# o objeto fica na origem do osso — que aqui e o COTOVELO. O baseado ficava
	# no meio do braco, e nao na mao, e a captura nao mostrava isso porque a
	# essa distancia as duas coisas sao o mesmo borrao.
	#
	# Quem achou foi uma linha de diagnostico imprimindo a posicao global do no:
	# 1999,78 num comodo cujo piso esta em 2000, ou seja vinte e dois
	# centimetros ABAIXO do chao — exatamente o deslocamento que eu tinha
	# escrito, sem a pose do osso aplicada em cima.
	_punho = Node3D.new()
	_punho.name = "Punho"
	_mao.add_child(_punho)
	_punho.position = Vector3(0.0, -0.24, 0.07)

	if papel != Papel.LIVRE:
		_pendurar(C_CONTROLE, Vector2(0.20, 0.115), MATERIAL_RECORTE)
		return
	if not fumando:
		return
	_montar_baseado()


## O baseado: um bastao de papel com a brasa na ponta.
##
## Comecou como dois quads cruzados com a celula do atlas, e nao funcionou. Um
## quad so tem luz pela normal, e a normal de quem esta com o braco ao lado do
## corpo aponta para o chao: o objeto saiu preto em todas as capturas, por mais
## emissao que o material levasse. Volume resolve — um bastao de doze
## milimetros tem sempre uma face virada para alguma coisa.
##
## E a brasa fica ACESA o tempo todo, num fio baixo, subindo na tragada. Num
## comodo sem luz de teto, o ponto laranja e a unica coisa daquela mao que se
## enxerga de longe, e e ele que conta o que a pessoa esta fazendo.
func _montar_baseado() -> void:
	var dados := PSXMesh.dados_vazios()
	Adereco.bastao(dados, Vector3(0.13, 0.013, 0.013), Vector3.ZERO, C_BASEADO,
		Color(1.0, 0.96, 0.88))
	var mi := MeshInstance3D.new()
	mi.name = "Baseado"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(MATERIAL_RECORTE) as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Em diagonal, como fica entre os dedos.
	mi.basis = Basis(Vector3.UP, 0.5) * Basis(Vector3.FORWARD, 0.34)
	_punho.add_child(mi)

	var brasa := PSXMesh.dados_vazios()
	Adereco.bastao(brasa, Vector3(0.022, 0.017, 0.017), Vector3(0.072, 0.0, 0.0),
		C_BASEADO, Color.WHITE)
	_ponta = MeshInstance3D.new()
	_ponta.name = "Brasa"
	_ponta.mesh = PSXMesh.dados_para_mesh(brasa)
	_ponta.material_override = (load(MATERIAL_BRASA)
		as ShaderMaterial).duplicate() as ShaderMaterial
	_ponta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ponta.basis = mi.basis
	_punho.add_child(_ponta)

	_brasa = OmniLight3D.new()
	_brasa.name = "LuzBrasa"
	_brasa.omni_range = 0.9
	_brasa.light_color = Color(1.0, 0.46, 0.16)
	_brasa.light_energy = 0.22
	_brasa.shadow_enabled = false
	_brasa.position = Vector3(0.075, 0.0, 0.0)
	_punho.add_child(_brasa)


func _pendurar(celula: Vector2i, tamanho: Vector2, material: String) -> void:
	var d := PSXMesh.placa_dados(tamanho, 100.0, Color.WHITE)
	var r := Carroceria.uv(celula)
	var uvs: PackedVector2Array = d["uv"]
	for k in uvs.size():
		uvs[k] = r.position + uvs[k] * r.size
	d["uv"] = uvs
	# Dois quads cruzados, e nao um. Um so desaparece quando visto de perfil, e
	# a mao gira: o cruzado sempre mostra alguma coisa, que e como todo objeto
	# fino era feito na epoca.
	# Em diagonal, como fica entre os dedos — e nao paralelo ao chao, que le como
	# apontador de laser.
	var pose := Basis(Vector3.UP, 0.42) * Basis(Vector3.FORWARD, 0.30)
	var dados := PSXMesh.dados_vazios()
	PSXMesh.acumular(dados, d, Transform3D(pose, Vector3.ZERO))
	PSXMesh.acumular(dados, d,
		Transform3D(pose * Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))

	var mi := MeshInstance3D.new()
	mi.name = "NaMao"
	mi.mesh = PSXMesh.dados_para_mesh(dados)
	mi.material_override = load(material) as Material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_punho.add_child(mi)


## O olho vermelho, colado no plano do rosto.
##
## Vai num quad proprio e nao numa celula de rosto nova porque o atlas de gente
## esta cheio: as oito linhas dele ja tem rosto, peca, cabelo, camisa, costas,
## calca e casaco. Uma linha a mais custaria uma textura de 256 por dois olhos.
##
## O quad tem exatamente o tamanho da face da cabeca, e a celula tem as manchas
## nas MESMAS coordenadas em que gerar_npc desenha os olhos — entao a mascara
## cai em cima deles em qualquer rosto sorteado, com qualquer separacao.
##
## Custa uma chamada de desenho por pessoa. E o preco de ter seis pessoas de
## olho vermelho num comodo, e so acontece dentro dele.
func _montar_olhos() -> void:
	var esqueleto := _corpo.esqueleto()
	if esqueleto == null:
		return
	var no := BoneAttachment3D.new()
	no.name = "Cabeca"
	esqueleto.add_child(no)
	no.bone_idx = _corpo.osso_da_cabeca()

	_olhos = MeshInstance3D.new()
	_olhos.name = "OlhosVermelhos"
	_olhos.mesh = PSXMesh.dados_para_mesh(
		PSXMesh.placa_dados(_corpo.tamanho_do_rosto(), 100.0, Color.WHITE))
	_olhos.material_override = load(MATERIAL_OLHOS) as Material
	_olhos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	no.add_child(_olhos)
	# O deslocamento vai no FILHO, e nao no BoneAttachment3D, que reescreve a
	# propria transformada com a pose do osso a cada quadro.
	_olhos.transform = _corpo.plano_do_rosto()


## A fumaca que sobe do baseado.
##
## Nao e filha da mao. Fumaca sobe na vertical por definicao, e pendurada no
## osso ela acompanharia o braco: quando a pessoa levasse o baseado a boca, a
## coluna sairia deitada de lado. Aqui o no e `top_level`, ou seja ignora a
## transformada do pai, e a cada quadro so a POSICAO e copiada da brasa.
func _montar_fumaca() -> void:
	if not fumando:
		return
	var dados := PSXMesh.dados_vazios()
	for giro: float in [0.0, PI * 0.5]:
		var d := PSXMesh.placa_dados(Vector2(0.26, 0.70), 0.35,
			Color(1.0, 1.0, 1.0, 0.85))
		PSXMesh.acumular(dados, d,
			Transform3D(Basis(Vector3.UP, giro), Vector3(0.0, 0.35, 0.0)))
	_fumaca = MeshInstance3D.new()
	_fumaca.name = "Fumaca"
	_fumaca.mesh = PSXMesh.dados_para_mesh(dados)
	_fumaca.material_override = load(MATERIAL_FUMACA) as Material
	_fumaca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fumaca.top_level = true
	add_child(_fumaca)


func _aplicar_postura() -> void:
	match papel:
		Papel.SENTADO:
			_corpo.postura(Corpo.Postura.SENTADO)
		Papel.EM_PE:
			_corpo.postura(Corpo.Postura.CONTROLE)
		_:
			_corpo.postura(Corpo.Postura.FUMANDO if fumando and
				_estado != Estado.ANDANDO else Corpo.Postura.LIVRE)


# --- ciclo ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _jogador == null:
		_jogador = get_tree().get_first_node_in_group(&"player") as Node3D

	if papel == Papel.LIVRE:
		match _estado:
			Estado.PARADO:
				_esperando(delta)
			Estado.ANDANDO:
				_andando(delta)
			Estado.CONVERSANDO:
				_conversando(delta)
			Estado.ATENDENDO:
				velocity = Vector3.ZERO
				if _jogador != null:
					_encarar(_jogador.global_position)
		move_and_slide()
		# A sala e plana e o corpo nao pula: qualquer deriva em Y so pode vir de
		# um empurrao, e deixar isso acumular afunda o convidado no piso.
		position.y = _y_piso
	else:
		velocity = Vector3.ZERO
		if _estado == Estado.ATENDENDO and _jogador != null:
			_encarar(_jogador.global_position)

	_girar(delta)
	_corpo.animar(Vector2(velocity.x, velocity.z).length(), delta)
	_atualizar_brasa()
	_seguir_fumaca()
	_murmurar(delta)
	_gargalhada(delta)


func _esperando(delta: float) -> void:
	velocity = Vector3.ZERO
	_espera -= delta
	if _procurar_papo():
		return
	if _espera > 0.0:
		return
	if pontos.is_empty():
		_espera = _rng.randf_range(ESPERA.x, ESPERA.y)
		return
	_alvo = pontos[_rng.randi() % pontos.size()]
	_estado = Estado.ANDANDO
	_aplicar_postura()


func _andando(_delta: float) -> void:
	var para := _alvo - global_position
	para.y = 0.0
	if para.length() < CHEGOU:
		if rotina == &"compra":
			_avancar_compra()
			return
		_estado = Estado.PARADO
		_espera = _rng.randf_range(ESPERA.x, ESPERA.y)
		velocity = Vector3.ZERO
		# Parou: olha para o meio da sala, e nao para a parede em que chegou.
		_encarar(foco)
		_aplicar_postura()
		return
	var direcao := para.normalized()
	velocity = direcao * (1.15 if rotina == &"compra" else VELOCIDADE)
	_giro_alvo = atan2(-direcao.x, -direcao.z)


func _conversando(delta: float) -> void:
	velocity = Vector3.ZERO
	_espera -= delta
	if not is_instance_valid(_parceiro) or _espera <= 0.0:
		_parceiro = null
		_estado = Estado.PARADO
		_espera = _rng.randf_range(ESPERA.x, ESPERA.y)
		_corpo.falar(false)
		_aplicar_postura()
		return
	_encarar(_parceiro.global_position)


## Junta este convidado a alguem livre que esteja perto.
##
## Quem procura e quem esta parado, e nao um gerente central como a Multidao usa
## na rua. Numa sala de seis pessoas a busca custa cinco comparacoes e economiza
## um autoload inteiro; na rua, com gente nascendo e morrendo, o gerente se
## paga.
func _procurar_papo() -> bool:
	if rotina == &"compra" and _espera > 100.0:
		return false
	if _espera > 1.5 or _rng.randf() > 0.02:
		return false
	for outro: Node in get_tree().get_nodes_in_group(&"convidado"):
		var c := outro as Convidado
		if c == null or c == self or not is_instance_valid(c):
			continue
		if c.papel != Papel.LIVRE or not c.esta_livre():
			continue
		if c.global_position.distance_to(global_position) > DISTANCIA_PAPO:
			continue
		var duracao := _rng.randf_range(DURACAO_PAPO.x, DURACAO_PAPO.y)
		iniciar_papo(c, duracao)
		c.iniciar_papo(self, duracao)
		return true
	return false


func iniciar_papo(outro: Convidado, duracao: float) -> void:
	_parceiro = outro
	_estado = Estado.CONVERSANDO
	_espera = duracao
	_corpo.falar(true)
	_corpo.postura(Corpo.Postura.LIVRE)
	_murmurio = 0.4


## Para de circular e assume a postura do papel.
##
## Existe para a captura: entre o enquadramento e o disparo passam alguns
## segundos, e nesse tempo quem estava na mira ja andou para o outro canto da
## sala. Mesma razao do Pedestre.acordar — quem mede precisa poder segurar o
## que esta medindo.
func congelar_para_captura() -> void:
	_estado = Estado.PARADO
	_espera = 9999.0
	velocity = Vector3.ZERO
	_parceiro = null
	_corpo.falar(false)
	_aplicar_postura()


func esta_livre() -> bool:
	return _estado == Estado.PARADO or _estado == Estado.ANDANDO


## Murmurio de sala cheia. Nao e conversa com o jogador: sao pedacos de fala
## saindo de gente que esta falando entre si, e e o que impede o comodo de soar
## como um diorama com bonecos.
func _murmurar(delta: float) -> void:
	if _estado != Estado.CONVERSANDO:
		return
	_murmurio -= delta
	if _murmurio > 0.0:
		return
	_murmurio = _rng.randf_range(2.2, 5.5)
	if not _voz.playing:
		_voz.dizer(FALAS[_rng.randi() % FALAS.size()])


## A brasa nunca apaga; ela respira.
##
## Acesa em fio baixo o tempo todo e forte na tragada. Ligar e desligar seria
## mais barato e leria como pisca-pisca: uma brasa de verdade nao some quando
## ninguem esta puxando, so escurece.
## A coluna acompanha a brasa em posicao, mas nunca em rotacao.
func _seguir_fumaca() -> void:
	if _fumaca == null or _brasa == null:
		return
	_fumaca.global_position = _brasa.global_position + Vector3(0.0, 0.06, 0.0)
	_fumaca.global_basis = Basis()


## Risada.
##
## O gesto e do Corpo e o som e daqui, porque o banco de voz depende do sexo e
## da altura da pessoa — isso mora na ficha, e o Corpo nao le ficha.
##
## So ri quem esta conversando: rir sozinho no meio da sala le como loucura, e
## nao como festa. E quando um ri, o parceiro tende a rir logo depois — e o
## contagio que faz o comodo soar como uma roda de amigos em vez de seis pessoas
## rindo em horarios sorteados.
func _gargalhada(delta: float) -> void:
	if _estado != Estado.CONVERSANDO:
		return
	_ate_rir -= delta
	if _ate_rir > 0.0:
		return
	_ate_rir = _rng.randf_range(INTERVALO_RISADA.x, INTERVALO_RISADA.y)
	gargalhar()
	if is_instance_valid(_parceiro) and _rng.randf() < 0.55:
		_parceiro.contagiar()


func gargalhar() -> void:
	_corpo.rir(_rng.randf_range(1.1, 1.6))
	var banco := "f" if StringName(ficha.get("sexo", &"M")) == &"F" else "m"
	var nome := StringName("risada_%s_%d" % [banco, 1 + _rng.randi() % 2])
	if _voz == null or not AudioDirector.tem(nome):
		return
	var aparencia: Dictionary = ficha.get("aparencia", {})
	_voz.stream = AudioDirector.stream(nome)
	_voz.pitch_scale = clampf(float(aparencia.get("voz", 1.0)), 0.7, 1.5)
	_voz.volume_db = -11.0
	_voz.play()


## Alguem do lado riu. Rir junto, meio segundo depois.
func contagiar() -> void:
	if _corpo.rindo():
		return
	await get_tree().create_timer(_rng.randf_range(0.35, 0.9)).timeout
	if is_instance_valid(self) and _estado == Estado.CONVERSANDO:
		gargalhar()


func _atualizar_brasa() -> void:
	if _brasa == null:
		return
	var t := _corpo.intensidade_da_tragada()
	_brasa.light_energy = 0.22 + t * 1.5
	if _ponta != null:
		var mat := _ponta.material_override as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("emission_energy", 1.6 + t * 3.4)


## Vira o rosto para um ponto, agora, e passa a considera-lo o foco.
##
## Publica porque quem esta parado nao reavalia o foco sozinho: `_encarar` so e
## chamado nas trocas de estado, e uma pessoa sem pontos de caminhada nunca troca
## de estado. Mudar `foco` de fora nao move ninguem.
##
## Existe para o balcao da loja. Quando o jogador pega a carteira que o cliente
## largou, o cliente vira e olha para ele — que e o que qualquer pessoa faz
## quando pegam o documento dela da mesa. Sem isso ele continua encarando o
## atendente enquanto o proprio documento e conferido, e a cena inteira le como
## dois bonecos parados perto de um objeto.
## Proximo passo da compra: prateleira, depois caixa.
func _avancar_compra() -> void:
	velocity = Vector3.ZERO
	if _indice_compra == 0:
		_pegar_da_prateleira()
		_indice_compra = 1
		if pontos.size() > 1:
			_alvo = pontos[1]
			_estado = Estado.ANDANDO
			_aplicar_postura()
			return
	_pousar_no_balcao()
	_estado = Estado.PARADO
	_espera = 9999.0
	_encarar(foco)
	_aplicar_postura()


## Caixa na mao. Nao e o item jogavel: e a silhueta de "eu peguei alguma coisa".
func _pegar_da_prateleira() -> void:
	if _sacola != null:
		return
	_sacola = _caixa_de_compra(Color("c45a3a") if _rng.randf() < 0.5 else Color("d8c05a"))
	if _punho != null:
		_punho.add_child(_sacola)
		_sacola.position = Vector3(0.04, -0.02, 0.08)
	else:
		add_child(_sacola)
		_sacola.position = Vector3(0.18, 0.95, 0.22)


## No tampo, ao lado da identidade. E o quadro do Shift at Midnight: produto
## e documento na mesma ilha, para o jogador conferir os dois sem andar.
func _pousar_no_balcao() -> void:
	var raiz := get_parent()
	if raiz == null:
		return
	if _sacola != null:
		var mundo := _sacola.global_transform
		_sacola.get_parent().remove_child(_sacola)
		raiz.add_child(_sacola)
		_sacola.global_transform = mundo
	var tampo := pouso_compra
	if tampo == Vector3.ZERO:
		tampo = global_position + Vector3(-0.55, 1.12, -0.15)
	if _sacola != null:
		_sacola.position = tampo
		_sacola.rotation = Vector3(0.0, 0.4, 0.0)
		_sacola.name = "CompraBalcao"
	# Segunda peca, um pouco deslocada: cesta de uma coisa so le como prop
	# esquecido, duas leem como compra.
	var extra := _caixa_de_compra(Color("3f6f9a"))
	extra.name = "CompraBalcao2"
	extra.position = tampo + Vector3(0.11, 0.0, -0.09)
	extra.rotation = Vector3(0.0, -0.3, 0.0)
	raiz.add_child(extra)


func _caixa_de_compra(cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PSXMesh.box(Vector3(0.09, 0.12, 0.07), 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A abertura precisa dos dois no caixa conversando. Sem isto o plano filma
## o cliente ainda na gondola e a fala de quarenta reais nao tem com quem.
func ir_ao_caixa() -> void:
	if pontos.size() < 2:
		return
	global_position = Vector3(pontos[1].x, _y_piso, pontos[1].z)
	_indice_compra = 1
	_pegar_da_prateleira()
	_pousar_no_balcao()
	_estado = Estado.PARADO
	_espera = 9999.0
	velocity = Vector3.ZERO
	_encarar(foco)
	rotation.y = _giro_alvo
	_primeiro_giro = false
	_aplicar_postura()


func encarar(ponto: Vector3) -> void:
	foco = ponto
	_encarar(ponto)


func _encarar(ponto: Vector3) -> void:
	var para := ponto - global_position
	para.y = 0.0
	if para.length() < 0.05:
		return
	_giro_alvo = atan2(-para.x, -para.z)


func _girar(delta: float) -> void:
	if _primeiro_giro:
		_primeiro_giro = false
		rotation.y = _giro_alvo
		return
	rotation.y = lerp_angle(rotation.y, _giro_alvo, minf(1.0, GIRO * delta))


# --- conversa com o jogador -------------------------------------------------

func abordar(_quem: Node) -> void:
	if Conversa.ativo or ficha.is_empty():
		return
	_estado = Estado.ATENDENDO
	velocity = Vector3.ZERO
	_parceiro = null
	_corpo.falar(false)
	# Quem esta jogando NAO larga o controle para conversar: responde de lado,
	# sem tirar os olhos da tela. E a coisa mais fiel que este comodo faz.
	if papel == Papel.LIVRE:
		_corpo.postura(Corpo.Postura.LIVRE)
	if not Conversa.fechou.is_connected(_ao_encerrar):
		Conversa.fechou.connect(_ao_encerrar, CONNECT_ONE_SHOT)
	Conversa.abrir(self, ficha)


func _ao_encerrar() -> void:
	_estado = Estado.PARADO
	_espera = _rng.randf_range(ESPERA.x, ESPERA.y)
	if papel != Papel.LIVRE:
		_encarar(foco)
	_aplicar_postura()


func dizer(linha: String) -> void:
	if _voz != null:
		_voz.dizer(linha)


func triangulos() -> int:
	return _corpo.triangulos() if _corpo != null else 0
