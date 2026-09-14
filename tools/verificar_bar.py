#!/usr/bin/env python3
"""Criterio de aceite do Bar do Ze.

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
LIMITE_LUZ = re.compile(r"^limits/opengl/max_lights_per_object=(\d+)", re.M)


def teto_de_luzes() -> int:
    m = LIMITE_LUZ.search((JOGO / "project.godot").read_text(encoding="utf-8"))
    return int(m.group(1)) if m else 8


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
        print(f"{chave:28s} {v[chave]}")

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

    exigir("portas_bar", num("portas_bar") > 0,
           "nenhuma porta da cidade leva a um bar")
    exigir("portas_mercado", num("portas_mercado") > 0,
           "o bar engoliu as portas de mercado")
    exigir("portas_casa", num("portas_casa") > 0,
           "o bar engoliu as portas de casa")
    exigir("portas_bar", num("portas_bar") <= num("portas_mercado"),
           "ha mais bar que mercado; o bar deveria ser mais raro")
    exigir("deslizantes_bar", num("deslizantes_bar") == 0,
           "porta de bar nasceu com folha deslizante: o vao tem de ser aberto")
    exigir("chunks_com_fachada",
           num("chunks_com_fachada") == num("portas_bar"),
           "ha porta de bar sem letreiro na fachada")
    exigir("chunks_com_vao",
           num("chunks_com_vao") == num("portas_bar"),
           "ha porta de bar sem vao preto: da rua le como loja fechada")
    exigir("mesas_calcada", num("mesas_calcada") >= 2,
           "faltam mesas na calcada: da rua o bar nao existe")

    exigir("entrou", num("entrou") == 1, "o jogador nao chegou ao bar")
    exigir("tris", 2500 <= num("tris") <= 18000,
           f"o bar tem {v.get('tris')} triangulos, fora da faixa 2500-18000")
    exigir("superficies_faltando", num("superficies_faltando") == 0,
           f"faltou superficie: {v.get('faltou', '?')}")
    exigir("tv", num("tv") >= 1, "o salao nao tem TV")
    exigir("gente", num("gente") >= 3,
           "faltam pessoas no bar: atendente, cliente e quem assiste o jogo")
    exigir("mesas_dentro", num("mesas_dentro") >= 2,
           "faltam mesas dentro do salao")
    exigir("cadeiras_dentro", num("cadeiras_dentro") >= 4,
           "faltam cadeiras dentro do salao")
    exigir("tem_bar_mesa", num("tem_bar_mesa") == 1,
           "a superficie bar_mesa nao entrou no interior")
    exigir("tem_bar_cadeira", num("tem_bar_cadeira") == 1,
           "a superficie bar_cadeira nao entrou no interior")
    exigir("luzes_totais", num("luzes_totais") <= 8,
           f"{v.get('luzes_totais')} luzes, acima de 8")
    teto = teto_de_luzes()
    exigir("luzes_totais", num("luzes_totais") <= teto,
           f"{v.get('luzes_totais')} luzes, acima do limite {teto} do projeto")
    exigir("pousos_ocupados", num("pousos_ocupados") == 0,
           f"nao cabe uma pessoa em pe em: {v.get('ocupado', '?')}")
    exigir("saida_sem_folha", num("saida_sem_folha") == 1,
           "a saida do bar tem folha: o vao tem de ser aberto")
    exigir("saiu", num("saiu") == 1, "o jogador nao saiu do bar")
    exigir("desvio_no_plano", num("desvio_no_plano", 99.0) < 0.4,
           "o jogador nao voltou para a calcada de onde entrou")

    if v.get("ambiente") != "bar":
        erros.append(f"o ambiente do bar e '{v.get('ambiente')}', esperado 'bar'")
    if v.get("ambiente_apos_sair") == "bar":
        erros.append("sair do bar nao devolveu o ambiente da rua")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print(f"\nOK — {len(v) - 2} medidas; rua, salao, caminhabilidade, "
          "ambiente e saida pelo vao")
    return 0


if __name__ == "__main__":
    sys.exit(main())
