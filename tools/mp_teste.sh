#!/usr/bin/env bash
# Teste de rede de nivel 4 (plano 14): processos de verdade, sockets de verdade.
#
#   ./tools/mp_teste.sh             cenarios basicos e o mundo compartilhado (~90 s)
#   ./tools/mp_teste.sh --carga=16  tambem sobe um dedicado com 16 bots
#   ./tools/mp_teste.sh --rede-ruim tambem passa tres bots por um proxy com 150 ms
#                                   de ida e volta, 2% de perda e 30 ms de jitter
#                                   (tools/rede_ruim.py, plano 13 item 8.4)
#
# Cada bot anda numa trajetoria que e funcao da hora do servidor, e mede o
# boneco dos outros contra a verdade (src/net/bot_rede.gd). O teste falha se
# alguem nao entrar, nao enxergar os outros, se o erro passar do teto, se a
# recusa nao vier com o motivo certo, ou se o servidor escrever ERROR no log.
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$RAIZ/.tools/Godot_v4.7.2-stable_win64_console.exe"
TMP="$(mktemp -d)"
PORTA=24599
CARGA=0
RUIM=0
TRACO="${TRACO:-}"
for a in "$@"; do
  case "$a" in
    --carga=*) CARGA="${a#--carga=}" ;;
    --rede-ruim) RUIM=1 ;;
  esac
done

# Teto do erro do boneco remoto contra a verdade, em cm, no percentil 95, contado
# so nas amostras em que havia dado para o instante desenhado. A pe a 2,4 m/s,
# 5 cm e um oitavo do passo; a medida em localhost fica bem abaixo.
TETO_P95_CM=5
# Fracao maxima de amostras "com fome" (nada chegou alem do teto de
# extrapolacao). E entrega, nao interpolacao; numa maquina so, e o agendador.
TETO_FOME_PCT=3

srv() {  # porta, log, args...
  local porta="$1" log="$2"; shift 2
  "$GODOT" --headless --path "$RAIZ/game" res://scenes/net/servidor_dedicado.tscn -- \
    --porta="$porta" --sem-lan --config="$TMP/srv_$porta.cfg" "$@" >"$log" 2>&1 &
}
bot() {  # porta, indice, duracao, log, args...
  local porta="$1" i="$2" dur="$3" log="$4"; shift 4
  "$GODOT" --headless --path "$RAIZ/game" res://scenes/net/bot_rede.tscn -- \
    --bot-entrar=127.0.0.1:"$porta" --bot-indice="$i" --bot-duracao="$dur" "$@" >"$log" 2>&1 &
}

echo "== cenario A: dedicado, max 2, tres bots (o terceiro tem de ouvir 'cheio')"
srv $PORTA "$TMP/a_srv.log" --max-jogadores=2 --sair-apos=17
sleep 2
bot $PORTA 0 12 "$TMP/a_b0.log" --bot-falar=oi-do-zero
bot $PORTA 1 12 "$TMP/a_b1.log"
# O terceiro nasce junto (a subida do bot compila a cidade para a assinatura, e
# isso no meio da medida dos outros e carga de bancada) e liga 3 s depois.
bot $PORTA 2 7 "$TMP/a_b2.log" --bot-atraso=3

# B depois de A, e nao junto: a subida de B (servidor e tres bots compilando a
# cidade) caia no meio da medida de A.
wait

echo "== cenario B: dedicado com senha (errada recusa, certa entra, outra cidade recusada)"
srv $((PORTA+1)) "$TMP/b_srv.log" --senha=abacaxi --sair-apos=12
sleep 2
bot $((PORTA+1)) 0 5 "$TMP/b_errada.log" --bot-senha=banana
bot $((PORTA+1)) 1 5 "$TMP/b_certa.log" --bot-senha=abacaxi
# Mesma versao, outra cidade: o relevo desligado muda o que o gerador monta, e a
# assinatura do mundo (AssinaturaDoMundo) tem de recusar com o motivo.
bot $((PORTA+1)) 2 5 "$TMP/b_cidade.log" --bot-senha=abacaxi --sem-relevo

