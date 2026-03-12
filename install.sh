#!/bin/bash

set -e
set -o pipefail
set -x

LOG_FILE="/tmp/bedrock_install_debug.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===== START: $(date) ====="
echo "macOS: $(sw_vers -productVersion)"
echo "Architecture: $(uname -m)"
echo "Server folder: $1"

if [[ $# -lt 1 ]]; then
    echo "Usage: ./install.sh <server_folder>"
    exit 1
fi

SERVER_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===== STEP 0: 準備 ====="
mkdir -p "$SERVER_DIR"

# 前回の残骸削除
rm -rf /tmp/wine
rm -rf /tmp/Contents
rm -f /tmp/wine.pkg

echo "===== STEP 1: Wine ダウンロード ====="
curl -L https://dl.winehq.org/wine-builds/macosx/pool/winehq-devel-5.7.pkg -o /tmp/wine.pkg
echo "Download finished: $(du -sh /tmp/wine.pkg)"

echo "===== STEP 2: pkg 展開 ====="
pkgutil --expand /tmp/wine.pkg /tmp/wine
ls -la /tmp/wine

echo "===== STEP 3: Payload 展開 ====="
cd /tmp
tar -xf /tmp/wine/org.winehq.wine-devel64.pkg/Payload

echo "===== STEP 4: wine コピー ====="
if [ -d "/tmp/Contents/Resources/wine" ]; then
    mv -v /tmp/Contents/Resources/wine "$SERVER_DIR"/wine
else
    echo "ERROR: wine folder not found!"
    exit 1
fi

echo "===== STEP 5: Bedrock server files 展開 ====="
cd "$SCRIPT_DIR"
unzip -o files.zip -d "$SERVER_DIR"

echo "===== STEP 6: Cleanup ====="
rm -rf /tmp/wine
rm -rf /tmp/Contents
rm -f /tmp/wine.pkg

echo "===== STEP 7: Wine prefix 初期化 ====="
WINEPREFIX="$SERVER_DIR/prefix" "$SERVER_DIR/wine/bin/wineboot"

echo "===== STEP 8: winedbg 削除 ====="
rm -f "$SERVER_DIR/prefix/drive_c/windows/system32/winedbg.exe"

echo "===== DONE: $(date) ====="
echo "Log saved at $LOG_FILE"
echo ""
echo "Start server with:"
echo "cd $SERVER_DIR"
echo "./bedrock_server"