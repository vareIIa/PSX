#!/usr/bin/env python3
"""Criterio de aceite da loja de conveniencia.

Roda a rotina TesteMercado dentro do jogo e confere cada numero. O que da para
afirmar objetivamente:

  cidade    existem portas de loja na rua, com fachada e porta deslizante, sem
            ter engolido as portas de casa e de apartamento
  loja      a planta monta, tem as superficies que definem uma loja, colisao em
            movel, as oito luzes, ponto de save e mercadoria
  ambiente  entrar troca o ambiente para o preset da loja, e sair devolve
  saida     a porta automatica tem duas folhas, elas correm, e o jogador volta
            para a posicao de onde entrou

O que nao da para afirmar assim, como se a loja parece uma loja, nao esta aqui:
para isso existe a captura.

    python tools/verificar_mercado.py [--build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[mercado\] ([a-z0-9_]+)=(\S+)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", action="store_true",
                    help="roda no executavel exportado em vez do editor")
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
    cmd += ["--", "--fog=leve", "--teste-mercado"]

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

    # --- a rua leva ate a loja ---
    exigir("portas_mercado", num("portas_mercado") > 0,
           "nenhuma porta da cidade leva a uma loja")
    exigir("portas_casa", num("portas_casa") > 0,
           "a loja engoliu as portas de casa")
    exigir("portas_apartamento", num("portas_apartamento") > 0,
           "a loja engoliu as portas de apartamento")
    # A loja tem de ser rara: se metade das portas do comercio for loja, deixa
    # de ser um destino e vira paisagem.
    exigir("portas_mercado", num("portas_mercado") < num("portas_apartamento"),
           "ha mais loja que apartamento; a loja deveria ser rara")
    exigir("portas_deslizantes",
           num("portas_deslizantes") == num("portas_mercado"),
           "porta de loja sem folha deslizante, ou deslizante fora da loja")
    exigir("chunks_com_fachada",
           num("chunks_com_fachada") == num("portas_mercado"),
           "ha porta de loja sem letreiro na fachada: da rua nao da para saber "
           "que ali tem loja")

    # --- a loja montada ---
    exigir("entrou", num("entrou") == 1, "o jogador nao chegou a loja")
    exigir("tris", 1500 <= num("tris") <= 22000,
           f"a loja tem {v.get('tris')} triangulos, fora da faixa esperada")
    exigir("superficies_faltando", num("superficies_faltando") == 0,
           f"faltou superficie que define a loja: {v.get('faltou', '?')}")
    exigir("colisores", num("colisores") >= 18,
           f"so {v.get('colisores')} colisores: gondola sem colisao e atravessavel")
    exigir("luzes", num("luzes") == 8,
           f"{v.get('luzes')} luzes, esperado 8: quatro calhas de corredor, a da "
           "frente, duas da camara fria e a da vitrine quente")
    exigir("ponto_de_save", num("ponto_de_save") == 1,
           "a loja nao tem onde salvar; e o unico lugar seguro do bairro")
    exigir("itens", num("itens") >= 3,
           "a loja nao tem mercadoria para levar")
    exigir("pegou_da_prateleira", num("pegou_da_prateleira") == 1,
           "pegar item da prateleira nao pos nada na bolsa")

    # --- ambiente ---
    if v.get("ambiente") != "mercado":
        erros.append(f"o ambiente da loja e '{v.get('ambiente')}', esperado "
                     "'mercado': a luz branca e chapada e metade do comodo")
    if v.get("ambiente_apos_sair") == "mercado":
        erros.append("sair da loja nao devolveu o ambiente da rua")

    # --- porta automatica ---
    exigir("porta_automatica", num("porta_automatica") == 1,
           "a saida da loja nao e porta automatica")
    exigir("folhas", num("folhas") == 2,
           f"a porta automatica tem {v.get('folhas')} folhas, esperado 2")
    exigir("folha_correu", num("folha_correu") == 1,
           "as folhas nao correram ao abrir")
    exigir("saiu", num("saiu") == 1, "o jogador nao saiu da loja")
    exigir("desvio_no_plano", num("desvio_no_plano", 99.0) < 0.4,
           "o jogador nao voltou para a posicao de onde entrou")
    exigir("queda", abs(num("queda", 99.0)) < 1.5,
           "o jogador voltou no ar e caiu longe demais")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print(f"\nOK — {len(v) - 2} medidas; cidade, loja, ambiente e saida conferidos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
