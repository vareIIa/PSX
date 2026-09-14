from pathlib import Path
cid = Path(r"C:\Users\\Administrator\\Documents\\Codes\\Games\\PSX\\game\\src\\levels\\cidade.gd")
ct = cid.read_text(encoding="utf-8")
needle = "func _rodar_abertura() -> void:\n\tif OS.get_cmdline_user_args().has(\"--pular-abertura\"):\n"
insert = """func _rodar_abertura() -> void:\n\tvar args := OS.get_cmdline_user_args()\n\tvar pin_praca := false\n\tfor a in args:\n\t\tif a.begins_with(\"--ir-para=270\"):\n\t\t\tpin_praca = true\n\t\t\tbreak\n\tif args.has(\"--ver-praca\") or pin_praca:\n\t\tvar fog := get_node_or_null(\"Ambiente\") as FogController\n\t\tif fog != null:\n\t\t\tfog.forcar(\"res://resources/fog/fog_noite_nublada.tres\")\n\tif args.has(\"--pular-abertura\"):\n"""
if "pin_praca" in ct:
    print("cidade already patched")
elif needle not in ct:
    print("MISS needle")
    # show nearby
    i = ct.find("func _rodar_abertura")
    print(repr(ct[i:i+120]))
else:
    ct = ct.replace(needle, insert, 1)
    cid.write_text(ct, encoding="utf-8")
    print("cidade fog OK")
