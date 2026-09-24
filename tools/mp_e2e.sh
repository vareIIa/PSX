#!/usr/bin/env bash
# Ponta a ponta com o jogo de verdade (plano 14, nivel 4, e o que o bot nao ve):
# duas cidades inteiras, uma hospeda e a outra entra, cada uma com a sonda
# (game/src/net/sonda_e2e.gd) mexendo na mesma porta de rua e no mesmo item.
#
#   ./tools/mp_e2e.sh            sem janela (--headless), ~90 s
#   ./tools/mp_e2e.sh --janela   com duas janelas pequenas, para ver acontecer
#
# Confere: os dois se veem; a porta aberta pelo anfitriao abre no convidado, a
# fechada pelo convidado fecha no anfitriao, e reabre; o item disputado no mesmo
# instante vai para uma mochila so; o chat chega; quem sai volta ao proprio mundo
# com o que carrega (P11); nenhum SCRIPT ERROR em nenhum dos dois.
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$RAIZ/.tools/Godot_v4.7.2-stable_win64_console.exe"
TELA=(--headless)
for a in "$@"; do
  case "$a" in
    --janela) TELA=(--resolution 640x360) ;;
  esac
done
PORTA=24587
T0=${T0:-75}
TMP="$(mktemp -d)"
COMUM=(--pular-menu --pular-abertura --ir-para=270,-40,271,-51)

"$GODOT" "${TELA[@]}" --path "$RAIZ/game" --position 0,40 -- "${COMUM[@]}" \
  --mp-hospedar=$PORTA --mp-validacao=corrigir --mp-nome=ANFITRIAO --mp-sonda=anfitriao --sonda-t0=$T0 \
  >"$TMP/anfitriao.log" 2>&1 &
HOST=$!
# A cidade do anfitriao monta chunk em thread; entrar antes de a porta abrir e
# ouvir "ninguem respondeu".
sleep 15
"$GODOT" "${TELA[@]}" --path "$RAIZ/game" --position 660,40 -- "${COMUM[@]}" \
  --mp-entrar=127.0.0.1:$PORTA --mp-nome=CONVIDADO --mp-sonda=convidado --sonda-t0=$T0 \
  >"$TMP/convidado.log" 2>&1 &
CONV=$!
wait $CONV
wait $HOST

python - "$TMP" <<'PY'
import json, sys, re, os
tmp = sys.argv[1]
falhas = []
def ok(cond, texto):
    print(("  ok   " if cond else "  FALHA ") + texto)
    if not cond:
        falhas.append(texto)

def ler(nome):
    txt = open(os.path.join(tmp, nome), encoding="utf-8", errors="replace").read()
    m = re.findall(r"^\[sonda\] RESULTADO (.*)$", txt, re.M)
    # "resources still in use at exit" e o motor fechando no meio da cena (a sonda
    # da quit com chunk montando). Recurso que nao carrega e trabalho de outra
    # frente no meio (textura que ainda nao existe): aviso, nao falha de rede.
    alheio = ("still in use at exit", "Failed loading resource", "[ext_resource]",
              "Failed to load resource", "res://assets/", "res://resources/")
    # SCRIPT ERROR e atribuido ao script da linha "at:" logo abaixo. Reprova se
    # for da rede ou do que ela toca; de outra frente, vira aviso com o arquivo.
    nosso = ("res://src/net/", "world_state.gd", "porta.gd", "item_no_chao.gd",
             "interiores.gd", "plantio.gd", "save_game.gd", "sonda_e2e.gd")
    linhas = txt.splitlines()
    erros, avisos = [], []
    for i, l in enumerate(linhas):
        if "SCRIPT ERROR" in l:
            onde = next((x for x in linhas[i + 1:i + 3] if "at:" in x), "")
            if onde and not any(n in onde for n in nosso):
                avisos.append(l + " " + onde.strip())
            else:
                erros.append(l + " " + onde.strip())
        elif l.startswith("ERROR"):
            (avisos if any(x in l for x in alheio) else erros).append(l)
    if avisos:
        uni = sorted(set(a[:160] for a in avisos))
        print("  aviso %s: %d erro(s) de outra frente, %d distinto(s):" % (nome, len(avisos), len(uni)))
        for u in uni[:4]:
            print("         " + u)
    return (json.loads(m[-1]) if m else None), erros, txt

