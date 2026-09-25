## Quanto custa montar gente e props no fio principal, e se o que sai de um
## cache e o MESMO que sairia montado na hora.
##
##     godot --path game --resolution 3840x2160 res://tests/bancada_variantes.tscn -- --pular-menu --estilo=moderno
##     ... -- --n=60              fichas por caso de tempo (padrao 60)
##     ... -- --despejo=ARQ       grava a impressao digital (SHA-256) de toda malha,
##                                osso, pele e material de --fichas pessoas nas
##                                quatro bandeiras do jogo, mais TV, sinuca e balcao
##     ... -- --comparar=ARQ      refaz o despejo e compara com um anterior: e a
##                                prova de que o cache nao mudou ninguem
##     ... -- --fichas=200        pessoas no despejo (padrao 200)
##
## Casos de tempo. `fio` e o custo no fio principal da criacao (Corpo.new,
## add_child, montar); `quadro` e o quadro inteiro em que a coisa nasceu, com a
## subida para a GPU e o desenho, contra `base.quadro` sem nascimento nenhum:
##   corpo.<bandeiras>.novo        pessoa inedita
##   corpo.<bandeiras>.de_novo     a mesma pessoa outra vez, em outro Corpo
##   corpo.rua.reciclado           o MESMO Corpo montado como outra pessoa (pool)
##   tv, sinuca, pedido, produtos  o no inteiro entrando na arvore
## As etapas de `Corpo.montar` saem do `Corpo.cronometro`.
##
## Imprime `[var] chave=valor`.
extends Node

## Quem liga o que antes de `montar` ([detalhado, com_rosto, piscar]), tirado
## de quem cria Corpo no jogo.
const BANDEIRAS := {
	"rua": [false, false, false],        # multidao, convidado, npc, morador
	"motorista": [false, true, false],   # Carro, Blitz
	"perto": [true, false, false],       # jogador, avatar, conversa, prancha
	"criacao": [true, false, true],      # retrato da criacao
}

## A TV sem a imagem (SubViewport e partida) e sem a luz: para saber de qual
## das duas e o quadro caro depois que uma TV nasce.
class TVSemImagem extends Televisao:
	func _montar_tela() -> void:
		_tela = MeshInstance3D.new()
		_tela.mesh = Televisao._malha_placa_cheia()
		add_child(_tela)

	func _process(_delta: float) -> void:
		pass


class TVSemLuz extends Televisao:
	func _montar_luz() -> void:
		pass


var _n := 60
var _so_tv := false
var _fichas_despejo := 200
var _despejo := ""
var _comparar := ""
var _raiz: Node3D
var _series: Dictionary = {}


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			_n = arg.trim_prefix("--n=").to_int()
		elif arg.begins_with("--fichas="):
			_fichas_despejo = arg.trim_prefix("--fichas=").to_int()
		elif arg.begins_with("--despejo="):
			_despejo = arg.trim_prefix("--despejo=")
		elif arg.begins_with("--comparar="):
			_comparar = arg.trim_prefix("--comparar=")
		elif arg == "--so-tv":
			_so_tv = true
	# Sem vsync: com ele todo quadro sai do tamanho do monitor.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_montar_palco()
	_rodar.call_deferred()


func _relatar(chave: String, valor: Variant) -> void:
	print("[var] %s=%s" % [chave, valor])


## Camera olhando para o lugar onde tudo nasce: o quadro medido inclui subir a
## malha e desenhar a pessoa, e nao so monta-la.
func _montar_palco() -> void:
	# A janela nao tem cenario: sem o aviso ela le como jogo travado em tela
	# cinza, e quem esta na maquina fecha no meio da medida.
	var aviso := CanvasLayer.new()
	aviso.layer = 100
	add_child(aviso)
	var texto := Label.new()
	texto.text = "BANCADA MEDINDO (variantes de corpo, TV, sinuca)\nfecha sozinha em ~%s\nnao feche" % (
		"1 min" if not _despejo.is_empty() or not _comparar.is_empty() else "2 min")
	texto.add_theme_font_size_override(&"font_size", 72)
	texto.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.2))
	texto.position = Vector2(80, 80)
	aviso.add_child(texto)
	_raiz = Node3D.new()
	_raiz.name = "Palco"
	add_child(_raiz)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.1, 3.4)
	_raiz.add_child(cam)
	cam.look_at(Vector3(0.0, 0.95, 0.0))
	cam.current = true
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.8, 0.5, 0.0)
	_raiz.add_child(sol)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.2, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	amb.environment = env
	_raiz.add_child(amb)


