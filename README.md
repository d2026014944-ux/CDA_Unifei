<p align="center">
  <img src=".github/assets/banner.jpg" alt="CDA OS — Distributed Academic Computing" width="100%" />
</p>

<h1 align="center">CDA OS</h1>

<p align="center">
  <strong>Sistema Operacional Linux Imutável para Computação Distribuída Acadêmica</strong>
</p>

<p align="center">
  <a href="https://github.com/d2026014944-ux/CDA_Unifei/actions"><img src="https://img.shields.io/github/actions/workflow/status/d2026014944-ux/CDA_Unifei/ci.yml?branch=main&style=flat-square&label=CI&logo=githubactions&logoColor=white" alt="CI"></a>
  <a href="#"><img src="https://img.shields.io/badge/shell-POSIX-informational?style=flat-square&logo=gnubash&logoColor=white" alt="Shell"></a>
  <a href="#"><img src="https://img.shields.io/badge/kernel-OverlayFS%20%2B%20SquashFS-0f172a?style=flat-square&logo=linux&logoColor=white" alt="Kernel"></a>
  <a href="#"><img src="https://img.shields.io/badge/mesh-batman--adv%20802.11s-22d3ee?style=flat-square&logo=wifi&logoColor=white" alt="Mesh"></a>
  <a href="#"><img src="https://img.shields.io/badge/compute-Dask%20%2B%20Jupyter-f97316?style=flat-square&logo=jupyter&logoColor=white" alt="Compute"></a>
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/contributions-welcome-brightgreen?style=flat-square" alt="Contributions"></a>
</p>

<p align="center">
  <a href="#-arquitetura">Arquitetura</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-cda-center">CDA Center</a> •
  <a href="#-documentação-institucional">Documentação</a> •
  <a href="#-contribuir">Contribuir</a>
</p>

---

## 🎯 O que é

O **CDA OS** é uma distribuição Linux acadêmica projetada pelo [DACDA](documentos/README.md) (Diretório Acadêmico de Ciência de Dados Aplicada) da **UNIFEI** para transformar notebooks e desktops comuns em um **cluster de computação distribuída ad-hoc** — sem datacenter, sem servidores dedicados, sem internet.

```
   📡 Wi-Fi Mesh (802.11s)
   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
   │  Nó 1    │◄──►│  Nó 2    │◄──►│  Nó 3    │◄──►│  Nó 4    │
   │  8GB RAM │    │  8GB RAM │    │  8GB RAM │    │  2GB RAM │
   │  ⚡ ram   │    │  ⚡ ram   │    │  ⚡ ram   │    │  💾 disk  │
   └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘
        │               │               │               │
   ┌────┴───────────────┴───────────────┴───────────────┴────┐
   │              batman-adv L2 • 10.42.0.0/24               │
   │         Dask Scheduler + Jupyter + Avahi mDNS           │
   └─────────────────────────────────────────────────────────┘
```

---

## 🏗 Arquitetura

<table>
<tr>
<td width="20%" align="center">

**Boot Imutável**

`SquashFS` + `OverlayFS`

Camadas read-only com escrita volátil em tmpfs

</td>
<td width="20%" align="center">

**Rede Mesh**

`batman-adv` + `802.11s`

IP determinístico via SHA-256 do machine-id

</td>
<td width="20%" align="center">

**Zero-Conf**

`Avahi` mDNS

Descoberta automática de Jupyter e Dask

</td>
<td width="20%" align="center">

**Painel Web**

`CDA Center`

7 CGI scripts — zero mocks

</td>
<td width="20%" align="center">

**Testes E2E**

`QEMU Lab`

4 VMs com failover de malha

</td>
</tr>
</table>

### Política de Boot Dual

| Condição | Modo | Performance |
|:---------|:----:|:-----------:|
| RAM ≥ 4GB **e** RAM ≥ 2× SquashFS | `ram` ⚡ | Máxima |
| RAM insuficiente | `disk` 💾 | Conservadora |
| `cda.force_ram=1` | `ram` ⚡ | Override |
| `cda.force_disk=1` | `disk` 💾 | Override |

