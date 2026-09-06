#!/usr/bin/env python3
"""Criterio de aceite da casa com morador.

Roda a rotina TesteCasa dentro do jogo, com fisica, e confere cada numero. O que
da para afirmar objetivamente:

  casa      a planta e montada, tem colisao em movel e as quatro luzes
  morador   comeca de costas, vira quando o jogador chega perto
  conversa  abre, trava o jogador, anda ate o fim, solta, entrega o presente
            e no segundo papo o assunto mudou
  porta     a trancada nao abre e nao tira o jogador do interior
  saida     sai da casa e volta para a posicao de onde entrou

O que nao da para afirmar assim, como se a sala parece a casa de alguem, nao
esta aqui — para isso existe a captura.

    python tools/verificar_casa.py [--build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[casa\] ([a-z0-9_]+)=(\S+)")


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
    cmd += ["--", "--fog=leve", "--teste-casa"]

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

    # --- a rua leva ate a casa ---
    exigir("portas_casa", num("portas_casa") > 0,
           "nenhuma porta da cidade leva a uma casa: a planta existe mas e "
           "inalcancavel")
    exigir("portas_apartamento", num("portas_apartamento") > 0,
           "toda porta virou casa; o apartamento sumiu da cidade")

    # --- casa ---
    exigir("entrou", num("entrou") == 1, "o jogador nao chegou ao interior")
    # Faixa larga de proposito: o teste protege contra a planta vir vazia ou
    # explodir de tamanho, nao contra o movel mudar de lugar.
    exigir("tris", 1500 <= num("tris") <= 20000,
           f"a casa tem {v.get('tris')} triangulos, fora da faixa esperada")
    exigir("colisores", num("colisores") >= 20,
           f"so {v.get('colisores')} colisores: movel sem colisao e atravessavel")
    exigir("luzes", num("luzes") == 5,
           f"{v.get('luzes')} luzes, esperado 5: teto da sala, abajur, cozinha, "
           "corredor e o brilho da TV")

    # --- morador ---
    exigir("npc", num("npc") == 1, "nao ha morador na casa")
    exigir("npc_de_costas", num("npc_de_costas") > 1.2,
           "o morador nao comeca de costas: a encenacao da entrada se perde")
    exigir("npc_virou", num("npc_virou", 9.0) < 0.2,
           "o morador nao se virou para o jogador que chegou perto")

    # --- conversa ---
    exigir("dialogo_abriu", num("dialogo_abriu") == 1, "a caixa de fala nao abriu")
    exigir("jogador_travado", num("jogador_travado") == 1,
           "o jogador continua andando durante a fala")
    exigir("dialogo_fechou", num("dialogo_fechou") == 1,
           "a conversa nao terminou sozinha")
    exigir("dialogo_passos", num("dialogo_passos") >= 4,
           "a conversa fechou cedo demais para ter mostrado as falas")
    exigir("jogador_solto", num("jogador_solto") == 1,
           "o jogador ficou preso depois da conversa")
    exigir("presente", num("presente") == 1,
           "o morador nao entregou o item da primeira conversa")
    exigir("assunto_avancou", num("assunto_avancou") == 1,
           "a segunda conversa repetiria a fala de chegada")

    # --- porta trancada ---
    exigir("porta_trancada", num("porta_trancada") == 1,
           "nao ha porta trancada no fim do corredor")
    exigir("porta_rotulo_trancada", num("porta_rotulo_trancada") == 1,
           "a porta trancada nao se anuncia como trancada")
    exigir("porta_trancada_nao_abre", num("porta_trancada_nao_abre") == 1,
           "acionar a porta trancada tirou o jogador do interior")

    # --- saida ---
    exigir("saiu", num("saiu") == 1, "o jogador nao saiu da casa")
    exigir("dist_do_retorno", num("dist_do_retorno", 99.0) < 0.6,
           "o jogador nao voltou para a posicao de onde entrou")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print(f"\nOK — {len(v) - 2} medidas; casa, morador, conversa e saida conferidos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
