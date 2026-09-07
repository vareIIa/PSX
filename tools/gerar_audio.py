#!/usr/bin/env python3
"""Gera o banco de sons do jogo por sintese.

O artigo de referencia e explicito: o que faz o Silent Hill assustar e o som, nao
a imagem. Chiado de radio, sirene, passo, chuva. Quase tudo isso e ruido filtrado
com envelope, que da para sintetizar sem gravar nada e sem depender de banco de
som de terceiro.

Formato do ART-BIBLE secao 11: 22.050 Hz, mono, 16 bits.

    python tools/gerar_audio.py
"""

import struct
import wave
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parent.parent
SAIDA = RAIZ / "game" / "assets" / "audio"
SR = 22050

rng = np.random.default_rng(1995)


def gravar(nome: str, x: np.ndarray, ganho: float = 0.9) -> None:
    pico = float(np.max(np.abs(x))) or 1.0
    y = np.clip(x / pico * ganho, -1.0, 1.0)
    dados = (y * 32767.0).astype("<i2")
    SAIDA.mkdir(parents=True, exist_ok=True)
    caminho = SAIDA / f"{nome}.wav"
    with wave.open(str(caminho), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())
    print(f"{nome:22s} {len(y) / SR:5.2f} s")


def ruido(dur: float) -> np.ndarray:
    return rng.standard_normal(int(SR * dur))


def passa_banda(x: np.ndarray, baixo: float, alto: float) -> np.ndarray:
    """Filtro por FFT. Nao e o mais eficiente, mas e exato e cabe em cinco
    linhas, o que importa mais num script que roda uma vez."""
    espectro = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    espectro[(freqs < baixo) | (freqs > alto)] = 0.0
    return np.fft.irfft(espectro, n=len(x))


def envelope(n: int, ataque: float, decaimento: float) -> np.ndarray:
    a = max(1, int(n * ataque))
    d = max(1, n - a)
    return np.concatenate([
        np.linspace(0.0, 1.0, a),
        np.exp(-np.linspace(0.0, 6.0, d)) ** decaimento,
    ])[:n]


def emenda_para_loop(x: np.ndarray, ms: float = 60.0) -> np.ndarray:
    """Cruza o fim com o comeco para o loop nao estalar."""
    n = int(SR * ms / 1000.0)
    if n * 2 >= len(x):
        return x
    rampa = np.linspace(0.0, 1.0, n)
    y = x.copy()
    y[:n] = x[:n] * rampa + x[-n:] * (1.0 - rampa)
    return y[:-n]


# --- radio ------------------------------------------------------------------

def estatica() -> None:
    """Chiado de radio. ART-BIBLE secao 11 manda passa-banda de 300 Hz a 3 kHz,
    que e exatamente a faixa de um alto-falante ruim de radio portatil."""
    x = passa_banda(ruido(4.0), 300.0, 3000.0)
    # Ondulacao lenta de amplitude: chiado plano soa como ruido de fita, nao
    # como radio fora de estacao.
    t = np.arange(len(x)) / SR
    x *= 1.0 + 0.35 * np.sin(2 * np.pi * 0.7 * t) + 0.2 * np.sin(2 * np.pi * 2.3 * t)
    gravar("estatica", emenda_para_loop(x))


def interferencia() -> None:
    """Estalos e picos. Entra por cima do chiado quando o inimigo chega perto."""
    n = int(SR * 3.0)
    x = passa_banda(rng.standard_normal(n), 800.0, 5000.0) * 0.25
    for _ in range(26):
        i = rng.integers(0, n - 900)
        comp = int(rng.integers(120, 800))
        x[i:i + comp] += passa_banda(rng.standard_normal(comp), 1200.0, 6000.0) \
            * envelope(comp, 0.02, 1.4) * rng.uniform(0.8, 2.2)
    gravar("interferencia", emenda_para_loop(x))


# --- ambiente ---------------------------------------------------------------

