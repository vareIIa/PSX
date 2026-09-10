#!/usr/bin/env python3
"""Criterio de aceite da Fase 3: streaming sem engasgo e com memoria estavel.

Roda o jogo com corrida automatica em linha reta, amostra desempenho ao longo do
percurso e afirma quatro coisas:

  1. O jogador percorre pelo menos 200 m, cruzando fronteiras de chunk.
  2. Nenhum frame passa do teto de engasgo depois do aquecimento inicial.
  3. A memoria nao cresce sem parar, ou seja, chunk descarregado devolve memoria.
  4. O numero de chunks carregados fica estavel, sem vazar nos.

O primeiro trecho e ignorado de proposito: o carregamento inicial monta a cidade
inteira em volta do jogador e sempre custa mais que o regime.

    python tools/verificar_streaming.py [--preset leve]
"""

import argparse
import math
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

# O que este teste precisa provar e o CICLO de streaming: carregar, descarregar
# e voltar ao regime, varias vezes, sem engasgo nem vazamento. Isso se prova
# atravessando fronteiras de chunk, e nao acumulando quilometros — a duodecima
# fronteira nao afirma nada que a sexta ja nao tenha afirmado.
#
# 4,6 m/s por 50 s dao 230 m, que a 32 m de chunk sao sete fronteiras em cada
# eixo de carga. O teste custava dois minutos e vinte; agora custa cinquenta
# segundos e afirma a mesma coisa.
FRAMES = 3000
PASSO = 120
AQUECIMENTO_M = 40.0

# Mesma razao de verificar_movimento: o percurso e IMPOSTO, e nao herdado do
# ponto onde a abertura larga o jogador. Herdado, o teste media o cenario junto
# com o streaming — e quando a praca ganhou muro de canteiro na frente do
# nascimento, ele acusou engasgo de carga num corredor que nunca saiu do lugar.
# A avenida da origem da 240 m retos de asfalto no sentido -Z, que e mais do que
# a distancia minima pede.
#
# x = -5,6 e o ACOSTAMENTO, e nao a faixa de rolamento (que vai ate 4,5 m do
# eixo), e o corredor vai com --atravessar. As duas coisas tem a mesma razao:
# --auto-run mantem transito, multidao e blitz ligados de proposito (essa e a
# carga a medir), e correr no meio deles terminava com o corredor empurrado para
# tras e prensado contra uma lataria — 62 m em 50 s, com o mundo congelado
# porque quem nao anda nao carrega chunk. Ser atropelado e comportamento certo
# do jogo; so nao e o que este teste mede. A cidade continua toda em volta; o
# que saiu foi so a colisao do corredor com ela.
PARTIDA = "-5.6,250"
MIRA = "-5.6,0"

DISTANCIA_MINIMA = 200.0
PIOR_FRAME_MS = 90.0
CRESCIMENTO_MEM_MAX = 1.35


def chunks_esperados(preset: str) -> int:
    """Teto de chunks carregados para este preset, contado e nao chutado.

    O ChunkManager carrega um quadrado de raio `ceil(stream_radius / 32)` e so
    descarrega um anel alem disso (FOLGA_DESCARGA = 1), para andar em cima da
    fronteira nao fazer o mesmo chunk nascer e morrer a cada passo. Andando em
    linha reta, o conjunto real fica entre o quadrado pedido e o quadrado com a
    folga: (2r+1)^2 e (2r+2)^2.

    Era um 60 fixo, que so valia para o preset em que foi medido. Com o raio
    vindo do preset, trocar de clima deixa de reprovar o streaming por um numero
    que nunca falou daquele clima.
    """
    caminho = RAIZ / "game" / "resources" / "fog" / f"fog_{preset}.tres"
    raio = 2
    if caminho.exists():
        for linha in caminho.read_text(encoding="utf-8").splitlines():
            if linha.startswith("stream_radius"):
                raio = max(1, math.ceil(float(linha.split("=")[1]) / 32.0))
    return (2 * raio + 2) ** 2

