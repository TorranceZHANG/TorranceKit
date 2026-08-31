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

uninstaller_help_text="$(zsh "$uninstaller" --help)"
[[ "$uninstaller_help_text" == *"--purge-data"* ]]
[[ "$uninstaller_help_text" == *"--dry-run"* ]]

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

uninstall_root="$empty_home/uninstall-test"
user_applications="$uninstall_root/UserApplications"
system_applications="$uninstall_root/SystemApplications"
test_library="$uninstall_root/Library"
test_trash="$uninstall_root/Trash"

for app_path in \
    "$user_applications/TorranceKit.app" \
    "$system_applications/TorranceKit.app" \
    "$user_applications/PasteNook.app" \
    "$system_applications/PasteNook.app"; do
    mkdir -p "$app_path/Contents"
    print -r -- fixture > "$app_path/Contents/fixture.txt"
done

test_data_paths=(
    "$test_library/Application Support/TorranceKit"
    "$test_library/Application Support/PasteNook"
    "$test_library/Caches/com.torrance.torrancekit"
    "$test_library/Saved Application State/com.torrance.PasteNook.savedState"
    "$test_library/HTTPStorages/com.torrance.torrancekit"
    "$test_library/Containers/com.torrance.PasteNook"
)
for test_data_path in "${test_data_paths[@]}"; do
    mkdir -p "$test_data_path"
    print -r -- fixture > "$test_data_path/fixture.txt"
done
mkdir -p "$test_library/Preferences/ByHost" "$test_library/Logs/DiagnosticReports"
print -r -- fixture > "$test_library/Preferences/com.torrance.torrancekit.plist"
print -r -- fixture > "$test_library/Preferences/ByHost/com.torrance.PasteNook.TEST.plist"
print -r -- fixture > "$test_library/Logs/DiagnosticReports/TorranceKit_2026-01-01.ips"
mkdir -p "$test_library/Application Support/Unrelated"
print -r -- keep > "$test_library/Application Support/Unrelated/keep.txt"

HOME="$empty_home" \
TORRANCEKIT_UNINSTALL_USER_APPLICATIONS_DIR="$user_applications" \
TORRANCEKIT_UNINSTALL_SYSTEM_APPLICATIONS_DIR="$system_applications" \
TORRANCEKIT_UNINSTALL_LIBRARY_DIR="$test_library" \
TORRANCEKIT_UNINSTALL_TRASH_DIR="$test_trash" \
TORRANCEKIT_UNINSTALL_TEST_MODE=1 \
    zsh "$uninstaller" --purge-data --yes >/dev/null

for removed_path in \
    "$user_applications/TorranceKit.app" \
    "$system_applications/TorranceKit.app" \
    "$user_applications/PasteNook.app" \
    "$system_applications/PasteNook.app" \
    "${test_data_paths[@]}" \
    "$test_library/Preferences/com.torrance.torrancekit.plist" \
    "$test_library/Preferences/ByHost/com.torrance.PasteNook.TEST.plist" \
    "$test_library/Logs/DiagnosticReports/TorranceKit_2026-01-01.ips"; do
    if [[ -e "$removed_path" ]]; then
        echo "卸载测试未清理：$removed_path" >&2
        exit 1
    fi
done
[[ -f "$test_library/Application Support/Unrelated/keep.txt" ]]
[[ "$(find "$test_trash" -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')" == "4" ]]

dry_run_root="$empty_home/uninstall-dry-run"
dry_run_app="$dry_run_root/UserApplications/TorranceKit.app"
dry_run_data="$dry_run_root/Library/Application Support/TorranceKit"
mkdir -p "$dry_run_app" "$dry_run_data"
dry_run_output="$(
    HOME="$empty_home" \
    TORRANCEKIT_UNINSTALL_USER_APPLICATIONS_DIR="$dry_run_root/UserApplications" \
    TORRANCEKIT_UNINSTALL_SYSTEM_APPLICATIONS_DIR="$dry_run_root/SystemApplications" \
    TORRANCEKIT_UNINSTALL_LIBRARY_DIR="$dry_run_root/Library" \
    TORRANCEKIT_UNINSTALL_TRASH_DIR="$dry_run_root/Trash" \
    TORRANCEKIT_UNINSTALL_TEST_MODE=1 \
        zsh "$uninstaller" --purge-data --yes --dry-run
)"
[[ -d "$dry_run_app" && -d "$dry_run_data" ]]
[[ "$dry_run_output" == *"预演完成；未修改本机。"* ]]

echo "TorranceKit installer tests passed"
