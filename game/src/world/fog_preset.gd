## Preset de clima e nevoeiro. Um recurso por clima do mundo.
##
## Antes controlava apenas a nevoa (oclusao por draw distance). Agora guarda
## tudo que define um clima: hora do dia, chuva, estrelas, iluminacao solar e
## lunar, nuvens. O raio de streaming ainda vive aqui porque os dois valores
## (fog_end e stream_radius) precisam mudar juntos — ver ART-BIBLE.md secao 8.
##
## Climas normais: dia_sol, dia_nuvens, dia_chuva,
##                 noite_estrelada, noite_nublada, noite_chuva.
## Climas especiais (Silent Hill Vibe): neblina, neblina_chuva.
##
## Contrato em docs/ART-BIBLE.md secao 8.
class_name FogPreset
extends Resource

## Identificador estavel usado no arquivo de configuracao. Nao traduza.
@export var id: StringName = &"neblina_chuva"

## Nome mostrado no menu de opcoes.
@export var display_name: String = "Neblina com Chuva"

@export_group("Nevoa")
@export var fog_enabled: bool = true
@export_range(0.0, 200.0, 0.5) var fog_begin: float = 4.0
@export_range(0.0, 400.0, 0.5) var fog_end: float = 18.0
@export var fog_color: Color = Color("c9cdc6")

@export_group("Ceu")
## Deve ser identico a fog_color quando a nevoa esta ligada. Qualquer diferenca
## cria uma linha de horizonte que denuncia o corte de draw distance na hora.
##
## Vale so quando o fundo E este valor; ver `ceu_proprio`.
@export var sky_color: Color = Color("c9cdc6")

## O nivel desenha o proprio ceu, e `sky_color` nao e o horizonte.
##
## A Estrada Velha monta um `CeuEstrada`: uma cupula presa a camera com degrade
## no shader. Onde ela existe, o que o jogador ve em cima nao e o
## `background_color` chapado, e a regra "ceu igual a nevoa" perde o objeto —
## nao ha emenda entre ceu e nevoa porque nao ha ceu chapado.
##
## O `sky_color` continua servindo para duas coisas nesses presets, e por isso
## nao virou lixo: e o fundo abaixo da borda da cupula, e no estilo MODERNO e a
## radiancia que a poca reflete. So deixou de ser o horizonte.
@export var ceu_proprio: bool = false

@export_group("Streaming")
## Distancia de carga de chunk, em metros. Nunca menor que fog_end, senao o
## jogador ve o chunk aparecer dentro do alcance de visao.
@export_range(16.0, 512.0, 16.0) var stream_radius: float = 64.0

@export_group("Grade de cor")
@export_range(0.0, 2.0, 0.01) var saturation: float = 0.88
@export var grade_tint: Color = Color.WHITE
@export_range(0.0, 4.0, 0.05) var ambient_energy: float = 0.6

## Cor da luz ambiente. Em exterior com nevoa ela e a propria cor da nevoa, que e
## o que espalha a luz. Com a nevoa desligada isso nao vale: o ceu noturno e quase
## preto, e usa-lo como ambiente apaga a cena inteira. Por isso a cor e separada.
@export var ambient_color: Color = Color("c9cdc6")

## Forca do facho de luz geometrico sob as lampadas.
##
## Nao segue a densidade da nevoa de forma linear, e por um motivo perceptual:
## em nevoa densa o fundo ja e claro, entao pouco brilho somado ja le como facho
## e muito brilho estoura em branco chapado. Em nevoa leve o fundo e escuro e o
## facho precisa de mais para aparecer. Por isso o valor e ajustado por preset em
## vez de calculado.
@export_range(0.0, 2.0, 0.01) var facho_forca: float = 0.5

# ---------------------------------------------------------------------------
# Campos de clima (novos)
# ---------------------------------------------------------------------------

@export_group("Clima")

## Hora do dia. Controla se e dia ou noite visualmente.
enum HoraDoDia { DIA, NOITE }
@export var hora_do_dia: HoraDoDia = HoraDoDia.NOITE

## Ativa particulas de chuva. Controlado por Chuva.gd.
##
## O padrao e false, e de proposito: chuva e opt-in. Quando era true, todo preset
## antigo que nao declarava o campo (denso, leve, off, interior, mercado, estufa,
## fumaca) herdava chuva em silencio, e o jogo chovia 24/7, inclusive dentro de
## casa. Clima que chove diz que chove.
@export var tem_chuva: bool = false

## Ativa estrelas no ceu noturno. So visivel com hora_do_dia == NOITE e
## nuvens < 0.5 (ceu muito coberto apaga as estrelas).
@export var tem_estrelas: bool = false

## Ativa disco da lua no ceu noturno.
@export var tem_lua: bool = false

## Cobertura de nuvens de 0 (ceu limpo) a 1 (ceu totalmente coberto).
@export_range(0.0, 1.0, 0.05) var nuvens: float = 0.9

@export_group("Iluminacao Direcional")

## Energia da luz direcional (sol ou lua). 0 = sem luz direcional.
@export_range(0.0, 4.0, 0.05) var sol_energia: float = 0.0

## Cor da luz direcional. Sol = amarelo quente, Lua = azul-branco frio.
@export var sol_cor: Color = Color("fffbe8")

## Rotacao da luz direcional. X = elevacao (positivo = mais alto no ceu),
## Y = azimute (direcao horizontal). Em graus.
@export var sol_rotacao: Vector2 = Vector2(-45.0, 30.0)


