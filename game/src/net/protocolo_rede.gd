## Contrato de fio da sessao de rede: constantes, formato dos pacotes e o que se
## aceita de quem esta do outro lado.
##
## Tudo aqui e funcao pura. A Sessao (autoload) so move bytes; quem diz o que os
## bytes significam e este arquivo, e por isso ele se testa sem socket nenhum
## (`tests/mp/run_tests_rede.gd`).
##
## Por que pacote em bytes e nao Dictionary no RPC
## -----------------------------------------------
## Um Dictionary de estado com seis chaves custa ~180 bytes no fio: o Godot manda
## o nome de cada chave e o tipo de cada valor. Em bytes o mesmo estado sao 21. A
## 20 Hz, com 16 jogadores, e a diferenca entre 58 KB/s e 7 KB/s por cliente. E o
## formato fixo tem outra vantagem, que importa mais que a banda: o servidor sabe
## o tamanho exato do que pode chegar, e pacote de tamanho errado nem e lido.
##
## Plano: MULTIPLAYER/PLANO/04_CONTRATO_DE_REDE.md e 20_PROTOCOLO.md.
class_name ProtocoloRede
extends RefCounted

## Sobe a cada mudanca no formato de qualquer pacote OU no que o mundo gera a
## partir da coordenada. Cliente e servidor com numero diferente nao conversam:
## a cidade sai da semente do chunk, e duas versoes do gerador desenham ruas
## diferentes no mesmo lugar sem erro nenhum na tela — um jogador anda na
## calcada e o outro o ve andando por dentro de um predio.
const VERSAO := 1
const JOGO := "nevoa_e_dither"

## 24567, e nao 7777: todo tutorial usa 7777 e a maquina de quem desenvolve
## costuma ter outra coisa escutando ali (plano 03 secao 5).
const PORTA_PADRAO := 24567
## Anuncio de servidor na rede local (LAN, Hamachi, Radmin, ZeroTier).
const PORTA_DESCOBERTA := 24568

const MAX_JOGADORES_PADRAO := 8
## Teto do servidor dedicado. Acima disso o instantaneo passa de 1 KB e o custo
## O(n^2) da montagem por cliente comeca a aparecer; subir pede medida.
const MAX_JOGADORES_TETO := 32

## Envio de estado do cliente e instantaneo do servidor, por segundo.
##
## Horror anda a 2,4 m/s. A 20 Hz sao 12 cm entre pacotes a pe, que a
## interpolacao cobre sem se ver. Um carro a 100 km/h anda 1,4 m entre pacotes,
## e ai quem cobre e o atraso de interpolacao abaixo.
const TICK_HZ := 20
## Atraso com que o jogador remoto e desenhado, em segundos.
##
## Dois pacotes e meio de folga: um pacote perdido (UDP) ainda deixa um par para
## interpolar, e o jogador remoto nunca para no ar esperando. Menos que isso e
## qualquer perda vira tranco; mais e o amigo reage tarde a porta que voce abriu.
const ATRASO_INTERPOLACAO := 0.12
## Quanto se extrapola quando o pacote nao chega. Passado disso o avatar para
## onde estava: extrapolar meio segundo leva o amigo para dentro da parede.
const EXTRAPOLACAO_MAX := 0.25
## Salto entre dois pacotes que se trata como teletransporte (entrar em
## interior, respawn, carregar save): corta seco em vez de deslizar.
const SALTO_TELEPORTE := 8.0

## Silencio que derruba um peer (ENet: minimo e maximo, em ms). Plano P11.
const TIMEOUT_MIN_MS := 3000
const TIMEOUT_MAX_MS := 8000
## Quanto um peer tem para se autenticar antes de ser derrubado, em segundos.
const TEMPO_AUTENTICACAO := 5.0

## Raio de interesse: alem disso o servidor nao manda o jogador para o cliente.
## Nevoa densa fecha a 18 m e o preset mais aberto carrega ~100 m; 160 m cobre
## o horizonte do Vulkan sem mandar a cidade inteira para quem esta num canto.
const RAIO_INTERESSE := 160.0

