## Autoload. Transforma o estilo escolhido em imagem.
##
## O `Settings` guarda a preferencia e nao sabe desenhar; este no escuta
## `changed` e aplica. E o mesmo contrato do `PSXPost`, que cuida da cadeia de
## pos-processo — aqui ficam as tres coisas que o pos NAO alcanca:
##
##   1. resolucao interna do 3D
##   2. snap de vertice e UV afim, via `global uniform`
##   3. modelo de iluminacao, via troca de `material.shader`
##
## Por que uniform GLOBAL e nao varredura de material
## --------------------------------------------------
## Snap e UV afim existem em todo material de superficie. Escrever neles um por
## um exigiria um registro central de materiais que este projeto nao tem (cada
## script carrega o seu por caminho). `global uniform` resolve isso no motor:
## uma chamada de `RenderingServer` alcanca todos de uma vez, inclusive os que
## ainda nem foram carregados pelo streaming de chunk.
##
## A troca de shader nao tem essa saida, porque `vertex_lighting` e
## `shadows_disabled` sao `render_mode` e o compilador ja os resolveu. Essa parte
## varre o diretorio de materiais uma vez e guarda a lista.
extends Node

const DIR_MATERIAIS := "res://resources/materials/"
const SHADER_VERTEX := "res://shaders/psx_surface.gdshader"
const SHADER_PIXEL := "res://shaders/psx_surface_pixel.gdshader"
## A janela do MODERNO tem shader proprio (PLANO_AAA_4K, Fase 11, criterio A34).
const SHADER_JANELA := "res://shaders/psx_janela.gdshader"

## Lataria, vidro e lente de carro tambem (PLANO_CARROS_AAA, F1/F2/F4): verniz,
## metal, vidro transparente e farol com refletor no MODERNO. No PS1 STYLE os
## tres voltam ao `psx_surface`.
const CARROS := {
	&"mat_carro": "res://shaders/psx_carro.gdshader",
	&"mat_carro_vidro": "res://shaders/psx_carro_vidro.gdshader",
	&"mat_carro_luz": "res://shaders/psx_carro_luz.gdshader",
}

## As quatro fontes do projeto. A vetorial de cada uma e o mesmo nome com `_v`
## e extensao de TrueType, gerada por `tools/gerar_fonte_vetor.py` a partir do
## PROPRIO bitmap. Ver `_aplicar_fontes`.
const FONTES: Array[String] = [
	"res://assets/fontes/psx_pequena.fnt",
	"res://assets/fontes/psx_media.fnt",
	"res://assets/fontes/psx_titulo.fnt",
	"res://assets/fontes/psx_mono.fnt",
]

## Quais materiais sao janela, e se o comodo atras esta aceso.
##
## No PS1 STYLE eles voltam para `psx_surface` com a textura de sempre: a build
## de 1999 nao muda (contrato A2).
const JANELAS := {
	&"mat_janela_acesa": true,
	&"mat_janela_apagada": false,
	# Vitrine de loja: a luz de dentro e o que faz a rua comercial existir a
	# noite, e de dia ela some no brilho do vidro.
	&"mat_vitrine": true,
}

