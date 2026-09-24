## Radar do canto de cima da direita, e o bloco de lugar embaixo dele.
##
## O que mudou em relacao ao cartao de papel (`Minimapa`)
## ------------------------------------------------------
## 1. Gira com o olhar. Frente e sempre para cima, como em GTA e Cyberpunk: o
##    mapa norte-para-cima obrigava a conta "estou virado para o leste, entao a
##    esquerda do mapa e a minha frente". O norte continua marcado no aro.
## 2. O alvo fora do quadro fica PRESO NA BORDA, apontando para onde esta. No
##    cartao ele simplesmente sumia assim que passava de 94 m.
## 3. Some a coordenada de quadra ("-1-2"). No lugar, o que o jogador casa com o
##    que ve na rua: o nome da rua (as placas da esquina dizem o mesmo), o
##    bairro, a hora e o tempo.
## 4. Afasta o zoom com a velocidade. A 60 km/h o cartao de 188 m mostrava a
##    esquina so depois de o carro passar dela.
##
## O giro nao redesenha o mapa
## ---------------------------
## O `Mapa` varre dezenas de quadras por desenho; redesenhar a cada grau de
## mouse seria pagar isso a 60 Hz. Entao o no inteiro gira (e transformacao, nao
## desenho) dentro de um recorte quadrado, e o `Mapa` tem lado igual a diagonal
## do recorte para o giro nunca mostrar quina vazia. Ele so se redesenha quando o
## jogador ANDA um pixel, como sempre fez.
class_name HudRadar
extends Control

## Metros por pixel parado e no maximo, e a velocidade (m/s) em que o maximo
## chega. 2,3 e a escala do cartao antigo; 5,0 a 20 m/s (72 km/h) mostra ~380 m.
const ESCALA_PE := 2.3
const ESCALA_MAX := 5.0
const VEL_ESCALA_MAX := 20.0
## Intervalo minimo entre redesenhos forcados do chao (chunk que carregou, rota).
const INTERVALO := 0.45
## Quanto a escala precisa mudar para valer redesenho. Zoom em degrau fino sem
## isto redesenharia a cada quadro de aceleracao.
const PASSO_ESCALA := 0.12

## Destino do GPS. O da missao e a cor de destaque das opcoes.
const COR_DESTINO := Color("ffd27a")

var alvo: Node3D
## Postos pelo `HudAAA` a partir de `HudConfig`.
var ver_radar := true
var ver_lugar := true
## Escala do HUD. O bloco de lugar mantem a largura NA TELA.
var escala := 1.0

var _recorte: Control
var _mapa: Mapa
var _topo: Control
var _local: Control
var _escala := ESCALA_PE
var _sujo := false
var _desde := 0.0
var _rumo := 0.0
var _rua := ""
var _bairro := ""
var _hora := ""
var _tempo := ""
var _desde_local := 99.0
var _com_mapa := true
## O lugar tem nome proprio (parque), e nao so o tipo do distrito.
var _nomeado := false
## Pontos de interesse perto, em coordenada de mundo: `{pos: Vector2, icone}`.
## Refeitos a cada `INTERVALO`; desenhados a cada quadro, sempre em pe.
var _blips: Array[Dictionary] = []
var _desde_blips := 99.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_recorte = Control.new()
	_recorte.name = "Recorte"
	_recorte.clip_contents = true
	_recorte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_recorte)
	var dentro := HudLayout.RADAR.grow(-2.0)
	_recorte.position = dentro.position
	_recorte.size = dentro.size

	_mapa = Mapa.new()
	_mapa.estilo = Mapa.Estilo.RADAR
	_mapa.metros_por_pixel = _escala
	_recorte.add_child(_mapa)
	var lado := ceilf(dentro.size.length()) + 2.0
	_mapa.size = Vector2(lado, lado)
	_mapa.position = (dentro.size - _mapa.size) * 0.5
	_mapa.pivot_offset = _mapa.size * 0.5

	# Seta, alvos, aro e norte: por cima do recorte, sem girar junto.
	_topo = Control.new()
	_topo.name = "Topo"
	_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_topo.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tamanho explicito: ver a nota em `HudAAA._ready` sobre o 0x0 e a escala.
	_topo.size = HudTema.TELA
	_topo.draw.connect(_desenhar_topo)
	add_child(_topo)

	_local = Control.new()
	_local.name = "Local"
	_local.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_local.set_anchors_preset(Control.PRESET_FULL_RECT)
	_local.size = HudTema.TELA
	_local.draw.connect(_desenhar_local)
	add_child(_local)

	Gps.destino_mudou.connect(_ao_mudar_destino)
	Missoes.iniciou.connect(func(_m: Dictionary) -> void: _ao_mudar_destino())
	Missoes.concluiu.connect(func(_m: Dictionary) -> void: _ao_mudar_destino())
	ChunkManager.chunk_carregado.connect(func(_c: Vector2i) -> void: _sujo = true)
	ChunkManager.chunk_descarregado.connect(func(_c: Vector2i) -> void: _sujo = true)
	_ao_mudar_destino()


