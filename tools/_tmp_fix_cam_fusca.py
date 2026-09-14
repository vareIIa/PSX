from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\carros_teste.gd")
t = p.read_text(encoding="utf-8")
old = '''func _posicionar_camera(vista: String, perto: float) -> void:
\tmatch vista:
\t\t"tras":
\t\t\t_cam.position = Vector3(0.0, 2.6, -11.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t"cima":
\t\t\t_cam.position = Vector3(0.0, 12.0, 0.01) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t"lado":
\t\t\t_cam.position = Vector3(11.0, 1.6, 0.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)'''
new = '''func _posicionar_camera(vista: String, perto: float) -> void:
\t# Perto aproxima em XZ; altura nao esmaga (senao --so=N deixa a camera
\t# na altura do para-choque e o perfil vira um "traseira" achatado).
\tvar d := clampf(perto, 0.35, 1.0)
\tvar hy := maxf(1.0, 1.0 / sqrt(d))
\tmatch vista:
\t\t"tras":
\t\t\t_cam.position = Vector3(0.0, 2.6 * hy, -11.0 * d)
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t"cima":
\t\t\t_cam.position = Vector3(0.0, 12.0 * d, 0.01)
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t"lado":
\t\t\t_cam.position = Vector3(11.0 * d, 1.7 * hy, 0.0)
\t\t\t_cam.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)'''
if old not in t:
    raise SystemExit("camera block not found")
t = t.replace(old, new, 1)
# Also fix frente_rua / default / dentro heights similarly for orbit
old2 = '''\t\t"frente_rua":
\t\t\t# Olha a FRETE real do carro (que aponta -Z).
\t\t\t_cam.position = Vector3(5.5, 2.4, -10.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)
\t\t_:
\t\t\t_cam.position = Vector3(7.0, 5.2, 17.0) * perto if perto >= 1.0 else Vector3(6.5, 2.6, 11.0) * perto
\t\t\t_cam.look_at(Vector3(0.0, 0.7, 0.0), Vector3.UP)'''
new2 = '''\t\t"frente_rua":
\t\t\t# Olha a FRETE real do carro (que aponta -Z).
\t\t\t_cam.position = Vector3(5.5 * d, 2.4 * hy, -10.0 * d)
\t\t\t_cam.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)
\t\t_:
\t\t\tif perto >= 1.0:
\t\t\t\t_cam.position = Vector3(7.0, 5.2, 17.0)
\t\t\telse:
\t\t\t\t_cam.position = Vector3(6.5 * d, 2.8 * hy, 11.0 * d)
\t\t\t_cam.look_at(Vector3(0.0, 0.75, 0.0), Vector3.UP)'''
if old2 not in t:
    raise SystemExit("frente_rua block not found")
t = t.replace(old2, new2, 1)
p.write_text(t, encoding="utf-8")
print("camera ok")
