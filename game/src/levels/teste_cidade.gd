## Rotina de verificacao da malha urbana, do gerador de parque e do mapa.
##
## Roda dentro do jogo porque metade do que ela afirma so existe rodando: o mapa e
## um Control que desenha, os icones sao recursos importados, e o parque nasce da
## mesma funcao que a thread do chunk chama.
##
## O teste que mais importa aqui e o de ordem. Um parque de ate 25 chunks e
## montado por 25 threads que nunca se falam, e cada uma percorre o parque inteiro
## desenhando so a parte dela. Se algum sorteio sair de um fluxo compartilhado, a
## sequencia anda diferente em cada chunk e a mesma arvore nasce de dois tamanhos
## conforme quem a desenha. Montar a quadra na ordem direta e na inversa e compa-
## rar chunk a chunk e o unico jeito de pegar isso — e ja pegou uma vez.
##
## Imprime linhas `[cidade] chave=valor` que tools/verificar_cidade.py confere.
class_name TesteCidade
extends RefCounted

## Alcance da varredura, em chunks a partir da origem. 11 x 11 pega varios
## distritos e umas quinze quadras sem custar os segundos de uma varredura maior.
const ALCANCE := 5

const ICONES: Array[String] = [
	"mercado", "casa", "predio", "parque", "telefone", "porta", "jogador", "norte",
]


static func executar(cena: Node, jogador: Node3D) -> void:
	var arvore := cena.get_tree()
	await arvore.create_timer(1.0).timeout

	_relatar("inicio", 1)
	_medir_malha()
	_medir_variacao()
	_medir_parques()
	_medir_pontos()
	_medir_mapa(cena, jogador)
	_medir_orcamento()

	_relatar("fim", 1)
	AudioDirector.silenciar_tudo()
	await arvore.process_frame
	arvore.quit(0)


static func _relatar(chave: String, valor: Variant) -> void:
	print("[cidade] %s=%s" % [chave, valor])


# --- malha ------------------------------------------------------------------

