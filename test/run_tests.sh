#!/usr/bin/env bash
# Automated test runner using RunCPM.
# For each test case in test/cases/, copies the .COM to the RunCPM drive,
# feeds input.txt via stdin, and diffs output against expected.txt.
#
# NOTE: RunCPM does not run a single program and exit — it is an interactive
# CP/M shell. This script feeds a command sequence via stdin: the program name
# followed by ^C (to exit RunCPM). If your program is interactive and requires
# expect-style automation, add an expect script alongside input.txt and adjust
# the invocation here.
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNCPM="$REPO_DIR/tools/runcpm/RunCPM"
DRIVE_DIR="$REPO_DIR/tools/runcpm-drive"
CASES_DIR="$REPO_DIR/test/cases"
PASS=0
FAIL=0

if [ ! -f "$RUNCPM" ]; then
    echo "ERROR: RunCPM not found at $RUNCPM — run 'make setup' first."
    exit 1
fi

mkdir -p "$DRIVE_DIR/A/0"

for case_dir in "$CASES_DIR"/*/; do
    [ -d "$case_dir" ] || continue
    prog=$(basename "$case_dir")
    prog_upper=$(echo "$prog" | tr '[:lower:]' '[:upper:]')
    com_file="$REPO_DIR/build/${prog_upper}.COM"

    if [ ! -f "$com_file" ]; then
        echo "SKIP: $prog (no $com_file)"
        continue
    fi

    cp "$com_file" "$DRIVE_DIR/A/0/"

    input="$case_dir/input.txt"
    expected="$case_dir/expected.txt"

    # Feed: the program invocation from input.txt, then exit RunCPM
    actual=$(cd "$DRIVE_DIR" && (cat "$input"; printf '\x03') | timeout 10 "$RUNCPM" 2>/dev/null || true)

    # Strip RunCPM output noise and extract only the program's output:
    #   1. Strip ANSI escape sequences
    #   2. Strip carriage returns (\r) — RunCPM outputs CRLF line endings
    #   3. Process backspace sequences — RunCPM echoes typed chars as _\b \bX; collapse to X
    #   4. Extract lines between the first A0> prompt (command entry) and the next A0> prompt
    #   5. Remove trailing blank lines
    actual_clean=$(printf '%s' "$actual" \
        | sed 's/\x1b\[[?0-9;]*[a-zA-Z]//g' \
        | tr -d '\r' \
        | sed -e ':bs' -e 's/[^\x08]\x08//g' -e 't bs' \
        | awk '/^A0>/ && !found { found=1; next } /^A0>/ && found { exit } /^RunCPM Version/ && found { exit } found { print }' \
        | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

    if diff -q <(printf '%s\n' "$actual_clean") "$expected" > /dev/null 2>&1; then
        echo "PASS: $prog"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $prog"
        echo "  --- expected ---"
        cat "$expected"
        echo "  --- actual ---"
        printf '%s\n' "$actual_clean"
        echo "  --- diff ---"
        diff <(printf '%s\n' "$actual_clean") "$expected" || true
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
