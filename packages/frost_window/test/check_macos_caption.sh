#!/bin/sh
# Usage: sh packages/frost_window/test/check_macos_caption.sh <directory-containing-FlutterMacOS.framework>
set -eu
if [ "$#" -ne 1 ]; then
  printf 'Usage: %s <flutter-macos-framework-directory>\n' "$0" >&2
  exit 2
fi
frameworks=$(CDPATH= cd -- "$1" && pwd)
repository=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
mkdir -p "$repository/build/caption-checks"
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macos12.0" \
  -F "$frameworks" -framework FlutterMacOS -Xlinker -rpath -Xlinker "$frameworks" \
  "$repository/packages/frost_window/macos/frost_window/Sources/frost_window/FrostWindowPlugin.swift" \
  "$repository/packages/frost_window/test/macos_caption_probe.swift" \
  -o "$repository/build/caption-checks/macos-caption-probe"
"$repository/build/caption-checks/macos-caption-probe"
