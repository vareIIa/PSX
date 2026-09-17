## Autoload. A escada de qualidade do preset MODERNO (PLANO_AAA_4K, Fase 2).
##
##     godot --path game -- --qualidade=4k
##     Nivel: baixo, medio, alto, ultra, 4k
##
## O que cada nivel mexe: resolucao interna do 3D, reconstrutor (FSR 2),
## anti-serrilhado temporal, nitidez (Fase 2) e, da Fase 4 em diante, oclusao de
## ambiente, luz indireta de tela, luz global e penumbra de sombra.
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

## Oclusao, luz indireta e penumbra, degrau por degrau.
##
## `ssao` escurece canto e quina lendo a profundidade da tela. `ssil` devolve a
## COR do que esta perto — um letreiro vermelho pinta o asfalto ao lado. `gi` e
## o SDFGI, que faz o mesmo em escala de quarteirao e e o unico caro de verdade.
## `blur` e a penumbra da sombra, em unidades do Godot.
##
## Por que a penumbra existe no MODERNO. O `DiretorSombra` fixava `shadow_blur`
## em zero com um argumento que era verdadeiro ate a Fase 3: borda dura combina
## com textura de filtro ponto. Com 1024 px, relevo e TAA, a mesma borda dura
## passou a ser a unica coisa serrilhada da cena. No PS1 STYLE nada disso liga —
## la nenhuma luz projeta sombra.
const LUZ := {
	Nivel.BAIXO: {"ssao": false, "ssil": false, "gi": false, "blur": 0.0, "filtro": 0},
	Nivel.MEDIO: {"ssao": true, "ssil": false, "gi": false, "blur": 0.7, "filtro": 1},
	Nivel.ALTO: {"ssao": true, "ssil": false, "gi": false, "blur": 1.0, "filtro": 2},
	Nivel.ULTRA: {"ssao": true, "ssil": true, "gi": true, "blur": 1.2, "filtro": 3},
	Nivel.NATIVO: {"ssao": true, "ssil": true, "gi": true, "blur": 1.2, "filtro": 3},
	Nivel.CRU: {"ssao": false, "ssil": false, "gi": false, "blur": 0.0, "filtro": 0},
}

## Quantos graus de tamanho angular do sol valem uma unidade de `blur`.
##
## Tres, e nao 0,53. O sol de verdade tem meio grau, e com meio grau a penumbra
## desta cidade e SUB-PIXEL: medido na `tests/bancada_luz.gd`, a dureza da borda
## ficou identica com e sem (1,00x). A 2,4 graus da 1,21x e a 4,8 graus, 1,63x.
## Tres graus (blur 1,2 vezes este fator, no nivel mais alto) poem a penumbra
## onde o olho a ve sem transformar sombra em mancha — e e o mesmo exagero que
## qualquer jogo faz, porque sombra de sol fisicamente correta nao le como sombra
## macia numa tela.
const ANGULO_POR_BLUR := 3.0


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
## `--sem-ao` e `--sem-gi`: desligam oclusao e luz global sem mudar o resto do
## nivel. Sao os interruptores de diagnostico dos criterios A11 e A12 — a mesma
## cena com e sem, que e a unica forma de dizer quanto cada um faz.
var _sem_ao := false
var _sem_gi := false
## `--sem-decalques`: tira oleo, pichacao e encardido (criterio A17) sem mexer
## no resto. E o par da regressao e da medida de custo.
var _sem_decalques := false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--sem-ao":
			_sem_ao = true
		elif arg == "--sem-gi":
			_sem_gi = true
		elif arg == "--sem-decalques":
			_sem_decalques = true
		elif arg.begins_with("--qualidade="):
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
	_aplicar_luz(LUZ[nivel])
	mudou.emit(nivel)
	var l: Dictionary = LUZ[nivel]
	print("[qualidade] %s: escala %.2f (%dx%d de %dx%d), %s, TAA %s | AO %s, SSIL %s, GI %s, penumbra %.1f"
		% [d["nome"], d["escala"],
			int(janela.size.x * float(d["escala"])),
			int(janela.size.y * float(d["escala"])),
			janela.size.x, janela.size.y,
			"FSR 2" if d["fsr"] else "bilinear",
			"sim" if d["taa"] else "nao",
			"sim" if (bool(l["ssao"]) and not _sem_ao) else "nao",
			"sim" if (bool(l["ssil"]) and not _sem_ao) else "nao",
			"sim" if (bool(l["gi"]) and not _sem_gi) else "nao",
			blur_de_sombra()])


## A penumbra que as luzes devem usar. Lida pelo `DiretorSombra` ao acender uma.
func blur_de_sombra() -> float:
	if not Settings.luz_por_pixel:
		return 0.0
	return float(LUZ[nivel]["blur"])


