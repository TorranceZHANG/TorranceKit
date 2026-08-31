#!/bin/zsh

set -euo pipefail

usage() {
    cat <<'EOF'
用法：./scripts/uninstall.sh [选项]

选项：
  --purge-data  永久删除 TorranceKit/PasteNook 的历史、配置、缓存、偏好和权限记录
  --yes         跳过永久删除前的确认（需与 --purge-data 一起使用）
  --dry-run     只显示将执行的操作，不修改本机
  --help        显示帮助
EOF
}

purge_data=false
assume_yes=false
dry_run=false

for argument in "$@"; do
    case "$argument" in
        --purge-data) purge_data=true ;;
        --yes) assume_yes=true ;;
        --dry-run) dry_run=true ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$assume_yes" == true && "$purge_data" != true ]]; then
    echo "--yes 只能与 --purge-data 一起使用。" >&2
    exit 2
fi

# TORRANCEKIT_UNINSTALL_* 变量只用于隔离测试，正常运行时均指向标准 macOS 路径。
user_applications_dir="${TORRANCEKIT_UNINSTALL_USER_APPLICATIONS_DIR:-$HOME/Applications}"
system_applications_dir="${TORRANCEKIT_UNINSTALL_SYSTEM_APPLICATIONS_DIR:-/Applications}"
library_dir="${TORRANCEKIT_UNINSTALL_LIBRARY_DIR:-$HOME/Library}"
trash_dir="${TORRANCEKIT_UNINSTALL_TRASH_DIR:-$HOME/.Trash}"
test_mode="${TORRANCEKIT_UNINSTALL_TEST_MODE:-0}"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
timestamp="$(date +%Y%m%d-%H%M%S)"
trash_sequence=0
moved_app_count=0

if [[ "$test_mode" != "1" && (
    -n "${TORRANCEKIT_UNINSTALL_USER_APPLICATIONS_DIR:-}" ||
    -n "${TORRANCEKIT_UNINSTALL_SYSTEM_APPLICATIONS_DIR:-}" ||
    -n "${TORRANCEKIT_UNINSTALL_LIBRARY_DIR:-}" ||
    -n "${TORRANCEKIT_UNINSTALL_TRASH_DIR:-}"
) ]]; then
    echo "卸载路径覆盖变量只能用于隔离测试。" >&2
    exit 1
fi

for protected_path in "$user_applications_dir" "$system_applications_dir" "$library_dir" "$trash_dir"; do
    if [[ -z "$protected_path" || "$protected_path" == "/" ]]; then
        echo "拒绝使用不安全的卸载路径：${protected_path:-<空>}" >&2
        exit 1
    fi
done
resolved_library_dir="${library_dir:A}"

run_label() {
    if [[ "$dry_run" == true ]]; then
        print -r -- "[预演] $*"
    else
        print -r -- "$*"
    fi
}

stop_running_application() {
    local application_name="$1"

    if [[ "$test_mode" == "1" ]]; then
        return
    fi
    if [[ "$dry_run" == true ]]; then
        run_label "停止进程：$application_name（如正在运行）"
        return
    fi
    if ! pgrep -x "$application_name" >/dev/null 2>&1; then
        return
    fi

    osascript \
        -e 'with timeout of 3 seconds' \
        -e "tell application \"$application_name\" to quit" \
        -e 'end timeout' >/dev/null 2>&1 || true
    for attempt in {1..30}; do
        pgrep -x "$application_name" >/dev/null 2>&1 || break
        sleep 0.1
    done

    if pgrep -x "$application_name" >/dev/null 2>&1; then
        pkill -TERM -x "$application_name" >/dev/null 2>&1 || true
        for attempt in {1..30}; do
            pgrep -x "$application_name" >/dev/null 2>&1 || break
            sleep 0.1
        done
    fi

    if pgrep -x "$application_name" >/dev/null 2>&1; then
        pkill -KILL -x "$application_name" >/dev/null 2>&1 || true
        sleep 0.2
    fi

    if pgrep -x "$application_name" >/dev/null 2>&1; then
        echo "无法停止 $application_name，已中止卸载，避免留下半卸载状态。" >&2
        exit 1
    fi
    echo "已停止 $application_name。"
}

