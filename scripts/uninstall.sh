#!/bin/zsh

set -euo pipefail

purge_data=false
assume_yes=false
for argument in "$@"; do
    case "$argument" in
        --purge-data) purge_data=true ;;
        --yes) assume_yes=true ;;
        *)
            echo "用法：$0 [--purge-data] [--yes]" >&2
            exit 2
            ;;
    esac
done

user_app="$HOME/Applications/TorranceKit.app"
system_app="/Applications/TorranceKit.app"
trash_dir="$HOME/.Trash"
trash_app="$trash_dir/TorranceKit-$(date +%Y%m%d-%H%M%S)-$$.app"

osascript -e 'tell application "TorranceKit" to quit' >/dev/null 2>&1 || true
mkdir -p "$trash_dir"

if [[ -e "$user_app" ]]; then
    mv "$user_app" "$trash_app"
    echo "应用已移到废纸篓。"
elif [[ -e "$system_app" ]]; then
    sudo mv "$system_app" "$trash_app"
    sudo chown -R "$(id -u):$(id -g)" "$trash_app"
    echo "应用已移到废纸篓。"
else
    echo "未找到已安装的 TorranceKit.app。"
fi

if [[ "$purge_data" == true ]]; then
    if [[ "$assume_yes" != true ]]; then
        read "answer?同时永久删除历史和配置？输入 yes 继续："
        [[ "$answer" == "yes" ]] || exit 0
    fi
    data_dir="$HOME/Library/Application Support/TorranceKit"
    if [[ -d "$data_dir" ]]; then
        find "$data_dir" -depth -delete
    fi
    defaults delete com.torrance.torrancekit >/dev/null 2>&1 || true
    echo "本地历史、配置和偏好已删除，无法恢复。"
fi
