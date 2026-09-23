#!/usr/bin/env python3
"""Materiais de verdade para os moveis da loja (PLANO_MERCADO_AAA_V2).

O kit da loja pintava louca, pia, lixeira e maquina de cafe por cima do
`metal.png` — um metal ESCURO (media 62 de 255, nos dois estilos). Tinta branca
por vertice multiplica o albedo e nao clareia (memoria "cor de vertice corta em
um"): a louca saia cinza-chumbo, e com o relevo do metal HD por cima, granito
(captures/mercado_aaa/auditoria/a14_banheiro.png). O conserto nao e tinta, e
material: cada coisa com o albedo, a rugosidade e o relevo dela.

Cada material sai em duas fidelidades, do mesmo desenho:
  game/assets/textures/<nome>.png        256 px, cor reduzida (PS1 STYLE)
  game/assets/textures_hd/<nome>.jpg     1024 px de cor (MODERNO)
  game/assets/textures_hd/<nome>_n.jpg   normal, do mapa de altura
  game/assets/textures_hd/<nome>_ru.png  rugosidade
e o .tres em game/resources/materials/mat_<nome>.tres. O TexturasHD acha o
conjunto pelo nome do albedo, sem tabela.

Os nomes comecam com `mercado_`: e o prefixo de abrigado da EstiloVisual (nao
molham na chuva) e o que o criterio A35 da bancada_fachada exige.

NAO passa pelo tools/gerar_materiais.py: aquele apaga, com --podar, todo .tres
fora da tabela dele. Estes sao desta frente e se geram aqui.

    python tools/gerar_mercado_aaa.py
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
PS1 = RAIZ / "game" / "assets" / "textures"
HD = RAIZ / "game" / "assets" / "textures_hd"
MAT = RAIZ / "game" / "resources" / "materials"

LADO_HD = 1024
LADO_PS1 = 256
rng = np.random.default_rng(90210)

MODELO = '''[gd_resource type="ShaderMaterial" load_steps=3 format=3]

[ext_resource type="Shader" path="res://shaders/psx_surface.gdshader" id="1_shader"]
[ext_resource type="Texture2D" path="res://assets/textures/{nome}.png" id="2_tex"]

[resource]
resource_name = "mat_{nome}"
shader = ExtResource("1_shader")
shader_parameter/albedo_tex = ExtResource("2_tex")
shader_parameter/tint = Color(1, 1, 1, 1)
shader_parameter/uv_tile = Vector2({tile}, {tile})
shader_parameter/snap_resolution = Vector2(240, 135)
shader_parameter/use_snap = true
shader_parameter/use_affine = true
shader_parameter/alpha_cutoff = 0.0
shader_parameter/emission_color = Color(0, 0, 0, 1)
shader_parameter/emission_energy = 0.0
shader_parameter/vento_forca = 0
shader_parameter/vento_velocidade = 1
shader_parameter/rugosidade = {rugosidade}
shader_parameter/brilho = {brilho}
shader_parameter/molha = 0.0
'''


# --- ruido --------------------------------------------------------------------

def ruido(lado: int, escala: float, oitavas: int = 4) -> np.ndarray:
    """Ruido de valor em oitavas, 0..1, que FECHA nas bordas (repete)."""
    total = np.zeros((lado, lado))
    amp = 1.0
    soma = 0.0
    freq = escala
    for _ in range(oitavas):
        n = max(2, int(freq))
        grade = rng.random((n, n))
        img = Image.fromarray((grade * 255).astype(np.uint8), "L")
        # Repetir a grade antes de ampliar e cortar o meio: a borda casa.
        tri = np.tile(np.asarray(img), (3, 3))
        grande = Image.fromarray(tri, "L").resize((lado * 3, lado * 3), Image.BICUBIC)
        total += np.asarray(grande, dtype=np.float64)[lado:2 * lado, lado:2 * lado] / 255.0 * amp
        soma += amp
        amp *= 0.5
        freq *= 2.0
    return total / soma


def escovado(lado: int, forca: float) -> np.ndarray:
    """Riscos finos numa direcao so: o inox escovado de pia e balcao."""
    base = rng.random((lado, lado))
    img = Image.fromarray((base * 255).astype(np.uint8), "L")
    tri = Image.fromarray(np.tile(np.asarray(img), (1, 3)), "L")
    # Borra so na horizontal, muito: o risco vira linha.
    tri = tri.filter(ImageFilter.BoxBlur(0)).resize((lado * 3 // 24, lado), Image.BILINEAR)
    tri = tri.resize((lado * 3, lado), Image.BICUBIC)
    a = np.asarray(tri, dtype=np.float64)[:, lado:2 * lado] / 255.0
    return (a - a.mean()) * forca + 0.5


def normal_de(altura: np.ndarray, forca: float) -> Image.Image:
    """Normal em espaco tangente (OpenGL, verde para cima) a partir da altura."""
    h = altura * forca
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    n = np.dstack((-dx, dy, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def salvar(nome: str, cor: np.ndarray, altura: np.ndarray, rug: np.ndarray,
           relevo: float, cores_ps1: int, tile: float, rugosidade: float,
           brilho: float) -> None:
    HD.mkdir(parents=True, exist_ok=True)
    PS1.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray(np.clip(cor, 0, 255).astype(np.uint8), "RGB")
    img.save(HD / f"{nome}.jpg", "JPEG", quality=92)
    normal_de(altura, relevo).save(HD / f"{nome}_n.jpg", "JPEG", quality=92)
    # R = rugosidade, G = oclusao (tools/texturas_hd.py). Em tons de cinza o
    # shader lia a rugosidade TAMBEM como oclusao: louca a 0,10 de rugosidade
    # virava 0,10 de luz, e o banheiro saia preto so no MODERNO.
    if altura.max() - altura.min() > 0.5:
        oclusao = np.clip(0.55 + altura * 0.45, 0.0, 1.0)
    else:
        oclusao = np.ones_like(rug)
    ru = np.dstack((np.clip(rug, 0, 1), oclusao, np.zeros_like(rug)))
    Image.fromarray((ru * 255).astype(np.uint8), "RGB").save(
        HD / f"{nome}_ru.png", "PNG", optimize=True)
    # O PS1 precisa de mais contraste para sobreviver ao corte de 15 bits.
    pequeno = img.resize((LADO_PS1, LADO_PS1), Image.LANCZOS)
    a = np.asarray(pequeno, dtype=np.float64)
    a = (a - a.mean()) * 1.25 + a.mean()
    pequeno = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")
    pequeno.quantize(colors=cores_ps1, method=Image.MEDIANCUT).save(
        PS1 / f"{nome}.png", "PNG", optimize=True)
    (MAT / f"mat_{nome}.tres").write_text(MODELO.format(
        nome=nome, tile=tile, rugosidade=rugosidade, brilho=brilho), encoding="utf-8")
    media = [round(x) for x in np.asarray(img).reshape(-1, 3).mean(axis=0)]
    print(f"{nome:26s} media {media}")


def rgb(base: tuple, variacao: np.ndarray, amp: float) -> np.ndarray:
    v = (variacao - 0.5)[..., None] * amp
    return np.asarray(base, dtype=np.float64)[None, None, :] + v


# --- materiais ------------------------------------------------------------------

def louca() -> None:
    """Louca sanitaria vitrificada: branco quase puro, liso, com brilho.

    O que separa louca de plastico branco e o reflexo, e nao a cor: rugosidade
    baixa no HD e um levissimo ondulado de esmalte no relevo. Nada de sujeira
    pintada — encardido e decalque, e desenhado na textura repete em toda peca.
    """
    lado = LADO_HD
    ond = ruido(lado, 3, 3)
    pinta = (rng.random((lado, lado)) > 0.9995).astype(np.float64)
    cor = rgb((241, 242, 239), ond, 7.0) - pinta[..., None] * 25.0
    rug = 0.10 + ond * 0.06
    salvar("mercado_louca", cor, ond * 0.3, rug + 0.06, 2.0, 32, 1.0, 0.18, 0.7)


def inox() -> None:
    """Inox escovado: bancada da copa, torneira, porta-papel, lixeira de pedal."""
    lado = LADO_HD
    risco = escovado(lado, 0.9)
    mancha = ruido(lado, 4, 3)
    cor = rgb((176, 180, 184), risco, 34.0) + rgb((0, 0, 0), mancha, 14.0)
    rug = 0.28 + (risco - 0.5) * 0.25 + (mancha - 0.5) * 0.1
    salvar("mercado_inox", cor, risco * 0.4, rug, 1.5, 32, 1.0, 0.3, 0.6)


def formica() -> None:
    """Formica cinza-areia pontilhada: tampo da mesa da copa e do escritorio."""
    lado = LADO_HD
    base = ruido(lado, 6, 3)
    fino = rng.random((lado, lado))
    escuro = (fino > 0.985).astype(np.float64)
    claro = (fino < 0.012).astype(np.float64)
    cor = rgb((206, 200, 186), base, 10.0) - escuro[..., None] * 60.0 + claro[..., None] * 25.0
    rug = 0.45 + (base - 0.5) * 0.1
    salvar("mercado_formica", cor, base * 0.2, rug, 1.0, 48, 1.0, 0.45, 0.3)


def _grade(lado: int, n: int, rejunte_px: int, base: tuple, rejunte: tuple,
           variacao: float, sujeira: float) -> tuple:
    """Ladrilho em grade n x n: cor, altura e rugosidade."""
    passo = lado / n
    cor = np.zeros((lado, lado, 3))
    alt = np.ones((lado, lado))
    rug = np.full((lado, lado), 0.22)
    # Peca a peca muda o CLARO, quase nada o matiz: lote de ceramica varia em
    # tom, e canal por canal a variacao pintava o piso de pastel.
    tom = rng.normal(0.0, variacao, (n, n, 1)) + rng.normal(0.0, variacao * 0.12, (n, n, 3))
    ys, xs = np.mgrid[0:lado, 0:lado]
    ci = (xs / passo).astype(int) % n
    cj = (ys / passo).astype(int) % n
    cor[:] = np.asarray(base, dtype=np.float64) + tom[cj, ci]
    # Rejunte: faixa escura e funda entre as pecas, com borda arredondada no
    # relevo (a quina do ladrilho e boleada).
    fx = (xs % passo)
    fy = (ys % passo)
    dist = np.minimum(np.minimum(fx, passo - fx), np.minimum(fy, passo - fy))
    no_rejunte = dist < rejunte_px * 0.5
    alt = np.clip(dist / (rejunte_px * 1.5), 0.0, 1.0)
    suja = ruido(lado, 5, 3)
    cor[no_rejunte] = np.asarray(rejunte, dtype=np.float64)
    cor -= ((1.0 - alt) * sujeira * (0.6 + suja))[..., None]
    rug[no_rejunte] = 0.85
    return cor, alt, rug


def ladrilho() -> None:
    """Piso do banheiro e da copa: ceramica clara de 20 cm, rejunte cinza.

    O piso_ceramico da rua (media 80) e escuro e manchado de vermelho; num
    banheiro de loja le como garagem. Aqui: 10 x 10 pecas por repeticao de 2 m.
    """
    cor, alt, rug = _grade(LADO_HD, 10, 6, (214, 212, 204), (138, 136, 130), 3.5, 14.0)
    salvar("mercado_ladrilho", cor, alt, rug, 3.0, 48, 1.0, 0.3, 0.45)


def revestimento() -> None:
    """Azulejo de parede de 15 x 15 cm, branco, ate o teto do banheiro.

    O mercado_azulejo antigo tinha um ponto em cada cruzamento e lia como
    alambrado. O azulejo de banheiro dos anos 90 e liso, branco-gelo, com
    rejunte fino claro — 13,3 pecas por 2 m; usa-se 14 para fechar a repeticao.
    """
    cor, alt, rug = _grade(LADO_HD, 14, 5, (236, 238, 234), (186, 188, 182), 2.0, 6.0)
    rug = np.where(rug < 0.5, 0.14, rug)
    salvar("mercado_revestimento", cor, alt, rug, 2.0, 32, 1.0, 0.18, 0.65)


def plastico() -> None:
    """Plastico injetado quase branco, para ser TINGIDO por vertice.

    O fumaca_plastico da casa (albedo cinza-azulado, media 165) desbota toda cor:
    a cesta vermelha saia salmao e o balde amarelo, oliva. Tinta de vertice so
    multiplica; para o vermelho sair vermelho o albedo tem de ser branco.
    """
    lado = LADO_HD
    base = ruido(lado, 8, 3)
    fino = rng.random((lado, lado))
    cor = rgb((238, 238, 236), base, 6.0) + rgb((0, 0, 0), fino, 5.0)
    rug = 0.42 + (base - 0.5) * 0.08
    salvar("mercado_plastico", cor, base * 0.15 + fino * 0.02, rug, 1.0, 32, 1.0, 0.42, 0.35)


def main() -> int:
    louca()
    inox()
    formica()
    ladrilho()
    revestimento()
    plastico()
    print("\nmateriais da loja prontos (rode --import no Godot)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
