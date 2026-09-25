#!/usr/bin/env python3
"""Sons das cabecadas do padre na janela do motorista.

Separado de `gerar_audio_susto.py` pelo mesmo motivo dele: cada gerador so
escreve os proprios arquivos. A 44.100 Hz, e nao nos 22.050 da biblia: a
batida de cranio no vidro vive no ataque (o estalo do vidro, a unha, o
chocalho da borracha), e a 22 kHz tudo acima de 11 kHz some — o vidro soava
papelao.

A cena (`AberturaEstrada._cabecadas_no_vidro`) empilha, por golpe:

- `cabecada_vidro_N` (1 a 3): o fisico — o cranio batendo (grave curto e
  surdo, a carne), o vidro vibrando no caixilho (modos da lamina e o chocalho
  da borracha), o molhado do sangue e, do segundo golpe em diante, o osso
  estalando e a trinca correndo;
- `tensao_suga`: meio segundo de ar sendo puxado para dentro, que TERMINA no
  impacto (tocado antes dele): e o que faz o golpe chegar;
- `tensao_impacto_N`: o golpe "de filme", cada um maior — o grave que afunda,
  e por cima um metal arranhado e desafinado que cresce de golpe em golpe;
- `tensao_drone_loop`: o cluster grave que nasce na primeira batida e sobe um
  degrau a cada uma;
- `zumbido_ouvido`: o apito depois do estouro.

E os pequenos: `mao_pousa_vidro` (a palma pousando molhada), `unha_vidro`
(as unhas arrastando), `padre_riso` (o ar passando pelos dentes quando o
sorriso abre), `testa_descola` (a pele descolando do vidro com sangue).

    python tools/gerar_audio_cabecada.py [nomes...]
"""

import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 44100

rng = np.random.default_rng(3141)


