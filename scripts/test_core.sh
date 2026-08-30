#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
sdk_path="${TORRANCEKIT_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
test_binary="$project_dir/.build/torrancekit-tests/core-tests"

mkdir -p "${test_binary:h}"
xcrun swiftc \
    -parse-as-library \
    -swift-version 5 \
    -target arm64-apple-macosx13.0 \
    -sdk "$sdk_path" \
    "$project_dir/Sources/TorranceKit/Models/ClipboardItem.swift" \
    "$project_dir/Sources/TorranceKit/Models/AppSettings.swift" \
    "$project_dir/Sources/TorranceKit/Services/AppPaths.swift" \
    "$project_dir/Sources/TorranceKit/Services/ClipboardHistory.swift" \
    "$project_dir/Tests/CoreTestRunner.swift" \
    -o "$test_binary"

"$test_binary"
