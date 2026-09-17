/**
 * CDA OS Control Center — Real Dashboard Engine
 *
 * Fetches REAL data from CGI endpoints running inside the Linux VM.
 * Falls back to a visible "OFFLINE" banner when CGI is unreachable
 * (e.g., running on the host machine outside the VM).
 */

(function () {
  'use strict';

  const API_BASE = '/cgi-bin';
  const POLL_INTERVAL = 3000;
  let isLive = false;

  // ─── Navigation ─────────────────────────────────────────────
  const navItems = document.querySelectorAll('.nav-item[data-page]');
  const sections = document.querySelectorAll('.page-section');

  function navigateTo(pageId) {
    sections.forEach(s => s.classList.remove('visible'));
    navItems.forEach(n => n.classList.remove('active'));
    const target = document.getElementById('page-' + pageId);
    const navTarget = document.querySelector(`.nav-item[data-page="${pageId}"]`);
    if (target) target.classList.add('visible');
    if (navTarget) navTarget.classList.add('active');
  }

  navItems.forEach(item => {
    item.addEventListener('click', (e) => {
      e.preventDefault();
      navigateTo(item.getAttribute('data-page'));
    });
  });

  // ─── Clock ──────────────────────────────────────────────────
  function updateClock() {
    const now = new Date();
    const time = now.toLocaleTimeString('pt-BR', { hour12: false });
    setText('topbar-clock', time);
    setText('dock-clock', time);
  }
  updateClock();
  setInterval(updateClock, 1000);

  // ─── API Fetch Helper ───────────────────────────────────────
  async function apiFetch(endpoint, params) {
    let url = API_BASE + '/' + endpoint;
    if (params) {
      const qs = new URLSearchParams(params).toString();
      url += '?' + qs;
    }
    try {
      const res = await fetch(url, { cache: 'no-store' });
      if (!res.ok) throw new Error(res.status);
      const data = await res.json();
      if (!isLive) {
        isLive = true;
        updateConnectionStatus(true);
      }
      return data;
    } catch (err) {
      if (isLive) {
        isLive = false;
        updateConnectionStatus(false);
      }
      return null;
    }
  }

  function updateConnectionStatus(online) {
    const chip = document.getElementById('sys-status');
    if (!chip) return;
    if (online) {
      chip.textContent = 'LIVE';
      chip.className = 'topbar-chip topbar-chip--live';
    } else {
      chip.textContent = 'OFFLINE';
      chip.className = 'topbar-chip topbar-chip--offline';
    }
  }

  // ─── System Info ────────────────────────────────────────────
  async function pollSysinfo() {
    const d = await apiFetch('sysinfo.cgi');
    if (!d) return;

    setText('chip-kernel', 'kernel ' + d.kernel);
    setText('chip-boot', 'boot ' + d.boot.mode);
    setText('chip-deployment', d.boot.deployment_name + ' @ ' + d.boot.deployment_version);
    setText('dock-mode', 'boot: ' + d.boot.mode);

    // Overview stats
    setText('ov-boot-mode', d.boot.mode.toUpperCase());
    setText('ov-deploy', d.boot.deployment_name + ' @ ' + d.boot.deployment_version);
    setText('ov-hostname', d.hostname);
    setText('ov-kernel', d.kernel);
    setText('ov-arch', d.arch);
    setText('ov-uptime', d.uptime);
    setText('ov-load', d.load['1m'] + ' / ' + d.load['5m'] + ' / ' + d.load['15m']);
    setText('ov-procs', String(d.processes));

    // RAM bars
    setBar('ov-ram', d.memory.pct);
    setBarColor('ov-ram-bar', d.memory.pct);
    setText('ov-ram-detail', d.memory.used_mib + ' / ' + d.memory.total_mib + ' MiB');
    setText('badge-ram', d.memory.pct + '%');

    // CPU
    setBar('ov-cpu', d.cpu.pct);
    setBarColor('ov-cpu-bar', d.cpu.pct);
    setText('ov-cpu-model', d.cpu.model || '—');
    setText('ov-cpu-cores', d.cpu.cores + ' cores');

    // Boot page
    setText('boot-mode', d.boot.mode);
    setText('boot-slot', d.boot.deployment_slot);
    setText('boot-name', d.boot.deployment_name);
    setText('boot-version', d.boot.deployment_version);
  }

  // ─── Processes ──────────────────────────────────────────────
  async function pollProcesses() {
    const procs = await apiFetch('processes.cgi');
    if (!procs) return;

    const tbody = document.getElementById('process-table-body');
    if (!tbody) return;

    // Sort by CPU% descending
    procs.sort((a, b) => b.cpu_pct - a.cpu_pct);

    tbody.innerHTML = '';
    procs.forEach(p => {
      const tr = document.createElement('tr');
      const stateClass = p.state === 'S' || p.state === 'R' ? 'tag--online' : p.state === 'Z' ? 'tag--danger' : 'tag--warn';
      const stateLabel = { R: 'Running', S: 'Sleeping', D: 'Disk', Z: 'Zombie', T: 'Stopped' }[p.state] || p.state;
      tr.innerHTML = `
        <td class="svc-port">${p.pid}</td>
        <td class="svc-name">${p.name}</td>
        <td class="svc-port">${p.cpu_pct}%</td>
        <td class="svc-port">${p.rss}</td>
        <td class="svc-port">${p.threads}</td>
        <td><span class="tag ${stateClass}">${stateLabel}</span></td>
        <td title="${p.cmdline}" style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:0.72rem;color:var(--text-muted)">${p.cmdline}</td>
      `;
      tbody.appendChild(tr);
    });

    setText('ov-procs', String(procs.length));
  }

  // ─── Network ────────────────────────────────────────────────
  async function pollNetwork() {
    const d = await apiFetch('network.cgi');
    if (!d) return;

    // Interfaces table
    const ifaceBody = document.getElementById('iface-table-body');
    if (ifaceBody) {
      ifaceBody.innerHTML = '';
      d.interfaces.forEach(iface => {
        const tr = document.createElement('tr');
        const stateTag = iface.state === 'up'
          ? '<span class="tag tag--online">UP</span>'
          : '<span class="tag tag--danger">DOWN</span>';
        tr.innerHTML = `
          <td class="svc-name">${iface.name}</td>
          <td class="svc-port">${iface.ip || '—'}</td>
          <td class="svc-port">${iface.mac}</td>
          <td>${stateTag}</td>
          <td class="svc-port">${iface.mtu}</td>
          <td class="svc-port">${iface.rx} / ${iface.tx}</td>
          <td class="svc-port">${iface.rx_errors} / ${iface.tx_errors}</td>
        `;
        ifaceBody.appendChild(tr);
      });
    }

    // Mesh info
    setText('mesh-gw', d.mesh.gw_mode || 'unknown');
    setText('dock-mesh', 'mesh: ' + d.mesh.active_peers + ' peers');
    setText('badge-nodes', String(d.mesh.active_peers));
    const meshStatus = document.getElementById('mesh-status');
    if (meshStatus) meshStatus.textContent = d.mesh.active_peers + ' Peers';

    // Mesh peers table
    const meshBody = document.getElementById('mesh-peers-body');
    if (meshBody && d.mesh.peers) {
      meshBody.innerHTML = '';
      d.mesh.peers.forEach(peer => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td class="svc-name">${peer.originator}</td>
          <td class="svc-port">${peer.last_seen}</td>
          <td class="svc-port">${peer.tq}/255</td>
          <td class="svc-port">${peer.nexthop}</td>
          <td class="svc-port">${peer.outif}</td>
        `;
        meshBody.appendChild(tr);
      });
    }

    // Routes
    const routesList = document.getElementById('routes-list');
    if (routesList && d.routes) {
      routesList.innerHTML = '';
      d.routes.forEach(r => {
        const div = document.createElement('div');
        div.className = 'audit-entry';
        div.innerHTML = `<span class="audit-msg" style="grid-column:1/-1">${r}</span>`;
        routesList.appendChild(div);
      });
    }
  }

  // ─── Storage ────────────────────────────────────────────────
  async function pollStorage() {
    const d = await apiFetch('storage.cgi');
    if (!d) return;

    // Mount table
    const mountBody = document.getElementById('mount-table-body');
    if (mountBody) {
      mountBody.innerHTML = '';
      d.mounts.forEach(m => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td class="svc-name">${m.device}</td>
          <td class="svc-port">${m.mountpoint}</td>
          <td class="svc-port">${m.fstype}</td>
          <td title="${m.options}" style="max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:0.72rem;color:var(--text-muted)">${m.options}</td>
        `;
        mountBody.appendChild(tr);
      });
    }

    // df table
    const dfBody = document.getElementById('df-table-body');
    if (dfBody) {
      dfBody.innerHTML = '';
      (d.disk_usage || []).forEach(df => {
        const tr = document.createElement('tr');
        const color = df.pct > 90 ? 'red' : df.pct > 70 ? 'amber' : 'green';
        tr.innerHTML = `
          <td class="svc-name">${df.filesystem}</td>
          <td class="svc-port">${df.mountpoint}</td>
          <td class="svc-port">${df.size}</td>
          <td class="svc-port">${df.used}</td>
          <td>
            <div class="bar-track" style="width:100px;display:inline-block;vertical-align:middle">
              <div class="bar-fill bar-fill--${color}" style="width:${df.pct}%"></div>
            </div>
            <span class="svc-port" style="margin-left:6px">${df.pct}%</span>
          </td>
        `;
        dfBody.appendChild(tr);
      });
    }

    // Overlay info
    if (d.overlay) {
      setText('overlay-layers', String(d.overlay.layers));
      setText('overlay-upper', d.overlay.upperdir);
      setText('overlay-upper-used', Math.round(d.overlay.upper_used_kb / 1024) + ' MiB');
    }

    // Block devices
    const blkBody = document.getElementById('blk-table-body');
    if (blkBody) {
      blkBody.innerHTML = '';
      (d.block_devices || []).forEach(blk => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td class="svc-name">/dev/${blk.name}</td>
          <td class="svc-port">${blk.size}</td>
          <td class="svc-port">${blk.ro ? 'RO' : 'RW'}</td>
          <td class="svc-port">${blk.removable ? 'Yes' : 'No'}</td>
        `;
        blkBody.appendChild(tr);
      });
    }
  }

  // ─── Logs ───────────────────────────────────────────────────
  async function pollLogs(source) {
    source = source || 'dmesg';
    const d = await apiFetch('logs.cgi', { source: source, lines: 100 });
    if (!d) return;

    const container = document.getElementById('log-output');
    if (!container) return;
    container.innerHTML = '';

    d.entries.forEach(entry => {
      const div = document.createElement('div');
      div.className = 'audit-entry';
      const levelClass = { err: 'audit-level--err', warn: 'audit-level--warn', info: 'audit-level--info', ok: 'audit-level--ok', audit: 'audit-level--info' }[entry.level] || 'audit-level--info';
      div.innerHTML = `
        <span class="audit-ts">${entry.ts || ''}</span>
        <span class="audit-level ${levelClass}">${entry.level}</span>
        <span class="audit-msg">${entry.msg}</span>
      `;
      container.appendChild(div);
    });

    // Auto-scroll to bottom
    container.scrollTop = container.scrollHeight;
  }

  // Log source selector
  document.querySelectorAll('[data-log-source]').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('[data-log-source]').forEach(b => b.classList.remove('btn--primary'));
      btn.classList.add('btn--primary');
      pollLogs(btn.getAttribute('data-log-source'));
    });
  });

  // ─── Terminal (Real) ────────────────────────────────────────
  const termInput = document.getElementById('term-input');
  const termPre = document.getElementById('terminal-pre');
  const termBody = document.getElementById('terminal-output');
  let cmdHistory = [];
  let historyIdx = -1;

  function appendTerminal(html) {
    if (!termPre) return;
    termPre.insertAdjacentHTML('beforeend', html);
    if (termBody) termBody.scrollTop = termBody.scrollHeight;
  }

  async function executeCommand(cmd) {
    if (!cmd.trim()) return;
    cmdHistory.unshift(cmd);
    historyIdx = -1;

    appendTerminal(`<span class="cmd-prompt">cda@localhost:~$ </span><span class="cmd-highlight">${escapeHtml(cmd)}</span>\n`);

    try {
      const res = await fetch(API_BASE + '/exec.cgi', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'cmd=' + encodeURIComponent(cmd),
      });
      const data = await res.json();

      if (data.stdout) {
        appendTerminal(`<span class="cmd-output">${escapeHtml(data.stdout)}</span>`);
      }
      if (data.stderr) {
        appendTerminal(`<span class="cmd-error">${escapeHtml(data.stderr)}</span>`);
      }
      if (data.rc !== 0) {
        appendTerminal(`<span class="cmd-warn">[exit code: ${data.rc}]</span>\n`);
      }
    } catch (err) {
      appendTerminal(`<span class="cmd-error">[fetch error: ${err.message}]</span>\n`);
    }
  }

  if (termInput) {
    termInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        const cmd = termInput.value;
        termInput.value = '';
        executeCommand(cmd);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        if (historyIdx < cmdHistory.length - 1) {
          historyIdx++;
          termInput.value = cmdHistory[historyIdx];
        }
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        if (historyIdx > 0) {
          historyIdx--;
          termInput.value = cmdHistory[historyIdx];
        } else {
          historyIdx = -1;
          termInput.value = '';
        }
      }
    });
  }

  // ─── Service Actions ────────────────────────────────────────
  document.querySelectorAll('[data-svc-action]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const action = btn.getAttribute('data-svc-action');
      const service = btn.getAttribute('data-svc-name');
      btn.disabled = true;
      btn.textContent = action + '...';
      const d = await apiFetch('services.cgi', { action: action, service: service });
      if (d) {
        btn.textContent = d.state || action;
        setTimeout(() => {
          btn.textContent = action.charAt(0).toUpperCase() + action.slice(1);
          btn.disabled = false;
        }, 1500);
      } else {
        btn.textContent = 'Error';
        btn.disabled = false;
      }
    });
  });

  // ─── Utilities ──────────────────────────────────────────────
  function setText(id, text) {
    const el = document.getElementById(id);
    if (el) el.textContent = text;
  }

  function setBar(prefix, pct) {
    const rounded = Math.round(pct);
    setText(prefix + '-pct', rounded + '%');
    const bar = document.getElementById(prefix + '-bar');
    if (bar) bar.style.width = rounded + '%';
  }

  function setBarColor(id, pct) {
    const el = document.getElementById(id);
    if (!el) return;
    const color = pct > 90 ? 'red' : pct > 75 ? 'amber' : pct > 50 ? 'cyan' : 'green';
    el.className = 'bar-fill bar-fill--' + color;
  }

  function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
  }

  // ─── Polling Engine ─────────────────────────────────────────
  async function pollAll() {
    await pollSysinfo();
    await pollProcesses();
    await pollNetwork();
    await pollStorage();
  }

  // Initial load
  pollAll();
  pollLogs('dmesg');

  // Live polling
  setInterval(pollAll, POLL_INTERVAL);

})();
