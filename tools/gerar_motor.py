#!/usr/bin/env python3
"""Banco de amostras do motor do carro.

Por que nao esta em gerar_audio.py
----------------------------------
Esta separado por uma razao de higiene, e nao de arrumacao: `gerar_audio.py` tem
UM gerador aleatorio criado no topo do modulo e consumido na ordem em que as
funcoes sao chamadas. Acrescentar um sorteio no meio dele muda o ruido de todo
som gerado DEPOIS — buzina, porta, passos — e a arvore aparece com trinta
arquivos modificados que ninguem pediu. Aqui o gerador e local e semeado
proprio, entao rodar isto mexe nestes arquivos e em nenhum outro.

Duas geracoes de motor moram aqui
---------------------------------
**O banco por fisica** (`motor_<arquitetura>_<rpm>_<on|off>`), que e o que o
carro toca. Ver `banco()` e a secao "O banco novo" abaixo: cada amostra e um
motor montado de verdade — explosoes num trem de pulsos na frequencia certa,
coletor, abafador, ponteira, admissao, tucho, correia — num ponto de rotacao e
numa carga. Tres arquiteturas: quatro em linha, tres em linha e boxer a ar.

**O legado** (`motor_baixo`, `motor_medio`, `motor_alto`): tres loops de soma de
senoides com `tanh` por cima. Soavam como orgao, e sao a razao do banco novo
existir. Continuam sendo gerados, identicos byte a byte, porque
`levels/teste_carro.gd` confere que eles existem e porque o gerador aleatorio
deles e o mesmo dos sons de evento: tirar as tres chamadas do comeco de `main`
mudaria o ruido do corte, do pneu, da batida e do vento.

Sons de evento e de rolamento, que o carro toca junto:

    motor_corte   a faisca cortando no limitador e na troca
    pneu_loop     o rolamento do pneu no asfalto, que sobe com a velocidade
    pneu_canta    a borracha escorregando: curva forte, freio de mao, arrancada
    batida_carro  lataria contra alguma coisa
    motor_alivio  o escapamento estourando quando o pe sai do acelerador
    vento_carro   o ar na lataria, que acima dos 80 km/h manda no ouvido
    motor_cambio  o assobio das engrenagens do cambio (banco novo)

    python tools/gerar_motor.py
"""

from __future__ import annotations

import math
import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

## Semente propria. Ver o cabecalho: o ponto e nao depender da ordem de chamada.
rng = np.random.default_rng(20260914)

## Duracao dos loops. Um segundo inteiro para o ciclo fechar em numero exato de
## voltas — ver `tom`.
DUR = 1.0

## Frequencia de explosao de cada faixa, em Hz. Num quatro cilindros de quatro
## tempos ha duas explosoes por volta, entao rpm = f0 * 30. Os tres numeros sao
## inteiros de proposito: com DUR = 1 s o loop fecha sem emenda no tom.
F_BAIXO = 40.0
F_MEDIO = 108.0
F_ALTO = 188.0


