## Tudo o que ACONTECE, em contraste com o que E: avisos, banners e alarmes.
##
##   avisos    coluna da direita, embaixo do lugar. Item recebido (com o icone
##             do item), bolsa cheia, dinheiro entrando e saindo.
##   banner    centro de cima. Missao nova, missao cumprida, bairro novo.
##   radio     legenda curta embaixo da bussola quando a estacao muda (GTA).
##   vida      vinheta vermelha pulsando nas bordas abaixo de 30%.
##
## Por que isto nao e o toast do iWeed
## -----------------------------------
## Porque o do iWeed e uma notificacao DO APARELHO — desce do topo como a de um
## telefone, com o icone do app — e continua sendo. Aqui e o jogo falando: o
## que entrou na bolsa nao chegou pelo celular.
##
## Os sinais ja existiam e ninguem escutava: `Inventario.item_recebido` e
## `espaco_insuficiente` foram escritos para isto e ficaram sem ouvinte.
class_name HudAvisos
extends Control

const T_AVISO := 3.6
const T_BANNER := 3.4
const T_RADIO := 2.6
const VIDA_ALARME := 0.3

var _avisos: Array[Dictionary] = []
var _banner: Dictionary = {}
var _fila_banner: Array[Dictionary] = []
var _radio: Dictionary = {}
var _saldo := 0
var _vida := 1.0
var _t := 0.0
var com_radar := true
## Escala do HUD, e o que aparece. Postos pelo `HudAAA`.
var escala := 1.0
var ver_avisos := true
var ver_banners := true
## Quantos avisos desenhar. Ao dirigir o mostrador do carro ocupa o pe da coluna
## e o `HudAAA` baixa este numero; os que nao cabem esperam na fila.
var maximo := HudLayout.AVISOS_MAX
## Segundos iniciais em que item recebido nao vira aviso. O novo jogo e o save
## carregado enchem a bolsa de uma vez; anunciar o kit inicial sao quatro
## cartoes dizendo o que o jogador ja tinha.
var _silencio := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Inventario.item_recebido.connect(_ao_receber)
	Inventario.espaco_insuficiente.connect(_ao_faltar_espaco)
	Inventario.vida_mudou.connect(func(a: int, m: int) -> void:
		_vida = float(a) / float(maxi(1, m)))
	_vida = float(Inventario.vida) / float(maxi(1, Inventario.vida_maxima))
	_saldo = Dinheiro.saldo()
	WorldState.mudou.connect(_ao_mudar_mundo)
	Missoes.iniciou.connect(func(m: Dictionary) -> void:
		banner("NOVA MISSAO", String(m.get("titulo", "")), HudTema.acento()))
	Missoes.concluiu.connect(func(m: Dictionary) -> void:
		banner("MISSAO CUMPRIDA", String(m.get("titulo", "")), HudTema.OK))
	RadioCarro.estacao_mudou.connect(_ao_mudar_estacao)


# --- entradas -------------------------------------------------------------------

func aviso(titulo: String, sub: String, cor: Color, icone: Texture2D = null,
		qtd: int = 0) -> void:
	# O mesmo aviso de novo renova o que esta na tela em vez de empilhar outro.
	for av: Dictionary in _avisos:
		if String(av["chave"]) == titulo and float(av["t"]) < T_AVISO - 0.4:
			av["sub"] = sub
			av["t"] = minf(float(av["t"]), 0.3)
			return
	_avisos.push_front({"titulo": titulo, "sub": sub, "cor": cor, "icone": icone,
		"t": 0.0, "chave": titulo, "qtd": qtd})
	while _avisos.size() > HudLayout.AVISOS_MAX:
		_avisos.pop_back()


## Rearma o silencio. O HUD chama ao voltar para a tela (saida do titulo,
## carga de save): o que entra na bolsa nesse instante e estado, e nao evento.
func silenciar(segundos: float = 3.0) -> void:
	_silencio = maxf(_silencio, segundos)
	_saldo = Dinheiro.saldo()


