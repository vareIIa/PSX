# CHECKLIST AUDIO O4 SAVE — cards CARREGAR
> 19/09/2026 · NO_GODOT · Sem Git

## Código
| Arquivo | Mudança |
|---|---|
| `game/src/ui/re7/save_card.gd` | focus → `AudioDirector.tocar_nav(-18)`; accept filled → `tocar_confirm(-14)`; empty accept → nav baixo |
| `game/src/ui/re7/save_panel.gd` | VOLTAR → `tocar_nav(-18)` |
| `game/src/ui/menu_sistema.gd` | `abrir_em(CARREGAR)` → `on_menu_push(&"save")`; deny slot vazio → nav; sem double-confirm |

## Aceite (review disco / playtest pós-GO Godot)
1. [ ] Abrir SISTEMA → CARREGAR: duck/drone já do menu; cards focáveis
2. [ ] Focus card: nav (papel)
3. [ ] Accept slot filled: confirm (pegar) → carrega
4. [ ] Accept slot vazio: soft deny, sem load
5. [ ] VOLTAR: nav → RAIZ
6. [ ] `abrir_em(CARREGAR)` / CLI: kind `save` no push
