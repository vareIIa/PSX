# MISSÃO 1 — "VOCÊ NÃO VAI LONGE"
### Roteiro de filmagem (shooting script)

> Versão 1.0 — 02/10/2026. Escrito sobre o estado da branch `deploy` (a mais nova:
> estrada, praça da Matriz, casa da fumaça v2, estufa de Jota e Helmer).
> Este documento é história e direção. O mapeamento técnico e a divisão de tarefas
> estão em `missao1/mapeamento.md`.

---

## 0. Como ler este roteiro

**Onde a missão encaixa.** O jogo hoje vai assim:
`estrada (o padre no farol) → acorda na praça da Matriz → missão "A CASA DA FUMAÇA" (marcar no GPS, ir até lá)`.
A Missão 1 começa no instante em que essa termina: o jogador bate na porta da casa da fumaça.

**Fatos do jogo que o roteiro respeita** (todos lidos no código/planos da `deploy`):
- O protagonista estava dirigindo de noite na chuva para **São Thomé das Letras**, com o grupo "Bonde São Thomé" no celular. Escreveu e apagou a desculpa "Gente, não vou conseguir ir". Viu **o padre** no farol, bateu na árvore, recebeu as mensagens do "?" ("O Lucas e a Mari já estão aqui.", "Olha pra mim.") e foi puxado pela janela. Acordou deitado na **praça da Matriz**, de cabeça para a **capela azul**.
- O **dono da casa** atende a porta (feito na F5 da casa v2). Suas falas atuais (`ROLE_DONO`) são reaproveitadas aqui.
- **Jota** (1,90 m, coque, alargador vermelho, tatuagem de espinhos, o que "quer mais") e **Helmer** (cacheado, óculos redondos, bigode, "o que diz número") são uma dupla fixa e única. A "Super" e o "olho de gato" já existem no vocabulário deles.
- Carros existentes: Sedan, Hatch, Perua, Picape, Taxi, **Marea**, Fusca. O rádio do carro (`radio_carro.gd`) existe.
- A cidade é infinita, gerada proceduralmente, sem saída. **Berg já entendeu isso.**

**Personagem novo: BERG.** Uns 45 anos. Óculos escuros aviador mesmo de noite, jaqueta de couro marrom gasta, camisa estampada aberta no peito, correntinha, bigode. Fala mineiro ("uai", "sô", "cê"), rápido, ouriçado: mexe na chave, olha para os lados, acende um cigarro no outro. É engraçado por nervoso, não por palhaçada. Já passou pelo que o jogador está passando e lida com isso com humor de quem desistiu de chorar.
**O carro do Berg:** Marea preto rebaixado, uma calota faltando, e no vidro traseiro um adesivo desbotado **"SÃO THOMÉ DAS LETRAS"** (ele também ia para lá). Sempre estaciona com duas rodas em cima da calçada.

**Formato de cada plano.** Cada cena é uma tabela. Colunas:

| coluna | o que é |
|---|---|
| ID | identificador do plano, para o código (`M1-C3-04`) |
| Tipo | um do vocabulário abaixo |
| Enquadramento | sujeito e o que está no quadro |
| Câmera | movimento |
| s | duração em segundos |
| Fala | quem fala e o quê. Sem fala: `—` |
| Cues | animação, som, luz, efeito |

**Vocabulário de plano → lente sugerida** (FOV vertical, para o `Cinema.enquadrar`):

| Tipo | FOV | Nota |
|---|---|---|
| establishing wide | 68 | abre lugar, sempre com névoa no fundo |
| medium two-shot | 50 | dois personagens da cintura para cima |
| close-up | 34 | rosto, ombros na borda |
| extreme close-up | 22 | olho, mão, objeto |
| over-the-shoulder | 42 | ombro de quem escuta em primeiro plano, desfocado pela névoa |
| low angle | 55 | câmera na altura do joelho olhando para cima |
| high angle | 55 | câmera acima da cabeça olhando para baixo |
| car-interior two-shot | 78 | do banco de trás ou do painel, os dois bancos da frente |
| sky/crane | 60 | sobe ou desce na vertical, céu e névoa no quadro |
| tracking/follow | 58 | acompanha quem anda ou o carro, recalculado por quadro (padrão `abertura_estrada.gd`) |
| dolly in/out | 45 | aproxima ou afasta em linha reta (`Cinema.mover`) |
| POV | 70 | primeira pessoa do jogador |

**Convenções.**
- `VOCÊ` = o protagonista. Na fita do nome aparece `{primeiro}` (primeiro nome da ficha).
- `DONO` = o dono da casa. Na fita aparece o nome sorteado da ficha dele.
- Falas aparecem na caixa de conversa (fala com escolha) ou como legenda de cena cortada. Voz: os bipes do sistema `Voz`, como o resto do jogo.
- `[se flag]` marca uma variante de fala. `◉ OLHO` marca o instante em que o olho do efeito borboleta aparece.
- Cortes secos são o padrão. `corte preto` = `Cinema.corte(0.12)`.
- Duração das falas: ~0,9 s por linha curta + 0,055 s por letra. Os tempos abaixo já contam isso.

---

## 1. O OLHO (efeito borboleta)

Aparece **uma vez por escolha marcada**, no instante em que o jogador confirma a opção.

- **Forma:** olho estilo PSX desenhado só no contorno. Pálpebra de cima, pálpebra de baixo e o círculo da íris, linhas de 1 px na resolução interna 480×270. Sem preenchimento. Íris é um anel, com um ponto de pupila.
- **Tamanho e lugar:** 52×26 px, canto superior direito da área de imagem, 8 px abaixo da tarja de cima e 10 px da borda direita.
- **Cor:** o bege do texto de cena (`#EBE3CC`), alfa 0,55. Recebe grão, dither e aberração como o resto: não é interface limpa.
- **Animação (1,9 s total):**
  1. 0,00–0,25 s: abre (pálpebras se afastam do centro), alfa 0 → 0,55.
  2. 0,25–0,70 s: íris corre para a **esquerda** e segura.
  3. 0,70–1,20 s: íris corre para a **direita** e segura.
  4. 1,20–1,45 s: íris volta ao centro.
  5. 1,45–1,60 s: piscada (fecha e abre em 4 quadros).
  6. 1,60–1,90 s: fade out.
  O movimento da íris anda em degraus de 1 px a 15 qps, não liso: é PSX.
