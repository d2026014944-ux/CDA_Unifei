# 📁 Documentação Institucional — DACDA/UNIFEI

Centralização de documentos normativos, planejamento estratégico, transparência financeira e comunicação do Diretório Acadêmico de Ciência de Dados Aplicada.

> **Aviso:** Os documentos de natureza jurídica são **minutas/modelos de trabalho**. Antes de protocolo ou uso oficial, o conteúdo deve ser validado pela UNIFEI e por profissional habilitado.

---

## Mapa de Navegação

### 📜 Estatuto e Bases Normativas

| Documento | Descrição |
|-----------|-----------|
| [Estatuto Social](estatuto/estatuto-social.md) | Minuta completa (11 capítulos, 27 artigos) |
| [Ata de Fundação](estatuto/ata-de-fundacao.md) | Modelo de ata constitutiva |
| [Regimento Interno](estatuto/regimento-interno.md) | Operação cotidiana, divisão de áreas e transição |

### 📊 Planejamento Estratégico

| Documento | Descrição |
|-----------|-----------|
| [Plano de Ação](planejamento/plano-de-acao.md) | Matriz 5W2H em 7 eixos estratégicos |
| [Cronograma](planejamento/cronograma.md) | Marcos temporais relativos (semanas/meses) |
| [Metas e Indicadores](planejamento/metas-e-indicadores.md) | KPIs por área: governança, participação, comunicação |

### 🏛️ Administrativo e Compliance

| Documento | Descrição |
|-----------|-----------|
| [Política de Transparência](administrativo/transparencia.md) | Escopo de divulgação e fluxo de aprovação |
| [Prestação de Contas](administrativo/prestacao-de-contas.md) | Template: receitas, despesas, parecer do Conselho Fiscal |
| [Políticas Internas](administrativo/politicas-internas.md) | Conflito de interesse, uso de recursos, proteção LGPD |

### 📣 Comunicação Institucional

| Documento | Descrição |
|-----------|-----------|
| [Identidade Visual](comunicacao/identidade-visual.md) | Guia de estilo, paleta, tipografia |
| [Comunicados Oficiais](comunicacao/comunicados-oficiais.md) | 4 modelos: comunicado, edital, nota pública, ofício |

### 📂 Registros e Áreas Auxiliares

| Pasta | Finalidade |
|-------|-----------|
| [Atas](atas/README.md) | Assembleias e reuniões (anonimizadas) |
| [Financeiro](financeiro/README.md) | Balancetes e relatórios periódicos |
| [Projetos](projetos/README.md) | Fichas técnicas de projetos e eventos |
| [Assets](assets/README.md) | Identidade visual e materiais gráficos |

---

## Conexão com a Infraestrutura Técnica

Esta documentação integra o monorepo do CDA OS, que inclui:

- **[CDA OS](../initramfs/)** — Distribuição Linux acadêmica imutável (OverlayFS + SquashFS)
- **[Rede Mesh](../scripts/mesh/)** — Cluster L2 via `batman-adv` para computação distribuída
- **[CDA Center](../cda-center/)** — Painel web de monitoramento operacional
- **[Testes QEMU](../tests/qemu/)** — Laboratório de virtualização com 4 VMs

O DACDA é a entidade estudantil que governa e direciona o desenvolvimento desta infraestrutura.
