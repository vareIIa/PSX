#!/usr/bin/env python3
"""Criterio de aceite do Bar do Seu Ze.

O bar nao e um interior: e o terreo vazado de um trecho de predio, construido
no chunk, sem porta e sem carga. Por isso o criterio central aqui nao e "o
interior montou", e sim tres numeros juntos:

    portas_no_bar        tem de ser ZERO
    caminho_bloqueado    tem de ser ZERO da calcada ate o fundo do salao
    dentro_de_interior   tem de ser ZERO o tempo todo

    python tools/verificar_bar.py
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[bar\] ([a-z0-9_]+)=(\S+)")

# Teto de triangulos do chunk, o mesmo de verificar_cidade.py. O bar mora
# DENTRO deste orcamento agora, e nao no orcamento folgado de um interior.
TETO_CHUNK = 6000


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", action="store_true")
    args = ap.parse_args()

    exe = RAIZ / "export" / "NevoaEDither.exe"
    if args.build:
        if not exe.exists():
            print(f"build ausente em {exe}; rode ./dev.sh export")
            return 1
        cmd = [str(exe), "--resolution", "640x360"]
    else:
        if not GODOT.exists():
            print(f"Godot ausente em {GODOT}")
            return 1
        cmd = [str(GODOT), "--path", str(JOGO), "--resolution", "640x360"]
    cmd += ["--", "--fog=leve", "--teste-bar"]

    print("rodando no %s..." % ("build exportado" if args.build else "editor"))
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=420)
    saida = r.stdout + r.stderr

    v: dict[str, str] = {}
    for m in LINHA.finditer(saida):
        v[m.group(1)] = m.group(2)

    if "fim" not in v:
        print("a rotina nao chegou ao fim; saida do motor:")
        print(saida[-1800:])
        return 1

    for chave in sorted(v):
        print(f"{chave:26s} {v[chave]}")

    erros: list[str] = []

    def num(chave: str, padrao: float = -1.0) -> float:
        try:
            return float(v.get(chave, padrao))
        except ValueError:
            return padrao

    def exigir(chave: str, cond: bool, msg: str) -> None:
        if chave not in v:
            erros.append(f"{chave} nao foi reportado")
        elif not cond:
            erros.append(msg)

    # --- o bar existe e nao comeu os outros lugares -------------------------
    exigir("bares", num("bares") > 0, "a cidade nao produziu nenhum bar")
    exigir("portas_mercado", num("portas_mercado") > 0,
           "o bar engoliu as portas de mercado")
    exigir("portas_casa", num("portas_casa") > 0,
           "o bar engoliu as portas de casa")
    exigir("bares", num("bares") <= num("portas_mercado"),
           "ha mais bar que mercado; o bar deveria ser mais raro")
    exigir("bar_na_cidade", num("bar_na_cidade") == 1,
           "nenhum bar foi encontrado para medir")

    # --- o bar e RUA, nao interior ------------------------------------------
    exigir("portas_no_bar", num("portas_no_bar") == 0,
           f"ha {v.get('portas_no_bar')} porta(s) dentro do bar; o lugar "
           "voltou a ter folha para abrir")
    exigir("dentro_de_interior", num("dentro_de_interior") == 0,
           "chegar ao bar carregou um interior; ele deveria ser o terreo "
           "do proprio predio, na rua")
    exigir("dentro_apos_caminhar", num("dentro_apos_caminhar") == 0,
           "andar para dentro do bar disparou carga de interior")
    exigir("caminho_bloqueado", num("caminho_bloqueado") == 0,
           f"{v.get('caminho_bloqueado')} paradas entre a calcada e o fundo "
           "do salao nao cabem uma pessoa em pe: a entrada esta obstruida")
    exigir("chegou_ate", num("chegou_ate") >= 4.5,
           f"a pe so se chega a z={v.get('chegou_ate')} m dentro do bar; o "
           "salao inteiro tem de ser andavel")
    exigir("distancia_da_boca", num("distancia_da_boca", 99.0) < 6.0,
           "o jogador terminou a caminhada longe do bar: alguma coisa ainda "
           "teleporta")

    # --- o lugar tem o que um boteco tem ------------------------------------
    exigir("superficies_faltando", num("superficies_faltando") == 0,
           f"faltou superficie no chunk do bar: {v.get('faltou', '?')}")
    exigir("mesas", num("mesas") >= 6,
           "faltam mesas entre calcada e salao")
    exigir("gente_no_bar", num("gente_no_bar") >= 5,
           "falta gente no bar: atendente, cliente, quem assiste o jogo e a "
           "dupla da sinuca")
    exigir("tv", num("tv") >= 1, "o salao nao tem TV")
    exigir("ponto_de_save", num("ponto_de_save") >= 1,
           "o bar nao tem telefone para salvar")
    exigir("luzes_no_bar", num("luzes_no_bar") >= 3,
           "o salao ficou sem luz propria; da rua ele le como buraco")

    # --- orcamento do chunk -------------------------------------------------
    exigir("tris_do_chunk_do_bar", num("tris_do_chunk_do_bar") <= TETO_CHUNK,
           f"o chunk do bar tem {v.get('tris_do_chunk_do_bar')} triangulos, "
           f"acima do teto de {TETO_CHUNK} de verificar_cidade.py")

    if v.get("ambiente", "") == "bar":
        erros.append("o clima trocou para um preset de bar; o bar e rua e "
                     "tem de usar o clima da cidade")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print(f"\nOK — {len(v) - 2} medidas; cidade, frente aberta, caminhada de "
          "ponta a ponta, mobilia e orcamento do chunk")
    return 0


if __name__ == "__main__":
    sys.exit(main())
