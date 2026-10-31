#!/bin/bash
# Regression cases derived from real router contract capture
# (tests/fixtures/contract/contract.tgz, 86 calls, 2026-10-31).

REPO="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO/tests/harness.sh"

ENCODED_CFG='aW5zdGFuY2VfbmFtZSA9ICJleGFtcGxlLW5vZGUiCmluc3RhbmNlX2lkID0gIjAwMDAwMDAwLTAwMDAtNDAwMC04MDAwLTAwMDAwMDAwMDAwMCIKZGhjcCA9IGZhbHNlCmlwdjQgPSAiMTAuMTI2LjEyNi4xMCIKbGlzdGVuZXJzID0gWwogICAgInRjcDovLzAuMC4wLjA6MTEwMTAiLAogICAgInVkcDovLzAuMC4wLjA6MTEwMTAiLAogICAgIndnOi8vMC4wLjAuMDoxMTAxMSIsCl0KCltuZXR3b3JrX2lkZW50aXR5XQpuZXR3b3JrX25hbWUgPSAiZXhhbXBsZS1uZXR3b3JrIgpuZXR3b3JrX3NlY3JldCA9ICJleGFtcGxlLXNlY3JldCIKCltbcGVlcl1dCnVyaSA9ICJ0Y3A6Ly8xOTguNTEuMTAwLjEwOjExMDEwIgoKW2ZsYWdzXQo='

# fields as exported by the software-center framework for a save_config submit
SAVE_FIELDS="easytier_config_content_encoded='$ENCODED_CFG' easytier_config_content=''"

setup_sandbox

section "T1: status polling (contract call #01: 'id status', no fields)"
install_core ok
sh "$SANDBOX/koolshare/bin/easytier-core" & echo $! > "$SANDBOX/run/easytier.pid"
OUT=$(run_script "46191478 status" "")
CODE=$?
assert_eq "exit code is 0" "$CODE" "0"
assert_contains "stdout has bare status word 运行" "$OUT" "运行"
assert_not_contains "no '未知的操作' error" "$OUT" "未知的操作"
assert_not_contains "no web_submit branch" "$OUT" "开始处理Web提交"
assert_not_contains "no dbus export leak in output" "$OUT" "easytier_config_content_encoded"

section "T2: status while stopped"
rm -f "$SANDBOX/run/easytier.pid"
OUT=$(run_script "55018858 status" "")
CODE=$?
assert_eq "exit code is 0" "$CODE" "0"
assert_contains "stdout has 停止" "$OUT" "停止"

section "T3: status with dead PID"
echo 999999 > "$SANDBOX/run/easytier.pid"
OUT=$(run_script "85477450 status" "")
assert_contains "stdout has 异常" "$OUT" "异常"
rm -f "$SANDBOX/run/easytier.pid"

section "T4: save_config web_submit (contract call #04: 'id save_config web_submit' + fields)"
install_core ok
OUT=$(run_script "68030339 save_config web_submit" "$SAVE_FIELDS")
CODE=$?
assert_eq "exit code is 0" "$CODE" "0"
assert_contains "config saved ok" "$OUT" "配置保存成功"
assert_contains "decoded config written to file" "$(cat "$SANDBOX/koolshare/configs/easytier.conf")" "network_name = \"example-network\""

section "T5: start web_submit, core ok (contract call #13)"
OUT=$(run_script "11453608 start web_submit" "$SAVE_FIELDS")
assert_contains "service started" "$OUT" "服务启动成功"
assert_contains "pid file written" "$(cat "$SANDBOX/run/easytier.pid" 2>/dev/null)" ""
kill "$(cat "$SANDBOX/run/easytier.pid")" 2>/dev/null; rm -f "$SANDBOX/run/easytier.pid"

section "T6: start web_submit, core exits immediately -> must report failure"
install_core fail
OUT=$(run_script "90000001 start web_submit" "$SAVE_FIELDS")
assert_contains "failure reported to log" "$OUT" "启动失败"
assert_not_contains "no false success" "$OUT" "服务启动成功"
[ -f "$SANDBOX/run/easytier.pid" ] && {
    assert_eq "pid file cleaned" "absent" "present"
} || assert_eq "pid file cleaned" "absent" "absent"

section "T7: start web_submit, binary missing -> must report failure"
install_core missing
OUT=$(run_script "90000002 start web_submit" "$SAVE_FIELDS")
assert_contains "failure reported" "$OUT" "启动失败"
assert_not_contains "no false success" "$OUT" "服务启动成功"

section "T8: stop web_submit (contract call #10)"
install_core ok
run_script "90000003 start web_submit" "$SAVE_FIELDS" > /dev/null
PID=$(cat "$SANDBOX/run/easytier.pid")
OUT=$(run_script "29355685 stop web_submit" "")
assert_contains "service stopped" "$OUT" "服务停止成功"
[ -f "$SANDBOX/run/easytier.pid" ] && assert_eq "pid removed" "present" "absent" || assert_eq "pid removed" "x" "x"

section "T9: save_autostart web_submit (contract call #47: only autostart in fields)"
OUT=$(run_script "11807023 save_autostart web_submit" "easytier_autostart='1'")
assert_contains "autostart saved" "$OUT" "自启动配置保存成功"

section "T10: log file survives status polling"
run_script "1 status" "" > /dev/null
LOGSZ1=$(wc -c < "$SANDBOX/upload/easytier_log.txt" 2>/dev/null || echo 0)
run_script "2 status" "" > /dev/null
LOGSZ2=$(wc -c < "$SANDBOX/upload/easytier_log.txt" 2>/dev/null || echo 0)
assert_not_contains "polling did not truncate log to zero" "size=$LOGSZ2" "size=0"

section "T11: dbus export alone must not flip script into web_submit"
OUT=$(run_script "3 status" "")
assert_not_contains "dbus-polluted env must not trigger web branch" "$OUT" "未知的操作"

echo
echo "=============================="
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
