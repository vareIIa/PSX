#!/usr/bin/env python3
"""Criterio de aceite da Fase 5: os sistemas de horror funcionam de verdade.

Roda a rotina TesteHorror dentro do jogo, com fisica, e confere cada numero.
Testa o que da para afirmar objetivamente:

  inventario  espaco contado, empilhamento, sobra quando a bolsa enche, cura
  radio       chiado cresce com a proximidade, e cresce devagar no comeco
  inimigo     ve de frente na linha de visao, nao ve de longe
  save        grava e restaura vida, itens, bateria e posicao

O que nao da para afirmar assim, como se o jogo assusta, nao esta aqui.

    python tools/verificar_horror.py
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[horror\] ([a-z0-9_]+)=([-\d.]+)")


def main() -> int:
    ap = argparse.ArgumentParser()
    # O bug de listagem de recurso so aparecia no pacote: no editor o inventario
    # enchia e no executavel vinha vazio, em silencio. Rodar o mesmo teste nos
    # dois lugares e a unica forma de pegar essa classe de problema.
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
    cmd += ["--", "--fog=leve", "--teste-horror"]
    print("rodando no %s..." % ("build exportado" if args.build else "editor"))
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=420)
    saida = r.stdout + r.stderr

    v: dict[str, float] = {}
    for m in LINHA.finditer(saida):
        v[m.group(1)] = float(m.group(2))

    if "fim" not in v:
        print("a rotina nao chegou ao fim; saida do motor:")
        print(saida[-1200:])
        return 1

    for chave in sorted(v):
        print(f"{chave:28s} {v[chave]}")

    erros: list[str] = []

    def exigir(chave: str, cond: bool, msg: str) -> None:
        if chave not in v:
            erros.append(f"{chave} nao foi reportado")
        elif not cond:
            erros.append(msg)

    # Inventario
    exigir("inv_vazio", v.get("inv_vazio") == 8, "a bolsa nao comeca com 8 espacos")
    exigir("inv_municao", v.get("inv_municao") == 12, "as 12 balas nao entraram")
    exigir("inv_ocupados_apos_pilha", v.get("inv_ocupados_apos_pilha") == 1,
           "12 balas ocuparam mais de um espaco: o empilhamento nao funciona")
    exigir("inv_sobra_com_bolsa_cheia", v.get("inv_sobra_com_bolsa_cheia") == 1,
           "bolsa cheia aceitou item: o limite de espaco nao vale nada")
    exigir("inv_curou", v.get("inv_curou") == 1, "a bandagem nao curou")
    exigir("inv_vida_apos_cura", v.get("inv_vida_apos_cura") == 75,
           f"vida apos cura foi {v.get('inv_vida_apos_cura')}, esperado 75")
    exigir("inv_bandagens_restantes", v.get("inv_bandagens_restantes") == 1,
           "a bandagem usada nao foi consumida")

    # Radio: cresce com a proximidade, e quase nada muda longe.
    exigir("radio_40_m", v.get("radio_40_m", 1.0) < 0.02,
           "o radio ja chia a 40 m: o alcance esta grande demais")
    exigir("radio_4_m", v.get("radio_4_m", 0.0) > 0.7,
           "o radio nao chega perto do maximo a 4 m")
    ordem = [v.get(k, -1.0) for k in ("radio_40_m", "radio_20_m", "radio_10_m", "radio_4_m")]
    if ordem != sorted(ordem):
        erros.append(f"o chiado nao cresce monotonicamente: {ordem}")
    if v.get("radio_20_m", 1.0) > 0.35:
        erros.append("o chiado sobe cedo demais: a curva deveria ser quadratica")

    # Inimigo
    exigir("inimigo_ve_de_frente", v.get("inimigo_ve_de_frente") == 1,
           "o inimigo nao ve o jogador parado a 9 m na linha de visao")
    exigir("inimigo_nao_ve_de_longe", v.get("inimigo_nao_ve_de_longe") == 1,
           "o inimigo percebe alem do alcance de visao")
    exigir("ruido_parado", v.get("ruido_parado") == 0.0,
           "jogador parado faz barulho")

    # Save
    exigir("save_gravou", v.get("save_gravou") == 1, "o save nao gravou")
    exigir("save_carregou", v.get("save_carregou") == 1, "o save nao carregou")
    exigir("save_vida", v.get("save_vida") == 55, "a vida nao foi restaurada")
    exigir("save_municao", v.get("save_municao") == 7, "a municao nao foi restaurada")
    exigir("save_pe_de_cabra", v.get("save_pe_de_cabra") == 1,
           "o item nao empilhavel nao foi restaurado")
    exigir("save_bilhete_sumiu", v.get("save_bilhete_sumiu") == 1,
           "item adquirido depois do save sobreviveu ao carregamento")
    exigir("save_bateria", abs(v.get("save_bateria", 0.0) - 0.42) < 0.02,
           "a bateria da lanterna nao foi restaurada")
    exigir("save_dist_do_ponto", v.get("save_dist_do_ponto", 99.0) < 0.1,
           "o jogador nao voltou para a posicao salva")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print(f"\nOK — {len(v) - 2} medidas, inventario, radio, inimigo e save conferidos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
