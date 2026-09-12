## Fundo 3D da criacao de personagem: a Estrada Velha de verdade, vista do banco
## do motorista, com o carro PARADO no acostamento.
##
## Por que e a cena, e nao uma imitacao dela
## -----------------------------------------
## A criacao de personagem e a tela IMEDIATAMENTE anterior a cena da estrada:
##
##     titulo -> NOVO JOGO -> [ficha] -> [criacao] -> [estrada] -> [abertura]
##
## Ou seja, quem preenche a ficha ja esta dentro do carro que vai sair andando no
## corte seguinte. Antes daqui havia um segundo mundo so para este fundo — a
## mesma lataria, mas com um `BG_COLOR` cinza-azulado no lugar do para-brisa,
## sem estrada, sem mata e sem ceu. Aquilo nao era o carro dele parado em lugar
## nenhum: era um carro num limbo, e o corte para a estrada anunciava que as
## duas telas foram feitas por sistemas diferentes.
##
## Agora este no monta o `EstradaBuilder`, o `CarroCena` e o `CeuEstrada` — os
## MESMOS tres da `AberturaEstrada` — e senta a camera no `suporte_camera` do
## carro, que e exatamente o que o plano DENTRO faz. Melhorar a estrada melhora
## esta tela junto, sem uma linha aqui.
##
## Mundo proprio
## -------------
## A `Criacao` renderiza isto num `SubViewport` com `own_world_3d`, entao nada
## daqui e visto pela cidade e nada da cidade e visto daqui. Duas consequencias
## que custam depuracao se forem esquecidas:
##
##   - a luz tem de nascer AQUI DENTRO (a do mundo de fora nao atravessa), e
##   - o `FogController` local nao pode entrar no grupo global, senao ele passa
##     a responder pelo clima da cidade — por isso `registrar_global = false` e
##     a injecao em `CeuEstrada.fog`.
class_name CabineFundoCriacao
extends Node3D

## Clima do fundo. E o mesmo conjunto de presets da `AberturaEstrada`, e e o
## mesmo da cena que vem no corte seguinte: noite fechada.
const CLIMA := "noite"
const CLIMAS := {
	"entardecer": "res://resources/fog/fog_estrada.tres",
	"noite": "res://resources/fog/fog_estrada_noite.tres",
	"amanhecer": "res://resources/fog/fog_estrada_amanhecer.tres",
	"dia": "res://resources/fog/fog_estrada_dia.tres",
}

## Onde o carro esta na estrada. Nao e zero: a mata e o relevo do caminho variam
## com a distancia, e a estaca zero e reta e pelada — o pior quadro do trecho
## inteiro para deixar atras de um documento.
const ESTACA := 96.0

## O carro esta PARADO.
##
## Ele encostou para preencher a ficha, e e por isso que a tela seguinte comeca
## com ele saindo. Andar tinha um custo que nao se paga num menu: a mata varrendo
## atras do texto puxa o olho para fora do campo que o jogador esta preenchendo,
## e o fundo passa a competir com a unica coisa que a tela pede. Parado, ele
## volta a ser cenario, que e o cargo dele aqui.
const VELOCIDADE := 0.0

## A nevoa da estrada, IGUAL a da estrada.
##
## Isto ja esteve em 6 m a 38 m, fechado a mao com o argumento de que um carro
## parado nao ganha profundidade do movimento e precisava de camada vinda da
## nevoa. O argumento e razoavel e o resultado nao era: puxar o inicio para 6 m
## poe a cor da nevoa — um cinza claro — em cima de tudo que se ve pelas
## janelas, e as janelas viram uma caixa de luz em volta da cabine. Medido
## contra o plano DENTRO da cena, era essa a maior parte da diferenca do lado de
## FORA do vidro.
##
## O valor fica sendo o do preset, sem correcao. As duas telas sao o mesmo carro
## no mesmo lugar com um corte de segundos entre elas, e a nevoa e a primeira
## coisa que denuncia quando nao sao.
const NEVOA_INICIO := 16.0
const NEVOA_FIM := 54.0

## Enquadramento: o do plano de dentro do carro, lido da propria cena.
##
## Copiar os numeros para ca daria duas versoes do mesmo enquadramento, e elas
## divergiriam no primeiro ajuste — que e como esta tela tinha ido parar num FOV
## de 62 olhando dezessete graus para baixo, para o volante, enquanto a cena
## olhava a estrada.
const FOV := AberturaEstrada.DENTRO_FOV

