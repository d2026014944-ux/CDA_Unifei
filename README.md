# CDA_Unifei

Infraestrutura base para um sistema acadêmico de Ciência de Dados com política clean room.

## Arquivos entregues

- `/home/runner/work/CDA_Unifei/CDA_Unifei/initramfs/init-overlay.sh`
  - Script de init para initramfs que monta OverlayFS a partir de camadas `.squashfs`.
  - Seleção automática RAM vs disco:
    - RAM quando `MemAvailable >= cda.ram_min_mib` **e** `MemAvailable >= 2x tamanho total das imagens`.
    - Disco quando RAM insuficiente.
    - Forçadores via kernel cmdline: `cda.force_ram=1` e `cda.force_disk=1`.

- `/home/runner/work/CDA_Unifei/CDA_Unifei/scripts/mesh/cda-mesh-setup.sh`
  - Configura `batman-adv` no kernel Linux para `wlan0` em modo mesh com SSID `CDA-Mesh`.

- `/home/runner/work/CDA_Unifei/CDA_Unifei/systemd/cda-batman-adv.service`
  - Unidade systemd (`oneshot`) para subir a malha no boot.

- `/home/runner/work/CDA_Unifei/CDA_Unifei/avahi/services/cda-data-services.service`
  - Registro dos serviços `_jupyter._tcp` (porta 8888) e `_dask._tcp` (porta 8786).

- `/home/runner/work/CDA_Unifei/CDA_Unifei/tests/qemu/mesh-lab.sh`
  - Infra como código para 4 VMs QEMU/KVM (8GB, 8GB, 8GB, 2GB), validação `tmpfs` vs disco e cenário de falha entre VM-1 e VM-3 com job Dask.

- `/home/runner/work/CDA_Unifei/CDA_Unifei/scripts/audit/woof-clean-room-audit.sh`
  - Auditoria de similaridade textual/fluxo contra diretório local do Woof-CE.

## Uso rápido

### 1) Initramfs
No bootloader, passe parâmetros opcionais:

- `cda.ram_min_mib=4096`
- `cda.force_ram=1` ou `cda.force_disk=1`
- `cda.live_dev=/dev/vda1` (opcional)
- `cda.squashdir=/caminho/com/squashfs` (opcional)

### 2) Mesh (systemd)

1. Instale o script em `/usr/local/sbin/cda-mesh-setup.sh`.
2. Instale a unidade em `/etc/systemd/system/cda-batman-adv.service`.
3. Ative:

```bash
sudo chmod +x /usr/local/sbin/cda-mesh-setup.sh
sudo systemctl daemon-reload
sudo systemctl enable --now cda-batman-adv.service
```

### 3) Avahi

Copie `avahi/services/cda-data-services.service` para `/etc/avahi/services/` e reinicie o `avahi-daemon`.

### 4) Testes QEMU

Defina variáveis e execute:

```bash
BASE_DISK=/path/base.qcow2 KERNEL_IMAGE=/path/bzImage INITRD_IMAGE=/path/initrd.img SSH_KEY=/path/id_ed25519 ./tests/qemu/mesh-lab.sh
```

### 5) Auditoria clean room

```bash
./scripts/audit/woof-clean-room-audit.sh /home/runner/work/CDA_Unifei/CDA_Unifei /path/to/woof-ce
```
