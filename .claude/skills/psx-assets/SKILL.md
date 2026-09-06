---
name: psx-assets
description: Pipeline de assets dentro do budget PSX — texturas de 128 px em paleta de 256 cores, presets de importação do Godot, budgets de polígono e animação a 15 fps com step discreto. Use ao criar, converter ou importar textura, modelo, sprite, fonte ou animação, e ao configurar import do Godot.
---

# Pipeline de Assets

Budgets canônicos em `docs/ART-BIBLE.md`, seções 6 e 10. Esta skill é o processo.

## Texturas

### Especificação

| Item | Valor |
|---|---|
| Tamanho | 128x128 para superfície, 256x256 só para atlas |
| Paleta | 256 cores indexadas, dither Floyd-Steinberg |
| Formato | PNG sem perda |
| Filtro | Nearest, no material |
| Mipmap | Desligado |
| Tiling | Toda textura de superfície tem que fechar nas bordas |

### Conversão

Use o utilitário do projeto em vez de fazer na mão:

```bash
python tools/psxify.py entrada.jpg -o game/assets/textures/parede_concreto.png
python tools/psxify.py pasta_fotos/ -o game/assets/textures/ --size 128 --colors 256
```

Ele reduz, quantiza com dither e grava PNG. Rode sempre antes de importar, nunca
importe um JPEG de 2000 px e deixe o Godot reescalar: o resultado fica suave demais e
perde o pixel duro.

### Preset de importação

Crie o `.import` com estes campos, ou configure uma vez no editor e copie:

```ini
compress/mode=0
mipmaps/generate=false
detect_3d/compress_to=0
process/fix_alpha_border=false
```

O `detect_3d/compress_to=0` importa: sem ele o Godot detecta uso em 3D e recomprime
para VRAM automaticamente, o que destrói a paleta.

### Economia de textura

Uma cidade precisa de muito material e pouco arquivo. A regra é: **textura em escala
de cinza mais tint por vértice ou por uniform**. Uma parede de concreto vira dez
paredes diferentes mudando só o `tint`. Isso é o que torna o kit modular viável sem
um artista dedicado.

## Modelos

### Budgets

| Item | Triângulos |
|---|---|
| Chunk de 32 m inteiro | 6.000 |
| Personagem principal | 900 |
| Inimigo | 700 |
| Prop de cenário | 150 |
| Visível em névoa densa | 25.000 |

### Regra de subdivisão

Por causa da UV afim, **chão e parede vão subdivididos em quads de no máximo 2 m**.
Um quad de 8 m distorce a textura a ponto de ficar ilegível. Isso consome budget de
polígono de propósito e está previsto nos números acima.

### Autoria sem Blender

O kit v1 é feito com `CSGBox3D` dentro do Godot e convertido para `ArrayMesh` pelo
menu de conversão. As referências de corredor do moodboard são literalmente caixas
texturizadas, então isso é o alvo estético, não uma limitação. Blender só entra quando
for preciso rigar personagem.

### Rig

Máximo de 24 ossos. Sem IK, sem blend shape, sem física de cabelo ou roupa.

## Animação

Taxa de 15 fps com interpolação discreta. É o que dá o movimento travado do PS1.

```gdscript
for i in anim.get_track_count():
    anim.track_set_interpolation_type(i, Animation.INTERPOLATION_NEAREST)
anim.step = 1.0 / 15.0
```

Sem interpolação de transição entre animações no `AnimationTree`: `xfade_time = 0`.
Corte seco entre estados.

## Áudio

| Item | Valor |
|---|---|
| SFX | 22.050 Hz, mono, 16 bits |
| Música | 44.1 kHz, estéreo |
| Formato | WAV para SFX curto, OGG para música e ambiente |

Conversão de SFX:

```bash
ffmpeg -i entrada.wav -ar 22050 -ac 1 -sample_fmt s16 saida.wav
```

Buses: `Master` com `SFX`, `Music` e `Radio` como filhos. O bus `Radio` leva um
passa-banda de 300 Hz a 3 kHz mais ruído branco cujo volume é modulado pela distância
até o inimigo mais próximo.

## Fontes

Bitmap ou TTF renderizada com `antialiasing = NONE` e hinting desligado. Tamanho em
múltiplo do pixel interno. Texto suave numa tela de 480x270 destrói a ilusão mais
rápido que qualquer outra coisa.

## Direitos autorais

Nada de nome, marca, logo, música ou personagem de obra existente, inclusive em
placeholder. O artigo de referência do projeto cita o Puppet Combo tendo que renomear
o primeiro jogo por isso. Placeholder tem o hábito de sobreviver até o release.