a, ea, ta = ler("anfitriao.log")
c, ec, tc = ler("convidado.log")
ok(a is not None, "anfitriao imprimiu o resultado")
ok(c is not None, "convidado imprimiu o resultado")
if a is None or c is None:
    for l in (ta.splitlines()[-15:] + ["--"] + tc.splitlines()[-15:]):
        print("       " + l)
    sys.exit(1)
for papel, r in (("anfitriao", a), ("convidado", c)):
    ok("erro" not in r, "%s sem erro de roteiro (%s)" % (papel, r.get("erro", "")))
    ok(r.get("viu", 0) >= 1, "%s ve o outro (%s)" % (papel, r.get("viu")))
    ok(r.get("mundo_pronto") is True, "%s com o mundo pronto" % papel)
    ok(r.get("porta", "") != "", "%s achou porta de rua (%s a %s m)" % (papel, r.get("porta"), r.get("porta_distancia")))
ok(a.get("porta") == c.get("porta"), "os dois escolheram a mesma porta (%s / %s)" % (a.get("porta"), c.get("porta")))
ra, rc = a.get("registros", {}), c.get("registros", {})
for nome, esperado, quem in (("r1", True, "anfitriao abriu"), ("r2", False, "convidado fechou"), ("r3", True, "anfitriao reabriu")):
    va = ra.get(nome, {}); vc = rc.get(nome, {})
    ok(va.get("aberta") is esperado and vc.get("aberta") is esperado,
       "%s: folha %s nas duas maquinas (anf %s, conv %s)" % (quem, "aberta" if esperado else "fechada", va.get("aberta"), vc.get("aberta")))
    ok(bool(va.get("mundo_porta")) is esperado and bool(vc.get("mundo_porta")) is esperado,
       "%s: WorldState igual nas duas (anf %s, conv %s)" % (quem, va.get("mundo_porta"), vc.get("mundo_porta")))
ma = ra.get("r3", {}).get("mochila", -1); mc = rc.get("r3", {}).get("mochila", -1)
ok(ma + mc == 1, "item disputado: soma das mochilas = 1 (anf %s, conv %s)" % (ma, mc))
ok(not ra.get("r3", {}).get("item_vivo", True) and not rc.get("r3", {}).get("item_vivo", True),
   "item sumiu do chao nas duas")
ok(any("oi-da-sonda" in l for l in a.get("ouvido", [])), "anfitriao ouviu o chat do convidado")
# Familias da PoliticaDeMundo.
r1a = ra.get("r1", {}); r1c = rc.get("r1", {})
ok(r1c.get("profissao") == "fazendeiro", "MUNDO: a profissao que o anfitriao deu chega ao convidado (%r)" % r1c.get("profissao"))
ok(r1a.get("saldo") == 7777 and r1c.get("saldo") != 7777,
   "PESSOA: a carteira do anfitriao fica com ele (anf %s, conv %s)" % (r1a.get("saldo"), r1c.get("saldo")))
ok(r1a.get("falou_sonda") is True and r1c.get("falou_sonda") is False,
   "PESSOA: a conversa ouvida pelo anfitriao nao conta como ouvida pelo convidado")
esperado = {"vagas": {"1": {"n": 4}, "2": {"n": 3}}}
ok(r1a.get("prateleira") == esperado and r1c.get("prateleira") == esperado,
   "FUSAO: duas maos na mesma prateleira no mesmo instante, as duas ficam (anf %s, conv %s)" % (r1a.get("prateleira"), r1c.get("prateleira")))
ok(r1c.get("mochila_casa") == 1 and r1a.get("mundo_casa") is True and r1c.get("mundo_casa") is True,
   "COMODO pela rua: item de dentro da casa da rua pego da calcada (conv %s, mundo %s/%s)" % (r1c.get("mochila_casa"), r1a.get("mundo_casa"), r1c.get("mundo_casa")))
r5a0 = ra.get("r5", {}); r5c0 = rc.get("r5", {})
ok(r5a0.get("visitou_marca") is True and r5c0.get("visitou_marca_anf") is True,
   "MAPA do grupo: o chunk que um pisou aparece no mapa do outro (anf ve o do conv %s, conv ve o do anf %s)" % (r5a0.get("visitou_marca"), r5c0.get("visitou_marca_anf")))
r4c = rc.get("r4", {})
ok(r4c.get("visitou_marca") is True and r4c.get("visitou_marca_anf") is True,
   "o convidado sai levando o mapa inteiro que viu (proprio %s, do grupo %s)" % (r4c.get("visitou_marca"), r4c.get("visitou_marca_anf")))
