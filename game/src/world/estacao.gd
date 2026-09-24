## A estacao do ano da vegetacao (PLANO_FLORA_AAA, etapa 7).
##
## Minas tem duas: a SECA (maio a setembro), de capim amarelo, folha caindo e
## poeira vermelha, e as AGUAS (outubro a abril), de tudo verde. E a florada
## anda pelo calendario: o ipe rosa em junho e julho, o amarelo em agosto e
## setembro, a quaresmeira de janeiro a abril.
##
## O jogo nao tem calendario (o Relogio conta hora e dia da partida, e a partida
## dura noites), entao a estacao e uma escolha, e nao uma conta: AGOSTO por
## padrao — o mes do ipe amarelo e da seca, a imagem de Minas que a praca mais
## precisa. `--mes=N` troca para captura e comparacao. Se um dia houver
## calendario, e so ele escrever `mes` antes de a cidade montar.
##
## Tudo aqui e lido na MONTAGEM do chunk (a arvore escolhe a celula de flor ou
## de folha quando nasce) e nao sorteia nada do rng de quem planta.
class_name Estacao
extends RefCounted

static var mes: int = _mes_inicial()


static func _mes_inicial() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mes="):
			return clampi(arg.trim_prefix("--mes=").to_int(), 1, 12)
	return 8


## Quanto e seca, de 0 (aguas) a 1 (auge da seca). Maio e outubro sao a virada.
static func seca() -> float:
	match mes:
		6, 7, 8, 9:
			return 1.0
		5, 10:
			return 0.5
	return 0.0


## A especie esta em flor neste mes?
static func florindo(especie: StringName) -> bool:
	match especie:
		&"ipe_rosa":
			return mes in [6, 7, 8]
		&"ipe_amarelo":
			return mes in [8, 9]
		&"quaresmeira":
			return mes in [1, 2, 3, 4, 12]
		&"reseda":
			return mes in [1, 2, 3, 12]
		&"pata_de_vaca":
			return mes in [6, 7, 8, 9]
		&"primavera":
			return true
	return false
