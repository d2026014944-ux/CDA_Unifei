# CLAUDE.MD

Spec viva do projeto CDA_Unifei.

## 1) Contexto do Dominio

Projeto de infraestrutura para ambiente academico de Ciencia de Dados com:
- boot imutavel por camadas SquashFS + OverlayFS
- rede mesh com batman-adv
- descoberta de servicos por Avahi
- laboratorio de validacao com QEMU/KVM
- auditoria clean room para conformidade

## 2) Stack Tecnologica

- Shell POSIX (`/bin/sh`) para automacao e bootstrap
- Linux kernel features: OverlayFS, tmpfs, SquashFS, switch_root
- Rede: `iw`, `ip`, `batman-adv`
- Service management: `systemd`
- Service discovery: `avahi-daemon`
- Virtualizacao/teste: `qemu-system-x86_64`, `qemu-img`
- Validacao distribuida: `dask.distributed` (cliente/scheduler no laboratorio)

## 3) Estrutura de Diretorios

- `initramfs/`
  - `init-overlay.sh`: init do boot live com politica RAM x disco.
- `boot/deployments/`
  - `base/`: slot inicial com deployment.conf e dir de imagens.
- `scripts/mesh/`
  - `cda-mesh-setup.sh`: sobe malha L2 e interface batman.
- `systemd/`
  - `cda-batman-adv.service`: unidade para aplicar setup de mesh no boot.
- `avahi/services/`
  - `cda-data-services.service`: publica Jupyter e Dask via mDNS.
- `tests/qemu/`
  - `mesh-lab.sh`: homologacao fim-a-fim com 4 VMs.
- `scripts/audit/`
  - `woof-clean-room-audit.sh`: verificacao de similaridade clean room.
- `cda-center/`
  - `index.html`: Dashboard CDA OS Control Center (HTML + CSS).
  - `style.css`: Design System "CDA Linux Pro" (dark terminal theme).
  - `dashboard.js`: Frontend que consome dados reais via CGI (polling 3s).
  - `cgi-bin/sysinfo.cgi`: Info do sistema (/proc/meminfo, cpuinfo, stat, loadavg).
  - `cgi-bin/processes.cgi`: Lista de processos (/proc/[pid]/stat, status, cmdline).
  - `cgi-bin/network.cgi`: Interfaces, batman-adv peers, rotas (/sys/class/net, batctl).
  - `cgi-bin/storage.cgi`: Montagens, df, overlay, block devices (/proc/mounts, /sys/block).
  - `cgi-bin/logs.cgi`: Logs do sistema (dmesg, syslog, journalctl, /run/cda).
  - `cgi-bin/services.cgi`: Controle de servicos systemd (whitelist).
  - `cgi-bin/exec.cgi`: Terminal real com execucao de comandos (blocklist de seguranca).

## 4) Variaveis e Parametros

### 4.1 Kernel cmdline (initramfs)

- `cda.ram_min_mib` (default: `4096`)
- `cda.force_ram=1`
- `cda.force_disk=1`
- `cda.live_dev=/dev/...`
- `cda.squashdir=/path`
- `cda.squash_subdir=...`
- `cda.deployment_dir=/path`
- `cda.deployment=slot-ou-current`
- `root=/dev/...` (fallback de origem)

### 4.2 Ambiente (mesh)

- `MESH_IFACE` (default: `wlan0`)
- `MESH_ID` (default: `CDA-Mesh`)
- `BAT_IFACE` (default: `bat0`)
- `MESH_CHANNEL` (default: `2412`)
- `IP_OCTET_RANGE_START` (default: `20`)
- `IP_OCTET_RANGE_SIZE` (default: `200`)

### 4.3 Ambiente (tests/qemu)

- `WORKDIR` (default: `/tmp/cda-mesh-lab`)
- `BASE_DISK` (obrigatoria)
- `KERNEL_IMAGE` (obrigatoria)
- `INITRD_IMAGE` (obrigatoria)
- `SSH_USER` (default: `student`)
- `SSH_KEY` (obrigatoria)

