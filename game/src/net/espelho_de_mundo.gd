## O lado do CLIENTE das mudancas de mundo: previsao, revisao e a espera da carga
## (plano 04 secoes 4.3, 4.4 e 7).
##
## Puro: nunca toca o WorldState. Cada chamada DEVOLVE as escritas que quem chama
## aplica, na ordem, cada uma {"cx": int, "cz": int, "chave": StringName,
## "valor": Variant}. Assim a regra inteira se testa sem autoload.
##
## As tres regras:
## - evento com rev <= rev da carga ja esta dentro da carga, e cai;
## - evento que chega antes da carga terminar espera por ela (canal 0 e canal 2
##   nao tem ordem entre si);
## - previsao pendente numa chave cede ao valor de qualquer outro autor, e
##   volta ao ultimo valor confirmado se o servidor negar.
class_name EspelhoDeMundo
extends RefCounted

## Teto da espera antes da carga. Passou disso, a espera para de guardar e
## `transbordou` fica verdadeiro: o estado ficou incompleto, e quem chama zera e
## pede a carga de novo.
const TETO_ESPERA := 4096

var carregado := false
var rev_base := -1
var transbordou := false

## "cx,cz|chave" -> {"cx", "cz", "chave", "seq", "valor", "anterior"}
var _pendentes: Dictionary = {}
## seq -> "cx,cz|chave". So o seq MAIS NOVO de cada chave: negacao de um seq
## substituido nao desfaz nada.
var _por_seq: Dictionary = {}
var _espera: Array[Dictionary] = []


## A tela ja mostra `valor`. `anterior` e o que ela mostrava antes: o valor que
## o WorldState tem, com o padrao da coisa (nunca null). Se a chave ja tinha
## previsao pendente, o anterior que vale e o dela, que e o ultimo confirmado.
func prever(cx: int, cz: int, chave: StringName, valor: Variant, anterior: Variant, seq: int) -> void:
	var k := _chave(cx, cz, chave)
	if _pendentes.has(k):
		var p: Dictionary = _pendentes[k]
		_por_seq.erase(int(p["seq"]))
		p["seq"] = seq
		p["valor"] = valor
	else:
		_pendentes[k] = {"cx": cx, "cz": cz, "chave": chave, "seq": seq,
			"valor": valor, "anterior": anterior}
	_por_seq[seq] = k


## `ev`: {"rev", "cx", "cz", "chave", "valor", "autor", "seq"} do `_mundo_mudou`.
func receber(ev: Dictionary, meu_id: int) -> Array[Dictionary]:
	var nada: Array[Dictionary] = []
	if not carregado:
		if _espera.size() >= TETO_ESPERA:
			transbordou = true
		else:
			_espera.append(ev)
		return nada
	if int(ev.get("rev", -1)) <= rev_base:
		return nada
	return _aplicar(ev, meu_id)


## A carga chegou e ja foi aplicada por quem chama. Devolve as escritas da
## espera que vieram depois dela, na ordem de chegada.
func concluir_carga(rev: int, meu_id: int) -> Array[Dictionary]:
	carregado = true
	rev_base = rev
	var saida: Array[Dictionary] = []
	for ev: Dictionary in _espera:
		if int(ev.get("rev", -1)) > rev_base:
			saida.append_array(_aplicar(ev, meu_id))
	_espera.clear()
	return saida


## O servidor negou `seq`. Se ele ainda e a previsao mais nova da chave, a tela
## volta ao ultimo valor confirmado. Se uma previsao mais nova o substituiu, nada
## muda: a resposta dela e que assenta a chave.
func negado(seq: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if not _por_seq.has(seq):
		return saida
	var k: String = _por_seq[seq]
	var p: Dictionary = _pendentes[k]
	_soltar(k)
	saida.append(_escrita(int(p["cx"]), int(p["cz"]), StringName(p["chave"]), p["anterior"]))
	return saida


func pendentes() -> int:
	return _pendentes.size()


func zerar() -> void:
	carregado = false
	rev_base = -1
	transbordou = false
	_pendentes.clear()
	_por_seq.clear()
	_espera.clear()


func _aplicar(ev: Dictionary, meu_id: int) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var cx := int(ev.get("cx", 0))
	var cz := int(ev.get("cz", 0))
	var chave := StringName(ev.get("chave", &""))
	var valor: Variant = ev.get("valor")
	var k := _chave(cx, cz, chave)
	if _pendentes.has(k):
		var p: Dictionary = _pendentes[k]
		if int(ev.get("autor", 0)) == meu_id:
			var seq := int(ev.get("seq", -1))
			if seq == int(p["seq"]):
				# A tela ja mostra isso.
				_soltar(k)
				return saida
			if seq < int(p["seq"]):
				# Confirmacao de uma previsao mais velha; a mais nova ainda voa. Se
				# ela for negada, e para este valor que a tela volta.
				p["anterior"] = valor
				return saida
		# Outro autor escreveu a chave: a previsao cede ao servidor.
		_soltar(k)
	# Sem pendente, inclusive a confirmacao atrasada de uma previsao que cedeu: o
	# servidor a aplicou depois do outro autor, e ela e o valor final.
	saida.append(_escrita(cx, cz, chave, valor))
	return saida


func _soltar(k: String) -> void:
	var p: Dictionary = _pendentes[k]
	_por_seq.erase(int(p["seq"]))
	_pendentes.erase(k)


static func _chave(cx: int, cz: int, chave: StringName) -> String:
	return "%d,%d|%s" % [cx, cz, chave]


static func _escrita(cx: int, cz: int, chave: StringName, valor: Variant) -> Dictionary:
	return {"cx": cx, "cz": cz, "chave": chave, "valor": valor}
