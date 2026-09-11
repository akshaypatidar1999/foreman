# Foreman Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the agent team as the `foreman` Claude Code plugin in `surajgour-d11/foreman`, installable by team members with two commands plus a setup skill.

**Architecture:** A single repo that is both marketplace and plugin. Agents are verbatim copies of the four role files. Standing orders are injected by a SessionStart hook. A `/foreman:setup` skill runs a Python doctor and applier for everything a plugin cannot set itself. All scripts depend only on macOS system binaries.

**Tech Stack:** Claude Code 2.1.267 plugin system (manifest, hooks, agents, skills, userConfig, dependencies); bash; `/usr/bin/python3` 3.9; `gh`.

**Spec:** `docs/design.md`

## Global Constraints

- Repo root is `~/Public/foreman`, remote `git@github.com:surajgour-d11/foreman.git`. Task 1 commits to `main`; every later task commits to branch `feat/plugin-v0.1`.
- Scripts use `/usr/bin/python3` and `/bin/bash` only; no third-party packages; Python code must run on 3.9 (no `match`, no `X | Y` types).
- Hooks exit 0 always and produce no stderr on the happy path.
- Agent files are byte-identical copies of `~/.claude/agents/*.md` at the time of Task 3.
- `orders.md` stays under 80 lines and is the only place the standing orders live in the plugin.
- Plugin name `foreman`, version `0.1.0` in `plugin.json` only. Author `Suraj Gour`, `https://github.com/surajgour-d11`. License MIT.
- Quality standards from the team design apply to every file here: thin docs, comments only where code cannot say it, one meaningful commit per task at the end.
- Verified harness facts: agents in plugins load as `foreman:<name>`; `userConfig` booleans reach hooks as `CLAUDE_PLUGIN_OPTION_KEEP_AWAKE`; `${CLAUDE_PLUGIN_ROOT}` is exported to hook processes; SessionStart hook JSON `hookSpecificOutput.additionalContext` reaches the model and `systemMessage` is shown to the user.

---

### Task 1: Scaffold on main and open the feature branch

**Files:**
- Create: `README.md`, `LICENSE`, `CHANGELOG.md`, `.gitignore`

**Interfaces:**
- Produces: branch `main` with one commit on the remote; local branch `feat/plugin-v0.1` for all later tasks.

- [ ] **Step 1: Write the scaffold files**

```bash
cd ~/Public/foreman
cat > README.md <<'EOF'
# Foreman

Run Claude Code as a small software team that reports to you. Four roles
(architect, implementer, reviewer, qa), a lead with standing orders, two
approval gates, escalation to your desktop and phone, and work that survives
interruptions.

Full install and usage instructions land with the first release.
EOF
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Suraj Gour

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
cat > CHANGELOG.md <<'EOF'
# Changelog

## Unreleased
EOF
printf '.superpowers/\n__pycache__/\n.DS_Store\n' > .gitignore
```

- [ ] **Step 2: Commit to main and push**

```bash
cd ~/Public/foreman && git add README.md LICENSE CHANGELOG.md .gitignore docs/design.md docs/superpowers/plans/2026-09-11-foreman-plugin.md
git commit -m "Scaffold the foreman plugin repo with design and plan"
git push -u origin main
```

Expected: push succeeds; `gh repo view surajgour-d11/foreman --json defaultBranchRef` shows `main`.

- [ ] **Step 3: Open the feature branch**

```bash
cd ~/Public/foreman && git checkout -b feat/plugin-v0.1 && git branch --show-current
```

Expected: `feat/plugin-v0.1`.

---

### Task 2: Manifests

**Files:**
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: plugin id `foreman@foreman`; option env var `CLAUDE_PLUGIN_OPTION_KEEP_AWAKE` for Task 5. The superpowers dependency is declared cross-marketplace because a bare name resolves only inside the foreman marketplace.

- [ ] **Step 1: Run validation to see it fail**

Run: `cd ~/Public/foreman && claude plugin validate .`
Expected: an error about a missing manifest or marketplace.

- [ ] **Step 2: Write both manifests**

```bash
cd ~/Public/foreman && mkdir -p .claude-plugin
cat > .claude-plugin/plugin.json <<'EOF'
{
  "name": "foreman",
  "displayName": "Foreman",
  "version": "0.1.0",
  "description": "Run Claude Code as a software team: architect, implementer, reviewer, and qa roles under a lead that reports to you.",
  "author": { "name": "Suraj Gour", "url": "https://github.com/surajgour-d11" },
  "repository": "https://github.com/surajgour-d11/foreman",
  "license": "MIT",
  "keywords": ["team", "agents", "review", "workflow"],
  "dependencies": [{ "name": "superpowers", "marketplace": "claude-plugins-official" }],
  "userConfig": {
    "keep_awake": {
      "type": "boolean",
      "title": "Keep the Mac awake",
      "description": "Run caffeinate for the life of each session so unattended work is not cut short by idle sleep.",
      "default": true
    }
  }
}
EOF
cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "foreman",
  "description": "Foreman: run Claude Code as a software team that reports to you.",
  "owner": { "name": "Suraj Gour", "url": "https://github.com/surajgour-d11" },
  "allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"],
  "plugins": [
    {
      "name": "foreman",
      "source": "./",
      "description": "Run Claude Code as a software team that reports to you."
    }
  ]
}
EOF
```

