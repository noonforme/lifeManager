# Developing LifeOS with Paseo

Open the existing local checkout at `/home/aUser/lifeManager` in Paseo.
Use this workspace to continue the unfinished changes already on disk.
A new git worktree starts from committed files and will not include those changes.

## Agents and project context

Codex uses the installed CLI and its existing ChatGPT login. Claude Code uses
its existing Claude Pro login. Both logins have been verified on this machine;
no API-key override was present during setup. Paseo can run either provider.
Each account keeps its own allowance; Paseo does not combine them into one pool.

Use one coordinator for the project and at most two implementation workers.
Give Codex and Claude independent Beads issues and separate worktrees so they
can work at the same time. Keep implementation and review separate: ask the
other provider to review the change against its issue and tests, then let the
coordinator integrate it and run the combined checks. Two implementations of
the same issue consume both allowances without increasing completed work.

When an account reaches its limit, preserve its worktree and record the issue,
changed files, completed checks, and next step in Beads. Give that handoff to the
other provider, or wait for the reported reset time. Check `codex login status`
and `claude auth status --json` when changing authentication; use the subscription
login for this workflow. Do not switch to API billing just to continue a task.

The recovery workers are separate Paseo workspace tabs. From your phone, connect
to this desktop host and open the worker or coordinator tab to follow its work.
Send project-wide changes to the coordinator; send a correction specific to a
worker's assigned issue to that worker.

Project instructions live in `AGENTS.md` and `CLAUDE.md`; project skills live in
`.agents/skills` and `.claude/skills`. Beads holds task status and persistent
project knowledge. A fresh session should run:

```bash
bd prime
bd list --status=in_progress
bd ready
git status --short
```

Before UI work, read `lib/ui/CATALOG.md` and follow the `lifeos-ui` skill.
Ask explicitly for commits or pushes when you want them; the project defaults
to leaving changes available for review.

For the current UI library work, a starting prompt is:

> Read AGENTS.md, run bd prime, and inspect lifeManager-9pk.2 and its child
> issues. Review the existing uncommitted changes and the UI library plan
> before continuing. Preserve the work already in this checkout.

## Workspace actions

The repository's `paseo.json` exposes three scripts in Paseo:

| Script | Action |
| --- | --- |
| `lifeos` | Open the `./app.sh` menu: app, tests, checks, debug mode, or widget gallery. |
| `test` | Run the existing launcher’s test command and exit. |
| `check` | Run analysis, format verification, and schema checks and exit. |

The launcher finds the pinned Flutter toolchain through `FLUTTER`, `PATH`, or
`~/.local/opt/flutter-3.47.5`. These scripts reuse it.

From a terminal in this repository:

```bash
paseo script ls
paseo script start test
```

If Paseo reports multiple workspaces for the same directory, add
`--workspace <workspace-id>`; find IDs with `paseo workspace ls`.
For future worktrees, include `paseo.json` in the branch used to create them.

## Phone or another computer

The desktop daemon uses Paseo's encrypted relay and listens locally at
`127.0.0.1:6767`. Pairing does not require router port forwarding.

After the initial setup, reopen Paseo once to load the saved setting that
keeps its daemon running after Desktop quits. Then open **Settings → your
host → Pair a device**, and scan the QR code with Paseo on your phone.
On another computer, use Paseo's pairing-link option for the same host.

The development computer must remain powered on, awake, and connected to the
internet for remote access. Get pairing links directly from Paseo; keep them
out of this repository.

The bundled CLI is available as `paseo` through a user-local symlink. Inspect
the daemon or generate a fresh pairing code with:

```bash
paseo daemon status
paseo daemon pair
```

See the official [connectivity guide](https://paseo.sh/docs/connectivity),
[Codex setup](https://paseo.sh/docs/codex), and
[workspace scripts](https://paseo.sh/docs/worktrees).
