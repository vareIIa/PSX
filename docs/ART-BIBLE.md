# ART BIBLE — Contrato de Renderização PSX
> Se um valor não está aqui, ele não está decidido. Nada de "mais ou menos assim".
> Versão 1.0 — 06/09/2026

---

## 1. Pipeline em uma imagem

```
Geometria low-poly
  -> vertex shader:  snap de vértice + UV afim + luz por vértice
  -> fragment:       textura point, sem mipmap, dither Bayer 4x4, corte 15 bits
  -> SubViewport 480x270
  -> pós:            grão, aberração cromática, scanline, vinheta, grade de cor
  -> upscale nearest para a janela
  -> letterbox 2.35:1 opcional
```

## 2. Resolução e saída

| Parâmetro | Valor | Nota |
|---|---|---|
| Resolução interna | 480 x 270 | 16:9. Equivale a 320x240 do NTSC em contagem de pixels |
| Modo "puro" opcional | 320 x 240 | Com pillarbox 4:3 |
| Filtro de upscale | Nearest neighbor | `texture_filter = TEXTURE_FILTER_NEAREST` no SubViewportContainer |
| Snap de escala | Somente inteiros | Evita pixels de tamanho desigual |
| FPS alvo | 30 travado | 60 disponível em opções |

## 3. Vertex snapping

O GTE do PS1 trabalhava em ponto fixo sem precisão subpixel: os vértices caíam em
coordenadas inteiras de tela. É o efeito mais reconhecível do console, o "tremor" da
geometria quando a câmera se move.

```glsl
// no vertex(), depois de calcular a posição em clip space
vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
vec2 grid = vec2(480.0, 270.0) * 0.5;   // meia resolução = snap mais agressivo
clip.xyz /= clip.w;                      // para NDC
clip.xy = floor(clip.xy * grid) / grid;  // snap
clip.xyz *= clip.w;                      // de volta para clip
POSITION = clip;
```

Grade de snap por categoria, em fração da resolução interna:

| Categoria | Grade | Motivo |
|---|---|---|
| Cenário estático | 0.5x | Tremor forte, é onde o efeito lê melhor |
| Personagens | 0.5x | Igual ao cenário, senão eles "flutuam" |
| Armas em primeira pessoa | desligado | Snap em objeto colado na câmera vira ruído epilético |
| UI 3D e texto | desligado | — |

## 4. Mapeamento de textura afim

O PS1 não tinha correção de perspectiva: a textura "nada" e se dobra em polígonos
grandes vistos em ângulo. Chão e paredes são onde isso aparece.

Técnica: o hardware sempre divide as varyings por `w`. Pré-multiplicando a UV por `w`
no vértice e dividindo pela varying `w` interpolada no fragmento, a correção se
cancela e sobra interpolação linear em espaço de tela.

```glsl
varying vec2 uv_affine;
varying float w_affine;
// vertex
uv_affine = UV * clip.w;
w_affine  = clip.w;
// fragment
vec2 uv = uv_affine / w_affine;
```

**Consequência de design:** polígonos grandes distorcem muito. Chão e parede devem
ser subdivididos em quads de no máximo 2 m x 2 m. Isso não é otimização, é o que faz
o efeito ficar bonito em vez de ilegível.

## 5. Cor, dither e banding

O PS1 escrevia em framebuffer de 15 bits (5 bits por canal, 32768 cores) e aplicava
dither ordenado antes de truncar, produzindo o padrão de xadrez visível nos gradientes.
É o traço dominante da print do quarto âmbar.

```glsl
const float BAYER[16] = float[](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0);

int idx = int(mod(FRAGCOORD.y, 4.0)) * 4 + int(mod(FRAGCOORD.x, 4.0));
vec3 dithered = color + (BAYER[idx] / 16.0 - 0.5) / 32.0;
color = floor(dithered * 32.0) / 32.0;   // 5 bits por canal
```

O dither é aplicado **na resolução interna**, nunca depois do upscale. Aplicar depois
produz um padrão fino e limpo que parece filtro de Instagram, não PS1.

## 6. Texturas

| Parâmetro | Valor |
|---|---|
| Tamanho máximo | 128 x 128 para superfícies, 256 x 256 só para atlas |
| Paleta | 256 cores indexadas, quantização com dither Floyd-Steinberg |
| Filtro | Nearest, sem mipmap, sem anisotropia |
| Compressão | Lossless. VRAM não é o gargalo, nitidez do pixel é |
| Repetição | Enable. Todo tile precisa fechar |