- **Som:** `interferencia.wav` bem baixo (−20 dB) com corte de graves, só durante a abertura do olho.
- **Regra:** o olho nunca bloqueia a cena. A conversa continua rodando atrás dele.

---

## 2. Estrutura da missão

**Título na HUD:** `VOCÊ NÃO VAI LONGE`

| Etapa | Texto da HUD | Termina quando |
|---|---|---|
| 1 | Fale com o dono da casa. | fim da Cena 1 |
| 2 | Saia da casa da fumaça. | jogador cruza a porta da rua |
| 2 opc | (Opcional) Desça ao porão. | fim da Cena 2. Some da HUD quando o jogador sai da casa |
| 3A | Siga o Berg. | (carona aceita) jogador chega à frente da igreja junto com Berg |
| 3B | Volte para a praça onde você acordou. | (carona recusada) jogador fala com Berg na igreja |
| 3B' | Ligue para o Berg. *(só se pegou o papel)* | ligação feita; vira "Encontre o Berg na igreja." com alfinete verde |

Fluxo:

```
[porta] → C1 DONO (◉ E1) → livre dentro da casa
            ├─ porão (opcional) → C2 JOTA E HELMER (◉ E2)
            └─ sai pela porta da rua → C3 O BERG (◉ E3)
                    ├─ ACEITA  → C4A ENTRAR NO CARRO → C5A A CORRIDA (◉ E5, ◉ E6) → C6A ESTACIONAR → segue o Berg → C7 FRENTE DA IGREJA
                    └─ RECUSA  → C4B O PAPEL (◉ E4 ao pegar) → Berg vira NPC 2 min → reaparece na igreja → C6B NA IGREJA → C7 FRENTE DA IGREJA
```

---

## CENA 1 — O DONO

*Externa/interna, noite. Porta da casa da fumaça. Música da festa abafada atrás da porta, chuva fina.*

Dispara quando o jogador bate e o dono abre (comportamento que já existe). As tarjas entram junto com a porta abrindo.

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C1-01 | establishing wide | Fachada da casa da fumaça de frente, rua molhada no primeiro terço, fumaça saindo pela fresta da janela iluminada de âmbar. Jogador pequeno na porta, de costas. | estática, leve dolly in de 1 m | 3.5 | — | Tarjas entram. Batida na porta (`porta_trinco`). Música abafa e cresce. |
| M1-C1-02 | over-the-shoulder | Por cima do ombro do jogador. A porta abre para dentro. DONO no vão, recortado pela luz azul da TV e âmbar das luminárias, fumaça rolando por cima da cabeça dele para a rua. | estática | 3.0 | DONO: "Você é o cara da praça. Já ouvi falar." | Porta abre (`porta_abre`). Som da festa sobe +8 dB de uma vez. DONO encostado no batente. |
| M1-C1-03 | close-up | VOCÊ, rosto molhado, luz da casa batendo de frente. | estática | 2.0 | VOCÊ: "Ouviu de quem?" | — |
| M1-C1-04 | medium two-shot | Os dois no vão da porta, perfil. | estática | 3.5 | DONO: "Cidade pequena." *(ri da própria piada)* "Entra. Fecha a porta que a névoa vem junto." | DONO ri (`risada_m_1`), dá passo para dentro, gesto de cabeça "vem". |
| M1-C1-05 | tracking/follow | Atrás do jogador entrando na sala: a festa, gente no sofá, TV com a partida, fumaça no teto. DONO vai na frente até a bancada da cozinha. | segue a 2,2 m, altura 1,5 m | 4.0 | — | Convidados olham o jogador entrando (2 ou 3 viram a cabeça). Porta fecha sozinha atrás. |
| M1-C1-06 | medium two-shot | Bancada da cozinha. DONO apoiado nela, jogador do outro lado. Sala desfocada ao fundo. | estática | 4.5 | DONO: "Ninguém entra nessa cidade faz tempo, {primeiro}. Sair é que é o problema." | DONO acende cigarro. |
| M1-C1-07 | close-up | VOCÊ, reação. | estática | 2.0 | VOCÊ: "Como você sabe meu nome?" | — |
| M1-C1-08 | close-up | DONO, fumaça saindo da boca devagar. | dolly in 0,3 m | 3.5 | DONO: "Aqui todo mundo sabe o nome de todo mundo. Até de quem acabou de chegar." | Pausa de 0,6 s antes da fala. |
| M1-C1-09 | over-the-shoulder | Por cima do ombro do DONO, jogador no quadro. | estática | 2.5 | DONO: "E aí. O que te trouxe?" | Abre a lista de escolha. |

**ESCOLHA E1** ◉ OLHO — flag `m1_contou_ao_dono`

| Opção | Valor | Plano | Fala | Cues |
|---|---|---|---|---|
| **CONTAR DA ESTRADA** | `true` | M1-C1-10a close-up VOCÊ (3.5 s), depois M1-C1-11a close-up DONO (4.5 s) | VOCÊ: "Eu tava indo pra São Thomé. Apaguei na estrada e acordei no chão da praça." / DONO *(para de sorrir, olha para a sala, abaixa a voz)*: "Fala baixo. Aqui dentro isso dá azar." "...Já teve gente perguntando de você hoje." | Música da sala abaixa 6 dB durante a fala do DONO (mixagem de tensão), volta depois. |
| **SÓ DE PASSAGEM** | `false` | M1-C1-10b close-up VOCÊ (2 s), depois M1-C1-11b medium two-shot com a sala ao fundo (4.5 s) | VOCÊ: "Tô só de passagem." / DONO *(gargalha, vira para a sala)*: "De passagem! Ó, ele tá de passagem!" | A sala inteira ri (`risada_m_2`, `risada_f_1`, `risada_f_2` em sequência, 3D). Dois convidados levantam a lata. |

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C1-12 | extreme close-up | Mão do DONO empurrando o pagamento pela bancada até o jogador. | estática | 2.5 | DONO: "Toma. Você vai precisar mais do que eu." | O mesmo pagamento que o `ROLE_DONO` já dá hoje. Som `pegar`. |
| M1-C1-13 | medium two-shot | Os dois. DONO aponta com o cigarro para a porta do porão e depois para a porta da rua. | estática | 5.0 | DONO: "Os meninos tão lá embaixo, no porão. Se quiser conhecer quem sabe das coisas..." "Se não, a porta é aquela." | Gesto de apontar (duas direções). Tarjas saem. Controle volta. HUD: etapa 2 + opcional. |

