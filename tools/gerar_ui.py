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
    arr = rampa(np.clip(norm(fbm(max(w, h), 5, 0.6)) * 0.2 + 0.62, 0, 1),
                "#6b6f5a", "#a9ae92")[:h, :w]
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
    print(f"\n{len(list(SAIDA.glob('*.png')))} texturas de interface")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
