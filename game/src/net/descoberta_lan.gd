## Achar servidor na rede local sem digitar IP.
##
## Quem hospeda grita um pacote UDP pequeno por segundo na porta de descoberta;
## quem procura escuta ali e monta a lista. E o mesmo desenho do "Abrir para LAN"
## de qualquer jogo de amigos, e e ele que faz o Hamachi parecer uma LAN.
##
## Por que nao so 255.255.255.255
## -------------------------------
## No Windows, o broadcast limitado sai por UMA placa de rede — a da rota padrao.
## O Hamachi e o Radmin sao placas virtuais, e o pacote nunca chega nelas. Entao o
## anuncio vai tambem para o broadcast DIRIGIDO de cada endereco local: /8 para
## as faixas das VPNs de jogo (Hamachi 25.x, Radmin 26.x) e /24 para o resto.
## O Godot nao expoe a mascara de rede de cada placa; /24 e a de quase toda rede
## domestica, e errar a mascara so faz o pacote nao chegar — nunca chega errado.
##
## Isto e conveniencia. Digitar o IP continua funcionando em qualquer caso, e e o
## que vale para servidor na internet.
class_name DescobertaLan
extends Node

signal lista_mudou()

## Segundos entre anuncios, e depois de quanto silencio um servidor sai da lista.
const INTERVALO := 1.0
const ESQUECER_APOS := 4.0
const TAM_MAX := 512

var _anuncio: PacketPeerUDP
var _escuta: PacketPeerUDP
var _conteudo: Callable
var _acc := 0.0
var _destinos := PackedStringArray()

## "ip:porta" -> {ip, porta, nome, n, max, senha, visto}
var servidores: Dictionary = {}


## Comeca a anunciar. `conteudo` devolve o Dictionary do anuncio a cada envio
## (numero de jogadores muda).
func anunciar(conteudo: Callable) -> void:
	_conteudo = conteudo
	_anuncio = PacketPeerUDP.new()
	_anuncio.set_broadcast_enabled(true)
	_destinos = destinos()
	_acc = INTERVALO
	set_process(true)


## Comeca a escutar. Erro se a porta ja esta tomada — outro jogo aberto na mesma
## maquina escutando; ai a lista fica vazia e o IP digitado ainda funciona.
func escutar() -> Error:
	_escuta = PacketPeerUDP.new()
	var err := _escuta.bind(ProtocoloRede.PORTA_DESCOBERTA, "*")
	if err != OK:
		_escuta = null
		return err
	set_process(true)
	return OK


func parar() -> void:
	if _anuncio != null:
		_anuncio.close()
		_anuncio = null
	if _escuta != null:
		_escuta.close()
		_escuta = null
	servidores.clear()
	set_process(false)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if _anuncio != null:
		_acc += delta
		if _acc >= INTERVALO:
			_acc = 0.0
			_enviar()
	if _escuta != null:
		_receber()


func _enviar() -> void:
	var dados: Dictionary = _conteudo.call() if _conteudo.is_valid() else {}
	dados["jogo"] = ProtocoloRede.JOGO
	dados["v"] = ProtocoloRede.VERSAO
	var bytes := JSON.stringify(dados).to_utf8_buffer()
	for ip: String in _destinos:
		_anuncio.set_dest_address(ip, ProtocoloRede.PORTA_DESCOBERTA)
		_anuncio.put_packet(bytes)


func _receber() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	var mudou := false
	while _escuta.get_available_packet_count() > 0:
		var bytes := _escuta.get_packet()
		var ip := _escuta.get_packet_ip()
		var info := ler_anuncio(bytes, ip)
		if info.is_empty():
			continue
		info["visto"] = agora
		var chave := "%s:%d" % [info["ip"], info["porta"]]
		if not servidores.has(chave):
			mudou = true
		servidores[chave] = info
	for chave: String in servidores.keys():
		if agora - float(servidores[chave]["visto"]) > ESQUECER_APOS:
			servidores.erase(chave)
			mudou = true
	if mudou:
		lista_mudou.emit()


## Anuncio lido e saneado, ou {} se nao e deste jogo nesta versao.
static func ler_anuncio(bytes: PackedByteArray, ip: String) -> Dictionary:
	if bytes.is_empty() or bytes.size() > TAM_MAX:
		return {}
	var v: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	if String(d.get("jogo", "")) != ProtocoloRede.JOGO:
		return {}
	var porta := int(d.get("porta", 0))
	if porta < 1 or porta > 65535:
		return {}
	return {
		"ip": ip,
		"porta": porta,
		"nome": ProtocoloRede.sanear_texto(String(d.get("nome", "")), 32).to_upper(),
		"n": clampi(int(d.get("n", 0)), 0, 255),
		"max": clampi(int(d.get("max", 0)), 0, 255),
		"senha": bool(d.get("senha", false)),
		# Versao diferente aparece na lista, marcada — some sem explicacao e o
		# jogador acha que a rede esta quebrada.
		"compativel": int(d.get("v", -1)) == ProtocoloRede.VERSAO,
	}


## Para onde anunciar: broadcast limitado e o dirigido de cada placa IPv4.
static func destinos() -> PackedStringArray:
	var saida := PackedStringArray(["255.255.255.255"])
	for ip: String in IP.get_local_addresses():
		var partes := ip.split(".")
		if partes.size() != 4 or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		var alvo := ""
		if partes[0] == "25" or partes[0] == "26":
			# Hamachi (25.0.0.0/8) e Radmin VPN (26.0.0.0/8).
			alvo = "%s.255.255.255" % partes[0]
		else:
			alvo = "%s.%s.%s.255" % [partes[0], partes[1], partes[2]]
		if not saida.has(alvo):
			saida.append(alvo)
	return saida
