#!/usr/bin/env python3
"""Criterio de aceite da Fase 3: andar 500 m sem engasgo e com memoria estavel.

Roda o jogo com corrida automatica em linha reta, amostra desempenho ao longo do
percurso e afirma quatro coisas:

  1. O jogador percorre pelo menos 500 m.
  2. Nenhum frame passa do teto de engasgo depois do aquecimento inicial.
  3. A memoria nao cresce sem parar, ou seja, chunk descarregado devolve memoria.
  4. O numero de chunks carregados fica estavel, sem vazar nos.

O primeiro trecho e ignorado de proposito: o carregamento inicial monta a cidade
inteira em volta do jogador e sempre custa mais que o regime.

    python tools/verificar_streaming.py [--preset leve]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

# 4,6 m/s de corrida por 130 s de simulacao dao cerca de 600 m de folga.
FRAMES = 7800
PASSO = 120
AQUECIMENTO_M = 40.0

DISTANCIA_MINIMA = 500.0
PIOR_FRAME_MS = 90.0
CRESCIMENTO_MEM_MAX = 1.35
CHUNKS_MAX = 60

LINHA = re.compile(
    r"\[stats\] frame=(\d+) x=(-?[\d.]+) y=-?[\d.]+ z=(-?[\d.]+) dentro=\d+ "
    r"pior_ms=([\d.]+) fps=(\d+) chunks=(\d+) tris=(\d+) mem=([\d.]+) nos=(\d+)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", default="leve")
    args = ap.parse_args()

    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1

    cmd = [
        str(GODOT), "--path", str(JOGO), "--resolution", "640x360", "--",
        f"--fog={args.preset}", "--auto-run", f"--stats={PASSO}",
        f"--shot-frame={FRAMES}", "--shot-quit",
    ]
    print(f"correndo {FRAMES / 60.0:.0f} s de simulacao no preset {args.preset}...")
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
    print(f"chunks no maximo  {chunks_max}")
    print(f"nos               {nos_ini} -> {nos_fim}")

    erros = []
    if distancia < DISTANCIA_MINIMA:
        erros.append(f"percorreu so {distancia:.0f} m")
    if pior > PIOR_FRAME_MS:
        erros.append(f"engasgo de {pior:.0f} ms em regime")
    if mem_fim > mem_ini * CRESCIMENTO_MEM_MAX:
        erros.append(f"memoria cresceu {mem_fim / mem_ini:.2f}x: chunk descarregado nao libera")
    if chunks_max > CHUNKS_MAX:
        erros.append(f"{chunks_max} chunks carregados, acima do esperado")
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
