## Falar: texto, voz e boca num relogio so.
##
## Antes eram tres relogios que por acaso andavam juntos: a UI digitava a 44
## letras por segundo, a `Voz` murmurava no maximo sete silabas ao acaso (0,95 s)
## e o corpo balancava a cabeca enquanto a linha nao acabava. Uma frase de cem
## letras digitava por 2,3 s com a voz calada na metade, e a boca — que nao
## existia — nao tinha de quem seguir.
##
## Aqui a linha vira SILABAS (portugues, regra simples: um nucleo de vogal por
## silaba) e cada silaba e um passo de 15 Hz, a mesma grade do corpo:
##
## - a voz toca uma silaba do banco da MESMA vogal (a, e, i, o, u);
## - a boca faz o viseme da vogal (a -> ABERTA; e, i -> ENTREABERTA; o, u ->
##   REDONDA); p, b e m fecham a boca no primeiro passo, como fecham de verdade;
## - o texto aparece ate o fim daquela silaba (`silaba_dita`).
##
## Virgula para tres passos, ponto cinco, reticencias sete, de boca fechada. O
## temperamento muda o passo (o bebado arrasta, o apressado atropela). `pular`
## cala tudo no mesmo quadro e mostra a linha inteira.
##
## Intencao na linha, sem reescrever o texto
## -----------------------------------------
## Marcas opcionais entre colchetes, que a UI nunca mostra (`sem_marcas`):
##     [raiva] [simpatia] [medo] ...   expressao ate o fim da linha
##     [pausa]                         pausa de ponto
##     [olha:esq] [olha:dir] [olha:frente]
##     [rapido] [devagar]              ritmo das silabas seguintes
##     [grita] [sussurra]              volume da voz
##     [gesto:nome]                    sinal `gesto` (os gestos sao da fase 4)
## Sem marca nenhuma a linha ja ganha microexpressao da pontuacao: sobrancelha
## sobe no fim da pergunta e na exclamacao, o olhar foge nas reticencias.
class_name Fala
extends Node

signal silaba_dita(ate: int)
signal terminou()
signal gesto(nome: StringName)

const HZ := 15.0
## Passos por silaba e de pausa (a 15 Hz: 2 passos = 7,5 silabas por segundo,
## o ritmo que a Voz ja tinha).
const PASSOS_SILABA := 2
const PAUSA_VIRGULA := 3
const PAUSA_PONTO := 5
const PAUSA_RETICENCIAS := 7

const VOGAIS := "aeiouáéíóúâêôãõàü"
const FECHAM := "pbm"

var voz: Voz
var rosto: Rosto
## Corpos que gesticulam enquanto a linha anda (o busto, o corpo no mundo).
var corpos: Array[Corpo] = []
var cadencia: float = 1.0
## Temperamento de quem fala (-1: sem gesto automatico) e quanto gesticula.
var personalidade: int = -1
var gesticula: float = 1.0

var _plano: Array = []
var _i := 0
var _passo := 0
var _t := 0.0
var _revelado := 0
var _total := 0
var _ativa := false
var _pergunta := false


## Comeca uma linha (com ou sem marcas). Devolve quantos segundos ela dura.
## O texto que a UI deve mostrar e `Fala.sem_marcas(linha)`.
func dizer(linha: String) -> float:
	var limpa := Fala.sem_marcas(linha)
	var marcas := Fala.marcas(linha)
	_plano = Fala.silabas(limpa, cadencia)
	_aplicar_marcas(marcas)
	_microexpressoes()
	_gestos(limpa, marcas)
	_total = limpa.length()
	_pergunta = limpa.strip_edges().ends_with("?")
	if voz != null and is_instance_valid(voz):
		voz.volume_extra = 0.0
	_i = 0
	_passo = 0
	_t = 0.0
	_revelado = 0
	_ativa = not _plano.is_empty()
	set_process(_ativa)
	for c in corpos:
		if is_instance_valid(c):
			c.falar(_ativa)
	if not _ativa:
		_revelado = _total
		terminou.emit()
	return duracao()


func duracao() -> float:
	var n := 0
	for s: Dictionary in _plano:
		n += int(s["passos"]) + int(s["pausa"])
	return float(n) / HZ


