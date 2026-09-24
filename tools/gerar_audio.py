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
    """Aguaceiro continuo, feito para NAO se reconhecer.

    Um loop so entrega que e loop quando tem dentro dele algo que se possa
    reconhecer voltando. A primeira versao tinha as duas coisas: seis segundos
    de ruido com uma ondulacao de 0,23 Hz por cima — uma pulsacao de 4,3 s que
    nao cabia inteira no arquivo, entao ela batia contra a emenda e produzia um
    "vum-vum" que o ouvido decorava em meio minuto e nao conseguia mais ignorar.

    Aqui sao catorze segundos de ruido sem nenhum evento: nada de estalo, nada
    de gota isolada, nada que se possa marcar. E as tres bandas sao filtradas
    por FFT, que e convolucao CIRCULAR — o fim do buffer ja continua no comeco
    por construcao, entao nao ha emenda nenhuma para estalar e o loop nao tem
    costura. As modulacoes que sobraram sao fracas e tem numero INTEIRO de
    ciclos no buffer, pelo mesmo motivo.

    A variacao que se ouve nao esta no arquivo: e a Chuva quem move o volume,
    com duas ondas lentas de periodo primo entre si. Chuva que aperta e afrouxa
    e o que faz o loop desaparecer.

    O gerador e proprio, e nao o global: assim o arquivo nao depende de quem
    rodou antes dele, e mexer aqui nao troca o ruido de todos os sons seguintes.
    """
    local = np.random.default_rng(1995 + 314)
    dur = 14.0
    n = int(SR * dur)
    t = np.arange(n) / SR

    # Tres bandas, cada uma com o seu ruido. A agulha e o que se ouve batendo no
    # asfalto; o corpo e a massa da chuva a distancia; o fundo e o que faz ela
    # ter peso em vez de soar como chiado de fita.
    agulha = passa_banda(local.standard_normal(n), 1800.0, 8000.0)
    corpo = passa_banda(local.standard_normal(n), 400.0, 1800.0)
    fundo = passa_banda(local.standard_normal(n), 90.0, 400.0)
    x = agulha * 0.90 + corpo * 0.50 + fundo * 0.16

    # Respiracao de fundo, presa ao loop: 3, 7 e 11 ciclos no buffer. Fraca de
    # proposito — e so para o ruido nao ficar chapado como estatica.
    for ciclos, amp, fase in ((3, 0.055, 0.0), (7, 0.035, 2.1), (11, 0.02, 4.2)):
        x = x * (1.0 + amp * np.sin(2 * np.pi * ciclos * t / dur + fase))

    # Sem emenda_para_loop: a FFT ja devolve um sinal circular, e cortar 200 ms
    # do fim para cruzar com o comeco so introduziria o degrau que ela evita.
    gravar("chuva_loop", x, 0.7)


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


