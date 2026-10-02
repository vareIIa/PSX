## Nivel de captura do Berg (Missao 1, tarefa B): o ator fazendo, em ordem, os
## gestos do roteiro na frente de um Marea preto parado, de noite.
##
##     godot --path game res://src/levels/teste_ator.tscn
##     ... -- --shots=/tmp/berg     salva um PNG no pico de cada gesto e sai
##
## Para que serve
## --------------
## O teste `tests/m1_b` mede: osso mexeu, sinal chegou, mao chegou no oculos.
## O que ele nao responde e se o gesto LE como gesto na tela de 104 px. Isso so
## se ve olhando, e este nivel e o lugar de olhar: mesmo cenario, mesma ordem
## da cena C3-C4 (encostado fumando, bituca, desencosta, ourico, papel, contorna
## o capo, abre a porta, baixa o oculos, ri, entra, sai), com a camera cortando
## para um enquadramento de cada coisa.
##
## Nao e a missao: nao tem roteiro, flag nem fala. A ligacao com a cena e da
## tarefa E; aqui so o corpo.
class_name TesteAtor
extends Node3D

## Onde o jogador "estaria" na cena: o papel cai perto dele.
const JOGADOR := Vector3(0.6, 0.0, 5.0)
const POS_CARRO := Vector3(0.0, 0.0, 0.0)

var _cam: Camera3D
var _berg: Ator
var _carro: Carro
var _shots := ""
var _n := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_montar_cenario()
	_rodar()


func _montar_cenario() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.24, 0.32)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Lua: o chao de 30 m tem quatro vertices, e a luz por vertice do poste
	# nao chega nele; sem isto a calcada fica preta nas fotos.
	var lua := DirectionalLight3D.new()
	lua.light_color = Color(0.55, 0.62, 0.85)
	lua.light_energy = 0.35
	lua.rotation = Vector3(-1.0, 0.6, 0.0)
	add_child(lua)
	# O poste da esquina: uma luz amarela alta, do lado do carona.
	var poste := OmniLight3D.new()
	poste.light_color = Color(1.0, 0.78, 0.48)
	poste.light_energy = 2.4
	poste.omni_range = 14.0
	poste.position = Vector3(3.0, 4.2, 2.0)
	add_child(poste)
	# Chao: calcada (onde o Berg fica) e rua (onde o carro esta).
	_laje(Vector3(0.0, -0.5, 0.0), Vector3(30.0, 1.0, 30.0), Color(0.16, 0.16, 0.17))
	# So malha, rente: o topo fica um milimetro abaixo do chao fisico, para o
	# papel deitado nao sumir dentro dela.
	_laje(Vector3(0.0, -0.011, 4.2), Vector3(30.0, 0.0, 6.0), Color(0.30, 0.29, 0.27))
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true


