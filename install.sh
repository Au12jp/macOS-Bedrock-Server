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

echo "===== STEP 0: 準備 ====="
mkdir -p "$SERVER_DIR"
rm -rf /tmp/wine
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
mv -v ./Contents/Resources/wine "$SERVER_DIR"/wine

echo "===== STEP 5: Bedrock server files 展開 ====="
cd "$OLDPWD"
unzip -o ./files.zip -d "$SERVER_DIR"

echo "===== STEP 6: Cleanup ====="
rm -rf /tmp/wine
rm -f /tmp/wine.pkg
rm -rf /tmp/Contents

echo "===== STEP 7: Wine prefix 初期化 ====="
WINEPREFIX="$SERVER_DIR/prefix" "$SERVER_DIR/wine/bin/wineboot"

echo "===== STEP 8: winedbg 削除 ====="
rm -f "$SERVER_DIR/prefix/drive_c/windows/system32/winedbg.exe"

echo "===== DONE: $(date) ====="
echo "Log saved at $LOG_FILE"
echo "Start server with:"
echo "cd $SERVER_DIR && ./bedrock_server"