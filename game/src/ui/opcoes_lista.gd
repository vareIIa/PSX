## As opcoes ajustaveis do jogo, num lugar so.
##
## Por que nao mora no menu de titulo
## ----------------------------------
## Porque ela passou a ter dois donos. A lista nasceu dentro de `menu.gd`, que
## era o unico lugar de onde dava para mexer em nevoa, grao, scanline, vinheta e
## dither — e "o unico lugar" era o problema: o jogador so alcancava esses seis
## ajustes ANTES de apertar NOVO JOGO, e nunca mais.
##
## Com o menu de sistema em jogo, dois paineis oferecem os mesmos ajustes. Copiar
## a lista para o segundo daria certo no dia em que fosse escrita e erraria no
## primeiro ajuste — um painel com sete opcoes e o outro com seis, os dois
## dizendo que sao as opcoes do jogo. Mesma armadilha que `mapa.gd` documenta
## para o desenho do mapa, e a mesma saida: uma fonte, dois leitores.
##
## Cada entrada e `{rotulo, ler: Callable() -> String, aplicar: Callable(passo: int)}`.
## `passo` e -1 ou +1: a lista nao sabe de tecla, so de direcao.
class_name OpcoesLista
extends RefCounted


## Os seis ajustes de imagem. Mesma ordem em que sempre apareceram.
static func video() -> Array[Dictionary]:
	return [
		{
			"rotulo": "NEVOA",
			"ler": func() -> String: return Settings.fog_preset().display_name.to_upper(),
			"aplicar": func(passo: int) -> void:
				var ids := Settings.FOG_PRESET_IDS
				var i := ids.find(Settings.fog_preset_id)
				Settings.set_fog_preset(ids[posmod(i + passo, ids.size())]),
		},
		barra("GRAO", &"grain", 0.0, 0.2, 0.02),
		barra("ABERRACAO", &"chromatic", 0.0, 2.0, 0.2),
		barra("SCANLINE", &"scanline", 0.0, 0.5, 0.04),
		barra("VINHETA", &"vignette", 0.0, 1.0, 0.1),
		{
			"rotulo": "DITHER",
			"ler": func() -> String: return "LIGADO" if Settings.dither else "DESLIGADO",
			"aplicar": func(_passo: int) -> void:
				Settings.set_post(&"dither", not Settings.dither),
		},
	]


## Um deslizador por bus. A lista sai de `Settings.BUSES`, e nao escrita a mao:
## acrescentar um bus la nao pode exigir lembrar de vir aqui.
static func audio() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for bus: StringName in Settings.BUSES:
		var b := bus
		saida.append({
			"rotulo": String(Settings.BUS_ROTULO.get(b, String(b))).to_upper(),
			"ler": func() -> String: return blocos(Settings.get_volume(b)),
			"aplicar": func(passo: int) -> void:
				Settings.set_volume(b, Settings.get_volume(b) + float(passo) * 0.1),
		})
	return saida


## Opcao numerica com passo fixo.
static func barra(rotulo: String, chave: StringName, minimo: float, maximo: float,
		passo: float) -> Dictionary:
	return {
		"rotulo": rotulo,
		"ler": func() -> String:
			var v: float = Settings.get(String(chave))
			return blocos((v - minimo) / (maximo - minimo)),
		"aplicar": func(p: int) -> void:
			var v: float = Settings.get(String(chave))
			Settings.set_post(chave, clampf(v + float(p) * passo, minimo, maximo)),
	}


## Barra em blocos em vez de porcentagem: numa tela de 480x270, dez blocos leem
## mais rapido que "0.14".
static func blocos(fracao: float) -> String:
	var n := clampi(int(round(fracao * 10.0)), 0, 10)
	return "[%s%s]" % ["#".repeat(n), ".".repeat(10 - n)]