func _rodar() -> void:
	var arvore := get_tree()
	# A largada (autoloads, streaming de nada, shaders do titulo) assenta antes.
	for i in 30:
		await arvore.process_frame
	if not _despejo.is_empty() or not _comparar.is_empty():
		await _fazer_despejo()
		arvore.quit(0)
		return
	if _so_tv:
		await _medir_tv()
		arvore.quit(0)
		return
	await _medir_tempos()
	arvore.quit(0)


## O quadro caro depois da TV: de quem e. Cada variante nasce no comeco de um
## quadro e fica 12 quadros; as variantes se revezam, para a deriva da maquina
## cair igual em todas.
func _medir_tv() -> void:
	var arvore := get_tree()
	var fabricas := {
		"tv": func() -> Node3D: return Televisao.new(),
		"tv_sem_imagem": func() -> Node3D: return TVSemImagem.new(),
		"tv_sem_luz": func() -> Node3D: return TVSemLuz.new(),
		"so_imagem": func() -> Node3D:
			var n := Node3D.new()
			var vp := SubViewport.new()
			vp.size = Vector2i(PartidaPS2.LARGURA, PartidaPS2.ALTURA)
			vp.disable_3d = true
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			n.add_child(vp)
			var p := PartidaPS2.new()
			p.transmissao = true
			vp.add_child(p)
			return n,
		"nada": func() -> Node3D: return Node3D.new(),
	}
	for i in 30:
		await arvore.process_frame
	await _base("base.quadro", 60)
	for volta in 25:
		for nome: String in fabricas:
			await arvore.process_frame
			await arvore.process_frame
			var t0 := Time.get_ticks_usec()
			var no: Node3D = (fabricas[nome] as Callable).call()
			no.position = Vector3(0.0, 1.0, -1.5)
			_raiz.add_child(no)
			var t := t0
			var pior := 0.0
			for q in 12:
				await arvore.process_frame
				var agora := Time.get_ticks_usec()
				var ms := _ms(t, agora)
				if q == 0:
					_somar(nome + ".quadro", ms)
				else:
					pior = maxf(pior, ms)
				t = agora
			_somar(nome + ".pior_dos_11_seguintes", pior)
			no.queue_free()
	var chaves := _series.keys()
	chaves.sort()
	for chave: String in chaves:
		_relatar(chave, _resumo(_series[chave]))


# --- fichas ---------------------------------------------------------------------

## Aparencias reais do registro: `quantas` transeuntes a partir de `base`, e o
## elenco inteiro (tatuagem, cacho, coque, barba, chapeu escrito a mao).
func _aparencias(quantas: int, base: int, com_elenco: bool) -> Array[Dictionary]:
	# O registro e autoload: pelo no, para o --check-only conseguir ler o
	# resto deste arquivo.
	var rc: Variant = get_node(^"/root/RegistroCivil")
	var out: Array[Dictionary] = []
	for i in quantas:
		var id: int = rc.call(&"id_de_transeunte", base + i * 7919)
		var f: Dictionary = rc.call(&"identidade", id)
		if not f.is_empty():
			out.append(f["aparencia"])
	if com_elenco:
		var k := 0
		for chave: StringName in Aparencia.ELENCO:
			var id: int = rc.call(&"id_de_transeunte", 777 + k * 31)
			var f: Dictionary = rc.call(&"identidade", id)
			out.append(Aparencia.de_personagem(f["aparencia"], chave))
			k += 1
	return out


func _novo_corpo(ap: Dictionary, band: Array, x: float) -> Corpo:
	var c := Corpo.new()
	c.detalhado = bool(band[0])
	c.com_rosto = bool(band[1])
	c.piscar = bool(band[2])
	c.position = Vector3(x, 0.0, 0.0)
	_raiz.add_child(c)
	c.montar(ap)
	return c


static func _x(i: int) -> float:
	return -1.2 + float(i % 7) * 0.4


# --- tempos ---------------------------------------------------------------------

func _somar(chave: String, ms: float) -> void:
	var s: PackedFloat32Array = _series.get(chave, PackedFloat32Array())
	s.append(ms)
	_series[chave] = s


static func _ms(t0: int, t1: int) -> float:
	return float(t1 - t0) / 1000.0


static func _resumo(s: PackedFloat32Array) -> String:
	if s.is_empty():
		return "-"
	var o := s.duplicate()
	o.sort()
	var soma := 0.0
	for x: float in o:
		soma += x
	return "n=%d media=%.3f mediana=%.3f p90=%.3f max=%.3f" % [o.size(),
		soma / o.size(), o[o.size() / 2], o[int(o.size() * 0.9)], o[o.size() - 1]]


