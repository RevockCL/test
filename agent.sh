#!/usr/bin/env bash
set -euo pipefail

# ================================
# Instalador PII Agent en /usr/local/bin
# ================================
# Ajusta si tu binario fuente está en otra ruta:
SRC="/home/almalinux/piitools/pii-agent-linux"
DEST="/usr/local/bin/pii-agent-linux"
SERVICE="/etc/systemd/system/pii-agent.service"

DOMAIN="discovery.botech.info"
PORT="443"
BASE_PATH="/home"
QUARANTINE_PATH="/home/quarantine"

echo "==> Verificando binario fuente: $SRC"
if [[ ! -f "$SRC" ]]; then
  echo "ERROR: No se encontró el binario en $SRC"
  exit 1
fi

echo "==> Creando /usr/local/bin (si no existe)"
sudo mkdir -p /usr/local/bin

echo "==> Copiando binario a $DEST"
sudo cp -f "$SRC" "$DEST"
sudo chmod 755 "$DEST"

# Limpiar posibles CRLF en caso de que sea script
if command -v dos2unix >/dev/null 2>&1; then
  sudo dos2unix "$DEST" || true
else
  sudo sed -i 's/\r$//' "$DEST" || true
fi

# Etiquetas SELinux correctas (si aplica)
if command -v getenforce >/dev/null 2>&1; then
  echo "==> Ajustando contexto SELinux"
  sudo restorecon -v "$DEST" || true
fi

echo "==> Creando/actualizando unidad systemd: $SERVICE"
sudo tee "$SERVICE" >/dev/null <<EOF
[Unit]
Description=PII Tools Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${DEST} cli \\
  -n ${DOMAIN} \\
  -p ${PORT} \\
  -t \$HOSTNAME \\
  -b ${BASE_PATH} \\
  -q ${QUARANTINE_PATH}
WorkingDirectory=/
Restart=always
RestartSec=5
Environment=HOSTNAME=%H

[Install]
WantedBy=multi-user.target
EOF

echo "==> Recargando systemd y habilitando servicio"
sudo systemctl daemon-reload
sudo systemctl enable --now pii-agent

echo "==> Estado del servicio:"
sudo systemctl status pii-agent --no-pager || true

echo "==> Últimos logs:"
sudo journalctl -u pii-agent -n 50 --no-pager || true

echo "✅ Listo. El agente debe estar ejecutándose desde ${DEST}"
