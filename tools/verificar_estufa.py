#!/usr/bin/env python3
"""Criterio de aceite da estufa: o cultivo, a folha de pagamento e os dois que
trabalham la dentro.

Roda a rotina TesteEstufa dentro do jogo, com fisica e com os autoloads de
verdade, e confere cada numero. O que da para afirmar objetivamente:

  sala        vinte e quatro vasos em DUAS malhas, e nao vinte e quatro nos
  ciclo       vazio -> terra -> semente -> agua -> tempo -> colheita, pelo
              caminho do jogador: mochila, rotulo e tecla de interagir
  agua        a planta cresce molhada e NAO cresce seca
  terra       aguenta tres colheitas e acaba
  memoria     sair pela porta e voltar devolve a mesma estufa
  ausencia    sem ninguem contratado o tempo so seca; com gente, o trabalho
              acontece, e acontece em passo de gente
  gente       Jota e Helmer estao la, estao na folha, trabalham, e nenhum osso
              deles atravessa o piso
  contrato    a aba de servicos contrata, nao duplica e dispensa
  fala        o fazendeiro diz um numero que confere com a sala

O que nao da para afirmar assim — se a estufa PARECE uma estufa — nao esta
aqui: para isso existem as capturas em captures/estufa.

    python tools/verificar_estufa.py
"""

import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[estufa\] ([a-z0-9_]+)=(\S+)")

