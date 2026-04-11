#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ROOTFS_DIR="$DIST_DIR/cda-rootfs"
INITRAMFS_DIR="$DIST_DIR/initramfs"

rm -rf "$ROOTFS_DIR" "$INITRAMFS_DIR"
mkdir -p "$ROOTFS_DIR" "$INITRAMFS_DIR"

# Layout base de filesystem para imagem raiz.
mkdir -p \
  "$ROOTFS_DIR"/boot \
  "$ROOTFS_DIR"/bin \
  "$ROOTFS_DIR"/sbin \
  "$ROOTFS_DIR"/etc/systemd/system \
  "$ROOTFS_DIR"/etc/avahi/services \
  "$ROOTFS_DIR"/usr/local/sbin \
  "$ROOTFS_DIR"/usr/share/cda \
  "$ROOTFS_DIR"/proc \
  "$ROOTFS_DIR"/sys \
  "$ROOTFS_DIR"/dev \
  "$ROOTFS_DIR"/run \
  "$ROOTFS_DIR"/var \
  "$ROOTFS_DIR"/tmp

cp "$ROOT_DIR/scripts/mesh/cda-mesh-setup.sh" "$ROOTFS_DIR/usr/local/sbin/cda-mesh-setup.sh"
cp "$ROOT_DIR/systemd/cda-batman-adv.service" "$ROOTFS_DIR/etc/systemd/system/cda-batman-adv.service"
cp "$ROOT_DIR/avahi/services/cda-data-services.service" "$ROOTFS_DIR/etc/avahi/services/cda-data-services.service"
cp "$ROOT_DIR/CLAUDE.MD" "$ROOTFS_DIR/usr/share/cda/CLAUDE.MD"
chmod +x "$ROOTFS_DIR/usr/local/sbin/cda-mesh-setup.sh"

# Estrutura de initramfs separada com init de overlay.
cp "$ROOT_DIR/initramfs/init-overlay.sh" "$INITRAMFS_DIR/init"
chmod +x "$INITRAMFS_DIR/init"

cat > "$DIST_DIR/README-DIST.txt" <<EOF
CDA_Unifei - Artefatos de distribuicao

Conteudo:
- cda-rootfs/: raiz do sistema para imagem Linux academica
- initramfs/init: script de init para boot com OverlayFS e squashfs
- cda-rootfs.tar.gz: pacote da raiz do sistema
- initramfs.tar.gz: pacote do initramfs
- SHA256SUMS: checksums dos artefatos

Gerado em: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

(
  cd "$DIST_DIR"
  tar -czf cda-rootfs.tar.gz cda-rootfs
  tar -czf initramfs.tar.gz initramfs
  sha256sum cda-rootfs.tar.gz initramfs.tar.gz > SHA256SUMS
)

cat > "$DIST_DIR/index.html" <<EOF
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>CDA Linux Distribution Artifacts</title>
  <style>
    :root { --bg: #0f172a; --card: #111827; --txt: #e5e7eb; --muted: #9ca3af; --acc: #22d3ee; }
    body { margin: 0; font-family: "IBM Plex Sans", sans-serif; background: radial-gradient(circle at top, #1f2937, #0b1020 60%); color: var(--txt); }
    .wrap { max-width: 880px; margin: 40px auto; padding: 24px; }
    .card { background: linear-gradient(145deg, rgba(17,24,39,.92), rgba(2,6,23,.95)); border: 1px solid rgba(34,211,238,.25); border-radius: 16px; padding: 24px; box-shadow: 0 20px 50px rgba(0,0,0,.35); }
    h1 { margin-top: 0; font-size: 1.6rem; }
    p { color: var(--muted); }
    a { color: var(--acc); text-decoration: none; font-weight: 600; }
    li { margin: 10px 0; }
    code { background: rgba(15,23,42,.6); border: 1px solid #334155; padding: 2px 6px; border-radius: 6px; color: #a5f3fc; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>CDA Linux Distribution Artifacts</h1>
      <p>Esta pagina publica os artefatos da distribuicao Linux academica (rootfs + initramfs), nao o repositorio bruto.</p>
      <ul>
        <li><a href="cda-rootfs/">Layout da raiz do sistema (cda-rootfs/)</a></li>
        <li><a href="initramfs/">Layout do initramfs (initramfs/)</a></li>
        <li><a href="cda-rootfs.tar.gz">Download cda-rootfs.tar.gz</a></li>
        <li><a href="initramfs.tar.gz">Download initramfs.tar.gz</a></li>
        <li><a href="SHA256SUMS">Checksums SHA256</a></li>
        <li><a href="README-DIST.txt">README dos artefatos</a></li>
      </ul>
      <p>Validacao rapida:</p>
      <p><code>sha256sum -c SHA256SUMS</code></p>
    </div>
  </div>
</body>
</html>
EOF

echo "[ok] artefatos gerados em $DIST_DIR"