func banner(titulo: String, sub: String, cor: Color) -> void:
	var b := {"titulo": titulo, "sub": sub, "cor": cor, "t": 0.0}
	if _banner.is_empty():
		_banner = b
	else:
		_fila_banner.append(b)


func _ao_receber(item: Item, qtd: int) -> void:
	if item == null or qtd <= 0 or _silencio > 0.0:
		return
	# Tres pilhas seguidas viram "+3", e nao tres cartoes iguais.
	for av: Dictionary in _avisos:
		if String(av["chave"]) == item.nome and float(av["t"]) < T_AVISO - 0.4:
			av["qtd"] = int(av["qtd"]) + qtd
			av["sub"] = "+%d" % int(av["qtd"])
			av["t"] = minf(float(av["t"]), 0.3)
			return
	aviso(item.nome, "+%d" % qtd, HudTema.TEXTO, item.icone, qtd)
	AudioDirector.tocar_ui(&"papel", -20.0)


func _ao_faltar_espaco(item: Item) -> void:
	aviso("BOLSA CHEIA", item.nome if item != null else "", HudTema.ALERTA)


func _ao_mudar_mundo(coord: Vector2i, chave: StringName, valor: Variant) -> void:
	if coord != Dinheiro.COORD or chave != &"saldo":
		return
	var novo := int(valor)
	var delta := novo - _saldo
	_saldo = novo
	if delta == 0 or _silencio > 0.0:
		return
	var sinal := "+" if delta > 0 else "-"
	aviso("%s%s" % [sinal, Dinheiro.formatar(absi(delta))], "saldo " + Dinheiro.formatar(novo),
		HudTema.OK if delta > 0 else HudTema.PERIGO)


func _ao_mudar_estacao(indice: int) -> void:
	# Com o seletor aberto o nome ja esta na tela dele.
	if RadioCarro.aberta():
		return
	if indice < 0 or indice >= RadioCarro.ESTACOES.size():
		_radio = {"nome": "RADIO DESLIGADO", "dial": "", "cor": HudTema.fraco(), "t": 0.0}
		return
	var e: Dictionary = RadioCarro.ESTACOES[indice]
	_radio = {"nome": String(e["nome"]), "dial": "%s  ·  %s" % [e["dial"], e["genero"]],
		"cor": e["cor"], "t": 0.0}


# --- tempo ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_silencio -= delta
	for k in range(_avisos.size() - 1, -1, -1):
		_avisos[k]["t"] = float(_avisos[k]["t"]) + delta
		if float(_avisos[k]["t"]) > T_AVISO:
			_avisos.remove_at(k)
	# O banner espera a notificacao do iWeed sair: os dois no meio de cima da
	# tela ao mesmo tempo se cobriam. Ja comecado, ele termina.
	if not _banner.is_empty() and (float(_banner["t"]) > 0.0 or not _iweed_na_tela()):
		_banner["t"] = float(_banner["t"]) + delta
		if float(_banner["t"]) > T_BANNER:
			_banner = {} if _fila_banner.is_empty() else _fila_banner.pop_front()
	if not _radio.is_empty():
		_radio["t"] = float(_radio["t"]) + delta
		if float(_radio["t"]) > T_RADIO:
			_radio = {}
	queue_redraw()


## Entra, fica, sai: alfa de 0..1 para um relogio `t` numa janela de `total`.
static func _envelope(t: float, total: float) -> float:
	var entra := HudTema.saida_cubica(t / HudTema.T_ENTRA)
	var sai := clampf((total - t) / HudTema.T_SAI, 0.0, 1.0)
	return minf(entra, sai)


# --- desenho --------------------------------------------------------------------

func _draw() -> void:
	if HudConfig.alarme():
		_desenhar_vida()
	if ver_avisos:
		_desenhar_avisos()
	if ver_banners:
		_desenhar_banner()
		_desenhar_radio()


