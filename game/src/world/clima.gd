## Autoload. Quanto o mundo esta molhado, de 0 a 1.
##
## Por que isto nao e `preset.tem_chuva`
## -------------------------------------
## Porque agua tem memoria e clima nao. `tem_chuva` e um booleano que vira no
## instante em que o preset troca: com ele, parar de chover secaria a rua no
## mesmo quadro, e comecar a chover deixaria o asfalto encharcado antes da
## primeira gota bater. As duas coisas leem como bug mesmo quando ninguem sabe
## dizer o que esta errado.
##
## `molhado` sobe devagar enquanto chove e desce MAIS devagar depois. E esse
## atraso — a rua que continua brilhando cinco minutos depois de o ceu limpar —
## que faz o lugar parecer um lugar em vez de um cenario com um interruptor.
##
## Quem le
## -------
##   - o `global uniform psx_molhado`, que alcanca todo material de superficie
##   - o `Environment`, que acende reflexo de tela quando ha o que refletir
##   - mais adiante: poca, respingo, som de passo e spray de roda
extends Node

const FOG_GROUP := &"fog_controller"

## Segundos de chuva ate o chao encharcar. Um minuto e meio: rapido o bastante
## para o jogador ligar a chuva ao chao na primeira vez que repara, lento o
## bastante para nao parecer um interruptor.
const TEMPO_MOLHA := 90.0

## Segundos ate secar. Quase quatro vezes mais lento, porque e assim na rua — e
## porque a poca que sobrevive ao fim da chuva e o detalhe que vende o sistema.
const TEMPO_SECA := 340.0

## Acima disto vale acender reflexo de tela. Abaixo, a lamina e fina demais para
## refletir qualquer coisa e o custo nao se paga.
const LIMIAR_REFLEXO := 0.22

## Quanto o valor precisa andar para valer uma escrita no servidor de render.
## Sem isto seria uma chamada por quadro para mover a terceira casa decimal.
const PASSO_MINIMO := 0.004

## Segundos para a chuva entrar e sair. Rapido, e de proposito: isto nao e a
## memoria da agua, e o "esta caindo agora". Os dois sao coisas diferentes e
## confundi-los e o que faz o anel de impacto continuar batendo numa poca dez
## minutos depois de o ceu limpar.
const TEMPO_CHUVA := 4.0

signal molhado_mudou(valor: float)

var molhado: float = 0.0

## Esta caindo chuva agora, de 0 a 1. Alimenta o anel de impacto e o respingo.
var chuva: float = 0.0
var _ultima_chuva: float = -1.0

var _fog: FogController
var _ultimo_escrito: float = -1.0
var _ssr_ligado: bool = false


## `--molhado=0.9` fixa o valor e congela a simulacao.
##
## Existe porque encharcar leva 90 segundos e uma captura dispara em um. Sem
## isso, toda revisao de arte de chuva mediria asfalto seco e concluiria que o
## sistema nao funciona — o mesmo tipo de teste que mede o cenario em vez do que
## se queria medir.
var _travado: float = -1.0

## `--chuva=0` com `--molhado=1` monta o estado "acabou de parar de chover": rua
## encharcada, nenhuma gota caindo. E um estado real do jogo — o que o sistema
## inteiro existe para produzir — e tambem o unico jeito de fotografar o anel de
## impacto isolado, ligando e desligando so ele.
var _chuva_travada: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--molhado="):
			_travado = clampf(arg.trim_prefix("--molhado=").to_float(), 0.0, 1.0)
			molhado = _travado
			print("[clima] molhado travado em %.2f" % _travado)
		elif arg.begins_with("--chuva="):
			_chuva_travada = clampf(arg.trim_prefix("--chuva=").to_float(), 0.0, 1.0)
			chuva = _chuva_travada
			print("[clima] chuva travada em %.2f" % _chuva_travada)
	_escrever(molhado_visivel())


