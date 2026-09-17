# Lessons Learned

## 2026-04-12: Dashboard mocado → Dashboard real

### Erro
Criado um dashboard com dados hardcoded (`systemState = { ramUsed: 5079 }`).
O usuario corretamente rejeitou: "Nao quero nada mocado, quero um sistema real."

### Root Cause
Pressa para entregar algo visualmente bonito sem questionar se era funcional.
Violacao do principio Feynman: "Se voce nao consegue ler dados reais do kernel,
voce nao tem um dashboard — voce tem um protetor de tela."

### Regra Permanente
1. **NUNCA** criar valores hardcoded em dashboards de sistema.
   Dados DEVEM vir de fontes reais: `/proc/`, `/sys/`, `batctl`, `systemctl`.
2. **CGI scripts** sao a ponte natural entre browser e Linux kernel em ambientes busybox.
3. **Frontend fetch-first**: o JS deve ser 100% fetch-based com fallback OFFLINE visivel.
4. Se o dado nao vem de uma syscall ou arquivo do kernel, ele NAO EXISTE no dashboard.

### Correcao
- 7 CGI shell scripts lendo de fontes reais do kernel
- dashboard.js 100% fetch-based com polling 3s
- Terminal real via exec.cgi
- run-local-os-vm.sh reduzido de 902 → 156 linhas
