#!/usr/bin/env python3
"""Rede ruim de mentira: proxy UDP que atrasa, embaralha e perde pacotes.

    python tools/rede_ruim.py --ouvir=24612 --alvo=127.0.0.1:24611 \\
        --atraso-ms=75 --jitter-ms=15 --perda=0.02 --duracao=28

Por que existe
--------------
Em localhost o ping e 0 ms e nada se perde, e o teste de nivel 4
(`tools/mp_teste.sh`) mede entao so o relogio e a interpolacao. O plano (fase
8.4) pede a medida com 150 ms de ida e volta, 2 % de perda e 30 ms de jitter,
para ajustar `ATRASO_INTERPOLACAO` por numero e nao por palpite. O clumsy e o
netem pedem administrador ou Linux; isto e biblioteca padrao e roda na bancada.

Topologia
---------
    bot --> [ouvir] proxy [um socket de subida POR CLIENTE] --> servidor

O ENet reconhece o peer pelo endereco de origem. Se todos os clientes saissem
pelo mesmo socket, o servidor veria um peer so e o segundo CONNECT colidiria
com o primeiro; com um socket de subida por endereco de cliente, cada bot
continua sendo um peer distinto. A resposta do servidor volta pelo socket de
subida daquele cliente e sai para ele pelo socket de escuta.

Numeros
-------
--atraso-ms vale para CADA sentido: 75 da ~150 ms de ida e volta, que e o que o
ping do jogo mostra. --jitter-ms soma a cada pacote um desvio uniforme em
[-jitter, +jitter], sorteado de novo por pacote; isso reordena pacotes como a
internet reordena, e o ENet lida (o confiavel reordena, o sequenciado descarta
o velho). --perda e independente por pacote e por sentido: a perda de ida e
volta fica 1 - (1 - p)^2. A semente e fixa por padrao, com um sorteador por
sentido, para o pacote n de cada sentido ter o mesmo destino em toda execucao.

Por que --duracao
-----------------
No Windows o `kill` do bash e o TerminateProcess nao rodam tratador de sinal do
Python: um proxy morto assim nunca escreveria o relatorio. Com --duracao ele
encerra sozinho e escreve. Ctrl+C e SIGTERM (onde existe) tambem escrevem.

Desenho
-------
Uma thread so, `select` em todos os sockets (nao bloqueantes) e um heap de
envios agendados; o `select` espera exatamente ate o proximo pacote vencer,
com teto de 5 ms. O UDP do asyncio no Windows (Proactor) tem armadilhas com
ConnectionResetError que aqui nao existem.

Saida: uma linha "[rede_ruim] ouvindo ..." ao subir e uma linha
"[rede_ruim] {json}" ao sair, com as contagens por sentido.
"""

import argparse
import heapq
import json
import os
import random
import select
import signal
import socket
import sys
import time

PREFIXO = "[rede_ruim] "
TAMANHO_MAX = 65535
# Teto de espera do select: o laco confere fim, sinal e faxina nesse passo.
ESPERA_MAX = 0.005
# De quanto em quanto tempo procurar cliente ocioso.
FAXINA_S = 1.0
# Buffer do sistema grande: rajada que estoura buffer e perda que nao sorteamos.
BUFFER_SO = 4 * 1024 * 1024
# Pacotes lidos de um socket por volta do laco, para nao atrasar os envios.
DRENAR_MAX = 256
# _WSAIOW(IOC_VENDOR, 12). O modulo socket nao expoe essa constante.
SIO_UDP_CONNRESET = 0x9800000C