---

## CENA 2 — JOTA E HELMER (opcional)

*Interna, noite. Porão da casa da fumaça: teto baixo (2,05 m), luz roxa de cultivo, lâmpada pendurada, bancada com potes, cartazes (a mona lisa de olho vermelho e o retrato de Jota fardado de general, já do andar 10).*

Dispara quando o jogador pisa no último degrau. Ao entrar, flag `m1_desceu_ao_porao = true` (não é escolha, não mostra olho).

> **Nota para quem implementa:** hoje a dupla trabalha na estufa. Durante a Missão 1 ela está no porão; quando a missão termina, volta à rotina da estufa. Eles continuam únicos (sem cópia), igual ao andar 10.

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C2-01 | POV | Descendo a escada de madeira. A lâmpada balança e o facho roxo corta a fumaça. | head bob da descida, 4 degraus | 3.0 | — | Passos `passo_madeira`. Som de ventilador e do funk lá de cima abafado pelo piso. |
| M1-C2-02 | establishing wide | De um canto baixo: o porão inteiro. HELMER de costas na bancada contando, JOTA curvado sob o teto baixo regando um vaso. | estática | 3.0 | HELMER *(sem virar)*: "Trinta e dois... trinta e três... Fecha a porta, tá vazando cheiro." | HELMER anota na prancheta a cada número. |
| M1-C2-03 | medium two-shot | JOTA se endireita, bate a cabeça na lâmpada. Lâmpada balança, sombras correm. | estática | 3.0 | JOTA: "Ai! ...Ô, é o cara da praça!" | Animação de bater a cabeça. Lâmpada vira pêndulo por 4 s (a luz oscila nos planos seguintes). |
| M1-C2-04 | low angle | JOTA de baixo, gigante sob o teto, regador na mão. | estática | 3.5 | JOTA: "Cê caiu do céu mesmo? Tão falando que cê caiu do céu." | — |
| M1-C2-05 | close-up | VOCÊ. | estática | 1.8 | VOCÊ: "Eu acordei no chão." | — |
| M1-C2-06 | over-the-shoulder | Por cima do ombro do jogador, HELMER ainda de costas. | estática | 2.5 | HELMER: "Dá no mesmo. Cento e quarenta e sete." | — |
| M1-C2-07 | medium two-shot | JOTA chega perto, aponta HELMER com o polegar. | estática | 3.5 | JOTA: "O Helmer conta tudo. Planta, dinheiro, os dias..." | — |
| M1-C2-08 | close-up | VOCÊ. | estática | 2.2 | VOCÊ: "Faz quantos dias que vocês tão aqui?" | — |
| M1-C2-09 | dolly in | HELMER para. Vira devagar. Pela primeira vez olha para o jogador. A luz roxa nos óculos redondos. | dolly in de 1,2 m até close-up | 4.0 | HELMER: "...Aí eu parei de contar." | Ventilador para por 1 s. Silêncio. A lâmpada ainda balança. |
| M1-C2-10 | medium two-shot | JOTA quebra o silêncio estendendo um baseado aceso. | estática | 3.5 | JOTA: "Cola aí. A primeira é por conta da casa. Olho de gato garantido." | Brasa acesa na mão. Abre a escolha. |

**ESCOLHA E2** ◉ OLHO — flag `m1_fumou_com_a_dupla`

| Opção | Valor | Plano | Fala | Cues |
|---|---|---|---|---|
| **ACEITAR** | `true` | M1-C2-11a POV (2.5 s): a mão do jogador pega, brasa sobe até perto da câmera, fumaça na frente da tela. M1-C2-12a medium two-shot (3.5 s) | JOTA: "Ihhh, olha o olho dele!" / HELMER *(anota)*: "Quatro segundos pra bater. Anotado." | Depois que a cena acaba: 45 s de "barato" na pós (aberração +60%, matiz oscilando ±8°, passos 5% mais lentos), saindo em rampa nos últimos 10 s. |
| **RECUSAR** | `false` | M1-C2-11b medium two-shot (3.5 s) | JOTA: "Careta!" *(ri)* / HELMER: "Sobra mais. Cento e quarenta e oito." | JOTA ri (`risada_m_2`), dá o trago ele mesmo. |

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C2-13 | medium two-shot | JOTA encosta no batente da escada. | estática | 3.5 | JOTA: "Quando cansar de procurar a saída, volta aqui. Tem vaga na estufa." | Gancho para o sistema de profissões. |
| M1-C2-14 | close-up | HELMER, já de volta à bancada, sem olhar. | estática | 2.0 | HELMER: "Ele não volta." | — |
| M1-C2-15 | close-up | JOTA, sorriso. | estática | 2.0 | JOTA: "Todo mundo volta." | Tarjas saem. Controle volta. Opcional some da HUD. |

---

## CENA 3 — O BERG

*Externa, noite. A rua em frente à casa da fumaça, névoa, chuva fina, asfalto molhado refletindo o âmbar da janela.*

