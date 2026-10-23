#!/bin/sh
# Usage: checks.sh <baseCommit> [repositoryDirectory]
# By default, resolve the repository from this script, not the caller's cwd.
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  printf 'Usage: %s <baseCommit> [repositoryDirectory]\n' "$0" >&2
  exit 2
fi

base_commit=$1
if [ "$#" -eq 2 ]; then
  cd -- "$2" || exit 2
else
  script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 2
  cd -- "$script_directory/.." || exit 2
fi

git rev-parse --verify "${base_commit}^{commit}" >/dev/null || exit 2

# Keep running independent checks, but retain any failure until the final exit.
# Do not pipe checks into tail/grep: their status would mask the check's status.
checks_status=0
run_check() {
  check_label=$1
  shift
  printf '\n== %s\n' "$check_label"
  if "$@"; then
    printf 'PASS: %s\n' "$check_label"
  else
    check_status=$?
    printf 'FAIL: %s (exit %s)\n' "$check_label" "$check_status" >&2
    checks_status=1
  fi
}

run_in_package() (
  package_directory=$1
  shift
  cd -- "$package_directory" || exit 2
  "$@"
)

run_check format dart format --output=none --set-exit-if-changed packages
for package_directory in packages/frost_ui packages/frost_window packages/frost_window/example packages/frost_ui_catalog; do
  run_check "analyze $package_directory" run_in_package "$package_directory" flutter analyze
done
run_check 'test ui' run_in_package packages/frost_ui flutter test
run_check 'test window' run_in_package packages/frost_window flutter test
run_check strings dart run tool/check_no_ui_strings.dart
run_check tokens dart run tool/check_tokens.dart --report
run_check 'diff check' git diff --check "$base_commit" HEAD

exit "$checks_status"
