## Suite de assercoes do contrato PSX. Nivel 2 de validacao.
##
##     godot --headless --path game --script res://tests/run_tests.gd
##
## Sai com codigo 1 na primeira falha acumulada, para servir de portao em CI.
## Testar configuracao de projeto parece burocracia ate alguem trocar o
## renderizador sem querer e o look inteiro mudar sem ninguem notar por tres dias.
extends SceneTree

const FOG_DIR := "res://resources/fog/"
const MAT_DIR := "res://resources/materials/"
const TEX_DIR := "res://assets/textures/"

# ART-BIBLE secoes 2, 4 e 6
const RES_INTERNA := Vector2i(480, 270)
const MAX_QUAD_M := 2.0
const MAX_TEXTURA_PX := 256

var _falhas: PackedStringArray = []
var _total: int = 0


func _initialize() -> void:
	print("\n=== contrato PSX ===\n")

	_config_do_projeto()
	_estilo_visual()
	_presets_de_nevoa()
	_shaders()
	_materiais()
	_texturas()
	_listagem_de_recursos()
	_subdivisao_de_malha()
	_cruzamentos()

	print("")
	if _falhas.is_empty():
		print("OK — %d assercoes" % _total)
		quit(0)
		return

	print("FALHOU — %d de %d assercoes" % [_falhas.size(), _total])
	for f: String in _falhas:
		print("  x %s" % f)
	quit(1)


func _check(cond: bool, msg: String) -> void:
	_total += 1
	if not cond:
		_falhas.append(msg)


func _secao(nome: String) -> void:
	print("-- %s" % nome)


# --- testes -----------------------------------------------------------------