## Um Corpo nascendo no comeco de um quadro: o custo no fio e o quadro inteiro.
func _um_corpo(caso: String, ap: Dictionary, band: Array, x: float) -> Corpo:
	var arvore := get_tree()
	await arvore.process_frame
	Corpo.cronometro.clear()
	Corpo.medir_montagem = true
	var t0 := Time.get_ticks_usec()
	var c := _novo_corpo(ap, band, x)
	var t1 := Time.get_ticks_usec()
	Corpo.medir_montagem = false
	for etapa: StringName in Corpo.cronometro:
		_somar(caso + "." + String(etapa), float(Corpo.cronometro[etapa]) / 1000.0)
	_somar(caso + ".fio", _ms(t0, t1))
	await arvore.process_frame
	_somar(caso + ".quadro", _ms(t0, Time.get_ticks_usec()))
	return c


func _base(caso: String, quantos: int) -> void:
	var arvore := get_tree()
	for i in quantos:
		await arvore.process_frame
		var t0 := Time.get_ticks_usec()
		await arvore.process_frame
		_somar(caso, _ms(t0, Time.get_ticks_usec()))


func _medir_tempos() -> void:
	var arvore := get_tree()
	# Aquecimento: um de cada bandeira, para shader e pipeline nao entrarem na
	# conta de ninguem.
	for band_nome: String in BANDEIRAS:
		var aq := _aparencias(2, 5, false)
		for ap: Dictionary in aq:
			var c := _novo_corpo(ap, BANDEIRAS[band_nome], 0.0)
			await arvore.process_frame
			await arvore.process_frame
			c.queue_free()
	for i in 10:
		await arvore.process_frame
	await _base("base.quadro", 60)

	var k := 0
	for band_nome: String in BANDEIRAS:
		k += 1
		var band: Array = BANDEIRAS[band_nome]
		var aps := _aparencias(_n, 100000 * k, band_nome == "rua")
		for fase: String in ["novo", "de_novo"]:
			var caso := "corpo.%s.%s" % [band_nome, fase]
			for i in aps.size():
				var c: Corpo = await _um_corpo(caso, aps[i], band, _x(i))
				c.queue_free()
		# Reciclado: um Corpo so, cada vez uma pessoa (o pool do coordenador).
		if band_nome == "rua" or band_nome == "motorista":
			var caso := "corpo.%s.reciclado" % band_nome
			var outras := _aparencias(_n, 900000 + 100000 * k, false)
			var c := _novo_corpo(outras[0], band, 0.0)
			for i in range(1, outras.size()):
				await arvore.process_frame
				Corpo.cronometro.clear()
				Corpo.medir_montagem = true
				var t0 := Time.get_ticks_usec()
				c.montar(outras[i])
				var t1 := Time.get_ticks_usec()
				Corpo.medir_montagem = false
				for etapa: StringName in Corpo.cronometro:
					_somar(caso + "." + String(etapa), float(Corpo.cronometro[etapa]) / 1000.0)
				_somar(caso + ".fio", _ms(t0, t1))
				await arvore.process_frame
				_somar(caso + ".quadro", _ms(t0, Time.get_ticks_usec()))
			c.queue_free()
		# O LOD do rosto: quem e da rua ganha a cara que mexe a 9 m da camera.
		if band_nome == "rua":
			var caso := "rosto.lod"
			for i in mini(aps.size(), 30):
				var c := _novo_corpo(aps[i], band, _x(i))
				await arvore.process_frame
				await arvore.process_frame
				var t0 := Time.get_ticks_usec()
				if Rosto.tem_rosto(c.aparencia()):
					var r := Rosto.new(c)
					r.expressao(Rosto.Expressao.NEUTRA)
					r.reagir(Rosto.Expressao.SURPRESA, 1.0)
					c.rosto = r
				_somar(caso + ".fio", _ms(t0, Time.get_ticks_usec()))
				c.queue_free()

	await _medir_encomendas()
	await _medir_props()
	var chaves := _series.keys()
	chaves.sort()
	for chave: String in chaves:
		_relatar(chave, _resumo(_series[chave]))