def bicicleta() -> None:
    """Campainha, rolagem e catraca.

    A campainha e o unico som do jogo que precisa ser INARMONICO de proposito.
    Uma cupula de latao batida nao produz serie harmonica: os parciais caem em
    razoes tortas (1 : 1,5 : 2,3 : 3,1), e e isso que o ouvido chama de "metal".
    Com parciais inteiros o mesmo envelope sai como apito de arbitro.

    O tremor tambem nao e enfeite. Cada parcial entra em duas copias com meio
    hertz de diferenca, e a interferencia entre elas produz o batimento lento
    que faz o sino parecer que treme enquanto morre. Sem ele o som decai reto e
    soa sintetizado, que e o que ele e.

    E toca DUAS vezes. O polegar bate na alavanca e ela volta — ninguem toca
    campainha de bicicleta uma vez so, e o "trim-trim" e mais reconhecivel que
    o timbre.
    """
    # Razao do parcial, ganho e quao rapido ele morre. Os agudos morrem antes,
    # que e o que da o "tim" na entrada e o "mmm" na cauda.
    PARCIAIS = [
        (1.00, 1.00, 3.0), (1.51, 0.55, 4.4), (2.34, 0.32, 6.0),
        (3.12, 0.18, 7.6), (4.05, 0.10, 9.2),
    ]
    f0 = 2280.0

    def toque(dur: float) -> np.ndarray:
        n = int(SR * dur)
        t = np.arange(n) / SR
        x = np.zeros(n)
        for razao, ganho, queda in PARCIAIS:
            for desafino in (-0.6, 0.6):
                fase = rng.uniform(0, 2 * np.pi)
                x += (np.sin(2 * np.pi * (f0 * razao + desafino) * t + fase)
                      * ganho * np.exp(-queda * t))
        # A pancada do martelinho no latao: doze milissegundos de ruido agudo.
        ataque = int(SR * 0.012)
        x[:ataque] += (passa_banda(rng.standard_normal(ataque), 2500.0, 9000.0)
                       * np.linspace(1.0, 0.0, ataque) * 1.8)
        return x

    dur = 1.15
    n = int(SR * dur)
    x = np.zeros(n)
    x += toque(dur)
    # O segundo toque entra antes do primeiro acabar, e por isso os dois se
    # somam em vez de se enfileirar.
    atraso = int(SR * 0.155)
    segundo = toque(dur - 0.155)[:n - atraso]
    x[atraso:atraso + len(segundo)] += segundo * 0.8
    gravar("sino_bicicleta", x, 0.7)

    # Rolagem: pneu fino no asfalto. Quase sem agudo — e o que separa bicicleta
    # de carro no ouvido, junto com a ausencia de motor. A velocidade entra por
    # afinacao em tempo de execucao, como no motor.
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    x = passa_banda(rng.standard_normal(n), 80.0, 1300.0)
    # Ondulacao no ritmo da volta da roda: o asfalto nao e liso e a roda passa
    # pelo mesmo defeito do pneu uma vez por volta.
    x *= 0.84 + 0.16 * np.sin(2 * np.pi * 3.1 * t)
    gravar("bicicleta_loop", emenda_para_loop(x, 70.0), 0.5)

    # Catraca da roda-livre: o tique de quando se para de pedalar e a bicicleta
    # segue andando. Dez tiques no arquivo, espacados por igual, e o comprimento
    # e multiplo exato do espacamento — assim o loop fecha sem emenda e sem
    # precisar do cruzamento, que aqui borraria justamente o silencio entre os
    # tiques.
    passo = int(SR * 0.05)
    n = passo * 10
    x = np.zeros(n)
    largura = 160
    for k in range(10):
        estalo = (passa_banda(rng.standard_normal(largura), 1800.0, 7000.0)
                  * envelope(largura, 0.01, 8.0))
        i = k * passo
        x[i:i + largura] += estalo
    gravar("catraca_loop", x, 0.4)


def lago() -> None:
    """Agua do parque: a lamina batendo na margem, o mergulho e a bracada.

    Por que a lamina nao e so ruido rosa filtrado
    ---------------------------------------------
    Porque agua parada nao chia: ela BATE, em intervalos irregulares, e o que o
    ouvido reconhece e o intervalo, nao o timbre. O loop aqui e ruido de banda
    estreita modulado por uma envoltoria lenta somada a batidas espacadas — sem
    as batidas, o mesmo som passa por vento, por chuva ou por chiado de TV.
    """
    # --- lamina na margem, em loop
    dur = 4.0
    n = int(SR * dur)
    x = passa_banda(rng.normal(0.0, 1.0, n), 180.0, 2200.0)
    t = np.arange(n) / SR
    # Duas ondulacoes lentas em razao irracional: sem periodo audivel.
    onda = 0.55 + 0.28 * np.sin(2.0 * np.pi * 0.21 * t) + 0.17 * np.sin(2.0 * np.pi * 0.37 * t + 1.1)
    x *= onda
    # As batidas. Espacadas de forma irregular, cada uma com ataque proprio.
    passo = 0.0
    while passo < dur - 0.4:
        passo += rng.uniform(0.35, 0.95)
        i = int(SR * passo)
        m = min(int(SR * 0.22), n - i)
        if m < 64:
            break
        env = np.exp(-np.linspace(0.0, 7.0, m))
        batida = passa_banda(rng.normal(0.0, 1.0, m), 600.0, 4200.0) * env
        x[i:i + m] += batida * rng.uniform(0.5, 1.0)
    gravar("lago_loop", emenda_para_loop(x), 0.5)

    # --- mergulho
    n = int(SR * 1.1)
    t = np.arange(n) / SR
    # O baque: banda larga que fecha rapido, que e o ar sendo expulso.
    baque = passa_banda(rng.normal(0.0, 1.0, n), 90.0, 3000.0) * np.exp(-t * 9.0)
    # A borbulha depois: banda que SOBE, porque a bolha encolhe ao subir.
    fase = 2.0 * np.pi * np.cumsum(np.linspace(320.0, 1500.0, n)) / SR
    bolha = np.sin(fase) * np.exp(-t * 4.5) * 0.22 * (rng.random(n) > 0.3)
    espirro = passa_banda(rng.normal(0.0, 1.0, n), 2000.0, 8000.0) * np.exp(-t * 5.0) * 0.5
    gravar("mergulho", baque + bolha + espirro, 0.85)

    # --- bracada
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    env = np.clip(np.sin(np.pi * t / t[-1]), 0.0, 1.0) ** 1.5
    br = passa_banda(rng.normal(0.0, 1.0, n), 300.0, 3600.0) * env
    gravar("bracada", br, 0.6)


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


