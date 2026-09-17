#!/usr/bin/env python3
"""Criterio de aceite da casa da fumaca e da primeira missao do jogo.

Roda a rotina TesteFumaca dentro do jogo, com fisica, e confere cada numero. O
que da para afirmar objetivamente:

  missao      tem tres etapas, e as tres fecham pelo caminho do jogador:
              tracar a rota no GPS, entrar na casa, falar com o dono
  gente       nove pessoas, dois com controle, um dono, ninguem com osso
              abaixo do piso
  conversa    o assunto da casa aparece DENTRO dela e nao aparece na rua; a
              caixa abre, responde e fecha
  presente    o dono paga o bilhete, e a bolsa cheia nao trava a missao

O que nao da para afirmar assim — se a sala PARECE a casa de alguem — nao esta
aqui: para isso existem as capturas em captures/fumaca_aaa.

    python tools/verificar_fumaca.py
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[fumaca\] ([a-z0-9_]+)=(\S+)")

# chave -> (esperado, por que importa)
#
# Cada linha aqui e um defeito que existiu de verdade, ou a prova de que ele
# nao voltou. Nenhuma delas e "parece certo".
CRITERIOS: dict[str, tuple[str, str]] = {
    "missao_comecou": ("1", "a primeira missao nasce"),
    "missao_etapas": ("3", "tres etapas: a terceira e a que faltava"),
    "etapa_apos_rota": ("1", "tracar a rota no GPS fecha a licao de mapa"),
    "etapa_apos_entrar": ("2",
                          "entrar ABRE a etapa do dono; 3 aqui seria a missao "
                          "voltando a terminar na soleira"),
    "gente": ("9", "oito da festa mais o dono"),
    "com_controle": ("2", "so os dois que jogam; era todo papel != LIVRE, e o "
                          "bar ganhava DualShock de brinde"),
    "donos": ("1", "um dono por comodo"),
    "pe_abaixo_do_piso": ("0", "a pose de sentado punha o pe 3 cm dentro do "
                               "chao; aqui a prova e no corpo que esta na sala"),
    "dono_rotulo_proprio": ("1", "o dono se anuncia entre nove rotulos iguais"),
    "conversa_abriu": ("1", "a caixa abre"),
    "role_na_casa": ("1", "o assunto do lugar existe dentro do lugar"),
    "role_na_rua": ("0", "e NAO vaza para a rua"),
    "escolheu_role": ("1", "da para perguntar do role"),
    "conversa_fechou": ("1", "e a caixa fecha sozinha depois"),
    "missao_concluida": ("1", "falar com o dono termina a missao"),
    "presente": ("1", "e ele paga o bilhete"),
    "bolsa_missao_concluida": ("1",
                               "com a bolsa CHEIA a missao fecha do mesmo "
                               "jeito; presente e missao estavam amarrados e "
                               "isso travava a primeira missao do jogo"),
    "assentos": ("2", "sofa e poltrona, com enquadramentos diferentes"),
    "sentado_travado": ("1", "sentado nao anda"),
    "sentado_olho_cm": ("86", "a lente desce para a altura do sofa"),
    "sentado_mudou_de_lugar": ("1", "o jogador vai para o movel"),
    "sentado_rotulo_levantar": ("1", "e o rotulo vira Levantar"),
    "levantou_solto": ("1", "levantar devolve o controle"),
    "levantou_olho_livre": ("1",
                            "e devolve a ALTURA: esquecer esta deixa o jogador "
                            "enxergando a 86 cm pelo resto da partida"),
    "levantou_voltou": ("1", "e o poe de volta onde estava"),
    "fim": ("1", "a rotina chegou ao fim"),
}


def main() -> int:
    if not GODOT.exists():
        print(f"binario ausente: {GODOT}")
        return 2
    saida = subprocess.run(
        [str(GODOT), "--path", str(JOGO), "--", "--teste-fumaca"],
        capture_output=True, text=True, timeout=300)
    lidos = dict(LINHA.findall(saida.stdout))
    if not lidos:
        print("a rotina nao imprimiu nada. stderr:")
        print(saida.stderr[-2000:])
        return 2

    falhas = 0
    for chave, (esperado, porque) in CRITERIOS.items():
        obtido = lidos.get(chave)
        if obtido == esperado:
            print(f"  ok    {chave} = {obtido}")
            continue
        falhas += 1
        print(f"  FALHA {chave} = {obtido} (esperado {esperado})")
        print(f"        {porque}")

    # Numeros que nao sao criterio, so contexto para quem esta lendo.
    for chave in ("gps_casas", "fumando", "osso_mais_baixo_cm",
                  "conversa_passos", "passos_ate_a_lista"):
        if chave in lidos:
            print(f"  .     {chave} = {lidos[chave]}")

    print()
    if falhas:
        print(f"{falhas} criterio(s) falharam")
        return 1
    print(f"casa da fumaca: {len(CRITERIOS)} criterios, todos passaram")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
