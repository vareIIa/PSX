from pathlib import Path
pb = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\parque_builder.gd")
t = pb.read_text(encoding="utf-8")
needle = "\tif _neste_chunk(igreja):\r\n\t\tKitParque.igreja_matriz(sup, colisao,\r\n\t\t\tVector3(igreja.x, y, igreja.y), 0.0)\r\n"
insert_after = needle + "\tprint(\"[praca_matriz] centro_q=\", centro_q, \" coreto=\", coreto_p, \" igreja=\", igreja)\r\n"
if needle not in t:
    needle = needle.replace("\r\n", "\n")
    insert_after = insert_after.replace("\r\n", "\n")
if needle not in t:
    raise SystemExit("needle missing")
if "[praca_matriz]" in t:
    print("print already present")
else:
    pb.write_bytes(t.replace(needle, insert_after, 1).encode("utf-8"))
    print("added position print")
