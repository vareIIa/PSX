# PROMPT-MESTRE — Projeto "SHIMOKAWA" (codinome)
> Documento canônico. Toda decisão de arte, código e escopo se resolve aqui.
> Versão 1.0 — 06/09/2026

---

## 1. Prompt original (do usuário)

> "Vamos fazer um jogo PSX style, em uma grande cidade vasta e explorável, visual FPS,
> clicando V vai pra terceira pessoa, nevoeiro vibe Silent Hill (ativável e desativável
> nas settings). Veja as prints, devemos seguir essa estética."

## 2. Prompt reescrito (versão executável)

**Pitch em uma frase.**
Um survival horror de exploração em primeira pessoa ambientado numa cidade japonesa
suburbana à noite, renderizado sob um contrato gráfico que emula com precisão o
hardware do PlayStation 1, onde o nevoeiro não é um efeito estético mas o próprio
sistema de oclusão que torna a cidade possível.

**O jogador.**
Controla um personagem em primeira pessoa. `V` alterna para uma câmera de terceira
pessoa em spring-arm alta e recuada, no enquadramento das prints 3 e 6. A troca é
instantânea e permitida em qualquer momento, inclusive em movimento, sem corte de
cena. Ambos os modos compartilham a mesma cápsula de colisão e a mesma velocidade.

**A cidade.**
Um distrito suburbano japonês contínuo e explorável a pé, montado a partir de um kit
modular numa grade de chunks de 32 m. Ruas estreitas, postes de concreto com fiação
aérea, máquinas de venda automática acesas, lojas de esquina, prédios de apartamento
de três andares com escada externa, um shotengai coberto, uma estação de trem.
Interiores selecionados são carregáveis sem tela de loading. A cidade é grande em
extensão percorrível, não em densidade de conteúdo: o vazio é intencional e é o que
produz o medo, conforme a tese de Mikami citada no artigo de referência.

**O nevoeiro.**
Três níveis nas configurações: `DENSO` (padrão, ~18 m de visibilidade, estética
Silent Hill 1 da print 5), `LEVE` (~45 m) e `DESLIGADO`. Em `DESLIGADO` o nevoeiro
volumétrico some mas o horizonte de streaming permanece: chunks continuam aparecendo
por pop-in a ~90 m, exatamente como um jogo de PS1 real sem névoa. Desligar o
nevoeiro nunca revela a cidade inteira, porque a cidade inteira nunca está carregada.

**O contrato gráfico.**
Renderização interna a 480x270, upscale nearest-neighbor para a resolução da janela.
Vertex snapping, mapeamento de textura afim, iluminação por vértice, dithering
ordenado Bayer 4x4 com truncamento para 15 bits de cor, texturas de no máximo 128 px
com filtro point e sem mipmap, e uma cadeia de pós-processamento com grão, aberração
cromática, scanlines, vinheta e letterbox. Os números exatos estão no ART-BIBLE.

**A interface.**
Diegética e artesanal: inventário em prancha de cortiça com recortes de papel, fita
adesiva, polaroid do personagem e status textual, no modelo da print 2. Nada de HUD
permanente em tela durante a exploração.

## 3. O que mudou e por quê

**"Cidade vasta e explorável" foi requalificado.** A frase original leva ao pior
resultado possível para um time pequeno: um mapa enorme e vazio de conteúdo que leva
dois anos para preencher. A releitura mantém a promessa (você anda por uma cidade
inteira, a pé, sem loading) e troca a métrica de sucesso de área bruta para densidade
de rota. Ver a seção de riscos no PLANO.

**"Nevoeiro desativável" ganhou um terceiro estado.** O nevoeiro do Silent Hill não
era enfeite: era o culling de draw distance do PS1. Um botão que simplesmente o
desliga expõe a cidade inteira e quebra ao mesmo tempo a performance e o clima. A
solução é manter o horizonte de streaming em todos os modos, de forma que `DESLIGADO`
entregue pop-in retrô honesto em vez de uma vista panorâmica impossível.

**O cenário foi fixado como Japão suburbano noturno.** As prints são inequívocas
nesse ponto: quatro das seis são japonesas e duas delas são diretamente da linhagem
Chilla's Art. Sem essa decisão fixada, cada asset novo vira uma discussão.

**A estética foi convertida em números.** "Vibe PSX" não é implementável. Resolução
interna, grade de snap, profundidade de cor, teto de textura e budget de polígono
são. O ART-BIBLE transforma cada print em parâmetro.

## 4. Pilares — o que o jogo é

1. **A restrição é a arte.** Nenhum efeito que o PS1 não conseguiria fazer, exceto na
   cadeia de pós-processamento, que emula a saída de vídeo composto e o VHS.
2. **O vazio assusta mais que o detalhe.** Salas com um único objeto. Ruas sem NPCs.
3. **O som carrega o medo.** Rádio com chiado, sirene, passos, chuva. Trilha no
   registro do Akira Yamaoka: drone industrial e metal percussivo.
4. **Recurso é escasso.** Munição e cura contadas em unidades, não em porcentagem.

## 5. Não-objetivos — o que o jogo não é

- Não tem mundo aberto com veículos, missões ou mapa de ícones.
- Não tem combate de ação. O confronto é evitável e caro.
- Não tem multiplayer, progressão por níveis, craft ou loot aleatório.
- Não tem iluminação em tempo real por pixel, sombras suaves, SSAO ou reflexos.
- Não busca 60 fps travados: 30 fps é autêntico e aceitável, com 60 opcional.

## 6. Referência visual — as seis prints

| Arquivo | O que extraímos |
|---|---|
| `1_61gUHPrW7IrHN2QqOn9_uw.webp` | Rua japonesa noturna. Céu verde-petróleo, luz sódio e neon, chuva, grão pesado. É o alvo principal da cidade. |
| `1_GDovc4E7KFIfN4klslsKHg.webp` | Quarto japonês âmbar. Dither gigante, textura chapada, pretos esmagados, letterbox. A referência mais fiel ao PS1 real. |
| `1_uK7r0x3HpJmSVeUa2c60lg.webp` | Rua no nevoeiro branco com pegadas de sangue. Vinheta CRT arredondada, contraste quase nulo. É o preset `DENSO`. |
| `1_A81Z0i4gJ32iWR_XjJOlAw.webp` | Corredor rosa em terceira pessoa. Define o enquadramento da câmera do `V` e a iluminação chapada por vértice. |
| `1_uPwt5ZFRdmAcPbF_OlEXLA.webp` | Corredor de concreto, porta tapada com tábuas. Define o interior degradado e a luz de fonte única. |
| `1_9seJRpDDqAscl-5RIYKDgw.webp` | Inventário em prancha de cortiça. Define toda a linguagem de UI. |
