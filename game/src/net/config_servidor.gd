## Configuracao de quem hospeda: servidor dedicado ou o jogo aberto para amigos.
##
## Tres camadas, a de baixo perde para a de cima:
##   1. o padrao deste arquivo
##   2. `servidor.cfg` (secao [servidor]) — o que o dono de um dedicado edita
##   3. a linha de comando depois de `--` — o que script, Docker e teste passam
##
## O arquivo mora em `user://` por padrao, e `--config=CAMINHO` aponta outro (um
## volume montado no container, por exemplo). Se nao existir, o servidor escreve
## um modelo comentado ali na primeira vez: ninguem deveria ter de adivinhar o
## nome de uma chave lendo codigo.
class_name ConfigServidor
extends RefCounted

const ARQUIVO_PADRAO := "user://servidor.cfg"
const SECAO := "servidor"

var porta: int = ProtocoloRede.PORTA_PADRAO
var max_jogadores: int = ProtocoloRede.MAX_JOGADORES_PADRAO
var nome: String = "SERVIDOR"
## Vazio = sem senha.
var senha: String = ""
## Recado mostrado a quem entra.
var mensagem: String = ""
## Anunciar na rede local (LAN, Hamachi, Radmin). Desligar em servidor publico:
## anunciar numa rede de datacenter nao acha ninguem e so gasta pacote.
var anunciar_lan: bool = true
## O que fazer com movimento implausivel:
##   "corrigir"   recusa e devolve o jogador ao ultimo ponto aceito (padrao desde
##                23/09: comodo, desmaio, save e chegada anunciam o salto, a
##                Sessao marca sozinha todo salto acima de 8 m, e o teste de ponta
##                a ponta entra e sai de interior com zero correcao)
##   "registrar"  anota e aceita (para depurar um teletransporte novo)
var validacao: String = "corrigir"
## Encerrar sozinho depois de tantos segundos. So para teste; 0 = nunca.
var sair_apos: float = 0.0
## Onde o arquivo foi lido (ou seria escrito).
var caminho: String = ARQUIVO_PADRAO


static func carregar(argumentos: PackedStringArray) -> ConfigServidor:
	var c := ConfigServidor.new()
	for a: String in argumentos:
		if a.begins_with("--config="):
			c.caminho = a.trim_prefix("--config=")
	c.ler_arquivo(c.caminho)
	c.aplicar_argumentos(argumentos)
	return c


## Le o arquivo, se existir. Chave ausente fica no padrao.
func ler_arquivo(arquivo: String) -> Error:
	var cfg := ConfigFile.new()
	var err := cfg.load(arquivo)
	if err != OK:
		return err
	porta = int(cfg.get_value(SECAO, "porta", porta))
	max_jogadores = int(cfg.get_value(SECAO, "max_jogadores", max_jogadores))
	nome = String(cfg.get_value(SECAO, "nome", nome))
	senha = String(cfg.get_value(SECAO, "senha", senha))
	mensagem = String(cfg.get_value(SECAO, "mensagem", mensagem))
	anunciar_lan = bool(cfg.get_value(SECAO, "anunciar_lan", anunciar_lan))
	validacao = String(cfg.get_value(SECAO, "validacao", validacao))
	return OK


func aplicar_argumentos(argumentos: PackedStringArray) -> void:
	for a: String in argumentos:
		if a.begins_with("--porta="):
			porta = a.trim_prefix("--porta=").to_int()
		elif a.begins_with("--max-jogadores="):
			max_jogadores = a.trim_prefix("--max-jogadores=").to_int()
		elif a.begins_with("--nome="):
			nome = a.trim_prefix("--nome=")
		elif a.begins_with("--senha="):
			senha = a.trim_prefix("--senha=")
		elif a.begins_with("--mensagem="):
			mensagem = a.trim_prefix("--mensagem=")
		elif a == "--sem-lan":
			anunciar_lan = false
		elif a.begins_with("--validacao="):
			validacao = a.trim_prefix("--validacao=")
		elif a.begins_with("--sair-apos="):
			sair_apos = a.trim_prefix("--sair-apos=").to_float()


## Problemas que impedem o servidor de subir. Vazio = pode subir.
func erros() -> PackedStringArray:
	var e := PackedStringArray()
	if porta < 1024 or porta > 65535:
		e.append("porta %d fora de 1024..65535" % porta)
	if max_jogadores < 1 or max_jogadores > ProtocoloRede.MAX_JOGADORES_TETO:
		e.append("max_jogadores %d fora de 1..%d" % [
			max_jogadores, ProtocoloRede.MAX_JOGADORES_TETO])
	if not validacao in ["registrar", "corrigir"]:
		e.append("validacao '%s' nao e registrar nem corrigir" % validacao)
	if senha.length() > ProtocoloRede.SENHA_MAX:
		e.append("senha passa de %d caracteres" % ProtocoloRede.SENHA_MAX)
	return e


## Nome ja saneado, para anuncio e desafio.
func nome_publico() -> String:
	return ProtocoloRede.sanear_texto(nome, 32).to_upper()


## Escreve o modelo comentado se o arquivo nao existe. Nunca sobrescreve.
func escrever_modelo_se_faltar() -> bool:
	if FileAccess.file_exists(caminho):
		return false
	var f := FileAccess.open(caminho, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(MODELO % [porta, max_jogadores])
	f.close()
	return true


const MODELO := """; Servidor dedicado de Nevoa e Dither.
; Qualquer chave tambem vale na linha de comando, depois de --:
;   --porta=24567 --max-jogadores=16 --nome=... --senha=... --sem-lan
; Plano completo: MULTIPLAYER/PLANO/18_SERVIDOR_DEDICADO.md

[servidor]

; Porta UDP. Abra ESTA porta no firewall/roteador (UDP, nao TCP).
porta=%d

; Quantas pessoas ao mesmo tempo (1..32).
max_jogadores=%d

; Nome que aparece na lista de servidores da rede local.
nome="SERVIDOR"

; Vazio = sem senha.
senha=""

; Recado mostrado a quem entra.
mensagem=""

; Anunciar na rede local (LAN, Hamachi, Radmin). Desligue em VPS/datacenter.
anunciar_lan=true

; corrigir  = recusa e devolve o jogador ao ultimo ponto aceito
; registrar = anota movimento impossivel e aceita
validacao="corrigir"
"""