func _process(delta: float) -> void:
	_desde += delta
	_desde_local += delta
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo == null:
			return
	var dentro_de_casa := Interiores.dentro
	_com_mapa = not dentro_de_casa and ver_radar
	_recorte.visible = _com_mapa
	_topo.visible = _com_mapa
	_local.visible = ver_lugar
	var pos := alvo.global_position

	if _com_mapa:
		_rumo = _rumo_da_camera()
		_mapa.rotation = _giro()
		_ajustar_escala(delta)
		if _desde >= INTERVALO and Gps.manter_rota(pos):
			_mapa.rota = Gps.rota_do_destino()
			_sujo = true
		if _sujo and _desde >= INTERVALO:
			_sujo = false
			_desde = 0.0
			_mapa.forcar_redesenho()
		_mapa.apontar(pos, _rumo)
		_desde_blips += delta
		if _desde_blips >= INTERVALO:
			_desde_blips = 0.0
			_colher_blips(pos)
		_topo.queue_redraw()

	if _desde_local >= 0.5:
		_desde_local = 0.0
		_refazer_local(pos, dentro_de_casa)
	_local.queue_redraw()


## Rumo do OLHAR, e nao do corpo. No carro e na terceira pessoa os dois
## discordam, e o radar tem de concordar com a tela.
func _rumo_da_camera() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return alvo.rotation.y
	var f := -cam.global_transform.basis.z
	if Vector2(f.x, f.z).length() < 0.01:
		return _rumo
	# Mesma convencao de `Node3D.rotation.y`: 0 olha para -Z, que e o norte.
	return atan2(-f.x, -f.z)


func _ajustar_escala(delta: float) -> void:
	var vel := 0.0
	var dono := alvo as Player
	if dono != null and dono.dirigindo():
		var c := dono.carro()
		if c != null and c.has_method(&"velocidade"):
			vel = absf(float(c.call(&"velocidade")))
	var quer := lerpf(ESCALA_PE, ESCALA_MAX, clampf(vel / VEL_ESCALA_MAX, 0.0, 1.0))
	# Suave e so em degrau: o zoom anda com o carro, mas o mapa so se refaz
	# quando a diferenca ja se ve.
	_escala = lerpf(_escala, quer, clampf(delta * 1.5, 0.0, 1.0))
	if absf(_escala - _mapa.metros_por_pixel) >= PASSO_ESCALA:
		_mapa.metros_por_pixel = _escala
		_mapa.forcar_redesenho()


func _ao_mudar_destino() -> void:
	_mapa.rota = Gps.rota_do_destino()
	_mapa.forcar_redesenho()