def estufa() -> None:
    """O ar da estufa: exaustor, ventilador e o reator da luminaria.

    Tres camadas, e as tres precisam estar la:

      exaustor    ruido largo e grave, o volume de ar passando pelo duto
      helice      batida periodica em 3 Hz, a pa cortando o ar
      reator      zumbido eletrico em 120 Hz, o ronco do transformador

    So o ruido soa como chuveiro. So o zumbido soa como geladeira. O que
    identifica uma sala com equipamento ligado e a batida da helice por cima do
    ruido — e a periodicidade que o ouvido usa para saber que ha uma MAQUINA
    girando, e nao ar correndo.
    """
    dur = 4.0
    m = int(SR * dur)
    tt = np.arange(m) / SR

    ar = passa_banda(rng.standard_normal(m), 60.0, 1600.0)
    # A batida da helice. Modula o ruido em vez de somar tom: pa de ventilador
    # nao toca nota, ela interrompe o ar.
    ar *= 0.78 + 0.22 * np.sin(2 * np.pi * 3.1 * tt)

    # Reator de luminaria: 120 Hz com a terceira harmonica, que e o que faz o
    # zumbido soar sujo em vez de senoidal.
    reator = (np.sin(2 * np.pi * 120.0 * tt) * 0.5
              + np.sin(2 * np.pi * 360.0 * tt) * 0.16)

    x = ar * 0.8 + reator * 0.12
    gravar("estufa_ar", emenda_para_loop(x, 80.0), 0.42)


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



def bzum() -> None:
    """Magneto passando na tela de um tubo: o Bzum da troca de canal."""
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * np.linspace(90.0, 38.0, n) * t)
    thump *= envelope(n, 0.01, 6.0) * 0.9
    sweep = np.sin(2 * np.pi * np.linspace(980.0, 120.0, n) * t)
    sweep *= envelope(n, 0.02, 4.5) * 0.55
    hiss = passa_banda(rng.standard_normal(n), 1500.0, 8000.0)
    hiss *= envelope(n, 0.005, 9.0) * 0.7
    x = thump + sweep + hiss
    gravar("bzum", x, 0.78)



# --- igreja -----------------------------------------------------------------


