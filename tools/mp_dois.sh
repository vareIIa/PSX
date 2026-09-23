#!/usr/bin/env bash
# Duas janelas do jogo na mesma maquina: uma hospeda, a outra entra.
#
#   ./tools/mp_dois.sh              abre as duas e deixa voce jogar (F7 abre a sessao)
#   ./tools/mp_dois.sh --foto       tira a foto do convidado vendo o anfitriao e fecha
#   ./tools/mp_dois.sh --dedicado   sobe um dedicado + duas janelas que entram nele
#   ./tools/mp_dois.sh --carro      o anfitriao na praca, de noite, fotografa dois
#                                   bots: um de carro (motorista no banco, farol,
#                                   rodas) e um a pe com a lanterna 30 graus abaixo
#
# E o nivel 4 com o jogo de verdade (Player, cidade, camera), para o que o bot
# headless nao mostra: se o amigo aparece com a roupa da carteira, se o nome
# fica em cima da cabeca, se a lanterna dele acende na nevoa.
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$RAIZ/.tools/Godot_v4.7.2-stable_win64_console.exe"
FOTO=0
DEDICADO=0
CARRO=0
for a in "$@"; do
  case "$a" in
    --foto) FOTO=1 ;;
    --dedicado) DEDICADO=1 ;;
    --carro) CARRO=1 ;;
  esac
done
PORTA=24567
LOGS="$(mktemp -d)"
COMUM=(--pular-menu --pular-abertura)
# O anfitriao nasce na praca da Matriz, olhando para a igreja: e o lugar que o
# jogo garante plano (relevo.gd poe a praca em y = 0) e com o preset de nevoa
# dela (memoria: preset da praca so com pin 270). Quem entra aparece do lado.
PRACA=(--ir-para=270,-40,271,-51)

if [ "$CARRO" -eq 1 ]; then
  mkdir -p "$RAIZ/captures/multiplayer"
  # Camera PRESA (`--olhar-igreja` com cinco numeros), e nao `--ir-para`: o
  # jogador vivo e empurrado por pedestre, e numa rodada ele foi parar 17 m longe
  # (memoria: --ir-para nao e regua). O pin da praca vai junto so pelo preset de
  # nevoa. E os bots PARADOS (`--bot-parado`), num lugar e num rumo conhecidos:
  # carro andando em circulo sai do quadro na hora da foto, e na avenida o
  # transito local para em cima dele (a replica ainda nao tem colisao, Fase 4).
  "$GODOT" --path "$RAIZ/game" --position 0,40 -- "${COMUM[@]}" \
    --ir-para=270,-40,274,-46 --olhar-igreja=266,-38,274,-46.5,1.0 \
    --mp-hospedar=$PORTA --mp-nome=ANFITRIAO \
    --shot="$RAIZ/captures/multiplayer/anfitriao_ve_carro_e_lanterna.png" \
    --shot-frame=1300 --shot-quit >"$LOGS/anfitriao.log" 2>&1 &
  HOST=$!
  sleep 8
  # Marea (modelo 5) estacionado de motor ligado: farol, facho na nevoa, brasa.
  "$GODOT" --headless --path "$RAIZ/game" res://scenes/net/bot_rede.tscn -- \
    --bot-entrar=127.0.0.1:$PORTA --bot-indice=0 --bot-duracao=40 \
    --bot-centro=276,-46 --bot-parado --bot-giro=76 --bot-carro=5,4410 --bot-lanterna \
    >"$LOGS/bot_carro.log" 2>&1 &
  B1=$!
  # A pe, lanterna ligada, olhando 35 graus para o chao: a poca de luz na frente
  # dele e a arfagem que viajou (medido: chao 1,7x mais claro que a +30 graus).
  "$GODOT" --headless --path "$RAIZ/game" res://scenes/net/bot_rede.tscn -- \
    --bot-entrar=127.0.0.1:$PORTA --bot-indice=1 --bot-duracao=40 \
    --bot-centro=271.5,-43.5 --bot-parado --bot-giro=200 --bot-lanterna --bot-arfagem=-35 \
    >"$LOGS/bot_pe.log" 2>&1 &
  B2=$!
  wait $HOST
  kill $B1 $B2 2>/dev/null
  echo "== anfitriao";  grep -E '^\[sessao\]|^\[servidor\]|ERROR|captur' "$LOGS/anfitriao.log" | head -20
  echo "logs em $LOGS"
  exit 0
fi

if [ "$DEDICADO" -eq 1 ]; then
  "$GODOT" --headless --path "$RAIZ/game" res://scenes/net/servidor_dedicado.tscn -- \
    --porta=$PORTA --sem-lan --config="$LOGS/servidor.cfg" >"$LOGS/servidor.log" 2>&1 &
  SRV=$!
  sleep 2
  "$GODOT" --path "$RAIZ/game" --position 0,40 -- "${COMUM[@]}" \
    --mp-entrar=127.0.0.1:$PORTA --mp-nome=PRIMEIRO >"$LOGS/a.log" 2>&1 &
  A=$!
  sleep 6
  "$GODOT" --path "$RAIZ/game" --position 640,380 -- "${COMUM[@]}" \
    --mp-entrar=127.0.0.1:$PORTA --mp-nome=SEGUNDO >"$LOGS/b.log" 2>&1
  kill $A $SRV 2>/dev/null
  echo "logs em $LOGS"
  exit 0
fi

"$GODOT" --path "$RAIZ/game" --position 0,40 -- "${COMUM[@]}" \
  "${PRACA[@]}" --mp-hospedar=$PORTA --mp-nome=ANFITRIAO >"$LOGS/anfitriao.log" 2>&1 &
HOST=$!
# A cidade do anfitriao monta chunk em thread; entrar antes do servidor abrir a
# porta e ouvir "ninguem respondeu".
sleep 8

if [ "$FOTO" -eq 1 ]; then
  mkdir -p "$RAIZ/captures/multiplayer"
  # 900 quadros de fisica = 15 s: boot, conexao, chegada com espera de chao e o
  # streaming montado em volta (memoria: primeira execucao nao vale captura).
  "$GODOT" --path "$RAIZ/game" --position 640,380 -- "${COMUM[@]}" \
    --mp-entrar=127.0.0.1:$PORTA --mp-nome=CONVIDADO \
    --shot="$RAIZ/captures/multiplayer/convidado_ve_anfitriao.png" --shot-frame=900 --shot-quit \
    >"$LOGS/convidado.log" 2>&1
  kill $HOST 2>/dev/null
  wait $HOST 2>/dev/null
else
  "$GODOT" --path "$RAIZ/game" --position 640,380 -- "${COMUM[@]}" \
    --mp-entrar=127.0.0.1:$PORTA --mp-nome=CONVIDADO >"$LOGS/convidado.log" 2>&1
  kill $HOST 2>/dev/null
fi

echo "== anfitriao";  grep -E '^\[sessao\]|^\[servidor\]|ERROR' "$LOGS/anfitriao.log" | head -20
echo "== convidado";  grep -E '^\[sessao\]|^\[shot|ERROR|captur' "$LOGS/convidado.log" | head -20
echo "logs em $LOGS"