## O caminho do pool: quem sabe quem vai aparecer encomenda antes
## (`VariantesDeCorpo.encomendar`), a thread monta, e o `montar` so pendura.
func _medir_encomendas() -> void:
	var arvore := get_tree()
	var band: Array = BANDEIRAS["rua"]
	for caso: String in ["encomendado", "reciclado_encomendado"]:
		var aps := _aparencias(_n, 7000000 if caso == "encomendado" else 8000000, false)
		await arvore.process_frame
		var t0 := Time.get_ticks_usec()
		for ap: Dictionary in aps:
			var te := Time.get_ticks_usec()
			VariantesDeCorpo.encomendar(ap)
			_somar("encomendar.fio", _ms(te, Time.get_ticks_usec()))
		_somar("encomendar.lote_de_%d.fio" % aps.size(), _ms(t0, Time.get_ticks_usec()))
		# Os quadros enquanto a thread monta: o fio principal nao deve sentir.
		var prontas := false
		var tq := Time.get_ticks_usec()
		while not prontas:
			await arvore.process_frame
			var agora := Time.get_ticks_usec()
			_somar("encomendar.quadro_durante", _ms(tq, agora))
			tq = agora
			prontas = true
			for ap: Dictionary in aps:
				if not VariantesDeCorpo.pronta(ap):
					prontas = false
					break
		_somar("encomendar.lote_de_%d.ate_prontas" % aps.size(), _ms(t0, Time.get_ticks_usec()))
		if caso == "encomendado":
			for i in aps.size():
				var c: Corpo = await _um_corpo("corpo.rua.encomendado", aps[i], band, _x(i))
				c.queue_free()
		else:
			var c := _novo_corpo(_aparencias(1, 5, false)[0], band, 0.0)
			for i in aps.size():
				await arvore.process_frame
				Corpo.cronometro.clear()
				Corpo.medir_montagem = true
				var t1 := Time.get_ticks_usec()
				c.reiniciar()
				c.montar(aps[i])
				var t2 := Time.get_ticks_usec()
				Corpo.medir_montagem = false
				for etapa: StringName in Corpo.cronometro:
					_somar("corpo.rua.%s.%s" % [caso, etapa], float(Corpo.cronometro[etapa]) / 1000.0)
				_somar("corpo.rua.%s.fio" % caso, _ms(t1, t2))
				await arvore.process_frame
				_somar("corpo.rua.%s.quadro" % caso, _ms(t1, Time.get_ticks_usec()))
			c.queue_free()
	_relatar("variantes", "guardadas=%d no_fio=%d na_thread=%d achadas=%d" % [
		VariantesDeCorpo.quantas(), VariantesDeCorpo.no_fio, VariantesDeCorpo.na_thread,
		VariantesDeCorpo.achadas])


func _medir_props() -> void:
	var arvore := get_tree()
	var fabricas := {
		"tv": func(i: int) -> Node3D:
			var tv := Televisao.new()
			tv.position = Vector3(0.0, 1.0, -1.0 - float(i % 3))
			return tv,
		"sinuca": func(i: int) -> Node3D:
			return JogoSinuca.criar({"pos": Vector3(0.0, 0.0, -3.0), "giro": 0.0,
				"semente": i}),
		"pedido": func(i: int) -> Node3D:
			var ids: Array[StringName] = [&"cerveja", &"guarana", &"pinga", &"coxinha", &"torresmo"]
			var p := PedidoNoBalcao.novo(ids[i % ids.size()])
			p.position = Vector3(0.0, 0.9, 0.0)
			return p,
		"produtos": func(i: int) -> Node3D:
			var itens: Array = []
			ProdutosDoBar.fileira(itens, [&"brahma_lata", &"skol_lata", &"coca_lata"],
				Vector3(-0.6, 0.9, 0.0), Vector3(0.6, 0.9, 0.0), 0.0, 4, 0.1, i)
			return ProdutosDoBar.criar({"pos": Vector3.ZERO, "itens": itens}),
	}
	for nome: String in fabricas:
		var fazer: Callable = fabricas[nome]
		for i in maxi(8, _n / 3):
			await arvore.process_frame
			await arvore.process_frame
			var t0 := Time.get_ticks_usec()
			var no: Node3D = fazer.call(i)
			_raiz.add_child(no)
			var t1 := Time.get_ticks_usec()
			var caso := nome + (".primeira" if i == 0 else "")
			_somar(caso + ".fio", _ms(t0, t1))
			await arvore.process_frame
			var t2 := Time.get_ticks_usec()
			_somar(caso + ".quadro", _ms(t0, t2))
			await arvore.process_frame
			_somar(caso + ".quadro_seguinte", _ms(t2, Time.get_ticks_usec()))
			no.queue_free()
	# O carro: so a Carroceria (o Carro e do coordenador), modelo a modelo. A
	# primeira volta enche os caches de casco, interior e roda (o `Transito`
	# faz isso na largada com `aquecer`); as outras sao o custo por carro.
	var n_modelos := Carroceria.Modelo.size()
	await arvore.process_frame
	_relatar("carroceria.aquecer_ms", "%.0f" % Carroceria.aquecer())
	for i in 4 * n_modelos:
		var modelo: Carroceria.Modelo = Carroceria.Modelo.values()[i % n_modelos]
		var caso := "carroceria" + (".primeira" if i < n_modelos else "")
		await arvore.process_frame
		Carroceria.cronometro.clear()
		Carroceria.medir_montagem = true
		var t0 := Time.get_ticks_usec()
		var _d := Carroceria.montar(modelo, Carroceria.TINTAS[i % Carroceria.TINTAS.size()], i,
			true, true, [] if i % 3 != 0 else [[Vector3(1, 0, 0.3), 0.8]])
		_somar(caso + ".fio", _ms(t0, Time.get_ticks_usec()))
		Carroceria.medir_montagem = false
		if i >= n_modelos:
			for etapa: StringName in Carroceria.cronometro:
				_somar(caso + "." + String(etapa), float(Carroceria.cronometro[etapa]) / 1000.0)
	# Encomendada: quem sabe o carro que vem (o Transito) pede antes; o
	# `montar` do Carro so pega.
	# Dois lotes de 14 (a fila guarda ate MAX_ENCOMENDAS prontas sem dono).
	for lote in 2:
		var carros: Array = []
		for j in 2 * n_modelos:
			var i := lote * 2 * n_modelos + j
			carros.append([Carroceria.Modelo.values()[i % n_modelos],
				Carroceria.TINTAS[(i * 7) % Carroceria.TINTAS.size()], 1000 + i, true, true,
				[] if i % 3 != 0 else [[Vector3(-1, 0, 0.5), 0.7]]])
		await arvore.process_frame
		for a: Array in carros:
			var te := Time.get_ticks_usec()
			Carroceria.encomendar(a[0], a[1], a[2], a[3], a[4], a[5])
			_somar("carroceria.encomendar.fio", _ms(te, Time.get_ticks_usec()))
		var tq := Time.get_ticks_usec()
		var espera := 0
		while espera < 600:
			await arvore.process_frame
			var agora := Time.get_ticks_usec()
			_somar("carroceria.encomendar.quadro_durante", _ms(tq, agora))
			tq = agora
			espera += 1
			var todas := true
			for a: Array in carros:
				if not Carroceria.encomenda_pronta(a[0], a[1], a[2], a[3], a[4], a[5]):
					todas = false
					break
			if todas:
				break
		for a: Array in carros:
			await arvore.process_frame
			var t0 := Time.get_ticks_usec()
			var _d := Carroceria.montar(a[0], a[1], a[2], a[3], a[4], a[5])
			_somar("carroceria.encomendada.fio", _ms(t0, Time.get_ticks_usec()))
		_relatar("carroceria.encomendas.lote%d" % lote,
			"%d carros prontos em %d quadros; usadas=%d tomadas=%d" % [carros.size(), espera,
			Carroceria.encomendas_usadas, Carroceria.encomendas_tomadas])


