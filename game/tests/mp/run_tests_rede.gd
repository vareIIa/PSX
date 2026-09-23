## Contrato da rede, nivel 2 (plano 14): o que se aceita no fio, sem socket.
##
##     godot --headless --path game --script res://tests/mp/run_tests_rede.gd
##
## Cobre o que e funcao pura — formato de pacote, saneamento, autenticacao,
## relogio, interpolacao, validacao, configuracao, descoberta. O que depende de
## dois processos (entrar, ver o outro, medir em centimetros) e o nivel 4:
## `tools/mp_teste.sh`.
##
## So classes sem autoload entram aqui: no modo --script o Godot nao registra os
## autoloads como identificadores (memoria do projeto, "teste de nivel 2 nao
## alcanca classe de tela"), e e por isso que o contrato mora em ProtocoloRede e
## nao na Sessao.
extends SceneTree

var _falhas: PackedStringArray = []
var _total: int = 0


func _initialize() -> void:
	print("\n=== contrato de rede ===\n")
	_estado_ida_e_volta()
	_pacotes_invalidos()
	_instantaneo()
	_hora_de_amostra()
	_autenticacao()
	_saneamento()
	_endereco()
	_espaco()
	_relogio()
	_interpolacao()
	_validador()
	_config()
	_descoberta()
	_assinatura()

	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return
	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)


func _check(cond: bool, msg: String) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _secao(nome: String) -> void:
	print("-- %s" % nome)


