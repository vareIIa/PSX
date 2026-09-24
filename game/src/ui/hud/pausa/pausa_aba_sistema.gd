## SISTEMA: continuar, carregar, opcoes e sair — em duas colunas.
##
## A esquerda as categorias; a direita o conteudo da categoria em foco, ja
## visivel antes de entrar nela (e o que o jogador procura: "onde fica o volume").
## E / D entra na coluna da direita; ESC / A volta. As linhas sao as mesmas de
## `OpcoesLista` que o menu de titulo le — uma fonte, tres leitores.
class_name PausaAbaSistema
extends PausaAba

const COLUNA := 128.0
const LINHA := 15.0

var _itens: Array[Dictionary] = []
var _sel := 0
var _dentro := false
var _sel_dir := 0
var _linhas: Array[Dictionary] = []
var _save: SaveCardsPanelRe7
var _confirmar_saida := false


func _ready() -> void:
	super._ready()
	_itens = [
		{"rotulo": "CONTINUAR", "tipo": &"continuar"},
		{"rotulo": "CARREGAR", "tipo": &"carregar"},
		{"rotulo": "IMAGEM", "tipo": &"opcoes", "linhas": OpcoesLista.video},
		{"rotulo": "SOM", "tipo": &"opcoes", "linhas": OpcoesLista.audio},
		{"rotulo": "HUD", "tipo": &"opcoes", "linhas": OpcoesLista.hud},
		{"rotulo": "EXIBICAO DO HUD", "tipo": &"opcoes", "linhas": OpcoesLista.hud_exibicao},
		{"rotulo": "PECAS DO HUD", "tipo": &"opcoes", "linhas": OpcoesLista.hud_pecas},
		{"rotulo": "LEGENDAS", "tipo": &"opcoes", "linhas": OpcoesLista.legendas},
		{"rotulo": "CONTROLES", "tipo": &"controles"},
		{"rotulo": "SAIR PARA O TITULO", "tipo": &"sair"},
	]


func ao_entrar() -> void:
	# Captura: `--sistema-item=controles` abre a SISTEMA com o item em foco.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--sistema-item="):
			var quer := arg.trim_prefix("--sistema-item=").to_upper()
			for i in _itens.size():
				if String(_itens[i]["rotulo"]) == quer:
					_sel = i
	_dentro = false
	_confirmar_saida = false
	_esconder_save()
	_carregar_linhas()
	queue_redraw()


func _carregar_linhas() -> void:
	_linhas.clear()
	var item: Dictionary = _itens[_sel]
	if item.has("linhas"):
		var fonte: Callable = item["linhas"]
		_linhas = fonte.call()
	_sel_dir = clampi(_sel_dir, 0, maxi(0, _linhas.size() - 1))


func ocupada() -> bool:
	return _dentro or (_save != null and _save.visible) or _confirmar_saida


func voltar() -> bool:
	if _save != null and _save.visible:
		_esconder_save()
		queue_redraw()
		return true
	if _confirmar_saida:
		_confirmar_saida = false
		queue_redraw()
		return true
	if _dentro:
		_dentro = false
		Settings.save_config()
		queue_redraw()
		return true
	return false


func dicas() -> Array:
	if _dentro:
		return [["W S", "MOVER"], ["A D", "AJUSTAR"]]
	return [["W S", "MOVER"], ["ENTER", "ESCOLHER"]]


