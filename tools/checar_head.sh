#!/usr/bin/env bash
# Criterio A1 do PLANO_AAA_4K: uma revisao do git compila SOZINHA?
#
#   bash tools/checar_head.sh               o HEAD
#   bash tools/checar_head.sh REV           qualquer revisao (sha, branch)
#   bash tools/checar_head.sh --indice      o que esta no indice agora (o commit
#                                           que sairia de um `git commit`)
#   bash tools/checar_head.sh --working-tree o working tree como esta (linha de
#                                           base: o que roda hoje na maquina)
#   bash tools/checar_head.sh --manter ...  nao apaga a copia (para investigar)
#
# Variavel CHECAR_HEAD_QUADROS: quantos quadros a cidade roda (1200).
#
# Copia a revisao (so a pasta game/) para uma pasta temporaria com `git archive`
# — sem worktree, sem tocar em .git alem de objetos —, importa, e roda
# tools/checar_head_cena.gd como cena principal, que compila todo script e
# carrega toda cena, recurso e shader.
#
# O working tree deste repositorio costuma ter centenas de arquivos de outras
# sessoes; e exatamente por isso que "abre no editor" nao prova que o commit
# abre. Esta checagem so enxerga o que esta no git (fora o `--working-tree`).
#
# Isolamento: a copia ganha `use_custom_user_dir`, para nao ler nem gravar o
# user://settings.cfg do jogo de verdade (memoria "duas builds leem o mesmo
# settings.cfg").
#
# Saida: 0 se compila e a cidade roda limpa; 1 se nao; 2 se a checagem nao
# chegou ao fim.

set -u

RAIZ=$(git rev-parse --show-toplevel)
GODOT="$RAIZ/.tools/Godot_v4.7.2-stable_win64_console.exe"
MANTER=0
ALVO=HEAD
for arg in "$@"; do
  case "$arg" in
    --manter) MANTER=1 ;;
    --indice) ALVO=--indice ;;
    --working-tree) ALVO=--working-tree ;;
    *) ALVO="$arg" ;;
  esac
done

if [ "$ALVO" = "--indice" ]; then
  ARVORE=$(git -C "$RAIZ" write-tree) || exit 2
  ROTULO="indice ($ARVORE)"
elif [ "$ALVO" = "--working-tree" ]; then
  ARVORE=
  ROTULO="working tree"
else
  ARVORE=$(git -C "$RAIZ" rev-parse --verify "$ALVO^{tree}") || exit 2
  ROTULO="$ALVO ($(git -C "$RAIZ" rev-parse --short "$ALVO"))"
fi

COPIA=$(mktemp -d -t checar_head.XXXXXX)
limpar() { [ "$MANTER" = 1 ] && echo "copia mantida em $COPIA" || rm -rf "$COPIA"; }
trap limpar EXIT

if [ -n "$ARVORE" ]; then
  git -C "$RAIZ" archive "$ARVORE" game | tar -x -C "$COPIA" || exit 2
else
  tar -C "$RAIZ" --exclude=game/.godot -cf - game | tar -x -C "$COPIA" || exit 2
fi
PROJ="$COPIA/game"
cp "$RAIZ/tools/checar_head_cena.gd" "$PROJ/_checar_head.gd"
cat > "$PROJ/_checar_head.tscn" <<'CENA'
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://_checar_head.gd" id="1"]

[node name="ChecarHead" type="Node"]
script = ExtResource("1")
CENA
# user:// proprio, dentro da secao [application].
sed -i 's/^\[application\]$/[application]\n\nconfig\/use_custom_user_dir=true\nconfig\/custom_user_dir_name="nevoa_checar_head"/' "$PROJ/project.godot"

PROJ_W=$(cygpath -m "$PROJ")
echo "checar_head: $ROTULO"
echo "  importando (sem cache: a copia nao tem .godot/)..."
timeout 900 "$GODOT" --headless --path "$PROJ_W" --import > "$COPIA/import.log" 2>&1
echo "  importacao terminou com codigo $?"

echo "  compilando..."
timeout 300 "$GODOT" --headless --path "$PROJ_W" res://_checar_head.tscn > "$COPIA/checar.log" 2>&1
CODIGO=$?

