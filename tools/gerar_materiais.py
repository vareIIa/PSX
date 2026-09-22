#!/usr/bin/env python3
"""Gera os ShaderMaterial .tres a partir de uma tabela unica.

Material escrito na mao vira drift: um esquece o use_affine, outro poe uv_tile
diferente sem motivo. A tabela e a fonte da verdade, o .tres e derivado.

    python tools/gerar_materiais.py
"""

import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DESTINO = RAIZ / "game" / "resources" / "materials"
TEXTURAS = RAIZ / "game" / "assets" / "textures"

MODELO_CONE = '''[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/psx_light_cone.gdshader" id="1_shader"]

[resource]
resource_name = "mat_{nome}"
render_priority = 1
shader = ExtResource("1_shader")
shader_parameter/cor = Color(1, 1, 1, 1)
shader_parameter/intensidade = 1.0
shader_parameter/fade_inicio = 12.0
shader_parameter/fade_fim = 26.0
shader_parameter/fade_perto = 1.2
shader_parameter/snap_resolution = Vector2(240, 135)
shader_parameter/use_snap = true
'''

MODELO_MARCA = '''[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/psx_marca.gdshader" id="1_shader"]

[resource]
resource_name = "mat_{nome}"
render_priority = 3
shader = ExtResource("1_shader")
shader_parameter/cor = Color(0.22, 0.2, 0.19, 1)
shader_parameter/forca = 0.9
shader_parameter/fade_inicio = 26.0
shader_parameter/fade_fim = 40.0
shader_parameter/snap_resolution = Vector2(240, 135)
shader_parameter/use_snap = true
'''

MODELO_FUMACA = '''[gd_resource type="ShaderMaterial" load_steps=3 format=3]

[ext_resource type="Shader" path="res://shaders/psx_fumaca.gdshader" id="1_shader"]
[ext_resource type="Texture2D" path="res://assets/textures/casa_atlas.png" id="2_tex"]

[resource]
resource_name = "mat_{nome}"
render_priority = 2
shader = ExtResource("1_shader")
shader_parameter/albedo_tex = ExtResource("2_tex")
shader_parameter/cor = Color({cor}, 1)
shader_parameter/densidade = {densidade}
shader_parameter/deriva = Vector2({deriva})
shader_parameter/celula = Vector4({celula})
shader_parameter/fade_de_raspao = {raspao}
shader_parameter/fade_inicio = {perto}
shader_parameter/fade_fim = {longe}
shader_parameter/fade_perto = 0.55
shader_parameter/snap_resolution = Vector2(240, 135)
shader_parameter/use_snap = true
'''

# As camadas de fumaca. Sao materiais e nao um so porque a deriva de cada uma e
# diferente: a do teto anda de lado, devagar, e a que sobe de um cigarro sobe.
#
# render_priority 2 poe as duas DEPOIS do facho de luz, que ja e 1. Fumaca
# desenhada antes do facho recebe o brilho dele por cima e vira uma mancha
# clara; desenhada depois, ela vela o facho, que e o que acontece de verdade
# num quarto com fumaca e uma luz acesa.
# Celulas de 32 num atlas de 256: cada uma ocupa 1/8 da UV.
_C = 32.0 / 256.0

FUMACAS: dict[str, tuple[str, float, str, str, float, float, float]] = {
    # nome              cor              densid  deriva          celula          perto longe
    "fumaca_teto":   ("0.92, 0.84, 0.72", 0.88, "0.010, 0.004",
                      f"0, {4 * _C}, {_C}, {_C}", 6.0, 12.0, 0.0),
    # Deriva positiva em Y faz o desenho SUBIR na placa: em placa_dados a UV
    # vertical decresce para cima, entao somar em v traz para o olho o que
    # estava embaixo. Com o sinal trocado a fumaca desce, que foi o primeiro
    # resultado aqui.
    "fumaca_baseado": ("0.94, 0.88, 0.78", 1.35, "0.0, 0.30",
                       f"{2 * _C}, {4 * _C}, {_C}, {_C}", 3.5, 8.0, 1.0),
    # Nao e fumaca, e usa o mesmo shader — e o unico material translucido do
    # projeto e o que os olhos vermelhos precisam e exatamente isso: um veu
    # colado no rosto que MISTURA com a pele em vez de recortar.
    #
    # Com recorte por alfa o vermelho entra cheio onde passa do limiar e some
    # onde nao passa, e o resultado sao duas manchas chapadas de tinta na cara.
    # Com mistura, o olho fica avermelhado, que e o que se queria.
    "olhos_vermelhos": ("0.96, 0.90, 0.88", 0.52, "0.0, 0.0",
                        f"{1 * _C}, {4 * _C}, {_C}, {_C}", 2.8, 5.5, 1.0),
    # Fumaca de pneu. Mesma celula da fumaca do teto — bafo cinza sem desenho
    # reconhecivel, que e o que ela precisa ser — com tres diferencas:
    #
    #   cor       puxa para o cinza. Fumaca de borracha queimada nao e branca de
    #             vapor; num jogo em que tudo e cinza, a que for branca demais
    #             vira um buraco claro no meio da rua.
    #   deriva    quase nada. As outras duas sao placas PARADAS e a UV correndo
    #             e o unico movimento que elas tem; esta e um bafo que voa pelo
    #             mundo, entao o movimento ja esta na geometria — ver
    #             `RastroPneu._superficie_fumaca`. Com deriva cheia o desenho
    #             escorrega DENTRO de um bafo que ja esta se mexendo, e o
    #             resultado le como ruido de video.
    #   raspao    zero. As placas do bafo sao viradas para a camera de qualquer
    #             angulo, entao o fade de raspao nunca teria o que cortar.
    #
    # Longe: 26 m. A fumaca sai do pneu do carro que o jogador esta dirigindo e
    # e vista de 6 m de camera; passar disso e outra pessoa derrapando, e nao
    # tem nenhuma.
    "fumaca_pneu":   ("0.78, 0.76, 0.74", 1.05, "0.0, 0.02",
                      f"0, {4 * _C}, {_C}, {_C}", 14.0, 26.0, 0.0),
}

