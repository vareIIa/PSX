## Rastreador de objetivo, em cima a esquerda. O sucessor do cartao de papel.
##
## O que ele diz, de cima para baixo
## ---------------------------------
##     A CASA DA FUMACA                       1/2    <- missao e etapa
##     Va ate a casa da fumaca.                      <- o que fazer AGORA
##     <> 270 m                                      <- quanto falta
##     [M] abre o GPS  [E] traca a rota              <- so nos primeiros 12 s
##
## O que mudou em relacao ao papel
## -------------------------------
## - Nao some dentro de casa. O cartao saia porque a distancia nao existe dentro
##   de um comodo; mas o objetivo existe ("fale com o dono" e dito DENTRO da
##   casa). Some so a linha de distancia.
## - Nao encolhe para tira sem o objetivo. Recolhe a dica e fica com as tres
##   linhas que importam, como Cyberpunk e RDR2: o objetivo lido nao vira
##   ruido, vira referencia de canto de olho.
## - A dica desenha as teclas. "[E]" como texto le como log; tecla desenhada le
##   como instrucao, e troca para o botao do controle quando o jogador pega um.
## - Etapa nova pisca o acento e escreve "NOVO OBJETIVO" por um instante: o
##   jogador tem de notar que a frase de cima MUDOU, e nao so que ela esta la.
class_name HudObjetivo
extends Control

## Quanto dura o brilho de etapa nova.
const T_NOVO := 2.2

var _dados: Dictionary = {}
var _com_dica := true
var _plano: Dictionary = {}
var _aberto := 0.0
var _visivel := false
var _t_leitura := 0.0
var _t_novo := 0.0
var _concluido := false
var _t_concluido := 0.0
var _jogador: Node3D
var _ultima_dist := ""
## Escala do HUD, posta pelo `HudAAA`. O rastreador mantem a largura na tela.
var escala := 1.0
var _plano_escala := 1.0
var _plano_dica := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Missoes.iniciou.connect(_ao_mudar)
	Missoes.avancou.connect(_ao_mudar)
	Missoes.concluiu.connect(_ao_concluir)
	var ctl := _controle()
	if ctl != null:
		ctl.dispositivo_mudou.connect(func(_q: int) -> void: queue_redraw())
	if not Missoes.atual.is_empty():
		_ao_mudar(Missoes.atual)


static func _controle() -> Controle:
	return Settings.get(&"controle") as Controle


func _ao_mudar(missao: Dictionary) -> void:
	var etapa := Missoes.etapa_atual()
	if etapa.is_empty():
		return
	var etapas: Array = missao.get("etapas", [])
	var i := int(missao.get("etapa", 0))
	_dados = {
		"titulo": String(missao.get("titulo", "")),
		"etapa": "%d/%d" % [i + 1, etapas.size()] if etapas.size() > 1 else "",
		"objetivo": String(etapa.get("texto", "")),
		"dica": String(etapa.get("dica", "")),
		"distancia": "",
	}
	_ultima_dist = ""
	_concluido = false
	_com_dica = true
	_visivel = true
	_t_leitura = HudTema.T_LEITURA
	_t_novo = T_NOVO
	_replanejar()
	AudioDirector.tocar_ui(&"papel", -18.0)


func _ao_concluir(_missao: Dictionary) -> void:
	_concluido = true
	_t_concluido = 2.6
	_com_dica = false
	_dados["distancia"] = ""
	_replanejar()


## Recolhe a dica agora. A captura usa: o estado recolhido e o que o jogador ve
## a maior parte do tempo, e esperar doze segundos num `--shot-frame` nao da.
func encolher_agora() -> void:
	_t_leitura = 0.0
	if _com_dica:
		_com_dica = false
		_replanejar()


func _largura() -> float:
	return HudLayout.largura_logica(HudLayout.OBJETIVO_LARGURA, escala)


func _replanejar() -> void:
	_plano_escala = escala
	_plano_dica = HudConfig.com_dica()
	_plano = HudLayout.objetivo(_dados, _com_dica and _plano_dica, _largura())
	queue_redraw()


func _process(delta: float) -> void:
	var quer := 1.0 if _visivel else 0.0
	var antes := _aberto
	_aberto = move_toward(_aberto, quer, delta / (HudTema.T_ENTRA if _visivel else HudTema.T_SAI))
	var mexeu := not is_equal_approx(antes, _aberto)
	if _t_novo > 0.0:
		_t_novo -= delta
		mexeu = true
	if _t_leitura > 0.0:
		_t_leitura -= delta
		# O ultimo segundo apaga a dica em vez de corta-la.
		mexeu = mexeu or _t_leitura < 1.0
		if _t_leitura <= 0.0 and _com_dica:
			_com_dica = false
			_replanejar()
	if _concluido:
		_t_concluido -= delta
		if _t_concluido <= 0.0 and _visivel:
			_visivel = false
			mexeu = true
	if _visivel and not _concluido:
		mexeu = _atualizar_distancia() or mexeu
	# Opcao mudou com o jogo aberto (tamanho, dica de teclas): reempilha.
	if not is_equal_approx(_plano_escala, escala) or _plano_dica != HudConfig.com_dica():
		_replanejar()
	if mexeu:
		queue_redraw()


func _atualizar_distancia() -> bool:
	var texto := ""
	var alvo := Missoes.posicao_do_alvo()
	if alvo != Vector3.INF and not Interiores.dentro:
		if _jogador == null or not is_instance_valid(_jogador):
			_jogador = get_tree().get_first_node_in_group(&"player") as Node3D
		if _jogador != null:
			var p := _jogador.global_position
			texto = HudTema.distancia(Vector2(alvo.x - p.x, alvo.z - p.z).length())
	if texto == _ultima_dist:
		return false
	_ultima_dist = texto
	_dados["distancia"] = texto
	_replanejar()
	return true