Dispara quando o jogador cruza a porta da rua. O Marea preto já está estacionado do outro lado da porta, **rodas do lado da calçada em cima do meio-fio** (carro inclinado ~6°), pisca-alerta apagado, motor desligado, rádio tocando baixo lá dentro. BERG encostado no paralama dianteiro, braços cruzados, cigarro.

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C3-01 | establishing wide | Do outro lado da rua, baixo: a porta da casa se abre e o jogador sai. Em primeiro plano, desfocado, o Marea inclinado na calçada. BERG é só uma silhueta com a brasa acesa. | estática | 3.5 | — | Tarjas entram. Porta fecha atrás do jogador, a música da festa corta. Fica só a chuva e o rádio do carro baixinho. |
| M1-C3-02 | extreme close-up | A brasa do cigarro acende forte num trago. Reflexo da janela nos óculos escuros. | estática | 1.5 | — | Som do trago. |
| M1-C3-03 | over-the-shoulder | Por cima do ombro do BERG, jogador parado na calçada. | estática | 3.0 | BERG: "Até que enfim. Pensei que cê tinha virado móvel lá dentro." | BERG joga a bituca no chão, pisa. |
| M1-C3-04 | close-up | VOCÊ, desconfiado. Passo para trás. | estática | 1.8 | VOCÊ: "Quem é você?" | — |
| M1-C3-05 | medium two-shot | Perfil dos dois, o carro entre eles e a câmera. BERG desencosta, mãos abertas, ouriçado, chaves tilintando no dedo. | tracking lateral lento, 1,5 m | 5.0 | BERG: "Calma, calma, calma. Berg. Prazer. Eu também não sou daqui." | Loop de "ouriçado": troca o peso de perna, gira o chaveiro. |
| M1-C3-06 | close-up | BERG. | estática | 4.5 | BERG: "Eu te vi hoje. Na praça. Cê tava deitado no chão de pedra, olhando pro céu igual peixe fora d'água." | — |
| M1-C3-07 | close-up | VOCÊ. | estática | 2.2 | VOCÊ: "Você me viu... e me deixou lá?" | — |
| M1-C3-08 | medium two-shot | BERG dá de ombros. | estática | 3.5 | BERG: "Tava vendo se cê levantava sozinho. Todo mundo levanta. Eu levantei." | — |
| — | — | **Variante** (substitui nada, entra antes do C3-09): | | | | |
| M1-C3-08v1 | close-up | BERG funga, cheira o ar, abre um sorriso. | estática | 3.5 | `[se m1_desceu_ao_porao]` BERG: "Cê desceu lá com o Jota e o Helmer, né? Tá com cheiro de estufa." | — |
| M1-C3-08v2 | close-up | BERG, sério. | estática | 3.5 | `[se m1_contou_ao_dono]` BERG: "O dono aí me ligou. Falou que cê tava perguntando da estrada." | — |
| M1-C3-09 | extreme close-up | Os óculos do BERG. No reflexo, o jogador pequeno e a janela âmbar. | dolly in lento | 4.5 | BERG: "Deixa eu adivinhar. Estrada de terra. Indo pra São Thomé. O farol pegou alguma coisa... e apagou." | Rádio do carro chia sozinho por 0,5 s (`estatica`). |
| M1-C3-10 | close-up | VOCÊ, choque. | dolly in 0,2 m | 2.2 | VOCÊ: "...Como você sabe disso?" | — |
| M1-C3-11 | low angle | BERG de baixo, contra o céu verde-petróleo e a névoa. Dá a volta até a traseira e bate com o nó do dedo no adesivo desbotado "SÃO THOMÉ DAS LETRAS". | estática, ele entra e sai do quadro | 5.5 | BERG: "Porque comigo foi igualzinho. Eu ia pra São Thomé ver disco voador. Acordei no chão daquela praça. Com essa mesma cara que cê tá fazendo agora." | Batida no vidro (`clique` grave). |
| M1-C3-12 | extreme close-up | O adesivo, gotas escorrendo por cima das letras. | estática | 1.5 | — | — |
| M1-C3-13 | medium two-shot | BERG volta para a frente do carro, abre os braços para a rua inteira. | estática | 5.0 | BERG: "Olha. Cê tá com cara de quem vai sair andando até achar a saída. Vou te poupar esse trabalho." | — |
| M1-C3-14 | over-the-shoulder | Por cima do ombro do jogador. BERG gira a chave no dedo e indica a porta do carona com a cabeça. | estática | 3.5 | BERG: "Entra aí. Te explico no caminho. Tem um lugar que eu quero te mostrar." | Abre a escolha. |

**ESCOLHA E3** ◉ OLHO — flag `m1_aceitou_carona_berg`

| Opção | Valor | Vai para |
|---|---|---|
| **ENTRAR NO CARRO** | `true` | Cena 4A |
| **RECUSAR** | `false` | Cena 4B |

---

## CENA 4A — ENTRAR NO CARRO (carona aceita)

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C4A-01 | medium two-shot | BERG sorri, bate duas vezes no teto do carro. | estática | 2.0 | BERG: "Isso. Gostei de você." | Batida no teto (`clique` metálico ×2). |
| M1-C4A-02 | tracking/follow | Câmera na altura do retrovisor, BERG contorna a frente do carro até a porta do motorista. Jogador vai para a porta do carona. | segue BERG | 3.0 | — | **Anim nova:** contornar o carro. |
| M1-C4A-03 | car-interior two-shot | De dentro do carro, do banco de trás central: as duas portas abrem quase juntas. BERG senta primeiro, jogador depois. | estática | 4.0 | — | **Anim nova:** abrir porta por fora, sentar, puxar a porta. Som `porta_carro` ×2 (abre), ×2 (fecha) defasado 0,3 s. Chuva fica abafada de repente quando as portas fecham. |
| M1-C4A-04 | extreme close-up | A chave entra na ignição e gira. Painel acende verde. | estática | 1.8 | — | `motor_partida`, depois `motor_loop`. |
| M1-C4A-05 | establishing wide | De fora, rente ao chão, do lado da calçada: a roda desce do meio-fio, a suspensão bate, o carro sai. | estática | 3.0 | — | Tranco da suspensão (`motor_marcha` + baque). |

---

## CENA 5A — A CORRIDA (carona aceita)

*Interna/externa do carro em movimento, noite, névoa. O carro dirige sozinho a rota real do GPS até a praça da Matriz.*

