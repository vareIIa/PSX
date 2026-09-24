## O HUD de jogo vetorial. Junta as pecas e decide quando a tela e dele.
##
## Substitui, na cidade, o cartao de missao (`HudMissao`), o minimapa de papel
## (`Minimapa`) e a faixa do rodape (`HudCidade` continua viva: e ela que anda o
## relogio e desenha o clarao de dano, e perdeu so o papel e o prompt).
##
## Quando ele sai da tela
## ----------------------
## Mora na camada 160, acima do pos (a justificativa esta em `HudTema.CAMADA`).
## O preco de morar acima e que ele fica tambem acima de pause, celular, GPS e
## documento, que moram entre 110 e 145. Entao ele pergunta a cada quadro se ha
## tela aberta e sai com fade. Cena cortada e conversa ja escondem o grupo `hud`
## sozinhas.
class_name HudAAA
extends CanvasLayer

var alvo: Node3D:
	set(v):
		alvo = v
		for no: Node in [_radar, _bussola, _estado]:
			if no != null:
				no.set(&"alvo", v)

var _raiz: Control
var _objetivo: HudObjetivo
var _radar: HudRadar
var _bussola: HudBussola
var _estado: HudEstado
var _prompt: HudPrompt
var _avisos: HudAvisos
var _marcador: HudMarcador
var _pontos: HudPontos
## Vigia de chegada ao destino do GPS (`HudNavegacao.vigiar_chegada`).
var _chegada_armada := false
var _destino_vigiado := Vector3.INF
var _desde_chegada := 0.0
var _lugar := ""
var _t_lugar := 1.5
var _fade := 1.0
var _mirar := 0.0


func _ready() -> void:
	layer = HudTema.CAMADA
	add_to_group(&"hud")
	# A prancha PAUSA a arvore ao abrir. Pausado junto, este `_process` nunca
	# rodava para notar a tela aberta e o HUD ficava por cima do inventario
	# inteiro. O porteiro roda sempre; as pecas, embaixo de `_raiz`, pausam.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_raiz = Control.new()
	_raiz.process_mode = Node.PROCESS_MODE_PAUSABLE
	_raiz.name = "HudAAA"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tamanho de tela explicito. Sob `CanvasLayer` o FULL_RECT deixava a raiz e
	# todas as pecas em 0x0: na escala 1 o desenho sai assim mesmo, mas com o
	# TAMANHO do HUD em 120% o motor descartava tudo que desenha em `_draw` —
	# so o mapa do radar, que tem retangulo proprio, sobrevivia (medido).
	_raiz.size = HudTema.TELA

	_radar = HudRadar.new()
	_bussola = HudBussola.new()
	_objetivo = HudObjetivo.new()
	_estado = HudEstado.new()
	_prompt = HudPrompt.new()
	_avisos = HudAvisos.new()
	_marcador = HudMarcador.new()
	_pontos = HudPontos.new()
	# Marcador e pontos primeiro: sao o mundo, e tudo o mais passa por cima.
	for no: Control in [_pontos, _marcador, _radar, _bussola, _objetivo, _estado, _avisos, _prompt]:
		_raiz.add_child(no)
		no.position = Vector2.ZERO
		no.size = HudTema.TELA
	alvo = alvo
	_flags_de_captura()
	visibility_changed.connect(func() -> void:
		if visible:
			_avisos.silenciar())


func _process(delta: float) -> void:
	var quer := 0.0 if tela_aberta() else 1.0
	_fade = move_toward(_fade, quer, delta / 0.15)
	if _mirar > 0.0:
		_mirar -= delta
		var m := Missoes.posicao_do_alvo()
		if alvo != null and m != Vector3.INF:
			var d := m - alvo.global_position
			alvo.rotation.y = atan2(-d.x, -d.z)
	_raiz.modulate.a = _fade * HudConfig.alfa()
	_raiz.visible = _fade > 0.0
	_aplicar_config()
	if not get_tree().paused:
		_desde_chegada += delta
		if _desde_chegada >= 0.3:
			_desde_chegada = 0.0
			_vigiar_chegada()

	# Lugar com nome proprio ganha banner ao entrar. Espera o primeiro segundo e
	# meio: no nascimento o radar ainda nao leu onde o jogador esta.
	if _t_lugar > 0.0:
		_t_lugar -= delta
		return
	var nome := _radar.lugar_nomeado()
	if nome != _lugar:
		_lugar = nome
		if not nome.is_empty():
			_avisos.banner(nome, "", HudTema.TEXTO)