func _draw() -> void:
	if _plano.is_empty() or _aberto <= 0.0:
		return
	var a := HudTema.saida_cubica(_aberto)
	var o := Vector2(HudLayout.M - (1.0 - a) * 24.0, HudLayout.M)
	var altura := float(_plano["altura"])

	# Veu que nasce da borda, cobre a coluna inteira — a tecla da dica e o "1/3"
	# tambem pousam em fundo — e so esfuma depois dela.
	var cheio := o.x + _largura() + HudLayout.OBJETIVO_FOLGA
	HudTema.veu_horizontal(self, Rect2(Vector2(0.0, o.y - HudLayout.OBJETIVO_PENA),
		Vector2(cheio + HudLayout.OBJETIVO_ESFUMA, altura + HudLayout.OBJETIVO_PENA * 2.0)),
		true, a, cheio, HudLayout.OBJETIVO_PENA)

	# Barra de acento. Acende inteira na etapa nova e volta ao fio.
	var brilho := clampf(_t_novo / T_NOVO, 0.0, 1.0)
	var cor_barra := HudTema.OK if _concluido else HudTema.acento()
	draw_rect(Rect2(o, Vector2(HudLayout.OBJETIVO_BARRA, altura)),
		HudTema.alfa(cor_barra, a * (0.75 + 0.25 * brilho)))
	if brilho > 0.0:
		draw_rect(Rect2(o - Vector2(1.0, 0.0), Vector2(HudLayout.OBJETIVO_BARRA + 2.0, altura)),
			HudTema.alfa(cor_barra, a * brilho * 0.35))

	for caixa: Dictionary in _plano["caixas"]:
		var r: Rect2 = caixa["rect"]
		r.position += o
		var linhas: PackedStringArray = caixa["linhas"]
		match String(caixa["nome"]):
			"titulo":
				var titulo := linhas[0]
				var cor := HudTema.acento()
				if _concluido:
					titulo = "OBJETIVO CUMPRIDO"
					cor = HudTema.OK
				elif _t_novo > T_NOVO - 1.2:
					titulo = "NOVO OBJETIVO"
				HudTema.texto(self, HudTema.rotulo(), r.position, titulo, HudTema.T_ROTULO,
					HudTema.alfa(cor, a))
			"etapa":
				HudTema.texto(self, HudTema.semi(), r.position, linhas[0], HudTema.T_ROTULO,
					HudTema.alfa(HudTema.fraco(), a))
			"objetivo":
				var f := HudTema.regular()
				var h := HudTema.altura(f, HudTema.T_CORPO)
				var cor := HudTema.fraco() if _concluido else HudTema.TEXTO
				for k in linhas.size():
					HudTema.texto(self, f, r.position + Vector2(0.0, h * k), linhas[k],
						HudTema.T_CORPO, HudTema.alfa(cor, a))
					if _concluido:
						var w := HudTema.largura(f, linhas[k], HudTema.T_CORPO)
						var y := r.position.y + h * k + h * 0.55
						draw_line(Vector2(r.position.x, y), Vector2(r.position.x + w, y),
							HudTema.alfa(HudTema.fraco(), a), 0.6)
			"distancia":
				var h := HudTema.altura(HudTema.semi(), HudTema.T_ROTULO)
				HudTema.losango(self, r.position + Vector2(3.0, h * 0.5), 2.6,
					HudTema.acento(), a)
				HudTema.texto(self, HudTema.semi(), r.position + Vector2(9.0, 0.0), linhas[0],
					HudTema.T_ROTULO, HudTema.alfa(HudTema.TEXTO, a))
			"dica":
				HudObjetivo.desenhar_frase(self, r.position, linhas[0], HudTema.T_MICRO + 1,
					a * clampf(_t_leitura, 0.0, 1.0) if _t_leitura > 0.0 else a,
					HudTema.fraco())


## Desenha "[E] abrir  [F] sair" com as teclas em caixa. Publico: o prompt de
## acao usa o mesmo desenho, e duas implementacoes do mesmo glifo divergem.
static func desenhar_frase(ci: CanvasItem, p: Vector2, frase: String, tam: int,
		a: float, cor_texto: Color) -> float:
	return desenhar_pedacos(ci, p, HudLayout.pedacos(frase), tam, a, cor_texto)


static func desenhar_pedacos(ci: CanvasItem, p: Vector2, pp: Array[Dictionary], tam: int,
		a: float, cor_texto: Color) -> float:
	var f := HudTema.semi()
	var x := p.x
	var ctl := _controle()
	var pad := ctl != null and ctl.dispositivo == Controle.Dispositivo.CONTROLE
	for i in pp.size():
		var pedaco: Dictionary = pp[i]
		if i > 0:
			x += 3.0 if bool(pp[i - 1]["tecla"]) and not bool(pedaco["tecla"]) else 8.0
		var t := String(pedaco["texto"])
		if bool(pedaco["tecla"]):
			x += HudTema.tecla(ci, Vector2(x, p.y), HudLayout.glifo(t, pad), tam, a)
		else:
			var h_tecla := HudTema.altura(f, tam) + 2.0
			var h := HudTema.altura(f, tam)
			HudTema.texto(ci, f, Vector2(x, p.y + (h_tecla - h) * 0.5), t, tam,
				HudTema.alfa(cor_texto, a))
			x += HudTema.largura(f, t, tam)
	return x - p.x