def igreja() -> None:
    """Harmonio da Praca da Matriz, e a badalada do sino.

    Nao e "musica religiosa" generica, e um harmonio de arraial: fole, palheta e
    quatro acordes lentos. Tres decisoes fazem a diferenca entre isto e um pad
    de sintetizador, e as tres estao no codigo abaixo.

    1. PALHETA, NAO SENOIDE. Harmonio soa por lamina de metal vibrando, e lamina
       produz harmonico impar forte. A serie 1, 3, 5, 7 com queda de 1/n da o
       timbre anasalado; so a fundamental daria flauta.

    2. O FOLE RESPIRA. O ganho global tem uma onda de 0,22 Hz sobreposta. Sem
       ela o acorde fica com volume de computador, e nenhum instrumento tocado
       com o pe tem volume de computador.

    3. DESAFINA. Cada nota ganha alguns centesimos de tom de desvio, fixo por
       nota. Harmonio de interior vive desafinado, e e a desafinacao que faz o
       acorde bater lento em vez de soar limpo - o mesmo batimento que um coro
       de tres pessoas produz.

    O modo e menor, e a progressao nao resolve: i - VI - III - VII, e volta ao
    i sem passar pela dominante. Uma cadencia que fecha soa consolo; esta fica
    rodando, que e o que se quer de um som ouvido do lado de fora da porta as
    onze e quinze da noite.
    """
    dur_acorde = 5.0
    n = int(SR * dur_acorde)
    t = np.arange(n) / SR

    def palheta(f0: float, desvio: float) -> np.ndarray:
        f = f0 * (2.0 ** (desvio / 1200.0))
        x = np.zeros(n)
        for k in (1, 3, 5, 7):
            x += np.sin(2.0 * np.pi * f * k * t) / k
        # Vibrato de fole: lento e raso. Rapido viraria efeito de teclado.
        return x * (1.0 + 0.012 * np.sin(2.0 * np.pi * 4.6 * t))

    la = 110.0

    def nota(semitons: float) -> float:
        return la * (2.0 ** (semitons / 12.0))

    # i(La menor) - VI(Fa) - III(Do) - VII(Sol), em terceira posicao
    acordes = [
        [0, 7, 12, 15],
        [-4, 5, 12, 20],
        [-9, 7, 12, 16],
        [-2, 7, 14, 19],
    ]
    desvios = [-6.0, 3.0, -2.0, 7.0]

    peca = []
    for j, acorde in enumerate(acordes):
        soma = np.zeros(n)
        for i, st in enumerate(acorde):
            soma += palheta(nota(float(st)), desvios[(i + j) % len(desvios)])
        # Ataque do fole: 0,35 s. Palheta nao ataca seca como corda pincada.
        env = np.clip(t / 0.35, 0.0, 1.0) * np.clip((dur_acorde - t) / 0.45, 0.0, 1.0)
        peca.append(soma * env)

    x = np.concatenate(peca)
    tt = np.arange(len(x)) / SR
    x *= 0.78 + 0.22 * np.sin(2.0 * np.pi * 0.22 * tt)
    # Corta o agudo: o que chega no calcamento atravessou 60 cm de alvenaria.
    # O filtro do proprio AudioStreamPlayer3D ja faz parte disso, mas ele e por
    # distancia; este e o timbre do instrumento, e vale de perto tambem.
    x = passa_banda(x, 60.0, 3200.0)
    # Um fio de ar do fole por cima. Sem ele o harmonio soa amostrado.
    ar = passa_banda(ruido(len(x) / SR), 900.0, 4000.0) * 0.016
    gravar("igreja_loop", emenda_para_loop(x + ar, 220.0), 0.62)

    # A badalada. Sino nao e harmonico: as parciais de um bronze fundido caem
    # perto de 1 : 2,0 : 2,4 : 3,0 : 4,5 da fundamental, e e a de 2,4 - a
    # "terca menor" do sino - que da o tom funebre que nenhum outro instrumento
    # tem. Com parciais inteiras sairia um orgao, nao um sino.
    dur_sino = 4.5
    m = int(SR * dur_sino)
    ts = np.arange(m) / SR
    f0 = 196.0
    sino = np.zeros(m)
    for razao, peso, meia_vida in (
        (1.00, 1.00, 3.6), (2.00, 0.62, 2.4), (2.40, 0.85, 2.9),
        (3.00, 0.40, 1.6), (4.50, 0.28, 0.9), (5.38, 0.16, 0.55),
    ):
        sino += peso * np.sin(2.0 * np.pi * f0 * razao * ts) * np.exp(-ts / meia_vida)
    # O golpe do badalo: um estalo curto de ruido no ataque. E ele que diz que
    # alguma coisa BATEU no metal.
    golpe = passa_banda(ruido(dur_sino), 1800.0, 7000.0)
    golpe *= np.exp(-ts / 0.035) * 0.5
    gravar("sino_igreja", sino + golpe, 0.85)


# --- estrada velha ----------------------------------------------------------