const NOME_MAX := 24
const CHAT_MAX := 96
const SENHA_MAX := 64
## Teto de qualquer mensagem de autenticacao, em bytes.
const AUTH_MAX := 8192

# --- espaco -------------------------------------------------------------------
# Onde o corpo esta. Dois corpos so se veem no mesmo espaco: interiores vivem a
# +2000 m em Y e a Estrada Velha a +4000 m, e dois interiores diferentes sao
# montados no MESMO lugar. Sem isto, quem esta no mercado ve o amigo que esta no
# bar andando por dentro das gondolas.
const ESPACO_RUA := 0
const ESPACO_ESTRADA := 1
## Primeiro id de interior; os de baixo sao reservados.
const ESPACO_INTERIOR_BASE := 16

## Faixas de altura que separam os espacos. Ver `Interiores.DESLOCAMENTO` (2000)
## e `AberturaEstrada.ALTURA` (4000).
const Y_INTERIOR := 1000.0
const Y_ESTRADA := 3000.0

# --- flags de estado (bits) ---------------------------------------------------
const F_AGACHADO := 1
const F_CORRENDO := 2
const F_LANTERNA := 4
const F_NO_CHAO := 8
const F_CARRO := 16
const F_BICICLETA := 32
## O proprio cliente declara que acabou de ser teletransportado. O servidor so
## confia nisso quando o espaco muda junto (ver ValidadorMovimento).
const F_TELEPORTE := 64
const F_TODAS := 127

# --- tamanhos de pacote ---------------------------------------------------------
## pos (3 x f32) + yaw (u16) + rapidez (u16) + flags (u8) + espaco (u32).
const TAM_ESTADO := 21
## modelo (u8) + semente (s32), so com F_CARRO.
const TAM_VEICULO := 5
## seq (u32) + hora da amostra (f64) + estado.
const TAM_CLIENTE_MIN := 12 + TAM_ESTADO
const TAM_CLIENTE_MAX := 12 + TAM_ESTADO + TAM_VEICULO
## tick (u32) + tempo (f64) + quantidade (u8).
const TAM_CABECALHO_INSTANTANEO := 13
## Por jogador no instantaneo: id (u32) + idade da amostra em ms (u16).
const TAM_ENTRADA := 6

## Limites de posicao aceitos. Abaixo de -200 e queda no vazio; acima de 5000 nao
## ha espaco nenhum do jogo.
const Y_MIN := -200.0
const Y_MAX := 5000.0
const XZ_MAX := 1000000.0

# --- motivos de recusa na entrada -------------------------------------------------
const RECUSA_JOGO := "jogo"
const RECUSA_VERSAO := "versao"
const RECUSA_SENHA := "senha"
const RECUSA_CHEIO := "cheio"
const RECUSA_PEDIDO := "pedido"

const TEXTO_RECUSA := {
	RECUSA_JOGO: "Isso nao e um servidor deste jogo.",
	RECUSA_VERSAO: "Versao diferente. Atualize o jogo dos dois lados.",
	RECUSA_SENHA: "Senha errada.",
	RECUSA_CHEIO: "Servidor cheio.",
	RECUSA_PEDIDO: "Pedido de entrada invalido.",
}


# --- estado ---------------------------------------------------------------------

static func escrever_estado(b: StreamPeerBuffer, e: Dictionary) -> void:
	var p: Vector3 = e.get("pos", Vector3.ZERO)
	b.put_float(p.x)
	b.put_float(p.y)
	b.put_float(p.z)
	b.put_u16(yaw_para_u16(float(e.get("yaw", 0.0))))
	# Rapidez em cm/s. 655 m/s de teto: nada no jogo chega perto.
	b.put_u16(clampi(roundi(float(e.get("rapidez", 0.0)) * 100.0), 0, 65535))
	var flags := int(e.get("flags", 0)) & F_TODAS
	b.put_u8(flags)
	b.put_u32(int(e.get("espaco", ESPACO_RUA)) & 0xFFFFFFFF)
	if flags & F_CARRO:
		b.put_u8(int(e.get("modelo", 0)) & 0xFF)
		b.put_32(int(e.get("semente", 0)))


