#!/usr/bin/env python3
"""Criterio de aceite da malha urbana, do gerador de parque e do mapa.

Roda a rotina TesteCidade dentro do jogo e confere cada numero. O que da para
afirmar objetivamente:

  malha     ha avenida e rua secundaria nos dois eixos, com viela entre elas; as
            quadras nao tem todas o mesmo tamanho; e o miolo de quadra grande
            nao e um buraco
  predios   altura, fachada, cor, coroamento e recuo variam de quadra para
            quadra, e nao de predio para predio
  parque    a quadra de parque nasce com grama, caminho, vegetacao, mobiliario e
            luz; ha mais de um traco de parque; e a folhagem balanca enquanto o
            asfalto nao
  ordem     o parque montado na ordem inversa sai identico ao da ordem direta.
            E o teste que pega o defeito de sorteio compartilhado entre chunks,
            que ja aconteceu uma vez e nao aparece em captura nenhuma
  mapa      os oito icones existem, o mapa monta, e cada porta que ele anuncia
            existe no mundo na mesma posicao
  custo     nenhum chunk passa do teto de triangulos

O que nao da para afirmar assim, como se o parque parece um parque, nao esta
aqui: para isso existe a captura.

    python tools/verificar_cidade.py [--build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[cidade\] ([a-z0-9_]+)=(\S+)")

## Teto de triangulos por chunk. ART-BIBLE secao 10.
TETO_TRIANGULOS = 6000


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
    cmd += ["--", "--fog=leve", "--teste-cidade"]

    print("rodando no %s..." % ("build exportado" if args.build else "editor"))
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
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

    # --- a malha corre nos dois eixos e nao e um tabuleiro ---
    exigir("avenidas_x", num("avenidas_x") >= 5,
           "poucas avenidas no eixo X: a cidade perde a grade arterial")
    exigir("avenidas_z", num("avenidas_z") >= 5,
           "poucas avenidas no eixo Z: so ha rua indo para a frente")
    exigir("ruas_x", num("ruas_x") >= 2, "nenhuma rua secundaria no eixo X")
    exigir("ruas_z", num("ruas_z") >= 2, "nenhuma rua secundaria no eixo Z")
    exigir("vielas", num("vielas") >= 1, "nenhuma viela: falta a via estreita")
    # A prova de que a malha nao e tabuleiro: rua que termina em outra. Uma
    # malha de linhas inteiras nao tem entroncamento em T nenhum (Tracado).
    exigir("entroncamentos_em_t", num("entroncamentos_em_t") >= 10,
           "quase nenhum entroncamento em T: as ruas voltaram a ser linhas inteiras")
    exigir("larguras_quadra", num("larguras_quadra") >= 2,
           "todas as quadras tem a mesma largura")
    exigir("fundos_quadra", num("fundos_quadra") >= 2,
           "todas as quadras tem a mesma profundidade")
    exigir("chunks_sem_rua", num("chunks_sem_rua") >= 1,
           "nao ha miolo de quadra grande: as quadras nunca passam de dois chunks")
    exigir("miolos_preenchidos",
           num("miolos_preenchidos") == num("chunks_sem_rua"),
           "ha miolo de quadra vazio: aparece como buraco pela fresta")

    # --- variacao por quadra ---
    exigir("quadras", num("quadras") >= 8, "poucas quadras na varredura")
    exigir("alturas", num("alturas") >= 3,
           "os predios tem menos de tres alturas de quadra: a cidade fica plana")
    exigir("fachadas", num("fachadas") >= 3, "menos de tres materiais de fachada")
    exigir("tintas", num("tintas") >= 4,
           "menos de quatro cores de quadra: os quarteiroes nao se distinguem")
    exigir("coroamentos", num("coroamentos") >= 3,
           "menos de tres remates de topo: a silhueta nao varia")
    exigir("recuos", num("recuos") >= 2, "nenhuma quadra recuada da calcada")

    # --- parque ---
    exigir("quadras_parque", num("quadras_parque") >= 1,
           "nenhuma quadra virou parque na varredura")
    exigir("tracos_de_parque", num("tracos_de_parque") >= 2,
           "so ha um traco de parque: e um parque, nao um gerador")
    exigir("nomes_de_parque", num("nomes_de_parque") >= 2,
           "todos os parques tem o mesmo nome")
    for peca in ("grama", "folhagem", "folhagem_recorte", "casca",
                 "pedra_parque", "arbusto"):
        exigir(f"parque_tem_{peca}", num(f"parque_tem_{peca}") == 1,
               f"o parque nasceu sem {peca}")
    exigir("parque_triangulos_folha", num("parque_triangulos_folha") >= 400,
           "quase nao ha folhagem no parque")
    exigir("recorte_folha", num("recorte_folha") > 0.1,
           "a copa perdeu o corte por alfa: a arvore volta a ser um bloco verde")
    exigir("parque_lampadas", num("parque_lampadas") >= 2,
           "o parque nao tem iluminacao propria")
    exigir("parque_emissores", num("parque_emissores") >= 1,
           "o parque nao emite som de folhas")
    exigir("parque_colisoes", num("parque_colisoes") >= 20,
           "o mobiliario do parque nao tem colisao: da para atravessar tudo")

    # --- ordem de montagem ---
    exigir("parque_ordem_divergente", num("parque_ordem_divergente") == 0,
           "o parque muda conforme a ordem em que os chunks sao montados: "
           "ha sorteio saindo de fluxo compartilhado")

    # --- vento ---
    exigir("vento_folhagem", num("vento_folhagem") > 0.02,
           "a folhagem nao balanca")
    exigir("vento_corrente", num("vento_corrente") > 0.01,
           "o balanco do parquinho esta parado")
    exigir("vento_asfalto", num("vento_asfalto") == 0.0,
           "o asfalto esta balancando ao vento")
    exigir("som_folhas", num("som_folhas") == 1, "falta o som de folhas")
    exigir("som_grilo", num("som_grilo") == 1, "falta o som de grilo")

    # --- mapa ---
    exigir("icones_ausentes", num("icones_ausentes") == 0,
           "falta icone de mapa no disco")
    exigir("icones", num("icones") >= 8, "menos de oito icones preparados")
    exigir("mapa_montou", num("mapa_montou") == 1, "o mapa nao montou")
    exigir("mapa_lugar", num("mapa_lugar") == 1,
           "o mapa nao sabe dizer onde o jogador esta")
    exigir("mapa_erro_quadra", num("mapa_erro_quadra", 99.0) < 0.01,
           "o retangulo que o mapa pinta nao bate com o que o chunk constroi")
    exigir("ponto_parque", num("ponto_parque") >= 1,
           "o parque nao aparece como ponto de interesse")
    exigir("ponto_telefone", num("ponto_telefone") >= 1,
           "nenhum telefone no mapa")
    exigir("portas_anunciadas", num("portas_anunciadas") >= 5,
           "o mapa anuncia quase nenhuma porta")
    exigir("portas_casadas", num("portas_casadas") == num("portas_anunciadas"),
           "o mapa anuncia porta que o mundo nao tem, ou em outra posicao")
    exigir("pontos_fora_do_chunk", num("pontos_fora_do_chunk") == 0,
           "ha ponto de interesse fora do proprio chunk")

    # --- custo ---
    exigir("tris_pior", num("tris_pior") <= TETO_TRIANGULOS,
           f"chunk com {num('tris_pior'):.0f} triangulos, acima do teto de "
           f"{TETO_TRIANGULOS}")

    print()
    if erros:
        print("FALHOU")
        for e in erros:
            print("  x", e)
        return 1
    print("OK — %d medidas" % len(v))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
