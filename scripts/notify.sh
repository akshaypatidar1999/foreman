#!/bin/bash
# Foreman Notification hook: show the event message as a macOS banner.
# Idle-prompt events fire ~60s after every turn the manager has not replied to,
# so they are dropped; only permission prompts and foreman's own pushes banner.
msg=$(/usr/bin/python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
m = (d.get("message") or "").replace("\n", " ")
if d.get("notification_type") == "idle_prompt" or "waiting for your input" in m:
    raise SystemExit(3)
print(m)
' 2>/dev/null) || exit 0
[ -z "$msg" ] && msg="Claude Code needs you"

if [ -n "${FOREMAN_NOTIFY_DRY_RUN:-}" ]; then
  echo "$msg"
  exit 0
fi
[ -x /usr/bin/osascript ] || exit 0
/usr/bin/osascript -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title "Claude Code" sound name "Glass"' \
  -e 'end run' -- "$msg" >/dev/null 2>&1
exit 0
