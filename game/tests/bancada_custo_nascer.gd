## Quanto custa NASCER cada coisa que aparece durante o jogo, por etapa.
##
##     godot --path game --resolution 3840x2160 res://tests/bancada_custo_nascer.tscn -- --pular-menu --estilo=moderno [--n=12]
##
## Monta a cidade de verdade, aquece os shaders (o mesmo aquecimento do titulo),
## para a Multidao e o Transito (senao eles nascem gente no meio da medida) e,
## parado, faz nascer N de cada tipo, um por quadro, perto do jogador: pedestre
## (como a Multidao), carro (como o Transito), convidado (como o ChunkManager) e
## TV. Para cada um mede `new`+`preparar`, `add_child` (o `_ready`, onde mora a
## montagem), o quadro seguinte inteiro e o `free`. Um `Corpo` avulso montado
## com outra ficha da a parte do corpo no total.
##
## Imprime `[nascer] tipo etapa mediana=.. max=.. primeiro=..` em ms.
extends Node

var _n := 12
var _serie := {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			_n = arg.trim_prefix("--n=").to_int()
	var cidade: Node = (load("res://scenes/test/cidade.tscn") as PackedScene).instantiate()
	add_child(cidade)
	(load("res://tests/aviso_de_bancada.gd") as GDScript).call(&"mostrar", self, "Custo de nascer pedestre, carro, convidado e TV (~40 s).")
	_rodar()


func _relatar(chave: String, valor: Variant) -> void:
	print("[nascer] %s %s" % [chave, valor])


func _anotar(tipo: String, etapa: String, ms: float) -> void:
	var k := "%s %s" % [tipo, etapa]
	if not _serie.has(k):
		_serie[k] = [] as Array[float]
	(_serie[k] as Array[float]).append(ms)


func _rodar() -> void:
	var arvore := get_tree()
	var jogador: Node3D = null
	while jogador == null:
		await arvore.process_frame
		jogador = arvore.get_first_node_in_group(&"player") as Node3D
	var espera := 0.0
	var estavel := 0.0
	var antes := -1
	while espera < 25.0 and estavel < 1.5:
		await arvore.process_frame
		espera += get_process_delta_time()
		var n := ChunkManager.chunks_carregados()
		var ocioso: bool = ChunkManager._em_voo.is_empty() and ChunkManager._prontos.is_empty() \
			and ChunkManager._montando.is_empty()
		estavel = estavel + get_process_delta_time() if (n == antes and ocioso) else 0.0
		antes = n
	_relatar("montagem_s", "%.1f chunks=%d" % [espera, ChunkManager.chunks_carregados()])
	var t_aq := Time.get_ticks_msec()
	AquecimentoDeShaders.iniciar(self)
	while not AquecimentoDeShaders.pronto():
		await arvore.process_frame
	_relatar("aquecimento_s", "%.1f" % ((Time.get_ticks_msec() - t_aq) / 1000.0))
	Multidao.parar()
	Transito.parar()
	await arvore.create_timer(2.0).timeout

	# Linha de base: quadro parado sem ninguem nascendo.
	var base: Array[float] = []
	var t_ant := Time.get_ticks_usec()
	for i in 60:
		await arvore.process_frame
		var t := Time.get_ticks_usec()
		base.append((t - t_ant) / 1000.0)
		t_ant = t
	_relatar("quadro_base", "mediana=%.2f max=%.2f" % [_mediana(base), base.max()])

	var centro := jogador.global_position
	var raiz_rua: Node3D = Multidao.raiz if Multidao.raiz != null else jogador.get_parent() as Node3D
	var semente := 91731
	for tipo: String in ["corpo", "pedestre", "pedestre_antes", "carroceria", "carro", "convidado", "tv", "multidao", "transito"]:
		Pedestre.lentos.clear()
		Pedestre.pior_passo = {"ms": 0.0}
		for i in _n:
			semente += 7919
			var no := _criar(tipo, semente, centro, raiz_rua)
			if no == null:
				continue
			var t0 := Time.get_ticks_usec()
			await arvore.process_frame
			_anotar(tipo, "quadro", (Time.get_ticks_usec() - t0) / 1000.0)
			# Quatro passos de fisica vivos: o primeiro move_and_slide acontece aqui.
			for k in 4:
				await arvore.physics_frame
			await arvore.process_frame
			var t1 := Time.get_ticks_usec()
			if is_instance_valid(no):
				no.free()
			_anotar(tipo, "free", (Time.get_ticks_usec() - t1) / 1000.0)
			await arvore.process_frame
		if Pedestre.medir and float(Pedestre.pior_passo["ms"]) > 0.0:
			_relatar("%s pior_passo_fisica" % tipo, "%.1f ms lentos(>5ms)=%d %s" % [
				float(Pedestre.pior_passo["ms"]), Pedestre.lentos.size(),
				str(Pedestre.pior_passo.get("etapas", {}))])
	# O carro por dentro: cada `_montar_*` do `Carro._ready` chamado de novo, no
	# relogio, num carro que ja esta na arvore (duplica as pecas; o carro sai
	# logo depois). Da o que um pool de Carro pouparia, peca por peca.
	for i in _n:
		semente += 7919
		var trechos := Vias.trechos_perto(centro, 10.0, 58.0)
		if trechos.is_empty():
			break
		var tr: Dictionary = trechos[semente % trechos.size()]
		var ficha := RegistroCivil.identidade(RegistroCivil.id_de_transeunte(semente))
		var c := Carro.new()
		c.preparar(ficha, tr["de"], tr["trecho"], semente)
		raiz_rua.add_child(c)
		c.global_position = Transito.ponto_de_nascimento(tr)
		await arvore.process_frame
		for passo: String in ["_montar_visual", "_montar_colisao", "_montar_rodas",
				"_montar_spray", "_cachear_luzes", "_montar_luzes", "_montar_som",
				"_montar_gatilho", "_montar_motorista", "_iniciar_rota", "_alinhar_na_faixa"]:
			if passo == "_montar_motorista":
				c.set(&"_motorista_corpo", null)
			var tp := Time.get_ticks_usec()
			c.call(StringName(passo))
			_anotar("carro_peca", passo, (Time.get_ticks_usec() - tp) / 1000.0)
		c.free()
		await arvore.process_frame
	var chaves: Array = _serie.keys()
	chaves.sort()
	for k: String in chaves:
		var v: Array[float] = _serie[k]
		_relatar(k, "mediana=%.2f max=%.2f primeiro=%.2f n=%d" % [_mediana(v), v.max(), v[0], v.size()])
	arvore.quit(0)


func _criar(tipo: String, semente: int, centro: Vector3, raiz_rua: Node3D) -> Node3D:
	var tf := Time.get_ticks_usec()
	var ficha := RegistroCivil.identidade(RegistroCivil.id_de_transeunte(semente))
	if ficha.is_empty():
		return null
	_anotar(tipo, "ficha", (Time.get_ticks_usec() - tf) / 1000.0)
	var ta := Time.get_ticks_usec()
	match tipo:
		"multidao":
			# O nascimento de verdade da Multidao, inteiro: sorteio do id, ficha
			# do registro, Pedestre e sinal.
			var trechos := Rotas.trechos_perto(centro, 4.0, 40.0)
			if trechos.is_empty():
				return null
			var tr: Dictionary = trechos[semente % trechos.size()]
			var antes := Multidao.vivos()
			var tb := Time.get_ticks_usec()
			Multidao.call(&"_nascer", tr)
			_anotar(tipo, "nascer", (Time.get_ticks_usec() - tb) / 1000.0)
			if Multidao.vivos() == antes:
				return null
			return Multidao.lista()[-1]
		"transito":
			var trechos := Vias.trechos_perto(centro, 10.0, 58.0)
			if trechos.is_empty():
				return null
			var tr: Dictionary = trechos[semente % trechos.size()]
			var antes := Transito.vivos()
			var tb := Time.get_ticks_usec()
			Transito.call(&"_nascer", tr)
			_anotar(tipo, "nascer", (Time.get_ticks_usec() - tb) / 1000.0)
			if Transito.vivos() == antes:
				return null
			return Transito.lista()[-1]
		"corpo":
			var c := Corpo.new()
			raiz_rua.add_child(c)
			c.global_position = centro + Vector3(3.0, 0.0, 0.0)
			var tb := Time.get_ticks_usec()
			c.montar(ficha.get("aparencia", {}))
			_anotar(tipo, "montar", (Time.get_ticks_usec() - tb) / 1000.0)
			return c
		"pedestre":
			var trechos := Rotas.trechos_perto(centro, 4.0, 40.0)
			if trechos.is_empty():
				return null
			var tr: Dictionary = trechos[semente % trechos.size()]
			var p := Pedestre.new()
			p.preparar(ficha, tr["de"], tr["para"])
			var tb := Time.get_ticks_usec()
			raiz_rua.add_child(p)
			p.global_position = (tr["ponto"] as Vector3) + Vector3(0.0, 0.1, 0.0)
			_anotar(tipo, "new", (tb - ta) / 1000.0)
			_anotar(tipo, "add", (Time.get_ticks_usec() - tb) / 1000.0)
			return p
		"carro":
			var trechos := Vias.trechos_perto(centro, 10.0, 58.0)
			if trechos.is_empty():
				return null
			var tr: Dictionary = trechos[semente % trechos.size()]
			var c := Carro.new()
			c.preparar(ficha, tr["de"], tr["trecho"], semente)
			var tb := Time.get_ticks_usec()
			raiz_rua.add_child(c)
			c.global_position = Transito.ponto_de_nascimento(tr)
			_anotar(tipo, "new", (tb - ta) / 1000.0)
			_anotar(tipo, "add", (Time.get_ticks_usec() - tb) / 1000.0)
			return c
		"pedestre_antes":
			# O mesmo pedestre, com a posicao posta ANTES de entrar na arvore: o
			# corpo fisico nunca existe na origem do mundo.
			var trechos := Rotas.trechos_perto(centro, 4.0, 40.0)
			if trechos.is_empty():
				return null
			var tr: Dictionary = trechos[semente % trechos.size()]
			var p := Pedestre.new()
			p.preparar(ficha, tr["de"], tr["para"])
			p.position = raiz_rua.to_local((tr["ponto"] as Vector3) + Vector3(0.0, 0.1, 0.0))
			var tb := Time.get_ticks_usec()
			raiz_rua.add_child(p)
			_anotar(tipo, "new", (tb - ta) / 1000.0)
			_anotar(tipo, "add", (Time.get_ticks_usec() - tb) / 1000.0)
			return p
		"carroceria":
			# So a lataria do carro, com os mesmos argumentos do `Carro._ready`:
			# o resto do custo do carro e o que um pool de Carro pouparia.
			var trechos := Vias.trechos_perto(centro, 10.0, 58.0)
			if trechos.is_empty():
				return null
			var tr: Dictionary = trechos[semente % trechos.size()]
			var c := Carro.new()
			c.preparar(ficha, tr["de"], tr["trecho"], semente)
			var tinta: Color = Carroceria.TINTAS[absi(semente * 7919) % Carroceria.TINTAS.size()]
			var amassados: Array = c.call(&"_amassados_de_fabrica")
			var tb := Time.get_ticks_usec()
			Carroceria.montar(c.modelo, tinta, semente, true, true, amassados)
			_anotar(tipo, "montar", (Time.get_ticks_usec() - tb) / 1000.0)
			c.free()
			return null
		"convidado":
			var suporte := Node3D.new()
			raiz_rua.add_child(suporte)
			suporte.global_position = centro + Vector3(-3.0, 0.0, 0.0)
			ChunkManager._coord_do_prop = ChunkManager.coord_de(centro)
			var c := ChunkManager._criar_convidado({"tipo": "convidado", "semente": semente,
				"pos": Vector3.ZERO, "giro": 0.0})
			if c == null:
				suporte.free()
				return null
			var tb := Time.get_ticks_usec()
			suporte.add_child(c)
			_anotar(tipo, "new", (tb - ta) / 1000.0)
			_anotar(tipo, "add", (Time.get_ticks_usec() - tb) / 1000.0)
			return suporte
		"tv":
			var tv := Televisao.new()
			tv.position = centro + Vector3(0.0, 1.0, 3.0)
			var tb := Time.get_ticks_usec()
			raiz_rua.add_child(tv)
			_anotar(tipo, "new", (tb - ta) / 1000.0)
			_anotar(tipo, "add", (Time.get_ticks_usec() - tb) / 1000.0)
			return tv
	return null


static func _mediana(v: Array[float]) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return s[s.size() / 2]
