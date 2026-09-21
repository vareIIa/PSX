# ONDA1 RE7 — Árvore de nós (fundação overlay)

Status: Onda 1 entregue · Sem Git · Sem tocar Casa da Fumaça
Shader: `res://shaders/ui_menu_overlay.gdshader`
Autoload: `UIManager` → `res://src/ui/ui_manager.gd`
Camada: `UiEstilo.CAMADA_RE7_OVERLAY` = **108** (mundo < overlay < prancha 110)

## Árvore em runtime

```
/root
├── … (outros autoloads)
└── UIManager                                 # PROCESS_MODE_ALWAYS
    └── Re7OverlayLayer                       # CanvasLayer.layer = 108
        ├── Re7BackBuffer                     # BackBufferCopy (VIEWPORT)
        └── Re7OverlayRect                    # ColorRect + ShaderMaterial
                                              #   ui_menu_overlay.gdshader
                                              #   blur/sat/CA/grain/vignette/
                                              #   scrim/dirt/warp/intensity

Cidade (exemplo)
└── PranchaInventario                         # CanvasLayer.layer = 110 (legado)
    └── Prancha (_raiz)
        ├── … scrapbook UI …
        └── MenuSistema
```

## Fluxo Onda 1

1. ESC / `inventario` / `pausa` → `PranchaInventario.abrir()`
2. `get_tree().paused = true` (legado) + `UIManager.push_menu(_raiz)`
3. Overlay liga (feature flag `RE7_OVERLAY`): DoF blur, sat 0.6, CA bordas, lens dirt
4. Layer 108 borra o mundo; prancha (110) permanece nítida por cima
5. `fechar()` → `UIManager.remove_menu(_raiz)` → overlay off se pilha vazia

## API

| método | efeito |
|---|---|
| `push_menu(node, pausar:=false)` | empilha; overlay on; pausa opcional |
| `pop_menu()` | desempilha topo; overlay off se vazia |
| `remove_menu(node)` | remove específico (fecho legado) |
| `topo()` / `profundidade()` / `overlay_ativo()` | inspeção |
| `set_overlay_enabled(bool)` | força filtro ligado/desligado |

## Captura de aceite

`captures/ui/re7_dev/onda1_overlay.png` via `--ver-pausa` + `--shot=` absoluto.