#!/usr/bin/env python3
"""Sons do susto da estrada (PLANO_INTRODUCAO_AAA_PICA, Parte A).

Separado de `gerar_audio.py` pelo mesmo motivo do tombo: este so escreve os
proprios arquivos, e rodar um nao reescreve o do outro. Mesmo formato
(ART-BIBLE secao 11): 22.050 Hz, mono, 16 bits, sintese sem amostra de
terceiro.

Os tres golpes da cena pedem tres timbres diferentes, e isso e o que impede o
trecho de virar "o mesmo estouro tres vezes":

- golpe 1 (o padre na estrada): `susto_golpe` — grave que afunda e um cacho
  de agudos desafinados raspando por cima. E o unico som "de filme".
- golpe 2 (a arvore): e fisico, nao musical — `batida_carro` (ja existe),
  `vidro_trinca`, `galhos_lataria` e `motor_morre`.
- golpe 3 (a janela): `tapa_vidro` seco, sem cauda, e o mundo acaba ali. O que
  sobra e o corpo dele: `respiracao_susto`, `coracao_loop` e a outra
  respiracao, `respiracao_calma`, que nao e dele.

    python tools/gerar_audio_susto.py
"""

import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

rng = np.random.default_rng(1077)


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
    print(f"{nome:22s} {len(y) / SR:5.2f} s")


