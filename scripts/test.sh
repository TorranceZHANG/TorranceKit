#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"

"$project_dir/scripts/test_core.sh"

cd "$project_dir"
swift test list --enable-xctest --disable-swift-testing >/dev/null
test_bundle="$(swift build --show-bin-path)/TorranceKitPackageTests.xctest"

if [[ ! -d "$test_bundle" ]]; then
    echo "未找到 XCTest bundle：$test_bundle" >&2
    exit 1
fi

xcrun xctest "$test_bundle"