def chuva() -> None:
    x = passa_banda(ruido(6.0), 700.0, 8000.0)
    t = np.arange(len(x)) / SR
    x *= 1.0 + 0.18 * np.sin(2 * np.pi * 0.23 * t)
    gravar("chuva_loop", emenda_para_loop(x, 200.0), 0.7)


def vento() -> None:
    x = passa_banda(ruido(8.0), 60.0, 700.0)
    t = np.arange(len(x)) / SR
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * 0.11 * t + 1.2)
    gravar("vento_loop", emenda_para_loop(x, 300.0), 0.6)


def zumbido() -> None:
    """Drone grave de tensao. Duas ondas quase na mesma frequencia batendo uma
    contra a outra: e o batimento que da a sensacao de desconforto."""
    t = np.arange(int(SR * 8.0)) / SR
    x = (np.sin(2 * np.pi * 47.0 * t) + np.sin(2 * np.pi * 48.7 * t) * 0.8
         + np.sin(2 * np.pi * 94.0 * t) * 0.25)
    x += passa_banda(rng.standard_normal(len(t)), 40.0, 220.0) * 0.12
    gravar("zumbido_loop", emenda_para_loop(x, 250.0), 0.55)


def sirene() -> None:
    """A sirene do Silent Hill. Varredura lenta, com uma segunda voz desafinada
    por cima: afinada demais soa como alarme de fabrica, nao como aviso."""
    dur = 9.0
    t = np.arange(int(SR * dur)) / SR
    base = 300.0 + 210.0 * np.sin(2 * np.pi * 0.16 * t - np.pi / 2)
    fase = 2 * np.pi * np.cumsum(base) / SR
    x = np.sin(fase) + 0.55 * np.sin(fase * 1.007 + 0.6) + 0.3 * np.sin(fase * 2.0)
    env = np.clip(np.minimum(t / 1.5, (dur - t) / 2.0), 0.0, 1.0)
    gravar("sirene", x * env)


# --- passos -----------------------------------------------------------------

def passos() -> None:
    perfis = {
        "concreto": (240.0, 2600.0, 0.11, 1.5),
        "madeira": (150.0, 1500.0, 0.16, 1.0),
        "metal": (400.0, 6000.0, 0.20, 0.7),
        "terra": (120.0, 900.0, 0.13, 1.9),
    }
    for nome, (baixo, alto, dur, dec) in perfis.items():
        for k in range(4):
            n = int(SR * dur * rng.uniform(0.85, 1.15))
            x = passa_banda(rng.standard_normal(n), baixo * rng.uniform(0.9, 1.1),
                            alto * rng.uniform(0.85, 1.15))
            x *= envelope(n, 0.01, dec)
            gravar(f"passo_{nome}_{k + 1}", x, 0.75)


# --- interface e objetos ----------------------------------------------------

