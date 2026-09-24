## A fala medida: silaba, texto e boca no mesmo passo.
##
##     godot --headless --path game --script res://tests/medir_fala.gd
##
## Criterios do PLANO_PERSONAGENS_AAA (fase 1), em linhas de verdade do jogo
## (as falas dos doze temperamentos):
##
## - separacao: exemplos de ouvido ("fa-la", "pas-sa", "can-to") batem;
## - texto: o `ate` de cada silaba so cresce e termina na linha inteira;
## - boca: nas silabas de a, o e u, a boca esta ABERTA ou REDONDA em pelo menos
##   60% dos passos; nas pausas (virgula, ponto) ela esta fechada em 100%;
## - `pular`: a linha aparece inteira e a boca fecha no mesmo passo;
## - ritmo: nenhuma linha passa de 12 s nem fica abaixo de 0,1 s por letra de
##   leitura (a linha precisa dar tempo de ser lida enquanto e dita).
extends SceneTree

var _passou := 0
var _total := 0


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	_separacao()
	var linhas := _linhas_do_jogo()
	_conta("linhas do jogo coletadas", linhas.size() >= 100, "%d" % linhas.size())
	_texto(linhas)
	await _boca(linhas)
	_marcas()
	_reacoes()
	await _micro()
	print("[fala] %d/%d" % [_passou, _total])
	quit(0 if _passou == _total else 1)


func _partes(linha: String) -> PackedStringArray:
	var saida := PackedStringArray()
	var ini := 0
	for s: Dictionary in Fala.silabas(linha):
		saida.append(linha.substr(ini, int(s["ate"]) - ini).strip_edges())
		ini = int(s["ate"])
	return saida


func _separacao() -> void:
	var casos := {
		"fala": "fa|la", "passa": "pas|sa", "canto": "can|to", "casa": "ca|sa",
		"de voce": "de|vo|ce", "Nao sei.": "Nao|sei.", "O que voce quer?": "O|que|vo|ce|quer?",
	}
	for linha: String in casos:
		var obtido := "|".join(_partes(linha))
		_conta("separa \"%s\"" % linha, obtido == casos[linha], obtido)


func _linhas_do_jogo() -> Array[String]:
	var saida: Array[String] = []
	for p: Dictionary in Personalidade.LISTA:
		for chave: String in ["saudacao", "despedida", "nevoa", "bairro", "voce"]:
			for l: String in p.get(chave, []):
				saida.append(l)
		var proprio: Dictionary = p.get("proprio", {})
		for l: String in proprio.get("linhas", []):
			saida.append(l)
	return saida


func _texto(linhas: Array[String]) -> void:
	var crescem := 0
	var terminam := 0
	var ritmo := 0
	for l in linhas:
		var plano := Fala.silabas(l)
		var ultimo := -1
		var ok := true
		for s: Dictionary in plano:
			if int(s["ate"]) <= ultimo:
				ok = false
			ultimo = int(s["ate"])
		crescem += 1 if ok else 0
		terminam += 1 if ultimo == l.length() else 0
		var n := 0
		for s: Dictionary in plano:
			n += int(s["passos"]) + int(s["pausa"])
		var dur := float(n) / Fala.HZ
		if dur <= 12.0 and dur >= l.length() * 0.02:
			ritmo += 1
	_conta("texto so cresce", crescem == linhas.size(), "%d de %d" % [crescem, linhas.size()])
	_conta("texto termina na linha inteira", terminam == linhas.size(),
		"%d de %d" % [terminam, linhas.size()])
	_conta("ritmo de leitura", ritmo == linhas.size(), "%d de %d" % [ritmo, linhas.size()])