---

## 🚀 Quick Start

<details>
<summary><strong>1. Boot via Initramfs</strong></summary>

No bootloader, passe parâmetros opcionais:

```bash
# Parâmetros de kernel cmdline
cda.ram_min_mib=4096          # Piso mínimo de RAM (MiB)
cda.force_ram=1               # Força boot em RAM
cda.force_disk=1              # Força boot em disco
cda.live_dev=/dev/sda1        # Dispositivo de boot
cda.deployment=current        # Slot de deployment
cda.squashdir=/path/squashfs  # Diretório de fallback
```

</details>

<details>
<summary><strong>2. Rede Mesh (systemd)</strong></summary>

```bash
sudo chmod +x /usr/local/sbin/cda-mesh-setup.sh
sudo systemctl daemon-reload
sudo systemctl enable --now cda-batman-adv.service
```

| Parâmetro | Valor |
|-----------|-------|
| SSID | `CDA-Mesh` |
| Frequência | 2412 MHz (Canal 1) |
| Sub-rede | `10.42.0.0/24` |
| Faixa de IPs | `.20` — `.219` |

</details>

<details>
<summary><strong>3. Avahi (mDNS)</strong></summary>

```bash
cp avahi/services/cda-data-services.service /etc/avahi/services/
systemctl restart avahi-daemon
```

Serviços publicados: `_jupyter._tcp:8888` • `_dask._tcp:8786`

</details>

<details>
<summary><strong>4. VM Local (QEMU)</strong></summary>

```bash
# Constrói rootfs, empacota initramfs e inicia VM
./scripts/build/run-local-os-vm.sh

# Acesso ao CDA Center:
# http://127.0.0.1:18080
```

</details>

<details>
<summary><strong>5. Testes de Integração (Mesh Lab)</strong></summary>

```bash
BASE_DISK=/path/base.qcow2 \
KERNEL_IMAGE=/path/bzImage \
INITRD_IMAGE=/path/initrd.img \
SSH_KEY=/path/id_ed25519 \
  ./tests/qemu/mesh-lab.sh
```

Valida: boot RAM vs. disco • failover mesh L2/L3 • cluster Dask distribuído

</details>

---

## 🖥 CDA Center

Painel web de monitoramento em tempo real servido pelo BusyBox httpd. **Zero dados mockados** — tudo lido diretamente do kernel Linux.

| Módulo | Fonte | Funcionalidade |
|:-------|:------|:---------------|
| `sysinfo` | `/proc/meminfo`, `/proc/cpuinfo` | CPU, RAM, uptime, load average |
| `processes` | `/proc/[pid]/stat` | Lista de processos com CPU% e MEM% |
| `network` | `/sys/class/net/`, `batctl` | Interfaces, peers mesh, rotas, DNS |
| `storage` | `/proc/mounts`, `df` | Montagens, overlay, dispositivos de bloco |
| `logs` | `dmesg`, `journalctl` | Logs do sistema, boot, metadados |
| `services` | `systemctl` | Status e controle (whitelist estrita) |
| `terminal` | `sh -c` + timeout 10s | Terminal web com blocklist de segurança |

<details>
<summary><strong>🔒 Blocklist de Segurança do Terminal</strong></summary>

Comandos automaticamente bloqueados:

```
rm -rf    mkfs    dd if=    shutdown    reboot
halt      poweroff    init 0    init 6
```

</details>

---

## 📜 Documentação Institucional

Governança, planejamento e transparência do [DACDA/UNIFEI](documentos/README.md):

<table>
<tr>
<td>

**📋 Normativo**
- [Estatuto Social](documentos/estatuto/estatuto-social.md)
- [Regimento Interno](documentos/estatuto/regimento-interno.md)
- [Ata de Fundação](documentos/estatuto/ata-de-fundacao.md)

</td>
<td>

**📊 Planejamento**
- [Plano de Ação](documentos/planejamento/plano-de-acao.md)
- [Cronograma](documentos/planejamento/cronograma.md)
- [Metas e KPIs](documentos/planejamento/metas-e-indicadores.md)

