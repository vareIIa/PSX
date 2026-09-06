---
name: psx-render
description: Contrato de renderização PSX no Godot 4 Compatibility — vertex snapping, UV afim, dither de 15 bits, névoa Silent Hill e a cadeia de pós-processamento. Use ao escrever ou alterar qualquer .gdshader, ao mexer em material, viewport, resolução interna, névoa, grão, aberração cromática, scanline ou vinheta, e sempre que o assunto for "por que isso não está parecendo PS1".
---

# Renderização PSX

Os números canônicos estão em `docs/ART-BIBLE.md`. Esta skill é o **como**. Se um valor
aqui divergir do ART-BIBLE, o ART-BIBLE ganha.

## Onde cada efeito mora

A divisão importa. Colocar um efeito na etapa errada é o erro mais comum.

| Efeito | Etapa | Por quê |
|---|---|---|
| Vertex snap | vertex shader do material | Precisa da posição em clip space |
| UV afim | vertex + fragment do material | Precisa cancelar a divisão por w |
| Filtro point, sem mipmap | uniform do material | — |
| Luz por vértice | `render_mode vertex_lighting` | — |
| Névoa | `Environment` do World | Precisa vir depois da iluminação |
| Dither e corte de 15 bits | pós-processo | O PS1 ditherava na escrita do framebuffer |
| Grão, aberração, scanline, vinheta | pós-processo | — |

Dither no material **não funciona direito**, porque `fragment()` roda antes da luz ser
aplicada e o padrão sai multiplicado pela iluminação. No pós, ele incide sobre a cor
final, que é o comportamento correto.

## Estrutura de viewport

```
Main (Node)
└─ SubViewportContainer      stretch = true, texture_filter = NEAREST
   └─ SubViewport            size = 480x270, scaling_3d_mode = BILINEAR, scale = 1.0
      └─ World3D             câmera, cena, WorldEnvironment
└─ PostLayer (CanvasLayer)
   └─ ColorRect              full rect, material = post_psx.gdshader
```

O `ColorRect` do pós fica **fora** do SubViewport e lê `SCREEN_TEXTURE`. Se ficar
dentro, o dither é aplicado antes do upscale duas vezes e vira moiré.

## psx_surface.gdshader

```glsl
shader_type spatial;
render_mode vertex_lighting, specular_disabled, shadows_disabled, cull_back;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 snap_res = vec2(240.0, 135.0);  // metade de 480x270
uniform bool use_affine = true;
uniform bool use_snap = true;

varying vec2 uv_affine;
varying float w_affine;

void vertex() {
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

    if (use_snap) {
        vec3 ndc = clip.xyz / clip.w;
        ndc.xy = floor(ndc.xy * snap_res) / snap_res;
        clip.xyz = ndc * clip.w;
    }
    POSITION = clip;

    // Pré-multiplicar por w cancela a correção de perspectiva do rasterizador.
    w_affine  = clip.w;
    uv_affine = UV * clip.w;
}

void fragment() {
    vec2 uv = use_affine ? (uv_affine / w_affine) : UV;
    vec4 c = texture(albedo_tex, uv) * tint;
    ALBEDO = c.rgb;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
```

### Por que a divisão por w não se anula

O rasterizador interpola toda varying de forma perspectiva-correta, ou seja, entrega
`linear(V/w) / linear(1/w)`. Passando `V = UV*w`, o numerador vira `linear(UV)`. A
varying `w_affine` chega como `1/linear(1/w)`. Dividindo uma pela outra sobra
`linear(UV)`, que é interpolação linear em espaço de tela. Isso é exatamente o que o
PS1 fazia por não ter divisor.

### Consequência obrigatória de design

A UV afim distorce proporcionalmente ao tamanho do polígono. **Chão e parede precisam
ser subdivididos em quads de no máximo 2 m.** Um plano de 32 m sem subdivisão fica
ilegível, não retrô. Isso não é negociável e é a causa número um de "o shader está
bugado" quando na verdade a malha é que está errada.

### Quando desligar o snap

