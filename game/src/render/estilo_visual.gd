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
	&"mat_meio_fio": {&"molha": 1.0, &"rugosidade": 0.26},
	&"mat_pedra_parque": {&"molha": 1.0, &"rugosidade": 0.12},
	&"mat_concreto": {&"molha": 1.0, &"rugosidade": 0.14},
	&"mat_concreto_sujo": {&"molha": 1.0, &"rugosidade": 0.16},
}

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
	"mat_painel"]

## Materiais que usam uma das duas variantes de superficie. Montado uma vez.
var _superficies: Array[ShaderMaterial] = []
## O nome de cada superficie, na mesma ordem de `_superficies`. E por ele que o
## conjunto HD do MODERNO acha as texturas de 1024 px (ver `TexturasHD`).
var _nomes_superficie: Array[StringName] = []
var _sh_vertex: Shader
var _sh_pixel: Shader

## Ultimo estado aplicado, para nao repetir trabalho a cada `changed` — o sinal
## tambem dispara quando o jogador mexe no volume, e trocar o shader de 100
## materiais por causa de um deslizador de audio custaria um engasgo visivel.
var _ultimo_pixel: bool = false
var _ultima_resolucao := Vector2i.ZERO


func _ready() -> void:
	_sh_vertex = load(SHADER_VERTEX) as Shader
	_sh_pixel = load(SHADER_PIXEL) as Shader
	_mapear_superficies()
	Settings.changed.connect(_aplicar)
	_aplicar()


## Junta os materiais que usam psx_surface ou psx_surface_pixel.
##
## `.remap` aparece no lugar de `.tres` em build exportada com conversao para
## binario ligada; sem tirar o sufixo, a lista sai vazia no executavel e o estilo
## funcionaria no editor e nao no jogo — o pior tipo de defeito.
func _mapear_superficies() -> void:
	_superficies.clear()
	_nomes_superficie.clear()
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
		if mat.shader != alvo:
			mat.shader = alvo
		# O conjunto de texturas acompanha o estilo: 1024 px com relevo no
		# MODERNO, 256 px com filtro ponto no PS1 STYLE.
		TexturasHD.aplicar(mat, _nomes_superficie[i], Settings.luz_por_pixel)