func tratar(evento: InputEvent) -> bool:
	if _save != null and _save.visible:
		return false
	var passo_v := 0
	var passo_h := 0
	if evento.is_action_pressed(&"mover_frente") or evento.is_action_pressed(&"ui_up"):
		passo_v = -1
	elif evento.is_action_pressed(&"mover_tras") or evento.is_action_pressed(&"ui_down"):
		passo_v = 1
	elif evento.is_action_pressed(&"mover_esq") or evento.is_action_pressed(&"ui_left"):
		passo_h = -1
	elif evento.is_action_pressed(&"mover_dir") or evento.is_action_pressed(&"ui_right"):
		passo_h = 1
	var escolher := evento.is_action_pressed(&"interagir") or evento.is_action_pressed(&"ui_accept")
	if _dentro:
		if passo_v != 0 and not _linhas.is_empty():
			_sel_dir = posmod(_sel_dir + passo_v, _linhas.size())
			AudioDirector.tocar_nav(-20.0)
		elif (passo_h != 0 or escolher) and not _linhas.is_empty():
			var aplicar: Callable = _linhas[_sel_dir]["aplicar"]
			aplicar.call(passo_h if passo_h != 0 else 1)
			AudioDirector.tocar_nav(-20.0)
		else:
			return false
		queue_redraw()
		return true
	if passo_v != 0:
		_sel = posmod(_sel + passo_v, _itens.size())
		_confirmar_saida = false
		_carregar_linhas()
		AudioDirector.tocar_nav(-20.0)
	elif escolher or passo_h > 0:
		_acionar()
	else:
		return false
	queue_redraw()
	return true


func _acionar() -> void:
	var item: Dictionary = _itens[_sel]
	match item["tipo"]:
		&"continuar":
			hub.call(&"fechar")
		&"carregar":
			_mostrar_save()
		&"opcoes":
			if not _linhas.is_empty():
				_dentro = true
				_sel_dir = 0
		&"sair":
			if _confirmar_saida:
				hub.call(&"fechar")
				hub.emit_signal(&"pediu_titulo")
			else:
				_confirmar_saida = true
	AudioDirector.tocar_confirm(-16.0)


# --- carregar -----------------------------------------------------------------

func _mostrar_save() -> void:
	if _save == null:
		_save = SaveCardsPanelRe7.new()
		_save.name = "Cartoes"
		add_child(_save)
		_save.pediu_voltar.connect(func() -> void:
			_esconder_save()
			queue_redraw())
		_save.pediu_carregar.connect(func(espaco: int) -> void:
			hub.call(&"fechar")
			hub.emit_signal(&"pediu_carregar", espaco))
	var dir := _direita()
	_save.position = dir.position + Vector2(8.0, 4.0)
	_save.size = Vector2(dir.size.x - 16.0, dir.size.y - 8.0)
	_save.visible = true
	_save.refresh_from_savegame()
	_save.foco_padrao()


func _esconder_save() -> void:
	if _save != null:
		_save.visible = false


# --- desenho ------------------------------------------------------------------

func _direita() -> Rect2:
	return Rect2(area.position.x + COLUNA + 12.0, area.position.y,
		area.size.x - COLUNA - 12.0, area.size.y)


func _draw() -> void:
	var x := area.position.x
	var y := area.position.y
	y += secao(Vector2(x, y), "SISTEMA", COLUNA)
	for i in _itens.size():
		var item: Dictionary = _itens[i]
		var r := Rect2(x, y, COLUNA, LINHA)
		var focada := i == _sel and not _dentro
		linha(r, String(item["rotulo"]), ">" if item.has("linhas") else "", focada,
			item["tipo"] != &"carregar" or _tem_save())
		if i == _sel and _dentro:
			draw_rect(Rect2(r.position, Vector2(1.5, r.size.y)), HudTema.alfa(HudTema.acento(), 0.5))
		y += LINHA + (5.0 if i in [1, _itens.size() - 2] else 1.0)

	var dir := _direita()
	HudTema.painel(self, dir, 0.9, 3.0)
	if _save != null and _save.visible:
		return
	var item: Dictionary = _itens[_sel]
	var dx := dir.position.x + 10.0
	var dy := dir.position.y + 8.0
	dy += secao(Vector2(dx, dy), String(item["rotulo"]), dir.size.x - 20.0)
	match item["tipo"]:
		&"continuar":
			_paragrafo(Vector2(dx, dy), dir.size.x - 20.0, "Volta para a rua, onde voce parou.")
		&"carregar":
			_paragrafo(Vector2(dx, dy), dir.size.x - 20.0,
				"Tres espacos de save. O que nao foi salvo desde o ultimo ponto de save se perde."
				if _tem_save() else "Nenhum save ainda. Salve num telefone publico.")
		&"sair":
			_paragrafo(Vector2(dx, dy), dir.size.x - 20.0,
				"APERTE DE NOVO PARA SAIR. O que nao foi salvo se perde." if _confirmar_saida
				else "Volta para a tela de titulo. O que nao foi salvo desde o ultimo ponto de save se perde.",
				HudTema.PERIGO if _confirmar_saida else HudTema.fraco())
		&"controles":
			_desenhar_controles(Vector2(dx, dy), dir.size.x - 20.0)
		&"opcoes":
			for k in _linhas.size():
				var l: Dictionary = _linhas[k]
				var ler: Callable = l["ler"]
				var valor := String(ler.call())
				var r := Rect2(dx - 4.0, dy, dir.size.x - 12.0, LINHA)
				var focada := _dentro and k == _sel_dir
				if OpcoesLista.eh_trilha(valor):
					linha(r, String(l["rotulo"]), "", focada)
					var nivel := float(OpcoesLista.nivel_trilha(valor)) / 10.0
					HudTema.barra(self, Rect2(r.end.x - 7.0 - 70.0, r.get_center().y - 1.5, 70.0, 3.0),
						nivel, HudTema.acento() if focada else HudTema.TEXTO)
				else:
					linha(r, String(l["rotulo"]), valor, focada)
				dy += LINHA