> **Nota de tempo:** a distância até a igreja varia com a semente. A cena dura ~160 s. Se a rota for mais longa, um **corte de tempo** (`corte preto`, 0,4 s) depois do M1-C5A-19 leva o carro aos últimos 150 m antes da praça. Se for mais curta, o carro dá voltas no quarteirão até a conversa acabar (os planos externos escondem isso).

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C5A-01 | sky/crane | De cima, 25 m, o Marea sozinho numa avenida molhada, faróis abrindo dois cones na névoa. A cidade some na névoa para todos os lados. | crane sobe de 15 para 30 m acompanhando | 5.0 | — | Só motor e chuva. |
| M1-C5A-02 | car-interior two-shot | Do banco de trás, os dois na frente. Limpador de para-brisa batendo. | estática, tremor leve de estrada | 4.5 | BERG: "Primeira semana eu fiz o que cê ia fazer. Enchi o tanque e fui reto. Nove horas reto." | Limpador em loop (1,1 s por batida). |
| M1-C5A-03 | close-up | VOCÊ, perfil, luz dos postes passando pelo rosto. | estática | 1.5 | VOCÊ: "E?" | Luz de poste passa a cada 2,4 s (faixa clara correndo pela cara). |
| M1-C5A-04 | close-up | BERG dirigindo, uma mão só no volante. | estática | 6.0 | BERG: "E a cidade foi junto. Rua, poste, mercado, casa da fumaça... Já reparou que tem casa da fumaça em todo canto? Parece franquia." | — |
| M1-C5A-05 | POV | Pelo para-brisa: a rua vem saindo da névoa sem fim, um cruzamento, outro, outro. | movimento do carro | 4.5 | BERG *(off)*: "Pintei um poste de spray rosa pra marcar. Voltei procurando. Nunca mais achei. As ruas mudam quando cê vira as costas, sô." | — |
| M1-C5A-06 | close-up | VOCÊ. | estática | 1.8 | VOCÊ: "Isso não existe." | — |
| M1-C5A-07 | over-the-shoulder | Por cima do ombro do jogador, BERG aponta com o queixo para a névoa à frente. | estática | 2.0 | BERG: "Fala isso pra ela." | — |
| M1-C5A-08 | extreme close-up | O dedo do BERG apertando o botão do rádio. | estática | 1.5 | — | **Anim nova:** mexer no rádio. Chiado (`radio_click`, `estatica`). |
| M1-C5A-09 | car-interior two-shot | Do painel, olhando para os dois. O rádio pega uma estação: funk (`funk_batida`). | estática | 6.5 | BERG: "Só pega essa rádio. Toca a mesma música desde que eu cheguei." "Eu já sei a letra de trás pra frente." | BERG balança a cabeça no ritmo e cantarola desafinado (voz `voz_m` em loop curto). |
| M1-C5A-10 | tracking/follow | De fora, ao lado do carro, rente às rodas, árvores e postes passando no primeiro plano. | tracking lateral a 3 m, 1 m de altura | 3.5 | — | Rádio abafado vindo de dentro. |
| M1-C5A-11 | close-up | BERG para de cantar. Abaixa o volume. Sério. | estática | 4.5 | BERG: "Me fala uma coisa. Antes de apagar... cê viu alguém na estrada?" | Rádio cai para −18 dB. Abre a escolha. |

**ESCOLHA E5** ◉ OLHO — flag `m1_contou_do_padre_ao_berg`

| Opção | Valor | Planos |
|---|---|---|
| **CONTAR DO PADRE** | `true` | ver 12a–15a |
| **NÃO VI NADA** | `false` | ver 12b–13b |

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C5A-12a | close-up | VOCÊ, olhando para a frente, sem piscar. | dolly in 0,2 m | 4.5 | VOCÊ: "Um padre. Parado no meio da estrada. Ele... sorriu pra mim." | — |
| M1-C5A-13a | extreme close-up | As mãos do BERG apertando o volante até os nós ficarem brancos. | estática | 2.0 | — | Rangido de couro do volante. **O rádio corta sozinho para estática** (`interferencia`) e fica. |
| M1-C5A-14a | car-interior two-shot | Do banco de trás. Silêncio, só limpador e estática. BERG não olha para o jogador. | estática | 5.5 | BERG: "...Sorrindo." "Eu nunca falei disso pra ninguém." "Eu também vi ele." | Pausa de 1,2 s antes da primeira fala. |
| M1-C5A-15a | close-up | BERG, de perfil, a luz de um poste passa e deixa o rosto no escuro. | estática | 4.5 | BERG: "É por isso que eu vou pra igreja toda noite. Se ele tá em algum lugar nessa cidade, é lá." | BERG desliga o rádio. |
| M1-C5A-12b | close-up | VOCÊ, desvia o olhar para a janela. | estática | 2.0 | VOCÊ: "Não. Só escuro." | — |
| M1-C5A-13b | close-up | BERG abaixa os óculos um centímetro com o dedo e olha para o jogador por cima deles. Segura. Sobe os óculos de volta. | estática | 4.5 | BERG: "Hm." "Tá bom. Cê é que sabe." | **Anim nova:** baixar os óculos (mesma do C4B). Rádio volta ao volume. |

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C5A-16 | sky/crane | De cima, bem alto (40 m), o carro virando uma esquina, a névoa engolindo as ruas em volta: um labirinto sem borda. | crane desce de 40 para 22 m | 4.5 | BERG *(off)*: "Uma coisa eu aprendi. Nessa cidade nada fica no lugar. Só a igreja. A igreja tá sempre lá." | — |
| M1-C5A-17 | car-interior two-shot | Do banco de trás. | estática | 4.5 | BERG: "Cê tinha alguém te esperando? Lá em São Thomé?" | Abre a escolha. |

**ESCOLHA E6** ◉ OLHO — flag `m1_falou_do_bonde`

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C5A-18a | close-up | VOCÊ. *(opção FALAR DO LUCAS E DA MARI, `true`)* | estática | 4.0 | VOCÊ: "O bonde. Uns amigos. O Lucas e a Mari já tavam lá." | — |
| M1-C5A-18a2 | extreme close-up | O retrovisor interno: BERG olhando pelo espelho para o banco de trás vazio. Ajusta o espelho. | estática | 2.5 | — | Por 2 quadros, a estática do rádio dá um pico. Nada aparece no espelho. |
| M1-C5A-18a3 | close-up | BERG. | estática | 5.0 | BERG: "Lucas e Mari." "...Tem uns nomes que a gente escuta por aqui." "Esquece. Nome comum." | — |
| M1-C5A-18b | close-up | VOCÊ. *(opção NÃO TINHA NINGUÉM, `false`)* | estática | 2.5 | VOCÊ: "Ninguém. Eu ia sozinho." | — |
| M1-C5A-18b2 | close-up | BERG. | estática | 5.0 | BERG: "Melhor. Ninguém sentindo sua falta, ninguém vindo te procurar." *(pausa)* "...Ou pior." | — |

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C5A-19 | tracking/follow | Atrás do carro, as lanternas vermelhas, a rua reta. | tracking atrás a 8 m, 2 m de altura | 3.0 | — | Ponto do corte de tempo, se precisar. |
| M1-C5A-20 | POV | Pelo para-brisa: a névoa abre e a **torre da capela azul** aparece, iluminada, acima das árvores da praça. | dolly in do carro | 4.5 | BERG: "Chegamos." | Luz da igreja (o facho que já existe na abertura) entra no quadro. Rádio desligado. |