## Como cada superficie reage a chuva, por nome de material.
##
## Politica em runtime, e nao coluna no `tools/gerar_materiais.py`, pelo mesmo
## motivo do `ChunkManager.SEM_SOMBRA`: a tabela do gerador tem 106 entradas e
## isto descreve quatro familias. Aplicado depois da carga, sobrevive a
## regeneracao dos .tres sem precisar que ninguem se lembre de vir aqui.
##
## `molha` = quanto a superficie encharca.
## `rugosidade` = quao espelhada ela fica encharcada. Alto = absorve.
##
## Ha uma HIERARQUIA aqui, e ela importa mais que os numeros. Poca > asfalto >
## calcada > grama. Asfalto molhado nao e espelho: e uma superficie rugosa com
## uma pelicula de agua, e devolve manchas alongadas, nao a imagem. Quando ele
## estava em 0,07 o reflexo do carro virava um borrao do tamanho da rua — a agua
## parada da poca e que tem direito de espelhar, e por isso a textura da poca vai
## a 0,10 enquanto o asfalto em volta fica em 0,19.
const MOLHABILIDADE := {
	# Absorvem. Escurecem muito e refletem pouco — grama molhada nao e espelho,
	# e foi assim que o gramado virou um lago de mercurio na primeira captura.
	#
	# Os numeros subiram de novo (0,55–0,65 para 0,72–0,76) contra o ceu ENCOBERTO
	# da Estrada Velha. Sob um preset de sol, a fonte e pequena e o realce cabe
	# numa faixa estreita da folha; sob um ceu coberto, a fonte e o ceu inteiro e
	# o mesmo numero espalha o realce pela folha toda — a moita perto da lente
	# saia como uma placa cinza lisa, sem textura, que e o defeito de sempre com
	# outra causa. Folha molhada escurece; quem devolve luz e a agua que escorre
	# dela, e essa nao cabe num numero de rugosidade.
	&"mat_grama": {&"molha": 0.85, &"rugosidade": 0.72},
	&"mat_terra": {&"molha": 0.95, &"rugosidade": 0.55},
	&"mat_areia": {&"molha": 0.90, &"rugosidade": 0.58},
	&"mat_mato": {&"molha": 0.80, &"rugosidade": 0.76},
	&"mat_folhagem": {&"molha": 0.70, &"rugosidade": 0.72},
	# A folha RECORTADA faltava, e ela e a que enche a mata da Estrada Velha:
	# `KitEstrada.massa` — a caixa de folha que faz o sub-bosque e o fundo — usa
	# so este material. Fora da tabela ela caia no padrao do shader, e a face de
	# cima de cada caixa virava espelho: no plano aereo aparecia como um clarao
	# branco cravado no meio da mata, e no plano do bicho como lajes cinzas
	# lisas no terco de baixo do quadro. A mesma causa em dois planos.
	&"mat_folhagem_recorte": {&"molha": 0.70, &"rugosidade": 0.72},
	&"mat_arbusto": {&"molha": 0.70, &"rugosidade": 0.72},
	&"mat_flor": {&"molha": 0.70, &"rugosidade": 0.72},
	&"mat_casca": {&"molha": 0.85, &"rugosidade": 0.74},
	&"mat_casca_palmeira": {&"molha": 0.85, &"rugosidade": 0.7},
	&"mat_vegetacao": {&"molha": 0.70, &"rugosidade": 0.72},
	# As plantas de quintal da rodada 2 do PLANO_FLORA_AAA (Plantas).
	&"mat_plantas": {&"molha": 0.70, &"rugosidade": 0.72},
	&"mat_caule": {&"molha": 0.80, &"rugosidade": 0.6},
	# A Estrada Velha. O leito e terra batida, e terra batida ABSORVE: escurece
	# muito e devolve pouco. Sem estas linhas ela cai no padrao do shader
	# (molha 1,0 / rugosidade 0,12), que e o numero da POCA — e a estrada
	# inteira, mais o chao da mata, vira um espelho de mercurio na primeira
	# gota. Quem tem direito de espelhar ali e a poca, que e decal proprio
	# (ver PocasEstrada) e carrega a propria rugosidade.
	# 0,62 e nao 0,46: sob o ceu ENCOBERTO do temporal a fonte de luz e o ceu
	# inteiro, e com 0,46 o realce cobria metade da pista de uma vez — o lado
	# direito do leito saia como uma faixa cinza lisa, sem barro e sem trilha,
	# do lado de uma metade esquerda que continuava marrom. Terra batida
	# molhada nao tem lamina; a lamina e a poca, e ela tem rugosidade propria.
	&"mat_leito": {&"molha": 0.95, &"rugosidade": 0.62},
	&"mat_tabua": {&"molha": 0.80, &"rugosidade": 0.52},
	&"mat_metal": {&"molha": 1.0, &"rugosidade": 0.30},
	# A lataria. Chapa pintada molhada reflete — e o efeito que a chuva na
	# cidade existe para mostrar — mas ela nao e a poca: verniz automotivo
	# molhado devolve manchas alongadas e um realce duro, nao a imagem. Sem
	# esta linha o carro caia no padrao do shader (0,12), que e o numero da
	# lamina de agua parada, e o capo virava um espelho de cromo virado para
	# cima: no plano de dentro da Estrada Velha ele estourava em branco e
	# ocupava o terco de baixo do para-brisa inteiro.
	# `gotas`: a chapa junta gota parada no primeiro segundo de chuva (criterio
	# A18 do PLANO_AAA_4K). A lente do farol junta menos: e vidro inclinado.
	&"mat_carro": {&"molha": 1.0, &"rugosidade": 0.26, &"gotas": 1.0},
	&"mat_carro_luz": {&"molha": 0.9, &"rugosidade": 0.22, &"gotas": 0.6},
	# O vidro de fora junta gota como a chapa; a rugosidade molhada nao muda
	# nada nele, que ja e liso.
	&"mat_carro_vidro": {&"molha": 1.0, &"rugosidade": 0.05, &"gotas": 1.0},
	# Gente. Fora da tabela, o ombro e o alto da cabeca caiam no padrao do
	# shader e viravam lamina de agua na chuva. Tecido absorve: `roupa` escurece
	# o corpo inteiro com o molhado do mundo.
	&"mat_npc": {&"molha": 0.35, &"rugosidade": 0.55, &"roupa": 1.0},
	# Viram lamina. E delas que sai o reflexo do poste.
	&"mat_asfalto": {&"molha": 1.0, &"rugosidade": 0.19},
	&"mat_asfalto_faixa": {&"molha": 1.0, &"rugosidade": 0.19},
	&"mat_asfalto_remendo": {&"molha": 1.0, &"rugosidade": 0.22},
	&"mat_calcada": {&"molha": 1.0, &"rugosidade": 0.24},
	&"mat_calcada_ladrilho": {&"molha": 1.0, &"rugosidade": 0.22},
	# Pedra de rua: a agua fica na junta e o granito brilha menos que o asfalto.
	&"mat_paralelepipedo": {&"molha": 1.0, &"rugosidade": 0.26},
	&"mat_meio_fio": {&"molha": 1.0, &"rugosidade": 0.26},
	&"mat_pedra_parque": {&"molha": 1.0, &"rugosidade": 0.12},
	&"mat_concreto": {&"molha": 1.0, &"rugosidade": 0.14},
	&"mat_concreto_sujo": {&"molha": 1.0, &"rugosidade": 0.16},
	# --- fachada (Fase 11) ---------------------------------------------------
	# Estas nove estavam FORA da tabela e caiam no padrao do shader, 0,12, que e
	# o numero da lamina de agua parada: todo peitoril, beiral e topo de muro
	# virava espelho na chuva. E o mesmo defeito que o `mat_npc` tinha.
	&"mat_reboco": {&"molha": 0.85, &"rugosidade": 0.42},
	&"mat_tijolo": {&"molha": 0.90, &"rugosidade": 0.50},
	&"mat_teto": {&"molha": 1.0, &"rugosidade": 0.34},
	# Telha ceramica: porosa, escurece muito e brilha pouco.
	&"mat_telha": {&"molha": 1.0, &"rugosidade": 0.38},
	# A francesa do TelhadoVivo: barro de forno industrial, mais liso.
	&"mat_telha_francesa": {&"molha": 1.0, &"rugosidade": 0.32},
	&"mat_azulejo": {&"molha": 1.0, &"rugosidade": 0.18},
	&"mat_porta": {&"molha": 0.80, &"rugosidade": 0.40},
	&"mat_toldo": {&"molha": 0.70, &"rugosidade": 0.45},
	&"mat_casa": {&"molha": 0.90, &"rugosidade": 0.44},
	&"mat_casa_recorte": {&"molha": 0.90, &"rugosidade": 0.44},
	&"mat_casa_tela": {&"molha": 0.90, &"rugosidade": 0.44},
	# Vidro: quase espelho encharcado, e ja quase espelho seco.
	&"mat_janela_acesa": {&"molha": 1.0, &"rugosidade": 0.10},
	&"mat_janela_apagada": {&"molha": 1.0, &"rugosidade": 0.10},
	# Vitro canelado do fundo (FundosVivos): vidro, molha como a janela.
	&"mat_vidro_canelado": {&"molha": 1.0, &"rugosidade": 0.10},
	&"mat_vitrine": {&"molha": 1.0, &"rugosidade": 0.10},
	&"mat_metal_ondulado": {&"molha": 1.0, &"rugosidade": 0.28},
	&"mat_metal_pintado": {&"molha": 1.0, &"rugosidade": 0.30},
	&"mat_letreiro_nome": {&"molha": 1.0, &"rugosidade": 0.30},
	&"mat_letreiro_industria": {&"molha": 1.0, &"rugosidade": 0.30},
	# O anuncio pintado na empena (EmpenaViva): tinta velha na parede.
	&"mat_anuncio_empena": {&"molha": 1.0, &"rugosidade": 0.34},
	&"mat_metal_enferrujado": {&"molha": 1.0, &"rugosidade": 0.42},
	&"mat_corrente": {&"molha": 1.0, &"rugosidade": 0.30},
	&"mat_letreiro": {&"molha": 1.0, &"rugosidade": 0.26},
	&"mat_marca_via": {&"molha": 1.0, &"rugosidade": 0.20},
	&"mat_placa_parque": {&"molha": 1.0, &"rugosidade": 0.25},
	&"mat_sinal_anda": {&"molha": 1.0, &"rugosidade": 0.25},
	&"mat_sinal_para": {&"molha": 1.0, &"rugosidade": 0.25},
	&"mat_semaforo_luz": {&"molha": 1.0, &"rugosidade": 0.22},
	&"mat_maquina_venda": {&"molha": 1.0, &"rugosidade": 0.28},
	&"mat_bicicleta": {&"molha": 1.0, &"rugosidade": 0.30},
	&"mat_personagem": {&"molha": 0.60, &"rugosidade": 0.50},
	&"mat_estufa": {&"molha": 1.0, &"rugosidade": 0.12},
	&"mat_estufa_recorte": {&"molha": 1.0, &"rugosidade": 0.12},
	# Agua parada nao "molha": ela ja e a agua.
	&"mat_agua": {&"molha": 0.0, &"rugosidade": 0.12},
}

