# -*- coding: utf-8 -*-
from pathlib import Path

# Patch carro.gd traffic
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\carro.gd")
t = p.read_text(encoding="utf-8")
old = """static func _sortear_modelo(s: int) -> Carroceria.Modelo:
\t# O taxi e raro de proposito. Um em nove: frequente o bastante para o
\t# jogador reparar que existe, raro o bastante para ainda ser um evento.
\tvar h := absi(s * 2654435761) % 100
\tif h < 11:
\t\treturn Carroceria.Modelo.TAXI
\tif h < 32:
\t\treturn Carroceria.Modelo.HATCH
\tif h < 50:
\t\treturn Carroceria.Modelo.PERUA
\tif h < 66:
\t\treturn Carroceria.Modelo.PICAPE
\treturn Carroceria.Modelo.SEDA"""
new = """static func _sortear_modelo(s: int) -> Carroceria.Modelo:
\t# Cidade: quase so Marea + Fusca, taxi raro. Genericos (SEDA/HATCH/...)
\t# continuam no enum para blitz/vitrine, mas o transito urbano e dos dois.
\tvar h := absi(s * 2654435761) % 100
\tif h < 8:
\t\treturn Carroceria.Modelo.TAXI
\tif h < 48:
\t\treturn Carroceria.Modelo.FUSCA
\treturn Carroceria.Modelo.MAREA"""
assert old in t, "sortear not found"
t = t.replace(old, new, 1)
p.write_text(t, encoding="utf-8")
print("carro.gd ok")

# Patch carros_teste.gd
p2 = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\carros_teste.gd")
t2 = p2.read_text(encoding="utf-8")
old2 = """const MODELOS: Array[Carroceria.Modelo] = [
\tCarroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,
\tCarroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI,
]"""
new2 = """const MODELOS: Array[Carroceria.Modelo] = [
\tCarroceria.Modelo.SEDA, Carroceria.Modelo.HATCH, Carroceria.Modelo.PERUA,
\tCarroceria.Modelo.PICAPE, Carroceria.Modelo.TAXI,
\tCarroceria.Modelo.MAREA, Carroceria.Modelo.FUSCA,
]"""
assert old2 in t2
t2 = t2.replace(old2, new2, 1)

old_cam = """func _posicionar_camera(vista: String, perto: float) -> void:
\tmatch vista:
\t\t"tras":
\t\t\t_cam.position = Vector3(0.0, 2.6, -11.0) * perto
\t\t"cima":
\t\t\t_cam.position = Vector3(0.0, 12.0, 0.01) * perto
\t\t"lado":
\t\t\t_cam.position = Vector3(11.0, 1.6, 0.0) * perto
\t\t_:
\t\t\t_cam.position = Vector3(7.0, 5.2, 17.0) * perto if perto >= 1.0 else Vector3(6.5, 2.6, 11.0) * perto
\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)"""
new_cam = """func _posicionar_camera(vista: String, perto: float) -> void:
\tmatch vista:
\t\t"tras":
\t\t\t_cam.position = Vector3(0.0, 2.6, -11.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t"cima":
\t\t\t_cam.position = Vector3(0.0, 12.0, 0.01) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t"lado":
\t\t\t_cam.position = Vector3(11.0, 1.6, 0.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t"dentro":
\t\t\t# Dentro da cabine olhando para a frente (-Z apos meia volta).
\t\t\t# Serve para provar que o vidro existe dos dois lados.
\t\t\t_cam.position = Vector3(0.32, 1.12, 0.55)
\t\t\t_cam.look_at(Vector3(0.0, 1.05, -2.8), Vector3.UP)
\t\t"frente_rua":
\t\t\t# Olha a FRETE real do carro (que aponta -Z).
\t\t\t_cam.position = Vector3(5.5, 2.4, -10.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t_:
\t\t\t_cam.position = Vector3(7.0, 5.2, 17.0) * perto if perto >= 1.0 else Vector3(6.5, 2.6, 11.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)"""
assert old_cam in t2, "camera not found"
t2 = t2.replace(old_cam, new_cam, 1)
p2.write_text(t2, encoding="utf-8")
print("carros_teste.gd ok")