## Acha o FogController da cena atual. E procurado a cada quadro enquanto nao
## existe porque a cidade monta o ambiente depois dos autoloads, e trocar de
## cena troca o controller — guardar a referencia de uma vez so deixaria o clima
## presos ao primeiro nivel carregado.
func _resolver_fog() -> void:
	if _fog != null and is_instance_valid(_fog) and _fog.is_inside_tree():
		return
	_fog = get_tree().get_first_node_in_group(FOG_GROUP) as FogController


func _process(delta: float) -> void:
	_resolver_fog()

	var alvo := _alvo()
	if _travado >= 0.0:
		alvo = -1.0  # congelado pela linha de comando; ver `_travado`
	# `alvo < 0` significa "nao conta": estamos num interior, onde o preset do
	# comodo nao tem chuva mas a RUA continua molhada do lado de fora. Sem esta
	# pausa, entrar num bar por cinco minutos secaria a cidade inteira.
	if alvo >= 0.0:
		var tempo := TEMPO_MOLHA if alvo > molhado else TEMPO_SECA
		molhado = move_toward(molhado, alvo, delta / tempo)

	# A chuva caindo segue o preset direto, sem a memoria lenta da agua: ela para
	# quando para. Dentro de um interior vai a zero — o anel de impacto nao tem o
	# que fazer no piso do bar.
	var chove := 0.0
	if not Interiores.dentro and _travado < 0.0:
		var p := _preset()
		chove = 1.0 if (p != null and p.tem_chuva) else 0.0
	elif _travado >= 0.0:
		# Com o valor travado pela linha de comando, a chuva acompanha: e o que
		# permite fotografar o anel de impacto sem esperar o clima virar.
		chove = 1.0 if _travado > 0.0 else 0.0
	if _chuva_travada >= 0.0:
		chove = _chuva_travada
	chuva = move_toward(chuva, chove, delta / TEMPO_CHUVA)
	if absf(chuva - _ultima_chuva) >= PASSO_MINIMO or is_equal_approx(chuva, chove):
		_ultima_chuva = chuva
		RenderingServer.global_shader_parameter_set(&"psx_chuva", chuva)

	var visivel := molhado_visivel()
	if absf(visivel - _ultimo_escrito) >= PASSO_MINIMO \
			or (visivel <= 0.0 and _ultimo_escrito > 0.0) \
			or (visivel >= 1.0 and _ultimo_escrito < 1.0):
		_escrever(visivel)

	# Fora do `if` de proposito. O ambiente nasce DEPOIS dos autoloads: no
	# `_ready` o FogController ainda nao existe e a primeira tentativa cai fora.
	# Amarrado a mudanca de valor, o reflexo nunca ligava com `--molhado=1`,
	# porque ali o valor nunca muda. A funcao ja sai barato quando nada mudou.
	_aplicar_reflexo(visivel)


## O que o shader deve ver, que nao e a mesma coisa que a memoria do clima.
##
## Dentro de um interior o valor renderizado e zero: a memoria continua guardada
## para quando o jogador sair, mas o piso do bar nao pode brilhar de chuva. A
## alternativa seria marcar `molha = 0` em cada material de interior, trinta e
## poucos arquivos que alguem esqueceria de atualizar no proximo comodo novo.
func molhado_visivel() -> float:
	return 0.0 if Interiores.dentro else molhado


## Para onde o molhado caminha. -1 quando o estado nao deve contar.
func _alvo() -> float:
	if Interiores.dentro:
		return -1.0
	var preset := _preset()
	if preset == null:
		return 0.0
	if not preset.tem_chuva:
		return 0.0
	# Chuva sob nevoa densa e uma garoa parada: molha, mas nao encharca. O mesmo
	# raciocinio que a Chuva usa para as particulas, pelo mesmo motivo.
	if preset.fog_enabled and preset.fog_end < 24.0:
		return 0.7
	return 1.0


