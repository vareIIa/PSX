## O iWeed na tela: notificacao do aparelho e o cartao da entrega do jogador.
##
## A notificacao desce do topo, no meio, como a de um telefone: quem pediu, o
## que e quanto paga, ou quem da equipe pegou e entregou. O cartao fica no canto
## de baixo, a esquerda, longe do minimapa e da tira de lugar: para quem, o que,
## onde, a que distancia e quanto tempo falta — e se o que esta no bolso cobre o
## pedido, que e a pergunta que o jogador faria antes de sair andando.
##
## Vetor, na gramatica da conversa (RE7): coordenadas de 480x270 e o
## `canvas_items` rasteriza na resolucao da janela.
class_name HudIWeed
extends CanvasLayer

const TELA := Vector2(480.0, 270.0)
const TOAST := Vector2(HudLayout.IWEED_TOAST_LARGURA, 31.0)
## Linhas de texto de uma notificacao. Na largura do vao do HUD a frase comum
## ("FULANO quer 2x Prensado no Beco do Ze. Paga R$ 60.") pede tres.
const LINHAS_MAX := 3
const T_ENTRA := 0.28
const T_FICA := 4.2
## Acima dos vitais do rodape; `HudLayout` confere que nao cruza nada.
const CARTAO := HudLayout.IWEED_CARTAO

# Paleta do HUD (`HudTema`): o cartao e a notificacao do iWeed falavam o RE7 de
# antes, e ficavam um tom mais frio que o resto da tela. O verde do app fica.
const COR_TEXTO := HudTema.TEXTO
const COR_TITULO := HudTema.TEXTO
const COR_FRACA := HudTema.TEXTO_FRACO
const VERDE := HudTema.OK
const LARANJA := HudTema.ALERTA
const VERMELHO := HudTema.PERIGO

var _tela: Control
var _f_reg: Font
var _f_semi: Font
var _fila: Array[Dictionary] = []
var _atual: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hud_iweed")
	_f_reg = UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_REGULAR)
	_f_semi = UiEstilo.fonte_re7(UiEstilo.RE7_WEIGHT_SEMIBOLD)
	_tela = Control.new()
	_tela.name = "IWeedHud"
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tela)
	_tela.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tela.draw.connect(_desenhar)
	_ligar.call_deferred()


func _ligar() -> void:
	var iw := IWeed.instancia()
	if iw != null and not iw.notificacao.is_connected(notificar):
		iw.notificacao.connect(notificar)


## Publica: qualquer sistema pode por uma notificacao na fila.
func notificar(titulo: String, texto: String, cor: Color) -> void:
	_fila.append({"titulo": titulo, "texto": texto, "cor": cor, "t": 0.0})


func notificacoes_na_tela() -> int:
	return _atual.size()


func _process(delta: float) -> void:
	_t += delta
	# Duas de cada vez. A terceira espera: tres cartoes empilhados no topo
	# cobririam a rua que o jogador esta olhando.
	while _atual.size() < 2 and not _fila.is_empty():
		_atual.append(_fila.pop_front())
		AudioDirector.tocar_ui(&"celular_ok", -10.0)
	for k in range(_atual.size() - 1, -1, -1):
		_atual[k]["t"] = float(_atual[k]["t"]) + delta
		if float(_atual[k]["t"]) > T_FICA + T_ENTRA * 2.0:
			_atual.remove_at(k)
	_tela.queue_redraw()


# --- desenho ------------------------------------------------------------------

