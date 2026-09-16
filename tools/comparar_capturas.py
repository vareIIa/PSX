"""Compara duas capturas ignorando o ruido animado do pos-processamento.

Por que nao comparar pixel a pixel
----------------------------------
O grao do pos-processamento e ruido animado de fase livre: entre duas execucoes
ele muda em quase todo pixel sem que nada na cena tenha mudado. Medido pixel a
pixel, duas execucoes da MESMA build no MESMO quadro dao 45% de pixels
diferentes, e qualquer teste de aceite construido sobre isso e inutil.

A media em blocos de 4x4 separa as duas coisas porque elas se comportam de forma
oposta na media: ruido de media zero cancela, e diferenca de estrutura — uma
sombra que apareceu, um facho que mudou de forma, uma cor que andou — sobrevive
inteira. Com blocos, duas execucoes da mesma build caem para 1,2%.

Procedimento do aceite do PS1 STYLE
-----------------------------------
A pergunta que este aceite responde e sobre o INTERRUPTOR, e nao sobre o rumo do
jogo: quando o jogador liga PS1 STYLE nas opcoes, ele recebe o jogo de antes da
migracao ou uma imitacao dele? O padrao do jogo continua sendo MODERNO.

  1. Criar a base num worktree, que nao encosta no trabalho de ninguem:
         git worktree add --detach /tmp/base <commit anterior a migracao>
         godot --headless --path /tmp/base/game --import

  2. Igualar a CONFIGURACAO das duas builds. Este e o passo que engana: a build
     antiga le `user://settings.cfg`, e a nova recebe `--estilo=ps1` na linha de
     comando. Com o config do usuario em MODERNO, a comparacao acusou 61% de
     diferenca que era so dither, scanline e vinheta — configuracao, nao build.
     Faca copia do settings.cfg, escreva os valores do preset PS1_STYLE
     (ESTILO_PRESETS em src/systems/settings.gd) e devolva a copia no fim.

  3. Escolher cena com dependencias LIMPAS. `scenes/test/rua_teste.tscn` serve:
     semente fixa, camera fixa em (0, 0, -3), e nenhum dos arquivos que ela usa
     estava modificado por outra frente. Capturar duas vezes de cada lado — a
     primeira execucao importa e monta, e nao vale.

  4. Comparar SEMPRE tres pares, nunca so um:
         base x base       -> o piso de ruido da bancada
         agora x agora     -> o piso de ruido da build nova
         base x agora      -> a medida que interessa
     Sem os dois primeiros nao ha como saber se o terceiro e sinal ou ruido.

  5. Para separar renderizador de codigo, repetir o terceiro par com a build
     nova rodando `--rendering-method gl_compatibility`.

Resultado medido em 2026-09-15, rua_teste no quadro 240:

     ruido da bancada                      1,13/255    1,19% dos blocos
     base PS1 x hoje, MESMO renderizador   1,28/255    2,70% dos blocos
     base PS1 x hoje, Vulkan               7,32/255   31,85% dos blocos

Ou seja: no mesmo renderizador o PS1 STYLE de hoje reproduz a build anterior
dentro do ruido da propria bancada. Toda a diferenca restante e a migracao para
Forward+, que e deliberada.

O que sao os 31,85% do Vulkan, e por que nao se persegue zero
-------------------------------------------------------------
Trocando SO o renderizador, com o mesmo codigo, da 31,89% — ou seja, o codigo
nao responde por nada. E a diferenca e espacial, nao global: medindo por faixa
de tela no mesmo par,

     faixa sem facho nenhum ....... 1,04% dos blocos
     faixa com facho .............. 69,12% dos blocos

Um por cento esta ABAIXO do piso de ruido de 1,19%: onde nao ha luz de ponto, os
dois renderizadores sao o mesmo quadro. Toda a divergencia mora onde ha luz.

A causa nao e um recurso faltando. O Forward+ acumula mistura aditiva e ilumina
superficie em espaco linear; o Compatibility fazia as duas coisas em sRGB. No
miolo do facho: 39,9 contra 69,2, com a parede fora do facho em 93,0 contra 93,4.

Perseguir zero foi tentado e abandonado com medida. Um ganho global no facho
geometrico, ajustado para 0,50, derrubou o erro medio de 7,32 para 4,45 — e os
blocos diferentes so de 31,85% para 29,18%. A area quase nao se move porque o
cone e apenas a parte VISIVEL da divergencia; a superficie iluminada por baixo
dele tambem muda. Igualar exigiria reafinar cada luz do jogo para o caminho PS1,
para imitar o comportamento menos correto dos dois. O mecanismo foi removido.

O criterio de aceite, portanto, e duplo:

     mesmo renderizador ... <= 3% de blocos. E o contrato do CODIGO, e o que
                              precisa continuar valendo a cada mudanca.
     Vulkan ............... ~32%, concentrados em area iluminada. E o preco
                              conhecido da migracao. O numero importa como
                              VIGIA: se subir muito, ou se passar a aparecer na
                              faixa sem facho, ai ha regressao de verdade.

Uso:
    python tools/comparar_capturas.py a.png b.png [limiar]
"""
import struct
import sys
import zlib