## 5) Responsabilidades por Componente

- `init-overlay.sh`
  - montar FS basicos (`proc`, `sys`, `dev`)
  - resolver deployment descriptors e selecionar slot de boot
  - localizar origem dos `.squashfs`
  - decidir modo de boot (`ram`/`disk`) com politica explicita
  - montar lower layers + overlay rw e transferir controle via `switch_root`
  - persistir metadata do deployment selecionado em `/run/cda/`

- `cda-mesh-setup.sh`
  - garantir dependencias de rede
  - configurar interface mesh 802.11s
  - anexar ao `bat0`
  - atribuir IP deterministico em `10.42.0.0/24`

- `mesh-lab.sh`
  - subir 4 VMs com diferentes perfis de RAM
  - validar politica de boot (RAM nas VMs 1-3, disco na VM4)
  - validar resiliencia basica da malha com scheduler Dask

- `cda-data-services.service`
  - anunciar servicos de dados em rede local via mDNS

## 6) Contratos e Regras de Negocio

1. Politica de boot:
- modo `ram` somente quando:
  - `MemAvailable >= cda.ram_min_mib`
  - e `MemAvailable >= 2x total_squashfs`
- `cda.force_ram=1` e `cda.force_disk=1` sobrescrevem decisao automatica.

2. Contrato de rede mesh:
- interface de malha deve ficar funcional em `BAT_IFACE`
- endereco IPv4 deve ser deterministico por `machine-id` no range configurado.

3. Contrato de deployment:
- `cda.deployment_dir` aponta para o layout de slots.
- `cda.deployment` seleciona o slot corrente; padrao `current`.
- cada slot deve expor `deployment.conf` e um subdir de imagens `.squashfs`.

4. Contrato de teste de integracao:
- alteracoes na politica de boot devem refletir em `mesh-lab.sh`
- alteracoes na configuracao de rede devem manter validacao de conectividade Dask.

## 7) Decisoes Arquiteturais Registradas

- Monorepo unico para visibilidade transversal de boot, rede, servicos e testes.
- Scripts em shell para reduzir dependencia de runtime no ambiente base.
- Teste de integracao E2E com QEMU como gate para regressao operacional.
- O primeiro degrau de rollout passa por deployment descriptors nomeados antes de qualquer migracao para OSTree.

## 8) Politica de Desenvolvimento (Akita Way)

- Primeiro testes, depois implementacao.
- Mudou arquitetura/contrato: atualizar este arquivo antes de seguir.
- Nenhuma sugestao de IA entra sem validacao tecnica humana.

## 9) Checklist de Entrega de Feature

- [ ] Contexto e criterio de aceite definidos
- [ ] Testes (unitarios/integracao) escritos antes da implementacao
- [ ] Implementacao minima para passar nos testes
- [ ] Contratos entre componentes validados
- [ ] Este `CLAUDE.MD` atualizado
- [ ] Risco principal e rollback definidos

## 10) Riscos Principais e Mitigacoes

- Risco: regressao no boot live por mudanca de parametros de cmdline.
  - Mitigacao: cobertura de teste no laboratorio QEMU para cenarios RAM/disco.

- Risco: quebra de conectividade mesh por alteracao de iface/canal.
  - Mitigacao: teste de integracao de conectividade + verificacao de bat0.

- Risco: dependencias externas ausentes no host (qemu, iw, batman-adv).
  - Mitigacao: preflight checks e documentacao de requisitos por ambiente.

- Risco: contrato de deployment quebrar o boot se slot/current nao existir.
  - Mitigacao: fallback para `cda.squashdir` e teste unitario de selecao de deployment.

## 11) Rollback Padrao

- Reverter commit da feature.
- Restaurar parametros anteriores de cmdline e unit files.
- Reexecutar `tests/qemu/mesh-lab.sh` para confirmar retorno ao baseline.