unregister_application() {
    local application_path="$1"

    if [[ "$test_mode" == "1" || ! -x "$lsregister" ]]; then
        return
    fi
    if [[ "$dry_run" == true ]]; then
        run_label "注销应用注册：$application_path"
        return
    fi
    "$lsregister" -u "$application_path" >/dev/null 2>&1 || true
}

move_application_to_trash() {
    local source_app="$1"
    local app_filename="${source_app:t}"
    local app_stem="${app_filename%.app}"
    local destination_app

    if [[ ! -e "$source_app" && ! -L "$source_app" ]]; then
        return
    fi

    trash_sequence=$((trash_sequence + 1))
    destination_app="$trash_dir/${app_stem}-uninstalled-$timestamp-$$-$trash_sequence.app"
    unregister_application "$source_app"

    if [[ "$dry_run" == true ]]; then
        run_label "移到废纸篓：$source_app -> $destination_app"
        return
    fi

    mkdir -p "$trash_dir"
    if [[ -w "${source_app:h}" ]]; then
        mv "$source_app" "$destination_app"
    else
        sudo mv "$source_app" "$destination_app"
        sudo chown -R "$(id -u):$(id -g)" "$destination_app"
    fi
    unregister_application "$destination_app"
    moved_app_count=$((moved_app_count + 1))
    echo "已移到废纸篓：$source_app"
}