MODELO = '''[gd_resource type="ShaderMaterial" load_steps=3 format=3]

[ext_resource type="Shader" path="res://shaders/{shader}.gdshader" id="1_shader"]
[ext_resource type="Texture2D" path="res://assets/textures/{tex}.png" id="2_tex"]

[resource]
resource_name = "mat_{nome}"
shader = ExtResource("1_shader")
shader_parameter/albedo_tex = ExtResource("2_tex")
shader_parameter/tint = Color({tint}, 1)
shader_parameter/uv_tile = Vector2({tile}, {tile})
shader_parameter/snap_resolution = Vector2(240, 135)
shader_parameter/use_snap = {snap}
shader_parameter/use_affine = {affine}
shader_parameter/alpha_cutoff = {recorte}
shader_parameter/emission_color = Color({emis}, 1)
shader_parameter/emission_energy = {energia}
shader_parameter/vento_forca = {vento}
shader_parameter/vento_velocidade = {vento_vel}
'''

# uv_tile multiplica a UV que o PSXMesh ja gera a 0.5 por metro. Ou seja, o
# numero de repeticoes por metro e 0.5 * uv_tile:
#   uv_tile 1.0  -> um tile a cada 2 m
#   uv_tile 0.5  -> um tile a cada 4 m
# O PS1 trabalhava perto de 32 a 64 pixels por metro. Com textura de 256 px,
# um tile a cada 4 m da 64 px/m, que e o alvo.
#
# nome                textura              uv_tile  tint                 snap     affine
MATERIAIS = [
    # --- chao e rua ---
    ("asfalto",          "asfalto",           0.5, "1, 1, 1",            "true",  "true"),
    ("asfalto_remendo",  "asfalto_remendo",   0.5, "1, 1, 1",            "true",  "true"),
    ("asfalto_faixa",    "asfalto_faixa",     0.5, "1, 1, 1",            "true",  "true"),
    ("calcada",          "calcada",           0.6, "1, 1, 1",            "true",  "true"),
    ("calcada_ladrilho", "calcada_ladrilho",  0.6, "1, 1, 1",            "true",  "true"),
    ("meio_fio",         "meio_fio",          1.0, "1, 1, 1",            "true",  "true"),
    ("terra",            "terra",             0.5, "1, 1, 1",            "true",  "true"),
    # Rua de pedra de bairro de casas (Tracado). Tile a cada 1,6 m: a fiada de
    # granito sai com uns 20 cm, que e o paralelepipedo de verdade. Textura de
    # tools/importar_paralelepipedo.py.
    ("paralelepipedo",   "paralelepipedo",    1.25, "1, 1, 1",           "true",  "true"),
    # --- Estrada Velha ---
    # Os dois materiais da cutscene de abertura. Estavam FORA desta tabela, e
    # fora dela o proprio gerador os apagava: o laco de orfaos no fim do main
    # faz unlink em todo mat_*.tres que ele nao escreveu. Rodar este script
    # apagava a terra e o mato da Estrada Velha, e o primeiro minuto do jogo
    # ficava sem chao ate alguem reparar.
    #
    # O leito usa o atlas do mato porque as celulas de barro, cascalho, poca e
    # folhico moram nele (ver KitEstrada.C_*), e nao porque ele seja mato.
    # `use_affine` desligado: o quad do leito tem 1,8 m e e visto rasante, que
    # e o caso em que a UV afim escorre de forma visivel (ART-BIBLE secao 4).
    ("leito",            "mato_atlas",        1.0, "1.04, 0.73, 0.51",   "true",  "false"),
    ("mato",             "mato_atlas",        1.0, "0.72, 0.86, 0.58",   "false", "false"),
    # --- paredes externas ---
    ("concreto",         "concreto_parede",   0.6, "1, 1, 1",            "true",  "true"),
    ("concreto_sujo",    "concreto_sujo",     0.6, "1, 1, 1",            "true",  "true"),
    ("azulejo",          "azulejo_fachada",   0.8, "1, 1, 1",            "true",  "true"),
    ("tijolo",           "tijolo",            0.8, "1, 1, 1",            "true",  "true"),
    ("metal_ondulado",   "metal_ondulado",    1.0, "1, 1, 1",            "true",  "true"),
    ("metal_enferrujado","metal_enferrujado", 1.0, "1, 1, 1",            "true",  "true"),
    # --- interiores ---
    ("piso",             "piso_madeira",      0.7, "1, 1, 1",            "true",  "true"),
    ("piso_ceramico",    "piso_ceramico",     0.7, "1, 1, 1",            "true",  "true"),
    ("reboco",           "reboco",            0.6, "1, 1, 1",            "true",  "true"),
    # Teto e o mesmo reboco rebaixado por tint. E a economia descrita na skill
    # psx-assets: variar material sem multiplicar arquivo de textura.
    ("teto",             "reboco",            0.6, "0.62, 0.61, 0.57",   "true",  "true"),
    ("personagem",       "reboco",            1.4, "1, 1, 1",            "true",  "true"),
    ("tabua",            "madeira_tabua",     1.0, "1, 1, 1",            "true",  "true"),
    # Gente. uv_tile 1.0 e obrigatorio, e nao escolha: a UV do corpo ja sai do
    # Corpo em coordenada de atlas, apontando para a celula certa do rosto ou da
    # camisa. Qualquer outro valor multiplica isso e a pessoa passa a vestir
    # pedacos aleatorios das outras celulas.
    ("npc",              "npc_atlas",         1.0, "1, 1, 1",            "true",  "true"),
    ("porta",            "porta",             1.0, "1, 1, 1",            "true",  "true"),
    # --- transito ---
    # Mesma regra do npc, e pela mesma razao: a UV do carro ja sai da Carroceria
    # em coordenada de atlas, apontando para a celula da lataria, do vidro ou do
    # pneu. uv_tile diferente de 1,0 multiplicaria isso e cada carro passaria a
    # vestir pedacos das celulas vizinhas.
    ("carro",            "carro_atlas",       1.0, "1, 1, 1",            "true",  "true"),
    # --- casa da fumaca ---
    # Mesma regra do npc e do carro: a UV ja sai do builder em coordenada de
    # atlas, entao uv_tile 1,0 e obrigatorio e nao escolha.
    ("casa",             "casa_atlas",        1.0, "1, 1, 1",            "true",  "true"),
    # Baseado e saquinho tem margem transparente na celula. Recorte, e nao
    # mistura: sem lista de transparentes nao ha ordenacao para errar.
    ("casa_recorte",     "casa_atlas",        1.0, "1, 1, 1",            "true",  "true"),
    # A pichacao da fachada da casa da fumaca: textura de pixo com alfa, uma
    # placa so. Ver tools/gerar_pichacao.py.
    ("pichacao",         "pichacao",          1.0, "1, 1, 1",            "true",  "true"),
    # A tela da TV nao arredonda vertice. E painel colado no gabinete, e com o
    # snap os dois caem no mesmo pixel e passam um na frente do outro a cada
    # passo do jogador — o defeito que a vitrine do mercado ja teve.
    ("casa_tela",        "casa_atlas",        1.0, "1, 1, 1",            "false", "true"),
    ("casa_brasa",       "casa_atlas",        1.0, "1, 1, 1",            "false", "true"),
    # Farol e lanterna. Nao arredondam vertice: sao painel colado na lataria e,
    # com o snap, painel e caixa caem no mesmo pixel e passam um na frente do
    # outro a cada passo — o mesmo defeito que a vitrine do mercado teve.
    # --- estufa ---
    # Mesmo atlas da casa, linhas 5 e 6. Quatro materiais porque quatro coisas
    # diferentes acontecem com aqueles pixels: superficie opaca, recorte por
    # alfa, recorte QUE BALANCA, e emissao.
    ("estufa",           "casa_atlas",        1.0, "1, 1, 1",            "true",  "true"),
    ("estufa_recorte",   "casa_atlas",        1.0, "1, 1, 1",            "true",  "true"),
    # A folhagem e o unico material do jogo que recorta E balanca ao mesmo
    # tempo. Ver VENTO: a forca e um quinto da arvore da rua, porque o que
    # sopra aqui e um ventilador de parede e nao o vento da avenida.
    ("estufa_folha",     "casa_atlas",        1.0, "1, 1, 1",            "true",  "true"),
    # A lente da luminaria. Nao arredonda vertice pela mesma razao da tela da
    # TV: e um painel colado no capuz, e com o snap os dois caem no mesmo pixel
    # e passam um na frente do outro a cada passo do jogador.
    ("estufa_luz",       "casa_atlas",        1.0, "1, 1, 1",            "false", "true"),
    # Os quadros, a chapa do elevador e as placas do andar 10. Atlas proprio,
    # desenhado por tools/gerar_quadros_maconha.py; UV ja sai em coordenada
    # de atlas, entao uv_tile 1,0.
    ("estufa_quadros",   "estufa_quadros",    1.0, "1, 1, 1",            "true",  "true"),
    ("carro_luz",        "carro_atlas",       1.0, "1, 1, 1",            "false", "true"),
    ("semaforo_luz",     "carro_atlas",       1.0, "1, 1, 1",            "false", "true"),
    # --- loja de conveniencia ---
    # As prateleiras, a geladeira, o letreiro e o vidro sao imagens em painel,
    # montadas com PSXMesh.placa_dados, cuja UV ja vai de 0 a 1. Por isso
    # uv_tile e 1.0: qualquer outro valor repetiria a imagem dentro do painel.
    #
    # E por isso que nenhum deles arredonda vertice.
    #
    # Painel colado numa estrutura e o caso em que o snap trabalha contra: a
    # placa e a caixa atras dela sao malhas diferentes, o arredondamento para a
    # grade de 240x135 leva as duas para o mesmo pixel, e a cada passo do
    # jogador uma passa na frente da outra. O resultado e a prateleira piscando
    # e a parede aparecendo atraves do vidro.
    #
    # A estrutura de metal ja nao arredonda, pelo mesmo motivo descrito no
    # ART-BIBLE secao 3. O painel tem de seguir a estrutura em que esta pregado.
    ("mercado_prateleira_0", "mercado_prateleira_0", 1.0, "1, 1, 1",      "false", "true"),
    ("mercado_prateleira_1", "mercado_prateleira_1", 1.0, "1, 1, 1",      "false", "true"),
    ("mercado_prateleira_2", "mercado_prateleira_2", 1.0, "1, 1, 1",      "false", "true"),
    ("mercado_geladeira",    "mercado_geladeira",    1.0, "1, 1, 1",      "false", "true"),
    ("mercado_letreiro",     "mercado_letreiro",     1.0, "1, 1, 1",      "false", "true"),
    ("mercado_secao",        "mercado_secao",        1.0, "1, 1, 1",      "false", "true"),
    # Textura propria. Reciclar o teto tingido de ciano fazia a vitrine ler
    # como ladrilho de forro — e, da rua, como porta de enrolar fechada.
    ("mercado_vidro",        "mercado_vidro",        1.0, "1, 1, 1",      "false", "true"),
    # Piso e teto sao a casca do comodo, nao painel pregado em nada: continuam
    # arredondando, que e a assinatura da imagem.
    ("mercado_piso",         "mercado_piso",         0.7, "1, 1, 1",      "true",  "true"),
    ("mercado_teto",         "mercado_teto",         0.5, "1, 1, 1",      "true",  "true"),
    # --- bloco de servico: garagem, corredor, banheiro e copa ---
    # Mesma divisao de sempre. Azulejo e papelao sao SUPERFICIE e repetem, entao
    # arredondam junto com a casca; quadro de avisos, estante de estoque, folha
    # de portao e a tela do monitor sao IMAGEM pregada numa estrutura de metal
    # que ja nao arredonda, e teriam de piscar contra ela se arredondassem.
    ("mercado_azulejo",      "mercado_azulejo",      1.6, "1, 1, 1",      "true",  "true"),
    ("mercado_papelao",      "mercado_papelao",      1.0, "1, 1, 1",      "true",  "true"),
    ("mercado_avisos",       "mercado_avisos",       1.0, "1, 1, 1",      "false", "true"),
    ("mercado_estoque",      "mercado_estoque",      1.0, "1, 1, 1",      "false", "true"),
    ("mercado_portao",       "mercado_portao",       1.0, "1, 1, 1",      "false", "true"),
    ("mercado_terminal",     "mercado_terminal",     1.0, "1, 1, 1",      "false", "true"),
    # --- fontes de luz propria, a assinatura da rua noturna ---
    ("vitrine",          "azulejo_fachada",   1.1, "1, 1, 1",            "true",  "true"),
    ("maquina_venda",    "calcada_ladrilho",  1.4, "1, 1, 1",            "true",  "true"),
    ("janela_acesa",     "calcada_ladrilho",  1.6, "1, 0.94, 0.8",       "true",  "true"),
    # A bandeira acima da porta da casa da fumaca. E a mesma vidraca da janela
    # comum com outra cor, e a cor e o assunto: numa rua inteira de vidro amber,
    # UM vao magenta diz que naquela casa alguem trocou a lampada de proposito.
    # E o mesmo magenta da lampada do canto do som la dentro.
    ("janela_fumaca",    "vidro_canelado",    1.6, "0.86, 0.62, 0.92",   "true",  "true"),
    # Vitro de banheiro e porta de cozinha de ferro (FundosVivos): o vidro
    # canelado sem luz propria, cinza-esverdeado, que nao deixa ver dentro.
    ("vidro_canelado",   "vidro_canelado",    1.6, "0.62, 0.68, 0.66",   "true",  "true"),
    ("letreiro",         "azulejo_fachada",   1.6, "1, 1, 1",            "true",  "true"),
    ("janela_apagada",   "metal",             1.2, "0.14, 0.16, 0.18",   "true",  "true"),
    # --- parque ---
    # Nada aqui arredonda vertice, e por dois motivos diferentes. A folhagem
    # porque ela ja se mexe: somar o arredondamento ao balanco faz a copa
    # tremer em vez de balancar. A casca porque ela e uma peca fina colada na
    # folhagem — mesmo caso do painel de prateleira do mercado, ART-BIBLE
    # secao 3.
    ("grama",            "grama",             0.5, "1, 1, 1",            "true",  "true"),
    # uv_tile baixo de proposito. A UV ja sai a 0.8 por metro do box_dados, entao
    # 0.6 poe um tile a cada 2,1 m e o aglomerado de folha da textura vira uma
    # folha de uns 18 cm no mundo, que e o tamanho certo. Mais tile deixaria a
    # folha do tamanho de uma moeda e a copa voltaria a ser ruido.
    ("folhagem",         "folhagem",          0.6, "1, 1, 1",            "false", "true"),
    # O recorte e o que tira a silhueta de caixa da copa. Ver RECORTE abaixo.
    ("folhagem_recorte", "folhagem_recorte",  0.5, "1, 1, 1",            "false", "true"),
    ("arbusto",          "folhagem_recorte",  0.8, "0.92, 0.96, 0.9",    "false", "true"),
    ("casca",            "casca",             1.1, "1, 1, 1",            "false", "true"),
    ("areia",            "areia",             0.5, "1, 1, 1",            "true",  "true"),
    ("pedra_parque",     "pedra_parque",      0.6, "1, 1, 1",            "true",  "true"),
    ("agua",             "agua",              0.4, "1, 1, 1",            "true",  "true"),
    # Corrente de balanco: metal que cede ao vento. Textura de metal, snap e
    # afim desligados pelo mesmo motivo do metal comum.
    ("corrente",         "metal",             1.0, "1, 1, 1",            "false", "false"),
    ("toldo",            "toldo",             0.7, "1, 1, 1",            "true",  "true"),
    ("placa_parque",     "placa_parque",      1.0, "1, 1, 1",            "false", "true"),
    # Objeto pequeno e colado na camera: snap nele vira ruido estroboscopico.
    # ART-BIBLE secao 3.
    ("metal",            "metal",             1.0, "1, 1, 1",            "false", "false"),
    # --- fachada viva (JanelaViva, ParedeVazada) ---
    # Pintado: o metal de cima tem albedo 63/255 e a tinta so multiplica, entao
    # ar-condicionado, grade clara e medidor saiam pretos. Base de plastico.
    ("metal_pintado",    "plastico",          1.0, "1, 1, 1",            "false", "false"),
    # A cortina da janela aberta: tecido que cede ao vento (ver VENTO).
    ("cortina",          "tecido",            1.6, "1, 1, 1",            "false", "false"),
    # A lampada do comodo aceso atras da janela aberta. Ver EMISSIVOS.
    ("lampada",          "reboco",            1.0, "1, 1, 1",            "false", "false"),
    # O comodo atras da janela aberta: parede e madeira com um piso de emissao
    # na propria cor (ver EMISSIVOS). Caixa fechada so recebe luz pelo vao, e
    # sem isso o comodo aberto lia como buraco preto.
    ("interior",         "reboco",            0.6, "1, 1, 1",            "false", "false"),
    ("interior_aceso",   "reboco",            0.6, "1, 1, 1",            "false", "false"),
    ("interior_madeira", "madeira_tabua",     1.0, "1, 1, 1",            "false", "false"),
    # O nome pintado na placa da loja: atlas de tools/gerar_letreiros.py, UV de
    # celula ja sai do ComercioVivo, entao uv_tile 1,0.
    ("letreiro_nome",    "letreiros",         1.0, "1, 1, 1",            "false", "false"),
    # O nome da firma pintado na parede do galpao e da oficina (IndustriaViva).
    ("letreiro_industria", "letreiros_industria", 1.0, "1, 1, 1",        "false", "false"),
    # --- bar do ze ---
    # Superficies do salao arredondam (casca). Paineis de imagem (letreiro,
    # toldo, cervejeira, vao, toalha) nao: sao placa colada em estrutura.
    ("bar_piso",         "bar_piso",          0.7, "1, 1, 1",            "true",  "true"),
    ("bar_ladrilho",     "bar_ladrilho",      0.9, "1, 1, 1",            "true",  "true"),
    ("bar_parede",       "bar_parede",        0.6, "1, 1, 1",            "true",  "true"),
    ("bar_teto",         "bar_teto",          0.5, "1, 1, 1",            "true",  "true"),
    ("bar_formica",      "bar_formica",       1.0, "1, 1, 1",            "true",  "true"),
    ("bar_mesa",         "bar_plastico",      1.0, "1, 1, 1",            "false", "true"),
    ("bar_cadeira",      "bar_plastico",      1.0, "1, 1, 1",            "false", "true"),
    ("bar_xadrez",       "bar_xadrez",        1.0, "1, 1, 1",            "false", "true"),
    ("bar_letreiro",     "bar_letreiro",      1.0, "1, 1, 1",            "false", "true"),
    ("bar_toldo",        "bar_toldo",         1.0, "1, 1, 1",            "false", "true"),
    ("bar_cervejeira",   "bar_cervejeira",    1.0, "1, 1, 1",            "false", "true"),
    ("bar_vao",          "bar_vao",           1.0, "1, 1, 1",            "false", "true"),
    ("bar_rua_noite",    "bar_rua_noite",     1.0, "1, 1, 1",            "false", "true"),
    ("bar_cartaz",       "bar_cartaz",        1.0, "1, 1, 1",            "false", "true"),
    ("bar_faixa",        "bar_faixa",         1.0, "1, 1, 1",            "false", "true"),
    ("bar_azulejo",      "bar_azulejo",       1.4, "1, 1, 1",            "true",  "true"),
    ("bar_feltro",       "bar_feltro",        1.6, "1, 1, 1",            "true",  "true"),
    ("bar_cardapio",     "bar_cardapio",      1.0, "1, 1, 1",            "false", "true"),
    ("bar_placa",        "bar_placa",         1.0, "1, 1, 1",            "false", "true"),
    ("bar_salgados",     "bar_salgados",      1.0, "1, 1, 1",            "false", "true"),
]