def _desligar_connreset(sock):
    """No Windows, um ICMP "porta inalcancavel" (cliente que fechou) vira
    WSAECONNRESET no PROXIMO recvfrom do socket, mesmo em UDP. Desliga isso no
    socket; o laco ainda captura o erro, caso o desligamento falhe."""
    if os.name != "nt":
        return False
    codigo = getattr(socket, "SIO_UDP_CONNRESET", None)
    if codigo is not None:
        try:
            sock.ioctl(codigo, False)
            return True
        except (ValueError, OSError):
            pass
    # sock.ioctl so aceita tres codigos; o resto vai direto ao WSAIoctl.
    try:
        import ctypes
        from ctypes import wintypes

        ws2 = ctypes.WinDLL("ws2_32")
        wsaioctl = ws2.WSAIoctl
        wsaioctl.argtypes = [
            ctypes.c_size_t, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD,
            ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD),
            ctypes.c_void_p, ctypes.c_void_p,
        ]
        wsaioctl.restype = ctypes.c_int
        desligado = wintypes.BOOL(False)
        devolvidos = wintypes.DWORD(0)
        r = wsaioctl(sock.fileno(), SIO_UDP_CONNRESET, ctypes.byref(desligado),
                     ctypes.sizeof(desligado), None, 0, ctypes.byref(devolvidos),
                     None, None)
        return r == 0
    except (OSError, AttributeError):
        return False


def _relogio_fino():
    """Pede ao Windows timer de 1 ms. Sem isso, numa maquina onde ninguem pediu,
    o select arredonda a espera para 15,6 ms e o atraso vira degrau. Devolve
    (conseguiu, desfazer)."""
    if os.name != "nt":
        return False, lambda: None
    try:
        import ctypes

        winmm = ctypes.WinDLL("winmm")
        if winmm.timeBeginPeriod(1) == 0:
            return True, lambda: winmm.timeEndPeriod(1)
    except (OSError, AttributeError):
        pass
    return False, lambda: None


def prioridade_acima_do_normal():
    """O proxy e a "rede" do teste: o relogio dele nao pode ser o ruido. Na
    bancada de nivel 4 ele divide oito nucleos com Godots que compilam a cidade
    ao subir; medido, um engasgo de 13 ms do proxy em prioridade normal virou
    110 ms de ida e volta num teto de 106. So no Windows (baixar o nice no Linux
    pede root)."""
    if os.name != "nt":
        return False
    try:
        import ctypes

        k32 = ctypes.WinDLL("kernel32")
        k32.GetCurrentProcess.restype = ctypes.c_void_p
        k32.SetPriorityClass.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
        return bool(k32.SetPriorityClass(k32.GetCurrentProcess(), 0x00008000))
    except (OSError, AttributeError):
        return False


def _socket_udp():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    for opcao in (socket.SO_RCVBUF, socket.SO_SNDBUF):
        try:
            s.setsockopt(socket.SOL_SOCKET, opcao, BUFFER_SO)
        except OSError:
            pass
    s.setblocking(False)
    return s


class Histograma:
    """Atraso alem do agendado, em ms, em caixas de 0,1 ms: o quanto o proxy
    errou o proprio relogio. Caixas e nao lista para rodar horas sem crescer."""

    PASSO_MS = 0.1
    CAIXAS = 500

    def __init__(self):
        self.caixas = [0] * (self.CAIXAS + 1)
        self.n = 0
        self.soma = 0.0
        self.maximo = 0.0

    def anotar(self, segundos):
        ms = max(0.0, segundos * 1000.0)
        self.caixas[min(int(ms / self.PASSO_MS), self.CAIXAS)] += 1
        self.n += 1
        self.soma += ms
        if ms > self.maximo:
            self.maximo = ms

    def quantil(self, q):
        if self.n == 0:
            return 0.0
        alvo = q * self.n
        acumulado = 0
        for i, c in enumerate(self.caixas):
            acumulado += c
            if acumulado >= alvo:
                if i == self.CAIXAS:
                    # Caixa de transbordo: a borda dela (50,1 ms) nao e medida.
                    break
                # A borda de cima da caixa e teto; o maximo real tambem.
                return round(min((i + 1) * self.PASSO_MS, self.maximo), 2)
        return round(self.maximo, 2)

    def resumo(self):
        return {
            "n": self.n,
            "media": round(self.soma / self.n, 3) if self.n else 0.0,
            "p50": self.quantil(0.50),
            "p99": self.quantil(0.99),
            "max": round(self.maximo, 2),
        }


