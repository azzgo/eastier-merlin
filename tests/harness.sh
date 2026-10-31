#!/bin/bash
# Test harness for easytier_config.sh — runs the script in an isolated fake
# /koolshare tree with mocked dbus/base.sh/binaries, using busybox ash.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_UNDER_TEST="$REPO/easytier/scripts/easytier_config.sh"
SANDBOX="${ET_SANDBOX:-/tmp/et_harness}"
MOCK="$REPO/tests/mock"

PASS=0
FAIL=0

setup_sandbox() {
    rm -rf "$SANDBOX"
    mkdir -p "$SANDBOX/koolshare/scripts" "$SANDBOX/koolshare/bin" \
        "$SANDBOX/koolshare/configs" "$SANDBOX/koolshare/webs" \
        "$SANDBOX/koolshare/res" "$SANDBOX/run" "$SANDBOX/upload"
    cp "$MOCK/lib/base.sh" "$SANDBOX/koolshare/scripts/base.sh"
    sed -e "s#/koolshare#$SANDBOX/koolshare#g" \
        -e "s#/var/run/easytier.pid#$SANDBOX/run/easytier.pid#" \
        -e "s#/var/lock/easytier.lock#$SANDBOX/run/easytier.lock#" \
        -e "s#/tmp/upload#$SANDBOX/upload#g" \
        "$SCRIPT_UNDER_TEST" > "$SANDBOX/koolshare/scripts/easytier_config.sh"
    chmod +x "$SANDBOX/koolshare/scripts/easytier_config.sh"
}

install_core() {
    local mode="$1"
    case "$mode" in
        ok)
            printf '#!/bin/sh\nexec sleep 60\n' > "$SANDBOX/koolshare/bin/easytier-core"
            ;;
        fail)
            printf '#!/bin/sh\necho "core: fatal config error" >&2\nexit 1\n' > "$SANDBOX/koolshare/bin/easytier-core"
            ;;
        missing)
            rm -f "$SANDBOX/koolshare/bin/easytier-core"
            ;;
    esac
    [ -f "$SANDBOX/koolshare/bin/easytier-core" ] && chmod +x "$SANDBOX/koolshare/bin/easytier-core"
}

run_script() {
    local argv="$1" env_over="$2"
    (
        export PATH="$MOCK/bin:$PATH"
        [ -n "$env_over" ] && eval "export $env_over"
        cd "$SANDBOX"
        eval "sh $SANDBOX/koolshare/scripts/easytier_config.sh $argv" 2>&1
    )
}

assert_eq() {
    local desc="$1" actual="$2" expected="$3"
    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS+1)); echo "  ok: $desc"
    else
        FAIL=$((FAIL+1))
        echo "  FAIL: $desc"
        echo "    expected: [$expected]"
        echo "    actual:   [$actual]"
    fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    case "$haystack" in
        *"$needle"*) PASS=$((PASS+1)); echo "  ok: $desc" ;;
        *)
            FAIL=$((FAIL+1))
            echo "  FAIL: $desc"
            echo "    expected to contain: [$needle]"
            echo "    haystack (first 500): $(printf '%s' "$haystack" | head -c 500)"
            ;;
    esac
}

assert_not_contains() {
    local desc="$1" haystack="$2" needle="$3"
    case "$haystack" in
        *"$needle"*)
            FAIL=$((FAIL+1))
            echo "  FAIL: $desc"
            echo "    must NOT contain: [$needle]"
            echo "    haystack (first 500): $(printf '%s' "$haystack" | head -c 500)"
            ;;
        *) PASS=$((PASS+1)); echo "  ok: $desc" ;;
    esac
}

section() { echo; echo "## $1"; }
