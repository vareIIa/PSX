#!/usr/bin/env python3
"""Criterio de aceite das lojas de verdade (LojaViva).

A rua comercial tinha 241 portas de loja abertas sem nada atras (censo de
22/09/2026, janela 16 x 20 chunks em volta da origem). A troca foi de
quantidade por qualidade: menos lojas, e cada uma e um lugar. O que se confere:

    placas_sem_loja      ZERO: placa de loja so onde ha loja
    lojas                pelo menos 15 na janela, de pelo menos 8 ramos
    lojas_sem_equipe     ZERO: toda loja tem quem atenda
    caminho_bloqueado    ZERO da calcada ate 2,4 m dentro do salao
    dentro_de_interior   ZERO: a loja e o terreo do predio, na rua
    pagou == preco e item_na_mochila == 1: a conversa vende de verdade

    python tools/verificar_lojas.py
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[loja\] ([a-z0-9_]+)=(\S+)")

# A loja entra no lugar das cascas de loja, e o par medido no mesmo chunk ficou
# entre -658 e +1.448 triangulos. Desde 25/09/2026 os tetos sao os da cidade, um
# por vista (verificar_cidade.TETO_LONGE e TETO_PERTO): chunk de loja e chunk da
# cidade. Medido: 19.664 de longe e 28.496 de perto no pior.
TETO_LONGE = 24000
TETO_PERTO = 36000


def main() -> int:
    if not GODOT.exists():
        print(f"Godot ausente em {GODOT}")
        return 1
    cmd = [str(GODOT), "--path", str(JOGO), "--resolution", "640x360", "--",
           "--fog=leve", "--teste-loja"]
    print("rodando no editor...")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    saida = r.stdout + r.stderr
    v: dict[str, str] = {}
    for m in LINHA.finditer(saida):
        v[m.group(1)] = m.group(2)
    if "fim" not in v:
        print("a rotina nao chegou ao fim; saida do motor:")
        print(saida[-2000:])
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

    # --- a cidade --------------------------------------------------------------
    exigir("placas_sem_loja", num("placas_sem_loja") == 0,
           f"{v.get('placas_sem_loja')} chunk(s) com placa de loja e sem loja: "
           "voltou loja de casca")
    exigir("lojas", num("lojas") >= 15, "menos de 15 lojas na janela do censo")
    exigir("ramos", num("ramos") >= 8, "menos de 8 ramos: a rua virou fila de clone")
    exigir("lojas_sem_equipe", num("lojas_sem_equipe") == 0, "loja sem quem atenda")
    exigir("lojas_sem_cliente", num("lojas_sem_cliente") == 0, "loja sem cliente")
    exigir("lojas_sem_produto", num("lojas_sem_produto") == 0,
           "loja sem prateleira de produto (loja_produtos)")
    exigir("tris_longe_do_pior_chunk_de_loja",
           num("tris_longe_do_pior_chunk_de_loja") <= TETO_LONGE,
           f"chunk de loja com {v.get('tris_longe_do_pior_chunk_de_loja')} triangulos "
           f"na vista de longe, acima de {TETO_LONGE}")
    exigir("tris_perto_do_pior_chunk_de_loja",
           num("tris_perto_do_pior_chunk_de_loja") <= TETO_PERTO,
           f"chunk de loja com {v.get('tris_perto_do_pior_chunk_de_loja')} triangulos "
           f"na vista de perto, acima de {TETO_PERTO}")

    # --- o lugar ---------------------------------------------------------------
    exigir("loja_para_medir", num("loja_para_medir") == 1, "nenhuma loja achada para medir")
    exigir("dentro_de_interior", num("dentro_de_interior") == 0,
           "chegar a loja carregou um interior")
    exigir("dentro_apos_caminhar", num("dentro_apos_caminhar") == 0,
           "entrar na loja disparou carga de interior")
    exigir("portas_na_loja", num("portas_na_loja") == 0, "ha folha de porta na loja")
    exigir("caminho_bloqueado", num("caminho_bloqueado") == 0,
           f"{v.get('caminho_bloqueado')} paradas entre a calcada e o salao nao cabem "
           "uma pessoa: a entrada esta obstruida")
    exigir("chegou_ate", num("chegou_ate") >= 2.3, "nao se chega andando ao salao")
    exigir("degrau_na_boca", num("degrau_na_boca", 99.0) <= 0.05,
           f"o piso da loja esta {v.get('degrau_na_boca')} m fora da calcada")
    exigir("atendentes", num("atendentes") >= 1, "ninguem atendendo no salao montado")
    exigir("gente_na_loja", num("gente_na_loja") >= 2, "salao vazio de gente")
    exigir("luzes_na_loja", num("luzes_na_loja") >= 2, "salao sem luz propria")

    # --- a venda ---------------------------------------------------------------
    exigir("atendente_achado", num("atendente_achado") == 1, "atendente nao achado na cena")
    exigir("conversa_aberta", num("conversa_aberta") == 1, "falar com o atendente nao abriu conversa")
    exigir("opcao_sobre", num("opcao_sobre") == 1, "a conversa nao tem o assunto da loja")
    if v.get("compra") != "sem_mercadoria":
        exigir("opcao_comprar", num("opcao_comprar") == 1, "a conversa nao oferece a mercadoria")
        exigir("pagou", num("pagou") == num("preco") and num("preco") > 0,
               f"pagou {v.get('pagou')} por um item de {v.get('preco')}")
        exigir("item_na_mochila", num("item_na_mochila") == 1, "o item nao entrou na mochila")
    else:
        exigir("opcao_servico", num("opcao_servico") == 1, "a conversa nao oferece o servico")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1
    print(f"\nOK — {len(v) - 2} medidas; cidade sem loja de casca, salao andavel, "
          "equipe e venda de verdade")
    return 0


if __name__ == "__main__":
    sys.exit(main())
