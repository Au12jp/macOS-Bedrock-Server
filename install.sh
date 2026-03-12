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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "===== STEP 0: 準備 ====="
# 相対パスを絶対パスに変換（後で cd しても壊れないようにする）
mkdir -p "$1"
SERVER_DIR="$(cd "$1" && pwd)"
echo "Absolute SERVER_DIR: $SERVER_DIR"
rm -rf /tmp/wine
rm -rf /tmp/wine_extract
rm -f /tmp/wine.pkg

echo "===== STEP 1: Wine ダウンロード ====="
curl -L https://dl.winehq.org/wine-builds/macosx/pool/winehq-devel-5.7.pkg -o /tmp/wine.pkg
echo "Download finished: $(du -sh /tmp/wine.pkg)"

echo "===== STEP 2: pkg 展開 ====="
pkgutil --expand /tmp/wine.pkg /tmp/wine
ls -la /tmp/wine

echo "===== STEP 3: Payload 展開 ====="
mkdir -p /tmp/wine_extract
cd /tmp/wine_extract

# macOS の pkg Payload は pax で展開する（tar では展開できない）
pax -rz -f /tmp/wine/org.winehq.wine-devel64.pkg/Payload

echo "展開後の構造確認:"
find /tmp/wine_extract -type d -name "wine" 2>/dev/null || echo "wine ディレクトリ未発見"

echo "===== STEP 4: wine コピー ====="
WINE_PATH=$(find /tmp/wine_extract -type d -name "wine" | head -n 1)

if [ -z "$WINE_PATH" ]; then
    echo "ERROR: wine フォルダが見つかりませんでした"
    echo "展開されたディレクトリ一覧:"
    find /tmp/wine_extract -maxdepth 5 -type d 2>/dev/null
    exit 1
fi

echo "Found wine at: $WINE_PATH"
cp -R "$WINE_PATH" "$SERVER_DIR/wine"

echo "===== STEP 5: Bedrock server files 展開 ====="
cd "$SCRIPT_DIR"
unzip -o files.zip -d "$SERVER_DIR"

echo "===== STEP 6: Cleanup ====="
rm -rf /tmp/wine
rm -rf /tmp/wine_extract
rm -f /tmp/wine.pkg

echo "===== STEP 7: Wine prefix 初期化 ====="
if [ ! -f "$SERVER_DIR/wine/bin/wineboot" ]; then
    echo "ERROR: wineboot が見つかりません"
    ls -la "$SERVER_DIR/wine/bin/" 2>/dev/null || echo "wine/bin が存在しません"
    exit 1
fi
WINEPREFIX="$SERVER_DIR/prefix" "$SERVER_DIR/wine/bin/wineboot"

echo "===== STEP 8: winedbg 削除 ====="
rm -f "$SERVER_DIR/prefix/drive_c/windows/system32/winedbg.exe"

echo "===== DONE: $(date) ====="
echo "Log saved at $LOG_FILE"
echo ""
echo "サーバー起動:"
echo "  cd $SERVER_DIR"
echo "  ./bedrock_server"