# Materiais com recorte por alfa, e o limiar de corte.
#
# Alfa aqui nao e transparencia: e tesoura. O fragmento com alfa abaixo do
# limiar simplesmente nao existe, entao nao ha ordenacao, nao ha lista de
# transparentes e nao ha custo de mistura — e como o PS1 fazia folha e grade.
#
# So a folha externa da copa recorta. O nucleo dela continua opaco de proposito:
# recortando os dois, da para ver o ceu pelo meio da arvore.
RECORTE: dict[str, float] = {
    # O mato da estrada e tufo em cruz: sem recorte ele vira duas placas.
    "mato": 0.42,
    "folhagem_recorte": 0.45,
    "arbusto": 0.45,
    # O saquinho tem plastico a 90 de alfa e o conteudo opaco: o limiar tem de
    # ficar abaixo disso, senao o plastico some e sobram os pedacos soltos no ar.
    "casa_recorte": 0.28,
    "pichacao": 0.45,
    "casa_brasa": 0.5,
    # A folha tem de recortar ALTO. Um limiar baixo deixa a franja semi
    # transparente da borda do foliolo virar uma aba retangular em volta da
    # planta, e ai a silhueta que o desenho da celula existe para dar se perde.
    "estufa_folha": 0.5,
    # O pote de vidro tem parede a 90 de alfa, igual ao saquinho: o limiar fica
    # abaixo disso, senao o vidro some e sobram os pedacos boiando.
    "estufa_recorte": 0.3,
}