---

## CENA 6A — ESTACIONAR NA PRAÇA (carona aceita)

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C6A-01 | low angle | Rente ao meio-fio da praça: o carro sobe na calçada de lado, duas rodas em cima, e para torto como viatura. | estática | 3.5 | — | Baque da suspensão, freio de mão (`clique`), motor desliga. |
| M1-C6A-02 | car-interior two-shot | Do painel. BERG tira a chave. | estática | 3.0 | BERG: "Estacionamento VIP." | — |
| M1-C6A-03 | medium two-shot | De fora, os dois saindo ao mesmo tempo pelas duas portas. | estática | 3.5 | — | **Anim nova:** sair do carro (motorista e carona), fechar porta. `porta_carro` ×2. |
| M1-C6A-04 | over-the-shoulder | Por cima do ombro do BERG, que já anda em direção à igreja, olha para trás. | estática | 2.5 | BERG: "Vem." | Tarjas saem. Controle volta. HUD: "Siga o Berg." |

**Gameplay:** BERG anda até a frente da capela pelo calçamento da praça. Anda devagar, para e espera se o jogador ficar a mais de 8 m, acende cigarro enquanto espera. Ao chegar a 3 m da escadaria com o jogador perto → Cena 7.

---

## CENA 4B — O PAPEL (carona recusada)

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C4B-01 | close-up | BERG. Um sorriso de canto, de quem já esperava isso. | estática | 2.0 | BERG: "Hm." | — |
| M1-C4B-02 | medium two-shot | BERG **desencosta do carro**, tira um papel dobrado do bolso da jaqueta. | estática | 2.5 | — | **Anim nova:** desencostar do carro. Som `papel`. |
| M1-C4B-03 | extreme close-up | O papel caindo, girando, e pousando na calçada molhada aos pés do jogador. Dá para ler: **BERG (35) 9 ••••-••••**. | câmera baixa, acompanha a queda | 2.5 | BERG *(off)*: "Eu sei que você vai precisar." | **Anim nova:** jogar papel no chão. O papel vira o item no chão `bilhete_berg` (interativo depois). DDD 35 é o sul de Minas, a região de São Thomé. |
| M1-C4B-04 | tracking/follow | BERG contorna a frente do carro devagar, a mão passando pelo capô, até a porta do motorista do lado da rua. O carro com duas rodas na calçada fica entre ele e o jogador. | tracking lateral acompanhando BERG | 4.0 | — | **Anim nova:** contornar o carro. |
| M1-C4B-05 | medium two-shot | De trás do jogador, por cima do teto do carro: BERG abre a porta do motorista. | estática | 2.0 | — | **Anim nova:** abrir porta do carro por fora. `porta_carro`. |
| M1-C4B-06 | close-up | BERG com a porta aberta, olha para o jogador por cima do teto. | estática | 1.5 | — | — |
| M1-C4B-07 | extreme close-up | O dedo indicador abaixa os óculos escuros um pouco. Os olhos do BERG aparecem por cima da armação. | dolly in lento | 2.0 | — | **Anim nova:** baixar os óculos. |
| M1-C4B-08 | close-up | BERG, os olhos à mostra. | estática | 4.0 | BERG: "Não vou me preocupar. Sei que você não vai longe." *(risada)* | `risada_m_1`. Ombros sacodem na risada. |
| M1-C4B-09 | car-interior two-shot | De dentro, do banco do carona: BERG sentando, puxando a porta, subindo os óculos. Ainda rindo baixo. | estática | 3.0 | — | **Anim nova:** entrar no carro. Porta fecha. `motor_partida`. |
| M1-C4B-10 | low angle | Rente ao meio-fio: a roda desce da calçada com o tranco da suspensão. | estática | 2.0 | — | Baque. |
| M1-C4B-11 | high angle | De cima da janela da casa da fumaça: o jogador pequeno na calçada, o papel branco ao lado do pé, o Marea indo embora, as lanternas vermelhas entrando na névoa. | crane sobe 3 m | 4.5 | — | Rádio do carro some aos poucos com a distância. Tarjas saem quando as lanternas ainda estão visíveis. Controle volta **com o carro ainda à vista**. |

**Gameplay depois do C4B-11:**

- O papel fica no chão como interativo: `[E] Pegar o papel`.
  - **E4** ◉ OLHO ao pegar — flag `m1_pegou_numero_berg = true`. Vira item no inventário ("Papel com telefone") e cria o contato **BERG** no celular. HUD: "Ligue para o Berg." Se o jogador sair da rua sem pegar, a flag fica `false` (sem olho).
- **O carro do Berg vira NPC de trânsito por 120 s** (ver Cena 4B-NPC abaixo).
- HUD: "Volte para a praça onde você acordou." (ou "Ligue para o Berg." se pegou o papel).

### Cena 4B-NPC — Berg pela cidade

- 0–120 s: o Marea dirige pela cidade em direções aleatórias, como qualquer carro do trânsito: para em semáforo, vira em cruzamentos sorteados. O jogador pode seguir a pé ou de carro. BERG visível dentro (vidro do MODERNO).
- Aos 120 s: o carro **some** só quando estiver fora da vista do jogador (fora do frustum ou além do alcance da névoa). Se o jogador estiver colado nele, o carro segue a rota do GPS até a praça e estaciona na frente do jogador: o resultado é o mesmo.
- Depois de sumir: o Marea aparece **estacionado na praça da Matriz** no mesmo ponto e ângulo do M1-C6A-01 (duas rodas na calçada, torto como viatura). BERG anda pela área da igreja em loop: vai até a escadaria, olha para a torre, fuma, dá uma volta no coreto, encosta no carro. Fica lá até o jogador interagir.

### Ligação (só se pegou o papel)

Celular → Contatos → BERG. A tela do celular, sem cena cortada.

| Fala | Cues |
|---|---|
| BERG: "Alô?" | 2 toques antes de atender. Funk do rádio dele ao fundo. |
| BERG: "...Ah, é você. Viu? Precisou." *(risada)* | `risada_m_2` |
| BERG: "Tô na igreja. Da praça. Onde mais?" | Desliga. HUD: "Encontre o Berg na igreja." Alfinete verde na igreja no mapa e no minimapa. |