def diversos() -> None:
    # Clique seco de menu
    n = int(SR * 0.05)
    gravar("clique", passa_banda(rng.standard_normal(n), 1400.0, 6000.0)
           * envelope(n, 0.005, 2.5), 0.6)

    # Pegar item: dois estalos curtos, como papel e metal juntos
    n = int(SR * 0.22)
    x = passa_banda(rng.standard_normal(n), 600.0, 5000.0) * envelope(n, 0.01, 1.6)
    i = int(SR * 0.07)
    x[i:] += (passa_banda(rng.standard_normal(n - i), 1800.0, 8000.0)
              * envelope(n - i, 0.01, 2.2) * 0.7)
    gravar("pegar", x, 0.7)

    # Porta velha: rangido por modulacao lenta de ruido de banda estreita
    n = int(SR * 1.3)
    t = np.arange(n) / SR
    base = passa_banda(rng.standard_normal(n), 300.0, 1800.0)
    x = base * (0.35 + 0.65 * np.abs(np.sin(2 * np.pi * 5.5 * t + np.sin(t * 3.0))))
    x *= np.clip(np.minimum(t / 0.1, (1.3 - t) / 0.4), 0.0, 1.0)
    gravar("porta_abre", x, 0.65)

    # Lanterna: clique de interruptor
    n = int(SR * 0.09)
    x = passa_banda(rng.standard_normal(n), 900.0, 4500.0) * envelope(n, 0.004, 3.0)
    gravar("interruptor", x, 0.65)

    # Tiro: estouro grave com cauda
    n = int(SR * 0.55)
    x = (passa_banda(rng.standard_normal(n), 60.0, 900.0) * envelope(n, 0.002, 1.2) * 1.6
         + passa_banda(rng.standard_normal(n), 1000.0, 9000.0) * envelope(n, 0.001, 3.5))
    gravar("tiro", x)

    # Respiracao ofegante, para folego no fim
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    x = passa_banda(rng.standard_normal(n), 200.0, 1600.0)
    x *= np.abs(np.sin(2 * np.pi * 1.1 * t)) ** 2
    gravar("ofegante", x, 0.5)

    # Trinco: o estalo curto de maçaneta antes de a folha girar. Existe para a
    # porta ter dois tempos. Folha que sai girando sozinha nao tem peso; folha
    # que estala e so depois cede parece ter alguem empurrando.
    n = int(SR * 0.14)
    x = passa_banda(rng.standard_normal(n), 1200.0, 7000.0) * envelope(n, 0.002, 4.0)
    i = int(SR * 0.045)
    x[i:] += (passa_banda(rng.standard_normal(n - i), 400.0, 2600.0)
              * envelope(n - i, 0.003, 3.0) * 0.8)
    gravar("porta_trinco", x, 0.6)

    # Porta trancada: a maçaneta bate no fim do curso duas vezes e para. Grave e
    # sem cauda, o oposto do rangido: a porta nao vai abrir e o som diz isso.
    n = int(SR * 0.5)
    x = np.zeros(n)
    for atraso in (0.0, 0.16):
        i = int(SR * atraso)
        m = n - i
        x[i:] += (passa_banda(rng.standard_normal(m), 180.0, 1400.0)
                  * envelope(m, 0.002, 9.0))
    gravar("porta_trava", x, 0.7)

    # Porta automatica de loja: motorzinho subindo, o corre do trilho e o toque
    # no fim do curso. Tres tempos, como a porta de dobradica, so que rapido.
    n = int(SR * 0.62)
    t = np.arange(n) / SR
    motor = passa_banda(rng.standard_normal(n), 240.0, 900.0)
    motor *= np.clip(np.minimum(t / 0.06, (0.52 - t) / 0.12), 0.0, 1.0)
    # A frequencia do trilho sobe e cai junto com o movimento.
    trilho = passa_banda(rng.standard_normal(n), 1600.0, 6000.0)
    trilho *= np.clip(np.sin(np.pi * np.clip(t / 0.52, 0, 1)), 0, 1) ** 2 * 0.5
    x = motor + trilho
    i = int(SR * 0.5)
    x[i:] += (passa_banda(rng.standard_normal(n - i), 150.0, 1200.0)
              * envelope(n - i, 0.002, 7.0) * 0.9)
    gravar("porta_desliza", x, 0.6)