## Valida o preset contra as regras do ART-BIBLE.
## Retorna lista vazia quando o preset esta correto.
func validate() -> PackedStringArray:
	var erros := PackedStringArray()

	if fog_enabled:
		if fog_begin >= fog_end:
			erros.append("%s: fog_begin (%.1f) deve ser menor que fog_end (%.1f)"
				% [id, fog_begin, fog_end])
		if not ceu_proprio and not sky_color.is_equal_approx(fog_color):
			erros.append("%s: sky_color %s difere de fog_color %s, cria linha de horizonte"
				% [id, sky_color.to_html(false), fog_color.to_html(false)])
		_conferir_ambiente(erros)
		if stream_radius < fog_end:
			erros.append("%s: stream_radius (%.0f m) menor que fog_end (%.0f m), chunk aparece na vista"
				% [id, stream_radius, fog_end])

	if stream_radius <= 0.0:
		erros.append("%s: stream_radius deve ser positivo" % id)

	return erros


## Quanta luz de preenchimento existe, contra quanta luz o ar devolve.
##
## A regra antiga aqui exigia `ambient_color == fog_color`, e ela era errada nos
## dois sentidos ao mesmo tempo — o que e raro o bastante para merecer registro.
##
## Primeiro, ela media a grandeza errada. A luz de ambiente que o Environment
## recebe e `ambient_color` VEZES `ambient_energy`, e a regra olhava so a cor. Nos
## dezesseis presets com nevoa ligada isso produzia:
##
##   - falso positivo: `praca_noite` reprovava, e o ambiente efetivo dela e 0,22
##     do valor da nevoa — dos mais conservadores do jogo;
##   - falso negativo: `estrada_dia` passava, e o ambiente efetivo dela e 1,20 do
##     valor da nevoa — o mais alto de todos.
##
## Segundo, ela confundia luz com cor de desvanecimento. `fog_color` e para onde
## o mundo some ao longe; `ambient_color` e a luz que preenche o que nao recebe
## facho. Sao coisas diferentes, e a prova de que o jogo sabia disso e que treze
## presets tinham as duas iguais — empurrados pela regra — enquanto os tres mais
## novos, escritos por quem estava olhando a tela, escolheram ambiente perto de
## metade da nevoa e conviveram com a bateria vermelha.
##
## Isto e a mesma familia do `volumetric_fog_albedo = fog_color`, que fazia o ar
## noturno absorver em vez de espalhar e por isso o facho volumetrico nunca
## acendia. Igualar duas grandezas so porque as duas sao "a cor do ar" e um erro
## que o codigo aceita sem reclamar.
##
## O que sobrou e a faixa larga: preenchimento que nao pode ser nulo, senao tudo
## que esta na sombra sai preto chapado contra a nevoa visivel, e nao pode passar
## do dobro da nevoa, senao geometria sem luz nenhuma fica mais clara que o ar na
## frente dela. Entre um e outro e escolha de arte, e nao assunto deste arquivo.
const AMBIENTE_MINIMO := 0.05
const AMBIENTE_MAXIMO := 2.0


func _conferir_ambiente(erros: PackedStringArray) -> void:
	var luz_nevoa := (fog_color.r + fog_color.g + fog_color.b) / 3.0
	if luz_nevoa <= 0.0:
		return
	var soma := ambient_color.r + ambient_color.g + ambient_color.b
	var luz_ambiente := soma / 3.0 * ambient_energy
	var razao := luz_ambiente / luz_nevoa
	if razao < AMBIENTE_MINIMO:
		erros.append(("%s: ambiente efetivo e %.2f da nevoa; abaixo de %.2f o que "
			+ "esta na sombra sai preto chapado contra a nevoa")
			% [id, razao, AMBIENTE_MINIMO])
	elif razao > AMBIENTE_MAXIMO:
		erros.append(("%s: ambiente efetivo e %.2f da nevoa; acima de %.2f a "
			+ "geometria sem luz fica mais clara que o ar na frente dela")
			% [id, razao, AMBIENTE_MAXIMO])


## O ar de um lugar que se atravessa andando, entre a rua e o interior.
##
## Existe pelo `InteriorNoMundo`: a casa esta na calcada, e o jogador cruza a
## soleira em vez de ser teleportado. Trocar o preset inteiro num quadro faria a
## sala mudar de cor no meio do passo; misturando pela posicao, a nevoa e o
## ambiente da casa chegam enquanto ele entra.
##
## O que e da RUA fica da rua em qualquer peso: raio de streaming, hora, chuva,
## ceu e sol. Pela porta aberta o jogador continua vendo a mesma cidade, com a
## mesma chuva caindo — o que muda e o ar entre ele e ela.
static func misturar(rua: FogPreset, casa: FogPreset, t: float) -> FogPreset:
	var p := rua.duplicate() as FogPreset
	t = clampf(t, 0.0, 1.0)
	p.fog_enabled = rua.fog_enabled or casa.fog_enabled
	p.fog_begin = lerpf(rua.fog_begin, casa.fog_begin, t)
	p.fog_end = lerpf(rua.fog_end, casa.fog_end, t)
	p.fog_color = rua.fog_color.lerp(casa.fog_color, t)
	p.saturation = lerpf(rua.saturation, casa.saturation, t)
	p.grade_tint = rua.grade_tint.lerp(casa.grade_tint, t)
	p.ambient_energy = lerpf(rua.ambient_energy, casa.ambient_energy, t)
	p.ambient_color = rua.ambient_color.lerp(casa.ambient_color, t)
	p.facho_forca = lerpf(rua.facho_forca, casa.facho_forca, t)
	if t >= 0.5:
		p.id = casa.id
		p.display_name = casa.display_name
	return p
