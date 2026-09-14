# -*- coding: utf-8 -*-
"""Pin 270,-40 + pose joelhos + luz quente. Backup before write."""
from pathlib import Path

ab = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
co = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\render\corpo.gd")
t = ab.read_text(encoding="utf-8")
Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\captures\praca_matriz\cine\_backup_abertura_pre_pin270.gd").write_text(t, encoding="utf-8")

# --- pin absoluto Cleiton 270,-40 olhar norte ---
old_pin = """\t# Pin Cleiton (cluster Matriz ~272,-48). Sul-oeste do coreto: igreja a direita
\t# no quadro, coreto no meio, postes no anel (ref 01).
\tconst PIN_MATRIZ := Vector3(272.0, 0.0, -48.0)
\tvar matriz := _praca_mais_perto(PIN_MATRIZ)
\tif matriz == Vector3.INF:
\t\tmatriz = PIN_MATRIZ
\t# ~12 m ao sul, 4 m a oeste do miolo.
\torigem = Vector3(matriz.x - 2.5, origem.y, matriz.z + 10.0)
\t_jogador.global_position = origem + Vector3.UP * 0.5
\tvar para_m := Vector3(matriz.x - origem.x, 0.0, (matriz.z - 6.0) - origem.z)
\tif para_m.length_squared() > 0.01:
\t\t_jogador.rotation.y = atan2(-para_m.x, -para_m.z)
\telse:
\t\t_jogador.rotation.y = 0.0"""

new_pin = """\t# Pin Cleiton/Jota: 270,-40 olhando norte. Lampiao SW (~265,-40) a esquerda;
\t# coreto 272,-48 + igreja ao norte no reach.
\tconst PIN_ACORDAR := Vector3(270.0, 0.0, -40.0)
\torigem = Vector3(PIN_ACORDAR.x, origem.y, PIN_ACORDAR.z)
\t_jogador.global_position = origem + Vector3.UP * 0.5
\t# Frente = norte (-Z): lampiao fica a esquerda no FP.
\t_jogador.rotation.y = 0.0"""

if old_pin not in t:
    raise SystemExit("pin block missing — check file")
t = t.replace(old_pin, new_pin, 1)

# --- after deitar use DEITADO_ACORDAR ---
old_d = """\t\t# LIVRE (nao ENCOSTADO): pernas esticadas. ENCOSTADO encolhia e o FP
\t\t# lia as coxas como cubos marrons no meio do quadro.
\t\tfigura.postura(Corpo.Postura.LIVRE)
\t\t_montar_maos(figura)
\t\t_deitar(figura, true)
\t\t_jogador.mostrar_corpo(true)"""
new_d = """\t\t_montar_maos(figura)
\t\t_deitar(figura, true)
\t\t# Joelhos levemente dobrados: FP le calca+bota, nao caixa reta.
\t\tfigura.postura(Corpo.Postura.DEITADO_ACORDAR)
\t\t_jogador.mostrar_corpo(true)"""
if old_d not in t:
    raise SystemExit("deitar block missing")
t = t.replace(old_d, new_d, 1)

# --- camera: look north toward church, center boots ---
old_cam = """\t\tvar p_cabeca := _ponto_osso(figura, Corpo.Osso.CABECA)
\t\tvar p_pe_e := _ponto_osso(figura, Corpo.Osso.CANELA_E)
\t\tvar p_pe_d := _ponto_osso(figura, Corpo.Osso.CANELA_D)
\t\tvar p_pes := (p_pe_e + p_pe_d) * 0.5
\t\t# Mais atras da cabeca + leve lado: pernas em perspectiva no terco baixo
\t\t# (ref 01), nao um bloco colado na lente.
\t\tvar lado := frente_praca.cross(Vector3.UP).normalized()
\t\tcam_de = p_cabeca - frente_praca * 0.42 + lado * 0.18 + Vector3.UP * 0.16
\t\t# Mira ALEM dos pes, pro calcamento — bota no centro-baixo, praca atras.
\t\tolhar_de = p_pes + frente_praca * 1.4 + Vector3.UP * 0.06"""

new_cam = """\t\tvar p_cabeca := _ponto_osso(figura, Corpo.Osso.CABECA)
\t\tvar p_pe_e := _ponto_osso(figura, Corpo.Osso.CANELA_E)
\t\tvar p_pe_d := _ponto_osso(figura, Corpo.Osso.CANELA_D)
\t\tvar p_pes := (p_pe_e + p_pe_d) * 0.5
\t\t# Atras da cabeca, pernas no centro-baixo (ref 01).
\t\tcam_de = p_cabeca - frente_praca * 0.50 + Vector3.UP * 0.20
\t\t# Mira as botas; praca (coreto/igreja) logo alem.
\t\tolhar_de = p_pes + frente_praca * 0.70 + Vector3.UP * 0.05"""
if old_cam not in t:
    raise SystemExit("cam block missing")
