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
- [x] Integracao dacda-documentos — Governanca institucional em documentos/
- [x] CI/CD GitHub Actions — ShellCheck, testes, links Markdown, LGPD
- [x] Ficha tecnica CDA OS — documentos/projetos/cda-os-cluster.md
- [x] Teste: verificar que o terminal (exec.cgi) bloqueia comandos destrutivos
- [x] Teste: validar que todos os CGI scripts retornam JSON valido

## Pendente
- [ ] Teste E2E: rodar VM e verificar que CGI retorna JSON valido em ambiente real
- [ ] Adicionar mais servicos na whitelist de services.cgi conforme necessario
- [ ] Portal de documentacao GitHub Pages (Docsify ou MkDocs)
- [ ] Aba institucional no CDA Center (visualizador offline de documentos DACDA)