## Materiais que nunca veem chuva e por isso ficam fora da tabela DE PROPOSITO.
##
## Existe para o teste `tests/checar_materiais.gd` (criterio A35) poder reprovar
## material novo que ficou de fora por esquecimento — que foi como `mat_npc` e as
## nove fachadas passaram despercebidas ate a Fase 11. Esquecer agora da erro.
const SEM_CHUVA: Array[StringName] = [
	&"mat_piso", &"mat_piso_ceramico", &"mat_espuma", &"mat_painel",
	&"mat_painel_luz", &"mat_celular_tela", &"mat_cigarro", &"mat_cigarro_brasa",
	&"mat_casa_brasa", &"mat_janela_fumaca",
	# Fachada viva: moram dentro do comodo atras da janela aberta.
	&"mat_cortina", &"mat_lampada", &"mat_interior", &"mat_interior_aceso",
	&"mat_interior_madeira",
]

## Prefixos de material que a chuva nao alcanca: e tudo que mora dentro.
##
## O `Clima` ja zera o molhado enquanto o jogador esta num interior, mas a porta
## do bar fica aberta para a rua — sem isto o piso do salao brilharia de chuva
## quando visto de fora.
## O painel do carro entra aqui pelo mesmo motivo que o piso do bar: ele
## mora DENTRO. Sem a linha, a tampa do painel e o aro do volante — as duas
## unicas superficies viradas para cima que existem numa cabine — caiam no
## padrao do shader e viravam espelho no primeiro temporal, refletindo o ceu
## encoberto de volta na cara de quem dirige. O interior ficava mais claro
## que a estrada la fora, que e o oposto do que um interior faz.
const ABRIGADOS: Array[String] = ["mat_bar_", "mat_mercado_", "mat_estufa_",
	"mat_fumaca_",
	"mat_painel"]