func _refazer_local(pos: Vector3, dentro_de_casa: bool) -> void:
	_nomeado = false
	if dentro_de_casa:
		_rua = ""
		_bairro = String(Interiores.tipo_atual()).replace("_", " ").to_upper()
	else:
		_rua = NomesDeRua.rua_perto(pos)
		var q := MalhaUrbana.quadra_de(floori(pos.x / MalhaUrbana.TAM),
			floori(pos.z / MalhaUrbana.TAM))
		if int(q["uso"]) == MalhaUrbana.Uso.PARQUE:
			_bairro = String(ParqueBuilder.planta(q)["nome"]).to_upper()
			_nomeado = true
		else:
			_bairro = MalhaUrbana.nome_do_distrito(q["distrito"]).to_upper()
	var ws := get_node_or_null(^"/root/WorldState")
	var rel: Relogio = ws.get(&"relogio") as Relogio if ws != null else null
	# Dia da semana na frente da hora: "SEX 22:43". A noite que vira dia vira
	# tambem o nome do dia, e o jogador sabe quantas ja passou.
	_hora = "%s %s" % [rel.dia_da_semana(), rel.texto()] if rel != null else ""
	_tempo = ""
	var preset := Settings.fog_preset()
	if preset != null and not String(preset.display_name).is_empty():
		# "Neblina (especial...)", "Estrada Velha — Noite": o HUD quer o tempo,
		# nao o nome do preset. Fica o que vem antes do parentese e do travessao.
		var nome := String(preset.display_name).get_slice(" (", 0).get_slice(" — ", 0)
		_tempo = nome.strip_edges().to_upper()


## Nome proprio do lugar, ou vazio. E o que merece banner ao entrar: "BOSQUE
## DO MORRO" e um lugar; "RESIDENCIAL" a cada esquina seria ruido.
func lugar_nomeado() -> String:
	return _bairro if _nomeado else ""


# --- desenho ------------------------------------------------------------------

func _desenhar_topo() -> void:
	if not _com_mapa:
		return
	var r := HudLayout.RADAR
	var dentro := r.grow(-2.0)
	var meio := dentro.get_center()


	# Escurecimento suave nas quatro bordas: o mapa "afunda" no aro em vez de
	# acabar num corte seco — o acabamento que separa radar de recorte de mapa.
	var fundo := Color(0.0, 0.0, 0.0, 0.5)
	var nada := Color(0.0, 0.0, 0.0, 0.0)
	var b := 7.0
	for faixa: Array in [
			[dentro.position, Vector2(dentro.end.x, dentro.position.y),
				Vector2(dentro.end.x, dentro.position.y + b), Vector2(dentro.position.x, dentro.position.y + b)],
			[Vector2(dentro.position.x, dentro.end.y), dentro.end,
				Vector2(dentro.end.x, dentro.end.y - b), Vector2(dentro.position.x, dentro.end.y - b)],
			[dentro.position, Vector2(dentro.position.x, dentro.end.y),
				Vector2(dentro.position.x + b, dentro.end.y), Vector2(dentro.position.x + b, dentro.position.y)],
			[Vector2(dentro.end.x, dentro.position.y), dentro.end,
				Vector2(dentro.end.x - b, dentro.end.y), Vector2(dentro.end.x - b, dentro.position.y)]]:
		_topo.draw_polygon(PackedVector2Array(faixa), PackedColorArray([fundo, fundo, nada, nada]))

	# Pontos de interesse, sempre em pe, so dentro do quadro.
	var quadro := dentro.grow(-3.5)
	for bl: Dictionary in _blips:
		var p := _na_tela(bl["pos"], meio)
		if quadro.has_point(p):
			HudTema.blip(_topo, p, bl["icone"])

	# Aro por cima do mapa, que e o proprio fundo. Borda dupla: escura por fora,
	# clara fina por dentro, para separar o radar de ceu claro e de rua escura.
	HudTema.sombra(_topo, r, 1.0)
	_topo.draw_rect(r, Color(0.0, 0.0, 0.0, 0.6), false, 2.0)
	_topo.draw_rect(dentro, Color(1.0, 1.0, 1.0, 0.18), false, 0.35)

	# Alvos por cima, presos na borda quando estao fora.
	for pino: Dictionary in Gps.pinos_do_destino():
		var mundo: Vector2 = pino["pos"]
		var de_missao: bool = pino.has("cor")
		var cor: Color = HudTema.acento() if de_missao else COR_DESTINO
		var p := _na_tela(mundo, meio)
		var borda := dentro.grow(-4.0)
		var fora := not borda.has_point(p)
		if fora:
			p = _prender(p, meio, borda)
		if de_missao:
			HudTema.losango(_topo, p, 2.6 if fora else 3.4, cor)
		else:
			_topo.draw_circle(p, (2.4 if fora else 3.0) + 1.0, Color(0.0, 0.0, 0.0, 0.7), true, -1.0, true)
			_topo.draw_circle(p, 2.4 if fora else 3.0, cor, true, -1.0, true)

	_desenhar_amigos(meio, dentro)

	# O jogador: sempre no meio. Para cima quando o mapa gira; com o norte fixo
	# a seta gira no lugar dele.
	var e := 4.2
	var giro_seta := _giro() - _rumo
	for passo: Array in [[e + 1.2, Color(0.0, 0.0, 0.0, 0.8)], [e, HudTema.TEXTO]]:
		var s: float = passo[0]
		HudTema.poligono(_topo, PackedVector2Array([
			meio + Vector2(0.0, -s).rotated(giro_seta),
			meio + Vector2(s * 0.68, s * 0.62).rotated(giro_seta),
			meio + Vector2(0.0, s * 0.25).rotated(giro_seta),
			meio + Vector2(-s * 0.68, s * 0.62).rotated(giro_seta),
		]), passo[1])

	# Norte no aro. Gira ao contrario do olhar: `_rumo` leva a frente para cima,
	# entao o norte (0, -1) vai para R(_rumo) * (0, -1).
	var norte := Vector2(0.0, -1.0).rotated(_giro())
	var n := _prender(meio + norte * 200.0, meio, r.grow(-0.5))
	_topo.draw_circle(n, 4.2, Color(0.0, 0.0, 0.0, 0.85), true, -1.0, true)
	var f := HudTema.semi()
	var tam := HudTema.T_MICRO
	var w := HudTema.largura(f, "N", tam)
	_topo.draw_string(f, n + Vector2(-w * 0.5, f.get_ascent(tam) * 0.5 - 0.6), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, tam, HudTema.TEXTO)