def gravar(nome: str, x: np.ndarray, ganho: float = 0.92) -> None:
    pico = float(np.max(np.abs(x))) or 1.0
    y = np.clip(x / pico * ganho, -1.0, 1.0)
    dados = (y * 32767.0).astype("<i2")
    SAIDA.mkdir(parents=True, exist_ok=True)
    with wave.open(str(SAIDA / f"{nome}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{nome:22s} {len(y) / SR:5.2f} s")


def tempo(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def ruido(n: int) -> np.ndarray:
    return rng.standard_normal(n)


def banda(x: np.ndarray, baixo: float, alto: float, ordem: int = 4) -> np.ndarray:
    baixo = max(baixo, 5.0)
    alto = min(alto, SR * 0.49)
    sos = signal.butter(ordem, [baixo, alto], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def passa_baixa(x: np.ndarray, corte: float, ordem: int = 4) -> np.ndarray:
    sos = signal.butter(ordem, min(corte, SR * 0.49), btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def passa_alta(x: np.ndarray, corte: float, ordem: int = 4) -> np.ndarray:
    sos = signal.butter(ordem, corte, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def ressoa(x: np.ndarray, f: float, q: float) -> np.ndarray:
    """Um modo ressonante (filtro de pico) excitado por `x`."""
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.lfilter(b, a, x)


def envelope(n: int, ataque: float, queda: float) -> np.ndarray:
    t = np.arange(n) / SR
    sobe = np.clip(t / max(ataque, 1e-5), 0.0, 1.0)
    return sobe * np.exp(-np.maximum(t - ataque, 0.0) / queda)


def janela(n: int, borda: float) -> np.ndarray:
    m = max(1, int(SR * borda))
    w = np.ones(n)
    rampa = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, m))
    w[:m] *= rampa
    w[-m:] *= rampa[::-1]
    return w


def pos(x: np.ndarray, som: np.ndarray, t0: float, ganho: float = 1.0) -> None:
    i = int(SR * t0)
    if i >= len(x):
        return
    m = min(len(som), len(x) - i)
    x[i:i + m] += som[:m] * ganho


def laco(x: np.ndarray, borda: float = 0.6) -> np.ndarray:
    """Dobra a cauda sobre o comeco em cosseno: o fim vira o comeco."""
    m = int(SR * borda)
    corpo = x[:-m].copy()
    rampa = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, m))
    corpo[:m] = corpo[:m] * rampa + x[-m:] * (1.0 - rampa)
    return corpo


def satura(x: np.ndarray, k: float) -> np.ndarray:
    return np.tanh(x * k) / np.tanh(k)


# --- o fisico ---------------------------------------------------------------

def cranio(n: int, f0: float, peso: float) -> np.ndarray:
    """O cranio batendo: um grave surdo que cai de tom (a pele amortece) e a
    carne, ruido grave curto."""
    t = np.arange(n) / SR
    f = f0 * (1.0 - 0.35 * (1.0 - np.exp(-t / 0.03)))
    fase = 2 * np.pi * np.cumsum(f) / SR
    osso = np.sin(fase) * envelope(n, 0.0008, 0.05 + 0.03 * peso)
    carne = passa_baixa(ruido(n), 420) * envelope(n, 0.0005, 0.018 + 0.01 * peso)
    return satura(osso * 1.2 + carne * 0.9, 1.6 + peso)


def lamina(n: int, forca: float, semente: int) -> np.ndarray:
    """O vidro temperado da porta vibrando no caixilho: modos da lamina,
    excitados por um impulso, e o chocalho da borracha e do mecanismo do vidro
    dentro da porta."""
    r = np.random.default_rng(semente)
    imp = np.zeros(n)
    imp[:int(SR * 0.002)] = r.standard_normal(int(SR * 0.002))
    modos = [(178, 18, 1.0), (402, 26, 0.8), (688, 30, 0.62), (1127, 38, 0.5),
             (1713, 44, 0.36), (2476, 52, 0.26), (3390, 60, 0.18), (4602, 70, 0.12)]
    x = np.zeros(n)
    for f, q, a in modos:
        f *= r.uniform(0.97, 1.03)
        x += ressoa(imp, f, q) * a
    x *= envelope(n, 0.0005, 0.10 + 0.05 * forca)
    t = np.arange(n) / SR
    chocalho = banda(ruido(n), 1400, 6500) * envelope(n, 0.002, 0.07 + 0.04 * forca) \
        * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 37.0 * t)))
    mecanismo = banda(ruido(n), 150, 900) * envelope(n, 0.004, 0.12) \
        * (0.5 + 0.5 * np.sin(2 * np.pi * 23.0 * t) ** 2)
    return x * 1.0 + chocalho * 0.35 * forca + mecanismo * 0.3


def molhado(n: int, forca: float) -> np.ndarray:
    """O sangue e a pele molhada no vidro: um estalo de agua curto e um
    chape que sobe de tom (a pele descolando uns milimetros)."""
    t = np.arange(n) / SR
    estalo = banda(ruido(n), 900, 5000) * envelope(n, 0.0004, 0.012)
    f = 380.0 + 900.0 * np.clip(t / 0.05, 0, 1)
    chape = banda(ruido(n), 300, 3200) * np.sin(2 * np.pi * np.cumsum(f) / SR) ** 2 \
        * envelope(n, 0.003, 0.03)
    return estalo * 0.6 * forca + chape * 0.5 * forca


def estalos(n: int, quantos: int, janela_s: float, baixo: float, alto: float,
            semente: int) -> np.ndarray:
    """Cliques de osso ou de trinca: impulsos filtrados, espaçados cada vez
    mais."""
    r = np.random.default_rng(semente)
    x = np.zeros(n)
    tempos = np.sort(r.uniform(0, 1, quantos) ** 2.2) * janela_s
    for tk in tempos:
        m = int(SR * r.uniform(0.0015, 0.004))
        clique = r.standard_normal(m) * np.exp(-np.arange(m) / (m * 0.25))
        pos(x, clique, tk, r.uniform(0.4, 1.0))
    return banda(x, baixo, alto)


