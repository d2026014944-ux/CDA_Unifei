# 🖥️ CDA OS — Cluster Acadêmico de Ciência de Dados

**Projeto técnico do DACDA/UNIFEI**

> Sistema operacional Linux imutável, distribuído em rede mesh ad-hoc, projetado para computação científica colaborativa em ambientes acadêmicos com recursos limitados.

---

## Dados do Projeto

| Campo | Valor |
|-------|-------|
| **Nome** | CDA OS (Ciência de Dados Aplicada — Operating System) |
| **Tipo** | Infraestrutura técnica — Software livre |
| **Responsável** | DACDA — Diretório Acadêmico de Ciência de Dados Aplicada |
| **Instituição** | Universidade Federal de Itajubá (UNIFEI) |
| **Repositório** | [github.com/d2026014944-ux/CDA_Unifei](https://github.com/d2026014944-ux/CDA_Unifei) |
| **Status** | Em desenvolvimento ativo |

---

## Objetivo

Construir uma plataforma de computação distribuída acessível e transparente para o curso de Ciência de Dados Aplicada, permitindo que estudantes montem **clusters de processamento ad-hoc** usando notebooks e desktops acadêmicos comuns — sem necessidade de infraestrutura de datacenter, servidores dedicados ou conexão com a internet.

---

## Arquitetura Técnica

### Os 5 Pilares

```
┌─────────────────────────────────────────────────────────────────┐
│                        CDA OS Architecture                      │
├─────────────┬─────────────┬────────────┬──────────┬─────────────┤
│  Boot       │  Rede       │ Descoberta │ Painel   │ Qualidade   │
│  Imutável   │  Mesh L2    │ Zero-Conf  │ Web CGI  │ & Testes    │
├─────────────┼─────────────┼────────────┼──────────┼─────────────┤
│ SquashFS +  │ batman-adv  │ Avahi      │ BusyBox  │ QEMU Lab    │
│ OverlayFS   │ 802.11s     │ mDNS       │ httpd    │ Clean Room  │
│ switch_root │ 10.42.0/24  │ DNS-SD     │ 7 CGIs   │ 4 VMs E2E   │
└─────────────┴─────────────┴────────────┴──────────┴─────────────┘
```

### 1. Boot Imutável por Camadas

O sistema de arquivos raiz é construído por sobreposição de camadas SquashFS compactadas (XZ), montadas em modo somente-leitura via OverlayFS. Uma camada de escrita volátil em `tmpfs` permite modificações temporárias que são descartadas a cada reboot, garantindo **estado limpo a cada inicialização**.

**Política de Boot Dual:**

| Condição | Modo | Comportamento |
|----------|------|---------------|
| `MemAvailable >= cda.ram_min_mib` **E** `MemAvailable >= 2× total SquashFS` | `ram` | Imagens copiadas para tmpfs — desempenho máximo |
| RAM insuficiente | `disk` | Montagem direta da mídia — funciona com 2 GB |
| `cda.force_ram=1` | `ram` | Override forçado |
| `cda.force_disk=1` | `disk` | Override forçado |

**Parâmetros de Kernel (cmdline):**

| Parâmetro | Descrição | Padrão |
|-----------|-----------|--------|
| `cda.ram_min_mib` | Piso mínimo de RAM em MiB | `4096` |
| `cda.force_ram` | Força modo RAM | `0` |
| `cda.force_disk` | Força modo disco | `0` |
| `cda.deployment_dir` | Base dos slots de deployment | — |
| `cda.deployment` | Nome do slot ativo | `current` |
| `cda.squashdir` | Diretório de fallback com `.squashfs` | — |
| `cda.live_dev` | Dispositivo de boot (pendrive, partição) | — |

**Gerenciamento de Deployments:**

Cada slot contém um `deployment.conf` com `DEPLOYMENT_NAME`, `DEPLOYMENT_VERSION`, `DEPLOYMENT_IMAGE_DIR` e `DEPLOYMENT_SLOT`. Um symlink `current` aponta para o slot ativo, permitindo rollback atômico.

### 2. Rede Mesh Ad-Hoc (batman-adv)

Topologia L2 auto-configurável via Wi-Fi mesh IEEE 802.11s:

| Parâmetro | Valor |
|-----------|-------|
| **Protocolo** | B.A.T.M.A.N. Advanced (kernel module) |
| **SSID** | `CDA-Mesh` |
| **Frequência** | 2412 MHz (Canal 1, 2.4 GHz) |
| **Sub-rede** | `10.42.0.0/24` |
| **Faixa de IPs** | `10.42.0.20` — `10.42.0.219` |
| **Atribuição** | Determinística: `SHA-256(machine-id) % 200 + 20` |
| **Interface virtual** | `bat0` |
| **Fallback IP** | `10.42.0.250` (sem machine-id) |

**Tuning para Dask (computação distribuída):**

| Parâmetro batctl | Valor | Efeito |
|-----------------|-------|--------|
| `gw_mode` | `client` | Nó como cliente de gateway |
| `multicast_fanout` | `8` | Retransmissão para até 8 vizinhos |
| `network_coding` | `1` | Combina pacotes para duplicar throughput |
| `orig_interval` | `500` ms | Convergência topológica 2× mais rápida |

**Resiliência:**

O serviço systemd (`cda-batman-adv.service`) opera como `oneshot` com `RemainAfterExit=yes`, watchdog de 30s, restart automático em falha (5s de backoff) e isolamento em `cda-compute.slice` via cgroups.

### 3. Descoberta Zero-Conf (Avahi)

Publicação automática via mDNS/DNS-SD dos serviços do cluster:

| Serviço | Tipo DNS-SD | Porta | TXT Records |
|---------|-------------|-------|-------------|
| Jupyter Notebook | `_jupyter._tcp` | 8888 | `path=/`, `stack=jupyter` |
| Dask Scheduler | `_dask._tcp` | 8786 | `role=scheduler`, `stack=dask` |

### 4. CDA OS Control Center

Painel web de monitoramento em tempo real servido pelo BusyBox httpd na porta 8080:

| CGI Script | Fonte de Dados | Funcionalidade |
|------------|---------------|----------------|
| `sysinfo.cgi` | `/proc/meminfo`, `/proc/cpuinfo`, `/proc/loadavg`, `/run/cda/` | Visão geral do sistema |
| `processes.cgi` | `/proc/[pid]/stat`, `/proc/[pid]/status` | Lista de processos com CPU/RAM |
| `network.cgi` | `/sys/class/net/`, `batctl`, `ip route` | Interfaces, peers mesh, rotas, DNS |
| `storage.cgi` | `/proc/mounts`, `df`, `/sys/block/` | Montagens, uso de disco, overlay |
| `logs.cgi` | `dmesg`, `syslog`, `journalctl`, `/run/cda/` | Logs do sistema e boot |
| `services.cgi` | `systemctl` | Status e controle (start/stop/restart) |
| `exec.cgi` | `sh -c` com timeout de 10s | Terminal web com blocklist de segurança |

**Princípios de Telemetria:**

1. **Zero mocks** — Todos os dados originam de `/proc`, `/sys`, `batctl` ou `systemctl`
2. **Frontend fetch-first** — JavaScript 100% assíncrono, polling a cada 3 segundos
3. **Blocklist de segurança** — Terminal web bloqueia: `rm -rf`, `mkfs`, `dd if=`, `shutdown`, `reboot`, `halt`, `poweroff`, `init 0`, `init 6`
4. **Whitelist de serviços** — Apenas `cda-batman-adv` e `avahi-daemon` podem ser controlados

### 5. Laboratório de Testes QEMU

Suíte E2E automatizada com 4 VMs interconectadas por socket multicast UDP:

| VM | RAM | Modo de Boot Esperado | Função |
|----|-----|-----------------------|--------|
| VM-1 | 8 GB | `ram` | Nó de computação + cliente Dask |
| VM-2 | 8 GB | `ram` | Nó intermediário na malha |
| VM-3 | 8 GB | `ram` | Dask scheduler |
| VM-4 | 2 GB | `disk` | Nó básico/legado |

**Teste de Failover:**

Injeta bloqueio L2 (`ebtables`) e L3 (`iptables`) entre VM-1 e VM-3, validando que o cluster Dask continua operando via roteamento dinâmico do batman-adv através de nós intermediários. Resultado esperado: `42` (lambda x: x * 2, 21).

---

## Stack Tecnológica

| Camada | Tecnologias |
|--------|-------------|
| **Kernel** | Linux (OverlayFS, SquashFS, tmpfs, loop, switch_root) |
| **Rede** | batman-adv, iw, iproute2, 802.11s |
| **Serviços** | systemd, Avahi (mDNS/DNS-SD) |
| **Servidor HTTP** | BusyBox httpd (CGI nativo) |
| **Frontend** | HTML5, CSS3, JavaScript vanilla |
| **Computação** | Dask Distributed, Jupyter, Python 3 |
| **Virtualização** | QEMU/KVM (qemu-system-x86_64) |
| **Build** | BusyBox, mksquashfs (XZ), cpio, unmkinitramfs |
| **Shell** | POSIX sh (nenhum bashismo) |

---

## Requisitos de Hardware

### Nó do Cluster

| Perfil | RAM Mínima | Modo de Boot | Requisito de Rede |
|--------|-----------|-------------|-------------------|
| **Computação (alto desempenho)** | 8 GB | `ram` | Wi-Fi com suporte a 802.11s mesh point |
| **Básico / Legado** | 2 GB | `disk` | Wi-Fi com suporte a 802.11s mesh point |

### Host de Desenvolvimento/Testes

| Recurso | Recomendação |
|---------|-------------|
| **RAM** | ≥ 32 GB (para rodar 4 VMs QEMU simultaneamente: 8+8+8+2 = 26 GB) |
| **CPU** | ≥ 8 núcleos lógicos (4 VMs × 2 vCPUs) |
| **Disco** | SSD com espaço para imagens QCOW2 |

---

## Portas de Rede

| Porta | Serviço | Protocolo |
|-------|---------|-----------|
| 8080 | CDA OS Control Center (httpd) | TCP |
| 8786 | Dask Scheduler | TCP |
| 8888 | Jupyter Notebook | TCP |
| 5353 | Avahi mDNS | UDP |
| 22 | SSH (gerenciamento de testes) | TCP |

---

## Política de Qualidade

- **TDD obrigatório** — Testes antes do código (Akita Way)
- **Auditoria clean-room** — Verificação de similaridade contra Woof-CE (zero copy-paste)
- **Anti-Vibe Coding** — Arquitetura humana pré-estabelecida; IA como assistente, não oráculo
- **Isolamento de cgroups** — Processos de rede em `cda-compute.slice`
- **Rollback atômico** — Via slots de deployment com `deployment.conf`

---

## Cronograma e Conexão Institucional

Este projeto integra o **Eixo 4 (Integração Acadêmica)** e o **Eixo 5 (Eventos)** do [Plano de Ação do DACDA](../planejamento/plano-de-acao.md):

| Fase | Entregáveis | Conexão com o Plano de Ação |
|------|-------------|----------------------------|
| **Fase 1** | Boot imutável + rede mesh funcional | Eixo 4: Articulação com docentes e laboratórios |
| **Fase 2** | Cluster Dask/Jupyter operacional | Eixo 5: Evento-piloto com workshop de computação distribuída |
| **Fase 3** | CDA Center + testes E2E automatizados | Eixo 6: Demonstração de transparência técnica |
| **Fase 4** | Distribuição empacotada para uso real | Eixo 7: Documentação de transição para próximas gestões |

---

## Referências Técnicas

- [B.A.T.M.A.N. Advanced](https://www.open-mesh.org/projects/batman-adv/wiki)
- [OverlayFS — Kernel Documentation](https://docs.kernel.org/filesystems/overlayfs.html)
- [Dask Distributed](https://distributed.dask.org/)
- [Avahi — DNS Service Discovery](https://avahi.org/)
- [BusyBox](https://busybox.net/)