# A carga vem depois, sozinha. Tudo junto eram 16 Godots em 8 nucleos, e o que
# se media era o agendador do Windows.
wait

# O mundo compartilhado (plano 04 secao 11). O servidor nasce com 600 chunks
# alterados, a cara de uma tarde de jogo, para a carga de entrada ter tamanho.
# `--bot-acao-em` e hora do SERVIDOR: BOT0 e BOT1 pedem o mesmo item no mesmo
# instante, e so um pode levar.
echo "== cenario D: mundo compartilhado (porta, item disputado, pedidos negados, carga de entrada)"
srv $((PORTA+3)) "$TMP/d_srv.log" --mundo-sintetico=600 --sair-apos=30
sleep 2
bot $((PORTA+3)) 0 20 "$TMP/d_b0.log" --bot-acao-em=12 --bot-pegar=0,0,900,bandagem \
  --bot-mundo=0,0,porta_10_20_30
bot $((PORTA+3)) 1 20 "$TMP/d_b1.log" --bot-acao-em=12 --bot-pegar=0,0,900,bandagem \
  --bot-ler=0,0,porta_10_20_30
# O que o servidor tem de negar, e com o motivo: longe demais, e chave fora da
# lista (a carteira do Dinheiro nao e mundo).
bot $((PORTA+3)) 2 20 "$TMP/d_b2.log" --bot-acao-em=12 --bot-mundo=40,40,porta_1_1_1 \
  --bot-mundo=0,0,saldo
# Entra depois de tudo: tem de ler a porta aberta e o item pego pela carga.
bot $((PORTA+3)) 3 20 "$TMP/d_b3.log" --bot-atraso=10 --bot-ler=0,0,porta_10_20_30 \
  --bot-ler=0,0,item_900
wait

# Caido e levantar (plano 08 secao 3.3), com a espera do servidor em 10 s: o BOT0
# cai, o BOT1 vai a pe ate ele e o levanta; o BOT0 cai de novo, ninguem vem, e
# ele apaga. O BOT2 so olha. Os circulos dos bots ficam ate 16 m um do outro:
# a pe sao ate 7 s de caminhada.
echo "== cenario F: caido e levantar"
srv $((PORTA+6)) "$TMP/f_srv.log" --sair-apos=38 --mp-socorro-espera=10
sleep 2
bot $((PORTA+6)) 0 32 "$TMP/f_b0.log" --bot-cair-em=8,19
bot $((PORTA+6)) 1 32 "$TMP/f_b1.log" --bot-levantar=8.5,BOT0
bot $((PORTA+6)) 2 32 "$TMP/f_b2.log"
wait

# Dar item (plano 08 secao 1.3). O BOT1 espera parado com lugar para UMA
# bandagem so (4 numa pilha de 5, e 7 lanternas); o BOT2 espera vazio. O BOT0 vai
# a pe e da 3 ao BOT1 (entra 1, voltam 2) e depois 2 ao BOT2.
echo "== cenario G: dar item"
srv $((PORTA+7)) "$TMP/g_srv.log" --sair-apos=34
sleep 2
bot $((PORTA+7)) 0 28 "$TMP/g_b0.log" --bot-kit=bandagem:5 --bot-dar=8,BOT1,0,3 --bot-dar=8,BOT2,0,2
bot $((PORTA+7)) 1 28 "$TMP/g_b1.log" --bot-parado \
  --bot-kit=bandagem:4,lanterna:1,lanterna:1,lanterna:1,lanterna:1,lanterna:1,lanterna:1,lanterna:1
bot $((PORTA+7)) 2 28 "$TMP/g_b2.log" --bot-parado
wait

