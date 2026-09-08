from pathlib import Path
DIR = Path("game/resources/fog")

def w(name, body):
    DIR.joinpath(name).write_text(body.strip() + "\n", encoding="utf-8", newline="\n")
    print("wrote", name)

w("fog_estrada_noite.tres", """
[gd_resource type="Resource" script_class="FogPreset" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/world/fog_preset.gd" id="1_fogpreset"]

[resource]
script = ExtResource("1_fogpreset")
id = &"estrada_noite"
display_name = "Estrada Noite"
fog_enabled = true
fog_begin = 8.0
fog_end = 38.0
fog_color = Color(0.07, 0.075, 0.09, 1)
sky_color = Color(0.07, 0.075, 0.09, 1)
stream_radius = 64.0
saturation = 0.85
grade_tint = Color(0.92, 0.94, 1.0, 1)
ambient_energy = 0.22
ambient_color = Color(0.07, 0.075, 0.09, 1)
facho_forca = 0.85
hora_do_dia = 1
tem_chuva = false
tem_estrelas = false
tem_lua = false
nuvens = 0.9
sol_energia = 0.04
sol_cor = Color(0.55, 0.6, 0.72, 1)
sol_rotacao = Vector2(-12, -40)
""")

w("fog_estrada_amanhecer.tres", """
[gd_resource type="Resource" script_class="FogPreset" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/world/fog_preset.gd" id="1_fogpreset"]

[resource]
script = ExtResource("1_fogpreset")
id = &"estrada_amanhecer"
display_name = "Estrada Amanhecer"
fog_enabled = true
fog_begin = 10.0
fog_end = 48.0
fog_color = Color(0.62, 0.58, 0.55, 1)
sky_color = Color(0.62, 0.58, 0.55, 1)
stream_radius = 80.0
saturation = 0.92
grade_tint = Color(1.0, 0.96, 0.9, 1)
ambient_energy = 0.95
ambient_color = Color(0.62, 0.58, 0.55, 1)
facho_forca = 0.35
hora_do_dia = 0
tem_chuva = false
tem_estrelas = false
tem_lua = false
nuvens = 0.75
sol_energia = 0.85
sol_cor = Color(1.0, 0.72, 0.48, 1)
sol_rotacao = Vector2(-6, 160)
""")

w("fog_estrada_dia.tres", """
[gd_resource type="Resource" script_class="FogPreset" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/world/fog_preset.gd" id="1_fogpreset"]

[resource]
script = ExtResource("1_fogpreset")
id = &"estrada_dia"
display_name = "Estrada Dia"
fog_enabled = true
fog_begin = 40.0
fog_end = 110.0
fog_color = Color(0.62, 0.72, 0.78, 1)
sky_color = Color(0.62, 0.72, 0.78, 1)
stream_radius = 128.0
saturation = 1.02
grade_tint = Color(1.0, 0.98, 0.94, 1)
ambient_energy = 1.35
ambient_color = Color(0.62, 0.72, 0.78, 1)
facho_forca = 0.15
hora_do_dia = 0
tem_chuva = false
tem_estrelas = false
tem_lua = false
nuvens = 0.2
sol_energia = 2.0
sol_cor = Color(1.0, 0.94, 0.78, 1)
sol_rotacao = Vector2(-48, 20)
""")
