from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
t = p.read_text(encoding="utf-8")

# Widen search a bit
t2 = t.replace("const PRACA_RAIO := 6", "const PRACA_RAIO := 14", 1)
if t2 == t:
    raise SystemExit("PRACA_RAIO not found")
t = t2

old_fn = '''## O centro do parque mais proximo, ou Vector3.INF.
##
## Le a malha urbana, que e estatica e nao precisa de nada carregado. E a mesma
## leitura que o GPS faz para achar um parque a trezentos metros de onde o
## jogador esta.
static func _praca_mais_perto(de: Vector3) -> Vector3:
\tvar aqui := Vector2i(floori(de.x / Mapa.TAM), floori(de.z / Mapa.TAM))
\tvar melhor := Vector3.INF
\tvar melhor_d := INF
\tfor cz in range(aqui.y - PRACA_RAIO, aqui.y + PRACA_RAIO + 1):
\t\tfor cx in range(aqui.x - PRACA_RAIO, aqui.x + PRACA_RAIO + 1):
\t\t\tvar q := MalhaUrbana.quadra_de(cx, cz)
\t\t\tif int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
\t\t\t\tcontinue
\t\t\tvar c: Vector3 = MalhaUrbana.centro_da_quadra(q)
\t\t\tvar d := Vector2(c.x - de.x, c.z - de.z).length()
\t\t\tif d < melhor_d:
\t\t\t\tmelhor_d = d
\t\t\t\tmelhor = c
\treturn melhor'''

new_fn = '''## Centro da Praca da Matriz (Traco.PRACA) mais perto, ou Vector3.INF.
##
## Nao vale qualquer parque: parquinho/bosque/lago nao tem igreja+coreto. A
## abertura do acordar so enquadra a ref 01 se o miolo for Matriz.
static func _praca_mais_perto(de: Vector3) -> Vector3:
\tvar aqui := Vector2i(floori(de.x / Mapa.TAM), floori(de.z / Mapa.TAM))
\tvar melhor := Vector3.INF
\tvar melhor_d := INF
\tfor cz in range(aqui.y - PRACA_RAIO, aqui.y + PRACA_RAIO + 1):
\t\tfor cx in range(aqui.x - PRACA_RAIO, aqui.x + PRACA_RAIO + 1):
\t\t\tvar q := MalhaUrbana.quadra_de(cx, cz)
\t\t\tif int(q["uso"]) != MalhaUrbana.Uso.PARQUE:
\t\t\t\tcontinue
\t\t\tvar plano := ParqueBuilder.planta(q)
\t\t\tif int(plano["traco"]) != ParqueBuilder.Traco.PRACA:
\t\t\t\tcontinue
\t\t\tvar local: Vector2 = plano["centro"]
\t\t\tvar c := Vector3(
\t\t\t\tfloat(q["x0"]) * Mapa.TAM + local.x,
\t\t\t\t0.0,
\t\t\t\tfloat(q["z0"]) * Mapa.TAM + local.y)
\t\t\tvar d := Vector2(c.x - de.x, c.z - de.z).length()
\t\t\tif d < melhor_d:
\t\t\t\tmelhor_d = d
\t\t\t\tmelhor = c
\treturn melhor'''

if old_fn not in t:
    raise SystemExit("praca_mais_perto block not found")
t = t.replace(old_fn, new_fn, 1)

# Teleport to south of Matriz before settling on floor
old_o = '''\tvar origem := _nasceu_em
\tfor _k in ESPERA_CHAO:
\t\tawait get_tree().physics_frame
\t\tif _tem_chao(origem):
\t\t\tbreak'''

new_o = '''\tvar origem := _nasceu_em
\t# Acordar NA Matriz: ~8 m ao sul do coreto, olhando norte (igreja). Sem isto
\t# o ponto_inicial cai num parquinho e a ref 01 vira balanco/trepa-trepa.
\tvar matriz := _praca_mais_perto(origem)
\tif matriz != Vector3.INF:
\t\torigem = Vector3(matriz.x, origem.y, matriz.z + 8.0)
\t\t_jogador.global_position = origem + Vector3.UP * 0.5
\t\t_jogador.rotation.y = 0.0
\t\t_jogador.zerar_velocidade()
\t\t_nasceu_em = origem
\tfor _k in ESPERA_CHAO:
\t\tawait get_tree().physics_frame
\t\tif _tem_chao(origem):
\t\t\tbreak'''

if old_o not in t:
    raise SystemExit("origem block not found")
t = t.replace(old_o, new_o, 1)

p.write_text(t, encoding="utf-8")
print("OK matriz spawn")
