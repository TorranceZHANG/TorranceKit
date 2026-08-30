#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
install_root="$HOME/Applications"

stop_running_application() {
    local application_name="$1"
    pgrep -x "$application_name" >/dev/null 2>&1 || return 0

    osascript \
        -e 'with timeout of 3 seconds' \
        -e "tell application \"$application_name\" to quit" \
        -e 'end timeout' >/dev/null 2>&1 || true
    local attempt
    for attempt in {1..30}; do
        pgrep -x "$application_name" >/dev/null 2>&1 || return 0
        sleep 0.1
    done

    echo "无法安全退出 $application_name，请手动退出后重新运行安装脚本。" >&2
    return 1
}

launch_application_in_background() {
    local application_path="$1"
    open "$application_path" --args --background-launch

    local attempt
    for attempt in {1..50}; do
        if pgrep -x TorranceKit >/dev/null 2>&1; then
            sleep 0.8
            pgrep -x TorranceKit >/dev/null 2>&1 \
                || { echo "TorranceKit 启动后意外退出。" >&2; exit 1; }
            return 0
        fi
        sleep 0.1
    done
    echo "TorranceKit 安装完成，但后台进程未能启动。" >&2
    exit 1
}

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
stop_running_application TorranceKit
stop_running_application PasteNook
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

launch_application_in_background "$destination_app"
echo "TorranceKit 已安装并在后台运行：$destination_app"
echo "从“应用程序”再次打开，或使用全局快捷键即可显示剪贴板。"
