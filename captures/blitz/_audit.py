from pathlib import Path
root = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX")
checks = {
  "malha estacionamento": "largura_estacionamento" in (root/"game/src/world/malha_urbana.gd").read_text(encoding="utf-8"),
  "blitz FSM": "enum Fase" in (root/"game/src/world/blitz.gd").read_text(encoding="utf-8"),
  "kit zebrado": "zebrado_acostamento" in (root/"game/src/world/kit_blitz.gd").read_text(encoding="utf-8"),
  "chunk pintura": "_pintura_estacionamento" in (root/"game/src/world/chunk_builder.gd").read_text(encoding="utf-8"),
  "carro ocultar": "func _ocultar_motorista_visual" in (root/"game/src/world/carro.gd").read_text(encoding="utf-8"),
  "cidade olhar": "func _olhar_blitz" in (root/"game/src/levels/cidade.gd").read_text(encoding="utf-8"),
  "avenida only": "via != MalhaUrbana.Via.AVENIDA" in (root/"game/src/world/blitz_manager.gd").read_text(encoding="utf-8"),
  "player pitch": "definir_pitch(atan2" in (root/"game/src/player/player.gd").read_text(encoding="utf-8"),
}
for k,v in checks.items():
    print(f"{'OK' if v else 'MISSING':7} {k}")
# show olhar_blitz briefly
t=(root/"game/src/levels/cidade.gd").read_text(encoding="utf-8")
i=t.find("func _olhar_blitz")
print("--- olhar ---")
print(t[i:i+700] if i>=0 else "none")
print("--- manager candidato ---")
m=(root/"game/src/world/blitz_manager.gd").read_text(encoding="utf-8")
j=m.find("func _candidato_valido")
print(m[j:j+900])