# Materiais que balancam ao vento. Forca em metros de desvio na ponta, e
# velocidade da onda. Todo o resto fica em zero e nem entra no ramo do shader.
VENTO: dict[str, tuple[float, float]] = {
    # Folha e casca com a MESMA forca de proposito. A forca e a amplitude global
    # e a rigidez por vertice e que decide quanto cada parte cede; com forcas
    # diferentes o topo do tronco anda menos que a base da copa e a arvore se
    # desmancha na junta. Quem separa tronco de copa e o alfa, nao isto.
    # O capim da beira balanca mais que a copa e mais rapido: ele e leve e
    # esta no chao, onde o vento passa raspando.
    "mato":     (0.20, 1.35),
    "folhagem": (0.22, 1.15),
    "folhagem_recorte": (0.22, 1.15),
    "casca":    (0.22, 1.15),
    # Arbusto e baixo e presa no chao: cede menos e vibra mais rapido.
    "arbusto":  (0.10, 1.45),
    # A corrente do balanco vai devagar. Um balanco vazio indo rapido le como
    # alguem empurrando, e a graca e justamente nao haver ninguem.
    "corrente": (0.14, 0.62),
    # Ventilador de parede, e nao vento de rua: curso curto e frequencia alta.
    # Com a forca da arvore, a plantacao inteira ondula como trigo e a sala
    # deixa de ler como comodo fechado.
    "estufa_folha": (0.045, 2.6),
    # A cortina da janela aberta: curso de poucos centimetros, a barra de baixo
    # e que anda (rigidez por vertice, JanelaViva).
    "cortina": (0.035, 1.8),
}