## Materiais que usam uma das duas variantes de superficie. Montado uma vez.
var _superficies: Array[ShaderMaterial] = []
## O nome do arquivo de cada superficie, na mesma ordem. E por ele que a janela
## acha o shader proprio.
var _nomes_material: Array[StringName] = []
## O nome de cada superficie, na mesma ordem de `_superficies`. E por ele que o
## conjunto HD do MODERNO acha as texturas de 1024 px (ver `TexturasHD`).
var _nomes_superficie: Array[StringName] = []
var _sh_vertex: Shader
var _sh_pixel: Shader
var _sh_janela: Shader
var _sh_carros: Dictionary = {}
## Folha no MODERNO (Vegetacao.MATERIAIS_FOLHA): luz atraves, recorte estavel,
## vento de tres camadas. Chave: nome do arquivo sem .tres ("mat_vegetacao").
var _sh_folha: Shader
var _folhas: Dictionary = {}

## Ultimo estado aplicado, para nao repetir trabalho a cada `changed` — o sinal
## tambem dispara quando o jogador mexe no volume, e trocar o shader de 100
## materiais por causa de um deslizador de audio custaria um engasgo visivel.
var _ultimo_pixel: bool = false
var _ultima_resolucao := Vector2i.ZERO
## Comeca em `false` porque o jogo comeca com a fonte de bitmap.
var _ultima_fonte_vetor: bool = false
## Caminho do .fnt -> propriedades da fonte de bitmap, para a volta ao PS1.
var _bitmap_guardado: Dictionary = {}
## As quatro fontes, seguradas pelo autoload.
##
## Sem esta lista o conserto some sozinho: o recurso mexido nao tinha dono, o
## cache soltava a instancia, e o proximo `load` reimportava o .fnt do disco.
## Passava pelo print e nao chegava na tela.
var _fontes: Array[FontFile] = []


