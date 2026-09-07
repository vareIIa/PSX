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
@export var sky_color: Color = Color("c9cdc6")

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
		if not sky_color.is_equal_approx(fog_color):
			erros.append("%s: sky_color %s difere de fog_color %s, cria linha de horizonte"
				% [id, sky_color.to_html(false), fog_color.to_html(false)])
		if not ambient_color.is_equal_approx(fog_color):
			erros.append("%s: com nevoa ligada, ambient_color deve igualar fog_color"
				% id)
		if stream_radius < fog_end:
			erros.append("%s: stream_radius (%.0f m) menor que fog_end (%.0f m), chunk aparece na vista"
				% [id, stream_radius, fog_end])

	if stream_radius <= 0.0:
		erros.append("%s: stream_radius deve ser positivo" % id)

	return erros