def tempo(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def passa_banda(x: np.ndarray, baixo: float, alto: float) -> np.ndarray:
    f = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    f[(freqs < baixo) | (freqs > alto)] = 0.0
    return np.fft.irfft(f, len(x))


def ruido(n: int) -> np.ndarray:
    return rng.standard_normal(n)


def envelope(n: int, ataque: float, queda: float) -> np.ndarray:
    t = np.arange(n) / SR
    sobe = np.clip(t / max(ataque, 1e-4), 0.0, 1.0)
    return sobe * np.exp(-np.maximum(t - ataque, 0.0) / queda)


def janela(n: int, borda: float) -> np.ndarray:
    """Sobe e desce em cosseno nas pontas: sem clique no comeco nem no fim."""
    m = max(1, int(SR * borda))
    w = np.ones(n)
    rampa = 0.5 - 0.5 * np.cos(np.linspace(0.0, np.pi, m))
    w[:m] *= rampa
    w[-m:] *= rampa[::-1]
    return w


def pos(x: np.ndarray, som: np.ndarray, t0: float, ganho: float = 1.0) -> None:
    i = int(SR * t0)
    fim = min(len(x), i + len(som))
    if fim > i:
        x[i:fim] += ganho * som[: fim - i]


# --- golpe 1 ----------------------------------------------------------------

def susto_golpe() -> np.ndarray:
    dur = 1.8
    t = tempo(dur)
    n = len(t)
    # O grave que afunda: 58 Hz caindo a 31, saturado. E o chao sumindo.
    f = 58.0 * np.exp(-t * 0.9) + 31.0 * (1.0 - np.exp(-t * 0.9))
    fase = 2 * np.pi * np.cumsum(f) / SR
    grave = np.tanh(2.2 * np.sin(fase)) * envelope(n, 0.004, 0.75)
    # O cacho: sete agudos desafinados entre si por poucos Hz, com vibrato
    # rapido e desencontrado. Raspa, nao soa acorde.
    cacho = np.zeros(n)
    for k, base in enumerate([1740, 1790, 1861, 2230, 2291, 2604, 3120]):
        vib = 1.0 + 0.012 * np.sin(2 * np.pi * (6.3 + k * 0.7) * t + k)
        ph = 2 * np.pi * np.cumsum(base * vib * (1.0 + 0.04 * t)) / SR
        cacho += np.sign(np.sin(ph)) * 0.3 + np.sin(ph)
    cacho = passa_banda(cacho, 900, 6000) * envelope(n, 0.006, 0.42)
    # O estalo do comeco: trinta milissegundos de ruido cheio.
    estalo = ruido(n) * envelope(n, 0.001, 0.028)
    # Um sopro que continua depois do golpe, como ar sendo puxado.
    sopro = passa_banda(ruido(n), 200, 1400) * envelope(n, 0.05, 0.9) * 0.25
    x = 1.0 * grave + 0.34 * cacho + 0.6 * estalo + sopro
    return x * janela(n, 0.003)


# --- golpe 2 ----------------------------------------------------------------

def vidro_trinca() -> np.ndarray:
    dur = 0.9
    n = int(SR * dur)
    x = np.zeros(n)
    # A rachadura anda: uma cascata de estalos que acelera e perde forca.
    t0 = 0.0
    passo = 0.022
    forca = 1.0
    while t0 < 0.42:
        m = int(SR * 0.006)
        e = passa_banda(ruido(m), 2200, 9500) * np.exp(-np.arange(m) / (SR * 0.0016))
        pos(x, e, t0, forca)
        t0 += passo * rng.uniform(0.5, 1.4)
        passo = max(0.006, passo * 0.9)
        forca *= 0.93
    # O vidro soando por um instante: parciais inarmonicas curtas.
    t = tempo(dur)
    anel = sum(np.sin(2 * np.pi * fq * t) * a for fq, a in
               [(2140, 0.5), (3380, 0.35), (4710, 0.25), (6230, 0.15)])
    x += 0.22 * anel * envelope(n, 0.002, 0.16)
    return x * janela(n, 0.002)


def galhos_lataria() -> np.ndarray:
    dur = 1.3
    n = int(SR * dur)
    t = tempo(dur)
    # Raspar: ruido medio com a forca tremendo, como galho pulando na chapa.
    tremor = np.clip(0.55 + 0.45 * np.sin(2 * np.pi * 17 * t + 3 * np.sin(2 * np.pi * 3.1 * t)), 0, 1)
    raspa = passa_banda(ruido(n), 500, 3800) * tremor * envelope(n, 0.03, 0.6)
    x = 0.7 * raspa
    # Graveto quebrando: estalos secos espalhados.
    for _ in range(9):
        m = int(SR * 0.012)
        e = passa_banda(ruido(m), 1200, 7000) * np.exp(-np.arange(m) / (SR * 0.003))
        pos(x, e, rng.uniform(0.0, 0.9), rng.uniform(0.4, 1.0))
    # As folhas batendo no vidro: chiado largo e macio.
    x += 0.35 * passa_banda(ruido(n), 2500, 8000) * envelope(n, 0.08, 0.35)
    return x * janela(n, 0.004)


def motor_morre() -> np.ndarray:
    dur = 1.6
    n = int(SR * dur)
    t = tempo(dur)
    # O giro caindo de 38 explosoes por segundo a quase nada, com duas
    # engasgadas no meio: o motor tentando e nao pegando.
    giro = 38.0 * np.exp(-t * 2.2) + 3.0
    engasgo = 1.0 - 0.8 * (np.exp(-((t - 0.45) / 0.05) ** 2) + np.exp(-((t - 0.8) / 0.06) ** 2))
    fase = np.cumsum(giro) / SR
    pulso = (np.sin(2 * np.pi * fase) > 0.6).astype(float)
    corpo = passa_banda(pulso * ruido(n) * 0.6 + pulso, 40, 900)
    x = corpo * engasgo * envelope(n, 0.01, 0.7)
    # O ultimo suspiro: uma batida grave e o silencio.
    batida = np.sin(2 * np.pi * 52 * tempo(0.25)) * envelope(int(SR * 0.25), 0.003, 0.06)
    pos(x, batida, 1.05, 0.6)
    return x * janela(n, 0.004)


# --- o banco do passageiro --------------------------------------------------

def vibra_banco() -> np.ndarray:
    dur = 1.0
    n = int(SR * dur)
    t = tempo(dur)
    # Dois pulsos de vibracao, como o telefone faz, e o aparelho chacoalhando
    # contra o tecido do banco: zumbido de 168 Hz com o chiado do contato.
    liga = ((t > 0.02) & (t < 0.38)) | ((t > 0.55) & (t < 0.91))
    zum = np.sign(np.sin(2 * np.pi * 168 * t)) * 0.5 + np.sin(2 * np.pi * 336 * t) * 0.3
    chacoalha = passa_banda(ruido(n), 1500, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 42 * t))
    x = (passa_banda(zum, 60, 1200) + 0.25 * chacoalha) * liga
    return x * janela(n, 0.004)