t = t.replace(old_cam, new_cam, 1)

# Force look toward church north for frente_praca when on pin
old_fp = """\tvar praca := _praca_mais_perto(onde)
\tif praca == Vector3.INF:
\t\tpraca = Vector3(272.0, 0.0, -48.0)
\tvar frente_praca := Vector3(praca.x - onde.x, 0.0, (praca.z - 5.0) - onde.z)
\tif frente_praca.length_squared() < 0.01:
\t\tfrente_praca = -eixo if eixo.length_squared() > 0.01 else Vector3(0.0, 0.0, -1.0)
\tfrente_praca = frente_praca.normalized()"""
new_fp = """\t# Look-at Cleiton: igreja ~272,-66 (norte). Fallback coreto 272,-48.
\tvar alvo_look := Vector3(272.0, 0.0, -66.0)
\tvar frente_praca := Vector3(alvo_look.x - onde.x, 0.0, alvo_look.z - onde.z)
\tif frente_praca.length_squared() < 0.01:
\t\tfrente_praca = Vector3(0.0, 0.0, -1.0)
\tfrente_praca = frente_praca.normalized()"""
if old_fp not in t:
    raise SystemExit("frente_praca block missing")
t = t.replace(old_fp, new_fp, 1)

# Warm apoio after Cinema.mover
needle = """\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\tif _hud != null:"""
warm = """\tCinema.mover(
\t\tcam_de, cam_ate,
\t\tolhar_de, olhar_ate,
\t\tACORDA_DURACAO, ACORDA_FOV.x, ACORDA_FOV.y)

\t# Lampiao quente a ESQUERDA (ref 01 / pin SW ~265,-40).
\tif _apoio != null and is_instance_valid(_apoio):
\t\t_apoio.global_position = Vector3(265.0, onde.y + 3.4, -40.0)
\t\t_apoio.light_color = Color(\"ffb45a\")
\t\t_apoio.light_energy = 6.0
\t\t_apoio.omni_range = 10.0

\tif _hud != null:"""
warm = warm.replace('\\"', '"')
if needle not in t:
    raise SystemExit("mover+hud needle missing")
t = t.replace(needle, warm, 1)

ab.write_text(t, encoding="utf-8")
print("abertura OK")

# --- Corpo: Postura.DEITADO_ACORDAR ---
c = co.read_text(encoding="utf-8")
Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\captures\praca_matriz\cine\_backup_corpo_pre_pin270.gd").write_text(c, encoding="utf-8")

if "DEITADO_ACORDAR" not in c:
    c = c.replace(
        "enum Postura { LIVRE, SENTADO, CONTROLE, FUMANDO, ENCOSTADO, LEVANTANDO }",
        "enum Postura { LIVRE, SENTADO, CONTROLE, FUMANDO, ENCOSTADO, LEVANTANDO, DEITADO_ACORDAR }",
        1,
    )
    old_m = """\t\tPostura.ENCOSTADO:
\t\t\t_pose_encostado(f)
\t\t_:"""
    new_m = """\t\tPostura.ENCOSTADO:
\t\t\t_pose_encostado(f)
\t\tPostura.DEITADO_ACORDAR:
\t\t\t_pose_deitado_acordar()
\t\t_:"""
    if old_m not in c:
        raise SystemExit("postura match missing")
    c = c.replace(old_m, new_m, 1)

    # Insert pose function before _pose_andando
    pose_fn = '''
## Deitado acordando: joelhos semi-dobrados pra FP mostrar calca e bota.
## O Node3D ja esta deitado (_deitar); aqui so articula o esqueleto.
func _pose_deitado_acordar() -> void:
\t_girar(Osso.COXA_E, -0.55, 0.0, 0.08)
\t_girar(Osso.CANELA_E, 0.95)
\t_girar(Osso.COXA_D, -0.48, 0.0, -0.08)
\t_girar(Osso.CANELA_D, 0.88)
\t_girar(Osso.TORSO, 0.12)
\t_girar(Osso.BRACO_E, 0.25, 0.0, 0.35)
\t_girar(Osso.ANTEBRACO_E, 0.40)
\t_girar(Osso.BRACO_D, 0.25, 0.0, -0.35)
\t_girar(Osso.ANTEBRACO_D, 0.40)


'''
    marker = "func _pose_andando(f: float) -> void:"
    if marker not in c:
        raise SystemExit("pose_andando missing")
    c = c.replace(marker, pose_fn + marker, 1)
    co.write_text(c, encoding="utf-8")
    print("corpo OK DEITADO_ACORDAR")
else:
    print("corpo already has DEITADO_ACORDAR")

print("done pin270")