class Direcao:
    def __init__(self, nome, semente):
        self.nome = nome
        # Semente em texto: deterministica entre execucoes, sem PYTHONHASHSEED.
        self.rng = random.Random(f"{semente}:{nome}")
        self.recebidos = 0
        self.enviados = 0
        self.perdidos = 0
        self.falhas = 0

    def resumo(self, pendentes):
        return {
            "recebidos": self.recebidos,
            "enviados": self.enviados,
            "perdidos": self.perdidos,
            "pendentes": pendentes,
            "falhas_envio": self.falhas,
        }


class Cliente:
    __slots__ = ("endereco", "sock", "ultimo")

    def __init__(self, endereco, sock, agora):
        self.endereco = endereco
        self.sock = sock
        self.ultimo = agora


class Proxy:
    def __init__(self, ouvir, alvo, atraso_ms, jitter_ms, perda, semente, esquecer_s):
        self.alvo = alvo
        self.atraso = atraso_ms / 1000.0
        self.jitter = jitter_ms / 1000.0
        self.perda = perda
        self.semente = semente
        self.esquecer_s = esquecer_s
        self.subida = Direcao("subida", semente)
        self.descida = Direcao("descida", semente)
        # (vence, seq, direcao, sock, dados, destino); seq desempata e mantem
        # a ordem de chegada entre pacotes com o mesmo vencimento.
        self.fila = []
        self._seq = 0
        self.clientes = {}
        self.por_sock = {}
        self.vistos = set()
        self.esquecidos = 0
        self.erros_leitura = 0
        self.atraso_extra = Histograma()
        self.rodando = True
        self.motivo = "fim"
        self.ouvinte = _socket_udp()
        # O que o sistema aceitou dos ajustes de tempo e de ICMP; vai no relatorio.
        self.ambiente = {"connreset_desligado": _desligar_connreset(self.ouvinte)}
        self.ouvinte.bind(ouvir)
        self.ouvir = self.ouvinte.getsockname()
        self._lista = [self.ouvinte]

    def _atualizar_lista(self):
        self._lista = [self.ouvinte, *self.por_sock]

    def _novo_cliente(self, endereco, agora):
        s = _socket_udp()
        _desligar_connreset(s)
        try:
            # Conectado: o sistema so entrega o que vem do servidor real.
            s.connect(self.alvo)
        except OSError:
            s.close()
            return None
        c = Cliente(endereco, s, agora)
        self.clientes[endereco] = c
        self.por_sock[s] = c
        self.vistos.add(endereco)
        self._atualizar_lista()
        return c

    def _esquecer_ociosos(self, agora):
        """Solta cliente sem pacote ha `esquecer_s`. Conta so o que VEM do
        cliente: o servidor continua mandando para um bot que ja saiu ate o ENet
        dele desistir. Sem isso, rodada longa vaza um socket por bot.

        O prazo corre depois que o ultimo pacote do cliente saiu da fila, nao de
        quando chegou: com atraso maior que --esquecer-s o socket fechava com
        pacote dele ainda agendado, e o pacote sumia como falha de envio."""
        prazo = self.esquecer_s + self.atraso + self.jitter
        mudou = False
        for endereco, c in list(self.clientes.items()):
            if agora - c.ultimo >= prazo:
                del self.clientes[endereco]
                del self.por_sock[c.sock]
                c.sock.close()
                self.esquecidos += 1
                mudou = True
        if mudou:
            self._atualizar_lista()

    def _agendar(self, direcao, dados, sock, destino, agora):
        direcao.recebidos += 1
        # Os dois sorteios sempre, perdido ou nao: o destino do pacote n de um
        # sentido depende so da semente e de n.
        sorteio_perda = direcao.rng.random()
        sorteio_jitter = direcao.rng.uniform(-1.0, 1.0)
        if sorteio_perda < self.perda:
            direcao.perdidos += 1
            return
        atraso = self.atraso + sorteio_jitter * self.jitter
        if atraso <= 0.0:
            self._enviar(direcao, sock, dados, destino)
            return
        self._seq += 1
        heapq.heappush(self.fila, (agora + atraso, self._seq, direcao, sock, dados, destino))

    def _enviar(self, direcao, sock, dados, destino):
        try:
            if destino is None:
                sock.send(dados)
            else:
                sock.sendto(dados, destino)
            direcao.enviados += 1
        except OSError:
            # Buffer cheio, socket de cliente esquecido, ICMP: UDP perde.
            direcao.falhas += 1

    def _enviar_vencidos(self):
        fila = self.fila
        while fila:
            agora = time.perf_counter()
            if fila[0][0] > agora:
                return
            vence, _, direcao, sock, dados, destino = heapq.heappop(fila)
            self.atraso_extra.anotar(agora - vence)
            self._enviar(direcao, sock, dados, destino)

    def _drenar_ouvinte(self):
        for _ in range(DRENAR_MAX):
            try:
                dados, origem = self.ouvinte.recvfrom(TAMANHO_MAX)
            except (BlockingIOError, InterruptedError):
                return
            except OSError:
                # ConnectionResetError de um cliente que fechou, se o
                # SIO_UDP_CONNRESET nao pegou. Nao e pacote; segue.
                self.erros_leitura += 1
                continue
            agora = time.perf_counter()
            c = self.clientes.get(origem)
            if c is None:
                c = self._novo_cliente(origem, agora)
                if c is None:
                    continue
            c.ultimo = agora
            self._agendar(self.subida, dados, c.sock, None, agora)

    def _drenar_subida(self, c):
        for _ in range(DRENAR_MAX):
            try:
                dados = c.sock.recv(TAMANHO_MAX)
            except (BlockingIOError, InterruptedError):
                return
            except OSError:
                # Servidor ainda fechado (ICMP): nao e pacote; segue.
                self.erros_leitura += 1
                continue
            self._agendar(self.descida, dados, self.ouvinte, c.endereco, time.perf_counter())

    def rodar(self, duracao):
        inicio = time.perf_counter()
        fim = inicio + duracao if duracao > 0 else float("inf")
        faxina = inicio + FAXINA_S
        while self.rodando:
            self._enviar_vencidos()
            agora = time.perf_counter()
            if agora >= fim:
                self.motivo = "duracao"
                return
            if agora >= faxina:
                self._esquecer_ociosos(agora)
                faxina = agora + FAXINA_S
            espera = min(ESPERA_MAX, fim - agora)
            if self.fila:
                espera = min(espera, self.fila[0][0] - agora)
            try:
                prontos, _, _ = select.select(self._lista, [], [], max(0.0, espera))
            except InterruptedError:
                continue
            for s in prontos:
                if s is self.ouvinte:
                    self._drenar_ouvinte()
                else:
                    c = self.por_sock.get(s)
                    if c is not None:
                        self._drenar_subida(c)

    def relatorio(self, duracao_real, duracao_pedida):
        pendentes = {"subida": 0, "descida": 0}
        for item in self.fila:
            pendentes[item[2].nome] += 1
        return {
            "subida": self.subida.resumo(pendentes["subida"]),
            "descida": self.descida.resumo(pendentes["descida"]),
            "clientes": len(self.vistos),
            "clientes_ativos": len(self.clientes),
            "esquecidos": self.esquecidos,
            "erros_leitura": self.erros_leitura,
            "atraso_extra_ms": self.atraso_extra.resumo(),
            "motivo": self.motivo,
            "duracao_s": round(duracao_real, 3),
            "parametros": {
                "ouvir": "%s:%d" % self.ouvir,
                "alvo": "%s:%d" % self.alvo,
                "atraso_ms": self.atraso * 1000.0,
                "jitter_ms": self.jitter * 1000.0,
                "perda": self.perda,
                "semente": self.semente,
                "duracao": duracao_pedida,
                "esquecer_s": self.esquecer_s,
            },
            "ambiente": self.ambiente,
        }

    def fechar(self):
        for c in self.clientes.values():
            c.sock.close()
        self.ouvinte.close()