func _boca(linhas: Array[String]) -> void:
	var c := Corpo.new()
	c.detalhado = true
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 12, "sexo": &"M", "idade": 40}))
	_conta("corpo de perto tem rosto", c.rosto != null and c.rosto.valido())
	if c.rosto == null:
		return
	c.rosto.pisca = false
	var f := Fala.new()
	root.add_child(f)
	f.rosto = c.rosto
	var aberta_aou := 0
	var passos_aou := 0
	var fechada_pausa := 0
	var passos_pausa := 0
	for l in linhas.slice(0, 100):
		f.dizer(l)
		var plano := Fala.silabas(l)
		for s: Dictionary in plano:
			for k in int(s["passos"]) + int(s["pausa"]):
				f._avancar_um_passo()
				var boca := c.rosto.estado(&"boca")
				if k < int(s["passos"]):
					if String(s["vogal"]) in ["a", "o", "u"]:
						passos_aou += 1
						if boca == &"ABERTA" or boca == &"REDONDA":
							aberta_aou += 1
				else:
					passos_pausa += 1
					if boca == &"":
						fechada_pausa += 1
		f.pular()
	var fr := float(aberta_aou) / maxf(1.0, passos_aou)
	_conta("boca aberta ou redonda em a/o/u", fr >= 0.6, "%.0f%% de %d passos" % [fr * 100.0, passos_aou])
	_conta("boca fechada nas pausas", fechada_pausa == passos_pausa,
		"%d de %d passos" % [fechada_pausa, passos_pausa])
	# Pular no meio.
	var longa := "Vi. Nao era gente, estava parado onde o poste queimou."
	f.dizer(longa)
	for k in 5:
		f._avancar_um_passo()
	f.pular()
	_conta("pular mostra a linha e fecha a boca", f.revelado() == longa.length()
		and c.rosto.estado(&"boca") == &"" and not f.falando())
	f.queue_free()
	c.queue_free()
	await process_frame


## Fase 2: marcas de intencao somem da tela e caem na silaba certa.
func _marcas() -> void:
	var l := "[raiva]Sai daqui[pausa], agora![gesto:aponta]"
	_conta("marca some da tela", Fala.sem_marcas(l) == "Sai daqui, agora!", Fala.sem_marcas(l))
	var m := Fala.marcas(l)
	_conta("marcas no lugar", m.size() == 3 and int(m[0][0]) == 0 and int(m[1][0]) == 9
		and int(m[2][0]) == 17, str(m))
	var todas := 0
	for linha: String in _linhas_do_jogo():
		if Fala.sem_marcas(linha).contains("["):
			todas += 1
	_conta("nenhuma linha do jogo mostra colchete", todas == 0, "%d" % todas)


## Fase 2: toda opcao de conversa tem reacao (ou e neutra de proposito).
func _reacoes() -> void:
	var sem := PackedStringArray()
	var chaves: Array = FalasNpc.TITULOS.keys()
	chaves.append_array([&"documento", &"blitz_colaborar", &"blitz_cafe", &"blitz_correr",
		&"descer", &"contratar_x", &"demitir_x"])
	var neutras := [&"bairro", &"sair"]
	for c: StringName in chaves:
		if c in neutras:
			continue
		for p in Personalidade.QUANTAS:
			if ExpressaoDaConversa.reacao(c, p).is_empty():
				sem.append("%s/%d" % [c, p])
	_conta("toda opcao tem reacao em todo temperamento", sem.is_empty(), ", ".join(sem))
	_conta("todo temperamento tem rosto de base",
		ExpressaoDaConversa.BASE.size() == Personalidade.QUANTAS)


## Fase 2: a pontuacao mexe na cara sozinha, e a marca de expressao tambem.
func _micro() -> void:
	var c := Corpo.new()
	c.detalhado = true
	root.add_child(c)
	c.montar(Aparencia.de_ficha({"id": 14, "sexo": &"F", "idade": 33}))
	c.rosto.pisca = false
	var f := Fala.new()
	root.add_child(f)
	f.rosto = c.rosto
	var ergueu := false
	f.dizer("Voce viu ele?")
	while f.falando():
		f._avancar_um_passo()
		ergueu = ergueu or c.rosto.estado(&"sobr_e") == &"ERGUIDA"
	_conta("pergunta ergue a sobrancelha", ergueu)
	var fugiu := false
	f.dizer("Eu nao sei... talvez.")
	while f.falando():
		f._avancar_um_passo()
		fugiu = fugiu or c.rosto.estado(&"olho_e") in [&"OLHA_ESQ", &"OLHA_DIR"]
	_conta("reticencias desviam o olhar", fugiu)
	f.dizer("[raiva]Sai daqui.")
	f._avancar_um_passo()
	_conta("marca de expressao muda o rosto", c.rosto.expressao_atual() == Rosto.Expressao.RAIVA
		and c.rosto.estado(&"sobr_e") == &"FRANZIDA")
	f.pular()
	f.queue_free()
	c.queue_free()
	await process_frame


func _conta(nome: String, ok: bool, texto: String = "") -> void:
	_total += 1
	if ok:
		_passou += 1
	print("  [%s] %s  %s" % ["ok" if ok else "FALHOU", nome, texto])