func pular() -> void:
	if not _ativa:
		return
	_revelado = _total
	_parar()


func falando() -> bool:
	return _ativa


## Quantas letras da linha ja podem aparecer.
func revelado() -> int:
	return _revelado


func _process(delta: float) -> void:
	if not _ativa:
		return
	_t += delta
	var passos := int(_t * HZ)
	while _passo < passos and _ativa:
		_avancar_um_passo()
		_passo += 1


## Um passo de 15 Hz: o que a boca faz nele, e se uma silaba comeca.
func _avancar_um_passo() -> void:
	if _i >= _plano.size():
		_revelado = _total
		_parar()
		return
	var s: Dictionary = _plano[_i]
	var local := int(s.get("_andou", 0))
	var dentro := int(s["passos"])
	if local == 0:
		_revelado = int(s["ate"])
		silaba_dita.emit(_revelado)
		_disparar(s)
		if voz != null and is_instance_valid(voz):
			var t := float(_i) / float(maxi(1, _plano.size() - 1))
			voz.silaba(String(s["vogal"]), t, _i == _plano.size() - 1, _pergunta)
	if rosto != null:
		if local < dentro:
			var fecha := local == 0 and bool(s["fecha"])
			rosto.boca_da_fala(&"" if fecha else StringName(s["viseme"]))
		else:
			rosto.boca_da_fala(&"")
	s["_andou"] = local + 1
	if local + 1 >= dentro + int(s["pausa"]):
		_i += 1


func _parar() -> void:
	_ativa = false
	set_process(false)
	if voz != null and is_instance_valid(voz):
		voz.parar()
	if rosto != null:
		rosto.boca_da_fala(&"", false)
	for c in corpos:
		if is_instance_valid(c):
			c.falar(false)
	silaba_dita.emit(_revelado)
	terminou.emit()


# --- marcas e microexpressoes -------------------------------------------------------

const EXPRESSOES := {
	"neutra": Rosto.Expressao.NEUTRA, "simpatia": Rosto.Expressao.SIMPATIA,
	"riso": Rosto.Expressao.RISO, "raiva": Rosto.Expressao.RAIVA,
	"desconfianca": Rosto.Expressao.DESCONFIANCA, "medo": Rosto.Expressao.MEDO,
	"surpresa": Rosto.Expressao.SURPRESA, "tristeza": Rosto.Expressao.TRISTEZA,
	"nojo": Rosto.Expressao.NOJO, "chapado": Rosto.Expressao.CHAPADO,
	"bebado": Rosto.Expressao.BEBADO, "dor": Rosto.Expressao.DOR,
}


## O texto sem as marcas `[...]`, que e o que a tela mostra.
static func sem_marcas(linha: String) -> String:
	var r := RegEx.create_from_string("\\[[a-z_:]+\\]")
	return r.sub(linha, "", true).replace("  ", " ")


## As marcas e onde caem no texto limpo: [[posicao, marca], ...].
static func marcas(linha: String) -> Array:
	var r := RegEx.create_from_string("\\[([a-z_:]+)\\]")
	var saida: Array = []
	var tirado := 0
	for m in r.search_all(linha):
		saida.append([m.get_start() - tirado, m.get_string(1)])
		tirado += m.get_end() - m.get_start()
	return saida


## Cada marca vira evento na silaba em que ela cai.
func _aplicar_marcas(marcas: Array) -> void:
	var ritmo := 0
	for m: Array in marcas:
		var pos := int(m[0])
		var k := 0
		while k < _plano.size() - 1 and int((_plano[k] as Dictionary)["ate"]) <= pos:
			k += 1
		var s: Dictionary = _plano[k] if not _plano.is_empty() else {}
		if s.is_empty():
			continue
		var marca := String(m[1])
		if marca == "pausa":
			# A pausa e da silaba que TERMINA na marca ("daqui[pausa]" para
			# depois de "qui", e nao entre "da" e "qui").
			var kp := 0
			while kp < _plano.size() - 1 and int((_plano[kp] as Dictionary)["ate"]) < pos:
				kp += 1
			var ant: Dictionary = _plano[kp]
			ant["pausa"] = int(ant["pausa"]) + PAUSA_PONTO
		elif marca == "rapido" or marca == "devagar":
			ritmo = -1 if marca == "rapido" else 1
			for j in range(k, _plano.size()):
				(_plano[j] as Dictionary)["passos"] = clampi(PASSOS_SILABA + ritmo, 2, 4)
		else:
			var ev: Array = s.get("eventos", [])
			ev.append(marca)
			s["eventos"] = ev