## Poe o mundo molhado AGORA, sem esperar os noventa segundos da chuva.
##
## A memoria lenta da agua e o que faz a cidade parecer um lugar: chove por um
## minuto e meio ate encharcar, seca em quase seis. Isso esta certo para quem
## esta jogando e errado para quem esta vendo um filme — a abertura da Estrada
## Velha dura um minuto inteiro, e com a rampa normal ela acabaria com a
## estrada em dois tercos de molhado, ou seja, chovendo a cena toda sobre um
## chao que nunca chega a ficar encharcado. O temporal ja estava caindo muito
## antes de o carro entrar em quadro; esta funcao e como se diz isso.
##
## Nao atropela `--molhado=`: ali quem manda e a linha de comando, e uma cena
## que sobrescrevesse o valor travado quebraria toda captura de revisao de agua.
func encharcar(valor: float) -> void:
	if _travado >= 0.0:
		return
	molhado = clampf(valor, 0.0, 1.0)
	_escrever(molhado_visivel())


## Cor do ceu em vigor. E o que uma poca reflete quando nao ha nada por cima
## dela, e por isso ela precisa sair daqui em vez de ser uma constante: a mesma
## poca e clara ao meio-dia nublado e quase preta na noite de chuva.
func cor_do_ceu() -> Color:
	var p := _preset()
	return p.sky_color if p != null else Color(0.45, 0.47, 0.5)


func _preset() -> FogPreset:
	if _fog != null:
		return _fog.preset_atual()
	return Settings.fog_preset()


func _escrever(valor: float) -> void:
	_ultimo_escrito = valor
	RenderingServer.global_shader_parameter_set(&"psx_molhado", valor)
	_aplicar_reflexo(valor)
	molhado_mudou.emit(valor)


## Reflexo de tela so quando ha lamina para refletir, e so no estilo MODERNO.
##
## SSR e recurso de Forward+ e nao existe no perfil de build de Compatibility;
## ligar com o chao seco e pagar por um efeito que nao tem o que mostrar, porque
## a rugosidade alta do asfalto seco engole o reflexo antes de ele aparecer.
##
## No PS1 STYLE fica sempre desligado: la o material nem tem specular, entao nao
## havia para onde o reflexo ir.
func _aplicar_reflexo(valor: float) -> void:
	if _fog == null or _fog.environment == null:
		return
	var quer := Settings.luz_por_pixel and valor >= LIMIAR_REFLEXO
	var env := _fog.environment
	# Compara com o AMBIENTE, e nao com uma copia local.
	#
	# A copia local ja custou um defeito mudo: o FogController reescreve o
	# Environment inteiro a cada troca de preset — e troca de preset acontece ao
	# entrar em qualquer interior. Ele zerava o `ssr_enabled` e este metodo
	# continuava achando que tinha ligado, entao nunca religava. O reflexo sumia
	# na primeira porta que o jogador abrisse e nao voltava mais.
	#
	# Perguntar ao dono do estado em vez de lembrar o que se pediu custa uma
	# leitura de bool por quadro e nao tem como divergir.
	if quer == env.ssr_enabled:
		return
	_ssr_ligado = quer
	env.ssr_enabled = quer
	# Evento raro (duas vezes por chuva) e a unica confirmacao de que o reflexo
	# existe: sem ela, asfalto molhado sem reflexo e indistinguivel de SSR
	# desligado, e os dois se procuram no lugar errado.
	print("[clima] reflexo de tela %s (molhado %.2f)"
		% ["LIGADO" if quer else "desligado", valor])
	if not quer:
		return
	# Poucos passos e fade curto: o reflexo do poste no asfalto e uma mancha
	# alongada, nao um espelho. Passos demais alongam o rastro ate o horizonte e
	# denunciam o truque na primeira vez que a camera gira.
	env.ssr_max_steps = 24
	env.ssr_fade_in = 0.2
	env.ssr_fade_out = 2.5
	env.ssr_depth_tolerance = 0.3