func _ready() -> void:
	_sh_vertex = load(SHADER_VERTEX) as Shader
	_sh_pixel = load(SHADER_PIXEL) as Shader
	_sh_janela = load(SHADER_JANELA) as Shader
	_sh_folha = load(Vegetacao.SHADER_FOLHA) as Shader
	for m: StringName in Vegetacao.MATERIAIS_FOLHA:
		_folhas[StringName("mat_" + String(m))] = true
	for nome: StringName in CARROS:
		_sh_carros[nome] = load(CARROS[nome]) as Shader
	_mapear_superficies()
	Settings.changed.connect(_aplicar)
	_aplicar()
	# A grama instanciada do MODERNO (PLANO_FLORA_AAA, etapa 4): segue os
	# chunks pelo sinal do ChunkManager e se esconde no PS1 STYLE.
	add_child.call_deferred(GramaViva.new())


## Junta os materiais que usam psx_surface ou psx_surface_pixel.
##
## `.remap` aparece no lugar de `.tres` em build exportada com conversao para
## binario ligada; sem tirar o sufixo, a lista sai vazia no executavel e o estilo
## funcionaria no editor e nao no jogo — o pior tipo de defeito.
func _mapear_superficies() -> void:
	_superficies.clear()
	_nomes_superficie.clear()
	_nomes_material.clear()
	for arquivo: String in DirAccess.get_files_at(DIR_MATERIAIS):
		var nome := arquivo
		if nome.ends_with(".remap"):
			nome = nome.trim_suffix(".remap")
		if not nome.ends_with(".tres"):
			continue
		var mat := load(DIR_MATERIAIS + nome) as ShaderMaterial
		if mat == null or mat.shader == null:
			continue
		var caminho := mat.shader.resource_path
		if caminho == SHADER_VERTEX or caminho == SHADER_PIXEL:
			_superficies.append(mat)
			_nomes_material.append(StringName(nome.trim_suffix(".tres")))
			# O nome que importa e o da TEXTURA, e nao o do material: seis
			# materiais diferentes usam `metal.png`, e `mat_janela_apagada` e um
			# deles. Pelo nome do material, a janela ficava sem conjunto HD
			# mesmo com o conjunto de `metal` pronto em disco.
			var id := _textura_de(mat, nome)
			_nomes_superficie.append(id)
			_aplicar_molhabilidade(mat, StringName(nome.trim_suffix(".tres")))
			TexturasHD.aplicar(mat, id, Settings.luz_por_pixel)
	if _superficies.is_empty():
		push_warning("EstiloVisual: nenhum material de superficie encontrado em %s"
			% DIR_MATERIAIS)
	var com_hd := 0
	for id: StringName in _nomes_superficie:
		if TexturasHD.tem(id):
			com_hd += 1
	print("[estilo] %d superficies, %d com conjunto HD de 1024 px"
		% [_superficies.size(), com_hd])


## O nome da textura de albedo deste material, sem pasta e sem extensao.
##
## E a chave do conjunto HD: `assets/textures/metal.png` casa com
## `assets/textures_hd/metal.jpg`. Sem albedo, cai no nome do arquivo do
## material, que e o que existia antes.
func _textura_de(mat: ShaderMaterial, arquivo: String) -> StringName:
	var tex := mat.get_shader_parameter(&"albedo_tex") as Texture2D
	if tex != null and not tex.resource_path.is_empty():
		return StringName(tex.resource_path.get_file().get_basename())
	return StringName(arquivo.trim_suffix(".tres").trim_prefix("mat_"))