def _endereco(texto, host_padrao=None, porta_zero=False):
    if ":" in texto:
        host, _, porta = texto.rpartition(":")
    else:
        host, porta = "", texto
    host = host or host_padrao
    if not host:
        raise argparse.ArgumentTypeError(f"falta o host em '{texto}' (HOST:PORTA)")
    try:
        p = int(porta)
    except ValueError:
        raise argparse.ArgumentTypeError(f"porta invalida em '{texto}'") from None
    if not (0 if porta_zero else 1) <= p <= 65535:
        raise argparse.ArgumentTypeError(f"porta fora da faixa em '{texto}'")
    return host, p


def _ler_argumentos(argv):
    ap = argparse.ArgumentParser(
        description="Proxy UDP que atrasa, embaralha e perde pacotes (teste de rede nivel 4).")
    ap.add_argument("--ouvir", required=True,
                    type=lambda t: _endereco(t, "127.0.0.1", porta_zero=True),
                    help="PORTA ou HOST:PORTA de escuta (0 = qualquer livre; o real sai na linha de subida)")
    ap.add_argument("--alvo", required=True, type=_endereco, help="HOST:PORTA do servidor real")
    ap.add_argument("--atraso-ms", type=float, default=0.0,
                    help="atraso fixo de UM sentido, aplicado nos dois (75 = ~150 ms de ida e volta)")
    ap.add_argument("--jitter-ms", type=float, default=0.0,
                    help="desvio por pacote, uniforme em [-j, +j]; reordena")
    ap.add_argument("--perda", type=float, default=0.0,
                    help="probabilidade de perder cada pacote, em cada sentido")
    ap.add_argument("--semente", type=int, default=1, help="semente do sorteio (padrao 1)")
    ap.add_argument("--duracao", type=float, default=0.0,
                    help="encerra sozinho depois de S segundos; 0 = nunca")
    ap.add_argument("--relatorio", default="", help="arquivo onde escrever o relatorio JSON ao sair")
    ap.add_argument("--esquecer-s", type=float, default=60.0,
                    help="solta o cliente depois de S segundos sem pacote dele, contados depois "
                         "do atraso (padrao 60)")
    a = ap.parse_args(argv)
    if a.atraso_ms < 0 or a.jitter_ms < 0:
        ap.error("atraso e jitter nao podem ser negativos")
    if not 0.0 <= a.perda <= 1.0:
        ap.error("--perda vai de 0 a 1")
    if a.esquecer_s <= 0:
        ap.error("--esquecer-s tem de ser positivo")
    return a