func _config_do_projeto() -> void:
	_secao("configuracao do projeto")

	# Forward+ desde a migracao para Vulkan. O ART-BIBLE 7 pedia
	# gl_compatibility por acreditar que o Compatibility "forcava naturalmente"
	# as restricoes de PS1 — nao forca, e a medida mostrou o contrario: sombra
	# funciona la, e `vertex_lighting` se comporta identico nos dois (delta
	# maximo de 1 em 255). O que o Compatibility de fato faz e RECUSAR o que o
	# jogo precisa para a agua: SSR, Decal, nevoa volumetrica e SSAO.
	#
	# O look de PS1 nao mora no renderizador, mora no preset de estilo.
	var metodo := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	_check(metodo == "forward_plus",
		"renderizador e '%s', deveria ser forward_plus" % metodo)

	var movel := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	_check(movel == "gl_compatibility",
		"perfil movel e '%s', deveria seguir em gl_compatibility: e a build para maquina sem Vulkan"
			% movel)

	for global_: String in ["psx_snap", "psx_affine", "psx_snap_escala", "psx_molhado"]:
		_check(ProjectSettings.has_setting("shader_globals/" + global_),
			"global uniform '%s' nao declarado: o interruptor de estilo nao alcanca os materiais"
				% global_)

	var w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	_check(Vector2i(w, h) == RES_INTERNA,
		"resolucao interna %dx%d, deveria ser %dx%d (ART-BIBLE 2)"
			% [w, h, RES_INTERNA.x, RES_INTERNA.y])

	var filtro := int(ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter", -1))
	_check(filtro == 0,
		"filtro de textura de canvas e %d, deveria ser 0 (nearest). Linear borra o dither" % filtro)

	for chave: String in [
		"rendering/anti_aliasing/quality/msaa_3d",
		"rendering/anti_aliasing/quality/screen_space_aa",
	]:
		_check(int(ProjectSettings.get_setting(chave, -1)) == 0,
			"%s deveria ser 0: serrilhado faz parte do alvo" % chave)


## O interruptor de estilo. Guarda as duas coisas que, quebradas em silencio,
## fariam o jogador escolher PS1 STYLE e receber outra coisa.
func _estilo_visual() -> void:
	_secao("estilo visual")

	var cfg: GDScript = load("res://src/systems/settings.gd")
	var presets: Dictionary = cfg.ESTILO_PRESETS

	# 1. PS1 STYLE tem de reproduzir o ART-BIBLE valor por valor. Estes numeros
	#    sao a build anterior ao interruptor; se um deles andar, o preset deixa
	#    de ser "o jogo de antes" e vira "parecido com o jogo de antes".
	var ps1: Dictionary = presets.get(cfg.Estilo.PS1_STYLE, {})
	_check(not ps1.is_empty(), "preset PS1_STYLE ausente")
	if not ps1.is_empty():
		var esperado := {
			&"resolucao_3d": RES_INTERNA,   # ART-BIBLE 2
			&"dither": true,                # ART-BIBLE 5
			&"scanline": 0.12,              # ART-BIBLE 9
			&"grain": 0.08,                 # ART-BIBLE 9
			&"chromatic": 0.6,              # ART-BIBLE 9
			&"vignette": 0.45,              # ART-BIBLE 9
			&"snap": true,                  # ART-BIBLE 3
			&"affine": true,                # ART-BIBLE 4
			&"luz_por_pixel": false,        # ART-BIBLE 7
			&"sombras": false,              # ART-BIBLE 7
		}
		for chave: StringName in esperado:
			_check(ps1.get(chave) == esperado[chave],
				"PS1_STYLE.%s e %s, o ART-BIBLE pede %s"
					% [chave, ps1.get(chave), esperado[chave]])

	# 2. A troca de shader so preserva os 106 materiais porque os dois arquivos
	#    declaram os MESMOS nomes de uniform. Um nome que divergisse faria
	#    aquele material perder o valor exatamente na hora de trocar de estilo —
	#    defeito mudo, que so aparece no material errado muito depois.
	# 3. Orcamento de sombra. Um numero alto aqui nao e "mais bonito": e o chao
	#    virando poca cinzenta uniforme, porque cada sombra e cortada pela luz do
	#    poste vizinho. Ver o cabecalho do DiretorSombra.
	var dir_s: GDScript = load("res://src/render/diretor_sombra.gd")
	_check(dir_s.ORCAMENTO >= 1 and dir_s.ORCAMENTO <= 4,
		"DiretorSombra.ORCAMENTO e %d: fora da faixa 1..4 a sombra deixa de dar direcao"
			% dir_s.ORCAMENTO)

	# 4. Chao nao projeta. Um plano de asfalto lancando sombra sobre si mesmo da
	#    listrado de auto-sombra e nao acrescenta nada.
	var cm: GDScript = load("res://src/world/chunk_manager.gd")
	var sem: Array = cm.SEM_SOMBRA
	for obrigatorio: StringName in [&"asfalto", &"calcada", &"grama", &"terra"]:
		_check(sem.has(obrigatorio),
			"ChunkManager.SEM_SOMBRA nao lista '%s': chao projetando da auto-sombra"
				% obrigatorio)

	# 5. Agua tem memoria. Secar MAIS devagar do que molhar e a coisa toda: e o
	#    atraso entre o ceu limpar e a rua secar que faz o lugar parecer um
	#    lugar. Invertido, o sistema vira um interruptor com passo suave.
	var clima: GDScript = load("res://src/world/clima.gd")
	_check(clima.TEMPO_SECA > clima.TEMPO_MOLHA,
		"Clima: secar (%.0f s) deveria ser mais lento que molhar (%.0f s)"
			% [clima.TEMPO_SECA, clima.TEMPO_MOLHA])

	# A chuva CAINDO e a agua PARADA sao dois relogios, e o da chuva tem de ser
	# muito mais rapido. Se aproximarem, o anel de impacto continua batendo na
	# poca minutos depois de o ceu limpar — a poca fervendo no dia seguinte.
	_check(clima.TEMPO_CHUVA * 4.0 < clima.TEMPO_SECA,
		"Clima: chuva (%.0f s) perto demais de secar (%.0f s); o anel de impacto vai sobreviver a chuva"
			% [clima.TEMPO_CHUVA, clima.TEMPO_SECA])

	# 6. Chao duro reflete, chao macio absorve. Sem esta separacao o gramado vira
	#    um lago de mercurio — aconteceu, e so a captura pegou.
	var ev: GDScript = load("res://src/render/estilo_visual.gd")
	var molhab: Dictionary = ev.MOLHABILIDADE
	for par: Array in [[&"mat_asfalto", &"mat_grama"], [&"mat_calcada", &"mat_terra"]]:
		var duro: Dictionary = molhab.get(par[0], {})
		var macio: Dictionary = molhab.get(par[1], {})
		if duro.is_empty() or macio.is_empty():
			_check(false, "MOLHABILIDADE nao cobre %s ou %s" % [par[0], par[1]])
			continue
		_check(float(duro[&"rugosidade"]) < float(macio[&"rugosidade"]),
			"%s deveria refletir mais que %s quando molhado" % [par[0], par[1]])

	# 7. A poca nao desliza. A posicao sai de um hash da celula, entao a mesma
	#    celula tem de devolver a MESMA poca sempre — senao ela troca de lugar
	#    quando o jogador anda e o pool e reapontado, que e o defeito classico de
	#    detalhe de superficie feito por sorteio.
	var pocas: GDScript = load("res://src/world/pocas.gd")
	var estavel := true
	for par: Vector2i in [Vector2i(3, 7), Vector2i(-5, 2), Vector2i(0, 0), Vector2i(41, -18)]:
		if pocas._poca_da_celula(par.x, par.y) != pocas._poca_da_celula(par.x, par.y):
			estavel = false
	_check(estavel, "Pocas: a mesma celula devolveu pocas diferentes; a poca vai deslizar")

	# A agua empoca DEPOIS de a superficie encharcar, nunca junto.
	_check(pocas.LIMIAR > 0.0 and pocas.LIMIAR < 1.0,
		"Pocas.LIMIAR e %.2f: fora de 0..1 a poca aparece junto com a primeira gota"
			% pocas.LIMIAR)

	# 8. O leque da roda so existe dentro de uma janela: agua no chao E
	#    velocidade. Os limites invertidos nao dao erro — dao um carro parado
	#    jogando agua, ou um carro a 90 km/h sem levantar nada.
	var spray: GDScript = load("res://src/world/spray_roda.gd")
	_check(spray.VEL_MINIMA < spray.VEL_CHEIA,
		"SprayRoda: VEL_MINIMA (%.1f) deveria ser menor que VEL_CHEIA (%.1f)"
			% [spray.VEL_MINIMA, spray.VEL_CHEIA])
	_check(spray.MOLHADO_MINIMO > 0.0 and spray.MOLHADO_MINIMO < 1.0,
		"SprayRoda.MOLHADO_MINIMO e %.2f: fora de 0..1 a roda levanta agua na rua seca"
			% spray.MOLHADO_MINIMO)

	# 9. A poca ESCURECE o asfalto. O brilho dela e reflexo, nao pigmento.
	#    Errado duas vezes na mesma fase: pintar o ceu no albedo faz a poca virar
	#    tinta clara, e num dia de sol ela fica mais clara que a rua por motivo
	#    nenhum.
	_check(pocas.CINZA_LAMINA < 128,
		"Pocas.CINZA_LAMINA e %d: acima do cinza medio a poca vira pigmento claro em vez de agua"
			% pocas.CINZA_LAMINA)

	# 10. A copa da arvore. O nucleo opaco tem de caber DENTRO dos blocos de
	#     recorte, senao e ele que vira a silhueta — e a arvore volta a ser uma
	#     laje verde mesmo com o recorte por alfa funcionando.
	var kp: GDScript = load("res://src/world/kit_parque.gd")
	_check(kp.COPA_NUCLEO < kp.COPA_BLOCO_MIN,
		"KitParque: nucleo da copa (%.2f) nao pode ser maior que o menor bloco externo (%.2f)"
			% [kp.COPA_NUCLEO, kp.COPA_BLOCO_MIN])

	# 11. O farol tem de encostar na rua LONGE, e nao na frente do proprio carro.
	#     Eram nove graus, e nove graus e geometria errada: a 62 cm do chao o
	#     eixo fura o asfalto a 3,9 m, e o resto de um facho de metros fica
	#     enterrado na pista. O que sobrava na tela era a parede de baixo do cone
	#     raspando a superficie — uma lamina deitada na rua, nao luz no ar.
	#
	#     O teste mede o ENCONTRO, e nao o angulo, porque o angulo aceitavel
	#     depende da altura do farol: quem baixar o farol tem de deitar a mira
	#     junto, e um teto em graus deixaria isso passar.
	var carro: GDScript = load("res://src/world/carro.gd")
	var altura_farol := 0.62
	var encontro := altura_farol / tan(absf(deg_to_rad(carro.FAROL_INCLINACAO)))
	_check(encontro >= 8.0,
		"Carro: com %.1f graus o farol encosta na rua a %.1f m; abaixo de 8 m o cone "
			% [carro.FAROL_INCLINACAO, encontro]
		+ "fica enterrado no asfalto e vira lamina deitada")
	_check(carro.FAROL_INCLINACAO < 0.0,
		"Carro: farol apontando para cima (%.1f graus)" % carro.FAROL_INCLINACAO)

	# 12. O facho nao pode ser mais longo que a distancia em que a bancada de
	#     captura poe a camera (7,5 m). Passando disso a camera entra DENTRO do
	#     tubo, onde a aproximacao de corda e falsa em todo pixel e o cone vira
	#     um cobertor cinza sobre a tela inteira.
	_check(carro.FACHO_COMPRIMENTO < 7.5,
		"Carro: facho de %.1f m alcanca a camera da bancada e a poe dentro do tubo"
			% carro.FACHO_COMPRIMENTO)

	# 13. Glow SOMADO e ponto branco acima de 1, no MODERNO.
	#
	#     Os dois padroes do Godot conspiram contra uma cena noturna. O glow nasce
	#     em SOFTLIGHT, que foi feito para foto diurna e e quase invisivel sobre
	#     preto: o glow estava LIGADO o tempo todo e mesmo assim nenhuma fonte de
	#     luz tinha halo. E o tonemap nasce LINEAR com branco em 1,0, onde tudo
	#     acima de 1 vira o MESMO #ffffff — lente de farol, letreiro e realce em
	#     poca saiam os tres como a mesma chapa branca, sem degrade por dentro, e
	#     e o degrade que o olho le como brilho.
	# 14. O item escolhido do menu tem de ser o MAIS claro da lista.
	#
	#     Estava ao contrario: o cursor pintava o item de TITULO_COR, vermelho
	#     escuro, enquanto os outros quatro ficavam quase brancos. Sobre a cidade
	#     em movimento que roda atras do menu, a selecao APAGAVA o item em vez de
	#     destaca-lo. O defeito atravessa revisao de codigo sem ser notado —
	#     `TITULO_COR if ativo else cor_ok` le como correto — e so aparece
	#     comparando as luminancias, que e o que este teste faz.
	var menu: GDScript = load("res://src/ui/menu.gd")
	_check(menu.ITEM_ESCOLHIDO.v > menu.ITEM_NORMAL.v,
		"Menu: item escolhido (v=%.2f) mais escuro que os outros (v=%.2f); a selecao apaga"
			% [menu.ITEM_ESCOLHIDO.v, menu.ITEM_NORMAL.v])
	_check(menu.ITEM_NORMAL.v > menu.ITEM_MORTO.v,
		"Menu: item indisponivel (v=%.2f) nao esta mais apagado que o normal (v=%.2f)"
			% [menu.ITEM_MORTO.v, menu.ITEM_NORMAL.v])

	# 15. Halo e letra do titulo de abertura partilham corpo, lugar e caixa.
	#
	#     Eram 44 em (18,70) de 444x52 contra 42 em (20,74) de 440x48. Dois
	#     textos centralizados em caixas diferentes e corpos diferentes abrem
	#     diferente: no meio da palavra coincidem, nas pontas as letras do halo
	#     escapam das vermelhas, e o titulo saia batido como impressao fora de
	#     registro. Halo que nao e concentrico com a letra nao e halo.
	#     A regra virou ESTRUTURA, e a assercao mudou junto. Contar ocorrencias
	#     (">= 3 vezes cada constante") era um proxy: ele exigia que os dois
	#     rotulos fossem escritos um de cada vez, com a mesma constante nos dois.
	#     Agora ha um construtor so — `_fazer_titulo_serif` — que aplica corpo,
	#     lugar e caixa aos DOIS num laco, e o proxy passou a acusar justamente o
	#     codigo que tornou o defeito impossivel.
	#
	#     O que se mede agora e o que importa: que existe um construtor unico,
	#     que as duas telas que mostram o titulo passam por ele, e que o jitter
	#     do boot escreve a MESMA posicao nos dois rotulos. Esta ultima e a que
	#     teria pego o defeito de verdade: o construtor ja estava certo e o
	#     `_process` desfazia o alinhamento a cada quadro, com (20,74) na letra e
	#     (18,70) no halo.
	var menu_fonte := FileAccess.get_file_as_string("res://src/ui/menu.gd")
	_check(menu_fonte.count("func _fazer_titulo_serif") == 1,
		"Menu: o titulo tem de ter UM construtor (halo e letra saem juntos)")
	_check(menu_fonte.count("_fazer_titulo_serif(") >= 3,
		"Menu: boot e titulo tem de montar o titulo pelo mesmo construtor")
	_check(menu_fonte.count("_boot_titulo.position = tremor") == 1
			and menu_fonte.count("_boot_titulo_glow.position = tremor") == 1,
		"Menu: o jitter do boot tem de mover halo e letra pela MESMA posicao")
	_check(not menu_fonte.contains("Vector2(18.0 + jx"),
		"Menu: o halo nao pode ter origem propria no jitter (era 18,70 contra 20,74)")

	# 16. O volume da nevoa tem de ESPALHAR luz.
	#
	#     `volumetric_fog_albedo` recebia `preset.fog_color`, e sao coisas
	#     opostas: albedo e quanta luz o ar devolve, fog_color e com que cor o
	#     mundo some ao longe. A noite o fog_color e 0,07 — ar preto, que absorve
	#     e nao espalha. Era por isso que o facho volumetrico nunca acendia:
	#     subir a densidade so escurecia a rua, seis vezes mais volume e nenhum
	#     facho.
	var fc_albedo: GDScript = load("res://src/world/fog_controller.gd")
	_check(fc_albedo.ALBEDO_MINIMO >= 0.5,
		"FogController: albedo do volume em %.2f; abaixo de 0,5 o ar absorve em vez de espalhar "
			% fc_albedo.ALBEDO_MINIMO
		+ "e o facho volumetrico nao acende por mais densidade que se ponha")

	# 17. Fonte de bitmap so pode ser ampliada em multiplo INTEIRO.
	#
	#     As quatro .fnt nasceram com `scaling_mode=2`, que autoriza qualquer
	#     escala. Como nenhum Label do menu pede tamanho, todos usavam o padrao
	#     do tema — 16 — contra tamanhos nativos de 11, 12, 14 e 18. Ou seja:
	#     cada fonte era reescalada por um fator quebrado ANTES da escala da
	#     janela, e a psx_titulo ainda por cima era REDUZIDA (16/18 = 0,889),
	#     jogando pixel fora. Medido em CONTINUAR: hastes de 3 e de 4 px na mesma
	#     palavra, que e o que faz uma UI de pixel parecer amadora.
	#
	#     Com `scaling_mode=1` o motor escolhe o multiplo inteiro mais proximo, e
	#     a grade fecha. E ajuste de IMPORTACAO: nao aparece em diff de codigo,
	#     nao da erro, e um clique no inspetor do editor desfaz. Por isso o teste.
	for fnt: String in ["psx_media", "psx_pequena", "psx_titulo", "psx_mono"]:
		var caminho := "res://assets/fontes/%s.fnt.import" % fnt
		var txt := FileAccess.get_file_as_string(caminho)
		_check(txt.contains("scaling_mode=1"),
			"%s.fnt com escala livre: a fonte sai reescalada por fator quebrado " % fnt
			+ "e as hastes verticais saem com larguras diferentes na mesma palavra")

	# 18. A lista de opcoes tem de caber no creme da folha.
	#
	#     Estourou duas vezes: uma em 19 px para fora do papel, outra em 2,6 px
	#     dentro da moldura. As duas vezes o conserto foi um passo novo cravado a
	#     mao, que envelhece na proxima linha que alguem adicionar — por isso o
	#     passo passou a sair da conta. Aqui so se confere que a conta tem espaco
	#     para existir: uma linha, sozinha, ja tem de caber.
	_check(menu.OPCOES_Y0 + float(UiEstilo.RE7_SIZE_BODY) <= menu.OPCOES_CREME_BASE,
		"Menu: a primeira linha de opcoes (y=%.0f + %.0f de fonte) ja passa do creme (%.1f)"
			% [menu.OPCOES_Y0, float(UiEstilo.RE7_SIZE_BODY), menu.OPCOES_CREME_BASE])
	_check(menu.OPCOES_PASSO_MAX > float(UiEstilo.RE7_SIZE_BODY),
		"Menu: passo maximo (%.1f) menor que a altura da fonte (%.0f); as linhas se tocam"
			% [menu.OPCOES_PASSO_MAX, float(UiEstilo.RE7_SIZE_BODY)])

	var fog_fonte := FileAccess.get_file_as_string("res://src/world/fog_controller.gd")
	_check(fog_fonte.contains("GLOW_BLEND_MODE_ADDITIVE"),
		"FogController sem glow somado: no padrao SOFTLIGHT nenhuma luz ganha halo sobre a noite")
	var fc: GDScript = load("res://src/world/fog_controller.gd")
	_check(fc.TONEMAP_BRANCO > 1.0,
		"FogController: ponto branco em %.1f faz toda luz saturar no mesmo branco chapado"
			% fc.TONEMAP_BRANCO)

	var sh_v := load("res://shaders/psx_surface.gdshader") as Shader
	var sh_p := load("res://shaders/psx_surface_pixel.gdshader") as Shader
	_check(sh_v != null, "psx_surface.gdshader nao carrega")
	_check(sh_p != null, "psx_surface_pixel.gdshader nao carrega")
	if sh_v != null and sh_p != null:
		var nomes_p := PackedStringArray()
		for u: Dictionary in sh_p.get_shader_uniform_list():
			nomes_p.append(str(u.get("name", "")))
		for u: Dictionary in sh_v.get_shader_uniform_list():
			var nome := str(u.get("name", ""))
			_check(nomes_p.has(nome),
				"uniform '%s' existe no psx_surface e falta no psx_surface_pixel: o material perde esse valor ao trocar de estilo"
					% nome)


func _presets_de_nevoa() -> void:
	_secao("presets de nevoa")
	_regra_do_ambiente()

	var ids: Array = load("res://src/systems/settings.gd").FOG_PRESET_IDS
	_check(not ids.is_empty(), "Settings.FOG_PRESET_IDS esta vazio")

	# Varre o disco em vez da lista do menu: preset de override, como o de
	# interior, tambem tem que obedecer o contrato mesmo sem aparecer nas opcoes.
	var dir := DirAccess.open(FOG_DIR)
	if dir == null:
		_check(false, "pasta de presets ausente: %s" % FOG_DIR)
		return
	var no_disco := PackedStringArray()
	for arquivo: String in dir.get_files():
		if arquivo.ends_with(".tres"):
			no_disco.append(arquivo.trim_prefix("fog_").trim_suffix(".tres"))

	for id: StringName in ids:
		_check(String(id) in no_disco, "preset do menu sem arquivo: fog_%s.tres" % id)

	for nome: String in no_disco:
		var path := "%sfog_%s.tres" % [FOG_DIR, nome]
		var id := StringName(nome)
		var preset: FogPreset = load(path)
		_check(preset != null, "%s nao carregou como FogPreset" % path)
		if preset == null:
			continue

		_check(preset.id == id, "%s tem id '%s', esperado '%s'" % [path, preset.id, id])

		for erro: String in preset.validate():
			_check(false, erro)


func _shaders() -> void:
	_secao("shaders")
	for path: String in ["res://shaders/psx_surface.gdshader", "res://shaders/post_psx.gdshader",
			"res://shaders/psx_light_cone.gdshader", "res://shaders/psx_fumaca.gdshader",
			"res://shaders/psx_agua.gdshader"]:
		_check(ResourceLoader.exists(path), "shader ausente: %s" % path)

	var fonte := FileAccess.get_file_as_string("res://shaders/psx_surface.gdshader")
	_check(fonte.contains("vertex_lighting"),
		"psx_surface sem render_mode vertex_lighting: o Godot cai em per-pixel e o look moderniza")
	_check(fonte.contains("POSITION = clip"),
		"psx_surface nao escreve POSITION: sem isso nao ha vertex snap")

	var cone := FileAccess.get_file_as_string("res://shaders/psx_light_cone.gdshader")
	_check(cone.contains("blend_add"),
		"psx_light_cone sem blend_add: o facho tem que somar, nao cobrir")
	_check(cone.contains("depth_draw_never"),
		"psx_light_cone escrevendo profundidade: o facho apagaria o que esta atras")

	# O defeito que ficou meses invisivel, e o motivo de a luz do jogo parecer
	# feia. O dither do alfa era SOMADO depois de todos os desvanecimentos:
	#
	#     a += (BAYER[idx] / 16.0 - 0.5) * 0.12;
	#
	# Somado ele nao respeita o zero. Com `a` zerado por distancia, por corda ou
	# por qualquer outro termo, ainda sobravam ate 0,06 de branco SOMADO — e 0,06
	# sobre uma rua noturna aparece. O que se via nao era luz: era um fantasma
	# pontilhado do tronco de cone, chapado e sem borda, cobrindo meia tela.
	#
	# Como FATOR o grao some junto com o facho. A diferenca entre `+=` e `*=`
	# nesta linha e a diferenca entre "a rua tem postes" e "a rua tem chapas de
	# vidro fosco", e nada no jogo avisa quando ela volta: nao ha erro, nao ha
	# aviso, e em 480x270 o fantasma se confunde com o dither da imagem toda.
	_check(not cone.contains("a += (BAYER"),
		"psx_light_cone somando o dither no alfa: o facho deixa de respeitar o zero "
		+ "e vira uma chapa pontilhada por cima da cena (ver comentario no shader)")
	_check(cone.contains("a *= 1.0 + (BAYER"),
		"psx_light_cone sem o dither como fator: o grao tem que sumir junto com o facho")

	var pos := FileAccess.get_file_as_string("res://shaders/post_psx.gdshader")
	_check(pos.contains("filter_nearest"),
		"post_psx sem filter_nearest no screen_tex: o dither borra no upscale")


func _materiais() -> void:
	_secao("materiais")
	var dir := DirAccess.open(MAT_DIR)
	_check(dir != null, "pasta de materiais ausente: %s" % MAT_DIR)
	if dir == null:
		return

	var achou := 0
	for arquivo: String in dir.get_files():
		if not arquivo.ends_with(".tres"):
			continue
		achou += 1
		var mat: ShaderMaterial = load(MAT_DIR + arquivo)
		_check(mat != null, "%s nao carregou como ShaderMaterial" % arquivo)
		if mat == null:
			continue
		if mat.shader == null:
			_check(false, "%s sem shader" % arquivo)
			continue

		var caminho := mat.shader.resource_path
		if caminho.contains("psx_light_cone"):
			# Facho de luz: geometria somada, sem textura e sem iluminacao.
			_check(mat.render_priority > 0,
				"%s deveria ter render_priority acima de 0 para desenhar apos o opaco" % arquivo)
			continue

		if caminho.contains("psx_fumaca"):
			# Fumaca / veu: geometria misturada (blend_mix), depois do opaco.
			# mat_fumaca_* e mat_olhos_vermelhos usam este shader de proposito.
			_check(mat.render_priority > 0,
				"%s deveria ter render_priority acima de 0 para desenhar apos o opaco" % arquivo)
			_check(mat.get_shader_parameter(&"albedo_tex") != null,
				"%s sem textura em albedo_tex" % arquivo)
			continue

		if caminho.contains("psx_marca"):
			# Marca de pneu: sujeira MULTIPLICADA sobre o asfalto, desenhada
			# depois do opaco e sem textura nenhuma — o desenho dela sai da cor
			# do vertice, que carrega quanto o pneu escorregou e ha quanto
			# tempo. Ver `shaders/psx_marca.gdshader`.
			_check(mat.render_priority > 0,
				"%s deveria ter render_priority acima de 0 para desenhar apos o opaco" % arquivo)
			continue

		if caminho.contains("psx_agua"):
			_check(mat.get_shader_parameter(&"albedo_tex") != null,
				"%s sem textura em albedo_tex" % arquivo)
			continue

		_check(caminho.contains("psx_surface"),
			"%s usa shader inesperado: %s" % [arquivo, caminho])
		_check(mat.get_shader_parameter(&"albedo_tex") != null,
			"%s sem textura em albedo_tex" % arquivo)

	_check(achou > 0, "nenhum material encontrado em %s" % MAT_DIR)


func _texturas() -> void:
	_secao("texturas")
	var dir := DirAccess.open(TEX_DIR)
	if dir == null:
		_check(false, "pasta de texturas ausente: %s" % TEX_DIR)
		return

	for arquivo: String in dir.get_files():
		if not arquivo.ends_with(".png"):
			continue

		var tex: Texture2D = load(TEX_DIR + arquivo)
		if tex == null:
			_check(false, "%s nao carregou" % arquivo)
			continue

		_check(tex.get_width() <= MAX_TEXTURA_PX and tex.get_height() <= MAX_TEXTURA_PX,
			"%s tem %dx%d, teto e %d px (ART-BIBLE 6)"
				% [arquivo, tex.get_width(), tex.get_height(), MAX_TEXTURA_PX])

		# O preset de importacao e onde o contrato de textura mora de verdade.
		var cfg := ConfigFile.new()
		if cfg.load(TEX_DIR + arquivo + ".import") != OK:
			_check(false, "%s sem arquivo .import" % arquivo)
			continue
		_check(not bool(cfg.get_value("params", "mipmaps/generate", true)),
			"%s com mipmap: em distancia a textura vira borrao e o dither some" % arquivo)
		_check(int(cfg.get_value("params", "compress/mode", -1)) == 0,
			"%s nao esta em lossless: a compressao destroi a paleta" % arquivo)
		_check(int(cfg.get_value("params", "detect_3d/compress_to", -1)) == 0,
			"%s com detect_3d ligado: o Godot recomprime sozinho ao ver uso em 3D" % arquivo)


## Listagem de recurso e o unico ponto do projeto que se comporta diferente no
## pacote exportado. Se ela quebrar, o jogo publicado fica sem item e sem som,
## em silencio.
func _listagem_de_recursos() -> void:
	_secao("listagem de recursos")

	var itens := Recursos.listar("res://resources/itens/", "tres")
	_check(itens.size() >= 8,
		"Recursos.listar achou so %d itens em resources/itens" % itens.size())
	for caminho: String in itens:
		_check(ResourceLoader.exists(caminho), "caminho invalido: %s" % caminho)

	var sons := Recursos.listar("res://assets/audio/", "wav")
	_check(sons.size() >= 20,
		"Recursos.listar achou so %d sons em assets/audio" % sons.size())

	# Nenhum caminho pode sair com sufixo de empacotamento.
	for caminho: String in itens + sons:
		_check(not caminho.ends_with(".remap") and not caminho.ends_with(".import"),
			"caminho com sufixo de pacote: %s" % caminho)


func _subdivisao_de_malha() -> void:
	_secao("subdivisao de malha")

	# A UV afim distorce proporcionalmente ao tamanho do poligono. PSXMesh existe
	# para garantir o teto de 2 m por construcao; este teste prova que garante.
	var mesh := PSXMesh.plane(Vector2(12.0, 7.0))
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	_check(not idx.is_empty(), "PSXMesh.plane devolveu malha sem indices")

	var maior := 0.0
	for i in range(0, idx.size(), 3):
		for par: Array in [[0, 1], [1, 2], [2, 0]]:
			var a := verts[idx[i + par[0]]]
			var b := verts[idx[i + par[1]]]
			maior = maxf(maior, a.distance_to(b))

	# A diagonal de um quad de 2 m mede 2*sqrt(2) = 2.83
	var teto := MAX_QUAD_M * sqrt(2.0) + 0.01
	_check(maior <= teto,
		"maior aresta de PSXMesh.plane e %.2f m, teto e %.2f m (ART-BIBLE 4)" % [maior, teto])

	_check(PSXMesh.triangle_count(mesh) == 6 * 4 * 2,
		"contagem de triangulos inesperada: %d" % PSXMesh.triangle_count(mesh))


## Direcao de tudo o que fica na esquina.
##
## E o teste que faltava. Semaforo virado para o lado errado, sinal de pedestre
## atravessado em relacao a zebra e arvore plantada em cima da faixa nao apareciam
## em captura nenhuma: de longe tudo vira o mesmo borrao de dois pixels na nevoa,
## e de perto o olho aceita qualquer coisa que esteja numa esquina. Aqui a
## afirmacao e geometrica, e sai da MESMA funcao que constroi (ChunkBuilder), com
## a direcao do transito vindo de Vias.
func _cruzamentos() -> void:
	_secao("cruzamento: zebra, semaforo e sinal de pedestre")

	var casos: Array[Vector2i] = []
	for i in range(-8, 9):
		for j in range(-8, 9):
			if Vias.existe_cruzamento(i, j):
				casos.append(Vector2i(i, j))
	_check(casos.size() >= 8,
		"achei so %d cruzamentos na malha de 17x17 chunks" % casos.size())

	for c: Vector2i in casos:
		_afirmar_cruzamento(c)

	# Arvore de calcada: nenhuma pode nascer dentro da caixa de uma travessia.
	# A fileira da avenida vem a cada 11 m ao longo da via, e quando a faixa de
	# estacionamento empurrou o meio-fio ela foi parar em cima da zebra.
	var invasoras := 0
	var total := 0
	for i in range(-8, 9):
		for j in range(-8, 9):
			for base: Vector3 in ChunkBuilder.arvores(i, j):
				total += 1
				var mundo := base + Vector3(float(i) * 32.0, 0.0, float(j) * 32.0)
				if _dentro_de_travessia(mundo):
					invasoras += 1
	_check(total > 0, "nenhuma arvore de calcada foi plantada em 17x17 chunks")
	_check(invasoras == 0,
		"%d de %d arvores de calcada nascem dentro de uma travessia"
			% [invasoras, total])


func _afirmar_cruzamento(c: Vector2i) -> void:
	# Quantos bracos dirigiveis o no tem: quatro no cruzamento, tres no T. Cada
	# braco e uma travessia e uma aproximacao de carro.
	var bracos := 0
	for b: bool in [Vias.braco_n(c.x, c.y), Vias.braco_s(c.x, c.y),
			Vias.braco_l(c.x, c.y), Vias.braco_o(c.x, c.y)]:
		if b:
			bracos += 1
	_check(bracos >= 3,
		"cruzamento %s tem %d bracos; no com menos de tres nao e cruzamento" % [c, bracos])

	var faixas := ChunkBuilder.travessias(c.x, c.y)
	_check(faixas.size() == bracos,
		"cruzamento %s tem %d travessias, deveria ter %d" % [c, faixas.size(), bracos])

	var sinais := ChunkBuilder.sinais_do_cruzamento(c.x, c.y)

	# Toda aproximacao de carro — cada braco que existe — precisa ter uma cabeca,
	# e nenhuma pode ficar sem.
	var aproximacoes := {}
	var travessias_servidas := {}

	for s: Dictionary in sinais:
		var eixo := int(s["eixo"])
		var sentido := float(s["sentido"])
		var pos: Vector3 = s["pos"]
		if not bool(s["com_semaforo"]):
			_checar_sinal_pedestre(c, s, faixas, travessias_servidas)
			continue
		aproximacoes[Vector2i(eixo, signi(int(sentido)))] = true

		# 1. A cabeca encara quem vem. `frente` e a normal da face, e o carro
		#    anda no sentido oposto a ela.
		var frente := Vector3(sin(float(s["giro"])), 0.0, cos(float(s["giro"])))
		var anda := Vias.direcao(eixo, signi(int(sentido)))
		_check(frente.dot(anda) < -0.99,
			"%s: semaforo do eixo %d sentido %+d olha para %v, e o carro vem de %v"
				% [c, eixo, signi(int(sentido)), frente, -anda])

		# 2. O poste fica DEPOIS da faixa (lado de la) e na mao do motorista.
		#    A direita e `frente x cima`, a mesma conta documentada em Vias.
		var plano := Vector3(pos.x, 0.0, pos.z)
		_check(plano.dot(anda) > 0.0,
			"%s: semaforo do eixo %d sentido %+d esta antes da faixa, em %v"
				% [c, eixo, signi(int(sentido)), plano])
		var direita := anda.cross(Vector3.UP)
		_check(plano.dot(direita) > 0.0,
			"%s: semaforo do eixo %d sentido %+d esta na contramao, em %v"
				% [c, eixo, signi(int(sentido)), plano])
		_checar_sinal_pedestre(c, s, faixas, travessias_servidas)

	_check(aproximacoes.size() == bracos,
		"%s: as %d aproximacoes de carro deveriam ter um semaforo cada, tem %d"
			% [c, bracos, aproximacoes.size()])
	_check(travessias_servidas.size() == faixas.size(),
		"%s: as %d travessias deveriam ter um sinal de pedestre cada, tem %d"
			% [c, faixas.size(), travessias_servidas.size()])


func _checar_sinal_pedestre(c: Vector2i, s: Dictionary, faixas: Array[Dictionary],
		travessias_servidas: Dictionary) -> void:
	if not bool(s["com_pedestre"]):
		return
	var eixo := int(s["eixo"])
	# 3. O sinal de pedestre olha na direcao de quem atravessa, e nao na do
	#    carro: quem anda em X le uma cara virada para X.
	var marcha := int(s["ped_marcha"])
	_check(marcha == 1 - eixo,
		"%s: sinal de pedestre marcha %d num poste de eixo %d" % [c, marcha, eixo])
	var ped_sentido := signi(int(s["ped_sentido"]))
	var frente_ped := Vector3(sin(float(s["ped_giro"])), 0.0, cos(float(s["ped_giro"])))
	var atravessa := Vias.direcao(marcha, ped_sentido)
	_check(frente_ped.dot(atravessa) < -0.99,
		"%s: sinal de pedestre olha para %v, e quem atravessa vem de %v"
			% [c, frente_ped, -atravessa])

	# 4. E o sinal pertence a uma travessia que existe, do lado em que ele
	#    esta plantado — nao adianta apontar certo do lado errado da rua.
	var ped_pos: Vector3 = s["ped_pos"]
	var achou := ""
	for t: Dictionary in faixas:
		if int(t["eixo_marcha"]) != marcha:
			continue
		var centro: Vector3 = t["centro"]
		# A travessia se desloca no eixo perpendicular a marcha.
		var lado_faixa := centro.x if marcha == 0 else centro.z
		var lado_sinal := ped_pos.x if marcha == 0 else ped_pos.z
		if signf(lado_faixa) == signf(lado_sinal):
			achou = "%v" % centro
			travessias_servidas[centro] = true
	_check(achou != "",
		"%s: sinal de pedestre em %v nao fica na ponta de travessia nenhuma"
			% [c, ped_pos])


## O ponto (em coordenada de mundo) cai dentro da caixa de alguma travessia?
func _dentro_de_travessia(mundo: Vector3) -> bool:
	var ci := floori(mundo.x / 32.0)
	var cj := floori(mundo.z / 32.0)
	for di in range(-1, 2):
		for dj in range(-1, 2):
			var i := ci + di
			var j := cj + dj
			if not Vias.existe_cruzamento(i, j):
				continue
			var vx := ChunkBuilder.vao_travessia(Vias.meia_asfalto_x_no(i, j))
			var vz := ChunkBuilder.vao_travessia(Vias.meia_asfalto_z_no(i, j))
			if absf(mundo.x - float(i) * 32.0) <= vx \
					and absf(mundo.z - float(j) * 32.0) <= vz:
				return true
	return false


## A regra de ambiente tem de olhar a ENERGIA, e nao so a cor.
##
## Testa o comportamento do validador com presets montados na hora, e nao o texto
## do arquivo: e a unica forma de provar que a regra mede a grandeza certa.
##
## A regra anterior exigia `ambient_color == fog_color` e ignorava
## `ambient_energy`. Isso a deixava errada nos dois sentidos ao mesmo tempo,
## coisa rara o bastante para virar teste:
##
##   - deixava passar `estrada_dia`, cujo ambiente EFETIVO era 1,20 da nevoa,
##     porque a cor batia;
##   - reprovava `praca_noite`, cujo ambiente efetivo era 0,22 da nevoa — dos
##     mais conservadores do jogo — porque a cor nao batia.
##
## Os dois casos abaixo sao exatamente esses dois formatos. Se alguem voltar a
## comparar so a cor, o primeiro passa a aprovar e o segundo a reprovar, e os
## dois checks caem juntos.
func _regra_do_ambiente() -> void:
	var cinza := Color(0.5, 0.5, 0.5)

	# Cor identica a nevoa, energia absurda: a regra TEM de reprovar.
	var exagerado := FogPreset.new()
	exagerado.id = "teste_energia_alta"
	exagerado.fog_enabled = true
	exagerado.fog_begin = 4.0
	exagerado.fog_end = 40.0
	exagerado.stream_radius = 64.0
	exagerado.fog_color = cinza
	exagerado.sky_color = cinza
	exagerado.ambient_color = cinza
	exagerado.ambient_energy = 4.0
	_check(exagerado.validate().size() > 0,
		"FogPreset: ambiente com a cor da nevoa mas energia 4,0 passou na validacao; "
		+ "a regra esta olhando so a cor e ignorando ambient_energy")

	# Cor bem mais escura que a nevoa, energia modesta: a regra NAO pode reprovar.
	var sobrio := FogPreset.new()
	sobrio.id = "teste_ambiente_sobrio"
	sobrio.fog_enabled = true
	sobrio.fog_begin = 4.0
	sobrio.fog_end = 40.0
	sobrio.stream_radius = 64.0
	sobrio.fog_color = cinza
	sobrio.sky_color = cinza
	sobrio.ambient_color = Color(0.16, 0.16, 0.16)
	sobrio.ambient_energy = 1.0
	_check(sobrio.validate().is_empty(),
		"FogPreset: ambiente a 0,32 da nevoa foi reprovado (%s); "
			% ", ".join(sobrio.validate())
		+ "escolher preenchimento mais escuro que a nevoa e decisao de arte, nao erro")

	# Ceu proprio dispensa a regra de horizonte, e so ela.
	var com_cupula := FogPreset.new()
	com_cupula.id = "teste_ceu_proprio"
	com_cupula.fog_enabled = true
	com_cupula.fog_begin = 4.0
	com_cupula.fog_end = 40.0
	com_cupula.stream_radius = 64.0
	com_cupula.fog_color = cinza
	com_cupula.sky_color = Color(0.2, 0.3, 0.7)
	com_cupula.ambient_color = Color(0.3, 0.3, 0.3)
	com_cupula.ambient_energy = 1.0
	com_cupula.ceu_proprio = true
	_check(com_cupula.validate().is_empty(),
		"FogPreset: preset com cupula propria reprovado por sky_color (%s); "
			% ", ".join(com_cupula.validate())
		+ "onde o nivel desenha o proprio ceu nao ha emenda de horizonte para haver")
	com_cupula.ceu_proprio = false
	_check(com_cupula.validate().size() > 0,
		"FogPreset: sky_color divergente passou mesmo sem cupula; a regra de "
		+ "horizonte parou de valer para quem usa o fundo chapado")