- [ ] **Step 3: Validate**

Run: `cd ~/Public/foreman && claude plugin validate . && claude plugin validate --strict .claude-plugin/plugin.json`
Expected: both pass. With both manifests present, `validate .` checks only marketplace.json, so the second command is what validates the plugin manifest.

- [ ] **Step 4: Commit**

```bash
cd ~/Public/foreman && git add .claude-plugin && git commit -m "Add plugin and marketplace manifests"
```

---

### Task 3: Agents

**Files:**
- Create: `agents/architect.md`, `agents/implementer.md`, `agents/reviewer.md`, `agents/qa.md`

**Interfaces:**
- Consumes: `~/.claude/agents/*.md`, the verified role files.
- Produces: agent types `foreman:architect`, `foreman:implementer`, `foreman:reviewer`, `foreman:qa`.

- [ ] **Step 1: Write the failing check**

```bash
cd ~/Public/foreman && for r in architect implementer reviewer qa; do cmp -s ~/.claude/agents/$r.md agents/$r.md && echo "same $r" || echo "DIFF $r"; done
```

Expected: four `DIFF` lines (files absent).

- [ ] **Step 2: Copy verbatim**

```bash
cd ~/Public/foreman && mkdir -p agents && cp ~/.claude/agents/{architect,implementer,reviewer,qa}.md agents/
```

- [ ] **Step 3: Verify identical and well-formed**

```bash
cd ~/Public/foreman && for r in architect implementer reviewer qa; do cmp -s ~/.claude/agents/$r.md agents/$r.md && echo "same $r" || echo "DIFF $r"; done
/usr/bin/python3 - <<'EOF'
import re
want = {"architect": ("inherit", "purple"), "implementer": ("inherit", "green"), "reviewer": ("opus", "orange"), "qa": ("sonnet", "cyan")}
for r, (model, color) in want.items():
    t = open(f"agents/{r}.md").read()
    fm = re.match(r"^---\n(.*?)\n---\n", t, re.S).group(1)
    kv = {k.strip(): v.strip() for k, v in (l.split(":", 1) for l in fm.splitlines() if ":" in l and not l.startswith(" "))}
    assert kv["name"] == r and kv["model"] == model and kv["color"] == color, r
print("agents: OK")
EOF
```

Expected: four `same` lines and `agents: OK`.

- [ ] **Step 4: Commit**

```bash
cd ~/Public/foreman && git add agents && git commit -m "Add the four team roles as plugin agents"
```

---

### Task 4: Standing orders

**Files:**
- Create: `orders.md`

**Interfaces:**
- Consumes: `~/.claude/CLAUDE.md`.
- Produces: the text Task 5's hook injects. First line is `# Standing orders for the lead`; Task 6's doctor uses that line to detect a manual-install leftover in `~/.claude/CLAUDE.md`.

- [ ] **Step 1: Write the failing check**

```bash
cd ~/Public/foreman && /usr/bin/python3 - <<'EOF'
t = open("orders.md").read()
assert t.count("\n") < 80
assert t.startswith("# Standing orders for the lead\n")
for n in ("`foreman:architect`", "`foreman:implementer`", "`foreman:reviewer`", "`foreman:qa`"):
    assert n in t, n
assert "~/.claude/agents" not in t
assert "SessionStart hook reports an unfinished ledger" in t
print("orders.md: OK")
EOF
```

Expected: `FileNotFoundError`.

- [ ] **Step 2: Derive orders.md from CLAUDE.md with the four name edits**

```bash
cd ~/Public/foreman && /usr/bin/python3 - <<'EOF'
s = open("/Users/suraj/.claude/CLAUDE.md").read()
def rep(old, new):
    global s
    assert s.count(old) == 1, old[:60]
    s = s.replace(old, new)
rep("Four roles live in `~/.claude/agents`: architect, implementer, reviewer, qa.",
    "Four roles ship with the foreman plugin: `foreman:architect`, `foreman:implementer`, `foreman:reviewer`, `foreman:qa`.")
rep("Every implementer dispatch uses the `implementer` agent type; every per-task review uses one `reviewer`.",
    "Every implementer dispatch uses the `foreman:implementer` agent type; every per-task review uses one `foreman:reviewer`.")
rep("6. QA: dispatch `qa` on the branch.", "6. QA: dispatch `foreman:qa` on the branch.")
rep("Spawn two teammates from the same agent file named", "Spawn two teammates from the same foreman agent type named")
open("orders.md", "w").write(s)
print("orders.md written,", s.count("\n"), "lines")
EOF
```

- [ ] **Step 3: Run the check**

Run the Step 1 python block.
Expected: `orders.md: OK`.

- [ ] **Step 4: Commit**

```bash
cd ~/Public/foreman && git add orders.md && git commit -m "Add the lead's standing orders"
```

---

### Task 5: Hooks

**Files:**
- Create: `hooks/hooks.json`, `scripts/session-start.sh`, `scripts/notify.sh`, `scripts/selftest.sh`

**Interfaces:**
- Consumes: `orders.md` (Task 4); `CLAUDE_PLUGIN_OPTION_KEEP_AWAKE` (Task 2); `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PID` from the harness.
- Produces: SessionStart JSON with `hookSpecificOutput.additionalContext` (orders, plus ledger notice when present) and `systemMessage` (ledger notice only); Notification banner.