## Escreve como este material responde a chuva.
##
## Vale uma vez, na carga: os dois valores nao dependem do estilo nem do clima,
## so de QUE superficie e aquela. O que varia com o tempo e o `psx_molhado`
## global, e quem move aquele e o Clima.
##
## Os uniforms existem so na variante por pixel. Escrever neles com o PS1 STYLE
## ativo nao custa nada e nao muda nada: o Godot guarda o valor no material e o
## psx_surface simplesmente nao o declara.
func _aplicar_molhabilidade(mat: ShaderMaterial, nome: StringName) -> void:
	for prefixo: String in ABRIGADOS:
		if String(nome).begins_with(prefixo):
			mat.set_shader_parameter(&"molha", 0.0)
			return
	if not MOLHABILIDADE.has(nome):
		return
	var d: Dictionary = MOLHABILIDADE[nome]
	mat.set_shader_parameter(&"molha", float(d[&"molha"]))
	mat.set_shader_parameter(&"rugosidade_molhada", float(d[&"rugosidade"]))
	mat.set_shader_parameter(&"gotas", float(d.get(&"gotas", 0.0)))
	mat.set_shader_parameter(&"roupa", float(d.get(&"roupa", 0.0)))


func _aplicar() -> void:
	_aplicar_globais()
	_aplicar_resolucao()
	_aplicar_iluminacao()
	_aplicar_fontes()


## A fonte do MODERNO e a MESMA letra, resolvida na tela (PLANO_AAA_4K, A28).
##
## O problema. A interface e desenhada em 480x270 e multiplicada ate a janela, e
## o atlas da fonte e magnificado com filtro linear. Medido em
## `tests/bancada_fonte.gd`: uma haste de 1 px da `psx_pequena` em 1080p sai
## como um monte de 8 px com pico 0,87 — nenhum pixel do texto tem a cor do
## texto. Em 480x270 nada disso aparece, porque la a escala e 1; e por isso o
## defeito atravessou o projeto inteiro sem ser visto.
##
## O conserto NAO e filtro ponto. Com ponto a borda endurece e a mesma haste
## passa a sair com 2 px numa letra e 3 na seguinte quando a escala e quebrada
## (1280x720 da 2,667x) — a queixa que ja estava escrita em
## `_conferir_escala_da_ui`. O conserto e a letra ser CONTORNO e o motor
## resolver a borda na resolucao da tela (MSDF).
##
## Por que a troca acontece AQUI, e por dentro do recurso
## -------------------------------------------------------
## Vinte telas carregam a fonte pelo caminho do .fnt, e varias tem trabalho de
## outra sessao em cima. Nenhuma delas muda uma linha: o que muda e o CONTEUDO
## do recurso que todas elas ja seguram.
##
## `take_over_path` nao serve: `load()` de recurso importado passa pelo caminho
## remapeado em `.godot/imported`, e o cache e guardado por ele — poriamos a
## fonte vetorial num endereco que ninguem consulta. `copy_from` tambem nao: com
## FontFile ele erra e trava a renderizacao seguinte (medido).
##
## O que funciona e mexer nas propriedades: `data` recebe os bytes do TrueType
## importado e o recurso passa a ser uma fonte dinamica, com MSDF ligado. Como e
## a MESMA instancia, tela ja montada troca junto, e o jogador que muda de preset
## no menu ve a fonte mudar sem reiniciar.
##
## A volta ao PS1 pede a copia de seguranca: fonte de bitmap nao guarda nada em
## `data` (sao 0 bytes), o desenho dela vive nas 802 propriedades de cache do
## recurso. Elas sao copiadas ANTES do primeiro transplante e reescritas na
## volta.
##
## A metrica e identica de proposito: mesmo avanco por glifo, mesma altura de
## linha, conferido frase a frase pela bancada (A28b). Uma fonte melhor que
## andasse 1 px por palavra arrumaria o texto e desarrumaria todo painel com
## `Vector2` escrito a mao. E por isso que o `msdf_size` do gerador e multiplo do
## tamanho nativo: com 128 sobre uma em de 11 px, o avanco volta com 0,016 px a
## mais por glifo e a frase sai 1 px mais larga.
##
## O PS1 STYLE volta ao .fnt: la a escala e 1, a borda ja e dura, e texto
## suavizado seria o oposto do contrato do ART-BIBLE.
func _aplicar_fontes() -> void:
	if Settings.luz_por_pixel == _ultima_fonte_vetor:
		return
	var trocadas := 0
	for caminho: String in FONTES:
		var alvo := load(caminho) as FontFile
		if alvo == null:
			continue
		if not _bitmap_guardado.has(caminho):
			_bitmap_guardado[caminho] = _guardar(alvo)
			_fontes.append(alvo)
		if Settings.luz_por_pixel:
			var vetor := load(caminho.replace(".fnt", "_v.ttf")) as FontFile
			if vetor == null:
				continue
			var nativo := alvo.fixed_size
			alvo.data = vetor.data
			alvo.multichannel_signed_distance_field = true
			alvo.msdf_size = vetor.msdf_size
			alvo.msdf_pixel_range = vetor.msdf_pixel_range
			alvo.subpixel_positioning = vetor.subpixel_positioning
			alvo.hinting = vetor.hinting
			# O tamanho nativo continua no recurso: e dele que sai todo
			# `font_size` do projeto, por `UiEstilo.tamanho_nativo`.
			alvo.fixed_size = nativo
			trocadas += 1
		else:
			var guardado: Dictionary = _bitmap_guardado[caminho]
			for chave: String in guardado:
				alvo.set(chave, guardado[chave])
			trocadas += 1
	_ultima_fonte_vetor = Settings.luz_por_pixel
	if trocadas > 0:
		print("[estilo] fonte %s em %d arquivos"
			% ["vetorial (MSDF)" if Settings.luz_por_pixel else "de bitmap", trocadas])


