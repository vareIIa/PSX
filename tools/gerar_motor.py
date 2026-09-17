#!/usr/bin/env python3
"""Banco de amostras do motor do carro do jogador.

Por que nao esta em gerar_audio.py
----------------------------------
Esta separado por uma razao de higiene, e nao de arrumacao: `gerar_audio.py` tem
UM gerador aleatorio criado no topo do modulo e consumido na ordem em que as
funcoes sao chamadas. Acrescentar um sorteio no meio dele muda o ruido de todo
som gerado DEPOIS — buzina, porta, passos — e a arvore aparece com trinta
arquivos modificados que ninguem pediu. Aqui o gerador e local e semeado
proprio, entao rodar isto mexe nestes cinco arquivos e em nenhum outro.

Por que sao tres loops e nao um
-------------------------------
Porque afinacao nao substitui timbre. O motor antigo era um loop de 46 Hz
esticado da marcha lenta ao corte: 0,6x a 4,7x. Uma amostra de 22 kHz puxada a
4,7x vira assobio, e puxada a 0,6x vira lama. Pior: um motor de quatro
cilindros NAO soa igual em rotacao alta e baixa — embaixo ele e desigual e
cavernoso, com meia-ordem audivel entre as explosoes; em cima ele fecha numa
parede continua e rasgada. Esticar uma amostra so nao produz essa mudanca, e e
justamente ela que o ouvido usa para saber que o carro esta acelerando.

Entao sao tres timbres, um por faixa, cruzados em rotacao. Cada um so e
esticado dentro da propria vizinhanca, onde esticar nao machuca.

    motor_baixo   1200 rpm de referencia — marcha lenta e saida
    motor_medio   3240 rpm — a faixa em que a cidade inteira acontece
    motor_alto    5640 rpm — pe no fundo, perto do corte

Mais dois sons de evento e um de rolamento:

    motor_corte   a faisca cortando no limitador e na troca
    pneu_loop     o rolamento do pneu no asfalto, que sobe com a velocidade
    pneu_canta    a borracha escorregando: curva forte, freio de mao, arrancada
    batida_carro  lataria contra alguma coisa
    motor_alivio  o escapamento estourando quando o pe sai do acelerador
    vento_carro   o ar na lataria, que acima dos 80 km/h manda no ouvido

    python tools/gerar_motor.py
"""

from __future__ import annotations

import wave
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
    """Confere o que da para afirmar de um som sem ouvi-lo.

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


def main() -> int:
    faixa_baixa()
    faixa_media()
    faixa_alta()
    corte()
    pneu()
    derrapagem()
    batida()
    alivio()
    vento()
    print(f"\n9 sons em {SAIDA.relative_to(RAIZ)}")
    falhas = conferir()
    if falhas:
        print()
        print(f"{falhas} problema(s) no banco")
        return 1
    print()
    print("banco ok: o timbre abre com a faixa e os lacos fecham")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
