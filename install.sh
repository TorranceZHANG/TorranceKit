#!/bin/zsh

set -euo pipefail

repository="${TORRANCEKIT_GITHUB_REPOSITORY:-TorranceZHANG/TorranceKit}"
requested_version="latest"
install_root="$HOME/Applications"
force_source=false
update_only=false
check_only=false
force_reinstall=false
system_install_requested=false
current_version=""

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

usage() {
    cat <<'EOF'
用法：install.sh [--version <版本>] [--system] [--source]
      install.sh --update [--system] [--force]
      install.sh --check [--system]

  --version <版本>  安装指定 Release，例如 0.1.0 或 v0.1.0
  --system          安装到 /Applications（需要 sudo）
  --source          跳过 Release，直接下载 main 源码快照构建
  --update          仅在存在更新的正式 Release 时安装
  --check           只检查是否存在更新，不修改已安装的 App
  --force           配合 --update，重新安装相同版本
  -h, --help        显示帮助

环境变量：
  TORRANCEKIT_GITHUB_REPOSITORY  GitHub 仓库，默认 TorranceZHANG/TorranceKit
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] || { echo "--version 缺少版本号" >&2; exit 2; }
            requested_version="$2"
            shift 2
            ;;
        --system)
            install_root="/Applications"
            system_install_requested=true
            shift
            ;;
        --source)
            force_source=true
            shift
            ;;
        --update)
            update_only=true
            shift
            ;;
        --check)
            update_only=true
            check_only=true
            shift
            ;;
        --force)
            force_reinstall=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "未知参数：$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$requested_version" != "latest" && ! "$requested_version" =~ '^v?[0-9]+(\.[0-9]+){1,2}$' ]]; then
    echo "--version 必须是数字版本号，例如 0.1.0 或 v0.1.0" >&2
    exit 2
fi
if [[ "$update_only" == true && "$requested_version" != "latest" ]]; then
    echo "--update/--check 不能与 --version 同时使用" >&2
    exit 2
fi
if [[ "$update_only" == true && "$force_source" == true ]]; then
    echo "--update/--check 只使用正式 Release，不能与 --source 同时使用" >&2
    exit 2
fi
if [[ "$force_reinstall" == true && "$update_only" == false ]]; then
    echo "--force 只能与 --update 一起使用" >&2
    exit 2
fi
if [[ "$check_only" == true && "$force_reinstall" == true ]]; then
    echo "--check 不能与 --force 同时使用" >&2
    exit 2
fi

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "TorranceKit 目前仅支持 Apple Silicon Mac。" >&2
    exit 1
fi

