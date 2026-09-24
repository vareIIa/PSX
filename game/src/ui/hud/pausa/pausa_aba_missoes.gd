## MISSOES: a missao em curso com todas as etapas, e as entregas do iWeed.
##
## A esquerda a missao: feitas riscadas, a atual com o losango, as proximas
## apagadas (o jogador sabe quanto falta sem que o jogo conte o que vem). A
## direita a agenda do iWeed, que ate aqui so existia dentro do celular.
## ENTER traca a rota no GPS ate o que estiver selecionado.
class_name PausaAbaMissoes
extends PausaAba

const COLUNA := 214.0
const LINHA := 15.0

## Linhas selecionaveis: a missao (se houver) e cada entrega da agenda.
var _alvos: Array[Dictionary] = []
var _sel := 0


func ao_entrar() -> void:
	_alvos.clear()
	if not Missoes.atual.is_empty() and Missoes.posicao_do_alvo() != Vector3.INF:
		_alvos.append({"tipo": &"missao"})
	for p: Dictionary in IWeed.agenda():
		_alvos.append({"tipo": &"entrega", "pedido": p})
	_sel = clampi(_sel, 0, maxi(0, _alvos.size() - 1))
	queue_redraw()


func dicas() -> Array:
	return [["W S", "MOVER"], ["ENTER", "TRACAR ROTA"]] if not _alvos.is_empty() else []


func tratar(evento: InputEvent) -> bool:
	if _alvos.is_empty():
		return false
	if evento.is_action_pressed(&"mover_frente") or evento.is_action_pressed(&"ui_up"):
		_sel = posmod(_sel - 1, _alvos.size())
	elif evento.is_action_pressed(&"mover_tras") or evento.is_action_pressed(&"ui_down"):
		_sel = posmod(_sel + 1, _alvos.size())
	elif evento.is_action_pressed(&"ui_accept"):
		_tracar(_alvos[_sel])
	else:
		return false
	AudioDirector.tocar_nav(-20.0)
	queue_redraw()
	return true


func _tracar(alvo: Dictionary) -> void:
	if alvo["tipo"] == &"entrega":
		IWeed.marcar_no_gps(int((alvo["pedido"] as Dictionary)["n"]))
	else:
		var mundo := Missoes.posicao_do_alvo()
		var j := get_tree().get_first_node_in_group(&"player") as Node3D
		Gps.destino = {
			"categoria": &"missao",
			"nome": String(Missoes.atual.get("titulo", "")).to_upper(),
			"mundo": mundo,
			"chunk": Vector2i(floori(mundo.x / MalhaUrbana.TAM), floori(mundo.z / MalhaUrbana.TAM)),
			"icone": &"",
			"endereco": NomesDeRua.rua_perto(mundo),
		}
		Gps.rota = Rota.tracar(j.global_position if j != null else mundo, mundo)
		Gps.destino_mudou.emit()
	AudioDirector.tocar_confirm(-14.0)


