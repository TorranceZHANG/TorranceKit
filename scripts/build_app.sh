#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${CONFIGURATION:-release}"
app_name="TorranceKit"
bundle_dir="$project_dir/dist/$app_name.app"
build_dir="$project_dir/.build/torrancekit/$configuration"
binary_path="$build_dir/$app_name"
signing_identity="${CODE_SIGN_IDENTITY:--}"
sdk_path="${TORRANCEKIT_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
source_files=("$project_dir"/Sources/TorranceKit/**/*.swift(N))
app_version="${APP_VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"

if [[ ! "$app_version" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
    echo "APP_VERSION 必须是数字版本号，例如 0.1.0" >&2
    exit 2
fi
if [[ ! "$build_number" =~ '^[0-9]+$' ]]; then
    echo "BUILD_NUMBER 必须是正整数" >&2
    exit 2
fi

if [[ "$configuration" == "release" ]]; then
    optimization_flags=(-O -whole-module-optimization)
else
    optimization_flags=(-Onone -g)
fi

cd "$project_dir"
mkdir -p "$build_dir"
xcrun swiftc \
    -parse-as-library \
    -swift-version 5 \
    -target arm64-apple-macosx13.0 \
    -sdk "$sdk_path" \
    "${optimization_flags[@]}" \
    "${source_files[@]}" \
    -o "$binary_path"

if [[ -d "$bundle_dir" ]]; then
    find "$bundle_dir" -depth -delete
fi
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Resources"
cp "$binary_path" "$bundle_dir/Contents/MacOS/$app_name"
cp "$project_dir/Resources/Info.plist" "$bundle_dir/Contents/Info.plist"
"$project_dir/scripts/generate_icon.sh" "$bundle_dir/Contents/Resources/TorranceKit.icns"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $app_version" \
    -c "Set :CFBundleVersion $build_number" \
    "$bundle_dir/Contents/Info.plist"

signing_arguments=(
    --force
    --deep
    --sign "$signing_identity"
    --identifier "com.torrance.torrancekit"
)
if [[ "$signing_identity" != "-" ]]; then
    signing_arguments+=(--options runtime --timestamp)
fi
codesign "${signing_arguments[@]}" "$bundle_dir"

echo "$bundle_dir"