## So captura: forca uma opcao sem gravar no `hud.cfg` do jogador.
##   --hud-escala=1.2   --hud-modo=minimo|desligado   --hud-norte-fixo
##   --hud-contraste    --hud-destaque=azul|amarelo
##   --hud-mirar-alvo   vira o jogador para o alvo da missao (foto do marcador 3D)
##   --hud-demo         dispara avisos, banner e notificacao do iWeed aos 3,5 s
##   --hud-expandido    como o TAB segurado, o tempo todo
##   --hud-pad=xbox|ps  finge controle na mao, da familia dada (botoes desenhados)
##   --hud-legenda=grande[,fechado][,sem-nome]  opcoes da legenda e uma fala aos 3 s
##   --hud-chegada      destino do GPS 40 m a frente e o jogador andando ate ele
func _flags_de_captura() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hud-escala="):
			HudConfig.escala()
			HudConfig.escala_hud = clampf(arg.trim_prefix("--hud-escala=").to_float(),
				HudConfig.ESCALA_MIN, HudConfig.ESCALA_MAX)
		elif arg.begins_with("--hud-modo="):
			HudConfig.escala()
			HudConfig.modo = HudConfig.MODO_ROTULO.find(arg.trim_prefix("--hud-modo=").to_upper())
			HudConfig.modo = maxi(HudConfig.modo, 0)
		elif arg == "--hud-norte-fixo":
			HudConfig.escala()
			HudConfig.radar_gira = false
		elif arg == "--hud-mirar-alvo":
			_mirar = 3.0
		elif arg == "--hud-expandido":
			HudConfig.escala()
			HudConfig.expandido = true
		elif arg == "--hud-demo":
			_demo.call_deferred()
		elif arg == "--hud-contraste":
			HudConfig.escala()
			HudConfig.contraste = true
		elif arg.begins_with("--hud-legenda="):
			HudConfig.escala()
			var partes := arg.trim_prefix("--hud-legenda=").split(",")
			HudConfig.legenda_tam = maxi(0, ["pequena", "media", "grande"].find(partes[0]))
			HudConfig.legenda_fundo = 1 if partes.has("fechado") else 0
			HudConfig.legenda_nome = not partes.has("sem-nome")
			_legenda_demo.call_deferred()
		elif arg == "--hud-chegada":
			_chegada_demo.call_deferred()
		elif arg.begins_with("--hud-pad="):
			HudGlifos.forcar = HudGlifos.PLAYSTATION if arg.ends_with("=ps") else HudGlifos.XBOX
			var ctl := Settings.get(&"controle") as Controle
			if ctl != null:
				ctl.dispositivo = Controle.Dispositivo.CONTROLE
				ctl.dispositivo_mudou.emit(ctl.dispositivo)
		elif arg.begins_with("--hud-destaque="):
			HudConfig.escala()
			HudConfig.destaque = maxi(0, HudConfig.DESTAQUE_ROTULO.find(
				arg.trim_prefix("--hud-destaque=").to_upper()))


func _legenda_demo() -> void:
	await get_tree().create_timer(3.0).timeout
	var cinema := get_node_or_null(^"/root/Cinema")
	if cinema != null:
		cinema.call(&"fala", "JOTA (celular): A entrega saiu. Passa no Beco do Ze antes da blitz fechar a avenida.")


## Poe o destino 40 m a frente e empurra o jogador ate ele: prova a vigia de
## chegada pelo caminho de verdade (`_vigiar_chegada` a cada 0,3 s).
func _chegada_demo() -> void:
	await get_tree().create_timer(2.0).timeout
	if alvo == null:
		return
	var frente := -alvo.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var d := alvo.global_position + frente * 40.0
	Gps.destino = {"categoria": &"marca", "nome": "MARCA NO MAPA", "mundo": d,
		"chunk": Vector2i(floori(d.x / MalhaUrbana.TAM), floori(d.z / MalhaUrbana.TAM)),
		"icone": &"", "endereco": NomesDeRua.rua_perto(d)}
	Gps.rota = Rota.tracar(alvo.global_position, d)
	Gps.destino_mudou.emit()
	await get_tree().create_timer(0.8).timeout
	var inicio := alvo.global_position
	for i in 40:
		alvo.global_position = inicio + frente * (float(i + 1) * 0.8)
		await get_tree().create_timer(0.05).timeout
	print("[chegada] destino vazio=%s" % Gps.destino.is_empty())


func _demo() -> void:
	await get_tree().create_timer(3.5).timeout
	var iw := get_tree().get_first_node_in_group(&"hud_iweed")
	if iw != null:
		iw.call(&"notificar", "NOVO PEDIDO", "Dona Cida quer 2x Prensado no Beco do Ze. Paga R$ 60.",
			HudTema.OK)
	_avisos.aviso("BATERIA", "+2", HudTema.TEXTO, Inventario.definicao(&"bateria").icone
		if Inventario.definicao(&"bateria") != null else null, 2)
	_avisos.aviso("+R$ 60", "saldo R$ 1.250", HudTema.OK)
	_avisos.aviso("BOLSA CHEIA", "Pe de cabra", HudTema.ALERTA)
	_avisos.banner("MISSAO CUMPRIDA", "A CASA DA FUMACA", HudTema.OK)


