#!/usr/bin/env python3
"""Verificacao funcional do controlador do jogador.

Roda o jogo com caminhada automatica e mede o deslocamento real entre a primeira
e a ultima amostra. Prova que o controlador move de verdade, e nao apenas que
compila: e o unico teste do projeto que exerce fisica, ja que a suite headless
nao roda _physics_process.

A posicao inicial e lida da propria execucao, nunca fixada no codigo. Fixar
significa que trocar a cena principal quebra o teste por um motivo que nao tem
nada a ver com o controlador.

    python tools/verificar_movimento.py
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

FRAMES = 420
PASSO = 60
MIN_AVANCO = 4.0
MAX_DERIVA = 0.5

LINHA = re.compile(r"\[stats\] frame=(\d+) x=(-?[\d.]+) y=-?[\d.]+ z=(-?[\d.]+)")


def main() -> int:
    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1

    cmd = [
        str(GODOT), "--path", str(JOGO), "--resolution", "640x360", "--",
        "--fog=leve", "--auto-walk", f"--stats={PASSO}",
        f"--shot-frame={FRAMES}", "--shot-quit",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=240)
    saida = r.stdout + r.stderr

    pontos = [(int(m.group(1)), float(m.group(2)), float(m.group(3)))
              for m in LINHA.finditer(saida)]
    if len(pontos) < 3:
        print("amostras insuficientes; saida do motor:")
        print(saida[-800:])
        return 1

    _, x0, z0 = pontos[0]
    fn, x1, z1 = pontos[-1]
    avanco = z0 - z1          # a frente e -Z
    deriva = abs(x1 - x0)
    segundos = fn / 60.0

    print(f"inicio          {x0:.2f}, {z0:.2f}")
    print(f"fim             {x1:.2f}, {z1:.2f}")
    print(f"avanco          {avanco:.2f} m em {segundos:.1f} s "
          f"({avanco / max(segundos, 0.01):.2f} m/s)")
    print(f"deriva lateral  {deriva:.2f} m")

    erros = []
    if avanco < MIN_AVANCO:
        erros.append(f"avancou so {avanco:.2f} m: o controlador nao move ou esta preso")
    if deriva > MAX_DERIVA:
        erros.append(f"deriva de {deriva:.2f} m sem entrada horizontal")

    # Monotonia: cada amostra tem que estar a frente da anterior. Sem isso um
    # jogador que anda, bate e volta passaria pelo teste de deslocamento total.
    for i in range(1, len(pontos)):
        if pontos[i][2] > pontos[i - 1][2] + 0.05:
            erros.append(f"recuou entre os frames {pontos[i - 1][0]} e {pontos[i][0]}")
            break

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print("\nOK — controlador move, na direcao certa, sem deriva e sem recuo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
