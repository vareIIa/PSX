# INVENTARIO MENUS — PSX (19/09/2026)

Ver PLAYBOOK_MENUS_AAA.md §13 para o resumo canônico.

## P0 imediato (qualquer bot de implementação)
Ligar em `cidade.gd`:
- `prancha.pediu_titulo` → fluxo voltar ao Menu/título
- `prancha.pediu_carregar(espaco)` → SaveGame.carregar + fechar prancha

## Hooks
- OpcoesLista.video()/audio()
- MenuSistema.abrir() / abrir_em(Pagina) / fechar() / tratar()
- PranchaInventario.menu_sistema() / abrir/fechar
- PAUZINHOS Rect2(448, 19, 18, 14) — expandir hit ≥32×32 (A11y §11)

## Não duplicar
Lista de opções: só OpcoesLista. Tokens: só UiEstilo.
