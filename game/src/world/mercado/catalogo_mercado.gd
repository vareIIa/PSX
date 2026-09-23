## O que a loja vende: cada produto, com marca, forma, tamanho e preco.
##
## Dados puros (PLANO_MERCADO_AAA, 4.1). Quem arruma a prateleira (`Planograma`),
## quem desenha o produto (`PrateleiraViva`), quem cobra (o caixa, na F4) e o
## freguês que enche a cesta (F3) leem ESTA tabela, e mais nenhuma. Um preco
## escrito em dois lugares vira dois precos.
##
## Novembro de 1998
## ----------------
## Salario minimo de R$ 130. Refrigerante de dois litros abaixo de dois reais,
## cerveja em lata abaixo de um, maco de cigarro entre um e um e sessenta. As
## marcas sao as que estavam na prateleira naquele mes: Kuat tinha um ano,
## Trakinas estava chegando, o creme dental Kolynos acabara de virar Sorriso, e a
## Bauducco ja tinha o panetone na ponta da gondola.
##
## A cara de cada produto (logo, cores, texto) NAO mora aqui: mora no atlas de
## rotulos, gerado por `tools/baixar_rotulos.py` com as marcas reais. Trocar o
## atlas troca todas as marcas sem mexer numa linha desta tabela (decisao D4).
##
## Formato
## -------
## Uma linha por produto, e SEMPRE nesta ordem de chaves: o `baixar_rotulos.py` le
## `id`, `curto` e `preco` desta arquivo para imprimir a etiqueta de preco. A
## etiqueta tem de dizer o mesmo numero que o caixa cobra, e a unica forma de
## garantir isso e as duas lerem a mesma linha.
##
## - `cm`: largura, altura e profundidade da unidade em PE na prateleira, em cm.
##   E o que a malha usa para escalar, e o que o planograma usa para encaixar.
## - `preco`: centavos. Real com centavo e inteiro; float de dinheiro soma errado.
## - `onde`: GELADEIRA, PRATELEIRA (seco, a temperatura ambiente), AMBOS (o
##   refrigerante de dois litros esta nos dois), CAIXA (expositor ao lado da
##   registradora, compra de impulso) e BALCAO (atras do balcao: so o atendente
##   alcanca, o freguês PEDE).
## - `idade`: 18 para cerveja, destilado e cigarro. E a razao pe no chao do
##   documento no balcao.
## - `validade`: dias, ou 0 para o que nao perece na escala do jogo.
## - `item`: o `Item` do inventario em que o produto vira quando e do jogador.
class_name CatalogoMercado
extends RefCounted

enum Forma {
	LATA,     ## cilindro de aluminio: refrigerante, cerveja, aerossol
	PET,      ## garrafa plastica com ombro e tampa
	GARRAFA,  ## vidro, gargalo longo: cerveja de 600, cachaca, suco
	CAIXA,    ## caixa de papelao: sabao em po, creme dental, leite longa vida
	PACOTE,   ## embalagem mole, fechada em cima: salgadinho, feijao, pao
	POTE,     ## cilindro baixo e largo: margarina, achocolatado, iogurte
	BARRA,    ## chato e comprido: chocolate, chiclete, sardinha
	MACO,     ## maco de cigarro
	FRASCO,   ## frasco achatado: detergente, xampu, agua sanitaria
}

enum Onde { GELADEIRA, PRATELEIRA, AMBOS, CAIXA, BALCAO }

## A data que o jogo vive. A validade impressa sai dela.
const HOJE := Vector3i(14, 11, 1998)