func _desenhar_vida() -> void:
	if _vida > VIDA_ALARME or _vida <= 0.0:
		return
	var forca := (1.0 - _vida / VIDA_ALARME) * 0.5 + 0.25
	var a := forca * (0.65 + 0.35 * sin(_t * 4.2))
	var tela := HudLayout.TELA
	var borda := 46.0
	var cheio := Color(0.55, 0.03, 0.02, a)
	var vazio := Color(0.55, 0.03, 0.02, 0.0)
	# Quatro faixas em degradê, cada uma do lado de fora para dentro.
	for f: Array in [
			[Vector2.ZERO, Vector2(tela.x, 0.0), Vector2(tela.x, borda), Vector2(0.0, borda)],
			[Vector2(0.0, tela.y), Vector2(tela.x, tela.y), Vector2(tela.x, tela.y - borda),
				Vector2(0.0, tela.y - borda)],
			[Vector2.ZERO, Vector2(0.0, tela.y), Vector2(borda, tela.y), Vector2(borda, 0.0)],
			[Vector2(tela.x, 0.0), Vector2(tela.x, tela.y), Vector2(tela.x - borda, tela.y),
				Vector2(tela.x - borda, 0.0)]]:
		draw_polygon(PackedVector2Array(f), PackedColorArray([cheio, cheio, vazio, vazio]))


func _desenhar_avisos() -> void:
	var f_rot := HudTema.rotulo()
	var f_semi := HudTema.semi()
	for i in mini(_avisos.size(), maximo):
		var av: Dictionary = _avisos[i]
		var a := _envelope(float(av["t"]), T_AVISO)
		# O aviso e desenhado em coordenada propria (0,0 no canto dele) e a escala
		# entra pela transformacao: a largura na tela fica fixa, o resto cresce.
		var na_tela := HudLayout.aviso_rect(i, com_radar, escala)
		draw_set_transform(na_tela.position + Vector2((1.0 - a) * 16.0, 0.0), 0.0,
			Vector2(escala, escala))
		var r := Rect2(Vector2.ZERO, Vector2(HudLayout.largura_logica(na_tela.size.x, escala),
			HudLayout.AVISO.y))
		HudTema.painel(self, r, a * 0.9)
		var cor: Color = av["cor"]
		draw_rect(Rect2(r.position + Vector2(0.0, 3.0), Vector2(1.5, r.size.y - 6.0)),
			HudTema.alfa(cor, a))
		var x := r.position.x + 6.0
		var icone: Texture2D = av["icone"]
		if icone != null:
			var lado := r.size.y - 6.0
			draw_texture_rect(icone, Rect2(Vector2(x, r.position.y + 3.0), Vector2(lado, lado)),
				false, Color(1.0, 1.0, 1.0, a))
			x += lado + 4.0
		var util := r.end.x - 5.0 - x
		var titulo := HudTema.encurtar(f_rot, String(av["titulo"]).to_upper(),
			HudTema.T_ROTULO, util - 16.0)
		HudTema.texto(self, f_rot, Vector2(x, r.position.y + 2.5), titulo, HudTema.T_ROTULO,
			HudTema.alfa(cor if icone == null else HudTema.TEXTO, a))
		var sub := String(av["sub"])
		if not sub.is_empty():
			var em_linha := icone != null
			if em_linha:
				# "+2" a direita, como contador.
				HudTema.texto(self, f_semi, Vector2(r.end.x - 5.0 - 30.0, r.position.y + 2.5),
					sub, HudTema.T_ROTULO, HudTema.alfa(HudTema.OK, a), 30.0,
					HORIZONTAL_ALIGNMENT_RIGHT)
			else:
				HudTema.texto(self, HudTema.regular(), Vector2(x, r.position.y + 10.5),
					HudTema.encurtar(HudTema.regular(), sub, HudTema.T_MICRO, util),
					HudTema.T_MICRO, HudTema.alfa(HudTema.fraco(), a))
	draw_set_transform(Vector2.ZERO)