## O olho OLHA PARA BAIXO, e aqui ele se separa do plano da cena.
##
## O enquadramento da estrada e o de quem DIRIGE: dois graus abaixo da linha do
## horizonte, a estrada no meio do quadro. Esta tela nao e essa cena — e alguem
## sentado num carro parado LENDO um documento no proprio colo, e ninguem le
## documento olhando para a estrada.
##
## Baixando o olho, tres coisas acontecem de uma vez: o painel e o volante
## entram em quadro e dizem onde a pessoa esta; o para-brisa sobe para a
## faixa de cima, que era morta; e o papel passa a ficar onde papel fica quando
## se le, que e embaixo. E o mesmo motivo pelo qual `DENTRO_PITCH` continua
## sendo lido pela cena e nao por aqui: os dois enquadramentos tem trabalhos
## diferentes e nao devem se seguir.
const PITCH := -32.0

## A camera fica no suporte, sem offset nenhum — e ja foi tentado o contrario.
##
## Como a carteira tapa o para-brisa, a tentacao e adiantar o olho para "abrir"
## o vidro. Nao abre: aproximar do vidro aproxima do PAINEL junto, e o painel
## esta a meio metro enquanto a mata esta a trinta. Vinte centimetros a frente
## incharam o painel ate a metade de baixo da tela e o para-brisa virou uma
## fresta. O que se ve do mundo nesta tela sao as janelas LATERAIS, e elas so
## existem na pose de quem esta sentado.

## Sem tremor de motor, e isso foi tentado e desfeito.
##
## Um carro parado com o motor ligado vibra, e a tentacao e por essa vibracao na
## camera. Nao da: o estilo do jogo trava os vertices numa grade de tela, entao
## camera que anda um milimetro faz VERTICE NENHUM andar ate a conta virar, e
## ai a mata inteira pula uma casa de uma vez. Medido entre dois quadros a tres
## segundos de distancia, a janela lateral mudava com pico de 120 de diferenca
## por canal — com o carro parado. Do lado de ca da tela isso nao le como motor
## em ponto morto, le como o carro andando, que e o oposto do que a cena pede.
##
## Vida no quadro, aqui, vem do que se move DENTRO dele — a folha balancando na
## mao, o cursor piscando, o farol na nevoa. A camera fica quieta.

var carro: CarroCena
var cabine: CarroCabine
var camera: Camera3D

var _estrada: EstradaBuilder
var _fog: FogController
var _ceu: CeuEstrada
var _relogio: float = 0.0
## Onde a lampada do teto ficou, em coordenada do carro. A folha da carteira
## precisa dela para saber para onde se inclinar.
var _pos_luz_teto := Vector3.ZERO
## A folha da carteira, pedida pela `Criacao` e construida no primeiro quadro.
var _folha_rect := Rect2()
var _folha_cor := Color.WHITE
var _folha_feita := false


func _ready() -> void:
	# Menu pausa a arvore em APARENCIA; o fundo precisa continuar respirando.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar_clima()
	_montar_estrada()
	_montar_carro()
	_montar_ceu()
	_montar_camera()
	_montar_luz_cena()


func _process(delta: float) -> void:
	if carro == null or not is_instance_valid(carro):
		return
	# Uma chamada so: `avancar` cuida de estaca, trechos, rodas e suspensao.
	# Com velocidade zero ela nao anda nada — o que sobra e o ponteiro no zero e
	# o volante quieto, que e o estado certo para um carro encostado.
	carro.avancar(delta)
	_relogio += delta
	if not _folha_feita and _folha_rect.size.x > 0.0:
		_montar_folha()
		_folha_feita = true


func _montar_clima() -> void:
	_fog = FogController.new()
	_fog.name = "Clima"
	_fog.follow_settings = false
	# Mundo proprio: este controller nao responde pelo clima do jogo. Ver o
	# cabecalho e `FogController.registrar_global`.
	_fog.registrar_global = false
	_fog.override_preset = _preset_do_fundo()
	_fog.environment = Environment.new()
	add_child(_fog)