const PRODUTOS: Array[Dictionary] = [
	# --- refrigerante -------------------------------------------------------
	{"id": &"coca_lata", "curto": "COCA-COLA LATA", "preco": 79, "nome": "Coca-Cola lata 350 ml", "marca": "Coca-Cola", "cat": &"refrigerante", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA},
	{"id": &"coca_2l", "curto": "COCA-COLA 2L", "preco": 189, "nome": "Coca-Cola 2 L", "marca": "Coca-Cola", "cat": &"refrigerante", "forma": Forma.PET, "cm": Vector3(10.4, 32.0, 10.4), "onde": Onde.AMBOS},
	{"id": &"guarana_lata", "curto": "GUARANA ANT. LATA", "preco": 69, "nome": "Guaraná Antarctica lata 350 ml", "marca": "Antarctica", "cat": &"refrigerante", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA},
	{"id": &"guarana_2l", "curto": "GUARANA ANT. 2L", "preco": 159, "nome": "Guaraná Antarctica 2 L", "marca": "Antarctica", "cat": &"refrigerante", "forma": Forma.PET, "cm": Vector3(10.4, 32.0, 10.4), "onde": Onde.AMBOS},
	{"id": &"fanta_lata", "curto": "FANTA LARANJA LATA", "preco": 69, "nome": "Fanta Laranja lata 350 ml", "marca": "Fanta", "cat": &"refrigerante", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA},
	{"id": &"fanta_2l", "curto": "FANTA LARANJA 2L", "preco": 169, "nome": "Fanta Laranja 2 L", "marca": "Fanta", "cat": &"refrigerante", "forma": Forma.PET, "cm": Vector3(10.4, 32.0, 10.4), "onde": Onde.AMBOS},
	{"id": &"sprite_lata", "curto": "SPRITE LATA", "preco": 69, "nome": "Sprite lata 350 ml", "marca": "Sprite", "cat": &"refrigerante", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA},
	{"id": &"kuat_2l", "curto": "KUAT GUARANA 2L", "preco": 129, "nome": "Kuat guaraná 2 L", "marca": "Kuat", "cat": &"refrigerante", "forma": Forma.PET, "cm": Vector3(10.4, 32.0, 10.4), "onde": Onde.AMBOS},
	{"id": &"pepsi_lata", "curto": "PEPSI LATA", "preco": 65, "nome": "Pepsi lata 350 ml", "marca": "Pepsi", "cat": &"refrigerante", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA},
	{"id": &"pepsi_2l", "curto": "PEPSI 2L", "preco": 149, "nome": "Pepsi 2 L", "marca": "Pepsi", "cat": &"refrigerante", "forma": Forma.PET, "cm": Vector3(10.4, 32.0, 10.4), "onde": Onde.AMBOS},
	{"id": &"soda_lata", "curto": "SODA LIMONADA LATA", "preco": 65, "nome": "Soda Limonada Antarctica lata", "marca": "Antarctica", "cat": &"refrigerante", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA},
	{"id": &"sukita_2l", "curto": "SUKITA LARANJA 2L", "preco": 119, "nome": "Sukita laranja 2 L", "marca": "Sukita", "cat": &"refrigerante", "forma": Forma.PET, "cm": Vector3(10.4, 32.0, 10.4), "onde": Onde.PRATELEIRA},
	{"id": &"dolly_2l", "curto": "DOLLY GUARANA 2L", "preco": 99, "nome": "Dolly guaraná 2 L", "marca": "Dolly", "cat": &"refrigerante", "forma": Forma.PET, "cm": Vector3(10.4, 32.0, 10.4), "onde": Onde.AMBOS},
	# --- cerveja ------------------------------------------------------------
	{"id": &"brahma_lata", "curto": "BRAHMA CHOPP LATA", "preco": 69, "nome": "Brahma Chopp lata 350 ml", "marca": "Brahma", "cat": &"cerveja", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA, "idade": 18},
	{"id": &"skol_lata", "curto": "SKOL LATA", "preco": 65, "nome": "Skol lata 350 ml", "marca": "Skol", "cat": &"cerveja", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA, "idade": 18},
	{"id": &"antarctica_lata", "curto": "ANTARCTICA LATA", "preco": 69, "nome": "Antarctica Pilsen lata 350 ml", "marca": "Antarctica", "cat": &"cerveja", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA, "idade": 18},
	{"id": &"kaiser_lata", "curto": "KAISER LATA", "preco": 55, "nome": "Kaiser lata 350 ml", "marca": "Kaiser", "cat": &"cerveja", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA, "idade": 18},
	{"id": &"schin_lata", "curto": "SCHINCARIOL LATA", "preco": 55, "nome": "Schincariol lata 350 ml", "marca": "Schincariol", "cat": &"cerveja", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA, "idade": 18},
	{"id": &"bohemia_lata", "curto": "BOHEMIA LATA", "preco": 89, "nome": "Bohemia lata 350 ml", "marca": "Bohemia", "cat": &"cerveja", "forma": Forma.LATA, "cm": Vector3(6.6, 12.2, 6.6), "onde": Onde.GELADEIRA, "idade": 18},
	{"id": &"brahma_600", "curto": "BRAHMA GARRAFA 600", "preco": 99, "nome": "Brahma Chopp garrafa 600 ml", "marca": "Brahma", "cat": &"cerveja", "forma": Forma.GARRAFA, "cm": Vector3(7.6, 29.0, 7.6), "onde": Onde.GELADEIRA, "idade": 18},
	# --- agua, suco, isotonico ----------------------------------------------
	{"id": &"agua_crystal", "curto": "AGUA CRYSTAL 500ML", "preco": 50, "nome": "Água mineral Crystal 500 ml", "marca": "Crystal", "cat": &"agua_suco", "forma": Forma.PET, "cm": Vector3(6.6, 21.0, 6.6), "onde": Onde.GELADEIRA},
	{"id": &"agua_minalba", "curto": "AGUA MINALBA 1,5L", "preco": 89, "nome": "Água mineral Minalba 1,5 L", "marca": "Minalba", "cat": &"agua_suco", "forma": Forma.PET, "cm": Vector3(8.8, 31.0, 8.8), "onde": Onde.AMBOS},
	{"id": &"gatorade", "curto": "GATORADE LIMAO", "preco": 129, "nome": "Gatorade limão 473 ml", "marca": "Gatorade", "cat": &"agua_suco", "forma": Forma.PET, "cm": Vector3(7.2, 20.5, 7.2), "onde": Onde.GELADEIRA},
	{"id": &"maguary", "curto": "SUCO MAGUARY MARAC.", "preco": 219, "nome": "Suco Maguary maracujá 500 ml", "marca": "Maguary", "cat": &"agua_suco", "forma": Forma.GARRAFA, "cm": Vector3(7.0, 23.0, 7.0), "onde": Onde.PRATELEIRA},
	{"id": &"tang", "curto": "TANG LARANJA", "preco": 35, "nome": "Tang laranja 45 g", "marca": "Tang", "cat": &"agua_suco", "forma": Forma.BARRA, "cm": Vector3(10.0, 14.0, 1.4), "onde": Onde.PRATELEIRA},
	{"id": &"kisuco", "curto": "KI-SUCO UVA", "preco": 15, "nome": "Ki-Suco uva", "marca": "Ki-Suco", "cat": &"agua_suco", "forma": Forma.BARRA, "cm": Vector3(8.0, 11.0, 1.0), "onde": Onde.PRATELEIRA},
	# --- laticinio ----------------------------------------------------------
	{"id": &"danone", "curto": "IOGURTE DANONE MOR.", "preco": 79, "nome": "Iogurte Danone morango 200 g", "marca": "Danone", "cat": &"laticinio", "forma": Forma.POTE, "cm": Vector3(7.0, 8.4, 7.0), "onde": Onde.GELADEIRA, "validade": 20},
	{"id": &"danoninho", "curto": "DANONINHO", "preco": 49, "nome": "Danoninho morango 90 g", "marca": "Danone", "cat": &"laticinio", "forma": Forma.POTE, "cm": Vector3(5.4, 5.6, 5.4), "onde": Onde.GELADEIRA, "validade": 20},
	{"id": &"yakult", "curto": "YAKULT", "preco": 39, "nome": "Yakult 80 g", "marca": "Yakult", "cat": &"laticinio", "forma": Forma.FRASCO, "cm": Vector3(4.4, 9.4, 4.4), "onde": Onde.GELADEIRA, "validade": 25},
	{"id": &"catupiry", "curto": "REQUEIJAO CATUPIRY", "preco": 199, "nome": "Requeijão Catupiry 250 g", "marca": "Catupiry", "cat": &"laticinio", "forma": Forma.POTE, "cm": Vector3(9.4, 6.4, 9.4), "onde": Onde.GELADEIRA, "validade": 45},
	{"id": &"qualy", "curto": "MARGARINA QUALY 500G", "preco": 149, "nome": "Margarina Qualy 500 g", "marca": "Sadia", "cat": &"laticinio", "forma": Forma.POTE, "cm": Vector3(12.4, 7.0, 12.4), "onde": Onde.GELADEIRA, "validade": 90},
	{"id": &"doriana", "curto": "MARGARINA DORIANA", "preco": 89, "nome": "Margarina Doriana 250 g", "marca": "Doriana", "cat": &"laticinio", "forma": Forma.POTE, "cm": Vector3(10.0, 6.0, 10.0), "onde": Onde.GELADEIRA, "validade": 90},
	{"id": &"parmalat", "curto": "LEITE PARMALAT 1L", "preco": 89, "nome": "Leite longa vida Parmalat 1 L", "marca": "Parmalat", "cat": &"matinal", "forma": Forma.CAIXA, "cm": Vector3(9.5, 19.6, 6.4), "onde": Onde.PRATELEIRA, "validade": 120},
	# --- mercearia ----------------------------------------------------------
	{"id": &"arroz", "curto": "ARROZ TIO JOAO 1KG", "preco": 109, "nome": "Arroz Tio João 1 kg", "marca": "Tio João", "cat": &"mercearia", "forma": Forma.PACOTE, "cm": Vector3(10.5, 22.0, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"feijao", "curto": "FEIJAO CAMIL 1KG", "preco": 119, "nome": "Feijão carioca Camil 1 kg", "marca": "Camil", "cat": &"mercearia", "forma": Forma.PACOTE, "cm": Vector3(12.0, 20.0, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"acucar", "curto": "ACUCAR UNIAO 1KG", "preco": 79, "nome": "Açúcar refinado União 1 kg", "marca": "União", "cat": &"mercearia", "forma": Forma.CAIXA, "cm": Vector3(10.0, 17.5, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"sal", "curto": "SAL CISNE 1KG", "preco": 39, "nome": "Sal refinado Cisne 1 kg", "marca": "Cisne", "cat": &"mercearia", "forma": Forma.CAIXA, "cm": Vector3(9.0, 15.0, 5.0), "onde": Onde.PRATELEIRA},
	{"id": &"miojo", "curto": "NISSIN MIOJO GALINHA", "preco": 35, "nome": "Nissin Miojo Lámen galinha 85 g", "marca": "Nissin", "cat": &"mercearia", "forma": Forma.PACOTE, "cm": Vector3(13.0, 11.0, 3.6), "onde": Onde.PRATELEIRA},
	{"id": &"espaguete", "curto": "ESPAGUETE ADRIA", "preco": 89, "nome": "Espaguete Adria 500 g", "marca": "Adria", "cat": &"mercearia", "forma": Forma.PACOTE, "cm": Vector3(7.5, 26.0, 3.2), "onde": Onde.PRATELEIRA},
	{"id": &"pomarola", "curto": "MOLHO POMAROLA", "preco": 79, "nome": "Molho de tomate Pomarola 340 g", "marca": "Cica", "cat": &"mercearia", "forma": Forma.CAIXA, "cm": Vector3(7.2, 11.0, 5.0), "onde": Onde.PRATELEIRA},
	{"id": &"elefante", "curto": "EXTRATO ELEFANTE", "preco": 99, "nome": "Extrato de tomate Elefante 350 g", "marca": "Cica", "cat": &"mercearia", "forma": Forma.LATA, "cm": Vector3(7.4, 9.0, 7.4), "onde": Onde.PRATELEIRA},
	{"id": &"hellmanns", "curto": "MAIONESE HELLMANNS", "preco": 199, "nome": "Maionese Hellmann's 500 g", "marca": "Hellmann's", "cat": &"mercearia", "forma": Forma.POTE, "cm": Vector3(9.0, 12.5, 9.0), "onde": Onde.PRATELEIRA},
	{"id": &"oleo", "curto": "OLEO LIZA 900ML", "preco": 99, "nome": "Óleo de soja Liza 900 ml", "marca": "Liza", "cat": &"mercearia", "forma": Forma.PET, "cm": Vector3(8.0, 24.5, 8.0), "onde": Onde.PRATELEIRA},
	{"id": &"sardinha", "curto": "SARDINHA COQUEIRO", "preco": 99, "nome": "Sardinha Coqueiro em óleo 130 g", "marca": "Coqueiro", "cat": &"mercearia", "forma": Forma.BARRA, "cm": Vector3(11.0, 7.6, 2.8), "onde": Onde.PRATELEIRA},
	{"id": &"maizena", "curto": "AMIDO MAIZENA 500G", "preco": 119, "nome": "Amido de milho Maizena 500 g", "marca": "Maizena", "cat": &"mercearia", "forma": Forma.CAIXA, "cm": Vector3(10.0, 17.0, 6.0), "onde": Onde.PRATELEIRA},
	# --- matinal ------------------------------------------------------------
	{"id": &"cafe_pilao", "curto": "CAFE PILAO 500G", "preco": 329, "nome": "Café Pilão 500 g", "marca": "Pilão", "cat": &"matinal", "forma": Forma.CAIXA, "cm": Vector3(9.0, 15.5, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"cafe_melitta", "curto": "CAFE MELITTA 500G", "preco": 339, "nome": "Café Melitta 500 g", "marca": "Melitta", "cat": &"matinal", "forma": Forma.CAIXA, "cm": Vector3(9.0, 15.5, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"nescau", "curto": "NESCAU 400G", "preco": 229, "nome": "Nescau 400 g", "marca": "Nestlé", "cat": &"matinal", "forma": Forma.POTE, "cm": Vector3(10.0, 14.0, 10.0), "onde": Onde.PRATELEIRA},
	{"id": &"toddy", "curto": "TODDY 400G", "preco": 219, "nome": "Toddy 400 g", "marca": "Toddy", "cat": &"matinal", "forma": Forma.POTE, "cm": Vector3(10.0, 14.0, 10.0), "onde": Onde.PRATELEIRA},
	{"id": &"ninho", "curto": "LEITE NINHO 400G", "preco": 369, "nome": "Leite em pó Ninho 400 g", "marca": "Nestlé", "cat": &"matinal", "forma": Forma.POTE, "cm": Vector3(10.0, 13.0, 10.0), "onde": Onde.PRATELEIRA},
	# --- biscoito -----------------------------------------------------------
	{"id": &"trakinas", "curto": "TRAKINAS CHOCOLATE", "preco": 69, "nome": "Trakinas chocolate 150 g", "marca": "Nabisco", "cat": &"biscoito", "forma": Forma.PACOTE, "cm": Vector3(14.5, 6.2, 5.2), "onde": Onde.PRATELEIRA},
	{"id": &"passatempo", "curto": "PASSATEMPO RECHEADO", "preco": 59, "nome": "Passatempo recheado 150 g", "marca": "Nestlé", "cat": &"biscoito", "forma": Forma.PACOTE, "cm": Vector3(14.5, 6.2, 5.2), "onde": Onde.PRATELEIRA},
	{"id": &"negresco", "curto": "NEGRESCO", "preco": 65, "nome": "Negresco 150 g", "marca": "Nestlé", "cat": &"biscoito", "forma": Forma.PACOTE, "cm": Vector3(14.5, 6.2, 5.2), "onde": Onde.PRATELEIRA},
	{"id": &"bono", "curto": "BONO CHOCOLATE", "preco": 69, "nome": "Bono chocolate 200 g", "marca": "Nestlé", "cat": &"biscoito", "forma": Forma.PACOTE, "cm": Vector3(15.5, 6.5, 5.5), "onde": Onde.PRATELEIRA},
	{"id": &"club_social", "curto": "CLUB SOCIAL", "preco": 69, "nome": "Club Social original", "marca": "Nabisco", "cat": &"biscoito", "forma": Forma.CAIXA, "cm": Vector3(12.5, 9.0, 4.2), "onde": Onde.PRATELEIRA},
	{"id": &"piraque", "curto": "CREAM CRACKER PIRAQUE", "preco": 79, "nome": "Cream Cracker Piraquê 200 g", "marca": "Piraquê", "cat": &"biscoito", "forma": Forma.PACOTE, "cm": Vector3(15.0, 7.0, 5.5), "onde": Onde.PRATELEIRA},
	{"id": &"wafer", "curto": "WAFER BAUDUCCO", "preco": 69, "nome": "Wafer Bauducco chocolate 140 g", "marca": "Bauducco", "cat": &"biscoito", "forma": Forma.PACOTE, "cm": Vector3(14.0, 5.0, 4.4), "onde": Onde.PRATELEIRA},
	# --- salgadinho ---------------------------------------------------------
	{"id": &"ruffles", "curto": "RUFFLES ORIGINAL", "preco": 99, "nome": "Ruffles original 57 g", "marca": "Elma Chips", "cat": &"salgadinho", "forma": Forma.PACOTE, "cm": Vector3(17.0, 24.0, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"cheetos", "curto": "CHEETOS REQUEIJAO", "preco": 59, "nome": "Cheetos requeijão 50 g", "marca": "Elma Chips", "cat": &"salgadinho", "forma": Forma.PACOTE, "cm": Vector3(15.0, 22.0, 5.0), "onde": Onde.PRATELEIRA},
	{"id": &"fandangos", "curto": "FANDANGOS PRESUNTO", "preco": 59, "nome": "Fandangos presunto 50 g", "marca": "Elma Chips", "cat": &"salgadinho", "forma": Forma.PACOTE, "cm": Vector3(15.0, 22.0, 5.0), "onde": Onde.PRATELEIRA},
	{"id": &"doritos", "curto": "DORITOS QUEIJO", "preco": 99, "nome": "Doritos queijo nacho 55 g", "marca": "Elma Chips", "cat": &"salgadinho", "forma": Forma.PACOTE, "cm": Vector3(17.0, 24.0, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"amendoim", "curto": "AMENDOIM JAPONES DORI", "preco": 89, "nome": "Amendoim japonês Dori 150 g", "marca": "Dori", "cat": &"salgadinho", "forma": Forma.PACOTE, "cm": Vector3(12.0, 18.0, 4.0), "onde": Onde.PRATELEIRA},
	# --- doce ---------------------------------------------------------------
	{"id": &"diamante_negro", "curto": "DIAMANTE NEGRO 180G", "preco": 149, "nome": "Diamante Negro Lacta 180 g", "marca": "Lacta", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(16.0, 8.0, 1.6), "onde": Onde.PRATELEIRA},
	{"id": &"laka", "curto": "LAKA 180G", "preco": 149, "nome": "Laka Lacta 180 g", "marca": "Lacta", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(16.0, 8.0, 1.6), "onde": Onde.PRATELEIRA},
	{"id": &"lacta_ao_leite", "curto": "LACTA AO LEITE 180G", "preco": 149, "nome": "Chocolate Lacta ao leite 180 g", "marca": "Lacta", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(16.0, 8.0, 1.6), "onde": Onde.PRATELEIRA},
	{"id": &"classic", "curto": "NESTLE CLASSIC 200G", "preco": 159, "nome": "Chocolate Nestlé Classic 200 g", "marca": "Nestlé", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(17.0, 8.4, 1.6), "onde": Onde.PRATELEIRA},
	{"id": &"garoto_ao_leite", "curto": "GAROTO AO LEITE 150G", "preco": 129, "nome": "Chocolate Garoto ao leite 150 g", "marca": "Garoto", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(15.0, 7.6, 1.5), "onde": Onde.PRATELEIRA},
	{"id": &"bombons_garoto", "curto": "BOMBONS GAROTO 400G", "preco": 399, "nome": "Caixa de bombons Garoto 400 g", "marca": "Garoto", "cat": &"doce", "forma": Forma.CAIXA, "cm": Vector3(22.0, 6.4, 13.0), "onde": Onde.PRATELEIRA},
	{"id": &"bis", "curto": "BIS LACTA", "preco": 119, "nome": "Bis Lacta 126 g", "marca": "Lacta", "cat": &"doce", "forma": Forma.CAIXA, "cm": Vector3(13.0, 7.0, 3.2), "onde": Onde.CAIXA},
	{"id": &"sonho_de_valsa", "curto": "SONHO DE VALSA", "preco": 20, "nome": "Sonho de Valsa", "marca": "Lacta", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(5.0, 4.4, 2.6), "onde": Onde.CAIXA},
	{"id": &"baton", "curto": "BATON GAROTO", "preco": 20, "nome": "Baton Garoto 16 g", "marca": "Garoto", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(2.4, 9.0, 1.3), "onde": Onde.CAIXA},
	{"id": &"prestigio", "curto": "PRESTIGIO", "preco": 35, "nome": "Prestígio 33 g", "marca": "Nestlé", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(10.5, 4.0, 1.8), "onde": Onde.CAIXA},
	{"id": &"chokito", "curto": "CHOKITO", "preco": 35, "nome": "Chokito 32 g", "marca": "Nestlé", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(10.5, 4.0, 1.8), "onde": Onde.CAIXA},
	{"id": &"serenata", "curto": "SERENATA DO AMOR", "preco": 20, "nome": "Serenata do Amor Garoto", "marca": "Garoto", "cat": &"doce", "forma": Forma.BARRA, "cm": Vector3(4.6, 4.0, 2.4), "onde": Onde.CAIXA},
	# --- bala e chiclete ----------------------------------------------------
	{"id": &"halls", "curto": "HALLS EXTRA FORTE", "preco": 40, "nome": "Halls extra forte", "marca": "Halls", "cat": &"bala", "forma": Forma.BARRA, "cm": Vector3(2.4, 7.4, 2.4), "onde": Onde.CAIXA},
	{"id": &"trident", "curto": "TRIDENT HORTELA", "preco": 50, "nome": "Trident hortelã", "marca": "Trident", "cat": &"bala", "forma": Forma.BARRA, "cm": Vector3(2.6, 7.4, 1.1), "onde": Onde.CAIXA},
	{"id": &"bubbaloo", "curto": "BUBBALOO MORANGO", "preco": 10, "nome": "Bubbaloo morango", "marca": "Bubbaloo", "cat": &"bala", "forma": Forma.BARRA, "cm": Vector3(2.2, 2.6, 2.2), "onde": Onde.CAIXA},
	{"id": &"mentos", "curto": "MENTOS MENTA", "preco": 45, "nome": "Mentos menta", "marca": "Mentos", "cat": &"bala", "forma": Forma.BARRA, "cm": Vector3(2.4, 7.6, 2.4), "onde": Onde.CAIXA},
	# --- padaria ------------------------------------------------------------
	{"id": &"pao_pullman", "curto": "PAO DE FORMA PULLMAN", "preco": 180, "nome": "Pão de forma Pullman 500 g", "marca": "Pullman", "cat": &"padaria", "forma": Forma.PACOTE, "cm": Vector3(26.0, 12.0, 11.0), "onde": Onde.PRATELEIRA, "validade": 7},
	{"id": &"bisnaguinha", "curto": "BISNAGUINHA SEVEN BOYS", "preco": 149, "nome": "Bisnaguinha Seven Boys 300 g", "marca": "Seven Boys", "cat": &"padaria", "forma": Forma.PACOTE, "cm": Vector3(21.0, 9.0, 13.0), "onde": Onde.PRATELEIRA, "validade": 7},
	{"id": &"panetone", "curto": "PANETONE BAUDUCCO", "preco": 499, "nome": "Panetone Bauducco 500 g", "marca": "Bauducco", "cat": &"padaria", "forma": Forma.CAIXA, "cm": Vector3(16.5, 14.0, 16.5), "onde": Onde.PRATELEIRA, "validade": 90},
	# --- higiene ------------------------------------------------------------
	{"id": &"colgate", "curto": "CREME DENTAL COLGATE", "preco": 119, "nome": "Creme dental Colgate 90 g", "marca": "Colgate", "cat": &"higiene", "forma": Forma.CAIXA, "cm": Vector3(18.5, 4.4, 3.6), "onde": Onde.PRATELEIRA},
	{"id": &"sorriso", "curto": "CREME DENTAL SORRISO", "preco": 89, "nome": "Creme dental Sorriso 90 g", "marca": "Sorriso", "cat": &"higiene", "forma": Forma.CAIXA, "cm": Vector3(18.5, 4.4, 3.6), "onde": Onde.PRATELEIRA},
	{"id": &"lux", "curto": "SABONETE LUX", "preco": 49, "nome": "Sabonete Lux 90 g", "marca": "Lux", "cat": &"higiene", "forma": Forma.CAIXA, "cm": Vector3(9.0, 5.8, 3.4), "onde": Onde.PRATELEIRA},
	{"id": &"protex", "curto": "SABONETE PROTEX", "preco": 79, "nome": "Sabonete Protex 90 g", "marca": "Protex", "cat": &"higiene", "forma": Forma.CAIXA, "cm": Vector3(9.0, 5.8, 3.4), "onde": Onde.PRATELEIRA},
	{"id": &"seda", "curto": "SHAMPOO SEDA 350ML", "preco": 229, "nome": "Shampoo Seda 350 ml", "marca": "Seda", "cat": &"higiene", "forma": Forma.FRASCO, "cm": Vector3(7.4, 20.0, 4.4), "onde": Onde.PRATELEIRA},
	{"id": &"neutrox", "curto": "CONDIC. NEUTROX", "preco": 189, "nome": "Condicionador Neutrox 300 ml", "marca": "Neutrox", "cat": &"higiene", "forma": Forma.FRASCO, "cm": Vector3(7.0, 19.0, 4.2), "onde": Onde.PRATELEIRA},
	{"id": &"rexona", "curto": "DESODORANTE REXONA", "preco": 349, "nome": "Desodorante Rexona aerossol", "marca": "Rexona", "cat": &"higiene", "forma": Forma.LATA, "cm": Vector3(4.6, 15.5, 4.6), "onde": Onde.PRATELEIRA},
	{"id": &"papel_neve", "curto": "PAPEL HIG. NEVE 4UN", "preco": 159, "nome": "Papel higiênico Neve 4 rolos", "marca": "Neve", "cat": &"higiene", "forma": Forma.PACOTE, "cm": Vector3(21.0, 11.0, 10.5), "onde": Onde.PRATELEIRA},
	{"id": &"prestobarba", "curto": "GILLETTE PRESTOBARBA", "preco": 99, "nome": "Aparelho Gillette Prestobarba", "marca": "Gillette", "cat": &"higiene", "forma": Forma.BARRA, "cm": Vector3(6.0, 17.0, 2.0), "onde": Onde.PRATELEIRA},
	{"id": &"always", "curto": "ABSORVENTE ALWAYS", "preco": 199, "nome": "Absorvente Always 8 unidades", "marca": "Always", "cat": &"higiene", "forma": Forma.PACOTE, "cm": Vector3(12.0, 14.0, 6.0), "onde": Onde.PRATELEIRA},
	{"id": &"pampers", "curto": "FRALDA PAMPERS M", "preco": 899, "nome": "Fralda Pampers M 16 unidades", "marca": "Pampers", "cat": &"higiene", "forma": Forma.PACOTE, "cm": Vector3(22.0, 25.0, 10.0), "onde": Onde.PRATELEIRA},
	# --- limpeza ------------------------------------------------------------
	{"id": &"detergente", "curto": "DETERGENTE YPE", "preco": 49, "nome": "Detergente Ypê neutro 500 ml", "marca": "Ypê", "cat": &"limpeza", "forma": Forma.FRASCO, "cm": Vector3(7.0, 21.0, 4.6), "onde": Onde.PRATELEIRA},
	{"id": &"omo", "curto": "SABAO EM PO OMO 1KG", "preco": 349, "nome": "Sabão em pó Omo 1 kg", "marca": "Omo", "cat": &"limpeza", "forma": Forma.CAIXA, "cm": Vector3(19.0, 24.0, 6.5), "onde": Onde.PRATELEIRA},
	{"id": &"qboa", "curto": "AGUA SANITARIA QBOA", "preco": 69, "nome": "Água sanitária Qboa 1 L", "marca": "Qboa", "cat": &"limpeza", "forma": Forma.FRASCO, "cm": Vector3(8.6, 25.0, 8.0), "onde": Onde.PRATELEIRA},
	{"id": &"bombril", "curto": "BOMBRIL 8UN", "preco": 59, "nome": "Lã de aço Bombril 8 unidades", "marca": "Bombril", "cat": &"limpeza", "forma": Forma.PACOTE, "cm": Vector3(10.0, 6.0, 4.4), "onde": Onde.PRATELEIRA},
	{"id": &"veja", "curto": "VEJA MULTIUSO", "preco": 199, "nome": "Veja multiuso 500 ml", "marca": "Veja", "cat": &"limpeza", "forma": Forma.FRASCO, "cm": Vector3(8.0, 24.0, 5.0), "onde": Onde.PRATELEIRA},
	{"id": &"pinho_sol", "curto": "PINHO SOL 500ML", "preco": 179, "nome": "Desinfetante Pinho Sol 500 ml", "marca": "Pinho Sol", "cat": &"limpeza", "forma": Forma.FRASCO, "cm": Vector3(8.0, 21.0, 5.0), "onde": Onde.PRATELEIRA},
	{"id": &"sabao_barra", "curto": "SABAO BARRA MINERVA", "preco": 129, "nome": "Sabão em barra Minerva 5 unidades", "marca": "Minerva", "cat": &"limpeza", "forma": Forma.CAIXA, "cm": Vector3(20.0, 5.0, 7.0), "onde": Onde.PRATELEIRA},
	{"id": &"baygon", "curto": "INSETICIDA BAYGON", "preco": 399, "nome": "Inseticida Baygon 300 ml", "marca": "Baygon", "cat": &"limpeza", "forma": Forma.LATA, "cm": Vector3(6.6, 20.0, 6.6), "onde": Onde.PRATELEIRA},
	{"id": &"esponja", "curto": "ESPONJA SCOTCH-BRITE", "preco": 59, "nome": "Esponja Scotch-Brite", "marca": "Scotch-Brite", "cat": &"limpeza", "forma": Forma.BARRA, "cm": Vector3(11.0, 7.5, 2.8), "onde": Onde.PRATELEIRA},
	# --- utilidade e farmacia leve -------------------------------------------
	{"id": &"fosforo", "curto": "FOSFORO FIAT LUX", "preco": 10, "nome": "Fósforos Fiat Lux", "marca": "Fiat Lux", "cat": &"utilidade", "forma": Forma.CAIXA, "cm": Vector3(5.2, 3.6, 1.6), "onde": Onde.BALCAO},
	{"id": &"isqueiro", "curto": "ISQUEIRO BIC", "preco": 99, "nome": "Isqueiro Bic", "marca": "Bic", "cat": &"utilidade", "forma": Forma.BARRA, "cm": Vector3(2.5, 8.2, 1.3), "onde": Onde.BALCAO},
	{"id": &"pilha_rayovac", "curto": "PILHA RAYOVAC AA", "preco": 190, "nome": "Pilhas Rayovac AA, par", "marca": "Rayovac", "cat": &"utilidade", "forma": Forma.BARRA, "cm": Vector3(8.0, 12.0, 1.6), "onde": Onde.PRATELEIRA, "item": &"bateria"},
	{"id": &"pilha_duracell", "curto": "PILHA DURACELL AA", "preco": 290, "nome": "Pilhas Duracell AA, par", "marca": "Duracell", "cat": &"utilidade", "forma": Forma.BARRA, "cm": Vector3(8.0, 12.0, 1.6), "onde": Onde.PRATELEIRA, "item": &"bateria"},
	{"id": &"bandaid", "curto": "BAND-AID 10UN", "preco": 129, "nome": "Curativo Band-Aid 10 unidades", "marca": "Band-Aid", "cat": &"farmacia", "forma": Forma.CAIXA, "cm": Vector3(8.0, 4.4, 2.2), "onde": Onde.PRATELEIRA, "item": &"bandagem"},
	{"id": &"aspirina", "curto": "ASPIRINA 10 COMP.", "preco": 99, "nome": "Aspirina 500 mg, 10 comprimidos", "marca": "Bayer", "cat": &"farmacia", "forma": Forma.CAIXA, "cm": Vector3(5.2, 8.4, 1.6), "onde": Onde.PRATELEIRA, "item": &"remedio"},
	{"id": &"engov", "curto": "ENGOV", "preco": 79, "nome": "Engov, 6 comprimidos", "marca": "Engov", "cat": &"farmacia", "forma": Forma.CAIXA, "cm": Vector3(5.0, 8.0, 1.4), "onde": Onde.PRATELEIRA},
	{"id": &"sonrisal", "curto": "SONRISAL", "preco": 69, "nome": "Sonrisal, 2 envelopes", "marca": "Sonrisal", "cat": &"farmacia", "forma": Forma.CAIXA, "cm": Vector3(5.4, 9.0, 2.0), "onde": Onde.PRATELEIRA},
	# --- destilado ----------------------------------------------------------
	{"id": &"cachaca_51", "curto": "CACHACA 51 965ML", "preco": 249, "nome": "Cachaça 51 965 ml", "marca": "51", "cat": &"destilado", "forma": Forma.GARRAFA, "cm": Vector3(8.4, 30.0, 8.4), "onde": Onde.PRATELEIRA, "idade": 18},
	{"id": &"velho_barreiro", "curto": "VELHO BARREIRO 910ML", "preco": 229, "nome": "Cachaça Velho Barreiro 910 ml", "marca": "Velho Barreiro", "cat": &"destilado", "forma": Forma.GARRAFA, "cm": Vector3(8.4, 30.0, 8.4), "onde": Onde.PRATELEIRA, "idade": 18},
	{"id": &"catuaba", "curto": "CATUABA SELVAGEM", "preco": 299, "nome": "Catuaba Selvagem 900 ml", "marca": "Catuaba Selvagem", "cat": &"destilado", "forma": Forma.GARRAFA, "cm": Vector3(8.4, 30.0, 8.4), "onde": Onde.PRATELEIRA, "idade": 18},
	{"id": &"dreher", "curto": "CONHAQUE DREHER", "preco": 399, "nome": "Conhaque Dreher 900 ml", "marca": "Dreher", "cat": &"destilado", "forma": Forma.GARRAFA, "cm": Vector3(8.4, 29.0, 8.4), "onde": Onde.PRATELEIRA, "idade": 18},
	{"id": &"orloff", "curto": "VODKA ORLOFF 1L", "preco": 699, "nome": "Vodka Orloff 1 L", "marca": "Orloff", "cat": &"destilado", "forma": Forma.GARRAFA, "cm": Vector3(8.4, 31.0, 8.4), "onde": Onde.PRATELEIRA, "idade": 18},
	# --- cigarro (atras do balcao) --------------------------------------------
	{"id": &"hollywood", "curto": "HOLLYWOOD", "preco": 115, "nome": "Hollywood, maço", "marca": "Hollywood", "cat": &"cigarro", "forma": Forma.MACO, "cm": Vector3(5.6, 8.8, 2.2), "onde": Onde.BALCAO, "idade": 18},
	{"id": &"free", "curto": "FREE", "preco": 140, "nome": "Free, maço", "marca": "Free", "cat": &"cigarro", "forma": Forma.MACO, "cm": Vector3(5.6, 8.8, 2.2), "onde": Onde.BALCAO, "idade": 18},
	{"id": &"derby", "curto": "DERBY", "preco": 100, "nome": "Derby, maço", "marca": "Derby", "cat": &"cigarro", "forma": Forma.MACO, "cm": Vector3(5.6, 8.8, 2.2), "onde": Onde.BALCAO, "idade": 18},
	{"id": &"marlboro", "curto": "MARLBORO", "preco": 160, "nome": "Marlboro, maço", "marca": "Marlboro", "cat": &"cigarro", "forma": Forma.MACO, "cm": Vector3(5.6, 8.8, 2.2), "onde": Onde.BALCAO, "idade": 18},
	{"id": &"carlton", "curto": "CARLTON", "preco": 160, "nome": "Carlton, maço", "marca": "Carlton", "cat": &"cigarro", "forma": Forma.MACO, "cm": Vector3(5.6, 8.8, 2.2), "onde": Onde.BALCAO, "idade": 18},
	{"id": &"minister", "curto": "MINISTER", "preco": 110, "nome": "Minister, maço", "marca": "Minister", "cat": &"cigarro", "forma": Forma.MACO, "cm": Vector3(5.6, 8.8, 2.2), "onde": Onde.BALCAO, "idade": 18},
	{"id": &"charm", "curto": "CHARM", "preco": 150, "nome": "Charm, maço", "marca": "Charm", "cat": &"cigarro", "forma": Forma.MACO, "cm": Vector3(5.6, 8.8, 2.2), "onde": Onde.BALCAO, "idade": 18},
]

static var _indice: Dictionary = {}


## O produto pelo id, ou vazio.
static func produto(id: StringName) -> Dictionary:
	if _indice.is_empty():
		for i in PRODUTOS.size():
			_indice[PRODUTOS[i]["id"]] = i
	var i: int = _indice.get(id, -1)
	return PRODUTOS[i] if i >= 0 else {}


static func existe(id: StringName) -> bool:
	return not produto(id).is_empty()


## Todos os ids de uma categoria, na ordem da tabela.
static func da_categoria(cat: StringName) -> Array[StringName]:
	var saida: Array[StringName] = []
	for p: Dictionary in PRODUTOS:
		if p["cat"] == cat:
			saida.append(p["id"])
	return saida


## Onde o produto pode ficar. AMBOS responde sim para geladeira e prateleira.
static func cabe_em(id: StringName, onde: Onde) -> bool:
	var p := produto(id)
	if p.is_empty():
		return false
	var o: int = p["onde"]
	if o == onde:
		return true
	return o == Onde.AMBOS and (onde == Onde.GELADEIRA or onde == Onde.PRATELEIRA)


## Tamanho em metros.
static func medida(id: StringName) -> Vector3:
	return Vector3(produto(id).get("cm", Vector3(8, 10, 5))) * 0.01


static func preco(id: StringName) -> int:
	return int(produto(id).get("preco", 0))


## "R$ 1,49". Centavos sempre com dois digitos, milhar com ponto.
static func reais(centavos: int) -> String:
	var sinal := "-" if centavos < 0 else ""
	var c := absi(centavos)
	var inteiro := str(c / 100)
	var com_ponto := ""
	while inteiro.length() > 3:
		com_ponto = "." + inteiro.right(3) + com_ponto
		inteiro = inteiro.left(inteiro.length() - 3)
	return "%sR$ %s%s,%02d" % [sinal, inteiro, com_ponto, c % 100]


## A validade impressa numa unidade, ou vazio para quem nao perece.
##
## `sorteio` de 0 a 1 espalha as unidades da mesma vaga: nem todo iogurte da
## geladeira venceu no mesmo dia, e o que vence primeiro fica na frente (e
## assim que se repoe, e e assim que o freguês esperto procura o de tras).
static func validade(id: StringName, sorteio: float) -> String:
	var dias := int(produto(id).get("validade", 0))
	if dias <= 0:
		return ""
	var t := Time.get_unix_time_from_datetime_dict({
		"year": HOJE.z, "month": HOJE.y, "day": HOJE.x, "hour": 12})
	t += int(roundf(float(dias) * lerpf(0.25, 1.0, clampf(sorteio, 0.0, 1.0)))) * 86400
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%02d/%02d/%02d" % [d["day"], d["month"], int(d["year"]) % 100]
