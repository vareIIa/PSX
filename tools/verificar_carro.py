#!/usr/bin/env python3
"""Criterio de aceite do carro dirigivel.

Roda a rotina TesteCarro dentro do jogo e confere cada numero. O que da para
afirmar objetivamente:

  acesso      ha carro na rua, a tecla de entrar entrega o volante, e o motor de
              um carro tomado em movimento continua ligado
  frota       os sete modelos sao carros DIFERENTES: nenhum carrega relacao
              morta, o mais lento leva o dobro do tempo do mais rapido aos 100
              km/h, e a velocidade final os separa em mais de 50 km/h. O
              limitador corta quando a roda force o motor acima do corte
  arrancada   com o pe no fundo o carro sai do lugar e cruza os 40 km/h
  esterco     virando para a esquerda o carro vai para a esquerda
  freio       a desaceleracao com o pedal no fundo e de carro, nao de caminhao
  painel      o mostrador existe, esta visivel, marca a velocidade, a rotacao e
              a marcha que o carro esta fazendo, e cabe num lugar da tela onde a
              vinheta do pos-processamento nao o apaga
  saida       sair devolve o jogador ao chao, de pe, fora da lataria, e leva o
              mostrador embora

O que nao da para afirmar assim — se o motor soa bem — nao esta aqui. Para isso
existe o ouvido, e `tools/gerar_motor.py` explica o que cada amostra tenta ser.

    python tools/verificar_carro.py [--build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[carro\] ([a-z0-9_]+)=(.+)")

## Tempo de sobra. O teste tem seis segundos de arrancada, tres de esterco,
## quatro de freio e seis de espera de transito, mais a cidade montando.
TEMPO_LIMITE = 900

## Quantos pedacos de marca de pneu uma derrapagem de dois segundos tem de
## deixar. Cada pedaco e de 0,30 m, entao seis sao 1,8 m de rastro — o minimo
## que se ve de dentro do carro. A primeira versao deixava DOIS, porque o
## limiar nao tinha histerese e a trilha era cortada e recomecada a cada
## oscilacao do escorregamento; ver `RastroPneu.LIMIAR_SOLTA`.
MIN_MARCAS = 6

## Quanto a marca pode ficar acima do asfalto, em metros.
##
## A conta de projeto — centro da roda menos o raio — errava por 5 cm e punha a
## marca ENTERRADA no chao: desenhada, contada pelo teste e invisivel na tela.
## O criterio e de dois lados: acima de zero (senao some no asfalto) e abaixo
## deste teto (senao flutua).
MARCA_MAX_ACIMA = 0.08


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
    cmd += ["--", "--teste-carro"]

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

    print("== acesso ==")
    exigir(numero(dados, "transito_vivos") >= 1,
           f"ha carro na rua ({dados.get('transito_vivos')})")
    exigir(dados.get("acesso") == "1",
           "a tecla de entrar entrega o volante")
    exigir(dados.get("tinha_motorista") == "1",
           "o carro tomado tinha motorista, e ele desceu")
    exigir(dados.get("ja_ligado") == "1",
           "carro tomado em movimento chega com o motor ligado")
    exigir(dados.get("ignicao") == "1", "o motor esta ligado ao dirigir")

    if dados.get("acesso") != "1":
        print(f"       motivo: {dados.get('acesso_motivo', 'nao relatado')}")
        print()
        print("FALHA  sem volante nao ha o que medir; o resto do relatorio seria"
              " uma coluna de vazios.")
        return 1

    print("== farol ==")
    exigir(dados.get("modelos_sem_dois_farois") == "-",
           f"os sete modelos tem dois farois "
           f"(sem: {dados.get('modelos_sem_dois_farois')})")
    exigir(dados.get("farois_fora_do_lugar") == "-",
           f"um farol de cada lado, longe da linha de centro "
           f"(fora: {dados.get('farois_fora_do_lugar')})")
    exigir(numero(dados, "fachos_no_carro") == 2,
           f"o carro da rua monta os DOIS fachos, e nao um no meio do bico "
           f"({dados.get('fachos_no_carro')})")

    print("== a frota ==")
    exigir(numero(dados, "sons_faltando") == 0,
           f"o banco de som do motor esta completo "
           f"({dados.get('sons_faltando')} faltando)")
    exigir(dados.get("frota_marchas_erradas") == "-",
           f"nenhum modelo carrega relacao morta — toda marcha declarada entra "
           f"em algum pe (mortas: {dados.get('frota_marchas_erradas')})")
    lento = numero(dados, "frota_cem_max")
    rapido = numero(dados, "frota_cem_min")
    exigir(rapido > 0 and lento / rapido >= 2.0,
           f"o carro mais lento leva pelo menos o DOBRO do tempo do mais rapido "
           f"aos 100 km/h ({rapido:.1f} s contra {lento:.1f} s)")
    exigir(numero(dados, "frota_final_max")
           - numero(dados, "frota_final_min") >= 50.0,
           f"a velocidade final separa os modelos em pelo menos 50 km/h "
           f"({dados.get('frota_final_min')} a {dados.get('frota_final_max')})")
    exigir(5.0 <= rapido <= 16.0,
           f"o mais rapido ainda e carro de rua ({rapido:.2f} s aos 100)")
    exigir(lento <= 30.0,
           f"o mais lento chega aos 100 km/h algum dia ({lento:.2f} s)")
    exigir(dados.get("limitador_corta") == "1",
           "o limitador corta a faisca quando a roda force o motor")
    exigir(abs(numero(dados, "limitador_giro_max")
               - numero(dados, "limitador_corte")) < 1.0,
           "o giro nao passa do corte")

    print("== dirigir ==")
    exigir(dados.get("na_faixa") == "1", "a medida partiu de uma faixa de rua")
    t40 = numero(dados, "t_40kmh")
    exigir(0.0 < t40 <= 4.0, f"cruza os 40 km/h do zero ({t40:.2f} s)")
    # O piso e 10 m, e nao a distancia que um carro faria em seis segundos.
    #
    # Distancia percorrida na cidade mede o QUARTEIRAO: o carro chega a uma
    # fachada, a um poste ou ao meio-fio de uma esquina e para, e dali em diante
    # o numero fala da quadra sorteada naquela partida. Medido em execucoes
    # seguidas do mesmo codigo: 24 m, 31 m, 79 m. Um piso alto aqui reprova o
    # carro por causa da rua — foi o que aconteceu — e um piso alto que passa
    # so as vezes ensina a ignorar o teste.
    #
    # Quem afirma que o carro acelera e `t_40kmh`, logo acima, medido nos dois
    # primeiros segundos, antes de haver muro. Os 10 m daqui sao o piso do
    # absurdo: pegam "o carro andou e voltou para o lugar" e nada mais.
    exigir(numero(dados, "arrancada_m") >= 10.0,
           f"saiu do lugar ({dados.get('arrancada_m')} m; a distancia em seis"
           f" segundos depende do quarteirao, ver o comentario)")
    exigir(dados.get("esterco_lado_certo") == "1",
           f"volante para a esquerda vira o carro para a esquerda "
           f"({dados.get('esterco_rumo_rad')} rad, {dados.get('esterco_lateral_m')} m)")
    freio = numero(dados, "freio_ms2")
    # Faixa, e nao piso. Depois que a massa passou a variar, `brake` — que e teto
    # de IMPULSO no Godot — deixou de dar a mesma desaceleracao em todo carro: o
    # mesmo numero que da 0,85 g no sedan dava 1,7 g no Fusca de 820 kg, mais
    # aderencia do que quatro tambores estreitos jamais tiveram. O teto aqui pega
    # o carro grudento tanto quanto o piso pega o que nao para.
    exigir(5.0 <= freio <= 11.0,
           f"o freio do {dados.get('modelo', '?')} para o carro sem gruda-lo no"
           f" chao ({freio:.2f} m/s2)")

    print("== chuva, pneu e batida ==")
    exigir(dados.get("chuva_muda_atrito") == "1",
           f"a chuva chega nas rodas no meio da partida "
           f"({dados.get('atrito_seco')} seco contra "
           f"{dados.get('atrito_molhado')} molhado)")
    # Duracao, e nao pico.
    #
    # Patinar na saida a pe no fundo e CERTO num carro de tracao dianteira com
    # primeira curta: o sedan pede 5799 N no eixo e o eixo da frente so tem uns
    # 4600 N de carga depois da transferencia de peso, entao a roda gira. O
    # relatorio mediu pico 0,74 nele e 0,00 no hatch, que tem menos forca. O que
    # nao pode acontecer e patinar a arrancada INTEIRA: chiado de meio segundo e
    # carro saindo, chiado de seis segundos e carro sem tracao.
    exigir(numero(dados, "patinou_s") <= 1.5,
           f"nao patina a arrancada inteira ({dados.get('patinou_s')} s de"
           f" escorregao num pico de {dados.get('escorrega_arrancada')})")
    exigir(numero(dados, "escorrega_curva") >= 0.25,
           f"volante no batente faz o pneu escorregar "
           f"({dados.get('escorrega_curva')})")
    exigir(numero(dados, "canta_db") > -40.0,
           f"e o pneu CANTA quando escorrega ({dados.get('canta_db')} dB no pico"
           f" de um escorregao de {dados.get('escorrega_pico')})")

    print("== o que o pneu deixa no chao ==")
    exigir(dados.get("marcas_reta") == "0",
           f"acelerar em linha reta NAO pinta o asfalto "
           f"({dados.get('marcas_reta')} pedacos, com a roda escorregando "
           f"{dados.get('escorrega_roda_reta')} no pico)")
    exigir(numero(dados, "derrapagem_v0") >= 5.0
           and dados.get("derrapagem_ligado") == "1",
           f"a derrapagem partiu de um carro andando e ligado "
           f"({dados.get('derrapagem_v0')} m/s, ligado="
           f"{dados.get('derrapagem_ligado')}) — sem isso o resto desta secao "
           f"mede um carro morto, e nao o rastro")
    exigir(numero(dados, "marcas_derrapando") >= MIN_MARCAS,
           f"derrapar deixa rastro ({dados.get('marcas_derrapando')} pedacos de "
           f"0,30 m, com a roda escorregando "
           f"{dados.get('escorrega_roda_derrapando')} no pico; minimo "
           f"{MIN_MARCAS})")
    exigir(numero(dados, "bafos_derrapando") >= 1,
           f"e levanta fumaca ({dados.get('bafos_derrapando')} bafos)")
    acima = numero(dados, "marca_acima_chao")
    exigir(0.0 < acima <= MARCA_MAX_ACIMA,
           f"e a marca assenta NO asfalto, nem enterrada nem flutuando "
           f"({acima:+.3f} m acima do chao medido por raio, alvo "
           f"{dados.get('marca_alvo_acima')}, teto {MARCA_MAX_ACIMA})")

    exigir(numero(dados, "batidas") >= 1,
           f"bater e notado ({dados.get('batidas')} em"
           f" {dados.get('batida_percorreu_m')} m fora da faixa)")
    exigir(numero(dados, "batida_forca") > 0.2,
           f"e a forca da batida acompanha o tombo "
           f"({dados.get('batida_forca')} de 1)")

    print("== vento e capotamento ==")
    exigir(dados.get("vento_assentou") == "1",
           f"o carro estava mesmo parado para a medida de vento "
           f"({dados.get('vento_parado_v')} m/s)")
    exigir(numero(dados, "vento_parado_db") <= -50.0,
           f"carro parado nao faz vento ({dados.get('vento_parado_db')} dB)")
    exigir(numero(dados, "vento_andando_db") >= -42.0,
           f"e andando faz ({dados.get('vento_andando_db')} dB a"
           f" {dados.get('vento_a_ms')} m/s)")
    exigir(dados.get("capotou") == "1", "o carro sabe que capotou")
    exigir(dados.get("capotado_motor_morreu") == "1",
           "capotado, o motor morre em vez de roncar de pernas para o ar")
    exigir(numero(dados, "capotado_saida_longe_m") >= 1.0
           or numero(dados, "capotado_saida_acima_m") >= 1.0,
           f"e da para DESCER dele — a saida cai fora da lataria "
           f"({dados.get('capotado_saida_longe_m')} m ao lado, "
           f"{dados.get('capotado_saida_acima_m')} m acima)")

    print("== painel ==")
    exigir(dados.get("painel") == "1", "o mostrador existe")
    exigir(dados.get("painel_visivel") == "1", "esta na tela ao dirigir")
    exigir(numero(dados, "painel_vinheta")
           >= numero(dados, "painel_vinheta_min"),
           f"nao cai na quina apagada pela vinheta "
           f"({dados.get('painel_vinheta')} >= {dados.get('painel_vinheta_min')})")
    erro = numero(dados, "painel_erro_kmh")
    exigir(0.0 <= erro <= 6.0,
           f"o velocimetro marca a velocidade (erro mediano de {erro:.1f} km/h "
           f"numa aceleracao de dois segundos)")
    giro = numero(dados, "painel_erro_giro")
    exigir(0.0 <= giro <= 0.08,
           f"o conta-giros marca a rotacao (erro mediano de {giro:.3f} "
           f"de fundo de escala)")
    exigir(dados.get("painel_marcha") == dados.get("painel_marcha_esperada"),
           f"a marcha no painel e a marcha engatada "
           f"({dados.get('painel_marcha')})")

    print("== som do motor ==")
    faixa = numero(dados, "motores_faixa")
    exigir(faixa >= 0.15,
           f"os carros da rua tem motores de alturas diferentes "
           f"(faixa de {faixa:.3f} em afinacao)")
    exigir(numero(dados, "motores_distintos") >= 12,
           f"dezesseis carros dao pelo menos doze motores distintos "
           f"({dados.get('motores_distintos')})")
    exigir(dados.get("som_detalhado") == "1",
           "o carro do jogador usa o banco de tres faixas, e nao a camada de rua")
    exigir(numero(dados, "som_camadas") >= 3,
           f"ha camadas tocando enquanto se acelera "
           f"({dados.get('som_camadas')} de 4)")
    exigir(numero(dados, "som_db") > -45.0,
           f"e audivel, e nao um tocador mudo ({dados.get('som_db')} dB)")
    exigir(0.4 <= numero(dados, "som_afinacao") <= 2.2,
           f"a afinacao acompanha a rotacao e fica na faixa util "
           f"({dados.get('som_afinacao')}x)")

    print("== sair ==")
    exigir(dados.get("saida") == "1", "a tecla devolve o jogador ao chao")
    exigir(dados.get("saida_visivel") == "1", "o corpo volta a ser visivel")
    exigir(numero(dados, "saida_carro_andou_m") <= 1.0,
           f"o carro fica onde foi estacionado, e nao volta para onde nasceu "
           f"({dados.get('saida_carro_andou_m')} m de salto ao congelar)")
    exigir(0.5 <= numero(dados, "saida_dist_m") <= 4.0,
           f"o jogador sai ao lado do carro, fora da lataria "
           f"({dados.get('saida_dist_m')} m)")
    exigir(dados.get("painel_sumiu") == "1", "o mostrador some ao descer")

    print()
    if falhas:
        print(f"FALHA  {len(falhas)} criterio(s):")
        for f in falhas:
            print(f"  - {f}")
        return 1
    print("carro: todos os criterios cumpridos")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