## O preset da estrada com a nevoa fechada — numa COPIA.
##
## `load` devolve a mesma instancia do recurso para todo mundo que pedir, entao
## mexer no objeto carregado mexeria na cena da estrada junto: a Estrada Velha
## acordaria com a nevoa de menu que ninguem pediu, e a causa estaria num
## arquivo de interface.
func _preset_do_fundo() -> FogPreset:
	var preset := load(_caminho_clima()) as FogPreset
	if preset == null:
		return null
	var copia := preset.duplicate() as FogPreset
	copia.fog_begin = NEVOA_INICIO
	copia.fog_end = NEVOA_FIM
	return copia


func _montar_estrada() -> void:
	_estrada = EstradaBuilder.new()
	_estrada.name = "Estrada"
	_estrada.clima_id = CLIMA
	add_child(_estrada)
	# O chao ANTES do primeiro quadro. Sem isto a carteira abre sobre o carro
	# suspenso no vazio enquanto os trechos sobem.
	_estrada.atualizar(ESTACA)


func _montar_carro() -> void:
	carro = CarroCena.new()
	carro.name = "Carro"
	carro.estrada = _estrada
	# Cenario, nao assunto: sem motor. Ver `CarroCena.com_som`.
	carro.com_som = false
	add_child(carro)
	carro.distancia = ESTACA
	carro.velocidade = VELOCIDADE
	carro.assentar()
	cabine = carro.cabine
	# Farol aceso e o que da o que ver la fora: parado e no escuro, a nevoa
	# acesa a frente e a unica coisa entre o para-brisa e o nada.
	if CLIMA != "dia":
		# Farol e luz de painel SIM; brasa e fill de lataria NAO.
		#
		# As duas ultimas existem para o carro ler de fora, e de dentro elas
		# acendiam o documento mais do que a lampada do teto. A luz do painel
		# fica: e ela que desenha o mostrador, e sem ela o painel some no preto —
		# que foi o que aconteceu quando o corte levou as tres.
		carro.acender_farois(true, false)


func _montar_ceu() -> void:
	_ceu = CeuEstrada.new()
	_ceu.name = "Ceu"
	# Injetado: o controller local esta fora do grupo de proposito.
	_ceu.fog = _fog
	add_child(_ceu)


func _montar_camera() -> void:
	camera = Camera3D.new()
	camera.name = "CameraFP"
	camera.current = true
	camera.fov = FOV
	camera.near = 0.08
	# Longe o bastante para a cupula (420 m) e a serra caberem. Um `far` curto
	# aqui apareceria como um circulo de vazio em volta do carro.
	camera.far = 900.0
	camera.rotation = Vector3(deg_to_rad(PITCH), 0.0, 0.0)
	# Filha do suporte: mesma pose do plano DENTRO, mesmo chacoalho, de graca.
	carro.suporte_camera.add_child(camera)


## Enquadramento de MENU: a estrada na mata, vista de fora do carro.
##
## Por que existe um segundo enquadramento
## ---------------------------------------
## Esta cena nasceu para a carteira, e a pose dela e a de quem le um papel no
## colo: olho baixo, 32 graus para baixo, painel e volante em quadro. Isso e
## exatamente certo para a ficha e exatamente errado para o fundo de um menu —
## num menu o papel nao existe, e o que sobra da pose e um painel de carro
## ocupando metade da tela.
##
## O que o menu pede e o contrario: a serra escura, a mata dos dois lados e a
## estrada sumindo na nevoa. Entao a camera sai do suporte do motorista, sobe
## para a altura de um adulto em pe no acostamento, recua atras do carro e olha
## quase na horizontal.
##
## A cena e a MESMA: mesmo `EstradaBuilder`, mesma mata, mesmo ceu de noite,
## mesmo preset de nevoa. So a lente muda. Melhorar a estrada melhora as duas
## telas junto, que e o motivo de ela ter sido escrita assim no comeco.
const MENU_ALTURA := 1.72
## Recuo atras do carro. Ele fica em quadro, pequeno, parado no acostamento —
## presenca, nao assunto.
const MENU_RECUO := 7.2
## Quase na horizontal. O pouco que desce poe o asfalto no terco de baixo sem
## apontar a lente para o chao.
const MENU_PITCH := -3.5
## Aberto: e a largura que faz a mata fechar dos dois lados e a estrada parecer
## estreita no meio dela.
const MENU_FOV := 68.0