## Copia de seguranca do recurso inteiro, propriedade a propriedade.
static func _guardar(fonte: FontFile) -> Dictionary:
	var d := {}
	for pi: Dictionary in fonte.get_property_list():
		if int(pi["usage"]) & PROPERTY_USAGE_STORAGE:
			d[pi["name"]] = fonte.get(pi["name"])
	return d


## Snap e UV afim. O global so sabe DESLIGAR: no shader ele entra multiplicando
## a decisao local (`use_snap && psx_snap`), para nao ligar tremor na mao em
## primeira pessoa, que tem snap desligado por motivo proprio.
func _aplicar_globais() -> void:
	RenderingServer.global_shader_parameter_set(&"psx_snap", Settings.snap)
	RenderingServer.global_shader_parameter_set(&"psx_affine", Settings.affine)
	RenderingServer.global_shader_parameter_set(&"psx_snap_escala", Settings.snap_escala())
	RenderingServer.global_shader_parameter_set(&"psx_facho_suave", Settings.luz_por_pixel)


## Resolucao interna do 3D, sem encolher a interface.
##
## Duas tentativas erradas antes desta, e as duas valem registro porque sao
## armadilhas do proprio motor:
##
##   1. So subir `content_scale_size` no modo `viewport`. O modo desenha 2D e 3D
##      no MESMO buffer, e todo painel do jogo esta posicionado em coordenadas de
##      480x270 — em 1280x720 o menu inteiro virou um quadrado no canto superior
##      esquerdo, com o resto da tela vazio.
##   2. Compensar com `content_scale_factor`. No modo `viewport` ele DIVIDE a
##      resolucao de render em vez de multiplicar o 2D: pedir 1280x720 com fator
##      2,666 devolveu uma captura de 480x270. Silencioso, e na direcao oposta.
##
## O caminho certo e trocar de MODO, nao empurrar numeros dentro do errado:
##
##   PS1 STYLE  -> `viewport`, base 480x270. 2D e 3D grossos juntos, que e
##                 exatamente o jogo de antes.
##   MODERNO    -> `canvas_items`, base 480x270. Neste modo o 3D renderiza na
##                 resolucao da JANELA e so o 2D e escalado a partir da base,
##                 entao a interface mantem o tamanho aparente e o mundo ganha
##                 todos os pixels da tela.
##
## A escada intermediaria sai de `scaling_3d_scale`, que e o knob do proprio
## Viewport para renderizar o 3D a uma fracao da janela sem tocar no 2D. E ele
## que permite 640x360 e 960x540 numa janela de 1280x720.
func _aplicar_resolucao() -> void:
	if Settings.resolucao_3d == _ultima_resolucao:
		return
	_ultima_resolucao = Settings.resolucao_3d
	var janela := get_window()
	if janela == null:
		return

	var base := Settings.RESOLUCAO_BASE
	if Settings.resolucao_3d == base:
		janela.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		janela.content_scale_size = base
		janela.scaling_3d_scale = 1.0
		return

	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	janela.content_scale_size = base
	# Altura da janela, e nao a largura: e ela que manda na proporcao quando a
	# tela do jogador nao e 16:9 e o `aspect` deixa barra nas laterais.
	var altura_janela := maxi(1, janela.size.y)
	janela.scaling_3d_scale = clampf(
		float(Settings.resolucao_3d.y) / float(altura_janela), 0.1, 1.0)
	_conferir_escala_da_ui(janela, base)