RESUMO=$(grep '^\[checar_head\] scripts=' "$COPIA/checar.log")
# O que o motor reclama por conta propria, alem da contagem da cena — e quem.
# Cada erro sai em duas linhas: a mensagem, e um `at: ... (res://arquivo:linha)`
# logo abaixo. `Failed to load` diz o arquivo na propria mensagem.
ERROS=$(awk '
  /SCRIPT ERROR|^ERROR:/ { msg = $0; sub(/^(SCRIPT )?ERROR: /, "", msg); pend = 1; next }
  pend && /^ *at: / {
    onde = $0
    if (match(msg, /"res:\/\/[^"]*"/)) onde = substr(msg, RSTART + 1, RLENGTH - 2)
    else if (match(onde, /res:\/\/[^)]*/)) onde = substr(onde, RSTART, RLENGTH)
    else onde = "(motor)"
    print onde "  " msg
    pend = 0
  }
' "$COPIA/checar.log" | sort | uniq -c | sort -k2)

grep '^\[checar_head\] falha' "$COPIA/checar.log" | sed 's/^/  /'
if [ -n "$ERROS" ]; then
  echo "  mensagens do motor (contagem, mensagem):"
  echo "$ERROS" | head -40 | sed 's/^/    /'
fi

if [ -z "$RESUMO" ]; then
  echo "  a checagem NAO chegou ao fim (codigo $CODIGO); ultimas linhas:"
  tail -15 "$COPIA/checar.log" | sed 's/^/    /'
  exit 2
fi
echo "  ${RESUMO#\[checar_head\] }"
if [ "$CODIGO" != 0 ] || [ -n "$ERROS" ]; then
  echo "A1 FALHA: $ROTULO nao compila sozinho"
  exit 1
fi

# Compilar nao prova que roda: um `load("res://...")` por texto, ou um recurso
# que so a cena principal pede, passa pela etapa acima. A cena principal roda
# $QUADROS quadros sem janela, JA NA CIDADE (sem menu e sem abertura: so o menu
# nao exercita nada), e todo erro de script conta.
#
# Fica de fora so o "resources still in use at exit": e o motor reclamando na
# saida forcada do `--quit-after`, e aparece numa execucao e nao na seguinte da
# mesma arvore.
#
# `--shot-frame` alto porque, sem captura, o CaptureTool encerra a amostragem no
# quadro de captura (30 por padrao) e o `--stats` nunca imprimiria.
QUADROS=${CHECAR_HEAD_QUADROS:-1200}
echo "  rodando a cidade por $QUADROS quadros..."
timeout 300 "$GODOT" --headless --path "$PROJ_W" --quit-after "$QUADROS" \
  -- --pular-menu --pular-abertura --stats=60 --shot-frame=1000000 > "$COPIA/rodar.log" 2>&1
RODOU=$?
FILTRADO=$(grep -A1 -E 'SCRIPT ERROR|^ERROR:' "$COPIA/rodar.log" | grep -v '^--$' \
  | grep -v -A1 'resources still in use at exit' | grep -v 'core/io/resource.cpp')
EXEC=$(echo "$FILTRADO" | grep -cE 'SCRIPT ERROR|^ERROR:')
# Prova de que a cidade carregou: o ultimo relatorio do CaptureTool tem chunks.
CHUNKS=$(grep -oE '^\[stats\] .*chunks=[0-9]+' "$COPIA/rodar.log" | tail -1 | grep -oE 'chunks=[0-9]+' | cut -d= -f2)
CHUNKS=${CHUNKS:-0}
if [ "$RODOU" != 0 ] || [ "$EXEC" != 0 ] || [ "$CHUNKS" = 0 ]; then
  echo "  a cidade terminou com codigo $RODOU, $EXEC erros e $CHUNKS chunks carregados:"
  echo "$FILTRADO" | sort | uniq -c | sort -rn | head -20 | sed 's/^/    /'
  echo "A1 FALHA: $ROTULO compila, mas a cidade nao roda limpa"
  exit 1
fi
echo "  cidade: $CHUNKS chunks carregados, 0 erros"
echo "A1 OK: $ROTULO compila sozinho e a cidade roda $QUADROS quadros sem erro"
exit 0