def cabecada_vidro(golpe: int) -> np.ndarray:
    forca = [0.6, 0.82, 1.0][golpe]
    dur = [0.9, 1.1, 1.3][golpe]
    n = int(SR * dur)
    x = cranio(n, [112, 98, 86][golpe], forca) * 1.1
    x += lamina(n, forca, 90 + golpe) * [0.55, 0.7, 0.8][golpe]
    x += molhado(n, forca) * [0.5, 0.65, 0.8][golpe]
    if golpe >= 1:
        # O osso: a testa abrindo.
        x += estalos(n, [0, 9, 16][golpe], 0.035, 1800, 7000, 11 + golpe) * 0.45
        # A trinca correndo pelo vidro: estalinhos agudos que rareiam.
        x += estalos(n, [0, 14, 26][golpe], 0.35, 3500, 11000, 23 + golpe) * 0.3
    return x * janela(n, 0.002)


def testa_descola() -> np.ndarray:
    """A pele descolando do vidro molhado de sangue: chupado, grudento."""
    dur = 0.32
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 260.0 + 1400.0 * (t / dur) ** 0.6
    chupa = banda(ruido(n), 200, 3000) * np.abs(np.sin(2 * np.pi * np.cumsum(f) / SR)) \
        * envelope(n, 0.03, 0.08)
    gruda = estalos(n, 12, 0.22, 1500, 6000, 77) * 0.5
    return (chupa + gruda) * janela(n, 0.004)


def mao_pousa_vidro() -> np.ndarray:
    """A palma pousando devagar no vidro molhado: os dedos primeiro (tique,
    tique), a palma assentando (surdo e largo) e o chiado da pele."""
    dur = 0.9
    n = int(SR * dur)
    x = np.zeros(n)
    for k, t0 in enumerate([0.0, 0.045, 0.075, 0.11]):
        m = int(SR * 0.05)
        dedo = banda(ruido(m), 600, 4000) * envelope(m, 0.0005, 0.006)
        dedo += lamina(m, 0.15, 300 + k) * 0.25
        pos(x, dedo, t0, 0.6)
    m = int(SR * 0.4)
    palma = passa_baixa(ruido(m), 500) * envelope(m, 0.012, 0.05)
    palma += lamina(m, 0.25, 333) * 0.2
    pos(x, palma, 0.16, 0.9)
    m = int(SR * 0.55)
    tt = np.arange(m) / SR
    chiado = banda(ruido(m), 900, 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 31 * tt)) \
        * envelope(m, 0.05, 0.16)
    pos(x, chiado, 0.22, 0.35)
    return x * janela(n, 0.003)


def unha_vidro() -> np.ndarray:
    """As unhas raspando o vidro devagar: stick-slip, um tom que gagueja e
    muda de altura com a pressao."""
    dur = 1.1
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k, base in enumerate([1180.0, 1460.0, 990.0]):
        r = np.random.default_rng(500 + k)
        pressao = 0.6 + 0.4 * np.sin(2 * np.pi * r.uniform(0.7, 1.4) * t + k)
        f = base * (0.85 + 0.3 * pressao) * (1.0 + 0.01 * r.standard_normal(n).cumsum() / np.sqrt(n))
        fase = 2 * np.pi * np.cumsum(f) / SR
        # Stick-slip: dente de serra com o ciclo aparecendo e sumindo.
        serra = (fase / (2 * np.pi)) % 1.0 * 2.0 - 1.0
        pega = (np.sin(2 * np.pi * r.uniform(9, 17) * t + k) > r.uniform(-0.3, 0.3)).astype(float)
        pega = passa_baixa(pega, 60, 2)
        x += serra * pega * pressao * [1.0, 0.6, 0.45][k]
    x = banda(x, 700, 9000)
    x *= envelope(n, 0.08, 0.5)
    return x * janela(n, 0.01)


