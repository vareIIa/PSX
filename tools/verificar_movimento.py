#!/usr/bin/env python3
"""Verificacao funcional do controlador do jogador.

Roda o jogo com caminhada automatica e mede o deslocamento real entre a primeira
e a ultima amostra. Prova que o controlador move de verdade, e nao apenas que
compila: e o unico teste do projeto que exerce fisica, ja que a suite headless
nao roda _physics_process.

A posicao inicial e IMPOSTA, e nao herdada de onde a cena principal larga o
jogador. Herdar parecia o certo — "fixar quebra o teste quando a cena muda" —,
mas o que herdamos junto era uma condicao que ninguem escreveu: a de que o
ponto de nascimento tem chao livre na frente. No dia em que a abertura passou a
largar o jogador na praca, a dois metros e meio de um muro de canteiro, o teste
passou a acusar "o controlador nao move ou esta preso" enquanto o controlador
estava perfeito. Uma medida que falha por causa do cenario nao esta medindo o
controlador.

Entao o ponto e dito aqui, no meio da avenida da origem, e a direcao junto:
asfalto reto, sem mobiliario, sem gente (--auto-walk desliga a multidao e o
transito) e sem depender de onde a historia comeca.

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

# Faixa externa da avenida que corre sobre x = 0, no sentido -Z. Anda por
# asfalto e chega a 14 m nos 7 s do teste, com folga de tres vezes o minimo.
# O olhar aponta para a origem, e --auto-walk anda para onde a camera olha.
PARTIDA = "-3.4,40"
MIRA = "-3.4,0"

LINHA = re.compile(r"\[stats\] frame=(\d+) x=(-?[\d.]+) y=-?[\d.]+ z=(-?[\d.]+)")


def main() -> int:
    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1

    cmd = [
        str(GODOT), "--path", str(JOGO), "--resolution", "640x360", "--",
        "--fog=leve", f"--ir-para={PARTIDA},{MIRA}",
        "--auto-walk", f"--stats={PASSO}",
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
