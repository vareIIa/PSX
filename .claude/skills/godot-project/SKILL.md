---
name: godot-project
description: Convenções e comandos do projeto Godot deste repositório — onde fica o binário portable, como rodar headless, como validar cena e shader sem abrir editor, layout de src e padrões de GDScript. Use ao rodar, testar ou depurar o jogo, ao criar script ou cena, e ao configurar project.godot ou export.
---

# Projeto Godot

## Binário

Godot 4.7.2 stable portable, dentro do repositório:

```
.tools/Godot_v4.7.2-stable_win64.exe            editor e runtime
.tools/Godot_v4.7.2-stable_win64_console.exe    mesma coisa, com stdout no terminal
```

Use sempre a variante `_console` em linha de comando, senão a saída não aparece.
Alias sugerido nas sessões de shell:

```bash
GODOT=".tools/Godot_v4.7.2-stable_win64_console.exe"
```

O projeto fica em `game/`, então quase todo comando leva `--path game`.

## Comandos

```bash
# importar assets e sair — roda depois de adicionar arquivo novo
"$GODOT" --headless --path game --import

# validar que tudo carrega, sem abrir janela
"$GODOT" --headless --path game --quit

# rodar o jogo
"$GODOT" --path game

# rodar uma cena específica
"$GODOT" --path game res://scenes/test/sala_teste.tscn

# abrir o editor
"$GODOT" -e --path game
```

`--headless --quit` é a validação padrão depois de qualquer mudança em cena, script ou
shader. Erro de sintaxe de GDScript e de shader aparece no stdout. Rode sempre antes de
dizer que algo está pronto.

Shader **não** é compilado no modo headless em todos os casos. Para validar shader de
verdade é preciso abrir a cena com janela pelo menos uma vez.

## Layout

```
game/
├─ project.godot
├─ shaders/          psx_surface.gdshader, post_psx.gdshader
├─ src/
│  ├─ player/        player.gd, camera_rig.gd
│  ├─ world/         chunk_manager.gd, world_state.gd, fog_controller.gd
│  ├─ systems/       inventory.gd, save_game.gd, radio.gd
│  └─ ui/            pause_menu.gd, inventory_board.gd
├─ assets/           textures/ models/ audio/ fonts/
├─ scenes/           world/chunks/ world/kit/ interiors/ test/
└─ resources/        fog_presets/ items/
```

Script mora em `src/`, cena mora em `scenes/`. Não misture `.gd` dentro de `scenes/`.

## Configuração obrigatória do project.godot

```ini
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=true
textures/default_filters/anisotropic_filtering_level=0
anti_aliasing/quality/msaa_3d=0
anti_aliasing/quality/screen_space_aa=0

[display]
window/size/viewport_width=480
window/size/viewport_height=270
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="viewport"
window/stretch/aspect="keep"
```

`stretch/mode="viewport"` mais `aspect="keep"` já entrega o upscale nearest com
pillarbox correto, o que é mais simples que montar SubViewport na mão. Use SubViewport
só se precisar de resolução interna diferente da do pós-processo.

## Autoloads

| Nome | Script | Papel |
|---|---|---|
| `Settings` | `src/systems/settings.gd` | Lê e grava `user://settings.cfg`, emite sinal ao mudar |
| `WorldState` | `src/world/world_state.gd` | Estado persistente de chunk descarregado |
| `ChunkManager` | `src/world/chunk_manager.gd` | Carga e descarga por distância |
| `AudioDirector` | `src/systems/audio_director.gd` | Buses, rádio, ambiente |

## Padrões de GDScript

- `class_name` em todo script que vira tipo. Tipagem estática sempre: `var hp: int = 3`.
- Sinal no passado: `item_picked_up`, `fog_preset_changed`.
- `@onready` só para nó filho direto. Referência a nó distante vem por autoload ou por
  `@export var alvo: Node3D`, nunca `get_node("../../..")`.
- Constante de tuning no topo do arquivo em `const`, nunca número solto no meio da
  lógica. Valor que vem do ART-BIBLE leva comentário citando a seção.

## Antes de dizer que está pronto

1. `--headless --path game --quit` sem erro no stdout.
2. Se mexeu em shader, abriu a cena com janela pelo menos uma vez.
3. Se mexeu em visual, comparou com a print correspondente em `PRINTS/`.