def mensagem_enviada() -> np.ndarray:
    dur = 0.5
    n = int(SR * dur)
    t = tempo(dur)
    # O "fuuump" de mensagem saindo: ruido varrendo para cima e um tom que
    # sobe de quinta, curto. Todo mundo reconhece, e e so isso que importa.
    varre = np.zeros(n)
    for k in range(10):
        a = k / 10.0
        b = passa_banda(ruido(n), 300 + 3000 * a, 700 + 3600 * a)
        w = np.exp(-((t - 0.03 - a * 0.18) / 0.035) ** 2)
        varre += b * w
    tom_f = 880 * (1.0 + 0.5 * np.clip((t - 0.12) / 0.08, 0, 1))
    tom = np.sin(2 * np.pi * np.cumsum(tom_f) / SR) * envelope(n, 0.004, 0.09) * (t > 0.12)
    x = 0.8 * varre + 0.35 * tom
    return x * janela(n, 0.004)


# --- golpe 3 ----------------------------------------------------------------

def tapa_vidro() -> np.ndarray:
    dur = 0.6
    n = int(SR * dur)
    t = tempo(dur)
    # A palma: grave curto e surdo.
    palma = np.sin(2 * np.pi * 128 * t * (1 - 0.3 * t)) * envelope(n, 0.001, 0.035)
    palma += passa_banda(ruido(n), 80, 900) * envelope(n, 0.001, 0.02)
    # O vidro vibrando no caixilho: parciais baixas e o chocalho da borracha.
    anel = sum(np.sin(2 * np.pi * fq * t) * a for fq, a in [(612, 0.5), (1430, 0.3), (2290, 0.18)])
    chocalho = passa_banda(ruido(n), 2000, 6000) * envelope(n, 0.004, 0.05)
    x = 1.0 * palma + 0.3 * anel * envelope(n, 0.001, 0.09) + 0.25 * chocalho
    return x * janela(n, 0.002)


def sopro(dur: float, baixo: float, alto: float, ataque: float, queda: float,
          voz: float = 0.0, f0: float = 118.0) -> np.ndarray:
    n = int(SR * dur)
    t = tempo(dur)
    x = passa_banda(ruido(n), baixo, alto)
    if voz > 0.0:
        # Um fio de voz no fundo do ar: e o que separa respiracao de vento.
        x += voz * passa_banda(np.sign(np.sin(2 * np.pi * f0 * t)), 90, 1400)
    sobe = np.clip(t / ataque, 0, 1) ** 1.5
    desce = np.clip((dur - t) / queda, 0, 1) ** 1.2
    return x * sobe * desce


def respiracao_susto() -> np.ndarray:
    dur = 5.0
    x = np.zeros(int(SR * dur))
    # O arfar de quem levou o susto: um puxao de ar alto e agudo, e depois
    # ciclos curtos que vao espacando. Inspirar e mais agudo que expirar.
    pos(x, sopro(0.42, 900, 4200, 0.06, 0.12, voz=0.08, f0=210), 0.0, 1.0)
    t0 = 0.55
    ciclo = 0.52
    forca = 0.9
    while t0 < dur - 0.6:
        pos(x, sopro(ciclo * 0.42, 700, 3600, 0.05, 0.08, voz=0.05, f0=180), t0, forca)
        pos(x, sopro(ciclo * 0.55, 300, 2200, 0.04, 0.16, voz=0.12, f0=128),
            t0 + ciclo * 0.45, forca * 0.8)
        t0 += ciclo
        ciclo *= 1.07
        forca *= 0.97
    return x * janela(len(x), 0.01)


def respiracao_calma() -> np.ndarray:
    dur = 6.0
    x = np.zeros(int(SR * dur))
    # A outra respiracao. Lenta, funda, perto demais — e calma, que e o que
    # ela tem de errado.
    t0 = 0.1
    while t0 < dur - 2.2:
        pos(x, sopro(1.3, 180, 1500, 0.5, 0.4, voz=0.03, f0=96), t0, 0.8)
        pos(x, sopro(1.6, 120, 1100, 0.2, 0.9, voz=0.06, f0=88), t0 + 1.35, 0.9)
        t0 += 3.1
    return x * janela(len(x), 0.02)