def gravar(nome: str, x: np.ndarray, ganho: float = 0.9) -> None:
    pico = float(np.max(np.abs(x))) or 1.0
    y = np.clip(x / pico * ganho, -1.0, 1.0)
    dados = (y * 32767.0).astype("<i2")
    SAIDA.mkdir(parents=True, exist_ok=True)
    with wave.open(str(SAIDA / f"{nome}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{nome:16s} {len(y) / SR:5.2f} s  {SR} Hz")


def passa_banda(x: np.ndarray, baixo: float, alto: float) -> np.ndarray:
    """Filtro de banda no dominio da frequencia.

    Feito por FFT e nao por biquad porque o sinal e curto e periodico: cortar no
    espectro e exato e nao deixa o transiente de partida que um filtro recursivo
    deixa no primeiro milissegundo — e num LOOP esse transiente e audivel toda
    vez que a amostra da a volta.
    """
    n = len(x)
    f = np.fft.rfft(x)
    freq = np.fft.rfftfreq(n, 1.0 / SR)
    janela = np.ones_like(freq)
    janela[freq < baixo] = 0.0
    janela[freq > alto] = 0.0
    # Ombro suave nas duas pontas: um corte quadrado no espectro vira zumbido.
    subida = (freq >= baixo) & (freq < baixo * 1.6)
    janela[subida] = np.linspace(0.0, 1.0, int(np.sum(subida)))
    descida = (freq > alto * 0.62) & (freq <= alto)
    janela[descida] = np.linspace(1.0, 0.0, int(np.sum(descida)))
    return np.fft.irfft(f * janela, n)


def emendar(x: np.ndarray, ms: float = 55.0) -> np.ndarray:
    """Cruza o fim com o comeco para o loop nao estalar.

    So o ruido precisa disto. A parte tonal ja fecha sozinha, porque a duracao e
    um numero inteiro de ciclos de todas as ordens usadas.
    """
    n = int(SR * ms / 1000.0)
    if n <= 0 or n * 2 >= len(x):
        return x
    y = x.copy()
    rampa = np.linspace(0.0, 1.0, n)
    y[:n] = y[:n] * rampa + x[-n:] * (1.0 - rampa)
    return y[:-n]


def tom(f0: float, ordens: list[tuple[float, float]], n: int) -> np.ndarray:
    """Soma de ordens do motor, com fase sorteada.

    `ordens` e uma lista de (multiplo de f0, peso). Multiplos de meia unidade
    existem: a meia-ordem e o que da o balanco desigual de um motor de quatro
    cilindros em rotacao baixa, e e a primeira coisa que some quando alguem
    sintetiza motor com serie harmonica inteira e o resultado sai como orgao.
    """
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, peso in ordens:
        fase = rng.uniform(0.0, 2.0 * np.pi)
        x += np.sin(2.0 * np.pi * f0 * k * t + fase) * peso
    return x


def rasgar(x: np.ndarray, quanto: float) -> np.ndarray:
    """Distorcao macia.

    Um motor em carga nao e uma soma de senoides: a coluna de gas satura e as
    pontas da onda achatam. `tanh` faz exatamente isso e, de quebra, cria as
    ordens superiores que dariam trabalho somar uma a uma. E a diferenca entre
    'roncar' e 'zumbir'.
    """
    if quanto <= 0.0:
        return x
    pico = float(np.max(np.abs(x))) or 1.0
    return np.tanh(x / pico * (1.0 + quanto * 3.0)) * pico


# --- legado: os tres loops de senoide ---------------------------------------
#
# Nao sao mais tocados pelo carro (ver o cabecalho). Ficam para o teste que
# confere a existencia deles e para o sorteio dos sons de evento, que vem
# depois deles no mesmo gerador, continuar dando os mesmos bytes.

def faixa_baixa() -> None:
    """Marcha lenta e saida. Cavernoso, desigual, com meia-ordem forte."""
    n = int(SR * DUR)
    t = np.arange(n) / SR
    x = tom(F_BAIXO, [
        (0.5, 0.42), (1.0, 1.00), (1.5, 0.26), (2.0, 0.54),
        (3.0, 0.21), (4.0, 0.15), (6.0, 0.07),
    ], n)
    # Balanco lento da marcha lenta: nenhum motor parado gira liso, e o carro
    # que gira liso parado soa eletrico.
    x *= 0.78 + 0.22 * np.sin(2.0 * np.pi * 3.0 * t + np.sin(2.0 * np.pi * t))
    x = rasgar(x, 0.20)
    x += emendar_ruido(n, 120.0, 1400.0, 0.13)
    gravar("motor_baixo", x, 0.80)


def faixa_media() -> None:
    """A faixa da cidade. Ja fechado, ainda com corpo."""
    n = int(SR * DUR)
    t = np.arange(n) / SR
    x = tom(F_MEDIO, [
        (0.5, 0.16), (1.0, 1.00), (1.5, 0.12), (2.0, 0.62),
        (3.0, 0.30), (4.0, 0.22), (5.0, 0.13), (6.0, 0.10), (8.0, 0.06),
    ], n)
    x *= 0.90 + 0.10 * np.sin(2.0 * np.pi * 6.5 * t)
    x = rasgar(x, 0.42)
    x += emendar_ruido(n, 260.0, 3200.0, 0.16)
    gravar("motor_medio", x, 0.86)


def faixa_alta() -> None:
    """Pe no fundo. Parede continua, rasgada, com sopro de admissao por cima."""
    n = int(SR * DUR)
    x = tom(F_ALTO, [
        (1.0, 1.00), (2.0, 0.70), (3.0, 0.42), (4.0, 0.30),
        (5.0, 0.22), (6.0, 0.16), (7.0, 0.11), (8.0, 0.08), (10.0, 0.05),
    ], n)
    x = rasgar(x, 0.85)
    # Sopro de admissao: banda larga e aguda, que so existe em carga alta. E o
    # que separa 'acelerando' de 'girando alto sem pe'.
    x += emendar_ruido(n, 700.0, 6500.0, 0.22)
    gravar("motor_alto", x, 0.92)


def emendar_ruido(n: int, baixo: float, alto: float, ganho: float) -> np.ndarray:
    """Ruido de banda que fecha em loop.

    Gera com folga, filtra, e cruza as pontas ANTES de cortar no tamanho final —
    filtrar depois da emenda reintroduziria a descontinuidade.
    """
    bruto = passa_banda(rng.standard_normal(n + int(SR * 0.1)), baixo, alto)
    emendado = emendar(bruto, 55.0)
    if len(emendado) < n:
        emendado = np.pad(emendado, (0, n - len(emendado)), mode="wrap")
    return emendado[:n] / (float(np.max(np.abs(emendado))) or 1.0) * ganho


def derrapagem() -> None:
    """Pneu escorregando no asfalto.

    Nao e ruido branco filtrado. Borracha deslizando GRUDA e SOLTA milhares de
    vezes por segundo — o fenomeno chama stick-slip — e o que sai disso e um
    ruido com uma ressonancia estreita por cima, quase um tom. E essa
    ressonancia que faz o ouvido dizer "pneu" em vez de "chuveiro".

    Duas ressonancias, e nao uma: pneu real canta em mais de um harmonico, e
    uma so soa como apito de arbitro.
    """
    n = int(SR * DUR)
    t = np.arange(n) / SR
    base = emendar_ruido(n, 400.0, 5200.0, 1.0)
    x = base * 0.45
    # Ressonancias em 1180 e 1770 Hz — quinta justa, que e a relacao que a
    # borracha produz com mais frequencia. Presas a numero inteiro de ciclos
    # para o laco fechar.
    for freq, peso in ((1180.0, 0.55), (1770.0, 0.30)):
        anel = passa_banda(base, freq * 0.93, freq * 1.07)
        x += anel / (float(np.max(np.abs(anel))) or 1.0) * peso
    # Ondulacao lenta: o pneu nao escorrega parelho, ele agarra e solta.
    x *= 0.72 + 0.28 * np.sin(2.0 * np.pi * 9.0 * t + np.sin(2.0 * np.pi * 2.0 * t))
    gravar("pneu_canta", x, 0.74)


def batida() -> None:
    """Lataria contra alguma coisa.

    Tres camadas no mesmo instante, porque bater faz tres barulhos: o ESTALO da
    chapa cedendo (agudo e curtissimo), o BUM da estrutura inteira ressoando
    (grave, com cauda) e o CHACOALHO do que esta solto dentro do carro.

    Sem a camada grave a batida vira porta batendo; sem a aguda vira trovao.
    """
    n = int(SR * 0.55)
    t = np.arange(n) / SR

    estalo = passa_banda(rng.standard_normal(n), 900.0, 7000.0)
    estalo *= np.exp(-t * 90.0)

    # O bum: dois modos graves proximos, que batendo um no outro dao o "blomp"
    # de chapa grande. Decaimento longo, que e a cauda da batida.
    bum = (np.sin(2.0 * np.pi * 78.0 * t) + 0.7 * np.sin(2.0 * np.pi * 112.0 * t))
    bum *= np.exp(-t * 11.0)

    chacoalho = passa_banda(rng.standard_normal(n), 300.0, 2600.0)
    chacoalho *= np.exp(-t * 7.0) * (0.5 + 0.5 * np.sin(2.0 * np.pi * 23.0 * t))

    gravar("batida_carro", estalo * 0.9 + bum * 1.0 + chacoalho * 0.35, 0.92)


def alivio() -> None:
    """O escapamento esvaziando quando o pe sai do acelerador.

    Motor em retencao queima o que sobrou no coletor, e o que se ouve e um
    estouro seco e curto — o "pop" do escapamento. Nao e o corte de giro: aquele
    e o motor emudecendo, este e o motor soltando o que tinha guardado.

    Existe porque tirar o pe era uma nao-acao sonora: o volume caia e nada mais
    acontecia. Num carro real, aliviar tem voz propria, e ela e metade do prazer
    de dirigir um carro cansado.
    """
    n = int(SR * 0.22)
    t = np.arange(n) / SR
    # Dois ou tres estouros proximos e desiguais — nunca um so, e nunca parelhos.
    x = np.zeros(n)
    for atraso, ganho in ((0.0, 1.0), (0.052, 0.55), (0.118, 0.32)):
        k = int(atraso * SR)
        if k >= n:
            continue
        env = np.exp(-(t[: n - k]) * 58.0)
        estouro = passa_banda(rng.standard_normal(n - k), 120.0, 2800.0) * env
        # Corpo grave: e a coluna de gas no tubo, e sem ela o pop vira estalo.
        estouro += np.sin(2.0 * np.pi * 132.0 * t[: n - k]) * env * 0.45
        x[k:] += estouro * ganho
    gravar("motor_alivio", x, 0.62)


def vento() -> None:
    """O ar passando pela lataria.

    Acima dos 80 km/h o vento e mais alto que o motor dentro de um carro de rua
    com borracha de porta velha, e sem ele acelerar so deixava o motor agudo: o
    carro PARECIA rapido no velocimetro e nao SOAVA rapido no ouvido.

    Ruido de banda larga com uma ondulacao muito lenta — a rajada. Sem a
    ondulacao ele vira chiado de televisao fora do ar.
    """
    n = int(SR * DUR)
    t = np.arange(n) / SR
    x = emendar_ruido(n, 180.0, 7500.0, 1.0)
    x *= 0.80 + 0.20 * np.sin(2.0 * np.pi * 1.0 * t)
    # Um assobio estreito por cima: e a fresta da porta, e e o que faz o ouvido
    # dizer "carro andando" em vez de "chuveiro".
    x += emendar_ruido(n, 2100.0, 3000.0, 0.22)
    gravar("vento_carro", x, 0.58)


def corte() -> None:
    """A faisca cortando.

    Nao e uma batida e nao e um estouro: e o motor emudecendo por setenta
    milissegundos e voltando. O que o ouvido pega e a BORDA — a queda seca e o
    retorno — entao o som e curto, seco e sem cauda. Com cauda viraria tiro.
    """
    n = int(SR * 0.085)
    t = np.arange(n) / SR
    x = passa_banda(rng.standard_normal(n), 180.0, 3400.0)
    # Duas batidas: o corte e a retomada. Uma so soa como clique de interface.
    env = np.exp(-t * 46.0) + 0.55 * np.exp(-np.abs(t - 0.045) * 130.0)
    x *= env
    # Um resto de tom grave por baixo, que e o escapamento esvaziando.
    x += np.sin(2.0 * np.pi * 95.0 * t) * np.exp(-t * 30.0) * 0.5
    gravar("motor_corte", x, 0.70)


def pneu() -> None:
    """Rolamento do pneu no asfalto.

    Ruido de banda media com uma ondulacao lenta por cima — o desenho da banda
    de rodagem passando pelo chao. Referencia de 20 m/s: a afinacao em tempo de
    execucao sobe e desce a partir dai.

    Existe porque motor sozinho nao da velocidade. Aos 90 km/h o que domina o
    ouvido de dentro de um carro de rua e o pneu, e sem essa camada acelerar so
    faz o motor ficar agudo — o carro parece rapido e nao SOA rapido.
    """
    n = int(SR * DUR)
    t = np.arange(n) / SR
    x = emendar_ruido(n, 220.0, 4200.0, 1.0)
    # Batida da banda de rodagem, presa a um numero inteiro de voltas para o
    # loop fechar.
    x *= 0.82 + 0.18 * np.sin(2.0 * np.pi * 17.0 * t)
    x += emendar_ruido(n, 60.0, 260.0, 0.45)
    gravar("pneu_loop", x, 0.62)


def conferir() -> int:
    """Confere o que da para afirmar dos sons de evento e do legado.

    Duas coisas, e as duas ja quebraram sintese de motor por ai:

    o timbre ABRE com a faixa   o centroide espectral — o centro de gravidade da
                                energia — tem de subir de uma amostra para a
                                seguinte. Se as tres tiverem o mesmo centroide,
                                sao a mesma amostra em alturas diferentes, e o
                                banco de tres faixas nao serviu para nada. Medido
                                hoje: 228, 703 e 1923 Hz.
    o laco FECHA                o degrau entre a ultima amostra e a primeira tem
                                de ser da ordem do degrau entre duas vizinhas
                                quaisquer. Muito maior e um estalo a cada volta —
                                o defeito que a emenda cruzada existe para
                                evitar, e que so se ouve depois do terceiro
                                segundo tocando, quando ninguem esta mais
                                prestando atencao no som.
    """
    falhas = 0
    centro_anterior = 0.0
    print()
    cab = ("amostra", "centroide Hz", "f0 Hz", "emenda")
    print(f"{cab[0]:14s} {cab[1]:>12s} {cab[2]:>8s} {cab[3]:>9s}")
    for nome in ("motor_baixo", "motor_medio", "motor_alto", "pneu_loop",
                 "pneu_canta", "vento_carro"):
        with wave.open(str(SAIDA / f"{nome}.wav"), "rb") as w:
            bruto = w.readframes(w.getnframes())
        x = np.frombuffer(bruto, dtype="<i2").astype(float) / 32768.0
        esp = np.abs(np.fft.rfft(x))
        freq = np.fft.rfftfreq(len(x), 1.0 / SR)
        centro = float((esp * freq).sum() / esp.sum())
        grave = freq < 400.0
        f0 = float(freq[grave][int(np.argmax(esp[grave]))])
        emenda = abs(x[0] - x[-1]) / float(np.mean(np.abs(np.diff(x))))
        print(f"{nome:14s} {centro:12.0f} {f0:8.1f} {emenda:8.1f}x")
        if emenda > 6.0:
            print(f"  FALHA  {nome}: o laco estala na volta")
            falhas += 1
        if nome.startswith("motor_"):
            if centro <= centro_anterior:
                print(f"  FALHA  {nome}: o timbre nao abriu em relacao"
                      " a faixa de baixo")
                falhas += 1
            centro_anterior = centro
    return falhas


# ===========================================================================
# O banco novo: o motor montado peca por peca
# ===========================================================================
#
# Por que o legado soava como orgao
# ---------------------------------
# Porque era um ORGAO: soma de senoides em ordens fixas, com fase fixa, repetida
# identica a cada ciclo. Um motor de verdade nao tem nenhuma das tres coisas.
# O que sai do escapamento e um TREM DE PULSOS — cada explosao abre a valvula de
# escape e solta um bolo de gas a alta pressao, com subida seca e cauda — e os
# pulsos nao sao iguais entre si: cada ciclo queima um pouco diferente do
# anterior (variabilidade ciclica de combustao, maior em marcha lenta e sem
# carga), cada cilindro tem a propria folga, e o coletor recebe os pulsos de
# cada banco por um caminho de comprimento diferente. O timbre que o ouvido
# chama de "motor" e esse trem irregular passando por tubos.
#
# Entao cada amostra e montada como a maquina:
#
#   explosoes   um pulso por explosao, no angulo de virabrequim certo, com
#               amplitude e instante sorteados POR CICLO. O pulso e mais curto
#               em giro alto (a abertura da valvula dura os mesmos graus em
#               menos tempo), e e isso que abre o timbre com a rotacao.
#   coletor     um tubo por banco, com reflexao na juncao: pente de ressonancia
#               com o comprimento do primario. No boxer os dois bancos chegam
#               ao abafador por caminhos diferentes — e o ronco desigual dele.
#   abafador    duas camaras de expansao (perda de transmissao classica, com
#               as bandas de passagem em c/2L) e a la de vidro, que come agudo.
#   ponteira    mais um tubo aberto-aberto, e a radiacao da boca, que e um
#               passa-alta: o escapamento nao irradia o grave que carrega.
#   admissao    pulsos de succao pelo coletor de admissao e pela caixa do filtro
#               (Helmholtz), e o RONCO: ruido de escoamento modulado por cada
#               admissao, forte so com borboleta aberta em giro alto.
#   mecanica    tucho fechando valvula (um estalo metalico por valvula por
#               ciclo), a correia ou a engrenagem do comando (um tom em dentes
#               por volta), e no boxer a ventoinha do arrefecimento a ar.
#   corpo       tudo ouvido de perto e atraves da lataria: passa-baixa suave,
#               sem chiado de agudo.
#
# Duas camadas por rotacao, porque carga muda o motor inteiro e nao so o
# volume: `on` e o pe no acelerador (pulso cheio, admissao rugindo), `off` e a
# retencao (pulso fraco e oco, mecanica aparecendo, estalos no escapamento).
#
# Como o laco fecha sem emenda
# ----------------------------
# Cada amostra dura um numero INTEIRO de ciclos de motor (720 graus). A rotacao
# de referencia e acertada para isso — o desvio do valor nominal e da ordem de
# 1e-5, 0,02 cent de afinacao — e tudo e montado no dominio da frequencia da
# propria amostra: um pulso no instante t e e^(-j2pi f t) somado em todas as
# raias da FFT, que sao periodicas no comprimento do laco. O sorteio de cada
# ciclo vira, sem esforco nenhum, um padrao periodico de N ciclos; o filtro e
# circular; o ruido e ruido branco da propria FFT. Nao ha emenda porque nao ha
# fim: a amostra e UM periodo de um sinal periodico.
#
# Por que 32 kHz e nao 44,1
# -------------------------
# O banco passa pelo "corpo" (passa-baixa de segunda ordem em 3 kHz) e pela la
# do abafador, entao acima de 9 kHz nao sobra nada acima de -60 dB do pico. A
# afinacao em tempo de execucao estica a camada audivel no maximo 1,42x (a maior
# razao entre vizinhos da grade, medida em `tests/bancada_motor_som.gd`) vezes o
# caracter do carro (ate 1,14): 9 kHz viram 14,6 kHz, abaixo dos 16 kHz de
# Nyquist. 44,1 kHz custaria 38% a mais de disco e memoria por um agudo que o
# proprio corpo do carro ja tirou.
#
# Por que PCM e nao QOA
# ---------------------
# O padrao de importacao do projeto e QOA (`compress/mode=2`). Com QOA, o
# `data` do `AudioStreamWAV` e o fluxo comprimido, e `AudioDirector.em_loop`
# calcula o fim do laco como `data.size() / 2`: no `motor_medio` legado, 4476
# de 22050 amostras. Medido em 22/09/2026 na saida, com captura no Master: o
# `pneu_loop` tocado assim repete a cada 0,203 s (correlacao 0,983 nesse atraso,
# -0,004 no de 1 s). O banco novo sai com um `.import` em PCM (`gravar_import`),
# e o `MotorSom` acerta o fim do laco pelo comprimento em segundos, que vale
# para qualquer formato.

SR_BANCO = 32000
## Pico do arquivo mais alto de cada arquitetura. Um decibel de folga para a
## interpolacao do reamostrador nao estourar.
PICO_BANCO = 10.0 ** (-1.0 / 20.0)
## Onde o laco comeca, em graus ANTES da primeira explosao. Todo arquivo comeca
## no mesmo angulo de virabrequim: tocados juntos com afinacao rpm/ref, dois
## pontos vizinhos da grade andam no mesmo passo de ciclo, e comecar no mesmo
## angulo e o que deixa os pulsos dos dois caindo juntos durante o cruzamento —
## sem isso a metade do cruzamento soa como dois motores.
ANGULO_INICIO = 30.0
## Velocidade do som no gas quente do coletor, no tubo do meio e na ponteira.
C_COLETOR = 520.0
C_TUBO = 480.0
C_CAMARA = 440.0
C_PONTEIRA = 400.0
C_AR = 343.0


@dataclass(frozen=True)
class Arquitetura:
    """O que muda de um motor para outro, em grandeza fisica.

    Os numeros sao de motor de rua brasileiro dos anos noventa, e nenhum e
    medida de um motor especifico: sao a ordem de grandeza certa de cada peca,
    escolhida para cada arquitetura soar como ela e nao como as outras.
    """
    nome: str
    ## Pontos de rotacao do banco. Grade geometrica (razao ~1,36): cada amostra
    ## e esticada no maximo ate o vizinho, e o timbre muda por razao de giro e
    ## nao por diferenca.
    grade: tuple[int, ...]
    ## Angulo de virabrequim de cada explosao no ciclo de 720 graus, na ordem
    ## de ignicao.
    angulos: tuple[float, ...]
    ## Banco de escape de cada explosao (qual coletor o pulso atravessa).
    bancos: tuple[int, ...]
    ## Folga fixa de cada cilindro: amplitude relativa e avanco em graus. E o que
    ## cria a meia-ordem mesmo em giro alto — motor com cilindros identicos nao
    ## existe.
    desequilibrio: tuple[float, ...]
    avanco: tuple[float, ...]
    ## Comprimento do primario de cada banco, m, e o atraso acustico extra do
    ## banco ate o abafador, s.
    coletores: tuple[float, ...]
    atraso_banco: tuple[float, ...]
    ## Duracao do sopro de escape, em graus de virabrequim.
    sopro: float
    ## Camaras do abafador: (razao de area, comprimento em m).
    camaras: tuple[tuple[float, float], ...]
    ## Onde a la do abafador comeca a comer agudo, Hz.
    absorcao: float
    ## Comprimento da ponteira, m.
    ponteira: float
    ## Modos do estalo de valvula: (Hz, decaimento em s, peso).
    modos_valvula: tuple[tuple[float, float, float], ...]
    ## Volume do tucho em relacao ao escapamento em carga, dB.
    valvula_db: float
    ## Dentes do sincronismo por volta de virabrequim, e o volume do tom.
    dentes: int
    sincronismo_db: float
    ## Carater do sopro: quanto do pulso e "latido" de valvula abrindo.
    latido: float
    ventoinha: bool = False
    ## Primeira ordem (balanco de virabrequim de tres cilindros), dB.
    primeira_ordem_db: float | None = None


ARQUITETURAS: dict[str, Arquitetura] = {
    # O quatro em linha de rua: 1.6 a 2.0, oito valvulas, correia dentada, coletor
    # 4-2-1 (cilindros 1 e 4 num par, 2 e 3 no outro). Ignicao 1-3-4-2, entao os
    # pares alternam e o trem sai parelho. E o sedan, a perua, o taxi, a picape
    # e o Marea.
    "i4": Arquitetura(
        nome="i4",
        grade=(800, 1100, 1500, 2050, 2800, 3800, 5200, 7000),
        angulos=(0.0, 180.0, 360.0, 540.0),
        bancos=(0, 1, 0, 1),
        desequilibrio=(1.00, 0.95, 1.04, 0.97),
        avanco=(0.0, 1.2, -0.8, 0.5),
        coletores=(0.85, 0.97),
        atraso_banco=(0.0, 0.00018),
        sopro=16.0,
        camaras=((7.0, 0.30), (10.0, 0.44)),
        absorcao=1100.0,
        ponteira=0.55,
        modos_valvula=((1250.0, 0.0007, 1.0), (2700.0, 0.0004, 0.5),
                       (4300.0, 0.00025, 0.25)),
        valvula_db=-29.0,
        dentes=21,
        sincronismo_db=-36.0,
        latido=0.05,
    ),
    # O 1.0 de tres cilindros: explosao a cada 240 graus, 1,5 por volta. O
    # intervalo longo e o desequilibrio de primeira ordem (tres cilindros nao se
    # anulam no balanco do virabrequim) sao a assinatura: ronco mais grave que o
    # giro sugere, meio manco, com um "tum" de carroceria por baixo.
    "i3": Arquitetura(
        nome="i3",
        grade=(900, 1200, 1600, 2200, 2900, 3900, 5200, 7000),
        angulos=(0.0, 240.0, 480.0),
        bancos=(0, 0, 0),
        desequilibrio=(1.00, 0.93, 1.05),
        avanco=(0.0, 1.8, -1.2),
        coletores=(0.80,),
        atraso_banco=(0.0,),
        sopro=18.0,
        camaras=((6.0, 0.28), (9.0, 0.40)),
        absorcao=1300.0,
        ponteira=0.50,
        modos_valvula=((1400.0, 0.0006, 1.0), (3100.0, 0.00035, 0.6),
                       (4800.0, 0.00025, 0.3)),
        valvula_db=-27.0,
        dentes=19,
        sincronismo_db=-32.0,
        latido=0.06,
        primeira_ordem_db=-15.0,
    ),
    # O boxer a ar do Fusca. Ignicao 1-4-3-2 com 1 e 2 de um lado e 3 e 4 do
    # outro: os bancos alternam direita, esquerda, esquerda, direita, e os
    # pulsos de cada lado chegam ao abafador unico por caminhos de comprimento
    # muito diferente. O pulso do lado longo chega atrasado — pouco em marcha
    # lenta, bastante perto do corte — e o trem fica desigual: e o "burburinho"
    # do boxer. Por cima, o que nenhum motor a agua tem: tucho mecanico batendo
    # sem camisa d'agua para abafar, e a ventoinha soprando o motor.
    "boxer": Arquitetura(
        nome="boxer",
        grade=(650, 900, 1250, 1700, 2350, 3350, 4700),
        angulos=(0.0, 180.0, 360.0, 540.0),
        bancos=(0, 1, 1, 0),
        desequilibrio=(1.00, 0.90, 1.07, 0.94),
        avanco=(0.0, 2.5, -1.5, 1.0),
        coletores=(0.55, 1.15),
        atraso_banco=(0.0, 0.0005),
        sopro=14.0,
        camaras=((5.0, 0.26),),
        absorcao=2400.0,
        ponteira=0.25,
        modos_valvula=((900.0, 0.0012, 0.8), (1900.0, 0.0009, 1.0),
                       (3300.0, 0.0005, 0.6), (5200.0, 0.0003, 0.3)),
        valvula_db=-21.0,
        dentes=38,
        sincronismo_db=-31.0,
        latido=0.24,
        ventoinha=True,
    ),
}


def nome_amostra(arq: str, rpm: int, carga: str) -> str:
    return f"motor_{arq}_{rpm}_{carga}"


# --- filtros no dominio da frequencia ---------------------------------------
#
# Todos analiticos, avaliados nas raias da FFT do laco. Circulares por
# construcao: o que sai pela direita entra pela esquerda, que e exatamente o
# comportamento de um sinal periodico em regime.

def _lp1(f: np.ndarray, fc: float) -> np.ndarray:
    return 1.0 / (1.0 + 1j * f / fc)


def _hp1(f: np.ndarray, fc: float) -> np.ndarray:
    u = 1j * f / fc
    return u / (1.0 + u)


def _lp2(f: np.ndarray, fc: float) -> np.ndarray:
    u = f / fc
    return 1.0 / (1.0 + 1j * math.sqrt(2.0) * u - u * u)


def _hp2(f: np.ndarray, fc: float) -> np.ndarray:
    u = f / fc
    return -(u * u) / (1.0 + 1j * math.sqrt(2.0) * u - u * u)


def _pico(f: np.ndarray, f0: float, q: float, ganho: float) -> np.ndarray:
    """Ressonancia: 1 fora da banda, `ganho` no centro."""
    u = f / f0
    bp = (1j * u / q) / (1.0 + 1j * u / q - u * u)
    return 1.0 + (ganho - 1.0) * bp


def _prateleira_grave(f: np.ndarray, fc: float, db: float) -> np.ndarray:
    g = 10.0 ** (db / 20.0)
    return (g + 1j * f / fc) / (1.0 + 1j * f / fc)


def _pente(f: np.ndarray, atraso: float, g: np.ndarray | float) -> np.ndarray:
    """Tubo com reflexao: a onda volta com ganho `g` depois de ida e volta.

    `g` negativo e boca aberta (a reflexao inverte), positivo e boca fechada ou
    estreitamento. E um IIR causal de verdade, so que avaliado em regime.
    """
    return 1.0 / (1.0 - g * np.exp(-2j * np.pi * f * atraso))


def _camara(f: np.ndarray, m: float, comprimento: float) -> np.ndarray:
    """Perda de transmissao de uma camara de expansao simples, em modulo.

    TL = 10 log10(1 + 1/4 (m - 1/m)^2 sin^2(kL)): atenua forte no meio e deixa
    passar em kL = n pi — as bandas de passagem em c/2L que dao a cor de cada
    abafador.
    """
    k = 2.0 * np.pi * f / C_CAMARA
    return 1.0 / np.sqrt(1.0 + 0.25 * (m - 1.0 / m) ** 2 * np.sin(k * comprimento) ** 2)


def _fase_minima(modulo: np.ndarray, n: int) -> np.ndarray:
    """Resposta de fase minima para um modulo dado (cepstro dobrado).

    Um filtro de fase zero no dominio da frequencia e simetrico no tempo: o
    abafador "tocaria" antes do pulso chegar, e o ataque do escape viraria um
    sopro. Fase minima e o filtro causal mais curto com aquele modulo, que e o
    que uma camara de verdade e.
    """
    c = np.fft.irfft(np.log(np.maximum(modulo, 1e-9)), n)
    w = np.zeros(n)
    w[0] = 1.0
    w[1:(n + 1) // 2] = 2.0
    if n % 2 == 0:
        w[n // 2] = 1.0
    return np.exp(np.fft.rfft(c * w, n))


def _corpo(f: np.ndarray) -> np.ndarray:
    """O carro entre o motor e o ouvido.

    Passa-baixa de segunda ordem em 3 kHz (lataria, forracao, distancia), um
    reforco de grave abaixo de 90 Hz (a carroceria vibra junto e o ouvido ouve
    pelo banco) e um passa-alta em 24 Hz para nao mandar subsonico ao mixer.
    """
    return _lp2(f, 3000.0) * _prateleira_grave(f, 90.0, 4.0) * _hp2(f, 24.0)


def _gama(f: np.ndarray, tau: float) -> np.ndarray:
    """Pulso de area unitaria (t/tau^2) e^(-t/tau): subida seca, cauda."""
    return 1.0 / (1.0 + 2j * np.pi * f * tau) ** 2


def _somar_eventos(f: np.ndarray, tempos: np.ndarray, pesos: np.ndarray) -> np.ndarray:
    """Espectro de um trem de impulsos: sum_k w_k e^(-j 2 pi f t_k).

    `pesos` tem uma linha por serie (varias series que compartilham os mesmos
    instantes saem de uma conta so). O instante e fracionario e exato — nao ha
    grade de amostra no dominio da frequencia —, e a soma e periodica no laco
    por construcao.
    """
    pesos = np.atleast_2d(pesos)
    saida = np.zeros((pesos.shape[0], f.size), dtype=complex)
    arg = -2j * np.pi * f
    for i in range(0, tempos.size, 48):
        e = np.exp(np.outer(tempos[i:i + 48], arg))
        saida += pesos[:, i:i + 48] @ e
    return saida


def _envelope(n: int, centros: np.ndarray, largura: float, pesos: np.ndarray) -> np.ndarray:
    """Soma circular de janelas de Hann, em amostras. Periodica no laco."""
    env = np.zeros(n)
    meia = max(1, int(largura * 0.5))
    k = np.arange(-meia, meia + 1)
    janela = 0.5 + 0.5 * np.cos(np.pi * k / (meia + 1))
    for c, p in zip(centros, pesos):
        idx = (int(round(c)) + k) % n
        np.add.at(env, idx, janela * p)
    return env


def _rms(x: np.ndarray) -> float:
    return float(np.sqrt(np.mean(x * x))) or 1e-12


def _unitario(x: np.ndarray) -> np.ndarray:
    return x / _rms(x)


def _ponderar_k(f: np.ndarray) -> np.ndarray:
    """A ponderacao K do LUFS (BS.1770): passa-alta em 38 Hz e +4 dB no agudo.

    E a regua de volume do banco. Nao e "o que o ouvido acha" — ninguem aqui
    ouviu nada —, e a norma que a industria usa para dizer que duas faixas tem
    o mesmo volume. Sem ponderacao a marcha lenta mediria alto por causa de um
    grave de 27 Hz que ninguem ouve.
    """
    g = 10.0 ** (4.0 / 20.0)
    fa = 1500.0 / math.sqrt(g)
    fb = 1500.0 * math.sqrt(g)
    return _hp2(f, 38.0) * (1.0 + 1j * f / fa) / (1.0 + 1j * f / fb)


def sonoridade(x: np.ndarray, sr: int = SR_BANCO) -> float:
    """Volume ponderado K, em dB relativos a escala cheia."""
    f = np.fft.rfftfreq(x.size, 1.0 / sr)
    y = np.fft.irfft(np.fft.rfft(x) * _ponderar_k(f), x.size)
    return 10.0 * math.log10(max(float(np.mean(y * y)), 1e-20))


# --- a montagem -------------------------------------------------------------

def _tamanho(rpm_nominal: int) -> tuple[int, int, float]:
    """Ciclos, amostras e a rotacao exata do laco.

    Marcha lenta mais longa: o sorteio de cada ciclo repete a cada laco, e com
    sete ciclos por segundo um laco curto vira um ritmo que o ouvido pega.
    """
    dur = 1.5 if rpm_nominal <= 1100 else (1.2 if rpm_nominal <= 2100 else 1.0)
    ciclos = max(6, round(dur * rpm_nominal / 120.0))
    n = round(ciclos * 120.0 * SR_BANCO / rpm_nominal)
    return ciclos, n, ciclos * 120.0 * SR_BANCO / n


def _posicao(arq: Arquitetura, rpm: float) -> float:
    """Onde este giro esta na faixa do motor, de 0 (lenta) a 1 (corte), em log."""
    a, b = arq.grade[0], arq.grade[-1]
    return float(np.clip(math.log(rpm / a) / math.log(b / a), 0.0, 1.0))


def alvo_sonoridade(arq: Arquitetura, rpm: float, carga: str) -> float:
    """A curva de volume do banco, em dB relativos ao topo em carga.

    Autorada, e nao deixada a fisica, porque a fisica da 35 dB entre a lenta e o
    corte (45 dBA parado, 80 dBA a pe no fundo dentro de um carro de rua) e um
    jogo nao tem essa faixa. Cinco decibeis por dobra de giro em carga — 15 dB
    da lenta ao corte, o dobro de pressao sonora de cada duas dobras — e a
    retencao abaixo dela por 3 dB na lenta (onde carga quase nao existe) ate
    9 dB no corte (onde o pe fora e um motor sendo arrastado).

    Reta em log de giro, e por isso suave: entre dois pontos vizinhos da grade
    (razao 1,36) a camada em carga sobe 2,2 dB e a de retencao 1,3.
    """
    on = -5.0 * math.log2(arq.grade[-1] / rpm)
    if carga == "on":
        return on
    return on - (3.0 + 6.0 * _posicao(arq, rpm))


def _semente(arq: str, rpm: int) -> int:
    return 20260922 + sum(ord(c) * 7919 for c in arq) + rpm * 104729


def _acertar_com_fixo(x: np.ndarray, fixo: np.ndarray, alvo: float) -> np.ndarray:
    """g*x + fixo com a sonoridade `alvo`, achando g por bissecao.

    `fixo` e a mecanica que veio da camada em carga no volume absoluto dela; so
    o que depende do pedal (escape, admissao) e escalado.
    """
    if sonoridade(fixo) >= alvo:
        raise ValueError("a mecanica sozinha ja passa do volume da retencao")
    lo, hi = -80.0, 40.0
    base = alvo - sonoridade(x)
    for _ in range(50):
        meio = 0.5 * (lo + hi)
        if sonoridade(x * 10.0 ** ((base + meio) / 20.0) + fixo) > alvo:
            hi = meio
        else:
            lo = meio
    return x * 10.0 ** ((base + 0.5 * (lo + hi)) / 20.0) + fixo


def sintetizar(arq: Arquitetura, rpm_nominal: int) -> tuple[dict[str, np.ndarray], float]:
    """As duas camadas de um ponto da grade, ja no volume da curva.

    `on` e `off` compartilham os MESMOS instantes de explosao e o mesmo ruido:
    tocados juntos, cruzar de um para o outro e um motor mudando de carga, e nao
    dois motores trocando de lugar.
    """
    ciclos, n, rpm = _tamanho(rpm_nominal)
    periodo = n / SR_BANCO
    f = np.fft.rfftfreq(n, 1.0 / SR_BANCO)
    s = _posicao(arq, rpm)
    sorte = np.random.default_rng(_semente(arq.nome, rpm_nominal))
    corpo = _corpo(f)
    ncil = len(arq.angulos)
    w0 = 6.0 * rpm  # graus por segundo

    # --- os instantes ------------------------------------------------------
    ciclo = np.repeat(np.arange(ciclos), ncil)
    cil = np.tile(np.arange(ncil), ciclos)
    base = (ciclo * 720.0 + np.asarray(arq.angulos)[cil]
            + np.asarray(arq.avanco)[cil] + ANGULO_INICIO)
    xi_t = sorte.standard_normal(base.size)
    xi_a = sorte.standard_normal(base.size)
    xi_a2 = 0.5 * xi_a + 0.866 * sorte.standard_normal(base.size)
    # Marcha lenta cacando: o controle de lenta nao segura o giro parado, ele
    # oscila uns 1,2% num ritmo de pouco mais de um por segundo. Numero inteiro
    # de oscilacoes no laco, para ele fechar.
    oscila = 0.012 * float(np.clip(1.0 - s / 0.35, 0.0, 1.0))
    voltas_osc = max(1, round(periodo * 1.3))
    k_osc = 2.0 * np.pi * voltas_osc / periodo

    def instantes(graus: np.ndarray) -> np.ndarray:
        t = graus / w0
        if oscila > 0.0:
            for _ in range(4):
                t = graus / w0 - oscila / k_osc * (1.0 - np.cos(k_osc * t))
        return np.mod(t, periodo)

    # Variabilidade de combustao, em graus de avanco e em fracao de amplitude.
    #
    # Em carga ela e maior em marcha lenta (mistura pobre, pouca turbulencia) e
    # some com o giro. Na retencao ela anda AO CONTRARIO: embaixo o motor ainda
    # queima um resto de mistura, mal e irregular — e o "burburinho" —, e de
    # ~2000 rpm para cima a injecao corta o combustivel e o que sai do escape e
    # ar bombeado, que e regular como um compressor. A primeira versao deixava a
    # retencao irregular ate o corte e o sorteio virava um ronco continuo de
    # grave por baixo das harmonicas, que a 7000 rpm estao a 233 Hz umas das
    # outras e deixam esse grave exposto.
    sig_t = {"on": 0.8 + 2.2 * (1.0 - s) ** 2, "off": 3.0 - 2.0 * s}
    sig_a = {"on": 0.05 + 0.12 * (1.0 - s) ** 2, "off": 0.30 - 0.22 * s}
    deseq = np.asarray(arq.desequilibrio)[cil]
    banco_de = np.asarray(arq.bancos)[cil]
    nbancos = max(arq.bancos) + 1

    # Mecanica: dois fechamentos de valvula por cilindro por ciclo, com o
    # proprio sorteio. Compartilhado entre as camadas: tucho nao sabe de carga.
    vt = np.concatenate([base + 400.0, base + 590.0])
    vt = vt + 1.5 * sorte.standard_normal(vt.size)
    va = np.clip(1.0 + 0.3 * sorte.standard_normal(vt.size), 0.3, None)
    tempos_valvula = instantes(vt)
    estalo = np.zeros(f.size, dtype=complex)
    for fm, dec, peso in arq.modos_valvula:
        wm = 2.0 * np.pi * fm
        modo = wm / ((1.0 / dec + 2j * np.pi * f) ** 2 + wm * wm)
        estalo += peso * modo / np.max(np.abs(modo))
    valvulas = np.fft.irfft(_somar_eventos(f, tempos_valvula, va)[0] * estalo * corpo, n)

    # Sincronismo: um tom em `dentes` vezes a volta, com as bandas laterais do
    # erro de passo (uma volta) e o segundo harmonico. Raia exata: o laco tem
    # 2*ciclos voltas, entao o tom cai em raia inteira e fecha sozinho.
    voltas = 2 * ciclos
    esp = np.zeros(f.size, dtype=complex)
    for mult, peso in ((arq.dentes, 1.0), (arq.dentes - 1, 0.2), (arq.dentes + 1, 0.2),
                       (2 * arq.dentes, 0.3)):
        k = voltas * mult
        if k < f.size:
            esp[k] = peso * np.exp(2j * np.pi * sorte.random())
    sincronismo = np.fft.irfft(esp * corpo, n)

    # Ventoinha do boxer: polia do alternador a ~1,8x o virabrequim, 25 pas.
    # Ruido de escoamento com o tom de passagem de pa por cima.
    ventoinha = np.zeros(n)
    if arq.ventoinha:
        passagem = voltas * 45  # 1,8 * 25 pas, em raias
        f_pa = passagem / periodo
        ruido = np.fft.rfft(sorte.standard_normal(n))
        ruido *= _hp2(f, 700.0) * _lp2(f, 6500.0) * _pico(f, f_pa, 1.2, 3.0)
        tons = np.zeros(f.size, dtype=complex)
        for mult, peso in ((1, 1.0), (2, 0.4)):
            if passagem * mult < f.size:
                tons[passagem * mult] = peso * np.exp(2j * np.pi * sorte.random())
        vt_ruido = np.fft.irfft(ruido * corpo, n)
        vt_tom = np.fft.irfft(tons * corpo, n)
        ventoinha = _unitario(vt_ruido) + 0.6 * _unitario(vt_tom)

    # Primeira ordem do tres cilindros: o virabrequim balanca uma vez por volta,
    # e a carroceria ronca junto.
    balanco = np.zeros(n)
    if arq.primeira_ordem_db is not None:
        esp = np.zeros(f.size, dtype=complex)
        esp[voltas] = 1.0
        esp[2 * voltas] = 0.35 * np.exp(2j * np.pi * sorte.random())
        balanco = np.fft.irfft(esp * corpo, n)

    # O ruido de escoamento da admissao e o assobio da borboleta: um so sorteio,
    # para as duas camadas.
    ruido_admissao = np.fft.rfft(sorte.standard_normal(n))
    ruido_assobio = np.fft.rfft(sorte.standard_normal(n))

    def escapamento(quente: float) -> tuple[np.ndarray, list[np.ndarray]]:
        """A cadeia de escape comum e um coletor por banco, com o gas a esta
        temperatura (multiplicador da velocidade do som)."""
        mag = np.ones(f.size)
        for m, comp in arq.camaras:
            mag *= _camara(f, m, comp / quente)
        cadeia = _fase_minima(mag, n)
        cadeia *= _pente(f, 2.0 * 1.4 / (C_TUBO * quente), 0.35 * np.exp(-f / 2000.0))
        cadeia *= _lp2(f, arq.absorcao)
        cadeia *= _pente(f, 2.0 * arq.ponteira / (C_PONTEIRA * quente),
                         -0.4 * np.exp(-f / 3000.0))
        cadeia *= _hp1(f, 80.0)  # radiacao da boca
        cadeia *= corpo
        coletor = [
            _pente(f, 2.0 * arq.coletores[b] / (C_COLETOR * quente), -0.5 * np.exp(-f / 2500.0))
            * np.exp(-2j * np.pi * f * arq.atraso_banco[b])
            for b in range(nbancos)
        ]
        return cadeia, coletor

    # Admissao: caixa do filtro (Helmholtz perto de 95 Hz), coletor de admissao
    # em quarto de onda, boca irradiando.
    cadeia_adm = (_pico(f, 95.0, 2.5, 4.0)
                  * _pente(f, 2.0 * 0.42 / C_AR, -0.55 * np.exp(-f / 1500.0))
                  * _hp1(f, 80.0) * corpo)
    forma_ronco = _hp2(f, 300.0) * _lp2(f, 3000.0) * _pico(f, 900.0, 1.0, 2.5)
    forma_assobio = (_pico(f, 2300.0, 7.0, 30.0) - 1.0) + 0.5 * (_pico(f, 3600.0, 9.0, 30.0) - 1.0)

    camadas: dict[str, np.ndarray] = {}
    for carga in ("on", "off"):
        on = carga == "on"
        # O gas de escape esquenta com giro e carga: ~400 C em marcha lenta,
        # ~850 C a pe no fundo perto do corte. A velocidade do som vai com a raiz
        # da temperatura absoluta (+29% nessa faixa), e todo tubo e toda camara
        # afinam para cima junto. E por isso que o mesmo escapamento soa mais
        # rasgado acelerando do que aliviando no mesmo giro — o gas da retencao
        # e quase ar.
        cadeia, coletor = escapamento(1.0 + (0.25 if on else 0.03) * s)
        graus = base + sig_t[carga] * xi_t
        tempos = instantes(graus)
        amp = deseq * np.clip(1.0 + sig_a[carga] * (xi_a if on else xi_a2), 0.15, None)

        # --- escapamento ---------------------------------------------------
        tau = arq.sopro / w0 * (1.0 if on else 1.9)
        kappa = 0.45 if on else 0.25
        forma = _gama(f, tau) - kappa * np.exp(-2j * np.pi * f * 3.5 * tau) * _gama(f, 2.5 * tau)
        # O latido: a frente seca do pulso, quando a valvula de escape abre com
        # o cilindro ainda em pressao. A subida dura uns 2 graus de virabrequim
        # — a velocidade de abertura da valvula e angular —, entao ela tambem
        # encurta com o giro. Com subida fixa de 0,1 ms o boxer em marcha lenta
        # virava um tique-taque de estalos 3,5x mais altos que o proprio pulso.
        latido = (arq.latido * (0.4 + 0.6 * s)) if on else 0.01
        forma = forma + latido * _gama(f, max(0.00006, 2.0 / w0))
        pesos = np.zeros((nbancos, tempos.size))
        for b in range(nbancos):
            pesos[b] = np.where(banco_de == b, amp, 0.0)
        somas = _somar_eventos(f, tempos, pesos)
        esc = np.zeros(f.size, dtype=complex)
        for b in range(nbancos):
            esc += coletor[b] * somas[b] * forma
        # Estalos de retencao: combustivel que sobrou queimando no coletor. So da
        # metade da faixa para cima, e FRACOS — uma textura por baixo do escape, e
        # nao estouros. O laco repete a cada segundo e um estouro que volta no
        # mesmo lugar a cada volta vira metronomo; o estouro de verdade e o
        # `motor_alivio`, que o `MotorSom` toca solto na borda do pedal. Na
        # primeira versao eles tinham ate 2,8x o pulso medio, com pico 12 dB
        # acima do resto do arquivo, e comiam a folga do banco inteiro.
        if not on and s > 0.25:
            quantos = sorte.poisson(6.0 * min(1.0, (s - 0.25) / 0.75) * periodo)
            if quantos > 0:
                te = sorte.uniform(0.0, periodo, quantos)
                ae = float(np.mean(amp)) * sorte.uniform(0.15, 0.35, quantos)
                be = sorte.integers(0, nbancos, quantos)
                pe = np.zeros((nbancos, quantos))
                for b in range(nbancos):
                    pe[b] = np.where(be == b, ae, 0.0)
                se = _somar_eventos(f, te, pe)
                # Pressao e rarefacao logo atras: area nula. Um estalo de ponteira nao
                # empurra gas para fora, ele so faz barulho — sem o lobo negativo o
                # estalo carregava grave continuo e ESCURECIA a retencao no corte.
                estouro = _gama(f, 0.0003) - _gama(f, 0.0012) + 0.1 * _gama(f, 0.0001)
                for b in range(nbancos):
                    esc += coletor[b] * se[b] * estouro
        escape = np.fft.irfft(esc * cadeia, n)

        # --- admissao ------------------------------------------------------
        t_adm = instantes(graus + 380.0)
        tau_adm = 40.0 / w0
        pulso_adm = -_somar_eventos(f, t_adm, amp)[0] * _gama(f, tau_adm)
        admissao = np.fft.irfft(pulso_adm * cadeia_adm, n)
        centros = instantes(graus + 470.0) * SR_BANCO
        env = _envelope(n, centros, 180.0 / w0 * SR_BANCO, amp)
        env /= float(np.max(env)) or 1.0
        ronco = np.fft.irfft(ruido_admissao * forma_ronco, n) * (0.25 + env)
        ronco = np.fft.irfft(np.fft.rfft(ronco) * corpo, n)
        assobio = np.fft.irfft(ruido_assobio * forma_assobio, n) * (0.8 + 0.2 * env)
        assobio = np.fft.irfft(np.fft.rfft(assobio) * corpo, n)

        # --- a mistura ----------------------------------------------------
        # O que depende do pedal entra em dB relativos ao escapamento DESTA
        # camada. O que nao depende — tucho, sincronismo, ventoinha, o balanco
        # do virabrequim — tem o MESMO volume absoluto nas duas: o comando de
        # valvulas nao sabe onde esta o pe. Por isso a retencao soa "mecanica":
        # ela nao ficou mais mecanica, o escape e que saiu da frente. A primeira
        # versao dava a mecanica um volume relativo proprio em cada camada, com
        # teto arbitrario, e a retencao acabava com MAIS tucho que a carga.
        if on:
            niveis = {
                "admissao": -16.0 + 8.0 * s,
                "ronco": -21.0 + 13.0 * s ** 1.4,
            }
        else:
            niveis = {
                "admissao": -32.0,
                "ronco": -44.0,
                "assobio": -36.0 + 18.0 * s,
            }
        partes = {"admissao": admissao, "ronco": ronco, "assobio": assobio}
        x = _unitario(escape)
        for chave, db in niveis.items():
            x = x + _unitario(partes[chave]) * 10.0 ** (db / 20.0)
        alvo = alvo_sonoridade(arq, rpm, carga)
        if on:
            mecanica = np.zeros(n)
            for parte, db in ((valvulas, arq.valvula_db + 3.0 * s),
                              (sincronismo, arq.sincronismo_db + 4.0 * s),
                              (ventoinha, -32.0 + 12.0 * s),
                              (balanco, arq.primeira_ordem_db)):
                if db is not None and np.any(parte):
                    mecanica = mecanica + _unitario(parte) * 10.0 ** (db / 20.0)
            y = x + mecanica
            # O volume da curva, e nao o da fisica. Ver `alvo_sonoridade`.
            ganho = 10.0 ** ((alvo - sonoridade(y)) / 20.0)
            camadas[carga] = y * ganho
            mecanica_absoluta = mecanica * ganho
        else:
            camadas[carga] = _acertar_com_fixo(x, mecanica_absoluta, alvo)
    return camadas, rpm


def gravar_banco(nome: str, x: np.ndarray, sr: int = SR_BANCO) -> int:
    """Grava sem normalizar: o volume relativo entre arquivos e informacao.

    O arquivo leva UMA amostra a mais no fim, copia da primeira: a amostra de
    guarda. O laco toca so o corpo (`MotorSom` poe o fim do laco em
    comprimento - 1), e a guarda existe para ser lida pelo reamostrador.

    Por que. O `AudioStreamWAV` interpola a ultima amostra do laco contra a que
    esta DEPOIS dela na memoria, e nao contra a primeira do laco — e depois dela
    ha o preenchimento zerado do buffer. Medido em 22/09/2026 com um laco de
    valor constante 0,5 capturado no Master: a cada volta a saida cai, com
    minimo de -0,37 tocando a 1,00x (o reamostrador cubico ainda passa do ponto)
    e 0,04 a 0,93x. Com a guarda, a amostra seguinte e a continuacao certa e a
    emenda e exata — sem precisar girar o laco para comecar num zero, o que
    tiraria cada arquivo do angulo de virabrequim comum (`ANGULO_INICIO`).
    """
    if float(np.max(np.abs(x))) > 1.0:
        raise ValueError(f"{nome}: estourou ({np.max(np.abs(x)):.3f})")
    dados = np.round(np.append(x, x[0]) * 32767.0).astype("<i2")
    caminho = SAIDA / f"{nome}.wav"
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(dados.tobytes())
    gravar_import(nome)
    return caminho.stat().st_size


def gravar_import(nome: str) -> None:
    """O `.import` do arquivo novo, em PCM. So escreve se ainda nao existe.

    Ver "Por que PCM e nao QOA" no comeco da secao. O Godot completa o resto
    (uid, caminho importado) no primeiro `--import`, e daqui em diante o arquivo
    e dele.
    """
    caminho = SAIDA / f"{nome}.wav.import"
    if caminho.exists():
        return
    caminho.write_text(
        "[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n[params]\n\n"
        "force/8_bit=false\nforce/mono=false\nforce/max_rate=false\n"
        "force/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\n"
        "edit/loop_mode=1\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n",
        encoding="utf-8", newline="\n")


def cambio() -> int:
    """O assobio das engrenagens do cambio, afinado em tempo de execucao.

    Referencia de 1000 Hz, que e a frequencia de engrenamento de um par de
    engrenagens com ~20 dentes no primario a 3000 rpm. O `MotorSom` estica
    isto pela frequencia de engrenamento da marcha que o carro esta usando, e
    a marcha ele descobre pela razao entre giro e velocidade.

    Bandas laterais em +-37 Hz (o eixo girando, com o erro de passo de cada
    volta) e um fio de ruido estreito em volta do tom: engrenagem de verdade
    nao assobia como diapasao.
    """
    n = SR_BANCO  # 1 s: toda raia inteira fecha
    f = np.fft.rfftfreq(n, 1.0 / SR_BANCO)
    sorte = np.random.default_rng(_semente("cambio", 1000))
    esp = np.zeros(f.size, dtype=complex)
    for hz, peso in ((1000, 1.0), (963, 0.16), (1037, 0.16), (2000, 0.25), (1963, 0.05),
                     (2037, 0.05)):
        esp[hz] = peso * np.exp(2j * np.pi * sorte.random())
    tom_ = np.fft.irfft(esp, n)
    ruido = np.fft.irfft(np.fft.rfft(sorte.standard_normal(n)) * (_pico(f, 1000.0, 25.0, 20.0) - 1.0), n)
    x = _unitario(tom_) + 0.25 * _unitario(ruido)
    x *= PICO_BANCO / float(np.max(np.abs(x)))
    tamanho = gravar_banco("motor_cambio", x)
    print(f"{'motor_cambio':22s} {n / SR_BANCO:5.2f} s  {SR_BANCO} Hz")
    return tamanho


def banco() -> int:
    """Gera o banco inteiro. Devolve o tamanho em bytes."""
    total = 0
    SAIDA.mkdir(parents=True, exist_ok=True)
    for arq in ARQUITETURAS.values():
        amostras: dict[str, np.ndarray] = {}
        for rpm_nominal in arq.grade:
            camadas, _rpm = sintetizar(arq, rpm_nominal)
            for carga, x in camadas.items():
                amostras[nome_amostra(arq.nome, rpm_nominal, carga)] = x
        # Um ganho so para a arquitetura inteira: o arquivo mais alto vai a -1 dBFS
        # e todos os outros descem junto, entao a curva de volume sobrevive.
        pico = max(float(np.max(np.abs(x))) for x in amostras.values())
        ganho = PICO_BANCO / pico
        for nome, x in amostras.items():
            total += gravar_banco(nome, x * ganho)
        print(f"{arq.nome:6s} {len(amostras):2d} amostras, ganho comum {20 * math.log10(ganho):+.1f} dB")
    total += cambio()
    return total


# --- conferencia do banco ---------------------------------------------------

def _ler(nome: str) -> tuple[np.ndarray, int]:
    with wave.open(str(SAIDA / f"{nome}.wav"), "rb") as w:
        sr = w.getframerate()
        bruto = w.readframes(w.getnframes())
    return np.frombuffer(bruto, dtype="<i2").astype(float) / 32768.0, sr


def _frequencia_de_explosao(arq: Arquitetura, rpm: float) -> float:
    return rpm / 60.0 * len(arq.angulos) / 2.0


def _periodo_medido(x: np.ndarray, sr: int, f_esperada: float) -> tuple[float, float]:
    """Frequencia fundamental por autocorrelacao (YIN), na janela de meia a uma e
    meia vez o intervalo de explosao. Devolve (Hz, quao bem repete: 0 perfeito).

    Autocorrelacao e nao pico de FFT porque o ouvido acha a altura de um trem de
    pulsos pelo intervalo entre eles, mesmo quando a raia da fundamental e fraca
    (fundamental ausente) — e em marcha lenta, a 27 Hz, ela e.
    """
    f = np.fft.rfftfreq(x.size, 1.0 / sr)
    xf = np.fft.rfft(x) * _lp2(f, 1500.0)
    r = np.fft.irfft(np.abs(xf) ** 2, x.size)
    d = 2.0 * (r[0] - r)
    d[0] = 0.0
    acum = np.cumsum(d)
    cmnd = np.ones_like(d)
    cmnd[1:] = d[1:] * np.arange(1, d.size) / np.maximum(acum[1:], 1e-20)
    t0 = sr / f_esperada
    a, b = int(t0 * 0.5), int(t0 * 1.5)
    k = a + int(np.argmin(cmnd[a:b]))
    # Refinamento parabolico em torno do minimo.
    if 0 < k < d.size - 1:
        y0, y1, y2 = cmnd[k - 1], cmnd[k], cmnd[k + 1]
        den = y0 - 2.0 * y1 + y2
        k = k + (0.5 * (y0 - y2) / den if abs(den) > 1e-12 else 0.0)
    return sr / k, float(cmnd[int(round(k))])


def _raia_explosao_db(x: np.ndarray, sr: int, f_exp: float) -> float:
    """A raia da explosao contra a mais forte abaixo de 2,5x ela, em dB."""
    esp = np.abs(np.fft.rfft(x))
    f = np.fft.rfftfreq(x.size, 1.0 / sr)
    k = int(round(f_exp * x.size / sr))
    raia = float(np.max(esp[max(1, k - 1):k + 2]))
    faixa = (f > 15.0) & (f < 2.5 * f_exp)
    return 20.0 * math.log10(raia / float(np.max(esp[faixa])))


def _brilho(x: np.ndarray, sr: int) -> float:
    """Centroide espectral ponderado por sonoridade, em Hz.

    Bandas de terco de oitava de 20 Hz a 12,5 kHz; o peso de cada banda e a
    potencia dela elevada a 0,3 (a lei de Stevens: sonoridade cresce com a raiz
    cubica da intensidade), e a media e feita em oitavas, que e como o ouvido
    divide frequencia. E a ideia da "agudeza" de Zwicker sem a tabela de Bark.

    Por que nao o centroide cru (media de Hz ponderada pelo modulo de cada raia
    da FFT): porque num trem de pulsos ele mede outra coisa. O modulo soma raia
    por raia, e um componente continuo — um estalo avulso, o ruido da ventoinha —
    ocupa todas as raias entre as harmonicas, enquanto o escape ocupa so as
    harmonicas. Medido na primeira versao deste banco: o i4 em retencao a 7000
    rpm tinha 4,7 dB MAIS energia acima de 1 kHz que a 5200 e o centroide cru
    dele CAIU de 1548 para 1211 Hz, porque os estalos de retencao entraram. Um
    numero que desce quando o agudo sobe nao e medida de brilho.
    """
    esp = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(x.size, 1.0 / sr)
    pesos, oitavas = [], []
    for k in range(29):
        c = 20.0 * 2.0 ** (k / 3.0)
        faixa = (f >= c * 2.0 ** (-1.0 / 6.0)) & (f < c * 2.0 ** (1.0 / 6.0))
        pesos.append(float(esp[faixa].sum()) ** 0.3)
        oitavas.append(math.log2(c))
    p = np.asarray(pesos)
    return 2.0 ** float((p * np.asarray(oitavas)).sum() / p.sum())


def _agudo_db(x: np.ndarray, sr: int, corte: float = 1000.0) -> float:
    """Energia acima de `corte`, em dB relativos a escala cheia."""
    esp = np.abs(np.fft.rfft(x)) ** 2
    f = np.fft.rfftfreq(x.size, 1.0 / sr)
    return 10.0 * math.log10(max(float(esp[f > corte].sum()) * 2.0 / x.size ** 2, 1e-20))


def conferir_banco() -> int:
    """Confere o banco novo sem ouvi-lo. Uma linha por arquivo.

    guarda      a amostra de guarda (a ultima do arquivo) e copia da primeira.
                Ver `gravar_banco`.
    emenda      o degrau da ultima amostra do corpo para a primeira, em
                unidades do degrau medio. Laco que fecha da ~1; estalo, dezenas.
    ciclos      o corpo tem exatamente o numero de amostras de `ciclos` ciclos
                de motor na rotacao de referencia.
    f_exp/f_med a frequencia de explosao (rpm/60 * cilindros/2) e a medida por
                autocorrelacao. Tem de bater em 3%: e a altura do motor.
    raia        a raia da explosao contra a mais forte abaixo de 2,5x ela. Nao
                pode sumir (fundamental ausente demais vira outro motor).
    brilho      `_brilho`. Tem de subir com o giro em cada camada: o pulso
                encurta, o gas esquenta e a admissao abre.
    dB          sonoridade ponderada K. On acima de off no mesmo giro; vizinhos
                da grade a no maximo 3 dB um do outro, que e o salto que se
                ouviria como degrau durante o cruzamento.
    >1k         energia acima de 1 kHz. Em carga, pelo menos 3 dB acima da
                retencao no mesmo giro: e o "rasgado" do pe no fundo.
    pico        dBFS. Nada estoura.
    """
    falhas = 0

    def falha(texto: str) -> None:
        nonlocal falhas
        falhas += 1
        print(f"  FALHA  {texto}")

    print()
    print(f"{'amostra':22s} {'s':>5s} {'ciclos':>6s} {'emenda':>7s} {'f_exp':>7s}"
          f" {'f_med':>7s} {'erro':>6s} {'raia':>6s} {'brilho':>7s} {'dB':>6s}"
          f" {'passo':>6s} {'>1k':>6s} {'pico':>6s}")
    for arq in ARQUITETURAS.values():
        anterior: dict[str, tuple[float, float]] = {}
        for rpm_nominal in arq.grade:
            medidas: dict[str, tuple[float, float, float]] = {}
            ciclos, n, rpm = _tamanho(rpm_nominal)
            for carga in ("on", "off"):
                nome = nome_amostra(arq.nome, rpm_nominal, carga)
                bruto, sr = _ler(nome)
                if bruto[-1] != bruto[0]:
                    falha(f"{nome}: a amostra de guarda nao e a primeira")
                x = bruto[:-1]
                if x.size != n or sr != SR_BANCO:
                    falha(f"{nome}: {x.size} amostras a {sr} Hz, e nao {n} a {SR_BANCO}")
                passo_medio = float(np.mean(np.abs(np.diff(x))))
                emenda = abs(x[0] - x[-1]) / passo_medio
                f_exp = _frequencia_de_explosao(arq, rpm)
                f_med, _rep = _periodo_medido(x, sr, f_exp)
                erro = f_med / f_exp - 1.0
                raia = _raia_explosao_db(x, sr, f_exp)
                brilho = _brilho(x, sr)
                db = sonoridade(x, sr)
                agudo = _agudo_db(x, sr)
                pico = 20.0 * math.log10(float(np.max(np.abs(x))))
                passo = db - anterior[carga][0] if carga in anterior else 0.0
                print(f"{nome:22s} {x.size / sr:5.2f} {ciclos:6d} {emenda:6.1f}x"
                      f" {f_exp:7.1f} {f_med:7.1f} {erro * 100:5.1f}% {raia:5.1f}"
                      f" {brilho:7.0f} {db:6.1f} {passo:+6.1f} {agudo:6.1f} {pico:6.1f}")
                if emenda > 6.0:
                    falha(f"{nome}: o laco estala na volta ({emenda:.1f}x)")
                if abs(erro) > 0.03:
                    falha(f"{nome}: a altura medida ({f_med:.1f} Hz) nao e a da"
                          f" explosao ({f_exp:.1f} Hz)")
                if raia < -12.0:
                    falha(f"{nome}: a raia da explosao sumiu ({raia:.1f} dB)")
                if pico > -0.05:
                    falha(f"{nome}: estoura ({pico:.2f} dBFS)")
                if carga in anterior:
                    if brilho <= anterior[carga][1]:
                        falha(f"{nome}: o timbre nao abriu com o giro"
                              f" ({anterior[carga][1]:.0f} -> {brilho:.0f} Hz)")
                    if abs(passo) > 3.0:
                        falha(f"{nome}: salto de volume de {passo:+.1f} dB para o vizinho")
                medidas[carga] = (db, brilho, agudo)
            on, off = medidas["on"], medidas["off"]
            if on[0] <= off[0]:
                falha(f"{arq.nome} {rpm_nominal}: em carga nao e mais alto que em retencao")
            if on[1] <= off[1]:
                falha(f"{arq.nome} {rpm_nominal}: em carga nao e mais brilhante que em"
                      f" retencao ({on[1]:.0f} contra {off[1]:.0f} Hz)")
            if on[2] < off[2] + 3.0:
                falha(f"{arq.nome} {rpm_nominal}: em carga nao rasga mais que em retencao"
                      f" ({on[2]:.1f} contra {off[2]:.1f} dB acima de 1 kHz)")
            anterior = {k: (v[0], v[1]) for k, v in medidas.items()}
    # O assobio do cambio tambem e laco: guarda e emenda.
    bruto, _sr = _ler("motor_cambio")
    x = bruto[:-1]
    emenda = abs(x[0] - x[-1]) / float(np.mean(np.abs(np.diff(x))))
    print(f"{'motor_cambio':22s} {x.size / SR_BANCO:5.2f} {'':6s} {emenda:6.1f}x")
    if bruto[-1] != bruto[0] or emenda > 6.0:
        falha("motor_cambio: o laco nao fecha")
    return falhas


def main() -> int:
    # O legado e os sons de evento, na ordem de sempre: o gerador aleatorio e um
    # so, e esta ordem e o que mantem os bytes. Ver o cabecalho.
    faixa_baixa()
    faixa_media()
    faixa_alta()
    corte()
    pneu()
    derrapagem()
    batida()
    alivio()
    vento()
    print()
    tamanho = banco()
    print(f"\nbanco novo: {tamanho / 1e6:.2f} MB em {SAIDA.relative_to(RAIZ)}")
    falhas = conferir()
    falhas += conferir_banco()
    if falhas:
        print()
        print(f"{falhas} problema(s) no banco")
        return 1
    print()
    print("banco ok: os lacos fecham, a altura e a da explosao, o timbre abre com o"
          " giro e o volume sobe sem degrau")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
