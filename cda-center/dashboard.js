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

  // ─── Telemetry Provider (Live CGI or Showcase Preview) ───────
  const DEMO_DATA = {
    'sysinfo.cgi': () => ({
      hostname: 'cda-node-01',
      kernel: '6.6.137-cda-l2mesh',
      arch: 'x86_64',
      uptime: '1d 08h 42m',
      uptime_sec: 117720,
      load: { '1m': (0.35 + Math.random() * 0.08).toFixed(2), '5m': '0.42', '15m': '0.38' },
      memory: {
        total_mib: 8192,
        used_mib: Math.floor(3400 + Math.random() * 120),
        available_mib: 4792,
        buffers_mib: 320,
        cached_mib: 1840,
        pct: Math.floor(41 + Math.random() * 3)
      },
      swap: { total_kb: 2097152, free_kb: 2097152 },
      cpu: { model: 'AMD Ryzen 7 / Intel Core i7 (4 vCPU)', cores: 4, pct: Math.floor(18 + Math.random() * 10) },
      boot: { mode: 'ram', deployment_name: 'cda-academic', deployment_version: '2026.09', deployment_slot: 'current' },
      processes: 68
    }),
    'processes.cgi': () => [
      { pid: 1420, name: 'dask-worker', state: 'R', ppid: 1, uid: 1000, threads: 8, cpu_pct: 14, mem_pct: 12, rss: '980M', rss_kb: 1003520, cmdline: 'python3 -m distributed.cli.dask_worker tcp://10.42.0.25:8786' },
      { pid: 1380, name: 'jupyter-lab', state: 'S', ppid: 1, uid: 1000, threads: 4, cpu_pct: 4, mem_pct: 6, rss: '490M', rss_kb: 501760, cmdline: 'jupyter-lab --ip=0.0.0.0 --port=8888 --no-browser' },
      { pid: 980, name: 'batman-adv', state: 'S', ppid: 2, uid: 0, threads: 2, cpu_pct: 2, mem_pct: 1, rss: '45M', rss_kb: 46080, cmdline: '[kworker/batadv]' },
      { pid: 1120, name: 'avahi-daemon', state: 'S', ppid: 1, uid: 104, threads: 1, cpu_pct: 0, mem_pct: 0, rss: '12M', rss_kb: 12288, cmdline: 'avahi-daemon: running [cda-node-01.local]' },
      { pid: 1050, name: 'httpd', state: 'S', ppid: 1, uid: 0, threads: 1, cpu_pct: 1, mem_pct: 0, rss: '8M', rss_kb: 8192, cmdline: '/bin/httpd -f -p 8080 -h /www' },
      { pid: 1, name: 'init', state: 'S', ppid: 0, uid: 0, threads: 1, cpu_pct: 0, mem_pct: 0, rss: '4M', rss_kb: 4096, cmdline: '/sbin/init' }
    ],
    'network.cgi': () => ({
      interfaces: [
        { name: 'bat0', state: 'up', mac: 'fe:42:0a:2a:00:19', mtu: 1500, ip: '10.42.0.25/24', rx: '48.2M', tx: '36.8M', rx_bytes: 50541363, tx_bytes: 38587596, rx_packets: 41200, tx_packets: 32800, rx_errors: 0, tx_errors: 0 },
        { name: 'wlan0', state: 'up', mac: 'dc:a6:32:11:42:99', mtu: 1532, ip: '', rx: '52.1M', tx: '41.0M', rx_bytes: 54630809, tx_bytes: 42991616, rx_packets: 44500, tx_packets: 36100, rx_errors: 0, tx_errors: 0 },
        { name: 'lo', state: 'up', mac: '00:00:00:00:00:00', mtu: 65536, ip: '127.0.0.1/8', rx: '12.4M', tx: '12.4M', rx_bytes: 13002342, tx_bytes: 13002342, rx_packets: 9800, tx_packets: 9800, rx_errors: 0, tx_errors: 0 }
      ],
      mesh: {
        bat_iface: 'bat0',
        gw_mode: 'client',
        active_peers: 3,
        peers: [
          { originator: 'dc:a6:32:11:42:01', last_seen: '0.4s', tq: 255, nexthop: 'dc:a6:32:11:42:01', outif: 'wlan0' },
          { originator: 'dc:a6:32:11:42:02', last_seen: '0.8s', tq: 242, nexthop: 'dc:a6:32:11:42:02', outif: 'wlan0' },
          { originator: 'dc:a6:32:11:42:03', last_seen: '1.2s', tq: 228, nexthop: 'dc:a6:32:11:42:01', outif: 'wlan0' }
        ]
      },
      routes: [
        '10.42.0.0/24 dev bat0 proto kernel scope link src 10.42.0.25',
        'default via 10.42.0.1 dev bat0 metric 100'
      ],
      dns: ['10.42.0.1', '1.1.1.1']
    }),
    'storage.cgi': () => ({
      mounts: [
        { device: 'overlay', mountpoint: '/', fstype: 'overlay', options: 'rw,relatime,lowerdir=/run/cda/lower/0,upperdir=/run/cda/rw/upper,workdir=/run/cda/rw/work' },
        { device: 'tmpfs', mountpoint: '/run', fstype: 'tmpfs', options: 'rw,nosuid,nodev,mode=755' },
        { device: '/dev/sda1', mountpoint: '/mnt/cda-data', fstype: 'ext4', options: 'rw,relatime' }
      ],
      disk_usage: [
        { filesystem: 'overlay', mountpoint: '/', size: '4.0G', used: '520M', size_kb: 4194304, used_kb: 532480, avail_kb: 3661824, pct: 13 },
        { filesystem: 'tmpfs', mountpoint: '/run/cda/images', size: '2.4G', used: '1.8G', size_kb: 2516582, used_kb: 1887436, avail_kb: 629146, pct: 75 },
        { filesystem: '/dev/sda1', mountpoint: '/mnt/cda-data', size: '120G', used: '24G', size_kb: 125829120, used_kb: 25165824, avail_kb: 100663296, pct: 20 }
      ],
      overlay: {
        lowerdir: '/run/cda/lower/0',
        upperdir: '/run/cda/rw/upper',
        workdir: '/run/cda/rw/work',
        layers: 1,
        upper_used_kb: 532480
      },
      block_devices: [
        { name: 'sda', size: '128G', size_bytes: 137438953472, ro: 0, removable: 0 },
        { name: 'sdb', size: '32G', size_bytes: 34359738368, ro: 0, removable: 1 }
      ]
    }),
    'logs.cgi': () => ({
      source: 'dmesg',
      entries: [
        { ts: '0.000000', level: 'info', msg: 'Linux version 6.6.137-cda-l2mesh (gcc 13.2.0) #1 SMP PREEMPT_DYNAMIC' },
        { ts: '0.124800', level: 'info', msg: 'cda-init: MemAvailable=4792 MiB >= 4096 MiB threshold -> RAM BOOT ACTIVATED' },
        { ts: '0.245100', level: 'info', msg: 'overlayfs: mounted lowerdir=/run/cda/lower/0 with upperdir in tmpfs' },
        { ts: '1.450200', level: 'info', msg: 'batman-adv: bat0: Adding interface: wlan0 (802.11s mode mp)' },
        { ts: '1.820100', level: 'info', msg: 'batman-adv: bat0: Interface activated: wlan0 with network coding enabled' },
        { ts: '2.102300', level: 'info', msg: 'avahi-daemon: Service "cda-node-01 CDA Services" (_jupyter._tcp / _dask._tcp) registered.' },
        { ts: '2.400100', level: 'info', msg: 'cda-httpd: listening on 0.0.0.0:8080 (CDA OS Control Center ready)' }
      ]
    }),
    'services.cgi': () => ({
      services: [
        { unit: 'cda-batman-adv.service', load: 'loaded', active: 'active', sub: 'running', desc: 'Rede Mesh L2 batman-adv (Watchdog 30s)' },
        { unit: 'avahi-daemon.service', load: 'loaded', active: 'active', sub: 'running', desc: 'Descoberta Zero-Conf mDNS/DNS-SD' },
        { unit: 'dask-worker.service', load: 'loaded', active: 'active', sub: 'running', desc: 'Dask Distributed Compute Node' },
        { unit: 'jupyter-lab.service', load: 'loaded', active: 'active', sub: 'running', desc: 'Ambiente Analítico Interativo Jupyter' },
        { unit: 'httpd.service', load: 'loaded', active: 'active', sub: 'running', desc: 'BusyBox HTTP Server (porta 8080)' }
      ]
    })
  };

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
      isLive = true;
      updateConnectionStatus('live');
      return data;
    } catch (err) {
      if (DEMO_DATA[endpoint]) {
        updateConnectionStatus('preview');
        return DEMO_DATA[endpoint]();
      }
      updateConnectionStatus('offline');
      return null;
    }
  }

  function updateConnectionStatus(mode) {
    const chip = document.getElementById('sys-status');
    if (!chip) return;
    if (mode === 'live') {
      chip.textContent = 'LIVE';
      chip.className = 'topbar-chip topbar-chip--live';
    } else if (mode === 'preview') {
      chip.textContent = 'DEMO PREVIEW';
      chip.className = 'topbar-chip topbar-chip--preview';
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
      const trimmed = cmd.trim();
      if (trimmed.match(/rm\s+-rf|mkfs|dd\s+if=|shutdown|reboot|halt|poweroff|init\s+[06]/)) {
        appendTerminal('<span class="cmd-error">blocked: destructive command not allowed from dashboard</span>\n<span class="cmd-warn">[exit code: 126]</span>\n');
      } else if (trimmed === 'uname -a') {
        appendTerminal('<span class="cmd-output">Linux cda-node-01 6.6.137-cda-l2mesh #1 SMP PREEMPT_DYNAMIC x86_64 GNU/Linux\n</span>');
      } else if (trimmed === 'hostname') {
        appendTerminal('<span class="cmd-output">cda-node-01\n</span>');
      } else if (trimmed.includes('batctl')) {
        appendTerminal('<span class="cmd-output">[B.A.T.M.A.N. adv 2024.1, meshif bat0]\nOriginator        last-seen (#/255) Nexthop           [outgoingIF]\ndc:a6:32:11:42:01    0.340s   (255) dc:a6:32:11:42:01 [     wlan0]\ndc:a6:32:11:42:02    0.820s   (242) dc:a6:32:11:42:02 [     wlan0]\ndc:a6:32:11:42:03    1.150s   (228) dc:a6:32:11:42:01 [     wlan0]\n</span>');
      } else if (trimmed === 'df -h') {
        appendTerminal('<span class="cmd-output">Filesystem      Size  Used Avail Use% Mounted on\noverlay         4.0G  520M  3.5G  13% /\ntmpfs           2.4G  1.8G  615M  75% /run/cda/images\n/dev/sda1       120G   24G   96G  20% /mnt/cda-data\n</span>');
      } else if (trimmed.includes('cat /proc/meminfo')) {
        appendTerminal('<span class="cmd-output">MemTotal:        8388608 kB\nMemFree:         2457600 kB\nMemAvailable:    4906800 kB\nBuffers:          327680 kB\nCached:          1884160 kB\n</span>');
      } else if (trimmed === 'clear') {
        termPre.innerHTML = '';
      } else if (trimmed === 'help') {
        appendTerminal('<span class="cmd-output">Comandos de demonstração disponíveis no modo Preview:\n  uname -a, hostname, batctl originators, df -h, cat /proc/meminfo, clear, help\n  Tente também um comando proibido (ex: rm -rf /) para ver a blocklist em ação.\n</span>');
      } else {
        appendTerminal(`<span class="cmd-output">[demo preview] comando '${escapeHtml(trimmed)}' executado (rc: 0)\n</span>`);
      }
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