func _iweed_na_tela() -> bool:
	var iw := get_tree().get_first_node_in_group(&"hud_iweed")
	return iw != null and HudConfig.ver(&"iweed") and int(iw.call(&"notificacoes_na_tela")) > 0


func _desenhar_banner() -> void:
	if _banner.is_empty() or float(_banner["t"]) <= 0.0:
		return
	var a := _envelope(float(_banner["t"]), T_BANNER)
	var r := HudLayout.banner_rect(escala)
	var meio := r.get_center().x
	var cor: Color = _banner["cor"]
	var f_titulo := HudTema.fonte(700, 2)
	var titulo := String(_banner["titulo"])
	var tam := HudLayout.tamanho_banner(titulo)
	var w := HudTema.largura(f_titulo, titulo, tam)
	# Faixa escura que abre do meio para os lados: o banner entra como um corte
	# de cinema, e nao como uma janela.
	var abre := HudTema.saida_cubica(float(_banner["t"]) / 0.4)
	var faixa_w := (w + 90.0) * abre
	var faixa := Rect2(meio - faixa_w * 0.5, r.position.y + 4.0, faixa_w, 34.0)
	for lado: float in [-1.0, 1.0]:
		var borda := meio + lado * faixa_w * 0.5
		draw_polygon(PackedVector2Array([Vector2(meio, faixa.position.y),
				Vector2(borda, faixa.position.y), Vector2(borda, faixa.end.y),
				Vector2(meio, faixa.end.y)]),
			PackedColorArray([Color(0, 0, 0, 0.6 * a), Color(0, 0, 0, 0.0),
				Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.6 * a)]))
	draw_rect(Rect2(meio - faixa_w * 0.3, faixa.position.y, faixa_w * 0.6, 0.6),
		HudTema.alfa(cor, a * 0.9))
	draw_rect(Rect2(meio - faixa_w * 0.3, faixa.end.y - 0.6, faixa_w * 0.6, 0.6),
		HudTema.alfa(cor, a * 0.9))
	HudTema.texto(self, f_titulo, Vector2(meio - w * 0.5, faixa.position.y + 4.0), titulo, tam,
		HudTema.alfa(cor, a))
	var sub := String(_banner["sub"]).to_upper()
	if not sub.is_empty():
		var f_sub := HudTema.rotulo()
		var ws := HudTema.largura(f_sub, sub, HudTema.T_ROTULO)
		HudTema.texto(self, f_sub, Vector2(meio - ws * 0.5, faixa.position.y + 23.0), sub,
			HudTema.T_ROTULO, HudTema.alfa(HudTema.TEXTO, a))


func _desenhar_radio() -> void:
	if _radio.is_empty():
		return
	var a := _envelope(float(_radio["t"]), T_RADIO)
	var meio := HudLayout.TELA.x * 0.5
	var y := HudLayout.M + (HudLayout.BUSSOLA.size.y + HudLayout.GPS_ALTURA) * escala + 4.0
	var f := HudTema.fonte(700, 1)
	var nome := String(_radio["nome"])
	var w := HudTema.largura(f, nome, HudTema.T_TITULO)
	HudTema.texto(self, f, Vector2(meio - w * 0.5, y), nome, HudTema.T_TITULO,
		HudTema.alfa(_radio["cor"], a))
	var dial := String(_radio["dial"])
	if not dial.is_empty():
		var fr := HudTema.regular()
		var wd := HudTema.largura(fr, dial, HudTema.T_MICRO)
		HudTema.texto(self, fr, Vector2(meio - wd * 0.5, y + 13.0), dial, HudTema.T_MICRO,
			HudTema.alfa(HudTema.fraco(), a))
