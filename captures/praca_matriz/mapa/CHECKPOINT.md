# Checkpoint Praça da Matriz — fachada punch fog=denso (2026-09-08)

## Pin (unchanged)
270,-40 look-at 271,-51 | PowerShell arg array:
  @('--ir-para=270,-40,271,-51','--fog=denso','--pular-abertura','--shot=...','--shot-frame=200','--shot-quit')

## Layout (coreto OFF axis — not moved back)
| peça | offset vs centro | notes |
|------|------------------|-------|
| coreto | (-7.0, +4.0) | west of axis |
| igreja | (0, -1.5) | nudged south; portal +1.4 m toward pin → ~6 m |
| door lamps | (±3.4, -1.5+5.8) | flank façade, ignore proibido |

## Fachada punch (kit_parque.igreja_matriz)
- Hollow ombreira (jambs+lintel+sill) + pure black door void
- janela_acesa hollow rim (same kit trick as poste_lanterna globe)
- Bright cross + dark back contour; bolder quoins with dark face
- Door-flank lanternas (parque_builder) energia 8.5

## Flor
- `_canteiros` early-return on Traco.PRACA (already)
- `_vegetacao` density *0.35 on PRACA; no moita on cobble

## Captures (denso, pin 270,-40)
- captures/praca_matriz/mapa/01_eixo_igreja.png
- captures/praca_matriz/mapa/05_denso_acordar.png
- captures/praca_matriz/mapa/11_fachada_punch.png

## Vs Cine2 (cine/02_deitado_igreja.png)
Cine2: featureless grey silhouette + red flor blobs on grass.
Mapa v8: black door + cream ombreira frame read; faint cross/quoins; cobble clear of flor.

## Scope
Only kit_parque.gd + parque_builder.gd. abertura.gd NOT touched. Pin stays 270,-40.

## Cruz punch (2026-09-08 19:44 UYT)
- kit_parque.igreja_matriz: cruz no plano do portal, acima do lintel, massa ombreira + dupla janela_acesa + backplate escuro
- Capture: captures/praca_matriz/mapa/13_cruz_punch.png (fog=denso, pin 270,-40 look-at 271,-51)
- Args: @('--ir-para=270,-40,271,-51','--fog=denso','--pular-abertura','--shot=captures/praca_matriz/mapa/13_cruz_punch.png','--shot-frame=200','--shot-quit')
- Godot: .tools\Godot_v4.7.2-stable_win64_console.exe
- Vs previous: cross now reads (bright + dark contour) where cine2/11 washed; door/ombreira/stairs unchanged