---

## CENA 6B — NA IGREJA (carona recusada)

Dispara ao interagir com BERG na praça (`[E] Falar com Berg`).

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C6B-01 | establishing wide | Da escadaria da capela, olhando para a praça: o jogador chegando pelo calçamento, BERG em primeiro plano de costas, encostado no carro. | estática | 3.0 | — | Tarjas entram. Luz da igreja no chão. |
| M1-C6B-02 | close-up | BERG vira, abre um sorriso enorme. | estática | 3.0 | BERG: "Olha só quem apareceu." | — |
| M1-C6B-03 | medium two-shot | Os dois. BERG abre os braços. | estática | 4.0 | BERG: "Falei. Ninguém vai longe aqui." *(risada)* "Deu a volta no mundo e caiu no mesmo lugar." | `risada_m_1`. |
| M1-C6B-04 | close-up | BERG, já sério, indica a igreja com a cabeça. | estática | 2.5 | BERG: "Vem. Quero te mostrar uma coisa." | Corte para a Cena 7. BERG e jogador são posicionados em frente à escadaria no corte preto. |

---

## CENA 7 — A FRENTE DA IGREJA (os dois caminhos)

*Externa, noite. Escadaria da capela azul da praça da Matriz. A luz da igreja atravessa a névoa e cai no calçamento.*

| ID | Tipo | Enquadramento | Câmera | s | Fala | Cues |
|---|---|---|---|---|---|---|
| M1-C7-01 | establishing wide | De longe, do outro lado da praça, baixo: a capela azul enorme no alto do quadro, os dois pequenos ao pé da escadaria, a luz caindo neles pela névoa. | dolly in lento de 3 m | 5.0 | — | Tarjas entram (se não estiverem). Só vento e chuva. Sem música. |
| M1-C7-02 | medium two-shot | Os dois de costas para a câmera, olhando para a torre. | estática | 3.0 | — | — |
| M1-C7-03 | close-up | BERG aponta para o calçamento, a poucos metros: o lugar exato do pin onde o jogador acordou. | estática | 3.5 | BERG: "Foi ali que cê acordou. Ó. Bem ali." | Gesto de apontar. |
| M1-C7-04 | high angle | Do alto, olhando para o calçamento vazio onde ele acordou. A luz da igreja faz um retângulo claro em volta do ponto. | estática | 3.0 | BERG *(off)*: "Eu acordei no mesmo lugar. Na mesma pedra." | Eco do zumbido da abertura (`zumbido_loop`, −24 dB) entra. |
| M1-C7-05 | close-up | VOCÊ, olhando o chão. | estática | 2.0 | — | — |
| M1-C7-06 | low angle | BERG contra a torre iluminada. | estática | 6.0 | BERG: "Cidade sem fim, sem placa, sem saída... e todo mundo acorda aqui. Isso não é coincidência, sô." | — |
| — | — | **Variante** antes do C7-07: | | | | |
| M1-C7-06v | close-up | BERG, voz baixa, sem olhar para o jogador. | estática | 3.5 | `[se m1_contou_do_padre_ao_berg]` BERG: "Se ele tá esperando alguém, é aqui dentro." | — |
| M1-C7-07 | over-the-shoulder | Por cima do ombro do jogador: BERG sobe dois degraus, vira, abaixa os óculos. | estática | 4.0 | BERG: "Amanhã a gente entra. Hoje cê dorme. Cê vai precisar." | Anim de baixar os óculos (reuso). |
| M1-C7-08 | sky/crane | A câmera sobe pela fachada da capela até acima da torre. Os dois somem lá embaixo. A cidade em volta é só névoa e pontos de luz até onde a vista alcança, sem borda nenhuma. | crane sobe de 2 para 45 m, 8 s | 8.0 | — | Um sino toca uma vez, longe e grave. Fade para preto nos últimos 1,5 s. |
| M1-C7-09 | — | Preto. Texto centralizado na fonte de título. | — | 3.5 | `MISSÃO CONCLUÍDA` / `VOCÊ NÃO VAI LONGE` | `celular_ok`. Tarjas saem. Controle volta na praça, BERG encostado no carro (interativo, falas de rotina até a Missão 2). |

---

## 8. Listas

### 8.1 Animações de personagem necessárias

**Novas:**

| Personagem | Animação | Usada em |
|---|---|---|
| BERG | idle encostado no carro (braços cruzados, cigarro, troca de peso) | C3 |
| BERG | loop "ouriçado" em pé (gira o chaveiro, troca de perna, olha em volta) | C3 |
| BERG | desencostar do carro | C3-05, C4B-02 |
| BERG | jogar papel no chão | C4B-03 |
| BERG | contornar o carro andando (mão passando no capô) | C4A-02, C4B-04 |
| BERG | abrir porta do motorista por fora | C4A-03, C4B-05 |
| BERG | entrar no carro e sentar, puxar a porta | C4A-03, C4B-09 |
| BERG | sentado dirigindo (mão no volante, virar volante esq./dir., uma mão só) | C5A |
| BERG | mexer no rádio | C5A-08 |
| BERG | apertar o volante (tensão) | C5A-13a |
| BERG | baixar os óculos com o indicador e subir de volta | C4B-07, C5A-13b, C7-07 |
| BERG | rir (ombros sacudindo) | C4B-08, C6B-03 |
| BERG | sair do carro e fechar a porta | C6A-03 |
| BERG | apontar (braço estendido) | C7-03 |
| BERG | bater no vidro/teto com o nó do dedo | C3-11, C4A-01 |
| BERG | rotina na igreja (andar, parar, olhar a torre, fumar, encostar no carro) | C4B-NPC |
| JOGADOR | abrir porta do carona por fora, sentar, fechar | C4A-03 |
| JOGADOR | sentado no carona (idle, olhar para o motorista, olhar pela janela) | C5A |
| JOGADOR | sair do carro e fechar a porta | C6A-03 |
| JOGADOR | agachar e pegar item do chão | E4 (papel) |
| JOGADOR | primeira pessoa: pegar e tragar (mão + brasa) | C2-11a |
| DONO | gesto de empurrar algo pela bancada | C1-12 |
| DONO | apontar em duas direções com o cigarro | C1-13 |
| JOTA | bater a cabeça na lâmpada | C2-03 |
| JOTA | oferecer o baseado (braço estendido) | C2-10 |
| HELMER | contar e anotar na prancheta (loop) | C2 |
| HELMER | virar devagar e olhar | C2-09 |

