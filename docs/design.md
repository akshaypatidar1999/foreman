# Foreman Plugin Design

**Date:** 2026-09-11
**Status:** Draft for manager review
**Parent design:** `docs/team-design.md`, the agent-team design this plugin packages. Nothing in the team's behaviour changes here; this document covers only distribution, prerequisites, and configuration.

## 1. Purpose

Ship the agent team as a Claude Code plugin named `foreman`, hosted in the private GitHub repo `surajgour-d11/foreman`, which is also its own marketplace. Team members install with two commands. Going public later means changing repo visibility, nothing in the layout.

## 2. Decisions

| Topic | Decision |
|---|---|
| Name | `foreman`. Skills appear as `/foreman:<skill>`, agents as `foreman:<role>`. |
| Hosting | One repo, both marketplace and plugin. `.claude-plugin/marketplace.json` lists `./` as the single plugin. |
| Platform | macOS only in this version. The macOS-specific parts (banner, caffeinate) exit silently elsewhere; the standing orders and ledger notice are platform-neutral and always emitted. |
| Standing orders | Fixed text, injected into every session by the SessionStart hook as `additionalContext`, the same mechanism superpowers uses. Plugins cannot ship a CLAUDE.md. |
| Configuration | One `userConfig` option, `keep_awake` (boolean, default true), read by the hook. No per-role overrides: plugin agents are namespaced `foreman:<role>`, so a copied agent file becomes a different agent and is never dispatched. Deferred. |
| Prerequisites | `superpowers` declared in `dependencies` in cross-marketplace form, since a bare name resolves only inside the foreman marketplace. `ponytail`, macOS tools, `gh` auth, Agent Teams env, and the two resilience settings are checked by `/foreman:setup`, which offers to apply the settings a plugin cannot set itself. |
| Version | `version` in `plugin.json` only, starting at `0.1.0`. Bumped on every release; users update with `claude plugin update foreman@foreman`. |
| License | MIT, so that going public needs no relicensing. Change before publishing if you prefer otherwise. |

## 3. Layout

```
foreman/
├── .claude-plugin/
│   ├── plugin.json          name, version, dependencies, userConfig
│   └── marketplace.json     single entry, source "./"
├── agents/                  architect.md, implementer.md, reviewer.md, qa.md
├── hooks/hooks.json         SessionStart (startup|clear|compact) and Notification
├── scripts/
│   ├── session-start.sh     orders + ledger message + caffeinate, one JSON output
│   ├── notify.sh            macOS banner
│   └── selftest.sh          runnable check for both hooks
├── orders.md                the standing orders, verbatim
├── skills/setup/
│   ├── SKILL.md             /foreman:setup
│   └── scripts/
│       ├── doctor.py        prerequisite report
│       └── apply-setup.py   settings merge and migration
├── tests/test_setup.sh      runnable check for doctor and apply against a fake HOME
├── docs/design.md           this file
├── docs/team-design.md      the parent agent-team design, copied so the repo is self-contained
├── README.md                install, update, override, project auto-enable
├── CHANGELOG.md
└── LICENSE
```

## 4. Changes to existing files

- **Agents.** Content unchanged. Body references to role names become `foreman:architect`, `foreman:reviewer`, and so on where a role is named as a dispatch target.
- **Standing orders** (`orders.md`). Same text as the current `~/.claude/CLAUDE.md` with four edits: roles are named `foreman:<role>` as dispatch targets, "live in `~/.claude/agents`" becomes "ship with the foreman plugin", and the hook line "the SessionStart hook prints it" stays true.
- **session-start.sh.** Gains a third job: read `orders.md` from `${CLAUDE_PLUGIN_ROOT}` and include it in `additionalContext` ahead of any ledger notice. Honours `CLAUDE_PLUGIN_OPTION_KEEP_AWAKE`. Runs on `startup|clear|compact` so orders survive compaction, matching superpowers.
- **notify.sh.** Unchanged, except it exits quietly when `osascript` is absent.
- **hooks.json.** Both hooks reference scripts via `"${CLAUDE_PLUGIN_ROOT}"/scripts/...`.

## 5. `/foreman:setup`

Idempotent. Run once after install, again any time to re-check.

1. Runs `skills/setup/scripts/doctor.py`, which prints one line per check: Claude Code version, superpowers enabled, ponytail enabled, macOS with `osascript` and `caffeinate`, `gh auth status`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` in settings env, `autoContinueAtUsageLimit`, `inputNeededNotifEnabled`, and leftovers from a manual install: a `~/.claude/CLAUDE.md` starting "# Standing orders for the lead", user-level agents with the four role names, user-level Notification or SessionStart hooks pointing at `~/.claude/hooks/`.
2. Shows the report and asks the user which fixes to apply. Missing plugins get the exact install commands. Settings and leftovers are applied by `skills/setup/scripts/apply-setup.py`, which merges into `~/.claude/settings.json` preserving every other key, and moves leftovers to `~/.claude/backups/foreman-migration-<date>/` rather than deleting them.
3. Re-runs the doctor and shows the result.

## 6. Install and update

```
claude plugin marketplace add surajgour-d11/foreman
claude plugin install foreman@foreman
/foreman:setup
```

Private repo access uses the team member's existing `gh auth login` or SSH key. Team repos can pre-register and enable the plugin for everyone who trusts the folder:

```json
{
  "extraKnownMarketplaces": { "foreman": { "source": { "source": "github", "repo": "surajgour-d11/foreman" } } },
  "enabledPlugins": { "foreman@foreman": true }
}
```

Release: bump `version` in `plugin.json`, add a CHANGELOG entry, merge to `main`. Users run `claude plugin update foreman@foreman`.

## 7. Verification

1. `claude plugin validate .` passes.
2. `scripts/selftest.sh` passes.
3. Plugin installed on this machine from the local checkout, the manual files migrated, and the doctor reports all green. The GitHub path, including private-repo access, is exercised by the post-merge re-register.
4. A fresh session in the throwaway repo: the lead can quote the first line of its standing orders, lists `foreman:architect`, `foreman:implementer`, `foreman:reviewer`, `foreman:qa`, and a dispatched `foreman:implementer` reports that its preloaded skills are present.
5. The `keep_awake` option set to false stops caffeinate from starting.

## 8. Git flow for this repo

The first commit on `main` is the scaffold (README, LICENSE, CHANGELOG, this design, and the plan) because an empty repo has nothing to open a pull request against. Everything else lands on a branch and is delivered as a draft pull request for the manager to review and merge.

## 9. Deferred

- Per-user or per-project role overrides.
- Linux support (`notify-send`, `systemd-inhibit`).
- Templated standing orders driven by `userConfig`.
- Submission to the official Anthropic marketplace when the repo goes public.
