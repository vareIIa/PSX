#!/usr/bin/env python3
"""Criterio de aceite da loja de conveniencia (PLANO_MERCADO_AAA, F1).

Roda a rotina TesteMercado duas vezes dentro do jogo e confere cada numero.

  NA RUA (padrao)
    cidade    as lojas existem na rua, nenhuma e teleportada, o lote de cada
              uma nao e invadido por muro nem predio, e a fileira da face da
              loja fecha de ponta a ponta nas lojas todas do raio
    chegada   a loja monta antes de o jogador chegar, a porta automatica ABRE
              SOZINHA para quem anda ate ela e o teste passa pela soleira ate a
              camara fria sem teleporte, sem cortina, sem salto e sem empacar
    loja      planta, superficies, colisao, luzes, save, pousos e vaos
    gente     o cliente vem da calcada, entra PELA PORTA e chega ao caixa sem
              ajuda (F0); o atendente fica no posto
    balcao    a carteira no tampo e a do cliente, o leitor abre o terminal na
              ficha dele, e a recusa do terminal nao prende o jogador
    portao    a botoeira sobe o portao de aco do predio e o jogador sai andando
              pela garagem para a calcada

  TELEPORTADO (--teleporte, a loja da abertura)
    a mesma planta com a frente fosca, o portao fechado barrando o vao, o
    portao que devolve o jogador na calcada a CENTRO_PORTA - EIXO_PORTAO
    metros da porta, e a porta automatica de saida

O que nao da para afirmar assim, como se a loja parece uma loja, nao esta aqui:
para isso existe a captura (captures/mercado_aaa/f1, quando roda com janela).

    python tools/verificar_mercado.py [--build]
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
# GODOT no ambiente serve a quem roda de uma worktree, que nao tem o .tools/.
GODOT = Path(os.environ.get("GODOT", RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"))
JOGO = RAIZ / "game"

LINHA = re.compile(r"\[mercado\] ([a-z0-9_]+)=(\S+)")
LIMITE_LUZ = re.compile(r"^limits/opengl/max_lights_per_object=(\d+)", re.M)
CONSTANTE = re.compile(r"^const ([A-Z_]+) := ([0-9.]+)$", re.M)


def teto_de_luzes() -> int:
    """Quantas luzes por objeto o projeto aceita hoje, lido do project.godot."""
    m = LIMITE_LUZ.search((JOGO / "project.godot").read_text(encoding="utf-8"))
    return int(m.group(1)) if m else 8


def constantes_da_planta() -> dict[str, float]:
    """As medidas do MercadoBuilder, lidas do arquivo e nao copiadas aqui."""
    texto = (JOGO / "src" / "world" / "mercado_builder.gd").read_text(encoding="utf-8")
    return {m.group(1): float(m.group(2)) for m in CONSTANTE.finditer(texto)}


def rodar(cmd: list[str], extra: list[str]) -> dict[str, str] | None:
    r = subprocess.run(cmd + ["--", "--fog=leve", "--teste-mercado"] + extra,
                       capture_output=True, text=True, timeout=600)
    saida = r.stdout + r.stderr
    v: dict[str, str] = {}
    for m in LINHA.finditer(saida):
        v[m.group(1)] = m.group(2)
    if "fim" not in v:
        print("a rotina nao chegou ao fim; saida do motor:")
        print(saida[-2400:])
        return None
    return v


class Criterio:
    def __init__(self, v: dict[str, str], rotulo: str) -> None:
        self.v = v
        self.rotulo = rotulo
        self.erros: list[str] = []

    def num(self, chave: str, padrao: float = -1.0) -> float:
        try:
            return float(self.v.get(chave, padrao))
        except ValueError:
            return padrao

    def exigir(self, chave: str, cond: bool, msg: str) -> None:
        if chave not in self.v:
            self.erros.append(f"[{self.rotulo}] {chave} nao foi reportado")
        elif not cond:
            self.erros.append(f"[{self.rotulo}] {msg}")

    def um(self, chave: str, msg: str) -> None:
        self.exigir(chave, self.num(chave) == 1, msg)

    def zero(self, chave: str, msg: str) -> None:
        self.exigir(chave, self.num(chave) == 0, msg)


def loja_montada(c: Criterio, teto: int) -> None:
    c.exigir("tris", 3000 <= c.num("tris") <= 26000,
             f"a loja tem {c.v.get('tris')} triangulos, fora da faixa esperada")
    c.zero("superficies_faltando",
           f"faltou superficie que define a loja: {c.v.get('faltou', '?')}")
    c.zero("servico_faltando",
           f"faltou superficie dos fundos: {c.v.get('faltou_servico', '?')}")
    c.exigir("colisores", c.num("colisores") >= 40,
             f"so {c.v.get('colisores')} colisores: movel ou parede atravessavel")
    c.exigir("luzes_totais", c.num("luzes_totais") <= teto,
             f"{c.v.get('luzes_totais')} fontes de luz, acima das {teto} por objeto "
             "do project.godot: as excedentes somem em silencio")
    c.exigir("luzes_totais", c.num("luzes_totais") >= c.num("luzes"),
             "ha menos fontes de luz que Lampadas; a conta nao fecha")
    c.um("ponto_de_save", "a loja nao tem onde salvar")
    c.exigir("portas_batente", c.num("portas_batente") == 4,
             f"{c.v.get('portas_batente')} portas de folha; sao quatro (servico, "
             "banheiro, copa, escritorio)")
    c.um("computador", "o balcao perdeu o computador")
    c.zero("pousos_ocupados",
           f"nao cabe uma pessoa em pe em: {c.v.get('ocupado', '?')}")
    c.zero("travessias_fechadas",
           f"vao de porta fechado: {c.v.get('travessia_fechada', '?')}")


def balcao(c: Criterio) -> None:
    c.um("carteira_e_de_quem_esta_ali",
         "a carteira no balcao nao e de ninguem que esta na loja")
    c.um("compra_no_balcao", "o cliente nao pousou a compra no balcao")
    c.um("carteira_abriu_documento", "a carteira nao abre o documento")
    c.um("leitor_comeca_travado", "o leitor aceita leitura sem carteira")
    c.um("leitor_armou", "fechar a carteira nao armou o leitor")
    c.um("leitor_abriu_terminal", "passar no leitor nao abriu o terminal")
    c.um("terminal_veio_com_o_cliente", "o terminal abriu em outra ficha")
    c.zero("leitor_recusado_abriu_terminal", "o terminal abriu com a carteira na tela")
    c.um("leitor_recusado_nao_travou",
         "a recusa do terminal deixou o jogador preso olhando o monitor")
    for k in ("terminal_abriu", "terminal_consultou", "terminal_ficha_confere",
              "terminal_recusa_invalido", "terminal_mesma_mae", "terminal_fechou"):
        c.um(k, f"terminal: {k} falhou")


def na_rua(c: Criterio, teto: int) -> None:
    # --- cidade ---
    c.exigir("lojas_r12", c.num("lojas_r12") >= 10,
             f"so {c.v.get('lojas_r12')} lojas num raio de 12 chunks; o criterio e 10")
    c.zero("lojas_teleportadas",
           "ha loja teleportada: onde o lote nao cabe a porta tem de ser outra coisa")
    c.exigir("props_da_loja", c.num("props_da_loja") == 4,
             "o chunk da loja nao tem porta automatica, portao, frente e interior")
    c.zero("porta_teleporte_no_chunk", "sobrou a Porta de teleporte no chunk da loja")
    c.um("letreiro", "a fachada da loja perdeu o letreiro")
    c.zero("lote_invadido",
           f"{c.v.get('lote_invadido')} pontos da loja dentro de muro ou predio da quadra")
    c.zero("fileira_buracos",
           f"a fileira da face da loja abre boca: {c.v.get('fileira_onde', '?')}")
    # --- chegada ---
    c.um("loja_montou", "a loja nao montou com o jogador na calcada")
    c.exigir("montagem_s", c.num("montagem_s") <= 5.0,
             f"a loja levou {c.v.get('montagem_s')} s para montar")
    c.um("porta_automatica", "a porta automatica nao nasceu")
    c.um("portao_enrolar", "o portao de aco nao nasceu")
    c.um("frente_da_loja", "a vitrine (MalhaFronteira) nao nasceu")
    c.um("chegou_na_geladeira",
         f"o jogador nao chegou a camara fria andando (parou no ponto "
         f"{c.v.get('parou_no_ponto', '?')}, em {c.v.get('parou_na_planta', '?')})")
    c.exigir("salto_max", c.num("salto_max", 9.0) < 0.5,
             f"salto de {c.v.get('salto_max')} m num quadro: teleporte na travessia")
    c.zero("cortina_max", "a cortina preta apareceu: a entrada nao e mais andando")
    c.zero("isolado", "o jogador foi para um comodo teleportado")
    c.um("entrou_no_mundo", "cruzar a soleira nao anunciou a entrada")
    c.exigir("porta_ao_cruzar", c.num("porta_ao_cruzar") >= 0.9,
             f"a porta estava {c.v.get('porta_ao_cruzar')} aberta quando o jogador "
             "passou: o sensor acordou tarde")
    c.exigir("empacou_s", c.num("empacou_s", 9.0) < 1.0,
             f"o jogador ficou {c.v.get('empacou_s')} s parado com a tecla apertada")
    c.um("jogador_entrou_pela_porta", "o sino da porta nao registrou o jogador")
    c.exigir("ambiente", c.v.get("ambiente") == "mercado_rua",
             f"o ambiente dentro da loja e '{c.v.get('ambiente')}', e nao o da loja na rua")
    loja_montada(c, teto)
    # --- gente ---
    c.um("atendente_classe", "o atendente nao e AtendenteLoja")
    c.um("cliente_existe", "a loja nao tem cliente")
    c.exigir("cliente_no_caixa_s", 0.0 <= c.num("cliente_no_caixa_s") <= 40.0,
             f"o cliente levou {c.v.get('cliente_no_caixa_s')} s para chegar ao caixa (F0: 40)")
    c.um("cliente_entrou_pela_porta", "o cliente nao entrou pela porta automatica")
    c.exigir("atendente_fora_do_posto", c.num("atendente_fora_do_posto", 9.0) < 0.4,
             "o atendente saiu de tras do balcao")
    balcao(c)
    # --- portao ---
    c.um("botoeira", "a garagem nao tem botoeira")
    c.um("botoeira_acha_portao", "a botoeira nao acha o portao do predio")
    c.exigir("portao_abertura", c.num("portao_abertura") >= 0.99,
             "a botoeira nao subiu o portao ate o fim")
    c.um("saiu_pelo_portao",
         f"o jogador nao saiu andando pela garagem (parou em {c.v.get('parou_na_planta', '?')})")
    c.exigir("portao_salto_max", c.num("portao_salto_max", 9.0) < 0.5,
             "salto na saida pelo portao")


def teleportado(c: Criterio, teto: int, planta: dict[str, float]) -> None:
    c.um("entrou", "nao entrou na loja teleportada")
    loja_montada(c, teto)
    c.um("portao_barra", "o vao do portao fechado deixa passar: la fora e o vazio")
    c.exigir("ambiente", c.v.get("ambiente") == "mercado",
             f"o ambiente da loja teleportada e '{c.v.get('ambiente')}'")
    c.um("pegou_da_prateleira", "o item da prateleira nao foi para o inventario")
    balcao(c)
    c.um("portao_folha_subiu", "a folha do portao nao subiu")
    c.um("saiu_pelo_portao", "o portao nao devolveu o jogador para a rua")
    lateral = planta.get("CENTRO_PORTA", 11.0) - planta.get("EIXO_PORTAO", 2.3)
    c.exigir("portao_lateral", abs(c.num("portao_lateral") - lateral) < 0.2,
             f"o portao devolveu o jogador a {c.v.get('portao_lateral')} m da porta; "
             f"na planta ele fica a {lateral:.1f}")
    c.exigir("portao_afastou", 0.5 < c.num("portao_afastou") < 3.0,
             f"o portao devolveu o jogador a {c.v.get('portao_afastou')} m da fachada")
    c.um("reentrou", "nao reentrou depois do portao")
    c.um("porta_automatica", "a saida teleportada perdeu a porta automatica")
    c.exigir("folhas", c.num("folhas") == 2, "a porta de saida nao tem duas folhas")
    c.um("folha_correu", "a folha da porta de saida nao correu")
    c.um("saiu", "a porta de saida nao devolveu o jogador")
    c.exigir("desvio_no_plano", c.num("desvio_no_plano", 9.0) < 0.3,
             f"o jogador voltou {c.v.get('desvio_no_plano')} m longe de onde entrou")
    c.exigir("ambiente_apos_sair", c.v.get("ambiente_apos_sair") != "mercado",
             "o ambiente da loja ficou preso depois de sair")


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

    teto = teto_de_luzes()
    planta = constantes_da_planta()
    erros: list[str] = []
    for rotulo, extra, conferir in (
            ("rua", [], lambda c: na_rua(c, teto)),
            ("teleporte", ["--teleporte"], lambda c: teleportado(c, teto, planta))):
        print(f"--- {rotulo}: rodando no {'build' if args.build else 'editor'}...")
        v = rodar(cmd, extra)
        if v is None:
            return 1
        for chave in sorted(v):
            print(f"  {chave:30s} {v[chave]}")
        c = Criterio(v, rotulo)
        conferir(c)
        erros += c.erros

    if erros:
        print(f"\nFALHOU ({len(erros)}):")
        for e in erros:
            print("  - " + e)
        return 1
    print("\nOK: a loja existe na rua, abre para quem chega e trabalha.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
