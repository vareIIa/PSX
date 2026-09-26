#!/usr/bin/env python3
"""Sons do agarrao do padre, o fim da abertura da estrada.

O agarrao (`AgarraoDoPadre`) acontece A UM PALMO da lente, e quase tudo
dele e ouvido de dentro da cabeca do motorista: a mao cobre metade da cara e
uma orelha, e o cranio conduz o grave. Por isso estes sons tem mais corpo
embaixo e menos ar em cima que os da janela (`gerar_audio_cabecada.py`, de
onde vem as ferramentas).

- `mao_na_cara`: a palma fria e molhada batendo na cara. O estalo da pele, o
  surdo do cranio por dentro, o molhado, as unhas assentando.
- `mao_aperta`: os dedos fechando na cara. A pele rangendo contra a pele, os
  nos do padre estalando, a manga molhada.
- `respira_abafado`: o motorista respirando em panico por entre os dedos,
  curto e pelo nariz. O vao dos dedos assobia.
- `cabeca_empurrada`: a cabeca jogada para longe. O pescoco estala, o encosto
  de espuma leva a nuca, e a roupa arrasta no banco.
- `puxao_ar`: o ar passando nas orelhas no puxao, cada vez mais agudo. Acaba
  seco, no impacto.
- `cabecada_final`: cranio contra cranio, ouvido de dentro. O grave que
  afunda, o osso do nariz e da testa partindo, e o apito que fica.

A 44.100 Hz, como os da janela.

    python tools/gerar_audio_agarrao.py [nomes...]
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar_audio_cabecada import (SR, banda, cranio, envelope, estalos, gravar,  # noqa: E402
                                  janela, molhado, passa_alta, passa_baixa, pos, ressoa,
                                  satura)

rng = np.random.default_rng(2718)


def ruido(n: int) -> np.ndarray:
    return rng.standard_normal(n)


def mao_na_cara() -> np.ndarray:
    """A palma batendo na cara, de dentro da cabeca."""
    dur = 0.75
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # O estalo da pele: palma chata e molhada, um tapa curto, largo, sem eco.
    m = int(SR * 0.03)
    estalo = banda(ruido(m), 700, 7000) * envelope(m, 0.0004, 0.0045)
    estalo += banda(ruido(m), 200, 1200) * envelope(m, 0.0006, 0.009) * 0.8
    pos(x, estalo, 0.0, 1.9)
    # O cranio por dentro: grave, um nada abaixo do da testa no vidro.
    x += cranio(n, 128.0, 0.55) * 0.6
    # O molhado da palma suja de sangue e barro.
    x += molhado(n, 0.9) * 0.7
    # As unhas assentando na testa e na bochecha, logo depois.
    x += estalos(n, 6, 0.09, 1800, 6000, 71) * 0.35
    # A pele deslizando um centimetro depois do tapa: chiado grave, curto.
    m = int(SR * 0.28)
    tt = np.arange(m) / SR
    desliza = banda(ruido(m), 250, 1800) * (0.55 + 0.45 * np.sin(2 * np.pi * 27 * tt)) \
        * envelope(m, 0.02, 0.07)
    pos(x, desliza, 0.03, 0.45)
    x *= 1.0 - 0.15 * np.exp(-t / 0.3)
    return satura(x, 1.3) * janela(n, 0.002)


def mao_aperta() -> np.ndarray:
    """Os dedos fechando na cara: pele rangendo e os nos estalando."""
    dur = 1.5
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # Pele contra pele: stick-slip grave e aspero, que gagueja com a forca.
    forca = np.clip(t / 0.35, 0.0, 1.0) * (0.75 + 0.25 * np.sin(2 * np.pi * 1.7 * t))
    f = 150.0 + 140.0 * forca
    serra = ((np.cumsum(f) / SR) % 1.0) * 2.0 - 1.0
    pega = passa_baixa((np.sin(2 * np.pi * 13.0 * t + 0.5 * np.sin(2 * np.pi * 3.1 * t)) > 0.1)
                       .astype(float), 50, 2)
    range_pele = banda(serra * pega * forca, 180, 1500)
    x += range_pele * 0.7
    # Os nos dos dedos compridos: estalos secos, graves, espalhados.
    x += estalos(n, 7, 1.1, 300, 2600, 72) * 0.9
    # A unha entrando na pele: um fio agudo e curto.
    x += estalos(n, 10, 0.5, 2500, 7000, 73) * 0.2
    # A manga molhada da batina, perto da orelha.
    x += banda(ruido(n), 600, 3500) * (0.5 + 0.5 * np.sin(2 * np.pi * 2.3 * t)) \
        * envelope(n, 0.1, 0.6) * 0.18
    return x * envelope(n, 0.03, 0.9) * janela(n, 0.01)


def respira_abafado() -> np.ndarray:
    """O motorista respirando pelo nariz, em panico, com a mao na cara.
    Curto e rapido, a entrada mais aguda que a saida, e o vao dos dedos
    assobiando em cima."""
    dur = 2.6
    n = int(SR * dur)
    x = np.zeros(n)
    t0 = 0.02
    k = 0
    r = np.random.default_rng(74)
    while t0 < dur - 0.25:
        entra = k % 2 == 0
        d = r.uniform(0.13, 0.17) if entra else r.uniform(0.17, 0.23)
        m = int(SR * d)
        tt = np.arange(m) / SR
        forma = np.sin(np.pi * tt / d) ** (1.2 if entra else 2.0)
        if entra:
            ar = banda(ruido(m), 900, 4200) * 0.6 + banda(ruido(m), 300, 900) * 0.4
        else:
            ar = banda(ruido(m), 250, 1800)
        # O vao dos dedos: um modo estreito, que muda com a mao.
        assobio = ressoa(ruido(m), r.uniform(1650, 2100), 30.0) * 0.5
        pos(x, (ar + assobio) * forma, t0, r.uniform(0.7, 1.0) * (1.0 if entra else 0.8))
        t0 += d + r.uniform(0.01, 0.05)
        k += 1
    # Abafado: a mao tampa metade do nariz.
    return passa_baixa(x, 3800) * janela(n, 0.02)


def cabeca_empurrada() -> np.ndarray:
    """A cabeca jogada para longe: o pescoco estala, a nuca afunda no
    encosto, a roupa arrasta."""
    dur = 0.9
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # O arrasto da roupa e do cabelo no banco: um sopro que sobe e desce.
    m = int(SR * 0.3)
    tt = np.arange(m) / SR
    arrasta = banda(ruido(m), 700, 5500) * np.sin(np.pi * tt / 0.3) ** 1.5
    pos(x, arrasta, 0.0, 0.5)
    # O pescoco torcendo: tres estalos graves e secos.
    x += estalos(n, 4, 0.12, 250, 2200, 75) * 1.7
    # A nuca no encosto: espuma e plastico, surdo.
    m = int(SR * 0.4)
    tt = np.arange(m) / SR
    encosto = passa_baixa(ruido(m), 260) * envelope(m, 0.004, 0.05)
    encosto += np.sin(2 * np.pi * 72 * tt * (1 - 0.4 * tt)) * envelope(m, 0.002, 0.08) * 0.8
    encosto += banda(ruido(m), 1500, 4000) * envelope(m, 0.001, 0.012) * 0.2
    pos(x, encosto, 0.2, 1.1)
    return satura(x, 1.2) * janela(n, 0.003)


def puxao_ar() -> np.ndarray:
    """O ar nas orelhas no puxao: sobe de tom e de forca e acaba seco, no
    impacto. Tocado de forma que o fim caia no branco."""
    dur = 0.34
    n = int(SR * dur)
    t = np.arange(n) / SR
    k = (t / dur) ** 1.8
    x = np.zeros(n)
    blocos = 16
    for b in range(blocos):
        i0 = b * n // blocos
        i1 = (b + 1) * n // blocos
        f = 250.0 + 3600.0 * (b / blocos) ** 1.5
        seg = banda(ruido(i1 - i0 + 2048), f * 0.5, f * 1.9)[1024:1024 + i1 - i0]
        x[i0:i1] = seg
    # O rugido grave do vento batendo na orelha.
    x = x * k + passa_baixa(ruido(n), 160) * k * 0.9
    m = int(SR * 0.002)
    x[-m:] *= np.linspace(1, 0, m)
    return x


def cabecada_final() -> np.ndarray:
    """Cranio contra cranio, de dentro: o grave que afunda, o osso partindo e
    o apito."""
    dur = 2.4
    n = int(SR * dur)
    t = np.arange(n) / SR
    # O impacto: dois cranios, um grave e um mais grave ainda.
    x = cranio(n, 92.0, 1.0) * 1.3 + cranio(n, 61.0, 1.0) * 0.9
    # O afundar: um seno que cai e satura, meio segundo.
    f = 58.0 * np.exp(-t * 2.2) + 24.0 * (1 - np.exp(-t * 2.2))
    x += satura(np.sin(2 * np.pi * np.cumsum(f) / SR), 3.0) * envelope(n, 0.002, 0.35) * 0.9
    # O osso: a testa e o nariz dele e os do motorista, estalos em rajada.
    x += estalos(n, 30, 0.05, 900, 8000, 76) * 1.4
    x += estalos(n, 12, 0.14, 300, 2500, 77) * 0.7
    x += molhado(n, 1.0) * 0.6
    # O estalo de ataque, largo: a pele das duas testas.
    x += banda(ruido(n), 150, 12000) * envelope(n, 0.0003, 0.008) * 0.9
    # O apito que fica.
    apito = np.sin(2 * np.pi * 6840 * t) + 0.5 * np.sin(2 * np.pi * 6893 * t)
    apito = apito * np.clip((t - 0.04) / 0.1, 0.0, 1.0) * np.exp(-np.maximum(t - 0.3, 0) / 1.1)
    x += passa_alta(apito, 3000) * 0.12
    return satura(x, 1.6) * janela(n, 0.004)


SONS = {
    "mao_na_cara": mao_na_cara,
    "mao_aperta": mao_aperta,
    "respira_abafado": respira_abafado,
    "cabeca_empurrada": cabeca_empurrada,
    "puxao_ar": puxao_ar,
    "cabecada_final": cabecada_final,
}


def main() -> int:
    nomes = sys.argv[1:] or list(SONS)
    for nome in nomes:
        gravar(nome, SONS[nome]())
    return 0


if __name__ == "__main__":
    sys.exit(main())
