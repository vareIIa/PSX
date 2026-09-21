#!/usr/bin/env bash
# Teste de rede de nivel 4 (plano 14): processos de verdade, sockets de verdade.
#
#   ./tools/mp_teste.sh            cenarios basicos (~40 s)
#   ./tools/mp_teste.sh --carga=16 tambem sobe um dedicado com 16 bots
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
for a in "$@"; do
  case "$a" in
    --carga=*) CARGA="${a#--carga=}" ;;
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
bot $PORTA 0 12 "$TMP/a_b0.log"
bot $PORTA 1 12 "$TMP/a_b1.log"
sleep 3
bot $PORTA 2 4 "$TMP/a_b2.log"

echo "== cenario B: dedicado com senha (errada recusa, certa entra)"
srv $((PORTA+1)) "$TMP/b_srv.log" --senha=abacaxi --sair-apos=12
sleep 2
bot $((PORTA+1)) 0 5 "$TMP/b_errada.log" --bot-senha=banana
bot $((PORTA+1)) 1 5 "$TMP/b_certa.log" --bot-senha=abacaxi

# A e B juntos sao 6 processos; a carga vem depois, sozinha. Tudo junto eram
# 16 Godots em 8 nucleos, e o que se media era o agendador do Windows.
wait

if [ "$CARGA" -gt 0 ]; then
  echo "== cenario C: dedicado com $CARGA bots"
  srv $((PORTA+2)) "$TMP/c_srv.log" --max-jogadores="$CARGA" --sair-apos=22
  sleep 2
  for i in $(seq 0 $((CARGA-1))); do
    bot $((PORTA+2)) "$i" 15 "$TMP/c_b$i.log"
  done
fi

wait

python - "$TMP" "$TETO_P95_CM" "$CARGA" "$TETO_FOME_PCT" <<'PY'
import json, sys, glob, os, re
tmp, teto, carga, teto_fome = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4])
falhas = []

def resultado(nome):
    caminho = os.path.join(tmp, nome)
    if not os.path.exists(caminho):
        return None
    for linha in open(caminho, encoding="utf-8", errors="replace"):
        if linha.startswith("[bot] RESULTADO "):
            return json.loads(linha[len("[bot] RESULTADO "):])
    return None

def erros_no_log(nome):
    caminho = os.path.join(tmp, nome)
    return [l.strip() for l in open(caminho, encoding="utf-8", errors="replace")
            if re.match(r"^(ERROR|SCRIPT ERROR)", l)]

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

def conferir_bot(nome, r, outros):
    if r is None:
        conferir(False, f"{nome}: sem linha de resultado")
        return
    conferir(r["estado"] == "ok", f"{nome}: entrou ({r['estado']} {r['recusa']})")
    faltando = sorted(set(outros) - set(r["vistos"]))
    conferir(not faltando, f"{nome}: viu {sorted(r['vistos'])}" + (f", faltou {faltando}" if faltando else ""))
    if outros:
        conferir(r["amostras"] > 100 and 0 <= r["erro_p95_cm"] <= teto,
                 f"{nome}: erro p50 {r['erro_p50_cm']} cm, p95 {r['erro_p95_cm']} cm, "
                 f"max {r['erro_max_cm']} cm em {r['amostras']} amostras (teto p95 {teto})")
        fome = fome_pct(r)
        conferir(fome <= teto_fome, f"{nome}: com fome {r['famintas']} ({fome:.1f}%, "
                 f"pior {r['famintas_max_cm']} cm; teto {teto_fome}%)")
    print(f"         ping {r['ping_ms']} ms, recebido {r['recebido_kbps']:.2f} KB/s, "
          f"quadro mais longo do bot {r['quadro_max_ms']} ms")

print("\n== A")
conferir_bot("BOT0", resultado("a_b0.log"), ["BOT1"])
conferir_bot("BOT1", resultado("a_b1.log"), ["BOT0"])
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
e = erros_no_log("b_srv.log")
conferir(not e, "servidor B sem ERROR no log" + (f": {e[:3]}" if e else ""))

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

print()
if falhas:
    print(f"FALHOU — {len(falhas)} conferencia(s). Logs em {tmp}")
    sys.exit(1)
print(f"OK — logs em {tmp}")
PY
