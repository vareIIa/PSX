#!/usr/bin/env python3
"""Criterio de aceite da loja de conveniencia.

Roda a rotina TesteMercado dentro do jogo e confere cada numero. O que da para
afirmar objetivamente:

  cidade    existem portas de loja na rua, com fachada, letreiro, porta
            deslizante e o portao da garagem ao lado dela, sem ter engolido as
            portas de casa e de apartamento
  loja      a planta monta, tem as superficies que definem uma loja, colisao em
            movel, as luzes, ponto de save e mercadoria
  servico   garagem, corredor, banheiro e copa existem como superficie, tem as
            tres portas de folha, o portao e o computador do balcao
  planta    cabe uma pessoa em pe nos sete comodos e os quatro vaos de porta
            estao abertos; o vao do portao continua fechado
  balcao    a carteira largada no balcao e a DO CLIENTE que esta ali, abri-la
            arma o leitor, passar no leitor vira a camera e abre o terminal ja
            na ficha daquela pessoa
  terminal  a consulta por CPF no computador do balcao devolve a ficha DAQUELA
            pessoa, com foto, e recusa numero invalido; a busca por nome acha
            quem passou pelo balcao e recusa consulta curta demais
  ambiente  entrar troca o ambiente para o preset da loja, e sair devolve
  saida     a porta automatica tem duas folhas, elas correm, e o jogador volta
            para a posicao de onde entrou; o portao devolve ele AO LADO dela, e
            aparece na calcada nos DOIS eixos, lateral e profundidade

O que nao da para afirmar assim, como se a loja parece uma loja, nao esta aqui:
para isso existe a captura.

    python tools/verificar_mercado.py [--build]
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[mercado\] ([a-z0-9_]+)=(\S+)")
LIMITE_LUZ = re.compile(r"^limits/opengl/max_lights_per_object=(\d+)", re.M)


def teto_de_luzes() -> int:
    """Quantas luzes por objeto o projeto aceita hoje.

    Lido do project.godot, e nao escrito aqui. O numero e uma configuracao do
    renderizador e um criterio de aceite ao mesmo tempo; com ele copiado nos dois
    lugares, baixar a configuracao passaria despercebido e o comodo apagaria sem
    que nenhum teste reclamasse.
    """
    m = LIMITE_LUZ.search((JOGO / "project.godot").read_text(encoding="utf-8"))
    # 8 e o padrao do motor quando a linha nao existe.
    return int(m.group(1)) if m else 8


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
    cmd += ["--", "--fog=leve", "--teste-mercado"]

    print("rodando no %s..." % ("build exportado" if args.build else "editor"))
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=420)
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

    # --- a rua leva ate a loja ---
    exigir("portas_mercado", num("portas_mercado") > 0,
           "nenhuma porta da cidade leva a uma loja")
    exigir("portas_casa", num("portas_casa") > 0,
           "a loja engoliu as portas de casa")
    exigir("portas_apartamento", num("portas_apartamento") > 0,
           "a loja engoliu as portas de apartamento")
    # A loja tem de ser rara: se metade das portas do comercio for loja, deixa
    # de ser um destino e vira paisagem.
    exigir("portas_mercado", num("portas_mercado") < num("portas_apartamento"),
           "ha mais loja que apartamento; a loja deveria ser rara")
    exigir("portas_deslizantes",
           num("portas_deslizantes") == num("portas_mercado"),
           "porta de loja sem folha deslizante, ou deslizante fora da loja")
    exigir("chunks_com_fachada",
           num("chunks_com_fachada") == num("portas_mercado"),
           "ha porta de loja sem letreiro na fachada: da rua nao da para saber "
           "que ali tem loja")
    # O portao e a segunda boca do mesmo lugar. Sem ele desenhado na calcada,
    # sair da garagem por dentro cospe o jogador na frente de uma parede lisa,
    # e nada no console diria nada.
    exigir("chunks_com_portao",
           num("chunks_com_portao") == num("portas_mercado"),
           "ha loja sem o portao da garagem na fachada: a saida de dentro da "
           "garagem daria numa parede")
    # E aqui as duas metades sao amarradas uma na outra. O desenho na calcada e
    # o deslocamento com que a garagem cospe o jogador na rua sao escritos em
    # arquivos diferentes e so precisam concordar no dia em que alguem
    # atravessar o portao. Este par de linhas faz os dois concordarem agora.
    #
    # A conta e o unico jeito de pegar um sinal trocado: com o portao desenhado
    # do lado errado, os dois numeros continuam batendo em MODULO e o jogador
    # sai na frente do predio vizinho.
    desenhado = num("lateral_do_portao", 0.0)
    exigir("lateral_do_portao", abs(desenhado - 5.2) < 0.1,
           f"o portao foi desenhado a {desenhado:.2f} m do eixo da loja, "
           "esperado 5.20 (KitMercado.AFASTAMENTO_PORTAO)")
    # A fachada tem dois eixos e a linha acima so prende um. Sem esta, o portao
    # pode estar no lugar certo da calcada e DENTRO do predio — foi assim que
    # ele passou uma noite inteira invisivel com os 46 numeros verdes.
    fundo = num("profundidade_do_portao", -9.0)
    exigir("profundidade_do_portao", 0.05 < fundo < 0.32,
           f"o portao avanca {fundo:.2f} m sobre a calcada: negativo quer dizer "
           "enterrado atras da parede (nao aparece da rua), e acima de 0.32 ele "
           "passa a frente da vitrine e deixa de ser a boca de servico")

    # --- a loja montada ---
    exigir("entrou", num("entrou") == 1, "o jogador nao chegou a loja")
    # A faixa subiu junto com a planta: a loja passou de 99 para 234 metros
    # quadrados quando ganhou o bloco de servico. O teto continua existindo
    # porque um interior que estoure o orcamento de PS1 engasga a thread de
    # construcao, e ai a porta abre antes de o comodo existir.
    exigir("tris", 3000 <= num("tris") <= 26000,
           f"a loja tem {v.get('tris')} triangulos, fora da faixa esperada")
    exigir("superficies_faltando", num("superficies_faltando") == 0,
           f"faltou superficie que define a loja: {v.get('faltou', '?')}")
    exigir("colisores", num("colisores") >= 40,
           f"so {v.get('colisores')} colisores: gondola ou parede sem colisao e "
           "atravessavel")
    exigir("luzes", num("luzes") == 13,
           f"{v.get('luzes')} luzes, esperado 13: no salao as quatro calhas de "
           "corredor, a do balcao, duas da camara fria e a vitrine quente; nos "
           "fundos a da garagem, a do corredor, o visor da maquina de refri, a "
           "do banheiro e a da copa. Passando de 16 o renderizador de "
           "compatibilidade descarta as ultimas sem avisar")
    # O limite por objeto do renderizador de compatibilidade esta em 16 (ver
    # project.godot). Passando disso, as luzes excedentes somem sem uma linha no
    # console — e o comodo que perde a luz e sempre o ultimo que alguem
    # acrescentou, que e justamente o que a pessoa esta olhando.
    teto = teto_de_luzes()
    exigir("luzes_totais", num("luzes_totais") <= teto,
           f"{v.get('luzes_totais')} fontes de luz no comodo, acima do limite "
           f"de {teto} por objeto configurado em project.godot: as excedentes "
           "serao descartadas em silencio e um comodo inteiro nasce escuro")
    exigir("luzes_totais", num("luzes_totais") >= num("luzes"),
           "ha menos fontes de luz que Lampadas; a conta nao fecha")
    exigir("ponto_de_save", num("ponto_de_save") == 1,
           "a loja nao tem onde salvar; e o unico lugar seguro do bairro")
    exigir("itens", num("itens") >= 4,
           "a loja nao tem mercadoria para levar, ou o deposito ficou sem a "
           "dele, que e o premio de ter atravessado a porta do caixa")
    exigir("pegou_da_prateleira", num("pegou_da_prateleira") == 1,
           "pegar item da prateleira nao pos nada na bolsa")

    # --- o bloco de servico ---
    exigir("servico_faltando", num("servico_faltando") == 0,
           f"faltou superficie dos fundos: {v.get('faltou_servico', '?')}. Sem "
           "elas o bloco de servico e uma sala cinza, e nao a coxia da loja")
    exigir("portas_batente", num("portas_batente") == 3,
           f"{v.get('portas_batente')} portas de folha, esperado 3: a de "
           "servico atras do caixa, a do banheiro e a da copa")
    exigir("portao_garagem", num("portao_garagem") == 1,
           "a garagem nao tem portao para a rua")
    exigir("computador", num("computador") == 1,
           "o balcao nao tem computador para consultar CPF")

    # --- a planta e caminhavel ---
    # Estas tres sao as unicas medidas do arquivo que provam que os comodos sao
    # LUGARES. Todo o resto conta objeto; estas andam.
    exigir("pousos_ocupados", num("pousos_ocupados") == 0,
           f"nao cabe uma pessoa em pe em: {v.get('ocupado', '?')}")
    exigir("travessias_fechadas", num("travessias_fechadas") == 0,
           f"vao de porta bloqueado em: {v.get('travessia_fechada', '?')}")
    exigir("portao_barra", num("portao_barra") == 1,
           "o vao do portao esta aberto por colisao: o jogador anda para fora "
           "da planta, e do outro lado nao ha cidade nenhuma")

    # --- o atendimento no balcao ---
    exigir("balcao_tem_carteira", num("balcao_tem_carteira") == 1,
           "nao ha identidade largada no balcao")
    exigir("balcao_tem_leitor", num("balcao_tem_leitor") == 1,
           "o balcao nao tem leitor de codigo")
    exigir("balcao_tem_luz", num("balcao_tem_luz") == 1,
           "o leitor nao tem luz vermelha; sem ela o aparelho nao responde nada")
    exigir("gente_no_balcao", num("gente_no_balcao") >= 2,
           "falta gente no caixa: o atendente e o cliente")
    # Esta e a linha que justifica o teste inteiro. As duas pessoas — o corpo em
    # pe no balcao e a carteira em cima dele — saem de `id_de_faixa` chamado em
    # arquivos diferentes, combinados so por convencao. Divergindo, o balcao
    # continua funcionando e passa a mostrar a carteira de um desconhecido.
    exigir("carteira_e_de_quem_esta_ali",
           num("carteira_e_de_quem_esta_ali") == 1,
           "a identidade em cima do balcao nao e de ninguem que esta ali: a "
           "semente do cliente e a da carteira divergiram")
    exigir("leitor_comeca_travado", num("leitor_comeca_travado") == 1,
           "o leitor aceita ser acionado com o balcao vazio; a ordem do gesto "
           "deixa de existir")
    exigir("carteira_abriu_documento", num("carteira_abriu_documento") == 1,
           "acionar a identidade nao abriu a carteira em tela cheia")
    exigir("leitor_armou", num("leitor_armou") == 1,
           "fechar a carteira nao armou o leitor")
    exigir("leitor_abriu_terminal", num("leitor_abriu_terminal") == 1,
           "passar no leitor nao abriu o terminal")
    exigir("terminal_veio_com_o_cliente",
           num("terminal_veio_com_o_cliente") == 1,
           "o terminal abriu na ficha de OUTRA pessoa depois da leitura")
    # A camera tem de VIRAR. Sem esta, o terminal abriria por cima do balcao e o
    # monitor viraria uma tela em vez de um objeto em cima da bancada.
    exigir("camera_virou", num("camera_virou") > 10.0,
           f"a camera girou {v.get('camera_virou')} graus ao ler o documento: "
           "ela nao chegou a se virar para o monitor")
    # O caminho em que o terminal recusa abrir. A sequencia trava o jogador para
    # virar a camera; se o terminal nao vem, quem travou tem de destravar. Sem
    # esta linha o defeito e invisivel — nada estoura, nada aparece no console, e
    # o jogador simplesmente para de responder.
    exigir("leitor_recusado_abriu_terminal",
           num("leitor_recusado_abriu_terminal") == 0,
           "o terminal abriu por cima da carteira em tela cheia")
    exigir("leitor_recusado_nao_travou",
           num("leitor_recusado_nao_travou") == 1,
           "o jogador ficou TRAVADO quando o terminal recusou abrir: nao ha "
           "tecla que resolva isso, e a partida acabou ali")

    # --- consulta de CPF no balcao ---
    exigir("terminal_abriu", num("terminal_abriu") == 1,
           "o computador do balcao nao abriu")
    exigir("terminal_consultou", num("terminal_consultou") == 1,
           "o terminal nao achou o CPF de alguem que existe no registro")
    exigir("terminal_ficha_confere", num("terminal_ficha_confere") == 1,
           "o terminal abriu a ficha de OUTRA pessoa: o CPF deixou de ser o "
           "endereco do registro")
    exigir("terminal_mesma_mae", num("terminal_mesma_mae") == 1,
           "a filiacao do terminal nao bate com a do registro civil")
    exigir("terminal_tem_foto", num("terminal_tem_foto") == 1,
           "a ficha veio sem foto: sem ela nao da para reconhecer na tela quem "
           "se encontrou na rua, que e o proposito da consulta")
    exigir("terminal_recusa_invalido", num("terminal_recusa_invalido") == 1,
           "o terminal aceitou um CPF invalido; a consulta perde o unico "
           "atrito que ela tem")
    exigir("terminal_vinculos", num("terminal_vinculos") >= 1,
           "a tela de vinculos nao tem ninguem no mesmo endereco")
    exigir("terminal_fechou", num("terminal_fechou") == 1,
           "o terminal nao fechou e o jogador ficou preso nele")

    # --- busca por nome ---
    exigir("busca_por_nome_acha", num("busca_por_nome_acha") == 1,
           "procurar pelo primeiro nome do cliente que esta no balcao nao acha "
           "o cliente que esta no balcao")
    exigir("busca_por_nome_curta_recusa",
           num("busca_por_nome_curta_recusa") == 1,
           "a busca aceitou duas letras; com esse tamanho ela casa com meia "
           "cidade e a lista deixa de ser uma resposta")
    exigir("busca_por_nome_invento", num("busca_por_nome_invento") == 1,
           "a busca por nome devolveu gente para um nome que nao existe")

    # --- saida pelo portao da garagem ---
    exigir("portao_folha_subiu", num("portao_folha_subiu") == 1,
           "a folha do portao nao subiu ao abrir")
    exigir("saiu_pelo_portao", num("saiu_pelo_portao") == 1,
           "acionar o portao nao levou o jogador para a rua")
    # AO LADO, e nao "a alguma distancia". A medida e no referencial da fachada
    # justamente porque um sinal trocado poria o jogador dentro do predio
    # vizinho com a mesma distancia absoluta.
    lateral = num("portao_lateral", 0.0)
    esperado = 6.06  # Porta.FOLHA_LARGURA + KitMercado.AFASTAMENTO_PORTAO
    exigir("portao_lateral", abs(lateral - esperado) < 0.6,
           f"o portao devolveu o jogador a {lateral:.2f} m de lado, esperado "
           f"{esperado:.2f}: ele nao saiu na frente do portao desenhado na rua")
    # A amarracao final: onde o jogador cai menos a meia folha da porta tem de
    # ser onde o portao foi desenhado. Sao dois caminhos independentes ate o
    # mesmo ponto da calcada.
    if "lateral_do_portao" in v and "portao_lateral" in v:
        folga = abs((lateral - 0.86) - num("lateral_do_portao", 0.0))
        exigir("portao_lateral", folga < 0.6,
               f"o jogador sai {folga:.2f} m longe do portao que a rua desenhou")
    exigir("portao_afastou", 0.4 < num("portao_afastou", 0.0) < 2.6,
           "o jogador nao saiu para a calcada ao atravessar o portao")
    exigir("portao_queda", abs(num("portao_queda", 99.0)) < 1.5,
           "o jogador saiu do portao no ar e caiu longe demais")
    exigir("reentrou", num("reentrou") == 1,
           "nao deu para voltar a loja depois de sair pelo portao")

    # --- ambiente ---
    if v.get("ambiente") != "mercado":
        erros.append(f"o ambiente da loja e '{v.get('ambiente')}', esperado "
                     "'mercado': a luz branca e chapada e metade do comodo")
    if v.get("ambiente_apos_sair") == "mercado":
        erros.append("sair da loja nao devolveu o ambiente da rua")

    # --- porta automatica ---
    exigir("porta_automatica", num("porta_automatica") == 1,
           "a saida da loja nao e porta automatica")
    exigir("folhas", num("folhas") == 2,
           f"a porta automatica tem {v.get('folhas')} folhas, esperado 2")
    exigir("folha_correu", num("folha_correu") == 1,
           "as folhas nao correram ao abrir")
    exigir("saiu", num("saiu") == 1, "o jogador nao saiu da loja")
    exigir("desvio_no_plano", num("desvio_no_plano", 99.0) < 0.4,
           "o jogador nao voltou para a posicao de onde entrou")
    exigir("queda", abs(num("queda", 99.0)) < 1.5,
           "o jogador voltou no ar e caiu longe demais")

    if erros:
        print("\nFALHOU")
        for e in erros:
            print("  x", e)
        return 1

    print(f"\nOK — {len(v) - 2} medidas; cidade, salao, bloco de servico, "
          "caminhabilidade, atendimento no balcao, consulta por CPF e por "
          "nome, ambiente e as duas saidas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
