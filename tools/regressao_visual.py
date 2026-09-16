"""Regressao visual do PLANO_AAA_4K (criterio A2).

Roda a rota fixa de captura nos presets pedidos, compara cada parada com a
referencia guardada em `captures/referencia/<rota>/<preset>/` e reprova acima da
tolerancia. E o teste que impede uma fase do MODERNO de mexer no PS1 STYLE sem
ninguem ver.

    python tools/regressao_visual.py                      # ps1 e moderno
    python tools/regressao_visual.py --preset=ps1
    python tools/regressao_visual.py --gravar             # (re)cria referencias
    python tools/regressao_visual.py --ruido              # o piso da bancada

Por que ha um modo `--ruido`. Duas execucoes da MESMA build nunca dao imagem
identica: o grao do pos-processo, a chuva, o transito e a multidao mudam a cada
quadro. Comparar por blocos de 4x4 (tools/comparar_capturas.py) cancela o grao,
mas nao a chuva. Entao a pergunta "esta diferente?" so tem sentido contra o piso
de ruido da propria bancada, medido rodando a rota duas vezes seguidas sem mudar
nada. Numero sem piso nao e medida; e palpite com virgula.

A rota, as paradas e as flags de clima vem de `game/resources/rotas/cidade.json`
— o mesmo arquivo que o jogo le. Duas definicoes seriam duas rotas.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.join(RAIZ, ".tools", "Godot_v4.7.2-stable_win64_console.exe")
JOGO = os.path.join(RAIZ, "game")
ROTAS = os.path.join(JOGO, "resources", "rotas", "cidade.json")
REFERENCIA = os.path.join(RAIZ, "captures", "referencia")
SAIDA = os.path.join(RAIZ, "captures", "regressao")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from comparar_capturas import comparar  # noqa: E402

## Acima disto a parada reprova. Calibrado contra o piso medido por `--ruido`:
## a chuva animada sozinha ja move blocos, entao o limite de blocos e folgado e
## quem manda e o erro medio.
TOL_ERRO = 3.0      # /255, media por bloco
TOL_BLOCOS = 12.0   # % de blocos acima do limiar de 12/255
## Tempo maximo de uma execucao da rota. A rota inteira leva ~15 s; 300 s cobre
## uma maquina lenta e ainda assim nunca deixa uma janela presa para sempre.
PRAZO = 300


def carregar_rota(nome):
    with open(ROTAS, encoding="utf-8") as f:
        tudo = json.load(f)
    if nome not in tudo:
        raise SystemExit("rota %s nao existe em %s" % (nome, ROTAS))
    return tudo[nome]


def rodar(rota_nome, rota, preset, destino, resolucao):
    """Uma execucao da rota, gravando as fotos em `destino`."""
    if os.path.isdir(destino):
        shutil.rmtree(destino)
    os.makedirs(destino, exist_ok=True)
    cmd = [GODOT, "--path", JOGO, "--resolution", resolucao, "--",
           "--pular-menu", "--pular-abertura",
           # Sem transito e sem multidao: com luz global e sondas de reflexo, um
           # carro que passa muda 22% dos blocos da avenida entre duas execucoes
           # da MESMA build. Quem mede desempenho roda sem esta flag.
           "--rota-sem-vida",
           "--rota=" + rota_nome, "--estilo=" + preset,
           "--rota-fotos=" + destino.replace("\\", "/")]
    cmd += rota.get("flags", [])
    inicio = time.time()
    # Uma execucao de quatro travou, medido, e so morreu no prazo. A rota ganhou
    # cao de guarda proprio (120 s) por causa disso; aqui fica a segunda rede.
    for tentativa in (1, 2):
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=PRAZO)
            break
        except subprocess.TimeoutExpired as e:
            print("  %s: execucao %d nao terminou em %d s; ultimas linhas:"
                  % (preset, tentativa, PRAZO))
            saida = (e.stdout or b"")
            if isinstance(saida, bytes):
                saida = saida.decode("utf-8", "replace")
            print(os.linesep.join(saida.splitlines()[-8:]))
            if tentativa == 2:
                raise SystemExit("a rota travou duas vezes seguidas")
    fotos = sorted(f for f in os.listdir(destino) if f.endswith(".png"))
    print("  %s: %d fotos em %.0f s" % (preset, len(fotos), time.time() - inicio))
    if not fotos:
        print(p.stdout[-2000:])
        raise SystemExit("a rota nao gravou foto nenhuma")
    return [f[:-4] for f in fotos]


def comparar_pastas(a, b, paradas, rotulo, vivas=()):
    """Compara parada a parada; devolve [(parada, erro, blocos)].

    Parada marcada como "viva" no JSON fica de fora: nela quem manda e o
    transito, que muda a cada execucao. Medido, o piso de ruido do `cruzamento`
    e 18,3/255 contra 1,1 a 1,8 das outras — comparar ali so produziria alarme
    falso. Ela continua na rota, porque para MEDIR desempenho ela e a melhor
    parada que existe.
    """
    linhas = []
    for parada in paradas:
        if parada in vivas:
            print("  %-14s viva (transito): fora da comparacao" % parada)
            continue
        fa = os.path.join(a, parada + ".png")
        fb = os.path.join(b, parada + ".png")
        if not (os.path.exists(fa) and os.path.exists(fb)):
            print("  %-14s SEM PAR (%s)" % (parada, rotulo))
            linhas.append((parada, float("inf"), 100.0))
            continue
        erro, blocos = comparar(fa, fb)
        linhas.append((parada, erro, blocos))
        print("  %-14s erro %5.2f/255   blocos %5.2f%%" % (parada, erro, blocos))
    return linhas


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preset", default="ambos", choices=["ps1", "moderno", "ambos"])
    ap.add_argument("--rota", default="noite_chuva")
    ap.add_argument("--resolucao", default="1280x720")
    ap.add_argument("--gravar", action="store_true",
                    help="grava o que sair como referencia nova")
    ap.add_argument("--ruido", action="store_true",
                    help="roda duas vezes e mede o piso de ruido da bancada")
    ap.add_argument("--tolerancia", type=float, default=TOL_ERRO)
    args = ap.parse_args()

    rota = carregar_rota(args.rota)
    presets = ["ps1", "moderno"] if args.preset == "ambos" else [args.preset]
    print("rota %s (%s)" % (args.rota, rota.get("descricao", "")))
    falhas = 0
    for preset in presets:
        atual = os.path.join(SAIDA, args.rota, preset)
        paradas = rodar(args.rota, rota, preset, atual, args.resolucao)

        if args.ruido:
            outra = os.path.join(SAIDA, args.rota, preset + "_b")
            rodar(args.rota, rota, preset, outra, args.resolucao)
            print(" piso de ruido, %s (inclusive as paradas vivas):" % preset)
            comparar_pastas(atual, outra, paradas, "ruido")
            continue

        ref = os.path.join(REFERENCIA, args.rota, preset)
        if args.gravar:
            os.makedirs(ref, exist_ok=True)
            for parada in paradas:
                shutil.copyfile(os.path.join(atual, parada + ".png"),
                                os.path.join(ref, parada + ".png"))
            print(" referencia gravada: %s (%d paradas)" % (ref, len(paradas)))
            continue
        if not os.path.isdir(ref):
            raise SystemExit("sem referencia em %s; rode com --gravar" % ref)
        print(" %s contra a referencia:" % preset)
        vivas = set(pp["nome"] for pp in rota.get("paradas", []) if pp.get("vivo"))
        for parada, erro, blocos in comparar_pastas(ref, atual, paradas,
                                                    "referencia", vivas):
            if erro > args.tolerancia or blocos > TOL_BLOCOS:
                falhas += 1
                print("  ^ %s REPROVA (limite %.2f/255 e %.1f%%)"
                      % (parada, args.tolerancia, TOL_BLOCOS))
    if args.ruido or args.gravar:
        return 0
    print("A2 %s: %d parada(s) fora da tolerancia" % ("FALHA" if falhas else "OK", falhas))
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main())