`use_snap = false` em arma de primeira pessoa, mão do personagem e qualquer coisa
grudada na câmera. Em objeto muito próximo o snap vira ruído estroboscópico
desconfortável, não charme retrô.

## post_psx.gdshader

Ordem dos passos é fixa: LUT, aberração, dither e corte, grão, scanline, vinheta.
Inverter a ordem muda o resultado, principalmente colocar o grão antes do corte de
bits, o que faz o grão sumir dentro da quantização.

```glsl
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float chromatic  : hint_range(0.0, 2.0) = 0.6;
uniform float grain      : hint_range(0.0, 0.2) = 0.08;
uniform float scanline   : hint_range(0.0, 0.5) = 0.12;
uniform float vignette   : hint_range(0.0, 1.0) = 0.45;
uniform float color_bits = 32.0;   // 32 níveis = 5 bits por canal
uniform vec2  internal_res = vec2(480.0, 270.0);

const float BAYER[16] = float[](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0);

float rand(vec2 c) {
    return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 center_off = uv - vec2(0.5);

    // 1. aberração cromática, crescendo para as bordas
    float amount = chromatic * length(center_off) / internal_res.x;
    vec3 col;
    col.r = texture(screen_tex, uv + center_off * amount).r;
    col.g = texture(screen_tex, uv).g;
    col.b = texture(screen_tex, uv - center_off * amount).b;

    // 2. dither ordenado + corte para 15 bits
    vec2 px = uv * internal_res;
    int idx = int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0));
    col += (BAYER[idx] / 16.0 - 0.5) / color_bits;
    col = floor(col * color_bits) / color_bits;

    // 3. grão animado
    col += (rand(px + fract(TIME)) - 0.5) * grain;

    // 4. scanline em linha alternada
    col *= 1.0 - scanline * step(1.0, mod(px.y, 2.0));

    // 5. vinheta
    col *= smoothstep(0.9, 0.9 - vignette, length(center_off) * 1.4);

    COLOR = vec4(col, 1.0);
}
```

O `filter_nearest` no `screen_tex` é obrigatório. Com filtro linear o dither é borrado
no upscale e todo o efeito se perde.

## Névoa

Feita no `WorldEnvironment`, não em shader, porque precisa incidir depois da luz.

```gdscript
env.fog_enabled = true
env.fog_mode = Environment.FOG_MODE_DEPTH
env.fog_depth_begin = 4.0
env.fog_depth_end = 18.0
env.fog_light_color = Color("c9cdc6")
env.background_mode = Environment.BG_COLOR
env.background_color = env.fog_light_color   # sempre iguais
```

**A cor do céu e a cor final da névoa têm que ser idênticas.** Qualquer diferença cria
uma linha de horizonte que denuncia o corte de draw distance na hora.

Os três presets estão no ART-BIBLE. `DESLIGADO` zera a névoa mas **mantém** o horizonte
de streaming em 96 m, produzindo pop-in de chunk. Isso é intencional e é a resposta ao
pedido de "névoa desativável" sem expor a cidade inteira.

## Armadilhas conhecidas do Compatibility

- `render_mode vertex_lighting` é obrigatório. Sem ele o Godot faz per-pixel e o look
  moderniza na hora, mesmo com todo o resto certo.
- Sombra dinâmica fica desligada em tudo. O PS1 não tinha. Use decal de sombra circular
  sob o personagem se precisar de ancoragem no chão.
- `scaling_3d_mode` do SubViewport tem que ser o padrão, não FSR. FSR reintroduz
  suavização de borda.
- Não use `MSAA` nem `TAA`. Serrilhado é parte do alvo.
- Textura importada precisa de `mipmaps/generate=false`, senão em distância a textura
  vira borrão cinza e o dither some.

## Como validar

Sempre compare lado a lado com as prints em `PRINTS/`. O critério não é "parece
antigo", é reproduzir três coisas específicas:

1. **Tremor de vértice** ao andar devagar perto de uma parede.
2. **Padrão de xadrez visível** nos gradientes de luz, como no quarto âmbar.
3. **Textura nadando** no chão quando a câmera gira.

Se as três estão presentes, o look fechou.