func _colher_blips(pos: Vector3) -> void:
	_blips.clear()
	if _mapa.metros_por_pixel > Mapa.ESCALA_SEM_ICONE:
		return
	var alcance := HudLayout.RADAR_LADO * 0.75 * _mapa.metros_por_pixel
	var tam := MalhaUrbana.TAM
	var c0 := Vector2i(floori((pos.x - alcance) / tam), floori((pos.z - alcance) / tam))
	var c1 := Vector2i(floori((pos.x + alcance) / tam), floori((pos.z + alcance) / tam))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if not _mapa.conhecido(Vector2i(cx, cz)):
				continue
			var origem := Vector2(float(cx) * tam, float(cz) * tam)
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				var icone := _mapa.icone_de(ponto)
				# Porta de apartamento nao vira blip: uma a cada tres quadras
				# cobriria o radar (mesma regra do mapa de papel).
				if icone == &"predio":
					continue
				var p: Vector3 = ponto["pos"]
				_blips.append({"pos": origem + Vector2(p.x, p.z), "icone": icone})


## Quanto o mapa gira. Com NORTE FIXO nas opcoes, zero: o mapa fica parado e
## quem gira e a seta.
func _giro() -> float:
	return _rumo if HudConfig.gira() else 0.0


## Mundo (x, z) para a tela do radar, ja girado.
func _na_tela(mundo: Vector2, meio: Vector2) -> Vector2:
	var centro := Vector2(alvo.global_position.x, alvo.global_position.z)
	return meio + ((mundo - centro) / _mapa.metros_por_pixel).rotated(_giro())


## Leva `p` para a borda do retangulo, pela reta que sai do meio.
static func _prender(p: Vector2, meio: Vector2, borda: Rect2) -> Vector2:
	var d := p - meio
	if d.length() < 0.001:
		return meio
	var meia := borda.size * 0.5
	var k := minf(meia.x / maxf(absf(d.x), 0.0001), meia.y / maxf(absf(d.y), 0.0001))
	if k >= 1.0:
		return p
	return meio + d * k


