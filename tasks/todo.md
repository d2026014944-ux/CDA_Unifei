# CDA OS Control Center — TODO

## Concluido
- [x] CGI sysinfo.cgi — /proc/meminfo, cpuinfo, stat, loadavg, /run/cda
- [x] CGI processes.cgi — /proc/[pid]/stat, status, cmdline
- [x] CGI network.cgi — /sys/class/net, batctl, ip route, resolv.conf
- [x] CGI storage.cgi — /proc/mounts, df, /sys/block, overlay info
- [x] CGI logs.cgi — dmesg, syslog, journalctl, boot metadata
- [x] CGI services.cgi — systemctl start/stop/restart com whitelist
- [x] CGI exec.cgi — Terminal real com blocklist de seguranca
- [x] Frontend index.html — 8 paginas de ferramentas reais
- [x] Frontend dashboard.js — 100% fetch-based, polling 3s
- [x] Frontend style.css — Design System CDA Linux Pro
- [x] Integracao run-local-os-vm.sh — cda-center copiado para rootfs/www
- [x] Backend cda-batman-adv.service — Watchdog + Restart + CGroups
- [x] Backend cda-mesh-setup.sh — Tuning batman-adv
- [x] CLAUDE.MD atualizado com nova estrutura
- [x] tasks/lessons.md criado

## Pendente
- [ ] Teste E2E: rodar VM e verificar que CGI retorna JSON valido
- [ ] Teste: verificar que o terminal (exec.cgi) bloqueia comandos destrutivos
- [ ] Adicionar mais servicos na whitelist de services.cgi conforme necessario