# Materiais que emitem luz propria. Cor e energia da emissao.
EMISSIVOS: dict[str, tuple[str, float]] = {
    # Piso de emissao da terra da Estrada Velha, pelo mesmo motivo do carro e do
    # npc: a cena tem um farol e mais nada de noite, e sem um piso a estrada
    # fora do facho vira um buraco preto.
    #
    # NEUTRO e BAIXO, e os dois adjetivos custaram caro. Era (0,55 0,18 0,06)
    # com energia 0,38 — laranja saturado — calibrado olhando so a noite. De
    # dia, somado a um sol de energia 1,9, a estrada inteira ficava luminosa:
    # o barro virava lava e a mata em volta pegava o quique. Emissao e luz que
    # nao depende do clima, entao ela tem de ser fraca o bastante para caber
    # em TODOS eles.
    "leito":         ("0.5, 0.46, 0.42",  0.14),
    "vitrine":       ("1, 0.93, 0.8",  1.05),
    "maquina_venda": ("1, 0.93, 0.85", 2.0),
    "janela_acesa":  ("1, 0.82, 0.55", 0.95),
    "janela_fumaca": ("0.78, 0.34, 0.86", 2.3),
    "letreiro":      ("1, 0.5, 0.38",  2.2),
    "personagem":    ("0.55, 0.6, 0.62", 0.42),
    # Mesma razao do personagem: sem um piso de emissao, quem sai do facho do
    # poste vira uma silhueta preta e o rosto — que e o trabalho todo do atlas —
    # deixa de existir. Um pouco abaixo do jogador, porque o pedestre esta na
    # rua e nao carrega lanterna.
    "npc":           ("0.52, 0.56, 0.6",  0.34),
    # A lataria tem um piso de emissao pelo mesmo motivo do npc: fora do facho
    # do poste um carro escuro vira um buraco na rua. Bem mais baixo que o do
    # npc, porque o carro tem farol proprio e nao precisa de ajuda para existir.
    "carro":         ("0.46, 0.5, 0.54",   0.22),
    # A sala e escura e a TV e a unica fonte de luz dela. A emissao alta aqui e
    # o que faz o tubo estourar de branco e recortar quem esta sentado na frente
    # — que e a imagem inteira do comodo.
    "casa_tela":     ("0.86, 0.94, 1",     2.1),
    # A brasa do baseado. Ilumina pouco e some quando ninguem traga; quem
    # acende de verdade e a luz do no, que pulsa.
    "casa_brasa":    ("1, 0.52, 0.2",      2.6),
    # Piso de emissao para o resto da mobilia, mesma razao do npc: a sala e
    # iluminada so pela TV, e sem isso o sofa vira um buraco preto.
    "casa":          ("0.4, 0.42, 0.46",   0.2),
    # O recorte precisa de MAIS piso que a mobilia, e nao do mesmo. Sao os
    # objetos pequenos — baseado, saquinho, garrafa — e a sala e escura: sem
    # isto eles saem pretos e a coisa que a pessoa tem na mao vira um borrao.
    "casa_recorte":  ("0.78, 0.74, 0.66",  0.95),
    # Farol e lanterna sao acesos pelo codigo: a energia aqui e so o valor de
    # repouso, e o Carro sobe para 2,4 quando o motor liga.
    # A estufa e clara, entao o piso de emissao aqui e baixo: serve so para o
    # canto sem luminaria em cima nao virar buraco preto.
    "estufa":         ("0.5, 0.52, 0.5",    0.16),
    "estufa_recorte": ("0.6, 0.62, 0.58",   0.26),
    # A folha ganha um pouco mais, e esverdeado: e o rebote da luz na massa de
    # folha, que num canteiro cheio e a diferenca entre planta e silhueta preta.
    "estufa_folha":   ("0.42, 0.58, 0.36",  0.34),
    # A lente. Alta pelo mesmo motivo da tela da TV: e a fonte de luz visivel do
    # comodo, e tem de estourar de branco quando o jogador olha para cima.
    "estufa_luz":     ("1, 0.93, 0.76",     2.4),
    "estufa_quadros": ("0.5, 0.5, 0.5",     0.12),
    "carro_luz":     ("1, 0.94, 0.84",     0.08),
    "semaforo_luz":  ("1, 1, 1",           0.05),
    # A loja e a unica fonte de luz branca e fria do jogo. Tudo mais na rua e
    # sodio alaranjado ou nevoa cinza, entao a vitrine acesa puxa o olho de
    # longe, que e exatamente o papel dela.
    "mercado_geladeira": ("0.72, 0.86, 1",    1.15),
    "mercado_letreiro":  ("1, 0.98, 0.92",    2.4),
    "mercado_secao":     ("1, 1, 0.98",       1.3),
    "mercado_vidro":     ("0.9, 0.96, 1",     1.5),
    # O monitor do balcao. Emissao alta pela mesma razao da televisao: e a unica
    # coisa acesa de um comodo iluminado por fluorescente branca, e se nao
    # estourar um pouco ele le como painel cinza colado na mesa em vez de tubo
    # ligado. O jogador tem de ver de longe que ha ALGO ligado ali.
    "mercado_terminal":  ("0.72, 0.84, 1",    1.9),
    # A agua do chafariz nao emite: ela devolve. Uma pitada de emissao e o unico
    # jeito barato de o tanque nao virar um buraco preto no meio da praca.
    "agua":              ("0.42, 0.55, 0.62", 0.35),
    # Bar: o letreiro e o que puxa o olho na nevoa. Cervejeira emite baixo,
    # toldo um pouco, vao so o vazamento quente do topo.
    "bar_letreiro":      ("1, 0.92, 0.45",    2.6),
    "bar_toldo":         ("0.9, 0.35, 0.22",  0.45),
    "bar_cervejeira":    ("0.7, 0.84, 1",     0.85),
    "bar_vao":           ("0.55, 0.32, 0.12", 0.55),
    "bar_rua_noite":     ("0.5, 0.4, 0.26",   0.5),
    "bar_cartaz":        ("0.4, 0.55, 0.3",   0.35),
    "bar_faixa":         ("1, 0.5, 0.28",     1.4),
    "bar_cardapio":      ("0.9, 0.86, 0.7",   0.3),
    "bar_placa":         ("0.9, 0.86, 0.7",   0.25),
    "bar_salgados":      ("1, 0.82, 0.5",     0.45),
    # A lampada do comodo atras da janela aberta: o bulbo que se ve da rua.
    "lampada":           ("1, 0.86, 0.62",    2.6),
    "interior":          ("1, 0.97, 0.92",    0.24),
    "interior_aceso":    ("1, 0.84, 0.6",     0.85),
    "interior_madeira":  ("1, 0.95, 0.9",     0.2),
}