**Já existentes (reuso):** dono abre a porta da rua, fumar em pé, convidados rindo, andar, falar (cabeça), sentar no sofá, regar (rotina de fazendeiro de Jota e Helmer).

**Carro (novas):** porta abrindo e fechando por dobradiça (motorista e carona), suspensão subindo e descendo o meio-fio, estacionar torto com duas rodas na calçada, dirigir sozinho seguindo a rota do GPS (cena 5A) e como NPC de trânsito (4B-NPC).

### 8.2 Escolhas e flags (efeito borboleta)

Todas mostram o OLHO ao confirmar. Todas vão para o save.

| ID | Onde | Opções | Flag | O que muda já na Missão 1 | O que pode mudar depois |
|---|---|---|---|---|---|
| E1 | Cena 1, dono | CONTAR DA ESTRADA / SÓ DE PASSAGEM | `m1_contou_ao_dono` | Berg comenta que o dono ligou para ele (C3-08v2). Se "passagem", a sala toda ri de você. | O dono vira informante e aliado (te esconde, te avisa) ou fica distante e pode te entregar a alguém que pergunta. |
| E2 | Cena 2, porão | ACEITAR / RECUSAR | `m1_fumou_com_a_dupla` | 45 s de barato na pós-produção. | Jota e Helmer confiam em você: vaga na estufa e entregas da Super liberadas mais cedo, a dupla te cobre numa situação futura. Recusar: Helmer te respeita, Jota te zoa e demora a ajudar. |
| E3 | Cena 3, carro | ENTRAR NO CARRO / RECUSAR | `m1_aceitou_carona_berg` | Escolhe o ramo inteiro (4A ou 4B). | Berg te trata como parceiro desde o começo, ou como alguém que ainda precisa aprender. Muda o tom dele na Missão 2. |
| E4 | Cena 4B, papel no chão | PEGAR (ou deixar) | `m1_pegou_numero_berg` | Contato BERG no celular, ligação e alfinete na igreja. Sem o papel, o jogador acha a praça sozinho. | O jogador pode ligar para o Berg em emergências. Sem o número, Berg só aparece quando quer. |
| E5 | Cena 5A, carro | CONTAR DO PADRE / NÃO VI NADA | `m1_contou_do_padre_ao_berg` | Berg revela que também viu o padre; fala extra na igreja (C7-06v). | Berg divide o que sabe sobre o padre e a igreja. Mentir: Berg esconde informação e desconfia na Missão 2. |
| E6 | Cena 5A, carro | FALAR DO LUCAS E DA MARI / NÃO TINHA NINGUÉM | `m1_falou_do_bonde` | Reação do Berg no retrovisor. | Lucas e Mari podem estar na cidade. Se você falou deles, Berg te avisa quando ouvir os nomes; se não, você descobre sozinho, tarde. |

**Flags de estado (sem olho):**

| Flag | Quando vira `true` | Usada em |
|---|---|---|
| `m1_desceu_ao_porao` | jogador entra no porão | Berg comenta o cheiro (C3-08v1) |
| `m1_concluida` | fim do C7-09 | liberar Missão 2, Berg fixo na praça |

### 8.3 Lugares e objetos

**Lugares:**

| Lugar | Estado | Nota |
|---|---|---|
| Casa da fumaça: porta da rua, sala, bancada da cozinha | existe (v2) | A casa da missão é a que o GPS da missão anterior escolheu. |
| Porão da casa da fumaça | **novo** | Escada de madeira de 4 a 6 degraus a partir da cozinha. Teto de 2,05 m (Jota tem que se curvar), luz roxa de cultivo, uma lâmpada pendurada que balança, bancada com potes e prancheta, a mona lisa de olho vermelho e o retrato de Jota de general na parede, um ventilador. |
| Rua em frente à casa | existe | Precisa de meio-fio alto o suficiente para o carro subir com duas rodas. |
| Avenidas da cidade (corrida) | existe | Rota real do GPS até a praça. |
| Praça da Matriz e capela azul | existe | Usar o pin onde o jogador acorda (270, −40) e a luz da igreja da abertura. Vaga do Berg: na calçada da praça, de frente para a escadaria. |

**Objetos e itens:**

| Objeto | Estado | Nota |
|---|---|---|
| Marea preto do Berg | carroceria existe, variante nova | Rebaixado, uma calota faltando, adesivo desbotado "SÃO THOMÉ DAS LETRAS" no vidro traseiro, portas que abrem. Único no mundo. |
| Rádio do carro | existe | Toca o funk (`funk_batida`) e corta para estática na cena do padre. |
| Papel com telefone (`bilhete_berg`) | **novo item** | Item no chão e no inventário. Pode reaproveitar o ícone `bilhete`. Texto: "BERG (35) 9 ••••-••••". |
| Contato BERG no celular | **novo** | App Contatos e Telefone, ligação com falas fixas. |
| Pagamento do dono | existe | O que o `ROLE_DONO` já paga hoje. |
| Baseado da Super (na mão de Jota) | existe no vocabulário | Só prop de cena com brasa. |
| Prancheta do Helmer | **novo prop** | Pode ser uma caixa fina com a célula de papel. |
| Lâmpada pendurada do porão | **novo prop** | Luz que balança (pêndulo amortecido de 4 s). |
| Cigarro e bituca do Berg | existe (fumar) | — |
| O OLHO | **novo, UI** | Ver seção 1. |

### 8.4 Sons usados

Todos já estão em `game/assets/audio`: `porta_abre`, `porta_trinco`, `porta_carro`, `motor_partida`, `motor_loop`, `motor_marcha`, `radio_click`, `estatica`, `interferencia`, `funk_batida`, `risada_m_1`, `risada_m_2`, `risada_f_1`, `risada_f_2`, `papel`, `pegar`, `clique`, `passo_madeira_*`, `zumbido_loop`, `celular_ok`, `chuva_loop`, `vento_loop`.
**Novo:** sino de igreja (uma badalada grave) para o C7-08.
