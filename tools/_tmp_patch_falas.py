from pathlib import Path
p = Path(r"game\src\levels\abertura_estrada.gd")
text = p.read_text(encoding="utf-8")

old_falas = '''const FALAS := {
	"passagem": "A gente marcou essa viagem faz uns dois meses.",
	"aerea_1": "Sao Thome das Letras. Todo mundo dizia que eu tinha que conhecer.",
	"aerea_2": "Duas horas de terra depois que acaba o asfalto.",
	"rasante": "Eu que nao queria vir.",
	"dentro_1": "E dificil explicar. Nao e medo, e outra coisa.",
	"dentro_2": "Faz uma semana que eu acordo pensando em desmarcar.",
	"dentro_3": "Cheguei a escrever a desculpa no celular. Nao mandei.",
	"dentro_4": "Mas a pousada ja tava paga e o pessoal ja tava vindo.",
	"saida": "Ai eu peguei o carro e vim.",
}'''

new_falas = '''const FALAS := {
	"passagem": "A gente marcou essa viagem faz uns dois meses.",
	"aerea_1": "Sao Thome das Letras. Todo mundo dizia que eu tinha que conhecer.",
	"aerea_2": "Duas horas de terra depois que acaba o asfalto.",
	"rasante": "Eu que nao queria vir.",
	"dentro_1": "Sem maldade, essa estrada nao parece ter fim.",
	"dentro_2": "Faz uma semana que eu acordo pensando em desmarcar.",
	"dentro_3": "Cheguei a escrever a desculpa no celular. Nao mandei.",
	"dentro_4": "Mas a pousada ja tava paga e o pessoal ja tava vindo.",
	"saida": "Ai eu peguei o carro e vim.",
}'''

if old_falas not in text:
    raise SystemExit("FALAS block not found")
text = text.replace(old_falas, new_falas, 1)

reps = [
    ('Cinema.legenda(FALAS["passagem"], 4.6)', 'Cinema.legenda(FALAS["passagem"], 4.2)'),
    ('Cinema.legenda(FALAS["aerea_1"], 4.8)', 'Cinema.legenda(FALAS["aerea_1"], 4.6)'),
    ('Cinema.legenda(FALAS["aerea_2"], 4.4)', 'Cinema.legenda(FALAS["aerea_2"], 4.0)'),
    ('Cinema.legenda(FALAS["rasante"], 4.0)', 'Cinema.legenda(FALAS["rasante"], 3.2)'),
    ('Cinema.legenda(FALAS["saida"], 4.2)', 'Cinema.legenda(FALAS["saida"], 3.6)'),
]
for a, b in reps:
    if a not in text:
        raise SystemExit(f"missing: {a}")
    text = text.replace(a, b, 1)

old_dentro = '''	var falas := ["dentro_1", "dentro_2", "dentro_3", "dentro_4"]
	for i in falas.size():
		Cinema.legenda(FALAS[falas[i]], 4.4)
		await _esperar(5.4)
	await _esperar(maxf(0.0, DENTRO_DURACAO - 5.4 * float(falas.size())))'''

new_dentro = '''	var falas := ["dentro_1", "dentro_2", "dentro_3", "dentro_4"]
	var durs := [4.0, 4.2, 4.2, 4.4]
	for i in falas.size():
		Cinema.legenda(FALAS[falas[i]], durs[i])
		await _esperar(5.4)
	await _esperar(maxf(0.0, DENTRO_DURACAO - 5.4 * float(falas.size())))'''

if old_dentro not in text:
    raise SystemExit("dentro loop not found")
text = text.replace(old_dentro, new_dentro, 1)

# Keep header comment in sync for dentro_1 meaning
p.write_text(text, encoding="utf-8")
print("OK patched")
