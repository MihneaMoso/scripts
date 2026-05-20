#!/usr/bin/env bash

# XMRig Automated Installer & Configurator (Linux/macOS)
# IMPORTANT: This script is for educational and authorized use only.
# Ensure you have permission to mine on this machine.

set -euo pipefail

# --- Root Check ---
if [[ "$EUID" -ne 0 ]]; then
    echo "Not running as root. Attempting to elevate..."
    exec sudo bash "$0" "$@"
fi

echo "Running with root privileges."

# --- Configuration ---
INSTALL_DIR="/opt/xmrig"
WALLET_ADDRESS="49G3kemCgBBPhjNK1gizHMR8V7qq5nMzrHz6BtETnqzSBTAs4tWCh7tWA9HZW6YhqHHwGUaX5t8EmjUyEe8FQPakU19pr8i" # <--- REPLACE THIS
POOL_URL="pool.supportxmr.com:3333"
COIN="monero"

# --- Prerequisites ---
for cmd in curl unzip jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is required but not installed."
        exit 1
    fi
done

# --- Installation ---
mkdir -p "$INSTALL_DIR"
echo "Created directory: $INSTALL_DIR"

# --- Download Latest Release ---
echo "Fetching latest release URL..."

LATEST_RELEASE_JSON=$(curl -s https://api.github.com/repos/xmrig/xmrig/releases/latest)

DOWNLOAD_URL=$(echo "$LATEST_RELEASE_JSON" | jq -r '
    .assets[]
    | select(.name | test("linux-static-x64.tar.gz$"))
    | .browser_download_url
' | head -n 1)

if [[ -z "$DOWNLOAD_URL" || "$DOWNLOAD_URL" == "null" ]]; then
    echo "Error: Could not find a Linux x64 tar.gz release."
    exit 1
fi

ARCHIVE_FILE="$INSTALL_DIR/xmrig.tar.gz"

echo "Downloading from: $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "$ARCHIVE_FILE"

if [[ ! -f "$ARCHIVE_FILE" ]]; then
    echo "Download failed."
    exit 1
fi

# --- Extract ---
echo "Extracting files..."
tar -xzf "$ARCHIVE_FILE" -C "$INSTALL_DIR"
rm -f "$ARCHIVE_FILE"

# Locate extracted folder
EXTRACTED_FOLDER=$(find "$INSTALL_DIR" -maxdepth 1 -type d -name "xmrig-*" | head -n 1)

if [[ -z "$EXTRACTED_FOLDER" ]]; then
    echo "Error: Could not locate extracted XMRig folder."
    exit 1
fi

EXECUTABLE_PATH="$EXTRACTED_FOLDER/xmrig"

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    echo "Warning: Could not locate xmrig binary automatically."
fi

# --- Generate config.json ---
echo "Generating config.json..."

cat > "$EXTRACTED_FOLDER/config.json" <<EOF
{
  "api": {
    "id": null,
    "worker-id": null
  },
  "http": {
    "enabled": false,
    "host": "127.0.0.1",
    "port": 0,
    "access-token": null,
    "restricted": true
  },
  "autosave": true,
  "background": false,
  "colors": true,
  "title": true,
  "randomx": {
    "init": -1,
    "init-avx2": -1,
    "mode": "auto",
    "1gb-pages": false,
    "rdmsr": true,
    "wrmsr": true,
    "cache_qos": false,
    "numa": true,
    "scratchpad_prefetch_mode": 1
  },
  "cpu": {
    "enabled": true,
    "huge-pages": true,
    "huge-pages-jit": false,
    "hw-aes": null,
    "priority": null,
    "memory-pool": false,
    "yield": true,
    "asm": true
  },
  "opencl": {
    "enabled": false
  },
  "cuda": {
    "enabled": false
  },
  "log-file": "xmrig.log",
  "donate-level": 1,
  "pools": [
    {
      "algo": null,
      "coin": "$COIN",
      "url": "$POOL_URL",
      "user": "$WALLET_ADDRESS",
      "pass": "x",
      "rig-id": null,
      "nicehash": false,
      "keepalive": true,
      "enabled": true,
      "tls": false
    }
  ],
  "print-time": 60,
  "health-print-time": 60,
  "retries": 5,
  "retry-pause": 5,
  "syslog": false,
  "verbose": 0,
  "watch": true,
  "pause-on-battery": false,
  "pause-on-active": false
}
EOF

echo "---------------------------------------------------"
echo "Installation Complete!"
echo "Location: $EXTRACTED_FOLDER"
echo "To run:"
echo "  $EXECUTABLE_PATH"
echo "---------------------------------------------------"