# chave -> (esperado, por que importa)
#
# Cada linha aqui e um defeito que um sistema de cultivo tem por padrao ate
# alguem provar que nao. Nenhuma delas e "parece certo".
CRITERIOS: dict[str, tuple[str, str]] = {
    "inicio": ("1", "a rotina comeca"),
    "entrou_na_estufa": ("1", "a porta dos fundos leva a estufa"),

    # --- a sala ---
    "vasos": ("352", "24 na lavoura (seis linhas de quatro) e 41 em cada uma "
                     "das oito galerias, uma variedade por andar"),
    "potes": ("9", "a prateleira que enche e o placar da sala"),
    "malhas": ("30", "a plantacao e agrupada por fileira da lavoura e por "
                     "galeria, cada grupo com opaco, folhagem e recorte, e a "
                     "galeria so desenha perto (13 m). Uma malha por vaso "
                     "seriam 352 chamadas de desenho numa sala so. As duas a "
                     "mais sao a vitrine do deposito, que existe mesmo sem "
                     "estoque: a rafia dos sacos e os palitos das plaquinhas"),
    "areas": ("396", "352 vasos, as quatro estacoes da lavoura (terra, semente, "
                     "tanque, prateleira), as quatro de cada galeria (terra, "
                     "semente, tanque, caixote da variedade) e os oito sacos abertos "
                     "da vitrine do deposito"),
    "plantacao_nos": ("1", "uma plantacao por comodo"),
    "corredor_chega_ao_fundo": ("1",
                                "o corredor esta livre da soleira ate a parede "
                                "do fundo. A captura da entrada faz a sala "
                                "parecer ter sete metros; nevoa e queda de luz "
                                "encurtam qualquer corredor, e olhar a imagem "
                                "nao distingue isso de uma parede atravessada "
                                "no meio"),
    "vazios_no_inicio": ("8", "as duas ultimas linhas nascem vazias: e o "
                              "convite, e sem vaso vazio na sala o sistema "
                              "inteiro fica invisivel. Oito e nao doze: com "
                              "metade da sala vazia a estufa le como abandonada"),

    # --- o ciclo, pelo caminho do jogador ---
    "rotulo_sem_terra": ("1", "o vaso DIZ o que falta; e o unico tutorial"),
    "ciclo_sem_terra": ("1", "e sem terra na mochila nao acontece nada"),
    "saco_deu_terra": ("4", "a estacao de insumos abastece"),
    "rotulo_com_terra": ("1", "e com terra o rotulo vira a acao"),
    "ciclo_vazio_terra": ("1", "vazio -> terra"),
    "gastou_terra": ("1", "e a terra sai da mochila. Sem isto o saco e infinito "
                          "e a estacao de insumos nao existe"),
    "ciclo_terra_semente": ("1", "terra -> semeado"),
    "pegou_regador": ("1", "o regador esta pendurado no tanque"),
    "ciclo_semente_agua": ("1", "semeado -> crescendo, na primeira rega"),
    "regador_gastou": ("1", "e a rega gasta uma carga das seis"),

    # --- a agua, que e a regra central ---
    "cresceu_com_agua": ("1", "o tempo empurra a planta molhada"),
    "agua_acabou": ("1", "a rega dura oito minutos de relogio e acaba"),
    "uma_rega_nao_fecha_o_ciclo": ("1",
                                   "e paga oito dos doze minutos do ciclo. A "
                                   "folga e de proposito: sem ela, regar seria "
                                   "um botao apertado uma vez e o fazendeiro "
                                   "ficaria sem o que fazer"),
    "nao_cresceu_seco": ("1",
                         "e a planta seca NAO anda. Se esta falhar, regar nao "
                         "quer dizer nada e o ciclo inteiro e decoracao"),

    # --- colheita ---
    "colheita": ("3", "tres por planta; um pote por planta nunca encheria a "
                      "prateleira"),
    "colheu_volta_pra_terra": ("1", "colher devolve o vaso a terra usada"),
    "terra_envelhece": ("1", "e na terceira colheita a terra acaba. Sem isto a "
                             "estufa e moto-perpetuo e o saco de terra so serve "
                             "uma vez na partida"),
    "pegou_da_prateleira": ("1", "o jogador tira da prateleira para a mochila"),
    "placar_diminuiu": ("1", "e o placar cai junto: a mesma colheita nao pode "
                             "existir nos dois lugares"),

    # --- memoria ---
    "sobreviveu_a_saida": ("1",
                           "sair pela porta e voltar devolve a MESMA estufa. E "
                           "o defeito mais silencioso possivel: nada na tela "
                           "acusa, e o trabalho do jogador some"),
    "colhido_sobreviveu": ("1", "inclusive o que ja estava na prateleira"),

    # --- o trabalho de quem fica ---
    "sem_fazendeiro_colheu": ("0",
                              "sem ninguem na folha, o tempo longe da estufa so "
                              "seca a terra"),
    "com_fazendeiro_colheu": ("1", "com gente contratada, o trabalho acontece"),
    "trabalho_limitado": ("1",
                          "e acontece em passo de gente. Sem teto, contratar "
                          "alguem viraria um botao de pular para o fim"),

    # --- Jota e Helmer ---
    "jota": ("1", "JOTA esta na sala e se chama assim"),
    "helmer": ("1", "HELMER tambem"),
    "na_folha": ("2", "e os dois estao na folha de pagamento de verdade, a "
                      "mesma que recebe quem o jogador contratar na rua"),
    "jota_rosto_proprio": ("1",
                           "a cara de Jota vem da linha do elenco, escrita a "
                           "mao, e nao do hash do id: uma pessoa que as vezes "
                           "aparece sem oculos nao e a mesma pessoa"),
    "helmer_rosto_proprio": ("1", "a de Helmer tambem"),
    "elenco_rostos_distintos": ("1",
                                "e sao rostos diferentes. Dois personagens na "
                                "mesma celula seriam um so com dois nomes, e o "
                                "criterio de cima passaria do mesmo jeito"),
    "elenco_perfis_distintos": ("1",
                                "o alargador preto e o vermelho. E o unico "
                                "traco que aparece de perfil, e de perfil e "
                                "como o jogador mais os ve na estufa"),
    "jota_mais_alto": ("1", "Jota e o alto, e so e o alto ao lado de Helmer"),
    "jota_tatuado": ("1", "espinhos no pescoco, no antebraco e na mao"),
    "jota_coque": ("1", "cabelo longo preso em coque"),
    "helmer_cacheado": ("1", "e o de Helmer e cacheado"),
    "elenco_cabelos_distintos": ("1",
                                 "e os dois penteados nao se confundem: um tem "
                                 "o que o outro nao tem, nos dois sentidos"),
    "coque_e_geometria": ("1",
                          "o coque acrescenta caixas ao corpo. Marcar a chave "
                          "na tabela nao prova nada: se o Corpo deixasse de ler "
                          "`coque`, a ficha continuaria dizendo que ele tem e o "
                          "boneco sairia de cabelo solto"),
    "cacho_e_geometria": ("1",
                          "e o cacho acrescenta os seis tufos. Cacho e "
                          "SILHUETA: textura cacheada dentro de uma calota lisa "
                          "continua lendo como capacete a quinze metros"),
    "helmer_sem_tatuagem": ("1", "e Helmer nao tem: e traco de um so"),
    "elenco_na_identidade": ("1",
                             "a carteira dele mostra a mesma cara do corpo na "
                             "sala. As duas saem de RegistroCivil.identidade; "
                             "aplicar o personagem so ao criar o no daria uma "
                             "cara na estufa e outra no documento"),
    "elenco_apelido_na_ficha": ("1", "e o nome vem junto, da mesma fonte"),
    "elenco_depois_da_porta": ("2",
                               "sair e voltar devolve os dois, e nao dois "
                               "desconhecidos com o nome deles"),
    "pe_abaixo_do_piso": ("0",
                          "a postura TRABALHANDO e nova, e pose nova nao medida "
                          "nao vale: a de sentado punha o pe 3 cm dentro do "
                          "chao e ninguem viu por duas fases"),
    "viu_alguem_trabalhando": ("1", "eles entram na postura de trabalho"),
    "fazendeiro_mexeu": ("1",
                         "e mexem em alguma coisa. Um fazendeiro contratado que "
                         "nao trabalha parece um NPC normal, e nada acusaria"),

    # --- contratar ---
    "servicos_na_rua": ("1", "a aba aparece com qualquer pessoa da cidade"),
    "servicos_no_volante": ("0",
                            "menos com quem esta sendo tirado do proprio carro"),
    "contratou": ("1", "contratar registra"),
    "folha_cresceu": ("1", "e entra na folha"),
    "profissao_gravada": ("1", "e na pessoa"),
    "nao_duplica": ("1", "contratar duas vezes nao abre duas vagas"),
    "aba_mostra_dispensar": ("1", "quem ja trabalha ve DISPENSAR no lugar"),
    "demitiu": ("1", "e dispensar desfaz"),
    "folha_voltou": ("1", "nos dois lugares"),

    # --- a fala que le o mundo ---
    "plantio_na_estufa": ("1", "o assunto da plantacao existe na estufa"),
    "plantio_na_rua": ("0", "e nao vaza para a calcada"),
    "fala_diz_o_numero": ("1",
                          "o fazendeiro diz quantos vasos estao prontos, e o "
                          "numero e o de verdade: o jogador pode andar ate la e "
                          "contar"),
    "de_fora_nao_sabe": ("1",
                         "e quem nao e da estufa nao sabe. Sem isto, contratar "
                         "alguem nao muda nada no que a pessoa diz"),

    # --- a folha de assuntos ---
    "lista_cabe": ("1",
                   "nenhuma conversa tem mais opcoes do que a folha desenha. "
                   "Dentro da casa da fumaca eram SETE numa folha de seis, e a "
                   "setima era VER IDENTIDADE: nao aparecia, e nada avisava"),

    "fim": ("1", "a rotina chegou ao fim"),
}


def main() -> int:
    if not GODOT.exists():
        print(f"binario ausente: {GODOT}")
        return 2
    saida = subprocess.run(
        [str(GODOT), "--path", str(JOGO), "--", "--teste-estufa"],
        capture_output=True, text=True, timeout=600)
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
    for chave in ("gente_na_estufa", "prontas_no_inicio", "placar_antes",
                  "placar_depois", "colhido_depois", "vaso_marcado_depois",
                  "maconha_antes", "maconha_depois", "corredor_livre_cm",
                  "jota_altura_cm", "helmer_altura_cm", "tris_cabelo_liso",
                  "tris_com_coque", "tris_com_cacho",
                  "triangulos_comodo", "malhas_do_comodo",
                  "triangulos_plantacao", "osso_mais_baixo_cm",
                  "cresceu_quanto_mil", "colheu_quanto", "potes_cheios",
                  "opcoes_rua", "opcoes_casa", "opcoes_estufa",
                  "opcoes_volante", "maior_lista"):
        if chave in lidos:
            print(f"  .     {chave} = {lidos[chave]}")

    print()
    if falhas:
        print(f"{falhas} criterio(s) falharam")
        return 1
    print(f"estufa: {len(CRITERIOS)} criterios, todos passaram")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