# --- despejo e comparacao ---------------------------------------------------------

static func _sha(v: Variant) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(var_to_bytes(v))
	return h.finish().hex_encode().substr(0, 24)


## O material como ele decide a imagem: o arquivo, ou o shader e os parametros
## que o recorte e o rosto mudam.
static func _desc_material(m: Material) -> String:
	if m == null:
		return "-"
	if not m.resource_path.is_empty():
		return m.resource_path
	var sm := m as ShaderMaterial
	if sm != null:
		var partes := PackedStringArray([sm.shader.resource_path if sm.shader != null else "?"])
		for p: StringName in [&"alpha_cutoff", &"relevo", &"albedo_tex", &"albedo_hd"]:
			var v: Variant = sm.get_shader_parameter(p)
			if v is Resource:
				v = (v as Resource).resource_path
			partes.append("%s=%s" % [p, v])
		return " ".join(partes)
	# Material montado em codigo (Standard): toda propriedade guardada, com a
	# textura pelo caminho.
	var props: Array = []
	for p: Dictionary in m.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var v: Variant = m.get(p["name"])
		if v is Resource:
			v = (v as Resource).resource_path
		elif v is Object:
			continue
		props.append([p["name"], v])
	return m.get_class() + ":" + _sha(props)


static func _desc_malha(mesh: Mesh) -> Array:
	if mesh == null:
		return []
	var out: Array = []
	var am := mesh as ArrayMesh
	for s in mesh.get_surface_count():
		# O formato (quais atributos, compressao) so a ArrayMesh diz; a malha
		# primitiva (a esfera da sinuca) gera os arrays e basta.
		out.append([_sha(mesh.surface_get_arrays(s)),
			am.surface_get_format(s) if am != null else -1,
			_desc_material(mesh.surface_get_material(s))])
	return out


static func _nome_limpo(n: StringName) -> String:
	# Nome gerado pelo motor ("@MeshInstance3D@123", o no sem nome) nao diz
	# nada e muda de rodada para rodada: vazio. Do resto, o nome dado.
	return String(n).get_slice("@", 0)