def transito() -> None:
    """Motor, buzina e porta de carro.

    O motor e UM loop de dois segundos, e nao um banco de rotacoes. Quem produz
    a rotacao e a afinacao em tempo de execucao (ver MotorSom): gravar uma
    amostra por faixa de giro seria meia duzia de arquivos para uma diferenca
    que o pitch ja da, e a troca de marcha — que e o que o ouvido realmente
    reconhece — nao esta no timbre, esta no salto.

    O timbre e uma serie harmonica com as ordens PARES reforcadas, que e o que
    da o ronco de quatro cilindros; so as impares dariam um zumbido de motor
    eletrico. A modulacao lenta por cima e a irregularidade da explosao, sem a
    qual o loop denuncia que e um loop no terceiro segundo.
    """
    dur = 2.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    f0 = 46.0
    x = np.zeros(n)
    for k in range(1, 13):
        # Ordens pares mais fortes, e o ganho caindo com a ordem.
        peso = (1.0 / k) * (1.5 if k % 2 == 0 else 0.55)
        fase = rng.uniform(0, 2 * np.pi)
        x += np.sin(2 * np.pi * f0 * k * t + fase) * peso
    # A explosao nao e perfeitamente regular: a modulacao lenta e o que separa
    # motor de orgao eletronico.
    x *= 0.82 + 0.18 * np.sin(2 * np.pi * 7.3 * t + np.sin(t * 2.1))
    x += passa_banda(rng.standard_normal(n), 300.0, 3000.0) * 0.16
    gravar("motor_loop", emenda_para_loop(x, 80.0), 0.75)

    # Partida: o arranque raspando e o motor pegando. Dois tempos — sem o
    # segundo, ligar o carro soa como uma chave girando no vazio.
    n = int(SR * 1.05)
    t = np.arange(n) / SR
    arranque = passa_banda(rng.standard_normal(n), 200.0, 1800.0)
    arranque *= (0.5 + 0.5 * np.sin(2 * np.pi * 11.0 * t)) * np.clip(
        (0.62 - t) / 0.62, 0.0, 1.0)
    # A rotacao sobe do arranque ate a marcha lenta.
    sobe = np.clip((t - 0.5) / 0.4, 0.0, 1.0)
    fase = 2 * np.pi * np.cumsum(28.0 + 20.0 * sobe) / SR
    pega = (np.sin(fase) + 0.6 * np.sin(2 * fase)) * sobe
    gravar("motor_partida", arranque * 0.8 + pega * 0.9, 0.7)

    # Troca de marcha: a batida surda do cambio engatando. Curta e grave; o que
    # se ouve de fora do carro e o tranco, nao a engrenagem.
    n = int(SR * 0.17)
    x = passa_banda(rng.standard_normal(n), 70.0, 700.0) * envelope(n, 0.002, 6.0)
    gravar("motor_marcha", x, 0.55)

    # Buzina. Duas notas juntas, uma quinta apart — e o que toda buzina de carro
    # de rua e, e uma nota so sai como apito de trem.
    def buzina(dur: float, nome: str) -> None:
        n = int(SR * dur)
        t = np.arange(n) / SR
        x = (np.sin(2 * np.pi * 405.0 * t) + 0.8 * np.sin(2 * np.pi * 607.0 * t)
             + 0.35 * np.sin(2 * np.pi * 1214.0 * t))
        # Ataque e corte rapidos, sem cauda: buzina nao tem reverberacao propria.
        env = np.clip(np.minimum(t / 0.02, (dur - t) / 0.05), 0.0, 1.0)
        gravar(nome, x * env, 0.72)

    buzina(0.28, "buzina_curta")
    buzina(1.25, "buzina_longa")

    # Porta de carro: o baque da chapa e o estalo do trinco. Mais seca que a
    # porta de casa, que tem rangido de dobradica velha; carro nao range.
    n = int(SR * 0.34)
    x = passa_banda(rng.standard_normal(n), 90.0, 900.0) * envelope(n, 0.002, 5.0)
    i = int(SR * 0.06)
    x[i:] += (passa_banda(rng.standard_normal(n - i), 1400.0, 7000.0)
              * envelope(n - i, 0.002, 6.0) * 0.5)
    gravar("porta_carro", x, 0.65)

    # Passo da roleta de radio: bipe curtissimo, quase um tique.
    n = int(SR * 0.035)
    t = np.arange(n) / SR
    gravar("bipe_curto", np.sin(2 * np.pi * 1750.0 * t) * envelope(n, 0.01, 3.0), 0.5)

    # Troca de estacao: o estalo do botao mais um respingo de estatica, que e o
    # que um radio de verdade faz ao pular de frequencia.
    n = int(SR * 0.26)
    x = passa_banda(rng.standard_normal(n), 1000.0, 5000.0) * envelope(n, 0.003, 4.0)
    i = int(SR * 0.05)
    x[i:] += passa_banda(rng.standard_normal(n - i), 2000.0, 9000.0) * np.clip(
        (0.16 - np.arange(n - i) / SR) / 0.16, 0.0, 1.0) * 0.55
    gravar("radio_click", x, 0.6)


