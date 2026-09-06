#!/usr/bin/env python3
"""Verifica a transicao para interior sem tela de carregamento.

A promessa da Fase 4 e que a porta abre e o jogador entra, sem corte. Este teste
faz a ida e a volta numa execucao so e afirma quatro coisas:

  1. O jogador chega ao interior.
  2. Nenhum frame passa do teto de engasgo durante a transicao, ou seja, a
     construcao realmente aconteceu na thread e nao travou a imagem.
  3. O jogador volta para a rua, na posicao de onde saiu.
  4. Sair nao deixa nos para tras, ou seja, o interior e mesmo liberado.

    python tools/verificar_interior.py
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

FRAMES = 600          # 10 s: entra em 1,5 s, sai em 5,5 s, sobra para assentar
PASSO = 10
PIOR_FRAME_MS = 90.0
TOLERANCIA_RETORNO = 0.6

LINHA = re.compile(
    r"\[stats\] frame=(\d+) x=(-?[\d.]+) y=(-?[\d.]+) z=(-?[\d.]+) dentro=(\d+) "
    r"pior_ms=([\d.]+) fps=(\d+) chunks=(\d+) tris=(\d+) mem=([\d.]+) nos=(\d+)")


def main() -> int:
    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1

    cmd = [
        str(GODOT), "--path", str(JOGO), "--resolution", "640x360", "--",
        "--fog=leve", "--entrar-interior", "--sair-interior",
        f"--stats={PASSO}", f"--shot-frame={FRAMES}", "--shot-quit",
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
    saida = r.stdout + r.stderr

    a = []
    for m in LINHA.finditer(saida):
        a.append({
            "frame": int(m.group(1)),
            "pos": (float(m.group(2)), float(m.group(3)), float(m.group(4))),
            "dentro": m.group(5) == "1", "pior": float(m.group(6)),
            "nos": int(m.group(11)),
        })

    if len(a) < 10:
        print("amostras insuficientes; saida do motor:")
        print(saida[-900:])
        return 1

    dentro = [s for s in a if s["dentro"]]
    fora_antes = [s for s in a if not s["dentro"] and s["frame"] < (dentro[0]["frame"] if dentro else 0)]
    fora_depois = [s for s in a if not s["dentro"] and dentro and s["frame"] > dentro[-1]["frame"]]

    print(f"amostras          {len(a)}")
    print(f"dentro            {len(dentro)}  "
          f"(frames {dentro[0]['frame'] if dentro else '-'} a "
          f"{dentro[-1]['frame'] if dentro else '-'})")
    print(f"fora antes        {len(fora_antes)}")
    print(f"fora depois       {len(fora_depois)}")

    erros = []
    if not dentro:
        erros.append("o jogador nunca entrou no interior")
    if not fora_depois:
        erros.append("o jogador nunca voltou para a rua")

    if dentro and fora_antes and fora_depois:
        p_antes = fora_antes[-1]["pos"]
        p_dentro = dentro[len(dentro) // 2]["pos"]
        p_depois = fora_depois[-1]["pos"]
        desvio = max(abs(p_antes[i] - p_depois[i]) for i in range(3))

        print(f"antes             {p_antes[0]:.1f}, {p_antes[1]:.1f}, {p_antes[2]:.1f}")
        print(f"dentro            {p_dentro[0]:.1f}, {p_dentro[1]:.1f}, {p_dentro[2]:.1f}")
        print(f"depois            {p_depois[0]:.1f}, {p_depois[1]:.1f}, {p_depois[2]:.1f}")
        print(f"desvio no retorno {desvio:.2f} m  (tolerancia {TOLERANCIA_RETORNO})")

        if p_dentro[1] < 1000.0:
            erros.append("estando dentro, a altura nao e a do interior")
        if desvio > TOLERANCIA_RETORNO:
            erros.append(f"voltou {desvio:.2f} m fora do lugar")

        nos_antes = fora_antes[-1]["nos"]
        nos_depois = fora_depois[-1]["nos"]
        print(f"nos               {nos_antes} -> {nos_depois}")
        if nos_depois > nos_antes + 40:
            erros.append(f"sobraram nos: {nos_antes} viraram {nos_depois}")

    pior = max(s["pior"] for s in a[2:])
    print(f"pior frame        {pior:.1f} ms  (teto {PIOR_FRAME_MS:.0f})")
    if pior > PIOR_FRAME_MS:
        erros.append(f"engasgo de {pior:.0f} ms: a construcao nao ficou na thread")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print("\nOK — entrou, voltou ao mesmo ponto, sem engasgo e sem no sobrando")
    return 0


if __name__ == "__main__":
    sys.exit(main())