- [ ] **Step 1: Write the failing self-test**

```bash
cd ~/Public/foreman && mkdir -p scripts && cat > scripts/selftest.sh <<'EOF'
#!/bin/bash
# Runnable check for the foreman hooks. Exit 0 means both behave.
s="$(cd "$(dirname "$0")" && pwd)"
py=/usr/bin/python3

out=$(echo '{"hook_event_name":"Notification","message":"Decision needed: new dependency","notification_type":"idle_prompt"}' | NOTIFY_DRY_RUN=1 "$s/notify.sh")
[ "$out" = "Decision needed: new dependency" ] || { echo "FAIL notify message: '$out'"; exit 1; }
out=$(echo 'not json' | NOTIFY_DRY_RUN=1 "$s/notify.sh")
[ "$out" = "Claude Code needs you" ] || { echo "FAIL notify fallback: '$out'"; exit 1; }

tmp=$(mktemp -d)
out=$(cd "$tmp" && CLAUDE_PID=$$ "$s/session-start.sh")
echo "$out" | $py -c '
import json, sys
d = json.load(sys.stdin)
ctx = d["hookSpecificOutput"]["additionalContext"]
assert d["hookSpecificOutput"]["hookEventName"] == "SessionStart"
assert "# Standing orders for the lead" in ctx, "orders missing"
assert "systemMessage" not in d, "unexpected systemMessage outside a repo"
' || { echo "FAIL session-start orders/no-ledger case"; exit 1; }
pgrep -f "caffeinate -i -w $$" >/dev/null || { echo "FAIL caffeinate not started by default"; exit 1; }

bash -c "CLAUDE_PLUGIN_OPTION_KEEP_AWAKE=false CLAUDE_PID=\$\$ '$s/session-start.sh' >/dev/null; pgrep -f \"caffeinate -i -w \$\$\" >/dev/null && echo STARTED" | grep -q STARTED && { echo "FAIL caffeinate started despite keep_awake=false"; exit 1; }

git -C "$tmp" init -q
mkdir -p "$tmp/.superpowers/sdd/demo"
printf '# SDD ledger — plan: docs/plan.md\nPhase: execution\n' > "$tmp/.superpowers/sdd/demo/progress.md"
out=$(cd "$tmp" && CLAUDE_PID=$$ "$s/session-start.sh")
echo "$out" | $py -c '
import json, sys
d = json.load(sys.stdin)
assert "progress.md" in d["systemMessage"] and "Phase: execution" in d["systemMessage"], d.get("systemMessage")
assert "Do not resume on your own" in d["hookSpecificOutput"]["additionalContext"]
' || { echo "FAIL ledger case"; exit 1; }

printf 'Phase: done\n' >> "$tmp/.superpowers/sdd/demo/progress.md"
out=$(cd "$tmp" && CLAUDE_PID=$$ "$s/session-start.sh")
echo "$out" | $py -c 'import json,sys; d=json.load(sys.stdin); assert "systemMessage" not in d, "finished ledger reported"' || { echo "FAIL done-ledger case"; exit 1; }

n=$(pgrep -f "caffeinate -i -w $$" | wc -l | tr -d " ")
[ "$n" = "1" ] || { echo "FAIL caffeinate started $n times, expected 1"; exit 1; }
rm -rf "$tmp"
echo "foreman hooks selftest: OK"
EOF
chmod +x scripts/selftest.sh && scripts/selftest.sh; echo "exit=$?"
```

Expected: a `FAIL notify` line and exit 1.

- [ ] **Step 2: Write notify.sh**

```bash
cd ~/Public/foreman && cat > scripts/notify.sh <<'EOF'
#!/bin/bash
# Foreman Notification hook: show the event message as a macOS banner.
msg=$(/usr/bin/python3 -c '
import json, sys
try:
    print((json.load(sys.stdin).get("message") or "").replace("\n", " "))
except Exception:
    pass
' 2>/dev/null)
[ -z "$msg" ] && msg="Claude Code needs you"

if [ -n "${NOTIFY_DRY_RUN:-}" ]; then
  echo "$msg"
  exit 0
fi
[ -x /usr/bin/osascript ] || exit 0
/usr/bin/osascript -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title "Claude Code" sound name "Glass"' \
  -e 'end run' "$msg" >/dev/null 2>&1
exit 0
EOF
chmod +x scripts/notify.sh
```

- [ ] **Step 3: Write session-start.sh**