## Le um estado. Devolve {} se faltar byte ou se o conteudo for invalido — quem
## chama descarta o pacote inteiro, nunca aplica metade.
static func ler_estado(b: StreamPeerBuffer) -> Dictionary:
	if b.get_available_bytes() < TAM_ESTADO:
		return {}
	var x := b.get_float()
	var y := b.get_float()
	var z := b.get_float()
	var yaw := u16_para_yaw(b.get_u16())
	var rapidez := float(b.get_u16()) / 100.0
	var flags := b.get_u8() & F_TODAS
	var espaco := b.get_u32()
	var e := {
		"pos": Vector3(x, y, z),
		"yaw": yaw,
		"rapidez": rapidez,
		"flags": flags,
		"espaco": espaco,
	}
	if flags & F_CARRO:
		if b.get_available_bytes() < TAM_VEICULO:
			return {}
		e["modelo"] = b.get_u8()
		e["semente"] = b.get_32()
	return e if estado_valido(e) else {}


static func estado_valido(e: Dictionary) -> bool:
	if not e.has("pos"):
		return false
	var p: Vector3 = e["pos"]
	if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
		return false
	if p.y < Y_MIN or p.y > Y_MAX:
		return false
	if absf(p.x) > XZ_MAX or absf(p.z) > XZ_MAX:
		return false
	return true


static func yaw_para_u16(yaw: float) -> int:
	if not is_finite(yaw):
		return 0
	return roundi(fposmod(yaw, TAU) / TAU * 65535.0) & 0xFFFF


static func u16_para_yaw(v: int) -> float:
	return wrapf(float(v) / 65535.0 * TAU, -PI, PI)


# --- pacote do cliente -------------------------------------------------------------

## `t_amostra` e a hora do SERVIDOR (estimada pelo cliente) em que o estado foi
## lido. Sem ela, o servidor so sabe quando o pacote chegou, e a idade do estado
## — ate um tick, mais a viagem — vira erro de posicao em quem desenha. Medido
## antes deste campo: 8 cm de mediana e 16 cm de pico a 2,4 m/s, que sao 33 ms
## de atraso sistematico. Com ele, o erro cai para o da interpolacao.
static func pacote_do_cliente(seq: int, t_amostra: float, e: Dictionary) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u32(seq & 0xFFFFFFFF)
	b.put_double(t_amostra)
	escrever_estado(b, e)
	return b.data_array