ok(r4c.get("mochila_casa") == 1, "o remedio da casa vai junto na saida (%s)" % r4c.get("mochila_casa"))
ok(a.get("mirou_item") is True and c.get("mirou_item") is True,
   "o raio da camera escolheu o item nas duas maquinas antes do [E] (anf %s, conv %s)" % (a.get("mirou_item"), c.get("mirou_item")))
rd = rc.get("r_dentro", {})
ok(rd.get("espaco", 0) >= 16, "o convidado entrou num comodo teleportado (espaco %s)" % rd.get("espaco"))
ok(rc.get("r5", {}).get("espaco") == 0, "e voltou para a rua (espaco %s)" % rc.get("r5", {}).get("espaco"))
ok(rc.get("r5", {}).get("correcoes") == 0 and ra.get("r5", {}).get("suspeitas") == 0,
   "com a validacao em CORRIGIR, a rota honesta (teletransporte, comodo, volta) nao leva correcao nem suspeita (correcoes %s, suspeitas %s)" % (rc.get("r5", {}).get("correcoes"), ra.get("r5", {}).get("suspeitas")))
r5a = ra.get("r5", {}); r5c = rc.get("r5", {})
ok(r5a.get("aberta") is False and not r5a.get("mundo_porta"),
   "anfitriao carregou save no meio: a porta dele assenta fechada (%s, %s)" % (r5a.get("aberta"), r5a.get("mundo_porta")))
ok(r5c.get("aberta") is False and not r5c.get("mundo_porta") and r5c.get("modo") == 4,
   "convidado recebeu o mundo de novo e segue na sessao (%s, %s, modo %s)" % (r5c.get("aberta"), r5c.get("mundo_porta"), r5c.get("modo")))
ok(any("carregou outro jogo" in l for l in c.get("ouvido", [])), "convidado foi avisado da recarga")
rca = ra.get("r_caido", {}); rla = ra.get("r_levantado", {})
ok(rca.get("no_chao") is True and rca.get("caido") is True and rca.get("vida") == 0,
   "CAIDO: vida zero em rede derruba, nao apaga (no chao %s, caido %s, vida %s)" % (rca.get("no_chao"), rca.get("caido"), rca.get("vida")))
ok("Levantar" in str(c.get("prompt_antes", "")) and "Levantando" in str(c.get("prompt_segurando", "")),
   "o convidado ve [E] no corpo e o progresso ao segurar (%r, %r)" % (c.get("prompt_antes"), c.get("prompt_segurando")))
ok(rla.get("no_chao") is False and rla.get("caido") is False and rla.get("vida") == 25 and rla.get("travado") is False,
   "segurar [E] 3 s LEVANTA o amigo: vida 25 e controle de volta (%s)" % rla)
ok(bool(a.get("levantado_por")), "o anfitriao sabe quem o levantou (%r)" % a.get("levantado_por"))
dr = (rla.get("relogio") or 0) - (a.get("relogio_antes") or 0)
ok(0 <= dr <= 2, "caido em rede nao pula a hora de ninguem (%s min de jogo)" % dr)
r4 = rc.get("r4", {})
ok(r4.get("modo") == 0, "convidado saiu para SOLO (modo %s)" % r4.get("modo"))
ok(not r4.get("mundo_porta"), "convidado de volta ao proprio mundo: porta do anfitriao nao esta no dele (%s)" % r4.get("mundo_porta"))
ok(not r4.get("mundo_item"), "item pego no mundo do anfitriao nao existe como pego no dele (%s)" % r4.get("mundo_item"))
ok(r4.get("mochila") == mc, "convidado levou a mochila junto (%s -> %s)" % (mc, r4.get("mochila")))
ok(r4.get("aberta") is False, "a folha da porta volta ao estado do proprio mundo (%s)" % r4.get("aberta"))
ok(ra.get("r3", {}).get("viu", 0) >= 1, "anfitriao via o convidado antes da saida")
ok(not ea, "anfitriao sem SCRIPT ERROR/ERROR (%d) %s" % (len(ea), ea[:3]))
ok(not ec, "convidado sem SCRIPT ERROR/ERROR (%d) %s" % (len(ec), ec[:3]))
print()
print(("OK" if not falhas else "FALHOU (%d)" % len(falhas)) + " — logs em " + tmp)
sys.exit(1 if falhas else 0)
PY