if [ "$RUIM" -eq 1 ]; then
  # 75 ms em cada sentido (150 de ida e volta), +-15 ms de jitter por pacote (30
  # de faixa, e pacote fora de ordem) e 2% de perda em cada sentido. O proxy da a
  # cada cliente o proprio socket de saida: o servidor ve tres enderecos.
  echo "== cenario E: rede ruim (150 ms ida e volta, 2% de perda, jitter de 30 ms)"
  srv $((PORTA+4)) "$TMP/e_srv.log" --sair-apos=34 ${TRACO:+--traco-servidor}
  python "$RAIZ/tools/rede_ruim.py" --ouvir=$((PORTA+5)) --alvo=127.0.0.1:$((PORTA+4)) \
    --atraso-ms=75 --jitter-ms=15 --perda=0.02 --duracao=36 >"$TMP/e_proxy.log" 2>&1 &
  sleep 2
  bot $((PORTA+5)) 0 26 "$TMP/e_b0.log" --bot-acao-em=16 --bot-mundo=0,0,porta_5_5_5 $TRACO
  bot $((PORTA+5)) 1 26 "$TMP/e_b1.log" --bot-acao-em=16 --bot-pegar=0,0,901,bateria $TRACO \
    --bot-ler=0,0,porta_5_5_5
  bot $((PORTA+5)) 2 26 "$TMP/e_b2.log" --bot-acao-em=16 --bot-pegar=0,0,901,bateria
  wait
fi

if [ "$CARGA" -gt 0 ]; then
  echo "== cenario C: dedicado com $CARGA bots"
  srv $((PORTA+2)) "$TMP/c_srv.log" --max-jogadores="$CARGA" --sair-apos=22
  sleep 2
  for i in $(seq 0 $((CARGA-1))); do
    bot $((PORTA+2)) "$i" 15 "$TMP/c_b$i.log"
  done
fi

wait

python - "$TMP" "$TETO_P95_CM" "$CARGA" "$TETO_FOME_PCT" "$RUIM" <<'PY'
import json, sys, glob, os, re
tmp, teto, carga, teto_fome = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4])
ruim = int(sys.argv[5])
# Na rede ruim o teto e o mesmo do localhost: o atraso de desenho de cada boneco
# segue a idade dos estados dele (BufferInterpolacao.avancar_atraso) e cobre um
# pacote perdido mais o jitter (plano 13 item 8.4).
TETO_RUIM_P95 = 5.0
TETO_RUIM_FOME = 3.0
falhas = []

def resultado(nome):
    caminho = os.path.join(tmp, nome)
    if not os.path.exists(caminho):
        return None
    for linha in open(caminho, encoding="utf-8", errors="replace"):
        if linha.startswith("[bot] RESULTADO "):
            return json.loads(linha[len("[bot] RESULTADO "):])
    return None

avisos_alheios = set()

def erros_no_log(nome):
    """Erros do log que reprovam a rede.

    Erro num script fora da rede e do que ela toca e de outra frente editando o
    jogo ao mesmo tempo (o dedicado compila e roda o gerador da cidade para a
    assinatura do mundo, e com ele a arvore de scripts que outra sessao pode estar
    no meio de editar). Esse vira aviso, com o arquivo, e nao reprova. Qualquer
    erro em src/net/ ou no que a rede toca reprova."""
    caminho = os.path.join(tmp, nome)
    linhas = open(caminho, encoding="utf-8", errors="replace").read().splitlines()
    saida = []
    for i, l in enumerate(linhas):
        if not re.match(r"^(ERROR|SCRIPT ERROR)", l):
            continue
        onde = linhas[i + 1].strip() if i + 1 < len(linhas) else ""
        m = re.search(r"res://([^:)]+)", onde)
        arquivo = m.group(1) if m else ""
        # O que a rede toca fora de src/net/: erro ali reprova, seja qual for.
        da_rede = arquivo.startswith("src/net/") or arquivo.startswith("tests/mp/") \
            or any(arquivo.endswith(x) for x in ("world_state.gd", "porta.gd", "item_no_chao.gd",
                                                 "interiores.gd", "plantio.gd", "save_game.gd",
                                                 "casa_viva.gd"))
        # Recurso que nao carrega (textura que outra frente ainda nao gerou).
        recurso = "res://assets/" in l or "res://resources/" in l or "Failed loading resource" in l
        if (arquivo and not da_rede) or (not arquivo and recurso):
            avisos_alheios.add(f"{arquivo or 'recurso'}: {l.strip()[:140]}")
            continue
        saida.append(l.strip() + (f"  [{onde}]" if onde else ""))
    return saida