## Microexpressao pela pontuacao, sem marca: pergunta e exclamacao sobem a
## sobrancelha nas duas silabas de antes; reticencias desviam o olhar na pausa.
## A marca explicita da linha vale mais: a micro nao passa por cima de uma
## expressao pedida (ver `_disparar`, que roda as marcas depois).
func _microexpressoes() -> void:
	for k in _plano.size():
		var s: Dictionary = _plano[k]
		var p := int(s["pausa"])
		if p == PAUSA_RETICENCIAS:
			var ev: Array = s.get("eventos", [])
			ev.append("micro:foge")
			s["eventos"] = ev
		elif p == PAUSA_PONTO and String(s.get("fim", "")) in ["?", "!"]:
			# So pergunta e exclamacao: sobrancelha subindo em todo ponto final
			# le como surpresa perpetua, e apagava a expressao marcada.
			var alvo: Dictionary = _plano[maxi(0, k - 2)]
			var ev: Array = alvo.get("eventos", [])
			ev.append("micro:ergue")
			alvo["eventos"] = ev


func _disparar(s: Dictionary) -> void:
	var marcada := false
	for marca: String in s.get("eventos", []):
		marcada = marcada or EXPRESSOES.has(marca)
	for marca: String in s.get("eventos", []):
		if marcada and marca.begins_with("micro:"):
			continue
		if EXPRESSOES.has(marca):
			if rosto != null:
				rosto.reagir(EXPRESSOES[marca], _resto() + 1.2)
		elif marca.begins_with("olha:"):
			if rosto != null:
				var lado := marca.trim_prefix("olha:")
				rosto.olhar(-1 if lado == "esq" else (1 if lado == "dir" else 0))
		elif marca == "grita" or marca == "sussurra":
			if voz != null and is_instance_valid(voz):
				voz.volume_extra = 6.0 if marca == "grita" else -8.0
			if rosto != null and marca == "grita":
				rosto.micro(&"ERGUIDA", &"ARREGALADO", _resto())
		elif marca.begins_with("gesto:"):
			var nome := StringName(marca.trim_prefix("gesto:"))
			gesto.emit(nome)
			if GestoDaFala.NOMES.has(nome):
				_gesto_no_corpo(int(GestoDaFala.NOMES[nome]))
		elif marca.begins_with("corpo:"):
			_gesto_no_corpo(int(marca.trim_prefix("corpo:")))
		elif marca == "micro:ergue":
			if rosto != null:
				rosto.micro(&"ERGUIDA", &"", 0.45)
		elif marca == "micro:foge":
			if rosto != null:
				# Para um lado ou outro conforme a silaba: sempre o mesmo lado
				# le como tique.
				var lado := &"OLHA_ESQ" if int(s["ate"]) % 2 == 0 else &"OLHA_DIR"
				rosto.micro(&"", lado, float(int(s["passos"]) + int(s["pausa"])) / HZ)


## Gestos da frase (`GestoDaFala`), se a linha nao marcou um a mao.
func _gestos(limpa: String, marcas: Array) -> void:
	if personalidade < 0 or corpos.is_empty():
		return
	for m: Array in marcas:
		if String(m[1]).begins_with("gesto:"):
			return
	for g: Array in GestoDaFala.escolher(limpa, personalidade, gesticula):
		var pos := int(g[0])
		var k := 0
		while k < _plano.size() - 1 and int((_plano[k] as Dictionary)["ate"]) <= pos:
			k += 1
		var s: Dictionary = _plano[k]
		var ev: Array = s.get("eventos", [])
		ev.append("corpo:%d" % int(g[1]))
		s["eventos"] = ev


func _gesto_no_corpo(tipo: int) -> void:
	for c in corpos:
		if is_instance_valid(c) and c.reacao() == 0:
			c.reagir(tipo)


