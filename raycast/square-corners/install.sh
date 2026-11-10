#!/bin/bash
set -euo pipefail
# Use the existing Ammonia installation; do not change macOS security settings.
export DYLD_INSERT_LIBRARIES=
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
tweak_dir=/private/var/ammonia/core/tweaks
name=libraycast_square_corners.dylib
if [[ "$(uname -s)" != Darwin || ! -d "$tweak_dir" ]]; then
    echo 'This requires macOS with an existing Ammonia/Sharpener installation.' >&2
    exit 1
fi
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/raycast-corners.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
xcrun clang -dynamiclib -fobjc-arc -Wall -Wextra -Wno-unused-parameter \
    -framework AppKit "$source_dir/square-corners.m" -o "$build_dir/$name"
codesign --sign - "$build_dir/$name"
printf 'Raycast\n' > "$build_dir/$name.whitelist"
install_command=(install)
if [[ ! -w "$tweak_dir" ]]; then
    install_command=(sudo install)
fi
# Install the whitelist first so no other process loads the tweak.
"${install_command[@]}" -m 644 "$build_dir/$name.whitelist" "$tweak_dir/$name.whitelist"
"${install_command[@]}" -m 755 "$build_dir/$name" "$tweak_dir/$name.new"
if [[ -w "$tweak_dir" ]]; then
    mv -f "$tweak_dir/$name.new" "$tweak_dir/$name"
else
    sudo mv -f "$tweak_dir/$name.new" "$tweak_dir/$name"
fi
printf 'Installed. Use Raycast menu → Quit Raycast, then reopen it.\n'