static func _desc_mi(mi: GeometryInstance3D) -> Dictionary:
	var d := {"nome": _nome_limpo(mi.name), "visivel": mi.visible,
		"sombra": mi.cast_shadow, "mat": _desc_material(mi.material_override),
		"xf": mi.transform, "camadas": mi.layers}
	var m := mi as MeshInstance3D
	if m != null:
		d["malha"] = _desc_malha(m.mesh)
		if m.skin != null:
			var binds: Array = []
			for b in m.skin.get_bind_count():
				binds.append([m.skin.get_bind_bone(b), m.skin.get_bind_pose(b)])
			d["pele"] = _sha(binds)
	var mm := mi as MultiMeshInstance3D
	if mm != null and mm.multimesh != null:
		d["multimesh"] = [_desc_malha(mm.multimesh.mesh), mm.multimesh.instance_count,
			_sha(mm.multimesh.buffer), mm.visibility_range_end]
	return d


## Tudo que decide a imagem de uma pessoa, menos a pose.
func _foto_corpo(c: Corpo) -> Dictionary:
	var sk := c.esqueleto()
	var ossos: Array = []
	for b in sk.get_bone_count():
		ossos.append([sk.get_bone_name(b), sk.get_bone_parent(b), sk.get_bone_rest(b)])
	var malhas: Array = []
	var rosto_nos: Array = []
	for f: Node in sk.get_children():
		var mi := f as MeshInstance3D
		if mi == null:
			continue
		var nome := _nome_limpo(mi.name)
		if nome.begins_with("Rosto_"):
			rosto_nos.append([nome, mi.visible, _desc_material(mi.material_override)])
			continue
		# No apagado e sem malha nao desenha nada (a barba guardada de quem nao
		# usa, no Corpo reciclado).
		if mi.mesh == null and not mi.visible:
			continue
		malhas.append(_desc_mi(mi))
	malhas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["nome"] < b["nome"])
	rosto_nos.sort()
	var d := {"ossos": _sha(ossos), "malhas": malhas, "rosto_nos": rosto_nos,
		"tri": c.triangulos(), "pano": c.tem_pano, "abducao": c.abducao(),
		"perfil": _sha(c.perfil()), "altura": c.altura(), "tem_rosto": c.rosto != null}
	return d


## As malhas de todos os estados do rosto desta pessoa.
static func _foto_rosto(c: Corpo) -> Dictionary:
	if not Rosto.tem_rosto(c.aparencia()):
		return {}
	var r := Rosto.new(c)
	var out := {}
	var estados := {&"boca": RostoMeta.BOCAS, &"sobr_e": RostoMeta.SOBRANCELHAS,
		&"sobr_d": RostoMeta.SOBRANCELHAS, &"olho_e": RostoMeta.OLHOS,
		&"olho_d": RostoMeta.OLHOS}
	for peca: StringName in estados:
		for e: StringName in estados[peca]:
			out["%s/%s" % [peca, e]] = _desc_malha(r._malha(peca, e))
	r.desmontar()
	return out


static func _foto_no(raiz: Node) -> Array:
	var out: Array = []
	for f: Node in raiz.find_children("*", "GeometryInstance3D", true, false):
		var d := _desc_mi(f as GeometryInstance3D)
		var caminho := PackedStringArray()
		for parte: String in String(raiz.get_path_to(f)).split("/"):
			caminho.append(_nome_limpo(parte))
		d["caminho"] = "/".join(caminho)
		out.append(d)
	return out