def estrada() -> None:
    """O temporal da Estrada Velha: trovao, chuva de dentro do carro e a roda
    entrando na agua.

    Os tres existem pelo mesmo motivo, e o motivo nao e a lista de efeitos: a
    abertura tinha sete planos de chuva e nenhum som novo. Metade do que se
    sente numa cena de chuva entra pelo ouvido, e essa metade estava inteira
    faltando -- o jogador via um temporal e ouvia o mesmo loop de chuva que
    ouve andando na calcada da cidade.

    Gerador proprio, como em `chuva()`: assim os arquivos nao dependem de quem
    rodou antes deles na lista do `main`.
    """
    local = np.random.default_rng(1995 + 707)

    # --- trovao -------------------------------------------------------------
    # Dois, e nao um. Trovao longe e so o ronco que sobrou depois de dois
    # quilometros de ar comendo tudo acima de uns 400 Hz; trovao perto tem o
    # ESTALO na frente, que e a frente de choque chegando antes do ronco. Um
    # arquivo so, tocado mais baixo, nao vira o outro: o que muda entre os dois
    # nao e o volume, e o conteudo de agudo.
    for nome, alcance, estalo, dur in (
        ("trovao_longe", (28.0, 420.0), 0.0, 5.2),
        ("trovao_perto", (40.0, 3400.0), 0.9, 4.2),
    ):
        n = int(SR * dur)
        t = np.arange(n) / SR
        x = passa_banda(local.standard_normal(n), alcance[0], alcance[1])

        # O ROLO. Um trovao nao decai liso: ele vai e volta, porque o som chega
        # de pedacos diferentes do raio e de tudo em que ele bateu no caminho.
        # Tres ondulacoes lentas em razao nao inteira dao esse vaivem sem que
        # nenhuma delas se reconheca voltando.
        rolo = np.ones(n)
        for freq, amp in ((0.37, 0.45), (0.83, 0.30), (1.7, 0.18)):
            rolo *= 1.0 + amp * np.sin(2 * np.pi * freq * t + local.random() * 6.3)
        # Ataque lento: o ronco CRESCE antes de cair. Com ataque rapido ele vira
        # uma explosao, que e outro som.
        sobe = np.clip(t / 0.55, 0.0, 1.0)
        cai = np.exp(-t / (dur * 0.30))
        x = x * rolo * sobe * cai

        if estalo > 0.0:
            # O estalo: banda larga, ataque de dois milissegundos, morto em
            # cento e cinquenta. E o que separa o raio que caiu perto do que
            # caiu no fim do vale.
            m = int(SR * 0.22)
            crack = passa_banda(local.standard_normal(m), 300.0, 9000.0)
            crack *= np.exp(-np.linspace(0.0, 9.0, m))
            crack[:int(SR * 0.002)] *= np.linspace(0.0, 1.0, int(SR * 0.002))
            x[:m] += crack * estalo

        gravar(nome, x, 0.92)

    # --- chuva de dentro do carro -------------------------------------------
    # A mesma chuva, ouvida atraves de uma lataria e de um vidro. Duas coisas
    # mudam, e as duas importam: o agudo some (o vidro nao deixa passar a
    # agulha da gota no asfalto) e aparece a BATIDA no teto, que so existe
    # para quem esta debaixo dele.
    #
    # Nao e o `chuva_loop` com um filtro por cima em tempo real de proposito.
    # Seria um efeito de barramento, e o jogo nao tem essa cadeia montada; e o
    # arquivo custa 400 KB, que e menos do que a complexidade custaria.
    dur = 12.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    # Abafado: quase nada acima de 900 Hz. A FFT e circular, entao o loop nao
    # tem costura -- mesmo motivo de `chuva()`.
    corpo = passa_banda(local.standard_normal(n), 120.0, 900.0)
    fundo = passa_banda(local.standard_normal(n), 55.0, 260.0)
    x = corpo * 0.55 + fundo * 0.40

    # A batida no teto. Impulsos esparsos filtrados pela MESMA FFT circular:
    # a cauda de um impulso perto do fim do buffer volta para o comeco por
    # construcao, entao ele nao estala na emenda.
    impulsos = np.zeros(n)
    quantos = int(dur * 34.0)
    onde = local.integers(0, n, quantos)
    impulsos[onde] = local.random(quantos) * 2.0 - 1.0
    batida = passa_banda(impulsos, 180.0, 1400.0)
    x += batida * 3.2

    for ciclos, amp, fase in ((3, 0.06, 0.0), (7, 0.04, 2.1)):
        x = x * (1.0 + amp * np.sin(2 * np.pi * ciclos * t / dur + fase))
    gravar("chuva_cabine_loop", x, 0.68)

    # --- a roda entrando na agua --------------------------------------------
    # Nao e um "splash" de pedra caindo em lago: e a lamina sendo RASGADA, meio
    # segundo de sopro com um pico curto no comeco. O que faz ler como agua e o
    # espectro descendo enquanto some -- a gota grossa fica por ultimo.
    dur = 0.62
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # Quatro bandas que morrem em tempos diferentes: a mais aguda primeiro.
    for baixo, alto, meia_vida, peso in (
        (2600.0, 8800.0, 0.055, 1.00),
        (1100.0, 2600.0, 0.11, 0.85),
        (420.0, 1100.0, 0.20, 0.60),
        (120.0, 420.0, 0.30, 0.35),
    ):
        banda = passa_banda(local.standard_normal(n), baixo, alto)
        x += banda * np.exp(-t / meia_vida) * peso
    # Ataque de 8 ms: o pneu entra na agua, nao bate nela.
    a = int(SR * 0.008)
    x[:a] *= np.linspace(0.0, 1.0, a)
    gravar("poca_pneu", x, 0.85)


