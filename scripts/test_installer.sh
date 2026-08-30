#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
installer="$project_dir/install.sh"
updater="$project_dir/update.sh"
source_installer="$project_dir/scripts/install.sh"
uninstaller="$project_dir/scripts/uninstall.sh"

zsh -n "$installer" "$updater" "$source_installer" "$uninstaller"

help_text="$(zsh "$installer" --help)"
[[ "$help_text" == *"--update"* && "$help_text" == *"--check"* ]]

installer_text="$(<"$installer")"
updater_text="$(<"$updater")"
[[ "$installer_text" == *"--max-time 60"* ]]
[[ "$installer_text" == *"--max-time 900"* ]]
[[ "$installer_text" == *"--progress-bar"* ]]
[[ "$updater_text" == *"--max-time 60"* ]]
[[ "$updater_text" == *"--progress-bar"* ]]
[[ "$installer_text" == *"--background-launch"* ]]
[[ "$(<"$source_installer")" == *"--background-launch"* ]]

if zsh "$installer" --version invalid >/dev/null 2>&1; then
    echo "安装脚本接受了无效版本号" >&2
    exit 1
fi

empty_home="$(mktemp -d "${TMPDIR:-/tmp}/torrancekit-installer-test.XXXXXX")"
cleanup() {
    find "$empty_home" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if HOME="$empty_home" zsh "$installer" --check >/dev/null 2>&1; then
    echo "更新检查在没有已安装 App 时意外成功" >&2
    exit 1
fi

version_function="$(sed -n '/^version_is_newer() {/,/^}/p' "$installer")"
zsh -c "$version_function
version_is_newer 0.2.0 0.1.9
version_is_newer 1.0.0 0.99.99
version_is_newer 1.2.10 1.2.9
! version_is_newer 1.2.0 1.2.0
! version_is_newer 1.1.9 1.2.0
"

echo "TorranceKit installer tests passed"