delete_private_path() {
    local target_path="$1"
    local resolved_target_path="${target_path:A}"

    case "$resolved_target_path" in
        "$resolved_library_dir"/*) ;;
        *)
            echo "拒绝删除 Library 目录之外的路径：$target_path" >&2
            exit 1
            ;;
    esac

    if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
        return
    fi
    if [[ "$dry_run" == true ]]; then
        run_label "永久删除：$target_path"
        return
    fi

    if [[ -d "$target_path" && ! -L "$target_path" ]]; then
        find "$target_path" -depth -delete
    else
        unlink "$target_path"
    fi
    echo "已永久删除：$target_path"
}

delete_matching_files() {
    local parent_directory="$1"
    shift
    local find_arguments=()
    local pattern
    local matched_path

    [[ -d "$parent_directory" ]] || return 0
    for pattern in "$@"; do
        if (( ${#find_arguments[@]} > 0 )); then
            find_arguments+=( -o )
        fi
        find_arguments+=( -name "$pattern" )
    done

    while IFS= read -r -d '' matched_path; do
        delete_private_path "$matched_path"
    done < <(find "$parent_directory" -maxdepth 1 -mindepth 1 -type f \( "${find_arguments[@]}" \) -print0)
}

remove_launch_agent() {
    local bundle_identifier="$1"
    local launch_agent="$library_dir/LaunchAgents/$bundle_identifier.plist"

    if [[ ! -e "$launch_agent" && ! -L "$launch_agent" ]]; then
        return
    fi
    if [[ "$test_mode" != "1" && "$dry_run" != true ]]; then
        launchctl bootout "gui/$(id -u)" "$launch_agent" >/dev/null 2>&1 || true
        launchctl remove "$bundle_identifier" >/dev/null 2>&1 || true
    fi
    delete_private_path "$launch_agent"
}

reset_privacy_permissions() {
    local bundle_identifier="$1"
    local reset_output

    if [[ "$test_mode" == "1" ]]; then
        return
    fi
    if [[ "$dry_run" == true ]]; then
        run_label "重置隐私权限：$bundle_identifier"
        return
    fi
    if reset_output="$(tccutil reset All "$bundle_identifier" 2>&1)"; then
        echo "已重置隐私权限：$bundle_identifier"
        return 0
    fi
    if [[ "$reset_output" == *"No such bundle identifier"* || "$reset_output" == *"-10814"* ]]; then
        echo "未发现已注册的 $bundle_identifier，无需重置隐私权限。"
        return 0
    fi
    print -r -- "$reset_output" >&2
    echo "无法重置 $bundle_identifier 的隐私权限记录。" >&2
    return 1
}

if [[ "$purge_data" == true && "$assume_yes" != true && "$dry_run" != true ]]; then
    read "answer?将永久删除 TorranceKit/PasteNook 的历史、配置、缓存、偏好和权限记录。输入 yes 继续："
    if [[ "$answer" != "yes" ]]; then
        purge_data=false
        echo "将只卸载应用并保留本地数据。"
    fi
fi

stop_running_application TorranceKit
stop_running_application PasteNook

# tccutil 需要应用仍处于已注册状态，因此权限必须先于应用注销和移动进行重置。
if [[ "$purge_data" == true ]]; then
    reset_privacy_permissions com.torrance.torrancekit
    reset_privacy_permissions com.torrance.PasteNook
fi

# 两个安装位置都要检查；不能用 if/elif，否则双重安装时会留下一个副本。
move_application_to_trash "$user_applications_dir/TorranceKit.app"
move_application_to_trash "$system_applications_dir/TorranceKit.app"
move_application_to_trash "$user_applications_dir/PasteNook.app"
move_application_to_trash "$system_applications_dir/PasteNook.app"

# 即使保留数据，也移除可能导致应用再次启动的旧版启动项。
remove_launch_agent com.torrance.torrancekit
remove_launch_agent com.torrance.PasteNook

if [[ "$purge_data" == true ]]; then
    bundle_identifiers=(com.torrance.torrancekit com.torrance.PasteNook)
    purge_paths=(
        "$library_dir/Application Support/TorranceKit"
        "$library_dir/Application Support/PasteNook"
        "$library_dir/Caches/TorranceKit"
        "$library_dir/Caches/PasteNook"
        "$library_dir/Saved Application State/TorranceKit.savedState"
        "$library_dir/Saved Application State/PasteNook.savedState"
        "$library_dir/Logs/TorranceKit"
        "$library_dir/Logs/PasteNook"
    )

    for bundle_identifier in "${bundle_identifiers[@]}"; do
        purge_paths+=(
            "$library_dir/Preferences/$bundle_identifier.plist"
            "$library_dir/Caches/$bundle_identifier"
            "$library_dir/Caches/com.apple.nsurlsessiond/Downloads/$bundle_identifier"
            "$library_dir/Saved Application State/$bundle_identifier.savedState"
            "$library_dir/HTTPStorages/$bundle_identifier"
            "$library_dir/HTTPStorages/$bundle_identifier.binarycookies"
            "$library_dir/WebKit/$bundle_identifier"
            "$library_dir/Cookies/$bundle_identifier.binarycookies"
            "$library_dir/Containers/$bundle_identifier"
            "$library_dir/Application Scripts/$bundle_identifier"
            "$library_dir/Logs/$bundle_identifier"
            "$library_dir/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/$bundle_identifier.sfl3"
        )
        if [[ "$test_mode" != "1" && "$dry_run" != true ]]; then
            defaults delete "$bundle_identifier" >/dev/null 2>&1 || true
        elif [[ "$dry_run" == true ]]; then
            run_label "删除偏好域：$bundle_identifier"
        fi
    done

    for purge_path in "${purge_paths[@]}"; do
        delete_private_path "$purge_path"
    done

    delete_matching_files \
        "$library_dir/Preferences/ByHost" \
        'com.torrance.torrancekit.*.plist' \
        'com.torrance.PasteNook.*.plist'
    delete_matching_files \
        "$library_dir/Logs/DiagnosticReports" \
        'TorranceKit_*.crash' 'TorranceKit_*.hang' 'TorranceKit_*.ips' \
        'PasteNook_*.crash' 'PasteNook_*.hang' 'PasteNook_*.ips'
    delete_matching_files \
        "$library_dir/Application Support/CrashReporter" \
        'TorranceKit_*.plist' 'PasteNook_*.plist'
fi

if [[ "$dry_run" == true ]]; then
    echo "预演完成；未修改本机。"
elif (( moved_app_count == 0 )); then
    echo "未找到已安装的 TorranceKit.app 或 PasteNook.app。"
fi

if [[ "$purge_data" == true && "$dry_run" != true ]]; then
    echo "卸载完成：应用已移出安装目录，本地数据和隐私权限记录已清理。"
elif [[ "$dry_run" != true ]]; then
    echo "卸载完成：本地历史和配置已保留。"
fi
