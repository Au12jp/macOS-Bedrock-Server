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

# 展開後の構造を確認（デバッグ用）
echo "展開後の /tmp 確認:"
find /tmp -maxdepth 4 -type d -name "wine" 2>/dev/null || echo "wine ディレクトリが見つかりません"

echo "===== STEP 4: wine コピー ====="
# wine フォルダを自動検索（パス固定しない）
WINE_PATH=$(find /tmp -type d -name "wine" | grep -v "^/tmp/wine$" | head -n 1)

if [ -z "$WINE_PATH" ]; then
    echo "ERROR: wine フォルダが見つかりませんでした"
    echo "展開されたファイル一覧:"
    find /tmp/Contents -type d 2>/dev/null || echo "/tmp/Contents が存在しません"
    exit 1
fi

echo "Found wine at: $WINE_PATH"
mv -v "$WINE_PATH" "$SERVER_DIR/wine"

echo "===== STEP 5: Bedrock server files 展開 ====="
cd "$SCRIPT_DIR"
unzip -o files.zip -d "$SERVER_DIR"

echo "===== STEP 6: Cleanup ====="
rm -rf /tmp/wine
rm -rf /tmp/Contents
rm -f /tmp/wine.pkg

echo "===== STEP 7: Wine prefix 初期化 ====="
if [ ! -f "$SERVER_DIR/wine/bin/wineboot" ]; then
    echo "ERROR: wineboot が見つかりません: $SERVER_DIR/wine/bin/wineboot"
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