```bash
cd ~/Public/foreman && cat > scripts/session-start.sh <<'EOF'
#!/bin/bash
# Foreman SessionStart hook.
# 1. Inject the lead's standing orders into the session.
# 2. Keep the Mac from idle-sleeping while this Claude process lives (keep_awake option).
# 3. If the current repo has unfinished team work, show the manager a message and
#    tell the lead to ask before resuming. Never resume on its own.

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

if [ "${CLAUDE_PLUGIN_OPTION_KEEP_AWAKE:-true}" != "false" ] && [ "$(uname)" = "Darwin" ]; then
  pid="${CLAUDE_PID:-}"
  if [ -z "$pid" ]; then
    p=$PPID
    while [ -n "$p" ] && [ "$p" -gt 1 ]; do
      case "$(ps -o comm= -p "$p" 2>/dev/null)" in *claude*) pid=$p; break ;; esac
      p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done
  fi
  if [ -n "$pid" ] && ! pgrep -f "caffeinate -i -w $pid\$" >/dev/null 2>&1; then
    nohup /usr/bin/caffeinate -i -w "$pid" >/dev/null 2>&1 &
  fi
fi

ledgers=""
if repo=$(git rev-parse --show-toplevel 2>/dev/null); then
  for ledger in "$repo"/.superpowers/sdd/*/progress.md; do
    [ -f "$ledger" ] || continue
    grep -q '^Phase: done' "$ledger" && continue
    phase=$(grep '^Phase:' "$ledger" | tail -1)
    ledgers="${ledgers}${ledger} (${phase:-no Phase line yet})"$'\n'
  done
fi

FOREMAN_ORDERS="$root/orders.md" FOREMAN_LEDGERS="$ledgers" /usr/bin/python3 - <<'PY'
import json, os
orders = open(os.environ["FOREMAN_ORDERS"]).read()
items = [l for l in os.environ["FOREMAN_LEDGERS"].splitlines() if l]
context = "<foreman>\nYou have foreman. These are your standing orders as the lead:\n\n" + orders + "</foreman>"
out = {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context}}
if items:
    listing = "; ".join(items)
    out["systemMessage"] = "Unfinished team work in this repo: " + listing + ". Type resume to continue it, or carry on with anything else."
    out["hookSpecificOutput"]["additionalContext"] += (
        "\n\nUnfinished team ledger: " + listing + ". Do not resume on your own. If the manager says resume or continue, "
        "run the resume protocol in your standing orders; otherwise mention it in one line and do what they asked.")
print(json.dumps(out))
PY
exit 0
EOF
chmod +x scripts/session-start.sh
```

- [ ] **Step 4: Write hooks.json**

```bash
cd ~/Public/foreman && mkdir -p hooks && cat > hooks/hooks.json <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/session-start.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}\"/scripts/notify.sh" }
        ]
      }
    ]
  }
}
EOF
```

- [ ] **Step 5: Run the self-test and validate**

Run: `cd ~/Public/foreman && scripts/selftest.sh && claude plugin validate . && claude plugin validate --strict .claude-plugin/plugin.json`
Expected: `foreman hooks selftest: OK` and both validations pass.

- [ ] **Step 6: Commit**

```bash
cd ~/Public/foreman && git add hooks scripts && git commit -m "Add session-start and notification hooks with a self-test"
```

---

### Task 6: Setup skill

**Files:**
- Create: `skills/setup/SKILL.md`, `skills/setup/scripts/doctor.py`, `skills/setup/scripts/apply-setup.py`, `tests/test_setup.sh`

**Interfaces:**
- Consumes: `$HOME/.claude/settings.json`, `$HOME/.claude/CLAUDE.md`, `$HOME/.claude/agents/`, `$HOME/.claude/hooks/`. Both scripts honour `HOME` so tests run against a fake home.
- Produces: `doctor.py` prints lines `OK|WARN|FAIL <check>: <detail>` and a final `summary: N ok, N warn, N fail`, exit 0. `apply-setup.py [--env] [--resilience] [--migrate] [--all] [--dry-run]` prints one line per change, exit 0.

- [ ] **Step 1: Write the failing test**

