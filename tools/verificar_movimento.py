#!/usr/bin/env python3
"""Verificacao funcional do controlador do jogador.

Roda o jogo com caminhada automatica e mede o deslocamento real. Prova que o
controlador move de verdade, e nao apenas que compila. E o unico teste do
projeto que exerce fisica: a suite headless nao roda _physics_process.

    python tools/verificar_movimento.py
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"
SAIDA = RAIZ / "captures" / "_walk.png"

Z_INICIAL = -3.0
MIN_DESLOCAMENTO = 0.4
FRAMES = 120


def main() -> int:
    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1

    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(GODOT), "--path", str(JOGO), "--resolution", "640x360", "--",
        "--fog=off", "--auto-walk", f"--shot={SAIDA}",
        f"--shot-frame={FRAMES}", "--shot-quit",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    saida = r.stdout + r.stderr

    m = re.search(r"jogador em\s+(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)", saida)
    if m is None:
        print("nao encontrei a posicao do jogador na saida:")
        print(saida[-800:])
        return 1

    x, y, z = (float(g) for g in m.groups())
    frente = abs(z - Z_INICIAL)
    desvio = abs(x)

    print(f"posicao final   {x:.2f}, {y:.2f}, {z:.2f}")
    print(f"avanco          {frente:.2f} m  (minimo {MIN_DESLOCAMENTO})")
    print(f"desvio lateral  {desvio:.2f} m")

    erros = []
    if frente < MIN_DESLOCAMENTO:
        erros.append(f"jogador nao avancou: {frente:.2f} m")
    if z > Z_INICIAL:
        erros.append("jogador andou para tras: -Z deveria ser a frente")
    if desvio > 0.3:
        erros.append(f"deriva lateral de {desvio:.2f} m sem entrada horizontal")
    if y < -1.0:
        erros.append(f"jogador caiu do cenario (y = {y:.2f})")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print("\nOK — controlador move, na direcao certa, sem deriva")
    return 0


if __name__ == "__main__":
    sys.exit(main())
