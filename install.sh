#!/bin/zsh

set -euo pipefail

repository="${TORRANCEKIT_GITHUB_REPOSITORY:-TorranceZHANG/TorranceKit}"
requested_version="latest"
install_root="$HOME/Applications"
force_source=false

usage() {
    cat <<'EOF'
用法：install.sh [--version <版本>] [--system] [--source]

  --version <版本>  安装指定 Release，例如 0.1.0 或 v0.1.0
  --system          安装到 /Applications（需要 sudo）
  --source          跳过 Release，直接下载 main 源码快照构建
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
            shift
            ;;
        --source)
            force_source=true
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

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
    echo "TorranceKit 目前仅支持 Apple Silicon Mac。" >&2
    exit 1
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/torrancekit-install.XXXXXX")"
cleanup() {
    find "$temporary_directory" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

download() {
    local url="$1"
    local destination="$2"
    curl --fail --silent --show-error --location --retry 3 \
        --connect-timeout 15 \
        --output "$destination" \
        "$url"
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
        fi
        sudo ditto "$source_app" "$destination_app"
    else
        mkdir -p "$install_root"
        [[ ! -e "$destination_app" ]] || mv "$destination_app" "$backup_app"
        [[ ! -e "$legacy_app" ]] || mv "$legacy_app" "$legacy_backup_app"
        ditto "$source_app" "$destination_app"
    fi

    open "$destination_app"
    echo "TorranceKit 已安装到：$destination_app"
}

install_release() {
    local release_tag
    if [[ "$requested_version" == "latest" ]]; then
        local release_metadata="$temporary_directory/release.json"
        curl --fail --silent --location --retry 2 \
            --connect-timeout 15 \
            --output "$release_metadata" \
            "https://api.github.com/repos/$repository/releases/latest" \
            || return 1
        release_tag="$(plutil -extract tag_name raw -o - "$release_metadata" 2>/dev/null)"
        [[ -n "$release_tag" ]] || return 1
    else
        release_tag="v${requested_version#v}"
    fi

    local version="${release_tag#v}"
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
fi

install_source_snapshot