if [[ "$update_only" == true ]]; then
    user_app="$HOME/Applications/TorranceKit.app"
    system_app="/Applications/TorranceKit.app"

    if [[ "$system_install_requested" == true ]]; then
        [[ -d "$system_app" ]] \
            || { echo "没有在 /Applications 中找到 TorranceKit.app。" >&2; exit 1; }
    elif [[ -d "$user_app" ]]; then
        install_root="$HOME/Applications"
    elif [[ -d "$system_app" ]]; then
        install_root="/Applications"
    else
        echo "没有找到已安装的 TorranceKit，请先运行安装脚本。" >&2
        exit 1
    fi

    installed_app="$install_root/TorranceKit.app"
    current_version="$(plutil -extract CFBundleShortVersionString raw "$installed_app/Contents/Info.plist" 2>/dev/null || true)"
    if [[ ! "$current_version" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
        echo "无法读取已安装 TorranceKit 的版本号：$installed_app" >&2
        exit 1
    fi
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/torrancekit-install.XXXXXX")"
cleanup() {
    find "$temporary_directory" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

download() {
    local url="$1"
    local destination="$2"
    curl --fail --show-error --location --retry 3 \
        --connect-timeout 15 \
        --max-time 900 \
        --progress-bar \
        --output "$destination" \
        "$url"
}

resolve_latest_release_tag() {
    local effective_url
    echo "正在检查 TorranceKit 正式版本…" >&2
    effective_url="$(
        curl --fail --silent --show-error --location --retry 2 \
            --connect-timeout 15 \
            --max-time 60 \
            --output /dev/null \
            --write-out '%{url_effective}' \
            "https://github.com/$repository/releases/latest"
    )" || return 1
    [[ "$effective_url" == */releases/tag/v* ]] || return 1
    local release_tag="${effective_url##*/}"
    [[ "$release_tag" =~ '^v[0-9]+(\.[0-9]+){1,2}$' ]] || return 1
    print -r -- "$release_tag"
}

version_is_newer() {
    local candidate="$1"
    local installed="$2"
    local -a candidate_parts installed_parts
    candidate_parts=("${(@s:.:)candidate}")
    installed_parts=("${(@s:.:)installed}")

    local index candidate_part installed_part
    for index in 1 2 3; do
        candidate_part="${candidate_parts[$index]:-0}"
        installed_part="${installed_parts[$index]:-0}"
        if (( candidate_part > installed_part )); then
            return 0
        fi
        if (( candidate_part < installed_part )); then
            return 1
        fi
    done
    return 1
}

install_application() {
    local source_app="$1"
    local destination_app="$install_root/TorranceKit.app"
    local trash_directory="$HOME/.Trash"
    local timestamp="$(date +%Y%m%d-%H%M%S)-$$"
    local backup_app="$trash_directory/TorranceKit-replaced-$timestamp.app"
    local legacy_app="$install_root/PasteNook.app"
    local legacy_backup_app="$trash_directory/PasteNook-renamed-$timestamp.app"

    [[ -d "$source_app" ]] || { echo "安装包中缺少 TorranceKit.app" >&2; exit 1; }
    [[ "$(plutil -extract CFBundleIdentifier raw "$source_app/Contents/Info.plist")" == "com.torrance.torrancekit" ]] \
        || { echo "应用 Bundle ID 校验失败" >&2; exit 1; }
    file "$source_app/Contents/MacOS/TorranceKit" | grep -q 'arm64' \
        || { echo "应用不是 arm64 构建" >&2; exit 1; }
    codesign --verify --deep --strict "$source_app"

    mkdir -p "$trash_directory"
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
        fi
        sudo ditto "$source_app" "$destination_app"
    else
        mkdir -p "$install_root"
        [[ ! -e "$destination_app" ]] || mv "$destination_app" "$backup_app"
        [[ ! -e "$legacy_app" ]] || mv "$legacy_app" "$legacy_backup_app"
        ditto "$source_app" "$destination_app"
    fi

    launch_application_in_background "$destination_app"
    local installed_version="$(plutil -extract CFBundleShortVersionString raw "$destination_app/Contents/Info.plist")"
    echo "TorranceKit $installed_version 已安装并在后台运行：$destination_app"
    echo "从“应用程序”再次打开，或使用全局快捷键即可显示剪贴板。"
}

install_release() {
    local release_tag
    if [[ "$requested_version" == "latest" ]]; then
        release_tag="$(resolve_latest_release_tag)" || return 1
    else
        release_tag="v${requested_version#v}"
    fi

    local version="${release_tag#v}"
    if [[ "$update_only" == true ]]; then
        if version_is_newer "$version" "$current_version"; then
            if [[ "$check_only" == true ]]; then
                echo "发现新版本：$current_version → $version"
                return 0
            fi
            echo "发现新版本：$current_version → $version"
        elif [[ "$version" == "$current_version" ]]; then
            if [[ "$force_reinstall" == true ]]; then
                echo "正在重新安装 TorranceKit $version…"
            else
                echo "TorranceKit $current_version 已是最新版本。"
                return 0
            fi
        else
            echo "当前版本 $current_version 比最新正式版本 $version 更新，无需处理。"
            return 0
        fi
    fi

    local archive_name="TorranceKit-$version-macOS-arm64.zip"
    local release_base_url="https://github.com/$repository/releases/download/$release_tag"
    local archive="$temporary_directory/$archive_name"
    local checksum="$archive.sha256"

    echo "正在下载 TorranceKit $version…"
    download "$release_base_url/$archive_name" "$archive" || return 1
    download "$release_base_url/$archive_name.sha256" "$checksum" || return 1

    local expected_checksum="$(awk 'NR == 1 { print $1 }' "$checksum")"
    local actual_checksum="$(shasum -a 256 "$archive" | awk '{ print $1 }')"
    [[ -n "$expected_checksum" && "$actual_checksum" == "$expected_checksum" ]] \
        || { echo "SHA-256 校验失败，已取消安装。" >&2; exit 1; }

    local extracted_directory="$temporary_directory/release"
    mkdir -p "$extracted_directory"
    ditto -x -k "$archive" "$extracted_directory"
    install_application "$extracted_directory/TorranceKit.app"
}

install_source_snapshot() {
    command -v xcrun >/dev/null 2>&1 \
        || { echo "尚无可用 Release，从源码安装需要完整 Xcode。" >&2; exit 1; }
    xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1 \
        || { echo "尚无可用 Release，请先安装并选中完整 Xcode。" >&2; exit 1; }

    echo "尚无可用 Release，正在下载 main 源码快照并本地构建…"
    local source_archive="$temporary_directory/source.zip"
    local source_root="$temporary_directory/source"
    download "https://github.com/$repository/archive/refs/heads/main.zip" "$source_archive"
    mkdir -p "$source_root"
    ditto -x -k "$source_archive" "$source_root"

    local source_directory=("$source_root"/*(N/))
    [[ ${#source_directory[@]} -eq 1 && -x "${source_directory[1]}/scripts/install.sh" ]] \
        || { echo "源码快照结构校验失败" >&2; exit 1; }

    if [[ "$install_root" == "/Applications" ]]; then
        "${source_directory[1]}/scripts/install.sh" --system
    else
        "${source_directory[1]}/scripts/install.sh"
    fi
}

if [[ "$force_source" == false ]]; then
    if install_release; then
        exit 0
    fi
    if [[ "$requested_version" != "latest" ]]; then
        echo "未找到 TorranceKit ${requested_version#v} 的 Release 安装包。" >&2
        exit 1
    fi
    if [[ "$update_only" == true ]]; then
        echo "无法获取最新 TorranceKit Release。请检查网络，或确认仓库已经发布正式版本。" >&2
        exit 1
    fi
fi

install_source_snapshot
