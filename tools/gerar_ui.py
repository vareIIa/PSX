#!/usr/bin/env python3
"""Gera as texturas da prancha de inventario.

A referencia de inventario nao e uma HUD: e uma prancha de cortica com recortes
de papel presos por fita e alfinete. Tudo aqui e papel, cortica, feltro e fita,
sintetizado com ruido e manchas. Nenhum arquivo vem de fora.

    python tools/gerar_ui.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "ui"
rng = np.random.default_rng(1995)


def fbm(lado: int, oitavas: int = 5, persist: float = 0.55) -> np.ndarray:
    out = np.zeros((lado, lado), dtype=np.float64)
    amp, total = 1.0, 0.0
    for o in range(oitavas):
        res = 2 ** (o + 1)
        if res > lado:
            break
        baixo = rng.random((res, res))
        img = Image.fromarray((baixo * 255).astype(np.uint8)).resize((lado, lado), Image.BICUBIC)
        out += np.asarray(img, dtype=np.float64) / 255.0 * amp
        total += amp
        amp *= persist
    return out / max(total, 1e-6)


def norm(a: np.ndarray) -> np.ndarray:
    lo, hi = a.min(), a.max()
    return (a - lo) / max(hi - lo, 1e-6)


def rampa(m: np.ndarray, escuro: str, claro: str) -> np.ndarray:
    d = np.array([int(escuro.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    c = np.array([int(claro.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)
    x = m[..., None]
    return d * (1.0 - x) + c * x


def salvar(nome: str, img: Image.Image, cores: int = 64) -> None:
    SAIDA.mkdir(parents=True, exist_ok=True)
    metodo = Image.FASTOCTREE if img.mode == "RGBA" else Image.MEDIANCUT
    img.quantize(colors=cores, method=metodo).save(SAIDA / f"{nome}.png", "PNG", optimize=True)
    print(f"{nome:22s} {img.width}x{img.height}")


# --- fundos -----------------------------------------------------------------

def cortica(lado: int = 128) -> None:
    """Cortica: granulado fino sobre bege queimado, com manchas maiores."""
    fino = norm(fbm(lado, 6, 0.72))
    grosso = norm(fbm(lado, 3, 0.5))
    m = np.clip(fino * 0.55 + grosso * 0.45, 0, 1) * 0.5 + 0.32
    arr = rampa(m, "#6b4d2c", "#c79a5f")
    # Pontos escuros: cortica de verdade tem furo, nao so gradiente.
    furos = rng.random((lado, lado)) > 0.988
    arr[furos] *= 0.55
    salvar("ui_cortica", Image.fromarray(arr.astype(np.uint8), "RGB"))


def papel(lado: int = 128) -> None:
    m = np.clip(norm(fbm(lado, 6, 0.6)) * 0.18 + 0.78, 0, 1)
    arr = rampa(m, "#b8ac90", "#f2ecd8")
    # Manchas de umidade, poucas e grandes.
    yy, xx = np.mgrid[0:lado, 0:lado]
    for _ in range(3):
        cx, cy = rng.integers(0, lado, 2)
        r = rng.integers(lado // 6, lado // 3)
        d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
        mancha = np.clip(1.0 - d / r, 0, 1) ** 2
        arr *= (1.0 - mancha[..., None] * 0.16)
    salvar("ui_papel", Image.fromarray(arr.astype(np.uint8), "RGB"))


def feltro(lado: int = 128) -> None:
    """Feltro marrom da faixa de slots."""
    m = np.clip(norm(fbm(lado, 7, 0.8)) * 0.3 + 0.35, 0, 1)
    arr = rampa(m, "#1e1208", "#4a2f1a")
    salvar("ui_feltro", Image.fromarray(arr.astype(np.uint8), "RGB"))


# --- recortes com alfa ------------------------------------------------------

def fita(w: int = 96, h: int = 32) -> None:
    """Fita adesiva: bege translucido com bordas rasgadas."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 4, w, h - 4), fill=(226, 214, 176, 170))
    # Bordas irregulares nas pontas
    for x in range(0, w, 3):
        d.rectangle((x, 4, x + 3, 4 + int(rng.integers(0, 3))), fill=(0, 0, 0, 0))
        d.rectangle((x, h - 4 - int(rng.integers(0, 3)), x + 3, h - 4), fill=(0, 0, 0, 0))
    # Brilho de fita
    d.line([(0, h // 2 - 3), (w, h // 2 - 3)], fill=(245, 238, 214, 90), width=2)
    salvar("ui_fita", im, 32)


def alfinete(s: int = 24) -> None:
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((3, 3, s - 3, s - 3), fill=(178, 46, 40, 255), outline=(38, 18, 16, 255), width=2)
    d.ellipse((7, 7, 13, 13), fill=(232, 128, 118, 255))
    salvar("ui_alfinete", im, 16)


def polaroid(w: int = 96, h: int = 112) -> None:
    """Moldura de polaroid, com a janela vazada para o retrato entrar atras."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, h - 1), fill=(238, 232, 214, 255), outline=(150, 142, 120, 255))
    d.rectangle((7, 7, w - 8, h - 26), fill=(0, 0, 0, 0))
    d.rectangle((6, 6, w - 7, h - 25), outline=(120, 112, 94, 255), width=1)
    salvar("ui_polaroid", im, 24)


def recorte_papel(w: int = 128, h: int = 40) -> None:
    """Tira de papel rasgada, para titulo e botao."""
    base = Image.open(SAIDA / "ui_papel.png").convert("RGB").resize((w, h), Image.BICUBIC)
    mascara = Image.new("L", (w, h), 255)
    d = ImageDraw.Draw(mascara)
    for x in range(0, w, 2):
        d.rectangle((x, 0, x + 2, int(rng.integers(0, 4))), fill=0)
        d.rectangle((x, h - int(rng.integers(0, 4)), x + 2, h), fill=0)
    for y in range(0, h, 2):
        d.rectangle((0, y, int(rng.integers(0, 3)), y + 2), fill=0)
        d.rectangle((w - int(rng.integers(0, 3)), y, w, y + 2), fill=0)
    im = base.convert("RGBA")
    im.putalpha(mascara.filter(ImageFilter.MinFilter(3)))
    salvar("ui_recorte", im, 48)


def vinheta_prancha(w: int = 256, h: int = 144) -> None:
    """Sombra nas bordas da prancha, para ela nao encostar na moldura da tela."""
    yy, xx = np.mgrid[0:h, 0:w]
    dx = np.abs(xx / w - 0.5) * 2.0
    dy = np.abs(yy / h - 0.5) * 2.0
    d = np.clip(np.maximum(dx, dy), 0, 1)
    a = (np.clip((d - 0.55) / 0.45, 0, 1) ** 1.5 * 190).astype(np.uint8)
    im = Image.new("RGBA", (w, h), (16, 10, 6, 0))
    im.putalpha(Image.fromarray(a, "L"))
    salvar("ui_vinheta", im, 32)


def retrato(w: int = 80, h: int = 78) -> None:
    """Foto do personagem para a polaroid.

    Deliberadamente ruim: foto de documento velha, mal enquadrada e com cor
    lavada. A referencia usa exatamente isso, e uma foto boa quebraria o tom."""
    arr = rampa(np.clip(norm(fbm(max(w, h), 5, 0.6)) * 0.2 + 0.48, 0, 1),
                "#4a4e3e", "#8b9078")[:h, :w]
    im = Image.fromarray(arr.astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    # Silhueta de ombros e cabeca, chapada.
    d.ellipse((w // 2 - 15, 14, w // 2 + 15, 46), fill=(150, 126, 104))
    d.polygon([(w // 2 - 30, h), (w // 2 - 20, 44), (w // 2 + 20, 44), (w // 2 + 30, h)],
              fill=(74, 104, 82))
    d.ellipse((w // 2 - 9, 24, w // 2 - 5, 29), fill=(42, 36, 32))
    d.ellipse((w // 2 + 5, 24, w // 2 + 9, 29), fill=(42, 36, 32))
    d.line([(w // 2 - 5, 38), (w // 2 + 5, 38)], fill=(96, 74, 62), width=1)
    salvar("ui_retrato", im, 48)


# --- pecas da prancha, segundo a referencia ---------------------------------

def faixa_couro(w: int = 448, h: int = 66) -> None:
    """Faixa de couro com costura tracejada e cantos de papel.

    Na referencia a faixa nao e um retangulo liso: tem costura pontilhada em
    volta e uma peca de papel clara em cada ponta, com uma seta preta. Sao esses
    dois detalhes que fazem a barra ler como objeto costurado e nao como painel.
    """
    couro = Image.open(SAIDA / "ui_feltro.png").convert("RGB").resize((w, h), Image.BICUBIC)
    im = couro.convert("RGBA")
    d = ImageDraw.Draw(im)

    # Costura: tracejado claro dois pixels para dentro da borda.
    for x in range(6, w - 6, 7):
        d.rectangle((x, 4, x + 3, 5), fill=(214, 198, 160, 220))
        d.rectangle((x, h - 6, x + 3, h - 5), fill=(214, 198, 160, 220))
    for y in range(6, h - 6, 7):
        d.rectangle((4, y, 5, y + 3), fill=(214, 198, 160, 220))
        d.rectangle((w - 6, y, w - 5, y + 3), fill=(214, 198, 160, 220))

    # Cantos de papel com seta, um em cada ponta.
    papel = (222, 206, 170, 255)
    for lado in (0, 1):
        x0 = 0 if lado == 0 else w - 34
        d.polygon([(x0 + (0 if lado == 0 else 6), 6),
                   (x0 + (34 if lado == 0 else 34), 2),
                   (x0 + (30 if lado == 0 else 28), h - 3),
                   (x0 + (2 if lado == 0 else 0), h - 7)], fill=papel)
        cx = x0 + 17
        cy = h // 2
        if lado == 0:
            d.polygon([(cx + 7, cy - 8), (cx - 7, cy), (cx + 7, cy + 8)], fill=(28, 24, 20, 255))
        else:
            d.polygon([(cx - 7, cy - 8), (cx + 7, cy), (cx - 7, cy + 8)], fill=(28, 24, 20, 255))

    salvar("ui_faixa", im, 64)


def moldura_selecao(s: int = 28) -> None:
    """Moldura branca nitida da selecao. NinePatch: so a borda importa."""
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, s - 1, s - 1), outline=(255, 252, 244, 255), width=3)
    d.rectangle((3, 3, s - 4, s - 4), outline=(28, 22, 16, 200), width=1)
    d.rectangle((4, 4, s - 5, s - 5), outline=(200, 190, 170, 70), width=1)
    salvar("ui_selecao", im, 8)



def selo(s: int = 56) -> None:
    """Selo circular do cartao de status. Contorno serrilhado, miolo vazio: e
    um carimbo apagado, nao um botao."""
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    import math
    pontos = []
    for i in range(48):
        a = i / 48.0 * math.tau
        r = (s / 2 - 3) * (1.0 + (0.045 if i % 2 == 0 else -0.045))
        pontos.append((s / 2 + math.cos(a) * r, s / 2 + math.sin(a) * r))
    d.polygon(pontos, outline=(148, 138, 116, 235))
    d.ellipse((7, 7, s - 8, s - 8), outline=(160, 150, 128, 200), width=1)
    salvar("ui_selo", im, 12)


def fita_marrom(w: int = 96, h: int = 22) -> None:
    """Fita adesiva escura onde o estado e escrito, como na referencia."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 2, w, h - 2), fill=(150, 122, 82, 245))
    for x in range(0, w, 3):
        d.rectangle((x, 2, x + 3, 2 + int(rng.integers(0, 3))), fill=(0, 0, 0, 0))
        d.rectangle((x, h - 2 - int(rng.integers(0, 3)), x + 3, h - 2), fill=(0, 0, 0, 0))
    d.line([(0, h // 2 - 4), (w, h // 2 - 4)], fill=(176, 148, 106, 110), width=2)
    salvar("ui_fita_marrom", im, 24)


def aba_botao(w: int = 110, h: int = 26) -> None:
    """Aba de papelao corrugado dos botoes USAR/EXAMINAR.

    Na referencia nao e fita creme: e tira de papelao, com as ranhuras do
    corrugado visiveis e borda irregular. Papel liso aqui vira botao de HUD.
    """
    base = Image.open(SAIDA / "ui_papel.png").convert("RGB").resize((w, h), Image.BICUBIC)
    # Escurece um pouco e marca corrugado horizontal — papelao, nao adesivo.
    px = np.asarray(base, dtype=np.float32)
    px *= np.array([0.86, 0.80, 0.68], dtype=np.float32)
    for y in range(0, h, 3):
        px[y:min(y + 1, h), :] *= 0.90
    base = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGB")
    mascara = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mascara)
    d.polygon([(2, 3), (w - 1, 0), (w - 3, h - 2), (0, h - 4)], fill=255)
    im = base.convert("RGBA")
    im.putalpha(mascara)
    # Sombra de um pixel para a peca sentar na mesa.
    sombra = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sombra)
    sd.polygon([(3, 5), (w, 2), (w - 2, h - 1), (1, h - 2)], fill=(40, 28, 18, 90))
    sombra.alpha_composite(im)
    salvar("ui_aba", sombra, 40)


def colagem(w: int = 240, h: int = 136) -> None:
    """Fundo da prancha: a mesa coberta de papel da referencia.

    Tres coisas separam isto de um fundo de textura qualquer, e as tres saem da
    referencia:

      e CLARO      creme e bege, nao marrom. O conteudo por cima e papel claro
                   com tinta escura; fundo escuro inverte a leitura e a prancha
                   passa a parecer uma tela preta com adesivos.
      e BAGUNCADO  dezenas de retangulos girados, sobrepostos, de tamanhos
                   diferentes, com fita por cima. Nada alinhado.
      e CENTRADO   o miolo e mais claro que as bordas. Nao e vinheta artistica:
                   e onde o texto vai, e o texto precisa de contraste.

    A primeira versao era marrom escura com pecas coloridas, e ao lado da
    referencia lia como cortica suja em vez de mesa de papel.
    """
    base = rampa(np.clip(norm(fbm(max(w, h), 5, 0.6)) * 0.22 + 0.68, 0, 1),
                 "#b4967a", "#f0e4cc")[:h, :w]
    im = Image.fromarray(base.astype(np.uint8), "RGB").convert("RGBA")

    # Papeis. Predominam os claros; os poucos escuros sao fotos e recortes de
    # jornal, e vao mais para as bordas.
    claros = ["#e8dcc0", "#dfd2b4", "#f0e6d2", "#d8c9a8", "#eee3ca", "#cabb98"]
    escuros = ["#8a6b48", "#6d5a44", "#9c7a52", "#7f8a76"]
    for i in range(46):
        borda = i % 3 == 0
        cw = int(rng.integers(30, 110))
        ch = int(rng.integers(24, 84))
        peca = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        pd = ImageDraw.Draw(peca)
        paleta = escuros if (borda and rng.random() < 0.5) else claros
        cor = paleta[int(rng.integers(0, len(paleta)))]
        rgb = tuple(int(cor.lstrip("#")[k:k + 2], 16) for k in (0, 2, 4))
        pd.rectangle((0, 0, cw - 1, ch - 1), fill=rgb + (int(rng.integers(180, 245)),))
        # Sombra de um pixel embaixo e a direita: e o que separa uma folha da
        # outra quando as duas sao do mesmo creme.
        pd.line((0, ch - 1, cw - 1, ch - 1), fill=(92, 74, 54, 120))
        pd.line((cw - 1, 0, cw - 1, ch - 1), fill=(92, 74, 54, 120))
        peca = peca.rotate(float(rng.integers(-22, 22)), expand=True,
                           resample=Image.BICUBIC)
        if borda:
            # Empurra para fora: a moldura da mesa fica cheia e o meio, limpo.
            x = int(rng.integers(-24, 24)) if rng.random() < 0.5 else int(
                rng.integers(w - 70, w - 6))
            y = int(rng.integers(-20, h - 10))
        else:
            x = int(rng.integers(-24, w - 20))
            y = int(rng.integers(-20, h - 20))
        im.alpha_composite(peca, (x, y))

    # Fita crepe por cima de tudo, na diagonal. E a assinatura da referencia:
    # nada esta so apoiado, tudo esta preso.
    for _ in range(9):
        fw = int(rng.integers(26, 64))
        fh = int(rng.integers(7, 12))
        tira = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        td = ImageDraw.Draw(tira)
        td.rectangle((0, 0, fw - 1, fh - 1), fill=(238, 228, 202, 168))
        td.line((0, 0, fw - 1, 0), fill=(206, 192, 162, 190))
        td.line((0, fh - 1, fw - 1, fh - 1), fill=(206, 192, 162, 190))
        tira = tira.rotate(float(rng.integers(-30, 30)), expand=True,
                           resample=Image.BICUBIC)
        im.alpha_composite(tira, (int(rng.integers(-10, w - 20)),
                                  int(rng.integers(-6, h - 10))))

    # Luz no meio, sombra na borda. Feito por multiplicacao, e nao por overlay
    # escuro chapado: chapado tira contraste do papel inteiro.
    yy, xx = np.mgrid[0:h, 0:w]
    dx = (xx - w * 0.5) / (w * 0.5)
    dy = (yy - h * 0.5) / (h * 0.5)
    r = np.clip(np.sqrt(dx * dx + dy * dy) / 1.25, 0.0, 1.0)
    ganho = (1.12 - 0.30 * r * r)[..., None]
    px = np.asarray(im.convert("RGB"), dtype=np.float32) * ganho
    im = Image.fromarray(np.clip(px, 0, 255).astype(np.uint8), "RGB")
    salvar("ui_colagem", im, 64)


def sublinhado(w: int = 96, h: int = 6) -> None:
    """Traco a mao sob o titulo do item. Nao e reto: reto le como borda de
    caixa, e a prancha inteira e feita a mao."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    y = h // 2
    pontos = [(x, y + (1 if (x // 7) % 2 == 0 else 0)) for x in range(0, w, 4)]
    d.line(pontos, fill=(58, 44, 32, 255), width=2)
    salvar("ui_sublinhado", im, 8)


def main() -> int:
    cortica()
    papel()
    feltro()
    fita()
    alfinete()
    polaroid()
    recorte_papel()
    retrato()
    vinheta_prancha()
    faixa_couro()
    moldura_selecao()
    selo()
    fita_marrom()
    aba_botao()
    colagem()
    sublinhado()
    print(f"\n{len(list(SAIDA.glob('*.png')))} texturas de interface")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
