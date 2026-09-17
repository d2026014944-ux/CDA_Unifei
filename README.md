# CDA_Unifei — Infraestrutura & Governança Acadêmica

Monorepo do **Diretório Acadêmico de Ciência de Dados Aplicada (DACDA)** da UNIFEI.  
Reúne a infraestrutura técnica do CDA OS e a documentação institucional do DA em um único repositório, com política de transparência e auditoria clean-room.

---

## 🗂️ Visão Geral do Repositório

```
CDA_Unifei/
├── initramfs/          # Boot imutável (OverlayFS + SquashFS)
├── scripts/            # Mesh networking, build, auditoria
├── systemd/            # Serviço batman-adv
├── avahi/              # Descoberta mDNS (Jupyter + Dask)
├── cda-center/         # Painel web CGI (dashboard de sistema)
├── dist/               # Artefatos de distribuição
├── tests/              # Testes QEMU e unitários
├── documentos/         # 📜 Governança institucional do DACDA
│   ├── estatuto/       #   Estatuto Social, Regimento, Ata
│   ├── planejamento/   #   Plano de Ação, Cronograma, KPIs
│   ├── administrativo/ #   Transparência, Prestação de Contas
│   ├── comunicacao/    #   Identidade Visual, Comunicados
│   ├── atas/           #   Atas de assembleias
│   ├── financeiro/     #   Balancetes e relatórios
│   ├── projetos/       #   Fichas técnicas de projetos
│   └── assets/         #   Materiais gráficos
└── tasks/              # TODO e lessons learned
```

---

## ⚙️ Infraestrutura Técnica (CDA OS)

### Initramfs e Boot Imutável

Script de init que monta OverlayFS a partir de camadas `.squashfs` com seleção automática:

- **RAM** quando `MemAvailable >= cda.ram_min_mib` **e** `MemAvailable >= 2× tamanho total das imagens`
- **Disco** quando RAM insuficiente
- Forçadores via kernel cmdline: `cda.force_ram=1` / `cda.force_disk=1`

### Rede Mesh (`batman-adv`)

Cluster L2 ad-hoc via Wi-Fi mesh (`802.11s`) com SSID `CDA-Mesh`:

- IPv4 determinístico via hash do `machine-id` (sub-rede `10.42.0.0/24`)
- Tuning para cargas Dask: `network_coding=1`, `multicast_fanout=8`
- Descoberta automática via Avahi: `_jupyter._tcp:8888` e `_dask._tcp:8786`

### CDA Center (Painel Web)

Dashboard em tempo real (polling 3s) com tema escuro via CGI scripts:

- Visão do sistema, processos, rede/mesh, armazenamento/overlay
- Logs de boot, controle de serviços, terminal web

### Testes e Validação

- 4 VMs QEMU/KVM (3×8GB RAM + 1×2GB disco) com injeção de falhas
- Testes unitários para deployment slots e fallback
- Auditoria clean-room contra Woof-CE

---

## 📜 Documentação Institucional (DACDA)

Documentos de governança, planejamento e transparência do Diretório Acadêmico.  
→ **[Navegar documentos](documentos/README.md)**

| Área | Documentos Principais |
|------|----------------------|
| **Estatuto** | [Estatuto Social](documentos/estatuto/estatuto-social.md) · [Regimento Interno](documentos/estatuto/regimento-interno.md) · [Ata de Fundação](documentos/estatuto/ata-de-fundacao.md) |
| **Planejamento** | [Plano de Ação](documentos/planejamento/plano-de-acao.md) · [Cronograma](documentos/planejamento/cronograma.md) · [Metas e KPIs](documentos/planejamento/metas-e-indicadores.md) |
| **Administrativo** | [Transparência](documentos/administrativo/transparencia.md) · [Prestação de Contas](documentos/administrativo/prestacao-de-contas.md) · [Políticas Internas](documentos/administrativo/politicas-internas.md) |
| **Comunicação** | [Identidade Visual](documentos/comunicacao/identidade-visual.md) · [Comunicados Oficiais](documentos/comunicacao/comunicados-oficiais.md) |

> **Aviso jurídico:** Os documentos normativos são **minutas/modelos de trabalho**. Antes de qualquer protocolo, devem ser validados pela UNIFEI e por profissional habilitado.

---

## 🚀 Uso Rápido

### 1) Initramfs

No bootloader, passe parâmetros opcionais:

- `cda.ram_min_mib=4096`
- `cda.force_ram=1` ou `cda.force_disk=1`
- `cda.live_dev=/dev/vda1` (opcional)
- `cda.squashdir=/caminho/com/squashfs` (opcional)

### 2) Mesh (systemd)

```bash
sudo chmod +x /usr/local/sbin/cda-mesh-setup.sh
sudo systemctl daemon-reload
sudo systemctl enable --now cda-batman-adv.service
```

### 3) Avahi

Copie `avahi/services/cda-data-services.service` para `/etc/avahi/services/` e reinicie o `avahi-daemon`.

### 4) Testes QEMU

```bash
BASE_DISK=/path/base.qcow2 KERNEL_IMAGE=/path/bzImage \
  INITRD_IMAGE=/path/initrd.img SSH_KEY=/path/id_ed25519 \
  ./tests/qemu/mesh-lab.sh
```

---

## 🤝 Como Contribuir

1. Abra uma issue com contexto e proposta
2. Desenvolva em branch própria (`tipo/tema-curto`)
3. Abra pull request com resumo e pontos de revisão
4. Aguarde revisão antes de merge

Consulte os detalhes em [CONTRIBUTING.md](CONTRIBUTING.md) e nosso [Código de Conduta](CODE_OF_CONDUCT.md).

> ⚠️ **LGPD:** Nunca publique CPF, RG, endereço, telefone pessoal, e-mail pessoal, dados bancários ou assinaturas. Use `[DADO ANONIMIZADO]` quando necessário.

---

## 📄 Licença e Aviso Institucional

Os documentos de natureza jurídica deste repositório são minutas/modelos de trabalho. Antes de qualquer protocolo, registro ou uso oficial, o conteúdo deve ser revisado e validado pela UNIFEI e por profissional habilitado, com adequação às normas internas e à legislação brasileira vigente.
