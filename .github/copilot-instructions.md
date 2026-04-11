# Skill: Engenharia de Prompt e Desenvolvimento Anti-Vibe Coding (Akita Way)

Estas instrucoes definem como colaborar com IA em engenharia de software com controle tecnico, rastreabilidade e qualidade.

## Objetivo

Tratar a IA como colaborador tecnico e nao como oraculo. A arquitetura, os requisitos e os criterios de qualidade sao responsabilidade humana.

## Principios Fundamentais

1. Disciplina > intuicao
- Estruture o problema antes de solicitar codigo.
- Nao delegue decisoes de arquitetura para a IA.

2. Anti-Vibe Coding
- Nunca aceite sugestoes sem analise de contexto.
- Toda resposta da IA deve ser validada tecnicamente.

3. Planejamento antes da execucao
- Defina limites do dominio, servicos e contratos.
- Use IA para acelerar implementacao, nao para decidir o produto.

## Fluxo de Trabalho (Akita Way)

### Fase 1: Fundacao e Estrutura

1. Arquitetura e dominio
- Defina entidades, limites de contexto e integracoes.
- Liste componentes obrigatorios: DB, APIs externas, filas, cache e observabilidade.

2. CLAUDE.MD (spec viva)
- Crie e mantenha um arquivo CLAUDE.MD no projeto.
- Documente nele:
  - stack tecnologica
  - variaveis de ambiente
  - estrutura de diretorios
  - responsabilidade de cada servico e modelo
  - decisoes arquiteturais e regras de negocio em evolucao
- Regra: toda mudanca de arquitetura deve atualizar o CLAUDE.MD antes de continuar.

### Fase 2: Desenvolvimento com TDD

1. TDD e obrigatorio
- Com IA, TDD e mais importante, nao menos.

2. Testes antes da implementacao
- Sempre solicite primeiro testes unitarios/integrados da feature.
- Implementacao so e aceita se os testes preexistentes passarem.

3. Recusa ativa
- Se a IA propor implementacao sem testes correspondentes, recuse.
- Reitere: "primeiro testes, depois codigo".

4. Controle manual quando necessario
- Se houver alucinacao, divergencia ou regressao:
  - pare o fluxo automatico
  - assuma edicao manual no editor
  - retome IA apenas com escopo reduzido e criterios objetivos

### Fase 3: Seguranca e Isolamento

1. AI-Jail (sandbox)
- Execute agentes e automacoes em ambiente isolado (Docker/containers).
- Evite execucao irrestrita no host local.

2. Modelo de permissoes
- Restrinja acessos de leitura/escrita e comandos perigosos.
- Monitore os comandos sugeridos/executados pela IA.

### Fase 4: Refatoracao Multisservico

1. Contexto compartilhado
- Prefira monorepo para visibilidade global dos servicos.
- Facilite refatoracoes transversais (tipos, contratos, payloads, eventos).

2. Testes cruzados de integracao
- Valide consumidor x provedor continuamente.
- Mudou contrato de dados? Teste de integracao deve falhar imediatamente se houver quebra.

## Politica Operacional para Prompts

1. Nunca usar one-shot para sistema real.
2. Trabalhar em ciclos curtos:
- Planejamento -> Documentacao -> TDD -> Implementacao -> Refatoracao -> Deploy
3. Toda feature deve incluir:
- contexto
- criterio de aceite
- testes esperados
- risco principal
- rollback

## Checklist de Aceitacao (Gate de Qualidade)

Uma entrega da IA so pode ser aceita quando todos os itens abaixo forem verdadeiros:

- [ ] Requisito e contexto estao claros e documentados.
- [ ] CLAUDE.MD atualizado com decisoes relevantes.
- [ ] Testes foram escritos antes da implementacao.
- [ ] Testes unitarios e de integracao estao verdes.
- [ ] Nao houve quebra de contrato entre servicos.
- [ ] Impactos de seguranca foram avaliados.
- [ ] Mudancas sao compreendidas pelo humano responsavel.

## Prompt Base Recomendado

Use este esqueleto para cada feature:

1. Contexto
- "Estamos no dominio X, servico Y, com contrato Z."

2. Restricoes
- "Nao altere API publica sem atualizar testes de integracao."
- "Nao implemente antes de gerar testes."

3. Entrega esperada
- "Gere primeiro testes unitarios e integrados para o cenario A/B."
- "Depois implemente o minimo para passar nos testes."

4. Validacao
- "Explique como os testes cobrem regressao e contrato."

## Mentalidade de Engenharia

Grandes criadores combinaram:

- Pensamento lateral para explorar alternativas.
- Raciocinio matematico dedutivo para garantir consistencia.
- Pensamento heuristico para decidir com pragmatismo sob restricoes reais.

## Regra Final

Velocidade sem criterio gera retrabalho. Use IA para acelerar o que voce ja projetou, nao para substituir engenharia.
