## PERSONAGEM: quem o jogador e, como esta, quanto tem.
##
## O retrato e o mesmo boneco do jogo (`Corpo`), num mundo proprio com luz de
## estudio — como a polaroide da prancha, mas em resolucao de retrato de
## verdade: o SubViewport renderiza no triplo do tamanho em que aparece, e em
## 4K o rosto continua rosto. A/D gira o boneco.
class_name PausaAbaPersonagem
extends PausaAba

const RETRATO := Vector2(112.0, 150.0)
const RESOLUCAO := 3

var _vp: SubViewport
var _cam: Camera3D
var _corpo: Corpo
var _giro := PI
var _aparencia_usada: Dictionary = {}


func _ready() -> void:
	super._ready()
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(RETRATO.x) * RESOLUCAO, int(RETRATO.y) * RESOLUCAO)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f97a0")
	env.ambient_light_energy = 0.9
	ambiente.environment = env
	_vp.add_child(ambiente)
	# Luz principal quente de um lado, recorte frio do outro: retrato de estudio.
	var chave := DirectionalLight3D.new()
	chave.light_energy = 1.3
	chave.light_color = Color("ffe2c4")
	chave.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(38.0), 0.0)
	_vp.add_child(chave)
	var recorte := DirectionalLight3D.new()
	recorte.light_energy = 0.7
	recorte.light_color = Color("9cc4ff")
	recorte.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(-140.0), 0.0)
	_vp.add_child(recorte)
	_cam = Camera3D.new()
	_cam.fov = 26.0
	_cam.near = 0.05
	_vp.add_child(_cam)
	_cam.current = true
	set_process(false)


func ao_entrar() -> void:
	var ap: Dictionary = RegistroCivil.jogador.get("aparencia", {})
	if _corpo == null or ap != _aparencia_usada:
		_refazer(ap)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	set_process(true)
	queue_redraw()