def padre_riso() -> np.ndarray:
    """O ar passando entre os dentes enquanto a boca abre: nao e riso de
    gente, e um sopro em soluços com a garganta rangendo por baixo (vocal
    fry a ~40 Hz), cada vez mais comprido."""
    dur = 2.2
    n = int(SR * dur)
    x = np.zeros(n)
    t0 = 0.0
    for k, (d, g) in enumerate([(0.16, 0.5), (0.2, 0.7), (0.26, 0.85), (0.5, 1.0)]):
        m = int(SR * d)
        tt = np.arange(m) / SR
        sopro = banda(ruido(m), 500, 4200) * np.sin(np.pi * tt / d) ** 1.5
        # A garganta: pulsos a ~38-46 Hz, irregulares, filtrados como voz.
        pul = np.zeros(m)
        p = 0.0
        while p < d:
            i = int(p * SR)
            if i < m:
                pul[i] = 1.0
            p += 1.0 / rng.uniform(36, 48)
        fry = banda(ressoa(pul, 520, 4) + ressoa(pul, 1150, 5) * 0.6, 120, 3000)
        fry *= np.sin(np.pi * tt / d) ** 0.8
        pos(x, sopro * 0.5 + fry * 0.9, t0, g)
        t0 += d + [0.11, 0.09, 0.07, 0.0][k]
    return x * janela(n, 0.005)


# --- a enfase ---------------------------------------------------------------

def tensao_suga() -> np.ndarray:
    """Meio segundo de ar puxado, que acaba NO impacto: ruido que cresce e
    sobe de tom, cortado seco no fim."""
    dur = 0.55
    n = int(SR * dur)
    t = np.arange(n) / SR
    k = (t / dur) ** 2.6
    x = np.zeros(n)
    # Ruido filtrado com o corte subindo: bloco a bloco.
    blocos = 24
    for b in range(blocos):
        i0 = b * n // blocos
        i1 = (b + 1) * n // blocos
        f = 300.0 + 5200.0 * (b / blocos) ** 2
        seg = banda(ruido(i1 - i0 + 2048), f * 0.5, f * 1.6)[1024:1024 + i1 - i0]
        x[i0:i1] = seg
    f = 60.0 + 240.0 * k
    tom = np.sin(2 * np.pi * np.cumsum(f) / SR)
    x = x * k * 0.8 + tom * k * 0.5
    # Corte seco no fim (e o golpe que corta), com dois ms de rampa.
    m = int(SR * 0.002)
    x[-m:] *= np.linspace(1, 0, m)
    return x


def tensao_impacto(golpe: int) -> np.ndarray:
    """O golpe de filme, maior a cada batida: grave que afunda e satura, um
    baque de tambor, e o metal arranhado — parciais inarmonicas desafinadas
    entre si, arrastadas como arco em chapa."""
    dur = [2.2, 2.8, 3.6][golpe]
    forca = [0.6, 0.8, 1.0][golpe]
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 62.0 * np.exp(-t * 1.1) + 27.0 * (1 - np.exp(-t * 1.1))
    grave = satura(np.sin(2 * np.pi * np.cumsum(f) / SR), 1.5 + 2.0 * forca) \
        * envelope(n, 0.003, 0.5 + 0.5 * forca)
    tambor = passa_baixa(ruido(n), 180) * envelope(n, 0.001, 0.09)
    tambor += np.sin(2 * np.pi * 74 * t * (1 - 0.3 * t)) * envelope(n, 0.001, 0.14)
    metal = np.zeros(n)
    parc = [311.0, 347.0, 523.0, 587.0, 882.0, 1244.0, 1318.0, 1861.0, 2637.0]
    for k, p in enumerate(parc[: 5 + golpe * 2]):
        vib = 1.0 + 0.004 * np.sin(2 * np.pi * (3.1 + k * 0.53) * t + k)
        ph = 2 * np.pi * np.cumsum(p * vib * (1.0 - 0.03 * t)) / SR
        arco = 0.5 + 0.5 * banda(ruido(n), 2, 18, 2) * 8.0
        metal += np.sin(ph) * np.clip(arco, 0, 1.5) / (1 + k * 0.3)
    metal = banda(metal, 250, 8000) * envelope(n, 0.02, 0.6 + 0.4 * forca)
    estalo = banda(ruido(n), 80, 12000) * envelope(n, 0.0005, 0.02)
    x = grave * 1.0 + tambor * 0.8 + metal * (0.18 + 0.12 * golpe) + estalo * 0.5
    return x * janela(n, 0.004)