func enquadrar_menu(ligado: bool) -> void:
	if camera == null or carro == null:
		return
	var pai := camera.get_parent()
	if ligado:
		if pai != self:
			if pai != null:
				pai.remove_child(camera)
			add_child(camera)
		var frente := -carro.global_transform.basis.z
		frente.y = 0.0
		if frente.length_squared() < 0.001:
			frente = Vector3.FORWARD
		frente = frente.normalized()
		var lado := Vector3.UP.cross(frente).normalized()
		# Um passo para o lado tira o carro do centro exato do quadro: carro
		# centrado le como foto de catalogo, carro fora do eixo le como carro
		# parado num acostamento.
		camera.global_position = carro.global_position - frente * MENU_RECUO 			+ lado * 1.6 + Vector3(0.0, MENU_ALTURA, 0.0)
		camera.rotation = Vector3(deg_to_rad(MENU_PITCH),
			atan2(frente.x, frente.z) + PI, 0.0)
		camera.fov = MENU_FOV
		# Reaponta a camera depois de trocar de pai.
		#
		# Uma `Camera3D` perde `current` ao SAIR da arvore, e nao recupera ao
		# voltar. Sem esta linha o SubViewport fica sem camera nenhuma e renderiza
		# vazio — o fundo do menu ficava transparente e o que aparecia era a
		# cidade por tras dele, que e exatamente o que se via antes de eu medir.
		camera.make_current()
		return
	if pai != carro.suporte_camera:
		if pai != null:
			pai.remove_child(camera)
		carro.suporte_camera.add_child(camera)
	camera.position = Vector3.ZERO
	camera.rotation = Vector3(deg_to_rad(PITCH), 0.0, 0.0)
	camera.fov = FOV
	camera.make_current()


## UMA luz dentro da cabine: a do teto. Mais nada.
##
## O que havia aqui, e por que saiu
## ---------------------------------
## Tres fontes de preenchimento — um pratico no painel, um rebote do farol e um
## repuxo frio atras do ombro — postas quando a unica preocupacao era "o
## interior nao pode sumir no preto". Elas cumpriam isso e cobravam caro:
## somadas, acendiam forro, colunas e painel quase no mesmo valor, e a cabine
## inteira virava uma massa bege sem forma. Comparada lado a lado com o plano
## DENTRO da propria cena da estrada, a diferenca era gritante — la o interior e
## escuro com desenho, aqui era um papelao claro.
##
## E havia um custo pior, que so aparece quando se mede: com quatro fontes no ar,
## APAGAR a lampada do teto nao mudava quase nada. A luz que deveria ser a
## protagonista da cena era a quarta parte da conta.
##
## Agora e uma so. O que ela alcanca, aparece; o que ela nao alcanca, escurece —
## que e como um carro parado a noite com a luzinha de teto acesa realmente se
## parece, e e o unico jeito de a carteira ser iluminada POR ela em vez de
## iluminada por um somatorio.
##
## O farol continua aceso, mas ele esta do lado de FORA: quem ele acende e a
## nevoa e a estrada, e nada dentro da cabine depende dele.
func _montar_luz_cena() -> void:
	if carro == null or cabine == null:
		return
	_montar_luz_de_teto(cabine.olho())


