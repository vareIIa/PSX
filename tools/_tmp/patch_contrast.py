from pathlib import Path
kp = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\kit_parque.gd")
t = kp.read_text(encoding="utf-8")
nl = "\r\n" if "\r\n" in t else "\n"
# brighter ombreira, bigger door already somewhat; boost quoin size on facade
old_q = "\t\t\t\tVector3(0.55, alt_q, 0.38), cor_q, giro,"
new_q = "\t\t\t\tVector3(0.75, alt_q, 0.48), cor_q, giro,"
if old_q not in t:
    raise SystemExit("quoin size missing")
t = t.replace(old_q, new_q, 1)
# door ombreira brighter
t2 = t.replace('var ombreira := Color("f0e4c8")', 'var ombreira := Color("fff6dc")', 1)
if t2 == t:
    print("ombreira already bright or missing")
else:
    t = t2
    print("ombreira brighter")
# taller tower for silhouette above coreto
old_th = "\tvar torre_h := 8.2"
new_th = "\tvar torre_h := 9.6"
if old_th in t:
    t = t.replace(old_th, new_th, 1)
    print("tower taller")
kp.write_bytes(t.encode("utf-8"))

# remove debug print from builder
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
bt = pb.read_text(encoding="utf-8")
lines = bt.splitlines(True)
out = [ln for ln in lines if "[praca_matriz]" not in ln]
pb.write_bytes("".join(out).encode("utf-8"))
print("debug print removed")
