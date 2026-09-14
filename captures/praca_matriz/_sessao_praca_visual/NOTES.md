# Sessao Praça Matriz - Visual

## Mudancas
1) Personagem no chao (`abertura.gd` `_deitar`):
   - `figura.position.y = KitParque.Y_CALCAMENTO + DEITADO_ALTURA` (0.22+0.18)
   - torso look acompanha: `onde.y + Y_CALCAMENTO + DEITADO_ALTURA + 0.12`

2) Igreja longe + coreto oeste + casinhas (`parque_builder.gd` `_praca_matriz`):
   - igreja offset `+0.8` -> `-5.0` (~15 m do pin 270/-40)
   - coreto `(-7,+4)` -> `(-8.5,+2)` (mais oeste, sem overlap)
   - casas: 3->4 por lado, mais perto da borda (2.8)
   - lanternas da porta / proibido alinhados ao novo offset
   - energia postes 7.2->9.0 (porta 6.5->8.0)

3) Noite escura (`fog_noite_nublada`):
   - `_plano_da_praca` forca `fog_noite_nublada.tres`
   - `cidade._rodar_abertura` forca o mesmo em `--ver-praca` / `--ir-para=270*`
   - NAO tocou `carro.gd` fog

## Provas
- captures/praca_matriz/_sessao_praca_visual/after_02b.png
- after_01b.png, after_p5b.png, after_eixo2.png
- cine/ espelho atualizado

## Mid_lum (pixel cru, centro)
- ref01 ~48, ref02 ~63
- after_02b / after cine ~40s (era ~136 com fog_denso)
- after_eixo2 deve seguir noite se ir-para=270

## Aberto
- Igreja ainda le como fachada baixa no denso curto; torre/telhado fracos vs ref 02
- Casas laterais ainda sumidas em alguns takes
- POV 01 quase preto demais vs ref 01 (acordar deveria mostrar pernas/igreja no FG)
# Update T1/fog

## T1 corpo
- y_local/world = 0.68 (calcamento 0.22) — mesh ACIMA da pedra
- `_deitar`: Y_CALCAMENTO + DEITADO_ALTURA + 0.28
- cams praca_1..4 baixadas pra ler corpo no calcamento
- before chroma body_band 24.6 -> after 37.1; body_lum 53.5 -> 71.5

## Fog ir-para
- `_forcar_fog_praca_se_pin()` em cidade.gd (ir-para=270* / --ver-praca)
- after_eixo_noite mid_lum 52.7 (era ~138 com denso)

## Provas
- before_t1_02.png / after_t1_02b.png
- after_eixo_noite.png