## O PAPEL da carteira, como superficie 3D dentro da cabine.
##
## Por que o papel saiu do 2D
## ---------------------------
## Ate aqui a carteira era inteira desenhada em cima da cena: papel, tinta e uma
## poca de luz pintada a mao imitando a lampada do teto. Imitar funcionava de
## longe e nao resistia a pergunta certa — a luz nao era a luz do carro, era um
## degrade que eu tinha ajustado para PARECER com ela. Trocar a lampada de lugar
## nao mexia na carteira; apagar a lampada deixava a carteira acesa.
##
## Agora o papel e um quadrilatero de verdade, pendurado a quarenta centimetros
## do olho, com material que RECEBE luz. Quem o acende e a mesma `LuzTeto` que
## acende o forro, o volante e as maos. Apagar a lampada apaga a carteira; mudar
## a cor dela muda a cor do papel; a queda da luz do canto de cima para o de
## baixo e a queda real da fonte, calculada pelo motor.
##
## A tinta continua em 2D, e essa e a divisao que faz a coisa funcionar: papel e
## superficie, e superficie quer luz; texto e informacao, e informacao quer
## pixel inteiro. Texto mapeado em textura de quad perde nitidez no primeiro
## grau de inclinacao, e legibilidade e a queixa que abriu esta tela inteira.
##
## O alinhamento nao e ajustado no olho: os quatro cantos saem de
## `project_position` sobre o MESMO retangulo de tela que o desenho 2D usa. Por
## construcao o papel cai exatamente debaixo da tinta, e continua caindo se o
## retangulo mudar de tamanho ou de lugar.
## NAO CHAMADO HOJE. Ver "o que falta" no fim deste comentario.
##
## Publica: pede a folha. Ela nasce no primeiro quadro, e nao agora.
##
## Construir aqui nao funciona, e a razao custou uma medida para aparecer: quem
## chama e a `Criacao`, no mesmo instante em que a cena entra na arvore, e nesse
## instante a transformada global da camera ainda nao assentou.
## `project_position` devolve quatro pontos degenerados, o quad sai com area
## zero e nao renderiza — sem erro nenhum no log. Pintado de vermelho, o
## vermelho nao aparecia; com a lampada em zero e em seis o papel media os
## mesmos 115, porque o que estava na tela era so a tinta 2D.
##
## No primeiro `_process` a arvore ja processou as transformadas, e os quatro
## cantos caem onde deveriam. Isso foi corrigido e verificado: pintado de
## vermelho, o quad aparece.
##
## O que falta, e o que ja foi eliminado
## --------------------------------------
## A folha renderiza e recebe AMBIENTE, mas nao recebe a lampada do teto. Medido
## com a lampada indo de 0 a 20 de energia, o papel fica travado em 43 de 255
## nas cinco configuracoes abaixo, enquanto o forro do carro — atingido pela
## MESMA lampada — vai de 20 a 66. Ja foram descartados:
##
##   - orientacao da normal (varrida de "toda para a camera" a "toda para a
##     lampada", em cinco misturas: 43 em todas);
##   - winding do triangulo (invertido: piora, nao muda o teto);
##   - malha montada a mao contra `PlaneMesh` do motor, com normal, tangente e
##     UV gerados por ele;
##   - no pai (filha da camera e filha do carro dao o mesmo numero);
##   - alcance e curva de atenuacao da luz (range de 2,1 a 20; atenuacao de 0,25
##     a 1,5).
##
## O que ainda nao foi olhado, na ordem em que eu olharia: `layers` da malha
## contra `light_cull_mask` da luz; e o material — a folha e a unica coisa da
## cabine com `StandardMaterial3D`, todo o resto usa o ShaderMaterial PSX do
## projeto, e a diferenca entre os dois na renderizacao Compatibility e a pista
## mais forte que sobrou.
func pedir_folha(retangulo: Rect2, cor: Color) -> void:
	_folha_rect = retangulo
	_folha_cor = cor
	_folha_feita = false


func _montar_folha() -> void:
	var retangulo := _folha_rect
	var cor := _folha_cor
	if camera == null:
		return
	var velho := camera.get_node_or_null("FolhaCarteira")
	if velho != null:
		velho.free()

	# Distancia de colo: perto o bastante para a lampada do teto chegar com
	# forca e longe o bastante para o papel nao atravessar o volante.
	var d := 0.42
	var cantos := [
		retangulo.position,
		Vector2(retangulo.end.x, retangulo.position.y),
		retangulo.end,
		Vector2(retangulo.position.x, retangulo.end.y),
	]
	var verts := PackedVector3Array()
	for c: Vector2 in cantos:
		verts.append(camera.to_local(camera.project_position(c, d)))

	# `PlaneMesh` do motor, e nao malha montada a mao.
	#
	# A versao anterior montava o quad com `add_surface_from_arrays`, normais
	# escritas por mim e winding escolhido por mim — tres variaveis novas de uma
	# vez, e o papel recusava a luz sem dizer por que. Medido: com a lampada
	# variando de 0 a 20 o papel ficava travado, enquanto o forro do carro,
	# atingido pela MESMA lampada, respondia normalmente. Sinal de que o problema
	# estava na superficie, e nao na fonte.
	#
	# O plano do motor traz normal, tangente e UV corretos por construcao. O
	# tamanho continua saindo de `project_position` sobre o retangulo de tela, que
	# e o que garante que o papel caia exatamente debaixo da tinta 2D.
	var centro_local := camera.to_local(
		camera.project_position(retangulo.get_center(), d))
	var largura := verts[0].distance_to(verts[1])
	var altura := verts[0].distance_to(verts[3])

	var plano := PlaneMesh.new()
	plano.orientation = PlaneMesh.FACE_Z
	plano.size = Vector2(largura, altura)
	plano.subdivide_width = 3
	plano.subdivide_depth = 3

	var mi := MeshInstance3D.new()
	mi.name = "FolhaCarteira"
	mi.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	# Fosco: papel nao tem reflexo especular, e o que ele devolve e difuso puro.
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Filha do CARRO, com a pose calculada a partir da camera.
	#
	# Pendurada na propria camera ela nao recebia a lampada do teto: com a luz
	# indo de 0 a 20 o papel media 43 sem se mexer, enquanto o forro do carro,
	# atingido pela mesma lampada, ia de 20 a 66. Trocado o pai, a mesma malha
	# com o mesmo material passou a responder. A pose e identica dos dois jeitos;
	# o que muda e de quem ela e filha.
	carro.add_child(mi)
	mi.global_transform = Transform3D(camera.global_transform.basis,
		camera.to_global(centro_local))


