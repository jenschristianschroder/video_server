#!/usr/bin/env bash
# setup.sh — Install and configure the Pi Video Server on a Raspberry Pi Zero 2 W
# Run once after cloning the repository:
#   chmod +x setup.sh && sudo ./setup.sh
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_USER="${SUDO_USER:-pi}"
SERVICE_NAME="video-server"
VENV_DIR="${APP_DIR}/venv"

echo "==> Installing system packages..."
apt-get update -qq
apt-get install -y python3 python3-venv python3-pip vlc

echo "==> Creating Python virtual environment..."
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/pip" install --upgrade pip
"${VENV_DIR}/bin/pip" install -r "${APP_DIR}/requirements.txt"

echo "==> Creating videos directory..."
mkdir -p "${APP_DIR}/videos"
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}/videos"

# ── Settings ─────────────────────────────────────────────────────────
ENV_FILE="${APP_DIR}/.env"

read -rp "==> Autoplay first video on startup? [Y/n] " autoplay_answer
autoplay_answer="${autoplay_answer:-Y}"
if [[ "${autoplay_answer}" =~ ^[Yy]$ ]]; then
    AUTOPLAY="true"
else
    AUTOPLAY="false"
fi

echo "AUTOPLAY_ON_START=${AUTOPLAY}" > "${ENV_FILE}"
chown "${APP_USER}:${APP_USER}" "${ENV_FILE}"
echo "    Wrote ${ENV_FILE}"

# ── Systemd service ──────────────────────────────────────────────────
echo "==> Installing systemd service (${SERVICE_NAME})..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Pi Video Server
After=network.target

[Service]
Type=simple
User=${APP_USER}
WorkingDirectory=${APP_DIR}
ExecStart=${VENV_DIR}/bin/python ${APP_DIR}/app.py
Restart=on-failure
RestartSec=5
Environment=DISPLAY=:0
EnvironmentFile=${ENV_FILE}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl start "${SERVICE_NAME}.service"

# ── Disable unnecessary services ─────────────────────────────────────
echo ""
read -rp "==> Disable unnecessary services to reduce overhead? [Y/n] " disable_answer
disable_answer="${disable_answer:-Y}"
if [[ "${disable_answer}" =~ ^[Yy]$ ]]; then
    # Services safe to disable on a headless video kiosk with WiFi
    DISABLE_SERVICES=(
        cloud-init.service
        cloud-init-local.service
        cloud-config.service
        cloud-final.service
        snapd.service
        snapd.socket
        snapd.seeded.service
        ModemManager.service
        bluetooth.service
        bluetooth.target
        hciuart.service
        triggerhappy.service
        triggerhappy.socket
        avahi-daemon.service
        avahi-daemon.socket
        cups.service
        cups-browsed.service
        apt-daily.service
        apt-daily.timer
        apt-daily-upgrade.service
        apt-daily-upgrade.timer
        man-db.timer
    )

    for svc in "${DISABLE_SERVICES[@]}"; do
        if systemctl list-unit-files "${svc}" &>/dev/null; then
            systemctl disable --now "${svc}" 2>/dev/null && \
                echo "    Disabled ${svc}" || \
                echo "    Skipped ${svc} (not found)"
        fi
    done
    echo "    Done — unnecessary services disabled."
else
    echo "    Skipping — services left as-is."
fi

echo ""
echo "==> Setup complete!"
echo "    The video server is running and will start automatically on reboot."
echo "    Manage with:  sudo systemctl {start|stop|restart|status} ${SERVICE_NAME}"
echo "    Logs:         journalctl -u ${SERVICE_NAME} -f"