def conferir(cond, msg):
    print(("  ok   " if cond else "  FALHA ") + msg)
    if not cond:
        falhas.append(msg)

def fome_pct(r):
    total = r["amostras"] + r["famintas"]
    return 100.0 * r["famintas"] / total if total else 0.0

def quadro_servidor(nome):
    caminho = os.path.join(tmp, nome)
    for l in open(caminho, encoding="utf-8", errors="replace"):
        m = re.search(r"quadro mais longo (\d+) ms", l)
        if m:
            return int(m.group(1))
    return -1

def conferir_bot(nome, r, outros, teto_p95=None, teto_f=None):
    teto_p95 = teto if teto_p95 is None else teto_p95
    teto_f = teto_fome if teto_f is None else teto_f
    if r is None:
        conferir(False, f"{nome}: sem linha de resultado")
        return
    conferir(r["estado"] == "ok", f"{nome}: entrou ({r['estado']} {r['recusa']})")
    faltando = sorted(set(outros) - set(r["vistos"]))
    conferir(not faltando, f"{nome}: viu {sorted(r['vistos'])}" + (f", faltou {faltando}" if faltando else ""))
    if outros:
        conferir(r["amostras"] > 100 and 0 <= r["erro_p95_cm"] <= teto_p95,
                 f"{nome}: erro p50 {r['erro_p50_cm']} cm, p95 {r['erro_p95_cm']} cm, "
                 f"max {r['erro_max_cm']} cm em {r['amostras']} amostras (teto p95 {teto_p95})")
        fome = fome_pct(r)
        conferir(fome <= teto_f, f"{nome}: com fome {r['famintas']} ({fome:.1f}%, "
                 f"pior {r['famintas_max_cm']} cm; teto {teto_f}%)")
    print(f"         ping {r['ping_ms']} ms, recebido {r['recebido_kbps']:.2f} KB/s, "
          f"quadro mais longo do bot {r['quadro_max_ms']} ms")

print("\n== A")
conferir_bot("BOT0", resultado("a_b0.log"), ["BOT1"])
conferir_bot("BOT1", resultado("a_b1.log"), ["BOT0"])
r1 = resultado("a_b1.log")
conferir(r1 is not None and any("BOT0: oi-do-zero" in c for c in r1.get("chat_ouvido", [])),
         f"chat: BOT1 ouviu o BOT0 ({r1 and r1.get('chat_ouvido')})")
r0 = resultado("a_b0.log")
conferir(r0 is not None and any("BOT0: oi-do-zero" in c for c in r0.get("chat_ouvido", [])),
         "chat: BOT0 ouviu o proprio recado de volta do servidor")
for nome, rr in (("BOT0", r0), ("BOT1", r1)):
    av = rr.get("relogio_avancou_s", 0) if rr else 0
    conferir(av >= 10, f"relogio: {nome} andou {av} s de jogo sem HUD (so o servidor anda)")
r = resultado("a_b2.log")
conferir(r is not None and r["estado"] == "recusado" and "cheio" in r["recusa"].lower(),
         f"BOT2 recusado por servidor cheio ({r and r['recusa']})")
e = erros_no_log("a_srv.log")
conferir(not e, "servidor A sem ERROR no log" + (f": {e[:3]}" if e else ""))
print(f"         quadro mais longo do servidor A: {quadro_servidor('a_srv.log')} ms")

print("\n== B")
r = resultado("b_errada.log")
conferir(r is not None and r["estado"] == "recusado" and "senha" in r["recusa"].lower(),
         f"senha errada recusada ({r and r['recusa']})")
r = resultado("b_certa.log")
conferir(r is not None and r["estado"] == "ok", f"senha certa entrou ({r and r['estado']})")
r = resultado("b_cidade.log")
conferir(r is not None and r["estado"] == "recusado" and "cidade" in r["recusa"].lower(),
         f"cidade diferente (--sem-relevo) recusada ({r and r['recusa']})")
e = erros_no_log("b_srv.log")
conferir(not e, "servidor B sem ERROR no log" + (f": {e[:3]}" if e else ""))

def lido(r, chave):
    return (r or {}).get("lidos", {}).get(chave)