def tensao_drone_loop() -> np.ndarray:
    """O cluster grave: duas quintas uma segunda menor de distancia (55/58,3 e
    82,4/87,3 Hz) com o batimento lento entre elas, e um ar escuro por cima.
    Oito segundos em laco; quem sobe o degrau e a afinacao do tocador."""
    dur = 8.6
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, a in [(55.0, 1.0), (58.27, 0.8), (82.41, 0.55), (87.31, 0.5), (110.0, 0.25),
                 (116.54, 0.22)]:
        vib = 1.0 + 0.0025 * np.sin(2 * np.pi * 0.13 * t + f)
        ph = 2 * np.pi * np.cumsum(f * vib) / SR
        # Serra suavizada: harmonicos que o filtro abre e fecha devagar.
        serra = sum(np.sin(ph * h) / h for h in range(1, 9))
        x += serra * a
    abre = 0.55 + 0.45 * np.sin(2 * np.pi * t / dur * 2.0) ** 2
    x = passa_baixa(x, 700) * abre + banda(x, 700, 1800) * 0.15
    ar = banda(ruido(n), 60, 900) * 0.08
    return laco(x + ar, 0.6)


def zumbido_ouvido() -> np.ndarray:
    """O apito no ouvido depois do estouro: dois senos agudos batendo e um
    fio de ruido, que sobe rapido e morre devagar."""
    dur = 4.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 7120 * t) + 0.6 * np.sin(2 * np.pi * 7187 * t) \
        + 0.25 * np.sin(2 * np.pi * 3560 * t)
    x += banda(ruido(n), 6500, 8000) * 0.15
    return x * envelope(n, 0.08, 1.4) * janela(n, 0.01)


# --- o gore ------------------------------------------------------------------

def nariz_quebra() -> np.ndarray:
    """A cartilagem e o osso do nariz cedendo: um estalo seco grave (o osso
    partindo), uma rajada de cliques miudos (a cartilagem esmigalhando) e o
    molhado por baixo."""
    dur = 0.6
    n = int(SR * dur)
    t = np.arange(n) / SR
    osso = banda(ruido(n), 250, 2400) * envelope(n, 0.0004, 0.012)
    osso += np.sin(2 * np.pi * 190 * t * (1 - 0.5 * t)) * envelope(n, 0.0005, 0.03) * 0.7
    cart = estalos(n, 38, 0.09, 1200, 7500, 901) * 0.8
    cart += estalos(n, 16, 0.2, 600, 3500, 902) * 0.5
    umido = molhado(n, 1.0) * 0.8
    return satura(osso * 1.1 + cart + umido, 1.4) * janela(n, 0.002)


def carne_rasga() -> np.ndarray:
    """Pele e musculo rasgando: um ruido grudento que sobe, em fibras que
    estouram (cliques ralos) e um descolar molhado no fim."""
    dur = 0.55
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = 400.0 + 1800.0 * (t / dur) ** 0.7
    rasgo = banda(ruido(n), 300, 5000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(f * 0.06) / SR)))
    rasgo *= envelope(n, 0.02, 0.18)
    fibras = estalos(n, 30, 0.4, 1500, 8000, 903) * 0.6
    return (rasgo * 0.8 + fibras) * janela(n, 0.003)


