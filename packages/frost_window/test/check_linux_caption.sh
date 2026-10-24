#!/bin/sh
# Run under the target Linux display session after Flutter has prepared a runner.
# Usage: sh packages/frost_window/test/check_linux_caption.sh /path/to/app/linux/flutter/ephemeral
set -eu
if [ "$#" -ne 1 ]; then
  printf 'Usage: %s <flutter-linux-ephemeral-directory>\n' "$0" >&2
  exit 2
fi
engine=$(CDPATH= cd -- "$1" && pwd)
repository=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
mkdir -p "$repository/build/caption-checks"
c++ -std=c++17 -Wall -Wextra -Werror -Wno-unused-parameter \
  "$repository/packages/frost_window/test/linux_caption_probe.cc" \
  "$repository/packages/frost_window/linux/caption_appearance.cc" \
  -I"$engine" -L"$engine" -Wl,-rpath,"$engine" -lflutter_linux_gtk \
  $(pkg-config --cflags --libs gtk+-3.0) \
  -o "$repository/build/caption-checks/linux-caption-probe"
"$repository/build/caption-checks/linux-caption-probe"
