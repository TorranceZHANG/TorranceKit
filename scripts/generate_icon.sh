#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
source_svg="$project_dir/Resources/AppIcon.svg"
output_icns="${1:-$project_dir/.build/torrancekit/AppIcon.icns}"
temporary_dir="$(mktemp -d)"
iconset_dir="$temporary_dir/TorranceKit.iconset"
master_png="$temporary_dir/icon_1024.png"

cleanup() {
    find "$temporary_dir" -depth -delete
}
trap cleanup EXIT

mkdir -p "$iconset_dir" "${output_icns:h}"
sips -s format png -z 1024 1024 "$source_svg" --out "$master_png" >/dev/null

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$master_png" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$master_png" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$iconset_dir" -o "$output_icns"
