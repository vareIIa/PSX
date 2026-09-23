#!/usr/bin/env python3
"""Autoteste do rede_ruim.py: o proxy medido de fora, com relogio proprio.

    python tools/rede_ruim_autoteste.py

Sobe o proxy como processo, do jeito que o teste de nivel 4 vai subir, entre um
servidor de eco UDP e clientes UDP que moram aqui (threads). Cada pacote leva o
instante de envio; o eco devolve igual, e o cliente mede a ida e volta com o
mesmo perf_counter. Nao confia no relatorio do proxy para a medida: o relatorio
so e conferido contra o que este processo contou.

Quatro rodadas:
  limpa  sem atraso nem perda: nada se perde, ida e volta < 3 ms, cada cliente
         chega ao servidor com endereco proprio, e o cliente ocioso e esquecido
         e volta com socket de subida novo.
  fixa   40 ms por sentido sem jitter: a precisao do relogio do proxy, e um
         cliente que fecha o socket antes da resposta (ICMP de volta, que no
         Windows vira WSAECONNRESET) nao pode derrubar o proxy.
  ruim   40 ms, jitter 10 ms, perda 5 %: mediana, piso, teto e perda de ida e
         volta contra a conta, 1 - 0,95^2 = 9,75 %.
  esquecida  atraso de 1,2 s e --esquecer-s=0.1: o cliente fica ocioso com
         pacote ainda na fila, e o socket de subida dele nao pode fechar antes
         de o pacote sair.

Imprime PASS/FAIL por conferencia e sai 0 se tudo passou, 1 se nao.
"""

import json
import math
import re
import shutil
import socket
import statistics
import struct
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

# Sem __pycache__ em tools/ por importar o proxy.
sys.dont_write_bytecode = True
from rede_ruim import Histograma, prioridade_acima_do_normal  # noqa: E402

AQUI = Path(__file__).resolve().parent
PROXY = AQUI / "rede_ruim.py"
# Etiqueta do cliente, numero de sequencia, instante de envio.
FORMATO = struct.Struct("<cId")
# Do tamanho de um pacote de estado pequeno do jogo.
ENCHIMENTO = b"\0" * 32

_resultados = []


def conferir(cond, nome, detalhe):
    _resultados.append(bool(cond))
    print(f"{'PASS' if cond else 'FAIL'}  {nome}: {detalhe}", flush=True)


class Eco(threading.Thread):
    """O "servidor": devolve cada pacote a quem mandou e anota de que endereco
    veio cada etiqueta. Um endereco por cliente e o que o ENet precisa ver."""

    def __init__(self):
        super().__init__(daemon=True)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("127.0.0.1", 0))
        self.sock.settimeout(0.1)
        self.porta = self.sock.getsockname()[1]
        self.origens = {}
        self.recebidos = 0
        self.devolvidos = 0
        self._parar = False
        self.start()

    def run(self):
        while not self._parar:
            try:
                dados, origem = self.sock.recvfrom(65535)
            except socket.timeout:
                continue
            except OSError:
                # ICMP de um socket de subida que o proxy ja fechou.
                continue
            self.recebidos += 1
            self.origens.setdefault(dados[:1], set()).add(origem)
            try:
                self.sock.sendto(dados, origem)
                self.devolvidos += 1
            except OSError:
                pass

    def fechar(self):
        self._parar = True
        self.join(1.0)
        self.sock.close()


class Cliente:
    def __init__(self, etiqueta, porta_proxy, ler=True):
        self.etiqueta = etiqueta.encode("ascii")
        self.destino = ("127.0.0.1", porta_proxy)
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("127.0.0.1", 0))
        self.sock.settimeout(0.1)
        self.enviados = 0
        self.ida_volta = {}
        self.duplicados = 0
        self._parar = False
        self._leitor = None
        if ler:
            self._leitor = threading.Thread(target=self._ler, daemon=True)
            self._leitor.start()

    def enviar(self, seq):
        pacote = FORMATO.pack(self.etiqueta, seq, time.perf_counter()) + ENCHIMENTO
        self.sock.sendto(pacote, self.destino)
        self.enviados += 1

    def disparar(self, n, por_segundo, primeiro=0):
        # Agenda absoluta: o atraso de um sleep nao empurra os seguintes.
        t0 = time.perf_counter()
        for i in range(n):
            espera = t0 + i / por_segundo - time.perf_counter()
            if espera > 0:
                time.sleep(espera)
            self.enviar(primeiro + i)

    def _ler(self):
        while not self._parar:
            try:
                dados = self.sock.recv(65535)
            except socket.timeout:
                continue
            except OSError:
                continue
            agora = time.perf_counter()
            _, seq, enviado = FORMATO.unpack_from(dados)
            if seq in self.ida_volta:
                self.duplicados += 1
                continue
            self.ida_volta[seq] = (agora - enviado) * 1000.0

    def recebidos(self, primeiro=0, n=None):
        fim = self.enviados if n is None else primeiro + n
        return [self.ida_volta[s] for s in range(primeiro, fim) if s in self.ida_volta]

    def fechar(self):
        self._parar = True
        if self._leitor is not None:
            self._leitor.join(1.0)
        self.sock.close()


