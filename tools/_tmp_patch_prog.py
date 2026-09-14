from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\PROGRESSO.md")
t = p.read_text(encoding="utf-8")
old = """## Estado critico AGORA (ler primeiro)

1. **Merge `feat/blitz-aaa` → `feat/estrada-velha` EM ANDAMENTO** (Jamerson pediu merge).
   - Conflito aberto: `game/src/levels/cidade.gd` (marcadores `<<<<<<<`).
   - Stash salvo: `stash@{0}` = `wip-pre-merge-blitz-aaa` (carroceria/carro/parque etc.).
   - Backup captures blitz untracked: `C:\\Users\\Administrator\\Documents\\Codes\\Games\\_bak_blitz_captures`
   - Captures blitz ja staged da branch: `captures/blitz/A*.png` … `E_estacionado.png`
   - **Proximos passos:** resolver `cidade.gd` (unir flags `--ver-estrada*` + `--blitz-demo*` e manter docs Estrada + helper `_rodar_estrada`), `git add`, `git commit` do merge, `git stash pop`.
2. Gate **afrouxado:** PASS com notas; FAIL so bug critico (crash, debug no frame, chao invisivel).
3. **Hermes (Fusca) + Renato (Marea) PAUSADOS** por Jamerson.
"""
# try without special arrow
import re
t2, n = re.subn(
    r"## Estado critico AGORA \(ler primeiro\).*?(?=\n## Fluxo novo jogo)",
    """## Estado critico AGORA (ler primeiro)

1. **Merge `feat/blitz-aaa` -> `feat/estrada-velha` FEITO:** commit `c244c04`.
   - `cidade.gd` resolvido (flags estrada+blitz + `_rodar_estrada`).
   - Stash `wip-pre-merge-blitz-aaa` ainda existe (pop bloqueado por WIP em `kit_parque.gd` / `parque_builder.gd`).
   - Backup antigo: `C:\\\\Users\\\\Administrator\\\\Documents\\\\Codes\\\\Games\\\\_bak_blitz_captures`
2. Gate **afrouxado:** PASS com notas; FAIL so bug critico.
3. **Hermes (Fusca) + Renato (Marea) PAUSADOS**.

""",
    t,
    count=1,
    flags=re.S,
)
print("patched", n)
p.write_text(t2, encoding="utf-8")