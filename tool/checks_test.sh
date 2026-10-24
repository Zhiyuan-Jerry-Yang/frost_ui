#!/bin/sh
# Run with sh tool/checks_test.sh. Only fixture commands run, never Flutter/Dart.
set -eu
script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
temporary_root=$(CDPATH= cd -- "${TMPDIR:-/tmp}" && pwd -P)
fixture=$(mktemp -d "$temporary_root/frost-checks.XXXXXX")
# Only the absolute, freshly allocated fixture directory may be removed.
case "$fixture" in
  "$temporary_root"/frost-checks.*) ;;
  *) printf 'Unexpected fixture directory: %s\n' "$fixture" >&2; exit 1 ;;
esac
trap 'rm -rf -- "$fixture"' 0
trap 'exit 130' INT
trap 'exit 143' TERM
repository="$fixture/repository with spaces"
mkdir -p "$fixture/bin" "$repository/tool" "$repository/packages/frost_ui" \
  "$repository/packages/frost_window/example"
cp "$script_directory/checks.sh" "$repository/tool/checks.sh"
cat > "$fixture/bin/command" <<'STUB'
#!/bin/sh
if [ "${1-}" = rev-parse ]; then
  case "$3" in
    'invalid^{commit}') exit 128 ;;
    *) exit 0 ;;
  esac
fi
number=$(cat "$CHECKS_COUNTER")
number=$((number + 1))
printf '%s\n' "$number" > "$CHECKS_COUNTER"
printf 'fixture check %s\n' "$number"
if [ "$number" -eq "$CHECKS_FAIL_AT" ]; then
  printf 'original failure diagnostic\n' >&2
  printf 'last line of failed output\n' >&2
  exit 23
fi
STUB
chmod +x "$fixture/bin/command"
for command_name in dart flutter git; do
  cp "$fixture/bin/command" "$fixture/bin/$command_name"
done
PATH="$fixture/bin:$PATH"
CHECKS_COUNTER="$fixture/counter"
export PATH CHECKS_COUNTER

assert_run() {
  expected_status=$1
  expected_count=$2
  shift 2
  printf '0\n' > "$CHECKS_COUNTER"
  actual_status=0
  "$@" > "$fixture/output" 2>&1 || actual_status=$?
  actual_count=$(cat "$CHECKS_COUNTER")
  if [ "$actual_status" -ne "$expected_status" ] || [ "$actual_count" -ne "$expected_count" ]; then
    cat "$fixture/output" >&2
    printf 'Expected status/count %s/%s, got %s/%s\n' \
      "$expected_status" "$expected_count" "$actual_status" "$actual_count" >&2
    exit 1
  fi
  cases=$((cases + 1))
}

cases=0
CHECKS_FAIL_AT=0
export CHECKS_FAIL_AT
# Both invocation forms work from outside the repository, including spaced paths.
cd -- "$fixture"
assert_run 0 7 sh "$repository/tool/checks.sh" HEAD
assert_run 0 7 sh "$repository/tool/checks.sh" HEAD "$repository"

# Each check can fail independently; later successes must not erase that failure.
for CHECKS_FAIL_AT in 1 2 3 4 5 6 7; do
  assert_run 1 7 sh "$repository/tool/checks.sh" HEAD
  grep -q 'original failure diagnostic' "$fixture/output"
  grep -q 'exit 23' "$fixture/output"
done
CHECKS_FAIL_AT=0
assert_run 2 0 sh "$repository/tool/checks.sh"
assert_run 2 0 sh "$repository/tool/checks.sh" HEAD "$repository" extra
assert_run 2 0 sh "$repository/tool/checks.sh" HEAD "$fixture/missing"
assert_run 2 0 sh "$repository/tool/checks.sh" invalid

# A failed package cd must not run checks in the wrong directory.
rmdir "$repository/packages/frost_ui"
assert_run 1 5 sh "$repository/tool/checks.sh" HEAD
printf 'PASS: %s checks.sh regression cases (fixture commands only)\n' "$cases"
