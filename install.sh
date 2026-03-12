#!/bin/bash

# ===== デバッグ全ログ版 =====
set -x          # 実行するコマンドを全部表示
set -e          # エラーが起きたら即停止
set -o pipefail # パイプの中のエラーも拾う

LOG_FILE="/tmp/bedrock_install_debug.log"
exec > >(tee -a "$LOG_FILE") 2>&1  # 全出力をログファイルにも保存

echo "===== START: $(date) ====="
echo "macOS: $(sw_vers -productVersion)"
echo "アーキテクチャ: $(uname -m)"
echo "引数1 (サーバーフォルダ): $1"
echo "引数2: $2"

if [[ $# -lt 1 ]] ; then
    echo 'Usage: install.sh Bedrock_server_folder. To run in verbose mode, use -v at the end.'
    exit 0
fi

echo ""
echo "===== STEP 1: Wine pkgをダウンロード ====="
curl -v -L 'https://dl.winehq.org/wine-builds/macosx/pool/winehq-devel-5.7.pkg' > /tmp/wine.pkg
echo "ダウンロード完了。ファイルサイズ: $(du -sh /tmp/wine.pkg)"

echo ""
echo "===== STEP 2: pkgを展開 ====="
pkgutil --expand /tmp/wine.pkg /tmp/wine
echo "展開後の内容:"
ls -la /tmp/wine/

echo ""
echo "===== STEP 3: Payloadをtar展開 ====="
echo "Payloadのパス確認:"
ls -la /tmp/wine/org.winehq.wine-devel64.pkg/
tar -xvf /tmp/wine/org.winehq.wine-devel64.pkg/Payload
echo "展開後のContents確認:"
ls -la ./Contents/Resources/wine/bin/ 2>/dev/null || echo "⚠️ wine/binが見つかりません"

echo ""
echo "===== STEP 4: wineをサーバーフォルダへ移動 ====="
echo "移動先: $1/wine"
mv -v ./Contents/Resources/wine "$1"/wine

echo ""
echo "===== STEP 5: files.zipを展開 ====="
unzip -v ./files.zip -d "$1"

echo ""
echo "===== STEP 6: 一時ファイルを削除 ====="
rm -rfv /tmp/wine.pkg
rm -rfv /tmp/wine
rm -rfv ./Contents

echo ""
echo "===== STEP 7: winebootでプレフィックス初期化 ====="
echo "wine実行ファイルの確認:"
file "$1"/wine/bin/wineboot || echo "⚠️ winebootが見つかりません"
WINEPREFIX="$1/prefix" "$1"/wine/bin/wineboot

echo ""
echo "===== STEP 8: winedbg削除 ====="
rm -rfv "$1/prefix/drive_c/windows/system32/winedbg.exe"

echo ""
echo "===== DONE: $(date) ====="
echo "ログは $LOG_FILE に保存されました"
echo "Successfully installed! サーバーフォルダ内の bedrock_server を実行してください。"