def mercado() -> None:
    """A loja de conveniencia que existe na rua (PLANO_MERCADO_AAA, F1).

    O dim-dom e o sino eletronico de porta de loja: duas notas descendo uma
    terca maior (mi, do), cada uma com ataque de martelo e cauda longa, saindo de
    um alto-falante pequeno — por isso o passa-banda, que tira o grave que uma
    caixinha de plastico no batente nao tem. Toca quando alguem CRUZA a porta
    para dentro; ouvido do deposito, e informacao de jogo.

    O motor do portao e um laco: o zumbido do motor (serie harmonica de 100 Hz,
    a rede eletrica dobrada), a corrente estalando em ritmo quase regular e a
    chapa ondulada vibrando por cima. Sem a irregularidade das batidas o laco se
    entrega no segundo giro.

    Semente propria e chamada propria (`python tools/gerar_audio.py mercado`):
    regravar o banco inteiro para acrescentar dois sons arriscaria mudar os que
    ja estao no jogo.
    """
    r = np.random.default_rng(1998)

    dur = 1.9
    n = int(SR * dur)
    x = np.zeros(n)
    for freq, inicio, forca in ((659.25, 0.0, 1.0), (523.25, 0.43, 0.92)):
        i = int(SR * inicio)
        tt = np.arange(n - i) / SR
        env = (1.0 - np.exp(-tt / 0.004)) * np.exp(-tt / 0.55)
        tom = (np.sin(2 * np.pi * freq * tt)
               + 0.28 * np.sin(2 * np.pi * 2.0 * freq * tt) * np.exp(-tt / 0.18)
               + 0.12 * np.sin(2 * np.pi * 3.01 * freq * tt) * np.exp(-tt / 0.09))
        x[i:] += forca * tom * env
    gravar("loja_dimdom", passa_banda(x, 350.0, 5500.0), 0.7)

    dur = 2.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    zumbido = sum(np.sin(2 * np.pi * 100.0 * k * t) / k for k in range(1, 7))
    zumbido *= 0.8 + 0.2 * np.sin(2 * np.pi * 3.0 * t)
    corrente = np.zeros(n)
    batida = 0.0
    while batida < dur - 0.02:
        i = int(SR * batida)
        m = int(SR * 0.008)
        estalo = passa_banda(r.standard_normal(m * 4), 800.0, 4000.0)[:m]
        corrente[i:i + m] += estalo * np.exp(-np.arange(m) / (m * 0.3)) \
            * r.uniform(0.5, 1.0)
        batida += 1.0 / 13.0 + r.uniform(-0.012, 0.012)
    chapa = passa_banda(r.standard_normal(n), 250.0, 900.0) * 0.3
    x = zumbido * 0.35 + corrente * 1.4 + chapa
    gravar("portao_motor", emenda_para_loop(x), 0.6)


def mercado_produto() -> None:
    """O produto e a geladeira (PLANO_MERCADO_AAA, F2).

    Cada forma soa pelo material: a lata e um tinido curto de aluminio fino (dois
    modos altos que morrem em 60 ms) com o arrasto na grade; o pacote e o
    amassado de plastico metalizado, ruido em rajadas; o vidro e o toque grave e
    longo da garrafa na chapa; a caixa e papelao deslizando e batendo seco.

    A porta da geladeira abre com o estalo da borracha descolando (a vedacao
    magnetica soltando de uma vez) e o sopro frio; fecha com a batida amortecida
    e o "tuc" da vedacao pegando. Sem o estalo, porta de geladeira soa porta de
    armario.

    `python tools/gerar_audio.py mercado_produto` — semente propria.
    """
    r = np.random.default_rng(1411)

    def env(n, ataque, queda):
        tt = np.arange(n) / SR
        return (1.0 - np.exp(-tt / ataque)) * np.exp(-tt / queda)

    # lata
    n = int(SR * 0.35)
    tt = np.arange(n) / SR
    tinido = sum(a * np.sin(2 * np.pi * f * tt) for f, a in ((2630.0, 1.0), (4110.0, 0.6), (5870.0, 0.3)))
    x = tinido * env(n, 0.001, 0.045)
    arrasto = passa_banda(r.standard_normal(n), 1500.0, 6000.0) * env(n, 0.01, 0.08) * 0.35
    gravar("pega_lata", x + arrasto, 0.55)

    # pacote
    n = int(SR * 0.45)
    x = np.zeros(n)
    t0 = 0.0
    while t0 < 0.32:
        i = int(SR * t0)
        m = int(SR * r.uniform(0.012, 0.04))
        x[i:i + m] += r.standard_normal(m) * np.exp(-np.arange(m) / (m * 0.4)) * r.uniform(0.3, 1.0)
        t0 += r.uniform(0.01, 0.05)
    gravar("pega_pacote", passa_banda(x, 1200.0, 8000.0), 0.5)

    # vidro
    n = int(SR * 0.6)
    tt = np.arange(n) / SR
    x = sum(a * np.sin(2 * np.pi * f * tt) * np.exp(-tt / q) for f, a, q in
            ((1180.0, 1.0, 0.16), (2960.0, 0.45, 0.07), (430.0, 0.5, 0.05)))
    x += passa_banda(r.standard_normal(n), 300.0, 2500.0) * env(n, 0.002, 0.02) * 0.6
    gravar("pega_vidro", x, 0.5)

    # caixa
    n = int(SR * 0.3)
    x = passa_banda(r.standard_normal(n), 400.0, 3000.0) * env(n, 0.02, 0.07) * 0.6
    i = int(SR * 0.12)
    m = int(SR * 0.03)
    x[i:i + m] += passa_banda(r.standard_normal(m), 150.0, 1200.0) * np.exp(-np.arange(m) / (m * 0.2)) * 1.4
    gravar("pega_caixa", x, 0.5)

    # geladeira abre
    n = int(SR * 0.9)
    x = np.zeros(n)
    m = int(SR * 0.05)
    x[:m] += passa_banda(r.standard_normal(m), 200.0, 2500.0) * np.exp(-np.arange(m) / (m * 0.15)) * 1.5
    sopro = passa_banda(r.standard_normal(n), 300.0, 2000.0) * env(n, 0.08, 0.3) * 0.35
    gravar("geladeira_abre", x + sopro, 0.6)

    # geladeira fecha
    n = int(SR * 0.6)
    tt = np.arange(n) / SR
    batida = (np.sin(2 * np.pi * 85.0 * tt) + 0.5 * np.sin(2 * np.pi * 170.0 * tt)) * env(n, 0.003, 0.06)
    x = batida + passa_banda(r.standard_normal(n), 150.0, 1500.0) * env(n, 0.002, 0.03) * 0.8
    i = int(SR * 0.09)
    m = int(SR * 0.03)
    x[i:i + m] += passa_banda(r.standard_normal(m), 400.0, 3000.0) * np.exp(-np.arange(m) / (m * 0.2)) * 0.6
    gravar("geladeira_fecha", x, 0.6)


