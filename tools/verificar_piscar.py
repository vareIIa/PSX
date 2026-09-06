#!/usr/bin/env python3
"""Verificacao funcional das lampadas que piscam.

Captura a mesma cena em instantes diferentes de simulacao e compara o nivel de
cada lampada. Prova tres coisas que o olho nao garante:

  1. Lampada com defeito muda de nivel ao longo do tempo.
  2. Lampada estavel NAO muda de forma perceptivel.
  3. Lampadas com defeito nao piscam em sincronia umas com as outras.

A captura conta frames de fisica, que rodam em passo fixo de 60 Hz, entao o
mesmo numero de frame e sempre o mesmo instante de simulacao. Sem isso a
comparacao entre execucoes nao valeria nada.

    python tools/verificar_piscar.py
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"
LIXO = RAIZ / "captures" / "_piscar.png"

# 900 frames de fisica sao 15 s de simulacao, tempo de sobra para pegar as
# rajadas do fluorescente, que espacam entre 2 e 7 s.
FRAMES_TOTAL = 900
PASSO = 6
VARIACAO_MINIMA = 0.15


def amostrar() -> dict[str, list[float]]:
    cmd = [
        str(GODOT), "--path", str(JOGO), "--resolution", "640x360", "--",
        "--fog=leve", f"--shot={LIXO}", f"--shot-frame={FRAMES_TOTAL}",
        f"--sample={PASSO}", "--shot-quit",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    saida = r.stdout + r.stderr

    series: dict[str, list[float]] = {}
    for _, nome, valor in re.findall(r"\[amostra\]\s+(\d+)\s+(\S+)\s+([\d.]+)", saida):
        series.setdefault(nome, []).append(float(valor))
    if not series:
        print("nenhuma amostra de lampada na saida")
        print(saida[-700:])
    return series


def main() -> int:
    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1
    LIXO.parent.mkdir(parents=True, exist_ok=True)

    series = amostrar()
    if not series:
        return 1

    n = min(len(v) for v in series.values())
    print(f"{len(series)} lampadas, {n} amostras cada "
          f"({n * PASSO / 60.0:.1f} s de simulacao)\n")
    print(f"{'lampada':16s} {'min':>6s} {'max':>6s} {'variacao':>9s} {'apagoes':>8s}")

    com_defeito: list[str] = []
    estaveis: list[str] = []
    for nome in sorted(series):
        vals = series[nome][:n]
        var = max(vals) - min(vals)
        # Uma transicao de aceso para apagado. E o que o jogador percebe como
        # "a luz piscou", diferente de uma ondulacao continua.
        apagoes = sum(1 for i in range(1, len(vals))
                      if vals[i] < 0.25 <= vals[i - 1])
        print(f"{nome:16s} {min(vals):6.2f} {max(vals):6.2f} {var:9.2f} {apagoes:8d}")
        (com_defeito if var >= VARIACAO_MINIMA else estaveis).append(nome)

    erros: list[str] = []
    if not com_defeito:
        erros.append("nenhuma lampada variou: o piscar nao esta rodando")
    if not estaveis:
        erros.append("todas as lampadas variaram: nao ha lampada estavel de controle")

    # Sincronia: se duas lampadas com defeito tem exatamente a mesma serie de
    # niveis, elas estao piscando juntas, o que le como falha de energia geral
    # em vez de lampada estragada.
    for i, a in enumerate(com_defeito):
        for b in com_defeito[i + 1:]:
            if [round(v, 3) for v in series[a][:n]] == [round(v, 3) for v in series[b][:n]]:
                erros.append(f"{a} e {b} piscam em sincronia")

    print(f"\ncom defeito: {len(com_defeito)}   estaveis: {len(estaveis)}")
    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print("\nOK — defeito varia, estavel nao varia, nenhuma sincronia")
    return 0


if __name__ == "__main__":
    sys.exit(main())