def casa_fumaca() -> None:
    """A batida que sai da caixa de som da sala.

    O que isto e, e o que nao e
    ---------------------------
    E uma batida ORIGINAL no padrao do funk carioca — o tamborzao, que e um
    ritmo de genero e nao a composicao de ninguem: bumbo no tempo, a celula de
    tres-tres-dois nos tambores, chimbal em semicolcheia. Sintetizada aqui, do
    zero, como todo som deste jogo.
    
    NAO e a musica que a cena homenageia. A melodia e a letra daquela faixa sao
    de quem as fez, e recriar as duas seria copiar, nao referenciar. O que a
    sala precisa e do ANDAMENTO e do timbre certos — a coisa que o ouvido
    reconhece atravessando a parede antes de entender qualquer palavra — e isso
    o ritmo entrega sozinho.

    Quem quiser a faixa de verdade larga o MP3 em `user://musica/casa/`, e a
    casa toca ela no lugar desta. O caminho ja existe e esta documentado na
    Televisao.
    """
    bpm = 130.0
    batida = 60.0 / bpm
    compassos = 2
    dur = batida * 4.0 * compassos
    n = int(SR * dur)
    x = np.zeros(n)
    t = np.arange(n) / SR

    def por(inicio: float, som: np.ndarray, ganho: float = 1.0) -> None:
        i = int(SR * inicio)
        m = min(len(som), n - i)
        if m > 0:
            x[i:i + m] += som[:m] * ganho

    def bumbo(dur_s: float = 0.32) -> np.ndarray:
        m = int(SR * dur_s)
        tt = np.arange(m) / SR
        # A altura despenca de 120 para 45 Hz nos primeiros cinquenta
        # milissegundos. E o mergulho que faz o bumbo ter peso em vez de tum.
        f = 45.0 + 75.0 * np.exp(-tt * 34.0)
        env = np.exp(-tt * 11.0)
        return np.sin(2 * np.pi * np.cumsum(f) / SR) * env

    def tambor(altura: float, dur_s: float = 0.19) -> np.ndarray:
        m = int(SR * dur_s)
        tt = np.arange(m) / SR
        env = np.exp(-tt * 19.0)
        pele = np.sin(2 * np.pi * altura * np.exp(-tt * 6.0) * tt * 4.0) * env
        estalo = passa_banda(rng.standard_normal(m), 800.0, 5200.0) * np.exp(-tt * 42.0)
        return pele * 0.85 + estalo * 0.5

    def chimbal(aberto: bool = False) -> np.ndarray:
        m = int(SR * (0.14 if aberto else 0.045))
        tt = np.arange(m) / SR
        return (passa_banda(rng.standard_normal(m), 6000.0, 10500.0)
                * np.exp(-tt * (11.0 if aberto else 46.0)))

    semi = batida / 4.0
    for c in range(compassos):
        base = c * batida * 4.0
        # Bumbo nos tempos 1 e 3, com a antecipacao no "e" do 4 no segundo
        # compasso: e o empurrao que faz a volta do loop nao soar como emenda.
        por(base, bumbo(), 1.0)
        por(base + batida * 2.0, bumbo(), 0.92)
        if c == compassos - 1:
            por(base + batida * 3.5, bumbo(0.22), 0.7)

        # Tamborzao: a celula de tres-tres-dois em semicolcheias, que e a
        # assinatura do genero. Alturas alternadas entre grave e agudo dao a
        # conversa entre os dois tambores.
        for k, passo in enumerate([0, 3, 6, 8, 11, 14]):
            grave = k % 2 == 0
            por(base + semi * passo, tambor(148.0 if grave else 232.0),
                0.85 if grave else 0.62)

        # Chimbal em toda semicolcheia, com o aberto no fim do compasso.
        for k in range(16):
            if k == 14:
                por(base + semi * k, chimbal(True), 0.30)
            else:
                por(base + semi * k, chimbal(), 0.16 if k % 2 else 0.24)

    _ = t
    gravar("funk_batida", emenda_para_loop(x, 40.0), 0.82)

    # O grito da sala: gente falando junto por cima da batida. Sem palavra, como
    # toda voz deste jogo — o que identifica nao e o texto, e a massa de vozes
    # num comodo pequeno.
    m = int(SR * 1.1)
    tt = np.arange(m) / SR
    vozes = np.zeros(m)
    for f0 in (108.0, 132.0, 164.0, 196.0):
        formante = passa_banda(rng.standard_normal(m), f0 * 3.0, f0 * 9.0)
        vozes += np.sin(2 * np.pi * f0 * tt) * 0.4 + formante * 0.5
    vozes *= np.clip(np.minimum(tt / 0.05, (1.1 - tt) / 0.35), 0.0, 1.0)
    vozes *= 0.7 + 0.3 * np.sin(2 * np.pi * 5.5 * tt)
    gravar("casa_grito", vozes, 0.55)

    # Chiado do tubo: o assobio de linha de uma TV de tubo ligada. Quinze
    # quilohertz e inaudivel para muita gente e presente para quem escuta, que e
    # exatamente o efeito de estar perto de uma TV velha.
    m = int(SR * 2.0)
    tt = np.arange(m) / SR
    tubo = (np.sin(2 * np.pi * 7860.0 * tt) * 0.5
            + passa_banda(rng.standard_normal(m), 2000.0, 9000.0) * 0.25)
    gravar("tv_chiado", emenda_para_loop(tubo, 50.0), 0.30)