class ProxyRodando:
    def __init__(self, pasta, porta_eco, duracao, *args):
        self.duracao = duracao
        self.arquivo = Path(pasta) / f"relatorio_{time.monotonic_ns()}.json"
        cmd = [sys.executable, str(PROXY), "--ouvir=127.0.0.1:0",
               f"--alvo=127.0.0.1:{porta_eco}", f"--duracao={duracao}",
               f"--relatorio={self.arquivo}", *args]
        self.inicio = time.perf_counter()
        self.p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True, encoding="utf-8")
        self.linha_subida = self.p.stdout.readline().strip()
        m = re.search(r"ouvindo [\d.]+:(\d+) -> ", self.linha_subida)
        if m is None:
            self.p.kill()
            raise RuntimeError(f"proxy nao subiu: {self.linha_subida!r}")
        self.porta = int(m.group(1))
        self.relatorio = None
        self.relatorio_arquivo = None
        self.codigo = None
        self.segundos = 0.0

    def esperar(self):
        try:
            resto, _ = self.p.communicate(timeout=self.duracao + 15)
        except subprocess.TimeoutExpired:
            self.p.kill()
            resto, _ = self.p.communicate()
        self.segundos = time.perf_counter() - self.inicio
        self.codigo = self.p.returncode
        for linha in resto.splitlines():
            if linha.startswith("[rede_ruim] {"):
                self.relatorio = json.loads(linha[len("[rede_ruim] "):])
        if self.arquivo.exists():
            self.relatorio_arquivo = json.loads(self.arquivo.read_text(encoding="utf-8"))
        return self.relatorio


def quantil(ordenados, q):
    if not ordenados:
        return float("nan")
    return ordenados[min(len(ordenados) - 1, max(0, math.ceil(q * len(ordenados)) - 1))]


def resumo(valores):
    o = sorted(valores)
    if not o:
        return {"n": 0}
    return {
        "n": len(o),
        "min": round(o[0], 2),
        "p50": round(statistics.median(o), 2),
        "p95": round(quantil(o, 0.95), 2),
        "p99": round(quantil(o, 0.99), 2),
        "max": round(o[-1], 2),
    }


def conferir_saida(px, nome):
    rel = px.relatorio
    conferir(px.codigo == 0 and rel is not None and rel.get("motivo") == "duracao"
             and abs(px.segundos - px.duracao) < 2.0,
             f"{nome}: sai sozinho por --duracao",
             f"codigo {px.codigo}, motivo {rel.get('motivo') if rel else None}, "
             f"{px.segundos:.1f} s para --duracao={px.duracao}")
    conferir(rel is not None and rel == px.relatorio_arquivo,
             f"{nome}: --relatorio igual a linha do stdout",
             "igual" if rel is not None and rel == px.relatorio_arquivo else "diferente ou ausente")


def conferir_contas(rel, eco, clientes, nome):
    """As contas do proxy contra as deste processo: o que os clientes mandaram
    e o que subiu, o que o eco devolveu e o que desceu."""
    mandados = sum(c.enviados for c in clientes)
    voltaram = sum(len(c.ida_volta) + c.duplicados for c in clientes)
    s, d = rel["subida"], rel["descida"]
    ok = (s["recebidos"] == mandados
          and s["enviados"] + s["perdidos"] + s["pendentes"] + s["falhas_envio"] == s["recebidos"]
          and s["enviados"] == eco.recebidos
          and d["recebidos"] == eco.devolvidos
          and d["enviados"] + d["perdidos"] + d["pendentes"] + d["falhas_envio"] == d["recebidos"]
          and d["enviados"] >= voltaram)
    conferir(ok, f"{nome}: contas do relatorio batem com as daqui",
             f"subida {s}, descida {d}; mandados {mandados}, eco recebeu {eco.recebidos} "
             f"devolveu {eco.devolvidos}, clientes receberam {voltaram}")