## A grade de pixel da UI so fecha com escala INTEIRA, e isto diz em voz alta
## quando ela nao fecha.
##
## A interface e desenhada em 480x270 e multiplicada ate a janela. Quando o
## multiplicador e quebrado, a mesma haste vertical sai com larguras diferentes
## na mesma palavra: medido em CONTINUAR a 1280x720, hastes de 3 e de 4 pixels
## lado a lado. A 1440x810, que e 3x exato, as oito hastes saem todas com 3.
##
## Nao da para consertar sozinho sem escolher um preco. Ampliar so em inteiro
## deixaria tarja preta em volta do 3D; mudar a caixa de projeto de 480x270 para
## 640x360 moveria todos os `Vector2` escritos a mao das telas de menu. As duas
## coisas sao decisao de quem toca a UI, e nao consequencia silenciosa de um
## ajuste de render — entao aqui so se MEDE e se avisa.
##
## Vale registrar o lado bom: 1920x1080 da 4,0 exatos e 3840x2160 da 8,0. Em tela
## cheia na resolucao mais comum do mundo, a UI ja e perfeita. Quem paga o preco
## e a janela de 1280x720, que e 2,667.
func _conferir_escala_da_ui(janela: Window, base: Vector2i) -> void:
	# Headless roda numa janela de 64x64 que nao desenha UI nenhuma. Medir a
	# escala dela e comparar com uma tela que nao existe, e o aviso resultante so
	# sujaria a saida da bateria de testes.
	if janela.size.y < base.y:
		return
	var escala := float(janela.size.y) / float(base.y)
	var inteira := absf(escala - roundf(escala)) < 0.001
	if inteira:
		print("[estilo] UI em %.0fx exato (%dx%d)" % [escala, janela.size.x, janela.size.y])
		return
	# Aviso e nao erro: o jogo funciona, so nao fica com a grade fechada. Quem
	# roda captura em 1280x720 nao pode ser bloqueado por isso.
	print("[estilo] UI em %.3fx (janela %dx%d sobre base %dx%d): escala quebrada, "
		% [escala, janela.size.x, janela.size.y, base.x, base.y]
		+ "a fonte de bitmap sai com hastes de larguras diferentes. "
		+ "Inteiro mais proximo: %dx%d." % [base.x * int(roundf(escala)), base.y * int(roundf(escala))])


## Troca o shader de todo material de superficie de uma vez.
##
## Os dois arquivos declaram os MESMOS nomes de uniform de proposito: o Godot
## reaproveita por nome o que ja estava setado, entao os 106 materiais atravessam
## a troca sem reconfigurar nenhum. Um nome que divergisse faria aquele material
## perder o valor e voltar ao padrao justamente na hora de trocar de estilo.
func _aplicar_iluminacao() -> void:
	if Settings.luz_por_pixel == _ultimo_pixel:
		return
	_ultimo_pixel = Settings.luz_por_pixel
	var alvo := _sh_pixel if Settings.luz_por_pixel else _sh_vertex
	if alvo == null:
		return
	for i in _superficies.size():
		var mat := _superficies[i]
		var nome := _nomes_material[i]
		var janela := Settings.luz_por_pixel and JANELAS.has(nome)
		var carro := Settings.luz_por_pixel and _sh_carros.has(nome)
		var quero: Shader = _sh_janela if janela else alvo
		if Settings.luz_por_pixel and _sh_folha != null and _folhas.has(nome):
			quero = _sh_folha
			# O cartao de perfil some so na copa: no `mato` e no `flor` ha chao e
			# vitoria-regia deitados, vistos sempre de raspao, e a cerca viva de
			# caixa tem lado de perfil que nao pode abrir buraco.
			mat.set_shader_parameter(&"fade_perfil", 1.0 if nome == &"mat_vegetacao" else 0.0)
		if carro:
			quero = _sh_carros[nome]
		if quero != null and mat.shader != quero:
			mat.shader = quero
		if carro:
			# O atlas do carro nao tem conjunto HD; quem da o acabamento e a
			# classe de material por vertice.
			continue
		if janela:
			# Vidro nao usa conjunto HD: o que ele mostra e o comodo atras e o
			# reflexo do ceu, e nao uma foto de superficie.
			mat.set_shader_parameter(&"acesa", bool(JANELAS[nome]))
			continue
		# O conjunto de texturas acompanha o estilo: 1024 px com relevo no
		# MODERNO, 256 px com filtro ponto no PS1 STYLE.
		TexturasHD.aplicar(mat, _nomes_superficie[i], Settings.luz_por_pixel)

