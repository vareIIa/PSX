# Jogo PSX Style

Survival horror de exploração num subúrbio japonês noturno, sob um contrato gráfico
que emula o hardware do PlayStation 1.

## Comece por aqui

| Documento | Para quê |
|---|---|
| [PLANO.md](PLANO.md) | Roadmap, status das fases, riscos |
| [docs/PROMPT-MESTRE.md](docs/PROMPT-MESTRE.md) | O que o jogo é, e o que não é |
| [docs/ART-BIBLE.md](docs/ART-BIBLE.md) | Todo número de renderização |
| [docs/PADROES-ENGENHARIA.md](docs/PADROES-ENGENHARIA.md) | Definição de pronto, validação, código |

## Rodar

```bash
./dev.sh check       # valida antes de commitar
./dev.sh run         # abre o jogo
./dev.sh shot denso  # captura automatizada num preset de névoa
./dev.sh sheet       # refaz a folha de comparação com as referências
```

O Godot portable vive em `.tools/` e não é versionado. Se sumir, baixe o
4.7.2-stable win64 do site oficial e descompacte lá.

## Estado

Fases 0 e 1 concluídas: o contrato gráfico está implementado e verificado.
O aceite visual está em `captures/COMPARACAO_FASE1.png`.