def rodada_limpa(pasta):
    print("== limpa: --atraso-ms=0 --jitter-ms=0 --perda=0 --esquecer-s=1.5", flush=True)
    eco = Eco()
    px = ProxyRodando(pasta, eco.porta, 9, "--atraso-ms=0", "--jitter-ms=0", "--perda=0",
                      "--esquecer-s=1.5")
    a = Cliente("A", px.porta)
    b = Cliente("B", px.porta)
    tb = threading.Thread(target=b.disparar, args=(50, 50))
    tb.start()
    a.disparar(600, 200)
    tb.join()
    # Ocioso alem de --esquecer-s mais uma volta de faxina: o proxy solta o
    # socket de subida de A, e o proximo pacote de A tem de abrir outro.
    time.sleep(2.8)
    a.etiqueta = b"R"
    a.disparar(20, 100, primeiro=600)
    time.sleep(0.4)
    a.fechar()
    b.fechar()
    rel = px.esperar()
    eco.fechar()

    fase1 = a.recebidos(0, 600)
    fase2 = a.recebidos(600, 20)
    rb = b.recebidos()
    ra = resumo(fase1)
    conferir(len(fase1) == 600 and len(rb) == 50 and len(fase2) == 20,
             "limpa: nenhuma perda", f"A {len(fase1)}/600, B {len(rb)}/50, A de volta {len(fase2)}/20")
    conferir(ra.get("p50", 99) < 3.0, "limpa: mediana da ida e volta < 3 ms", f"A {ra}")
    oa, ob, orr = (eco.origens.get(k, set()) for k in (b"A", b"B", b"R"))
    conferir(len(oa) == 1 and len(ob) == 1 and oa != ob,
             "limpa: dois clientes chegam ao servidor por enderecos distintos",
             f"A por {sorted(oa)}, B por {sorted(ob)}")
    conferir(rel is not None and rel["esquecidos"] >= 2 and len(orr) == 1 and orr != oa,
             "limpa: ocioso esquecido volta por socket de subida novo",
             f"esquecidos {rel['esquecidos'] if rel else None}, A antes {sorted(oa)}, "
             f"depois {sorted(orr)}")
    conferir(rel is not None and rel["clientes"] == 2, "limpa: relatorio conta 2 clientes",
             f"clientes {rel['clientes'] if rel else None}")
    if rel is not None:
        conferir_contas(rel, eco, [a, b], "limpa")
    conferir_saida(px, "limpa")


def rodada_fixa(pasta):
    print("== fixa: --atraso-ms=40 --jitter-ms=0 --perda=0 (precisao; cliente que morre)",
          flush=True)
    eco = Eco()
    px = ProxyRodando(pasta, eco.porta, 6, "--atraso-ms=40", "--jitter-ms=0", "--perda=0")
    # Manda e fecha: a resposta chega 80 ms depois numa porta fechada, o
    # Windows devolve ICMP, e sem o SIO_UDP_CONNRESET (ou o except) o proximo
    # recvfrom do proxy estoura.
    morto = Cliente("D", px.porta, ler=False)
    for i in range(5):
        morto.enviar(i)
    morto.fechar()
    time.sleep(0.3)
    a = Cliente("A", px.porta)
    a.disparar(600, 200)
    time.sleep(0.5)
    a.fechar()
    rel = px.esperar()
    eco.fechar()

    ra = resumo(a.recebidos())
    conferir(ra["n"] == 600, "fixa: cliente morto nao derruba o proxy",
             f"A recebeu {ra['n']}/600 depois do cliente que fechou; "
             f"erros_leitura {rel['erros_leitura'] if rel else None}")
    extra = rel["atraso_extra_ms"] if rel else {}
    conferir(ra["n"] > 0 and 79.0 <= ra["p50"] <= 82.0 and ra["p95"] <= 83.0,
             "fixa: 2 x 40 ms acertado em ~2 ms",
             f"ida e volta {ra}; atraso alem do agendado, no proxy: {extra}; "
             f"{rel['ambiente'] if rel else ''}")
    conferir(ra["n"] > 0 and ra["min"] >= 79.9, "fixa: nunca sai antes do atraso",
             f"min {ra.get('min')}")
    if rel is not None:
        conferir_contas(rel, eco, [morto, a], "fixa")
    conferir_saida(px, "fixa")