## {"seq": int, "t": float, "estado": Dictionary} ou {} se o pacote nao presta.
static func ler_pacote_do_cliente(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < TAM_CLIENTE_MIN or bytes.size() > TAM_CLIENTE_MAX:
		return {}
	var b := StreamPeerBuffer.new()
	b.data_array = bytes
	var seq := b.get_u32()
	var t := b.get_double()
	var e := ler_estado(b)
	if e.is_empty() or b.get_available_bytes() != 0:
		return {}
	return {"seq": seq, "t": t if is_finite(t) else 0.0, "estado": e}


## A hora de amostra que o servidor aceita de um cliente. Fora da janela (relogio
## do cliente ainda sem convergir, ou mentira) vale a hora de chegada. Um segundo
## para tras e o bastante para a pior rede que ainda joga; para a frente, so a
## folga do arredondamento.
##
## Prende na janela em vez de trocar pela hora de chegada: trocar de fonte no
## meio do caminho faz a linha do tempo do jogador pular, e o boneco dele para
## ou corre por um instante.
static func hora_de_amostra_aceita(t_declarada: float, t_chegada: float) -> float:
	if not is_finite(t_declarada) or t_declarada <= 0.0:
		return t_chegada
	return clampf(t_declarada, t_chegada - 1.0, t_chegada + 0.05)


# --- instantaneo do servidor ----------------------------------------------------------

## `entradas`: lista de {"id": int, "t": hora da amostra, ...estado}. No maximo
## 255 por pacote. A hora de cada um vai como idade relativa ao instantaneo, em
## ms: dois bytes em vez de oito, e 65 s de teto, que nenhum estado vivo atinge.
static func instantaneo(tick: int, t_servidor: float, entradas: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	var n := mini(entradas.size(), 255)
	b.put_u32(tick & 0xFFFFFFFF)
	b.put_double(t_servidor)
	b.put_u8(n)
	for i in n:
		var ent: Dictionary = entradas[i]
		b.put_u32(int(ent["id"]) & 0xFFFFFFFF)
		var idade := t_servidor - float(ent.get("t", t_servidor))
		b.put_u16(clampi(roundi(idade * 1000.0), 0, 65535))
		escrever_estado(b, ent)
	return b.data_array


## {"tick": int, "t": float, "jogadores": {id: estado com "t"}} ou {} se nao
## presta. Cada estado volta com a hora da propria amostra em "t".
static func ler_instantaneo(bytes: PackedByteArray) -> Dictionary:
	var teto := TAM_CABECALHO_INSTANTANEO + 255 * (TAM_ENTRADA + TAM_ESTADO + TAM_VEICULO)
	if bytes.size() < TAM_CABECALHO_INSTANTANEO or bytes.size() > teto:
		return {}
	var b := StreamPeerBuffer.new()
	b.data_array = bytes
	var tick := b.get_u32()
	var t := b.get_double()
	if not is_finite(t):
		return {}
	var n := b.get_u8()
	var jogadores := {}
	for i in n:
		if b.get_available_bytes() < TAM_ENTRADA:
			return {}
		var id := b.get_u32()
		var idade := float(b.get_u16()) / 1000.0
		var e := ler_estado(b)
		if e.is_empty():
			return {}
		e["t"] = t - idade
		jogadores[id] = e
	if b.get_available_bytes() != 0:
		return {}
	return {"tick": tick, "t": t, "jogadores": jogadores}


# --- espaco -------------------------------------------------------------------------------

static func espaco_interior(tipo: StringName, semente: int) -> int:
	return ESPACO_INTERIOR_BASE + (hash([String(tipo), semente]) & 0x3FFFFFFF)


## Espaco por altura, para quem nao tem `Interiores` a mao (servidor, teste).
## O caminho do jogo usa `Sessao.espaco_do_corpo`, que sabe QUAL interior.
static func faixa_de_espaco(y: float) -> int:
	if y > Y_ESTRADA:
		return ESPACO_ESTRADA
	if y > Y_INTERIOR:
		return ESPACO_INTERIOR_BASE
	return ESPACO_RUA


# --- autenticacao -----------------------------------------------------------------------------
# Tres mensagens, todas Dictionary em var_to_bytes, pelo canal de autenticacao do
# SceneMultiplayer — que roda ANTES de o peer existir para o resto do jogo. Um
# cliente de versao errada ou senha errada nunca chega a mandar um RPC.
#
#   servidor -> cliente  desafio   {tipo, jogo, v, nonce, senha: bool, nome, n, max}
#   cliente  -> servidor pedido    {tipo, jogo, v, nome, aparencia, prova}
#   servidor -> cliente  veredito  {tipo, ok: bool, motivo}
#
# A prova e sha256(nonce + ":" + senha). O nonce muda a cada conexao, entao a
# prova capturada numa conexao nao abre a proxima. Nao e criptografia de canal —
# isso e DTLS, plano 18 secao 7 — mas a senha nunca viaja em texto.

static func mensagem(d: Dictionary) -> PackedByteArray:
	return var_to_bytes(d)


## Le uma mensagem de autenticacao. `bytes_to_var` sem objetos: um peer nao
## consegue instanciar nada deste lado mandando bytes.
static func ler_mensagem(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > AUTH_MAX:
		return {}
	var v: Variant = bytes_to_var(bytes)
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	return v


static func novo_nonce() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func prova_de_senha(senha: String, nonce: String) -> String:
	return (nonce + ":" + senha).sha256_text()


## Veredito do servidor sobre um pedido. "" = aceito; senao, um RECUSA_*.
static func julgar_pedido(pedido: Dictionary, nonce: String, senha: String,
		ocupados: int, maximo: int) -> String:
	if String(pedido.get("jogo", "")) != JOGO:
		return RECUSA_JOGO
	if int(pedido.get("v", -1)) != VERSAO:
		return RECUSA_VERSAO
	if String(pedido.get("tipo", "")) != "pedido":
		return RECUSA_PEDIDO
	if not senha.is_empty():
		var prova := String(pedido.get("prova", ""))
		if prova != prova_de_senha(senha, nonce):
			return RECUSA_SENHA
	if ocupados >= maximo:
		return RECUSA_CHEIO
	return ""


# --- saneamento -----------------------------------------------------------------------------

## Texto de outra maquina, pronto para ir numa Label. Sem caractere de controle,
## sem quebra de linha, com teto.
static func sanear_texto(s: String, teto: int) -> String:
	var saida := ""
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 32 or c == 127:
			continue
		saida += String.chr(c)
		if saida.length() >= teto:
			break
	return saida.strip_edges()


static func sanear_nome(s: String) -> String:
	var n := sanear_texto(s, NOME_MAX).to_upper()
	return n if not n.is_empty() else "VIAJANTE"


## Faixas aceitas para as medidas do corpo. Fora disso o `Corpo` monta, mas monta
## um gigante de cinco metros ou uma pessoa sem ombro — e a malha vem de um peer
## que qualquer um pode escrever.
const FAIXAS_APARENCIA := {
	"altura": Vector2(1.30, 2.10),
	"ombro": Vector2(0.20, 0.60),
	"quadril": Vector2(0.20, 0.60),
	"corpulencia": Vector2(0.60, 1.50),
	"gordura": Vector2(0.0, 1.0),
	"passo": Vector2(0.40, 1.60),
	"cadencia": Vector2(0.40, 1.60),
	"voz": Vector2(0.50, 1.80),
}
## Chaves que o `Corpo` le e que a ficha sorteada nao traz (so o elenco).
const CHAVES_BOOL_EXTRA := ["cacheado", "coque", "tatuagem"]


## A aparencia que chegou, reduzida ao que o `Corpo` sabe ler, com cada valor no
## tipo e na faixa certos. Chave desconhecida cai; chave faltando vem da
## referencia — `Corpo.montar` nunca recebe um dicionario pela metade.
static func sanear_aparencia(d: Variant) -> Dictionary:
	var ref := aparencia_de_referencia()
	var saida := ref.duplicate(true)
	if typeof(d) != TYPE_DICTIONARY:
		return saida
	var entrada: Dictionary = d
	for chave_bruta: Variant in entrada:
		var chave := String(chave_bruta) if (typeof(chave_bruta) == TYPE_STRING
			or typeof(chave_bruta) == TYPE_STRING_NAME) else ""
		if chave.is_empty():
			continue
		var tipo_ref := typeof(ref.get(chave)) if ref.has(chave) else (
			TYPE_BOOL if CHAVES_BOOL_EXTRA.has(chave) else TYPE_NIL)
		if tipo_ref == TYPE_NIL:
			continue
		var v: Variant = entrada[chave_bruta]
		match tipo_ref:
			TYPE_FLOAT:
				if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
					continue
				var f := float(v)
				if not is_finite(f):
					continue
				var faixa: Vector2 = FAIXAS_APARENCIA.get(chave, Vector2(-4.0, 4.0))
				saida[chave] = clampf(f, faixa.x, faixa.y)
			TYPE_INT:
				if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
					continue
				saida[chave] = clampi(int(v), 0, 255)
			TYPE_BOOL:
				if typeof(v) == TYPE_BOOL:
					saida[chave] = v
			TYPE_COLOR:
				if typeof(v) != TYPE_COLOR:
					continue
				var c: Color = v
				saida[chave] = Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0),
					clampf(c.b, 0.0, 1.0), 1.0)
	return saida


## A pessoa que o `Player` monta quando nao ha ficha (player.gd, _refazer_corpo).
static func aparencia_de_referencia() -> Dictionary:
	return Aparencia.de_ficha({"id": 7, "sexo": &"M", "idade": 31})
