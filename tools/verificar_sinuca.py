#!/usr/bin/env python3
"""Criterio de aceite da sinuca do bar (PLANO_BAR_E_CIDADE_AAA, Fase 2).

Duas etapas:

1. Bancada headless (`tests/bancada_sinuca.gd`): a fisica contra a solucao
   fechada (rolamento, choque de frente, regra dos 90 graus, tabela), a quebra
   (para, nao sobrepoe, nao sai da mesa, e determinista), o custo por segundo
   simulado e uma partida inteira IA contra IA.
2. Partida no jogo, com janela (`--sinuca-demo`): a mesa do Seu Ze comeca
   sozinha, os dois lados na IA, ate alguem matar a 8. Prova que o no do jogo,
   a camera, o painel e o som rodam juntos sem erro, e grava as fotos.

    python tools/verificar_sinuca.py [--fotos DIR] [--sem-janela]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"
LINHA = re.compile(r"\[sinuca\] (\S+)=(\S+)(?: (ok|FALHA))?")


def bancada():
    cmd = [str(GODOT), "--headless", "--path", str(JOGO), "--script",
           "res://tests/bancada_sinuca.gd"]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    saida = r.stdout + r.stderr
    falhas = []
    for m in LINHA.finditer(saida):
        print(f"  {m.group(1):28s} {m.group(2):>10s}  {m.group(3) or ''}")
        if m.group(3) == "FALHA":
            falhas.append(m.group(1))
    if "SCRIPT ERROR" in saida:
        falhas.append("erro de script na bancada")
    if "falhas=" not in saida:
        falhas.append("a bancada nao terminou")
    return falhas


def partida(fotos):
    cmd = [str(GODOT), "--path", str(JOGO), "--resolution", "1280x720",
           "res://scenes/test/cidade.tscn", "--", "--pular-menu", "--ver-bar",
           "--bar-cena=sinuca", "--sinuca-demo", "--sinuca-sair"]
    if fotos:
        cmd.append(f"--sinuca-fotos={fotos}")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    saida = r.stdout + r.stderr
    falhas = []
    tacadas = len(re.findall(r"\[sinuca\] tacada=", saida))
    fim = re.search(r"\[sinuca\] fim_de_jogo vencedor=(\d) tacadas=(\d+)", saida)
    erros = [l for l in saida.splitlines() if "SCRIPT ERROR" in l]
    print(f"  tacadas                      {tacadas:>10d}")
    print(f"  fim_de_jogo                  {'sim' if fim else 'nao':>10s}")
    if "[sinuca] demo" not in saida:
        falhas.append("a partida demo nao comecou (mesa longe do jogador?)")
    if not fim:
        falhas.append("a partida nao terminou")
    if tacadas < 3:
        falhas.append("menos de tres tacadas")
    if erros:
        falhas.append(f"{len(erros)} erro(s) de script: {erros[0]}")
    return falhas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fotos", default="")
    ap.add_argument("--sem-janela", action="store_true")
    args = ap.parse_args()
    print("bancada:")
    falhas = bancada()
    if not args.sem_janela:
        print("partida:")
        falhas += partida(args.fotos)
    if falhas:
        print("\nFALHOU")
        for f in falhas:
            print(f"  x {f}")
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
