## Autoload. A escada de qualidade do preset MODERNO (PLANO_AAA_4K, Fase 2).
##
##     godot --path game -- --qualidade=4k
##     Nivel: baixo, medio, alto, ultra, 4k
##
## O que cada nivel mexe hoje: resolucao interna do 3D, reconstrutor (FSR 2),
## anti-serrilhado temporal e nitidez. As fases seguintes penduram aqui sombra,
## oclusao de ambiente, luz global e reflexo — o lugar ja esta feito e cada fase
## acrescenta uma linha na tabela.
##
## Por que fora do `EstiloVisual`
## ------------------------------
## O `EstiloVisual` responde a uma pergunta diferente: PS1 STYLE ou MODERNO. Ele
## escreve a resolucao interna a partir de `Settings.resolucao_3d` e o modo de
## escala da janela. A qualidade escreve DEPOIS dele, e so quando o estilo e
## MODERNO — no PS1 STYLE este autoload devolve tudo ao padrao e sai de cena. E
## o contrato do plano: nenhuma fase do MODERNO pode mudar uma captura do PS1.
##
## Por que a resolucao e ESCALA e nao numero
## -----------------------------------------
## `Settings.resolucao_3d` e absoluto (1280x720 no MODERNO), e o `EstiloVisual`
## o converte em `scaling_3d_scale` dividindo pela altura da JANELA. Num monitor
## 4K isso da 0,33 — ou seja, o jogo em tela cheia renderiza a um terco e o
## "1280x720" vira um numero sem sentido. Aqui o nivel manda a fracao, e a
## resolucao interna acompanha a janela: 1,0 num monitor 4K e 4K de verdade.
class_name QualidadeGrafica
extends Node

enum Nivel {
	BAIXO, MEDIO, ALTO, ULTRA, NATIVO,
	## Nativo e CRU: sem reconstrutor e sem anti-serrilhado. Nao e para jogar —
	## e a linha de base do criterio A7, o "antes" da Fase 2, e a unica forma de
	## provar que o FSR 2 e o TAA fazem alguma coisa.
	CRU,
}

## Fracao da altura da janela em que o 3D e renderizado, e o que reconstroi o
## resto. Os numeros de FSR 2 sao os da tabela da AMD: 50% "performance", 59%
## "balanced", 67% "quality", 77% "ultra quality".
##
## `taa` so entra no nivel NATIVO. Com FSR 2 o anti-serrilhado ja e temporal por
## dentro do reconstrutor; ligar os dois junto e borrao em cima de borrao.
const NIVEIS := {
	Nivel.BAIXO: {"escala": 0.50, "fsr": true, "taa": false, "nitidez": 0.5, "nome": "baixo"},
	Nivel.MEDIO: {"escala": 0.59, "fsr": true, "taa": false, "nitidez": 0.4, "nome": "medio"},
	Nivel.ALTO: {"escala": 0.67, "fsr": true, "taa": false, "nitidez": 0.3, "nome": "alto"},
	Nivel.ULTRA: {"escala": 0.77, "fsr": true, "taa": false, "nitidez": 0.2, "nome": "ultra"},
	Nivel.NATIVO: {"escala": 1.00, "fsr": false, "taa": true, "nitidez": 0.0, "nome": "4k"},
	Nivel.CRU: {"escala": 1.00, "fsr": false, "taa": false, "nitidez": 0.0, "nome": "cru"},
}

## O nivel de partida.
##
## NATIVO, e nao um nivel com reconstrutor, porque a medida deixa: a cidade a
## noite na chuva, em 3840x2160 NATIVO com TAA, custa 2,8 ms por quadro (360 fps)
## na maquina de referencia. Reconstruir a partir de 67% pouparia meio
## milissegundo de um orcamento de 16,7 e cobraria nitidez em troca. A escada
## existe para maquina menor, e quem desce nela e o jogador.
const PADRAO := Nivel.NATIVO

signal mudou(nivel: Nivel)

var nivel: Nivel = PADRAO


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qualidade="):
			var pedido := arg.trim_prefix("--qualidade=").to_lower()
			var achou := false
			for n: Nivel in NIVEIS:
				if NIVEIS[n]["nome"] == pedido:
					nivel = n
					achou = true
					break
			if not achou:
				push_warning("QualidadeGrafica: --qualidade=%s desconhecido" % pedido)
	Settings.changed.connect(_aplicar)
	# Depois do EstiloVisual, que tambem ouve `changed` e escreve a mesma janela.
	# A ordem entre dois ouvintes do mesmo sinal e a ordem de conexao, e o
	# EstiloVisual conecta no `_ready` dele, que roda antes deste (ver a ordem no
	# project.godot). Mesmo assim a aplicacao daqui e adiada um quadro no
	# arranque, porque a janela ainda nao tem o tamanho final quando o autoload
	# nasce — e a fracao depende da altura dela.
	get_tree().process_frame.connect(_aplicar, CONNECT_ONE_SHOT)


func aplicar(novo: Nivel) -> void:
	nivel = novo
	_aplicar()


func _aplicar() -> void:
	var janela := get_window()
	if janela == null:
		return
	# PS1 STYLE sai daqui como entrou. Ver o cabecalho.
	if not Settings.luz_por_pixel:
		janela.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		janela.use_taa = false
		return

	var d: Dictionary = NIVEIS[nivel]
	janela.scaling_3d_mode = (Viewport.SCALING_3D_MODE_FSR2 if d["fsr"]
		else Viewport.SCALING_3D_MODE_BILINEAR)
	janela.scaling_3d_scale = float(d["escala"])
	janela.fsr_sharpness = float(d["nitidez"])
	janela.use_taa = bool(d["taa"])
	mudou.emit(nivel)
	print("[qualidade] %s: escala %.2f (%dx%d de %dx%d), %s, TAA %s"
		% [d["nome"], d["escala"],
			int(janela.size.x * float(d["escala"])),
			int(janela.size.y * float(d["escala"])),
			janela.size.x, janela.size.y,
			"FSR 2" if d["fsr"] else "bilinear",
			"sim" if d["taa"] else "nao"])


## O nome do nivel atual, para relatorio e para a interface.
func nome() -> String:
	return String(NIVEIS[nivel]["nome"])
