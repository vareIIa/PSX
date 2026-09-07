#!/usr/bin/env python3
"""Gera definicoes de item e dispara o bake volumetrico dos icones.

Os PNG da roleta nao sao mais desenhos flat: vem de ItemModelo (malhas
low-poly) renderizado em estudio por scenes/tools/bake_icones.tscn — o mesmo
mesh que gira na vitrine da prancha.

Uso:
    python tools/gerar_itens.py          # .tres + bake Godot (D3D12/Vulkan)
    python tools/gerar_itens.py --so-tres
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ICONES = RAIZ / "game" / "assets" / "icones"
ITENS = RAIZ / "game" / "resources" / "itens"
GAME = RAIZ / "game"
GODOT = RAIZ / ".tools" / "Godot_v4.7.2-stable_win64_console.exe"

MODELO = '''[gd_resource type="Resource" script_class="Item" load_steps=3 format=3]

[ext_resource type="Script" path="res://src/systems/item.gd" id="1_item"]
[ext_resource type="Texture2D" path="res://assets/icones/{id}.png" id="2_icone"]

[resource]
script = ExtResource("1_item")
id = &"{id}"
nome = "{nome}"
descricao = "{descricao}"
tipo = {tipo}
icone = ExtResource("2_icone")
empilhavel = {empilhavel}
max_pilha = {max_pilha}
consumivel = {consumivel}
cura = {cura}
municao_de = &"{municao_de}"
'''

CURA, MUNICAO, ARMA, FERRAMENTA, CHAVE, DOCUMENTO = range(6)

ITEM_DEFS = [
    ("bandagem", "Bandagem", "Para o sangue. Nao resolve o que causou.",
     CURA, True, 5, True, 35, ""),
    ("remedio", "Remedio", "Amargo. Meu pai tomava um desses todo dia.",
     CURA, True, 3, True, 70, ""),
    ("pistola", "Pistola", "Arma pesada. Espero nao precisar.",
     ARMA, False, 1, False, 0, ""),
    ("municao_9mm", "Municao 9mm", "Conte antes de sair. Depois nao da tempo.",
     MUNICAO, True, 30, False, 0, "pistola"),
    ("lanterna", "Lanterna", "A luz acaba antes da noite.",
     FERRAMENTA, False, 1, False, 0, ""),
    ("bateria", "Bateria", "Ainda tem carga. Acho.",
     FERRAMENTA, True, 6, True, 0, ""),
    ("radio", "Radio", "So pega chiado. O chiado tambem diz alguma coisa.",
     FERRAMENTA, False, 1, False, 0, ""),
    ("chave_apartamento", "Chave", "Numero apagado. Abre alguma porta.",
     CHAVE, False, 1, False, 0, ""),
    ("pe_de_cabra", "Pe de cabra", "Serve para abrir. Serve para outras coisas.",
     FERRAMENTA, False, 1, False, 0, ""),
    ("bilhete", "Bilhete", "A letra treme no fim. Ela escreveu com pressa.",
     DOCUMENTO, False, 1, False, 0, ""),
    ("identidade", "Identidade",
     "Sou eu. O nome, o numero, a data. Enquanto eu tiver isto, alguem pode provar que eu existi.",
     DOCUMENTO, False, 1, False, 0, ""),
]


def escrever_tres() -> None:
    ITENS.mkdir(parents=True, exist_ok=True)
    ICONES.mkdir(parents=True, exist_ok=True)
    for (iid, nome, desc, tipo, emp, pilha, cons, cura, mun) in ITEM_DEFS:
        (ITENS / f"{iid}.tres").write_text(MODELO.format(
            id=iid, nome=nome, descricao=desc.replace('"', "'"), tipo=tipo,
            empilhavel=str(emp).lower(), max_pilha=pilha,
            consumivel=str(cons).lower(), cura=cura, municao_de=mun,
        ), encoding="utf-8")
        print(f"{iid:20s} {nome}")


def bake_godot() -> int:
    if not GODOT.is_file():
        print(f"Godot ausente em {GODOT}", file=sys.stderr)
        return 1
    # --headless usa renderer dummy e nao gera textura. Bake precisa de GPU.
    drivers = ["d3d12", "vulkan", "opengl3"]
    last = 1
    for drv in drivers:
        cmd = [
            str(GODOT), "--path", str(GAME),
            "--rendering-driver", drv,
            "res://scenes/tools/bake_icones.tscn",
        ]
        print("bake:", " ".join(cmd))
        last = subprocess.call(cmd)
        if last == 0:
            return 0
        print(f"driver {drv} falhou ({last}), tentando outro...")
    return last


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--so-tres", action="store_true", help="So grava .tres, sem bake")
    args = ap.parse_args()
    escrever_tres()
    print(f"\n{len(ITEM_DEFS)} recursos .tres")
    if args.so_tres:
        return 0
    return bake_godot()


if __name__ == "__main__":
    raise SystemExit(main())