func _fazer_despejo() -> void:
	var arvore := get_tree()
	var tudo := {}
	var aps := _aparencias(_fichas_despejo, 424242, true)
	var t0 := Time.get_ticks_msec()
	for band_nome: String in BANDEIRAS:
		var band: Array = BANDEIRAS[band_nome]
		for i in aps.size():
			var c := _novo_corpo(aps[i], band, _x(i))
			tudo["%d|%s" % [i, band_nome]] = _foto_corpo(c)
			if band_nome == "rua":
				tudo["%d|rosto" % i] = _foto_rosto(c)
			c.free()
			if i % 20 == 0:
				await arvore.process_frame
	# O mesmo Corpo montado pessoa atras de pessoa, como o pool fara: tem de dar
	# exatamente a pessoa montada do zero.
	var extra: Array = []
	for band_nome: String in ["rua", "motorista"]:
		var band: Array = BANDEIRAS[band_nome]
		var c := _novo_corpo(aps[aps.size() - 1], band, 0.0)
		for i in aps.size():
			c.montar(aps[i])
			# O esqueleto velho sai no fim do quadro (queue_free no codigo antigo).
			await arvore.process_frame
			var foto := _foto_corpo(c)
			tudo["%d|%s|reciclado" % [i, band_nome]] = foto
			extra.append(["reciclado_igual_ao_novo|%d|%s" % [i, band_nome], foto,
				"%d|%s" % [i, band_nome]])
		c.free()
	var classe_variantes: Variant = _classe(&"VariantesDeCorpo")
	if classe_variantes != null:
		# O pool: um Corpo so, `reiniciar` e as bandeiras de cada pessoa, na
		# ordem que calhar (rua, motorista, perto, criacao, rua...): nada da
		# pessoa anterior pode vazar para a seguinte.
		var nomes: Array = BANDEIRAS.keys()
		var c := _novo_corpo(aps[0], BANDEIRAS["criacao"], 0.0)
		for i in aps.size():
			var band_nome: String = nomes[(i * 3 + i / 4) % nomes.size()]
			var band: Array = BANDEIRAS[band_nome]
			c.call(&"reiniciar")
			c.detalhado = bool(band[0])
			c.com_rosto = bool(band[1])
			c.piscar = bool(band[2])
			c.montar(aps[i])
			await arvore.process_frame
			extra.append(["pool|%d|%s" % [i, band_nome], _foto_corpo(c),
				"%d|%s" % [i, band_nome]])
		c.free()
		# A thread: cache vazio, a bandeira inteira encomendada, esperada pronta,
		# e so entao montada. A malha que saiu do WorkerThreadPool tem de ser a
		# mesma. Uma bandeira por vez: as quatro juntas passam do LIMITE, e a
		# poda levaria as primeiras antes de alguem pedi-las.
		for band_nome: String in BANDEIRAS:
			var band: Array = BANDEIRAS[band_nome]
			classe_variantes.call(&"limpar")
			var antes_thread := int(classe_variantes.get(&"na_thread"))
			for ap: Dictionary in aps:
				classe_variantes.call(&"encomendar", ap, band[0], band[2])
			var espera := 0
			while espera < 600:
				await arvore.process_frame
				espera += 1
				var todas := true
				for ap: Dictionary in aps:
					if not bool(classe_variantes.call(&"pronta", ap, band[0], band[2])):
						todas = false
						break
				if todas:
					break
			_relatar("thread." + band_nome, "%d montadas na thread em %d quadros" % [
				int(classe_variantes.get(&"na_thread")) - antes_thread, espera])
			for i in aps.size():
				var c2 := _novo_corpo(aps[i], band, _x(i))
				extra.append(["thread|%d|%s" % [i, band_nome], _foto_corpo(c2),
					"%d|%s" % [i, band_nome]])
				c2.free()
		_relatar("variantes", "guardadas=%s no_fio=%s na_thread=%s achadas=%s" % [
			classe_variantes.call(&"quantas"), classe_variantes.get(&"no_fio"),
			classe_variantes.get(&"na_thread"), classe_variantes.get(&"achadas")])
	# Props.
	for i in 4:
		var tv := Televisao.new()
		_raiz.add_child(tv)
		tudo["tv|%d" % i] = _foto_no(tv)
		# A neve da abertura, e a volta dela para a partida.
		tv.mostrar_estatica(true)
		tudo["tv|%d|neve" % i] = _foto_no(tv)
		tv.mostrar_estatica(false)
		tudo["tv|%d|volta" % i] = _foto_no(tv)
		tv.free()
		var sin := JogoSinuca.criar({"pos": Vector3(0.0, 0.0, -3.0), "giro": 0.0, "semente": i})
		_raiz.add_child(sin)
		tudo["sinuca|%d" % i] = _foto_no(sin)
		sin.free()
	for id: StringName in [&"cerveja", &"guarana", &"pinga", &"coxinha", &"torresmo"]:
		for vez in 2:
			var p := PedidoNoBalcao.novo(id)
			_raiz.add_child(p)
			tudo["pedido|%s|%d" % [id, vez]] = _foto_no(p)
			p.free()
	var carros: Array = []
	for i in 2 * Carroceria.Modelo.size():
		var modelo: Carroceria.Modelo = Carroceria.Modelo.values()[i % Carroceria.Modelo.size()]
		carros.append([modelo, Carroceria.TINTAS[(i * 5) % Carroceria.TINTAS.size()], i * 3,
			true, true, [] if i < Carroceria.Modelo.size() else [[Vector3(1, 0, 0.3), 0.8]]])
	var tri_conferidas := 0
	var tri_erradas := 0
	for i in carros.size():
		var a: Array = carros[i]
		var d := Carroceria.montar(a[0], a[1], a[2], a[3], a[4], a[5])
		tudo["carroceria|%d" % i] = _foto_carroceria(d)
		# `PSXMesh.triangle_count` conta pelo tamanho da ArrayMesh, sem ler a
		# GPU: tem de dar o mesmo que contar pelos arrays.
		for k: String in d:
			if d[k] is Mesh:
				tri_conferidas += 1
				if PSXMesh.triangle_count(d[k]) != _tri_pelos_arrays(d[k]):
					tri_erradas += 1
	_relatar("triangle_count", "%d malhas, %d diferentes da conta pelos arrays" % [
		tri_conferidas, tri_erradas])
	# A carroceria encomendada: montada na thread, pega pronta pelo `montar`.
	if true:
		var aceitas := 0
		for a: Array in carros:
			if Carroceria.encomendar(a[0], a[1], a[2], a[3], a[4], a[5]):
				aceitas += 1
		var espera := 0
		while espera < 600:
			await arvore.process_frame
			espera += 1
			var todas := true
			for a: Array in carros:
				if not Carroceria.encomenda_pronta(a[0], a[1], a[2], a[3], a[4], a[5]):
					todas = false
					break
			if todas:
				break
		var usadas_antes := Carroceria.encomendas_usadas
		for i in carros.size():
			var a: Array = carros[i]
			extra.append(["carroceria_encomendada|%d" % i, _foto_carroceria(Carroceria.montar(
				a[0], a[1], a[2], a[3], a[4], a[5])), "carroceria|%d" % i])
		_relatar("carroceria_encomendada", "aceitas=%d prontas em %d quadros, usadas=%d" % [
			aceitas, espera, Carroceria.encomendas_usadas - usadas_antes])
	_relatar("despejo", "%d chaves em %d ms" % [tudo.size(), Time.get_ticks_msec() - t0])

	if not _despejo.is_empty():
		var f := FileAccess.open(_despejo, FileAccess.WRITE)
		f.store_var(tudo)
		f.close()
		_relatar("gravado", _despejo)
	if not _comparar.is_empty():
		var f := FileAccess.open(_comparar, FileAccess.READ)
		var antes: Dictionary = f.get_var()
		f.close()
		var iguais := 0
		var diferentes: Array[String] = []
		var faltando: Array[String] = []
		for chave: String in antes:
			if not tudo.has(chave):
				faltando.append(chave)
			elif _igual(antes[chave], tudo[chave]):
				iguais += 1
			else:
				diferentes.append(chave)
		for chave: String in tudo:
			if not antes.has(chave):
				faltando.append("+" + chave)
		_relatar("comparacao", "iguais=%d diferentes=%d faltando=%d" % [iguais,
			diferentes.size(), faltando.size()])
		for chave in diferentes.slice(0, 12):
			_relatar("diferente." + chave, "\n  antes=%s\n  agora=%s" % [antes[chave], tudo[chave]])
		for chave in faltando.slice(0, 12):
			_relatar("faltando", chave)
		# As provas cruzadas: reciclado, pool e thread contra a pessoa montada do
		# zero pelo codigo de antes.
		var por_grupo := {}
		for par: Array in extra:
			var grupo := String(par[0]).get_slice("|", 0)
			var cont: Vector2i = por_grupo.get(grupo, Vector2i.ZERO)
			if antes.has(par[2]) and _igual(antes[par[2]], par[1]):
				cont.x += 1
			else:
				cont.y += 1
				if cont.y <= 4:
					_relatar("diferente." + String(par[0]), "\n  antes=%s\n  agora=%s" % [
						antes.get(par[2]), par[1]])
			por_grupo[grupo] = cont
		for grupo: String in por_grupo:
			var cont: Vector2i = por_grupo[grupo]
			_relatar("comparacao." + grupo, "iguais=%d diferentes=%d" % [cont.x, cont.y])