## Opcoes > HUD, a cada quadro. Sao leituras de campo estatico; o custo e o de
## comparar meia duzia de booleanos, e mudar uma opcao aparece no quadro seguinte.
func _aplicar_config() -> void:
	var s := HudConfig.escala()
	var ver_radar := HudConfig.ver(&"radar")
	_objetivo.visible = HudConfig.ver(&"objetivo")
	# A bussola nao tem o que dizer dentro de casa: some junto com o radar.
	_bussola.visible = HudConfig.ver(&"bussola") and not Interiores.dentro
	_radar.ver_radar = ver_radar
	_radar.ver_lugar = HudConfig.ver(&"lugar")
	_radar.visible = ver_radar or _radar.ver_lugar
	_prompt.visible = HudConfig.ver(&"prompt")
	_estado.visible = HudConfig.modo_vitais() != HudConfig.Vitais.DESLIGADOS \
		or BlitzNoCaminho.procurado()
	_avisos.ver_avisos = HudConfig.ver(&"avisos")
	_avisos.ver_banners = HudConfig.ver(&"banners")
	_avisos.com_radar = not Interiores.dentro and ver_radar
	_avisos.escala = s
	var limite := INF
	var painel := get_tree().get_first_node_in_group(&"painel_carro") as PainelCarro
	if painel != null and painel.mostrado() and HudConfig.ver(&"painel_carro"):
		limite = painel.centro().y - PainelLayout.RAIO - 4.0
	_avisos.maximo = HudLayout.avisos_que_cabem(s, _avisos.com_radar, limite)
	_marcador.escala = s
	_pontos.escala = s
	for par: Array in [[_objetivo, HudLayout.PIVO_OBJETIVO], [_bussola, HudLayout.PIVO_BUSSOLA],
			[_radar, HudLayout.PIVO_RADAR], [_estado, HudLayout.PIVO_ESTADO],
			[_prompt, HudLayout.PIVO_PROMPT]]:
		var no: Control = par[0]
		no.pivot_offset = par[1]
		no.scale = Vector2(s, s)
		no.set(&"escala", s)


## Fecha a navegacao quando o jogador chega ao destino do GPS: banner, som e a
## rota apagada. Destino novo desarma a vigia ate o jogador sair do raio.
func _vigiar_chegada() -> void:
	if Gps.destino.is_empty() or alvo == null:
		_destino_vigiado = Vector3.INF
		_chegada_armada = false
		return
	var d: Vector3 = Gps.destino["mundo"]
	if d != _destino_vigiado:
		_destino_vigiado = d
		_chegada_armada = false
	var dono := alvo as Player
	var dirigindo := dono != null and dono.dirigindo()
	var p := alvo.global_position
	var r := HudNavegacao.vigiar_chegada(Vector2(d.x, d.z), Vector2(p.x, p.z), dirigindo,
		_chegada_armada)
	_chegada_armada = bool(r["armada"])
	if not bool(r["chegou"]):
		return
	var nome := String(Gps.destino.get("nome", ""))
	var endereco := String(Gps.destino.get("endereco", ""))
	_avisos.banner("VOCE CHEGOU", nome if not nome.is_empty() else endereco, HudTema.OK)
	AudioDirector.tocar_ui(&"celular_ok", -12.0)
	Gps.destino = {}
	Gps.rota = PackedVector2Array()
	Gps.destino_mudou.emit()
	_destino_vigiado = Vector3.INF


## Ha tela de jogo por cima? Lido pelo nome, e nao pelo tipo: alguns desses
## autoloads nascem depois, e um HUD que quebra porque o celular ainda nao
## existe e pior que um HUD que aparece meio quadro a mais.
func tela_aberta() -> bool:
	if UIManager.profundidade() > 0 or get_tree().paused:
		return true
	for nome: String in ["Celular", "Gps", "Terminal", "Documento", "Dialogo"]:
		var no := get_node_or_null(NodePath("/root/" + nome))
		if no != null and bool(no.get(&"ativo")):
			return true
	var foto := get_node_or_null(^"/root/Foto")
	if foto != null and bool(foto.get(&"ativo")):
		return true
	return false


# --- API para o nivel ---------------------------------------------------------

func definir_prompt(texto: String) -> void:
	_prompt.definir(texto)


func aviso(titulo: String, sub: String, cor: Color = HudTema.TEXTO) -> void:
	_avisos.aviso(titulo, sub, cor)


func banner(titulo: String, sub: String = "", cor: Color = HudTema.ACENTO) -> void:
	_avisos.banner(titulo, sub, cor)


## Recolhe a dica do objetivo. Mesmo contrato de `HudMissao.encolher_agora`,
## que a captura `--ver-missao=tira` chama pelo grupo.
func encolher_agora() -> void:
	_objetivo.encolher_agora()