def conferir_disputa(rotulo, a, b):
    """Dois bots pediram o mesmo item: exatamente um leva, o outro ouve JA_FOI.
    E a soma das mochilas que prova (memoria: adicionar devolve a SOBRA)."""
    pegou = [(r or {}).get("pegou") for r in (a, b)]
    motivos = [(r or {}).get("motivo_pegar") for r in (a, b)]
    mochilas = [(r or {}).get("mochila_item", 0) for r in (a, b)]
    conferir(pegou.count(True) == 1 and pegou.count(False) == 1 and "JA_FOI" in motivos,
             f"{rotulo}: um leva, o outro ouve JA_FOI ({pegou}, {motivos})")
    conferir(sum(mochilas) == 1, f"{rotulo}: soma das mochilas = {sum(mochilas)} ({mochilas})")

print("\n== D")
d = [resultado(f"d_b{i}.log") for i in range(4)]
for i, r in enumerate(d):
    m = (r or {}).get("mundo", {})
    conferir(r is not None and r["estado"] == "ok" and r.get("mundo_pronto") is True,
             f"BOT{i}: entrou e recebeu o mundo ({m.get('bytes', 0) / 1024:.1f} KB em "
             f"{m.get('partes', 0)} parte(s), {m.get('ms', -1)} ms)")
conferir_disputa("item disputado no mesmo instante", d[0], d[1])
conferir(lido(d[1], "0,0|porta_10_20_30") is True,
         f"porta aberta pelo BOT0 aparece aberta no BOT1 ({lido(d[1], '0,0|porta_10_20_30')})")
neg = (d[2] or {}).get("negados", [])
conferir("LONGE" in neg, f"pedido a dois chunks negado com LONGE ({neg})")
conferir("INVALIDO" in neg, f"chave fora da lista (saldo) negada com INVALIDO ({neg})")
conferir(lido(d[3], "0,0|porta_10_20_30") is True and lido(d[3], "0,0|item_900") is True,
         f"quem entra depois le a porta e o item pela carga ({(d[3] or {}).get('lidos')})")
m3 = (d[3] or {}).get("mundo", {})
conferir(m3.get("bytes", 0) > 4096, f"a carga de entrada tem o mundo sintetico ({m3.get('bytes', 0)} bytes)")
e = erros_no_log("d_srv.log")
conferir(not e, "servidor D sem ERROR no log" + (f": {e[:3]}" if e else ""))
for i in range(4):
    e = erros_no_log(f"d_b{i}.log")
    conferir(not e, f"BOT{i} de D sem ERROR no log" + (f": {e[:3]}" if e else ""))

print("\n== F")
f = [resultado(f"f_b{i}.log") for i in range(3)]
so = [(r or {}).get("socorro", {}) for r in f]
conferir(so[0].get("quedas") == 2, f"BOT0 caiu duas vezes ({so[0].get('quedas')})")
conferir(so[0].get("levantado_por") == ["BOT1"],
         f"a primeira queda: BOT1 foi a pe e levantou o BOT0 ({so[0].get('levantado_por')}; "
         f"BOT1 pediu {so[1].get('pediu_levantar')} vez)")
conferir(so[0].get("apagou") == 1, f"a segunda queda, sem ajuda: apagou no fim da espera ({so[0].get('apagou')})")
for i in (1, 2):
    conferir("BOT0" in so[i].get("viu_caido", []), f"BOT{i} viu o BOT0 no chao (F_CAIDO) ({so[i].get('viu_caido')})")
e = erros_no_log("f_srv.log")
conferir(not e, "servidor F sem ERROR no log" + (f": {e[:3]}" if e else ""))
for i in range(3):
    e = erros_no_log(f"f_b{i}.log")
    conferir(not e, f"BOT{i} de F sem ERROR no log" + (f": {e[:3]}" if e else ""))

print("\n== G")
g = [resultado(f"g_b{i}.log") or {} for i in range(3)]
ban = lambda r, k: int(r.get(k, {}).get("bandagem", 0))
conferir(g[0].get("deu") == [[True, "bandagem", 1, ""], [True, "bandagem", 2, ""]],
         f"BOT0 deu 1 ao BOT1 (so cabia 1) e 2 ao BOT2 ({g[0].get('deu')})")