func _desenhar_amigos(meio: Vector2, dentro: Rect2) -> void:
	if not Sessao.em_rede():
		return
	var meu_espaco := Sessao.espaco_do_corpo(alvo)
	var avatares := Sessao.avatares()
	for id: int in avatares:
		var e: Dictionary = (avatares[id] as AvatarRemoto).estado
		if e.is_empty() or int(e.get("espaco", -1)) != meu_espaco:
			continue
		var p3: Vector3 = e["pos"]
		var p := _prender(_na_tela(Vector2(p3.x, p3.z), meio), meio, dentro.grow(-3.0))
		_topo.draw_circle(p, 2.8, Color(0.0, 0.0, 0.0, 0.8), true, -1.0, true)
		_topo.draw_circle(p, 2.0, HudTema.AMIGO, true, -1.0, true)


func _desenhar_local() -> void:
	var r := HudLayout.local_rect(_com_mapa)
	# Largura fixa na tela, encostada no pivo da direita.
	var w := HudLayout.largura_logica(HudLayout.LOCAL_LARGURA, escala)
	r = Rect2(HudLayout.PIVO_RADAR.x - w, r.position.y, w, r.size.y)
	var f_rot := HudTema.rotulo()
	var f_reg := HudTema.regular()
	var direita := r.end.x
	var tam1 := HudTema.T_ROTULO + 1
	var linha1 := HudTema.encurtar(f_rot, _rua if not _rua.is_empty() else _bairro, tam1, r.size.x)
	var linha2 := HudLayout.linha_de_lugar(_bairro if not _rua.is_empty() else "", _hora,
		_tempo if _com_mapa else "", r.size.x)
	var extra := ""
	# TAB segurado: o saldo e o dia, que o HUD normal nao mostra parado.
	if HudConfig.expandido:
		var rel: Relogio = WorldState.relogio
		extra = "DIA %d  ·  %s" % [rel.dia, Dinheiro.formatar(Dinheiro.saldo())]
	var h1 := HudTema.altura(f_rot, tam1)
	var h2 := HudTema.altura(f_reg, HudTema.T_ROTULO)
	var h3 := HudTema.altura(HudTema.semi(), tam1) if not extra.is_empty() else 0.0
	var largo := maxf(HudTema.largura(f_rot, linha1, tam1),
		maxf(HudTema.largura(f_reg, linha2, HudTema.T_ROTULO),
			HudTema.largura(HudTema.semi(), extra, tam1)))
	# Veu que sobe da borda da tela: cheio por baixo da linha mais larga (o texto
	# branco pousa em fundo ate a primeira letra), esfuma so depois dela.
	var pena := 5.0
	var borda := direita + HudLayout.M / maxf(escala, 0.01)
	var cheio := (borda - direita) + largo + 6.0
	HudTema.veu_horizontal(_local, Rect2(borda - cheio - 18.0, r.position.y - pena,
		cheio + 18.0, h1 + h2 + h3 + pena * 2.0), false, 0.8, cheio, pena)
	var y := r.position.y
	HudTema.texto(_local, f_rot, Vector2(r.position.x, y), linha1, tam1, HudTema.TEXTO,
		r.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	y += h1
	HudTema.texto(_local, f_reg, Vector2(r.position.x, y), linha2, HudTema.T_ROTULO,
		HudTema.fraco(), r.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	if not extra.is_empty():
		y += h2
		HudTema.texto(_local, HudTema.semi(), Vector2(r.position.x, y), extra, tam1,
			HudTema.TEXTO, r.size.x, HORIZONTAL_ALIGNMENT_RIGHT)
	# `direita` e o alinhamento de tudo; um fio de acento amarra o bloco ao radar.
	_local.draw_rect(Rect2(direita - 18.0, r.position.y - 2.5, 18.0, 1.0), HudTema.acento())