func _perto(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


# --- testes -------------------------------------------------------------------------

func _estado_ida_e_volta() -> void:
	_secao("estado: ida e volta")
	var e := {
		"pos": Vector3(-80.25, 0.5, 112.75), "yaw": 2.5, "rapidez": 4.6,
		"flags": ProtocoloRede.F_CORRENDO | ProtocoloRede.F_NO_CHAO | ProtocoloRede.F_LANTERNA,
		"espaco": ProtocoloRede.ESPACO_RUA,
	}
	var bytes := ProtocoloRede.pacote_do_cliente(7, 123.456, e)
	_check(bytes.size() == ProtocoloRede.TAM_CLIENTE_MIN,
		"pacote a pe tem %d bytes (esperado %d)" % [bytes.size(), ProtocoloRede.TAM_CLIENTE_MIN])
	var p := ProtocoloRede.ler_pacote_do_cliente(bytes)
	_check(not p.is_empty(), "pacote a pe volta")
	if p.is_empty():
		return
	var v: Dictionary = p["estado"]
	_check(int(p["seq"]) == 7, "seq volta")
	_check(_perto(float(p["t"]), 123.456, 1e-9), "hora da amostra volta em f64")
	_check((v["pos"] as Vector3).distance_to(e["pos"]) < 1e-4, "posicao volta")
	_check(_perto(float(v["yaw"]), 2.5, TAU / 65535.0), "giro volta com um passo de u16")
	_check(_perto(float(v["rapidez"]), 4.6, 0.01), "rapidez volta em cm/s")
	_check(int(v["flags"]) == int(e["flags"]), "flags voltam")

	var carro := e.duplicate()
	carro["flags"] = ProtocoloRede.F_CARRO
	carro["modelo"] = 5
	carro["semente"] = -123456
	var pc := ProtocoloRede.ler_pacote_do_cliente(ProtocoloRede.pacote_do_cliente(8, 1.0, carro))
	_check(not pc.is_empty(), "pacote com carro volta")
	if not pc.is_empty():
		var vc: Dictionary = pc["estado"]
		_check(int(vc["modelo"]) == 5 and int(vc["semente"]) == -123456,
			"modelo e semente com sinal voltam")
	# Giro negativo e acima de TAU dao a mesma volta.
	_check(ProtocoloRede.yaw_para_u16(-PI / 2.0) == ProtocoloRede.yaw_para_u16(3.0 * PI / 2.0),
		"giro normaliza a volta")
	_check(ProtocoloRede.yaw_para_u16(NAN) == 0, "giro NaN vira zero")

	# Estado v2: arfagem da cabeca e flags de 16 bits.
	var olhando := e.duplicate()
	olhando["arfagem"] = deg_to_rad(-45.0)
	olhando["flags"] = ProtocoloRede.F_LANTERNA | ProtocoloRede.F_SENTADO | ProtocoloRede.F_AUSENTE \
		| ProtocoloRede.F_CARONA
	var po := ProtocoloRede.ler_pacote_do_cliente(ProtocoloRede.pacote_do_cliente(9, 2.0, olhando))
	_check(not po.is_empty(), "estado v2 volta")
	if not po.is_empty():
		var vo: Dictionary = po["estado"]
		_check(_perto(float(vo["arfagem"]), deg_to_rad(-45.0), deg_to_rad(0.64)),
			"arfagem volta com um passo de u8 (0,63 grau)")
		_check(int(vo["flags"]) == int(olhando["flags"]), "flags acima de 8 bits voltam")
	_check(ProtocoloRede.u8_para_arfagem(ProtocoloRede.arfagem_para_u8(0.0)) == 0.0,
		"olhar reto volta zero exato")
	_check(_perto(ProtocoloRede.u8_para_arfagem(ProtocoloRede.arfagem_para_u8(PI)),
		ProtocoloRede.ARFAGEM_MAX, 1e-6), "arfagem presa em 80 graus")
	_check(ProtocoloRede.arfagem_para_u8(NAN) == 128, "arfagem NaN vira o horizonte")
	var so_flags := e.duplicate()
	so_flags["flags"] = 0xFFFF
	var pf := ProtocoloRede.ler_pacote_do_cliente(ProtocoloRede.pacote_do_cliente(10, 2.0, so_flags))
	_check(not pf.is_empty() and int(pf["estado"]["flags"]) == ProtocoloRede.F_TODAS,
		"bit desconhecido nao passa")
	_check(ProtocoloRede.F_FAROL == ProtocoloRede.F_LANTERNA
		and ProtocoloRede.F_FREANDO == ProtocoloRede.F_AGACHADO
		and ProtocoloRede.F_FREIO_DE_MAO == ProtocoloRede.F_CORRENDO,
		"no carro, os bits de quem anda a pe viram luz e freio")


func _pacotes_invalidos() -> void:
	_secao("pacotes invalidos sao recusados inteiros")
	var bom := ProtocoloRede.pacote_do_cliente(1, 1.0, {"pos": Vector3.ZERO})
	_check(ProtocoloRede.ler_pacote_do_cliente(bom.slice(0, bom.size() - 1)).is_empty(),
		"um byte a menos")
	var mais := bom.duplicate()
	mais.append(0)
	_check(ProtocoloRede.ler_pacote_do_cliente(mais).is_empty(), "um byte a mais")
	_check(ProtocoloRede.ler_pacote_do_cliente(PackedByteArray()).is_empty(), "vazio")
	for pos: Vector3 in [Vector3(NAN, 0, 0), Vector3(0, INF, 0), Vector3(0, 9000, 0),
			Vector3(0, -500, 0), Vector3(2e6, 0, 0)]:
		var b := ProtocoloRede.pacote_do_cliente(1, 1.0, {"pos": pos})
		_check(ProtocoloRede.ler_pacote_do_cliente(b).is_empty(), "posicao %s" % pos)
	# Flag de carro sem os bytes do carro. O byte baixo das flags esta em 12 (seq
	# + hora) + 12 (pos) + 2 (giro) + 2 (rapidez) + 1 (arfagem).
	var sem_carro := ProtocoloRede.pacote_do_cliente(1, 1.0, {"pos": Vector3.ZERO})
	sem_carro[12 + 17] = ProtocoloRede.F_CARRO
	_check(ProtocoloRede.ler_pacote_do_cliente(sem_carro).is_empty(), "F_CARRO sem veiculo")
	# Autenticacao: lixo, tipo errado, grande demais.
	_check(ProtocoloRede.ler_mensagem(PackedByteArray([1, 2, 3])).is_empty(), "auth lixo")
	_check(ProtocoloRede.ler_mensagem(var_to_bytes([1, 2])).is_empty(), "auth que nao e dicionario")
	var grande := PackedByteArray()
	grande.resize(ProtocoloRede.AUTH_MAX + 1)
	_check(ProtocoloRede.ler_mensagem(grande).is_empty(), "auth acima do teto")


func _instantaneo() -> void:
	_secao("instantaneo")
	var entradas := []
	for i in 3:
		entradas.append({"id": 100 + i, "t": 10.0 - 0.01 * i, "pos": Vector3(i, 0.5, -i),
			"yaw": 0.1 * i, "rapidez": 2.4, "flags": ProtocoloRede.F_NO_CHAO, "espaco": 0})
	var bytes := ProtocoloRede.instantaneo(42, 10.0, entradas)
	_check(bytes.size() == ProtocoloRede.TAM_CABECALHO_INSTANTANEO
		+ 3 * (ProtocoloRede.TAM_ENTRADA + ProtocoloRede.TAM_ESTADO),
		"tamanho do instantaneo: %d bytes" % bytes.size())
	var inst := ProtocoloRede.ler_instantaneo(bytes)
	_check(not inst.is_empty(), "instantaneo volta")
	if inst.is_empty():
		return
	_check(int(inst["tick"]) == 42 and _perto(float(inst["t"]), 10.0, 1e-9), "cabecalho volta")
	var lista: Dictionary = inst["jogadores"]
	_check(lista.size() == 3 and lista.has(101), "tres jogadores com id")
	_check(_perto(float(lista[102]["t"]), 9.98, 0.0011), "hora de cada amostra volta com 1 ms")
	_check(ProtocoloRede.ler_instantaneo(bytes.slice(0, bytes.size() - 2)).is_empty(),
		"instantaneo cortado e recusado")
	# Amostra "do futuro" (relogio adiantado) nao gera idade negativa.
	var futuro := ProtocoloRede.ler_instantaneo(ProtocoloRede.instantaneo(1, 5.0,
		[{"id": 1, "t": 5.2, "pos": Vector3.ZERO, "espaco": 0}]))
	_check(_perto(float(futuro["jogadores"][1]["t"]), 5.0, 1e-6), "amostra adiantada vira a hora do instantaneo")


func _hora_de_amostra() -> void:
	_secao("hora de amostra aceita pelo servidor")
	_check(_perto(ProtocoloRede.hora_de_amostra_aceita(9.97, 10.0), 9.97, 1e-9), "normal passa")
	_check(_perto(ProtocoloRede.hora_de_amostra_aceita(0.0, 10.0), 10.0, 1e-9), "zero vira chegada")
	_check(_perto(ProtocoloRede.hora_de_amostra_aceita(NAN, 10.0), 10.0, 1e-9), "NaN vira chegada")
	_check(_perto(ProtocoloRede.hora_de_amostra_aceita(3.0, 10.0), 9.0, 1e-9), "velha demais e presa em 1 s")
	_check(_perto(ProtocoloRede.hora_de_amostra_aceita(12.0, 10.0), 10.05, 1e-9), "do futuro e presa")


func _autenticacao() -> void:
	_secao("autenticacao")
	var nonce := ProtocoloRede.novo_nonce()
	_check(nonce.length() == 32, "nonce de 16 bytes em hex")
	_check(nonce != ProtocoloRede.novo_nonce(), "nonce muda a cada conexao")
	var pedido := {"tipo": "pedido", "jogo": ProtocoloRede.JOGO, "v": ProtocoloRede.VERSAO,
		"prova": ProtocoloRede.prova_de_senha("abacaxi", nonce)}
	_check(ProtocoloRede.julgar_pedido(pedido, nonce, "abacaxi", 0, 8) == "", "senha certa entra")
	_check(ProtocoloRede.julgar_pedido(pedido, nonce, "banana", 0, 8) == ProtocoloRede.RECUSA_SENHA,
		"senha errada")
	_check(ProtocoloRede.julgar_pedido(pedido, ProtocoloRede.novo_nonce(), "abacaxi", 0, 8)
		== ProtocoloRede.RECUSA_SENHA, "prova de outra conexao nao abre esta")
	_check(ProtocoloRede.julgar_pedido(pedido, nonce, "", 0, 8) == "", "sem senha, prova e ignorada")
	_check(ProtocoloRede.julgar_pedido(pedido, nonce, "", 8, 8) == ProtocoloRede.RECUSA_CHEIO, "cheio")
	var velho := pedido.duplicate()
	velho["v"] = ProtocoloRede.VERSAO - 1
	_check(ProtocoloRede.julgar_pedido(velho, nonce, "", 0, 8) == ProtocoloRede.RECUSA_VERSAO, "versao")
	var outro := pedido.duplicate()
	outro["jogo"] = "outro"
	_check(ProtocoloRede.julgar_pedido(outro, nonce, "", 0, 8) == ProtocoloRede.RECUSA_JOGO, "outro jogo")
	_check(ProtocoloRede.julgar_pedido({}, nonce, "", 0, 8) != "", "pedido vazio")
	_check(ProtocoloRede.prova_de_senha("x", nonce).find("x") < 0, "a senha nao viaja na prova")

	# Cidade: mesma versao, gerador diferente.
	var com_cidade := pedido.duplicate()
	com_cidade["cidade"] = "0123456789abcdef"
	_check(ProtocoloRede.julgar_pedido(com_cidade, nonce, "", 0, 8, "0123456789abcdef") == "",
		"mesma cidade entra")
	_check(ProtocoloRede.julgar_pedido(com_cidade, nonce, "", 0, 8, "fedcba9876543210")
		== ProtocoloRede.RECUSA_CIDADE, "outra cidade e recusada")
	_check(ProtocoloRede.julgar_pedido(pedido, nonce, "", 0, 8, "fedcba9876543210")
		== ProtocoloRede.RECUSA_CIDADE, "pedido sem cidade e recusado quando o servidor tem uma")
	_check(ProtocoloRede.julgar_pedido(com_cidade, nonce, "", 0, 8, "") == "",
		"servidor sem assinatura ainda nao confere a cidade")
	_check(ProtocoloRede.TEXTO_RECUSA.has(ProtocoloRede.RECUSA_CIDADE), "cidade tem texto para o jogador")
	# A versao vem antes da cidade: quem esta em outra versao le "versao", que diz o
	# que fazer, e nao "cidade".
	var velho_e_outra := com_cidade.duplicate()
	velho_e_outra["v"] = ProtocoloRede.VERSAO - 1
	_check(ProtocoloRede.julgar_pedido(velho_e_outra, nonce, "", 0, 8, "fedcba9876543210")
		== ProtocoloRede.RECUSA_VERSAO, "versao e conferida antes da cidade")


func _saneamento() -> void:
	_secao("saneamento")
	_check(ProtocoloRede.sanear_nome("  maria\n\t ") == "MARIA", "nome: espaco, controle, maiuscula")
	_check(ProtocoloRede.sanear_nome("") == "VIAJANTE", "nome vazio")
	_check(ProtocoloRede.sanear_nome("x".repeat(100)).length() == ProtocoloRede.NOME_MAX, "nome com teto")
	# NUL nao existe em String do Godot; o controle de teste e o 0x01 e o DEL.
	var sujo := "a" + String.chr(1) + "b" + String.chr(127) + "c
"
	_check(ProtocoloRede.sanear_texto(sujo, 10) == "abc", "texto sem controle")

	var ref := ProtocoloRede.aparencia_de_referencia()
	var limpa := ProtocoloRede.sanear_aparencia(ref)
	_check(limpa == ref, "aparencia valida passa igual")
	var ruim := ref.duplicate()
	ruim["altura"] = 50.0
	ruim["ombro"] = NAN
	ruim["camisa"] = 9999
	ruim["pele"] = Color(5, -1, 0.5, 0.2)
	ruim["script"] = "res://malicioso.gd"
	ruim[&"calvo"] = "sim"
	ruim.erase("rosto")
	var s := ProtocoloRede.sanear_aparencia(ruim)
	_check(_perto(float(s["altura"]), 2.10, 1e-6), "altura presa na faixa")
	_check(is_finite(float(s["ombro"])), "NaN nao entra")
	_check(int(s["camisa"]) == 255, "celula presa em 255")
	var pele: Color = s["pele"]
	_check(pele.r == 1.0 and pele.g == 0.0 and pele.a == 1.0, "cor presa em 0..1, opaca")
	_check(not s.has("script"), "chave desconhecida cai")
	_check(typeof(s["calvo"]) == TYPE_BOOL, "tipo errado nao entra")
	_check(s.has("rosto"), "chave faltando vem da referencia")
	_check(ProtocoloRede.sanear_aparencia("lixo") == ref, "nao-dicionario vira a referencia")
	var elenco := ref.duplicate()
	elenco["cacheado"] = true
	_check(bool(ProtocoloRede.sanear_aparencia(elenco).get("cacheado", false)), "chave do elenco passa")


func _endereco() -> void:
	_secao("endereco")
	_check(ProtocoloRede.separar_endereco("25.1.2.3") == ["25.1.2.3", ProtocoloRede.PORTA_PADRAO], "so IP")
	_check(ProtocoloRede.separar_endereco(" 25.1.2.3:3000 ") == ["25.1.2.3", 3000], "IP e porta")
	_check(ProtocoloRede.separar_endereco("meu.servidor.com:24570") == ["meu.servidor.com", 24570], "nome")
	_check(ProtocoloRede.separar_endereco("x:99999")[1] == ProtocoloRede.PORTA_PADRAO, "porta invalida")
	_check(ProtocoloRede.separar_endereco("::1")[0] == "::1", "IPv6 fica inteiro")


func _espaco() -> void:
	_secao("espaco")
	_check(ProtocoloRede.faixa_de_espaco(0.5) == ProtocoloRede.ESPACO_RUA, "rua")
	_check(ProtocoloRede.faixa_de_espaco(2000.5) >= ProtocoloRede.ESPACO_INTERIOR_BASE, "interior")
	_check(ProtocoloRede.faixa_de_espaco(4000.5) == ProtocoloRede.ESPACO_ESTRADA, "estrada")
	var a := ProtocoloRede.espaco_interior(&"mercado", 77451)
	_check(a == ProtocoloRede.espaco_interior(&"mercado", 77451), "mesmo interior, mesmo espaco")
	_check(a != ProtocoloRede.espaco_interior(&"bar", 77451), "tipo diferente, espaco diferente")
	_check(a != ProtocoloRede.espaco_interior(&"mercado", 77452), "semente diferente, espaco diferente")
	_check(a >= ProtocoloRede.ESPACO_INTERIOR_BASE and a <= 0xFFFFFFFF, "cabe em u32 sem colidir com rua")


func _relogio() -> void:
	_secao("relogio de rede")
	var r := RelogioDeRede.new()
	_check(not r.pronto(), "comeca sem estimativa")
	# Servidor 100 s adiante. Primeiro pacote chega 300 ms atrasado.
	r.amostrar(100.0 + 1.0 - 0.3, 1.0)
	_check(r.pronto() and _perto(r.agora(1.0), 100.7, 1e-6), "primeiro pacote da a estimativa")
	# Pacote rapido: a estimativa sobe NA HORA (limite de baixo).
	r.amostrar(100.0 + 1.05 - 0.002, 1.05)
	_check(_perto(r.agora(1.05), 101.048, 1e-6), "pacote rapido corrige para cima de uma vez")
	# Nunca volta no tempo, mesmo com a janela so de pacotes atrasados.
	var anterior := r.agora(1.05)
	var monotono := true
	for i in range(1, 200):
		var tl := 1.05 + 0.05 * float(i)
		r.amostrar(100.0 + tl - 0.8, tl)
		var agora := r.agora(tl)
		if agora < anterior:
			monotono = false
		anterior = agora
	_check(monotono, "relogio nunca anda para tras")
	var tl_fim := 1.05 + 0.05 * 199.0
	_check(r.agora(tl_fim) > 100.0 + tl_fim - 0.81, "desce ate o atraso novo, devagar")
	_check(r.agora(tl_fim) <= 100.0 + tl_fim, "nunca passa da hora real do servidor")


func _interpolacao() -> void:
	_secao("interpolacao")
	var b := BufferInterpolacao.new()
	_check(b.amostrar(1.0).is_empty() and not b.cobre(1.0), "vazio")
	for i in 5:
		b.empurrar(float(i) * 0.05, {"pos": Vector3(float(i) * 0.12, 0, 0), "yaw": 0.0,
			"rapidez": 2.4, "flags": 0, "espaco": 0})
	_check(not b.cobre(-0.01) and b.cobre(0.0), "cobre so a partir da primeira amostra")
	var meio := b.amostrar(0.075)
	_check(_perto((meio["pos"] as Vector3).x, 0.18, 1e-5), "meio do caminho entre dois pacotes")
	b.empurrar(0.1, {"pos": Vector3(99, 0, 0), "espaco": 0})
	_check(_perto(b.ultimo_t(), 0.2, 1e-9), "amostra fora de ordem e descartada")
	var alem := b.amostrar(0.2 + 0.1)
	_check(_perto((alem["pos"] as Vector3).x, 0.48 + 0.24, 1e-4), "extrapola na mesma velocidade")
	var muito := b.amostrar(0.2 + 5.0)
	_check(_perto((muito["pos"] as Vector3).x, 0.48 + 2.4 * ProtocoloRede.EXTRAPOLACAO_MAX, 1e-4),
		"extrapolacao para no teto")
	# Teletransporte: corta seco, nao desliza atravessando parede.
	b.empurrar(0.25, {"pos": Vector3(500, 2000, 0), "espaco": 20, "flags": 0})
	var tp := b.amostrar(0.24)
	_check((tp["pos"] as Vector3).x < 1.0, "antes do salto fica no ponto velho")
	_check(int(b.amostrar(0.25)["espaco"]) == 20, "no salto, o espaco novo")
	# Giro pelo arco curto.
	var g := BufferInterpolacao.misturar({"pos": Vector3.ZERO, "yaw": PI - 0.1},
		{"pos": Vector3.ZERO, "yaw": -PI + 0.1}, 0.5)
	_check(absf(absf(float(g["yaw"])) - PI) < 0.01, "giro atravessa +-PI pelo lado curto")
	var arf := BufferInterpolacao.misturar({"pos": Vector3.ZERO, "arfagem": -0.4},
		{"pos": Vector3.ZERO, "arfagem": 0.2}, 0.5)
	_check(_perto(float(arf["arfagem"]), -0.1, 1e-6), "arfagem interpolada, a lanterna nao pula")


func _validador() -> void:
	_secao("validador de movimento")
	var v := ValidadorMovimento.new()
	_check(v.conferir(Vector3.ZERO, 0, 0, 1, 10.0), "primeiro estado")
	_check(v.conferir(Vector3(0.23, 0, 0), 0, 0, 2, 10.05), "andando")
	# Dois pacotes amontoados no mesmo quadro do servidor: o seq diz que passou um tick.
	_check(v.conferir(Vector3(0.46, 0, 0), 0, 0, 3, 10.05), "pacotes amontoados pelo Wi-Fi")
	_check(not v.conferir(Vector3(30, 0, 0), 0, 0, 4, 10.10), "30 m a pe em 50 ms")
	_check(v.suspeitas == 1, "suspeita contada")
	_check(v.ultimo_aceito().distance_to(Vector3(0.46, 0, 0)) < 1e-6, "ultimo aceito nao avanca")
	_check(v.conferir(Vector3(3.9, 0, 0), ProtocoloRede.F_CARRO, 0, 5, 10.15), "carro a 70 m/s")
	_check(v.conferir(Vector3(500, 2000, 0), 0, 99, 6, 10.2), "entrar em interior (espaco novo)")
	# Mentir no seq nao compra mais que meio segundo sobre o relogio do servidor.
	var w := ValidadorMovimento.new()
	w.conferir(Vector3.ZERO, 0, 0, 1, 0.0)
	_check(not w.conferir(Vector3(40, 0, 0), 0, 0, 100000, 0.05), "seq inflado nao libera teletransporte")
	# Teletransporte declarado no mesmo espaco (acordar no orelhao): uma vez a cada 3 s.
	var tp := ValidadorMovimento.new()
	tp.conferir(Vector3.ZERO, 0, 0, 1, 0.0)
	_check(tp.conferir(Vector3(300, 0, 0), ProtocoloRede.F_TELEPORTE, 0, 2, 0.05),
		"teletransporte declarado passa")
	_check(not tp.conferir(Vector3(600, 0, 0), ProtocoloRede.F_TELEPORTE, 0, 3, 1.0),
		"segundo teletransporte em menos de 3 s nao passa")
	_check(tp.conferir(Vector3(600, 0, 0), ProtocoloRede.F_TELEPORTE, 0, 4, 3.1),
		"depois de 3 s passa de novo")
	_check(tp.teleportes == 2, "teletransportes contados")


func _config() -> void:
	_secao("configuracao do servidor")
	var c := ConfigServidor.new()
	c.aplicar_argumentos(PackedStringArray(["--porta=25000", "--max-jogadores=16", "--nome=Mata",
		"--senha=s3", "--sem-lan", "--validacao=corrigir", "--sair-apos=2.5"]))
	_check(c.porta == 25000 and c.max_jogadores == 16 and c.nome == "Mata", "argumentos basicos")
	_check(c.senha == "s3" and not c.anunciar_lan and c.validacao == "corrigir", "senha, lan, validacao")
	_check(_perto(c.sair_apos, 2.5, 1e-9), "sair-apos")
	_check(c.erros().is_empty(), "config valida")
	c.porta = 80
	c.max_jogadores = 99
	c.validacao = "banir"
	_check(c.erros().size() == 3, "tres problemas apontados")
	_check(ConfigServidor.MODELO.contains("[servidor]") and ConfigServidor.MODELO.contains("porta="),
		"modelo comentado tem a secao e as chaves")


func _descoberta() -> void:
	_secao("descoberta na rede local")
	var bom := JSON.stringify({"jogo": ProtocoloRede.JOGO, "v": ProtocoloRede.VERSAO,
		"nome": "mundo de ze\n", "porta": 24567, "n": 3, "max": 8, "senha": true}).to_utf8_buffer()
	var info := DescobertaLan.ler_anuncio(bom, "25.10.20.30")
	_check(not info.is_empty() and info["compativel"], "anuncio valido")
	_check(info.get("nome", "") == "MUNDO DE ZE", "nome saneado")
	_check(DescobertaLan.ler_anuncio("{}".to_utf8_buffer(), "1.2.3.4").is_empty(), "sem jogo")
	var outra_versao := JSON.stringify({"jogo": ProtocoloRede.JOGO, "v": 999, "porta": 1}).to_utf8_buffer()
	var ov := DescobertaLan.ler_anuncio(outra_versao, "1.2.3.4")
	_check(not ov.is_empty() and not ov["compativel"], "outra versao aparece marcada")
	var destinos := DescobertaLan.destinos()
	_check(destinos.has("255.255.255.255"), "broadcast limitado sempre")
	var com_cidade := JSON.stringify({"jogo": ProtocoloRede.JOGO, "v": ProtocoloRede.VERSAO,
		"porta": 24567, "cidade": "0123456789abcdef"}).to_utf8_buffer()
	_check(DescobertaLan.ler_anuncio(com_cidade, "1.2.3.4").get("cidade", "") == "0123456789abcdef",
		"cidade do anuncio passa")
	var cidade_suja := JSON.stringify({"jogo": ProtocoloRede.JOGO, "v": ProtocoloRede.VERSAO,
		"porta": 24567, "cidade": "<b>oi</b>"}).to_utf8_buffer()
	_check(DescobertaLan.ler_anuncio(cidade_suja, "1.2.3.4").get("cidade", "x") == "",
		"cidade que nao e hex cai")


func _assinatura() -> void:
	_secao("assinatura do mundo")
	var cidade := func(cx: int, cz: int) -> Dictionary:
		return {
			"props": [
				{"tipo": "lampada", "pos": Vector3(13.2 + cx, 1.24, 17.575 + cz), "semente": 763359131782},
				{"tipo": "porta", "pos": Vector3(2.0, -12.94, 16.0)},
			],
			"colisao": [1, 2, 3],
			"triangulos": 2714,
		}
	var a := AssinaturaDoMundo.calcular(cidade)
	_check(a.length() == AssinaturaDoMundo.TAMANHO, "assinatura de %d hex" % AssinaturaDoMundo.TAMANHO)
	_check(a == AssinaturaDoMundo.calcular(cidade), "mesma cidade, mesma assinatura")
	# A mesma cidade sem relevo: a porta desce 12,94 m. E o caso do `--sem-relevo`.
	var plana := func(cx: int, cz: int) -> Dictionary:
		var d: Dictionary = cidade.call(cx, cz)
		(d["props"][1] as Dictionary)["pos"] = Vector3(2.0, 0.0, 16.0)
		return d
	_check(a != AssinaturaDoMundo.calcular(plana), "sem relevo, outra assinatura")
	# Um prop 20 cm para o lado: outra cidade.
	var mexida := func(cx: int, cz: int) -> Dictionary:
		var d: Dictionary = cidade.call(cx, cz)
		(d["props"][0] as Dictionary)["pos"] = Vector3(13.4 + cx, 1.24, 17.575 + cz)
		return d
	_check(a != AssinaturaDoMundo.calcular(mexida), "prop 20 cm ao lado muda a assinatura")
	# Meio milimetro nao e cidade diferente: o decimetro e a regua.
	var ruido := func(cx: int, cz: int) -> Dictionary:
		var d: Dictionary = cidade.call(cx, cz)
		(d["props"][1] as Dictionary)["pos"] = Vector3(2.0005, -12.9404, 16.0)
		return d
	_check(a == AssinaturaDoMundo.calcular(ruido), "ruido abaixo do decimetro nao muda")
	var mais_colisao := func(cx: int, cz: int) -> Dictionary:
		var d: Dictionary = cidade.call(cx, cz)
		(d["colisao"] as Array).append(4)
		return d
	_check(a != AssinaturaDoMundo.calcular(mais_colisao), "uma forma de colisao a mais muda")
	var lixo := func(_cx: int, _cz: int) -> Variant: return "lixo"
	_check(AssinaturaDoMundo.calcular(lixo).length() == AssinaturaDoMundo.TAMANHO,
		"construtor que devolve lixo nao quebra")