```bash
cd ~/Public/foreman && mkdir -p tests && cat > tests/test_setup.sh <<'EOF'
#!/bin/bash
# Runnable check for /foreman:setup scripts against a fake HOME.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
py=/usr/bin/python3
doctor="$here/skills/setup/scripts/doctor.py"
apply="$here/skills/setup/scripts/apply-setup.py"

fake=$(mktemp -d); export HOME="$fake"
mkdir -p "$HOME/.claude/agents" "$HOME/.claude/hooks"
cat > "$HOME/.claude/settings.json" <<'JSON'
{
  "model": "keep-me",
  "enabledPlugins": {"superpowers@claude-plugins-official": true, "ponytail@ponytail": true},
  "hooks": {
    "Notification": [{"hooks": [{"type": "command", "command": "/Users/x/.claude/hooks/notify.sh"}]}],
    "SessionStart": [{"hooks": [{"type": "command", "command": "/Users/x/.claude/hooks/session-start.sh"}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "echo keep"}]}]
  }
}
JSON
printf '# Standing orders for the lead\nold text\n' > "$HOME/.claude/CLAUDE.md"
for r in architect implementer reviewer qa; do printf -- '---\nname: %s\n---\n' "$r" > "$HOME/.claude/agents/$r.md"; done
echo '#!/bin/bash' > "$HOME/.claude/hooks/notify.sh"

report=$($py "$doctor")
echo "$report" | grep -q "^FAIL agent-teams" || { echo "FAIL: doctor missed agent-teams env"; echo "$report"; exit 1; }
echo "$report" | grep -q "^WARN resilience" || { echo "FAIL: doctor missed resilience settings"; exit 1; }
echo "$report" | grep -q "^WARN leftover-orders" || { echo "FAIL: doctor missed CLAUDE.md leftover"; exit 1; }
echo "$report" | grep -q "^WARN leftover-agents" || { echo "FAIL: doctor missed agents leftover"; exit 1; }
echo "$report" | grep -q "^WARN leftover-hooks" || { echo "FAIL: doctor missed hooks leftover"; exit 1; }
echo "$report" | grep -q "^OK superpowers" || { echo "FAIL: doctor should see superpowers enabled"; exit 1; }

before=$(cat "$HOME/.claude/settings.json")
$py "$apply" --all --dry-run >/dev/null
[ "$before" = "$(cat "$HOME/.claude/settings.json")" ] || { echo "FAIL: dry-run changed settings"; exit 1; }
[ -f "$HOME/.claude/CLAUDE.md" ] || { echo "FAIL: dry-run moved CLAUDE.md"; exit 1; }

$py "$apply" --all >/dev/null
$py - <<'PY'
import json, os, glob
s = json.load(open(os.path.expanduser("~/.claude/settings.json")))
assert s["model"] == "keep-me"
assert s["env"]["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] == "1"
assert s["autoContinueAtUsageLimit"] is True and s["inputNeededNotifEnabled"] is True
assert "Notification" not in s["hooks"] and "SessionStart" not in s["hooks"], s["hooks"]
assert s["hooks"]["PostToolUse"][0]["hooks"][0]["command"] == "echo keep"
assert not os.path.exists(os.path.expanduser("~/.claude/CLAUDE.md"))
assert not os.path.exists(os.path.expanduser("~/.claude/agents/reviewer.md"))
backups = glob.glob(os.path.expanduser("~/.claude/backups/foreman-migration-*"))
assert len(backups) == 1, backups
b = backups[0]
for f in ("CLAUDE.md", "settings.json", "agents/reviewer.md", "hooks/notify.sh"):
    assert os.path.exists(os.path.join(b, f)), f
print("apply: OK")
PY

report=$($py "$doctor")
echo "$report" | grep -q "leftover" && { echo "FAIL: leftovers still reported"; echo "$report"; exit 1; }
echo "$report" | grep -q "^FAIL agent-teams" && { echo "FAIL: env still reported"; exit 1; }
echo "$report" | grep -q "^OK resilience" || { echo "FAIL: resilience not OK after apply"; exit 1; }
rm -rf "$fake"
echo "setup selftest: OK"
EOF
chmod +x tests/test_setup.sh && tests/test_setup.sh; echo "exit=$?"
```

Expected: a python "No such file" error and exit 2.

- [ ] **Step 2: Write doctor.py**

```bash
cd ~/Public/foreman && mkdir -p skills/setup/scripts && cat > skills/setup/scripts/doctor.py <<'EOF'
#!/usr/bin/env python3
"""Report foreman prerequisites. One line per check: OK|WARN|FAIL <name>: <detail>. Always exits 0."""
import json
import os
import platform
import shutil
import subprocess

MIN_CLAUDE = (2, 1, 267)
HOME = os.path.expanduser("~")
CLAUDE_DIR = os.path.join(HOME, ".claude")
SETTINGS = os.path.join(CLAUDE_DIR, "settings.json")
ROLES = ("architect", "implementer", "reviewer", "qa")
counts = {"OK": 0, "WARN": 0, "FAIL": 0}


def line(level, name, detail):
    counts[level] += 1
    print("%s %s: %s" % (level, name, detail))


def settings():
    try:
        return json.load(open(SETTINGS))
    except (OSError, ValueError):
        return {}


def version_tuple(text):
    for tok in text.split():
        parts = tok.split(".")
        if len(parts) == 3 and all(p.isdigit() for p in parts):
            return tuple(int(p) for p in parts)
    return None


s = settings()

if platform.system() == "Darwin":
    line("OK", "macos", platform.mac_ver()[0])
else:
    line("FAIL", "macos", "foreman supports macOS only in this version")

for tool in ("/usr/bin/osascript", "/usr/bin/caffeinate"):
    line("OK" if os.path.exists(tool) else "FAIL", os.path.basename(tool), tool)

claude = shutil.which("claude")
if claude:
    try:
        out = subprocess.run([claude, "--version"], capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.TimeoutExpired):
        out = ""
    v = version_tuple(out)
    if v is None:
        line("WARN", "claude-version", "could not parse `claude --version`: %r" % out.strip())
    elif v >= MIN_CLAUDE:
        line("OK", "claude-version", ".".join(map(str, v)))
    else:
        line("FAIL", "claude-version", "%s is below %s; run `claude update`" % (".".join(map(str, v)), ".".join(map(str, MIN_CLAUDE))))
else:
    line("FAIL", "claude-version", "`claude` not on PATH")

enabled = s.get("enabledPlugins", {})
def plugin_on(prefix):
    return any(k.startswith(prefix + "@") and v for k, v in enabled.items())
line("OK" if plugin_on("superpowers") else "FAIL", "superpowers",
     "enabled" if plugin_on("superpowers") else "run: claude plugin install superpowers@claude-plugins-official")
line("OK" if plugin_on("ponytail") else "FAIL", "ponytail",
     "enabled" if plugin_on("ponytail") else "run: claude plugin marketplace add DietrichGebert/ponytail && claude plugin install ponytail@ponytail")

gh = shutil.which("gh")
if gh and subprocess.run([gh, "auth", "status"], capture_output=True).returncode == 0:
    line("OK", "gh-auth", "logged in")
else:
    line("WARN", "gh-auth", "draft PRs at Gate 2 need `gh auth login`")

if s.get("env", {}).get("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS") == "1":
    line("OK", "agent-teams", "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1")
else:
    line("FAIL", "agent-teams", "not set; fix: apply-setup.py --env")

if s.get("autoContinueAtUsageLimit") is True and s.get("inputNeededNotifEnabled") is True:
    line("OK", "resilience", "autoContinueAtUsageLimit and inputNeededNotifEnabled are on")
else:
    line("WARN", "resilience", "autoContinueAtUsageLimit or inputNeededNotifEnabled off; fix: apply-setup.py --resilience")

orders = os.path.join(CLAUDE_DIR, "CLAUDE.md")
try:
    first = open(orders).readline().strip()
except OSError:
    first = ""
if first == "# Standing orders for the lead":
    line("WARN", "leftover-orders", "%s duplicates the plugin's orders; fix: apply-setup.py --migrate" % orders)

leftover_agents = [r for r in ROLES if os.path.exists(os.path.join(CLAUDE_DIR, "agents", r + ".md"))]
if leftover_agents:
    line("WARN", "leftover-agents", "~/.claude/agents/{%s}.md duplicate the plugin roles; fix: apply-setup.py --migrate" % ",".join(leftover_agents))

hooks = s.get("hooks", {})
leftover_hooks = [ev for ev in ("Notification", "SessionStart")
                  for group in hooks.get(ev, []) for h in group.get("hooks", [])
                  if "/.claude/hooks/" in h.get("command", "")]
if leftover_hooks:
    line("WARN", "leftover-hooks", "user-level %s hooks point at ~/.claude/hooks and would fire twice; fix: apply-setup.py --migrate" % ",".join(sorted(set(leftover_hooks))))

print("summary: %d ok, %d warn, %d fail" % (counts["OK"], counts["WARN"], counts["FAIL"]))
EOF
chmod +x skills/setup/scripts/doctor.py
```

