#!/usr/bin/env python3
"""Criterio de aceite do transito da cidade.

Roda a rotina TesteTransito dentro do jogo e confere cada numero. Existe porque
o transito era a unica parte grande do jogo sem nenhuma medida: a cidade tinha
55 medidas de geometria e o carro do jogador 47 de direcao, e a rua podia estar
travada sem que uma linha de relatorio mudasse.

Os criterios sao experimentos MONTADOS, e nao observacao do transito solto: duas
execucoes seguidas da observacao livre, sem uma linha mudada, deram 0,53 e 1,00
de frota em movimento, porque o que a rua faz depende de onde o jogador nasceu.
O que se mede aqui e sempre o mesmo carro, na mesma faixa, na mesma luz.

  parada      o carro para ANTES da linha de retencao. A IA parava "ao entrar na
              zona do sinal" em vez de "na linha", e a zona era maior que a
              distancia de freio: ele entrava a 11 m/s, freava a 8 m/s2 e parava
              a 1,60 m do CENTRO — tres metros alem da linha, atravessado na
              frente de quem tinha verde, pelo vermelho inteiro
  partida     quando a luz abre, ele sai. Um criterio de parada sem criterio de
              partida aprovaria uma cidade de estatuas — e quase aprovou: a
              primeira versao do conserto declarava "comprometido" quem tivesse
              a linha para tras, e o carro parado EM CIMA dela saia sozinho no
              vermelho
  fila        quem chega atras para atras, com folga de para-choque, e nao
              dentro da lataria do outro nem por cima dela
  contorno    um carro parado na pista nao tranca a faixa. E a situacao que o
              jogo produz toda vez que o jogador estaciona um carro tomado e
              desce, e sem saida ela prendia a faixa ate o bairro ser
              descarregado. Fila de semaforo, essa, nao se ultrapassa

    python tools/verificar_transito.py [--build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[transito\] ([a-z0-9_]+)=(.+)")

## O teste observa 26 s de transito, espera um ciclo de semaforo, mede a parada
## e mede o contorno; a cidade ainda leva tempo para montar. O limite e folga
## sobre isso.
TEMPO_LIMITE = 600

## Quanto o bico pode passar da linha de retencao, em metros.
##
## Um metro. Nao e zero porque a linha e um ponto e a parada e um processo:
## o ultimo passo de fisica antes de zerar ainda anda alguns centimetros. E nao
## e tres, que era o erro — tres metros poem o para-choque no meio da faixa de
## quem esta atravessando.
FOLGA_PARADA = 1.0

## Folga minima entre dois carros em fila, de centro a centro, em metros.
##
## O carro tem 4,2 m de comprimento e a folga de para-choque e 1,5 m, entao a
## conta da 5,7. Cinco metros aceita o carro mais curto da frota sem aceitar
## duas latarias no mesmo lugar.
MIN_FILA = 5.0

## Quanto ele pode demorar para sair depois do verde, em segundos.
MAX_PARTIDA = 2.5


def numero(d: dict, chave: str) -> float:
    try:
        return float(d.get(chave, "nan"))
    except ValueError:
        return float("nan")


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
    cmd += ["--", "--teste-transito"]

    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           timeout=TEMPO_LIMITE)
    except subprocess.TimeoutExpired:
        print(f"FALHA  o teste nao terminou em {TEMPO_LIMITE} s")
        return 1

    saida = r.stdout + r.stderr
    dados: dict[str, str] = {}
    for linha in saida.splitlines():
        m = LINHA.match(linha.strip())
        if m:
            dados[m.group(1)] = m.group(2).strip()

    if not dados.get("fim"):
        print("FALHA  a rotina nao chegou ao fim. Saida:")
        print("\n".join(saida.splitlines()[-40:]))
        return 1

    falhas: list[str] = []

    def exigir(ok: bool, texto: str) -> None:
        marca = "ok  " if ok else "NAO "
        print(f"  {marca} {texto}")
        if not ok:
            falhas.append(texto)

    print("== a rua existe ==")
    exigir(numero(dados, "vivos") >= 2,
           f"ha transito para medir ({dados.get('vivos')} carros)")
    if numero(dados, "vivos") < 2:
        print()
        print("FALHA  sem carros na rua o resto do relatorio nao diz nada.")
        return 1

    print("== onde ele para ==")
    exigir(dados.get("sinal_montado") == "1",
           "deu para montar o experimento (carro largando no vermelho)")
    if dados.get("sinal_montado") == "1":
        exigir(dados.get("sinal_parou") == "1",
               "o carro parou no vermelho")
        alem = numero(dados, "sinal_alem_da_linha_m")
        exigir(alem <= FOLGA_PARADA,
               f"e parou ANTES da linha de retencao "
               f"({alem:+.2f} m alem dela, teto {FOLGA_PARADA:+.2f}; "
               f"a linha fica a {dados.get('sinal_linha_m')} m do centro e ele "
               f"encostou a {dados.get('sinal_do_centro_m')} m)")
        partiu = numero(dados, "verde_partiu_s")
        exigir(partiu == partiu and partiu <= MAX_PARTIDA,
               f"e saiu quando a luz abriu ({dados.get('verde_partiu_s')} s "
               f"depois do verde, teto {MAX_PARTIDA})")

        print("== fila ==")
        exigir(dados.get("fila_parou") == "1",
               "quem chegou atras tambem parou")
        exigir(numero(dados, "fila_folga_m") >= MIN_FILA,
               f"e parou ATRAS, e nao dentro da lataria do outro "
               f"({dados.get('fila_folga_m')} m de centro a centro, "
               f"minimo {MIN_FILA})")

    # Esquina sem semaforo: desde que so a avenida tem luz (Semaforo.tem_sinal),
    # a rua de bairro e PARE e preferencia. Sem este experimento, "o carro para
    # e cede" seria palavra — os raios do carro so olham para a frente, e quem
    # vem de lado so aparece na batida.
    print("== PARE (esquina sem semaforo) ==")
    exigir(dados.get("pare_montado") == "1",
           "deu para montar o experimento (um pela secundaria, um pela preferencial)")
    if dados.get("pare_montado") == "1":
        exigir(dados.get("pare_parou") == "1",
               "quem vinha pela secundaria parou na linha")
        alem_pare = numero(dados, "pare_alem_da_linha_m")
        exigir(alem_pare <= FOLGA_PARADA,
               f"e parou ANTES da linha ({alem_pare:+.2f} m alem dela, "
               f"teto {FOLGA_PARADA:+.2f})")
        exigir(dados.get("pare_cedeu") == "1",
               "e nao entrou com o da preferencial chegando perto")
        exigir(dados.get("pare_atravessou") == "1",
               "e depois atravessou (PARE nao e parede)")

    print("== carro parado na pista ==")
    exigir(dados.get("contorno_montado") == "1",
           "deu para montar a situacao (um carro parado, outro chegando atras)")
    if dados.get("contorno_montado") == "1":
        exigir(dados.get("contorno_passou") == "1",
               f"o carro de tras passou pelo parado "
               f"(preso por {dados.get('contorno_preso_s')} s antes)")
        exigir(dados.get("contorno_decidiu") == "1",
               "e passou CONTORNANDO, e nao atravessando a lataria")

    # PLANO_TRANSITO_AAA, Passo 3: quem desce da calcada numa zebra com sinal so
    # desce no ANDA. E contagem de violacao — zero e zero em qualquer rodada —,
    # entao vale como criterio mesmo observada na rua solta.
    print("== pedestre e boneco ==")
    if "ped_descidas_com_sinal" in dados:
        exigir(numero(dados, "ped_fora_do_anda") == 0,
               f"nenhuma travessia com sinal comecada fora do ANDA "
               f"({dados.get('ped_fora_do_anda')} de "
               f"{dados.get('ped_descidas_com_sinal')} na observacao)")
        print(f"       travessias comecadas (todas): {dados.get('ped_travessias')}")

    print("== a rua andando (informa, nao reprova) ==")
    print(f"       frota em movimento: {dados.get('obs_fracao_andando')}")
    print(f"       rodados pela frota: {dados.get('obs_andado_m')} m")
    print(f"       parada mais longa:  {dados.get('obs_parada_mais_longa_s')} s"
          f" (motivo: {dados.get('obs_motivo_da_maior')})")

    # O motorista da IA (PLANO_TRANSITO_AAA): quanto ele custa na rua de
    # verdade. A bancada (tests/bancada_transito.gd) mede com a malha fria.
    print("== o motorista (informa, nao reprova) ==")
    print(f"       ia: {dados.get('ia')}")
    print(f"       pior planejamento de quarteirao: {dados.get('ia_pior_planejar_ms')} ms")
    print(f"       pior primeiro planejamento:      {dados.get('ia_pior_inicial_ms')} ms")
    print(f"       passo medio por carro:           {dados.get('ia_passo_medio_ms')} ms")

    print()
    if falhas:
        print(f"FALHA  {len(falhas)} criterio(s) nao cumprido(s):")
        for f in falhas:
            print(f"  - {f}")
        return 1
    print("transito: todos os criterios cumpridos")
    return 0


if __name__ == "__main__":
    sys.exit(main())
