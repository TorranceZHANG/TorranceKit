#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
install_root="$HOME/Applications"

if [[ "${1:-}" == "--system" ]]; then
    install_root="/Applications"
elif [[ $# -gt 0 ]]; then
    echo "用法：$0 [--system]" >&2
    exit 2
fi

"$project_dir/scripts/build_app.sh"
source_app="$project_dir/dist/TorranceKit.app"
destination_app="$install_root/TorranceKit.app"
backup_app="$HOME/.Trash/TorranceKit-replaced-$(date +%Y%m%d-%H%M%S)-$$.app"
legacy_app="$install_root/PasteNook.app"
legacy_backup_app="$HOME/.Trash/PasteNook-renamed-$(date +%Y%m%d-%H%M%S)-$$.app"

mkdir -p "$HOME/.Trash"
osascript -e 'tell application "TorranceKit" to quit' >/dev/null 2>&1 || true
osascript -e 'tell application "PasteNook" to quit' >/dev/null 2>&1 || true
if [[ "$install_root" == "/Applications" ]]; then
    sudo mkdir -p "$install_root"
    if [[ -e "$destination_app" ]]; then
        sudo mv "$destination_app" "$backup_app"
        sudo chown -R "$(id -u):$(id -g)" "$backup_app"
    fi
    if [[ -e "$legacy_app" ]]; then
        sudo mv "$legacy_app" "$legacy_backup_app"
        sudo chown -R "$(id -u):$(id -g)" "$legacy_backup_app"
        echo "旧 PasteNook.app 已移到废纸篓。"
    fi
    sudo ditto "$source_app" "$destination_app"
else
    mkdir -p "$install_root"
    if [[ -e "$destination_app" ]]; then
        mv "$destination_app" "$backup_app"
    fi
    if [[ -e "$legacy_app" ]]; then
        mv "$legacy_app" "$legacy_backup_app"
        echo "旧 PasteNook.app 已移到废纸篓。"
    fi
    ditto "$source_app" "$destination_app"
fi

open "$destination_app"
echo "TorranceKit 已安装到：$destination_app"