BLOCO = 4


def ler(caminho: str):
    dados = open(caminho, "rb").read()
    assert dados[:8] == b"\x89PNG\r\n\x1a\n", "%s nao e PNG" % caminho
    i, largura, altura, tipo, idat = 8, 0, 0, 2, b""
    while i < len(dados):
        tam = struct.unpack(">I", dados[i:i + 4])[0]
        marca = dados[i + 4:i + 8]
        corpo = dados[i + 8:i + 8 + tam]
        if marca == b"IHDR":
            largura, altura, prof, tipo = struct.unpack(">IIBB", corpo[:10])
            assert prof == 8, "so 8 bits por canal"
        elif marca == b"IDAT":
            idat += corpo
        i += 12 + tam
    cru = zlib.decompress(idat)
    canais = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[tipo]
    passo = largura * canais
    saida = bytearray()
    anterior = bytearray(passo)
    pos = 0
    for _ in range(altura):
        filtro = cru[pos]
        pos += 1
        linha = bytearray(cru[pos:pos + passo])
        pos += passo
        for x in range(passo):
            a = linha[x - canais] if x >= canais else 0
            b = anterior[x]
            c = anterior[x - canais] if x >= canais else 0
            if filtro == 1:
                linha[x] = (linha[x] + a) & 255
            elif filtro == 2:
                linha[x] = (linha[x] + b) & 255
            elif filtro == 3:
                linha[x] = (linha[x] + (a + b) // 2) & 255
            elif filtro == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                linha[x] = (linha[x] + pr) & 255
        saida += linha
        anterior = linha
    if canais == 3:
        return largura, altura, bytes(saida)
    rgb = bytearray()
    for k in range(largura * altura):
        rgb += saida[k * canais:k * canais + 3]
    return largura, altura, bytes(rgb)


def _medias(largura: int, altura: int, d: bytes):
    bl, ba = largura // BLOCO, altura // BLOCO
    fora = [0.0] * (bl * ba * 3)
    n = float(BLOCO * BLOCO)
    for by in range(ba):
        for bx in range(bl):
            acc = [0, 0, 0]
            for y in range(by * BLOCO, by * BLOCO + BLOCO):
                base = y * largura * 3
                for x in range(bx * BLOCO, bx * BLOCO + BLOCO):
                    i = base + x * 3
                    acc[0] += d[i]
                    acc[1] += d[i + 1]
                    acc[2] += d[i + 2]
            o = (by * bl + bx) * 3
            fora[o], fora[o + 1], fora[o + 2] = acc[0] / n, acc[1] / n, acc[2] / n
    return bl, ba, fora


def comparar(caminho_a: str, caminho_b: str, limiar: float = 12.0):
    la, ha, da = ler(caminho_a)
    lb, hb, db = ler(caminho_b)
    if (la, ha) != (lb, hb):
        raise SystemExit("tamanhos diferentes: %dx%d contra %dx%d" % (la, ha, lb, hb))
    bl, ba, ma = _medias(la, ha, da)
    _, _, mb = _medias(lb, hb, db)
    soma = 0.0
    fora = 0
    for i in range(0, len(ma), 3):
        d = abs(ma[i] - mb[i]) + abs(ma[i + 1] - mb[i + 1]) + abs(ma[i + 2] - mb[i + 2])
        soma += d
        if d > limiar:
            fora += 1
    n = bl * ba
    return soma / (n * 3.0), 100.0 * fora / n


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    limiar = float(sys.argv[3]) if len(sys.argv) > 3 else 12.0
    erro, pc = comparar(sys.argv[1], sys.argv[2], limiar)
    print("erro medio %.2f/255   blocos diferentes %.2f%%" % (erro, pc))
