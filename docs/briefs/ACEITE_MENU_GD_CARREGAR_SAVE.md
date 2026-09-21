# ACEITE_MENU_GD_CARREGAR_SAVE — 2026-09-19

**Ticket:** menu.gd título CARREGAR legado → SaveCardsPanelRe7  
**PO2:** New Bot (loop AAA RE7)  
**Máquina:** KernelOS-PC · game/src/ui/menu.gd (mtime ~18:34 UYT)  
**Modo:** código-only · NO_GODOT · playtest HOLD · grid cutover OFF

## Verdict
**PASS**

## DoD (estático)
- [x] _save_panel: SaveCardsPanelRe7 + _audio_save_pushed
- [x] _montar_carregar instancia SaveCardsPanelRe7 @ (130,31); sem _montar_lista(_no_carregar
- [x] pediu_carregar / pediu_voltar conectados
- [x] AudioDirector.on_menu_push(&\"save\") / pop em esconder e saída de CARREGAR
- [x] mostrar(CARREGAR) → refresh_from_savegame + foco_padrao deferred
- [x] _lista_tem_foco só TITULO (painel dono do foco em CARREGAR)
- [x] input defere a SaveCards quando painel visível

## Próximo
P1 NESTED_MENUSISTEMA_PUSH — MenuSistema.abrir empilhar via UIManager.push_menu (FILO). Código-only.
