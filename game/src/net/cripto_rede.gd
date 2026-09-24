## A sessao cifrada (DTLS sobre o ENet, plano 13 fase 8).
##
## O que ela resolve: sem isso, qualquer um na mesma rede (o Wi-Fi do bar, a rede
## do Hamachi) le o chat, os nomes e a posicao de todo mundo. Com DTLS, le lixo.
##
## O que ela NAO resolve, e por que esta tudo bem: o certificado e autoassinado e
## o cliente nao o confere (`TLSOptions.client_unsafe`). Um servidor falso no
## meio do caminho seria aceito pela camada de transporte — mas quem entra com
## senha passa pelo desafio da autenticacao (`ProtocoloRede`), que o impostor nao
## sabe responder sem a senha. Conferir certificado pediria uma autoridade, e um
## jogo entre amigos por IP nao tem uma.
##
## A chave e gerada uma vez por maquina (RSA 2048, ~0,3 s) e guardada em
## user://rede/, para nao pagar isso a cada vez que alguem hospeda.
class_name CriptoRede
extends RefCounted

const PASTA := "user://rede"
const CHAVE := "user://rede/servidor.key"
const CERTIFICADO := "user://rede/servidor.crt"

static var _opcoes: TLSOptions


## DESLIGADA por padrao, e ligada so com `--dtls` (ou PSX_DTLS=1) nas DUAS pontas.
##
## Medido em 23/09, em par, com o mesmo `mp_teste.sh` na mesma hora: sem DTLS o
## erro do boneco do amigo fica em p95 0,10 cm e fome 0%; com DTLS, p95 de 2 a
## 23 cm e fome de 1 a 10%. O mediano nao muda, o que muda sao rajadas: o DTLS
## do ENet do Godot 4.7.2 entrega o canal de estado aos solavancos. Sem
## compressao o resultado e o mesmo. Cifrar e fazer o amigo andar aos trancos
## nao e troca que um jogo aceite; fica pronto para quando o motor corrigir.
static func ligada() -> bool:
	return OS.get_cmdline_user_args().has("--dtls") or not OS.get_environment("PSX_DTLS").is_empty()


static func opcoes_do_servidor() -> TLSOptions:
	if _opcoes != null:
		return _opcoes
	var chave := CryptoKey.new()
	var cert := X509Certificate.new()
	var guardadas := FileAccess.file_exists(CHAVE) and FileAccess.file_exists(CERTIFICADO)
	if not guardadas or chave.load(CHAVE) != OK or cert.load(CERTIFICADO) != OK:
		var c := Crypto.new()
		chave = c.generate_rsa(2048)
		cert = c.generate_self_signed_certificate(chave, "CN=nevoa-e-dither,O=PSX,C=BR",
			"20260101000000", "20460101000000")
		DirAccess.make_dir_recursive_absolute(PASTA)
		chave.save(CHAVE)
		cert.save(CERTIFICADO)
	_opcoes = TLSOptions.server(chave, cert)
	return _opcoes


static func opcoes_do_cliente() -> TLSOptions:
	return TLSOptions.client_unsafe()
