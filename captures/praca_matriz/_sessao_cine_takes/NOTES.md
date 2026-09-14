# Sessao Cine Takes — DEITADO afastar

Branch: feat/estrada-velha
Arquivo: game/src/levels/abertura.gd (_plano_da_praca Part B)
Hard stop: coreto / abertura_estrada.gd / fog carro.gd
Prova: Godot --ver-praca (janela)

## Distancia camera→torso (m, offset 3D)

| take | before | after | FOV |
|------|--------|-------|-----|
| praca_1 (c1) | 5.56 | 12.66 | 58→62 |
| praca_2 (c2) | 5.10 | 11.86 | 54→60 |
| praca_3 (c3) | 3.93 | 9.00 | 52→58 |
| praca_4 (c4) | 2.95 | 5.48 | 54→58 |
| praca_5 (c5) | 8.49 | 14.38 | 60→64 |

Nota: c3 primeiro after a 8.5m puro leste deu frame preto (streaming); corrigido para SE obliquo ~9m.

## Frame
Before: close no corpo/fachada.
After: establishing praça + igreja + postes + casas; corpo silhueta/lower FG.
Meta: PRINTS/ref_praca_matriz 04_vista + 02_igreja.

Caps after_* = captures/praca_matriz/cine atuais pos --ver-praca.