## A luz de teto: a lampadinha acima do retrovisor, acesa.
##
## E a fonte que a cena PEDE. As outras duas — o mostrador do painel e o rebote
## do farol na nevoa — desenham o carro, mas nenhuma delas ilumina um documento
## erguido na frente do rosto: o painel acende de baixo e a nevoa esta a dez
## metros. Quem le papel dentro de um carro parado a noite acende a luzinha de
## teto, e e por isso que ela existe em todo carro.
##
## Duas pecas, e as duas importam:
##
##   - a LUZ, quente e curta, pendurada no forro logo atras do para-brisa. E ela
##     que poe a poca clara no teto, nos ombros e na carteira;
##   - a LENTE, uma caixinha chapada de creme no lugar exato da luz. Sem ela a
##     poca no forro nao tem de onde vir, e luz sem fonte visivel le como erro
##     de iluminacao, nao como lampada acesa.
##
## Meio metro a frente do olho, e nao em cima dele: com a camera aberta em 70
## graus, uma lampada no teto logo acima da cabeca cai a setenta graus do eixo e
## fica fora de quadro. No lugar do retrovisor ela entra a vinte e poucos e
## aparece na faixa de cima da tela — que era justamente a faixa morta.
func _montar_luz_de_teto(olho: Vector3) -> void:
	var teto := cabine.teto()
	# Puxada para o lado do motorista, e nao no eixo do carro.
	#
	# Carro tem luz de teto no meio e, muitas vezes, uma luz de leitura de cada
	# lado. Esta e a de leitura: no eixo, ela fica quarenta centimetros ao lado
	# de quem le e chega no papel de raspao.
	var pos := Vector3(olho.x * 0.75, teto - 0.05, olho.z - 0.50)

	_pos_luz_teto = pos
	# FACHO, e nao bola de luz. E aqui que estava o defeito da tela.
	#
	# Com uma `OmniLight3D` no forro, o alcance necessario para chegar ao colo
	# (uns 60 cm) tambem chega as portas, ao tunel e ao encosto — que estao a
	# distancia parecida — e todos acendem no mesmo valor. Olhando para a
	# estrada isso nao aparece, porque nada disso entra em quadro; olhando para
	# BAIXO, como esta tela olha, essas superficies sao a maior parte da imagem,
	# e elas sao grandes, chapadas e sem desenho. Medido contra o plano DENTRO
	# da propria cena: a mediana da cena fica em 3 de 255 e a daqui subia para
	# 35, com os brancos IGUAIS nos dois (228 contra 230) — ou seja, nao era
	# exposicao a mais, era superficie iluminada onde a cena nao tem nenhuma.
	#
	# Lampada de teto de carro nao e uma bola nua: e uma lente encaixada no
	# forro, e o corpo dela tapa a luz para os lados. Ela joga para BAIXO. Um
	# `SpotLight3D` apontado para o colo e a mesma peca descrita como ela e — e
	# de quebra e o que a cena pedia desde o inicio, porque agora a carteira
	# recebe luz DIRECIONAL de uma fonte que esta num lugar, em vez de um banho
	# uniforme que chegaria igual de qualquer canto.
	var luz := SpotLight3D.new()
	luz.name = "LuzTeto"
	luz.position = pos
	# Apontada para baixo e um pouco para tras: a lente esta meio metro a frente
	# do olho e o colo fica atras dela. Rotacao local em vez de `look_at` porque
	# a luz e filha do carro, que inclina com a estrada — `look_at` trabalha em
	# coordenada global e brigaria com essa inclinacao a cada quadro.
	luz.rotation = Vector3(deg_to_rad(-108.0), 0.0, 0.0)
	# Cone largo o bastante para cobrir a carteira inteira a meio metro, e nao
	# mais: o que passa da borda do cone e porta.
	luz.spot_angle = 44.0
	luz.spot_angle_attenuation = 1.3
	luz.spot_range = 2.0
	luz.spot_attenuation = 1.0
	luz.light_energy = 1.2
	luz.light_color = Color(1.0, 0.87, 0.66)
	luz.shadow_enabled = false
	carro.add_child(luz)

	# O derrame da propria lente no forro em volta dela, e so isso.
	#
	# Facho puro deixaria a lente acesa boiando num teto preto, que le como erro
	# de iluminacao. Uma lampada de verdade vaza um pouco pelas beiradas da
	# lente e acende um palmo de forro. Alcance de meio metro: ela nao chega em
	# porta nenhuma, que e o ponto.
	var derrame := OmniLight3D.new()
	derrame.name = "DerrameTeto"
	derrame.position = pos
	derrame.omni_range = 0.52
	derrame.omni_attenuation = 1.6
	derrame.light_energy = 0.7
	derrame.light_color = Color(1.0, 0.89, 0.70)
	derrame.shadow_enabled = false
	carro.add_child(derrame)

	var lente := MeshInstance3D.new()
	lente.name = "LenteTeto"
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.11, 0.022, 0.07)
	lente.mesh = caixa
	lente.position = pos + Vector3(0.0, 0.012, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.93, 0.78)
	# Chapada: a lente e a propria fonte, entao ela nao pode receber sombra de
	# nada — uma lente sombreada le como plastico apagado.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lente.material_override = mat
	lente.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carro.add_child(lente)