## Escreve oclusao, luz indireta e penumbra no ambiente da cena.
##
## Roda depois do `FogController`, que e quem monta o `Environment` a cada troca
## de preset — e por isso ele parou de zerar SSAO e SDFGI: quem zera o que outro
## sistema ligou mata o recurso em silencio na primeira troca de clima. Aqui
## tambem ha uma repeticao de seguranca: o ambiente e reescrito quando o preset
## de nevoa muda, e esta funcao volta a passar por cima.
func _aplicar_luz(d: Dictionary) -> void:
	var fog := get_tree().get_first_node_in_group(&"fog_controller") as WorldEnvironment
	if fog == null or fog.environment == null:
		return
	var env := fog.environment
	if not Settings.luz_por_pixel:
		return

	env.ssao_enabled = bool(d["ssao"]) and not _sem_ao
	# Raio curto e forca alta: o que se quer e a QUINA, o encontro de parede com
	# chao e o pe do poste. Raio grande escurece parede inteira e le como
	# sujeira, nao como sombra de contato.
	# Calibrado na `tests/bancada_luz.gd`: com 2,2 de intensidade a quina
	# escurecia 3,9% e o criterio A11 pede 15%.
	env.ssao_radius = 0.7
	env.ssao_intensity = 5.0
	env.ssao_power = 2.0
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.35

	env.ssil_enabled = bool(d["ssil"]) and not _sem_ao
	env.ssil_radius = 3.0
	env.ssil_intensity = 1.1
	env.ssil_normal_rejection = 1.0

	env.sdfgi_enabled = bool(d["gi"]) and not _sem_gi
	if env.sdfgi_enabled:
		# Quatro cascatas de 6,4 m: a primeira cobre a rua em que o jogador esta,
		# e a ultima chega ao fim do quarteirao. Mais que isso e memoria gasta
		# com o que a nevoa ja esconde.
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.2
		env.sdfgi_use_occlusion = true
		env.sdfgi_bounce_feedback = 0.5
		# Calibrado na avenida noturna, que e a vista mais escura do jogo. Com 1,0
		# a mediana da imagem sobe de 1 para 15,6 de 255 — metade da tela deixa de
		# ser preto absoluto, e a noite perde o peso. Com 0,35 volta ao preto
		# (mediana 0,6). Em 0,6 a mediana fica em 8,0 e o realce nao se mexe (p95
		# 39,8 antes, 41,1 depois): a sombra ganha leitura sem a cena virar dia.
		env.sdfgi_energy = 0.6
		env.sdfgi_normal_bias = 1.1

	_cuidar_das_sondas(bool(d["gi"]) and not _sem_gi)
	# Decalques de rua em todo degrau que tem luz por pixel de verdade: no BAIXO
	# a GPU ja esta no limite, e no CRU — a linha de base sem nenhum recurso —
	# eles apareceriam como diferenca que nao e de anti-serrilhado.
	_cuidar_dos_decalques(nivel != Nivel.BAIXO and nivel != Nivel.CRU
		and not _sem_decalques)

	RenderingServer.positional_soft_shadow_filter_set_quality(
		int(d["filtro"]) as RenderingServer.ShadowQuality)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		int(d["filtro"]) as RenderingServer.ShadowQuality)
	# Penumbra: em luz posicional e `shadow_blur`; no SOL e o TAMANHO ANGULAR.
	#
	# `shadow_blur` numa `DirectionalLight3D` nao muda nada — medido na
	# `bancada_luz`, a borda deu 2 px com e sem. O que da penumbra ao sol e
	# `light_angular_distance`, o diametro aparente da fonte em graus (o do sol
	# de verdade e 0,53).
	for no: Node in get_tree().get_nodes_in_group(&"luz_sombra"):
		var luz := no as Light3D
		if luz == null or not luz.shadow_enabled:
			continue
		if luz is DirectionalLight3D:
			(luz as DirectionalLight3D).light_angular_distance = 				float(d["blur"]) * ANGULO_POR_BLUR
		else:
			luz.shadow_blur = float(d["blur"])


## Liga ou desliga as sondas de reflexo da rua (criterio A14).
##
## Elas vivem num no proprio, filho da cena, e nao num chunk: ver
## `SondasReflexo`, que explica por que uma sonda por chunk custou cinco
## engasgos de carga. Entram nos mesmos degraus da luz global, porque respondem a
## mesma pergunta — o que a tela nao mostra.
func _cuidar_das_sondas(quer: bool) -> void:
	var cena := get_tree().current_scene
	if cena == null:
		return
	var atual := cena.get_node_or_null(^"SondasReflexo") as SondasReflexo
	if quer and Settings.luz_por_pixel:
		if atual == null:
			var s := SondasReflexo.new()
			s.name = "SondasReflexo"
			cena.add_child(s)
			print("[qualidade] %d sondas de reflexo seguindo o jogador"
				% SondasReflexo.QUANTAS)
	elif atual != null:
		atual.queue_free()


## Liga ou desliga os decalques de rua (criterio A17). Mesmo desenho das
## sondas: um no proprio, filho da cena, que segue o jogador.
func _cuidar_dos_decalques(quer: bool) -> void:
	var cena := get_tree().current_scene
	if cena == null:
		return
	var atual := cena.get_node_or_null(^"DecalquesRua") as DecalquesRua
	if quer and Settings.luz_por_pixel:
		if atual == null:
			cena.add_child(DecalquesRua.new())
			print("[qualidade] decalques de rua: %d vagas por chunk por familia"
				% DecalquesRua.VAGAS)
	elif atual != null:
		atual.queue_free()


## O nome do nivel atual, para relatorio e para a interface.
func nome() -> String:
	return String(NIVEIS[nivel]["nome"])