def risadas() -> None:
    """A risada de quem esta chapado.

    E feita das mesmas silabas da Voz, e nao de uma gravacao: uma risada
    gravada repetindo em seis pessoas na mesma sala denuncia o loop em quinze
    segundos, e o banco de vozes deste jogo ja existe justamente para nao
    precisar de gravacao por linha.

    O que faz soar como risada e a FORMA, e nao o timbre. Tres coisas:

      a cadencia acelera        as silabas comecam espacadas e vao se juntando
      a altura cai              cada silaba comeca mais grave que a anterior
      a ultima e mais longa     e o ar acabando, e e o que fecha o gesto

    Uma risada de metrica constante soa como tosse. Foi a primeira que saiu.
    """
    for banco, f0_base in (("m", 118.0), ("f", 196.0)):
        for variante in (1, 2):
            rng_local = np.random.default_rng(4200 + variante + (0 if banco == "m" else 9))
            silabas = 5 + variante
            partes = []
            espaco = 0.20
            for k in range(silabas):
                ultima = k == silabas - 1
                # A altura desce por silaba: e o ar saindo.
                f0 = f0_base * (1.0 - 0.06 * k) * float(rng_local.uniform(0.96, 1.05))
                dur = 0.20 if ultima else float(rng_local.uniform(0.085, 0.12))
                vogal = "a" if k % 2 == 0 else ("e" if variante == 1 else "o")
                s = silaba(f0, vogal, dur, -0.12 if ultima else 0.04, "h")
                partes.append(s)
                if not ultima:
                    partes.append(np.zeros(int(SR * espaco)))
                # E acelera: cada intervalo e menor que o anterior.
                espaco = max(0.055, espaco * 0.78)
            x = np.concatenate(partes)
            # Um sopro de ar por cima de tudo, que e o que separa riso de fala.
            ar = passa_banda(rng.standard_normal(len(x)), 900.0, 4200.0)
            env = np.abs(x) / (np.max(np.abs(x)) or 1.0)
            gravar(f"risada_{banco}_{variante}", x + ar * env * 0.35, 0.7)