def coracao_loop() -> np.ndarray:
    # 104 batidas por minuto: rapido o bastante para ser medo, lento o
    # bastante para cada batida ser ouvida inteira.
    dur = 60.0 / 104.0
    n = int(SR * dur)
    x = np.zeros(n)

    def batida(f0: float, q: float) -> np.ndarray:
        m = int(SR * 0.16)
        tt = np.arange(m) / SR
        return np.sin(2 * np.pi * f0 * tt * (1 - 0.4 * tt / 0.16)) * envelope(m, 0.004, q)

    pos(x, batida(58, 0.045), 0.0, 1.0)
    pos(x, batida(46, 0.05), 0.19, 0.7)
    return passa_banda(x, 25, 300)


def coro_baixo() -> np.ndarray:
    dur = 1.6
    n = int(SR * dur)
    t = tempo(dur)
    # Gente cantarolando de boca fechada, em cacho apertado e sem tonica
    # clara. Tres vozes, cada uma com um vibrato proprio e um pouco de ar.
    x = np.zeros(n)
    for f0, fase in [(110.0, 0.0), (130.8, 1.3), (155.6, 2.1), (164.8, 0.7)]:
        vib = 1.0 + 0.006 * np.sin(2 * np.pi * (4.7 + fase) * t + fase)
        ph = 2 * np.pi * np.cumsum(f0 * vib) / SR
        voz = sum(np.sin(k * ph) / k for k in range(1, 9))
        x += voz
    # Formante de "u": corta o brilho, fica a boca fechada.
    x = passa_banda(x, 80, 900) + 0.08 * passa_banda(ruido(n), 200, 1200)
    x *= np.clip(t / 0.25, 0, 1)
    return x * janela(n, 0.01)


def sorriso_abre() -> np.ndarray:
    """O sorriso do padre abrindo na janela: couro rangendo em estalos que
    apertam, o ar saindo por entre os dentes, um grave subindo por baixo e um
    fio agudo desafinado por cima. Nada disso e voz."""
    dur = 1.6
    n = int(SR * dur)
    t = tempo(dur)
    x = np.zeros(n)
    # Os estalos: intervalo de 70 ms caindo para 11, cada um uma ressonancia
    # curta de madeira molhada.
    agora = 0.08
    passo = 0.070
    while agora < dur - 0.1:
        k = agora / dur
        estalo = passa_banda(ruido(int(SR * 0.03)), 260 + 500 * k, 900 + 900 * k)
        estalo *= envelope(len(estalo), 0.0008, 0.006 + 0.004 * rng.random())
        pos(x, estalo, agora, 0.5 + 0.7 * k)
        agora += passo * (0.75 + 0.5 * rng.random())
        passo = max(0.011, passo * 0.9)
    # O ar entre os dentes.
    chiado = passa_banda(ruido(n), 2400, 6500) * np.clip((t - 0.3) / 1.1, 0, 1) ** 2
    x += 0.35 * chiado
    # O grave que sobe.
    f = 42.0 + 16.0 * (t / dur) ** 1.5
    x += 0.9 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.clip(t / 1.2, 0, 1)
    # O fio agudo: tres notas quase juntas, batendo.
    for f0 in (1760.0, 1864.7, 1975.5):
        vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.3 * t + f0)
        x += 0.05 * np.sin(2 * np.pi * np.cumsum(f0 * vib * (1 + 0.03 * t)) / SR) \
            * np.clip((t - 0.4) / 1.0, 0, 1)
    return x * janela(n, 0.01)