## Tabela de `HudControles`: acao, tecla e botao, com a coluna do aparelho que
## o jogador esta usando AGORA acesa e a outra apagada.
func _desenhar_controles(p: Vector2, largura: float) -> void:
	var ctl := Settings.get(&"controle") as Controle
	var pad := ctl != null and ctl.dispositivo == Controle.Dispositivo.CONTROLE
	var x_tecla := p.x + largura - 104.0
	var x_botao := p.x + largura - 44.0
	var fr := HudTema.rotulo()
	var familia := "PLAYSTATION" if HudGlifos.familia() == HudGlifos.PLAYSTATION else "XBOX"
	HudTema.texto(self, fr, Vector2(x_tecla, p.y), "TECLADO", HudTema.T_MICRO,
		HudTema.fraco() if not pad else HudTema.TEXTO_APAGADO)
	HudTema.texto(self, fr, Vector2(x_botao, p.y), familia, HudTema.T_MICRO,
		HudTema.fraco() if pad else HudTema.TEXTO_APAGADO)
	var y := p.y + 10.0
	var f := HudTema.regular()
	var tam := HudTema.T_MICRO
	var passo := HudControles.LINHA
	for l: Dictionary in HudControles.linhas():
		HudTema.texto(self, f, Vector2(p.x, y + 1.0), String(l["rotulo"]), HudTema.T_ROTULO,
			HudTema.TEXTO)
		var tecla := String(l["tecla"])
		var botao := String(l["botao"])
		if not tecla.is_empty():
			HudTema.tecla(self, Vector2(x_tecla, y), tecla, tam, 1.0 if not pad else 0.45)
		if not botao.is_empty():
			HudTema.tecla(self, Vector2(x_botao, y), HudLayout.MARCA_PAD + botao, tam,
				1.0 if pad else 0.45)
		else:
			HudTema.texto(self, f, Vector2(x_botao + 2.0, y + 1.0), "no celular", HudTema.T_MICRO,
				HudTema.alfa(HudTema.fraco(), 1.0 if pad else 0.45))
		y += passo


func _paragrafo(p: Vector2, largura: float, texto: String, cor: Color = HudTema.TEXTO_FRACO) -> void:
	var f := HudTema.regular()
	var h := HudTema.altura(f, HudTema.T_CORPO)
	var linhas := HudTema.quebrar(f, texto, HudTema.T_CORPO, largura)
	for i in linhas.size():
		HudTema.texto(self, f, p + Vector2(0.0, h * i), linhas[i], HudTema.T_CORPO, cor)


func _tem_save() -> bool:
	for i in SaveGame.ESPACOS:
		if SaveGame.existe(i):
			return true
	return false