## As ruas correm nos dois eixos, com largura variada, e nenhum eixo e uma grade
## regular.
static func _medir_malha() -> void:
	# Contado por TRECHO de chunk: so a avenida e linha inteira, rua e viela
	# existem por trecho (MalhaUrbana.via_x_em).
	var por_classe := {0: 0, 1: 0, 2: 0, 3: 0}
	var por_classe_z := {0: 0, 1: 0, 2: 0, 3: 0}
	for i in range(-20, 21):
		for j in range(-20, 21):
			por_classe[int(MalhaUrbana.via_x_em(i, j))] += 1
			por_classe_z[int(MalhaUrbana.via_z_em(j, i))] += 1

	_relatar("avenidas_x", por_classe[MalhaUrbana.Via.AVENIDA])
	_relatar("avenidas_z", por_classe_z[MalhaUrbana.Via.AVENIDA])
	_relatar("ruas_x", por_classe[MalhaUrbana.Via.RUA])
	_relatar("ruas_z", por_classe_z[MalhaUrbana.Via.RUA])
	_relatar("vielas", por_classe[MalhaUrbana.Via.VIELA] + por_classe_z[MalhaUrbana.Via.VIELA])

	# As avenidas sao regulares nos dois eixos de proposito: e a grade arterial
	# que da orientacao. O que NAO pode ser regular e o resto — e a prova e o
	# entroncamento em T, que uma malha de linhas inteiras nao tem nenhum.
	var em_t := 0
	for i in range(-20, 21):
		for j in range(-20, 21):
			if not Vias.existe_cruzamento(i, j):
				continue
			var bracos := int(Vias.braco_n(i, j)) + int(Vias.braco_s(i, j)) 				+ int(Vias.braco_l(i, j)) + int(Vias.braco_o(i, j))
			if bracos == 3:
				em_t += 1
	_relatar("entroncamentos_em_t", em_t)

	# Larguras de quadra encontradas, em chunks.
	var larguras: Dictionary = {}
	var fundos: Dictionary = {}
	for cz in range(-ALCANCE, ALCANCE + 1):
		for cx in range(-ALCANCE, ALCANCE + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			larguras[int(q["x1"]) - int(q["x0"])] = true
			fundos[int(q["z1"]) - int(q["z0"])] = true
	_relatar("larguras_quadra", larguras.size())
	_relatar("fundos_quadra", fundos.size())

	# Chunk sem rua nenhuma e miolo de quadra grande. Tem de existir e tem de ter
	# geometria: sem ela o jogador ve um buraco pela fresta entre dois predios.
	var sem_rua := 0
	var sem_rua_com_geometria := 0
	for cz in range(-ALCANCE, ALCANCE + 1):
		for cx in range(-ALCANCE, ALCANCE + 1):
			if MalhaUrbana.tem_via(cx, cz):
				continue
			sem_rua += 1
			# Trinta triangulos ja e o chao mais um galpao. O miolo nunca e
			# pisado; o que ele nao pode ser e vazio.
			if int(ChunkBuilder.construir(cx, cz)["triangulos"]) > 30:
				sem_rua_com_geometria += 1
	_relatar("chunks_sem_rua", sem_rua)
	_relatar("miolos_preenchidos", sem_rua_com_geometria)


# --- variacao de predio -----------------------------------------------------

static func _medir_variacao() -> void:
	var alturas: Dictionary = {}
	var fachadas: Dictionary = {}
	var tintas: Dictionary = {}
	var coroas: Dictionary = {}
	var recuos: Dictionary = {}
	var usos := {0: 0, 1: 0, 2: 0}
	var quadras: Dictionary = {}

	for cz in range(-ALCANCE, ALCANCE + 1):
		for cx in range(-ALCANCE, ALCANCE + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			if quadras.has(q["id"]):
				continue
			quadras[q["id"]] = true
			usos[int(q["uso"])] += 1
			if int(q["uso"]) != MalhaUrbana.Uso.EDIFICADO:
				continue
			alturas[int(q["andares"])] = true
			fachadas[q["fachada"]] = true
			tintas[str(q["tinta"])] = true
			coroas[int(q["coroamento"])] = true
			recuos["%.1f" % float(q["recuo_extra"])] = true

	_relatar("quadras", quadras.size())
	_relatar("quadras_edificadas", usos[MalhaUrbana.Uso.EDIFICADO])
	_relatar("quadras_parque", usos[MalhaUrbana.Uso.PARQUE])
	_relatar("quadras_baldio", usos[MalhaUrbana.Uso.BALDIO])
	_relatar("alturas", alturas.size())
	_relatar("fachadas", fachadas.size())
	_relatar("tintas", tintas.size())
	_relatar("coroamentos", coroas.size())
	_relatar("recuos", recuos.size())


# --- parque -----------------------------------------------------------------

static func _medir_parques() -> void:
	var tracos: Dictionary = {}
	var nomes: Dictionary = {}
	var primeira := Vector2i(0, 0)
	var achou := false

	for cz in range(-ALCANCE * 2, ALCANCE * 2 + 1):
		for cx in range(-ALCANCE * 2, ALCANCE * 2 + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			if int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
				continue
			var plano := ParqueBuilder.planta(q)
			tracos[int(plano["traco"])] = true
			nomes[String(plano["nome"])] = true
			if not achou:
				achou = true
				primeira = Vector2i(int(q["x0"]), int(q["z0"]))

	_relatar("tracos_de_parque", tracos.size())
	_relatar("nomes_de_parque", nomes.size())
	if not achou:
		_relatar("parque_ausente", 1)
		return

	# Conteudo de um parque de verdade: grama, caminho, vegetacao que balanca,
	# mobiliario com colisao, luz e o emissor de folhas.
	var q0 := MalhaUrbana.quadra_de(primeira.x, primeira.y)
	var materiais: Dictionary = {}
	var lampadas := 0
	var folhagens := 0
	var colisoes := 0
	var tris_folha := 0

	for cz in range(int(q0["z0"]), int(q0["z1"])):
		for cx in range(int(q0["x0"]), int(q0["x1"])):
			var d := ChunkBuilder.construir(cx, cz)
			var sup: Dictionary = d["superficies"]
			for m: StringName in sup:
				materiais[m] = true
			# As duas folhagens contam: a copa e nucleo opaco mais blocos
			# recortados, e a maior parte dos triangulos esta nos recortados.
			for folha: StringName in [&"folhagem", &"folhagem_recorte"]:
				if sup.has(folha):
					tris_folha += PSXMesh.dados_triangulos(sup[folha])
			colisoes += (d["colisao"] as Array).size()
			for prop: Dictionary in d["props"]:
				if prop["tipo"] == "lampada":
					lampadas += 1
				elif prop["tipo"] == "folhagem":
					folhagens += 1

	for m: StringName in [&"grama", &"folhagem", &"folhagem_recorte", &"casca",
			&"pedra_parque", &"arbusto"]:
		_relatar("parque_tem_" + String(m), 1 if materiais.has(m) else 0)
	_relatar("parque_triangulos_folha", tris_folha)
	# O corte por alfa e o que tira a silhueta de caixa da copa. Se este material
	# sumir da copa, a arvore volta a ser um bloco verde e nenhuma outra medida
	# aqui perceberia.
	var corte := load("res://resources/materials/mat_folhagem_recorte.tres") as ShaderMaterial
	var limiar: Variant = corte.get_shader_parameter("alpha_cutoff") if corte != null else null
	_relatar("recorte_folha", "%.2f" % (float(limiar) if limiar != null else 0.0))
	_relatar("parque_lampadas", lampadas)
	_relatar("parque_emissores", folhagens)
	_relatar("parque_colisoes", colisoes)
	_relatar("parque_chunks", (int(q0["x1"]) - int(q0["x0"])) * (int(q0["z1"]) - int(q0["z0"])))

	_medir_ordem(q0)
	_medir_vento()


## O teste de ordem. Ver a nota no topo do arquivo.
static func _medir_ordem(q0: Dictionary) -> void:
	var direta: Array[int] = []
	var chunks: Array[Vector2i] = []
	for cz in range(int(q0["z0"]), int(q0["z1"])):
		for cx in range(int(q0["x0"]), int(q0["x1"])):
			chunks.append(Vector2i(cx, cz))
	for c: Vector2i in chunks:
		direta.append(int(ChunkBuilder.construir(c.x, c.y)["triangulos"]))

	chunks.reverse()
	var inversa: Dictionary[Vector2i, int] = {}
	for c: Vector2i in chunks:
		inversa[c] = int(ChunkBuilder.construir(c.x, c.y)["triangulos"])

	chunks.reverse()
	var divergentes := 0
	for i in chunks.size():
		if inversa[chunks[i]] != direta[i]:
			divergentes += 1
	_relatar("parque_ordem_divergente", divergentes)


## O vento existe no material, e o som que o acompanha existe no banco.
static func _medir_vento() -> void:
	_relatar("vento_folhagem", "%.3f" % forca_do_vento("folhagem"))
	_relatar("vento_corrente", "%.3f" % forca_do_vento("corrente"))
	# Material que nao e vegetacao nao pode balancar: um poste que verga ao vento
	# estragaria a cena inteira.
	_relatar("vento_asfalto", "%.3f" % forca_do_vento("asfalto"))

	_relatar("som_folhas", 1 if AudioDirector.tem(&"folhas_loop") else 0)
	_relatar("som_grilo", 1 if AudioDirector.tem(&"grilo") else 0)


## Forca do vento de um material.
##
## Parametro nao definido vale o padrao do shader, que e zero — e isso PRECISA
## ser tratado aqui. O executavel exportado converte os .tres para binario e no
## caminho descarta todo parametro igual ao padrao, entao la get_shader_parameter
## devolve null onde o editor devolve 0. Ler o null como float sem tratar
## devolvia o valor do material lido antes, e o criterio acusou o asfalto de
## balancar ao vento. E o tipo de divergencia entre editor e pacote que so o
## passo `build` pega.
static func forca_do_vento(nome: String) -> float:
	var mat := load("res://resources/materials/mat_%s.tres" % nome) as ShaderMaterial
	if mat == null:
		return -1.0
	var bruto: Variant = mat.get_shader_parameter("vento_forca")
	return 0.0 if bruto == null else float(bruto)


# --- pontos de interesse ----------------------------------------------------

## O mapa e o mundo leem a mesma funcao. Este teste prova isso: cada porta que o
## mapa anuncia tem de existir como prop, na mesma posicao.
static func _medir_pontos() -> void:
	var por_tipo: Dictionary[StringName, int] = {}
	var portas_anunciadas := 0
	var portas_casadas := 0
	var fora_do_chunk := 0

	for cz in range(-ALCANCE, ALCANCE + 1):
		for cx in range(-ALCANCE, ALCANCE + 1):
			var pontos := ChunkBuilder.pontos_de_interesse(cx, cz)
			var props: Array[Dictionary] = ChunkBuilder.construir(cx, cz)["props"]

			for ponto: Dictionary in pontos:
				var tipo: StringName = ponto["tipo"]
				por_tipo[tipo] = por_tipo.get(tipo, 0) + 1
				var p: Vector3 = ponto["pos"]
				if p.x < -1.0 or p.x > 33.0 or p.z < -1.0 or p.z > 33.0:
					fora_do_chunk += 1
				if tipo != &"porta":
					continue
				portas_anunciadas += 1
				for prop: Dictionary in props:
					if prop["tipo"] != "porta":
						continue
					if Vector3(prop["pos"]).distance_to(p) < 0.01:
						portas_casadas += 1
						break

	# O parque anuncia um icone so, no chunk do centro da quadra dele — e com a
	# malha do Tracado nao ha garantia de que algum centro caia nos onze por onze
	# chunks em volta da origem. Contado na mesma janela dobrada de
	# `_medir_parques`, e sem montar chunk: aqui so importa o anuncio.
	var parques := 0
	for cz in range(-ALCANCE * 2, ALCANCE * 2 + 1):
		for cx in range(-ALCANCE * 2, ALCANCE * 2 + 1):
			for ponto: Dictionary in ChunkBuilder.pontos_de_interesse(cx, cz):
				if ponto["tipo"] == &"parque":
					parques += 1
	por_tipo[&"parque"] = parques

	for tipo: StringName in por_tipo:
		_relatar("ponto_" + String(tipo), por_tipo[tipo])
	_relatar("portas_anunciadas", portas_anunciadas)
	_relatar("portas_casadas", portas_casadas)
	_relatar("pontos_fora_do_chunk", fora_do_chunk)


# --- mapa -------------------------------------------------------------------

static func _medir_mapa(cena: Node, jogador: Node3D) -> void:
	var faltando := 0
	for nome: String in ICONES:
		if not ResourceLoader.exists("res://assets/ui/icone_%s.png" % nome):
			faltando += 1
	_relatar("icones_ausentes", faltando)
	_relatar("icones", ICONES.size())

	var mapa := Mapa.new()
	mapa.estilo = Mapa.Estilo.PAGINA
	mapa.metros_por_pixel = 3.2
	mapa.revelar_tudo = true
	cena.add_child(mapa)
	mapa.size = Vector2(306.0, 172.0)
	mapa.centro = jogador.global_position
	mapa.forcar_redesenho()

	_relatar("mapa_montou", 1)
	_relatar("mapa_lugar", 1 if mapa.onde_estou() != "" else 0)

	# O retangulo que o mapa pinta tem de ser o mesmo que o chunk constroi. Sao
	# duas contas em arquivos diferentes, e e exatamente ai que um mapa comeca a
	# mentir.
	var maior_erro := 0.0
	for cz in range(-ALCANCE, ALCANCE + 1):
		for cx in range(-ALCANCE, ALCANCE + 1):
			var q := MalhaUrbana.quadra_de(cx, cz)
			var da_quadra := MalhaUrbana.retangulo_da_quadra(q)
			var do_chunk := ChunkBuilder.area_util(cx, cz)
			var mundo := Rect2(do_chunk.position + Vector2(cx * 32.0, cz * 32.0),
				do_chunk.size)
			var corte := da_quadra.intersection(Rect2(cx * 32.0, cz * 32.0, 32.0, 32.0))
			maior_erro = maxf(maior_erro, (corte.position - mundo.position).length())
			maior_erro = maxf(maior_erro, (corte.size - mundo.size).length())
	_relatar("mapa_erro_quadra", "%.3f" % maior_erro)

	mapa.queue_free()


# --- orcamento --------------------------------------------------------------

static func _medir_orcamento() -> void:
	var pior := 0
	var pior_em := Vector2i.ZERO
	var soma := 0
	var n := 0
	for cz in range(-ALCANCE, ALCANCE + 1):
		for cx in range(-ALCANCE, ALCANCE + 1):
			var t := int(ChunkBuilder.construir(cx, cz)["triangulos"])
			if t > pior:
				pior_em = Vector2i(cx, cz)
			pior = maxi(pior, t)
			soma += t
			n += 1
	_relatar("tris_pior", pior)
	# Onde, para quem for otimizar nao precisar varrer de novo.
	_relatar("tris_pior_em", "%d,%d" % [pior_em.x, pior_em.y])
	_relatar("tris_medio", soma / maxi(n, 1))