# --- interior de minas ------------------------------------------------------

def longe(x: np.ndarray, corte: float, ecos: tuple = ()) -> np.ndarray:
    """O que a distancia faz com um som: come o agudo e, num vale, devolve o
    som batido no morro do outro lado. `ecos` e uma lista de (atraso s, ganho)."""
    y = passa_banda(x, 80.0, corte)
    for atraso, ganho in ecos:
        n = int(SR * atraso)
        y = y + np.concatenate([np.zeros(n), passa_banda(y, 150.0, corte * 0.6)[:len(y) - n]]) * ganho
    return y


def interior() -> None:
    """O ceu e o quintal de uma cidade do interior de Minas (CeuVivo).

    Tudo aqui e ouvido de LONGE, e isso e o que salva a sintese: um bicho
    gravado de perto tem detalhe que ruido filtrado nao imita, mas a cem metros
    sobram o contorno de altura e o ritmo, e sao eles que o ouvido reconhece.

    - maritaca: guincho aspero em rajada, dois a cinco gritos. Tom agudo com
      modulacao rapida e ruido por cima: e o "aspero" que diz maritaca.
    - bem-te-vi: as tres notas que dao o nome, a ultima longa e descendo.
    - cachorro_longe: dois a quatro latidos do outro lado do vale, com o eco
      batendo no morro. O eco e metade do "longe".
    - aviao_teco_loop: o motor de quatro cilindros e a helice de um aviaozinho,
      o zumbido que o interior inteiro ouve passar.
    - jato_longe_loop: o ronco grave e largo de um jato a dez quilometros.
    """
    r = np.random.default_rng(1974)

    # Maritaca: cada grito e um tom de 1,9-2,6 kHz com vibrato de 55-80 Hz
    # (a aspereza) e harmonicos fortes, num envelope curto.
    def grito(dur: float, f0: float) -> np.ndarray:
        n = int(SR * dur)
        t = np.arange(n) / SR
        cai = f0 * (1.0 + 0.18 * np.sin(np.pi * t / dur)) * (1.0 - 0.12 * t / dur)
        fm = 1.0 + 0.06 * np.sin(2.0 * np.pi * r.uniform(55.0, 80.0) * t)
        fase = 2.0 * np.pi * np.cumsum(cai * fm) / SR
        x = np.sin(fase) + 0.55 * np.sin(2.0 * fase + 0.4) + 0.3 * np.sin(3.0 * fase + 1.1)
        x += passa_banda(r.standard_normal(n), 1500.0, 5000.0) * 0.35
        env = np.clip(t / 0.012, 0.0, 1.0) * np.clip((dur - t) / 0.04, 0.0, 1.0)
        return x * env

    for k, gritos in enumerate((3, 5, 2)):
        pedacos = []
        for i in range(gritos):
            pedacos.append(grito(r.uniform(0.11, 0.2), r.uniform(1900.0, 2600.0)))
            pedacos.append(np.zeros(int(SR * r.uniform(0.05, 0.16))))
        x = longe(np.concatenate(pedacos + [np.zeros(int(SR * 0.3))]), 5200.0, ((0.11, 0.12),))
        gravar(f"maritaca_{k + 1}", x, 0.8)

    # Bem-te-vi: "bem" curto subindo, "te" curtinho, "viii" longo descendo.
    def nota(dur: float, f_ini: float, f_fim: float, aspero: float) -> np.ndarray:
        n = int(SR * dur)
        t = np.arange(n) / SR
        f = f_ini + (f_fim - f_ini) * (t / dur) ** 0.7
        fase = 2.0 * np.pi * np.cumsum(f) / SR
        x = np.sin(fase) + 0.4 * np.sin(2.0 * fase)
        x *= 1.0 + aspero * np.sin(2.0 * np.pi * 70.0 * t)
        env = np.clip(t / 0.01, 0.0, 1.0) * np.clip((dur - t) / 0.03, 0.0, 1.0)
        return x * env

    for k, (a, b) in enumerate(((2500.0, 3500.0), (2400.0, 3300.0))):
        x = np.concatenate([
            nota(0.13, a, a * 1.12, 0.25), np.zeros(int(SR * 0.07)),
            nota(0.07, a * 1.1, a * 1.15, 0.2), np.zeros(int(SR * 0.06)),
            nota(0.36, b, b * 0.72, 0.35), np.zeros(int(SR * 0.4)),
        ])
        if k == 1:
            # O segundo repete o "bem-te-vi" mais fraco, como quem responde.
            x = np.concatenate([x, x * 0.55])
        gravar(f"bem_te_vi_{k + 1}", longe(x, 6000.0, ((0.09, 0.1),)), 0.8)

    # Cachorro: o latido e um pulso de voz de 450-650 Hz caindo, com formante
    # e sopro; de longe, sem agudo e com o eco do morro.
    def latido(f0: float) -> np.ndarray:
        dur = r.uniform(0.13, 0.2)
        n = int(SR * dur)
        t = np.arange(n) / SR
        f = f0 * (1.0 + 0.35 * np.exp(-t / 0.03)) * (1.0 - 0.25 * t / dur)
        fase = 2.0 * np.pi * np.cumsum(f) / SR
        x = sum(np.sin(k * fase) / k ** 0.8 for k in range(1, 9))
        x = passa_banda(x, 350.0, 2400.0)
        x += passa_banda(r.standard_normal(n), 500.0, 2500.0) * 0.5
        env = np.clip(t / 0.008, 0.0, 1.0) * np.exp(-t / (dur * 0.45))
        return x * env

    for k, latidos in enumerate((2, 3, 4)):
        f0 = r.uniform(430.0, 620.0)
        pedacos = []
        for i in range(latidos):
            pedacos.append(latido(f0 * r.uniform(0.95, 1.05)))
            pedacos.append(np.zeros(int(SR * r.uniform(0.28, 0.55))))
        x = np.concatenate(pedacos + [np.zeros(int(SR * 1.2))])
        gravar(f"cachorro_longe_{k + 1}", longe(x, 1900.0, ((0.23, 0.35), (0.61, 0.16))), 0.75)

    # Teco-teco: helice e motor com frequencias de ciclo inteiro no loop de 6 s,
    # para a emenda nao estalar; uma ondulacao lenta de 0,5 Hz no volume.
    dur = 6.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, peso in ((80.0, 1.0), (40.0, 0.5)):
        for k in range(1, 14):
            x += peso * np.sin(2.0 * np.pi * f * k * t + k * 0.7) / k ** 0.9
    x *= 0.8 + 0.2 * np.sin(2.0 * np.pi * 0.5 * t)
    ar = passa_banda(r.standard_normal(n), 250.0, 1400.0) * 0.8
    x = passa_banda(x + ar, 50.0, 1800.0)
    gravar("aviao_teco_loop", emenda_para_loop(x, 120.0), 0.7)

    # Jato: ruido grave largo, com um inchaco lento. Nada de apito: a dez
    # quilometros so o grave chega.
    dur = 8.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = passa_banda(r.standard_normal(n), 35.0, 520.0)
    x += passa_banda(r.standard_normal(n), 500.0, 1100.0) * 0.12
    x *= 0.85 + 0.15 * np.sin(2.0 * np.pi * 0.125 * t)
    gravar("jato_longe_loop", emenda_para_loop(x, 400.0), 0.7)


def main() -> int:
    import sys
    # So as familias pedidas, quando pedidas: `python tools/gerar_audio.py mercado`.
    pedidas = sys.argv[1:]
    if pedidas:
        for nome in pedidas:
            globals()[nome]()
        return 0
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
    bicicleta()
    lago()
    casa_fumaca()
    bzum()
    risadas()
    estufa()
    igreja()
    estrada()
    mercado()
    interior()
    n = len(list(SAIDA.glob("*.wav")))
    print(f"\n{n} sons em {SAIDA.relative_to(RAIZ)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