def folhas() -> None:
    """Folha ao vento. E o mesmo material do vento — ruido filtrado — mas com a
    banda deslocada para o agudo e a modulacao muito mais rapida.

    A diferenca entre "vento" e "folha ao vento" esta toda na modulacao. Vento e
    uma respiracao de dez segundos; folha e um chiado que sobe e desce em menos
    de dois, porque cada rajada agita a copa inteira de uma vez. Sem a modulacao
    rapida por cima da lenta, isto vira ruido rosa e o jogador nao ouve arvore
    nenhuma.

    A rajada lenta usa 0.21 Hz, que e a mesma constante do psx_surface: o som
    engrossa no quadro em que a copa esta no auge do balanco."""
    x = passa_banda(ruido(9.0), 900.0, 6500.0)
    t = np.arange(len(x)) / SR
    rapida = 0.55 + 0.45 * np.sin(2 * np.pi * 0.63 * t + 0.4)
    lenta = 0.65 + 0.35 * np.sin(2 * np.pi * 0.21 * t)
    x *= rapida * lenta
    # Estalos esparsos: galho seco tocando galho seco.
    for _ in range(14):
        i = int(rng.integers(0, len(x) - SR // 4))
        n = SR // 22
        x[i:i + n] += (passa_banda(rng.standard_normal(n), 1800.0, 7000.0)
                       * envelope(n, 0.004, 5.0) * 0.5)
    gravar("folhas_loop", emenda_para_loop(x, 260.0), 0.55)


def grilo() -> None:
    """Grilo: tres a cinco pulsos curtos de tom quase puro, com harmonico.

    Grilo de verdade e uma serie de pulsos, nao um tom continuo. Sao os pulsos
    que o ouvido reconhece; um seno de 4 kHz sustentado soa como alarme."""
    freq = 4300.0
    pulso = int(SR * 0.016)
    silencio = int(SR * 0.028)
    partes = []
    for _ in range(4):
        t = np.arange(pulso) / SR
        p = (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2 * t))
        partes.append(p * envelope(pulso, 0.15, 1.6))
        partes.append(np.zeros(silencio))
    x = np.concatenate(partes)
    x += passa_banda(rng.standard_normal(len(x)), 3000.0, 8000.0) * 0.05
    gravar("grilo", x, 0.5)


# --- voz --------------------------------------------------------------------

# Formantes das cinco vogais, em Hz. Sao as duas ou tres ressonancias que o
# trato vocal poe por cima do zumbido da laringe, e sao elas — nao a altura da
# nota — que fazem o ouvido reconhecer um "a" e nao um "u".
VOGAIS = {
    "a": (730.0, 1090.0, 2440.0),
    "e": (530.0, 1840.0, 2480.0),
    "i": (270.0, 2290.0, 3010.0),
    "o": (570.0, 840.0, 2410.0),
    "u": (300.0, 870.0, 2240.0),
}


def silaba(f0: float, vogal: str, dur: float, glide: float,
           ataque: str) -> np.ndarray:
    """Uma silaba sem lingua nenhuma.

    Sintese aditiva: harmonicos de f0 com amplitude dada pela envoltoria de
    formantes. Nao e a maneira mais fiel de sintetizar voz, e a mais barata que
    ainda soa como boca — que e o que interessa, porque a fala aqui NAO pode ser
    entendida. O texto esta escrito na tela; a voz so precisa dizer que aquilo
    sai de uma pessoa, com a idade e o tamanho daquela pessoa.

    `glide` inclina a frequencia ao longo da silaba. E o que separa pergunta de
    afirmacao sem uma palavra sequer.
    """
    n = int(SR * dur)
    t = np.arange(n) / SR
    f1, f2, f3 = VOGAIS[vogal]
    freq = f0 * (1.0 + glide * (t / max(dur, 1e-3)))
    fase = 2 * np.pi * np.cumsum(freq) / SR

    x = np.zeros(n)
    h = 1
    while h * f0 < 5200.0:
        fh = h * f0
        # Envoltoria de formante: tres sinos somados. A queda de 6 dB por oitava
        # e a inclinacao natural da fonte glotal; sem ela a voz sai metalica.
        amp = 0.0
        for fc, larg, peso in ((f1, 110.0, 1.0), (f2, 150.0, 0.55), (f3, 220.0, 0.22)):
            amp += peso * np.exp(-((fh - fc) / larg) ** 2)
        amp *= 1.0 / (1.0 + (fh / 500.0) ** 1.2)
        if amp > 0.002:
            x += amp * np.sin(fase * h)
        h += 1

    env = np.minimum(1.0, np.linspace(0.0, 3.0, n)) * np.exp(-np.linspace(0.0, 2.6, n))
    x *= env

    # Ataque consonantal. Sem ele as silabas emendam num zumbido continuo e a
    # voz vira serra eletrica; com ele o ouvido ouve articulacao.
    if ataque != "":
        na = int(SR * 0.022)
        if ataque == "surdo":
            golpe = passa_banda(rng.standard_normal(na), 2200.0, 7000.0) * 0.5
        else:
            golpe = passa_banda(rng.standard_normal(na), 120.0, 900.0) * 0.7
        x[:na] += golpe * envelope(na, 0.05, 3.0)
    return x


def vozes() -> None:
    """Dois bancos de oito silabas. O jogo escolhe o banco pelo sexo da ficha e
    a afinacao pela altura da pessoa, entao dezesseis arquivos cobrem a cidade
    inteira sem duas pessoas soarem iguais."""
    receita = [
        ("a", 0.15, 0.00, "surdo"), ("e", 0.13, 0.06, ""),
        ("o", 0.17, -0.05, "sonoro"), ("i", 0.12, 0.10, "surdo"),
        ("u", 0.16, -0.08, "sonoro"), ("a", 0.11, 0.12, ""),
        ("e", 0.18, -0.10, "sonoro"), ("o", 0.13, 0.04, "surdo"),
    ]
    for banco, f0 in (("m", 112.0), ("f", 196.0)):
        for i, (vogal, dur, glide, ataque) in enumerate(receita, start=1):
            x = silaba(f0 * (0.94 + 0.03 * (i % 4)), vogal, dur, glide, ataque)
            gravar("voz_%s_%d" % (banco, i), x, 0.72)


# --- celular ----------------------------------------------------------------

def bipe(freq: float, dur: float, quadrada: bool = True) -> np.ndarray:
    t = np.arange(int(SR * dur)) / SR
    onda = np.sign(np.sin(2 * np.pi * freq * t)) if quadrada else np.sin(2 * np.pi * freq * t)
    # Passa-baixa curto para tirar o brilho de onda quadrada pura, que num
    # aparelho de 1998 vinha de um alto-falante de dois centimetros.
    return passa_banda(onda, 60.0, 3400.0) * envelope(len(t), 0.03, 2.2)


def celular() -> None:
    """Sons do aparelho. Tudo em onda quadrada filtrada: e o que um telefone da
    epoca tinha, e a diferenca entre isso e um bipe limpo e a diferenca entre o
    aparelho existir no mundo e ser uma janela flutuando na tela."""
    gravar("celular_abre", np.concatenate([bipe(660.0, 0.05), bipe(990.0, 0.09)]), 0.5)
    gravar("celular_tecla", bipe(1240.0, 0.035), 0.4)
    gravar("celular_ok", np.concatenate([bipe(880.0, 0.06), np.zeros(int(SR * 0.02)),
                                         bipe(1320.0, 0.11)]), 0.5)
    gravar("celular_erro", np.concatenate([bipe(320.0, 0.09), np.zeros(int(SR * 0.03)),
                                           bipe(240.0, 0.16)]), 0.5)
    # Folha de papel virando: o documento saindo do bolso.
    x = passa_banda(rng.standard_normal(int(SR * 0.42)), 900.0, 6000.0)
    env = np.exp(-np.linspace(0.0, 5.0, len(x))) * (0.5 + 0.5 * np.sin(
        np.linspace(0.0, 9.0, len(x))))
    gravar("papel", x * env, 0.42)


def main() -> int:
    estatica()
    interferencia()
    chuva()
    vento()
    zumbido()
    sirene()
    folhas()
    grilo()
    passos()
    diversos()
    vozes()
    celular()
    transito()
    casa_fumaca()
    risadas()
    n = len(list(SAIDA.glob("*.wav")))
    print(f"\n{n} sons em {SAIDA.relative_to(RAIZ)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
