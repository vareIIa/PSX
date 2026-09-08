from pathlib import Path
p = Path(r"C:\Users\Administrator\Documents\Codes\Games\PSX\game\src\world\malha_urbana.gd")
text = p.read_text(encoding="utf-8")
marker = "static func largura_calcada(v: Via) -> float:"
insert = """## Faixa de estacionamento / acostamento entre a pista de rolamento e o
## meio-fio. A blitz e os carros encostados vivem aqui — sem isto a viatura
## caia na calcada (MARGEM_ACOST alem da borda do asfalto).
static func largura_estacionamento(v: Via) -> float:
	match v:
		Via.AVENIDA:
			return 2.2
		Via.RUA:
			return 1.8
		_:
			return 0.0


## Meia largura do asfalto total (rolamento + estacionamento).
static func meia_asfalto(v: Via) -> float:
	return meia_pista(v) + largura_estacionamento(v)


"""
if "largura_estacionamento" not in text:
    if marker not in text:
        raise SystemExit("marker missing")
    text = text.replace(marker, insert + marker, 1)
    print("inserted estacionamento")
else:
    print("already has estacionamento")

old_av = """static func largura_calcada(v: Via) -> float:
	match v:
		Via.AVENIDA:
			return 3.0
		Via.RUA:
			return 2.5"""
new_av = """static func largura_calcada(v: Via) -> float:
	match v:
		Via.AVENIDA:
			# Era 3,0. Estacionamento de 2,2 m comeu 0,5 m; sobram 2,5 m de
			# calcada — ainda cabe arvore (DA_GUIA) e passagem.
			return 2.5
		Via.RUA:
			return 2.2"""
if old_av not in text:
    i = text.find("largura_calcada")
    raise SystemExit("calcada block missing: " + repr(text[i:i+200]))
text = text.replace(old_av, new_av, 1)
print("calcada updated")

old_r = "return meia_pista(v) + largura_calcada(v)"
new_r = "return meia_asfalto(v) + largura_calcada(v)"
if old_r not in text:
    raise SystemExit("recuo missing")
text = text.replace(old_r, new_r, 1)
print("recuo updated")
p.write_text(text, encoding="utf-8")
print("DONE malha")