- [ ] **Step 3: Write apply-setup.py**

```bash
cd ~/Public/foreman && cat > skills/setup/scripts/apply-setup.py <<'EOF'
#!/usr/bin/env python3
"""Apply the fixes the doctor cannot: settings a plugin may not set, and leftovers from a manual install.

Usage: apply-setup.py [--env] [--resilience] [--migrate] [--all] [--dry-run]
Every change is printed. Files are moved to ~/.claude/backups/foreman-migration-<stamp>/, never deleted.
"""
import json
import os
import shutil
import sys
import time

HOME = os.path.expanduser("~")
CLAUDE_DIR = os.path.join(HOME, ".claude")
SETTINGS = os.path.join(CLAUDE_DIR, "settings.json")
ROLES = ("architect", "implementer", "reviewer", "qa")
HOOK_FILES = ("notify.sh", "session-start.sh", "selftest.sh")

args = set(sys.argv[1:])
dry = "--dry-run" in args
do_env = "--env" in args or "--all" in args
do_res = "--resilience" in args or "--all" in args
do_mig = "--migrate" in args or "--all" in args
if not (do_env or do_res or do_mig):
    print(__doc__)
    sys.exit(0)

stamp = time.strftime("%Y%m%d-%H%M%S")
backup = os.path.join(CLAUDE_DIR, "backups", "foreman-migration-" + stamp)


def say(msg):
    print(("would " if dry else "") + msg)


def move(src, rel):
    if not os.path.exists(src):
        return
    dst = os.path.join(backup, rel)
    say("move %s -> %s" % (src, dst))
    if not dry:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)


try:
    s = json.load(open(SETTINGS))
except (OSError, ValueError):
    s = {}
original = json.dumps(s, sort_keys=True)

if do_env:
    s.setdefault("env", {})["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
    say("set env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1")
if do_res:
    s["autoContinueAtUsageLimit"] = True
    s["inputNeededNotifEnabled"] = True
    say("set autoContinueAtUsageLimit=true, inputNeededNotifEnabled=true")
if do_mig:
    hooks = s.get("hooks", {})
    for ev in ("Notification", "SessionStart"):
        groups = hooks.get(ev, [])
        kept = [g for g in groups if not any("/.claude/hooks/" in h.get("command", "") for h in g.get("hooks", []))]
        if len(kept) != len(groups):
            say("remove user-level %s hook pointing at ~/.claude/hooks" % ev)
            if kept:
                hooks[ev] = kept
            else:
                hooks.pop(ev, None)
    orders = os.path.join(CLAUDE_DIR, "CLAUDE.md")
    try:
        first = open(orders).readline().strip()
    except OSError:
        first = ""
    if first == "# Standing orders for the lead":
        move(orders, "CLAUDE.md")
    for r in ROLES:
        move(os.path.join(CLAUDE_DIR, "agents", r + ".md"), os.path.join("agents", r + ".md"))
    for f in HOOK_FILES:
        move(os.path.join(CLAUDE_DIR, "hooks", f), os.path.join("hooks", f))

if json.dumps(s, sort_keys=True) != original:
    say("write %s (previous copy in %s)" % (SETTINGS, os.path.join(backup, "settings.json")))
    if not dry:
        os.makedirs(backup, exist_ok=True)
        if os.path.exists(SETTINGS):
            shutil.copy2(SETTINGS, os.path.join(backup, "settings.json"))
        with open(SETTINGS, "w") as fh:
            json.dump(s, fh, indent=2)
            fh.write("\n")
print("done" if not dry else "dry run, nothing changed")
EOF
chmod +x skills/setup/scripts/apply-setup.py
```