def sussurros() -> np.ndarray:
    """Muita gente sussurrando longe, sem palavra: ruido de fala em silabas que
    nao casam. Entra no vacuo, quando a chuva some."""
    dur = 3.4
    n = int(SR * dur)
    t = tempo(dur)
    x = np.zeros(n)
    for _ in range(7):
        # Silabas: 4 a 7 por segundo, com buracos, cada voz na sua fenda.
        ritmo = 4.0 + 3.0 * rng.random()
        fase = rng.random() * 6.28
        silabas = np.clip(np.sin(2 * np.pi * ritmo * t + fase)
                          + 0.6 * np.sin(2 * np.pi * ritmo * 0.37 * t + fase * 2), 0, None) ** 2
        centro = 1400 + 1600 * rng.random()
        voz = passa_banda(ruido(n), centro * 0.6, centro * 1.5)
        x += voz * silabas * (0.5 + 0.5 * rng.random())
    x *= np.clip(t / 1.2, 0, 1)
    return x * janela(n, 0.05)


def estalo_osso(semente: int) -> np.ndarray:
    """Um osso estalando: o pescoco do padre quebrando de lado, o cotovelo
    dobrando ao contrario. Tres camadas em quarenta milissegundos: o pop surdo da
    junta, um cacho de cliques secos (a cartilagem) e um triturar curto no meio.
    Nada de cauda: o estalo e o silencio logo depois."""
    r = np.random.default_rng(4100 + semente)
    dur = 0.22
    n = int(SR * dur)
    x = np.zeros(n)
    t0 = 0.004
    # O pop da junta: grave curto que cai de altura.
    m = int(SR * 0.07)
    tt = np.arange(m) / SR
    f0 = r.uniform(95, 150)
    pop = np.sin(2 * np.pi * f0 * tt * (1 - 2.5 * tt)) * envelope(m, 0.0006, 0.018)
    pos(x, pop, t0 + r.uniform(0.0, 0.01), 0.9)
    # Os cliques: tres a seis, cada vez mais juntos.
    agora = t0
    for _ in range(int(r.integers(3, 7))):
        c = int(SR * 0.004)
        clique = passa_banda(r.standard_normal(c), 1800, 9500) \
            * np.exp(-np.arange(c) / (SR * r.uniform(0.0004, 0.0011)))
        pos(x, clique, agora, r.uniform(0.5, 1.0))
        agora += r.uniform(0.003, 0.014)
    # O triturar: ruido medio com a forca pulsando rapido, como galho verde.
    m = int(SR * r.uniform(0.035, 0.07))
    tt = np.arange(m) / SR
    pulsa = np.clip(np.sin(2 * np.pi * r.uniform(120, 220) * tt), 0, None) ** 2
    tritura = passa_banda(r.standard_normal(m), 700, 3600) * pulsa * envelope(m, 0.002, 0.02)
    pos(x, tritura, t0 + 0.006, 0.55)
    return x * janela(n, 0.002)


def rangido_osso() -> np.ndarray:
    """O braco girando em volta de si mesmo: estalos de junta que aceleram,
    como madeira torcendo, com um grave de esforco por baixo."""
    dur = 0.55
    n = int(SR * dur)
    t = tempo(dur)
    x = np.zeros(n)
    agora = 0.01
    passo = 0.045
    while agora < dur - 0.06:
        k = agora / dur
        c = int(SR * 0.012)
        e = passa_banda(ruido(c), 400 + 900 * k, 2600 + 2400 * k) \
            * np.exp(-np.arange(c) / (SR * 0.0022))
        pos(x, e, agora, 0.45 + 0.55 * k)
        agora += passo * rng.uniform(0.6, 1.3)
        passo = max(0.008, passo * 0.82)
    grave = np.sin(2 * np.pi * np.cumsum(70 + 40 * t) / SR) * envelope(n, 0.05, 0.25)
    x += 0.35 * grave
    # O estalo final, mais forte.
    pos(x, estalo_osso(9), dur - 0.2, 0.9)
    return x * janela(n, 0.003)