Preset de importação no Godot, aplicado por pasta via `.godot/imported`:
`compress/mode=0`, `mipmaps/generate=false`, `detect_3d/compress_to=0`.
O filtro point é setado no material, não no import.

## 7. Iluminação

Iluminação **por vértice**, calculada no vertex shader e interpolada como cor. Nada
de per-pixel, normal map, sombra dinâmica, SSAO, GI ou reflexo. O renderizador do
projeto é o **Compatibility** do Godot, que já é gl_compatibility e força boa parte
dessas restrições naturalmente.

Fontes de luz permitidas por chunk: **no máximo 4 dinâmicas**. Todo o resto é luz
assada em cor de vértice ou em textura. As prints 3, 4 e 6 mostram exatamente isso:
uma única fonte quente e o resto caindo para preto.

## 8. Nevoeiro

Três presets, expostos nas configurações. Todos usam nevoeiro de profundidade linear
sobre a cor de fundo, nunca volumétrico com raymarch.

| Preset | Início | Fim | Cor | Horizonte de streaming |
|---|---|---|---|---|
| `DENSO` | 4 m | 18 m | `#c9cdc6` quase branco | 64 m |
| `LEVE` | 15 m | 60 m | `#8a9490` | 96 m |
| `DESLIGADO` | — | — | céu | 96 m com pop-in |

A cor do céu **sempre** iguala a cor final do nevoeiro, senão aparece uma linha de
horizonte que denuncia o truque.

O corte de desenho (`ChunkManager`) sai do fim do nevoeiro vezes `ALCANCE_EXTRA`,
e **por malha** soma-se a meia diagonal dela: `visibility_range_end` mede até o
centro da malha, e a de um chunk tem 22,6 m do centro à quina. Sem essa margem o
corte acontece 22 m antes do pedido e a rua acaba dentro do campo de visão. No preset noturno da print 1, o nevoeiro é
`#16241f`, verde-petróleo escuro.

## 9. Cadeia de pós-processamento

Ordem fixa. Cada item é um `ColorRect` com shader sobre o SubViewport, ou um único
shader com todos os passos, que é o que vamos fazer por custo.

| # | Efeito | Intensidade padrão | Ajustável |
|---|---|---|---|
| 1 | Grade de cor por LUT | por bioma | não |
| 2 | Aberração cromática | 0.6 px nas bordas | sim, 0 a 2 |
| 3 | Grão animado | 0.08 | sim, 0 a 0.2 |
| 4 | Scanlines | 0.12 de alpha, 1 linha sim 1 não | sim, on/off |
| 5 | Vinheta | raio 0.75, suavidade 0.45 | sim, on/off |
| 6 | Letterbox | 2.35:1 só em cutscene | automático |

A print 5 é a receita completa no máximo: vinheta forte, grão alto, contraste quase
zerado. A print 2 mostra a aberração cromática isolada, bem visível nas bordas.

## 10. Budgets

| Item | Teto |
|---|---|
| Triângulos por chunk de 32 m | 6.000 |
| Triângulos visíveis em `DENSO` | 25.000 |
| Personagem principal | 900 |
| Inimigo | 700 |
| Prop de cenário | 150 |
| Draw calls por frame | 120 |
| Ossos por rig | 24 |
| Taxa de animação | 15 fps, sem interpolação entre keys |

A animação a 15 fps com step discreto é o que dá o movimento "travado" característico.
No Godot: `Animation.track_set_interpolation_type(i, Animation.INTERPOLATION_NEAREST)`.

## 11. Áudio

| Parâmetro | Valor |
|---|---|
| Taxa de amostragem | 22.050 Hz mono para SFX |
| Profundidade | 16 bits, com opção de reduzir para 8 no bus |
| Música | 44.1 kHz estéreo, sem restrição de taxa |
| Reverb | Um único bus com reverb de sala, sem convolução |

Bus de áudio: `Master -> [SFX, Music, Radio]`. O bus `Radio` tem um passa-banda de
300 Hz a 3 kHz mais ruído branco modulado pela distância até o inimigo mais próximo.
É o rádio do Silent Hill e é o principal sistema de tensão do jogo.