## A conta antiga de `PSXMesh.triangle_count`: pelos arrays lidos da GPU.
static func _tri_pelos_arrays(mesh: Mesh) -> int:
	var total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		total += indices.size() / 3 if not indices.is_empty() \
			else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## O que `Carroceria.montar` devolve, com cada malha pela impressao digital.
## `luzes_dados` e novo (os dados de `luzes`, para o Carro nao ler a GPU): fica
## fora, para comparar com o despejo do codigo de antes.
static func _foto_carroceria(d: Dictionary) -> Dictionary:
	var foto := {}
	for chave: String in d:
		if chave == "luzes_dados":
			continue
		var v: Variant = d[chave]
		if v is Mesh:
			foto[chave] = _desc_malha(v)
		elif v is Dictionary and chave == "longe":
			var l := {}
			for k2: String in v:
				l[k2] = _desc_malha(v[k2]) if v[k2] is Mesh else v[k2]
			foto[chave] = l
		else:
			foto[chave] = v
	return foto


## Uma classe global pelo nome, ou null se ela nao existe nesta arvore (o mesmo
## despejo roda no codigo de antes, que nao tinha a `VariantesDeCorpo`).
static func _classe(nome: StringName) -> Variant:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == nome:
			return load(String(c["path"]))
	return null


## Igualdade profunda (Dictionary == compara por referencia no GDScript 4).
static func _igual(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return false
		for k: Variant in da:
			if not db.has(k) or not _igual(da[k], db[k]):
				return false
		return true
	if a is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return false
		for i in aa.size():
			if not _igual(aa[i], ab[i]):
				return false
		return true
	return a == b
