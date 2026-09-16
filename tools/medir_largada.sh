#!/usr/bin/env bash
# Quanto cada AUTOLOAD custa na largada (PLANO_AAA_4K, criterio A3).
#
#   bash tools/medir_largada.sh [repeticoes]
#
# Por que nao da para medir isso de dentro do jogo. Quando o `_ready` do
# primeiro autoload roda, os 26 filhos de /root JA existem — o motor instancia
# todos os autoloads e a cena principal, e so depois propaga `_ready`. Ou seja,
# nenhum no consegue cronometrar o vizinho; `node_added` nao ve nada (medido).
#
# Entao a medida vem de execucoes SEPARADAS: uma copia do projeto, cena
# principal vazia, e a lista de autoloads truncada em k. A diferenca entre k e
# k-1 e o que o autoload k custa — compilar o script, `_init` e `_ready`.
#
# Roda sem janela: o numero absoluto fica menor que o do jogo de verdade (a
# largada com janela e ~2,6 s contra ~1,8 s aqui), mas a REPARTICAO e a mesma, e
# e ela que diz em quem mexer.
#
# Saida: uma linha por autoload, com o acumulado e o custo proprio.

set -u
cd "$(git rev-parse --show-toplevel)"
REPETICOES=${1:-2}
GODOT=".tools/Godot_v4.7.2-stable_win64_console.exe"
COPIA=$(mktemp -d -t largada.XXXXXX)
trap 'rm -rf "$COPIA"' EXIT

# A copia leva o .godot junto: sem o cache de importacao, cada execucao
# reimportaria o projeto inteiro e a medida seria de importacao, nao de largada.
tar -C . -cf - game | tar -x -C "$COPIA"
cat > "$COPIA/game/_largada.gd" <<'EOF'
extends Node
func _ready() -> void:
	print("[largada] pronto em ", Time.get_ticks_msec(), " ms")
	get_tree().quit(0)
EOF
cat > "$COPIA/game/_largada.tscn" <<'EOF'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://_largada.gd" id="1"]

[node name="Largada" type="Node"]
script = ExtResource("1")
EOF

ORIG="$COPIA/game/project.godot"
cp "$ORIG" "$COPIA/base.godot"
mapfile -t NOMES < <(sed -n '/^\[autoload\]/,/^\[/p' "$ORIG" | grep '^[A-Za-z]*="')
PROJ_W=$(cygpath -m "$COPIA/game")
echo "largada: ${#NOMES[@]} autoloads, $REPETICOES repeticoes por ponto"

anterior=0
for k in $(seq 0 ${#NOMES[@]}); do
  python - "$COPIA/base.godot" "$ORIG" "$k" <<'PY'
import io, sys
bak, saida, k = sys.argv[1], sys.argv[2], int(sys.argv[3])
s = io.open(bak, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in s else "\n"
fora, dentro, n = [], False, 0
for l in s.split(nl):
    if l.startswith("[autoload]"):
        dentro = True
    elif dentro and l.startswith("["):
        dentro = False
    if dentro and '="*res://' in l:
        n += 1
        if n > k:
            continue
    if l.startswith("run/main_scene="):
        l = 'run/main_scene="res://_largada.tscn"'
    fora.append(l)
io.open(saida, "w", encoding="utf-8", newline="").write(nl.join(fora))
PY
  melhor=999999
  for _ in $(seq 1 "$REPETICOES"); do
    ms=$(timeout 180 "$GODOT" --headless --path "$PROJ_W" 2>&1 \
      | grep -oE '\[largada\] pronto em [0-9]+' | grep -oE '[0-9]+$')
    # O MENOR de N: a largada so sofre interferencia para cima (disco, outro
    # processo), nunca para baixo. Media aqui mediria o vizinho.
    [ -n "${ms:-}" ] && [ "$ms" -lt "$melhor" ] && melhor=$ms
  done
  nome="(so o motor)"
  [ "$k" -gt 0 ] && nome=$(echo "${NOMES[$((k-1))]}" | cut -d= -f1)
  if [ "$k" = 0 ]; then
    printf "%-18s %6s ms\n" "$nome" "$melhor"
  else
    printf "%-18s %6s ms   (+%s)\n" "$nome" "$melhor" "$((melhor - anterior))"
  fi
  anterior=$melhor
done