func _laje(centro: Vector3, tamanho: Vector3, cor: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(tamanho.x, maxf(tamanho.y, 0.02), tamanho.z)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mi.material_override = mat
	mi.position = centro
	add_child(mi)
	if tamanho.y > 0.0:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = tamanho
		cs.shape = caixa
		sb.position = centro
		sb.add_child(cs)
		add_child(sb)


func _rodar() -> void:
	_carro = Carro.new()
	_carro.name = "Marea"
	# Ficha vazia: sem motorista (com ficha a IA sai dirigindo).
	_carro.tinta_fixa = Color(0.04, 0.04, 0.05)
	_carro.modelo = Carroceria.Modelo.MAREA
	_carro.preparar({}, Vector2i.ZERO, Vector4i.ZERO, 7)
	add_child(_carro)
	_carro.estacionar_solto(POS_CARRO, 0.0)
	await _esperar(0.4)
	_carro.prender_estacionado(true)

	var ficha := Elenco.ficha(Elenco.BERG)
	var ap: Dictionary = (ficha.get("aparencia", {}) as Dictionary).duplicate(true)
	# A tarefa D poe o oculos escuro no Elenco; ate la, poe aqui.
	if int(ap.get("oculos", 0)) <= 0:
		ap["oculos"] = Aparencia.OCULOS_ESCURO
	ficha["aparencia"] = ap
	_berg = Ator.new()
	_berg.name = "Berg"
	_berg.preparar(Elenco.BERG, ficha)
	add_child(_berg)
	_berg.global_position = POS_CARRO + Vector3(1.6, 0.0, 1.0)

	# C3: encostado no paralama, fumando, o peso trocando de perna.
	await _berg.encostar_no_carro(_carro, 1.0)
	_berg.acender_cigarro()
	_plano(Vector3(2.6, 1.5, 4.2), _berg.global_position + Vector3.UP * 1.2)
	await _esperar(3.0)
	await _foto("encostado")
	await _berg.jogar_bituca()
	await _berg.fazer(Corpo.GestoCena.DESENCOSTAR)
	await _foto("desencostou")

	# Ourico: o chaveiro girando, a perna sem parar.
	_berg.ouricado(true)
	await _esperar(2.0)
	await _foto("ouricado")
	_berg.ouricado(false)

	# O papel: na direcao de quem estaria na frente dele.
	_berg.encarar(JOGADOR, true)
	await _esperar(0.6)
	_plano(_berg.global_position + Vector3(2.4, 1.3, 1.2), _berg.global_position + Vector3.UP * 0.8)
	# O gesto inteiro: tira do bolso, peteleco, e o papel sai da mao na marca.
	_berg.mirar_papel(JOGADOR + Vector3(0.4, 0.0, -0.6))
	_berg.fazer(Corpo.GestoCena.JOGAR_PAPEL)
	await _esperar(1.2)
	await _foto("jogou_papel")
	var papel: Node3D = await _berg.papel_caiu
	var no_chao := papel.global_position
	# O close do roteiro: "da para ler".
	_plano(no_chao + Vector3(0.0, 0.42, 0.3), no_chao)
	await _esperar(0.3)
	await _foto("papel_no_chao")

	# Contorna o capo com a mao na lataria ate a porta do motorista.
	_plano(Vector3(-1.0, 2.6, -5.5), POS_CARRO + Vector3.UP * 0.8)
	# Sem await: a foto sai no meio do caminho, e depois espera ele chegar.
	_berg.contornar_carro(_carro, Carro.Banco.MOTORISTA)
	await _esperar(1.4)
	await _foto("mao_no_capo")
	await _ate_terminar(Corpo.GestoCena.MAO_NO_CAPO)
	var porta := _carro.ponto_da_porta(Carro.Banco.MOTORISTA).origin
	while _berg.global_position.distance_to(porta) > 0.2:
		await get_tree().process_frame
	await _esperar(0.6)

	# Na porta: olha para tras, baixa o oculos, ri.
	_plano(_berg.global_position + Vector3(-1.2, 1.6, 1.4), _berg.global_position + Vector3.UP * 1.5)
	_berg.encarar(JOGADOR, true)
	await _esperar(0.5)
	_berg.fazer(Corpo.GestoCena.BAIXAR_OCULOS)
	await _esperar(0.6)
	await _foto("baixando_oculos")
	await _ate_terminar(Corpo.GestoCena.BAIXAR_OCULOS)
	_plano(_berg.global_position + (JOGADOR - _berg.global_position).normalized() * 1.0
		+ Vector3.UP * 1.62, _berg.global_position + Vector3.UP * 1.6)
	await _foto("oculos_na_ponta")
	_berg.fazer(Corpo.GestoCena.RIR)
	_berg.gargalhar(1)
	await _esperar(0.6)
	await _foto("rindo")
	await _ate_terminar(Corpo.GestoCena.RIR)
	await _berg.fazer(Corpo.GestoCena.SUBIR_OCULOS)

	# Entra e sai.
	_plano(_berg.global_position + Vector3(-2.6, 1.7, 1.6), _berg.global_position + Vector3.UP)
	_berg.entrar_no_carro(_carro, Carro.Banco.MOTORISTA)
	await _esperar(2.4)
	await _foto("entrando")
	while _berg.corpo().postura_atual() != Corpo.Postura.DIRIGINDO \
			or _berg.corpo().gesto_de_cena() != Corpo.GestoCena.NENHUM:
		await get_tree().process_frame
	await _esperar(0.3)
	await _foto("sentado")
	await _esperar(1.0)
	await _berg.sair_do_carro(_carro, Carro.Banco.MOTORISTA)
	await _foto("saiu")

	# Igreja: anda, para, olha a torre, fuma.
	_berg.vagar_em(POS_CARRO + Vector3(0.0, 0.0, 6.0), 3.0, Vector3(0.0, 9.0, 14.0))
	_plano(Vector3(5.0, 3.0, 10.0), POS_CARRO + Vector3(0.0, 1.0, 6.0))
	await _esperar(6.0)
	await _foto("vagando")
	if not _shots.is_empty():
		print("[teste_ator] %d capturas em %s" % [_n, _shots])
		get_tree().quit()


func _plano(de: Vector3, para: Vector3) -> void:
	_cam.global_position = de
	_cam.look_at(para, Vector3.UP)


func _foto(nome: String) -> void:
	_n += 1
	print("[teste_ator] %02d %s" % [_n, nome])
	if _shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("%s/%02d_%s.png" % [_shots, _n, nome])


## Espera o gesto de cena `g` comecar (se ainda nao comecou) e acabar.
func _ate_terminar(g: Corpo.GestoCena) -> void:
	var c := _berg.corpo()
	var limite := 8.0
	while c.gesto_de_cena() != g and limite > 0.0:
		limite -= get_process_delta_time()
		await get_tree().process_frame
	while c.gesto_de_cena() == g:
		await get_tree().process_frame
	# Contornar ainda anda alguns passos depois da mao sair do capo.
	await _esperar(0.4)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