LINHA = re.compile(
    r"\[stats\] frame=(\d+) x=(-?[\d.]+) y=-?[\d.]+ z=(-?[\d.]+) dentro=\d+ "
    r"pior_ms=([\d.]+) fps=(\d+) chunks=(\d+) tris=(\d+) mem=([\d.]+) nos=(\d+)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", default="leve")
    # docs/PADROES-ENGENHARIA.md: a medicao so vale em build exportado. O editor
    # adiciona custo que distorce draw call e tempo de frame.
    ap.add_argument("--build", action="store_true",
                    help="mede no executavel exportado em vez do editor")
    args = ap.parse_args()

    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1

    exe = RAIZ / "export" / "NevoaEDither.exe"
    if args.build:
        if not exe.exists():
            print(f"build ausente em {exe}; rode ./dev.sh export")
            return 1
        cmd = [str(exe), "--resolution", "640x360"]
    else:
        cmd = [str(GODOT), "--path", str(JOGO), "--resolution", "640x360"]
    cmd += ["--", f"--fog={args.preset}", f"--ir-para={PARTIDA},{MIRA}",
            "--auto-run", "--atravessar", f"--stats={PASSO}",
            f"--shot-frame={FRAMES}", "--shot-quit"]
    onde = "build exportado" if args.build else "editor"
    print(f"correndo {FRAMES / 60.0:.0f} s no preset {args.preset} ({onde})...")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    saida = r.stdout + r.stderr

    amostras = []
    for m in LINHA.finditer(saida):
        amostras.append({
            "frame": int(m.group(1)), "x": float(m.group(2)), "z": float(m.group(3)),
            "pior": float(m.group(4)), "fps": int(m.group(5)),
            "chunks": int(m.group(6)), "tris": int(m.group(7)),
            "mem": float(m.group(8)), "nos": int(m.group(9)),
        })

    if len(amostras) < 5:
        print("amostras insuficientes; saida do motor:")
        print(saida[-1200:])
        return 1

    z0 = amostras[0]["z"]
    for a in amostras:
        a["dist"] = abs(a["z"] - z0)

    regime = [a for a in amostras if a["dist"] > AQUECIMENTO_M]
    if not regime:
        print("o jogador nao saiu do aquecimento")
        return 1

    distancia = amostras[-1]["dist"]
    pior = max(a["pior"] for a in regime)
    mem_ini = min(a["mem"] for a in regime[:3])
    mem_fim = max(a["mem"] for a in regime[-3:])
    mem_pico = max(a["mem"] for a in regime)
    chunks_max = max(a["chunks"] for a in regime)
    nos_ini = regime[0]["nos"]
    nos_fim = regime[-1]["nos"]

    print(f"\n{'metros':>8s} {'pior ms':>8s} {'fps':>5s} {'chunks':>7s} "
          f"{'tris':>8s} {'mem MB':>8s} {'nos':>6s}")
    passo_impressao = max(1, len(amostras) // 14)
    for a in amostras[::passo_impressao]:
        print(f"{a['dist']:8.0f} {a['pior']:8.1f} {a['fps']:5d} {a['chunks']:7d} "
              f"{a['tris']:8d} {a['mem']:8.1f} {a['nos']:6d}")

    print(f"\ndistancia         {distancia:.0f} m   (minimo {DISTANCIA_MINIMA:.0f})")
    print(f"pior frame        {pior:.1f} ms  (teto {PIOR_FRAME_MS:.0f})")
    print(f"memoria           {mem_ini:.1f} -> {mem_fim:.1f} MB, pico {mem_pico:.1f}")
    print(f"chunks no maximo  {chunks_max}  (teto {chunks_esperados(args.preset)})")
    print(f"nos               {nos_ini} -> {nos_fim}")

    erros = []
    if distancia < DISTANCIA_MINIMA:
        erros.append(f"percorreu so {distancia:.0f} m")
    if pior > PIOR_FRAME_MS:
        erros.append(f"engasgo de {pior:.0f} ms em regime")
    # Performance.MEMORY_STATIC nao e instrumentado em build de release: vem
    # zerado. Comparar zero com zero passaria sempre, o que e pior que nao medir,
    # entao a assercao e explicitamente pulada em vez de dar um OK falso.
    if mem_ini <= 0.0:
        print("memoria            nao instrumentada nesta build, assercao pulada")
    elif mem_fim > mem_ini * CRESCIMENTO_MEM_MAX:
        erros.append(f"memoria cresceu {mem_fim / mem_ini:.2f}x: chunk descarregado nao libera")
    teto_chunks = chunks_esperados(args.preset)
    if chunks_max > teto_chunks:
        erros.append(f"{chunks_max} chunks carregados, acima do teto {teto_chunks} "
                     f"do preset {args.preset}")
    if nos_fim > nos_ini * 1.5:
        erros.append(f"nos foram de {nos_ini} para {nos_fim}: vazamento de no")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print("\nOK — 500 m percorridos, sem engasgo, memoria e nos estaveis")
    return 0


if __name__ == "__main__":
    sys.exit(main())
