"""Suaviza os pesos das juntas do braco e exporta o .glb do braco do padre.

blender -b <mao_riggada.blend> --python b_exportar.py -- <saida.glb> <saida.blend>
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
saida, blend = argv[0], argv[1]
mao = bpy.data.objects["mao_jogo"]
arm = bpy.data.objects["braco_padre"]
mao.name = "braco_padre_pele"
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = mao
mao.select_set(True)
bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
# as juntas longas do braco: a dobra do cotovelo e do pulso mais redonda
for g in ["braco", "antebraco", "antebraco_giro", "mao"]:
    mao.vertex_groups.active_index = mao.vertex_groups[g].index
    bpy.ops.object.vertex_group_smooth(group_select_mode="ACTIVE", factor=0.5, repeat=6, expand=0.0)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")
for pb in arm.pose.bones:
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.location = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=blend)
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
mao.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(
    filepath=saida, export_format="GLB", use_selection=True, export_yup=True,
    export_apply=False, export_skins=True, export_animations=False,
    export_all_influences=False, export_def_bones=False, export_texcoords=True,
    export_normals=True, export_tangents=True, export_materials="EXPORT",
    export_image_format="AUTO")
print("[exportar] ok", saida)