def main() -> int:
    podar = "--podar" in sys.argv
    DESTINO.mkdir(parents=True, exist_ok=True)
    existentes = {p.stem for p in DESTINO.glob("mat_*.tres")}
    gerados: set[str] = set()
    faltando: list[str] = []

    # O facho de luz nao usa psx_surface: ele e somado, nao iluminado.
    (DESTINO / "mat_cone_luz.tres").write_text(
        MODELO_CONE.format(nome="cone_luz"), encoding="utf-8")
    gerados.add("mat_cone_luz")
    print("mat_cone_luz         <- psx_light_cone.gdshader")

    # A marca de pneu tambem nao usa psx_surface: ela MULTIPLICA o asfalto em
    # vez de ser iluminada por cima dele. Ver o cabecalho do shader.
    (DESTINO / "mat_marca_pneu.tres").write_text(
        MODELO_MARCA.format(nome="marca_pneu"), encoding="utf-8")
    gerados.add("mat_marca_pneu")
    print("mat_marca_pneu       <- psx_marca.gdshader")

    for nome, dados in FUMACAS.items():
        cor, densidade, deriva, celula, perto, longe, raspao = dados
        (DESTINO / f"mat_{nome}.tres").write_text(
            MODELO_FUMACA.format(nome=nome, cor=cor, densidade=densidade,
                                 deriva=deriva, celula=celula, perto=perto,
                                 longe=longe, raspao=raspao),
            encoding="utf-8")
        gerados.add(f"mat_{nome}")
        print(f"mat_{nome:16s} <- psx_fumaca.gdshader")

    for nome, tex, tile, tint, snap, affine in MATERIAIS:
        if not (TEXTURAS / f"{tex}.png").exists():
            faltando.append(f"mat_{nome} -> {tex}.png")
            continue
        alvo = DESTINO / f"mat_{nome}.tres"
        emis, energia = EMISSIVOS.get(nome, ("0, 0, 0", 0.0))
        vento, vento_vel = VENTO.get(nome, (0.0, 1.0))
        recorte = RECORTE.get(nome, 0.0)
        alvo.write_text(MODELO.format(shader="psx_surface", nome=nome, tex=tex, tile=f"{tile:g}",
                                      tint=tint, snap=snap, affine=affine,
                                      emis=emis, energia=f"{energia:g}",
                                      vento=f"{vento:g}", vento_vel=f"{vento_vel:g}",
                                      recorte=f"{recorte:g}"),
                        encoding="utf-8")
        gerados.add(alvo.stem)
        print(f"mat_{nome:18s} <- {tex}.png   uv_tile {tile:g}")

    orfaos = sorted(existentes - gerados)
    if orfaos and not podar:
        # AVISA, e nao apaga. O padrao era apagar, e apagar por padrao ja custou
        # caro tres vezes: quem roda este script para acrescentar UM material
        # perde todo .tres que outra frente criou a mao e ainda nao listou aqui.
        # Na ultima vez foram doze arquivos de cinco frentes diferentes --
        # painel do carro, sinais de pedestre, cigarro, agua do lago -- e o
        # estrago so apareceu quando o jogo abriu sem painel.
        #
        # O laco existia por um motivo legitimo: material renomeado deixa lixo.
        # Mas lixo e barato e arquivo de outra pessoa nao, e a assimetria entre
        # os dois precos e o que decide quem e o padrao.
        print("")
        print("fora da tabela (NAO apagados; use --podar para remover):")
        for orfao in orfaos:
            print("  ", orfao)
    elif orfaos:
        for orfao in orfaos:
            (DESTINO / f"{orfao}.tres").unlink()
            print(f"removido {orfao}.tres (--podar)")

    if faltando:
        print("\ntextura ausente para:")
        for f in faltando:
            print("  ", f)
        return 1

    print(f"\n{len(gerados)} materiais")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
