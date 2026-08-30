#!/bin/zsh

set -euo pipefail

repository="${TORRANCEKIT_GITHUB_REPOSITORY:-TorranceZHANG/TorranceKit}"
script_directory="${0:A:h}"
local_installer="$script_directory/install.sh"

if [[ "${0:t}" == "update.sh" && -f "$local_installer" ]]; then
    exec zsh "$local_installer" --update "$@"
fi

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/torrancekit-update.XXXXXX")"
cleanup() {
    find "$temporary_directory" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT INT TERM

installer="$temporary_directory/install.sh"
echo "正在获取 TorranceKit 更新程序…"
curl --fail --show-error --location --retry 3 \
    --connect-timeout 15 \
    --max-time 60 \
    --progress-bar \
    --output "$installer" \
    "https://raw.githubusercontent.com/$repository/main/install.sh"

zsh "$installer" --update "$@"