def main(argv=None):
    a = _ler_argumentos(argv)
    try:
        alvo = (socket.gethostbyname(a.alvo[0]), a.alvo[1])
        ouvir = (socket.gethostbyname(a.ouvir[0]), a.ouvir[1])
        proxy = Proxy(ouvir, alvo, a.atraso_ms, a.jitter_ms, a.perda, a.semente, a.esquecer_s)
    except OSError as e:
        print(PREFIXO + f"nao subiu: {e}", file=sys.stderr, flush=True)
        return 2

    def parar(numero, _quadro):
        proxy.rodando = False
        proxy.motivo = f"sinal {numero}"

    for nome in ("SIGTERM", "SIGBREAK", "SIGHUP"):
        sinal = getattr(signal, nome, None)
        if sinal is not None:
            try:
                signal.signal(sinal, parar)
            except (ValueError, OSError):
                pass

    print(PREFIXO + "ouvindo %s:%d -> %s:%d atraso %g ms jitter %g ms perda %g" % (
        proxy.ouvir[0], proxy.ouvir[1], alvo[0], alvo[1], a.atraso_ms, a.jitter_ms, a.perda),
        flush=True)

    proxy.ambiente["prioridade_acima_do_normal"] = prioridade_acima_do_normal()
    proxy.ambiente["timer_1ms"], restaurar = _relogio_fino()
    inicio = time.perf_counter()
    try:
        proxy.rodar(a.duracao)
    except KeyboardInterrupt:
        proxy.motivo = "interrompido"
    finally:
        restaurar()
    rel = proxy.relatorio(time.perf_counter() - inicio, a.duracao)
    proxy.fechar()
    linha = json.dumps(rel, ensure_ascii=True)
    if a.relatorio:
        try:
            with open(a.relatorio, "w", encoding="utf-8") as f:
                f.write(linha + "\n")
        except OSError as e:
            print(PREFIXO + f"relatorio nao escrito em {a.relatorio}: {e}", file=sys.stderr, flush=True)
    print(PREFIXO + linha, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