static func _alfa(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func _cantos(r: Rect2, raio: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [Vector2(r.end.x - raio, r.position.y + raio),
		Vector2(r.end.x - raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.end.y - raio),
		Vector2(r.position.x + raio, r.position.y + raio)]
	for k in 4:
		var a0 := -PI * 0.5 + float(k) * PI * 0.5
		for s in 5:
			var a := a0 + float(s) / 4.0 * PI * 0.5
			pts.append(cs[k] + Vector2(cos(a), sin(a)) * raio)
	return pts


## O painel do HUD: sombra suave, borda fina e o contraste das opcoes.
func _painel(r: Rect2, a: float) -> void:
	HudTema.painel(_tela, r, a, 3.0)


## `p` e a linha de base. Com a sombra do HUD por baixo: branco sobre painel
## translucido em nevoa clara precisa dela tanto quanto o texto solto.
func _texto(p: Vector2, t: String, tam: int, cor: Color, fonte: Font = null,
		largura: float = -1.0, alin := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := fonte if fonte != null else _f_reg
	_tela.draw_string(f, p + HudTema.SOMBRA_DESVIO, t, alin, largura, tam,
		_alfa(HudTema.SOMBRA, cor.a))
	_tela.draw_string(f, p, t, alin, largura, tam, cor)


func _quebrar(texto: String, tam: int, largura: float) -> Array[String]:
	var saida: Array[String] = []
	var linha := ""
	for palavra: String in texto.split(" ", false):
		var tenta := palavra if linha.is_empty() else linha + " " + palavra
		if _f_reg.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= largura \
				or linha.is_empty():
			linha = tenta
		else:
			saida.append(linha)
			linha = palavra
	if not linha.is_empty():
		saida.append(linha)
	return saida


func _cortar(t: String, tam: int, largura: float, fonte: Font) -> String:
	if fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= largura:
		return t
	var s := t
	while s.length() > 1 and fonte.get_string_size(s + "...", HORIZONTAL_ALIGNMENT_LEFT,
			-1, tam).x > largura:
		s = s.substr(0, s.length() - 1)
	return s + "..."


## O icone do app: folha verde num quadrado de canto redondo.
func _icone_app(c: Vector2, lado: float, a: float) -> void:
	var r := Rect2(c - Vector2(lado, lado) * 0.5, Vector2(lado, lado))
	_tela.draw_colored_polygon(_cantos(r, lado * 0.24), _alfa(Color("153d24"), a))
	AppCelular.folha(_tela, c, lado * 0.36, _alfa(VERDE, a))


func _desenhar() -> void:
	if not HudConfig.ver(&"iweed"):
		return
	# Mesma OPACIDADE das opcoes que o resto do HUD.
	_tela.modulate.a = HudConfig.alfa()
	if Celular.ativo or Gps.ativo:
		return
	for k in _atual.size():
		_desenhar_toast(_atual[k], k)
	if not Conversa.ativo and not Interiores.dentro:
		_desenhar_cartao()


func _desenhar_toast(n: Dictionary, k: int) -> void:
	var t := float(n["t"])
	var entra := clampf(t / T_ENTRA, 0.0, 1.0)
	var sai := clampf((t - T_FICA - T_ENTRA) / T_ENTRA, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - entra, 3.0)
	var a := e * (1.0 - sai)
	# Desce ate embaixo da bussola do HUD, e nao ate o topo da tela.
	var y := -TOAST.y + (HudLayout.IWEED_TOPO + TOAST.y) * e - sai * 10.0 \
		+ float(k) * (TOAST.y + 9.0 * float(LINHAS_MAX - 1) + 4.0)
	# Com a conversa aberta, a tarja de cinema cobre o topo: desce junto.
	if Conversa.ativo:
		y += 16.0
	# Duas linhas quando o texto nao cabe: "FULANO te entregou. Tem blitz por
	# perto" era cortado no meio da palavra.
	var largura_texto := TOAST.x - 34.0
	var linhas := _quebrar(String(n["texto"]), 8, largura_texto)
	var alto := TOAST.y + 9.0 * float(clampi(linhas.size(), 1, LINHAS_MAX) - 1)
	var x := (TELA.x - TOAST.x) * 0.5
	# Com a conversa aberta a lista de assuntos ocupa a direita: a notificacao
	# vai para a esquerda, e nao por cima dela.
	if Conversa.ativo:
		x = 16.0
	var r := Rect2(Vector2(x, y), Vector2(TOAST.x, alto))
	_painel(r, a)
	var cor: Color = n["cor"]
	_tela.draw_rect(Rect2(r.position.x + 1.0, r.position.y + 5.0, 1.4, r.size.y - 10.0),
		_alfa(cor, a))
	_icone_app(r.position + Vector2(15.0, r.size.y * 0.5), 15.0, a)
	_texto(r.position + Vector2(28.0, 12.0), "iWeed", 6, _alfa(COR_FRACA, a), _f_semi)
	var w_app := _f_semi.get_string_size("iWeed", HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	_texto(r.position + Vector2(31.0 + w_app, 12.0), _cortar(String(n["titulo"]), 7,
		r.size.x - 60.0 - w_app, _f_semi), 7, _alfa(cor, a), _f_semi)
	_texto(Vector2(r.end.x - 34.0, r.position.y + 12.0), "agora", 6, _alfa(COR_FRACA, a),
		_f_reg, 28.0, HORIZONTAL_ALIGNMENT_RIGHT)
	for q in mini(LINHAS_MAX, linhas.size()):
		var linha := linhas[q]
		if q == LINHAS_MAX - 1 and linhas.size() > LINHAS_MAX:
			linha = _cortar(" ".join(PackedStringArray(linhas.slice(q))), 8, largura_texto, _f_reg)
		_texto(r.position + Vector2(28.0, 23.5 + float(q) * 9.0), linha, 8, _alfa(COR_TEXTO, a))


func _desenhar_cartao() -> void:
	var p := IWeed.proxima_do_jogador()
	if p.is_empty():
		return
	var r := CARTAO
	_painel(r, 1.0)
	var t := IWeed.agora()
	var inicio := float(p["inicio"])
	var fim := float(p["fim"])
	var antes := t < inicio
	var resta := (fim - t) / maxf(0.01, fim - inicio)
	var cor := VERDE if antes or resta > 0.5 else (LARANJA if resta > 0.2 else VERMELHO)
	if not antes and resta <= 0.2 and fmod(_t, 0.8) < 0.4:
		cor = _alfa(cor, 0.55)

	_icone_app(r.position + Vector2(10.0, 10.0), 10.0, 1.0)
	_texto(r.position + Vector2(19.0, 12.5), "ENTREGA", 6, COR_FRACA, _f_semi)
	var prazo := ("EM %s" % IWeed.falta(inicio)) if antes \
		else ("RESTAM %s" % IWeed.falta(fim))
	_texto(Vector2(r.end.x - 70.0, r.position.y + 12.5), prazo, 7, cor, _f_semi, 63.0,
		HORIZONTAL_ALIGNMENT_RIGHT)

	var cliente := IWeed.nome_curto(int(p["cliente"])).to_upper()
	_texto(r.position + Vector2(7.0, 24.5), _cortar(cliente, 9, 88.0, _f_semi), 9,
		COR_TITULO, _f_semi)
	# O pedido e o que esta no bolso, lado a lado. Laranja quando nao cobre.
	var produto := String(p["produto"])
	var qtd := int(p["qtd"])
	var item: StringName = IWeed.PRODUTOS[produto]["item"]
	var tem := Inventario.quantidade(item)
	var pedido := "%dx %s" % [qtd, IWeed.nome_do_produto(produto)]
	var cor_pedido := VERDE if tem >= qtd else LARANJA
	_texto(Vector2(r.end.x - 72.0, r.position.y + 24.5), pedido, 7, cor_pedido, _f_semi,
		65.0, HORIZONTAL_ALIGNMENT_RIGHT)

	var lugar := "%s  %s" % [String(p["lugar"]), String(p.get("rua", ""))]
	_texto(r.position + Vector2(7.0, 35.0), _cortar(lugar.strip_edges(), 7, 104.0, _f_reg),
		7, COR_FRACA)
	_texto(Vector2(r.end.x - 72.0, r.position.y + 35.0), "NO BOLSO %d/%d" % [mini(tem, 99), qtd],
		6, cor_pedido if tem < qtd else COR_FRACA, _f_semi, 65.0, HORIZONTAL_ALIGNMENT_RIGHT)

	# Distancia e seta relativa a camera: a pergunta "para que lado?" respondida
	# sem abrir o mapa.
	var jogador := get_tree().get_first_node_in_group(&"player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if jogador != null and cam != null:
		var onde := IWeed.ponto(p)
		var d := Vector2(onde.x - jogador.global_position.x, onde.z - jogador.global_position.z)
		var frente := -cam.global_transform.basis.z
		var ang := Vector2(frente.x, frente.z).angle_to(d)
		var c := r.position + Vector2(12.0, 44.5)
		var dir := Vector2(0.0, -1.0).rotated(ang)
		var lado := Vector2(dir.y, -dir.x)
		_tela.draw_colored_polygon(PackedVector2Array([c + dir * 4.2,
			c - dir * 3.0 + lado * 3.0, c - dir * 1.4, c - dir * 3.0 - lado * 3.0]), cor)
		var metros := d.length()
		var texto := ("%d m" % roundi(metros)) if metros < 1000.0 \
			else ("%.1f km" % (metros / 1000.0))
		if metros < 3.0:
			texto = "AQUI"
		_texto(r.position + Vector2(19.0, 47.0), texto, 8, COR_TITULO, _f_semi)
		_texto(r.position + Vector2(56.0, 47.0), "%s - %s" % [IWeed.hora(inicio),
			IWeed.hora(fim)], 7, COR_FRACA, _f_reg)

	# Barra do prazo na borda de baixo: cheia no comeco da janela, vazia no fim.
	var barra := Rect2(r.position.x + 5.0, r.end.y - 3.0, r.size.x - 10.0, 1.2)
	_tela.draw_rect(barra, Color(1.0, 1.0, 1.0, 0.08))
	var cheia := 1.0 if antes else clampf(resta, 0.0, 1.0)
	_tela.draw_rect(Rect2(barra.position, Vector2(barra.size.x * cheia, barra.size.y)), cor)
