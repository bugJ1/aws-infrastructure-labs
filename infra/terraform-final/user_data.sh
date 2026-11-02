#!/bin/bash
# User Data: se ejecuta UNA sola vez, como root, en el primer arranque.
# Registro completo en /var/log/cloud-init-output.log
set -euxo pipefail

REPO_URL="${repo_url}"
APP_DIR="/opt/app"

export HOME=/root
export DEBIAN_FRONTEND=noninteractive

# apt puede estar ocupado con unattended-upgrades en el primer arranque;
# se espera hasta 5 minutos en vez de fallar.
APT_WAIT="-o DPkg::Lock::Timeout=300"

apt-get $APT_WAIT update -y
apt-get $APT_WAIT install -y git docker.io
systemctl enable --now docker

git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"

docker build -t sizing-app .
docker run -d --name sizing-app --restart unless-stopped -p 8000:8000 sizing-app

echo "User Data terminado: la aplicacion responde en el puerto 8000"
