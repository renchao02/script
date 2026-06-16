#!/bin/bash
set -e

INSTALL_DIR="/opt/xray"
XPATH="/rayrenchao"
PORT=443

echo "=============================="
echo " Xray + XHTTP 安装...."
echo "=============================="

### ===== DOMAIN（必填） =====
read -p "输入域名（必填）: " DOMAIN
if [ -z "$DOMAIN" ]; then
  echo "DOMAIN is required. Exit."
  exit 1
fi

### ===== UUID（可选） =====
read -p "输入UUID（默认自动生成）：" UUID


### ===== VERSION（可选） =====
read -p "输入版本号（默认最新版本）: " XRAY_VERSION
if [ -z "$XRAY_VERSION" ]; then
  XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/"
  echo "使用最新版本: latest version"
else
  XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/"
  echo "使用版本: $XRAY_VERSION"
fi

### ===== ARCH DETECT =====
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    FILE="Xray-linux-64.zip"
    ;;
  aarch64 | arm64)
    FILE="Xray-linux-arm64-v8a.zip"
    ;;
  armv7l)
    FILE="Xray-linux-arm32-v7a.zip"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "Detected arch: $ARCH -> $FILE"

### ===== INSTALL DEP =====
echo "Installing dependencies..."
apt update -y
apt install -y curl unzip cron ca-certificates

mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

### ===== DOWNLOAD XRAY =====
echo "Downloading Xray..."
curl -fL -o xray.zip ${XRAY_URL}${FILE}

unzip -o xray.zip
chmod +x xray

### ===== CONFIG =====
echo "Writing config..."

if [ -z "$UUID" ]; then
  UUID=$(${INSTALL_DIR}/xray uuid)
fi

cat > ${INSTALL_DIR}/config.yaml <<EOF
log:
  loglevel: warning

inbounds:
  - port: ${PORT}
    protocol: vless

    settings:
      clients:
        - id: ${UUID}
      decryption: none

    streamSettings:
      network: xhttp
      security: tls

      tlsSettings:
        certificates:
          - certificateFile: ${INSTALL_DIR}/fullchain.pem
            keyFile: ${INSTALL_DIR}/privkey.pem

      xhttpSettings:
        path: ${XPATH}

outbounds:
  - protocol: freedom
EOF

### ===== SYSTEMD =====
echo "Creating systemd service..."

cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/xray run -c ${INSTALL_DIR}/config.yaml

Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray


### ===== INSTALL ACME =====
echo "Installing acme.sh..."
curl https://get.acme.sh | sh

if ss -lnt | grep -q ':80 '; then
    echo "Port 80 is occupied"
    exit 1
fi

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

echo "Requesting TLS cert..."
if ~/.acme.sh/acme.sh --list | awk '{print $1}' | grep -qx "${DOMAIN}"; then
    echo "Certificate already exists."
else
    echo "Requesting TLS cert..."
    ~/.acme.sh/acme.sh --issue --standalone -d "${DOMAIN}"
fi

~/.acme.sh/acme.sh --install-cert -d ${DOMAIN} \
  --key-file ${INSTALL_DIR}/privkey.pem \
  --fullchain-file ${INSTALL_DIR}/fullchain.pem \
  --reloadcmd "systemctl restart xray"


ENC_PATH=$(printf '%s' "${XPATH}" | sed 's/\//%2F/g')
SHARE_LINK="vless://${UUID}@${DOMAIN}:${PORT}?type=xhttp&security=tls&path=${ENC_PATH}&encryption=none#Xray-XHTTP"


echo "=============================="
echo " Installation complete"
echo " DOMAIN: ${DOMAIN}"
echo " UUID  : ${UUID}"
echo " VERSION: ${XRAY_VERSION:-latest}"
echo " ARCH  : ${ARCH}"
echo " PATH  : ${XPATH}"
echo "Client Share Link:"
echo "${SHARE_LINK}"
echo "=============================="