func _refazer(aparencia: Dictionary) -> void:
	if _corpo != null:
		_corpo.queue_free()
	_aparencia_usada = aparencia
	_corpo = Corpo.new()
	_vp.add_child(_corpo)
	_corpo.montar(aparencia)
	_corpo.rotation.y = _giro
	_corpo.animar(0.0, 0.016)
	# Meio corpo: a lente mira um pouco abaixo da boca de QUEM esta na foto.
	var boca := _corpo.altura_da_boca()
	_cam.position = Vector3(0.0, boca - 0.18, 2.9)
	_cam.look_at(Vector3(0.0, boca - 0.3, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if not visible or not bool(hub.get(&"aberta")):
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_process(false)
		return
	var giro := Input.get_axis(&"mover_esq", &"mover_dir")
	if absf(giro) > 0.05:
		_giro += giro * delta * 2.4
	if _corpo != null:
		_corpo.rotation.y = _giro
		_corpo.animar(0.0, delta)
	queue_redraw()


func dicas() -> Array:
	return [["A D", "GIRAR"]]


func _draw() -> void:
	var r := Rect2(area.position, RETRATO)
	# Fundo do retrato: degrade escuro, o boneco em cima (fundo transparente).
	HudTema.painel(self, r, 0.95, 3.0)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)]),
		PackedColorArray([Color("2a3136"), Color("2a3136"), Color("101416"), Color("101416")]))
	draw_texture_rect(_vp.get_texture(), r, false)
	var borda := HudTema.cantos(r, 3.0)
	borda.append(borda[0])
	draw_polyline(borda, Color(1.0, 1.0, 1.0, 0.14), 0.5, true)

	var ficha := RegistroCivil.jogador
	var x := r.end.x + 16.0
	var w := area.end.x - x
	var y := area.position.y
	var ft := HudTema.fonte(700, 1)
	var f := HudTema.regular()
	var fs := HudTema.semi()
	var h := HudTema.altura(f, HudTema.T_CORPO)
	var nome := String(ficha.get("nome", "SEM NOME")).to_upper()
	HudTema.texto(self, ft, Vector2(x, y), HudTema.encurtar(ft, nome, HudTema.T_DESTAQUE, w),
		HudTema.T_DESTAQUE, HudTema.TEXTO)
	y += HudTema.altura(ft, HudTema.T_DESTAQUE)
	var sub := "%s  ·  %s anos" % [String(ficha.get("profissao", "")).to_upper(), str(ficha.get("idade", "?"))]
	HudTema.texto(self, HudTema.rotulo(), Vector2(x, y), sub, HudTema.T_ROTULO, HudTema.acento())
	y += h + 8.0
	# Ficha em duas colunas.
	var campos := [["CPF", "cpf"], ["RG", "rg"], ["NASCIMENTO", "nascimento"],
		["NATURALIDADE", "naturalidade"], ["ENDERECO", "endereco"]]
	for c: Array in campos:
		var valor := String(ficha.get(c[1], "—"))
		HudTema.texto(self, HudTema.rotulo(), Vector2(x, y), String(c[0]), HudTema.T_MICRO,
			HudTema.fraco())
		HudTema.texto(self, f, Vector2(x + 62.0, y - 1.0), HudTema.encurtar(f, valor, HudTema.T_CORPO,
			w - 62.0), HudTema.T_CORPO, HudTema.TEXTO)
		y += h + 1.0
	y += 6.0
	# Estado e dinheiro.
	y += secao(Vector2(x, y), "ESTADO", w)
	var vida := float(Inventario.vida) / float(maxi(1, Inventario.vida_maxima))
	var cor_vida := HudTema.PERIGO if vida <= 0.4 else (HudTema.ALERTA if vida <= 0.75 else HudTema.OK)
	HudTema.texto(self, fs, Vector2(x, y), String(Inventario.estado()), HudTema.T_CORPO, cor_vida)
	HudTema.barra(self, Rect2(x + 60.0, y + h * 0.5 - 1.5, w - 60.0, 3.0), vida, cor_vida)
	y += h + 2.0
	if BlitzNoCaminho.procurado():
		var t := "PROCURADO PELA BLITZ"
		var wt := HudTema.largura(HudTema.rotulo(), t, HudTema.T_ROTULO) + 8.0
		HudTema.poligono(self, HudTema.cantos(Rect2(x, y, wt, h), 1.5), HudTema.PERIGO)
		HudTema.texto(self, HudTema.rotulo(), Vector2(x + 4.0, y + 1.0), t, HudTema.T_ROTULO, Color.WHITE)
		y += h + 4.0
	y += 4.0
	y += secao(Vector2(x, y), "DINHEIRO  ·  %s" % Dinheiro.formatar(Dinheiro.saldo()), w)
	var extrato: Array = Dinheiro.extrato()
	var n := 0
	for i in range(extrato.size() - 1, -1, -1):
		if y > area.end.y - h or n >= 4:
			break
		var e: Dictionary = extrato[i]
		var valor := int(e.get("valor", 0))
		var motivo := String(e.get("motivo", ""))
		var vt := ("+" if valor >= 0 else "-") + Dinheiro.formatar(absi(valor))
		HudTema.texto(self, f, Vector2(x, y), HudTema.encurtar(f, motivo, HudTema.T_ROTULO, w - 60.0),
			HudTema.T_ROTULO, HudTema.fraco())
		var wv := HudTema.largura(fs, vt, HudTema.T_ROTULO)
		HudTema.texto(self, fs, Vector2(area.end.x - wv, y), vt, HudTema.T_ROTULO,
			HudTema.OK if valor >= 0 else HudTema.PERIGO)
		y += h
		n += 1
	if extrato.is_empty():
		HudTema.texto(self, f, Vector2(x, y), "Nenhum movimento ainda.", HudTema.T_ROTULO,
			HudTema.fraco())