def olho_sai() -> np.ndarray:
    """O olho saindo da orbita: a sucção (a orbita soltando), um estalo
    molhado e o fio esticando — um rangido fino que sobe de tom."""
    dur = 1.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    m = int(SR * 0.12)
    tt = np.arange(m) / SR
    f = 180.0 + 900.0 * (tt / 0.12) ** 0.5
    succao = banda(ruido(m), 150, 2500) * np.abs(np.sin(2 * np.pi * np.cumsum(f) / SR))         * envelope(m, 0.01, 0.05)
    x = np.zeros(n)
    pos(x, succao, 0.0, 1.0)
    estalo = banda(ruido(n), 400, 6000) * envelope(n, 0.0004, 0.01)
    pos(x, estalo[: int(SR * 0.08)], 0.07, 1.1)
    # O fio: stick-slip fino, subindo, que para quando o nervo segura.
    k = np.clip((t - 0.08) / 0.5, 0.0, 1.0)
    ff = 700.0 + 1600.0 * k
    serra = ((np.cumsum(ff) / SR) % 1.0) * 2.0 - 1.0
    pega = (np.sin(2 * np.pi * 23.0 * t) > 0.2).astype(float)
    fio = banda(serra * passa_baixa(pega, 80, 2), 900, 6000) * (k > 0) * np.exp(-np.maximum(t - 0.5, 0) / 0.1)
    x += fio * 0.25
    x += molhado(n, 1.0) * 0.5
    return x * janela(n, 0.004)


def sangue_pinga_loop() -> np.ndarray:
    """Sangue pingando no forro plastico da porta: plics curtos e molhados, a
    intervalos irregulares, e um que cai no que ja juntou (mais grave e
    chapinhado)."""
    dur = 3.0
    n = int(SR * dur)
    x = np.zeros(n)
    r = np.random.default_rng(904)
    t0 = 0.05
    while t0 < dur - 0.1:
        m = int(SR * 0.06)
        tt = np.arange(m) / SR
        f0 = r.uniform(900, 1700)
        plic = np.sin(2 * np.pi * f0 * tt * (1 + 3.0 * tt)) * envelope(m, 0.0005, 0.008)
        plic += banda(ruido(m), 1500, 6000) * envelope(m, 0.0003, 0.003) * 0.4
        if r.random() < 0.35:
            plic += banda(ruido(m), 200, 1200) * envelope(m, 0.001, 0.02) * 0.5
        pos(x, plic, t0, r.uniform(0.4, 1.0))
        t0 += r.uniform(0.09, 0.35)
    return laco(x, 0.2)


SONS = {
    "cabecada_vidro_1": lambda: cabecada_vidro(0),
    "cabecada_vidro_2": lambda: cabecada_vidro(1),
    "cabecada_vidro_3": lambda: cabecada_vidro(2),
    "testa_descola": testa_descola,
    "mao_pousa_vidro": mao_pousa_vidro,
    "unha_vidro": unha_vidro,
    "padre_riso": padre_riso,
    "tensao_suga": tensao_suga,
    "tensao_impacto_1": lambda: tensao_impacto(0),
    "tensao_impacto_2": lambda: tensao_impacto(1),
    "tensao_impacto_3": lambda: tensao_impacto(2),
    "tensao_drone_loop": tensao_drone_loop,
    "zumbido_ouvido": zumbido_ouvido,
    "nariz_quebra": nariz_quebra,
    "carne_rasga": carne_rasga,
    "olho_sai": olho_sai,
    "sangue_pinga_loop": sangue_pinga_loop,
}


def main() -> int:
    nomes = sys.argv[1:] or list(SONS)
    for nome in nomes:
        gravar(nome, SONS[nome]())
    return 0


if __name__ == "__main__":
    sys.exit(main())
