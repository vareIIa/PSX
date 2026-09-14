from pathlib import Path
# Compare capture vs ref file sizes; also dump first bytes uniqueness
import hashlib
base = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX")
for name in ["01_lado.png","02_traseira.png","03_frente.png","04_cima.png","05_dentro.png"]:
    p = base / "captures/carros/fusca" / name
    h = hashlib.md5(p.read_bytes()).hexdigest()[:8]
    print(name, p.stat().st_size, h)