conferir(ban(g[1], "mochila_fim") - ban(g[1], "mochila_ini") == 1 and ban(g[2], "mochila_fim") == 2,
         f"entrou 1 no BOT1 e 2 no BOT2 ({ban(g[1], 'mochila_ini')}->{ban(g[1], 'mochila_fim')}, "
         f"{ban(g[2], 'mochila_ini')}->{ban(g[2], 'mochila_fim')})")
conferir(ban(g[0], "mochila_ini") - ban(g[0], "mochila_fim") == 3,
         f"saiu de A = entrou em B + C, e a sobra voltou (BOT0 {ban(g[0], 'mochila_ini')}->{ban(g[0], 'mochila_fim')})")
total_ini = sum(ban(r, "mochila_ini") for r in g)
total_fim = sum(ban(r, "mochila_fim") for r in g)
conferir(total_ini == total_fim == 9, f"nenhuma bandagem nasceu nem sumiu ({total_ini} -> {total_fim})")
conferir(int(g[1].get("mochila_fim", {}).get("lanterna", 0)) == 7, "as lanternas do BOT1 ficaram")
e = erros_no_log("g_srv.log")
conferir(not e, "servidor G sem ERROR no log" + (f": {e[:3]}" if e else ""))
for i in range(3):
    e = erros_no_log(f"g_b{i}.log")
    conferir(not e, f"BOT{i} de G sem ERROR no log" + (f": {e[:3]}" if e else ""))

if ruim:
    print("\n== E (rede ruim)")
    er = [resultado(f"e_b{i}.log") for i in range(3)]
    nomes = ["BOT0", "BOT1", "BOT2"]
    for i, r in enumerate(er):
        conferir_bot(nomes[i], r, [n for n in nomes if n != nomes[i]], TETO_RUIM_P95, TETO_RUIM_FOME)
    conferir_disputa("item disputado com perda", er[1], er[2])
    conferir(lido(er[1], "0,0|porta_5_5_5") is True,
             f"porta aberta com perda aparece aberta no outro ({lido(er[1], '0,0|porta_5_5_5')})")
    for l in open(os.path.join(tmp, "e_proxy.log"), encoding="utf-8", errors="replace"):
        if l.startswith("[rede_ruim] {"):
            print("         " + l.strip()[:400])

if carga:
    print(f"\n== C ({carga} bots)")
    nomes = [f"BOT{i}" for i in range(carga)]
    p95 = []
    kbps = []
    fomes = []
    for i in range(carga):
        r = resultado(f"c_b{i}.log")
        if r is None or r["estado"] != "ok":
            conferir(False, f"BOT{i} nao entrou ({r and r['estado']})")
            continue
        faltando = sorted(set(nomes) - {f"BOT{i}"} - set(r["vistos"]))
        if faltando:
            conferir(False, f"BOT{i} nao viu {faltando}")
        p95.append(r["erro_p95_cm"])
        kbps.append(r["recebido_kbps"])
        fomes.append(fome_pct(r))
    if p95:
        conferir(max(p95) <= teto, f"pior p95 entre {len(p95)} bots: {max(p95)} cm")
        conferir(max(fomes) <= teto_fome, f"pior fome entre {len(fomes)} bots: {max(fomes):.1f}%")
        print(f"         quadro mais longo do servidor C: {quadro_servidor('c_srv.log')} ms")
        print(f"         banda recebida por cliente: media {sum(kbps)/len(kbps):.2f} KB/s, max {max(kbps):.2f} KB/s")
    e = erros_no_log("c_srv.log")
    conferir(not e, "servidor C sem ERROR no log" + (f": {e[:3]}" if e else ""))

if avisos_alheios:
    print(f"\n== aviso: {len(avisos_alheios)} erro(s) de compilacao fora da rede (outra frente editando?)")
    for a in sorted(avisos_alheios)[:8]:
        print(f"         {a}")

print()
if falhas:
    print(f"FALHOU — {len(falhas)} conferencia(s). Logs em {tmp}")
    sys.exit(1)
print(f"OK — logs em {tmp}")
PY