- [ ] **Step 4: Write SKILL.md**

```bash
cd ~/Public/foreman && cat > skills/setup/SKILL.md <<'EOF'
---
name: setup
description: Check and fix the prerequisites for the foreman team plugin - required plugins, macOS tools, gh auth, Agent Teams, resilience settings, and leftovers from a manual install. Run once after installing foreman, and again whenever something seems off.
---

# Foreman setup

The scripts are in `scripts/` under this skill's base directory. Call them with `/usr/bin/python3`.

1. Run `scripts/doctor.py` and show its output verbatim.
2. If the summary has no WARN or FAIL lines, say the setup is complete and stop.
3. Otherwise, for each problem the doctor can fix, ask the manager with AskUserQuestion (multiSelect) which to apply:
   - Agent Teams env var (`--env`)
   - Resilience settings (`--resilience`)
   - Move manual-install leftovers to a backup folder (`--migrate`)
   Missing plugins, an old Claude Code, or `gh` auth cannot be fixed by the script; show the exact command from the doctor line instead.
4. Run `scripts/apply-setup.py` with the chosen flags and show its output. Nothing is deleted; moved files land in `~/.claude/backups/foreman-migration-<stamp>/`.
5. Run the doctor again and show the result. If `--env` or `--migrate` ran, tell the manager to restart Claude Code so the env var and hook changes take effect.
EOF
```

- [ ] **Step 5: Run the test, then the doctor for real**

Run: `cd ~/Public/foreman && tests/test_setup.sh && /usr/bin/python3 skills/setup/scripts/doctor.py`
Expected: `setup selftest: OK`, then a real report for this machine ending with a `summary:` line. Leftover warnings for `~/.claude/CLAUDE.md`, agents, and hooks are expected here; they are migrated in Task 8.

- [ ] **Step 6: Commit**

```bash
cd ~/Public/foreman && git add skills tests && git commit -m "Add /foreman:setup with a prerequisite doctor, an applier, and a test"
```

---

### Task 7: Documentation

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `docs/design.md`
- Create: `docs/team-design.md`

**Interfaces:**
- Consumes: `~/.claude/docs/superpowers/specs/2026-09-10-agent-team-design.md`.

- [ ] **Step 1: Copy the parent design and write the README**

```bash
cd ~/Public/foreman && cp ~/.claude/docs/superpowers/specs/2026-09-10-agent-team-design.md docs/team-design.md
cat > README.md <<'EOF'
# Foreman

Run Claude Code as a small software team that reports to you. Four roles
(architect, implementer, reviewer, qa), a lead with standing orders, two
approval gates, escalation to your desktop and phone, and work that survives
interruptions. How the team works is in [docs/team-design.md](docs/team-design.md).

## Requirements

macOS. Claude Code 2.1.267 or newer. The `superpowers` and `ponytail` plugins.
`gh` logged in, for the draft pull request at the end of each feature.

## Install

```
claude plugin marketplace add surajgour-d11/foreman
claude plugin install foreman@foreman
```

Then, in any Claude Code session:

```
/foreman:setup
```

It checks the requirements, offers to apply the three settings a plugin
cannot set for itself, and moves any files from a manual install into a
backup folder. Restart Claude Code afterwards.

## What changes in a session

- The lead follows the standing orders in [orders.md](orders.md): plan, plan
  review by two architects, your approval, execution with per-task review,
  qa, final review by two reviewers, and a draft pull request for you.
- A macOS banner appears whenever Claude Code is waiting on you.
- Your Mac does not idle-sleep while a session is open.
- If a repo has unfinished team work, the session tells you on open and
  waits for you to type `resume`. It never resumes on its own.

## Configure

`keep_awake` (default on) controls the caffeinate behaviour. Set it at install
with `claude plugin install foreman@foreman --config keep_awake=false`, or
change it later from `/plugin`.

Roles cannot be customised per user in this version; the lead dispatches the
plugin's own `foreman:<role>` agents. Per-role overrides are on the list for a
later release.

To enable foreman for everyone who opens a repo, add to its `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": { "foreman": { "source": { "source": "github", "repo": "surajgour-d11/foreman" } } },
  "enabledPlugins": { "foreman@foreman": true }
}
```

## Update and remove

```
claude plugin update foreman@foreman
claude plugin uninstall foreman@foreman
```

Uninstalling leaves the settings `/foreman:setup` applied; your backups are
in `~/.claude/backups/foreman-migration-*`.

## Development

`scripts/selftest.sh` checks the hooks. `tests/test_setup.sh` checks the
setup scripts against a fake home. `claude plugin validate .` checks the
manifests. Release by bumping `version` in `.claude-plugin/plugin.json` and
adding a CHANGELOG entry.
EOF
cat > CHANGELOG.md <<'EOF'
# Changelog

## 0.1.0

First release. Four roles, standing orders injected per session, banner and
keep-awake hooks, `/foreman:setup` doctor and applier. macOS only.
EOF
```

- [ ] **Step 2: Commit**

