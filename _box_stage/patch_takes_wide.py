from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\levels\abertura.gd")
text = p.read_text(encoding="utf-8")
start = text.find("\t# --- Part B: takes externos, corpo AINDA DEITADO -----------------------")
end = text.find("\t# Proximos planos escondem/re-posam o corpo; desfaz o deitar SEM animacao", start)
if start < 0 or end < 0:
    raise SystemExit(f"markers missing start={start} end={end}")
new = '''\t# --- Part B: takes externos, corpo AINDA DEITADO -----------------------
\t#
\t# Meta visual: PRINTS/ref_praca_matriz — 04_vista + eixo da igreja.
\t# Corpo DEITADO = silhueta no terco inferior; quem carrega o quadro e a
\t# praca inteira e a cidade no fundo. Nao e close no torso.
\t#
\t# Historico: cams a 2–5 m liam o boneco PS1 como caixas e comiam a praca.
\t# Aqui o recuo fica na casa dos 7–12 m (altura 3–6,5), lente 58–64, olhar
\t# ALEM do corpo pro eixo/fachadas — cidade e nevoa entram no quadro.
\t# Nao e plano de coreto (hard stop); coreto so aparece se estiver no eixo
\t# largo da vista, nunca como assunto.
\tawait Cinema.corte(0.14)
\t_jogador.mostrar_corpo(true)
\tif figura != null:
\t\t_deitar(figura, true)
\t\tfigura.postura(Corpo.Postura.DEITADO_ACORDAR)

\tvar meio: Vector3 = pose["meio"]
\tvar torso := Vector3(meio.x, onde.y + KitParque.Y_CALCAMENTO + DEITADO_ALTURA + 0.12, meio.z)

\t# praca_1 — eixo sul elevado: corpo lower-third + igreja/cidade no fundo
\t# (idioma 02_igreja + escala 04_vista).
\tvar c1 := Vector3(torso.x - 1.2, onde.y + 5.2, torso.z + 11.5)
\tvar l1 := Vector3(torso.x + 0.2, onde.y + 2.1, torso.z - 12.0)
\tCinema.enquadrar(c1, l1, 62.0)
\tawait Cinema.clarear(0.35)
\tCinema.legenda(FALAS["praca_1"], 3.8)
\tawait get_tree().create_timer(0.55).timeout
\tawait _capturar_plano("02_deitado_igreja")
\tawait get_tree().create_timer(3.3).timeout

\t# praca_2 — SW elevado largo: calcamento + casas + nevoa; corpo pequeno FG.
\tawait Cinema.corte(0.1)
\tvar c2 := Vector3(torso.x - 8.0, onde.y + 4.4, torso.z + 7.5)
\tvar l2 := Vector3(torso.x + 1.2, onde.y + 1.7, torso.z - 5.0)
\tCinema.enquadrar(c2, l2, 60.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS["praca_2"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano("praca_2")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_3 — perfil leste afastado: le deitado sem close; praca/cidade a W.
\tawait Cinema.corte(0.1)
\tvar c3 := Vector3(torso.x + 8.5, onde.y + 3.6, torso.z + 4.0)
\tvar l3 := Vector3(torso.x - 1.5, onde.y + 1.4, torso.z - 3.5)
\tCinema.enquadrar(c3, l3, 58.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS["praca_3"], 3.4)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano("praca_3")
\tawait get_tree().create_timer(3.0).timeout

\t# praca_4 — rasante: silhueta FG, olhar LONGE pra praca acesa (nao anatomia).
\tawait Cinema.corte(0.1)
\tvar c4 := Vector3(torso.x + 2.2, onde.y + 0.42, torso.z + 5.0)
\tvar l4 := Vector3(torso.x - 0.4, onde.y + 2.2, torso.z - 14.0)
\tCinema.enquadrar(c4, l4, 58.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS["praca_4"], 3.2)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano("praca_4")
\tawait get_tree().create_timer(2.8).timeout

\t# praca_5 — establishing tipo 04_vista: altura + recuo, corpo tiny, praca cheia.
\tawait Cinema.corte(0.1)
\tvar c5 := Vector3(torso.x - 3.2, onde.y + 6.5, torso.z + 12.5)
\tvar l5 := Vector3(torso.x + 0.4, onde.y + 1.9, torso.z - 11.0)
\tCinema.enquadrar(c5, l5, 64.0)
\tawait Cinema.clarear(0.28)
\tCinema.legenda(FALAS["praca_5"], 3.6)
\tawait get_tree().create_timer(0.5).timeout
\tawait _capturar_plano("praca_5")
\tawait get_tree().create_timer(3.2).timeout

'''
p.write_text(text[:start] + new + text[end:], encoding="utf-8")
print("PATCHED_OK", start, end)
# verify new cams present
t2 = p.read_text(encoding="utf-8")
for s in ["torso.z + 11.5", "torso.z + 12.5", "04_vista + eixo"]:
    print(s, s in t2)