def rodada_ruim(pasta):
    atraso, jitter, perda = 40.0, 10.0, 0.05
    print(f"== ruim: --atraso-ms={atraso:g} --jitter-ms={jitter:g} --perda={perda:g} --duracao=20",
          flush=True)
    eco = Eco()
    px = ProxyRodando(pasta, eco.porta, 20, f"--atraso-ms={atraso:g}", f"--jitter-ms={jitter:g}",
                      f"--perda={perda:g}")
    a = Cliente("A", px.porta)
    n = 2000
    a.disparar(n, 200)
    time.sleep(1.0)
    a.fechar()
    rel = px.esperar()
    eco.fechar()

    ra = resumo(a.recebidos())
    alvo = 2 * atraso
    conferir(abs(ra["p50"] - alvo) <= 6.0, f"ruim: mediana em {alvo:g} +- 6 ms", f"{ra}")
    piso = 2 * (atraso - jitter) - 2
    conferir(ra["min"] >= piso, f"ruim: min >= {piso:g} ms", f"min {ra['min']}")
    teto = 2 * (atraso + jitter) + 6
    conferir(ra["max"] <= teto, f"ruim: max <= {teto:g} ms", f"max {ra['max']}")
    esperada = 1 - (1 - perda) ** 2
    observada = 1 - ra["n"] / n
    conferir(abs(observada - esperada) <= 0.03,
             f"ruim: perda de ida e volta {esperada * 100:.2f} % +- 3 pp",
             f"{observada * 100:.2f} % ({n - ra['n']} de {n}); proxy perdeu "
             f"{rel['subida']['perdidos'] if rel else '?'} na subida e "
             f"{rel['descida']['perdidos'] if rel else '?'} na descida")
    conferir(a.duplicados == 0, "ruim: nada duplicado", f"{a.duplicados} duplicados")
    if rel is not None:
        conferir_contas(rel, eco, [a], "ruim")
        print(f"     atraso alem do agendado, no proxy: {rel['atraso_extra_ms']}", flush=True)
    conferir_saida(px, "ruim")


def rodada_esquecida(pasta):
    print("== esquecida: --atraso-ms=1200 --esquecer-s=0.1 (cliente ocioso com pacote na fila)",
          flush=True)
    eco = Eco()
    px = ProxyRodando(pasta, eco.porta, 4, "--atraso-ms=1200", "--jitter-ms=0", "--perda=0",
                      "--esquecer-s=0.1")
    a = Cliente("A", px.porta)
    for i in range(5):
        a.enviar(i)
    # Sobe em 1,2 s, desce em 2,4 s; a faxina solta o cliente no meio disso.
    time.sleep(3.2)
    a.fechar()
    rel = px.esperar()
    eco.fechar()

    ra = resumo(a.recebidos())
    falhas = rel["subida"]["falhas_envio"] if rel else None
    esquecidos = rel["esquecidos"] if rel else None
    conferir(eco.recebidos == 5 and ra["n"] == 5 and falhas == 0 and esquecidos == 1,
             "esquecida: pacote agendado sai antes de o socket fechar",
             f"eco recebeu {eco.recebidos}/5, A recebeu {ra['n']}/5, falhas na subida {falhas}, "
             f"esquecidos {esquecidos}")
    if rel is not None:
        conferir_contas(rel, eco, [a], "esquecida")
    conferir_saida(px, "esquecida")


def conferir_histograma():
    """O atraso_extra_ms do relatorio: quantil nunca acima do maximo, e o
    transbordo (acima de 50 ms) vem do maximo, nao da borda da caixa."""
    h = Histograma()
    for _ in range(10):
        h.anotar(0.00122)
    miudo = h.resumo()
    h = Histograma()
    for _ in range(90):
        h.anotar(0.00025)
    for _ in range(10):
        h.anotar(0.080)
    engasgo = h.resumo()
    conferir(miudo["p99"] <= miudo["max"] and engasgo["p99"] == 80.0 and engasgo["p50"] == 0.3,
             "histograma do relatorio", f"1,22 ms x10 -> {miudo}; 90 x 0,25 + 10 x 80 ms -> {engasgo}")


def main():
    # O lado que mede tambem: um engasgo deste processo apareceria como atraso
    # do proxy.
    prioridade_acima_do_normal()
    pasta = tempfile.mkdtemp(prefix="rede_ruim_")
    try:
        conferir_histograma()
        rodada_limpa(pasta)
        rodada_fixa(pasta)
        rodada_ruim(pasta)
        rodada_esquecida(pasta)
    except Exception as e:  # noqa: BLE001 - o autoteste tem de dizer FAIL, nao so morrer
        conferir(False, "autoteste rodou ate o fim", repr(e))
    finally:
        shutil.rmtree(pasta, ignore_errors=True)
    passou = sum(_resultados)
    total = len(_resultados)
    print(f"{'PASS' if passou == total else 'FAIL'} - {passou}/{total} conferencias", flush=True)
    return 0 if passou == total else 1


if __name__ == "__main__":
    sys.exit(main())
