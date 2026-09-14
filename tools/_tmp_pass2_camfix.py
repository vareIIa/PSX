# -*- coding: utf-8 -*-
from pathlib import Path
import re
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\carros_teste.gd")
t = p.read_text(encoding="utf-8")
# Fix tras: car front is -Z, so rear camera must be +Z
t2 = t.replace(
    '_cam.position = Vector3(0.0, 2.6 * hy, -11.0 * d)',
    '_cam.position = Vector3(0.0, 2.6 * hy, 11.0 * d)',
    1,
)
# Closer side for silhouette gate
t2 = t2.replace(
    '_cam.position = Vector3(11.0 * d, 1.7 * hy, 0.0)',
    '_cam.position = Vector3(8.5 * d, 1.55 * hy, 0.0)',
    1,
)
# Closer frente
t2 = t2.replace(
    '_cam.position = Vector3(5.5 * d, 2.4 * hy, -10.0 * d)',
    '_cam.position = Vector3(4.2 * d, 2.1 * hy, -8.0 * d)',
    1,
)
if t2 == t:
    print('WARN: no camera replacements?')
p.write_text(t2, encoding='utf-8')
print('camera fixes ok')
print([l for l in t2.splitlines() if '11.0 * d' in l or '8.5 * d' in l or '8.0 * d' in l or '4.2' in l])
