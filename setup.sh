#!/usr/bin/env bash
# setup.sh — Install and configure the Pi Video Server on a Raspberry Pi Zero 2 W
# Run once after cloning the repository:
#   chmod +x setup.sh && sudo ./setup.sh
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_USER="${SUDO_USER:-$(logname 2>/dev/null || echo pi)}"
if ! id -u "${APP_USER}" &>/dev/null; then
    echo "ERROR: User '${APP_USER}' does not exist." >&2
    exit 1
fi
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

echo "==> Adding ${APP_USER} to input group (for keyboard control)..."
usermod -aG input "${APP_USER}"

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
After=network-online.target
Wants=network-online.target

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
    # Properly disable cloud-init via its supported mechanism
    touch /etc/cloud/cloud-init.disabled
    CMDLINE_FILE="/boot/firmware/cmdline.txt"
    if [ -f "${CMDLINE_FILE}" ] && ! grep -q 'cloud-init=disabled' "${CMDLINE_FILE}"; then
        sed -i 's/$/ cloud-init=disabled/' "${CMDLINE_FILE}"
    fi
    echo "    Disabled cloud-init (marker file + kernel cmdline)"

    # Services safe to disable on a headless video kiosk with WiFi
    DISABLE_SERVICES=(
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
        if systemctl list-unit-files | grep -q "^${svc}[[:space:]]"; then
            systemctl disable --now "${svc}" 2>/dev/null && \
                echo "    Disabled ${svc}" || \
                echo "    Skipped ${svc} (could not disable)"
        else
            echo "    Skipped ${svc} (not installed)"
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
