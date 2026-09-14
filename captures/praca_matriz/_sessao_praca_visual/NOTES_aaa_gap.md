## AAA-gap close (2026-09-09)

Pedido New Bot: sineira LER mais alta no eixo noite + casas laterais no eixo/praca_5. Sem portal/punch/rim.

### Causa
Casas de aproximacao em centro.y+12/+16 = SUL do pin 270,-40 → atras da camera do ir-para.

### Fix
- parque_builder: casas flanqueando eixo (z entre pin e igreja, x ±8–10)
- kit_parque: torre_h 17.5→20, parede_h 4.6→4.15, vao sino alto, cornija gorda, casa h 3.55→4.05

### Metricas (mid / towTop / span / Lw / Rw)
| shot | mid | top | span | Lw | Rw |
| aaa_eixo (antes) | 53.1 | 51.3 | 0.32 | 0.00 | 0.01 |
| polish_eixo | 67.3 | 53.7 | 0.31 | 0.09 | 0.18 |
| aaa_p5 | 57.2 | 46.2 | 0.25 | 0.04 | 0.14 |
| polish_p5 | 68.9 | 48.3 | 0.26 | 0.08 | 0.01 |

Provas: polish_eixo.png, polish_p5.png (before = aaa_eixo / aaa_p5)
