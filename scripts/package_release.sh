#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
default_version="$(tr -d '[:space:]' < "$project_dir/VERSION")"
version="${1:-$default_version}"
archive="$project_dir/dist/TorranceKit-$version-macOS-arm64.zip"

APP_VERSION="$version" "$project_dir/scripts/build_app.sh"
rm -f "$archive"
ditto -c -k --norsrc --keepParent \
    "$project_dir/dist/TorranceKit.app" \
    "$archive"
(
    cd "${archive:h}"
    shasum -a 256 "${archive:t}" > "${archive:t}.sha256"
)

echo "$archive"
