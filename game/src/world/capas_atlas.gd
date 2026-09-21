## Gerado por tools/baixar_capas.py. Nao editar a mao.
##
## Onde cada capa esta no atlas `capas` (textures/capas.png no PS1,
## textures_hd/capas.jpg no MODERNO). UV de 0 a 1, origem no canto de cima.
class_name CapasAtlas
extends RefCounted

const LADO := 2048.0
const DISCOS: PackedStringArray = ["sobrevivendo_no_inferno", "nada_como_um_dia", "raio_x_do_brasil", "da_lama_ao_caos", "afrociberdelia", "roots", "chaos_ad", "cabeca_dinossauro", "transpiracao_continua", "tamo_ai_na_atividade", "procura_da_batida_perfeita", "lado_b_lado_a", "racional", "africa_brasil", "os_mutantes", "raimundos", "cartola_1976", "traficando_informacao", "samba_esporte_fino", "admiravel_chip_novo", "chegou_a_hora", "dois_legiao", "acabou_chorare", "clube_da_esquina", "tropicalia", "krig_ha_bandolo", "selvagem"]
const JOGOS: PackedStringArray = ["gta_san_andreas", "gta_vice_city", "gta_iii", "pes6", "pes5", "nfs_underground_2", "nfs_most_wanted", "thps3", "god_of_war", "guitar_hero", "resident_evil_4", "shadow_of_the_colossus", "silent_hill_2", "bully", "mgs3", "gran_turismo_4", "burnout_3", "kingdom_hearts_2", "tekken_5", "shaolin_monks", "budokai_tenkaichi_3", "midnight_club_3", "the_warriors", "final_fantasy_x", "fifa_street", "smackdown_2006", "crash_nitro_kart", "pirata_bomba_patch", "pirata_gta_rio", "pirata_winning", "pirata_mix"]
## A partir daqui, em JOGOS, sao encartes de CD-R pirata.
const PRIMEIRO_PIRATA := 27


static func disco(k: int) -> Rect2:
	k = posmod(k, DISCOS.size())
	var x := float(k % 8) * 256.0 + 3.0
	var y := float(k / 8) * 256.0 + 3.0
	return Rect2(x / LADO, y / LADO, 250.0 / LADO, 250.0 / LADO)


static func jogo(k: int) -> Rect2:
	k = posmod(k, JOGOS.size())
	var x := float(k % 11) * 180.0 + 3.0
	var y := 1024.0 + float(k / 11) * 256.0 + 3.0
	return Rect2(x / LADO, y / LADO, 174.0 / LADO, 250.0 / LADO)