```bash
cd ~/Public/foreman && git add README.md CHANGELOG.md docs && git commit -m "Document install, configuration, and development"
```

---

### Task 8: Install on this machine and verify (lead-run)

The lead runs this task itself: it talks to the manager, and it changes the manager's own settings. Every `claude -p` gets `< /dev/null` (otherwise it waits on stdin) and is invoked as `command claude` because the manager's shell aliases `claude` to a caffeinate wrapper.

**Files:**
- Modify: `docs/design.md` (final status), the plan's ledger `progress.md` (results)

**Interfaces:**
- Consumes: everything above; the throwaway repo at `/private/tmp/claude-501/-Users-suraj-Public/b26d3e91-98d6-4764-9e99-792c374bfbd4/scratchpad/team-smoke`.

- [ ] **Step 1: Register the marketplace from the local checkout and install**

```bash
claude plugin marketplace add ~/Public/foreman
claude plugin install foreman@foreman
claude plugin list 2>&1 | grep -i foreman
```

Expected: `foreman@foreman` listed as installed and enabled. No push happens before Gate 2. Fresh-install auto-install of superpowers is not exercised here because superpowers is already installed. After the pull request merges, re-register from GitHub so updates track `main`: `claude plugin marketplace remove foreman && claude plugin marketplace add surajgour-d11/foreman && claude plugin install foreman@foreman`. Removing the marketplace uninstalls the plugin and drops its `pluginConfigs`, so `keep_awake` returns to its default.

- [ ] **Step 2: Doctor**

Run: `/usr/bin/python3 ~/Public/foreman/skills/setup/scripts/doctor.py`
Expected: no FAIL lines; WARNs for `leftover-orders`, `leftover-agents`, `leftover-hooks`. Until Step 6 both the user-level and the plugin hooks fire, so the ledger banner shows twice in the toy repo; transient.

- [ ] **Step 3: Probe a real session for orders and agent names**

```bash
cd /private/tmp/claude-501/-Users-suraj-Public/b26d3e91-98d6-4764-9e99-792c374bfbd4/scratchpad/team-smoke
command claude -p --model haiku "Three answers, terse. 1) Quote verbatim the markdown heading line (it starts with #) of the standing orders you were given at session start, or NONE. 2) List every agent type available to you whose name starts with foreman:, comma separated. 3) List every skill available to you whose name starts with foreman:." < /dev/null
```

Expected: `# Standing orders for the lead`; `foreman:architect, foreman:implementer, foreman:qa, foreman:reviewer`; `foreman:setup`.

- [ ] **Step 4: Probe that a plugin agent's skill preload applies**

```bash
cd /private/tmp/claude-501/-Users-suraj-Public/b26d3e91-98d6-4764-9e99-792c374bfbd4/scratchpad/team-smoke
command claude -p --model sonnet "Dispatch the foreman:implementer agent with this brief: change no files; list the names of any skills already loaded in your context, then stop. Paste its reply verbatim and nothing else." < /dev/null
```

Expected: the reply names `test-driven-development`, `verification-before-completion`, and `ponytail`. If it names none, record it: the fix is one line in `agents/implementer.md` telling it to load those skills first, and that becomes a fix task.

- [ ] **Step 5: Probe keep_awake off**

```bash
/usr/bin/python3 - <<'EOF'
import json, os
p = os.path.expanduser("~/.claude/settings.json"); s = json.load(open(p))
s.setdefault("pluginConfigs", {}).setdefault("foreman@foreman", {}).setdefault("options", {})["keep_awake"] = False
json.dump(s, open(p, "w"), indent=2); open(p, "a").write("\n")
EOF
cd /tmp && command claude -p --model haiku "Reply ok." < /dev/null >/dev/null 2>&1 & cpid=$!
seen=""; for i in $(seq 1 30); do pgrep -f "caffeinate -i -w $cpid\$" >/dev/null && { seen=yes; break; }; sleep 0.5; done; wait $cpid; echo "caffeinate for $cpid: ${seen:-none}"
```

Expected: `caffeinate for <pid>: none`. The pattern is scoped to this probe's PID so another open session's caffeinate cannot make it pass or fail. Then set the option back to `true` the same way and confirm caffeinate appears within the loop.

- [ ] **Step 6: Migrate this machine**

Pre-approved at Gate 1. Run `/usr/bin/python3 ~/Public/foreman/skills/setup/scripts/apply-setup.py --migrate`, then the doctor again.
Expected: no `leftover` lines; `summary: N ok, 0 warn, 0 fail`. The lead's own session loaded `~/.claude/hooks/*.sh` at startup, so its banner hook errors until the manager restarts; expected. Rollback if anything looks wrong, with `<b>` the new `~/.claude/backups/foreman-migration-*` directory:

```bash
cp <b>/settings.json ~/.claude/; mv <b>/CLAUDE.md ~/.claude/; mv <b>/agents/* ~/.claude/agents/; mv <b>/hooks/* ~/.claude/hooks/
```

- [ ] **Step 7: Record results**

Append one `Result: Task 8 step N — PASS | FAIL — <what>` line per step to the plan's ledger `progress.md`. Any FAIL becomes a fix task. Then set `docs/design.md` Status to `Implemented and verified 2026-09-11` and commit it: `git add docs/design.md && git commit -m "Mark the design verified"`.