func _draw() -> void:
	var x := area.position.x
	var y := area.position.y
	var f := HudTema.regular()
	var fs := HudTema.semi()
	var h := HudTema.altura(f, HudTema.T_CORPO)
	y += secao(Vector2(x, y), "MISSAO", COLUNA)
	if Missoes.atual.is_empty():
		HudTema.texto(self, f, Vector2(x, y), "Nenhuma missao em curso.", HudTema.T_CORPO,
			HudTema.fraco())
	else:
		var m := Missoes.atual
		var focada: bool = not _alvos.is_empty() and _alvos[_sel]["tipo"] == &"missao"
		var titulo := String(m.get("titulo", "")).to_upper()
		if focada:
			draw_rect(Rect2(x - 4.0, y - 2.0, COLUNA + 4.0, HudTema.altura(fs, HudTema.T_TITULO) + 4.0),
				Color(1.0, 1.0, 1.0, 0.07))
			draw_rect(Rect2(x - 4.0, y - 2.0, 1.5, HudTema.altura(fs, HudTema.T_TITULO) + 4.0),
				HudTema.acento())
		HudTema.texto(self, HudTema.fonte(700, 1), Vector2(x, y), titulo, HudTema.T_TITULO,
			HudTema.TEXTO)
		y += HudTema.altura(fs, HudTema.T_TITULO) + 6.0
		var etapas: Array = m.get("etapas", [])
		var atual := int(m.get("etapa", 0))
		for i in etapas.size():
			var e: Dictionary = etapas[i]
			var linhas := HudTema.quebrar(f, String(e.get("texto", "")), HudTema.T_CORPO, COLUNA - 14.0)
			var cor := HudTema.TEXTO
			if i < atual:
				cor = HudTema.TEXTO_APAGADO
			elif i > atual:
				cor = HudTema.alfa(HudTema.fraco(), 0.7)
			# Marca da etapa: feita, atual, por vir.
			var c := Vector2(x + 4.0, y + h * 0.5)
			if i < atual:
				draw_polyline(PackedVector2Array([c + Vector2(-2.5, 0.0), c + Vector2(-0.8, 1.8),
					c + Vector2(2.6, -2.0)]), HudTema.OK, 0.9, true)
			elif i == atual:
				HudTema.losango(self, c, 2.8, HudTema.acento())
			else:
				draw_arc(c, 2.2, 0.0, TAU, 12, cor, 0.6, true)
			for k in linhas.size():
				HudTema.texto(self, fs if i == atual else f, Vector2(x + 12.0, y), linhas[k],
					HudTema.T_CORPO, cor)
				if i < atual:
					var w := HudTema.largura(f, linhas[k], HudTema.T_CORPO)
					draw_line(Vector2(x + 12.0, y + h * 0.55), Vector2(x + 12.0 + w, y + h * 0.55),
						HudTema.TEXTO_APAGADO, 0.6)
				y += h
			if i == atual and not String(e.get("dica", "")).is_empty():
				HudObjetivo.desenhar_frase(self, Vector2(x + 12.0, y + 1.0), String(e["dica"]),
					HudTema.T_ROTULO, 1.0, HudTema.fraco())
				y += h + 3.0
			y += 4.0
		var alvo := Missoes.posicao_do_alvo()
		var j := get_tree().get_first_node_in_group(&"player") as Node3D
		if alvo != Vector3.INF and j != null:
			var d := Vector2(alvo.x - j.global_position.x, alvo.z - j.global_position.z).length()
			HudTema.losango(self, Vector2(x + 4.0, y + h * 0.5), 2.4, HudTema.acento())
			HudTema.texto(self, fs, Vector2(x + 12.0, y), "%s em linha reta" % HudTema.distancia(d),
				HudTema.T_CORPO, HudTema.fraco())

	# --- entregas do iWeed
	var dx := area.position.x + COLUNA + 18.0
	var dw := area.end.x - dx
	var dy := area.position.y
	HudTema.painel(self, Rect2(dx - 8.0, dy - 4.0, dw + 8.0, area.size.y + 4.0), 0.85, 3.0)
	dy += secao(Vector2(dx, dy), "ENTREGAS  ·  IWEED", dw - 8.0)
	var agenda := IWeed.agenda()
	if agenda.is_empty():
		HudTema.texto(self, f, Vector2(dx, dy), "Nenhuma entrega aceita.", HudTema.T_CORPO,
			HudTema.fraco())
		dy += h
	for p: Dictionary in agenda:
		if dy > area.end.y - h * 3.0:
			break
		var focada := false
		for k in _alvos.size():
			if k == _sel and _alvos[k]["tipo"] == &"entrega" \
					and int((_alvos[k]["pedido"] as Dictionary)["n"]) == int(p["n"]):
				focada = true
		var bloco := Rect2(dx - 4.0, dy - 1.0, dw - 4.0, h * 2.0 + 3.0)
		if focada:
			draw_rect(bloco, Color(1.0, 1.0, 1.0, 0.07))
			draw_rect(Rect2(bloco.position, Vector2(1.5, bloco.size.y)), HudTema.acento())
		var cliente := IWeed.nome_curto(int(p["cliente"]))
		var falta := IWeed.falta(int(p.get("fim", 0)))
		HudTema.texto(self, fs, Vector2(dx, dy), HudTema.encurtar(fs, cliente, HudTema.T_CORPO,
			dw - 50.0), HudTema.T_CORPO, HudTema.TEXTO)
		var wf := HudTema.largura(fs, falta, HudTema.T_ROTULO)
		HudTema.texto(self, fs, Vector2(dx + dw - 10.0 - wf, dy + 0.5), falta, HudTema.T_ROTULO,
			HudTema.ALERTA)
		dy += h
		var linha2 := "%dx %s  ·  %s" % [int(p["qtd"]), IWeed.nome_do_produto(String(p["produto"])),
			String(p.get("lugar", ""))]
		HudTema.texto(self, f, Vector2(dx, dy), HudTema.encurtar(f, linha2, HudTema.T_ROTULO,
			dw - 10.0), HudTema.T_ROTULO, HudTema.fraco())
		dy += h + 5.0
	var novos := IWeed.abertos().size()
	if novos > 0:
		HudTema.texto(self, fs, Vector2(dx, area.end.y - h), "%d pedido(s) novo(s) no celular" % novos,
			HudTema.T_ROTULO, HudTema.OK)
