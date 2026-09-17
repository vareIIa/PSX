#!/usr/bin/env python3
"""Criterio de aceite da gente da cidade.

Roda a rotina TesteNpc dentro do jogo e confere cada numero. O que da para
afirmar objetivamente:

  registro  o CPF e uma funcao invertivel do id, sem um unico erro em milhares
            de casos, e numero inventado e recusado. E a afirmacao que sustenta
            o sistema inteiro: se a inversa errar, a consulta devolve a ficha de
            OUTRA pessoa e ninguem percebe
  familia   toda casa tem oito moradores com papel, o filho e mais novo que o
            chefe, e a filiacao dele cita gente que mora ali
  corpo     uma pessoa e UMA malha e UM osso por vertice, dentro do teto de
            triangulos, e o ciclo de caminhada tem exatamente quinze poses
  falas     nenhum marcador de costura sobra na tela, toda conversa termina em
            VER IDENTIDADE, e o rotulo esconde o nome ate a pessoa dize-lo
  rua       gente nasce, anda, fica no chao e nao repete ficha
  ciclo     abordar, conversar, ver o documento, consultar o CPF no celular e
            achar os vinculos — o laco inteiro do pedido, de ponta a ponta
  calcada   a linha por onde a multidao anda esta desimpedida de ponta a ponta
  criacao   o que o jogador escolhe chega no corpo e sobrevive ao save
  custo     cada pessoa a mais custa uma chamada de desenho, e nao dez

O que nao da para afirmar assim, como se a pessoa PARECE uma pessoa, nao esta
aqui: para isso existe a captura.

    python tools/verificar_npc.py [--build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[npc\] ([a-z0-9_]+)=(\S+)")

## Teto de triangulos de um personagem. ART-BIBLE secao 10.
TETO_TRIANGULOS = 900
## Ossos por rig. ART-BIBLE secao 10.
TETO_OSSOS = 24


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
    cmd += ["--", "--fog=leve", "--teste-npc"]

    print("rodando no %s..." % ("build exportado" if args.build else "editor"))
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    saida = r.stdout + r.stderr

    v: dict[str, str] = {}
    for m in LINHA.finditer(saida):
        v[m.group(1)] = m.group(2)

    if "fim" not in v:
        print("a rotina nao chegou ao fim; saida do motor:")
        print(saida[-1800:])
        return 1

    for chave in sorted(v):
        print(f"{chave:28s} {v[chave]}")

    erros: list[str] = []

    def num(chave: str, padrao: float = -1.0) -> float:
        try:
            return float(v.get(chave, padrao))
        except ValueError:
            return padrao

    def exigir(chave: str, cond: bool, msg: str) -> None:
        if chave not in v:
            erros.append(f"{chave} nao foi reportado")
        elif not cond:
            erros.append(msg)

    # --- registro civil ---
    exigir("cpf_ida_volta_erros", num("cpf_ida_volta_erros") == 0,
           "o CPF nao volta ao mesmo id: a consulta devolve a ficha errada")
    exigir("rg_ida_volta_erros", num("rg_ida_volta_erros") == 0,
           "o RG nao volta ao mesmo id")
    exigir("cpf_formato_ok", num("cpf_formato_ok") == num("cpf_amostra"),
           "ha CPF com numero de digitos errado")
    exigir("cpf_ao_acaso_aceitos",
           num("cpf_ao_acaso_aceitos") <= num("cpf_ao_acaso_testados") * 0.02,
           "numero inventado esta sendo aceito demais: o verificador nao vale")
    exigir("ficha_determinista", num("ficha_determinista") == 1,
           "a mesma pessoa sai diferente na segunda consulta")

    # --- familia ---
    exigir("vinculos_completos", num("vinculos_completos") == num("casas"),
           "ha domicilio sem os oito moradores")
    exigir("filiacao_ligada", num("filiacao_ligada") >= 100,
           "a filiacao dos filhos nao cita quem mora na casa")
    exigir("idades_impossiveis", num("idades_impossiveis") == 0,
           "ha idade impossivel no registro, ou filho mais velho que o pai")
    exigir("falecidos_no_registro", num("falecidos_no_registro") >= 1,
           "ninguem no registro esta falecido: a consulta nunca surpreende")
    exigir("enderecos_distintos", num("enderecos_distintos") >= 100,
           "os enderecos se repetem: a cidade toda mora no mesmo lugar")

    # --- aparencia ---
    exigir("silhuetas_distintas", num("silhuetas_distintas") >= 120,
           "pouca variacao de silhueta: a rua vira fila de clones")
    exigir("tons_de_pele", num("tons_de_pele") >= 5, "poucos tons de pele")
    exigir("alturas_de_voz", num("alturas_de_voz") >= 8,
           "todo mundo fala na mesma altura")
    exigir("com_casaco", num("com_casaco") >= 20, "ninguem usa casaco")
    exigir("com_saia", num("com_saia") >= 5, "ninguem usa saia")
    exigir("atlas_existe", num("atlas_existe") == 1, "atlas de personagem ausente")
    exigir("atlas_lado", num("atlas_lado") == 256,
           "o atlas nao tem 256 px: ART-BIBLE secao 4")

    # --- corpo ---
    exigir("corpo_triangulos", num("corpo_triangulos") <= TETO_TRIANGULOS,
           f"personagem com {num('corpo_triangulos'):.0f} triangulos, acima do "
           f"teto de {TETO_TRIANGULOS}")
    exigir("corpo_ossos", 0 < num("corpo_ossos") <= TETO_OSSOS,
           f"rig acima do teto de {TETO_OSSOS} ossos")
    exigir("corpo_malhas", num("corpo_malhas") == 1,
           "uma pessoa esta virando mais de uma malha: dez na tela estouram o "
           "teto de draw call sozinhas")
    exigir("poses_por_ciclo", num("poses_por_ciclo") == 15,
           "o ciclo de caminhada nao tem quinze poses: perdeu a quantizacao e "
           "passou a ler como animacao moderna")
    exigir("poses_parado", num("poses_parado") >= 5,
           "parado o corpo nao respira: le como manequim")
    exigir("retrato_largura", num("retrato_largura") == 40, "retrato sem largura")
    exigir("retrato_cores", num("retrato_cores") >= 40,
           "o retrato saiu chapado: a foto do documento nao tem imagem")

    # --- falas ---
    exigir("personalidades", num("personalidades") >= 10,
           "menos de dez personalidades: as conversas se repetem rapido")
    exigir("falas_marcador_solto", num("falas_marcador_solto") == 0,
           "sobrou marcador {campo} no texto que vai para a tela")
    exigir("falas_distintas", num("falas_distintas") >= 120,
           "pouca variedade de fala")
    exigir("opcoes_erradas", num("opcoes_erradas") == 0,
           "ha conversa com numero de opcoes errado")
    exigir("opcoes_fora_do_papel", num("opcoes_fora_do_papel") == 0,
           "ha conversa com mais opcoes do que a folha desenha: a que sobra "
           "nao aparece na tela e nada avisa")
    exigir("ultima_opcao_documento", num("ultima_opcao_documento") >= 20,
           "nem toda conversa termina em VER IDENTIDADE")
    exigir("rotulo_anonimo", num("rotulo_anonimo") == 1,
           "o nome aparece antes de a pessoa dizer o nome")
    exigir("rotulo_nomeado", num("rotulo_nomeado") == 1,
           "o nome nao aparece nem depois de a pessoa dizer o nome")

    # --- rotas ---
    exigir("rotas_travadas", num("rotas_travadas") == 0,
           "a malha de calcada tem beco sem saida")
    exigir("rotas_dentro_da_quadra", num("rotas_dentro_da_quadra") == 0,
           "ha ponto de caminhada dentro de uma quadra: gente atravessando predio")
    exigir("trechos_na_coroa", num("trechos_na_coroa") >= 5,
           "nao ha calcada onde fazer gente nascer")
    exigir("trechos_montados", num("trechos_montados") >= 1,
           "nenhum trecho de nascimento tem chunk montado")

    # --- audio ---
    exigir("amostras_de_voz", num("amostras_de_voz") == 16,
           "faltam amostras de voz")
    exigir("sons_de_celular", num("sons_de_celular") == 5,
           "faltam sons do aparelho")

    # --- rua ---
    exigir("pedestres_vivos", num("pedestres_vivos") >= 3,
           "a rua de comercio nao se povoou")
    exigir("pedestres_distintos",
           num("pedestres_distintos") == num("pedestres_vivos"),
           "duas pessoas com a mesma ficha andando ao mesmo tempo")
    # A multidao esta viva ou congelada?
    #
    # Contar quem andou mais de um passo nao responde isso: parar E
    # comportamento — descansar na esquina, parar para conversar com outra
    # pessoa, contornar quem vem em sentido contrario. Exigir que todos andem em
    # toda janela de tres segundos e exigir que ninguem faca nada disso, e o
    # criterio reprovava um sistema certo em uma execucao a cada duas.
    #
    # As duas medidas abaixo respondem de verdade:
    #
    #   distancia media   a rua anda, mesmo com gente parada no meio dela
    #   travados          ninguem esta imovel SEM MOTIVO. Cada pessoa imovel tem
    #                     de ser explicada por um estado parado — conversa,
    #                     descanso, atendimento — com uma unidade de folga para
    #                     quem parou dentro da janela de medicao.
    exigir("pedestre_andou", num("pedestre_andou") >= 1,
           "ninguem na rua deu um passo em tres segundos")
    exigir("pedestre_dist_media", num("pedestre_dist_media") >= 0.4,
           "a rua andou menos de meio metro por pessoa em tres segundos: a "
           "multidao esta travando uma na outra")
    # -1 quer dizer que ninguem na rua tinha idade para ser julgado.
    if num("pedestre_fracao_travada") >= 0.0:
        exigir("pedestre_fracao_travada", num("pedestre_fracao_travada") < 0.4,
               "ha pedestre veterano que passou boa parte da vida andando "
               "contra alguma coisa, e a multidao nao o recolheu")
    exigir("pedestres_retirados", num("pedestres_retirados") <= 6,
           "gente demais desistindo de andar: a calcada virou armadilha")

    # A linha de marcha tem de estar limpa. E o criterio que pegou a fileira de
    # predios construida por cima da calcada: a massa era invisivel da rua, so a
    # colisao dela existia, e um terco das calcadas da cidade era intransponivel
    # sem que nenhuma captura mostrasse nada de errado.
    if num("calcada_amostras") > 0:
        exigir("calcada_bloqueada",
               num("calcada_bloqueada") <= num("calcada_amostras") * 0.05,
               "a linha por onde os pedestres andam esta obstruida: ha coisa "
               "solida em cima da calcada")
    exigir("pedestre_sem_chao", num("pedestre_sem_chao") == 0,
           "ha pedestre sem chao embaixo: alguem esta fora do bairro montado")
    exigir("pedestre_desnivel_pior", num("pedestre_desnivel_pior", 9.0) < 0.5,
           "ha gente flutuando ou enterrada na calcada")

    # Conversa entre NPCs. -1 quer dizer que nao havia dois na rua para testar,
    # o que acontece em distrito de pouco movimento e nao e defeito.
    if num("conversa_entre_npcs") >= 0:
        exigir("conversa_entre_npcs", num("conversa_entre_npcs") == 2,
               "dois pedestres postos a conversar nao pararam")
        exigir("npcs_se_encaram", num("npcs_se_encaram") == 2,
               "os dois conversam de costas um para o outro")
        exigir("conversa_de_rua_terminou", num("conversa_de_rua_terminou") == 1,
               "a conversa entre pedestres nao acaba: eles ficam parados para "
               "sempre no meio da calcada")

    # --- o laco inteiro do pedido ---
    exigir("conversa_abriu", num("conversa_abriu") == 1,
           "apertar E numa pessoa nao abre conversa")
    exigir("conversa_opcoes", num("conversa_opcoes") == 7,
           "a conversa nao oferece os assuntos (sete desde que contratar "
           "servicos entrou na lista de toda pessoa da cidade)")
    exigir("conversa_nomeou", num("conversa_nomeou") == 1,
           "perguntar o nome nao registra que a pessoa se apresentou")
    exigir("documento_abriu", num("documento_abriu") == 1,
           "VER IDENTIDADE nao abre a carteira")
    exigir("conversa_fechou", num("conversa_fechou") == 1,
           "a conversa nao fecha e o jogador fica travado")
    exigir("agenda", num("agenda") >= 2,
           "quem foi abordado nao entra na agenda do celular")
    exigir("celular_abriu", num("celular_abriu") == 1, "o celular nao abre")
    exigir("jogador_tem_ficha", num("jogador_tem_ficha") == 1,
           "o jogador nao tem identidade propria")
    exigir("jogador_tem_documento", num("jogador_tem_documento") == 1,
           "a carteira do jogador nao esta no inventario")
    exigir("consulta_propria", num("consulta_propria") == 1,
           "o portal nao aceita o CPF do proprio jogador")
    exigir("consulta_invalida", num("consulta_invalida") == 1,
           "o portal aceita CPF invalido")
    exigir("consulta_de_terceiro", num("consulta_de_terceiro") == 1,
           "o portal nao acha pelo CPF alguem que esta na rua")
    exigir("vinculos_de_terceiro", num("vinculos_de_terceiro") == 7,
           "a consulta nao devolve a familia de quem foi consultado")

    # --- criacao de personagem ---
    exigir("ajustes_disponiveis", num("ajustes_disponiveis") >= 10,
           "a tela de criacao tem menos de dez controles")
    exigir("ajustes_iniciais", num("ajustes_iniciais") >= 10,
           "a tela nao abre com a pessoa sorteada: o jogador teria de montar "
           "tudo do zero")
    exigir("ajuste_pegou_rosto", num("ajuste_pegou_rosto") == 1,
           "trocar de rosto na criacao nao muda a aparencia")
    exigir("ajuste_pegou_altura", num("ajuste_pegou_altura") == 1,
           "o controle de altura nao chega no corpo")
    exigir("ajuste_pegou_chapeu", num("ajuste_pegou_chapeu") == 1,
           "escolher chapeu nao poe chapeu")
    exigir("corpo_altura_gordo",
           num("corpo_altura_gordo") - num("corpo_altura_magro") > 0.3,
           "os dois extremos do controle de altura dao corpos do mesmo tamanho")
    exigir("corpo_tris_gordo", num("corpo_tris_gordo") <= TETO_TRIANGULOS,
           "o corpo no extremo do controle passa do teto de triangulos")
    exigir("aparencia_sobrevive_ao_save",
           num("aparencia_sobrevive_ao_save") == 1,
           "a aparencia escolhida nao volta igual depois de salvar e carregar")

    # --- custo ---
    # O que importa e o custo POR PESSOA. O total inclui a cidade inteira, que
    # ja existia antes da multidao e nao e responsabilidade dela.
    exigir("draw_calls_por_pessoa", num("draw_calls_por_pessoa") <= 2.0,
           "cada pessoa esta custando mais de duas chamadas de desenho: a pele "
           "parou de fundir o corpo numa malha so")

    print()
    if erros:
        print("FALHOU")
        for e in erros:
            print("  x", e)
        return 1
    print("OK — %d medidas" % len(v))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