</td>
<td>

**🏛️ Administrativo**
- [Transparência](documentos/administrativo/transparencia.md)
- [Prestação de Contas](documentos/administrativo/prestacao-de-contas.md)
- [Políticas Internas](documentos/administrativo/politicas-internas.md)

</td>
<td>

**📣 Comunicação**
- [Identidade Visual](documentos/comunicacao/identidade-visual.md)
- [Comunicados Oficiais](documentos/comunicacao/comunicados-oficiais.md)

</td>
</tr>
</table>

> 📄 **Ficha técnica do projeto:** [CDA OS — Cluster Acadêmico](documentos/projetos/cda-os-cluster.md)

---

## 🗂 Estrutura do Repositório

```
CDA_Unifei/
│
├── 🔧 initramfs/              Boot imutável (OverlayFS + SquashFS)
├── 📡 scripts/mesh/            Rede mesh batman-adv
├── 🔨 scripts/build/           Build de rootfs e VM local
├── 🔍 scripts/audit/           Auditoria clean-room
├── ⚙️  systemd/                 Serviço batman-adv (watchdog + cgroups)
├── 📻 avahi/                   Descoberta mDNS (Jupyter + Dask)
├── 🖥️  cda-center/              Painel web CGI (dashboard + terminal)
├── 📦 dist/                    Artefatos de distribuição
├── 🧪 tests/                   Testes unitários + QEMU mesh lab
├── 📜 documentos/              Governança institucional DACDA
│   ├── estatuto/               Estatuto, Regimento, Ata
│   ├── planejamento/           Plano de Ação, Cronograma, KPIs
│   ├── administrativo/         Transparência, Contas, Políticas
│   ├── comunicacao/            Identidade Visual, Comunicados
│   ├── atas/                   Atas de assembleias
│   ├── financeiro/             Balancetes e relatórios
│   ├── projetos/               Fichas técnicas de projetos
│   └── assets/                 Materiais gráficos
└── 📋 tasks/                   TODO e lessons learned
```

---

## 🛠 Stack Tecnológica

<table>
<tr>
<td align="center"><strong>🐧 Kernel</strong><br><sub>OverlayFS • SquashFS<br>tmpfs • loop • switch_root</sub></td>
<td align="center"><strong>📡 Rede</strong><br><sub>batman-adv • iw<br>802.11s • iproute2</sub></td>
<td align="center"><strong>⚙️ Serviços</strong><br><sub>systemd • Avahi<br>mDNS • DNS-SD</sub></td>
<td align="center"><strong>🌐 Web</strong><br><sub>BusyBox httpd<br>CGI nativo • HTML5</sub></td>
<td align="center"><strong>🔬 Compute</strong><br><sub>Dask Distributed<br>Jupyter • Python 3</sub></td>
<td align="center"><strong>🧪 Testes</strong><br><sub>QEMU/KVM<br>ShellCheck • CI/CD</sub></td>
</tr>
</table>

---

## 🤝 Contribuir

1. Abra uma **issue** com contexto e proposta
2. Crie uma branch: `tipo/tema-curto`
3. Desenvolva e abra um **pull request**
4. Aguarde revisão colegiada

Leia [CONTRIBUTING.md](CONTRIBUTING.md) e nosso [Código de Conduta](CODE_OF_CONDUCT.md).

> ⚠️ **LGPD:** Nunca publique CPF, RG, endereço, telefone pessoal, e-mail pessoal, dados bancários ou assinaturas. Use `[DADO ANONIMIZADO]` quando necessário.

---

## ⚖️ Aviso Jurídico

Os documentos normativos são **minutas/modelos de trabalho**. Antes de protocolo ou uso oficial, o conteúdo deve ser validado pela UNIFEI e por profissional habilitado, conforme legislação brasileira vigente.

---

<p align="center">
  <sub>Desenvolvido com 🧠 pelo <strong>DACDA</strong> — Diretório Acadêmico de Ciência de Dados Aplicada • UNIFEI</sub>
</p>