## Segundos que faltam da linha.
func _resto() -> float:
	var n := 0
	for k in range(_i, _plano.size()):
		var s: Dictionary = _plano[k]
		n += int(s["passos"]) + int(s["pausa"])
	return float(n) / HZ


# --- silabas --------------------------------------------------------------------

## A linha em silabas: [{ate, vogal, viseme, fecha, passos, pausa}]. `ate` e o
## indice (exclusivo) ate onde o texto aparece quando a silaba comeca — inclui o
## espaco e a pontuacao depois dela, para a palavra nao ficar sem o ponto.
##
## Separacao simples, de ouvido: cada grupo de vogais e um nucleo; entre dois
## nucleos, uma consoante vai para a silaba de tras e o resto fica na da
## frente ("pas-sa", "can-to", "fa-la"). Palavra sem vogal ("22:43", "R$")
## vale uma silaba de boca meio aberta.
static func silabas(linha: String, cadencia: float = 1.0) -> Array:
	var saida: Array = []
	var n := linha.length()
	var baixa := linha.to_lower()
	var passos := PASSOS_SILABA if cadencia >= 0.85 else PASSOS_SILABA + 1
	# Nucleos de vogal: [inicio, fim] (fim inclusivo).
	var nucleos: Array = []
	var i := 0
	while i < n:
		if VOGAIS.contains(baixa[i]):
			var ini := i
			while i + 1 < n and VOGAIS.contains(baixa[i + 1]):
				i += 1
			nucleos.append([ini, i])
		i += 1
	if nucleos.is_empty():
		if linha.strip_edges().is_empty():
			return []
		return [{"ate": n, "vogal": "e", "viseme": &"ENTREABERTA", "fecha": false,
			"passos": passos, "pausa": 0}]
	var inicio := 0
	for k in nucleos.size():
		var nuc: Array = nucleos[k]
		var fim := int(nuc[1]) + 1
		if k + 1 < nucleos.size():
			var prox := int((nucleos[k + 1] as Array)[0])
			# Consoantes (so letras) entre este nucleo e o proximo.
			var letras: Array[int] = []
			for j in range(fim, prox):
				if _e_letra(baixa[j]):
					letras.append(j)
			if letras.size() >= 1:
				# A ultima consoante antes do proximo nucleo vai com ele; se
				# houver um espaco ou pontuacao no meio, a palavra acaba antes.
				var corte := letras[letras.size() - 1]
				for j in range(fim, prox):
					if not _e_letra(baixa[j]):
						corte = j + 1
						while corte < prox and not _e_letra(baixa[corte]):
							corte += 1
						break
				fim = corte
			else:
				fim = prox
		else:
			fim = n
		var trecho := baixa.substr(inicio, fim - inicio)
		var vogal := baixa[int(nuc[0])]
		var onset := baixa.substr(inicio, int(nuc[0]) - inicio).strip_edges()
		saida.append({
			"ate": fim,
			"vogal": _vogal_base(vogal),
			"viseme": _viseme(vogal),
			"fecha": not onset.is_empty() and FECHAM.contains(onset[onset.length() - 1]),
			"passos": passos,
			"pausa": _pausa(trecho),
			"fim": trecho.strip_edges().right(1),
		})
		inicio = fim
	return saida


static func _e_letra(c: String) -> bool:
	return c.to_upper() != c.to_lower()


static func _vogal_base(c: String) -> String:
	if "aáâãà".contains(c):
		return "a"
	if "eéê".contains(c):
		return "e"
	if "ií".contains(c):
		return "i"
	if "oóôõ".contains(c):
		return "o"
	return "u"


static func _viseme(c: String) -> StringName:
	match _vogal_base(c):
		"a":
			return &"ABERTA"
		"o", "u":
			return &"REDONDA"
		_:
			return &"ENTREABERTA"


static func _pausa(trecho: String) -> int:
	var t := trecho.strip_edges(false, true)
	if t.ends_with("...") or t.ends_with("…"):
		return PAUSA_RETICENCIAS
	if t.ends_with(".") or t.ends_with("!") or t.ends_with("?"):
		return PAUSA_PONTO
	if t.ends_with(",") or t.ends_with(";") or t.ends_with(":") or t.ends_with("—"):
		return PAUSA_VIRGULA
	return 0
