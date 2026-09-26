"""Espelha o braco riggado (direito) em X e exporta o esquerdo.

blender -b <final.blend> --python b_espelhar.py -- <saida_esq.glb>

Escala -1 em X no objeto do esqueleto e da pele, aplicada: os ossos e a malha
viram os do braco esquerdo (o Blender vira a ordem das faces na malha para a
normal continuar para fora). Os nomes dos ossos e dos grupos nao mudam. Sai sem imagem: o material de jogo
(`BracoDoPadre`) usa as texturas do direito nos dois.
"""
import sys
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
saida = argv[0]
arm = bpy.data.objects["braco_padre"]
pele = bpy.data.objects["braco_padre_pele"]
bpy.ops.object.select_all(action="DESELECT")
for o in (arm, pele):
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
# a pele e filha do esqueleto: espelha o esqueleto e aplica nos dois
arm.scale = (-1.0, 1.0, 1.0)
bpy.context.view_layer.update()
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True, properties=False)
bpy.context.view_layer.update()
me = pele.data
print("[espelhar] escala", tuple(arm.scale), tuple(pele.scale))
bpy.ops.export_scene.gltf(
    filepath=saida, export_format="GLB", use_selection=True, export_yup=True,
    export_apply=False, export_skins=True, export_animations=False,
    export_all_influences=False, export_def_bones=False, export_texcoords=True,
    export_normals=True, export_tangents=True, export_materials="EXPORT",
    export_image_format="NONE")
print("[espelhar] ok", saida)