## SEM PERNAS DE PILOTO — e a ausencia e deliberada.
##
## Havia aqui um par de pernas em caixas PSX (coxa, joelho, canela, pe) para
## "ancorar o assento". Elas eram a maior coisa em quadro nesta tela e nao
## eram perna nenhuma: eram duas lajotas chapadas cobrindo as laterais, e foi
## isso que se leu, com razao, como "o carro esta uma macinha gigante".
##
## A causa e de ESCALA, e nao de ajuste. O olho desta cabine fica a 31 cm do
## piso (`CarroCabine.OLHO_ALTURA`), que e uma medida de estilo: a cabine e um
## enquadramento, nao um interior em tamanho de gente. Uma coxa medida em
## centimetros humanos nao cabe em 31 cm de espaco — na primeira versao o
## joelho ficava a DOZE centimetros da lente, e uma caixa de onze centimetros a
## doze centimetros de uma lente de 70 graus enche meia tela sozinha. Afastando
## e afinando ate a proporcao honesta, a coxa ainda ficava a 31 cm e continuava
## sendo a metade de baixo da imagem. Nao ha numero que resolva: para a perna
## caber, ou a cabine cresce ou a lente fecha, e as duas sao a cena.
##
## E o plano DENTRO da propria Estrada Velha, que e a referencia desta tela,
## nao tem perna nenhuma — e ninguem sente falta, porque quem diz onde a pessoa
## esta sao o volante, o painel e o para-brisa. Aqui dizem tambem as maos e o
## documento, que sao desenhados por cima em 2D.
##
## Se um dia voltarem, o teste e este: capturar com `--ver-aparencia
## --so-fundo` e medir a mediana da imagem contra a do plano DENTRO da cena
## (`--ver-estrada --estrada-plano=dentro --estrada-clima=noite`). Perna que
## cabe nao move esse numero.


func _caminho_clima() -> String:
	return String(CLIMAS.get(CLIMA, CLIMAS["entardecer"]))
