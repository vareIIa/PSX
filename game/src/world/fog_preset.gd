## Preset de nevoeiro. Um recurso por nivel de visibilidade.
##
## A nevoa nao e enfeite: ela e o sistema de oclusao que torna a cidade possivel.
## Por isso o raio de streaming vive aqui dentro e nao no ChunkManager — os dois
## valores tem que mudar juntos ou o jogador ve chunk aparecendo no vazio.
##
## Contrato em docs/ART-BIBLE.md secao 8.
class_name FogPreset
extends Resource

## Identificador estavel usado no arquivo de configuracao. Nao traduza.
@export var id: StringName = &"denso"

## Nome mostrado no menu de opcoes.
@export var display_name: String = "Denso"

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