def ofegante_esforco() -> np.ndarray:
    """Ele esticado atras do telefone no chao, preso no cinto: o ar entra e sai
    pela boca, rapido e curto, com a voz raspando no esforco ("hnn") a cada
    duas ou tres expiracoes, e o ritmo acelerando."""
    dur = 5.5
    x = np.zeros(int(SR * dur))
    t0 = 0.05
    ciclo = 0.50
    k = 0
    while t0 < dur - 0.5:
        # Inspira: agudo, puxado pela boca aberta.
        pos(x, sopro(ciclo * 0.38, 900, 4600, 0.03, 0.06, voz=0.04, f0=220), t0, 0.85)
        # Expira: mais grave, com voz; a cada tanto, o gemido do esforco.
        gemido = k % 3 == 2
        pos(x, sopro(ciclo * (0.58 if gemido else 0.5), 250, 2400, 0.02, 0.12,
                     voz=0.45 if gemido else 0.14, f0=112 if gemido else 135),
            t0 + ciclo * 0.42, 1.0 if gemido else 0.8)
        t0 += ciclo * rng.uniform(0.92, 1.08)
        ciclo = max(0.34, ciclo * 0.975)
        k += 1
    return x * janela(len(x), 0.02)


def mensagem_recebida() -> np.ndarray:
    dur = 0.55
    n = int(SR * dur)
    t = tempo(dur)
    # O aviso de mensagem chegando: tres notas de sino subindo, como o do
    # telefone — mas a terceira sai um quarto de tom baixa, e as tres batem
    # contra uma copia desafinada. Quem ouve reconhece, e estranha.
    x = np.zeros(n)
    for k, (fq, t0) in enumerate([(1318.5, 0.0), (1568.0, 0.11), (2034.0, 0.22)]):
        dentro = t >= t0
        tt = np.clip(t - t0, 0, None)
        env = np.exp(-tt / 0.16) * dentro * np.clip(tt / 0.003, 0, 1)
        sino = np.sin(2 * np.pi * fq * tt) + 0.35 * np.sin(2 * np.pi * fq * 2.76 * tt) * np.exp(-tt / 0.05)
        torto = np.sin(2 * np.pi * fq * 1.012 * tt)
        x += (sino + 0.45 * torto) * env
    return 0.45 * x * janela(n, 0.004)


def apoio_banco() -> np.ndarray:
    dur = 0.35
    n = int(SR * dur)
    t = tempo(dur)
    # A mao batendo espalmada no assento: o baque surdo da espuma, o estalo
    # curto do tecido e a mola do banco.
    baque = passa_banda(ruido(n), 60, 420) * envelope(n, 0.002, 0.05)
    baque += np.sin(2 * np.pi * 92 * t * (1 - 0.4 * t)) * envelope(n, 0.001, 0.06) * 0.8
    tecido = passa_banda(ruido(n), 1800, 5200) * envelope(n, 0.001, 0.018) * 0.35
    mola = np.sin(2 * np.pi * 310 * t) * np.exp(-t / 0.09) * 0.06 * (t > 0.01)
    return (1.1 * baque + tecido + mola) * janela(n, 0.003)


def main() -> int:
    gravar("susto_golpe", susto_golpe(), 0.95)
    gravar("vidro_trinca", vidro_trinca(), 0.8)
    gravar("galhos_lataria", galhos_lataria(), 0.75)
    gravar("motor_morre", motor_morre(), 0.8)
    gravar("vibra_banco", vibra_banco(), 0.6)
    gravar("mensagem_enviada", mensagem_enviada(), 0.7)
    gravar("tapa_vidro", tapa_vidro(), 0.95)
    gravar("respiracao_susto", respiracao_susto(), 0.8)
    gravar("respiracao_calma", respiracao_calma(), 0.6)
    gravar("coracao_loop", coracao_loop(), 0.9)
    gravar("coro_baixo", coro_baixo(), 0.6)
    gravar("sorriso_abre", sorriso_abre(), 0.85)
    gravar("sussurros", sussurros(), 0.5)
    # Os novos vem por ultimo: o sorteio global anda na ordem, e um som novo no
    # comeco regravaria todos os de baixo com outro ruido.
    for i in range(4):
        gravar(f"estalo_osso_{i + 1}", estalo_osso(i), 0.95)
    gravar("rangido_osso", rangido_osso(), 0.9)
    gravar("ofegante_esforco", ofegante_esforco(), 0.8)
    gravar("mensagem_recebida", mensagem_recebida(), 0.7)
    gravar("apoio_banco", apoio_banco(), 0.85)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
